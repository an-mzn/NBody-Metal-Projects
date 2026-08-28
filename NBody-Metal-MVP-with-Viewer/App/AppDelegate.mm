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
@end

@implementation ViewDelegate
- (instancetype)initWithView:(MTKView*)view {
  if ((self=[super init])) {
    _dev = view.device;
    NSURL* cwd = [NSURL fileURLWithPath:[[NSFileManager defaultManager] currentDirectoryPath]];
    NSURL* nbodyLib = [cwd URLByAppendingPathComponent:@"Shaders/nbody.metallib"];
    NSURL* pointsLib = [cwd URLByAppendingPathComponent:@"Shaders/points.metallib"];

    _N = 50000;
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

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size {}
- (void)drawInMTKView:(MTKView*)view {
  _sim->step(0.016f);

  id<CAMetalDrawable> drawable = view.currentDrawable;
  MTLRenderPassDescriptor* rpd = view.currentRenderPassDescriptor;
  if (!drawable || !rpd) return;

  id<MTLCommandBuffer> cb = [_sim->commandQueue() commandBuffer];
  id<MTLRenderCommandEncoder> enc = [cb renderCommandEncoderWithDescriptor:rpd];
  [enc setRenderPipelineState:_pipe];
  [enc setVertexBuffer:_sim->positionBuffer() offset:0 atIndex:0];
  [enc drawPrimitives:MTLPrimitiveTypePoint vertexStart:0 vertexCount:_N];
  [enc endEncoding];
  [cb presentDrawable:drawable];
  [cb commit];
}
@end

@interface AppDelegate : NSObject<NSApplicationDelegate>
@property(strong) NSWindow* window;
@property(strong) MTKView* view;
@property(strong) ViewDelegate* delegate;
@end

@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification*)n {
  NSRect r = NSMakeRect(100,100,960,600);
  self.window = [[NSWindow alloc] initWithContentRect:r
    styleMask:(NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable)
    backing:NSBackingStoreBuffered defer:NO];
  id<MTLDevice> dev = MTLCreateSystemDefaultDevice();
  self.view = [[MTKView alloc] initWithFrame:r device:dev];
  self.view.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
  self.view.clearColor = MTLClearColorMake(0.05,0.07,0.10,1);
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
