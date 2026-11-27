//
//  main.m
//  ModernKey
//
//  Created by Tuyen on 1/18/19.
//  Copyright © 2019 Tuyen Mai. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

int main(int argc, const char * argv[]) {
    // There is no storyboard or main nib: the delegate builds the status and main menus in code.
    static AppDelegate *delegate;
    @autoreleasepool {
        delegate = [AppDelegate new];
        NSApplication.sharedApplication.delegate = delegate;
    }
    return NSApplicationMain(argc, argv);
}
