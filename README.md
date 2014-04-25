# rtmp-wrapper

rtmp-wrapper is a librtmp wrapper library for iOS platform

## Getting Started

### Install the Prerequisites

* OS X is requried for all iOS development
* [XCODE](https://developer.apple.com/xcode/) from the [App Store](https://itunes.apple.com/us/app/xcode/id497799835?ls=1&mt=12).
* [GIT](http://git-scm.com/download/mac) is required.
* [CocoaPods](http://beta.cocoapods.org/) is required for the iOS dependency management. You should have [ruby](http://www.interworks.com/blogs/ckaukis/2013/03/05/installing-ruby-200-rvm-and-homebrew-mac-os-x-108-mountain-lion) installed on your machine before install CocoaPods

### Install the library

Source code for the SDK is available on [GitHub](git@github.com:ifactorylab/rtmp-wrapper.git)
```
$ git clone git@github.com:ifactorylab/rtmp-wrapper.git
```

### Run CocoaPods

CocoaPods installs all dependencies for the library project
```
$ cd rtmp-wrapper
$ pods install
$ open rtmp-wrapper.xcworkspace
```

### Add rtmp-wrapper to your project

Create a Podfile if not exist, add the line below
```
pod 'rtmp-wrapper',   '~> 1.0.6'
```

### Publishing RTMP stream

```
#import "RtmpWrapper.h"

RtmpWrapper *rtmp = [[RtmpWrapper alloc] init];
BOOL ret = [rtmp rtmpOpenWithURL:@"YOUR RTMP PUBLISHING POINT" enableWrite:YES];
if (ret) {    
  NSData *video =
    [NSData dataWithContentsOfURL:[NSURL URLWithString:@"FLV VIDEO URL ON THE NET"]];
  NSLog(@"original video length: %d", [video length]);
  NSUInteger length = [video length];  
  NSUInteger chunkSize = 10 * 5120;
  NSUInteger offset = 0;
  
  // Let's split video to small chunks to publish to media server
  do {
    NSUInteger thisChunkSize = length - offset > chunkSize ? chunkSize : length - offset;
    NSData* chunk = [NSData dataWithBytesNoCopy:(char *)[video bytes] + offset
                                         length:thisChunkSize
                                   freeWhenDone:NO];
    offset += thisChunkSize;
    
    // Write new chunk to rtmp server
    NSLog(@"%d", [rtmp rtmpWrite:chunk]);
    sleep(1);
  } while (offset < length);
}

// Close rtmp connection and release class object
[rtmp rtmpClose];
[rtmp release];
```

## Version detail

### 1.0.8
- arc enabled

### 1.0.6
- async open / write added
- autoreconnect removed

### 1.0.5
- sigpipe => ignored
- reconnect function added

### 1.0.4
- added connected and autoReconnect