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
#import "IFBandwidthCalculator.h"

const NSUInteger kRtmpOpenTimeout = 5;
const NSUInteger kRtmpWriteTimeout = 5;
const NSUInteger kMaxBufferSizeInKbyte = 500; // kbytes
const char *kOpenQueue = "com.ifactory.lab.rtmp.open.queue";
NSString *const kErrorDomain = @"com.ifactory.lab.rtmp.wrapper";

@interface RtmpWrapper () {
  RTMP *_rtmp;
  BOOL _connected;
  BOOL _writeQueueInUse;
  // Lock to protect writeQueueInUse_ variables from multi threaded access
  NSObject *_lock;
  IFBandwidthCalculator *_bandwidth;
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
@synthesize rtmpUrl = _rtmpUrl;
@synthesize writeEnable;
@synthesize bufferSize;
@synthesize maxBufferSizeInKbyte;
@synthesize openTimeout = _openTimeout;
@synthesize writeTimeout = _writeTimeout;
@synthesize outboundBandwidthInKbps;
@synthesize flvBuffer = _flvBuffer;

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
    _connected = NO;
    _flvBuffer = [[NSMutableArray alloc] init];
    _lock = [[NSObject alloc] init];
    maxBufferSizeInKbyte = kMaxBufferSizeInKbyte;
    bufferSize = 0;
    _writeQueueInUse = NO;
    _openTimeout = kRtmpOpenTimeout;
    _writeTimeout = kRtmpWriteTimeout;
    _bandwidth = [[IFBandwidthCalculator alloc] init];
    
    signal(SIGPIPE, SIG_IGN);
    
    RTMP_LogSetLevel(RTMP_LOGALL);
    RTMP_LogCallback(rtmpLog);
  }
  return self;
}

- (void)dealloc {
  _rtmpUrl = nil;
  _bandwidth = nil;
  [self clearBuffer];
  [self close];
  /*
  if (rtmpUrl) {
    [rtmpUrl release];
  }
  
  if (flvBuffer_) {
    [flvBuffer_ release];
  }
  if (lock_) {
    [lock_ release];
  }
   [bandwidth_ release];
   
   [super dealloc];
   */
}

- (void)setLogInfo {
  RTMP_LogSetLevel(RTMP_LOGINFO);
}

+ (NSError *)errorRTMPFailedWithReason:(NSString *)errorReason
                               andCode:(RTMPErrorCode)errorCode {
  NSMutableDictionary *userinfo = [[NSMutableDictionary alloc] init];
  userinfo[NSLocalizedDescriptionKey] = errorReason;
  
  // create error object
  NSError *err = [NSError errorWithDomain:kErrorDomain
                                     code:errorCode
                                 userInfo:userinfo];
  // [userinfo release];
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
      handler = nil;
      // [handler release];
    }
  }
}

- (NSDictionary *)setWriteObject:(NSData *)data
                  withCompletion:(WriteCompleteHandler)completion {
  NSMutableDictionary *b = [[NSMutableDictionary alloc] init];
  [b setObject:data forKey:@"data"];
  [b setObject:[NSString stringWithFormat:@"%d", (int)data.length] forKey:@"length"];
  [b setObject:[completion copy] forKey:@"completion"];
  // return [b autorelease];
  return b;
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
    __block WriteCompleteHandler handler = [item objectForKey:@"completion"];
    __block NSUInteger sent = -1;
    
    IFTimeoutHandler timeoutBlock = ^(IFTimeoutBlock *block) {
      NSError *error =
        [RtmpWrapper errorRTMPFailedWithReason:@"Timed out for writing"
                                       andCode:RTMPErrorWriteTimeout];
      if (handler) {
        handler(sent, error);
        handler = nil;
        // [handler release];
      }
      
      self.writeQueueInUse = NO;
    };
    
    IFExecutionBlock executionBlock = ^(IFTimeoutBlock *b) {
      NSError *error = nil;
      sent = [self write:data];
      if (sent != length) {
        error =
          [RtmpWrapper errorRTMPFailedWithReason:
           [NSString stringWithFormat:@"Failed to write data "
                                       "(sent: %ld, length: %ld)", sent, length]
                                         andCode:RTMPErrorWriteFail];
      }
      
      [b signal];
      // If block has timed out, don't call callback function.
      if (!b.timedOut) {
        if (handler) {
          handler(sent, error);
          handler = nil;
          // [handler release];
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
    [block setExecuteAsyncWithTimeout:(int)_writeTimeout
                          WithHandler:timeoutBlock
                    andExecutionBlock:executionBlock];
    // [block release];
  }
}

#pragma mark -
#pragma mark Async class Methods

- (void)openWithURL:(NSString *)url
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
    if (![self openWithURL:url enableWrite:enableWrite]) {
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
  
  [block setExecuteAsyncWithTimeout:(int)_openTimeout
                        WithHandler:timeoutBlock
                  andExecutionBlock:execution];
  // [block release];
}

- (void)write:(NSData *)data
withCompletion:(WriteCompleteHandler)completion {
  [self write:data
 withPriority:RTMPWritePriorityNormal
withCompletion:completion];
}

- (void)write:(NSData *)data
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

- (BOOL)openWithURL:(NSString *)url enableWrite:(BOOL)enableWrite {
  @synchronized (self) {
    // If still opened or not nil, close it.
    if (_rtmp) {
      [self close];
    }
    
    // Allocate rtmp context object
    _rtmp = RTMP_Alloc();
    
    RTMP_Init(_rtmp);
    char *strUrl = (char *)[url cStringUsingEncoding:NSASCIIStringEncoding];
    if (!RTMP_SetupURL(_rtmp, strUrl)) {
      return NO;
    }
    
    self.rtmpUrl = url;
    self.writeEnable = enableWrite;
    
    if (enableWrite) {
      RTMP_EnableWrite(_rtmp);
    }
    
    if (!RTMP_Connect(_rtmp, NULL) || !RTMP_ConnectStream(_rtmp, 0)) {
      return NO;
    }
    
    connected_ = RTMP_IsConnected(_rtmp);
    return YES;
  }
}

- (NSUInteger)write:(NSData *)data {
  @synchronized (self) {
    int sent = -1;
    if (self.connected) {
      NSDate *start = [NSDate date];
      sent = RTMP_Write(_rtmp, [data bytes], (int)[data length]);
      // Caculate time difference between the starting point and
      // now
      NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:start];
      [_bandwidth appendElapsed:elapsed withBytesOfWrite:sent];
      self.outboundBandwidthInKbps = _bandwidth.outboundKBps;
      // NSLog(@"Elapsed %f seconds for %d bytes (%f kbps)", elapsed, sent, bandwidth_.outboundKBps);
    }
    return sent;
  }
}

- (void)clearBuffer {
   @synchronized (_flvBuffer) {
     for (id b in _flvBuffer) {
       if (!b || ![b isKindOfClass:[NSDictionary class]]) {
         continue;
       }
       WriteCompleteHandler handler = [b objectForKey:@"completion"];
       if (handler) {
         handler = nil;
         // [handler release];
       }
     }
     [_flvBuffer removeAllObjects];
   }
}

- (BOOL)isConnected {
  @synchronized (self) {
    connected_ = NO;
    if (_rtmp) {
      connected_ = RTMP_IsConnected(_rtmp);
    }
    return connected_;
  }
}

- (void)close {
  @synchronized (self) {
    if (_rtmp) {
      // Close rtmp connection
      RTMP_Close(_rtmp);
      
      // Release rtmp context
      RTMP_Free(_rtmp);
      _rtmp = nil;
    }
  }
}

- (BOOL)reconnect {
  return [self openWithURL:self.rtmpUrl enableWrite:self.writeEnable];
}

#pragma mark -
#pragma mark Setters and Getters Methods

- (id)popFirstBuffer {
  @synchronized (self.flvBuffer) {
    id obj = nil;
    if (_flvBuffer.count > 0) {
      obj = _flvBuffer.firstObject;
      if (obj) {
        bufferSize -= [[obj objectForKey:@"length"] integerValue];
        // [obj retain];
        [_flvBuffer removeObject:obj];
      }
    }
    // return [obj autorelease];
    return obj;
  }
}

- (void)pushBuffer:(id)obj {
  @synchronized (_flvBuffer) {
    if (obj) {
      bufferSize += [[obj objectForKey:@"length"] integerValue];
      [self.flvBuffer addObject:obj];
    }
  }
}

- (BOOL)writeQueueInUse {
  @synchronized (_lock) {
    return _writeQueueInUse;
  }
}

- (void)setWriteQueueInUse:(BOOL)inUse {
  @synchronized (_lock) {
    _writeQueueInUse = inUse;
  }
}

@end

