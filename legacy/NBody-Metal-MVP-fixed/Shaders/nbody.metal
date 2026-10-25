#include <metal_stdlib>
using namespace metal;

kernel void nbody_forces(const device float2* pos   [[buffer(0)]],
                         const device float*  mass  [[buffer(1)]],
                         device float2*       acc   [[buffer(2)]],
                         constant uint&       N     [[buffer(3)]],
                         uint gid [[thread_position_in_grid]]) {
    if (gid >= N) return;
    float2 pi = pos[gid];
    float2 a = float2(0.0);
    const float soft = 1e-2f;
    for (uint j = 0; j < N; ++j) {
        float2 d = pos[j] - pi;
        float r2 = dot(d,d) + soft;
        float invr = rsqrt(r2);
        float invr3 = invr*invr*invr;
        a += mass[j] * d * invr3;
    }
    acc[gid] = a;
}

kernel void integrate(device float2* pos [[buffer(0)]],
                      device float2* vel [[buffer(1)]],
                      const device float2* acc [[buffer(2)]],
                      constant float& dt [[buffer(3)]],
                      constant uint& N  [[buffer(4)]],
                      uint gid [[thread_position_in_grid]]) {
    if (gid >= N) return;
    float2 v = vel[gid] + acc[gid] * dt;
    float2 p = pos[gid] + v * dt;
    vel[gid] = v;
    pos[gid] = p;
}