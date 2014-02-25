//
//  IFBandwidthCalculator.h
//  rtmp-wrapper
//
//  Created by Min Kim on 2/25/14.
//  Copyright (c) 2014 iFactory Lab Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface IFBandwidthCalculator : NSObject

@property (nonatomic, assign) double outboundBps;
@property (nonatomic, assign) double outboundKBps;
@property (nonatomic, assign) double outboundMBps;

@property (nonatomic, assign) double durationForBandwidthCalculation;

- (void)appendElapsed:(NSTimeInterval)elapsed withBytesOfWrite:(NSUInteger)bytes;

@end
