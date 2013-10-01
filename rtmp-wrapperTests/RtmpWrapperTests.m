//
//  RtmpWrapperTests.m
//  RtmpWrapperTests
//
//  Created by Min Kim on 9/30/13.
//  Copyright (c) 2013 iFactory Lab Limited. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "RtmpWrapper.h"

@interface RtmpWrapperTests : XCTestCase

@end

NSString const* kRtmpEP = @"rtmp://media18.lsops.net/live/test";

@implementation RtmpWrapperTests

- (void)setUp {
  [super setUp];
  // Put setup code here. This method is called before the invocation of each
  // test method in the class.
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of
  // each test method in the class.
  [super tearDown];
}

- (void)testOpenURL {
  RtmpWrapper *rtmp = [[RtmpWrapper alloc] init];
  BOOL ret = [rtmp rtmpOpenWithURL:(NSString *)kRtmpEP enableWrite:YES];
  XCTAssertTrue(ret);
  [rtmp rtmpClose];
  [rtmp release];
}

- (void)testPublishStream {
  RtmpWrapper *rtmp = [[RtmpWrapper alloc] init];
  BOOL ret = [rtmp rtmpOpenWithURL:(NSString *)kRtmpEP enableWrite:YES];
  XCTAssertTrue(ret);
  if (ret) {    
    NSData *video =
      [NSData dataWithContentsOfURL:
        [NSURL URLWithString:@"http://bcn01.livestation.com/test.flv"]];
    NSLog(@"original video length: %d", [video length]);
    NSUInteger videoLength = [video length];
    
    /*
    NSUInteger length = [video length];
    NSUInteger chunkSize = 100 * 1024;
    NSUInteger offset = 0;
    do {
      NSUInteger thisChunkSize = length - offset > chunkSize ? chunkSize : length - offset;
      NSData* chunk = [NSData dataWithBytesNoCopy:(char *)[video bytes] + offset
                                           length:thisChunkSize
                                     freeWhenDone:NO];
      offset += thisChunkSize;
      
      // Write new chunk to rtmp server
      NSLog(@"%d", [rtmp rtmpWrite:chunk]);
    } while (offset < length);
     */
    XCTAssertEqual([rtmp rtmpWrite:video], videoLength);
  }
  
  [rtmp rtmpClose];
  [rtmp release];
}

@end
