//
//  OpenKeyManager.m
//  OpenKey
//
//  Created by Tuyen on 1/27/19.
//  Copyright © 2019 Tuyen Mai. All rights reserved.
//

#import "OpenKeyManager.h"
#import "MJAccessibilityUtils.h"
#import <Carbon/Carbon.h>

extern void OpenKeyInit(void);
extern void ResetInputSession(void);
extern void RefreshInputContext(void);

extern CGEventRef OpenKeyCallback(CGEventTapProxy proxy,
                                  CGEventType type,
                                  CGEventRef event,
                                  void *refcon);

extern NSString* ConvertUtil(NSString* str);

@interface OpenKeyManager ()

@end

@implementation OpenKeyManager {

}
static BOOL _isInited = NO;

static CFMachPortRef      eventTap;
static CGEventMask        eventMask;
static CFRunLoopSourceRef runLoopSource;
static BOOL engineInitialized;
static BOOL userDisabled;
static NSTimer *healthTimer;

+(BOOL)isInited {
    return _isInited;
}

// The tap, timers and engine share the AppKit run loop; no cross-thread engine calls.
+(BOOL)isActive {
    return eventTap && CFMachPortIsValid(eventTap) && CGEventTapIsEnabled(eventTap);
}

+(BOOL)isPaused { return userDisabled; }

+(void)recoverEventTap {
    if (userDisabled || !MJAccessibilityIsEnabled() || IsSecureEventInputEnabled()) return;
    if (eventTap && CFMachPortIsValid(eventTap)) {
        ResetInputSession();
        CGEventTapEnable(eventTap, true);
    }
}

+(void)handleTapDisabledByUser {
    userDisabled = YES;
    ResetInputSession();
}

+(BOOL)resumeEventTap {
    return userDisabled ? NO : [self initEventTap];
}

+(void)prepareEngine {
    if (!engineInitialized) {
        OpenKeyInit();
        engineInitialized = YES;
    }
}

+(BOOL)initEventTap {
    if (!MJAccessibilityIsEnabled()) return NO;
    userDisabled = NO; // Only an explicit initialization/retry clears an intentional pause.
    if (eventTap && CFMachPortIsValid(eventTap)) {
        if (![self isActive]) [self recoverEventTap];
        return [self isActive];
    }
    [self stopEventTap];
    [self prepareEngine];
    eventMask = CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp) |
                CGEventMaskBit(kCGEventFlagsChanged) | CGEventMaskBit(kCGEventLeftMouseDown) |
                CGEventMaskBit(kCGEventRightMouseDown);
    // Keep the established session tap location while repairing lifecycle/recovery.
    eventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap,
                               kCGEventTapOptionDefault, eventMask, OpenKeyCallback, NULL);
    if (!eventTap) return NO;
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
    if (!runLoopSource) {
        CFRelease(eventTap);
        eventTap = NULL;
        return NO;
    }
    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, kCFRunLoopCommonModes);
    _isInited = YES;
    ResetInputSession();
    RefreshInputContext();
    CGEventTapEnable(eventTap, true);
    healthTimer = [NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer) {
        RefreshInputContext();
        if (!MJAccessibilityIsEnabled()) {
            [self stopEventTap];
        } else if (!userDisabled && !IsSecureEventInputEnabled()) {
            if (!eventTap || !CFMachPortIsValid(eventTap)) [self initEventTap];
            else if (!CGEventTapIsEnabled(eventTap)) [self recoverEventTap];
        }
    }];
    [[NSRunLoop mainRunLoop] addTimer:healthTimer forMode:NSRunLoopCommonModes];
    return [self isActive];
}

+(BOOL)stopEventTap {
    [healthTimer invalidate];
    healthTimer = nil;
    if (runLoopSource) {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, kCFRunLoopCommonModes);
        CFRelease(runLoopSource);
        runLoopSource = NULL;
    }
    if (eventTap) {
        CFMachPortInvalidate(eventTap);
        CFRelease(eventTap);
        eventTap = NULL;
    }
    _isInited = NO;
    if (engineInitialized) ResetInputSession();
    return YES;
}

+(NSArray*)getTableCodes {
    return [[NSArray alloc] initWithObjects:
            @"Unicode",
            @"TCVN3 (ABC)",
            @"VNI Windows",
            @"Unicode tổ hợp",
            @"Vietnamese Locale CP 1258", nil];
}

+(NSString*)getBuildDate {
    return [NSString stringWithUTF8String:__DATE__];
}

#pragma mark -Convert feature
+(BOOL)quickConvert {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSString *htmlString = [pasteboard stringForType:NSPasteboardTypeHTML];
    NSString *rawString = [pasteboard stringForType:NSPasteboardTypeString];
    bool converted = false;
    if (htmlString != nil) {
        htmlString = ConvertUtil(htmlString);
        converted = true;
    }
    if (rawString != nil) {
        rawString = ConvertUtil(rawString);
        converted = true;
    }
    if (converted) {
        [pasteboard clearContents];
        if (htmlString != nil)
            [pasteboard setString:htmlString forType:NSPasteboardTypeHTML];
        if (rawString != nil)
            [pasteboard setString:rawString forType:NSPasteboardTypeString];
        
        return YES;
    }
    return NO;
}

+(void)showMessage:(NSWindow*)window message:(NSString*)msg subMsg:(NSString*)subMsg {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:msg];
    [alert setInformativeText:subMsg]; // AppKit supplies its own localized OK button.
    if (window) {
        [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
        }];
    } else {
        [alert runModal];
    }
}

#pragma mark -Release downloads

+(void)checkNewVersion:(NSWindow*)parent callbackFunc:(CheckNewVersionCallback)callback {
    // Download/install is explicit. Never run the inherited upstream replacement helper.
    BOOL opened=[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/vinadesignstore/vinakey/releases"]];
    if (callback) callback();
    if (!opened) [self showMessage:parent message:@"Không thể mở trang phát hành" subMsg:@"Truy cập github.com/vinadesignstore/vinakey/releases để tải bản mới."];
}
@end
