#include <metal_stdlib>
using namespace metal;

struct VSOut {
    float4 pos [[position]];
    float pointSize [[point_size]];
    float3 color [[user(locn0)]];
};
struct FSIn { float3 color [[user(locn0)]]; };

vertex VSOut vs_points(const device float2* pos [[buffer(0)]],
                       const device float2* vel [[buffer(1)]],
                       uint vid [[vertex_id]]) {
    VSOut o;
    float2 p = pos[vid];
    float speed = length(vel[vid]);
    float t = clamp(speed / 1.5f, 0.0f, 1.0f);
    float3 cool = float3(0.12f, 0.55f, 1.0f);
    float3 warm = float3(1.0f, 0.82f, 0.22f);
    float3 hot = float3(1.0f, 0.24f, 0.12f);
    o.color = t < 0.6f
        ? mix(cool, warm, t / 0.6f)
        : mix(warm, hot, (t - 0.6f) / 0.4f);
    o.pos = float4(p, 0, 1);
    o.pointSize = 2.2f;
    return o;
}

fragment float4 fs_solid(FSIn in [[stage_in]]) {
    return float4(in.color, 1.0f);
}
