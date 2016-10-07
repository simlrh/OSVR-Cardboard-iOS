//
//  OSVRManager.m
//  Moonlight
//
//  Created by Stephen Le Roy Harris on 29/09/2016.
//  Copyright © 2016 Moonlight Stream. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMotion/CMMotionManager.h>
#import "OSVRManager.h"
#import "iOSDeviceSizes.h"
#import "SDiOSVersion.h"

@implementation OSVRManager {
    StreamConfiguration* _config;
    id<ConnectionCallbacks> _callbacks;
    NSInputStream *inputStream;
    NSOutputStream *outputStream;
    BOOL hasSpaceAvailable;
    CMMotionManager *motionManager;
    NSOperationQueue *opQueue;
    BOOL hasSentConfig;
    NSTimer *syncTimer;
    BOOL sendTimeSync;
    NSMutableData *outputBuffer;
    NSTimeInterval offset;
}

- (id) initWithConfig:(StreamConfiguration*)config connectionCallbacks:(id<ConnectionCallbacks>)callbacks {
    self = [super init];
    _config = config;
    _callbacks = callbacks;
    hasSentConfig = NO;
    sendTimeSync = YES;
    outputBuffer = [[NSMutableData alloc] init];
    offset = 0;
    return self;
}

- (CMQuaternion) multiplyQuaternion:(CMQuaternion)left with:(CMQuaternion)right {
    
    CMQuaternion newQ;
    newQ.w = left.w*right.w - left.x*right.x - left.y*right.y - left.z*right.z;
    newQ.x = left.w*right.x + left.x*right.w + left.y*right.z - left.z*right.y;
    newQ.y = left.w*right.y + left.y*right.w + left.z*right.x - left.x*right.z;
    newQ.z = left.w*right.z + left.z*right.w + left.x*right.y - left.y*right.x;
    
    return newQ;
}

- (void) sendOrientation:(CMDeviceMotion *)motion {
    if ([outputStream streamStatus] == NSStreamStatusNotOpen) return;
    
    if (offset == 0) {
        NSLog(@"%@", @"Setting offset");
        offset = CACurrentMediaTime() - motion.timestamp;
    }
    
    if (!hasSentConfig) {
        NSString *deviceName = [[UIDevice currentDevice] name];
        NSString *viewerParams = [[NSUserDefaults standardUserDefaults] objectForKey:@"viewerParams"];
        
        DeviceVersion deviceVersion =[SDiOSVersion deviceVersion];
        CGFloat deviceWidth = DeviceWidths[deviceVersion];
        CGFloat screenWidth = ScreenWidths[deviceVersion];
        CGFloat screenHeight = ScreenHeights[deviceVersion];
        /*
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        int screenHorizontal = screenRect.size.width;
        int screenVertical = screenRect.size.height;
         */
        
        // Send portrait resolution of stream
        int screenHorizontal = _config.height;
        int screenVertical = _config.width;
        
        NSString *configFormat = @"{\"protocolVersion\":\"%@\",\"deviceName\":\"%@\",\"viewerParams\":\"%@\",\"deviceWidth\":%f,\"screenWidth\":%f,\"screenHeight\":%f,\"screenHorizontal\":%d,\"screenVertical\":%d}\n";

        NSString *config = [NSString stringWithFormat:configFormat, kOSVRProtocolVersion, deviceName, viewerParams, deviceWidth, screenWidth, screenHeight, screenHorizontal, screenVertical];
        
        [outputBuffer appendBytes:[config UTF8String] length:[config length]];
        hasSentConfig = YES;
    }
    
    NSTimeInterval timestamp;
    long long seconds;
    long microseconds;
    
    if (sendTimeSync == YES) {
        timestamp = CACurrentMediaTime();
        seconds = (long long)timestamp;
        microseconds = (long)(fmod(timestamp, 1) * 1000000);
        
        NSString *timesyncFormat = @"{\"s\":%lld,\"m\":%ld}\n";
        NSString *timesyncReport = [NSString stringWithFormat:timesyncFormat, seconds, microseconds];
    
        [outputBuffer appendBytes:[timesyncReport UTF8String] length:[timesyncReport length]];
        sendTimeSync = NO;
    }
    
    timestamp = motion.timestamp + offset;
    seconds = (long long)timestamp;
    microseconds = (long)(fmod(timestamp, 1) * 1000000);
    
    CMQuaternion quaternion = [motion.attitude quaternion];
    CMQuaternion osvrQuaternion;
    osvrQuaternion.x = quaternion.y;
    osvrQuaternion.y = -quaternion.z;
    osvrQuaternion.z = quaternion.x;
    osvrQuaternion.w = -quaternion.w;
    
    CMQuaternion rotation;
    rotation.x = -sin(M_PI_2);
    rotation.y = 0;
    rotation.z = 0;
    rotation.w = -cos(M_PI_2) + sin(M_PI_2);
    
    osvrQuaternion = [self multiplyQuaternion:osvrQuaternion with:rotation];
    
    NSString *reportFormat = @"{\"x\":%f,\"y\":%f,\"z\":%f,\"w\":%f,\"s\":%lld,\"m\":%ld}\n";
    NSString *report = [NSString stringWithFormat:reportFormat, osvrQuaternion.x, osvrQuaternion.y, osvrQuaternion.z, osvrQuaternion.w, seconds, microseconds];

    [outputBuffer appendBytes:[report UTF8String] length:[report length]];
    
    [self sendOutput];
}

- (void) updateTimesync:(uint8_t *)buffer maxLength:(NSInteger)length
{
    NSTimeInterval currentTime = CACurrentMediaTime();

    long long seconds;
    long microseconds;
    long long serverSeconds;
    long serverMicroseconds;
    
    if (4 == sscanf((char *)buffer, "{\"s\":%lld,\"m\":%ld,\"ss\":%lld,\"sm\":%ld}\n",
                    &seconds, &microseconds, &serverSeconds, &serverMicroseconds)) {
        NSTimeInterval sentTime = seconds + (microseconds / 1000000);
        NSTimeInterval latency = (currentTime - sentTime) / 2;
        
        NSLog(@"Latency: %lfs\n", latency);
        
        NSTimeInterval serverTime = serverSeconds + (serverMicroseconds / 1000000);
        offset = (serverTime - currentTime) + latency;        
    }
}

- (void) sendOutput {
    if ([outputBuffer length] && [outputStream hasSpaceAvailable]) {
        NSInteger written = [outputStream write:[outputBuffer bytes] maxLength:[outputBuffer length]];
        if (written <= 0) {
        }
        else if (written < [outputBuffer length]) {
            [outputBuffer setData:[outputBuffer subdataWithRange:NSMakeRange(written, [outputBuffer length] - written)]];
        } else {
            [outputBuffer setLength:0];
        }
    }
}

- (void) main {
    NSThread *thread = [[NSThread alloc] initWithBlock:^{
        CFReadStreamRef readStream;
        CFWriteStreamRef writeStream;
        CFStringRef host = (__bridge CFStringRef) _config.host;
        CFStreamCreatePairWithSocketToHost(NULL, host, kOSVRPort, &readStream, &writeStream);
        
        outputStream = (__bridge_transfer NSOutputStream *)writeStream;
        inputStream = (__bridge_transfer NSInputStream *)readStream;
        
        [inputStream setDelegate:self];
        [outputStream setDelegate:self];
        [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [inputStream open];
        [outputStream open];
        
        opQueue = [[NSOperationQueue alloc] init];
        motionManager = [[CMMotionManager alloc] init];
        
        motionManager.deviceMotionUpdateInterval = 1.0 / kOSVRReportsPerSecond;
        [motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryCorrectedZVertical toQueue:opQueue withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
            [self sendOrientation:motion];
        }];
        
        syncTimer = [NSTimer scheduledTimerWithTimeInterval:kOSVRTimeSyncInterval repeats:YES block:^(NSTimer * _Nonnull timer) {
            sendTimeSync = YES;
        }];
        
        [[NSRunLoop currentRunLoop] run];
    }];
    
    [thread setThreadPriority:1.0];
    [thread start];
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
    switch(eventCode) {
        case NSStreamEventHasSpaceAvailable:
        {
            break;
        }
        case NSStreamEventHasBytesAvailable:
        {
            uint8_t buffer[1024];
            NSInteger len = 0;
            len = [(NSInputStream *)stream read:buffer maxLength:1024];
            if (len) {
                [self updateTimesync:buffer maxLength:len];
            }
            break;
        }
        case NSStreamEventErrorOccurred:
        case NSStreamEventEndEncountered:
        {
            [stream close];
            [stream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            stream = nil;
            
            if (stream == outputStream) {
                [motionManager stopDeviceMotionUpdates];
                [_callbacks connectionTerminated:0];
            }
            break;
        }

    }
}

- (void) stopStream {
    [motionManager stopDeviceMotionUpdates];
    [syncTimer invalidate];

    [inputStream close];
    [outputStream close];
    [inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    inputStream = nil;
    outputStream = nil;
}

@end;
