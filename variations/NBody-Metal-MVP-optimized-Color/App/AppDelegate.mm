#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import "../Source/Renderer.hpp"
#import "../Source/Sim.hpp"

@interface ViewDelegate : NSObject<MTKViewDelegate>
@property(nonatomic,strong) id<MTLDevice> dev;
@property(nonatomic,strong) id<MTLRenderPipelineState> pipe;
@property(nonatomic) Renderer* sim;
@property(nonatomic) uint32_t N;
@property(nonatomic) BOOL paused;
- (void)togglePause;
- (void)restart;
@end

@implementation ViewDelegate
- (instancetype)initWithView:(MTKView*)view {
  if ((self=[super init])) {
    _paused = YES;
    _dev = view.device;
    NSURL* cwd = [NSURL fileURLWithPath:[[NSFileManager defaultManager] currentDirectoryPath]];
    NSURL* nbodyLib = [cwd URLByAppendingPathComponent:@"Shaders/nbody.metallib"];
    NSURL* pointsLib = [cwd URLByAppendingPathComponent:@"Shaders/points.metallib"];

    _N = 30000;
    _sim = new Renderer(_dev, nbodyLib, _N);

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

- (void)togglePause { self.paused = !self.paused; }
- (void)restart {
  SimInit init = makeInit(_N, 42);
  _sim->uploadInitialData(init.posXY.data(), init.velXY.data(), init.mass.data());
  self.paused = YES;
}

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size {}
- (void)drawInMTKView:(MTKView*)view {
  if (!_paused) _sim->step(0.008f, false);

  id<CAMetalDrawable> drawable = view.currentDrawable;
  MTLRenderPassDescriptor* rpd = view.currentRenderPassDescriptor;
  if (!drawable || !rpd) return;

  id<MTLCommandBuffer> cb = [_sim->commandQueue() commandBuffer];
  id<MTLRenderCommandEncoder> enc = [cb renderCommandEncoderWithDescriptor:rpd];
  [enc setRenderPipelineState:_pipe];
  [enc setVertexBuffer:_sim->positionBuffer() offset:0 atIndex:0];
  [enc setVertexBuffer:_sim->velocityBuffer() offset:0 atIndex:1];
  [enc drawPrimitives:MTLPrimitiveTypePoint vertexStart:0 vertexCount:_N];
  [enc endEncoding];
  [cb presentDrawable:drawable];
  [cb commit];
}
@end

@interface AppDelegate : NSObject<NSApplicationDelegate>
@property(strong) id quitKeyMonitor;
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
  self.quitKeyMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
      handler:^NSEvent *(NSEvent *event) {
    NSEventModifierFlags flags = event.modifierFlags;
    NSString *key = event.charactersIgnoringModifiers.lowercaseString;
    if ((flags & NSEventModifierFlagControl) &&
        !(flags & (NSEventModifierFlagCommand | NSEventModifierFlagOption)) &&
        ([key isEqualToString:@"c"] || [key isEqualToString:@"\003"])) {
      [NSApp terminate:nil];
      return nil;
    }
    if (event.keyCode == 49) { [self.delegate togglePause]; return nil; }
    if ([key isEqualToString:@"r"]) { [self.delegate restart]; return nil; }
    return event;
  }];

  NSRect r = NSMakeRect(100,100,960,600);
  self.window = [[NSWindow alloc] initWithContentRect:r
    styleMask:(NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable)
    backing:NSBackingStoreBuffered defer:NO];
  id<MTLDevice> dev = MTLCreateSystemDefaultDevice();
  self.view = [[MTKView alloc] initWithFrame:r device:dev];
  self.view.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
  self.view.clearColor = MTLClearColorMake(0.0,0.0,0.0,1);
  self.view.preferredFramesPerSecond = 60;
  self.delegate = [[ViewDelegate alloc] initWithView:self.view];
  self.view.delegate = self.delegate;
  self.window.contentView = self.view;
  [self.window makeKeyAndOrderFront:nil];
}
@end

int main(int argc, const char** argv){
  @autoreleasepool {
    NSApplication* app = [NSApplication sharedApplication];
    AppDelegate* d = [AppDelegate new];
    app.delegate = d;
    [app run];
    return 0;
  }
}
