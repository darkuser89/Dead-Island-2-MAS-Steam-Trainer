// SPDX-License-Identifier: GPL-3.0-only
#import "OverlayShortcuts.h"

NSInteger DI2ShortcutForEvent(NSEvent *event) {
    if (event.type!=NSEventTypeKeyDown) return -1;
    NSEventModifierFlags flags=event.modifierFlags;
    if (!(flags&NSEventModifierFlagCommand) || (flags&NSEventModifierFlagControl)) return -1;
    // ISO German caret is a dead key: its characters can be empty or composed.
    // Character matching additionally supports e.g. Shift+6 on an ANSI layout.
    if (!((event.keyCode==10 && !(flags&NSEventModifierFlagShift)) || [event.charactersIgnoringModifiers isEqualToString:@"^"])) return -1;
    return flags&NSEventModifierFlagOption ? DI2ShortcutMouse : DI2ShortcutPanel;
}
@implementation DI2OverlayShortcuts {
    BOOL _registered[DI2ShortcutCount], _held[DI2ShortcutCount];
}
- (void)setEnabled:(BOOL)enabled {
    _enabled=enabled;
    if (!enabled) memset(_held,0,sizeof(_held));
}
- (void)setRegistered:(BOOL)registered shortcut:(DI2OverlayShortcut)shortcut {
    if (shortcut<0 || shortcut>=DI2ShortcutCount) return;
    _registered[shortcut]=registered;
    if (!registered) _held[shortcut]=NO;
}
- (BOOL)ownsLocalEvent:(NSEvent *)event {
    NSInteger shortcut=DI2ShortcutForEvent(event);
    return _enabled && shortcut>=0 && event.keyCode==10 && !(event.modifierFlags&NSEventModifierFlagShift)
        && _registered[shortcut];
}
- (BOOL)nativeShortcut:(DI2OverlayShortcut)shortcut pressed:(BOOL)pressed {
    if (shortcut<0 || shortcut>=DI2ShortcutCount || !_enabled || !_registered[shortcut]) return NO;
    if (!pressed) { _held[shortcut]=NO; return YES; }
    if (_held[shortcut]) return YES;
    _held[shortcut]=YES;
    if (self.handler) self.handler(shortcut);
    return YES;
}
@end
