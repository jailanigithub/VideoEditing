//
//  VideoEditingModel.h
//  VideoEditing
//
//  Created by aram on 2/6/14.
//  Copyright (c) 2014 aram. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^ImageExtractionHandler)(BOOL isSuccess, int percentOfCompletion, NSArray *savedImagesPathArray, NSError *err);

@interface VideoEditingModel : NSObject
-(BOOL)generateFramesFromVideoAtPath:(NSURL*)videoPath pathToSaveTheImages:(NSString*)imagePath completionHandler:(ImageExtractionHandler)completionHandler;
@end
