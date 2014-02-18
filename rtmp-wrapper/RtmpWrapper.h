//
//  RtmpWrapper.h
//  RtmpWrapper
//
//  Created by Min Kim on 9/30/13.
//  Copyright (c) 2013 iFactory Lab Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^WriteCompleteHandler)(NSError *error);
typedef void (^OpenCompleteHandler)(NSError *error);

typedef enum RTMPErrorCode {
  RTMPErrorBufferFull = 0,
  RTMPErrorURLOpenFail,
  RTMPErrorOpenTimeout,
  RTMPErrorWriteFail,
  RTMPErrorWriteTimeout
} RTMPErrorCode;

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
- (BOOL)rtmpOpenWithURL:(NSString *)url enableWrite:(BOOL)enableWrite;

- (void)rtmpClose;

- (NSUInteger)rtmpWrite:(NSData *)data;

+ (NSError *)errorRTMPFailedWithReason:(NSString *)errorReason
                               andCode:(RTMPErrorCode)errorCode;

- (void)rtmpOpenWithURL:(NSString *)url
            enableWrite:(BOOL)enableWrite
         withCompletion:(OpenCompleteHandler)handler;
/**
 @abstract
  Asynchronous rtmp write function
 
 @param data
 @param completion
 */
- (void)rtmpWrite:(NSData *)data
   withCompletion:(WriteCompleteHandler)completion;

- (void)appendData:(NSData *)data
    withCompletion:(WriteCompleteHandler)completion;

- (void)setLogInfo;

- (BOOL)reconnect;

@property (nonatomic, assign, getter = isConnected) BOOL connected;
@property (nonatomic, assign) NSUInteger maxBufferSizeInKbyte;

@end
