//
//  VideoEditingModel.m
//  VideoEditing
//
//  Created by aram on 2/6/14.
//  Copyright (c) 2014 aram. All rights reserved.
//

#import "VideoEditingModel.h"
#import <AVFoundation/AVAsset.h>
#import <AVFoundation/AVFoundation.h>


@interface VideoEditingModel()
@property(nonatomic, strong) NSOperationQueue *imageWritingQueue;
@property(nonatomic, strong) NSMutableArray *savedImagePathArray;
@property(nonatomic, copy) ImageExtractionHandler imageExtractionCompletionHandler;
@property(nonatomic, strong) NSError *imageCreationError;
@property(nonatomic, assign) BOOL isAllOperationEnqueued;
@end

@implementation VideoEditingModel

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
            NSLog(@"Image Wrirting queue has completed. Image completed %d", self.savedImagePathArray.count);
            [self.imageWritingQueue removeObserver:self forKeyPath:@"operations" context:nil];
//            self.imageExtractionCompletionHandler(YES, 100, self.savedImagePathArray, nil);
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object
                               change:change context:context];
    }
}

-(AVAsset*)getAssetAtFilePath:(NSURL*)filePathUrl{
    
    AVAsset *asset  = [AVAsset assetWithURL:filePathUrl];
    return asset;
}

-(NSMutableArray*)savedImagePathArray{
    
    if(!_savedImagePathArray)
        _savedImagePathArray = [[NSMutableArray alloc]init];
    return _savedImagePathArray;
}

-(BOOL)isValidPath:(NSString*)filePath{
    return YES;
}

-(NSString*)getDocumentDirectory{
    
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex: 0];
    return documentsDirectory;
}

-(int)percentageNumerator:(int)num denominator:(int)deno{
    return (num/deno)*100;
}

-(BOOL)generateFramesFromVideoAtPath:(NSURL*)videoPathUrl pathToSaveTheImages:(NSString*)imagePath completionHandler:(ImageExtractionHandler)completionHandler {
    
    //Copy the completion handler
    self.imageExtractionCompletionHandler = [completionHandler copy];
    
    //Check the source and destination file path is correct one
    if([[NSFileManager defaultManager] fileExistsAtPath:videoPathUrl.absoluteString]){
        NSLog(@"The given source (VIDEO) file path is INVALID");
        return NO;
    }

    //Retrive asset from specified path
    AVAsset *asset = [self getAssetAtFilePath:videoPathUrl];
    if(!asset){
        NSLog(@"Returned asset is nill");
        return NO;
    }
    
    //Create AVVideoComposition
    AVVideoComposition *videoComposition = [AVVideoComposition videoCompositionWithPropertiesOfAsset:asset];
    
    //Retrive video's properties
    NSTimeInterval duration         = CMTimeGetSeconds(asset.duration);
    NSTimeInterval frameDuration    = CMTimeGetSeconds(videoComposition.frameDuration);
    CGSize renderSize = videoComposition.renderSize;
    CGFloat totalFrames = round(duration/frameDuration);

    //Create an array to store all time values at which the images captured from the video
    NSMutableArray *times = [NSMutableArray arrayWithCapacity:totalFrames];
    NSLog(@"Total Number of frames %d", (int)totalFrames);
    for (int i = 0; i < totalFrames/6; i++) {
        
        NSValue *time = [NSValue valueWithCMTime:CMTimeMakeWithSeconds(i*frameDuration, videoComposition.frameDuration.timescale)];
        [times addObject:time];
    }
    
    // Launching the process...
    AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc]initWithAsset:asset];
    imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
    imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
    imageGenerator.maximumSize = renderSize;
    imageGenerator.appliesPreferredTrackTransform=TRUE;

    //Handler for asynchronous image creation
    __block unsigned int i = 0;
    AVAssetImageGeneratorCompletionHandler handler = ^(CMTime requestedTime, CGImageRef im, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error){
        
        self.imageCreationError = error;
        i++;
        CGImageRetain(im);
        if(result == AVAssetImageGeneratorSucceeded){
            
            NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
                
                NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex: 0];
                NSError *error = nil;
                
                NSString *videoOutputPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"VideoFrames%i.png", i]];
                
                UIImage *image = [UIImage imageWithCGImage:im];
                if(![UIImagePNGRepresentation(image) writeToFile:videoOutputPath options:NSDataWritingFileProtectionNone error:&error]){
                    NSLog(@"Failed to save image at path %@", videoOutputPath);
                }
                else{
                    [self.savedImagePathArray addObject:[NSString stringWithFormat:@"VideoFrames%i.png", i]];
                    int percent = (i/(totalFrames/6))*100;
                    self.imageExtractionCompletionHandler(YES, percent, self.savedImagePathArray, self.imageCreationError);
                }
                CGImageRelease(im);
                
            }];
            [self.imageWritingQueue addOperation:operation];
            if(i == totalFrames/6){
                NSLog(@"All Operation has been enqueued");
                self.isAllOperationEnqueued = YES;
            }
        }else if (result == AVAssetImageGeneratorFailed){
            NSLog(@"Failed:     Image %d is failed to generate", i);
            NSLog(@"Error: %@", [error localizedDescription]);
        }else if (result == AVAssetImageGeneratorCancelled){
            NSLog(@"Cancelled:  Image %d is cancelled to generate", i);
            NSLog(@"Error: %@", [error localizedDescription]);
        }
    };
    
    [imageGenerator generateCGImagesAsynchronouslyForTimes:times completionHandler:handler];
    
    return YES;
}

@end
