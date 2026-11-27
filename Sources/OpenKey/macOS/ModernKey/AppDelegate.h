//
//  AppDelegate.h
//  ModernKey
//
//  Created by Tuyen on 1/18/19.
//  Copyright © 2019 Tuyen Mai. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ViewController.h"

#define OPENKEY_BUNDLE @"com.vinadesignstore.vinakey"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate>

-(void)onImputMethodChanged:(BOOL)willNotify;
-(void)onInputMethodSelected;
-(void)setInputLanguage:(int)language;

-(void)askPermission;
-(void)onControlPanelSelected;

-(void)onInputTypeSelectedIndex:(int)index;
-(void)onCodeTableChanged:(int)index;

-(void)setRunOnStartup:(BOOL)val;
-(BOOL)runOnStartupEnabled;
-(void)loadDefaultConfig;

-(void)setGrayIcon:(BOOL)val;

-(void)onQuickConvert;
-(void)setQuickConvertString;

-(void)showIconOnDock:(BOOL)val;
@end

