#include <metal_stdlib>
using namespace metal;

struct VSOut { float4 pos [[position]]; float pointSize [[point_size]]; };

vertex VSOut vs_points(const device float2* pos [[buffer(0)]],
                       uint vid [[vertex_id]]) {
    VSOut o;
    o.pos = float4(pos[vid], 0, 1);   // positions already in NDC-ish [-1,1]
    o.pointSize = 2.0;
    return o;
}

fragment float4 fs_solid() {
    return float4(1,1,1,1);
}