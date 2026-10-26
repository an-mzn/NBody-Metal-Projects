#include <algorithm>
#include <cmath>
#include <random>
#include "Sim.hpp"

SimInit makeInit(uint32_t N, uint32_t seed) {
    SimInit s;
    s.posXYZW.resize(N * 4);
    s.velXYZW.resize(N * 4);
    s.mass.resize(N, 1.0f);
    std::mt19937 rng(seed);
    std::uniform_real_distribution<float> uniform(0.0f, 1.0f);
    constexpr float radius = 1.35f;
    constexpr float twoPi = 6.28318530718f;
    for (uint32_t i = 0; i < N; ++i) {
        // Four tetrahedrally spaced spin axes keep the combined cloud 3D.
        // Each thick orbital band shares a direction of circulation.
        constexpr float invSqrt3 = 0.57735026919f;
        constexpr float axes[4][3] = {
            {invSqrt3, invSqrt3, invSqrt3},
            {invSqrt3, -invSqrt3, -invSqrt3},
            {-invSqrt3, invSqrt3, -invSqrt3},
            {-invSqrt3, -invSqrt3, invSqrt3}
        };
        const auto& axis = axes[i % 4];
        const float invPlanar = 1.0f / std::sqrt(axis[0]*axis[0] + axis[1]*axis[1]);
        const float tx = -axis[1]*invPlanar, ty = axis[0]*invPlanar;
        const float bx = -axis[2]*ty, by = axis[2]*tx;
        const float bz = axis[0]*ty - axis[1]*tx;
        const float azimuth = twoPi * uniform(rng);
        const float c = std::cos(azimuth), sn = std::sin(azimuth);
        const float ux = c*tx + sn*bx, uy = c*ty + sn*by, uz = sn*bz;
        // A modest spread of inclinations gives each band real thickness.
        const float inclination = (uniform(rng) - 0.5f) * 0.5f;
        const float ci = std::cos(inclination), si = std::sin(inclination);
        const float nx = ci*ux + si*axis[0];
        const float ny = ci*uy + si*axis[1];
        const float nz = ci*uz + si*axis[2];
        const float r = radius * std::cbrt(uniform(rng));
        // The common tangent makes neighbouring particles circulate together;
        // gravity, rather than a prescribed animation, bends subsequent paths.
        const float vx = -sn*tx + c*bx;
        const float vy = -sn*ty + c*by;
        const float vz = c*bz;
        // Circular-speed estimate for a uniform sphere, including softening.
        // Matches the viewer's baseline gravity; this is a visual initial
        // condition, not an exact equilibrium under changing music gravity.
        // A gentle core bias strengthens central circulation, tapering to
        // the existing circular-speed estimate at the edge of the cloud.
        const float coreOrbit = 1.0f + 0.10f * (1.0f - (r*r)/(radius*radius));
        const float speed = std::sqrt(1e-4f * 1.15f * float(N)
            / std::pow(radius*radius + 0.1f, 1.5f)) * r * coreOrbit;
        s.posXYZW[4*i] = r*nx;
        s.posXYZW[4*i+1] = r*ny;
        s.posXYZW[4*i+2] = r*nz;
        s.velXYZW[4*i] = speed*vx;
        s.velXYZW[4*i+1] = speed*vy;
        s.velXYZW[4*i+2] = speed*vz;
    }
    return s;
}
