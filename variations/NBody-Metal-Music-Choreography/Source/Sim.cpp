#include <cmath>
#include <algorithm>
#include <random>
#include "Sim.hpp"

SimInit makeInit(uint32_t N, uint32_t seed) {
    SimInit s;
    s.posXYZW.resize(N*4);
    s.velXYZW.resize(N*4);
    s.mass.resize(N);
    std::mt19937 rng(seed);
    std::uniform_real_distribution<float> U(0.f,1.f);
    std::normal_distribution<float> N01(0.f,1.f);

    for (uint32_t i=0;i<N;++i){
        // Two spiral arms
        float arm = (i % 2 == 0) ? 0.f : float(M_PI);
        float t = 4.0f * (float(i) / float(N));
        float r = 0.05f + 0.45f * t + 0.03f * N01(rng);
        float a = arm + 3.0f * t + 0.20f * N01(rng);
        float x = r * std::cos(a), y = r * std::sin(a);
        s.posXYZW[4*i+0] = x; s.posXYZW[4*i+1] = y;
        // Give the spiral substantial depth so it reads as a volume from every angle.
        float fraction = std::min(std::sqrt(x*x+y*y) / 1.85f, 1.0f);
        s.posXYZW[4*i+2] = 0.62f * fraction * std::sin(2.0f*a)
            + 0.34f * std::sqrt(std::max(0.0f, 1.0f-fraction*fraction)) * N01(rng);
        // mass + tangential velocity
        s.mass[i] = 1.0f;
        float rr = std::sqrt(x*x + y*y) + 1e-3f;
        float tx = -y / rr, ty = x / rr;
        float k = 0.35f;
        s.velXYZW[4*i+0] = k * tx / std::sqrt(rr);
        s.velXYZW[4*i+1] = k * ty / std::sqrt(rr);
        s.velXYZW[4*i+2] = (1.24f / 1.85f) * std::cos(2.0f*a) * k / std::sqrt(rr);
    }

    return s;
}
