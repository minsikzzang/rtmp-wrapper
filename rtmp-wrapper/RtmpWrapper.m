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

@interface RtmpWrapper () {
  RTMP *rtmp_;
  BOOL connected_;
}

@end

@implementation RtmpWrapper

@synthesize connected = connected_;
@synthesize autoReconnect;

static void rtmpLog(int level, const char *fmt, va_list args) {
  /*
  switch (level) {
    default:
    case RTMP_LOGCRIT:    level = AV_LOG_FATAL;   break;
    case RTMP_LOGERROR:   level = AV_LOG_ERROR;   break;
    case RTMP_LOGWARNING: level = AV_LOG_WARNING; break;
    case RTMP_LOGINFO:    level = AV_LOG_INFO;    break;
    case RTMP_LOGDEBUG:   level = AV_LOG_VERBOSE; break;
    case RTMP_LOGDEBUG2:  level = AV_LOG_DEBUG;   break;
  }
  
  av_vlog(NULL, level, fmt, args);
  av_log(NULL, level, "\n");
   */
  NSLog([NSString stringWithUTF8String:fmt], args);
}

- (id)init {
  self = [super init];
  if (self != nil) {
    // Allocate rtmp context object
    rtmp_ = RTMP_Alloc();
    connected_ = NO;
    autoReconnect = NO;
    RTMP_LogSetLevel(RTMP_LOGALL);
  }
  return self;
}

- (void)dealloc {
  if (self.connected) {
    [self rtmpClose];
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
  RTMP_LogCallback(rtmpLog);
  RTMP_Init(rtmp_);
  if (!RTMP_SetupURL(rtmp_,
                     (char *)[url cStringUsingEncoding:NSASCIIStringEncoding])) {
    return NO;
  }
  
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
  if (self.connected) {
    RTMP_Close(rtmp_);
  }
}

- (NSUInteger)rtmpWrite:(NSData *)data {
  int sent = RTMP_Write(rtmp_, [data bytes], [data length]);
  if (sent <= 0) {
    // If the RTMP_Write fails, check if the connection is still established.
    if (!self.connected && self.autoReconnect) {
      // If the connection has dropped and autoReconnect set to true, try to
      // reconnect current rtmp to the server
      if (!RTMP_Connect(rtmp_, NULL) || !RTMP_ConnectStream(rtmp_, 0)) {
        // Failed to reconnect..
      } else {
        sent = RTMP_Write(rtmp_, [data bytes], [data length]);
      }
    }
  }
  return sent;
}

@end

