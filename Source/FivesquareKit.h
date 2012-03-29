//
//  FivesquareKit.h
//  FivesquareKit
//
//  Created by John Clayton on 6/6/2009.
//  Copyright 2009 Fivesquare Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "FSQCore.h"
#import "FSQFoundation.h"
#import "FSQCoreData.h"
#import "FSQCoreLocation.h"

#if TARGET_OS_IPHONE
#import "FSQUIKit.h"
#endif



@interface FivesquareKit {
	
}

+ (NSString *) version;

@end