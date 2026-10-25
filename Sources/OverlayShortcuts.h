// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>

typedef NS_ENUM(NSInteger, DI2OverlayShortcut) { DI2ShortcutPanel, DI2ShortcutMouse, DI2ShortcutCount };
NSInteger DI2ShortcutForEvent(NSEvent *event);

// Shared ownership between the AppKit fallback and macOS hotkey delivery.
// A registered physical shortcut belongs exclusively to the native path.
@interface DI2OverlayShortcuts : NSObject
@property(nonatomic) BOOL enabled;
@property(nonatomic, copy) void (^handler)(DI2OverlayShortcut);
- (void)setRegistered:(BOOL)registered shortcut:(DI2OverlayShortcut)shortcut;
- (BOOL)ownsLocalEvent:(NSEvent *)event;
- (BOOL)nativeShortcut:(DI2OverlayShortcut)shortcut pressed:(BOOL)pressed;
@end
