#include <metal_stdlib>
using namespace metal;
struct VSOut { float4 pos [[position]]; float pointSize [[point_size]]; float3 color; };
// Approximate blackbody RGB for color temperatures from 1,000 K to 40,000 K.
float3 kelvinRGB(float kelvin) {
    float t = clamp(kelvin, 1000.0f, 40000.0f) / 100.0f;
    float3 rgb;
    if (t <= 66.0f) {
        rgb.r = 1.0f;
        rgb.g = clamp((99.4708025861f * log(t) - 161.1195681661f) / 255.0f, 0.0f, 1.0f);
        rgb.b = t <= 19.0f ? 0.0f : clamp((138.5177312231f * log(t - 10.0f) - 305.0447927307f) / 255.0f, 0.0f, 1.0f);
    } else {
        rgb.r = clamp((329.698727446f * pow(t - 60.0f, -0.1332047592f)) / 255.0f, 0.0f, 1.0f);
        rgb.g = clamp((288.1221695283f * pow(t - 60.0f, -0.0755148492f)) / 255.0f, 0.0f, 1.0f);
        rgb.b = 1.0f;
    }
    // Keep the coolest core visibly red; the standard approximation renders
    // even 1,000 K as orange on screen.
    float redCore = 1.0f - smoothstep(1000.0f, 3200.0f, kelvin);
    rgb.g *= 1.0f - redCore;
    rgb.b *= 1.0f - redCore;
    return rgb;
}
vertex VSOut vs_points(const device float4* positions [[buffer(0)]],
                       constant float4* parameters [[buffer(1)]],
                       constant float& sizeScale [[buffer(11)]], uint id [[vertex_id]]) {
    float aspect = max(parameters[0].x, 0.1f);
    // Draw the simulated position directly. Only the camera transforms it.
    float3 p = positions[id].xyz;
    // Keep an extended, stable colour range for gravitationally scattered particles.
    // A soft exponential scale preserves variation beyond that normal extent,
    // rather than clipping all distant particles to the same blue at 2.7.
    const float colorRadius = 2.0f + 3.6f;
    float relativeRadius = length(p) / colorRadius;
    float radialFraction = 1.0f - exp(-0.33136f * relativeRadius * relativeRadius);
    float temperature = mix(1000.0f, 40000.0f, radialFraction);
    // User-controlled orbit around the particle volume.
    float yaw = parameters[0].y;
    float tilt = parameters[0].z;
    p = float3(cos(yaw)*p.x + sin(yaw)*p.z, p.y, -sin(yaw)*p.x + cos(yaw)*p.z);
    p = float3(p.x, cos(tilt)*p.y - sin(tilt)*p.z, sin(tilt)*p.y + cos(tilt)*p.z);
    // Pan the camera target in the rotated view plane.
    p.xy -= parameters[1].xy;
    float distance = parameters[0].w - p.z;
    float perspective = 4.5f / max(0.025f, distance);
    VSOut out;
    const float nearPlane = 0.025f, farPlane = 30.0f;
    float depth = farPlane * (distance - nearPlane) / (farPlane - nearPlane);
    out.pos = float4(p.x * 2.07f / aspect, p.y * 2.07f, depth, distance);
    out.pointSize = clamp(2.0f * perspective, 1.3f, 2.7f) * sizeScale;
    out.color = kelvinRGB(temperature) * clamp(0.82f + p.z * 0.16f, 0.58f, 1.0f);
    return out;
}
fragment float4 fs_solid(VSOut in [[stage_in]], float2 uv [[point_coord]]) {
    float coverage = 1.0f - smoothstep(0.28f, 0.5f, length(uv - 0.5f));
    if (coverage < 0.01f) discard_fragment();
    return float4(in.color, coverage);
}
