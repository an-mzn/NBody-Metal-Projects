#pragma once

#import <Cocoa/Cocoa.h>
#include <cstdint>
#include "Sim.hpp"

@interface LaunchPromptAccessory : NSObject
@property(nonatomic, strong) NSURL *audioURL;
@property(nonatomic, strong) NSPopUpButton *audioChoice;
@property(nonatomic, strong) NSArray<NSURL *> *preloadedURLs;
@property(nonatomic, strong) NSSlider *sizeSlider;
@property(nonatomic, strong) NSTextField *sizeName;
@property(nonatomic, strong) NSSlider *speedSlider;
@property(nonatomic, strong) NSTextField *speedName;
@property(nonatomic, strong) NSSlider *gravitySlider;
@property(nonatomic, strong) NSTextField *gravityName;
- (void)chooseAudio:(id)sender;
- (void)selectAudioTrack:(id)sender;
- (void)rebuildAudioChoices;
- (void)updateParticleSize:(id)sender;
- (void)updateSimulationSetting:(id)sender;
@end

@implementation LaunchPromptAccessory
- (void)chooseAudio:(id)sender {
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  panel.title = @"Choose an audio track";
  panel.prompt = @"Use Track";
  panel.canChooseFiles = YES;
  panel.canChooseDirectories = NO;
  panel.allowsMultipleSelection = NO;
  panel.allowedFileTypes = @[@"mp3", @"m4a", @"wav", @"aiff", @"caf", @"aac", @"flac"];
  if ([panel runModal] == NSModalResponseOK && panel.URL) self.audioURL = panel.URL;
  [self rebuildAudioChoices];
}
- (void)rebuildAudioChoices {
  [self.audioChoice removeAllItems];
  BOOL hasCustomTrack = self.audioURL != nil;
  for (NSURL *track in self.preloadedURLs) {
    if ([self.audioURL.URLByStandardizingPath isEqual:track.URLByStandardizingPath]) { hasCustomTrack = NO; break; }
  }
  if (hasCustomTrack) {
    NSString *title = [NSString stringWithFormat:@"Selected: %@", self.audioURL.lastPathComponent];
    [self.audioChoice addItemWithTitle:title];
    self.audioChoice.lastItem.representedObject = self.audioURL;
    self.audioChoice.lastItem.target = self;
    self.audioChoice.lastItem.action = @selector(selectAudioTrack:);
  }
  for (NSURL *track in self.preloadedURLs) {
    [self.audioChoice addItemWithTitle:track.lastPathComponent];
    self.audioChoice.lastItem.representedObject = track;
    self.audioChoice.lastItem.target = self;
    self.audioChoice.lastItem.action = @selector(selectAudioTrack:);
  }
  [self.audioChoice addItemWithTitle:@"Choose your own…"];
  self.audioChoice.lastItem.target = self;
  self.audioChoice.lastItem.action = @selector(selectAudioTrack:);
  [self.audioChoice selectItemAtIndex:0];
  for (NSMenuItem *item in self.audioChoice.itemArray) {
    if ([item.representedObject isKindOfClass:NSURL.class] &&
        [[item.representedObject URLByStandardizingPath] isEqual:self.audioURL.URLByStandardizingPath]) {
      [self.audioChoice selectItem:item];
      break;
    }
  }
}
- (void)selectAudioTrack:(id)sender {
  NSMenuItem *item = self.audioChoice.selectedItem;
  if ([item.title isEqualToString:@"Choose your own…"]) {
    [self chooseAudio:sender];
    return;
  }
  if ([item.representedObject isKindOfClass:NSURL.class]) {
    self.audioURL = item.representedObject;
  }
}
- (void)updateParticleSize:(id)sender {
  self.sizeName.stringValue = [NSString stringWithFormat:@"%.2f×", self.sizeSlider.floatValue];
}
- (void)updateSimulationSetting:(id)sender {
  self.speedName.stringValue = [NSString stringWithFormat:@"%.2f×", self.speedSlider.floatValue];
  self.gravityName.stringValue = [NSString stringWithFormat:@"%.2f×", self.gravitySlider.floatValue];
}
@end

static inline BOOL presentLaunchPrompt(BOOL supportsAudio,
                                       uint32_t defaultParticleCount,
                                       uint32_t *particleCount,
                                       NSURL **audioURL,
                                       float *particleSizeScale,
                                       float *simulationSpeed,
                                       float *gravityScale,
                                       StartingShape *startingShape) {
  LaunchPromptAccessory *controller = [LaunchPromptAccessory new];
  const CGFloat width = 520.0;
  const CGFloat height = (supportsAudio ? 272.0 : 226.0) + 46.0;
  NSView *accessory = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, width, height)];

  const CGFloat shapeY = supportsAudio ? 279.0 : 233.0;
  NSTextField *shapeLabel = [NSTextField labelWithString:@"Starting shape"];
  shapeLabel.frame = NSMakeRect(0, shapeY, 160, 24);
  [accessory addSubview:shapeLabel];
  NSPopUpButton *shapeChoice = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(180, shapeY-3, 330, 30) pullsDown:NO];
  for (uint32_t i = 0; i < startingShapeCount; ++i)
    [shapeChoice addItemWithTitle:[NSString stringWithUTF8String:startingShapeName((StartingShape)i)]];
  const uint32_t shapeIndex = startingShape ? (uint32_t)*startingShape : 0;
  [shapeChoice selectItemAtIndex:shapeIndex < startingShapeCount ? shapeIndex : 0];
  [accessory addSubview:shapeChoice];

  NSTextField *countLabel = [NSTextField labelWithString:@"Particle count"];
  countLabel.frame = NSMakeRect(0, 187, 160, 24);
  [accessory addSubview:countLabel];

  NSTextField *countField = [[NSTextField alloc] initWithFrame:NSMakeRect(180, 184, 330, 28)];
  countField.stringValue = [NSString stringWithFormat:@"%u", defaultParticleCount];
  countField.alignment = NSTextAlignmentRight;
  countField.placeholderString = @"100–100,000";
  [accessory addSubview:countField];

  NSTextField *sizeLabel = [NSTextField labelWithString:@"Particle size"];
  sizeLabel.frame = NSMakeRect(0, 141, 160, 24);
  [accessory addSubview:sizeLabel];

  controller.sizeSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(180, 139, 240, 26)];
  controller.sizeSlider.minValue = 0.5;
  controller.sizeSlider.maxValue = 3.0;
  controller.sizeSlider.floatValue = particleSizeScale ? *particleSizeScale : 1.0f;
  controller.sizeSlider.continuous = YES;
  controller.sizeSlider.target = controller;
  controller.sizeSlider.action = @selector(updateParticleSize:);
  [accessory addSubview:controller.sizeSlider];

  controller.sizeName = [NSTextField labelWithString:@"1.00×"];
  controller.sizeName.frame = NSMakeRect(440, 141, 70, 22);
  controller.sizeName.alignment = NSTextAlignmentRight;
  [accessory addSubview:controller.sizeName];

  NSTextField *speedLabel = [NSTextField labelWithString:@"Simulation speed"];
  speedLabel.frame = NSMakeRect(0, 95, 160, 24);
  [accessory addSubview:speedLabel];
  controller.speedSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(180, 93, 240, 26)];
  controller.speedSlider.minValue = 0.25;
  controller.speedSlider.maxValue = 2.0;
  controller.speedSlider.floatValue = simulationSpeed ? *simulationSpeed : 1.0f;
  controller.speedSlider.target = controller;
  controller.speedSlider.action = @selector(updateSimulationSetting:);
  [accessory addSubview:controller.speedSlider];
  controller.speedName = [NSTextField labelWithString:@"1.00×"];
  controller.speedName.frame = NSMakeRect(440, 95, 70, 22);
  controller.speedName.alignment = NSTextAlignmentRight;
  [accessory addSubview:controller.speedName];

  NSTextField *gravityLabel = [NSTextField labelWithString:@"Gravity strength"];
  gravityLabel.frame = NSMakeRect(0, 49, 160, 24);
  [accessory addSubview:gravityLabel];
  controller.gravitySlider = [[NSSlider alloc] initWithFrame:NSMakeRect(180, 47, 240, 26)];
  controller.gravitySlider.minValue = 0.25;
  controller.gravitySlider.maxValue = 2.0;
  controller.gravitySlider.floatValue = gravityScale ? *gravityScale : 1.0f;
  controller.gravitySlider.target = controller;
  controller.gravitySlider.action = @selector(updateSimulationSetting:);
  [accessory addSubview:controller.gravitySlider];
  controller.gravityName = [NSTextField labelWithString:@"1.00×"];
  controller.gravityName.frame = NSMakeRect(440, 49, 70, 22);
  controller.gravityName.alignment = NSTextAlignmentRight;
  [accessory addSubview:controller.gravityName];

  NSTextField *hint = [NSTextField labelWithString:@"100–100,000 particles; larger counts may run slower."];
  hint.frame = NSMakeRect(0, 5, width, 18);
  hint.font = [NSFont systemFontOfSize:11.0];
  hint.textColor = NSColor.secondaryLabelColor;
  [accessory addSubview:hint];

  [controller updateParticleSize:nil];
  [controller updateSimulationSetting:nil];

  if (supportsAudio) {
    NSTextField *audioLabel = [NSTextField labelWithString:@"Audio track"];
    audioLabel.frame = NSMakeRect(0, 233, 160, 24);
    [accessory addSubview:audioLabel];

    NSString *root = [[[[NSFileManager defaultManager] currentDirectoryPath] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
    NSArray<NSString *> *trackNames = @[@"Spill your time.mp3", @"limitless - Hiroi Sekai.mp3", @"143 ways to lose urself .mp3"];
    NSMutableArray<NSURL *> *tracks = [NSMutableArray array];
    for (NSString *name in trackNames) {
      NSURL *track = [NSURL fileURLWithPath:[root stringByAppendingPathComponent:[@"tracks" stringByAppendingPathComponent:name]]];
      if ([[NSFileManager defaultManager] fileExistsAtPath:track.path]) [tracks addObject:track];
    }
    controller.preloadedURLs = tracks;
    controller.audioURL = audioURL && *audioURL ? *audioURL : tracks.firstObject;
    controller.audioChoice = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(180, 230, 330, 30) pullsDown:NO];
    [accessory addSubview:controller.audioChoice];
    [controller rebuildAudioChoices];
  }

  while (YES) {
    NSAlert *alert = [NSAlert new];
    alert.alertStyle = NSAlertStyleInformational;
    alert.messageText = @"Simulation setup";
    alert.informativeText = supportsAudio
        ? @"Choose a starting shape, particle count, display size, simulation speed, gravity strength, and audio. The viewer starts paused."
        : @"Set particle count, display size, simulation speed, and gravity strength. The viewer starts paused.";
    alert.accessoryView = accessory;
    [alert addButtonWithTitle:@"Start"];
    [alert addButtonWithTitle:@"Cancel"];
    alert.window.initialFirstResponder = countField;
    [alert.window makeFirstResponder:countField];
    [countField selectText:nil];
    if ([alert runModal] != NSAlertFirstButtonReturn) return NO;

    NSString *value = [countField.stringValue stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    BOOL digitsOnly = value.length > 0 && [value rangeOfCharacterFromSet:nonDigits].location == NSNotFound;
    long long count = digitsOnly ? value.longLongValue : 0;
    if (count >= 100 && count <= 100000) {
      if (startingShape) *startingShape = (StartingShape)shapeChoice.indexOfSelectedItem;
      if (particleCount) *particleCount = (uint32_t)count;
      if (audioURL) *audioURL = controller.audioURL;
      if (particleSizeScale) *particleSizeScale = controller.sizeSlider.floatValue;
      if (simulationSpeed) *simulationSpeed = controller.speedSlider.floatValue;
      if (gravityScale) *gravityScale = controller.gravitySlider.floatValue;
      return YES;
    }

    NSAlert *validation = [NSAlert new];
    validation.alertStyle = NSAlertStyleWarning;
    validation.messageText = @"Enter a valid particle count";
    validation.informativeText = @"Use a whole number from 100 to 100,000.";
    [validation addButtonWithTitle:@"OK"];
    [validation runModal];
  }
}

static inline void bringViewerWindowToFront(NSWindow *window, NSView *view) {
  [window makeKeyAndOrderFront:nil];
  [NSApp activate];
  [window makeFirstResponder:view];
  dispatch_async(dispatch_get_main_queue(), ^{
    [NSApp activate];
    [[NSRunningApplication currentApplication] activateWithOptions:NSApplicationActivateAllWindows];
    [window makeKeyAndOrderFront:nil];
    [window orderFrontRegardless];
    [window makeFirstResponder:view];
  });
}
