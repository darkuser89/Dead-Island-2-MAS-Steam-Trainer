// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import <Security/Security.h>
#import <os/log.h>
#import "OverlaySettings.h"
#import "GameEdition.h"
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
@property(nonatomic, strong) NSButton *uncut;
@property(nonatomic, strong) NSRunningApplication *game;
@property(nonatomic, copy) NSString *token;
@property(nonatomic, strong) NSTimer *processTimer;
@property(nonatomic, strong) NSButton *showOverlay, *showBadge, *allowDragging, *mouseInput;
@property(nonatomic, strong) NSPopUpButton *position;
@property(nonatomic, copy) NSDictionary *options;
@property(nonatomic, strong) id settingsObserver;
@property(nonatomic) DI2GameEdition edition;
@property(nonatomic, strong) NSPopUpButton *editionPicker;
@property(nonatomic, strong) NSButton *chooseGame, *steamButton;
@property(nonatomic, strong) NSTextField *gameLocation;
@property(nonatomic) BOOL masUncutWanted;
@end

@implementation TrainerDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    self.options=DI2NormalizeOverlayOptions([NSUserDefaults.standardUserDefaults objectForKey:DI2OverlayPreferencesKey]);
    self.edition=DI2EditionForKey([NSUserDefaults.standardUserDefaults stringForKey:@"GameEdition"]);
    if (self.edition==DI2EditionUnknown) self.edition=DI2EditionMAS;
    NSMenu *menu = [NSMenu new];
    NSMenuItem *application = [NSMenuItem new];
    [menu addItem:application];
    NSMenu *applicationMenu = [NSMenu new];
    [applicationMenu addItemWithTitle:@"Trainer beenden" action:@selector(terminate:) keyEquivalent:@"q"];
    application.submenu = applicationMenu;
    NSApp.mainMenu = menu;
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 620, 660)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable
        backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"Dead Island 2 Trainer";
    self.window.releasedWhenClosed = NO;
    NSTextField *title = [NSTextField labelWithString:@"Dead Island 2 Trainer"];
    title.font = [NSFont boldSystemFontOfSize:26];
    NSTextField *subtitle = [NSTextField wrappingLabelWithString:@"Version 0.6.3 · Steam und Mac App Store · Apple Silicon"];
    self.editionPicker=[[NSPopUpButton alloc]initWithFrame:NSZeroRect pullsDown:NO];
    [self.editionPicker addItemsWithTitles:@[@"Mac App Store",@"Steam"]];
    [self.editionPicker selectItemAtIndex:self.edition==DI2EditionSteam ? 1 : 0];
    self.editionPicker.target=self; self.editionPicker.action=@selector(changeEdition:);
    self.editionPicker.accessibilityLabel=@"Spiele-Version";
    self.chooseGame=[NSButton buttonWithTitle:@"Spiele-App wählen …" target:self action:@selector(chooseGameApp:)];
    self.steamButton=[NSButton buttonWithTitle:@"Steam öffnen" target:self action:@selector(openSteam:)];
    NSStackView *editionRow=[NSStackView stackViewWithViews:@[[NSTextField labelWithString:@"Spiel auswählen"],self.editionPicker,self.chooseGame,self.steamButton]];
    editionRow.spacing=10;
    self.gameLocation=[NSTextField labelWithString:editionPath(self.edition)];
    self.gameLocation.font=[NSFont systemFontOfSize:11];self.gameLocation.lineBreakMode=NSLineBreakByTruncatingMiddle;
    self.gameLocation.textColor=NSColor.secondaryLabelColor;
    NSTextField *details = [NSTextField wrappingLabelWithString:@"⌘ + ^ öffnet das Overlay mit freier Maus; erneut drücken oder Esc gibt die Spielsteuerung zurück. Aktive Cheats bleiben an.\nF1 Gottmodus · F2 Ausdauer · F3 Reserve · F4/F5 Geld\nF6–F11 weitere Schalter · F12 alles aus · Weitere Tasten: ⇧/⌥ + F-Taste.\nNur Einzelspieler. Geld, XP und ergänzte Gegenstände werden vom Spiel gespeichert."];
    details.font = [NSFont systemFontOfSize:13];
    self.uncut = [NSButton checkboxWithTitle:@"Vorhandenen Uncut-Starthelfer mitverwenden" target:nil action:nil];
    self.uncut.enabled = uncutAvailable();
    self.uncut.state = self.uncut.enabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.masUncutWanted=self.uncut.enabled;
    self.showOverlay=[NSButton checkboxWithTitle:@"Overlay anzeigen – Trainer bleibt beim Verbergen aktiv" target:self action:@selector(changeOverlayOptions:)];
    self.showBadge=[NSButton checkboxWithTitle:@"Beim Verbergen ein kleines Trainer-Symbol anzeigen" target:self action:@selector(changeOverlayOptions:)];
    self.allowDragging=[NSButton checkboxWithTitle:@"Mit der Maus verschiebbar: Titelleiste im Overlay ziehen" target:self action:@selector(changeOverlayOptions:)];
    self.mouseInput=[NSButton checkboxWithTitle:@"Maus im sichtbaren Overlay freigeben (⌘⌥ + ^ zum Umschalten)" target:self action:@selector(changeOverlayOptions:)];
    self.position=[[NSPopUpButton alloc]initWithFrame:NSZeroRect pullsDown:NO];
    NSArray *positionNames=@[@"Oben links",@"Oben rechts",@"Unten links",@"Unten rechts",@"Mitte",@"Frei / letzte gezogene Position"];
    NSArray *positionKeys=@[@"top-left",@"top-right",@"bottom-left",@"bottom-right",@"center",@"free"];
    [self.position addItemsWithTitles:positionNames];
    for (NSUInteger i=0;i<positionKeys.count;i++) self.position.itemArray[i].representedObject=positionKeys[i];
    self.position.target=self; self.position.action=@selector(changeOverlayOptions:);
    self.position.accessibilityLabel=@"Overlay-Position im Spielfenster";
    NSButton *reset=[NSButton buttonWithTitle:@"Position zurücksetzen" target:self action:@selector(resetOverlayPosition:)];
    NSStackView *positionRow=[NSStackView stackViewWithViews:@[[NSTextField labelWithString:@"Position"],self.position,reset]];
    positionRow.spacing=10;
    NSTextField *settingsTitle=[NSTextField labelWithString:@"Overlay-Einstellungen"];
    settingsTitle.font=[NSFont boldSystemFontOfSize:14];
    NSTextField *settingsHint=[NSTextField wrappingLabelWithString:@"Position und Größe werden gespeichert. Änderungen gelten auch für eine mit dieser Launcher-Sitzung gestartete Spielinstanz."];
    settingsHint.font=[NSFont systemFontOfSize:11]; settingsHint.textColor=NSColor.secondaryLabelColor;
    [self updateOverlayControls];
    self.start = [NSButton buttonWithTitle:@"Spiel mit Trainer starten" target:self action:@selector(startGame:)];
    self.start.bezelStyle = NSBezelStyleRounded;
    self.start.keyEquivalent = @"\r";
    self.status = [NSTextField wrappingLabelWithString:@"Bereit. Spiele-Dateien werden nicht verändert."];
    self.status.font = [NSFont systemFontOfSize:12];
    self.status.textColor = NSColor.secondaryLabelColor;
    NSStackView *stack = [NSStackView stackViewWithViews:@[title,subtitle,editionRow,self.gameLocation,details,settingsTitle,self.showOverlay,self.showBadge,self.mouseInput,self.allowDragging,positionRow,settingsHint,self.uncut,self.start,self.status]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 13;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.window.contentView addSubview:stack];
    for (NSTextField *text in @[details,settingsHint,self.status,self.gameLocation]) {
        text.preferredMaxLayoutWidth=564;
        [text.widthAnchor constraintEqualToConstant:564].active=YES;
    }
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.window.contentView.leadingAnchor constant:28],
        [stack.trailingAnchor constraintEqualToAnchor:self.window.contentView.trailingAnchor constant:-28],
        [stack.topAnchor constraintEqualToAnchor:self.window.contentView.topAnchor constant:24]
    ]];
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
                ? @"Trainer aktiv · Overlay sichtbar · ⌘ + ^ zum Verbergen."
                : @"Trainer aktiv · Overlay verborgen · Cheats/F-Tasten bleiben an · ⌘ + ^ zum Anzeigen.";
        }];
}
- (void)refreshInstallation {
    self.gameLocation.stringValue=editionPath(self.edition);self.gameLocation.toolTip=self.gameLocation.stringValue;
    BOOL running=self.game && !self.game.terminated;
    self.editionPicker.enabled=!running;self.chooseGame.enabled=!running;
    self.steamButton.enabled=self.edition==DI2EditionSteam;
    self.uncut.toolTip=@"Der zusätzliche Uncut-Starthelfer wird ausschließlich bei der Mac-App-Store-Version mitgeladen.";
    self.uncut.enabled=self.edition==DI2EditionMAS && uncutAvailable();
    self.uncut.state=self.uncut.enabled && self.masUncutWanted ? NSControlStateValueOn : NSControlStateValueOff;
    NSError *error=nil;NSDictionary *installation=DI2InspectGame(editionPath(self.edition),self.edition,&error);
    self.start.enabled=!running && installation!=nil;
    if (!running) self.status.stringValue=installation
        ? [NSString stringWithFormat:@"%@ %@ erkannt. Beide Spiele-Apps bleiben unverändert.",DI2EditionTitle(self.edition),installation[@"version"]]
        : error.localizedDescription;
}
- (void)changeEdition:(id)sender {
    (void)sender;
    if (self.edition==DI2EditionMAS) self.masUncutWanted=self.uncut.state==NSControlStateValueOn;
    self.edition=self.editionPicker.indexOfSelectedItem==1 ? DI2EditionSteam : DI2EditionMAS;
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
    } else self.status.stringValue=@"Overlay-Einstellungen gespeichert. ⌘ + ^ zeigt auch ein vollständig verborgenes Overlay wieder an.";
}
- (void)resetOverlayPosition:(id)sender {
    (void)sender;
    NSMutableDictionary *options=[self.options mutableCopy]; options[@"x"]=@0; options[@"y"]=@0;
    self.options=options; [self.position selectItemAtIndex:0]; [self changeOverlayOptions:nil];
}
- (void)startGame:(id)sender {
    (void)sender;
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
    if (self.edition==DI2EditionMAS && self.uncut.state == NSControlStateValueOn) {
        if (!uncutAvailable()) { self.status.stringValue = @"Der gewählte vorhandene Uncut-Starthelfer ist nicht verfügbar."; return; }
        [libraries addObject:[uncutPath stringByAppendingPathComponent:@"Contents/Resources/RuntimeIdentity.dylib"]];
    }
    self.token = NSUUID.UUID.UUIDString;
    NSWorkspaceOpenConfiguration *configuration = NSWorkspaceOpenConfiguration.configuration;
    configuration.activates = YES;
    configuration.createsNewApplicationInstance = YES;
    NSMutableDictionary *environment=[@{
        @"DYLD_INSERT_LIBRARIES": [libraries componentsJoinedByString:@":"],
        @"DI2_TRAINER_TARGET": [gamePath stringByAppendingPathComponent:@"Contents/MacOS/DeadIsland2"],
        @"DI2_TRAINER_SESSION": self.token,
        @"DI2_TRAINER_EDITION":DI2EditionKey(self.edition),
        @"DI2_TRAINER_OVERLAY_OPTIONS": DI2EncodeOverlayOptions(self.options)
    } mutableCopy];
    if (self.edition==DI2EditionSteam) { environment[@"SteamAppId"]=@"934700";environment[@"SteamGameId"]=@"934700"; }
    configuration.environment=environment;
    self.start.enabled = NO;
    self.editionPicker.enabled=NO;self.chooseGame.enabled=NO;
    self.status.stringValue = @"Spielstart wird angefordert …";
    [NSWorkspace.sharedWorkspace openApplicationAtURL:[NSURL fileURLWithPath:gamePath]
        configuration:configuration completionHandler:^(NSRunningApplication *application, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error || !application) {
                    [self refreshInstallation];
                    self.status.stringValue = [NSString stringWithFormat:@"Spielstart fehlgeschlagen: %@", error.localizedDescription ?: @"Kein Prozess gestartet."];
                    return;
                }
                self.game = application;
                self.status.stringValue = [NSString stringWithFormat:@"Spiel gestartet · PID %d · Overlay %@ · ⌘ + ^", application.processIdentifier,[self.options[@"visible"] boolValue] ? @"sichtbar" : @"verborgen"];
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
