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
    const float G = 1e-4f;
    const float soft = 1e-1f;
    for (uint j = 0; j < N; ++j) {
        float2 d = pos[j] - pi;
        float r2 = dot(d,d) + soft;
        float invr = rsqrt(r2);
        float invr3 = invr*invr*invr;
        a += G * mass[j] * d * invr3;
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
    v *= 0.999f;
    float2 p = pos[gid] + v * dt;
    vel[gid] = v;
    pos[gid] = p;
}


#include <metal_stdlib>
using namespace metal;

// Tiled all-pairs force accumulation using threadgroup memory.
// Reduces global memory traffic by reusing tiles across the threadgroup.
kernel void nbody_forces_tiled(const device float2* pos   [[buffer(0)]],
                               const device float*  mass  [[buffer(1)]],
                               device float2*       acc   [[buffer(2)]],
                               constant uint&       N     [[buffer(3)]],
                               uint gid [[thread_position_in_grid]],
                               uint tid [[thread_index_in_threadgroup]],
                               uint tgs [[threads_per_threadgroup]]) {
    if (gid >= N) return;
    float2 pi = pos[gid];
    float2 a = float2(0.0);
    const float soft = 1e-1f;
    const uint TILE = tgs; // tile size = threadgroup size

    threadgroup float2 tPos[1024];   // max supported by typical tg size (guarded by TILE)
    threadgroup float  tMass[1024];

    // Loop over tiles of size TILE
    for (uint base = 0; base < N; base += TILE) {
        uint j = base + tid;
        // Cooperative load into threadgroup memory
        if (j < N) {
            tPos[tid]  = pos[j];
            tMass[tid] = mass[j];
        } else {
            tPos[tid]  = float2(0.0);
            tMass[tid] = 0.0f;
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);

        // Iterate over the tile
        uint bound = min(TILE, N - base);
        #pragma unroll(1)
        for (uint k = 0; k < bound; ++k) {
            float2 d = tPos[k] - pi;
            float r2 = dot(d,d) + soft;
            float invr = fast::rsqrt(r2);
            float invr3 = invr*invr*invr;
            invr3 = clamp(invr3, 0.0f, 1e6f);
            a += tMass[k] * d * invr3;
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    acc[gid] = a * 1e-4f; // global gravity scale
}
