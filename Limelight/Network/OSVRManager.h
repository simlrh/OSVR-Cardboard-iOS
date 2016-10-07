//
//  NSOperation_OSVRManager.h
//  Moonlight
//
//  Created by Stephen Le Roy Harris on 29/09/2016.
//  Copyright © 2016 Moonlight Stream. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMotion/CMMotionManager.h>
#import "StreamConfiguration.h"
#import "Connection.h"

#define kOSVRPort 5555
#define kOSVRProtocolVersion @"0.1"
#define kOSVRReportsPerSecond 100.0
#define kOSVRTimeSyncInterval 2.0

@interface OSVRManager : NSOperation <NSStreamDelegate>

- (id) initWithConfig:(StreamConfiguration*)config connectionCallbacks:(id<ConnectionCallbacks>)callback;
- (void) sendOrientation:(CMDeviceMotion *)motion;
- (void) stopStream;

@end
