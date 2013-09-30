//
//  RtmpWrapper.m
//  RtmpWrapper
//
//  Created by Min Kim on 9/30/13.
//  Copyright (c) 2013 iFactory Lab Limited. All rights reserved.
//

#import "RtmpWrapper.h"

#import "rtmp.h"

@interface RtmpWrapper () {
  RTMP *rtmpContext_;
}

@end

@implementation RtmpWrapper

- (id)init {
  self = [super init];
  if (self != nil) {
    // Allocate rtmp context object
    rtmpContext_ = RTMP_Alloc();
    RTMP_Init(rtmpContext_);
  }
  return self;
}

- (void)dealloc {
  // Release rtmp context
  RTMP_Free(rtmpContext_);
  
  [super dealloc];
}

- (int)setupURL:(NSString *)url {
  int ret = RTMP_SetupURL(rtmpContext_,
                          (char *)[url cStringUsingEncoding:NSASCIIStringEncoding]);
  return ret;
}

@end

