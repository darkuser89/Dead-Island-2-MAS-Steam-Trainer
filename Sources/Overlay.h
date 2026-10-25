// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>

@interface DI2OverlayRoot : NSView
@property(nonatomic) BOOL panelVisible;
@property(nonatomic, readonly) NSView *panel;
@property(nonatomic, readonly) NSView *badge;
- (instancetype)initWithFrame:(NSRect)frame version:(NSString *)version;
- (void)togglePanel:(id)sender;
@end

BOOL DI2OverlayToggleEvent(NSEvent *event);
