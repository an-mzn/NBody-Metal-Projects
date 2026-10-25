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
        bool left = (i < N/2);
        float cx = left ? -0.5f : 0.5f;
        float cy = 0.0f;
        float a = 2.f*float(M_PI)*U(rng);
        float r = 0.15f * std::sqrt(U(rng));
        float x = cx + r*std::cos(a);
        float y = cy + r*std::sin(a);
        s.posXY[2*i+0] = x; s.posXY[2*i+1] = y;
        // counter-rotating tangential velocities
        s.mass[i] = 1.0f;
        float rr = std::sqrt((x-cx)*(x-cx) + (y-cy)*(y-cy)) + 1e-3f;
        float tx = -(y-cy) / rr, ty = (x-cx) / rr;
        float spin = left ? 1.0f : -1.0f;
        float k = 0.30f;
        s.velXY[2*i+0] = spin * k * tx;
        s.velXY[2*i+1] = spin * k * ty;
    }

    return s;
}
