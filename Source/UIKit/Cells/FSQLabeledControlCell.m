//
//  FSQLabledSwitchCell.m
//  FivesquareKit
//
//  Created by John Clayton on 12/9/2009.
//  Copyright 2009 Fivesquare Software, LLC. All rights reserved.
//

#import "FSQLabeledControlCell.h"


@implementation FSQLabeledControlCell

- (BOOL) becomeFirstResponder {
	return [self.control becomeFirstResponder];
}

@end
