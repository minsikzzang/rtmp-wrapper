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

// NSString *const kRtmpEP = @"{put your rtmp publishing entry point}";
NSString *const kRtmpEP = @"rtmp://fso.ams.BBBF.edgecastcdn.net/20BBBF/default/unit-test?6CtBJ5J3FMvWC44r&adbe-live-event=test-ugc";
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
  BOOL ret = [rtmp rtmpOpenWithURL:kRtmpEP enableWrite:YES];
  XCTAssertTrue(ret);
  [rtmp rtmpClose];
  [rtmp release];
}

- (void)testAsyncOpenUrlSuccess {
  RtmpWrapper *rtmp = [[RtmpWrapper alloc] init];
  dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
  
  [rtmp setLogInfo];
  [rtmp rtmpOpenWithURL:kRtmpEP enableWrite:YES withCompletion:^(NSError *error) {
    XCTAssertNil(error);
    // Signal that block has completed
    dispatch_semaphore_signal(semaphore);    
  }];
  
  while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                             beforeDate:[NSDate dateWithTimeIntervalSinceNow:1]];
  dispatch_release(semaphore);
  
  [rtmp rtmpClose];
  [rtmp release];
}

- (void)testAsyncOpenUrlFail {
  RtmpWrapper *rtmp = [[RtmpWrapper alloc] init];
  dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
  
  [rtmp setLogInfo];
  [rtmp rtmpOpenWithURL:@"rtmp://google.com/test" enableWrite:YES withCompletion:^(NSError *error) {
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, RTMPErrorOpenTimeout);
              
    // Signal that block has completed
    dispatch_semaphore_signal(semaphore);    
  }];
  
  while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                             beforeDate:[NSDate dateWithTimeIntervalSinceNow:1]];
  dispatch_release(semaphore);
  
  [rtmp rtmpClose];
  [rtmp release];
}

- (void)testPublishStream {
  RtmpWrapper *rtmp = [[RtmpWrapper alloc] init];
  [rtmp setLogInfo];
  
  BOOL ret = [rtmp rtmpOpenWithURL:kRtmpEP enableWrite:YES];
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
      [rtmp rtmpWrite:chunk];
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
  
  BOOL ret = [rtmp rtmpOpenWithURL:kRtmpEP enableWrite:YES];
  XCTAssertTrue(ret);
  XCTAssertTrue(rtmp.connected);
  [rtmp rtmpClose];
  XCTAssertFalse(rtmp.connected);
  
  [rtmp release];
}

- (void)testSendToBrokenConnection {
  RtmpWrapper *rtmp = [[RtmpWrapper alloc] init];
  [rtmp setLogInfo];
  
  BOOL ret = [rtmp rtmpOpenWithURL:kRtmpEP enableWrite:YES];
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

- (void)testManualReconnect {
  RtmpWrapper *rtmp = [[RtmpWrapper alloc] init];
  [rtmp setLogInfo];
  
  BOOL ret = [rtmp rtmpOpenWithURL:kRtmpEP enableWrite:YES];
  XCTAssertTrue(ret);
  if (ret) {
    NSData *video =
    [NSData dataWithContentsOfURL:[NSURL URLWithString:(NSString *)kSourceFLV]];
    // [NSData dataWithContentsOfURL:[NSURL URLWithString:(NSString *)kSourceMP4]];
    NSLog(@"original video length: %d", [video length]);
    
    NSUInteger length = [video length];
    NSUInteger chunkSize = 100 * 5120;
    NSUInteger offset = 0;
    int i = 0;
    do {
      NSUInteger thisChunkSize = length - offset > chunkSize ? chunkSize : length - offset;
      NSData* chunk = [NSData dataWithBytesNoCopy:(char *)[video bytes] + offset
                                           length:thisChunkSize
                                     freeWhenDone:NO];
      offset += thisChunkSize;
      
      // Write new chunk to rtmp server
      NSUInteger res = [rtmp rtmpWrite:chunk];
      XCTAssertEqual(res, chunk.length);
      XCTAssertTrue(rtmp.connected);
      
      if (i++ == 0) {
        // After sending, close the connection
        [rtmp rtmpClose];
        [rtmp reconnect];
      } else {
        break;
      }
    } while (offset < length);
  }
  
  [rtmp rtmpClose];
  [rtmp release];
}

- (void)testAsyncWriteSingleData {
  RtmpWrapper *rtmp = [[RtmpWrapper alloc] init];
  [rtmp setLogInfo];
  dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
  
  NSData *video =
    [NSData dataWithContentsOfURL:[NSURL URLWithString:(NSString *)kSourceFLV]];
  NSUInteger thisChunkSize = 1024;
  NSData* chunk = [NSData dataWithBytesNoCopy:(char *)[video bytes]
                                       length:thisChunkSize
                                 freeWhenDone:NO];
  
  [rtmp rtmpOpenWithURL:kRtmpEP enableWrite:YES];
  [rtmp rtmpWrite:chunk withCompletion:^(NSUInteger sent, NSError *error) {
    // Signal that block has completed
    XCTAssertNil(error);
    dispatch_semaphore_signal(semaphore);
  }];

  while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW)) {
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                             beforeDate:[NSDate dateWithTimeIntervalSinceNow:1]];
  }
  
  dispatch_release(semaphore);
  
  [rtmp rtmpClose];
  [rtmp release];
}

- (void)testAsyncWriteBufferOverflow {
  dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
  RtmpWrapper *rtmp = [[RtmpWrapper alloc] init];
  [rtmp setLogInfo];
  rtmp.maxBufferSizeInKbyte = 10;
  
  BOOL ret = [rtmp rtmpOpenWithURL:kRtmpEP enableWrite:YES];
  XCTAssertTrue(ret);
  if (ret) {
    NSData *video =
    [NSData dataWithContentsOfURL:[NSURL URLWithString:(NSString *)kSourceFLV]];
    
    NSUInteger length = [video length];
    NSUInteger chunkSize = 1024 * 5;
    NSUInteger offset = 0;
    int i = 0;
    __block int done = 0;
    
    do {
      NSUInteger thisChunkSize = length - offset > chunkSize ? chunkSize : length - offset;
      NSData* chunk = [NSData dataWithBytesNoCopy:(char *)[video bytes] + offset
                                           length:thisChunkSize
                                     freeWhenDone:NO];
      offset += thisChunkSize;
      [rtmp appendData:chunk withCompletion:^(NSUInteger sent, NSError *error) {
        // Signal that block has completed
        done++;
      }];
      
      if (i++ > 10) {
        break;
      }
    } while (offset < length);
    
    [rtmp rtmpWrite:nil withCompletion:^(NSUInteger sent, NSError *error) {
      
    }];

    while (i != done) {
      sleep(1);
    }
    
    dispatch_semaphore_signal(semaphore);
  }
  
  while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW)) {
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                             beforeDate:[NSDate dateWithTimeIntervalSinceNow:1]];
  }
  
  dispatch_release(semaphore);
  
  [rtmp rtmpClose];
  [rtmp release];
}

- (void)testAsyncWriteMultiData {
  dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
  RtmpWrapper *rtmp = [[RtmpWrapper alloc] init];
  [rtmp setLogInfo];
  
  dispatch_queue_t test_queue =
    dispatch_queue_create("test", DISPATCH_QUEUE_SERIAL);
  BOOL ret = [rtmp rtmpOpenWithURL:kRtmpEP enableWrite:YES];
  XCTAssertTrue(ret);
  if (ret) {
    NSData *video =
      [NSData dataWithContentsOfURL:[NSURL URLWithString:(NSString *)kSourceFLV]];
    // [NSData dataWithContentsOfURL:[NSURL URLWithString:(NSString *)kSourceMP4]];
    NSLog(@"original video length: %d", [video length]);
    
    NSUInteger length = [video length];
    NSUInteger chunkSize = 1024 * 100;
    NSUInteger offset = 0;
    int i = 0;
    __block int done = 0;
    
    do {
      NSUInteger thisChunkSize = length - offset > chunkSize ? chunkSize : length - offset;
      NSData* chunk = [NSData dataWithBytesNoCopy:(char *)[video bytes] + offset
                                           length:thisChunkSize
                                     freeWhenDone:NO];
      offset += thisChunkSize;
      
      dispatch_async(test_queue, ^{
        [rtmp rtmpWrite:chunk withCompletion:^(NSUInteger sent, NSError *error) {
          // Signal that block has completed
          done++;
          NSLog(@"DONE: %d, SENT: %d, ERROR: %@", done, sent, error);
        }];
      });
      
      NSLog(@"TRY: %d", ++i);
      if (i > 9) {
        break;
      }
    } while (offset < length);
    
    while (i != done) {
      if (done > i) {
        break;
      }
      sleep(1);
    }
    
    dispatch_semaphore_signal(semaphore);
  }
  
  while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW)) {
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                             beforeDate:[NSDate dateWithTimeIntervalSinceNow:1]];
  }
  
  dispatch_release(semaphore);
  
  [rtmp rtmpClose];
  [rtmp release];
}

- (void)testClearBuffer {
  dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
  RtmpWrapper *rtmp = [[RtmpWrapper alloc] init];
  [rtmp setLogInfo];
  
  BOOL ret = [rtmp rtmpOpenWithURL:kRtmpEP enableWrite:YES];
  XCTAssertTrue(ret);
  if (ret) {
    NSData *video =
    [NSData dataWithContentsOfURL:[NSURL URLWithString:(NSString *)kSourceFLV]];
    // [NSData dataWithContentsOfURL:[NSURL URLWithString:(NSString *)kSourceMP4]];
    NSLog(@"original video length: %d", [video length]);
    
    NSUInteger length = [video length];
    NSUInteger chunkSize = 1024 * 100;
    NSUInteger offset = 0;
    int i = 0;
    __block int done = 0;
    
    do {
      NSUInteger thisChunkSize = length - offset > chunkSize ? chunkSize : length - offset;
      NSData* chunk = [NSData dataWithBytesNoCopy:(char *)[video bytes] + offset
                                           length:thisChunkSize
                                     freeWhenDone:NO];
      offset += thisChunkSize;
      
      [rtmp appendData:chunk withCompletion:^(NSUInteger sent, NSError *error) {
        // Signal that block has completed
        done++;
      }];
      
      if (i++ > 9) {
        break;
      }
      [rtmp clearRtmpBuffer];
    } while (offset < length);
    
    [rtmp clearRtmpBuffer];
    XCTAssertTrue(done == 0);
    
    dispatch_semaphore_signal(semaphore);
  }
  
  while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW)) {
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                             beforeDate:[NSDate dateWithTimeIntervalSinceNow:1]];
  }
  
  dispatch_release(semaphore);
  
  [rtmp rtmpClose];
  [rtmp release];
}


@end
