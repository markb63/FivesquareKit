//
//  FSQRuntime.h
//  FivesquareKit
//
//  Created by John Clayton on 5/29/2010.
//  Copyright 2010 Fivesquare Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>


@interface FSQRuntime : NSObject {

}


/** Copies method from target to source and overwrites it if overwrite is set
 *  to YES.
 *  @param aMethod_sel - The method selector indicating which method to copy
 *  @param source - The class to copy the method from
 *  @param target - The class to copy the method to
 *  @param overwrite - Whether to overwrite an existing method in the target class with the source method
 *  @return YES on success
 */
+ (BOOL) copyMethod:(SEL)aMethod_sel from:(Class)source to:(Class)target overwrite:(BOOL)overwrite;

/** Swizzles (overwrites the implementation of) target's method with source's method.
 *  @param originalMethod_sel - The method selector of the method in source being swizzled
 *  @param source - The class to swizzle the method from
 *  @param replacementMethod_sel - The method selector of the method in target being used to swizzle the original method in source
 *  @param target - The class to swizzle the method to
 *  @param aliasOriginal - Whether to stash the original method implementation in a new method called "_original<originalMethod>"
 *  @return YES on success
 */
+ (BOOL) swizzleMethod:(SEL)originalMethod_sel inTarget:(Class)target withMethod:(SEL)replacementMethod_sel fromSource:(Class)source aliasOriginal:(BOOL)shouldAlias;

/** Copies originalMethod to newMethod in klass
 *  @param originalMethod_sel - The method selector of the method being aliased
 *  @param newMethod_sel - The method selector of the new method alias
 */
+ (BOOL) aliasMethod:(SEL)originalMethod_sel to:(SEL)newMethod_sel inClass:(Class)klass;
@end
