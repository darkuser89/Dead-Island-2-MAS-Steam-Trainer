// SPDX-License-Identifier: GPL-3.0-only
#import "Overlay.h"
#import <QuartzCore/QuartzCore.h>
#import <unistd.h>

// Unreal's Cocoa game window can be resized from its game thread. Never introduce
// an Auto Layout engine into that window: all overlay geometry and drawing are manual.
static NSColor *accent(void) { return [NSColor colorWithRed:1 green:0.53 blue:0.35 alpha:1]; }
static void text(NSString *value, NSRect rectangle, CGFloat size, NSColor *color, BOOL bold) {
    NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
    style.lineBreakMode = NSLineBreakByWordWrapping;
    [value drawInRect:rectangle withAttributes:@{
        NSFontAttributeName: bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size],
        NSForegroundColorAttributeName: color, NSParagraphStyleAttributeName: style
    }];
}
@interface DI2OverlayButton : NSView
@property(nonatomic, copy) NSString *title;
@property(nonatomic, weak) DI2OverlayRoot *owner;
@end
@implementation DI2OverlayButton
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return NO; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { (void)event; return YES; }
- (instancetype)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.accessibilityElement = YES;
        self.accessibilityRole = NSAccessibilityButtonRole;
    }
    return self;
}
- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    [[NSColor colorWithWhite:0.18 alpha:1] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:7 yRadius:7] fill];
    text(self.title, NSInsetRect(self.bounds, 10, 5), 13, NSColor.whiteColor, NO);
}
- (void)mouseDown:(NSEvent *)event { (void)event; [self.owner togglePanel:self]; }
- (BOOL)accessibilityPerformPress {
    if (NSThread.isMainThread) [self.owner togglePanel:self];
    else dispatch_async(dispatch_get_main_queue(), ^{ [self.owner togglePanel:self]; });
    return YES;
}
@end

@interface DI2OverlayPanel : NSView
@property(nonatomic, copy) NSString *gameVersion;
@end
@implementation DI2OverlayPanel
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return NO; }
- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect box = NSInsetRect(self.bounds, 0.5, 0.5);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:box xRadius:15 yRadius:15];
    [[NSColor colorWithRed:0.065 green:0.075 blue:0.085 alpha:0.97] setFill]; [path fill];
    [accent() setStroke]; [path stroke];
    CGFloat width = self.bounds.size.width - 44;
    NSColor *muted = [NSColor colorWithWhite:0.72 alpha:1];
    text(@"DEAD ISLAND 2", NSMakeRect(22,20,width,18), 11, accent(), YES);
    text(@"Trainer · Ingame-Overlay", NSMakeRect(22,48,width,34), 22, NSColor.whiteColor, YES);
    text(@"●  Direkt im Spielprozess aktiv", NSMakeRect(22,94,width,24), 13,
        [NSColor colorWithRed:0.58 green:0.9 blue:0.67 alpha:1], YES);
    text([NSString stringWithFormat:@"Spiel %@  ·  PID %d\nOverlay 0.1.0  ·  Apple Silicon", self.gameVersion, getpid()],
        NSMakeRect(22,128,width,42), 12, muted, NO);
    text(@"Overlay-Grundlage\nCheat-Funktionen sind noch nicht eingebaut.", NSMakeRect(22,184,width,45), 13, NSColor.whiteColor, NO);
    text(@"Ein-/ausblenden: F8 oder ⌘⇧T\nBei Medienbelegung: fn + F8 verwenden.", NSMakeRect(22,244,width,42), 12, muted, NO);
}
@end

@implementation DI2OverlayRoot {
    DI2OverlayPanel *_panel;
    DI2OverlayButton *_badge;
    DI2OverlayButton *_hideButton;
}
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return NO; }
- (BOOL)acceptsFirstResponder { return NO; }
- (NSView *)panel { return _panel; }
- (NSView *)badge { return _badge; }
- (instancetype)initWithFrame:(NSRect)frame version:(NSString *)version {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.identifier = @"DI2TrainerOverlay";
    self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.wantsLayer = YES;
    self.layer.backgroundColor = NSColor.clearColor.CGColor;
    self.layer.zPosition = 100000;
    self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
    self.accessibilityElement = YES;
    self.accessibilityRole = NSAccessibilityGroupRole;
    self.accessibilityLabel = @"Dead Island 2 Trainer Ingame-Overlay";

    _panel = [[DI2OverlayPanel alloc] initWithFrame:NSZeroRect];
    _panel.gameVersion = version;
    _panel.wantsLayer = YES;
    _panel.accessibilityElement = YES;
    _panel.accessibilityRole = NSAccessibilityGroupRole;
    _panel.accessibilityLabel = [NSString stringWithFormat:@"Trainer · Ingame-Overlay. Direkt im Spielprozess aktiv. Spiel %@, PID %d. Noch keine Cheat-Funktionen. F8 oder Befehl-Umschalt-T zum Ein- und Ausblenden.", version, getpid()];
    [self addSubview:_panel];
    _hideButton = [[DI2OverlayButton alloc] initWithFrame:NSMakeRect(22,306,190,30)];
    _hideButton.title = @"Overlay ausblenden";
    _hideButton.accessibilityLabel = _hideButton.title;
    _hideButton.owner = self;
    [_panel addSubview:_hideButton];
    _badge = [[DI2OverlayButton alloc] initWithFrame:NSMakeRect(16,16,130,30)];
    _badge.title = @"Trainer · F8";
    _badge.accessibilityLabel = @"Trainer-Overlay einblenden";
    _badge.owner = self;
    [self addSubview:_badge];
    self.panelVisible = YES;
    [self layout];
    return self;
}
- (void)layout {
    [super layout];
    CGFloat width = MAX(160, MIN(410, self.bounds.size.width - 32));
    CGFloat height = MIN(360, MAX(160, self.bounds.size.height - 32));
    _panel.frame = NSMakeRect(16,16,width,height);
    _hideButton.frame = NSMakeRect(22,MIN(306,height - 44),MIN(190,width - 44),30);
    _badge.frame = NSMakeRect(16,16,130,30);
}
- (void)setPanelVisible:(BOOL)visible {
    _panelVisible = visible;
    _panel.hidden = !visible;
    _badge.hidden = visible;
    [self setNeedsDisplay:YES];
}
- (void)togglePanel:(id)sender { (void)sender; self.panelVisible = !self.panelVisible; }
- (NSView *)hitTest:(NSPoint)point {
    NSView *hit = [super hitTest:point];
    return hit == self ? nil : hit;
}
@end

BOOL DI2OverlayToggleEvent(NSEvent *event) {
    if (event.type != NSEventTypeKeyDown || event.isARepeat) return NO;
    NSEventModifierFlags modifiers = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
    if (event.keyCode == 100 && !(modifiers & (NSEventModifierFlagCommand | NSEventModifierFlagControl | NSEventModifierFlagOption))) return YES;
    return event.keyCode == 17 && (modifiers & (NSEventModifierFlagCommand | NSEventModifierFlagShift)) == (NSEventModifierFlagCommand | NSEventModifierFlagShift)
        && !(modifiers & (NSEventModifierFlagControl | NSEventModifierFlagOption));
}
