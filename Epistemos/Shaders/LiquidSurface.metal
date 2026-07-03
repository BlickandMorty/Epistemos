#include <metal_stdlib>
using namespace metal;

// Owner 2026-07-03: make the app feel ALIVE beyond the graph. Stitchable SwiftUI color
// shaders — a subtle animated liquid layer drawn OVER a base tint (they blend over the
// incoming color, low intensity). Compiled into default.metallib by Xcode's Metal build
// phase; referenced via SwiftUI's ShaderLibrary. Position arrives in view-local point
// space, so the view size is passed as a uniform for UV normalization.

// --- shared cheap value-noise + fbm ---
static inline float hash21(float2 p) {
    p = fract(p * float2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}
static inline float valueNoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i), b = hash21(i + float2(1, 0));
    float c = hash21(i + float2(0, 1)), d = hash21(i + float2(1, 1));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
static inline float fbm(float2 p) {
    float v = 0.0, amp = 0.5;
    for (int i = 0; i < 4; ++i) { v += amp * valueNoise(p); p *= 2.0; amp *= 0.5; }
    return v;
}

// A) AURORA / DOMAIN-WARP GRADIENT — subtle animated theme-tinted backdrop.
// Apply to a filled Rectangle(). intensity ~0.12–0.16.
[[ stitchable ]] half4 auroraFlow(float2 position, half4 color,
                                  float time, float2 size,
                                  half4 tintA, half4 tintB, float intensity) {
    float2 uv = position / max(size, float2(1.0, 1.0));
    float2 warp = float2(fbm(uv * 3.0 + time * 0.05),
                         fbm(uv * 3.0 - time * 0.06 + 7.3));
    float f = fbm(uv * 2.0 + warp * 0.6 + float2(0.0, time * 0.03));
    float g = smoothstep(0.2, 0.9, f);
    half4 grad = mix(tintA, tintB, half(g));
    half a = half(intensity) * grad.a;
    return half4(mix(color.rgb, grad.rgb, a), color.a);
}

// B) LIQUID SHEEN SWEEP — moving specular band for loading / idle states.
// Apply behind a label. intensity ~0.18.
[[ stitchable ]] half4 liquidSheen(float2 position, half4 color,
                                   float time, float2 size,
                                   half4 sheen, float intensity) {
    float2 uv = position / max(size, float2(1.0, 1.0));
    float d = (uv.x + uv.y) * 0.5;
    float sweep = fract(time * 0.18);
    float band = exp(-pow((d - sweep) * 6.0, 2.0));       // gaussian band
    band *= 0.85 + 0.15 * sin(uv.y * 12.0 + time * 1.5);  // liquid wobble
    half a = half(band * intensity) * sheen.a;
    return half4(mix(color.rgb, sheen.rgb, a), color.a);
}

// C) SUBTLE DOMAIN-WARP GRADIENT — wobbling vertical theme gradient (panels/text).
// intensity ~0.14.
[[ stitchable ]] half4 domainWarpGradient(float2 position, half4 color,
                                          float time, float2 size,
                                          half4 topC, half4 botC, float intensity) {
    float2 uv = position / max(size, float2(1.0, 1.0));
    float w = fbm(uv * 2.5 + float2(time * 0.04, time * 0.03));
    float y = clamp(uv.y + (w - 0.5) * 0.25, 0.0, 1.0);
    half4 grad = mix(topC, botC, half(y));
    return half4(mix(color.rgb, grad.rgb, half(intensity)), color.a);
}
