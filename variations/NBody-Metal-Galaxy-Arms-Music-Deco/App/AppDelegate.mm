#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <AVFoundation/AVFoundation.h>
#import <SoundAnalysis/SoundAnalysis.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "../Source/Renderer.hpp"
#import "../Source/Sim.hpp"
#import "../Source/LaunchPrompt.hpp"
#import "../Source/ViewerControls.hpp"
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <vector>

struct RiffCue {
  double start;
  double end;
  float gravityScale;
};

static constexpr double kCueLookAheadSeconds = 0.55;
static constexpr double kMainSectionDuration = 2.5;

@interface SaxResultsObserver : NSObject<SNResultsObserving>
@property(nonatomic,strong) NSMutableArray<NSDictionary<NSString *, NSNumber *> *> *regions;
@property(nonatomic,copy) void (^regionsDidChange)(NSArray<NSDictionary<NSString *, NSNumber *> *> *regions);
@property(nonatomic) CFTimeInterval lastNotificationTime;
- (NSArray<NSDictionary<NSString *, NSNumber *> *> *)regionsSnapshot;
@end

@implementation SaxResultsObserver
- (instancetype)init {
  if ((self = [super init])) _regions = [NSMutableArray array];
  return self;
}

- (void)request:(id<SNRequest>)request didProduceResult:(id<SNResult>)result {
  if (![result isKindOfClass:[SNClassificationResult class]]) return;
  SNClassificationResult *classificationResult = (SNClassificationResult *)result;
  static NSArray<NSString *> *musicLabels;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    musicLabels = @[@"saxophone", @"trumpet", @"trombone", @"brass", @"flute", @"clarinet",
                    @"piano", @"guitar", @"bass", @"drum", @"percussion", @"violin",
                    @"cello", @"singing", @"music"];
  });
  NSString *matchedLabel = nil;
  double matchedConfidence = 0.0;
  for (SNClassification *candidate in classificationResult.classifications) {
    NSString *label = candidate.identifier.lowercaseString;
    BOOL isMusicalSound = NO;
    for (NSString *keyword in musicLabels) {
      if ([label containsString:keyword]) { isMusicalSound = YES; break; }
    }
    if (isMusicalSound && candidate.confidence >= 0.10) {
      matchedLabel = label;
      matchedConfidence = candidate.confidence;
      break;
    }
  }
  if (!matchedLabel) return;

  double start = CMTimeGetSeconds(classificationResult.timeRange.start);
  double duration = CMTimeGetSeconds(classificationResult.timeRange.duration);
  if (!std::isfinite(start) || !std::isfinite(duration) || duration <= 0.0) return;
  NSDictionary *region = @{@"start": @(start), @"end": @(start + duration),
                           @"confidence": @(matchedConfidence)};
  NSArray *snapshot;
  BOOL shouldNotify = NO;
  @synchronized (self) {
    [self.regions addObject:region];
    CFTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (now - self.lastNotificationTime >= 0.20) {
      self.lastNotificationTime = now;
      snapshot = [self.regions copy];
      shouldNotify = YES;
    }
  }
  if (shouldNotify && self.regionsDidChange) self.regionsDidChange(snapshot);
}

- (NSArray<NSDictionary<NSString *, NSNumber *> *> *)regionsSnapshot {
  @synchronized (self) { return [self.regions copy]; }
}
@end

@interface ViewDelegate : NSObject<MTKViewDelegate> {
  CFAbsoluteTime _trackStartTime;
  int _activeCueIndex;
  std::vector<RiffCue> _riffCues;
  NSUInteger _analysisGeneration;
}
@property(nonatomic,strong) id<MTLDevice> dev;
@property(nonatomic,strong) id<MTLRenderPipelineState> pipe;
@property(nonatomic,strong) AVAudioEngine *audioEngine;
@property(nonatomic,strong) AVAudioPlayerNode *player;
@property(nonatomic,strong) AVAudioFile *audioFile;
@property(nonatomic,strong) AVAudioFile *playbackFile;
@property(nonatomic,strong) SNAudioFileAnalyzer *audioAnalyzer;
@property(nonatomic,strong) SaxResultsObserver *analysisObserver;
@property(nonatomic) Renderer* sim;
@property(nonatomic) uint32_t N;
@property(nonatomic) float pointSizeScale;
@property(nonatomic) float simulationSpeed;
@property(nonatomic) float gravityScale;
@property(nonatomic) BOOL paused;
- (void)togglePause;
- (void)restart;
- (void)loadAudioURL:(NSURL *)url;
- (BOOL)startPlayback;
- (void)stopAudio;
- (void)buildRiffCuesFromRegions:(NSArray<NSDictionary<NSString *, NSNumber *> *> *)regions;
@end

@implementation ViewDelegate
- (instancetype)initWithView:(MTKView*)view particleCount:(uint32_t)particleCount particleSizeScale:(float)particleSizeScale simulationSpeed:(float)simulationSpeed gravityScale:(float)gravityScale {
  if ((self=[super init])) {
    self.paused = YES;
    _trackStartTime = 0.0;
    _activeCueIndex = -1;
    _analysisGeneration = 0;
    _dev = view.device;
    NSURL* cwd = [NSURL fileURLWithPath:[[NSFileManager defaultManager] currentDirectoryPath]];
    NSURL* nbodyLib = [cwd URLByAppendingPathComponent:@"Shaders/nbody.metallib"];
    NSURL* pointsLib = [cwd URLByAppendingPathComponent:@"Shaders/points.metallib"];

    _N = particleCount;
    _pointSizeScale = particleSizeScale;
    _simulationSpeed = simulationSpeed;
    _gravityScale = gravityScale;
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
  AVAudioTime *playerTime = [self.player lastRenderTime];
  AVAudioTime *playerTimeInNode = playerTime ? [self.player playerTimeForNodeTime:playerTime] : nil;
  double trackTime = playerTimeInNode && playerTimeInNode.isSampleTimeValid
      ? (double)playerTimeInNode.sampleTime / playerTimeInNode.sampleRate
        - self.audioEngine.outputNode.presentationLatency
      : -1.0;
  float gravityScale = 1.0f;
  if (!self.paused && trackTime >= 0.0) {
    const double cueTime = trackTime + kCueLookAheadSeconds;
    for (const RiffCue& cue : _riffCues) {
      if (cueTime >= cue.start && cueTime < cue.end) {
        gravityScale = cue.gravityScale;
        break;
      }
    }
    _sim->step(0.008f * self.simulationSpeed, false, gravityScale * self.gravityScale);
  }

  id<CAMetalDrawable> drawable = view.currentDrawable;
  MTLRenderPassDescriptor* rpd = view.currentRenderPassDescriptor;
  if (!drawable || !rpd) return;

  id<MTLCommandBuffer> cb = [_sim->commandQueue() commandBuffer];
  id<MTLRenderCommandEncoder> enc = [cb renderCommandEncoderWithDescriptor:rpd];
  [enc setRenderPipelineState:_pipe];
  [enc setVertexBuffer:_sim->positionBuffer() offset:0 atIndex:0];
  ViewerControlsView *controls = (ViewerControlsView *)view;
  [controls updateCameraPath];
  float camera[4] = {controls.cameraZoom, controls.cameraPanX, controls.cameraPanY, controls.cameraRoll};
  [enc setVertexBytes:camera length:sizeof(camera) atIndex:10];
  float particleSize = self.pointSizeScale;
  [enc setVertexBytes:&particleSize length:sizeof(particleSize) atIndex:11];
  [enc drawPrimitives:MTLPrimitiveTypePoint vertexStart:0 vertexCount:_N];
  [enc endEncoding];
  [cb presentDrawable:drawable];
  [cb commit];
}

- (void)togglePause {
  self.paused = !self.paused;
  if (self.paused) [self.player pause];
  else if (self.player) [self.player play];
  else if (self.playbackFile && [self startPlayback]) { }
}
- (void)restart {
  SimInit init = makeInit(_N, 42);
  _sim->uploadInitialData(init.posXY.data(), init.velXY.data(), init.mass.data());
  [self.player stop];
  [self.audioEngine stop];
  self.player = nil;
  self.audioEngine = nil;
  if (self.audioFile) {
    NSError *error = nil;
    self.playbackFile = [[AVAudioFile alloc] initForReading:self.audioFile.url error:&error];
    if (!self.playbackFile) NSLog(@"Could not restart audio: %@", error);
  }
  self.paused = YES;
}

- (void)loadAudioURL:(NSURL *)url {
  NSUInteger generation = ++_analysisGeneration;
  [self stopAudio];
  _riffCues.clear();
  _activeCueIndex = -1;
  SimInit init = makeInit(_N, 42);
  _sim->uploadInitialData(init.posXY.data(), init.velXY.data(), init.mass.data());

  NSError *error = nil;
  self.audioFile = [[AVAudioFile alloc] initForReading:url error:&error];
  if (!self.audioFile) {
    NSLog(@"Could not open audio file %@: %@", url, error);
    return;
  }
  self.playbackFile = [[AVAudioFile alloc] initForReading:url error:&error];
  if (!self.playbackFile) {
    NSLog(@"Could not prepare audio playback for %@: %@", url, error);
    self.audioFile = nil;
    return;
  }

  // Playback begins when the user resumes with Space.
  self.audioAnalyzer = [[SNAudioFileAnalyzer alloc] initWithURL:url error:&error];
  if (!self.audioAnalyzer) { NSLog(@"Audio analysis failed: %@", error); return; }
  SNClassifySoundRequest *request = [[SNClassifySoundRequest alloc]
      initWithClassifierIdentifier:SNClassifierIdentifierVersion1 error:&error];
  if (!request) { NSLog(@"Sound classifier unavailable: %@", error); return; }
  request.overlapFactor = 0.75;
  request.windowDuration = CMTimeMakeWithSeconds(0.5, 1000);
  self.analysisObserver = [SaxResultsObserver new];
  __weak ViewDelegate *weakSelf = self;
  self.analysisObserver.regionsDidChange = ^(NSArray<NSDictionary<NSString *, NSNumber *> *> *regions) {
    dispatch_async(dispatch_get_main_queue(), ^{
      ViewDelegate *owner = weakSelf;
      if (owner && generation == owner->_analysisGeneration) [owner buildRiffCuesFromRegions:regions];
    });
  };
  if (![self.audioAnalyzer addRequest:request withObserver:self.analysisObserver error:&error]) {
    NSLog(@"Audio classification request failed: %@", error);
    return;
  }
  NSApp.keyWindow.title = [NSString stringWithFormat:@"Analyzing %@…", url.lastPathComponent];
  [self.audioAnalyzer analyzeWithCompletionHandler:^(BOOL completed) {
    dispatch_async(dispatch_get_main_queue(), ^{
      ViewDelegate *owner = weakSelf;
      if (!owner || generation != owner->_analysisGeneration) return;
      if (completed) [owner buildRiffCuesFromRegions:[owner.analysisObserver regionsSnapshot]];
      owner.audioAnalyzer = nil;
      owner.analysisObserver = nil;
      NSApp.keyWindow.title = [NSString stringWithFormat:@"Galaxy Arms — %@", url.lastPathComponent];
    });
  }];
}

- (void)buildRiffCuesFromRegions:(NSArray<NSDictionary<NSString *, NSNumber *> *> *)regions {
  _riffCues.clear();
  struct DetectedInterval { double start; double end; double confidence; };
  std::vector<DetectedInterval> detected;
  detected.reserve(regions.count);
  for (NSDictionary<NSString *, NSNumber *> *region in regions) {
    double start = region[@"start"].doubleValue;
    double end = region[@"end"].doubleValue;
    double confidence = region[@"confidence"].doubleValue;
    if (start >= 0.0 && end > start) detected.push_back({start, end, confidence});
  }
  std::sort(detected.begin(), detected.end(), [](const auto& a, const auto& b) { return a.start < b.start; });

  std::vector<DetectedInterval> merged;
  for (const auto& interval : detected) {
    if (!merged.empty() && interval.start <= merged.back().end + 0.15) {
      merged.back().end = std::max(merged.back().end, interval.end);
      merged.back().confidence = std::max(merged.back().confidence, interval.confidence);
    } else {
      merged.push_back(interval);
    }
  }

  size_t mainSections = 0;
  for (size_t i = 0; i < merged.size(); ++i) {
    const double duration = merged[i].end - merged[i].start;
    const bool isMainSection = duration >= kMainSectionDuration || merged[i].confidence >= 0.70;
    if (isMainSection) ++mainSections;
    const float push = isMainSection ? 7.0f : 3.5f;
    const float release = isMainSection ? 0.08f : 0.35f;
    _riffCues.push_back({merged[i].start, merged[i].end, (i % 2 == 0) ? push : release});
  }
  std::fprintf(stderr, "Detected %zu musical sections (%zu major). Major passages trigger stronger gravity changes.\n",
               _riffCues.size(), mainSections);
  std::fflush(stderr);
}

- (BOOL)startPlayback {
  if (!self.audioFile || !self.playbackFile) return NO;
  NSError *error = nil;
  self.audioEngine = [AVAudioEngine new];
  self.player = [AVAudioPlayerNode new];
  [self.audioEngine attachNode:self.player];
  if (![self.audioEngine connect:self.player to:self.audioEngine.mainMixerNode format:self.audioFile.processingFormat error:&error]) {
    NSLog(@"Could not connect audio player: %@", error);
    return NO;
  }
  [self.audioEngine prepare];
  if (![self.audioEngine startAndReturnError:&error]) {
    NSLog(@"Could not start audio engine: %@", error);
    return NO;
  }
  [self.player scheduleFile:self.playbackFile atTime:nil completionHandler:nil];
  if (![self.player playAndReturnError:&error]) {
    NSLog(@"Could not play audio file: %@", error);
    return NO;
  }
  return YES;
}

- (void)stopAudio {
  [self.audioAnalyzer cancelAnalysis];
  self.audioAnalyzer = nil;
  self.analysisObserver = nil;
  [self.player stop];
  [self.audioEngine stop];
  self.player = nil;
  self.audioEngine = nil;
  self.playbackFile = nil;
}
@end

@interface AppDelegate : NSObject<NSApplicationDelegate>
- (void)returnToSetup;
@property(strong) id quitKeyMonitor;
@property(strong) NSURL *selectedAudioURL;
@property(nonatomic) BOOL isShowingSetup;
@property(strong) NSWindow* window;
@property(strong) ViewerControlsView* view;
@property(strong) ViewDelegate* delegate;
@end

@implementation AppDelegate
- (void)openAudio:(id)sender {
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  panel.title = @"Choose an audio track";
  panel.prompt = @"Analyze and Play";
  panel.canChooseFiles = YES;
  panel.canChooseDirectories = NO;
  panel.allowsMultipleSelection = NO;
  panel.allowedContentTypes = @[UTTypeAudio];
  if ([panel runModal] == NSModalResponseOK && panel.URL) {
    [self.delegate loadAudioURL:panel.URL];
  }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
  return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
  if (self.quitKeyMonitor) [NSEvent removeMonitor:self.quitKeyMonitor];
  [self.delegate stopAudio];
}

- (void)applicationDidFinishLaunching:(NSNotification*)n {
  uint32_t particleCount = 30000;
  NSURL *selectedAudioURL = nil;
  float particleSizeScale = 1.0f;
  float simulationSpeed = 1.0f;
  float gravityScale = 1.0f;
  if (!presentLaunchPrompt(YES, 30000, &particleCount, &selectedAudioURL, &particleSizeScale, &simulationSpeed, &gravityScale)) {
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
  [previousDelegate stopAudio];
  [previousWindow orderOut:nil];

  uint32_t particleCount = self.delegate.N;
  float particleSizeScale = self.delegate.pointSizeScale;
  float simulationSpeed = self.delegate.simulationSpeed;
  float gravityScale = self.delegate.gravityScale;
  NSURL *selectedAudioURL = self.selectedAudioURL;
  BOOL supportsAudio = YES;
  BOOL shouldStart = presentLaunchPrompt(supportsAudio, particleCount, &particleCount,
      &selectedAudioURL, &particleSizeScale, &simulationSpeed, &gravityScale);
  self.isShowingSetup = NO;
  if (!shouldStart) {
    bringViewerWindowToFront(previousWindow, self.view);
    return;
  }

  if ([previousDelegate respondsToSelector:@selector(stopAudio)]) [previousDelegate stopAudio];
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
  NSMenu *mainMenu = [NSMenu new];
  NSMenuItem *fileMenuItem = [[NSMenuItem alloc] initWithTitle:@"File" action:nil keyEquivalent:@""];
  NSMenu *fileMenu = [NSMenu new];
  NSMenuItem *openItem = [[NSMenuItem alloc] initWithTitle:@"Open Audio…" action:@selector(openAudio:) keyEquivalent:@"o"];
  openItem.target = self;
  [fileMenu addItem:openItem];
  [fileMenu addItem:[NSMenuItem separatorItem]];
  [fileMenu addItemWithTitle:@"Quit Galaxy Arms Music Deco" action:@selector(terminate:) keyEquivalent:@"q"];
  [fileMenuItem setSubmenu:fileMenu];
  [mainMenu addItem:fileMenuItem];
  NSApp.mainMenu = mainMenu;

  installViewerFullScreenMenu();
  NSRect r = NSMakeRect(100,100,960,600);
  self.window = [[NSWindow alloc] initWithContentRect:r
    styleMask:(NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable)
    backing:NSBackingStoreBuffered defer:NO];
  self.window.releasedWhenClosed = NO;
  self.window.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
  self.window.title = @"Galaxy Arms Music Deco";
  id<MTLDevice> dev = MTLCreateSystemDefaultDevice();
  self.view = [[ViewerControlsView alloc] initWithFrame:r device:dev];
  self.view.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
  self.view.clearColor = MTLClearColorMake(0.0,0.0,0.0,1);
  self.view.preferredFramesPerSecond = 60;
  self.delegate = [[ViewDelegate alloc] initWithView:self.view particleCount:particleCount particleSizeScale:particleSizeScale simulationSpeed:simulationSpeed gravityScale:gravityScale];
  self.view.delegate = self.delegate;
  __weak ViewDelegate *weakDelegate = self.delegate;
  self.view.pauseHandler = ^{ [weakDelegate togglePause]; };
  self.view.restartHandler = ^{ [weakDelegate restart]; };
  self.window.contentView = self.view;
  bringViewerWindowToFront(self.window, self.view);
  if (selectedAudioURL) {
    [self.delegate loadAudioURL:selectedAudioURL];
  }
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
