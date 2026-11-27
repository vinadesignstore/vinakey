// Exercise production AppDelegate menu actions without a keyboard hook or user preferences.
#import <objc/runtime.h>
#import <ServiceManagement/ServiceManagement.h>
#import "../Sources/OpenKey/macOS/ModernKey/AppDelegate.h"
#import "../Sources/OpenKey/macOS/ModernKey/SettingsWindowController.h"
#import "../Sources/OpenKey/macOS/ModernKey/OpenKeyManager.h"
#import "../Sources/OpenKey/macOS/ModernKey/MJAccessibilityUtils.h"
#import "../Sources/OpenKey/engine/Engine.h"
#include <cassert>
extern int vSwitchKeyStatus;
bool convertToolDontAlertWhenCompleted=false;
static NSUserDefaults *prefs;
static BOOL trusted=YES,active=YES;
static int saves=0,settingsOpened=0,loginErrors=0;
@interface FakeLoginService : NSObject
@property NSInteger status;
@property BOOL fails,approval;
@property int registrations;
@end
@implementation FakeLoginService
-(BOOL)registerAndReturnError:(NSError **)error {
    self.registrations++;
    if (self.fails) { *error=[NSError errorWithDomain:@"test" code:1 userInfo:nil]; return NO; }
    self.status=self.approval ? 2 : 1; return YES;
}
-(BOOL)unregisterAndReturnError:(NSError **)error { self.status=0; return YES; }
@end
static FakeLoginService *loginService;
@interface SMAppService (LoginTests)
+(id)testMainAppService;
@end
@implementation SMAppService (LoginTests)
+(id)testMainAppService { return loginService; }
@end
extern "C" {
void OnInputMethodChanged(void) { ++saves; }
void OnTableCodeChange(void) {}
void RequestNewSession(void) {}
void RefreshInputContext(void) {}
void OnActiveAppChanged(void) {}
}
BOOL MJAccessibilityIsEnabled(void) { return trusted; }
@interface NSUserDefaults (MenuTests)
+(NSUserDefaults *)menuTestDefaults;
@end
@implementation NSUserDefaults (MenuTests)
+(NSUserDefaults *)menuTestDefaults { return prefs; }
@end
@interface MenuRunningApp : NSObject
@property(readonly) NSString *bundleIdentifier;
@end
@implementation MenuRunningApp
-(NSString *)bundleIdentifier { return @"org.openkey.menu-test"; }
@end
@interface NSWorkspace (MenuTests)
-(NSRunningApplication *)menuTestApp;
@end
@implementation NSWorkspace (MenuTests)
-(NSRunningApplication *)menuTestApp { static MenuRunningApp *app=[MenuRunningApp new]; return (NSRunningApplication *)app; }
@end
@interface AppDelegate (MenuTests)
-(void)createStatusBarMenu;
-(NSImage *)inputBadge:(NSString *)label;
-(void)selectMenuSource:(NSMenuItem *)sender;
@end
@interface MenuDelegate : AppDelegate
@end
@implementation MenuDelegate
-(void)onControlPanelSelected { ++settingsOpened; }
@end
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation SettingsWindowController
@end
@implementation OpenKeyManager
+(void)showMessage:(NSWindow *)window message:(NSString *)message subMsg:(NSString *)detail { loginErrors++; }
+(BOOL)isActive { return active; }
+(BOOL)initEventTap { return active=trusted; }
@end
#pragma clang diagnostic pop
int main() { @autoreleasepool {
    NSString *suite=[@"org.openkey.menu-tests." stringByAppendingString:NSUUID.UUID.UUIDString];
    prefs=[[NSUserDefaults alloc] initWithSuiteName:suite];
    method_exchangeImplementations(class_getClassMethod(NSUserDefaults.class,@selector(standardUserDefaults)),
        class_getClassMethod(NSUserDefaults.class,@selector(menuTestDefaults)));
    [NSApplication sharedApplication];
    MenuDelegate *delegate=[MenuDelegate new]; [delegate createStatusBarMenu];
    NSBitmapImageRep *badge=[NSBitmapImageRep imageRepWithData:[[delegate inputBadge:@"EN"] TIFFRepresentation]];
    NSUInteger filled=0,cutout=0;
    for (NSInteger y=badge.pixelsHigh/4;y<badge.pixelsHigh*3/4;y++)
        for (NSInteger x=badge.pixelsWide/4;x<badge.pixelsWide*3/4;x++) {
            CGFloat alpha=[badge colorAtX:x y:y].alphaComponent;
            if (alpha>0.9) filled++; if (alpha<0.1) cutout++;
        }
    assert(filled>20 && cutout>5); // Solid template badge with transparent letter cutouts.

    method_exchangeImplementations(class_getInstanceMethod(NSWorkspace.class,@selector(frontmostApplication)),
        class_getInstanceMethod(NSWorkspace.class,@selector(menuTestApp)));
    NSArray<NSMenuItem *> *styles=[delegate valueForKey:@"menuTypingStyles"];
    NSMenuItem *english=[delegate valueForKey:@"menuEnglish"];
    assert(styles.count==4);
    NSStatusItem *status=[delegate valueForKey:@"statusItem"];
    for (NSUInteger i=0;i<styles.count;i++) {
        [delegate selectMenuSource:styles[i]];
        assert(vLanguage==1 && vInputType==i && [prefs integerForKey:@"InputType"]==i);
        assert(styles[i].state==NSControlStateValueOn && english.state==NSControlStateValueOff);
        assert([status.button.title isEqual:styles[i].title] && status.button.image.isTemplate);
        for (NSUInteger j=0;j<styles.count;j++) assert(styles[j].state==(i==j ? NSControlStateValueOn : NSControlStateValueOff));
    }
    assert(saves==4);
    [delegate selectMenuSource:english];
    assert(vLanguage==0 && vInputType==3 && saves==5 && settingsOpened==0);
    assert(english.state==NSControlStateValueOn && [status.button.title isEqual:@"ABC"]);
    for (NSMenuItem *item in styles) assert(item.state==NSControlStateValueOff);
    [prefs setObject:@{@"org.openkey.menu-test":@1} forKey:@"AppLanguageRules"];
    [delegate menuWillOpen:[delegate valueForKey:@"theMenu"]]; assert(!english.enabled && styles[0].enabled);
    [delegate selectMenuSource:styles[0]]; assert(vLanguage==1 && vInputType==0 && saves==6);
    [delegate selectMenuSource:english]; assert(vLanguage==1 && saves==6);
    [prefs setObject:@{@"org.openkey.menu-test":@0} forKey:@"AppLanguageRules"];
    [delegate menuWillOpen:[delegate valueForKey:@"theMenu"]]; assert(english.enabled && !styles[0].enabled);
    [delegate selectMenuSource:styles[1]]; assert(vInputType==0 && saves==6);
    [delegate selectMenuSource:english]; assert(vLanguage==0 && saves==7);
    [prefs removeObjectForKey:@"AppLanguageRules"]; trusted=NO;
    [delegate menuWillOpen:[delegate valueForKey:@"theMenu"]]; assert(!english.enabled && !styles[0].enabled);
    [delegate selectMenuSource:styles[0]]; assert(settingsOpened==1 && saves==7);
    trusted=YES; active=NO;
    [delegate menuWillOpen:[delegate valueForKey:@"theMenu"]]; assert(!english.enabled && !styles[0].enabled);
    assert(![[delegate valueForKey:@"menuConnection"] isHidden]);
    NSMenu *application=NSApp.mainMenu.itemArray.firstObject.submenu;
    NSMenuItem *settings=[application itemWithTitle:@"Cài đặt…"];
    assert([settings.keyEquivalent isEqual:@","] && settings.target==delegate);
    assert(settings.action==@selector(onControlPanelSelected));
    NSMenuItem *close=[NSApp.windowsMenu itemWithTitle:@"Đóng"];
    assert(close.action==@selector(performClose:) && [close.keyEquivalent isEqual:@"w"] && close.target==nil);
    NSMenu *menu=[delegate valueForKey:@"theMenu"];
    assert(menu.numberOfItems==12 && [menu itemWithTitle:@"Gõ tắt…"]==nil);
    if (@available(macOS 13.0,*)) {
        loginService=[FakeLoginService new];
        method_exchangeImplementations(class_getClassMethod(SMAppService.class,@selector(mainAppService)),class_getClassMethod(SMAppService.class,@selector(testMainAppService)));
        assert(![delegate runOnStartupEnabled]);
        [delegate setRunOnStartup:YES]; assert([delegate runOnStartupEnabled] && [prefs boolForKey:@"RunOnStartup"]);
        [delegate setRunOnStartup:YES]; assert(loginService.registrations==1);
        [delegate setRunOnStartup:NO]; assert(![delegate runOnStartupEnabled] && ![prefs boolForKey:@"RunOnStartup"]);
        loginService.fails=YES; [delegate setRunOnStartup:YES]; assert(loginErrors==1 && ![prefs boolForKey:@"RunOnStartup"]);
        loginService.fails=NO; loginService.approval=YES; [delegate setRunOnStartup:YES]; assert(loginErrors==2 && ![prefs boolForKey:@"RunOnStartup"]);
        [delegate setRunOnStartup:NO]; assert(loginService.status==0);
        method_exchangeImplementations(class_getClassMethod(SMAppService.class,@selector(mainAppService)),class_getClassMethod(SMAppService.class,@selector(testMainAppService)));
    }
    [[NSStatusBar systemStatusBar] removeStatusItem:[delegate valueForKey:@"statusItem"]];
    [prefs removePersistentDomainForName:suite];
    puts("Menu/login: registration, failure/approval state, all typing sources, active badge/name/checkmarks, saved mode, fixed rules, permission gate, Command-Comma and Command-W passed");
} }
