// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import "LauncherView.h"
#import "TrainerMaterial.h"

@interface DI2LauncherCounter : NSObject
@property(nonatomic) NSUInteger starts, uncutStarts, changes, settings, restores;
- (void)start:(id)sender;
- (void)uncutStart:(id)sender;
- (void)change:(id)sender;
- (void)settings:(id)sender;
- (void)restore:(id)sender;
@end
@implementation DI2LauncherCounter
- (void)start:(id)sender { (void)sender; self.starts++; }
- (void)uncutStart:(id)sender { (void)sender; self.uncutStarts++; }
- (void)change:(id)sender { (void)sender; self.changes++; }
- (void)settings:(id)sender { (void)sender; self.settings++; }
- (void)restore:(id)sender { (void)sender; self.restores++; }
@end

int main(int argc,const char *argv[]) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSWindow *window=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,520,564) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
        window.releasedWhenClosed=NO; window.appearance=[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        DI2LauncherView *view=[[DI2LauncherView alloc]initWithFrame:NSMakeRect(0,0,520,564) version:@"0.6.11"];
        window.contentView=view; [view layout];
        DI2LauncherCounter *counter=[DI2LauncherCounter new];
        view.start.target=counter; view.start.action=@selector(start:);
        view.uncutStart.target=counter; view.uncutStart.action=@selector(uncutStart:);
        view.editionPicker.target=counter; view.editionPicker.action=@selector(change:);
        view.settingsButton.target=counter; view.settingsButton.action=@selector(settings:);
        view.restoreCheats.target=counter;view.restoreCheats.action=@selector(restore:);
        [view.restoreCheats performClick:nil];
        NSCAssert(counter.restores==1 && view.restoreCheats.state==NSControlStateValueOn,@"restore option is clickable");
        [view.restoreCheats performClick:nil];
        NSCAssert(counter.restores==2 && view.restoreCheats.state==NSControlStateValueOff,@"restore option can be disabled");
        [view showSelectionHint:@"Gespeicherte Auswahl wird nach dem Laden aktiviert."];
        for(DI2GameEdition edition=DI2EditionMAS;edition<=DI2EditionSteam;edition++) {
            [view showEdition:edition found:NO running:NO uncutAvailable:YES path:@"/missing/DeadIsland2.app"];
            NSCAssert(!view.start.enabled && !view.uncutStart.enabled && view.chooseGame.enabled && view.editionPicker.enabled,@"missing game blocks only launch, preserving recovery controls");
            NSCAssert([view.installationStatus.stringValue isEqual:@"Nicht gefunden"],@"missing installation has a visible status");
            [view showEdition:edition found:YES running:NO uncutAvailable:YES path:@"/Applications"];
            NSCAssert(view.start.enabled && view.editionPicker.selectedSegment==(edition==DI2EditionSteam ? 1 : 0),@"both store selections remain available");
            NSCAssert(view.steamButton.hidden==(edition!=DI2EditionSteam),@"Steam helper belongs only to Steam selection");
            NSCAssert(view.uncutStart.enabled==(edition==DI2EditionMAS),@"uncut action belongs only to MAS with a helper");
            if(edition==DI2EditionMAS) {
                NSUInteger normal=counter.starts,uncut=counter.uncutStarts;[view.uncutStart performClick:nil];
                NSCAssert(counter.starts==normal && counter.uncutStarts==uncut+1,@"red and orange buttons dispatch separate modes");
                [view showEdition:edition found:YES running:NO uncutAvailable:NO path:@"/Applications"];
                NSCAssert(view.start.enabled && !view.uncutStart.enabled,@"missing helper blocks only the uncut mode");
                [view showEdition:edition found:YES running:NO uncutAvailable:YES path:@"/Applications"];
            }
            NSUInteger previous=counter.starts; [view.start performClick:nil];
            NSCAssert(counter.starts==previous+1,@"primary button dispatches one explicit action; test never starts a game");
            [view showEdition:edition found:YES running:YES uncutAvailable:YES path:@"/Applications"];
            NSCAssert(!view.start.enabled && !view.uncutStart.enabled && !view.editionPicker.enabled && !view.chooseGame.enabled,@"running session locks replacement and duplicate launch");
            NSCAssert(view.settingsButton.enabled && [view.start.title isEqual:@"Spiel läuft"],@"settings remain reachable during a running session");
            for(NSView *child in view.subviews) NSCAssert(NSContainsRect(view.bounds,child.frame),@"launcher controls fit the compact content bounds");
        }
        [view.editionPicker setEnabled:YES]; view.editionPicker.selectedSegment=0;
        [view.editionPicker sendAction:view.editionPicker.action to:view.editionPicker.target];
        view.editionPicker.selectedSegment=1; [view.editionPicker sendAction:view.editionPicker.action to:view.editionPicker.target];
        [view.settingsButton performClick:nil];
        NSCAssert(counter.changes==2 && counter.settings==1,@"segmented selection and settings dispatch separately");
        NSCAssert(view.start.keyEquivalent.length==1 && [view.start.keyEquivalent isEqual:@"\r"],@"return key retains the primary action");
        for(NSNumber *glass in @[@NO,@YES]) for(NSString *appearance in @[NSAppearanceNameAqua,NSAppearanceNameDarkAqua]) {
            DI2LauncherView *surface=[[DI2LauncherView alloc]initWithFrame:NSMakeRect(0,0,520,564) version:@"test" glassEnabled:glass.boolValue];
            window.contentView=surface; window.appearance=[NSAppearance appearanceNamed:appearance];
            [surface showEdition:DI2EditionMAS found:YES running:NO uncutAvailable:YES path:@"/Applications"];
            [window.contentView layoutSubtreeIfNeeded];
            for(NSView *control in @[surface.start,surface.uncutStart,surface.editionPicker,surface.settingsButton,surface.chooseGame,surface.restoreCheats]) {
                NSRect rect=[surface convertRect:control.bounds fromView:control];
                NSCAssert(NSContainsRect(surface.bounds,rect),@"native materials preserve control placement in either appearance");
                NSPoint center=NSMakePoint(NSMidX(rect),NSMidY(rect));
                NSView *hit=[surface hitTest:[surface convertPoint:center toView:surface.superview]];
                NSCAssert(hit==control || [hit isDescendantOf:control],@"glass container passes clicks: %@ got %@ (glass %@)",control,hit,glass);
            }
            NSCAssert(glass.boolValue || !surface.usesLiquidGlass,@"legacy material can be exercised on current macOS");
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 260000
            if(@available(macOS 26.0,*)) {
                BOOL expected=glass.boolValue && !NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceTransparency && !NSWorkspace.sharedWorkspace.accessibilityDisplayShouldIncreaseContrast;
                NSCAssert(surface.usesLiquidGlass==expected,@"SDK/runtime and accessibility policy choose the material");
                if(expected) {
                    NSView *parent=surface.start.superview;
                    while(parent && ![parent isKindOfClass:NSGlassEffectView.class])parent=parent.superview;
                    NSCAssert(parent && ((NSGlassEffectView *)parent).tintColor
                        && !surface.start.bordered,@"native button is embedded in tinted system glass");
                }
            }
#endif
            surface.start.target=counter;surface.start.action=@selector(start:);
            surface.uncutStart.target=counter;surface.uncutStart.action=@selector(uncutStart:);
            NSUInteger normal=counter.starts,uncut=counter.uncutStarts;
            [surface.start performClick:nil];[surface.uncutStart performClick:nil];
            NSCAssert(counter.starts==normal+1 && counter.uncutStarts==uncut+1,@"both native start buttons retain independent actions");
        }
        NSView *settingsContent=[[NSView alloc]initWithFrame:NSMakeRect(0,0,620,426)];
        NSView *settingsSurface=DI2LauncherSurface(settingsContent,16,YES);
        NSCAssert([settingsSurface isKindOfClass:DI2TrainerMaterial.class] && ((DI2TrainerMaterial *)settingsSurface).contentView==settingsContent,@"settings use the shared material policy");
        window.contentView=view; window.appearance=[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        if(argc==3) {
            [view showEdition:DI2EditionMAS found:YES running:NO uncutAvailable:YES path:@"/Applications"];
            view.gameIcon.image=[[NSImage alloc]initWithContentsOfFile:[NSString stringWithUTF8String:argv[2]]];
            view.wantsLayer=NO; for(NSView *child in view.subviews)child.wantsLayer=NO;
            NSBitmapImageRep *bitmap=[view bitmapImageRepForCachingDisplayInRect:view.bounds];
            [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
            NSData *png=[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
            NSCAssert([png writeToFile:[NSString stringWithUTF8String:argv[1]] atomically:YES],@"launcher preview saved outside source");
        }
        [window close];
        puts("Launcher UI checks passed: MAS/Steam selection, missing/running states, native glass/fallback hit testing in light/dark, safe actions and compact layout.");
    } return 0;
}
