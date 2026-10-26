#pragma once
#include <algorithm>
#include <cmath>

// Exact critically damped response for a target held over this frame.
// Retaining velocity makes movement accelerate and settle continuously.
inline void smoothMusicMotion(float& value, float& velocity, float target,
                              double delta, double responseTime) {
    if (delta <= 0) return;
    const double omega = 2.0 / std::max(0.01, responseTime);
    const double offset = value - target;
    const double change = (velocity + omega * offset) * delta;
    const double decay = std::exp(-omega * delta);
    value = float(target + (offset + change) * decay);
    velocity = float((velocity - omega * change) * decay);
    if (value < 0 || value > 1) {
        value = std::clamp(value, 0.0f, 1.0f);
        velocity = 0;
    }
}
