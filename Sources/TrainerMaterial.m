// SPDX-License-Identifier: GPL-3.0-only
// Adapted from Mac Trainer Template 1.1.
#import "TrainerMaterial.h"
#import <QuartzCore/QuartzCore.h>

@implementation DI2TrainerMaterial {
    NSView *_material;
    CGFloat _radius;
    id _displayObserver;
}
- (instancetype)initWithContentView:(NSView *)content cornerRadius:(CGFloat)radius {
    if((self=[super initWithFrame:content.frame])) {
        _contentView=content;_radius=radius;_liquidGlassEnabled=YES;
        self.identifier=@"TrainerMaterial";
        [self refreshAppearance];
        __weak DI2TrainerMaterial *weakSelf=self;
        _displayObserver=[NSWorkspace.sharedWorkspace.notificationCenter
            addObserverForName:NSWorkspaceAccessibilityDisplayOptionsDidChangeNotification object:nil
            queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event){(void)event;[weakSelf refreshAppearance];}];
    }return self;
}
- (void)dealloc {if(_displayObserver)[NSWorkspace.sharedWorkspace.notificationCenter removeObserver:_displayObserver];}
- (BOOL)isFlipped {return YES;}
- (BOOL)isOpaque {return NO;}
- (BOOL)allowsLiquidGlass {
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 260000
    if(@available(macOS 26.0,*))return self.liquidGlassEnabled;
#endif
    return NO;
}
- (void)setLiquidGlassEnabled:(BOOL)enabled {_liquidGlassEnabled=enabled;[self refreshAppearance];}
- (void)setTintColor:(NSColor *)color {_tintColor=[color copy];[self updateTint];}
- (void)updateTint {
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 260000
    if(@available(macOS 26.0,*))if([_material isKindOfClass:NSGlassEffectView.class]) {
        ((NSGlassEffectView *)_material).tintColor=self.tintColor;return;
    }
#endif
    if(_materialMode==DI2TrainerMaterialOpaque) {
        [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
            self->_material.layer.backgroundColor=(self.tintColor ?: NSColor.windowBackgroundColor).CGColor;
        }];
    }
}
- (void)viewDidChangeEffectiveAppearance {[super viewDidChangeEffectiveAppearance];[self updateTint];}
- (BOOL)reducesTransparency {return NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceTransparency || NSWorkspace.sharedWorkspace.accessibilityDisplayShouldIncreaseContrast;}
- (void)refreshAppearance {
    BOOL reduced=[self reducesTransparency];
    DI2TrainerMaterialMode mode=reduced ? DI2TrainerMaterialOpaque : [self allowsLiquidGlass] ? DI2TrainerMaterialLiquidGlass : DI2TrainerMaterialVibrancy;
    if(_material && mode==_materialMode){[self updateTint];return;}
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 260000
    if(@available(macOS 26.0,*))if([_material isKindOfClass:NSGlassEffectView.class])((NSGlassEffectView *)_material).contentView=nil;
#endif
    [_contentView removeFromSuperview];[_material removeFromSuperview];
    _materialMode=mode;
    _material=nil;
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 260000
    if(@available(macOS 26.0,*)) {
        if(mode==DI2TrainerMaterialLiquidGlass){
            NSGlassEffectView *glass=[[NSGlassEffectView alloc]initWithFrame:self.bounds];
            glass.cornerRadius=_radius;glass.style=NSGlassEffectViewStyleRegular;
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 270000
            if(@available(macOS 27.0,*))glass.effectIsInteractive=[_contentView isKindOfClass:NSButton.class];
#endif
            glass.contentView=_contentView;_material=glass;
        }
    }
#endif
    if(!_material || mode!=DI2TrainerMaterialLiquidGlass){
        if(mode==DI2TrainerMaterialVibrancy){
            NSVisualEffectView *blur=[[NSVisualEffectView alloc]initWithFrame:self.bounds];
            blur.material=NSVisualEffectMaterialHUDWindow;blur.blendingMode=NSVisualEffectBlendingModeWithinWindow;
            blur.state=NSVisualEffectStateActive;_material=blur;
        }else{
            _material=[[NSView alloc]initWithFrame:self.bounds];_material.wantsLayer=YES;
        }
        _material.wantsLayer=YES;_material.layer.cornerRadius=_radius;_material.layer.masksToBounds=YES;
        [_material addSubview:_contentView];
    }
    _material.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
    _contentView.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
    [self addSubview:_material];[self updateTint];[self layout];
}
- (void)layout {
    [super layout];_material.frame=self.bounds;_contentView.frame=_material.bounds;
    NSSize size=_logicalContentSize.width>0 && _logicalContentSize.height>0 ? _logicalContentSize : _material.bounds.size;
    _contentView.bounds=NSMakeRect(0,0,size.width,size.height);
}
- (NSView *)hitTest:(NSPoint)point {
    // Route directly to existing controls, not the material's private subviews.
    if(self.isHiddenOrHasHiddenAncestor || !NSPointInRect([self convertPoint:point fromView:self.superview],self.bounds))return nil;
    return [_contentView hitTest:[_contentView.superview convertPoint:point fromView:self.superview]];
}
@end
