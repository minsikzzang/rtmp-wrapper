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
  BOOL headerSent_;
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
  }
  return self;
}

- (void)dealloc {
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
  
  headerSent_ = NO;
  return YES;
}

- (void)rtmpClose {
  if (rtmp_) {
    RTMP_Close(rtmp_);
    rtmp_ = 0;
  }
}

- (NSUInteger)rtmpWrite:(NSData *)data {
  
  /*
  int bufSize = [data length];
  const char *buf = [data bytes];
   */
/*
  if (buf[0] == 'F' && buf[1] == 'L' && buf[2] == 'V') {
    NSLog(@"FLV HEADER\n%@", [[NSData dataWithBytes:buf length:13] hexString]);
    buf += 13;
    bufSize -= 13;
  }
*/
  /*
  while (bufSize > 0) {
    if (buf[0] == 'F' && buf[1] == 'L' && buf[2] == 'V') {
      NSLog(@"FLV HEADER\n%@", [[NSData dataWithBytes:buf length:13] hexString]);
      if (!headerSent_) {
        headerSent_ = YES;
      } else {
        NSLog(@"NO GOOD");
      }
      buf += 13;
      bufSize -= 13;
    }

    char packetType = *buf++;
    int bodySize = AMF_DecodeInt24(buf);
    buf += 3;
    int timeStamp = AMF_DecodeInt24(buf);
    buf += 3;
    timeStamp |= *buf++ << 24;
    
    NSLog(@"TagHeader\n%@", [[NSData dataWithBytes:buf - 8 length:11] hexString]);
    bufSize -= 11;
    NSLog(@"TagBody\n%@", [[NSData dataWithBytes:(buf) length:bodySize] hexString]);
    bufSize -= bodySize;
    buf += bodySize;
    NSLog(@"TagTail\n%@", [[NSData dataWithBytes:(buf) length:4] hexString]);
    bufSize -= 4;
    buf += 4;
  }
  return 0;
*/
  // return RTMP_Write(rtmp_, buf, bufSize);
   
  return RTMP_Write(rtmp_, [data bytes], [data length]);
}

@end

