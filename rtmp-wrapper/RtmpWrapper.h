//
//  RtmpWrapper.h
//  RtmpWrapper
//
//  Created by Min Kim on 9/30/13.
//  Copyright (c) 2013 iFactory Lab Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

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

- (int)rtmpWrite:(NSData *)data;

@end
