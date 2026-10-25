// SPDX-License-Identifier: GPL-3.0-only
#import "Overlay.h"
#import <os/log.h>
#import <unistd.h>
#import <limits.h>
#import <mach-o/dyld.h>

static os_log_t runtimeLog;
static NSMutableArray<DI2OverlayRoot *> *roots;
static NSString *sessionToken;
static id monitor;
static NSTimer *attachmentTimer;

static BOOL supportedProcess(void) {
    NSString *identifier = NSBundle.mainBundle.bundleIdentifier;
#ifdef DI2_OVERLAY_TEST
    return [identifier isEqualToString:@"local.deadisland2.trainer-test"];
#else
    if (![identifier isEqualToString:@"com.plaion.DeadIsland2Usk"]) return NO;
    NSString *target = NSProcessInfo.processInfo.environment[@"DI2_TRAINER_TARGET"];
    if (!target.length) return NO;
    uint32_t size = PATH_MAX;
    char executable[PATH_MAX], actual[PATH_MAX], expected[PATH_MAX];
    if (_NSGetExecutablePath(executable, &size) || !realpath(executable, actual)
        || !realpath(target.fileSystemRepresentation, expected)) return NO;
    return strcmp(actual, expected) == 0 && strcmp(strrchr(actual, '/') + 1, "DeadIsland2") == 0;
#endif
}

static void attachToGameWindow(void) {
    if (!NSApp || ![NSThread isMainThread]) return;
    // Keep only live roots; moving/recreated game windows are discovered again.
    for (DI2OverlayRoot *root in roots.copy) {
        if (!root.window || !root.superview || root.window.contentView != root.superview) {
            [root removeFromSuperview]; [roots removeObjectIdenticalTo:root];
        }
    }
    NSWindow *candidate = nil;
    CGFloat largest = 0;
    for (NSWindow *window in NSApp.windows) {
        if (!window.isVisible || window.isMiniaturized || window.attachedSheet
            || [window isKindOfClass:NSPanel.class] || !window.contentView) continue;
        NSSize size = window.contentView.bounds.size;
        CGFloat area = size.width * size.height;
        if (size.width >= 640 && size.height >= 360 && area > largest) { candidate = window; largest = area; }
    }
    if (!candidate) return;
    NSView *content = candidate.contentView;
    for (DI2OverlayRoot *root in roots) {
        if (root.superview == content) {
            root.frame = content.bounds;
            return;
        }
    }
    NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?";
    DI2OverlayRoot *root = [[DI2OverlayRoot alloc] initWithFrame:content.bounds version:version];
    [content addSubview:root positioned:NSWindowAbove relativeTo:nil];
    [roots addObject:root];
    os_log(runtimeLog, "Overlay attached in game process pid=%{public}d window=%{public}s class=%{public}s",
        getpid(), (candidate.title ?: @"").UTF8String, NSStringFromClass(content.class).UTF8String);
    if (sessionToken.length) {
        @try {
            [NSDistributedNotificationCenter.defaultCenter postNotificationName:@"local.deadisland2.trainer.attached"
                object:sessionToken userInfo:@{@"pid": @(getpid()), @"version": @"0.1.0"} deliverImmediately:YES];
        } @catch (NSException *exception) {
            os_log(runtimeLog, "Optional launcher status notification unavailable: %{public}s", exception.name.UTF8String);
        }
    }
}

__attribute__((constructor)) static void startOverlay(void) {
    @autoreleasepool {
        runtimeLog = os_log_create("local.deadisland2.trainer", "overlay");
        if (!supportedProcess()) { os_log_error(runtimeLog, "Unsupported process; overlay not installed"); return; }
        sessionToken = [NSProcessInfo.processInfo.environment[@"DI2_TRAINER_SESSION"] copy];
        os_log(runtimeLog, "Trainer overlay library loaded in pid=%{public}d", getpid());
        dispatch_async(dispatch_get_main_queue(), ^{
            roots = [NSMutableArray new];
            monitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
                if (!DI2OverlayToggleEvent(event)) return event;
                BOOL handled = NO;
                for (DI2OverlayRoot *root in roots) {
                    if (root.window == event.window || root.window.isKeyWindow) { [root togglePanel:nil]; handled = YES; }
                }
                return handled ? nil : event;
            }];
            attachmentTimer = [NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer) { (void)timer; attachToGameWindow(); }];
            [NSRunLoop.mainRunLoop addTimer:attachmentTimer forMode:NSRunLoopCommonModes];
            attachToGameWindow();
        });
    }
}
