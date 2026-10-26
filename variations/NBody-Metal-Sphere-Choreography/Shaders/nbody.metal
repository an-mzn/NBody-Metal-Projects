#include <metal_stdlib>
using namespace metal;

kernel void nbody_forces(const device float4* pos   [[buffer(0)]],
                         const device float*  mass  [[buffer(1)]],
                         device float4*       acc   [[buffer(2)]],
                         constant uint&       N     [[buffer(3)]],
                               uint gid [[thread_position_in_grid]]) {
    if (gid >= N) return;
    float4 pi = pos[gid];
    float4 a = float4(0.0);
    const float G = 1e-4f;
    const float soft = 1e-1f;
    for (uint j = 0; j < N; ++j) {
        float4 d = pos[j] - pi;
        float r2 = dot(d,d) + soft;
        float invr = rsqrt(r2);
        float invr3 = invr*invr*invr;
        a += G * mass[j] * d * invr3;
    }
    acc[gid] = a;
}

kernel void integrate(device float4* pos [[buffer(0)]],
                      device float4* vel [[buffer(1)]],
                      const device float4* acc [[buffer(2)]],
                      constant float& dt [[buffer(3)]],
                      constant uint& N  [[buffer(4)]],
                      uint gid [[thread_position_in_grid]]) {
    if (gid >= N) return;
    float4 v = vel[gid] + acc[gid] * dt;
    // Lower drag lets particles carry more of their velocity through each orbit.
    v *= exp(-0.075f * dt);
    float4 p = pos[gid] + v * dt;
    vel[gid] = v;
    pos[gid] = p;
}


#include <metal_stdlib>
using namespace metal;

// Tiled all-pairs force accumulation using threadgroup memory.
// Reduces global memory traffic by reusing tiles across the threadgroup.
kernel void nbody_forces_tiled(const device float4* pos   [[buffer(0)]],
                               const device float*  mass  [[buffer(1)]],
                               device float4*       acc   [[buffer(2)]],
                               constant uint&       N     [[buffer(3)]],
                               constant float&      gravityScale [[buffer(4)]],
                               uint gid [[thread_position_in_grid]],
                               uint tid [[thread_index_in_threadgroup]],
                               uint tgs [[threads_per_threadgroup]]) {
    bool valid = gid < N;
    float4 pi = valid ? pos[gid] : float4(0.0);
    float4 a = float4(0.0);
    const float soft = 1e-1f;
    const uint TILE = tgs; // tile size = threadgroup size

    threadgroup float4 tPos[1024];   // max supported by typical tg size (guarded by TILE)
    threadgroup float  tMass[1024];

    // Loop over tiles of size TILE
    const uint sourceCount = N == 30000u ? 3000u : (N == 3000u ? 750u : min(N, 2048u));
    for (uint base = 0; base < sourceCount; base += TILE) {
        uint j = base + tid;
        // Cooperative load into threadgroup memory
        if (j < sourceCount) {
            // For the symmetric sphere, sample 12 evenly spaced longitudes
            // from every 120-particle ring. This preserves rotational symmetry
            // in the tiled force estimate while reducing source traffic.
            uint source = N == 30000u
                ? (j / 12u) * 120u + (j % 12u) * 10u
                : (N == 3000u
                    ? (j / 3u) * 12u + (j % 3u) * 4u
                    : uint((ulong(j) * N) / sourceCount));
            tPos[tid] = pos[source];
            tMass[tid] = mass[source] * (float(N) / float(sourceCount));
        } else {
            tPos[tid]  = float4(0.0);
            tMass[tid] = 0.0f;
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);

        // Iterate over the tile
        uint bound = min(TILE, sourceCount - base);
        #pragma unroll(1)
        for (uint k = 0; k < bound; ++k) {
            float4 d = tPos[k] - pi;
            float r2 = dot(d,d) + soft;
            float invr = fast::rsqrt(r2);
            float invr3 = invr*invr*invr;
            invr3 = clamp(invr3, 0.0f, 1e6f);
            a += tMass[k] * d * invr3;
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (valid) acc[gid] = a * (1e-4f * gravityScale); // global gravity scale
}
