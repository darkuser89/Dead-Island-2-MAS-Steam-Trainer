// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import "LauncherView.h"

@interface DI2LauncherCounter : NSObject
@property(nonatomic) NSUInteger starts, uncutStarts, changes, settings;
- (void)start:(id)sender;
- (void)uncutStart:(id)sender;
- (void)change:(id)sender;
- (void)settings:(id)sender;
@end
@implementation DI2LauncherCounter
- (void)start:(id)sender { (void)sender; self.starts++; }
- (void)uncutStart:(id)sender { (void)sender; self.uncutStarts++; }
- (void)change:(id)sender { (void)sender; self.changes++; }
- (void)settings:(id)sender { (void)sender; self.settings++; }
@end

int main(int argc,const char *argv[]) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSWindow *window=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,520,564) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
        window.releasedWhenClosed=NO; window.appearance=[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        DI2LauncherView *view=[[DI2LauncherView alloc]initWithFrame:NSMakeRect(0,0,520,564) version:@"0.6.4"];
        window.contentView=view; [view layout];
        DI2LauncherCounter *counter=[DI2LauncherCounter new];
        view.start.target=counter; view.start.action=@selector(start:);
        view.uncutStart.target=counter; view.uncutStart.action=@selector(uncutStart:);
        view.editionPicker.target=counter; view.editionPicker.action=@selector(change:);
        view.settingsButton.target=counter; view.settingsButton.action=@selector(settings:);
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
        puts("Launcher UI checks passed: MAS/Steam selection, missing/running states, safe action dispatch, settings access and compact layout.");
    } return 0;
}
