#pragma once
#include "MusicAnalysis.hpp"
// Runs on the existing background analysis queue. Returns an actionable error
// rather than silently presenting frequency bands as separated instruments.
MusicAnalysis analyzeInstruments(NSURL *url);
