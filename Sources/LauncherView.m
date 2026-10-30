// SPDX-License-Identifier: GPL-3.0-only
#import "LauncherView.h"
#import <QuartzCore/QuartzCore.h>
#import "OverlayShortcuts.h"
#import "TrainerMaterial.h"

static NSColor *accent(void) { return [NSColor colorWithRed:1 green:0.40 blue:0.15 alpha:1]; }
static NSTextField *text(NSString *value, CGFloat size, NSFontWeight weight, NSColor *color) {
    NSTextField *label=[NSTextField labelWithString:value];
    label.font=[NSFont systemFontOfSize:size weight:weight]; label.textColor=color;
    return label;
}
@interface DI2LauncherContent : NSView
@end
@implementation DI2LauncherContent
- (BOOL)isFlipped { return YES; }
@end

NSView *DI2LauncherSurface(NSView *content, CGFloat radius, BOOL glassEnabled) {
    DI2TrainerMaterial *surface=[[DI2TrainerMaterial alloc]initWithContentView:content cornerRadius:radius];
    surface.liquidGlassEnabled=glassEnabled;
    if([content isKindOfClass:NSButton.class])surface.tintColor=((NSButton *)content).bezelColor;
    return surface;
}

static NSButton *launchButton(NSString *title, NSColor *tint, BOOL glass) {
    NSButton *button=[NSButton buttonWithTitle:title target:nil action:NULL];
    button.controlSize=NSControlSizeLarge; button.font=[NSFont systemFontOfSize:16 weight:NSFontWeightSemibold];
    button.bezelStyle=NSBezelStyleRounded;
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 260000
    if (@available(macOS 26.0,*)) {
        if(glass) {
            button.bordered=NO;
            button.contentTintColor=NSColor.whiteColor;
            button.controlSize=NSControlSizeExtraLarge;
        }
    }
#else
    (void)glass;
#endif
    button.bezelColor=tint;
    button.image=[NSImage imageWithSystemSymbolName:@"play.fill" accessibilityDescription:nil];
    button.imagePosition=NSImageLeading; button.imageHugsTitle=YES;
    button.accessibilityLabel=title;
    return button;
}

@implementation DI2LauncherView {
    NSView *_card, *_cardContent, *_content, *_group, *_startSurface, *_uncutSurface;
    BOOL _usesLiquidGlass;
    NSTextField *_eyebrow, *_heading, *_version, *_gameTitle, *_hint;
    NSArray<NSTextField *> *_shortcuts;
}
- (BOOL)isFlipped { return YES; }
- (BOOL)usesLiquidGlass {return _usesLiquidGlass && ((DI2TrainerMaterial *)_card).materialMode==DI2TrainerMaterialLiquidGlass;}
- (void)drawRect:(NSRect)dirty {(void)dirty;[NSColor.windowBackgroundColor setFill];NSRectFill(self.bounds);}
- (instancetype)initWithFrame:(NSRect)frame version:(NSString *)version {
    return [self initWithFrame:frame version:version glassEnabled:YES];
}
- (instancetype)initWithFrame:(NSRect)frame version:(NSString *)version glassEnabled:(BOOL)enabled {
    if(!(self=[super initWithFrame:frame]))return nil;
    self.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
    _content=[[DI2LauncherContent alloc]initWithFrame:self.bounds];
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 260000
    if (@available(macOS 26.0,*)) {
        if(enabled) {
            NSGlassEffectContainerView *container=[[NSGlassEffectContainerView alloc]initWithFrame:self.bounds];
            container.contentView=_content; _group=container; _usesLiquidGlass=YES;
        }
    }
#else
    (void)enabled;
#endif
    if(!_group)_group=_content;
    _group.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable; [self addSubview:_group];
    _eyebrow=text(@"TRAINER",12,NSFontWeightBold,accent());
    _heading=text(@"Dead Island 2",30,NSFontWeightBold,NSColor.labelColor);
    _version=text([NSString stringWithFormat:@"v%@",version],10,NSFontWeightMedium,NSColor.secondaryLabelColor);
    _settingsButton=[NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"gearshape" accessibilityDescription:@"Overlay-Einstellungen"] target:nil action:NULL];
    _settingsButton.bordered=NO; _settingsButton.contentTintColor=NSColor.secondaryLabelColor;
    _settingsButton.toolTip=@"Overlay-Einstellungen";
    _settingsButton.accessibilityLabel=@"Overlay-Einstellungen";
    _editionPicker=[NSSegmentedControl segmentedControlWithLabels:@[@"Mac App Store",@"Steam"] trackingMode:NSSegmentSwitchTrackingSelectOne target:nil action:NULL];
    _editionPicker.segmentStyle=NSSegmentStyleRounded; _editionPicker.controlSize=NSControlSizeLarge;
    _editionPicker.font=[NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
    _editionPicker.accessibilityLabel=@"Spiele-Version";
    _cardContent=[[DI2LauncherContent alloc]initWithFrame:NSMakeRect(0,0,460,90)];
    _card=DI2LauncherSurface(_cardContent,18,_usesLiquidGlass);
    _gameIcon=[[NSImageView alloc]initWithFrame:NSZeroRect]; _gameIcon.imageScaling=NSImageScaleProportionallyUpOrDown;
    _gameIcon.wantsLayer=YES; _gameIcon.layer.cornerRadius=9; _gameIcon.layer.masksToBounds=YES;
    _gameIcon.accessibilityLabel=@"Dead Island 2 Spielsymbol";
    _gameTitle=text(@"Dead Island 2",18,NSFontWeightSemibold,NSColor.labelColor);
    _installationStatus=text(@"Spiel auswählen",13,NSFontWeightMedium,NSColor.secondaryLabelColor);
    _chooseGame=[NSButton buttonWithTitle:@"Ändern …" target:nil action:NULL]; _chooseGame.bordered=NO;
    _chooseGame.font=[NSFont systemFontOfSize:13]; _chooseGame.contentTintColor=NSColor.secondaryLabelColor;
    _chooseGame.accessibilityLabel=@"Spiele-App ändern";
    _steamButton=[NSButton buttonWithTitle:@"Steam öffnen" target:nil action:NULL]; _steamButton.bordered=NO;
    _steamButton.font=[NSFont systemFontOfSize:10]; _steamButton.contentTintColor=NSColor.secondaryLabelColor;
    for(NSView *child in @[_gameIcon,_gameTitle,_installationStatus,_chooseGame,_steamButton])[_cardContent addSubview:child];
    _start=launchButton(@"Spiel mit Trainer starten",accent(),_usesLiquidGlass); _start.keyEquivalent=@"\r";
    _uncutStart=launchButton(@"Spiel Uncut mit Trainer starten",[NSColor colorWithRed:0.88 green:0.19 blue:0.16 alpha:1],_usesLiquidGlass);
    _startSurface=_usesLiquidGlass ? DI2LauncherSurface(_start,27,YES) : _start;
    _uncutSurface=_usesLiquidGlass ? DI2LauncherSurface(_uncutStart,27,YES) : _uncutStart;
    _restoreCheats=[NSButton checkboxWithTitle:@"Cheat-Auswahl beim nächsten Start laden" target:nil action:NULL];
    _restoreCheats.font=[NSFont systemFontOfSize:12];
    _restoreCheats.toolTip=@"Schalter und Zahlenwerte werden getrennt für Mac App Store und Steam gespeichert. Einmalaktionen laufen nie automatisch.";
    _hint=text([NSString stringWithFormat:@"%@ öffnet das Overlay mit Mausbedienung.",DI2HotkeyAt(DI2HotkeyPanel).label],12,NSFontWeightRegular,NSColor.secondaryLabelColor); _hint.alignment=NSTextAlignmentCenter;
    _status=[NSTextField wrappingLabelWithString:@""]; _status.font=[NSFont systemFontOfSize:11];
    _status.textColor=NSColor.secondaryLabelColor; _status.alignment=NSTextAlignmentCenter; _status.maximumNumberOfLines=2;
    _shortcuts=@[text([DI2HotkeyAt(DI2HotkeyPanel).label stringByAppendingString:@"  Overlay"],11,NSFontWeightSemibold,NSColor.secondaryLabelColor),text([DI2HotkeyAt(DI2HotkeyMouse).label stringByAppendingString:@"  Maus"],11,NSFontWeightSemibold,NSColor.secondaryLabelColor),text([DI2HotkeyReadableLabel(DI2HotkeyDisableAll) stringByAppendingString:@" · Aus"],11,NSFontWeightSemibold,NSColor.secondaryLabelColor)];
    for(NSTextField *shortcut in _shortcuts)shortcut.alignment=NSTextAlignmentCenter;
    for(NSView *child in @[_eyebrow,_heading,_version,_settingsButton,_editionPicker,_card,_startSurface,_uncutSurface,_restoreCheats,_hint,_status])[_content addSubview:child];
    for(NSView *child in _shortcuts)[_content addSubview:child];
    [self layout]; return self;
}
- (void)layout {
    [super layout]; CGFloat width=NSWidth(self.bounds),margin=30,content=width-2*margin;
    _eyebrow.frame=NSMakeRect(margin,54,180,18); _heading.frame=NSMakeRect(margin,77,content-50,42);
    _version.frame=NSMakeRect(width-margin-40,90,40,16); _version.alignment=NSTextAlignmentRight;
    _settingsButton.frame=NSMakeRect(width-margin-26,45,28,28);
    _editionPicker.frame=NSMakeRect(margin,142,content,30);
    for(NSInteger i=0;i<2;i++)[_editionPicker setWidth:(content-4)/2 forSegment:i];
    _card.frame=NSMakeRect(margin,192,content,90);
    _gameIcon.frame=NSMakeRect(18,22,46,46); _gameTitle.frame=NSMakeRect(82,21,content-190,26);
    _installationStatus.frame=NSMakeRect(82,49,content-190,21);
    _chooseGame.frame=NSMakeRect(content-94,27,80,25); _steamButton.frame=NSMakeRect(content-107,58,94,18);
    _startSurface.frame=NSMakeRect(margin,302,content,54); _uncutSurface.frame=NSMakeRect(margin,368,content,54);
    _restoreCheats.frame=NSMakeRect(margin,434,content,22);
    _hint.frame=NSMakeRect(margin,463,content,20);
    _status.frame=NSMakeRect(margin,487,content,31);
    CGFloat part=content/3;
    for(NSUInteger i=0;i<_shortcuts.count;i++)_shortcuts[i].frame=NSMakeRect(margin+i*part,521,part,18);
}
- (void)showSelectionHint:(NSString *)hint { _hint.stringValue=hint; }
- (void)showEdition:(DI2GameEdition)edition found:(BOOL)found running:(BOOL)running uncutAvailable:(BOOL)helper path:(NSString *)path {
    _editionPicker.selectedSegment=edition==DI2EditionSteam ? 1 : 0;
    _editionPicker.enabled=!running; _chooseGame.enabled=!running;
    _steamButton.hidden=edition!=DI2EditionSteam;
    _start.enabled=found && !running; _start.title=running ? @"Spiel läuft" : @"Spiel mit Trainer starten";
    _uncutStart.enabled=found && !running && edition==DI2EditionMAS && helper;
    _startSurface.alphaValue=_start.enabled ? 1 : 0.5;
    _uncutSurface.alphaValue=_uncutStart.enabled ? 1 : 0.5;
    _uncutStart.toolTip=edition!=DI2EditionMAS ? @"Der zusätzliche Uncut-Starthelfer ist nur für die Mac-App-Store-Version vorgesehen."
        : !helper ? @"Der separate Helfer /Applications/Dead Island 2 Uncut.app wird benötigt."
        : @"Startet die Mac-App-Store-Version mit Trainer und vorhandenem externen Uncut-Helfer. Spiele-Dateien bleiben unverändert.";
    _installationStatus.stringValue=running ? @"Trainer aktiv" : found ? @"Spiel gefunden" : @"Nicht gefunden";
    _installationStatus.textColor=found ? [NSColor colorWithRed:0.35 green:0.80 blue:0.54 alpha:1] : accent();
    _card.toolTip=[NSString stringWithFormat:@"%@\n%@",DI2EditionTitle(edition),path ?: @""];
    _gameIcon.image=found ? [NSWorkspace.sharedWorkspace iconForFile:path] : [NSImage imageWithSystemSymbolName:@"gamecontroller" accessibilityDescription:@"Spiel auswählen"];
    [_start setNeedsDisplay:YES]; [_uncutStart setNeedsDisplay:YES];
}
@end
