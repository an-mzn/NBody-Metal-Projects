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

kernel void nbody_forces_tiled(const device float2* pos   [[buffer(0)]],
                               const device float*  mass  [[buffer(1)]],
                               device float2*       acc   [[buffer(2)]],
                               constant uint&       N     [[buffer(3)]],
                               constant float& gravityScale [[buffer(4)]],
                               uint gid [[thread_position_in_grid]],
                               uint tid [[thread_index_in_threadgroup]],
                               uint tgs [[threads_per_threadgroup]]) {
    const float2 pi = gid < N ? pos[gid] : float2(0.0);
    float2 a = float2(0.0);
    const float soft = 1e-2f;
    threadgroup float2 tPos[1024];
    threadgroup float tMass[1024];

    for (uint base = 0; base < N; base += tgs) {
        uint j = base + tid;
        if (j < N) {
            tPos[tid] = pos[j];
            tMass[tid] = mass[j];
        } else {
            tPos[tid] = float2(0.0);
            tMass[tid] = 0.0f;
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);

        uint bound = min(tgs, N - base);
        for (uint k = 0; k < bound; ++k) {
            float2 d = tPos[k] - pi;
            float invr = rsqrt(dot(d, d) + soft);
            a += tMass[k] * d * (invr * invr * invr);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (gid < N) acc[gid] = a * gravityScale;
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
