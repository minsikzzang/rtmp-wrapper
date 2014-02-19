//
//  RtmpWrapper.m
//  RtmpWrapper
//
//  Created by Min Kim on 9/30/13.
//  Copyright (c) 2013 iFactory Lab Limited. All rights reserved.
//

#import "RtmpWrapper.h"
#import <librtmp/rtmp.h>
#import <librtmp/log.h>
#import "IFTimeoutBlock.h"

const NSUInteger kRtmpOpenTimeout = 5;
const NSUInteger kRtmpWriteTimeout = 5;
const NSUInteger kMaxBufferSizeInKbyte = 500; // kbytes
const char *kOpenQueue = "com.ifactory.lab.rtmp.open.queue";
NSString *const kErrorDomain = @"com.ifactory.lab.rtmp.wrapper";

@interface RtmpWrapper () {
  RTMP *rtmp_;
  BOOL connected_;
  BOOL writeQueueInUse_;
  NSMutableArray *flvBuffer_;
  NSObject *lock_;
}

- (void)internalWrite:(id)buffer;
- (void)appendData:(NSData *)data
    withCompletion:(WriteCompleteHandler)completion;
// Resize data buffer for the given data. If the buffer size is bigger than
// max size, remove first input and return error to the completion handler.
- (void)resizeBuffer:(NSData *)data;

@property (nonatomic, retain) NSString *rtmpUrl;
@property (nonatomic, retain) NSMutableArray *flvBuffer;
@property (nonatomic, assign) NSInteger bufferSize;
@property (nonatomic, assign) BOOL writeEnable;
@property (nonatomic, assign) BOOL writeQueueInUse;

@end

@implementation RtmpWrapper

@synthesize connected = connected_;
@synthesize rtmpUrl;
@synthesize writeEnable;
@synthesize bufferSize;
@synthesize maxBufferSizeInKbyte;
@synthesize rtmpOpenTimeout;
@synthesize rtmpWriteTimeout;

void rtmpLog(int level, const char *fmt, va_list args) {
  NSString *log = @"";
  switch (level) {
    default:
    case RTMP_LOGCRIT:
      log = @"FATAL";
      break;
    case RTMP_LOGERROR:
      log = @"ERROR";
      break;
    case RTMP_LOGWARNING:
      log = @"WARN";
      break;
    case RTMP_LOGINFO:
      log = @"INFO";
      break;
    case RTMP_LOGDEBUG:
      log = @"VERBOSE";
      break;
    case RTMP_LOGDEBUG2:
      log = @"DEBUG";
      break;
  }
    
  NSLog([log stringByAppendingString:[NSString
                                      stringWithUTF8String:fmt]],
        args);
}

- (id)init {
  self = [super init];
  if (self != nil) {
    connected_ = NO;
    flvBuffer_ = [[NSMutableArray alloc] init];
    lock_ = [[NSObject alloc] init];
    maxBufferSizeInKbyte = kMaxBufferSizeInKbyte;
    bufferSize = 0;
    writeQueueInUse_ = NO;
    rtmpOpenTimeout = kRtmpOpenTimeout;
    rtmpWriteTimeout = kRtmpWriteTimeout;
    
    signal(SIGPIPE, SIG_IGN);
    
    // Allocate rtmp context object
    [self setRTMP:RTMP_Alloc()];
    
    RTMP_LogSetLevel(RTMP_LOGALL);
    RTMP_LogCallback(rtmpLog);
  }
  return self;
}

- (void)dealloc {
  if (self.connected) {
    [self rtmpClose];
  }
  if (rtmpUrl) {
    [rtmpUrl release];
  }
  if (flvBuffer_) {
    [flvBuffer_ release];
  }
  if (lock_) {
    [lock_ release];
  }
  // Release rtmp context
  RTMP_Free([self getRTMP]);
  
  [super dealloc];
}

- (void)setLogInfo {
  RTMP_LogSetLevel(RTMP_LOGINFO);
}

- (BOOL)isConnected {
  RTMP *r = [self getRTMP];
  if (r) {
    connected_ = RTMP_IsConnected(r);
  }
  return connected_;
}

- (void)rtmpClose {
  @synchronized (self) {
    RTMP *r = [self getRTMP];
    if (r) {
      RTMP_Close(r);
    }
  }
}

- (BOOL)reconnect {
  return [self rtmpOpenWithURL:self.rtmpUrl enableWrite:self.writeEnable];
}

+ (NSError *)errorRTMPFailedWithReason:(NSString *)errorReason
                               andCode:(RTMPErrorCode)errorCode {
  NSMutableDictionary *userinfo = [[NSMutableDictionary alloc] init];
  userinfo[NSLocalizedDescriptionKey] = errorReason;
  
  // create error object
  NSError *err = [NSError errorWithDomain:kErrorDomain
                                     code:errorCode
                                 userInfo:userinfo];
  [userinfo release];
  return err;
}

#pragma mark -
#pragma mark Private Methods

- (void)resizeBuffer:(NSData *)data {
  while (self.flvBuffer.count > 1 &&
         bufferSize > maxBufferSizeInKbyte * 1024) {
    id b = [self popFirstBuffer];
    if (!b || ![b isKindOfClass:[NSDictionary class]]) {
      break;
    }
    
    WriteCompleteHandler handler = [b objectForKey:@"completion"];
    NSError *error =
      [RtmpWrapper errorRTMPFailedWithReason:@"RTMP buffer is full because "
                                              "either frequent send failing or "
                                              "some reason."
                                     andCode:RTMPErrorBufferFull];
    if (handler) {
      // We have to release handler object because we copied earlier for safety
      // of multithread use
      handler(-1, error);
      [handler release];
    }
  }
}

- (NSDictionary *)setWriteObject:(NSData *)data
                  withCompletion:(WriteCompleteHandler)completion {
  NSMutableDictionary *b = [[NSMutableDictionary alloc] init];
  [b setObject:data forKey:@"data"];
  [b setObject:[NSString stringWithFormat:@"%d", data.length] forKey:@"length"];
  [b setObject:[completion copy] forKey:@"completion"];
  return [b autorelease];
}

- (void)appendData:(NSData *)data
    withCompletion:(WriteCompleteHandler)completion {
  NSDictionary *b = [self setWriteObject:data withCompletion:completion];
  [self pushBuffer:b];
}

- (void)internalWrite:(id)buffer {
  id item = (buffer == nil ? [self popFirstBuffer] : buffer);
  if (item) {
    NSData *data = [item objectForKey:@"data"];
    NSUInteger length = [[item objectForKey:@"length"] integerValue];
    WriteCompleteHandler handler = [item objectForKey:@"completion"];
    __block NSUInteger sent = -1;
    
    IFTimeoutHandler timeoutBlock = ^(IFTimeoutBlock *block) {
      NSError *error =
        [RtmpWrapper errorRTMPFailedWithReason:@"Timed out for writing"
                                       andCode:RTMPErrorWriteTimeout];
      if (handler) {
        handler(sent, error);
        [handler release];
      }
      
      self.writeQueueInUse = NO;
    };
    
    IFExecutionBlock executionBlock = ^(IFTimeoutBlock *b) {
      NSError *error = nil;
      sent = [self rtmpWrite:data];
      if (sent != length) {
        error =
          [RtmpWrapper errorRTMPFailedWithReason:
           [NSString stringWithFormat:@"Failed to write data "
                                       "(sent: %d, length: %d)", sent, length]
                                         andCode:RTMPErrorWriteFail];
      }
      
      [b signal];
      // If block has timed out, don't call callback function.
      if (!b.timedOut) {
        if (handler) {
          handler(sent, error);
          [handler release];
        }
        // If there is no error and there are more buffers to be sent,
        // call itself again.
        if (!error) {
          if (self.flvBuffer.count > 0) {
            [self internalWrite:nil];
            return;
          }
        } 
      }
      self.writeQueueInUse = NO;
    };
    
    IFTimeoutBlock *block = [[IFTimeoutBlock alloc] init];
    [block setExecuteAsyncWithTimeout:rtmpWriteTimeout
                          WithHandler:timeoutBlock
                    andExecutionBlock:executionBlock];
    [block release];
  }
}

#pragma mark -
#pragma mark Async class Methods

- (void)rtmpOpenWithURL:(NSString *)url
            enableWrite:(BOOL)enableWrite
         withCompletion:(OpenCompleteHandler)handler {
  IFTimeoutBlock *block = [[IFTimeoutBlock alloc] init];
  IFTimeoutHandler timeoutBlock = ^(IFTimeoutBlock *block) {
    // Deal with rtmp open timed out
    NSError *error =
      [RtmpWrapper errorRTMPFailedWithReason:
       [NSString stringWithFormat:@"Timed out for openning %@", url]
                                     andCode:RTMPErrorOpenTimeout];
    handler(error);
  };
  
  IFExecutionBlock execution = ^(IFTimeoutBlock *block) {
    NSError *error = nil;
    if (![self rtmpOpenWithURL:url enableWrite:enableWrite]) {
      error =
        [RtmpWrapper errorRTMPFailedWithReason:
         [NSString stringWithFormat:@"Cannot open %@", url]
                                       andCode:RTMPErrorURLOpenFail];
    }
    
    [block signal];
    if (!block.timedOut) {
      handler(error);
    }
  };
  
  [block setExecuteAsyncWithTimeout:rtmpOpenTimeout
                        WithHandler:timeoutBlock
                  andExecutionBlock:execution];
  [block release];
}

- (void)rtmpWrite:(NSData *)data
   withCompletion:(WriteCompleteHandler)completion {
  [self rtmpWrite:data
     withPriority:RTMPWritePriorityNormal
   withCompletion:completion];
}

- (void)rtmpWrite:(NSData *)data
     withPriority:(RTMPWritePriority)priority
   withCompletion:(WriteCompleteHandler)completion {
  // If priority is not high, put it into queue
  if (priority != RTMPWritePriorityHigh) {
    if (data) {
      [self appendData:data withCompletion:completion];
    }
    
    // Resize buffer for the given data.
    [self resizeBuffer:data];
    
    // Once queue is not in use, try to write data
    if (!self.writeQueueInUse) {
      self.writeQueueInUse = YES;
      @synchronized (self) {
        [self internalWrite:nil];
      }
    }
  } else {
    // If priority is high, create a write object and write it directly
    NSDictionary *obj = [self setWriteObject:data
                              withCompletion:completion];
    @synchronized (self) {
      [self internalWrite:obj];
    }
  }
}

#pragma mark -
#pragma mark Sync class Methods

- (BOOL)rtmpOpenWithURL:(NSString *)url enableWrite:(BOOL)enableWrite {
  RTMP *r = [self getRTMP];
  RTMP_Init(r);
  if (!RTMP_SetupURL(r,
                     (char *)[url cStringUsingEncoding:NSASCIIStringEncoding])) {
    return NO;
  }
  
  self.rtmpUrl = url;
  self.writeEnable = enableWrite;
  
  if (enableWrite) {
    RTMP_EnableWrite(r);
  }
  
  if (!RTMP_Connect(r, NULL) || !RTMP_ConnectStream(r, 0)) {
    return NO;
  }
  
  connected_ = RTMP_IsConnected(r);
  return YES;
}

- (NSUInteger)rtmpWrite:(NSData *)data {
  @synchronized (self) {
    int sent = -1;
    if (self.connected) {
      sent = RTMP_Write([self getRTMP], [data bytes], [data length]);
    }
    return sent;
  }
}

- (void)clearRtmpBuffer {
   @synchronized (flvBuffer_) {
     for (id b in flvBuffer_) {
       if (!b || ![b isKindOfClass:[NSDictionary class]]) {
         continue;
       }
       WriteCompleteHandler handler = [b objectForKey:@"completion"];
       if (handler) {
         [handler release];
       }
     }
     [flvBuffer_ removeAllObjects];
   }
}

#pragma mark -
#pragma mark Setters and Getters Methods

- (id)popFirstBuffer {
  @synchronized (flvBuffer_) {
    id obj = nil;
    if (flvBuffer_.count > 0) {
      obj = flvBuffer_.firstObject;
      if (obj) {
        bufferSize -= [[obj objectForKey:@"length"] integerValue];
        [obj retain];
        [flvBuffer_ removeObject:obj];
      }
    }
    return [obj autorelease];
  }
}

- (void)pushBuffer:(id)obj {
  @synchronized (flvBuffer_) {
    if (obj) {
      bufferSize += [[obj objectForKey:@"length"] integerValue];
      [flvBuffer_ addObject:obj];      
    }
  }
}

- (NSMutableArray *)flvBuffer {
  @synchronized (flvBuffer_) {
    return flvBuffer_;
  }
}

- (void)setFlvBuffer:(NSMutableArray *)b {
  @synchronized (flvBuffer_) {
    flvBuffer_ = b;
  }
}

- (BOOL)writeQueueInUse {
  @synchronized (lock_) {
    return writeQueueInUse_;
  }
}

- (void)setWriteQueueInUse:(BOOL)inUse {
  @synchronized (lock_) {
    writeQueueInUse_ = inUse;
  }
}

- (void)setRTMP:(RTMP *)rtmp {
  @synchronized (lock_) {
    rtmp_ = rtmp;
  }
}

- (RTMP *)getRTMP {
  @synchronized (lock_) {
    return rtmp_;
  }
}

@end

