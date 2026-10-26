#include <algorithm>
#include <cmath>
#include <random>
#include "Sim.hpp"

namespace {
constexpr float pi = 3.14159265359f;
struct Vec3 { float x, y, z; };
Vec3 operator+(Vec3 a, Vec3 b) { return {a.x+b.x, a.y+b.y, a.z+b.z}; }
Vec3 operator-(Vec3 a, Vec3 b) { return {a.x-b.x, a.y-b.y, a.z-b.z}; }
Vec3 operator*(Vec3 a, float b) { return {a.x*b, a.y*b, a.z*b}; }
float length(Vec3 a) { return std::sqrt(a.x*a.x+a.y*a.y+a.z*a.z); }
Vec3 normalized(Vec3 a) { return a*(1.0f/std::max(length(a), 1e-6f)); }
Vec3 cross(Vec3 a, Vec3 b) { return {a.y*b.z-a.z*b.y, a.z*b.x-a.x*b.z, a.x*b.y-a.y*b.x}; }

// Parametric paths give each shape a supporting initial direction of flow.
Vec3 path(StartingShape shape, float t, uint32_t component, float width) {
    switch (shape) {
        case StartingShape::TrefoilKnot:
            return {0.53f*(std::sin(t)+2*std::sin(2*t)),
                    0.53f*(std::cos(t)-2*std::cos(2*t)), -0.53f*std::sin(3*t)};
        case StartingShape::SpiralVortex: {
            float radius = 0.22f + 1.55f*t;
            float angle = 2*pi*float(component)/4 + 2.4f*pi*t;
            return {radius*std::cos(angle), radius*std::sin(angle), 0.95f*(t-0.5f)};
        }
        case StartingShape::FoldedRibbon: {
            // A broad half-twisted ribbon, with an additional vertical fold.
            float radius = 1.05f + width*std::cos(t*0.5f);
            return {radius*std::cos(t), radius*std::sin(t),
                    width*std::sin(t*0.5f) + 0.30f*std::sin(2*t)};
        }
        default:
            // Linked circles in perpendicular planes (a thick Hopf link).
            if (component == 0)
                return {-0.525f+1.05f*std::cos(t), 1.05f*std::sin(t), 0};
            return {0.525f+1.05f*std::cos(t), 0, 1.05f*std::sin(t)};
    }
}
}

SimInit makeInit(uint32_t N, uint32_t seed, StartingShape shape) {
    SimInit s;
    s.posXYZW.resize(N*4);
    s.velXYZW.resize(N*4);
    s.mass.resize(N, 1.0f);
    std::mt19937 rng(seed);
    std::uniform_real_distribution<float> uniform(0.0f, 1.0f);
    for (uint32_t i = 0; i < N; ++i) {
        Vec3 position, velocity;
        if (shape == StartingShape::TwoClusters) {
            const float sign = i%2 == 0 ? -1.0f : 1.0f;
            const float azimuth = 2*pi*uniform(rng), height = 2*uniform(rng)-1;
            const float planar = std::sqrt(std::max(0.0f, 1-height*height));
            const float radius = 0.48f*std::cbrt(uniform(rng));
            const Vec3 local = {radius*planar*std::cos(azimuth),
                                radius*planar*std::sin(azimuth), radius*height};
            constexpr float separation = 1.10f;
            position = local + Vec3{sign*separation, 0, 0};
            const float orbitSpeed = std::sqrt(1e-4f*float(N)*(separation*separation
                /std::pow(4*separation*separation+0.1f, 1.5f)
                +0.12f*separation*separation/std::pow(separation*separation+0.65f*0.65f, 1.5f)
                +0.18f*separation*separation/std::pow(separation*separation+4, 1.5f)));
            const float spin = 0.75f*std::sqrt(1e-4f*0.5f*float(N)/std::pow(0.48f*0.48f+0.1f, 1.5f));
            velocity = Vec3{-local.y*spin*sign, local.x*spin*sign, 0}
                     + Vec3{0, sign*orbitSpeed, 0};
        } else {
            const uint32_t component = shape == StartingShape::SpiralVortex ? i%4 : i%2;
            const float t = uniform(rng)*(shape == StartingShape::SpiralVortex ? 1.0f : 2*pi);
            const float width = (uniform(rng)-0.5f)*0.85f;
            const Vec3 centre = path(shape, t, component, width);
            const Vec3 tangent = normalized(path(shape, t+0.001f, component, width)
                                           - path(shape, t-0.001f, component, width));
            const Vec3 reference = std::abs(tangent.z)<0.9f ? Vec3{0,0,1} : Vec3{0,1,0};
            const Vec3 normal = normalized(cross(tangent, reference));
            const Vec3 binormal = cross(tangent, normal);
            const float angle = 2*pi*uniform(rng);
            const float thickness = shape == StartingShape::FoldedRibbon ? 0.025f
                                  : shape == StartingShape::SpiralVortex ? 0.065f : 0.13f;
            const float offset = thickness*std::sqrt(uniform(rng));
            position = centre + normal*(offset*std::cos(angle)) + binormal*(offset*std::sin(angle));
            const float speed = 0.75f*std::sqrt(1e-4f*float(N)/std::max(length(centre), 0.4f));
            const float direction = shape == StartingShape::DoubleTorus && component == 1 ? -1.0f : 1.0f;
            velocity = tangent*(speed*direction);
        }
        s.posXYZW[4*i] = position.x;
        s.posXYZW[4*i+1] = position.y;
        s.posXYZW[4*i+2] = position.z;
        s.velXYZW[4*i] = velocity.x;
        s.velXYZW[4*i+1] = velocity.y;
        s.velXYZW[4*i+2] = velocity.z;
    }
    return s;
}
