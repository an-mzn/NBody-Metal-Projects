#pragma once

#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>
#include <algorithm>
#include <cmath>

@interface ViewerControlsView : MTKView
@property(nonatomic) float cameraZoom;
@property(nonatomic) float cameraPanX;
@property(nonatomic) float cameraPanY;
@property(nonatomic) float cameraRoll;
@property(nonatomic) BOOL cameraPathActive;
@property(nonatomic) CFAbsoluteTime cameraPathStartTime;
@property(nonatomic, copy) dispatch_block_t pauseHandler;
@property(nonatomic, copy) dispatch_block_t restartHandler;
- (void)resetCamera;
- (void)startCameraPath;
- (void)updateCameraPath;
@end

@implementation ViewerControlsView
- (instancetype)initWithFrame:(NSRect)frame device:(id<MTLDevice>)device {
  if ((self = [super initWithFrame:frame device:device])) [self resetCamera];
  return self;
}
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (void)resetCamera {
  self.cameraPathActive = NO;
  self.cameraZoom = 1.0f;
  self.cameraPanX = 0.0f;
  self.cameraPanY = 0.0f;
  self.cameraRoll = 0.0f;
}
- (void)mouseDown:(NSEvent *)event {
  [self.window makeFirstResponder:self];
  if (event.clickCount == 2) [self resetCamera];
}
- (void)rightMouseDown:(NSEvent *)event {
  [self.window makeFirstResponder:self];
  self.cameraPathActive = NO;
}
- (void)rightMouseDragged:(NSEvent *)event {
  self.cameraPathActive = NO;
  const float height = (float)std::max(1.0, self.bounds.size.height);
  const float width = (float)std::max(1.0, self.bounds.size.width);
  self.cameraPanX += 2.0f * (float)event.deltaX / width / self.cameraZoom;
  self.cameraPanY -= 2.0f * (float)event.deltaY / height / self.cameraZoom;
}
- (void)mouseDragged:(NSEvent *)event {
  self.cameraPathActive = NO;
  self.cameraRoll = std::remainder(self.cameraRoll + (float)event.deltaX * 0.008f,
                                   6.2831853f);
}
- (void)scrollWheel:(NSEvent *)event {
  self.cameraPathActive = NO;
  self.cameraZoom = std::clamp(self.cameraZoom *
      std::exp((float)event.scrollingDeltaY * 0.02f), 0.2f, 8.0f);
}
- (void)startCameraPath {
  [self resetCamera];
  self.cameraPathStartTime = CFAbsoluteTimeGetCurrent();
  self.cameraPathActive = YES;
}
- (void)updateCameraPath {
  if (!self.cameraPathActive) return;
  const double phase = 6.28318530718 *
      (CFAbsoluteTimeGetCurrent() - self.cameraPathStartTime) / 36.0;
  self.cameraRoll = 0.32f * (float)sin(phase);
  self.cameraZoom = 1.0f + 0.13f * (float)(sin(phase + 0.7) - sin(0.7));
}
- (void)keyDown:(NSEvent *)event {
  NSEventModifierFlags flags = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
  NSString *key = event.charactersIgnoringModifiers.lowercaseString;
  if (event.keyCode == 49 && !(flags & (NSEventModifierFlagCommand | NSEventModifierFlagControl | NSEventModifierFlagOption))) {
    if (self.pauseHandler) self.pauseHandler();
    return;
  }
  if ([key isEqualToString:@"r"] && !(flags & (NSEventModifierFlagCommand | NSEventModifierFlagControl | NSEventModifierFlagOption))) {
    if (self.restartHandler) self.restartHandler();
    return;
  }
  if ([key isEqualToString:@"c"] && !(flags & (NSEventModifierFlagCommand | NSEventModifierFlagControl | NSEventModifierFlagOption))) {
    [self resetCamera];
    return;
  }
  if ([key isEqualToString:@"1"] && !(flags & (NSEventModifierFlagCommand | NSEventModifierFlagControl | NSEventModifierFlagOption))) {
    [self startCameraPath];
    return;
  }
  if ([key isEqualToString:@"f"] &&
      (flags & (NSEventModifierFlagCommand | NSEventModifierFlagControl)) ==
          (NSEventModifierFlagCommand | NSEventModifierFlagControl) &&
      !(flags & NSEventModifierFlagOption)) {
    [self.window toggleFullScreen:nil];
    return;
  }
  [super keyDown:event];
}
@end

static inline void installViewerFullScreenMenu(void) {
  NSMenu *mainMenu = NSApp.mainMenu ?: [NSMenu new];
  NSMenuItem *viewItem = [[NSMenuItem alloc] initWithTitle:@"View" action:nil keyEquivalent:@""];
  NSMenu *viewMenu = [NSMenu new];
  NSMenuItem *fullScreenItem = [[NSMenuItem alloc] initWithTitle:@"Toggle Full Screen"
      action:@selector(toggleFullScreen:) keyEquivalent:@"f"];
  fullScreenItem.keyEquivalentModifierMask = NSEventModifierFlagControl | NSEventModifierFlagCommand;
  [viewMenu addItem:fullScreenItem];
  viewItem.submenu = viewMenu;
  [mainMenu addItem:viewItem];
  NSApp.mainMenu = mainMenu;
}
