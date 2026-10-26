#pragma once
#include <vector>
#include <cstdint>
#include <random>

struct SimInit {
    std::vector<float> posXYZW; // aligned x,y,z,0 vectors
    std::vector<float> velXYZW;
    std::vector<float> mass;
};

enum class StartingShape : uint32_t {
    DoubleTorus, TrefoilKnot, SpiralVortex, FoldedRibbon, TwoClusters
};
constexpr uint32_t startingShapeCount = 5;
inline const char* startingShapeName(StartingShape shape) {
    switch (shape) {
        case StartingShape::DoubleTorus: return "Double Torus";
        case StartingShape::TrefoilKnot: return "Trefoil Knot";
        case StartingShape::SpiralVortex: return "Spiral Vortex";
        case StartingShape::FoldedRibbon: return "Folded Ribbon";
        case StartingShape::TwoClusters: return "Two Clusters";
    }
    return "Double Torus";
}
SimInit makeInit(uint32_t N, uint32_t seed = 42,
                 StartingShape shape = StartingShape::DoubleTorus);