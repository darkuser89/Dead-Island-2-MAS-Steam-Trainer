// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import "GameEdition.h"

// Launcher surface built from the shared, accessibility-aware material wrapper.
NSView *DI2LauncherSurface(NSView *content, CGFloat radius, BOOL glassEnabled);

@interface DI2LauncherView : NSView
@property(nonatomic, readonly) BOOL usesLiquidGlass;
@property(nonatomic, readonly) NSSegmentedControl *editionPicker;
@property(nonatomic, readonly) NSButton *chooseGame, *steamButton, *start, *uncutStart, *settingsButton, *restoreCheats;
@property(nonatomic, readonly) NSTextField *status, *installationStatus;
@property(nonatomic, readonly) NSImageView *gameIcon;
- (instancetype)initWithFrame:(NSRect)frame version:(NSString *)version;
- (instancetype)initWithFrame:(NSRect)frame version:(NSString *)version glassEnabled:(BOOL)enabled;
- (void)showSelectionHint:(NSString *)hint;
- (void)showEdition:(DI2GameEdition)edition found:(BOOL)found running:(BOOL)running uncutAvailable:(BOOL)helper path:(NSString *)path;
@end
