//
//  FSQThumbstripView.m
//  FivesquareKit
//
//  Created by John Clayton on 4/19/12.
//  Copyright (c) 2012 Fivesquare Software, LLC. All rights reserved.
//

#import "FSQThumbstripView.h"

#import "FSQLogging.h"
#import "FSQAsserter.h"
#import "FSQThumbstripCell.h"

#define kFSQThumbstripCellTransitionAnimationDuration 0.1


@interface FSQThumbstripView ()

// Private

@property (nonatomic, strong) NSMutableSet *activeCells;
@property (nonatomic, strong) NSMutableSet *inactiveCells;
@property (nonatomic, strong) NSMutableArray *cellOffsetRanges;
@property (nonatomic, readonly) CGFloat offsetInSignificantDimension;
@property (nonatomic, readonly) NSInteger indexOfCellAtCurrentOffset;
@property (nonatomic, readonly) CGRect visibleRect;
@property (nonatomic, readonly) BOOL isHorizontal;

// Overrides


- (void) initialize;

// Scroll view

- (CGFloat) offsetInSignificantDimensionOfPoint:(CGPoint)point;

// Cell handling

- (CGSize) sizeThatFitsForCellAtIndex:(NSInteger)index;
- (id) activeCellForIndex:(NSInteger)index;
- (CGPoint) originForCellAtIndex:(NSInteger)index;
- (void) loadVisibleCells;
- (void) loadCellAtIndex:(NSInteger)index;

// Scroll handling

- (void) scrollingBegan;
- (void) didScroll;

@end



@implementation FSQThumbstripView

// ========================================================================== //

#pragma mark - Properties

@synthesize dataSource=dataSource_;
@synthesize delegate=delegate_;
@synthesize cellClass=cellClass_;
@synthesize cellSize=cellSize_;
@synthesize backgroundView=backgroundView_;

@dynamic visibleRange;
- (NSRange) visibleRange {
	NSInteger location = [self indexOfCellAtCurrentOffset];
	NSUInteger length = 0;
	CGFloat contentSpan = self.isHorizontal ? self.bounds.size.width : self.bounds.size.height;
	CGFloat offset = [self offsetInSignificantDimension];
	if (offset < 0) {
		offset = 0;
	}

	NSRange contentRange = NSMakeRange(offset, contentSpan);
//	FLog(@"contentRange: %@",NSStringFromRange(contentRange));
	
	NSUInteger count = cellOffsetRanges_.count;
	for (NSInteger index = location; index < count; index++) {
		NSRange cellRange = [[cellOffsetRanges_ objectAtIndex:(NSUInteger)index] rangeValue];
//		FLog(@"cellRange: %@",NSStringFromRange(cellRange));
		NSRange intersectionRange = NSIntersectionRange(contentRange, cellRange);
//		FLog(@"intersectionRange: %@",NSStringFromRange(intersectionRange));
		if (intersectionRange.length == 0) {
			break;
		}
		length++;
	}
	return NSMakeRange((NSUInteger)location, length);
}

@dynamic visibleCells;
- (NSSet *) visibleCells {
	return nil;
}

- (void) setCellSize:(CGSize)cellSize {
	if (CGSizeEqualToSize(cellSize_, cellSize_)) {
		cellSize_ = cellSize;
		[self setNeedsDisplay];
	}
}


// Private


@synthesize activeCells=activeCells_;
@synthesize inactiveCells=inactiveCells_;
@synthesize cellOffsetRanges=cellOffsetRanges_;


@dynamic isHorizontal;
- (BOOL) isHorizontal {
	return self.bounds.size.width >= self.bounds.size.height;
}

@dynamic offsetInSignificantDimension;
- (CGFloat) offsetInSignificantDimension {
	return [self offsetInSignificantDimensionOfPoint:self.contentOffset];
}

@dynamic indexOfCellAtCurrentOffset;
- (NSInteger) indexOfCellAtCurrentOffset {
	__block NSInteger index = NSNotFound;
	CGFloat offset = [self offsetInSignificantDimension];
	[self.cellOffsetRanges enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		NSRange range = [obj rangeValue];
		if (NSLocationInRange(offset, range)) {
			index = (NSInteger)idx;
			*stop = YES;
		}
	}];
	return index;
}

@dynamic visibleRect;
- (CGRect) visibleRect {
	CGRect rect = self.bounds;
	CGFloat offset = [self offsetInSignificantDimension];
	if (offset < 0) {
		offset = 0;
	}
	if (self.isHorizontal) {
		rect.origin.x = offset;
	} else {
		rect.origin.y = offset;
	}
	return rect;
}


// ========================================================================== //

#pragma mark - Object



- (void) initialize {
	
	self.directionalLockEnabled = YES;
	
	activeCells_  = [NSMutableSet new];
	inactiveCells_ = [NSMutableSet new];
	cellOffsetRanges_ = [NSMutableArray new];
	
	cellSize_ = CGSizeMake(200, 200);
//	self.backgroundColor = [UIColor redColor];
	self.showsHorizontalScrollIndicator = NO;
	self.showsVerticalScrollIndicator = NO;
	self.pagingEnabled = NO;
	
	self.clipsToBounds = NO;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
		[self initialize];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self initialize];
    }
    return self;
}



// ========================================================================== //

#pragma mark - UIScrollView

- (void) layoutSubviews {
	[super layoutSubviews];
	

	[self loadVisibleCells];
}

- (void) didScroll {
//	FLog(@"contentOffset: %@", NSStringFromCGPoint(self.contentOffset));
	[self loadVisibleCells];
}

- (void) willMoveToSuperview:(UIView *)newSuperview {
	if (newSuperview) {
		[self addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
	} else {
		[self removeObserver:self forKeyPath:@"contentOffset"];
	}
}


// ========================================================================== //

#pragma mark - Public interface


- (FSQThumbstripCell *) cellAtIndex:(NSInteger)index {
	id cell = [self activeCellForIndex:index];
	if (cell == nil) {
		cell = [dataSource_ thumbstripView:self cellForIndex:index];
		FSQAssert(cell != nil, @"thumbstripView:cellForIndex: cannot return nil");
	}
	return cell;
}

- (NSInteger) indexForCellAtPoint:(CGPoint)point {
	return NSNotFound;
}

- (NSIndexSet *) indexesForCellsInRect:(CGRect)rect {
	return nil;
}

- (void) selectCellAtIndex:(NSInteger)index animated:(BOOL)animated {
	
}

- (void) deselectCellAtIndex:(NSInteger)index animated:(BOOL)animated {
	
}


- (void) reloadData {
//	[UIView animateWithDuration:kFSQThumbstripCellTransitionAnimationDuration animations:^{
		for (id cell in activeCells_) {
			[cell setAlpha:0];
			[cell removeFromSuperview];
		}
//	}];
	[activeCells_ removeAllObjects];
	[inactiveCells_ removeAllObjects];	
	[cellOffsetRanges_ removeAllObjects];
	
	// get the total width, compute cell ranges, and set content size
	NSInteger count = [dataSource_ numberOfItemsInthumbstripView:self];
	CGFloat offset = 0;
	for (int i = 0; i < count; i++) {
		CGSize cellSize = [self sizeThatFitsForCellAtIndex:i];
		CGFloat length = self.isHorizontal ? cellSize.width : cellSize.height;
		[cellOffsetRanges_ addObject:[NSValue valueWithRange:NSMakeRange(offset, length)]];
		offset += length;
	}
	CGSize newContentSize = self.contentSize;
	if (self.isHorizontal) {
		newContentSize.width = offset;
	} else {
		newContentSize.height = offset;
	}
	self.contentSize = newContentSize;

	[self layoutSubviews];
}

- (id) dequeueReusableCellWithIdentifier:(NSString *)identifier {
	Class klass = cellClass_;
	if (klass == nil) {
		klass = [FSQThumbstripCell class];
	}
	
	id cell;
	if ( (cell = [inactiveCells_ anyObject]) ) {
		[inactiveCells_ removeObject:cell];
		[cell prepareForReuse];
	} else {
		cell = [[klass alloc] initWithReuseIdentifier:identifier];
	}
	return cell;
}


// ========================================================================== //

#pragma mark - Helpers

- (CGFloat) offsetInSignificantDimensionOfPoint:(CGPoint)point {
	CGFloat offset = self.isHorizontal ? point.x : point.y;
	return offset;
}

- (CGSize) sizeThatFitsForCellAtIndex:(NSInteger)index {
	CGSize cellSize = self.cellSize;
	if ([delegate_ respondsToSelector:@selector(thumbstripView:sizeForCellAtIndex:)]) {
		cellSize = [delegate_ thumbstripView:self sizeForCellAtIndex:index];
	}
	return cellSize;
}

- (id) activeCellForIndex:(NSInteger)index {
	if (index >= cellOffsetRanges_.count) {
		return nil;
	}

	NSRange cellRangeForIndex = [[cellOffsetRanges_ objectAtIndex:(NSUInteger)index] rangeValue];
	
	for (FSQThumbstripCell *cell in activeCells_) {
		CGFloat location = self.isHorizontal ? cell.frame.origin.x : cell.frame.origin.y;
		CGFloat length = self.isHorizontal ? cell.frame.size.width : cell.frame.size.height;
		NSRange cellRange = NSMakeRange(location, length);
		
		if (NSEqualRanges(cellRangeForIndex, cellRange)) {
			return cell;
		}
	}
	return nil;
}

- (CGPoint) originForCellAtIndex:(NSInteger)index {
	if (index >= cellOffsetRanges_.count ) {
		return CGPointZero;
	}
	NSRange cellRange = [[cellOffsetRanges_ objectAtIndex:(NSUInteger)index] rangeValue];
	CGFloat x = self.isHorizontal ? cellRange.location : 0;
	CGFloat y = self.isHorizontal ? 0 : cellRange.location;
	return CGPointMake(x, y);
}

- (void) loadVisibleCells {
	// dequeue unused cells
	
	NSMutableSet *invisibleCells = [NSMutableSet new];
	CGRect visibleRect = [self visibleRect];
	for (id cell in activeCells_) {
		CGRect cellRect = [cell frame];
		BOOL visible = CGRectIntersectsRect(visibleRect, cellRect);
		if (NO == visible) {
			[invisibleCells addObject:cell];
		}
	}
//	FLog(@"inivisbleCells: %@", invisibleCells);
//	FLog(@"1. activeCells_: %@", activeCells_);
//	FLog(@"1. inactiveCells_: %@", inactiveCells_);
	[activeCells_ minusSet:invisibleCells];
	[inactiveCells_ unionSet:invisibleCells];

//	FLog(@"2. activeCells_: %@", activeCells_);
//	FLog(@"2. inactiveCells_: %@", inactiveCells_);

	
	// load any visible cells that are not loaded
	
	NSRange visibleRange = [self visibleRange];
	for (NSInteger index = (NSInteger)visibleRange.location; index < NSMaxRange(visibleRange); index++) {
		[self loadCellAtIndex:index];
	}	

	[invisibleCells makeObjectsPerformSelector:@selector(removeFromSuperview)];
}

- (void) loadCellAtIndex:(NSInteger)index {
//	FLog(@"loadCellAtIndex: %d",index);

	id existingCell = [self activeCellForIndex:index];
	if (existingCell) {
//		FLog(@"existing cell: %@",existingCell);
		return;
	}
	if (dataSource_) {
		id cell = [dataSource_ thumbstripView:self cellForIndex:index];
		FSQAssert(cell != nil, @"thumbstripView:cellForIndex: cannot return nil");
		if (cell) {
			
			CGRect cellFrame = CGRectZero;
			cellFrame.size = [self sizeThatFitsForCellAtIndex:index];
			cellFrame.origin = [self originForCellAtIndex:index];
			[cell setFrame:cellFrame];
			
//			[cell setAlpha:0];
//			[UIView animateWithDuration:kFSQThumbstripCellTransitionAnimationDuration animations:^{
//				FLog(@"adding new cell");
				[self addSubview:cell];
				[cell setAlpha:1];
//			} completion:^(BOOL finished) {
				[activeCells_ addObject:cell];
//			}];
		}	
	}
} 



// ========================================================================== //

#pragma mark - Observations


- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
//	if ([keyPath isEqualToString:@"contentOffset"]) {
//		CGFloat currentOffset = [self offsetInSignificantDimension];
//		CGFloat newOffset = [self offsetInSignificantDimensionOfPoint:[[change objectForKey:NSKeyValueChangeNewKey] CGPointValue]];
//		if (currentOffset != newOffset) {
//			[self didScroll];
//		}
//	}
}


@end