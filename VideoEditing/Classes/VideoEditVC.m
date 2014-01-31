//
//  VideoEditVC.m
//  VideoEditing
//
//  Created by aram on 1/31/14.
//  Copyright (c) 2014 aram. All rights reserved.
//

#import "VideoEditVC.h"
#import <MediaPlayer/MPMoviePlayerController.h>
#import <MediaPlayer/MPMoviePlayerViewController.h>

@interface VideoEditVC ()
@property(nonatomic, weak) IBOutlet UIImageView *imageView;
@end

@implementation VideoEditVC

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

-(AVAsset*)getVideoAsset{
    
    NSURL *url      = [[NSBundle mainBundle] URLForResource:@"sample_iPod" withExtension:@"m4v"];
    AVAsset *asset  = [AVAsset assetWithURL:url];
    return asset;
}

-(void)playVideo{

    NSURL *url      = [[NSBundle mainBundle] URLForResource:@"sample_iPod" withExtension:@"m4v"];

    MPMoviePlayerViewController *mpVC = [[MPMoviePlayerViewController alloc]initWithContentURL:url];
    [self presentViewController:mpVC animated:YES completion:^{
        NSLog(@"MPMoview player has presented");
    }];
    
}

-(void)generateImageAtSpecifiedTime{

    //Create image Image Generator
    AVAsset *asset = [self getVideoAsset];
    AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    imageGenerator.appliesPreferredTrackTransform = YES;

    //Create AVVideoComposition
    AVVideoComposition *videoComposition = [AVVideoComposition videoCompositionWithPropertiesOfAsset:asset];
    CGSize renderSize = videoComposition.renderSize;
    NSLog(@"Reder size width %f height %f", renderSize.width, renderSize.height);
    
    // Launching the process...
    imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
    imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
    imageGenerator.maximumSize = renderSize;
    
    NSError *err = NULL;
    CMTime time = CMTimeMakeWithSeconds(10, videoComposition.frameDuration.timescale);
    CGImageRef imageRef = [imageGenerator copyCGImageAtTime:time actualTime:NULL error:&err];
    
    if(!imageRef){
        NSLog(@"Returned image ref is null");
        return;
    }
    
    UIImage *image = [[UIImage alloc]initWithCGImage:imageRef];
    
    if(!err){
        if(image){
            NSLog(@"UIImage available");
            [self.imageView setImage:image];
        }else{
            NSLog(@"UIImage not available");
        }
    }else{
        NSLog(@"Failed to generate image");
    }

}

-(void)generateListOfImage{
    
    //Create image Image Generator
    AVAsset *asset = [self getVideoAsset];
//    AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc]initWithAsset:asset];
    
    //Create AVVideoComposition
    AVVideoComposition *videoComposition = [AVVideoComposition videoCompositionWithPropertiesOfAsset:asset];
    
    //Retrive video properties
    NSTimeInterval duration         = CMTimeGetSeconds(asset.duration);
    NSTimeInterval frameDuration    = CMTimeGetSeconds(videoComposition.frameDuration);
    CGSize renderSize = videoComposition.renderSize;
    CGFloat totalFrames = round(duration/frameDuration);
    
    //Create an array to store all time values at which the images to be captured from the video
    NSMutableArray *times = [NSMutableArray arrayWithCapacity:totalFrames];
    NSLog(@"Total Number of frames %d", (int)totalFrames);
    for (int i = 0; i <= totalFrames; i++) {

        NSValue *time = [NSValue valueWithCMTime:CMTimeMakeWithSeconds(i*frameDuration, videoComposition.frameDuration.timescale)];
        [times addObject:time];
    }

    __block int i = 0;
    AVAssetImageGeneratorCompletionHandler handler = ^(CMTime requestedTime, CGImageRef im, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error){

        i++;
        if(result == AVAssetImageGeneratorSucceeded){
            NSLog(@"Success:    Image %d is generated", i);
        }else if (result == AVAssetImageGeneratorFailed){
            NSLog(@"Failed:     Image %d is failed to generate", i);
            NSLog(@"Error: %@", [error localizedDescription]);
        }else if (result == AVAssetImageGeneratorCancelled){
            NSLog(@"Cancelled:  Image %d is cancelled to generate", i);
            NSLog(@"Error: %@", [error localizedDescription]);
        }
    };
    
    // Launching the process...
    imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
    imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
    imageGenerator.maximumSize = renderSize;
    imageGenerator.appliesPreferredTrackTransform=TRUE;

    [imageGenerator generateCGImagesAsynchronouslyForTimes:times completionHandler:handler];
    
}

-(void)generateImages{
    
    //Create image Image Generator
    AVAsset *asset = [self getVideoAsset];
    AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
//    AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc]initWithAsset:asset];
    
    //Create an array to store all time values at which the images to be captured from the video
    NSMutableArray *times = [NSMutableArray arrayWithCapacity:3];
    
    for (int i = 1; i <= 3; i++) {
        NSValue *value = [NSValue valueWithCMTime:CMTimeMake(i, 1)];
        [times addObject:value];
    }

    __block int i = 0;
    AVAssetImageGeneratorCompletionHandler handler = ^(CMTime requestedTime, CGImageRef im, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error){
        
        i++;
        if(result == AVAssetImageGeneratorSucceeded){
            NSLog(@"Success:    Image %d is generated", i);
        }else if (result == AVAssetImageGeneratorFailed){
            NSLog(@"Failed:     Image %d is failed to generate", i);
            NSLog(@"Error: %@ code %d", [error localizedDescription], error.code);
            
        }else if (result ==  AVAssetImageGeneratorCancelled){
            NSLog(@"Cancelled:  Image %d is cancelled to generate", i);
            NSLog(@"Error: %@", [error localizedDescription]);
        }
    };
    
    // Launching the process...
    imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
    imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
    imageGenerator.appliesPreferredTrackTransform=TRUE;
    
    [imageGenerator generateCGImagesAsynchronouslyForTimes:times completionHandler:handler];
}

//the video asset, 2/ the image generator, 3/ the composition, which helps to retrieve video properties.
//AVURLAsset *asset = [[[AVURLAsset alloc] initWithURL:moviePathURL
//                                             options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], AVURLAssetPreferPreciseDurationAndTimingKey, nil]] autorelease];
//AVAssetImageGenerator *generator = [[[AVAssetImageGenerator alloc] initWithAsset:asset] autorelease];
//generator.appliesPreferredTrackTransform = YES; // if I omit this, the frames are rotated 90° (didn't try in landscape)

//AVVideoComposition * composition = [AVVideoComposition videoCompositionWithPropertiesOfAsset:asset];

//// Retrieving the video properties
//NSTimeInterval duration = CMTimeGetSeconds(asset.duration);
//frameDuration = CMTimeGetSeconds(composition.frameDuration);
//CGSize renderSize = composition.renderSize;
//CGFloat totalFrames = round(duration/frameDuration);
//

//// Selecting each frame we want to extract : all of them.
//NSMutableArray * times = [NSMutableArray arrayWithCapacity:round(duration/frameDuration)];
//for (int i=0; i<totalFrames; i++) {
//    NSValue *time = [NSValue valueWithCMTime:CMTimeMakeWithSeconds(i*frameDuration, composition.frameDuration.timescale)];
//    [times addObject:time];
//}
//
//__block int i = 0;
//AVAssetImageGeneratorCompletionHandler handler = ^(CMTime requestedTime, CGImageRef im, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error){
//    if (result == AVAssetImageGeneratorSucceeded) {
//        int x = round(CMTimeGetSeconds(requestedTime)/frameDuration);
//        CGRect destinationStrip = CGRectMake(x, 0, 1, renderSize.height);
//        [self drawImage:im inRect:destinationStrip fromRect:originStrip inContext:context];
//    }
//    else
//        NSLog(@"Ouch: %@", error.description);
//    i++;
//    [self performSelectorOnMainThread:@selector(setProgressValue:) withObject:[NSNumber numberWithFloat:i/totalFrames] waitUntilDone:NO];
//    if(i == totalFrames) {
//        [self performSelectorOnMainThread:@selector(performVideoDidFinish) withObject:nil waitUntilDone:NO];
//    }
//};
//
//// Launching the process...
//generator.requestedTimeToleranceBefore = kCMTimeZero;
//generator.requestedTimeToleranceAfter = kCMTimeZero;
//generator.maximumSize = renderSize;
//[generator generateCGImagesAsynchronouslyForTimes:times completionHandler:handler];

-(void)viewDidAppear:(BOOL)animated{

    [super viewDidAppear:YES];
    [self generateListOfImage];
//    [self generateImages];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
