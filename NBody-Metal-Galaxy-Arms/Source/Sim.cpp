#include <cmath>
#include <random>
#include "Sim.hpp"

SimInit makeInit(uint32_t N, uint32_t seed) {
    SimInit s;
    s.posXY.resize(N*2);
    s.velXY.resize(N*2);
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
        s.posXY[2*i+0] = x; s.posXY[2*i+1] = y;
        // mass + tangential velocity
        s.mass[i] = 1.0f;
        float rr = std::sqrt(x*x + y*y) + 1e-3f;
        float tx = -y / rr, ty = x / rr;
        float k = 0.35f;
        s.velXY[2*i+0] = k * tx / std::sqrt(rr);
        s.velXY[2*i+1] = k * ty / std::sqrt(rr);
    }

    return s;
}
