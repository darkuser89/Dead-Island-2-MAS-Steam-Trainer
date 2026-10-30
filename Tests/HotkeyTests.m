// SPDX-License-Identifier: GPL-3.0-only
#import "OverlayShortcuts.h"

static NSDictionary *reserved(unsigned short code,NSEventModifierFlags flags) {
    return @{@"keyCode":@(code),@"modifiers":@(flags)};
}
static NSEvent *key(unsigned short code,NSEventModifierFlags flags,NSString *characters) {
    return [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:flags timestamp:0
        windowNumber:0 context:nil characters:characters charactersIgnoringModifiers:characters isARepeat:NO keyCode:code];
}
int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSEventModifierFlags shift=NSEventModifierFlagShift, command=NSEventModifierFlagCommand,
            control=NSEventModifierFlagControl, option=NSEventModifierFlagOption;
        NSArray *os=@[reserved(103,0),reserved(103,shift),reserved(111,0),reserved(111,shift),
            reserved(10,command),reserved(10,command|option),reserved(122,0)];
        DI2ConfigureHotkeys(os);
        NSCAssert(!DI2HotkeyAt(DI2FeatureStamina).remapped && [DI2HotkeyAt(DI2FeatureStamina).label isEqual:@"F2"],@"free F keys remain unchanged");
        NSCAssert(DI2HotkeyAt(DI2HotkeyDisableAll).modifiers==control,@"all-off gets first choice of replacement");
        NSCAssert([DI2HotkeyReadableLabel(DI2HotkeyDisableAll) isEqual:@"Control + F12"],@"Mac key name is written out clearly");
        NSCAssert(DI2HotkeyAt(DI2FeatureCurveball).modifiers==control && DI2HotkeyAt(DI2FeatureCurveball).keyCode==103,@"plain F11 action gets the short Control+F11 replacement");
        NSCAssert(DI2HotkeyForEvent(key(111,control|shift|command,@""))<0,@"old cumbersome chord is not retained as an alias");
        NSMutableSet *unique=[NSMutableSet new];
        for(NSInteger i=0;i<DI2HotkeyCount;i++) {
            DI2HotkeyBinding *item=DI2HotkeyAt(i);NSCAssert(item.available,@"fixture has a replacement for every action");
            if(item.remapped)NSCAssert(item.modifiers && (item.modifiers&(item.modifiers-1))==0,@"replacement uses exactly one modifier, never a modifier chord");
            NSString *signature=[NSString stringWithFormat:@"%hu:%lu",item.keyCode,(unsigned long)item.modifiers];
            NSCAssert(![unique containsObject:signature],@"replacement never steals another trainer binding");[unique addObject:signature];
            NSCAssert(DI2HotkeyForEvent(key(item.keyCode,item.modifiers,@""))==i,@"all 31 current bindings dispatch exactly their own action");
            for(NSDictionary *entry in os)NSCAssert(item.keyCode!=[entry[@"keyCode"] unsignedShortValue]
                || item.modifiers!=[entry[@"modifiers"] unsignedIntegerValue],@"no trainer binding overlaps an enabled OS key");
        }
        for(NSDictionary *entry in os)NSCAssert(DI2HotkeyForEvent(key([entry[@"keyCode"] unsignedShortValue],
            [entry[@"modifiers"] unsignedIntegerValue],@""))<0,@"old conflicting keys are passed through, never kept as aliases");
        for(NSNumber *code in @[@122,@120,@99,@118,@96])NSCAssert(DI2HotkeyForEvent(key(code.unsignedShortValue,option,@""))<0,@"known Option hardware/accessibility keys remain free");
        DI2HotkeyBinding *stamina=DI2HotkeyAt(DI2FeatureStamina);
        NSCAssert(DI2HotkeyForEvent(key(stamina.keyCode,stamina.modifiers|NSEventModifierFlagFunction|NSEventModifierFlagNumericPad|NSEventModifierFlagCapsLock,@""))==DI2FeatureStamina,@"Fn/layout flags do not change a logical F key");
        NSCAssert([DI2HotkeyConflictSummary() containsString:@"F12 →"],@"read-only diagnostic shows changed bindings");
        DI2OverlayShortcuts *remappedRouter=[DI2OverlayShortcuts new];remappedRouter.enabled=YES;
        [remappedRouter setRegistered:YES shortcut:DI2ShortcutPanel];
        __block NSUInteger presses=0;remappedRouter.handler=^(DI2OverlayShortcut shortcut){(void)shortcut;presses++;};
        DI2HotkeyBinding *panel=DI2HotkeyAt(DI2HotkeyPanel);
        NSCAssert([remappedRouter ownsLocalEvent:key(panel.keyCode,panel.modifiers,@"")],@"remapped physical chord belongs only to the native route");
        [remappedRouter nativeShortcut:DI2ShortcutPanel pressed:YES];
        [remappedRouter nativeShortcut:DI2ShortcutPanel pressed:YES];
        NSCAssert(presses==1,@"remapped held key dispatches once");
        [remappedRouter nativeShortcut:DI2ShortcutPanel pressed:NO];
        [remappedRouter nativeShortcut:DI2ShortcutPanel pressed:YES];
        NSCAssert(presses==2,@"new remapped press is delivered again after release");
        DI2ConfigureHotkeys(@[reserved(111,0),reserved(111,control)]);
        NSCAssert([DI2HotkeyAt(DI2HotkeyDisableAll).label isEqual:@"⌥1"],@"if Control+F12 is occupied, use a simple number shortcut");
        NSMutableArray *exhausted=[NSMutableArray arrayWithArray:@[reserved(111,0),reserved(111,control),reserved(111,shift)]];
        const unsigned short digitCodes[]={18,19,20,21,23,22,26,28,25,29};
        for(NSUInteger i=0;i<10;i++)for(NSNumber *flags in @[@(option),@(control)])
            [exhausted addObject:reserved(digitCodes[i],flags.unsignedIntegerValue)];
        DI2ConfigureHotkeys(exhausted);
        NSCAssert(!DI2HotkeyAt(DI2HotkeyDisableAll).available && [DI2HotkeyAt(DI2HotkeyDisableAll).label isEqual:@"—"],@"exhausted short replacements disable the shortcut rather than adding modifiers");
        DI2ConfigureHotkeys(@[reserved(22,command|shift)]);
        NSCAssert(DI2ShortcutForEvent(key(22,command|shift,@"^"))<0,@"character-based alias cannot reclaim a system shortcut");
        DI2ConfigureHotkeys(@[]);
        NSCAssert(DI2ShortcutForEvent(key(22,command|shift,@"^"))==DI2ShortcutPanel,@"non-conflicting ANSI caret fallback remains available");
        DI2OverlayShortcuts *router=[DI2OverlayShortcuts new];router.enabled=YES;
        [router setRegistered:YES shortcut:DI2ShortcutPanel];
        DI2BlockHotkey(DI2HotkeyPanel);
        NSCAssert(![router ownsLocalEvent:key(10,command,@"")] && ![router nativeShortcut:DI2ShortcutPanel pressed:YES],@"native registration collision blocks both delivery paths");
        DI2ReloadSystemHotkeys();
        puts("Hotkey conflict checks passed: 31 unique bindings, unchanged free F keys, OS/custom conflicts, fallback exhaustion, alias safety, Fn flags and native collision blocking.");
        puts(DI2HotkeyConflictSummary().UTF8String);
    } return 0;
}
