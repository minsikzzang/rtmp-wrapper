//
//  RtmpWrapper.h
//  RtmpWrapper
//
//  Created by Min Kim on 9/30/13.
//  Copyright (c) 2013 iFactory Lab Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^WriteCompleteHandler)(NSUInteger sent, NSError *error);
typedef void (^OpenCompleteHandler)(NSError *error);

typedef enum RTMPErrorCode {
  RTMPErrorBufferFull = 0,
  RTMPErrorURLOpenFail,
  RTMPErrorOpenTimeout,
  RTMPErrorWriteFail,
  RTMPErrorWriteTimeout
} RTMPErrorCode;

typedef enum RTMPWritePriority {
  RTMPWritePriorityLow = 0,
  RTMPWritePriorityNormal,
  RTMPWritePriorityHigh
} RTMPWritePriority;

@interface RtmpWrapper : NSObject

/**
 @abstract
  Open rtmp connection to the given URL.
 
 @param url 
  rtmp://server[:port][/app][/playpath][ keyword=value]...
  where 'app' is first one or two directories in the path
  (e.g. /ondemand/, /flash/live/, etc.)
  and 'playpath' is a file name (the rest of the path,
  may be prefixed with "mp4:")
 
  Additional RTMP library options may be appended as
  space-separated key-value pairs.
 */
- (BOOL)openWithURL:(NSString *)url enableWrite:(BOOL)enableWrite;

/**
 @abstract
  Close current connection / release all the resources
 */
- (void)close;

/**
 @abstract
  Write the given data to open rtmp connection
 
 @param data A buffer to write
 */
- (NSUInteger)write:(NSData *)data;

/**
 @abstract
  Create all required resources for opening RTMP connection to the given URL
 
 @param url
 @param enableWrite If YES, it will be able to write data to the URL
 @param handler Completion handler
 */
- (void)openWithURL:(NSString *)url
        enableWrite:(BOOL)enableWrite
     withCompletion:(OpenCompleteHandler)handler;

/**
 @abstract
  Asynchronous rtmp write function
 
 @param data
 @param completion
 */
- (void)write:(NSData *)data
withCompletion:(WriteCompleteHandler)completion;

/**
 @abstract
  Asynchronous rtmp write function with priority
 
 @param data
 @param priority
 @param completion
 */
- (void)write:(NSData *)data
 withPriority:(RTMPWritePriority)priority
withCompletion:(WriteCompleteHandler)completion;

- (void)appendData:(NSData *)data
    withCompletion:(WriteCompleteHandler)completion;

- (void)setLogInfo;

- (BOOL)reconnect;

- (void)clearBuffer;

+ (NSError *)errorRTMPFailedWithReason:(NSString *)errorReason
                               andCode:(RTMPErrorCode)errorCode;

@property (nonatomic, assign, getter = isConnected) BOOL connected;
@property (nonatomic, assign) NSUInteger maxBufferSizeInKbyte;
@property (nonatomic, assign) NSUInteger openTimeout;
@property (nonatomic, assign) NSUInteger writeTimeout;
@property (nonatomic, assign) double outboundBandwidthInKbps;


@end
