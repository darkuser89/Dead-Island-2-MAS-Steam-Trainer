// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import "Overlay.h"
#include <math.h>
@interface DI2OverlayRoot (LayoutTesting)
- (void)editFeature:(DI2Feature)feature;
- (void)headerClick:(NSPoint)point;
- (void)beginDraggingAt:(NSPoint)point;
- (void)dragTo:(NSPoint)point;
- (void)endDragging;
@end

static NSEvent *mouseEvent(NSWindow *window, NSView *view, NSPoint point, NSEventType type) {
    return [NSEvent mouseEventWithType:type location:[view convertPoint:point toView:nil] modifierFlags:0 timestamp:0
        windowNumber:window.windowNumber context:nil eventNumber:1 clickCount:1 pressure:type==NSEventTypeLeftMouseUp ? 0 : 1];
}
static void click(NSWindow *window, DI2OverlayRoot *root, NSView *view, NSPoint point) {
    NSCAssert([root handleMouseEvent:mouseEvent(window,view,point,NSEventTypeLeftMouseDown)],@"overlay click consumed");
    NSCAssert([root handleMouseEvent:mouseEvent(window,view,point,NSEventTypeLeftMouseUp)],@"matching release consumed");
}
static void testMouseRouting(void) {
    NSWindow *window=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,1100,720) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    window.releasedWhenClosed=NO;
    DI2OverlayRoot *root=[[DI2OverlayRoot alloc]initWithFrame:NSMakeRect(20,30,1060,660) version:@"mouse-test"];
    [window.contentView addSubview:root];
    DI2TrainerState *state=[DI2TrainerState new];state.ready=YES;state.features[DI2FeatureMoney].value=10000;[root updateState:state];
    __block NSInteger calls=0;
    for (NSNumber *scale in @[@0.7,@0.9,@1.3]) for (NSString *position in @[@"top-left",@"top-right",@"bottom-left",@"bottom-right",@"center"]) {
        [root applyOverlayOptions:@{@"scale":scale,@"position":position}];
        for (NSInteger i=0;i<DI2FeatureCount;i++) {
            NSInteger before=calls;
            root.featureHandler=^(DI2Feature feature) { NSCAssert(feature==i,@"mouse targets the clicked feature");calls++; };
            click(window,root,root.panel.subviews[i],NSMakePoint(244,10));
            NSCAssert(calls==before+1,@"all 26 toggles/GO dispatch once across scales and positions");
        }
    }
    root.featureHandler=^(DI2Feature feature) { (void)feature;calls++; };
    __block double value=0;
    root.valueHandler=^(DI2Feature feature,double amount) { NSCAssert(feature==DI2FeatureMoney,@"clicked money control");value=amount; };
    NSView *money=root.panel.subviews[DI2FeatureMoney];
    click(window,root,money,NSMakePoint(147,10));NSCAssert(value==9000,@"minus changes numeric value");
    click(window,root,money,NSMakePoint(222,10));NSCAssert(value==11000,@"plus changes numeric value");
    click(window,root,money,NSMakePoint(170,10));
    NSEvent *digits=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:window.windowNumber context:nil characters:@"25000" charactersIgnoringModifiers:@"25000" isARepeat:NO keyCode:20];
    NSEvent *enter=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:window.windowNumber context:nil characters:@"\r" charactersIgnoringModifiers:@"\r" isARepeat:NO keyCode:36];
    [root handleEvent:digits];[root handleEvent:enter];NSCAssert(value==25000,@"mouse-selected numeric field accepts keyboard edit");
    [root applyOverlayOptions:@{@"position":@"top-left"}];NSRect before=root.panel.frame;
    [root handleMouseEvent:mouseEvent(window,root.panel,NSMakePoint(100,12),NSEventTypeLeftMouseDown)];
    NSCAssert([root handleMouseEvent:mouseEvent(window,root,NSMakePoint(1000,600),NSEventTypeLeftMouseDragged)],@"drag remains owned outside the panel");
    [root handleMouseEvent:mouseEvent(window,root,NSMakePoint(1000,600),NSEventTypeLeftMouseUp)];
    NSCAssert(!NSEqualRects(before,root.panel.frame) && [root.overlayOptions[@"position"] isEqual:@"free"],@"routed title drag moves panel");
    NSInteger beforeCalls=calls;state.ready=NO;[root updateState:state];
    NSView *god=root.panel.subviews[DI2FeatureGod];click(window,root,god,NSMakePoint(244,10));
    NSCAssert(calls==beforeCalls,@"loading/network still blocks mouse cheat activation");
    state.ready=YES;[root updateState:state];[root applyOverlayOptions:@{@"mouse":@NO}];
    NSCAssert(![root handleMouseEvent:mouseEvent(window,god,NSMakePoint(244,10),NSEventTypeLeftMouseDown)],@"display-only mode passes clicks through");
    NSCAssert(![root hitTest:[god convertPoint:NSMakePoint(244,10) toView:root.superview]],@"AppKit hit testing passes through display-only panel");
    [root applyOverlayOptions:nil];
    NSCAssert(![root handleMouseEvent:mouseEvent(window,root,NSMakePoint(1000,600),NSEventTypeLeftMouseDown)]
        && ![root handleMouseEvent:mouseEvent(window,root,NSMakePoint(1000,600),NSEventTypeLeftMouseUp)],@"outside click and release stay with game");
    [root handleMouseEvent:mouseEvent(window,root.panel,NSMakePoint(526,12),NSEventTypeLeftMouseDown)];
    NSCAssert(!root.panelVisible && [root handleMouseEvent:mouseEvent(window,root,NSMakePoint(1000,600),NSEventTypeLeftMouseUp)],@"close click consumes release without leaking to gameplay");
    [root applyOverlayOptions:@{@"visible":@NO,@"badge":@YES}];click(window,root,root.badge,NSMakePoint(20,10));
    NSCAssert(root.panelVisible,@"badge click reopens overlay");
    NSWindow *foreign=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,20,20) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];foreign.releasedWhenClosed=NO;
    NSCAssert(![root handleMouseEvent:mouseEvent(foreign,foreign.contentView,NSMakePoint(5,5),NSEventTypeLeftMouseDown)],@"foreign-window events untouched");
    [foreign close];[window close];
    puts("Mouse routing checks passed: all 26 controls, scaled/offset coordinates, numeric fields, dragging, close/badge, display-only and loading/network gating.");
}

@interface HostView : NSView
@property(nonatomic, strong) id<MTLDevice> device;
@property(nonatomic, strong) id<MTLCommandQueue> queue;
@property(nonatomic, strong) NSTimer *timer;
@end
@implementation HostView
- (CALayer *)makeBackingLayer { return [CAMetalLayer layer]; }
- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.wantsLayer = YES;
    self.device = MTLCreateSystemDefaultDevice();
    self.queue = [self.device newCommandQueue];
    ((CAMetalLayer *)self.layer).device = self.device;
    ((CAMetalLayer *)self.layer).pixelFormat = MTLPixelFormatBGRA8Unorm;
    __weak HostView *weakSelf = self;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0/30 repeats:YES block:^(NSTimer *timer) {
        (void)timer;
        HostView *view = weakSelf;
        if (!view.window.isVisible) return;
        CAMetalLayer *layer = (CAMetalLayer *)view.layer;
        layer.drawableSize = NSMakeSize(view.bounds.size.width * view.window.backingScaleFactor, view.bounds.size.height * view.window.backingScaleFactor);
        id<CAMetalDrawable> drawable = [layer nextDrawable];
        if (!drawable) return;
        MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
        pass.colorAttachments[0].texture = drawable.texture;
        pass.colorAttachments[0].loadAction = MTLLoadActionClear;
        pass.colorAttachments[0].storeAction = MTLStoreActionStore;
        double t = NSProcessInfo.processInfo.systemUptime;
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0.10 + sin(t)*0.02,0.16,0.22,1);
        id<MTLCommandBuffer> command = [view.queue commandBuffer];
        id<MTLRenderCommandEncoder> encoder = [command renderCommandEncoderWithDescriptor:pass];
        [encoder endEncoding]; [command presentDrawable:drawable]; [command commit];
    }];
    return self;
}
@end
@interface HostDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSWindow *window;
@end
@implementation HostDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    NSMenu *menu = [NSMenu new];
    NSMenuItem *item = [NSMenuItem new];
    [menu addItem:item];
    NSMenu *appMenu = [NSMenu new];
    [appMenu addItemWithTitle:@"Test beenden" action:@selector(terminate:) keyEquivalent:@"q"];
    item.submenu = appMenu;
    NSApp.mainMenu = menu;
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,1100,720)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"Trainer Overlay · Metal-Test";
    self.window.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
    self.window.contentView = [[HostView alloc] initWithFrame:self.window.contentView.bounds];
    [self.window center]; [self.window makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app { (void)app; return YES; }
@end
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc==3 && strcmp(argv[1],"--preview")==0) {
            [NSApplication sharedApplication];
            NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,540,368) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:YES];
            DI2OverlayRoot *root=[[DI2OverlayRoot alloc] initWithFrame:NSMakeRect(0,0,540,368) version:@"0.6.4"];
            window.contentView=root;
            DI2TrainerState *sample=[DI2TrainerState new]; sample.ready=YES; sample.cash=@12500;
            sample.status=@"VORSCHAU"; sample.message=@"26 Anbindungen · neue Funktionen noch ohne Ingame-Test.";
            sample.overlayMouseActive=YES;
            for(NSInteger i=0;i<DI2FeatureCount;i++) sample.features[i].available=DI2FeatureInfoAt(i)->implemented;
            sample.features[DI2FeatureGod].active=sample.features[DI2FeatureGod].wanted=YES;
            sample.features[DI2FeatureStamina].active=sample.features[DI2FeatureStamina].wanted=YES;
            sample.features[DI2FeatureDurability].wanted=YES;
            [root updateState:sample]; [root layout];
            root.wantsLayer=NO; root.panel.wantsLayer=NO;
            NSBitmapImageRep *bitmap=[root.panel bitmapImageRepForCachingDisplayInRect:root.panel.bounds];
            [root.panel cacheDisplayInRect:root.panel.bounds toBitmapImageRep:bitmap];
            NSData *png=[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
            if (![png writeToFile:[NSString stringWithUTF8String:argv[2]] atomically:YES]) return 3;
            puts("Compact overlay preview rendered without launching a game."); return 0;
        }
        if (argc == 2 && strcmp(argv[1], "--unit-test") == 0) {
            [NSApplication sharedApplication];
            DI2OverlayRoot *root = [[DI2OverlayRoot alloc] initWithFrame:NSMakeRect(0,0,1100,720) version:@"test"];
            NSMutableArray<NSView *> *views = [NSMutableArray arrayWithObject:root];
            while (views.count) {
                NSView *view = views.lastObject;
                [views removeLastObject];
                NSCAssert(view.constraints.count == 0 && ![view isKindOfClass:NSStackView.class], @"game overlay must not introduce Auto Layout");
                [views addObjectsFromArray:view.subviews];
            }
            NSCAssert(root.panelVisible && !root.panel.hidden && root.badge.hidden, @"initial visibility");
            NSCAssert([root hitTest:NSMakePoint(1000,600)] == nil, @"outside overlay is click-through");
            [root togglePanel:nil];
            NSCAssert(!root.panelVisible && root.panel.hidden && root.badge.hidden, @"default hide removes the entire overlay");
            NSCAssert([root hitTest:NSMakePoint(25,25)]==nil,@"fully hidden overlay does not swallow mouse clicks");
            [root applyOverlayOptions:@{@"visible":@NO,@"badge":@YES}];
            NSCAssert(!root.badge.hidden,@"badge is an explicit option");
            root.frame = NSMakeRect(0,0,800,600); [root layout];
            NSCAssert(NSMaxX(root.panel.frame) <= root.bounds.size.width, @"resize stays inside game view");
            NSEvent *toggle = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:NSEventModifierFlagCommand timestamp:0 windowNumber:0 context:nil characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:10];
            NSCAssert(DI2OverlayToggleEvent(toggle), @"Command + German dead circumflex toggles");
            NSEvent *caret = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil characters:@"^" charactersIgnoringModifiers:@"^" isARepeat:NO keyCode:10];
            NSCAssert(!DI2OverlayToggleEvent(caret),@"circumflex without Command passes through");
            NSEvent *f8 = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:100];
            NSCAssert(!DI2OverlayToggleEvent(f8),@"old F8 shortcut is released");
            NSEvent *other = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil characters:@"a" charactersIgnoringModifiers:@"a" isARepeat:NO keyCode:0];
            NSCAssert(!DI2OverlayToggleEvent(other), @"normal game key is passed through");
            __block NSInteger cashActions = 0, stopActions=0;
            root.actionHandler = ^(DI2TrainerAction action) { if (action==DI2TrainerCash1000) cashActions++; if(action==DI2TrainerDisableAll)stopActions++; };
            NSEvent *f4 = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:118];
            [root handleEvent:f4]; NSCAssert(cashActions==0,@"money disabled without local player");
            NSEvent *f12 = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:111];
            [root handleEvent:f12];NSCAssert(stopActions==1,@"F12 can cancel pending cheats during loading without enabling money actions");
            DI2TrainerState *ready = [DI2TrainerState new]; ready.ready=YES; ready.cash=@42;
            [root updateState:ready]; [root handleEvent:f4];
            NSCAssert(cashActions==1,@"one explicit key adds money exactly once even with hidden panel");
            NSEvent *repeat = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil characters:@"" charactersIgnoringModifiers:@"" isARepeat:YES keyCode:118];
            [root handleEvent:repeat]; NSCAssert(cashActions==1,@"key repeat never adds more money");
            ready.healthAvailable=YES; ready.staminaAvailable=YES; [root updateState:ready];
            const unsigned short keys[]={122,120,99,118,96,111};
            const DI2TrainerAction actions[]={DI2TrainerHealth,DI2TrainerStamina,DI2TrainerAmmo,DI2TrainerCash1000,DI2TrainerCash10000,DI2TrainerDisableAll};
            __block NSInteger received=0;
            for(NSUInteger i=0;i<6;i++) {
                DI2TrainerAction expected=actions[i];
                root.actionHandler=^(DI2TrainerAction actual){ NSCAssert(actual==expected,@"function key dispatches correct command"); received++; };
                NSEvent *key=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:keys[i]];
                NSCAssert([root handleEvent:key],@"assigned function key consumed");
            }
            NSCAssert(received==6,@"F1–F5 and F12 commands dispatched");
            NSCAssert(root.panel.frame.size.width<=486.01 && root.panel.frame.size.height<=331.21,@"compact default footprint");
            NSUInteger rows=0;
            for(NSView *row in root.panel.subviews) {
                NSCAssert(NSContainsRect(root.panel.bounds,row.frame),@"all rows fit inside compact panel"); rows++;
            }
            NSCAssert(rows==26,@"all reference functions present");
            __block NSInteger features=0;
            for(NSInteger i=0;i<DI2FeatureCount;i++) {
                const DI2FeatureInfo *info=DI2FeatureInfoAt(i);
                for(NSInteger j=0;j<i;j++) NSCAssert(info->key!=DI2FeatureInfoAt(j)->key || info->modifiers!=DI2FeatureInfoAt(j)->modifiers,@"unique feature hotkeys");
                NSInteger before=features;
                root.featureHandler=^(DI2Feature actual){ NSCAssert(actual==i,@"catalog hotkey matches feature"); features++; };
                NSEventModifierFlags flags=(info->modifiers & 1 ? NSEventModifierFlagShift : 0) | (info->modifiers & 2 ? NSEventModifierFlagOption : 0);
                NSEvent *key=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:flags timestamp:0 windowNumber:0 context:nil characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:info->key];
                [root handleEvent:key];
                NSCAssert(features==before+(info->implemented ? 1 : 0),@"unsupported rows never dispatch cheats");
            }
            NSCAssert(features==26,@"all 26 feature commands dispatch");
            __block double edited=0;
            root.valueHandler=^(DI2Feature feature,double value){ NSCAssert(feature==DI2FeatureMoney,@"numeric field targets selected feature");edited=value; };
            [root editFeature:DI2FeatureMoney];
            NSEvent *digits=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil characters:@"25000" charactersIgnoringModifiers:@"25000" isARepeat:NO keyCode:20];
            NSEvent *enter=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil characters:@"\r" charactersIgnoringModifiers:@"\r" isARepeat:NO keyCode:36];
            [root handleEvent:digits]; [root handleEvent:enter]; NSCAssert(edited==25000,@"inline numeric editing commits parsed target");
            [root headerClick:NSMakePoint(495,10)]; NSCAssert(root.panel.frame.size.height<45,@"folded header footprint");
            [root headerClick:NSMakePoint(495,10)]; NSCAssert(root.panel.frame.size.height>300,@"unfold restores compact rows");
            NSDictionary *invalid=DI2NormalizeOverlayOptions(@{@"visible":@"false",@"badge":NSNull.null,@"position":@"outside",@"x":@(-99),@"y":@99,@"scale":@(NAN)});
            NSCAssert([invalid[@"visible"] boolValue] && ![invalid[@"badge"] boolValue]
                && [invalid[@"position"] isEqual:@"top-left"] && [invalid[@"x"] doubleValue]==0
                && [invalid[@"y"] doubleValue]==1 && [invalid[@"scale"] doubleValue]==0.9,@"invalid persisted/IPC values normalize safely");
            NSDictionary *roundTrip=DI2DecodeOverlayOptions(DI2EncodeOverlayOptions(@{@"visible":@NO,@"position":@"bottom-right",@"scale":@1.2}));
            NSCAssert(![roundTrip[@"visible"] boolValue] && [roundTrip[@"position"] isEqual:@"bottom-right"],@"launch environment options round trip");
            NSCAssert([DI2DecodeOverlayOptions(@"[1]")[@"visible"] boolValue],@"non-object JSON rejected");
            NSString *message=DI2OverlayMessage(roundTrip,@"test-session",123);
            NSCAssert([DI2OverlayMessageOptions(message,@"test-session",123) isEqual:roundTrip],@"sandbox-compatible object message round trip");
            NSCAssert(!DI2OverlayMessageOptions(message,@"other-session",123) && !DI2OverlayMessageOptions(message,@"test-session",456)
                && !DI2OverlayMessageOptions(@"{\"pid\":123}",@"test-session",123)
                && !DI2OverlayMessageOptions(@123,@"test-session",123),@"foreign sessions/processes and malformed notifications ignored");
            DI2OverlayRoot *movable=[[DI2OverlayRoot alloc]initWithFrame:NSMakeRect(0,0,1100,720) version:@"test"];
            [movable updateState:ready];
            __block int optionChanges=0,hiddenCommands=0;
            movable.optionsChanged=^(NSDictionary *options) { (void)options; optionChanges++; };
            movable.actionHandler=^(DI2TrainerAction action) { NSCAssert(action==DI2TrainerCash1000,@"hidden F4 dispatch"); hiddenCommands++; };
            ready.features[DI2FeatureGod].active=YES; ready.features[DI2FeatureGod].wanted=YES;
            [movable updateState:ready]; [movable togglePanel:nil];
            [movable handleEvent:f4];
            NSCAssert(hiddenCommands==1 && ready.features[DI2FeatureGod].active && ready.features[DI2FeatureGod].wanted
                && movable.panel.hidden && movable.badge.hidden,@"hiding keeps trainer state and hotkeys active");
            [movable handleEvent:toggle]; NSCAssert(movable.panelVisible && optionChanges==2,@"keyboard restores fully hidden panel");
            for (NSString *anchor in @[@"top-left",@"top-right",@"bottom-left",@"bottom-right",@"center"]) {
                [movable applyOverlayOptions:@{@"position":anchor}];
                NSRect frame=movable.panel.frame;
                NSCAssert(NSContainsRect(movable.bounds,frame),@"all presets remain inside game view");
                if ([anchor hasSuffix:@"left"]) NSCAssert(fabs(NSMinX(frame)-12)<0.01,@"left preset");
                if ([anchor hasSuffix:@"right"]) NSCAssert(fabs(NSMaxX(frame)-1088)<0.01,@"right preset");
                if ([anchor hasPrefix:@"bottom"]) NSCAssert(fabs(NSMaxY(frame)-708)<0.01,@"bottom preset");
                if ([anchor isEqual:@"center"]) NSCAssert(fabs(NSMidX(frame)-550)<0.01 && fabs(NSMidY(frame)-360)<0.01,@"center preset");
            }
            [movable applyOverlayOptions:@{@"position":@"top-left"}];
            [movable beginDraggingAt:NSMakePoint(30,30)]; [movable dragTo:NSMakePoint(230,130)]; [movable endDragging];
            NSCAssert(fabs(movable.panel.frame.origin.x-212)<0.01 && fabs(movable.panel.frame.origin.y-112)<0.01
                && [movable.overlayOptions[@"position"] isEqual:@"free"] && optionChanges==3,@"title drag stores free position once");
            NSDictionary *saved=movable.overlayOptions;
            DI2OverlayRoot *restored=[[DI2OverlayRoot alloc]initWithFrame:movable.frame version:@"test"];
            [restored applyOverlayOptions:DI2DecodeOverlayOptions(DI2EncodeOverlayOptions(saved))];
            NSCAssert(NSEqualRects(restored.panel.frame,movable.panel.frame),@"new game root restores saved free position");
            [movable beginDraggingAt:NSMakePoint(230,130)]; [movable dragTo:NSMakePoint(10000,-10000)]; [movable endDragging];
            NSCAssert(fabs(NSMaxX(movable.panel.frame)-1088)<0.01 && fabs(NSMinY(movable.panel.frame)-12)<0.01,@"drag clamped to visible bounds");
            movable.frame=NSMakeRect(0,0,340,240); [movable layout];
            NSCAssert(NSContainsRect(movable.bounds,movable.panel.frame),@"small window resize keeps moved panel reachable");
            [movable applyOverlayOptions:@{@"draggable":@NO,@"position":@"center"}]; NSRect locked=movable.panel.frame;
            [movable beginDraggingAt:NSMakePoint(10,10)]; [movable dragTo:NSMakePoint(90,90)]; [movable endDragging];
            NSCAssert(NSEqualRects(locked,movable.panel.frame),@"position lock blocks mouse dragging");
            NSCAssert(!ready.features[DI2FeatureMoney].wanted && ready.features[DI2FeatureGod].active,@"layout options do not alter cheat state");
            DI2OverlayRoot *mouseRoot=[[DI2OverlayRoot alloc]initWithFrame:NSMakeRect(0,0,1100,720) version:@"test"];
            [mouseRoot updateState:ready];NSCAssert(mouseRoot.wantsMouseInteraction,@"visible panel defaults to mouse interaction");
            NSEvent *mouseToggle=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:NSEventModifierFlagCommand|NSEventModifierFlagOption timestamp:0 windowNumber:0 context:nil characters:@"^" charactersIgnoringModifiers:@"^" isARepeat:NO keyCode:10];
            [mouseRoot handleEvent:mouseToggle];NSCAssert(!mouseRoot.wantsMouseInteraction && mouseRoot.panelVisible,@"mouse shortcut returns game control without hiding panel");
            [mouseRoot handleEvent:mouseToggle];NSCAssert(mouseRoot.wantsMouseInteraction,@"mouse shortcut releases cursor again");
            [mouseRoot editFeature:DI2FeatureMoney];
            NSEvent *escape=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil characters:@"\033" charactersIgnoringModifiers:@"\033" isARepeat:NO keyCode:53];
            [mouseRoot handleEvent:escape];NSCAssert(mouseRoot.panelVisible,@"first Escape cancels numeric editing");
            [mouseRoot handleEvent:escape];NSCAssert(!mouseRoot.panelVisible && !mouseRoot.wantsMouseInteraction && ready.features[DI2FeatureGod].active,@"Escape closes overlay and releases mouse while preserving cheats");
            NSCAssert(![mouseRoot handleEvent:escape],@"hidden overlay does not swallow the game menu's Escape");
            [mouseRoot applyOverlayOptions:@{@"visible":@YES,@"mouse":@NO}];NSCAssert(!mouseRoot.wantsMouseInteraction && mouseRoot.panelVisible,@"display-only overlay can stay visible during play");
            DI2OverlayRoot *hotkeyRoot=[[DI2OverlayRoot alloc]initWithFrame:NSMakeRect(0,0,1100,720) version:@"test"];
            [hotkeyRoot updateState:ready];
            DI2OverlayShortcuts *router=[DI2OverlayShortcuts new];router.enabled=YES;
            [router setRegistered:YES shortcut:DI2ShortcutPanel];[router setRegistered:YES shortcut:DI2ShortcutMouse];
            __block NSUInteger shortcutCalls=0;
            router.handler=^(DI2OverlayShortcut action) {
                shortcutCalls++;
                if(action==DI2ShortcutPanel)[hotkeyRoot togglePanel:nil];else [hotkeyRoot toggleMouseInteraction];
            };
            NSCAssert([router ownsLocalEvent:toggle],@"registered caret key belongs only to native route");
            // Simulate either delivery order. Local echoes must not toggle back.
            [router nativeShortcut:DI2ShortcutPanel pressed:YES];
            if(![router ownsLocalEvent:toggle])[hotkeyRoot handleEvent:toggle];
            NSCAssert(!hotkeyRoot.panelVisible && shortcutCalls==1,@"native press hides exactly once, including local duplicate");
            [router nativeShortcut:DI2ShortcutPanel pressed:YES];
            [hotkeyRoot updateState:ready];
            NSCAssert(!hotkeyRoot.panelVisible && shortcutCalls==1,@"held key and state polling do not reopen overlay");
            [router nativeShortcut:DI2ShortcutPanel pressed:NO];
            if(![router ownsLocalEvent:toggle])[hotkeyRoot handleEvent:toggle];
            [router nativeShortcut:DI2ShortcutPanel pressed:YES];
            NSCAssert(hotkeyRoot.panelVisible && shortcutCalls==2,@"next press reopens once when local echo arrives first");
            [router nativeShortcut:DI2ShortcutPanel pressed:NO];
            NSCAssert([router ownsLocalEvent:mouseToggle],@"native mouse shortcut has the same ownership rule");
            [router nativeShortcut:DI2ShortcutMouse pressed:YES];
            NSCAssert(hotkeyRoot.panelVisible && !hotkeyRoot.wantsMouseInteraction,@"native mouse hotkey does not close panel");
            router.enabled=NO;
            NSCAssert(![router nativeShortcut:DI2ShortcutPanel pressed:YES] && ![router ownsLocalEvent:toggle],@"inactive app ignores native shortcuts and releases local ownership");
            router.enabled=YES;[router nativeShortcut:DI2ShortcutMouse pressed:YES];
            NSCAssert(hotkeyRoot.wantsMouseInteraction,@"focus change clears a potentially missed key release");
            [router setRegistered:NO shortcut:DI2ShortcutPanel];
            NSCAssert(![router ownsLocalEvent:toggle] && ![router nativeShortcut:DI2ShortcutPanel pressed:YES],@"failed native registration leaves the AppKit fallback available");
            [hotkeyRoot handleEvent:toggle];NSCAssert(!hotkeyRoot.panelVisible,@"dead-key AppKit fallback remains functional");
            NSEvent *ansiCaret=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:NSEventModifierFlagCommand|NSEventModifierFlagShift timestamp:0 windowNumber:0 context:nil characters:@"^" charactersIgnoringModifiers:@"^" isARepeat:NO keyCode:22];
            NSCAssert(DI2OverlayToggleEvent(ansiCaret) && ![router ownsLocalEvent:ansiCaret],@"non-ISO caret layouts retain character-based fallback");
            NSEvent *heldCaret=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:NSEventModifierFlagCommand timestamp:0 windowNumber:0 context:nil characters:@"" charactersIgnoringModifiers:@"" isARepeat:YES keyCode:10];
            [hotkeyRoot handleEvent:heldCaret];NSCAssert(!hotkeyRoot.panelVisible,@"fallback key repeat does not reopen panel");
            NSCAssert(ready.features[DI2FeatureGod].active,@"shortcut routes never reset active cheats");
            testMouseRouting();
            puts("Overlay state, cursor controls, click-through, resize and hotkey tests passed.");
            return 0;
        }
        NSApplication *app = NSApplication.sharedApplication;
        HostDelegate *delegate = [HostDelegate new];
        app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        [app run];
    }
    return 0;
}
