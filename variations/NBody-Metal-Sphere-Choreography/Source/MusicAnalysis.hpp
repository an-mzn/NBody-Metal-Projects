#pragma once
#import <Foundation/Foundation.h>
#include <vector>

struct MusicFrame {
    float energy = 0, attack = 0, brightness = 0;
    float bass = 0, mid = 0, treble = 0;
    float beat = 0, phrase = 0;
};
struct MusicAnalysis {
    std::vector<MusicFrame> frames;
    double frameDuration = 0;
    float bpm = 0, beatConfidence = 0;
    NSString *error = nil;
};
MusicAnalysis analyzeMusic(NSURL *url);
