#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <AVFoundation/AVFoundation.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "../Source/Renderer.hpp"
#import "../Source/Sim.hpp"
#import "../Source/MusicAnalysis.hpp"
#include "../Source/MotionSmoothing.hpp"
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <signal.h>
#include <vector>

@interface OrbitView : MTKView
@property(nonatomic) float cameraYaw;
@property(nonatomic) float cameraPitch;
@property(nonatomic) float cameraDistance;
@property(nonatomic) float cameraPanX;
@property(nonatomic) float cameraPanY;
@property(nonatomic) BOOL cameraPathActive;
@property(nonatomic) CFAbsoluteTime cameraPathStartTime;
- (void)resetCamera;
- (void)startCameraPath;
- (void)updateCameraPath;
@end

@implementation OrbitView
- (instancetype)initWithFrame:(NSRect)frame device:(id<MTLDevice>)device {
  if ((self = [super initWithFrame:frame device:device])) [self resetCamera];
  return self;
}
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (void)resetCamera {
  self.cameraPathActive = NO;
  self.cameraYaw = 0.0f;
  // Start looking down the spiral's Z axis so the arms form a flat circular projection.
  self.cameraPitch = 0.0f;
  self.cameraDistance = 4.5f;
  self.cameraPanX = 0.0f;
  self.cameraPanY = 0.0f;
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
  const float aspect = (float)(self.bounds.size.width / height);
  const float scaleY = self.cameraDistance / (height * 1.035f);
  self.cameraPanX -= (float)event.deltaX * scaleY * aspect;
  self.cameraPanY += (float)event.deltaY * scaleY;
}
- (void)mouseDragged:(NSEvent *)event {
  self.cameraPathActive = NO;
  self.cameraYaw = std::remainder(self.cameraYaw + (float)event.deltaX * 0.008f, 6.2831853f);
  self.cameraPitch = std::clamp(self.cameraPitch + (float)event.deltaY * 0.008f, -1.48f, 1.48f);
}
- (void)scrollWheel:(NSEvent *)event {
  self.cameraPathActive = NO;
  self.cameraDistance = std::clamp(self.cameraDistance * std::exp((float)event.scrollingDeltaY * 0.02f), 0.15f, 12.0f);
}
- (void)startCameraPath {
  self.cameraPathStartTime = CFAbsoluteTimeGetCurrent();
  self.cameraPathActive = YES;
}
- (void)updateCameraPath {
  if (!self.cameraPathActive) return;
  const double phase = 6.28318530718 * (CFAbsoluteTimeGetCurrent() - self.cameraPathStartTime) / 36.0;
  // Slow aerial orbit with long, gently eased moves between wide and close framing.
  self.cameraYaw = (float)(phase + 0.24 * sin(phase) + 0.10 * sin(2.0 * phase));
  self.cameraPitch = 0.62f + 0.25f * (float)sin(phase + 0.3)
      + 0.09f * (float)sin(2.0 * phase - 0.8);
  self.cameraDistance = 3.9f + 2.0f * (float)sin(phase + 0.7)
      + 0.35f * (float)sin(2.0 * phase - 0.4);
}
- (void)keyDown:(NSEvent *)event {
  if ([event.charactersIgnoringModifiers.lowercaseString isEqualToString:@"c"]) [self resetCamera];
  else [super keyDown:event];
}
@end

@interface ViewDelegate : NSObject<MTKViewDelegate, SCStreamOutput, SCStreamDelegate> {
  CFAbsoluteTime _trackStartTime;
  int _activeCueIndex;
  std::vector<MusicFrame> _musicFrames;
  MusicFrame _visualMusic;
  MusicFrame _visualMusicVelocity;
  double _previousAudioTime;
  double _previousPhysicsTime;
  double _musicFrameDuration;
  NSUInteger _analysisGeneration;
}
@property(nonatomic,strong) id<MTLDevice> dev;
@property(nonatomic,strong) id<MTLRenderPipelineState> pipe;
@property(nonatomic,strong) id<MTLDepthStencilState> depthState;
@property(nonatomic,strong) AVAudioEngine *audioEngine;
@property(nonatomic,strong) AVAudioPlayerNode *player;
@property(nonatomic,strong) AVAudioFile *audioFile;
@property(nonatomic,strong) AVAudioFile *playbackFile;
@property(nonatomic,strong) SCStream *captureStream;
@property(nonatomic,strong) AVAssetWriter *recordingWriter;
@property(nonatomic,strong) AVAssetWriterInput *recordingVideoInput;
@property(nonatomic,strong) AVAssetWriterInput *recordingAudioInput;
@property(nonatomic,strong) dispatch_queue_t recordingQueue;
@property(nonatomic) BOOL recordingSessionStarted;
@property(nonatomic) BOOL recordingWriterStartAttempted;
@property(nonatomic) BOOL recordingStopInProgress;
@property(nonatomic,strong) NSMutableArray *recordingStopCompletions;
@property(nonatomic,weak) MTKView *view;
@property(nonatomic) Renderer* sim;
@property(nonatomic) uint32_t N;
@property(nonatomic) BOOL paused;
- (void)togglePause;
- (void)restart;
- (void)loadAudioURL:(NSURL *)url;
- (BOOL)startPlayback;
- (void)stopAudio;
- (void)recordTrackToURL:(NSURL *)url;
- (void)stopRecording;
- (void)stopRecordingWithCompletion:(dispatch_block_t)completion;
- (BOOL)isRecording;
@end

@implementation ViewDelegate
- (instancetype)initWithView:(MTKView*)view {
  if ((self=[super init])) {
    self.view = view;
    self.paused = YES;
    _trackStartTime = 0.0;
    _activeCueIndex = -1;
    _analysisGeneration = 0;
    _visualMusic = {};
    _visualMusicVelocity = {};
    _previousAudioTime = -1.0;
  _previousPhysicsTime = -1.0;
    _musicFrameDuration = 0.04;
    _recordingQueue = dispatch_queue_create("music.choreography.recording", DISPATCH_QUEUE_SERIAL);
    _recordingStopCompletions = [NSMutableArray array];
    _dev = view.device;
    NSURL* cwd = [NSURL fileURLWithPath:[[NSFileManager defaultManager] currentDirectoryPath]];
    NSURL* nbodyLib = [cwd URLByAppendingPathComponent:@"Shaders/nbody.metallib"];
    NSURL* pointsLib = [cwd URLByAppendingPathComponent:@"Shaders/points.metallib"];

    _N = 30000;
    _sim = new Renderer(_dev, nbodyLib, _N);

    SimInit init = makeInit(_N, 42);
    _sim->uploadInitialData(init.posXYZW.data(), init.velXYZW.data(), init.mass.data());

    NSError* err=nil;
    id<MTLLibrary> lib = [_dev newLibraryWithURL:pointsLib error:&err];
    if (!lib) { NSLog(@"points.metallib load failed: %@", err); abort(); }
    id<MTLFunction> vs = [lib newFunctionWithName:@"vs_points"];
    id<MTLFunction> fs = [lib newFunctionWithName:@"fs_solid"];
    MTLRenderPipelineDescriptor* d = [MTLRenderPipelineDescriptor new];
    d.vertexFunction = vs; d.fragmentFunction = fs;
    d.colorAttachments[0].pixelFormat = view.colorPixelFormat;
    d.colorAttachments[0].blendingEnabled = YES;
    d.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    d.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    d.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    d.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    d.depthAttachmentPixelFormat = view.depthStencilPixelFormat;
    MTLDepthStencilDescriptor *depth = [MTLDepthStencilDescriptor new];
    depth.depthCompareFunction = MTLCompareFunctionLessEqual;
    depth.depthWriteEnabled = YES;
    _depthState = [_dev newDepthStencilStateWithDescriptor:depth];
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
  if (trackTime >= 0.0 && !_musicFrames.empty()) {
    const double position = std::max(0.0, trackTime + 0.08) / _musicFrameDuration;
    const size_t index = std::min((size_t)position, _musicFrames.size() - 1);
    const size_t next = std::min(index + 1, _musicFrames.size() - 1);
    const float fraction = (float)(position - std::floor(position));
    const MusicFrame& a = _musicFrames[index];
    const MusicFrame& b = _musicFrames[next];
    const double delta = _previousAudioTime >= 0.0 ? std::clamp(trackTime - _previousAudioTime, 0.0, 0.1) : 0.016;
    for (auto field : {&MusicFrame::energy, &MusicFrame::attack, &MusicFrame::brightness,
                       &MusicFrame::bass, &MusicFrame::mid, &MusicFrame::treble,
                       &MusicFrame::beat, &MusicFrame::phrase}) {
      const float target = a.*field + (b.*field-a.*field)*fraction;
      const bool transient = field == &MusicFrame::attack || field == &MusicFrame::beat;
      const float emphasis = std::clamp((target - 0.45f) / 0.45f, 0.0f, 1.0f);
      // Spectral features fluctuate from frame to frame; use slower envelopes
      // so musical response feels fluid instead of vibrating with FFT noise.
      const double smoothing = transient ? 0.48 - 0.12 * emphasis
          : (field == &MusicFrame::phrase ? 0.85 : 0.48);
      smoothMusicMotion(_visualMusic.*field, _visualMusicVelocity.*field, target, delta, smoothing);
    }
    _previousAudioTime = trackTime;
    const double physicsDelta = _previousPhysicsTime < 0.0 ? 1.0/60.0 : trackTime-_previousPhysicsTime;
    const float dt = (float)std::clamp(physicsDelta * 0.48, 0.0, 0.02);
    if (!self.paused && dt > 0 && _sim->step(dt, false, 1.15f + 0.45f * _visualMusic.energy) >= 0) {
      _previousPhysicsTime = trackTime;
    }
  }

  id<CAMetalDrawable> drawable = view.currentDrawable;
  MTLRenderPassDescriptor* rpd = view.currentRenderPassDescriptor;
  if (!drawable || !rpd) return;

  id<MTLCommandBuffer> cb = [_sim->commandQueue() commandBuffer];
  id<MTLRenderCommandEncoder> enc = [cb renderCommandEncoderWithDescriptor:rpd];
  [enc setRenderPipelineState:_pipe];
  [enc setDepthStencilState:_depthState];
  [enc setVertexBuffer:_sim->positionBuffer() offset:0 atIndex:0];
  OrbitView *orbit = (OrbitView *)view;
  [orbit updateCameraPath];
  float visualParameters[20] = {(float)std::max(0.0, trackTime), _visualMusic.energy,
      _visualMusic.attack, _visualMusic.brightness,
      (float)(view.drawableSize.width / std::max(1.0, (double)view.drawableSize.height)), orbit.cameraYaw, orbit.cameraPitch, orbit.cameraDistance,
      _visualMusic.bass, _visualMusic.mid, _visualMusic.treble, _visualMusic.beat,
      _visualMusic.phrase, 0, 0, 0,
      orbit.cameraPanX, orbit.cameraPanY, 0, 0};
  [enc setVertexBytes:visualParameters length:sizeof(visualParameters) atIndex:1];
  [enc drawPrimitives:MTLPrimitiveTypePoint vertexStart:0 vertexCount:_N];
  [enc endEncoding];
  [cb presentDrawable:drawable];
  [cb commit];
}

- (void)togglePause {
  self.paused = !self.paused;
  if (self.paused) [self.player pause];
  else if (self.player) {
    NSError *error = nil;
    if (![self.player playAndReturnError:&error]) NSLog(@"Could not resume audio: %@", error);
  }
  else if (self.playbackFile) [self startPlayback];
}
- (void)restart {
  SimInit init = makeInit(_N, 42);
  _sim->uploadInitialData(init.posXYZW.data(), init.velXYZW.data(), init.mass.data());
  _visualMusic = {};
  _visualMusicVelocity = {};
  _previousAudioTime = -1.0;
  _previousPhysicsTime = -1.0;
  [self stopAudio];
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
  _musicFrames.clear();
  _visualMusic = {};
  _visualMusicVelocity = {};
  _previousAudioTime = -1.0;
  _previousPhysicsTime = -1.0;
  _activeCueIndex = -1;
  SimInit init = makeInit(_N, 42);
  _sim->uploadInitialData(init.posXYZW.data(), init.velXYZW.data(), init.mass.data());

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

  NSApp.keyWindow.title = [NSString stringWithFormat:@"Preparing choreography — %@", url.lastPathComponent];
  __weak ViewDelegate *weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    auto analysis = analyzeMusic(url);
    dispatch_async(dispatch_get_main_queue(), ^{
      ViewDelegate *owner = weakSelf;
      if (!owner || generation != owner->_analysisGeneration) return;
      if (analysis.error || analysis.frames.empty()) {
        NSApp.keyWindow.title = @"Audio analysis failed — choose another track";
        NSLog(@"Music analysis failed: %@", analysis.error);
        return;
      }
      owner->_musicFrames = analysis.frames;
      owner->_musicFrameDuration = analysis.frameDuration;
      NSApp.keyWindow.title = [NSString stringWithFormat:@"Music Choreography — %@", url.lastPathComponent];
      // Playback begins when the user resumes with Space.
    });
  });
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
  __weak ViewDelegate *weakSelf = self;
  AVAudioPlayerNode *scheduledPlayer = self.player;
  [self.player scheduleFile:self.playbackFile atTime:nil completionHandler:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      ViewDelegate *owner = weakSelf;
      if (!owner || owner.player != scheduledPlayer) return;
      owner.paused = YES;
      [owner stopRecording];
    });
  }];
  if (![self.player playAndReturnError:&error]) {
    NSLog(@"Could not play audio file: %@", error);
    return NO;
  }
  return YES;
}

- (void)recordTrackToURL:(NSURL *)url {
  if (!self.audioFile || _musicFrames.empty() || self.captureStream) return;
  [SCShareableContent getShareableContentExcludingDesktopWindows:YES onScreenWindowsOnly:YES
      completionHandler:^(SCShareableContent *content, NSError *error) {
    if (error || !content) {
      NSLog(@"Could not access window capture: %@", error);
      return;
    }
    SCWindow *target = nil;
    for (SCWindow *candidate in content.windows) {
      if (candidate.windowID == (CGWindowID)NSApp.keyWindow.windowNumber) { target = candidate; break; }
    }
    if (!target) { NSLog(@"Could not find the choreography window to record."); return; }

    if ([[NSFileManager defaultManager] fileExistsAtPath:url.path] &&
        ![[NSFileManager defaultManager] removeItemAtURL:url error:nil]) {
      NSLog(@"Could not replace existing recording at %@", url.path);
      return;
    }
    NSError *writerError = nil;
    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:url fileType:AVFileTypeMPEG4 error:&writerError];
    if (!writer) { NSLog(@"Could not create recording: %@", writerError); return; }
    // Capture the complete window, including its title bar, at its backing pixel size.
    const CGFloat scale = self.view.window.backingScaleFactor;
    const NSInteger width = std::max<NSInteger>(2, (NSInteger)std::round(target.frame.size.width * scale)) & ~1;
    const NSInteger height = std::max<NSInteger>(2, (NSInteger)std::round(target.frame.size.height * scale)) & ~1;
    NSDictionary *videoSettings = @{AVVideoCodecKey: AVVideoCodecTypeHEVC,
                                    AVVideoWidthKey: @(width), AVVideoHeightKey: @(height),
                                    AVVideoCompressionPropertiesKey: @{
                                      AVVideoAverageBitRateKey: @45000000,
                                      AVVideoExpectedSourceFrameRateKey: @60,
                                      AVVideoMaxKeyFrameIntervalKey: @120
                                    }};
    AVAssetWriterInput *videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    videoInput.expectsMediaDataInRealTime = YES;
    NSDictionary *audioSettings = @{AVFormatIDKey: @(kAudioFormatMPEG4AAC), AVSampleRateKey: @48000,
                                    AVNumberOfChannelsKey: @2, AVEncoderBitRateKey: @192000};
    AVAssetWriterInput *audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
    audioInput.expectsMediaDataInRealTime = YES;
    if (![writer canAddInput:videoInput] || ![writer canAddInput:audioInput]) {
      NSLog(@"Could not configure movie recording inputs."); return;
    }
    [writer addInput:videoInput]; [writer addInput:audioInput];
    self.recordingWriter = writer;
    self.recordingVideoInput = videoInput;
    self.recordingAudioInput = audioInput;
    self.recordingSessionStarted = NO;
    self.recordingWriterStartAttempted = NO;

    SCContentFilter *filter = [[SCContentFilter alloc] initWithDesktopIndependentWindow:target];
    SCStreamConfiguration *configuration = [SCStreamConfiguration new];
    configuration.width = width; configuration.height = height;
    configuration.minimumFrameInterval = CMTimeMake(1, 60);
    configuration.queueDepth = 5;
    configuration.capturesAudio = YES;
    configuration.sampleRate = 48000;
    configuration.channelCount = 2;
    configuration.showsCursor = NO;
    SCStream *stream = [[SCStream alloc] initWithFilter:filter configuration:configuration delegate:self];
    self.captureStream = stream;
    NSError *outputError = nil;
    if (![stream addStreamOutput:self type:SCStreamOutputTypeScreen sampleHandlerQueue:self.recordingQueue error:&outputError] ||
        ![stream addStreamOutput:self type:SCStreamOutputTypeAudio sampleHandlerQueue:self.recordingQueue error:&outputError]) {
      NSLog(@"Could not configure window capture: %@", outputError);
      self.captureStream = nil; self.recordingWriter = nil; return;
    }
    [stream startCaptureWithCompletionHandler:^(NSError *captureError) {
      dispatch_async(dispatch_get_main_queue(), ^{
        if (captureError) {
          NSLog(@"Could not start window recording: %@", captureError);
          self.captureStream = nil; self.recordingWriter = nil; return;
        }
        NSApp.keyWindow.title = [NSString stringWithFormat:@"Recording — %@", url.lastPathComponent];
      });
    }];
  }];
}

- (void)stream:(SCStream *)stream didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(SCStreamOutputType)type {
  if (!CMSampleBufferDataIsReady(sampleBuffer) || !self.recordingWriter) return;
  if (type == SCStreamOutputTypeScreen) {
    // ScreenCaptureKit also sends idle, blank, and suspended notifications as
    // sample buffers. Only complete frames contain a fresh image to encode.
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);
    if (!attachments || CFArrayGetCount(attachments) == 0) return;
    NSDictionary *frameInfo = (__bridge NSDictionary *)CFArrayGetValueAtIndex(attachments, 0);
    NSNumber *frameStatus = frameInfo[SCStreamFrameInfoStatus];
    if (frameStatus.integerValue != SCFrameStatusComplete && frameStatus.integerValue != SCFrameStatusStarted) return;
    if (!self.recordingSessionStarted && !self.recordingWriterStartAttempted) {
      self.recordingWriterStartAttempted = YES;
      CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
      @try {
        if (self.recordingWriter.status != AVAssetWriterStatusUnknown || !CMTIME_IS_VALID(timestamp) || !CMTIME_IS_NUMERIC(timestamp)) {
          NSLog(@"Recording cannot start (writer status %ld, timestamp %@)", (long)self.recordingWriter.status, CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, timestamp)));
          dispatch_async(dispatch_get_main_queue(), ^{ [self stopRecording]; });
          return;
        }
        if (![self.recordingWriter startWriting]) {
          NSLog(@"Could not start recording writer: %@", self.recordingWriter.error);
          dispatch_async(dispatch_get_main_queue(), ^{ [self stopRecording]; });
          return;
        }
        [self.recordingWriter startSessionAtSourceTime:timestamp];
        self.recordingSessionStarted = YES;
      } @catch (NSException *exception) {
        NSLog(@"Recording writer threw while starting: %@ — %@", exception.name, exception.reason);
        dispatch_async(dispatch_get_main_queue(), ^{ [self stopRecording]; });
        return;
      }
    }
    if (self.recordingVideoInput.readyForMoreMediaData && ![self.recordingVideoInput appendSampleBuffer:sampleBuffer]) {
      NSLog(@"Could not append video frame: %@", self.recordingWriter.error);
      dispatch_async(dispatch_get_main_queue(), ^{ [self stopRecording]; });
    }
  } else if (type == SCStreamOutputTypeAudio && self.recordingSessionStarted && self.recordingAudioInput.readyForMoreMediaData) {
    if (![self.recordingAudioInput appendSampleBuffer:sampleBuffer]) {
      NSLog(@"Could not append audio sample: %@", self.recordingWriter.error);
      dispatch_async(dispatch_get_main_queue(), ^{ [self stopRecording]; });
    }
  }
}

- (void)stopRecording {
  [self stopRecordingWithCompletion:nil];
}

- (BOOL)isRecording {
  return self.captureStream != nil || self.recordingWriter != nil;
}

- (void)finishRecordingStop {
  self.recordingStopInProgress = NO;
  NSArray<dispatch_block_t> *completions = [self.recordingStopCompletions copy];
  [self.recordingStopCompletions removeAllObjects];
  for (dispatch_block_t completion in completions) completion();
}

- (void)stopRecordingWithCompletion:(dispatch_block_t)completion {
  if (completion) [self.recordingStopCompletions addObject:[completion copy]];
  if (self.recordingStopInProgress) return;
  self.recordingStopInProgress = YES;
  SCStream *stream = self.captureStream;
  if (!stream) {
    dispatch_async(dispatch_get_main_queue(), ^{ [self finishRecordingStop]; });
    return;
  }
  self.captureStream = nil;
  [stream stopCaptureWithCompletionHandler:^(NSError *error) {
    dispatch_async(self.recordingQueue, ^{
      AVAssetWriter *writer = self.recordingWriter;
      if (!writer) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self finishRecordingStop]; });
        return;
      }
      if (!self.recordingSessionStarted) {
        if (writer.status == AVAssetWriterStatusWriting) [writer cancelWriting];
        [[NSFileManager defaultManager] removeItemAtURL:writer.outputURL error:nil];
        self.recordingWriter = nil; self.recordingVideoInput = nil; self.recordingAudioInput = nil;
        self.recordingWriterStartAttempted = NO;
        dispatch_async(dispatch_get_main_queue(), ^{ [self finishRecordingStop]; });
        return;
      }
      [self.recordingVideoInput markAsFinished];
      [self.recordingAudioInput markAsFinished];
      [writer finishWritingWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
          if (writer.status == AVAssetWriterStatusCompleted) NSLog(@"Recording saved: %@", writer.outputURL.path);
          else {
            NSLog(@"Recording could not be finalized: %@", writer.error ?: error);
            [[NSFileManager defaultManager] removeItemAtURL:writer.outputURL error:nil];
          }
          NSApp.keyWindow.title = [NSString stringWithFormat:@"Music Choreography — %@", self.audioFile.url.lastPathComponent ?: @""];
          self.recordingWriter = nil; self.recordingVideoInput = nil; self.recordingAudioInput = nil;
          self.recordingSessionStarted = NO;
          self.recordingWriterStartAttempted = NO;
          [self finishRecordingStop];
        });
      }];
    });
  }];
}

- (void)stopAudio {
  [self.player stop];
  [self.audioEngine stop];
  self.player = nil;
  self.audioEngine = nil;
  self.playbackFile = nil;
}
@end

@interface AppDelegate : NSObject<NSApplicationDelegate>
@property(strong) id quitKeyMonitor;
@property(strong) NSWindow* window;
@property(strong) MTKView* view;
@property(strong) ViewDelegate* delegate;
@property(nonatomic,strong) dispatch_source_t interruptSource;
@property(nonatomic) BOOL terminateAfterRecording;
@end

@implementation AppDelegate
- (void)recordTrack:(id)sender {
  NSSavePanel *panel = [NSSavePanel savePanel];
  panel.title = @"Save Window Recording";
  panel.prompt = @"Record Track";
  panel.allowedContentTypes = @[UTTypeMPEG4Movie];
  NSString *baseName = self.window.title ?: @"Music Choreography";
  baseName = [baseName stringByDeletingPathExtension];
  panel.nameFieldStringValue = [NSString stringWithFormat:@"%@.mp4", baseName];
  if ([panel runModal] == NSModalResponseOK && panel.URL) [self.delegate recordTrackToURL:panel.URL];
}

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

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
  if (![self.delegate isRecording]) return NSTerminateNow;
  self.terminateAfterRecording = YES;
  __weak AppDelegate *weakSelf = self;
  [self.delegate stopRecordingWithCompletion:^{
    AppDelegate *owner = weakSelf;
    if (owner && owner.terminateAfterRecording) {
      owner.terminateAfterRecording = NO;
      [NSApp replyToApplicationShouldTerminate:YES];
    }
  }];
  return NSTerminateLater;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
  if (self.quitKeyMonitor) [NSEvent removeMonitor:self.quitKeyMonitor];
  if (self.interruptSource) dispatch_source_cancel(self.interruptSource);
  [self.delegate stopAudio];
}

- (void)applicationDidFinishLaunching:(NSNotification*)n {
  // Convert terminal Ctrl-C into a normal AppKit quit request so recording can finalize.
  signal(SIGINT, SIG_IGN);
  self.interruptSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGINT, 0, dispatch_get_main_queue());
  dispatch_source_set_event_handler(self.interruptSource, ^{ [NSApp terminate:nil]; });
  dispatch_resume(self.interruptSource);

  self.quitKeyMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
      handler:^NSEvent *(NSEvent *event) {
    NSEventModifierFlags flags = event.modifierFlags;
    NSString *key = event.charactersIgnoringModifiers.lowercaseString;
    if ([key isEqualToString:@"1"]) { [(OrbitView *)self.view startCameraPath]; return nil; }
    if (event.keyCode == 49) { [self.delegate togglePause]; return nil; }
    if ([key isEqualToString:@"r"] && (flags & NSEventModifierFlagOption)) {
      if ([self.delegate isRecording]) [self.delegate stopRecording];
      else [self recordTrack:nil];
      return nil;
    }
    if ([key isEqualToString:@"r"]) { [self.delegate restart]; return nil; }
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
  [fileMenu addItemWithTitle:@"Quit Music Choreography" action:@selector(terminate:) keyEquivalent:@"q"];
  [fileMenuItem setSubmenu:fileMenu];
  [mainMenu addItem:fileMenuItem];
  NSApp.mainMenu = mainMenu;

  NSRect r = NSMakeRect(100,100,960,600);
  self.window = [[NSWindow alloc] initWithContentRect:r
    styleMask:(NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable)
    backing:NSBackingStoreBuffered defer:NO];
  self.window.title = @"Music Choreography";
  id<MTLDevice> dev = MTLCreateSystemDefaultDevice();
  self.view = [[OrbitView alloc] initWithFrame:r device:dev];
  self.view.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
  self.view.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
  self.view.clearDepth = 1.0;
  self.view.clearColor = MTLClearColorMake(0.0,0.0,0.0,1);
  self.view.preferredFramesPerSecond = 60;
  self.delegate = [[ViewDelegate alloc] initWithView:self.view];
  self.view.delegate = self.delegate;
  self.window.contentView = self.view;
  [self.window makeKeyAndOrderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];
  dispatch_async(dispatch_get_main_queue(), ^{
    NSURL *defaultTrack = [[NSURL fileURLWithPath:[[NSFileManager defaultManager] currentDirectoryPath] isDirectory:YES]
        URLByAppendingPathComponent:@"Spill your time (extended version + slowed).mp3"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:defaultTrack.path]) {
      [self.delegate loadAudioURL:defaultTrack];
    } else {
      [self openAudio:nil];
    }
  });
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
