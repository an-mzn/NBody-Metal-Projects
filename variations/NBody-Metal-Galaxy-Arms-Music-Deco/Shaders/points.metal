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
    o.pos = float4(pos[vid], 0, 1);
    o.pointSize = 2.4f;
    o.color = float3(0.82f, 0.62f, 0.30f);
    return o;
}

fragment float4 fs_solid(FSIn in [[stage_in]]) {
    return float4(in.color, 1.0f);
}
