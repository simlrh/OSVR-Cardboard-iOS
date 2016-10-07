//
//  QRCodeViewController.m
//  Moonlight
//
//  Created by Stephen Le Roy Harris on 01/10/2016.
//  Copyright © 2016 Moonlight Stream. All rights reserved.
//

#import "QRCodeViewController.h"

@interface QRCodeViewController ()

@end

@implementation QRCodeViewController {
    AVCaptureSession *_captureSession;
    AVCaptureVideoPreviewLayer *_videoPreviewLayer;
}

- (BOOL) startReading {
    NSError *error;
    
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    if (!input) {
        return NO;
    }
    
    _captureSession = [[AVCaptureSession alloc] init];
    [_captureSession addInput:input];
    
    AVCaptureMetadataOutput *captureMetadataOutput =  [[AVCaptureMetadataOutput alloc] init];
    [_captureSession addOutput:captureMetadataOutput];
    
    dispatch_queue_t dispatchQueue;
    dispatchQueue = dispatch_queue_create("qrQueue", NULL);
    [captureMetadataOutput setMetadataObjectsDelegate:self queue:dispatchQueue];
    [captureMetadataOutput setMetadataObjectTypes:[NSArray arrayWithObject:AVMetadataObjectTypeQRCode]];
    
    _videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    _videoPreviewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
    [_videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [_videoPreviewLayer setFrame:self.videoView.layer.bounds];
    _videoPreviewLayer.sublayerTransform = CATransform3DMakeRotation(M_PI_2, 0, 0, 1);
    [self.videoView.layer addSublayer:_videoPreviewLayer];
    
    [_captureSession startRunning];
    
    return YES;
}

- (void)stopReading {
    [_captureSession stopRunning];
    _captureSession = nil;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)redirectResponse newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler {
    
    NSURL *url = [NSURL URLWithString:[[redirectResponse allHeaderFields] valueForKey:@"Location"]];
    NSString *viewerParams = [[url query] stringByReplacingOccurrencesOfString:@"p=" withString:@""];
    
    [[NSUserDefaults standardUserDefaults] setObject:viewerParams forKey:@"viewerParams"];
    completionHandler(nil);
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    if (metadataObjects != nil && [metadataObjects count] > 0 ) {
        AVMetadataMachineReadableCodeObject *metadataObject = [metadataObjects objectAtIndex:0];
        if ([[metadataObject type] isEqualToString:AVMetadataObjectTypeQRCode]) {
            [self stopReading];
            
            NSString *fullAddress = [metadataObject stringValue];
            if (![fullAddress containsString:@"http://"]
                && ![fullAddress containsString:@"https://"]) {
                fullAddress = [@"https://" stringByAppendingString: fullAddress];
            }
            NSURL *url = [NSURL URLWithString:fullAddress];
            
            NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
            NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[[NSOperationQueue alloc] init]];
                
            NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
            request.HTTPMethod = @"HEAD";
                
            NSURLSessionDataTask *downloadTask = [session dataTaskWithRequest:request];
                
            [downloadTask resume];
            
            UIAlertController* alertController = [UIAlertController
                                                  alertControllerWithTitle: @"Viewer Detected"
                                                  message:@"Your Cardboard viewer has been configured"
                                                  preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                [self performSegueWithIdentifier:@"finishedScanning" sender:self];
            }]];
            
            [self presentViewController:alertController animated:YES completion:nil];


        }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self startReading];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    _captureSession = nil;
}


@end
