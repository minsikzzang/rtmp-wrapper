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

// NSString const* kRtmpEP = @"{put your rtmp publishing entry point}";
NSString const* kRtmpEP = @"rtmp://fso.ams.BBBF.edgecastcdn.net/20BBBF/default/bunny?6CtBJ5J3FMvWC44r&adbe-live-event=test-ugc";
NSString const* kSourceFLV = @"http://bcn01.livestation.com/test.flv";
NSString const* kSourceMP4 = @"http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4";

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
  [rtmp setLogInfo];
  
  BOOL ret = [rtmp rtmpOpenWithURL:(NSString *)kRtmpEP enableWrite:YES];
  XCTAssertTrue(ret);
  if (ret) {    
    NSData *video =
      [NSData dataWithContentsOfURL:[NSURL URLWithString:(NSString *)kSourceFLV]];
      // [NSData dataWithContentsOfURL:[NSURL URLWithString:(NSString *)kSourceMP4]];
    NSLog(@"original video length: %d", [video length]);
    NSUInteger videoLength = [video length];
    
    NSUInteger length = [video length];
    NSUInteger chunkSize = 100 * 5120;
    NSUInteger offset = 0;
    do {
      NSUInteger thisChunkSize = length - offset > chunkSize ? chunkSize : length - offset;
      NSData* chunk = [NSData dataWithBytesNoCopy:(char *)[video bytes] + offset
                                           length:thisChunkSize
                                     freeWhenDone:NO];
      offset += thisChunkSize;
      
      // Write new chunk to rtmp server
      NSLog(@"%d", [rtmp rtmpWrite:chunk]);
      sleep(0.2);
    } while (offset < length);
 
    XCTAssertEqual([rtmp rtmpWrite:video], videoLength);
  }
  
  [rtmp rtmpClose];
  [rtmp release];
}

- (void)testIsRTMPConnected {
  RtmpWrapper *rtmp = [[RtmpWrapper alloc] init];
  [rtmp setLogInfo];
  
  BOOL ret = [rtmp rtmpOpenWithURL:(NSString *)kRtmpEP enableWrite:YES];
  XCTAssertTrue(ret);
  XCTAssertTrue(rtmp.connected);
  [rtmp rtmpClose];
  XCTAssertFalse(rtmp.connected);
  
  [rtmp release];
}

- (void)testSendToBrokenConnection {
  RtmpWrapper *rtmp = [[RtmpWrapper alloc] init];
  [rtmp setLogInfo];
  
  BOOL ret = [rtmp rtmpOpenWithURL:(NSString *)kRtmpEP enableWrite:YES];
  XCTAssertTrue(ret);
  if (ret) {
    NSData *video =
    [NSData dataWithContentsOfURL:[NSURL URLWithString:(NSString *)kSourceFLV]];
    // [NSData dataWithContentsOfURL:[NSURL URLWithString:(NSString *)kSourceMP4]];
    NSLog(@"original video length: %d", [video length]);
    
    NSUInteger length = [video length];
    NSUInteger chunkSize = 100 * 5120;
    NSUInteger offset = 0;
    do {
      NSUInteger thisChunkSize = length - offset > chunkSize ? chunkSize : length - offset;
      NSData* chunk = [NSData dataWithBytesNoCopy:(char *)[video bytes] + offset
                                           length:thisChunkSize
                                     freeWhenDone:NO];
      offset += thisChunkSize;
      
      // Before sending, close the connection
      [rtmp rtmpClose];
      
      // Write new chunk to rtmp server
      int res = [rtmp rtmpWrite:chunk];
      XCTAssertEqual(res, -1);
      break;
    } while (offset < length);
  }
  
  [rtmp release];
}

- (void)testAutoReconnect {
  RtmpWrapper *rtmp = [[RtmpWrapper alloc] init];
  rtmp.autoReconnect = YES;
  
  [rtmp setLogInfo];
  
  BOOL ret = [rtmp rtmpOpenWithURL:(NSString *)kRtmpEP enableWrite:YES];
  XCTAssertTrue(ret);
  if (ret) {
    NSData *video =
    [NSData dataWithContentsOfURL:[NSURL URLWithString:(NSString *)kSourceFLV]];
    // [NSData dataWithContentsOfURL:[NSURL URLWithString:(NSString *)kSourceMP4]];
    NSLog(@"original video length: %d", [video length]);
    
    NSUInteger length = [video length];
    NSUInteger chunkSize = 100 * 5120;
    NSUInteger offset = 0;
    do {
      NSUInteger thisChunkSize = length - offset > chunkSize ? chunkSize : length - offset;
      NSData* chunk = [NSData dataWithBytesNoCopy:(char *)[video bytes] + offset
                                           length:thisChunkSize
                                     freeWhenDone:NO];
      offset += thisChunkSize;
      
      // Before sending, close the connection
      [rtmp rtmpClose];
      
      // Write new chunk to rtmp server
      NSUInteger res = [rtmp rtmpWrite:chunk];
      XCTAssertEqual(res, chunk.length);
      XCTAssertTrue(rtmp.connected);      
      break;
    } while (offset < length);
  }
  
  [rtmp release];

}

@end
