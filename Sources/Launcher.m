// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import <Security/Security.h>
#import <os/log.h>

static NSString *const gamePath = @"/Applications/DeadIsland2.app";
static NSString *const uncutPath = @"/Applications/Dead Island 2 Uncut.app";

static OSStatus validateGame(void) {
    SecStaticCodeRef code = NULL;
    SecRequirementRef requirement = NULL;
    OSStatus result = SecStaticCodeCreateWithPath((__bridge CFURLRef)[NSURL fileURLWithPath:gamePath], kSecCSDefaultFlags, &code);
    if (!result) result = SecRequirementCreateWithString(CFSTR("anchor apple generic and identifier \"com.plaion.DeadIsland2Usk\""), kSecCSDefaultFlags, &requirement);
    if (!result) result = SecStaticCodeCheckValidity(code, kSecCSDoNotValidateResources | kSecCSCheckAllArchitectures, requirement);
    if (!result) {
        CFDictionaryRef information = NULL;
        result = SecCodeCopySigningInformation(code, kSecCSSigningInformation, &information);
        NSDictionary *details = CFBridgingRelease(information);
        if (!result && ![details[(__bridge NSString *)kSecCodeInfoTeamIdentifier] isEqualToString:@"XSBJ2Q9R2T"]) result = errSecCSReqFailed;
    }
    if (code) CFRelease(code);
    if (requirement) CFRelease(requirement);
    return result;
}
static BOOL uncutAvailable(void) {
    NSBundle *bundle = [NSBundle bundleWithPath:uncutPath];
    return [bundle.bundleIdentifier isEqualToString:@"local.deadisland2.launcher"]
        && [NSFileManager.defaultManager isReadableFileAtPath:[uncutPath stringByAppendingPathComponent:@"Contents/Resources/RuntimeIdentity.dylib"]];
}

@interface TrainerDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) NSTextField *status;
@property(nonatomic, strong) NSButton *start;
@property(nonatomic, strong) NSButton *uncut;
@property(nonatomic, strong) NSRunningApplication *game;
@property(nonatomic, copy) NSString *token;
@property(nonatomic, strong) id observer;
@property(nonatomic, strong) NSTimer *processTimer;
@end

@implementation TrainerDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    NSMenu *menu = [NSMenu new];
    NSMenuItem *application = [NSMenuItem new];
    [menu addItem:application];
    NSMenu *applicationMenu = [NSMenu new];
    [applicationMenu addItemWithTitle:@"Trainer beenden" action:@selector(terminate:) keyEquivalent:@"q"];
    application.submenu = applicationMenu;
    NSApp.mainMenu = menu;
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 540, 370)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable
        backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"Dead Island 2 Trainer";
    self.window.releasedWhenClosed = NO;
    NSTextField *title = [NSTextField labelWithString:@"Dead Island 2 Trainer"];
    title.font = [NSFont boldSystemFontOfSize:26];
    NSTextField *subtitle = [NSTextField wrappingLabelWithString:@"Version 0.1.0 · Ingame-Overlay\nMac App Store · Apple Silicon"];
    NSTextField *details = [NSTextField wrappingLabelWithString:@"Das Overlay läuft direkt im Spielprozess und wird in dessen Fenster eingeblendet.\n\nEin-/ausblenden: F8 (ggf. fn + F8) oder ⌘⇧T.\nDiese erste Version enthält noch keine Cheats."];
    details.font = [NSFont systemFontOfSize:13];
    self.uncut = [NSButton checkboxWithTitle:@"Vorhandenen Uncut-Starthelfer mitverwenden" target:nil action:nil];
    self.uncut.enabled = uncutAvailable();
    self.uncut.state = self.uncut.enabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.start = [NSButton buttonWithTitle:@"Spiel mit Overlay starten" target:self action:@selector(startGame:)];
    self.start.bezelStyle = NSBezelStyleRounded;
    self.start.keyEquivalent = @"\r";
    self.status = [NSTextField wrappingLabelWithString:@"Bereit. Spiele-Dateien werden nicht verändert."];
    self.status.font = [NSFont systemFontOfSize:12];
    self.status.textColor = NSColor.secondaryLabelColor;
    NSStackView *stack = [NSStackView stackViewWithViews:@[title, subtitle, details, self.uncut, self.start, self.status]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 18;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.window.contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.window.contentView.leadingAnchor constant:28],
        [stack.trailingAnchor constraintEqualToAnchor:self.window.contentView.trailingAnchor constant:-28],
        [stack.topAnchor constraintEqualToAnchor:self.window.contentView.topAnchor constant:24]
    ]];
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    __weak TrainerDelegate *weakSelf = self;
    self.observer = [NSDistributedNotificationCenter.defaultCenter addObserverForName:@"local.deadisland2.trainer.attached"
        object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event) {
            TrainerDelegate *strongSelf = weakSelf;
            if ([event.object isEqualToString:strongSelf.token] && [event.userInfo[@"pid"] intValue] == strongSelf.game.processIdentifier) {
                strongSelf.status.stringValue = [NSString stringWithFormat:@"Overlay im Spielprozess aktiv · PID %d · F8 / ⌘⇧T", strongSelf.game.processIdentifier];
            }
        }];
}
- (void)startGame:(id)sender {
    (void)sender;
    for (NSRunningApplication *running in NSWorkspace.sharedWorkspace.runningApplications) {
        if ([running.bundleURL.URLByResolvingSymlinksInPath.path isEqualToString:gamePath]) {
            self.status.stringValue = @"Bitte die laufende App-Store-Version regulär beenden und danach mit diesem Trainer starten.";
            return;
        }
    }
    OSStatus validity = validateGame();
    if (validity) { self.status.stringValue = [NSString stringWithFormat:@"Original-App-Store-Signatur nicht bestätigt (Fehler %d).", (int)validity]; return; }
    NSString *library = [NSBundle.mainBundle pathForResource:@"TrainerOverlay" ofType:@"dylib"];
    if (!library) { self.status.stringValue = @"Das Overlay-Modul fehlt."; return; }
    NSMutableArray *libraries = [NSMutableArray arrayWithObject:library];
    if (self.uncut.state == NSControlStateValueOn) {
        if (!uncutAvailable()) { self.status.stringValue = @"Der gewählte vorhandene Uncut-Starthelfer ist nicht verfügbar."; return; }
        [libraries addObject:[uncutPath stringByAppendingPathComponent:@"Contents/Resources/RuntimeIdentity.dylib"]];
    }
    self.token = NSUUID.UUID.UUIDString;
    NSWorkspaceOpenConfiguration *configuration = NSWorkspaceOpenConfiguration.configuration;
    configuration.activates = YES;
    configuration.createsNewApplicationInstance = YES;
    configuration.environment = @{
        @"DYLD_INSERT_LIBRARIES": [libraries componentsJoinedByString:@":"],
        @"DI2_TRAINER_TARGET": [gamePath stringByAppendingPathComponent:@"Contents/MacOS/DeadIsland2"],
        @"DI2_TRAINER_SESSION": self.token
    };
    self.start.enabled = NO;
    self.status.stringValue = @"Spielstart wird angefordert …";
    [NSWorkspace.sharedWorkspace openApplicationAtURL:[NSURL fileURLWithPath:gamePath]
        configuration:configuration completionHandler:^(NSRunningApplication *application, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error || !application) {
                    self.status.stringValue = [NSString stringWithFormat:@"Spielstart fehlgeschlagen: %@", error.localizedDescription ?: @"Kein Prozess gestartet."];
                    self.start.enabled = YES;
                    return;
                }
                self.game = application;
                self.status.stringValue = [NSString stringWithFormat:@"Spiel gestartet · PID %d. Das Overlay erscheint im Spielfenster.", application.processIdentifier];
                [self.processTimer invalidate];
                self.processTimer = [NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer *timer) {
                    if (self.game.terminated) {
                        [timer invalidate]; self.start.enabled = YES;
                        self.status.stringValue = @"Spiel beendet. Bereit für einen neuen Start.";
                    }
                }];
            });
        }];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application { (void)application; return YES; }
- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    if (self.observer) [NSDistributedNotificationCenter.defaultCenter removeObserver:self.observer];
    [self.processTimer invalidate];
}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc == 2 && strcmp(argv[1], "--validate-only") == 0) {
            OSStatus result = validateGame();
            printf("Original App Store signature: %d\n", (int)result);
            return result ? 2 : 0;
        }
        NSApplication *app = NSApplication.sharedApplication;
        TrainerDelegate *delegate = [TrainerDelegate new];
        app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        [app run];
    }
    return 0;
}
