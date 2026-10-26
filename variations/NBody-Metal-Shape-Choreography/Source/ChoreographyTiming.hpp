#pragma once
#include "MusicAnalysis.hpp"
#include <algorithm>
#include <array>
#include <cmath>

// The full track is available before playback. Centered smoothing retains the
// event's timestamp, unlike a causal spring which delays every musical change.
inline void prepareChoreographyFrames(MusicAnalysis& analysis) {
    if (analysis.frames.empty() || !(analysis.frameDuration > 0)) return;
    const auto parts = {&MusicFrame::vocals, &MusicFrame::drums, &MusicFrame::instrumentBass,
                        &MusicFrame::guitar, &MusicFrame::piano, &MusicFrame::other};
    for (auto& frame : analysis.frames) {
        float strongest = 0;
        for (auto field : parts) strongest = std::max(strongest, frame.*field);
        for (auto field : parts) {
            const float relative = frame.*field / std::max(strongest, 1e-6f);
            frame.*field = std::clamp(std::sqrt(strongest) * relative
                * (0.12f + 1.35f * relative * relative), 0.0f, 1.0f);
        }
    }
    const auto source = analysis.frames;
    for (auto field : {&MusicFrame::energy, &MusicFrame::attack, &MusicFrame::brightness,
                      &MusicFrame::bass, &MusicFrame::mid, &MusicFrame::treble,
                      &MusicFrame::beat, &MusicFrame::phrase,
                      &MusicFrame::vocals, &MusicFrame::drums, &MusicFrame::instrumentBass,
                      &MusicFrame::guitar, &MusicFrame::piano, &MusicFrame::other}) {
        const bool transient = field == &MusicFrame::attack || field == &MusicFrame::beat
            || field == &MusicFrame::drums || field == &MusicFrame::piano;
        const double sigma = field == &MusicFrame::phrase ? 0.14 : transient ? 0.035 : 0.070;
        const int radius = (int)std::ceil(3 * sigma / analysis.frameDuration);
        std::vector<double> weights(2 * radius + 1);
        double weightSum = 0;
        for (int offset = -radius; offset <= radius; ++offset) {
            const double distance = offset * analysis.frameDuration / sigma;
            weights[offset + radius] = std::exp(-0.5 * distance * distance);
            weightSum += weights[offset + radius];
        }
        for (size_t i = 0; i < source.size(); ++i) {
            double value = 0;
            for (int offset = -radius; offset <= radius; ++offset) {
                const size_t index = (size_t)std::clamp((long long)i + offset,
                    0LL, (long long)source.size() - 1);
                value += (source[index].*field) * weights[offset + radius];
            }
            analysis.frames[i].*field = (float)(value / weightSum);
        }
    }
    // Layered passages must not add six full-volume deformations together.
    // Preserve relative prominence, but bound their combined movement to 120%
    // of the strongest part. A single clear part is unchanged.
    for (auto& frame : analysis.frames) {
        float strongest = 0, total = 0;
        for (auto field : parts) {
            strongest = std::max(strongest, frame.*field);
            total += frame.*field;
        }
        const float scale = total > 0 ? std::min(1.0f, 1.20f * strongest / total) : 1.0f;
        for (auto field : parts) frame.*field *= scale;
    }

}

using MusicExpressionFrame = std::array<float, 6>;

// Follow a passage's established lead continuously, including slow attacks
// and sustained notes. Separate envelopes crossfade particle groups on handoff.
inline std::vector<MusicExpressionFrame> prepareLeadExpression(const MusicAnalysis& analysis) {
    const float MusicFrame::*parts[] = {&MusicFrame::vocals, &MusicFrame::drums,
        &MusicFrame::instrumentBass, &MusicFrame::guitar, &MusicFrame::piano, &MusicFrame::other};
    const size_t count = analysis.frames.size();
    std::vector<MusicExpressionFrame> expression(count, MusicExpressionFrame{});
    if (!count || !(analysis.frameDuration > 0)) return expression;
    std::array<std::vector<double>, 6> prefix;
    std::array<float, 6> references;
    for (size_t part = 0; part < 6; ++part) {
        prefix[part].resize(count + 1, 0);
        std::vector<float> levels(count);
        for (size_t i = 0; i < count; ++i) {
            levels[i] = analysis.frames[i].*parts[part];
            prefix[part][i+1] = prefix[part][i] + levels[i];
        }
        const size_t quantile = size_t(0.90 * (count - 1));
        std::nth_element(levels.begin(), levels.begin() + quantile, levels.end());
        references[part] = std::max(0.025f, levels[quantile]);
    }
    const size_t context = std::max(size_t(1), size_t(0.65 / analysis.frameDuration));
    size_t leader = 0, lastSwitch = 0;
    for (size_t i = 0; i < count; ++i) {
        const size_t left = i > context ? i-context : 0;
        const size_t right = std::min(count, i+context+1);
        std::array<double, 6> scores = {};
        size_t candidate = 0;
        for (size_t part = 0; part < 6; ++part) {
            scores[part] = (prefix[part][right] - prefix[part][left]) / (right-left);
            if (scores[part] > scores[candidate]) candidate = part;
        }
        if (i == 0 || (candidate != leader && scores[candidate] > scores[leader] * 1.35
                         && i-lastSwitch >= context)) {
            leader = candidate;
            lastSwitch = i;
        }
        const float floor = std::max(0.015f, references[leader] * 0.12f);
        const float level = analysis.frames[i].*parts[leader];
        const float strength = std::clamp((level-floor) / (references[leader]-floor), 0.0f, 1.0f);
        expression[i][leader] = strength*strength*(3.0f-2.0f*strength);
    }
    // Centered smoothing keeps slow phrase contours aligned and gives leader
    // handoffs a crossfade rather than instantly displacing a different group.
    const auto source = expression;
    constexpr double sigma = 0.10;
    const int radius = (int)std::ceil(3*sigma/analysis.frameDuration);
    std::vector<double> weights(2*radius+1);
    double totalWeight = 0;
    for (int offset = -radius; offset <= radius; ++offset) {
        const double distance = offset*analysis.frameDuration/sigma;
        weights[offset+radius] = std::exp(-0.5*distance*distance);
        totalWeight += weights[offset+radius];
    }
    for (size_t i = 0; i < count; ++i) {
        std::array<double, 6> sum = {};
        for (int offset = -radius; offset <= radius; ++offset) {
            const size_t index = (size_t)std::clamp((long long)i+offset, 0LL, (long long)count-1);
            for (size_t part = 0; part < 6; ++part)
                sum[part] += source[index][part]*weights[offset+radius];
        }
        for (size_t part = 0; part < 6; ++part) expression[i][part] = (float)(sum[part]/totalWeight);
    }
    return expression;
}
