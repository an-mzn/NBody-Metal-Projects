#pragma once
#include <vector>
#include <cstdint>
#include <random>

struct SimInit {
    std::vector<float> posXY; // interleaved x,y pairs
    std::vector<float> velXY;
    std::vector<float> mass;
};

SimInit makeInit(uint32_t N, uint32_t seed = 42);