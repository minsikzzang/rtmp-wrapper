//
//  IFTimeoutBlock.m
//  rtmp-wrapper
//
//  Created by Min Kim on 2/18/14.
//  Copyright (c) 2014 iFactory Lab Limited. All rights reserved.
//

#import "IFTimeoutBlock.h"

@interface IFTimeoutBlock() {
  int signalsRemaining_;
  int expectedSignalCount_;
}

- (void)reset;

@property (nonatomic, copy) IFExecutionBlock executionBlock;
@property (nonatomic, copy) IFTimeoutHandler timeoutBlock;

@end

@implementation IFTimeoutBlock

@synthesize timedOut;
@synthesize executionBlock;
@synthesize timeoutBlock;

- (id)init {
  return [self initWithExpectedSignalCount:1];
}

- (id)initWithExpectedSignalCount:(NSInteger)expectedSignalCount {
  if (self = [super init]) {
    expectedSignalCount_ = expectedSignalCount;
    [self reset];
  }
  return self;
}

- (void)dealloc {
  if (executionBlock) {
    [executionBlock release];
    executionBlock = nil;
  }
  if (timeoutBlock) {
    [timeoutBlock release];
    timeoutBlock = nil;
  }
  [super dealloc];
}
- (void)waitWithTimeout:(NSUInteger)timeout
        periodicHandler:(IFTimeoutPeriodicHandler)handler {
  NSDate *start = [NSDate date];
  
  // loop until the previous call completes
  while (signalsRemaining_ > 0) {
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.1]];
    if (timeout > 0 &&
        [[NSDate date] timeIntervalSinceDate:start] > timeout) {
      [self reset];
    
      // We only return when it's timed-out.
      if (handler) {
        handler(self);
      }
    }    
  };
  [self reset];
}

- (void)signal {
  @synchronized (self) {
    --signalsRemaining_;
  }  
}

- (void)reset {
  signalsRemaining_ = expectedSignalCount_;
}

- (void)setExecuteAsyncWithTimeout:(int)timeout
                       WithHandler:(IFTimeoutHandler)handler
                 andExecutionBlock:(IFExecutionBlock)execution {
  self.executionBlock = execution;
  self.timeoutBlock = handler;
  
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,(unsigned long)NULL), ^(void) {
    [self waitWithTimeout:timeout periodicHandler:^(IFTimeoutBlock *block) {
      timedOut = YES;
      if (self.timeoutBlock) {
        self.timeoutBlock();  
      }
      
    }];
  });
  
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,(unsigned long)NULL), ^(void) {
    if (self.executionBlock) {
      self.executionBlock();
    }
  });
}

@end
