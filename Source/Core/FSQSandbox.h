//
//  FSQSandbox.h
//  FivesquareKit
//
//  Created by John Clayton on 1/29/2011.
//  Copyright 2011 Fivesquare Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface FSQSandbox : NSObject {

}

+ (NSString *) documentsDirectory;
+ (NSString *) applicationSupportDirectory;
+ (NSString *) cachesDirectory;
+ (NSString *) tempDirectory;

+ (BOOL) createDocumentsDirectory;
+ (BOOL) createApplicationSupportDirectory;
+ (BOOL) createCachesDirectory;

/** Return the string representing any directory in the user search domain given its constant, e.g.,  NSCachesDirectory. */
+ (NSString *) directoryInUserSearchPath:(NSSearchPathDirectory)directoryIdentifier;

/** Create any directory in the user domain given the directory constant, e.g.,  NSCachesDirectory.  */
+ (BOOL) createDirectoryInUserSearchPath:(NSSearchPathDirectory)directoryIdentifier error:(NSError **)error;

+ (unsigned long long) freeSpaceForDirectoryInUserSearchPath:(NSUInteger)directoryIdentifier;

@end
