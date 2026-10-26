#include <metal_stdlib>
using namespace metal;

struct VSOut {
    float4 pos [[position]];
    float pointSize [[point_size]];
    float3 color [[user(locn0)]];
};
struct FSIn { float3 color [[user(locn0)]]; };

vertex VSOut vs_points(const device float2* pos [[buffer(0)]],
                       constant uint& particleCount [[buffer(2)]],
                       constant float4& camera [[buffer(10)]],
                       constant float& sizeScale [[buffer(11)]],
                       uint vid [[vertex_id]]) {
    VSOut o;
    float2 p = pos[vid];
    float3 leftCluster = float3(0.18f, 0.82f, 1.0f);
    float3 rightCluster = float3(1.0f, 0.43f, 0.20f);
    o.color = vid < particleCount / 2 ? leftCluster : rightCluster;
    float cs = cos(camera.w), sn = sin(camera.w);
    p = float2(cs * p.x - sn * p.y, sn * p.x + cs * p.y) * camera.x + camera.yz;
    o.pos = float4(p, 0, 1);
    o.pointSize = 2.6f * sizeScale;
    return o;
}

fragment float4 fs_solid(FSIn in [[stage_in]]) {
    return float4(in.color, 1.0f);
}
