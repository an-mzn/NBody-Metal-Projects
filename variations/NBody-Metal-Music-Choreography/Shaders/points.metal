#include <metal_stdlib>
using namespace metal;
struct VSOut { float4 pos [[position]]; float pointSize [[point_size]]; float3 color; };
float particleHash(uint id) { return fract(sin(float(id) * 12.9898f + 4.1f) * 43758.5453f); }
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
                       constant float4* parameters [[buffer(1)]], uint id [[vertex_id]]) {
    float4 music = parameters[0];
    float energy = music.y, attack = music.z, brightness = music.w;
    float4 bands = parameters[2]; // bass, midrange, treble, beat-aligned attack
    float phrase = parameters[3].x;
    float aspect = max(parameters[1].x, 0.1f);
    float3 physicalPosition = positions[id].xyz;
    float2 xy = physicalPosition.xy;
    float radius = length(xy);
    float layer = physicalPosition.z;
    // Sustained phrases twist depth layers in opposite directions.
    float twist = (bands.y * 0.20f + attack * 0.10f + phrase * 0.08f)
                  * sin(radius * 1.6f + layer * 0.8f);
    float cs = cos(twist), sn = sin(twist);
    xy = float2(cs*xy.x - sn*xy.y, sn*xy.x + cs*xy.y);
    // Attacks ripple and shear locally; displacement stays bounded.
    float2 tangent = float2(-xy.y, xy.x) / max(radius, 0.05f);
    // Fade tangential ripples to zero at the centre so attacks cannot excavate a ring.
    float rippleFade = smoothstep(0.0f, 0.35f, radius);
    xy += tangent * (attack * 0.065f + bands.w * 0.035f) * rippleFade
          * cos(radius * 1.8f + layer * 0.4f);
    float z = physicalPosition.z + (bands.x * 0.10f + energy * 0.04f + attack * 0.055f + bands.w * 0.035f)
              * sin(radius * 2.1f + layer * 0.6f);
    z += (brightness * 0.015f + bands.z * 0.025f + phrase * 0.06f)
         * sin(radius * 1.5f + layer * 0.35f);
    float3 p = float3(xy, z);
    // Map distance from the 3D centre to a blackbody color temperature:
    // redder in the core, increasingly blue toward the outer edge.
    float radialFraction = smoothstep(0.0f, 2.7f, length(p));
    float temperature = mix(1000.0f, 12000.0f, radialFraction);
    // User-controlled orbit around the layered particle field.
    float yaw = parameters[1].y;
    float tilt = parameters[1].z;
    p = float3(cos(yaw)*p.x + sin(yaw)*p.z, p.y, -sin(yaw)*p.x + cos(yaw)*p.z);
    p = float3(p.x, cos(tilt)*p.y - sin(tilt)*p.z, sin(tilt)*p.y + cos(tilt)*p.z);
    // Pan the camera target in the rotated view plane.
    p.xy -= parameters[4].xy;
    float distance = parameters[1].w - p.z;
    float perspective = 4.5f / max(0.025f, distance);
    VSOut out;
    const float nearPlane = 0.025f, farPlane = 30.0f;
    float depth = farPlane * (distance - nearPlane) / (farPlane - nearPlane);
    out.pos = float4(p.x * 2.07f / aspect, p.y * 2.07f, depth, distance);
    out.pointSize = clamp(2.0f * perspective, 1.3f, 2.7f);
    out.color = kelvinRGB(temperature) * clamp(0.82f + p.z * 0.16f, 0.58f, 1.0f);
    return out;
}
fragment float4 fs_solid(VSOut in [[stage_in]], float2 uv [[point_coord]]) {
    float coverage = 1.0f - smoothstep(0.28f, 0.5f, length(uv - 0.5f));
    if (coverage < 0.01f) discard_fragment();
    return float4(in.color, coverage);
}
