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

const NSUInteger kMaxBufferSizeInKbyte = 500; // kb

@interface RtmpWrapper () {
  RTMP *rtmp_;
  BOOL connected_;
}

@property (nonatomic, retain) NSString *rtmpUrl;
@property (nonatomic, assign) BOOL writeEnable;
@property (nonatomic, retain) NSMutableArray *flvBuffer;
@property (nonatomic, assign) NSInteger bufferSize;

@end

@implementation RtmpWrapper

@synthesize connected = connected_;
@synthesize autoReconnect;
@synthesize rtmpUrl;
@synthesize writeEnable;
@synthesize flvBuffer;
@synthesize maxBufferSizeInKbyte;
@synthesize bufferSize;

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
    autoReconnect = NO;
    flvBuffer = [[NSMutableArray alloc] init];
    maxBufferSizeInKbyte = kMaxBufferSizeInKbyte;
    bufferSize = 0;
    
    signal(SIGPIPE, SIG_IGN);
    
    // Allocate rtmp context object
    rtmp_ = RTMP_Alloc();
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
  if (flvBuffer) {
    [flvBuffer release];
  }
  // Release rtmp context
  RTMP_Free(rtmp_);
  
  [super dealloc];
}

- (void)setLogInfo {
  RTMP_LogSetLevel(RTMP_LOGINFO);
}

- (BOOL)isConnected {
  if (rtmp_) {
    connected_ = RTMP_IsConnected(rtmp_);
  }
  return connected_;
}

- (BOOL)rtmpOpenWithURL:(NSString *)url enableWrite:(BOOL)enableWrite {  
  RTMP_Init(rtmp_);
  if (!RTMP_SetupURL(rtmp_,
                     (char *)[url cStringUsingEncoding:NSASCIIStringEncoding])) {
    return NO;
  }
  
  self.rtmpUrl = url;
  self.writeEnable = enableWrite;
  
  if (enableWrite) {
    RTMP_EnableWrite(rtmp_);
  }

  if (!RTMP_Connect(rtmp_, NULL) || !RTMP_ConnectStream(rtmp_, 0)) {
    return NO;
  }
  
  connected_ = RTMP_IsConnected(rtmp_);
  return YES;
}

- (void)rtmpClose {
  if (rtmp_) {
    RTMP_Close(rtmp_);
  }
}

- (BOOL)reconnect {
  if (!RTMP_IsConnected(rtmp_)) {
    if (!RTMP_Connect(rtmp_, NULL)) {
      return NO;
    }
  }
  return RTMP_ReconnectStream(rtmp_, 0);
}

+ (NSError *)errorRTMPFailedWithReason:(NSString *)errorReason
                               andCode:(RTMPErrorCode)errorCode {
  NSMutableDictionary *userinfo = [[NSMutableDictionary alloc] init];
  userinfo[NSLocalizedDescriptionKey] = errorReason;
  
  // create error object
  NSError *err = [NSError errorWithDomain:@"com.ifactory.lab.rtmp.wrapper"
                                     code:errorCode
                                 userInfo:userinfo];
  [userinfo release];
  return err;
}

// Resize data buffer for the given data. If the buffer size is bigger than
// max size, remove first input and return error to the completion handler.
- (void)resizeBuffer:(NSData *)data {
  while (bufferSize + data.length > maxBufferSizeInKbyte * 1024) {
    NSDictionary *b = [flvBuffer objectAtIndex:0];
    bufferSize -= [[b objectForKey:@"length"] integerValue];
    WriteCompleteHandler handler = [b objectForKey:@"completion"];
   
    NSError *error =
      [RtmpWrapper errorRTMPFailedWithReason:@"RTMP buffer is full because "
                                              "either frequent send failing or"
                                              "some reason."
                                     andCode:RTMPErrorBufferFull];
    handler(error);
    [flvBuffer removeObjectAtIndex:0];
  }
}

- (void)appendData:(NSData *)data
    withCompletion:(WriteCompleteHandler)completion {
  // Resize buffer for the given data.
  [self resizeBuffer:data];
  
  NSMutableDictionary *b = [[NSMutableDictionary alloc] init];
  [b setObject:@"data" forKey:data];
  [b setObject:@"length" forKey:[NSString stringWithFormat:@"%d", data.length]];
  [b setObject:@"completion" forKey:completion];
  
  bufferSize += data.length;
  bufferSize -= [[b objectForKey:@"length"] integerValue];

  [flvBuffer addObject:b];
  [b release];
}

- (void)rtmpWrite:(NSData *)data
   withCompletion:(WriteCompleteHandler)completion {
  [self appendData:data withCompletion:completion];
}

- (NSUInteger)rtmpWrite:(NSData *)data {
  int sent = RTMP_Write(rtmp_, [data bytes], [data length]);
  if (sent <= 0) {
    // If the RTMP_Write fails, check if the connection is still established.
    if (!self.connected && self.autoReconnect) {
      // If the connection has dropped and autoReconnect set to true, try to
      // reconnect current rtmp to the server
      [self rtmpClose];
      if (![self reconnect]) {
        // Failed to reconnect..
      } else {
        sent = RTMP_Write(rtmp_, [data bytes], [data length]);
      }
    }
  }
  return sent;
}

@end

