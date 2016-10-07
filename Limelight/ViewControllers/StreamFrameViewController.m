//
//  StreamFrameViewController.m
//  Moonlight
//
//  Created by Diego Waxemberg on 1/18/14.
//  Copyright (c) 2015 Moonlight Stream. All rights reserved.
//

#import "StreamFrameViewController.h"
#import "MainFrameViewController.h"
#import "VideoDecoderRenderer.h"
#import "StreamManager.h"
#import "ControllerSupport.h"
#import "OSVRManager.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

@implementation StreamFrameViewController {
    ControllerSupport *_controllerSupport;
    StreamManager *_streamMan;
    OSVRManager *_osvrMan;
    NSOperationQueue *_opQueue;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    
    [self.stageLabel setText:@"Starting App"];
    [self.stageLabel sizeToFit];
    self.stageLabel.center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height / 2);
    self.spinner.center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height / 2 - self.stageLabel.frame.size.height - self.spinner.frame.size.height);
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    _controllerSupport = [[ControllerSupport alloc] init];
    
    _streamMan = [[StreamManager alloc] initWithConfig:self.streamConfig
                                            renderView:self.view
                                   connectionCallbacks:self];
    _opQueue = [[NSOperationQueue alloc] init];
    [_opQueue addOperation:_streamMan];
    
    _osvrMan = [[OSVRManager alloc] initWithConfig:self.streamConfig connectionCallbacks:self];
    [_opQueue addOperation:_osvrMan];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
}

- (void) returnToMainFrame {
    [_controllerSupport cleanup];
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    [_streamMan stopStream];
    [_osvrMan stopStream];
    [self returnToMainFrame];
}

- (void)edgeSwiped {
    Log(LOG_D, @"User swiped to end stream");
    [_streamMan stopStream];
    [_osvrMan stopStream];
    [self returnToMainFrame];
}

- (void) connectionStarted {
    Log(LOG_I, @"Connection started");
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.spinner stopAnimating];
        [self.stageLabel setText:@"Waiting for first frame..."];
        [self.stageLabel sizeToFit];
        [(StreamView*)self.view setupOnScreenControls: _controllerSupport swipeDelegate:self];
    });
}

- (void)connectionTerminated:(long)errorCode {
    Log(LOG_I, @"Connection terminated: %ld", errorCode);
    
    [_streamMan stopStream];
    [_osvrMan stopStream];
    
    if (errorCode) {
        NSLog(@"%@", @"Restarting stream");
        _streamMan = [[StreamManager alloc] initWithConfig:self.streamConfig
                                                renderView:self.view
                                       connectionCallbacks:self];
        _osvrMan = [[OSVRManager alloc] initWithConfig:self.streamConfig connectionCallbacks:self];
        
        [_opQueue addOperation:_streamMan];
        [_opQueue addOperation:_osvrMan];
    } else {
        [self returnToMainFrame];
    }
}

- (void) stageStarting:(const char*)stageName {
    Log(LOG_I, @"Starting %s", stageName);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString* lowerCase = [NSString stringWithFormat:@"%s in progress...", stageName];
        NSString* titleCase = [[[lowerCase substringToIndex:1] uppercaseString] stringByAppendingString:[lowerCase substringFromIndex:1]];
        [self.stageLabel setText:titleCase];
        [self.stageLabel sizeToFit];
        self.stageLabel.center = CGPointMake(self.view.frame.size.width / 2, self.stageLabel.center.y);
    });
}

- (void) stageComplete:(const char*)stageName {
}

- (void) stageFailed:(const char*)stageName withError:(long)errorCode {
    Log(LOG_I, @"Stage %s failed: %ld", stageName, errorCode);
    
    [_streamMan stopStream];
    [_osvrMan stopStream];
    
    [self returnToMainFrame];
}

- (void) launchFailed:(NSString*)message {
    Log(LOG_I, @"Launch failed: %@", message);
    
    [self returnToMainFrame];
}

- (void) displayMessage:(const char*)message {
    Log(LOG_I, @"Display message: %s", message);
}

- (void) displayTransientMessage:(const char*)message {
    Log(LOG_I, @"Display transient message: %s", message);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)shouldAutorotate {
    return NO;
}

@end
