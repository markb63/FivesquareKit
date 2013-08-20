//
//  UIView+FSQUIKit.m
//  FivesquareKit
//
//  Created by John Clayton on 4/13/12.
//  Copyright (c) 2012 Fivesquare Software, LLC. All rights reserved.
//

#import "UIView+FSQUIKit.h"

@implementation UIView (FSQUIKit)

- (id) firstDescendantMemberOfClass:(Class)aClass {
	id descendant = nil;
	for (UIView * subview in self.subviews) {
		if ([subview isMemberOfClass:aClass]) {
			descendant = subview;
			break;
		}
	}
	if (descendant == nil) {
		for (UIView * subview in self.subviews) {
			descendant = [subview firstDescendantMemberOfClass:aClass];
		}
	}
	return descendant;
}

- (id) firstAncestorOfClass:(Class)aClass {
	UIView *ancestor = nil;
	UIView *view = self;
	do {
		if ([view isKindOfClass:aClass]) {
			ancestor = view;
			break;
		}
		view = view.superview;
	} while (view);
	return ancestor;
}

- (CGAffineTransform) offscreenLeftTransform {
	CGAffineTransform offscreenLeftTransform = CGAffineTransformMakeTranslation(-self.bounds.size.width,0);
	return offscreenLeftTransform;
}

- (CGAffineTransform) offscreenRightTransform {
	CGAffineTransform offscreenRightTransform = CGAffineTransformMakeTranslation(self.bounds.size.width,0);
	return offscreenRightTransform;
}

- (CGAffineTransform) offscreenTopTransform {
	CGAffineTransform offscreenTopTransform = CGAffineTransformMakeTranslation(0, -self.bounds.size.height);
	return offscreenTopTransform;
}

- (CGAffineTransform) offscreenBottomTransform {
	CGAffineTransform offscreenBottomTransform = CGAffineTransformMakeTranslation(0, self.bounds.size.height);
	return offscreenBottomTransform;
}



@end
