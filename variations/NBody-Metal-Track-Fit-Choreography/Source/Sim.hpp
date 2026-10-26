#pragma once
#include <vector>
#include <cstdint>
#include <random>

struct SimInit {
    std::vector<float> posXYZW; // aligned x,y,z,0 vectors
    std::vector<float> velXYZW;
    std::vector<float> mass;
};

SimInit makeInit(uint32_t N, uint32_t seed = 42);