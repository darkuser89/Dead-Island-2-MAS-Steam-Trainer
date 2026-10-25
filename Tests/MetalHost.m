// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import "Overlay.h"

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
            NSCAssert(!root.panelVisible && root.panel.hidden && !root.badge.hidden, @"hidden panel retains badge");
            root.frame = NSMakeRect(0,0,800,600); [root layout];
            NSCAssert(NSMaxX(root.panel.frame) <= root.bounds.size.width, @"resize stays inside game view");
            NSEvent *f8 = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:100];
            NSCAssert(DI2OverlayToggleEvent(f8), @"F8 toggles");
            NSEvent *other = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil characters:@"a" charactersIgnoringModifiers:@"a" isARepeat:NO keyCode:0];
            NSCAssert(!DI2OverlayToggleEvent(other), @"normal game key is passed through");
            puts("Overlay state, click-through, resize and hotkey tests passed.");
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
