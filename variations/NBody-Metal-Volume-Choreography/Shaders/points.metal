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
                       constant float4* parameters [[buffer(1)]],
                       constant float& sizeScale [[buffer(11)]], uint id [[vertex_id]]) {
    float4 music = parameters[0];
    float energy = music.y;
    float4 bands = parameters[2]; // bass, midrange, treble, beat-aligned attack
    float phrase = parameters[3].x;
    float4 instruments = parameters[5]; // vocals, drums, bass, guitar
    float piano = parameters[6].x, other = parameters[6].y;
    float aspect = max(parameters[1].x, 0.1f);
    float3 physicalPosition = positions[id].xyz;
    float radius = length(physicalPosition);
    // Radius-dependent rotations around all axes preserve volume and avoid
    // privileging an XY sheet. Music still moves individual depth layers.
    float3 angles = float3(bands.y * 0.08f + phrase * 0.05f + instruments.x * 0.16f,
                          bands.z * 0.06f + instruments.w * 0.18f + other * 0.06f,
                          bands.x * 0.06f + instruments.z * 0.22f + energy * 0.04f)
                    * sin(radius * 1.6f + float3(0.0f, 2.1f, 4.2f));
    float3 p = physicalPosition;
    p.yz = float2(cos(angles.x)*p.y - sin(angles.x)*p.z,
                  sin(angles.x)*p.y + cos(angles.x)*p.z);
    p.xz = float2(cos(angles.y)*p.x - sin(angles.y)*p.z,
                  sin(angles.y)*p.x + cos(angles.y)*p.z);
    p.xy = float2(cos(angles.z)*p.x - sin(angles.z)*p.y,
                  sin(angles.z)*p.x + cos(angles.z)*p.y);
    p *= 1.0f + (instruments.y * 0.055f + bands.w * 0.015f) * sin(radius * 2.1f);
    // Piano accents add a distinct vertical wave; residual accompaniment
    // adds a gentler depth wave. These are bounded display deformations.
    p.y += piano * 0.065f * sin(radius * 3.4f + physicalPosition.x);
    p.z += other * 0.035f * sin(radius * 1.9f + physicalPosition.y);
    // Map distance from the 3D centre to a blackbody color temperature:
    // redder in the core, increasingly blue toward the outer edge.
    float radialFraction = smoothstep(0.0f, 2.7f, length(p));
    float temperature = mix(1000.0f, 12000.0f, radialFraction);
    // User-controlled orbit around the particle volume.
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
    out.pointSize = clamp(2.0f * perspective, 1.3f, 2.7f) * sizeScale;
    out.color = kelvinRGB(temperature) * clamp(0.82f + p.z * 0.16f, 0.58f, 1.0f);
    return out;
}
fragment float4 fs_solid(VSOut in [[stage_in]], float2 uv [[point_coord]]) {
    float coverage = 1.0f - smoothstep(0.28f, 0.5f, length(uv - 0.5f));
    if (coverage < 0.01f) discard_fragment();
    return float4(in.color, coverage);
}
