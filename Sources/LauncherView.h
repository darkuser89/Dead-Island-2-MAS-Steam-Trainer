// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import "GameEdition.h"

@interface DI2LauncherView : NSView
@property(nonatomic, readonly) NSSegmentedControl *editionPicker;
@property(nonatomic, readonly) NSButton *chooseGame, *steamButton, *start, *uncutStart, *settingsButton;
@property(nonatomic, readonly) NSTextField *status, *installationStatus;
@property(nonatomic, readonly) NSImageView *gameIcon;
- (instancetype)initWithFrame:(NSRect)frame version:(NSString *)version;
- (void)showEdition:(DI2GameEdition)edition found:(BOOL)found running:(BOOL)running uncutAvailable:(BOOL)helper path:(NSString *)path;
@end
