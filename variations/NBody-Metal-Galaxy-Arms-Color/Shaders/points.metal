#include <metal_stdlib>
using namespace metal;

struct VSOut {
    float4 pos [[position]];
    float pointSize [[point_size]];
    float3 color [[user(locn0)]];
};
struct FSIn { float3 color [[user(locn0)]]; };

vertex VSOut vs_points(const device float2* pos [[buffer(0)]],
                       uint vid [[vertex_id]]) {
    VSOut o;
    float2 p = pos[vid];
    float radius = length(p);
    float t = clamp(radius / 0.9f, 0.0f, 1.0f);
    float3 inner = float3(0.12f, 0.95f, 0.82f);
    float3 middle = float3(0.42f, 0.38f, 1.0f);
    float3 outer = float3(1.0f, 0.46f, 0.72f);
    o.color = t < 0.55f
        ? mix(inner, middle, t / 0.55f)
        : mix(middle, outer, (t - 0.55f) / 0.45f);
    o.pos = float4(p, 0, 1);
    o.pointSize = 2.4f;
    return o;
}

fragment float4 fs_solid(FSIn in [[stage_in]]) {
    return float4(in.color, 1.0f);
}
