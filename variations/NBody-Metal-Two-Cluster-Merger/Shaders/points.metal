#include <metal_stdlib>
using namespace metal;

struct VSOut { float4 pos [[position]]; float pointSize [[point_size]]; };

vertex VSOut vs_points(const device float2* pos [[buffer(0)]],
                       constant float4& camera [[buffer(10)]],
                       constant float& sizeScale [[buffer(11)]], uint vid [[vertex_id]]) {
    VSOut o;
    float2 p = pos[vid];
    float cs = cos(camera.w), sn = sin(camera.w);
    p = float2(cs * p.x - sn * p.y, sn * p.x + cs * p.y) * camera.x + camera.yz;
    o.pos = float4(p, 0, 1);   // positions already in NDC-ish [-1,1]
    o.pointSize = 2.0 * sizeScale;
    return o;
}

fragment float4 fs_solid() {
    return float4(1,1,1,1);
}