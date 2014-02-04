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
@property(nonatomic, weak) IBOutlet UIButton *convert, *play;
@property(nonatomic, strong) NSMutableArray *savedImageArray;
@property(nonatomic, strong) NSOperationQueue *imageWritingQueue;
@property(nonatomic, strong) AVAssetWriter *videoWriter;
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

-(NSOperationQueue*)imageWritingQueue{
    
    if(!_imageWritingQueue){
        _imageWritingQueue = [[NSOperationQueue alloc]init];
        [_imageWritingQueue addObserver:self forKeyPath:@"operations" options:0 context:NULL];
    }
    return _imageWritingQueue;
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                         change:(NSDictionary *)change context:(void *)context
{
    if (object == self.imageWritingQueue && [keyPath isEqualToString:@"operations"]) {
        if ([self.imageWritingQueue.operations count] == 0) {
            // Do something here when your queue has completed
            NSLog(@"Image Wrirting queue has completed");
            NSLog(@"Convert button has been dislayed");
            [self.convert setHidden:NO];
            [self.imageWritingQueue removeObserver:self forKeyPath:@"operations" context:nil];
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object
                               change:change context:context];
    }
}

-(NSMutableArray*)savedImageArray{
    if(!_savedImageArray)
        _savedImageArray = [[NSMutableArray alloc]init];
    return _savedImageArray;
}

-(AVAsset*)getVideoAsset{
    
    NSURL *url      = [[NSBundle mainBundle] URLForResource:@"sample_iPod" withExtension:@"m4v"];
    AVAsset *asset  = [AVAsset assetWithURL:url];
    return asset;
}

-(void)playVideo{
    
    NSString *documentsDirectory = [NSHomeDirectory()
                                    stringByAppendingPathComponent:@"Documents"];
    NSString *videoOutputPath = [documentsDirectory stringByAppendingPathComponent:@"test_output.mov"];
    NSURL *url = [NSURL fileURLWithPath:videoOutputPath];
  
    if (![[NSFileManager defaultManager] fileExistsAtPath:videoOutputPath]) {
        NSLog(@"Video doesn't exist at path %@", videoOutputPath);
        return;
    }
    
    if(self.videoWriter.status != AVAssetWriterStatusCompleted){
        NSLog(@"Not Yet completed %i", self.videoWriter.status);
//      return;
    }
    NSLog(@"Video writer status %i", self.videoWriter.status);

    MPMoviePlayerViewController *mpVC = [[MPMoviePlayerViewController alloc]initWithContentURL:url];
    mpVC.moviePlayer.movieSourceType = MPMovieSourceTypeFile;
    [mpVC.moviePlayer play];
    
    [self presentViewController:mpVC animated:YES completion:^{
        NSLog(@"MPMoview player has presented %@", url);
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
    for (int i = 0; i < totalFrames/6; i++) {

        NSValue *time = [NSValue valueWithCMTime:CMTimeMakeWithSeconds(i*frameDuration, videoComposition.frameDuration.timescale)];
        [times addObject:time];
    }
    
    // Launching the process...
    imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
    imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
    imageGenerator.maximumSize = renderSize;
    imageGenerator.appliesPreferredTrackTransform=TRUE;

        __block unsigned int i = 0;
        AVAssetImageGeneratorCompletionHandler handler = ^(CMTime requestedTime, CGImageRef im, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error){
            i++;
            CGImageRetain(im);
            if(result == AVAssetImageGeneratorSucceeded){
                
                //Create a weak self
//                UIImage *image = [UIImage imageWithCGImage:im];
                    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
                    
                    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex: 0];
                    NSError *error = nil;
                    
                    NSString *videoOutputPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"VideoFrames%i.png", i]];
                    
                    UIImage *image = [UIImage imageWithCGImage:im];
                    if(![UIImagePNGRepresentation(image) writeToFile:videoOutputPath options:NSDataWritingFileProtectionNone error:&error])
                        NSLog(@"Failed to save image at path %@", videoOutputPath);
                    else
                        [self.savedImageArray addObject:[NSString stringWithFormat:@"VideoFrames%i.png", i]];
//                        NSLog(@"%ith Image has been written successfully at %@", i, videoOutputPath);
//                    
                    CGImageRelease(im);
                    
                }];
                [self.imageWritingQueue addOperation:operation];
            }else if (result == AVAssetImageGeneratorFailed){
                NSLog(@"Failed:     Image %d is failed to generate", i);
                NSLog(@"Error: %@", [error localizedDescription]);
            }else if (result == AVAssetImageGeneratorCancelled){
                NSLog(@"Cancelled:  Image %d is cancelled to generate", i);
                NSLog(@"Error: %@", [error localizedDescription]);
            }
         };

        [imageGenerator generateCGImagesAsynchronouslyForTimes:times completionHandler:handler];
}

//-(void)generateImages{
//    
//    //Create image Image Generator
//    AVAsset *asset = [self getVideoAsset];
//    AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
////    AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc]initWithAsset:asset];
//    
//    //Create an array to store all time values at which the images to be captured from the video
//    NSMutableArray *times = [NSMutableArray arrayWithCapacity:3];
//    
//    for (int i = 1; i <= 3; i++) {
//        NSValue *value = [NSValue valueWithCMTime:CMTimeMake(i, 1)];
//        [times addObject:value];
//    }
//
//    __block int i = 0;
//    AVAssetImageGeneratorCompletionHandler handler = ^(CMTime requestedTime, CGImageRef im, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error){
//        
//        i++;
//        if(result == AVAssetImageGeneratorSucceeded){
//            NSLog(@"Success:    Image %d is generated", i);
//        }else if (result == AVAssetImageGeneratorFailed){
//            NSLog(@"Failed:     Image %d is failed to generate", i);
//            NSLog(@"Error: %@ code %d", [error localizedDescription], error.code);
//            
//        }else if (result ==  AVAssetImageGeneratorCancelled){
//            NSLog(@"Cancelled:  Image %d is cancelled to generate", i);
//            NSLog(@"Error: %@", [error localizedDescription]);
//        }
//    };
//    
//    // Launching the process...
//    imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
//    imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
//    imageGenerator.appliesPreferredTrackTransform=TRUE;
//    
//    [imageGenerator generateCGImagesAsynchronouslyForTimes:times completionHandler:handler];
//}

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

-(IBAction)playGeneratedVideo:(id)sender{
    [self playVideo];
}


-(IBAction) convertToVideo
{
    NSLog(@"Touch up inside called");
    NSString *documentsDirectory = [NSHomeDirectory()
                                    stringByAppendingPathComponent:@"Documents"];
    NSString *videoOutputPath = [documentsDirectory stringByAppendingPathComponent:@"test_output.mov"];

    NSLog(@"-->videoOutputPath= %@", videoOutputPath);
    
    // get rid of existing mp4 if exists...
    NSError *error = nil;
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    
    if ([fileMgr fileExistsAtPath:videoOutputPath]){
        if([fileMgr removeItemAtPath:videoOutputPath error:&error] != YES)
            NSLog(@"Unable to delete file: %@", [error localizedDescription]);
    }
//    [self writeImageAsMovie:self.savedImageArray toPath:videoOutputPath size:self.view.frame.size duration:30];

    [self writeImagesAsMovie:self.savedImageArray toPath:videoOutputPath];
}


//Here i'm passing the imageArray and savedVideoPath to the function below
/*
-(void)writeImageAsMovie:(NSArray *)array toPath:(NSString*)path size:(CGSize)size duration:(int)duration
{
    
    NSError *error = nil;
    
    if(!_videoWriter){
        _videoWriter = [[AVAssetWriter alloc] initWithURL:
                        [NSURL fileURLWithPath:path] fileType:AVFileTypeQuickTimeMovie
                                                    error:&error];
    }
    
    NSParameterAssert(_videoWriter);
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:size.width], AVVideoWidthKey,
                                   [NSNumber numberWithInt:size.height], AVVideoHeightKey,
                                   nil];
    AVAssetWriterInput* writerInput = [AVAssetWriterInput
                                        assetWriterInputWithMediaType:AVMediaTypeVideo
                                        outputSettings:videoSettings];
    
    writerInput.expectsMediaDataInRealTime = YES;
    // NSDictionary *bufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];
    
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor
                                                     assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput
                                                     sourcePixelBufferAttributes:nil];
    
    
    NSParameterAssert(writerInput);
    NSParameterAssert([_videoWriter canAddInput:writerInput]);
    [_videoWriter addInput:writerInput];
    
    
    //Start a session:
    [_videoWriter startWriting];
    [_videoWriter startSessionAtSourceTime:kCMTimeZero];
    
    CVPixelBufferRef buffer = NULL;
    
    //convert uiimage to CGImage.
    for (int i = 1; i <= 50; i++) {
        
        NSFileManager *fileMgr = [NSFileManager defaultManager];
        NSString *documentsDirectory = [NSHomeDirectory()
                                        stringByAppendingPathComponent:@"Documents"];
        
        NSString *videoOutputPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"VideoFrames%i.png", i]];
        
        //Skip if image doesn't exists in the specified path
        if(![fileMgr fileExistsAtPath:videoOutputPath]){
            NSLog(@"The image to be written is doesn't exist at path %@", videoOutputPath);
            
        }else{
            UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfFile:videoOutputPath]];
            
            buffer = [self pixelBufferFromCGImage:[image CGImage]];
            if (!buffer) {
                NSLog(@"Buffer is null");
            }
            if(![adaptor appendPixelBuffer:buffer withPresentationTime:kCMTimeZero]){
                NSLog(@"Adaptor failed to append the buffer");
                return;
            }
            else{
                NSLog(@"Adaptor is append the buffer %i succsessfully", i);
//                [NSThread sleepForTimeInterval:0.05];
            }
            CVBufferRelease(buffer);
            if (i == 50)
                NSLog(@"%ith frame has been added to the video", i);
            
            if(i%5 == 0)
                NSLog(@"%ith Frame has been written", i);
        }
    }
    
    //Write samples:

    //Finish the session:
    [writerInput markAsFinished];
    [_videoWriter finishWritingWithCompletionHandler:^{
        NSLog(@"Writing has been finished successfully");
    }];
}
*/

-(void)viewDidAppear:(BOOL)animated{

    [super viewDidAppear:YES];
//    [self generateImages];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.

    //Hide convert button initially
    [self.convert setHidden:YES];
    [self generateListOfImage];

}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
-(void)saveTheImageArrayInBundle:(UIImage*)image tag:(unsigned int)tag{

    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSString *documentsDirectory = [NSHomeDirectory()
                                    stringByAppendingPathComponent:@"Documents"];
    NSError *error = nil;
   
   NSString *videoOutputPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"VideoFrames%i.png", tag]];

    if(tag == 1)
        NSLog(@"Path %@", videoOutputPath);
    
    if ([fileMgr removeItemAtPath:videoOutputPath error:&error] != YES)
       NSLog(@"Unable to delete file: %@", [error localizedDescription]);
    if(![UIImagePNGRepresentation(image) writeToFile:videoOutputPath atomically:YES])
       NSLog(@"Failed to save image at path %@", videoOutputPath);
}

*/

- (void) writeImagesAsMovie:(NSArray *)newArray toPath:(NSString*)path {

    NSString *documents = [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex: 0];
    NSLog(@"Documents %@", documents);
    
    NSLog(@"NewArray[0] %@", [newArray objectAtIndex:0]);
    NSString *filename = [documents stringByAppendingPathComponent:[newArray objectAtIndex:0]];
    NSLog(@"File name: %@", filename);
    
    UIImage *first = [UIImage imageWithContentsOfFile:filename];
    
    if(!first){
        NSLog(@"Image doesn't exist at %@", filename);
        return;
    }

    CGSize frameSize = first.size;
    
    NSError *error = nil;
    self.videoWriter = [[AVAssetWriter alloc] initWithURL:
                                  [NSURL fileURLWithPath:path] fileType:AVFileTypeMPEG4
                                                              error:&error];
    
    if(error) {
        NSLog(@"error creating AssetWriter: %@",[error description]);
    }
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:frameSize.width], AVVideoWidthKey,
                                   [NSNumber numberWithInt:frameSize.height], AVVideoHeightKey,
                                   nil];
    
    AVAssetWriterInput* writerInput = [AVAssetWriterInput
                                        assetWriterInputWithMediaType:AVMediaTypeVideo
                                        outputSettings:videoSettings];
    
    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
    [attributes setObject:[NSNumber numberWithUnsignedInt:kCVPixelFormatType_32ARGB] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
    [attributes setObject:[NSNumber numberWithUnsignedInt:frameSize.width] forKey:(NSString*)kCVPixelBufferWidthKey];
    [attributes setObject:[NSNumber numberWithUnsignedInt:frameSize.height] forKey:(NSString*)kCVPixelBufferHeightKey];
    
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor
                                                     assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput
                                                     sourcePixelBufferAttributes:attributes];
    
    [self.videoWriter addInput:writerInput];
    
    // fixes all errors
    writerInput.expectsMediaDataInRealTime = YES;
    
    //Start a session:
    BOOL start = [self.videoWriter startWriting];
    NSLog(@"Session started? %d", start);
    [self.videoWriter startSessionAtSourceTime:kCMTimeZero];
    
    
    CVPixelBufferRef buffer = NULL;
    buffer = [self pixelBufferFromCGImage:[first CGImage]];
    if(!buffer){
        NSLog(@"Buffer is NULL");
        return;
    }
    BOOL result = [adaptor appendPixelBuffer:buffer withPresentationTime:kCMTimeZero];
    
    if (result == NO) //failes on 3GS, but works on iphone 4
        NSLog(@"failed to append buffer");
    
    if(buffer)
        CVBufferRelease(buffer);
    
    [NSThread sleepForTimeInterval:0.05];
    
    int fps = 5;
    
    int i = 0;
    for (NSString *filename in newArray)
    {
        if (adaptor.assetWriterInput.readyForMoreMediaData)
        {
            
            i++;
            NSLog(@"inside for loop %d %@ ",i, filename);
            CMTime frameTime = CMTimeMake(1, fps);
            CMTime lastTime=CMTimeMake(i, fps);
            CMTime presentTime=CMTimeAdd(lastTime, frameTime);
            
            NSString *filePath = [documents stringByAppendingPathComponent:filename];
            
            UIImage *imgFrame = [UIImage imageWithContentsOfFile:filePath] ;
            buffer = [self pixelBufferFromCGImage:[imgFrame CGImage]];
            
            if(!buffer){
                NSLog(@"Buffer is NULL");
                return;
            }
            
            BOOL result = [adaptor appendPixelBuffer:buffer withPresentationTime:presentTime];
            
            if (result == NO) //failes on 3GS, but works on iphone 4
            {
                NSLog(@"failed to append buffer");
                NSLog(@"The error is %@", [self.videoWriter error]);
            }
            if(buffer)
                CVBufferRelease(buffer);
            [NSThread sleepForTimeInterval:0.05];
        }
        else
        {
            NSLog(@"error");
            i--;
        }
        [NSThread sleepForTimeInterval:0.02];
    }
    
    //Finish the session:
    [writerInput markAsFinished];
    [self.videoWriter finishWritingWithCompletionHandler:^{
        NSLog(@"Video writting has been done");
        [self playVideo];
    }];
    CVPixelBufferPoolRelease(adaptor.pixelBufferPool);
}

- (CVPixelBufferRef) pixelBufferFromCGImage: (CGImageRef) image
{
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    CVPixelBufferRef pxbuffer = NULL;
    
    CVPixelBufferCreate(kCFAllocatorDefault, CGImageGetWidth(image),
                        CGImageGetHeight(image), kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options,
                        &pxbuffer);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, CGImageGetWidth(image),
                                                 CGImageGetHeight(image), 8, 4*CGImageGetWidth(image), rgbColorSpace,
                                                 (CGBitmapInfo)kCGImageAlphaNoneSkipFirst);
    
    CGContextConcatCTM(context, CGAffineTransformMakeRotation(0));
    
//    CGAffineTransform flipVertical = CGAffineTransformMake(
//                                                           1, 0, 0, -1, 0, CGImageGetHeight(image)
//                                                           );
//    CGContextConcatCTM(context, flipVertical);
//    
//    CGAffineTransform flipHorizontal = CGAffineTransformMake(
//                                                             -1.0, 0.0, 0.0, 1.0, CGImageGetWidth(image), 0.0
//                                                             );
//    
//    CGContextConcatCTM(context, flipHorizontal);
    
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),
                                           CGImageGetHeight(image)), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}




/*


-(void)convertimagetoVideo
{
    ///////////// setup OR function def if we move this to a separate function ////////////
    // this should be moved to its own function, that can take an imageArray, videoOutputPath, etc...
    
    
    NSError *error = nil;
    // set up file manager, and file videoOutputPath, remove "test_output.mp4" if it exists...
    //NSString *videoOutputPath = @"/Users/someuser/Desktop/test_output.mp4";
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSString *documentsDirectory = [NSHomeDirectory()
                                    stringByAppendingPathComponent:@"Documents"];
    NSString *videoOutputPath = [documentsDirectory stringByAppendingPathComponent:@"test_output.mp4"];
    //NSLog(@"-->videoOutputPath= %@", videoOutputPath);
    // get rid of existing mp4 if exists...
    if ([fileMgr removeItemAtPath:videoOutputPath error:&error] != YES)
        NSLog(@"Unable to delete file: %@", [error localizedDescription]);
    
    
    CGSize imageSize = CGSizeMake(400, 200);
    //    NSUInteger fps = 30;
    NSUInteger fps = 30;
    
    //NSMutableArray *imageArray;
    //imageArray = [[NSMutableArray alloc] initWithObjects:@"download.jpeg", @"download2.jpeg", nil];
    NSMutableArray *imageArray;
    NSArray* imagePaths = [[NSBundle mainBundle] pathsForResourcesOfType:@"png" inDirectory:nil];
    imageArray = [[NSMutableArray alloc] initWithCapacity:imagePaths.count];
    NSLog(@"-->imageArray.count= %i", imageArray.count);
    for (NSString* path in imagePaths)
    {
        [imageArray addObject:[UIImage imageWithContentsOfFile:path]];
        //NSLog(@"-->image path= %@", path);
    }
    
    //////////////     end setup    ///////////////////////////////////
    
    NSLog(@"Start building video from defined frames.");
    
    AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:
                                  [NSURL fileURLWithPath:videoOutputPath] fileType:AVFileTypeQuickTimeMovie
                                                              error:&error];
    NSParameterAssert(videoWriter);
    
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:imageSize.width], AVVideoWidthKey,
                                   [NSNumber numberWithInt:imageSize.height], AVVideoHeightKey,
                                   nil];
    
    AVAssetWriterInput* videoWriterInput = [AVAssetWriterInput
                                            assetWriterInputWithMediaType:AVMediaTypeVideo
                                            outputSettings:videoSettings];
    
    
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor
                                                     assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoWriterInput
                                                     sourcePixelBufferAttributes:nil];
    
    NSParameterAssert(videoWriterInput);
    NSParameterAssert([videoWriter canAddInput:videoWriterInput]);
    videoWriterInput.expectsMediaDataInRealTime = YES;
    [videoWriter addInput:videoWriterInput];
    
    //Start a session:
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
    
    CVPixelBufferRef buffer = NULL;
    
    //convert uiimage to CGImage.
    int frameCount = 0;
    double numberOfSecondsPerFrame = 6;
    double frameDuration = fps * numberOfSecondsPerFrame;
    
    //for(VideoFrame * frm in imageArray)
    NSLog(@"**************************************************");
    for(UIImage * img in imageArray)
    {
        //UIImage * img = frm._imageFrame;
        buffer = [self pixelBufferFromCGImage:[img CGImage]];
        
        BOOL append_ok = NO;
        int j = 0;
        while (!append_ok && j < 30) {
            if (adaptor.assetWriterInput.readyForMoreMediaData)  {
                //print out status:
                NSLog(@"Processing video frame (%d,%d)",frameCount,[imageArray count]);
                
                //CMTime frameTime = CMTimeMake((int64_t), (int32_t)2);
                
                CMTime frameTime = CMTimeMake(frameCount*frameDuration,(int32_t) fps);
                NSLog(@"seconds = %f, %u, %d", CMTimeGetSeconds(frameTime),fps,j);
                append_ok = [adaptor appendPixelBuffer:buffer withPresentationTime:frameTime];
                if(!append_ok){
                    NSError *error = videoWriter.error;
                    if(error!=nil) {
                        NSLog(@"Unresolved error %@,%@.", error, [error userInfo]);
                    }
                }
            }
            else {
                printf("adaptor not ready %d, %d\n", frameCount, j);
                [NSThread sleepForTimeInterval:0.1];
            }
            j++;
        }
        if (!append_ok) {
            printf("error appending image %d times %d\n, with error.", frameCount, j);
        }
        frameCount++;
    }
    NSLog(@"**************************************************");
    
    //Finish the session:
    [videoWriterInput markAsFinished];
    [videoWriter finishWriting];
    NSLog(@"Write Ended");
    
}


-(void)CompileFilestomakeVideo
{
    
    // set up file manager, and file videoOutputPath, remove "test_output.mp4" if it exists...
    //NSString *videoOutputPath = @"/Users/someuser/Desktop/test_output.mp4";
    NSString *documentsDirectory = [NSHomeDirectory()
                                    stringByAppendingPathComponent:@"Documents"];
    NSString *videoOutputPath = [documentsDirectory stringByAppendingPathComponent:@"test_output.mp4"];
    //NSLog(@"-->videoOutputPath= %@", videoOutputPath);
    // get rid of existing mp4 if exists...
    
    AVMutableComposition* mixComposition = [AVMutableComposition composition];
    
    NSString *bundleDirectory = [[NSBundle mainBundle] bundlePath];
    // audio input file...
    NSString *audio_inputFilePath = [bundleDirectory stringByAppendingPathComponent:@"30secs.mp3"];
    NSURL    *audio_inputFileUrl = [NSURL fileURLWithPath:audio_inputFilePath];
    
    // this is the video file that was just written above, full path to file is in --> videoOutputPath
    NSURL    *video_inputFileUrl = [NSURL fileURLWithPath:videoOutputPath];
    
    // create the final video output file as MOV file - may need to be MP4, but this works so far...
    NSString *outputFilePath = [documentsDirectory stringByAppendingPathComponent:@"final_video.mp4"];
    NSURL    *outputFileUrl = [NSURL fileURLWithPath:outputFilePath];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:outputFilePath])
        [[NSFileManager defaultManager] removeItemAtPath:outputFilePath error:nil];
    
    CMTime nextClipStartTime = kCMTimeZero;
    
    AVURLAsset* videoAsset = [[AVURLAsset alloc]initWithURL:video_inputFileUrl options:nil];
    CMTimeRange video_timeRange = CMTimeRangeMake(kCMTimeZero,videoAsset.duration);
    AVMutableCompositionTrack *a_compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    [a_compositionVideoTrack insertTimeRange:video_timeRange ofTrack:[[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:nextClipStartTime error:nil];
    
    //nextClipStartTime = CMTimeAdd(nextClipStartTime, a_timeRange.duration);
    
    AVURLAsset* audioAsset = [[AVURLAsset alloc]initWithURL:audio_inputFileUrl options:nil];
    CMTimeRange audio_timeRange = CMTimeRangeMake(kCMTimeZero, audioAsset.duration);
    AVMutableCompositionTrack *b_compositionAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    [b_compositionAudioTrack insertTimeRange:audio_timeRange ofTrack:[[audioAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0] atTime:nextClipStartTime error:nil];
    
    
    
    AVAssetExportSession* _assetExport = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];
    _assetExport.outputFileType = @"com.apple.quicktime-movie";
    //_assetExport.outputFileType = @"public.mpeg-4";
    //NSLog(@"support file types= %@", [_assetExport supportedFileTypes]);
    _assetExport.outputURL = outputFileUrl;
    
    [_assetExport exportAsynchronouslyWithCompletionHandler:
     ^(void ) {
         [self saveVideoToAlbum:outputFilePath];
     }
     ];
    
    ///// THAT IS IT DONE... the final video file will be written here...
    NSLog(@"DONE.....outputFilePath--->%@", outputFilePath);
    
    // the final video file will be located somewhere like here:
    // /Users/caferrara/Library/Application Support/iPhone Simulator/6.0/Applications/D4B12FEE-E09C-4B12-B772-7F1BD6011BE1/Documents/outputFile.mov
    
    
    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////
}
- (void) saveVideoToAlbum:(NSString*)path {
    
    NSLog(@"saveVideoToAlbum");
    
    if(UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(path)){
        UISaveVideoAtPathToSavedPhotosAlbum (path, self, @selector(video:didFinishSavingWithError: contextInfo:), nil);
    }
}

-(void) video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    if(error)
        NSLog(@"error: %@", error);
    else
        NSLog(@" OK");
}



////////////////////////
- (CVPixelBufferRef) pixelBufferFromCGImage: (CGImageRef) image {
    
    CGSize size = CGSizeMake(400, 200);
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    CVPixelBufferRef pxbuffer = NULL;
    
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                          size.width,
                                          size.height,
                                          kCVPixelFormatType_32ARGB,
                                          (__bridge CFDictionaryRef) options,
                                          &pxbuffer);
    if (status != kCVReturnSuccess){
        NSLog(@"Failed to create pixel buffer");
    }
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, size.width,
                                                 size.height, 8, 4*size.width, rgbColorSpace,
                                                 kCGImageAlphaPremultipliedFirst);
    //kCGImageAlphaNoneSkipFirst);
    CGContextConcatCTM(context, CGAffineTransformMakeRotation(0));
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),
                                           CGImageGetHeight(image)), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}
 
 */

@end
