#pragma once
#import <Foundation/Foundation.h>
#include <vector>

struct MusicFrame {
    float energy = 0, attack = 0, brightness = 0;
    float bass = 0, mid = 0, treble = 0;
    float beat = 0, phrase = 0;
    float vocals = 0, drums = 0, instrumentBass = 0;
    float guitar = 0, piano = 0, other = 0;
};
struct MusicAnalysis {
    std::vector<MusicFrame> frames;
    std::vector<float> rawEnergy; // Shared-scale stem comparison before normalization.
    double frameDuration = 0;
    float bpm = 0, beatConfidence = 0;
    float referenceEnergy = 0; // Unscaled 95th-percentile energy for stem gating.
    NSURL *sampleURL = nil;
    NSString *error = nil;
};
MusicAnalysis analyzeMusic(NSURL *url);
