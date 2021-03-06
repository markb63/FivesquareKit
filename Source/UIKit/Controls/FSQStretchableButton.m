//
//  FSQStretchableButton.m
//  FivesquareKit
//
//  Created by John Clayton on 4/3/12.
//  Copyright (c) 2012 Fivesquare Software, LLC. All rights reserved.
//

#import "FSQStretchableButton.h"

@interface FSQStretchableButton ()
- (void) generateStretchableImages;
@end

@implementation FSQStretchableButton

// ========================================================================== //

#pragma mark - Properties


- (void) setCapInsets:(UIEdgeInsets)capInsets {
	if (NO == UIEdgeInsetsEqualToEdgeInsets(_capInsets, capInsets)) {
		_capInsets = capInsets;
		[self generateStretchableImages];
	}
}

@dynamic horizontalCapInsets;
- (void) setHorizontalCapInsets:(CGPoint)horizontalCapInsets {
	UIEdgeInsets newCapInsets = self.capInsets;
	newCapInsets.left = horizontalCapInsets.x;
	newCapInsets.right = horizontalCapInsets.y;
	self.capInsets = newCapInsets;
}

- (CGPoint) horizontalCapInsets {
	return CGPointMake(_capInsets.left, _capInsets.right);
}

@dynamic verticalCapInsets;
- (void) setVerticalCapInsets:(CGPoint)verticalCapInsets {
	UIEdgeInsets newCapInsets = self.capInsets;
	newCapInsets.top = verticalCapInsets.x;
	newCapInsets.bottom = verticalCapInsets.y;
	self.capInsets = newCapInsets;
}

- (CGPoint) verticalCapInsets {
	return CGPointMake(_capInsets.top, _capInsets.bottom);
}

- (CGRect) capInsetsAsRect {
	return CGRectMake(_capInsets.left, _capInsets.top, _capInsets.right, _capInsets.bottom);
}

- (void) setCapInsetsAsRect:(CGRect)insetsAsRect {
	UIEdgeInsets capInsets = UIEdgeInsetsMake(insetsAsRect.origin.y, insetsAsRect.origin.x, insetsAsRect.size.height, insetsAsRect.size.width);
	self.capInsets = capInsets;
}

// ========================================================================== //

#pragma mark -  Button


- (void) initialize {
	self.capInsets = UIEdgeInsetsMake(0, 2, 0, 2);
}

- (void) ready {
//	[self generateStretchableImages];
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self initialize];
		[self ready];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
		[ self initialize];
    }
    return self;
}

- (void) awakeFromNib {
	[super awakeFromNib];
	[self ready];
}

// Have to do this here because appearance now tracks usage of setters and will not invoke appearance selectors if the property has been called already
- (void) didMoveToSuperview {
	if (self.superview) {
		[self generateStretchableImages];
	}
}


/*
 UIControlStateNormal       = 0,                       
 UIControlStateHighlighted  = 1 << 0,                  // used when UIControl isHighlighted is set
 UIControlStateDisabled     = 1 << 1,
 UIControlStateSelected     = 1 << 2,                  // flag usable by app (see below)
*/
- (void) setBackgroundImage:(UIImage *)image forState:(UIControlState)state {
	UIImage *resizableImage = nil;
	if (image) {
		resizableImage = [image resizableImageWithCapInsets:self.capInsets];
	}
	[super setBackgroundImage:resizableImage forState:state];
	[self setNeedsDisplay];
}

- (void) setBackgroundImage:(UIImage *)image forState:(UIControlState)state capInsets:(UIEdgeInsets)capInsets {
	self.capInsets = capInsets;
	[self setBackgroundImage:image forState:state];
}




// ========================================================================== //

#pragma mark - Helpers

- (void) generateStretchableImages {
	for (NSUInteger state = UIControlStateNormal; state <= UIControlStateSelected; state = 1 << state ) {
		[self setBackgroundImage:[self backgroundImageForState:state] forState:state];
	}
}




@end
