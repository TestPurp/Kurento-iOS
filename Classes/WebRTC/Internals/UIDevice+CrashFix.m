//
//  UIDevice+CrashFix.m
//  KurentoToolbox-Static
//
//  Created by xzming on 2020/9/15.
//  Copyright © 2020 Telecom Italia S.p.A. All rights reserved.
//

#import "UIDevice+CrashFix.h"
#include <objc/runtime.h>

@implementation UIDevice (CrashFix)

static inline void cf_swizzleSelector(Class theClass, SEL originalSelector, SEL swizzledSelector) {
    Method originalMethod = class_getInstanceMethod(theClass, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(theClass, swizzledSelector);
    method_exchangeImplementations(originalMethod, swizzledMethod);
}

+ (void)load {
    if ([UIDevice currentDevice].systemVersion.floatValue >= 13.0) {
        cf_swizzleSelector(UIDevice.class, @selector(endGeneratingDeviceOrientationNotifications), @selector(cfEndGeneratingDeviceOrientationNotifications));
    }
}

- (void)cfEndGeneratingDeviceOrientationNotifications {
    NSLog(@"%s isMainThread:%d", __PRETTY_FUNCTION__, [NSThread isMainThread]);
    if (![NSThread isMainThread]) {
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [self cfEndGeneratingDeviceOrientationNotifications];
//        });
        return;
    }
    [self cfEndGeneratingDeviceOrientationNotifications];
}

@end
