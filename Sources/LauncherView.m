// SPDX-License-Identifier: GPL-3.0-only
#import "LauncherView.h"
#import <QuartzCore/QuartzCore.h>

static NSColor *accent(void) { return [NSColor colorWithRed:1 green:0.40 blue:0.15 alpha:1]; }
static NSTextField *text(NSString *value, CGFloat size, NSFontWeight weight, NSColor *color) {
    NSTextField *label=[NSTextField labelWithString:value];
    label.font=[NSFont systemFontOfSize:size weight:weight]; label.textColor=color;
    return label;
}
@interface DI2LauncherCard : NSView
@end
@implementation DI2LauncherCard
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirty {
    (void)dirty; NSBezierPath *shape=[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds,0.5,0.5) xRadius:14 yRadius:14];
    [[NSColor colorWithWhite:0.115 alpha:1] setFill]; [shape fill];
    [[NSColor colorWithWhite:0.18 alpha:1] setStroke]; [shape stroke];
}
@end

@interface DI2LaunchButton : NSButton
@property(nonatomic) BOOL uncutStyle;
@end
@implementation DI2LaunchButton
- (void)drawRect:(NSRect)dirty {
    (void)dirty;
    NSColor *buttonColor=self.uncutStyle ? [NSColor colorWithRed:0.88 green:0.19 blue:0.16 alpha:1] : accent();
    NSColor *fill=self.enabled ? buttonColor : [buttonColor blendedColorWithFraction:0.85 ofColor:[NSColor colorWithWhite:0.18 alpha:1]];
    if(self.enabled && self.cell.isHighlighted) fill=[buttonColor blendedColorWithFraction:0.12 ofColor:NSColor.blackColor];
    [fill setFill]; [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:12 yRadius:12] fill];
    NSString *title=[NSString stringWithFormat:@"%@%@",self.enabled ? @"▶ " : @"",self.title];
    NSColor *ink=self.enabled ? (self.uncutStyle ? NSColor.whiteColor : [NSColor colorWithWhite:0.07 alpha:1]) : NSColor.secondaryLabelColor;
    NSDictionary *style=@{NSFontAttributeName:[NSFont systemFontOfSize:17 weight:NSFontWeightBold],NSForegroundColorAttributeName:ink};
    NSSize size=[title sizeWithAttributes:style];
    [title drawAtPoint:NSMakePoint((NSWidth(self.bounds)-size.width)/2,(NSHeight(self.bounds)-size.height)/2) withAttributes:style];
    if(self.window.firstResponder==self && self.enabled) {
        [[NSColor colorWithWhite:1 alpha:0.7] setStroke];
        NSBezierPath *ring=[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds,3,3) xRadius:9 yRadius:9];
        ring.lineWidth=2; [ring stroke];
    }
}
@end

@implementation DI2LauncherView {
    DI2LauncherCard *_card;
    NSTextField *_eyebrow, *_heading, *_version, *_gameTitle, *_hint;
    NSArray<NSTextField *> *_shortcuts;
}
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirty { (void)dirty; [[NSColor colorWithWhite:0.075 alpha:1] setFill]; NSRectFill(self.bounds); }
- (instancetype)initWithFrame:(NSRect)frame version:(NSString *)version {
    if(!(self=[super initWithFrame:frame]))return nil;
    self.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
    self.wantsLayer=YES; self.layer.backgroundColor=[NSColor colorWithWhite:0.075 alpha:1].CGColor;
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
    _card=[[DI2LauncherCard alloc]initWithFrame:NSZeroRect]; _card.wantsLayer=YES;
    _card.layer.cornerRadius=14; _card.layer.backgroundColor=[NSColor colorWithWhite:0.115 alpha:1].CGColor;
    _card.layer.borderWidth=1; _card.layer.borderColor=[NSColor colorWithWhite:0.18 alpha:1].CGColor;
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
    for(NSView *child in @[_gameIcon,_gameTitle,_installationStatus,_chooseGame,_steamButton])[_card addSubview:child];
    _start=[[DI2LaunchButton alloc]initWithFrame:NSZeroRect]; _start.title=@"Spiel mit Trainer starten";
    [_start setButtonType:NSButtonTypeMomentaryPushIn]; _start.bordered=NO; _start.keyEquivalent=@"\r";
    _start.accessibilityLabel=@"Spiel mit Trainer starten";
    _uncutStart=[[DI2LaunchButton alloc]initWithFrame:NSZeroRect]; ((DI2LaunchButton *)_uncutStart).uncutStyle=YES;
    _uncutStart.title=@"Spiel Uncut mit Trainer starten"; _uncutStart.accessibilityLabel=_uncutStart.title;
    [_uncutStart setButtonType:NSButtonTypeMomentaryPushIn]; _uncutStart.bordered=NO;
    _hint=text(@"⌘ + ^ öffnet das Overlay mit Mausbedienung.",12,NSFontWeightRegular,NSColor.secondaryLabelColor); _hint.alignment=NSTextAlignmentCenter;
    _status=[NSTextField wrappingLabelWithString:@""]; _status.font=[NSFont systemFontOfSize:11];
    _status.textColor=NSColor.secondaryLabelColor; _status.alignment=NSTextAlignmentCenter; _status.maximumNumberOfLines=2;
    _shortcuts=@[text(@"⌘^  Overlay",11,NSFontWeightSemibold,NSColor.secondaryLabelColor),text(@"⌘⌥^  Maus",11,NSFontWeightSemibold,NSColor.secondaryLabelColor),text(@"F12  Cheats aus",11,NSFontWeightSemibold,NSColor.secondaryLabelColor)];
    for(NSTextField *shortcut in _shortcuts)shortcut.alignment=NSTextAlignmentCenter;
    for(NSView *child in @[_eyebrow,_heading,_version,_settingsButton,_editionPicker,_card,_start,_uncutStart,_hint,_status])[self addSubview:child];
    for(NSView *child in _shortcuts)[self addSubview:child];
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
    _start.frame=NSMakeRect(margin,302,content,54); _uncutStart.frame=NSMakeRect(margin,368,content,54);
    _hint.frame=NSMakeRect(margin,443,content,20);
    _status.frame=NSMakeRect(margin,473,content,33);
    CGFloat part=content/3;
    for(NSUInteger i=0;i<_shortcuts.count;i++)_shortcuts[i].frame=NSMakeRect(margin+i*part,521,part,18);
}
- (void)showEdition:(DI2GameEdition)edition found:(BOOL)found running:(BOOL)running uncutAvailable:(BOOL)helper path:(NSString *)path {
    _editionPicker.selectedSegment=edition==DI2EditionSteam ? 1 : 0;
    _editionPicker.enabled=!running; _chooseGame.enabled=!running;
    _steamButton.hidden=edition!=DI2EditionSteam;
    _start.enabled=found && !running; _start.title=running ? @"Spiel läuft" : @"Spiel mit Trainer starten";
    _uncutStart.enabled=found && !running && edition==DI2EditionMAS && helper;
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
