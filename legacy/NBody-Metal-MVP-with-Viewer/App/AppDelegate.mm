#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import "../Source/Renderer.hpp"
#import "../Source/Sim.hpp"
#import "../Source/LaunchPrompt.hpp"

@interface ViewDelegate : NSObject<MTKViewDelegate>
@property(nonatomic,strong) id<MTLDevice> dev;
@property(nonatomic,strong) id<MTLRenderPipelineState> pipe;
@property(nonatomic) Renderer* sim;
@property(nonatomic) uint32_t N;
@property(nonatomic) float pointSizeScale;
@property(nonatomic) float simulationSpeed;
@property(nonatomic) float gravityScale;
@property(nonatomic) BOOL hasRenderedInitialFrame;
@end

@implementation ViewDelegate
- (instancetype)initWithView:(MTKView*)view particleCount:(uint32_t)particleCount particleSizeScale:(float)particleSizeScale simulationSpeed:(float)simulationSpeed gravityScale:(float)gravityScale {
  if ((self=[super init])) {
    _dev = view.device;
    NSURL* cwd = [NSURL fileURLWithPath:[[NSFileManager defaultManager] currentDirectoryPath]];
    NSURL* nbodyLib = [cwd URLByAppendingPathComponent:@"Shaders/nbody.metallib"];
    NSURL* pointsLib = [cwd URLByAppendingPathComponent:@"Shaders/points.metallib"];

    _N = particleCount;
    _pointSizeScale = particleSizeScale;
    _simulationSpeed = simulationSpeed;
    _gravityScale = gravityScale;
    _sim = new Renderer(_dev, nbodyLib, _N, gravityScale);

    SimInit init = makeInit(_N, 42);
    _sim->uploadInitialData(init.posXY.data(), init.velXY.data(), init.mass.data());

    NSError* err=nil;
    id<MTLLibrary> lib = [_dev newLibraryWithURL:pointsLib error:&err];
    if (!lib) { NSLog(@"points.metallib load failed: %@", err); abort(); }
    id<MTLFunction> vs = [lib newFunctionWithName:@"vs_points"];
    id<MTLFunction> fs = [lib newFunctionWithName:@"fs_solid"];
    MTLRenderPipelineDescriptor* d = [MTLRenderPipelineDescriptor new];
    d.vertexFunction = vs; d.fragmentFunction = fs;
    d.colorAttachments[0].pixelFormat = view.colorPixelFormat;
    NSError* e=nil;
    _pipe = [_dev newRenderPipelineStateWithDescriptor:d error:&e];
    if (!_pipe) { NSLog(@"Failed to create render PSO: %@", e); abort(); }
  }
  return self;
}

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size {}
- (void)drawInMTKView:(MTKView*)view {
  if (self.hasRenderedInitialFrame) _sim->step(0.016f * self.simulationSpeed, false);

  id<CAMetalDrawable> drawable = view.currentDrawable;
  MTLRenderPassDescriptor* rpd = view.currentRenderPassDescriptor;
  if (!drawable || !rpd) return;

  id<MTLCommandBuffer> cb = [_sim->commandQueue() commandBuffer];
  id<MTLRenderCommandEncoder> enc = [cb renderCommandEncoderWithDescriptor:rpd];
  [enc setRenderPipelineState:_pipe];
  [enc setVertexBuffer:_sim->positionBuffer() offset:0 atIndex:0];
  float particleSize = self.pointSizeScale;
  [enc setVertexBytes:&particleSize length:sizeof(particleSize) atIndex:11];
  [enc drawPrimitives:MTLPrimitiveTypePoint vertexStart:0 vertexCount:_N];
  [enc endEncoding];
  [cb presentDrawable:drawable];
  [cb commit];
  self.hasRenderedInitialFrame = YES;
}
@end

@interface AppDelegate : NSObject<NSApplicationDelegate>
- (void)returnToSetup;
@property(strong) id quitKeyMonitor;
@property(strong) NSURL *selectedAudioURL;
@property(nonatomic) BOOL isShowingSetup;
@property(strong) NSWindow* window;
@property(strong) MTKView* view;
@property(strong) ViewDelegate* delegate;
@end

@implementation AppDelegate
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
  return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
  if (self.quitKeyMonitor) [NSEvent removeMonitor:self.quitKeyMonitor];
}

- (void)applicationDidFinishLaunching:(NSNotification*)n {
  uint32_t particleCount = 30000;
  NSURL *selectedAudioURL = nil;
  float particleSizeScale = 1.0f;
  float simulationSpeed = 1.0f;
  float gravityScale = 1.0f;
  if (!presentLaunchPrompt(NO, 30000, &particleCount, &selectedAudioURL, &particleSizeScale, &simulationSpeed, &gravityScale)) {
    [NSApp terminate:nil];
    return;
  }
  self.selectedAudioURL = selectedAudioURL;
  [self launchWithParticleCount:particleCount audioURL:selectedAudioURL particleSizeScale:particleSizeScale simulationSpeed:simulationSpeed gravityScale:gravityScale];
}

- (void)returnToSetup {
  if (self.isShowingSetup) return;
  self.isShowingSetup = YES;
  NSWindow *previousWindow = self.window;
  MTKView *previousView = self.view;
  id previousDelegate = self.delegate;
  [previousWindow orderOut:nil];

  uint32_t particleCount = self.delegate.N;
  float particleSizeScale = self.delegate.pointSizeScale;
  float simulationSpeed = self.delegate.simulationSpeed;
  float gravityScale = self.delegate.gravityScale;
  NSURL *selectedAudioURL = self.selectedAudioURL;
  BOOL supportsAudio = NO;
  BOOL shouldStart = presentLaunchPrompt(supportsAudio, particleCount, &particleCount,
      &selectedAudioURL, &particleSizeScale, &simulationSpeed, &gravityScale);
  self.isShowingSetup = NO;
  if (!shouldStart) {
    bringViewerWindowToFront(previousWindow, self.view);
    return;
  }

  previousView.delegate = nil;
  previousWindow.contentView = nil;
  self.selectedAudioURL = selectedAudioURL;
  [self launchWithParticleCount:particleCount audioURL:selectedAudioURL
      particleSizeScale:particleSizeScale simulationSpeed:simulationSpeed gravityScale:gravityScale];
  if (previousWindow != self.window) [previousWindow close];
}

- (void)launchWithParticleCount:(uint32_t)particleCount audioURL:(NSURL *)selectedAudioURL particleSizeScale:(float)particleSizeScale simulationSpeed:(float)simulationSpeed gravityScale:(float)gravityScale {
  if (self.quitKeyMonitor) { [NSEvent removeMonitor:self.quitKeyMonitor]; self.quitKeyMonitor = nil; }
  self.quitKeyMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
      handler:^NSEvent *(NSEvent *event) {
    NSEventModifierFlags flags = event.modifierFlags;
    NSString *key = event.charactersIgnoringModifiers.lowercaseString;
    if (self.isShowingSetup) return event;
    if ([key isEqualToString:@"s"] &&
        !(flags & (NSEventModifierFlagCommand | NSEventModifierFlagControl | NSEventModifierFlagOption))) {
      dispatch_async(dispatch_get_main_queue(), ^{ [self returnToSetup]; });
      return nil;
    }
    if ((flags & NSEventModifierFlagControl) &&
        !(flags & (NSEventModifierFlagCommand | NSEventModifierFlagOption)) &&
        ([key isEqualToString:@"c"] || [key isEqualToString:@"\003"])) {
      [NSApp terminate:nil];
      return nil;
    }
    return event;
  }];

  NSRect r = NSMakeRect(100,100,960,600);
  self.window = [[NSWindow alloc] initWithContentRect:r
    styleMask:(NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable)
    backing:NSBackingStoreBuffered defer:NO];
  self.window.releasedWhenClosed = NO;
  id<MTLDevice> dev = MTLCreateSystemDefaultDevice();
  self.view = [[MTKView alloc] initWithFrame:r device:dev];
  self.view.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
  self.view.clearColor = MTLClearColorMake(0.0,0.0,0.0,1);
  self.view.preferredFramesPerSecond = 60;
  self.delegate = [[ViewDelegate alloc] initWithView:self.view particleCount:particleCount particleSizeScale:particleSizeScale simulationSpeed:simulationSpeed gravityScale:gravityScale];
  self.view.delegate = self.delegate;
  self.window.contentView = self.view;
  bringViewerWindowToFront(self.window, self.view);
}
@end

int main(int argc, const char** argv){
  @autoreleasepool {
    NSApplication* app = [NSApplication sharedApplication];
    [app setActivationPolicy:NSApplicationActivationPolicyRegular];
    AppDelegate* d = [AppDelegate new];
    app.delegate = d;
    [app run];
    return 0;
  }
}
