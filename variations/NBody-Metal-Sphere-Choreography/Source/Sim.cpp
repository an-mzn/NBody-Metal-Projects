#include <algorithm>
#include <cmath>
#include <random>
#include "Sim.hpp"

SimInit makeInit(uint32_t N, uint32_t seed) {
    SimInit s;
    s.posXYZW.resize(N * 4);
    s.velXYZW.resize(N * 4);
    s.mass.resize(N);

    std::mt19937 rng(seed);
    std::uniform_real_distribution<float> U(0.0f, 1.0f);
    constexpr float sphereRadius = 1.35f;
    constexpr float spin = 0.22f;
    constexpr float twoPi = 6.28318530718f;
    const uint32_t radialShells = 10;
    const uint32_t latitudeBands = 25;
    constexpr uint32_t pointsPerRing = 120;

    for (uint32_t i = 0; i < N; ++i) {
        float x, y, z;
        if (N == radialShells * latitudeBands * pointsPerRing) {
            // Equal-volume radial shells, equal-area latitude bands, and
            // evenly spaced longitudes give the starting cloud 120-fold
            // rotational symmetry around its spin axis.
            const uint32_t ring = i / pointsPerRing;
            const uint32_t longitude = i % pointsPerRing;
            const uint32_t shell = ring / latitudeBands;
            const uint32_t latitude = ring % latitudeBands;
            const float radius = sphereRadius * std::cbrt((shell + 0.5f) / radialShells);
            const float zDirection = 1.0f - 2.0f * (latitude + 0.5f) / latitudeBands;
            const float planar = std::sqrt(std::max(0.0f, 1.0f - zDirection * zDirection));
            const float ringOffset = (ring % 2 == 0) ? 0.0f : 0.5f;
            const float azimuth = twoPi * (longitude + ringOffset) / pointsPerRing;
            x = radius * planar * std::cos(azimuth);
            y = radius * planar * std::sin(azimuth);
            z = radius * zDirection;
        } else {
            // Keep the initializer useful for custom counts outside the
            // viewer's structured, rotationally symmetric defaults.
            const float zDirection = 2.0f * U(rng) - 1.0f;
            const float azimuth = twoPi * U(rng);
            const float planar = std::sqrt(std::max(0.0f, 1.0f - zDirection * zDirection));
            const float radius = sphereRadius * std::cbrt(U(rng));
            x = radius * planar * std::cos(azimuth);
            y = radius * planar * std::sin(azimuth);
            z = radius * zDirection;
        }

        s.posXYZW[4 * i + 0] = x;
        s.posXYZW[4 * i + 1] = y;
        s.posXYZW[4 * i + 2] = z;
        s.posXYZW[4 * i + 3] = 0.0f;
        // Solid-body rotation is axisymmetric and gives each ring the same
        // angular velocity without adding random directional noise.
        s.velXYZW[4 * i + 0] = -spin * y;
        s.velXYZW[4 * i + 1] =  spin * x;
        s.velXYZW[4 * i + 2] = 0.0f;
        s.velXYZW[4 * i + 3] = 0.0f;
        s.mass[i] = 1.0f;
    }

    return s;
}
