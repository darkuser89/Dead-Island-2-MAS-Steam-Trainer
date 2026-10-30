// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import <Security/Security.h>
#import <os/log.h>
#import "OverlaySettings.h"
#import "GameEdition.h"
#import "LauncherView.h"
#import "OverlayShortcuts.h"
#import "SelectionSettings.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

static NSString *const uncutPath = @"/Applications/Dead Island 2 Uncut.app";
static NSString *editionPathKey(DI2GameEdition edition) { return [@"GamePath." stringByAppendingString:DI2EditionKey(edition)]; }
static NSString *editionPath(DI2GameEdition edition) {
    id saved=[NSUserDefaults.standardUserDefaults objectForKey:editionPathKey(edition)];
    return [saved isKindOfClass:NSString.class] && [saved isAbsolutePath] ? saved : DI2EditionDefaultPath(edition);
}

static OSStatus validateGame(NSString *path, DI2GameEdition edition) {
    SecStaticCodeRef code = NULL;
    SecRequirementRef requirement = NULL;
    OSStatus result = SecStaticCodeCreateWithPath((__bridge CFURLRef)[NSURL fileURLWithPath:path], kSecCSDefaultFlags, &code);
    NSString *identity=[NSString stringWithFormat:@"anchor apple generic and identifier \"%@\"",DI2EditionBundleID(edition)];
    if (!result) result = SecRequirementCreateWithString((__bridge CFStringRef)identity, kSecCSDefaultFlags, &requirement);
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
@property(nonatomic, strong) NSButton *startUncut;
@property(nonatomic, strong) NSRunningApplication *game;
@property(nonatomic, copy) NSString *token;
@property(nonatomic, strong) NSTimer *processTimer;
@property(nonatomic, strong) NSButton *showOverlay, *showBadge, *allowDragging, *mouseInput;
@property(nonatomic, strong) NSPopUpButton *position;
@property(nonatomic, copy) NSDictionary *options;
@property(nonatomic, strong) id settingsObserver, selectionObserver;
@property(nonatomic, copy) NSString *launchedProfile, *pendingSelectionMessage;
@property(nonatomic) BOOL launching;
@property(nonatomic) DI2GameEdition edition;
@property(nonatomic, strong) NSSegmentedControl *editionPicker;
@property(nonatomic, strong) DI2LauncherView *launcherView;
@property(nonatomic, strong) NSWindow *settingsWindow;
@property(nonatomic, strong) NSButton *chooseGame, *steamButton;
@property(nonatomic, strong) NSTextField *gameLocation;
@end

@implementation TrainerDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    self.options=DI2InitialOverlayOptions([NSUserDefaults.standardUserDefaults objectForKey:DI2OverlayPreferencesKey]);
    self.edition=DI2EditionForKey([NSUserDefaults.standardUserDefaults stringForKey:@"GameEdition"]);
    if (self.edition==DI2EditionUnknown) self.edition=DI2EditionMAS;
    NSMenu *menu = [NSMenu new];
    NSMenuItem *application = [NSMenuItem new];
    [menu addItem:application];
    NSMenu *applicationMenu = [NSMenu new];
    NSMenuItem *settings=[applicationMenu addItemWithTitle:@"Overlay-Einstellungen …" action:@selector(openSettings:) keyEquivalent:@","]; settings.target=self;
    [applicationMenu addItemWithTitle:@"Trainer beenden" action:@selector(terminate:) keyEquivalent:@"q"];
    application.submenu = applicationMenu;
    NSApp.mainMenu = menu;
    [self buildLauncher];
    [self refreshInstallation];
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    __weak TrainerDelegate *weakSelf = self;
    self.settingsObserver=[NSDistributedNotificationCenter.defaultCenter addObserverForName:DI2OverlayChangedNotification
        object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event) {
            TrainerDelegate *strongSelf=weakSelf;
            if (!strongSelf.game || strongSelf.game.terminated) return;
            NSDictionary *options=DI2OverlayMessageOptions(event.object,strongSelf.token,strongSelf.game.processIdentifier);
            if (!options) return;
            strongSelf.options=options;
            [NSUserDefaults.standardUserDefaults setObject:strongSelf.options forKey:DI2OverlayPreferencesKey];
            [strongSelf updateOverlayControls];
            strongSelf.status.stringValue=[strongSelf.options[@"visible"] boolValue]
                ? [NSString stringWithFormat:@"Trainer aktiv · Overlay sichtbar · %@ zum Verbergen.",DI2HotkeyAt(DI2HotkeyPanel).label]
                : [NSString stringWithFormat:@"Trainer aktiv · Overlay verborgen · Cheats bleiben an · %@ zum Anzeigen.",DI2HotkeyAt(DI2HotkeyPanel).label];
        }];
    self.selectionObserver=[NSDistributedNotificationCenter.defaultCenter addObserverForName:DI2SelectionChangedNotification
        object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event) {
            TrainerDelegate *owner=weakSelf;
            if (owner.launching) {
                // The first game report can arrive before NSWorkspace's completion.
                if ([event.object isKindOfClass:NSString.class] && [event.object length]<=16384)
                    owner.pendingSelectionMessage=event.object;
                return;
            }
            [owner receiveSelectionMessage:event.object];
        }];
}
- (void)receiveSelectionMessage:(id)message {
    if (!self.game || self.game.terminated) return;
    NSDictionary *selection=DI2SelectionMessageSelection(message,self.token,self.launchedProfile,self.game.processIdentifier);
    if (!selection) return;
    [NSUserDefaults.standardUserDefaults setObject:selection forKey:DI2SelectionPreferencesKey(self.launchedProfile)];
    [self updateSelectionHint];
}
- (void)updateSelectionHint {
    BOOL enabled=self.launcherView.restoreCheats.state==NSControlStateValueOn;
    id saved=[NSUserDefaults.standardUserDefaults objectForKey:DI2SelectionPreferencesKey(DI2EditionKey(self.edition))];
    NSString *hint=!enabled ? @"Cheats starten ohne gespeicherte Auswahl."
        : saved ? @"Gespeicherte Auswahl wird nach dem Laden aktiviert."
        : @"Noch keine gespeicherte Auswahl für diese Spielversion.";
    [self.launcherView showSelectionHint:hint];
}
- (void)changeSelectionRestore:(id)sender {
    (void)sender;
    [NSUserDefaults.standardUserDefaults setBool:self.launcherView.restoreCheats.state==NSControlStateValueOn forKey:DI2SelectionRestorePreferencesKey];
    [self updateSelectionHint];
}
- (void)buildLauncher {
    self.window=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,520,564)
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable
        backing:NSBackingStoreBuffered defer:NO];
    self.window.title=@"Dead Island 2 Trainer"; self.window.releasedWhenClosed=NO;
    self.window.titleVisibility=NSWindowTitleVisible; self.window.titlebarAppearsTransparent=NO;
    self.window.movableByWindowBackground=YES;
    self.window.opaque=YES; self.window.backgroundColor=NSColor.windowBackgroundColor;
    NSString *version=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"0.6.11";
    self.launcherView=[[DI2LauncherView alloc]initWithFrame:NSMakeRect(0,0,520,564) version:version];
    self.window.contentView=self.launcherView;
    self.editionPicker=self.launcherView.editionPicker; self.editionPicker.target=self; self.editionPicker.action=@selector(changeEdition:);
    self.chooseGame=self.launcherView.chooseGame; self.chooseGame.target=self; self.chooseGame.action=@selector(chooseGameApp:);
    self.steamButton=self.launcherView.steamButton; self.steamButton.target=self; self.steamButton.action=@selector(openSteam:);
    self.start=self.launcherView.start; self.start.target=self; self.start.action=@selector(startGame:);
    self.startUncut=self.launcherView.uncutStart; self.startUncut.target=self; self.startUncut.action=@selector(startUncutGame:);
    self.launcherView.settingsButton.target=self; self.launcherView.settingsButton.action=@selector(openSettings:);
    self.status=self.launcherView.status;
    id restore=[NSUserDefaults.standardUserDefaults objectForKey:DI2SelectionRestorePreferencesKey];
    self.launcherView.restoreCheats.state=(restore==nil || [restore boolValue]) ? NSControlStateValueOn : NSControlStateValueOff;
    self.launcherView.restoreCheats.target=self;self.launcherView.restoreCheats.action=@selector(changeSelectionRestore:);
    self.settingsWindow=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,620,426)
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
    self.settingsWindow.title=@"Overlay-Einstellungen"; self.settingsWindow.releasedWhenClosed=NO;
    self.settingsWindow.opaque=YES; self.settingsWindow.backgroundColor=NSColor.windowBackgroundColor;
    NSView *settingsContent=[[NSView alloc]initWithFrame:NSMakeRect(0,0,620,426)];
    self.settingsWindow.contentView=DI2LauncherSurface(settingsContent,16,YES);
    self.showOverlay=[NSButton checkboxWithTitle:@"Overlay anzeigen – beim Verbergen bleiben Cheats aktiv" target:self action:@selector(changeOverlayOptions:)];
    self.showBadge=[NSButton checkboxWithTitle:@"Beim Verbergen ein kleines Trainer-Symbol anzeigen" target:self action:@selector(changeOverlayOptions:)];
    self.mouseInput=[NSButton checkboxWithTitle:@"Maus im sichtbaren Overlay freigeben (beim Öffnen automatisch)" target:self action:@selector(changeOverlayOptions:)];
    self.allowDragging=[NSButton checkboxWithTitle:@"Overlay mit der Maus verschieben: Titelleiste ziehen" target:self action:@selector(changeOverlayOptions:)];
    self.position=[[NSPopUpButton alloc]initWithFrame:NSZeroRect pullsDown:NO];
    [self.position addItemsWithTitles:@[@"Oben links",@"Oben rechts",@"Unten links",@"Unten rechts",@"Mitte",@"Frei / letzte Position"]];
    NSArray *keys=@[@"top-left",@"top-right",@"bottom-left",@"bottom-right",@"center",@"free"];
    for(NSUInteger i=0;i<keys.count;i++)self.position.itemArray[i].representedObject=keys[i];
    self.position.target=self; self.position.action=@selector(changeOverlayOptions:);
    self.position.accessibilityLabel=@"Overlay-Position im Spielfenster";
    NSButton *reset=[NSButton buttonWithTitle:@"Zurücksetzen" target:self action:@selector(resetOverlayPosition:)];
    NSStackView *positionRow=[NSStackView stackViewWithViews:@[[NSTextField labelWithString:@"Position"],self.position,reset]]; positionRow.spacing=10;
    NSTextField *hint=[NSTextField wrappingLabelWithString:@"Anzeigeoptionen werden gespeichert und an die mit dieser Launcher-Sitzung gestartete Spielinstanz übertragen."];
    hint.font=[NSFont systemFontOfSize:11]; hint.textColor=NSColor.secondaryLabelColor;
    self.gameLocation=[NSTextField labelWithString:editionPath(self.edition)];
    self.gameLocation.font=[NSFont systemFontOfSize:10]; self.gameLocation.textColor=NSColor.secondaryLabelColor;
    self.gameLocation.lineBreakMode=NSLineBreakByTruncatingMiddle;
    NSTextField *hotkeyInfo=[NSTextField wrappingLabelWithString:[@"⌃ Control · ⌥ Option · ⇧ Umschalt · ⌘ Command\n" stringByAppendingString:DI2HotkeyConflictSummary()]];
    hotkeyInfo.font=[NSFont systemFontOfSize:11];hotkeyInfo.textColor=NSColor.secondaryLabelColor;
    NSButton *done=[NSButton buttonWithTitle:@"Fertig" target:self action:@selector(closeSettings:)]; done.keyEquivalent=@"\r";
    NSStackView *stack=[NSStackView stackViewWithViews:@[self.showOverlay,self.showBadge,self.mouseInput,self.allowDragging,positionRow,hint,hotkeyInfo,self.gameLocation,done]];
    stack.orientation=NSUserInterfaceLayoutOrientationVertical; stack.alignment=NSLayoutAttributeLeading; stack.spacing=15; stack.translatesAutoresizingMaskIntoConstraints=NO;
    [settingsContent addSubview:stack];
    for(NSTextField *label in @[hint,hotkeyInfo,self.gameLocation]){label.preferredMaxLayoutWidth=564;[label.widthAnchor constraintEqualToConstant:564].active=YES;}
    [NSLayoutConstraint activateConstraints:@[[stack.leadingAnchor constraintEqualToAnchor:settingsContent.leadingAnchor constant:28],[stack.trailingAnchor constraintEqualToAnchor:settingsContent.trailingAnchor constant:-28],[stack.topAnchor constraintEqualToAnchor:settingsContent.topAnchor constant:24]]];
    [self updateOverlayControls];
}
- (void)openSettings:(id)sender { (void)sender; if(!self.settingsWindow.isVisible)[self.settingsWindow center];[self.settingsWindow makeKeyAndOrderFront:nil]; }
- (void)closeSettings:(id)sender { (void)sender; [self.settingsWindow orderOut:nil]; }
- (void)refreshInstallation {
    [self updateSelectionHint];
    self.gameLocation.stringValue=editionPath(self.edition);self.gameLocation.toolTip=self.gameLocation.stringValue;
    BOOL running=self.game && !self.game.terminated;
    self.editionPicker.enabled=!running;self.chooseGame.enabled=!running;
    self.steamButton.enabled=self.edition==DI2EditionSteam;
    NSError *error=nil;NSDictionary *installation=DI2InspectGame(editionPath(self.edition),self.edition,&error);
    [self.launcherView showEdition:self.edition found:installation!=nil running:running uncutAvailable:uncutAvailable() path:editionPath(self.edition)];
    if (!running) self.status.stringValue=installation
        ? @""
        : error.localizedDescription;
}
- (void)changeEdition:(id)sender {
    (void)sender;
    self.edition=self.editionPicker.selectedSegment==1 ? DI2EditionSteam : DI2EditionMAS;
    [NSUserDefaults.standardUserDefaults setObject:DI2EditionKey(self.edition) forKey:@"GameEdition"];
    [self refreshInstallation];
}
- (void)chooseGameApp:(id)sender {
    (void)sender;NSOpenPanel *panel=[NSOpenPanel openPanel];panel.allowedContentTypes=@[UTTypeApplicationBundle];
    panel.canChooseFiles=YES;panel.canChooseDirectories=NO;panel.allowsMultipleSelection=NO;
    panel.message=[NSString stringWithFormat:@"Die %@-Version von Dead Island 2 auswählen.",DI2EditionTitle(self.edition)];
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response!=NSModalResponseOK) return;
        NSError *error=nil;NSDictionary *info=DI2InspectGame(panel.URL.path,self.edition,&error);
        if (!info) { self.status.stringValue=error.localizedDescription; return; }
        [NSUserDefaults.standardUserDefaults setObject:info[@"path"] forKey:editionPathKey(self.edition)];
        [self refreshInstallation];
    }];
}
- (void)openSteam:(id)sender {
    (void)sender;NSURL *url=[NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:@"com.valvesoftware.steam"];
    if (!url) { self.status.stringValue=@"Steam wurde nicht gefunden. Bitte den Steam-Client öffnen und anmelden."; return; }
    NSWorkspaceOpenConfiguration *configuration=NSWorkspaceOpenConfiguration.configuration;
    [NSWorkspace.sharedWorkspace openApplicationAtURL:url configuration:configuration completionHandler:^(NSRunningApplication *app,NSError *error) {
        dispatch_async(dispatch_get_main_queue(),^{
            self.status.stringValue=error || !app ? @"Steam konnte nicht geöffnet werden. Bitte den Client selbst starten."
                : @"Nach der Anmeldung in Steam erneut „Spiel mit Trainer starten“ wählen.";
        });
    }];
}
- (void)updateOverlayControls {
    self.showOverlay.state=[self.options[@"visible"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
    self.showBadge.state=[self.options[@"badge"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
    self.mouseInput.state=[self.options[@"mouse"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
    self.allowDragging.state=[self.options[@"draggable"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
    for (NSMenuItem *item in self.position.itemArray) if ([item.representedObject isEqual:self.options[@"position"]]) [self.position selectItem:item];
}
- (void)changeOverlayOptions:(id)sender {
    (void)sender;
    NSMutableDictionary *options=[self.options mutableCopy];
    options[@"visible"]=@(self.showOverlay.state==NSControlStateValueOn);
    options[@"badge"]=@(self.showBadge.state==NSControlStateValueOn);
    options[@"mouse"]=@(self.mouseInput.state==NSControlStateValueOn);
    options[@"draggable"]=@(self.allowDragging.state==NSControlStateValueOn);
    options[@"position"]=self.position.selectedItem.representedObject ?: @"top-left";
    self.options=DI2NormalizeOverlayOptions(options);
    [NSUserDefaults.standardUserDefaults setObject:self.options forKey:DI2OverlayPreferencesKey];
    if (self.game && !self.game.terminated && self.token.length) {
        @try {
            [NSDistributedNotificationCenter.defaultCenter postNotificationName:DI2OverlaySettingsNotification
                object:DI2OverlayMessage(self.options,self.token,self.game.processIdentifier) userInfo:nil deliverImmediately:YES];
            self.status.stringValue=@"Overlay-Einstellungen gesendet; Rückmeldung des Spiels wird erwartet. Gespeichert für den nächsten Start.";
        } @catch (NSException *exception) {
            (void)exception; self.status.stringValue=@"Einstellungen gespeichert. Live-Übernahme nicht verfügbar; gilt beim nächsten Trainer-Start.";
        }
    } else self.status.stringValue=[NSString stringWithFormat:@"Overlay-Einstellungen gespeichert. %@ zeigt das verborgene Overlay wieder an.",DI2HotkeyAt(DI2HotkeyPanel).label];
}
- (void)resetOverlayPosition:(id)sender {
    (void)sender;
    NSMutableDictionary *options=[self.options mutableCopy]; options[@"x"]=@0; options[@"y"]=@0;
    self.options=options; [self.position selectItemAtIndex:0]; [self changeOverlayOptions:nil];
}
- (void)startGame:(id)sender { (void)sender; [self launchGameWithUncut:NO]; }
- (void)startUncutGame:(id)sender { (void)sender; [self launchGameWithUncut:YES]; }
- (void)launchGameWithUncut:(BOOL)useUncut {
    if(useUncut && self.edition!=DI2EditionMAS) { self.status.stringValue=@"Der zusätzliche Uncut-Helfer ist nur für die Mac-App-Store-Version vorgesehen."; return; }
    NSError *error=nil;NSDictionary *installation=DI2InspectGame(editionPath(self.edition),self.edition,&error);
    if (!installation) { self.status.stringValue=error.localizedDescription; return; }
    NSString *gamePath=installation[@"path"];
    for (NSRunningApplication *running in NSWorkspace.sharedWorkspace.runningApplications) {
        if ([running.bundleIdentifier isEqualToString:DI2EditionBundleID(DI2EditionMAS)] || [running.bundleIdentifier isEqualToString:DI2EditionBundleID(DI2EditionSteam)]
            || [running.bundleURL.URLByResolvingSymlinksInPath.path isEqualToString:gamePath]) {
            self.status.stringValue = @"Bitte die laufende Spielinstanz regulär beenden und danach die gewünschte Version mit diesem Trainer starten.";
            return;
        }
    }
    OSStatus validity = validateGame(gamePath,self.edition);
    if (validity) { self.status.stringValue = [NSString stringWithFormat:@"Original-%@-Signatur nicht bestätigt (Fehler %d).",DI2EditionTitle(self.edition),(int)validity]; return; }
    if (self.edition==DI2EditionSteam && ![NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.valvesoftware.steam"].count) {
        [self openSteam:nil]; return;
    }
    NSString *library = [NSBundle.mainBundle pathForResource:@"TrainerOverlay" ofType:@"dylib"];
    if (!library) { self.status.stringValue = @"Das Overlay-Modul fehlt."; return; }
    NSMutableArray *libraries = [NSMutableArray arrayWithObject:library];
    if (useUncut) {
        if (!uncutAvailable()) { self.status.stringValue = @"Der gewählte vorhandene Uncut-Starthelfer ist nicht verfügbar."; return; }
        [libraries addObject:[uncutPath stringByAppendingPathComponent:@"Contents/Resources/RuntimeIdentity.dylib"]];
    }
    self.options=DI2InitialOverlayOptions(self.options);
    [self updateOverlayControls];
    self.token = NSUUID.UUID.UUIDString;
    self.launchedProfile=DI2EditionKey(self.edition);
    id selection=self.launcherView.restoreCheats.state==NSControlStateValueOn
        ? [NSUserDefaults.standardUserDefaults objectForKey:DI2SelectionPreferencesKey(self.launchedProfile)] : nil;
    NSWorkspaceOpenConfiguration *configuration = NSWorkspaceOpenConfiguration.configuration;
    configuration.activates = YES;
    configuration.createsNewApplicationInstance = YES;
    NSMutableDictionary *environment=[@{
        @"DYLD_INSERT_LIBRARIES": [libraries componentsJoinedByString:@":"],
        @"DI2_TRAINER_TARGET": [gamePath stringByAppendingPathComponent:@"Contents/MacOS/DeadIsland2"],
        @"DI2_TRAINER_SESSION": self.token,
        @"DI2_TRAINER_EDITION":DI2EditionKey(self.edition),
        @"DI2_TRAINER_OVERLAY_OPTIONS": DI2EncodeOverlayOptions(self.options),
        @"DI2_TRAINER_CHEAT_SELECTION": DI2EncodeCheatSelection(selection)
    } mutableCopy];
    if (self.edition==DI2EditionSteam) { environment[@"SteamAppId"]=@"934700";environment[@"SteamGameId"]=@"934700"; }
    configuration.environment=environment;
    self.start.enabled = NO; self.startUncut.enabled=NO;
    self.editionPicker.enabled=NO;self.chooseGame.enabled=NO;
    self.status.stringValue = @"Spielstart wird angefordert …";
    self.launching=YES;self.pendingSelectionMessage=nil;
    [NSWorkspace.sharedWorkspace openApplicationAtURL:[NSURL fileURLWithPath:gamePath]
        configuration:configuration completionHandler:^(NSRunningApplication *application, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.launching=NO;
                if (error || !application) {
                    self.pendingSelectionMessage=nil;
                    [self refreshInstallation];
                    self.status.stringValue = [NSString stringWithFormat:@"Spielstart fehlgeschlagen: %@", error.localizedDescription ?: @"Kein Prozess gestartet."];
                    return;
                }
                self.game = application;
                [self receiveSelectionMessage:self.pendingSelectionMessage];self.pendingSelectionMessage=nil;
                [self refreshInstallation];
                self.status.stringValue = [NSString stringWithFormat:@"Spiel gestartet · PID %d · Overlay %@ · %@", application.processIdentifier,[self.options[@"visible"] boolValue] ? @"sichtbar" : @"verborgen",DI2HotkeyAt(DI2HotkeyPanel).label];
                [self.processTimer invalidate];
                self.processTimer = [NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer *timer) {
                    if (self.game.terminated) {
                        [timer invalidate]; [self refreshInstallation];
                        self.status.stringValue = @"Spiel beendet. Bereit für einen neuen Start.";
                    }
                }];
            });
        }];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application {
    (void)application;
    // Keep receiving placement changes while the game is running. The Dock
    // icon reopens settings; an explicit Quit still leaves gameplay running.
    return !self.game || self.game.terminated;
}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)application hasVisibleWindows:(BOOL)visible {
    (void)application;
    if (!visible) [self.window makeKeyAndOrderFront:nil];
    return YES;
}
- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    if (self.settingsObserver) [NSDistributedNotificationCenter.defaultCenter removeObserver:self.settingsObserver];
    if (self.selectionObserver) [NSDistributedNotificationCenter.defaultCenter removeObserver:self.selectionObserver];
    [self.processTimer invalidate];
}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if ((argc==2 || argc==3) && strcmp(argv[1], "--validate-only") == 0) {
            DI2GameEdition edition=argc==2 ? DI2EditionMAS : DI2EditionForKey([NSString stringWithUTF8String:argv[2]]);
            NSError *error=nil;NSDictionary *info=DI2InspectGame(editionPath(edition),edition,&error);
            if (!info) { fprintf(stderr,"Installation check failed: %s\n",error.localizedDescription.UTF8String); return 2; }
            OSStatus result = validateGame(info[@"path"],edition);
            printf("Original %s signature: %d\n", DI2EditionTitle(edition).UTF8String,(int)result);
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
