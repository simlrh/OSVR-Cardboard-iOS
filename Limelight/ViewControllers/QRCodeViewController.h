//
//  QRCodeViewController.h
//  Moonlight
//
//  Created by Stephen Le Roy Harris on 01/10/2016.
//  Copyright © 2016 Moonlight Stream. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface QRCodeViewController : UIViewController <AVCaptureMetadataOutputObjectsDelegate, NSURLSessionDelegate>

@property IBOutlet UIView *videoView;

@end
