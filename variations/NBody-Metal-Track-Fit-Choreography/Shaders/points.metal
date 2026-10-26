#include <metal_stdlib>
using namespace metal;
struct VSOut { float4 pos [[position]]; float pointSize [[point_size]]; float3 color; float visibility; };
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
// Progress only advances with the music. Each randomized gesture carries
// particles onward around an axis rather than oscillating an offset.
float3 musicFlow(float3 p, float progress, int mode, float orientation, float layer) {
    float3 axis;
    float rate = 0.95f;
    switch (mode) {
        case 0: axis = float3(0, 0, 1); break; // Flat circular flow.
        case 1: axis = float3(1, 0, 0); break; // Vertical rolls.
        case 2: axis = float3(0, 1, 0); break; // Depth orbits.
        case 3: // Diagonal spiralling layers.
            axis = normalize(float3(1, 1, 0.5f));
            rate *= 0.75f + 0.25f * layer;
            break;
        case 4: // Stable groups sweep at different forward rates.
            axis = normalize(float3(0.2f, 0.5f, 1));
            rate *= 0.55f + 0.80f * layer;
            break;
        default: // A gently twisting corkscrew with stable per-particle rates.
            axis = normalize(float3(0.5f, 1, 0.2f));
            rate *= 0.85f + 0.20f * (2.0f * layer - 1.0f);
            break;
    }
    axis.xz = float2(cos(orientation)*axis.x + sin(orientation)*axis.z,
                     -sin(orientation)*axis.x + cos(orientation)*axis.z);
    float angle = progress * rate;
    float cs = cos(angle), sn = sin(angle);
    // Rotation preserves the cloud's radius, including when layers overlap.
    return p * cs + cross(axis, p) * sn + axis * dot(axis, p) * (1.0f - cs);
}
vertex VSOut vs_points(const device float4* positions [[buffer(0)]],
                       constant float4* parameters [[buffer(1)]],
                       constant float& sizeScale [[buffer(11)]], uint id [[vertex_id]]) {
    float aspect = max(parameters[1].x, 0.1f);
    float3 p = positions[id].xyz;
    float modes[6] = {parameters[7].x, parameters[7].y, parameters[7].z,
                      parameters[7].w, parameters[8].x, parameters[8].y};
    float progress[6] = {parameters[9].x, parameters[9].y, parameters[9].z,
                         parameters[9].w, parameters[10].x, parameters[10].y};
    // One axis per group avoids competing full-cloud rotations that can
    // look like rocking even when each individual angle advances steadily.
    uint group = id % 6u;
    p = musicFlow(p, progress[group] * parameters[8].w * 0.28f,
                  int(modes[group]), parameters[8].z, particleHash(id));
    float leadTravel[6] = {parameters[10].z, parameters[10].w,
        parameters[11].x, parameters[11].y, parameters[11].z, parameters[11].w};
    // Keep a permanent gravitational core. Render-only emissions must not
    // eventually carry every group away from the simulated central orbit.
    // Independent hash inputs distribute core particles across all six parts.
    bool centralCore = particleHash(id + 7919u) < 0.40f;
    float travelled = centralCore ? 0.0f : leadTravel[group] * 0.95f;
    float pathLength = 1.8f + 1.8f * particleHash(id);
    float cycle = fract(travelled / pathLength);
    // Motion never retracts. Particles fade before wrapping to their original
    // radius and fade back in after the invisible reset. Different path lengths
    // stagger the resets so the cloud does not pulse as a single shell.
    float fadeIn = travelled < pathLength ? 1.0f : smoothstep(0.0f, 0.16f, cycle);
    float visibility = fadeIn * (1.0f - smoothstep(0.80f, 1.0f, cycle));
    float3 radial = p / max(length(p), 0.001f);
    p += radial * (cycle * pathLength);
    // The musical lead drives a common central orbit for every particle,
    // including the permanent core. Integrated phrase strength changes speed
    // continuously, so sustained riffs visibly carry the whole cloud onward.
    float leadProgress = leadTravel[0] + leadTravel[1] + leadTravel[2]
                       + leadTravel[3] + leadTravel[4] + leadTravel[5];
    float angle = leadProgress * 0.85f;
    float cs = cos(angle), sn = sin(angle);
    p.xy = float2(cs*p.x - sn*p.y, sn*p.x + cs*p.y);
    // Include the initial cloud (1.35) and the longest outward path (3.6).
    // A soft exponential scale preserves variation beyond that normal extent,
    // rather than clipping all distant particles to the same blue at 2.7.
    const float colorRadius = 1.35f + 3.6f;
    float relativeRadius = length(p) / colorRadius;
    float radialFraction = 1.0f - exp(-0.33136f * relativeRadius * relativeRadius);
    float temperature = mix(1000.0f, 40000.0f, radialFraction);
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
    out.visibility = visibility;
    out.color = kelvinRGB(temperature) * clamp(0.82f + p.z * 0.16f, 0.58f, 1.0f);
    return out;
}
fragment float4 fs_solid(VSOut in [[stage_in]], float2 uv [[point_coord]]) {
    float coverage = 1.0f - smoothstep(0.28f, 0.5f, length(uv - 0.5f));
    coverage *= in.visibility;
    if (coverage < 0.01f) discard_fragment();
    return float4(in.color, coverage);
}
