//
//  RtmpWrapper.m
//  RtmpWrapper
//
//  Created by Min Kim on 9/30/13.
//  Copyright (c) 2013 iFactory Lab Limited. All rights reserved.
//

#import "RtmpWrapper.h"
#import "NSData+Hex.h"

#import <librtmp/rtmp.h>
#import <librtmp/log.h>

@interface RtmpWrapper () {
  RTMP *rtmp_;
  BOOL rtmpOpen_;
}

@end

@implementation RtmpWrapper

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
  NSLog(fmt, args);
}

- (id)init {
  self = [super init];
  if (self != nil) {
    // Allocate rtmp context object
    rtmp_ = RTMP_Alloc();
    rtmpOpen_ = NO;
  }
  return self;
}

- (void)dealloc {
  if (rtmpOpen_) {
    [self rtmpClose];
  }
  // Release rtmp context
  RTMP_Free(rtmp_);
  
  [super dealloc];
}

- (BOOL)rtmpOpenWithURL:(NSString *)url enableWrite:(BOOL)enableWrite {
  RTMP_LogSetLevel(RTMP_LOGALL);
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
  rtmpOpen_ = YES;
  return YES;
}

- (void)rtmpClose {
  if (rtmpOpen_) {
    RTMP_Close(rtmp_);
    rtmpOpen_ = NO;
  }
}

- (NSUInteger)rtmpWrite:(NSData *)data {
  return RTMP_Write(rtmp_, [data bytes], [data length]);
}

@end

