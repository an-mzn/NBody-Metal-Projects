#include <cmath>
#include "Sim.hpp"

SimInit makeInit(uint32_t N, uint32_t seed) {
    SimInit s;
    s.posXY.resize(N*2);
    s.velXY.resize(N*2);
    s.mass.resize(N);
    std::mt19937 rng(seed);
    std::uniform_real_distribution<float> uni(-1.0f, 1.0f);
    for (uint32_t i=0;i<N;++i){
        // Random ring-ish distribution
        float x = uni(rng);
        float y = uni(rng);
        s.posXY[2*i+0] = x;
        s.posXY[2*i+1] = y;
        float r = std::sqrt(x*x + y*y) + 1e-3f;
        float k = 0.35f;
        float tx = -y / r, ty = x / r;
        s.velXY[2*i+0] = k * tx / std::sqrt(r);
        s.velXY[2*i+1] = k * ty / std::sqrt(r);
        s.mass[i] = 1.0f;
    }
    return s;
}