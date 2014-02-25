//
//  IFBandwidthCalculator.m
//  rtmp-wrapper
//
//  Created by Min Kim on 2/25/14.
//  Copyright (c) 2014 iFactory Lab Limited. All rights reserved.
//

#import "IFBandwidthCalculator.h"

const double kDurationForBandwidthCalculation = 5.0;

@interface IFBandwidthCalculator() {
  double totalElapsedOfWrite_;
  NSUInteger totalBytesOfWrite_;
}

- (double)getBandwidthInBps:(double)elapsed bytes:(NSUInteger)bytes;

@end

@implementation IFBandwidthCalculator

@synthesize durationForBandwidthCalculation;
@synthesize outboundBps;
@synthesize outboundKBps;
@synthesize outboundMBps;

- (id)init {
  self = [super init];
  if (self) {
    totalElapsedOfWrite_ = 0.0;
    totalBytesOfWrite_ = 0;
    durationForBandwidthCalculation = kDurationForBandwidthCalculation;
  }
  return self;
}

- (void)appendElapsed:(NSTimeInterval)elapsed
     withBytesOfWrite:(NSUInteger)bytes {
  totalElapsedOfWrite_ += elapsed;
  totalBytesOfWrite_ += bytes;
  
  self.outboundBps = [self getBandwidthInBps:totalElapsedOfWrite_
                                       bytes:totalBytesOfWrite_];
  self.outboundKBps = self.outboundBps / 1024;
  self.outboundMBps = self.outboundKBps / 1024;
  
  if (totalElapsedOfWrite_ > kDurationForBandwidthCalculation) {
    totalElapsedOfWrite_ = 0;
    totalBytesOfWrite_ = 0;
  }
}

- (double)getBandwidthInBps:(double)elapsed bytes:(NSUInteger)bytes {
  NSUInteger bits = (bytes > 0 ? bytes * 8 : 0);
  return (double)bits / elapsed;
}

@end
