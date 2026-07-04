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

// D) PIXEL-ART VECTOR-SQUARE GRADIENT — a blocky "pixel-art blur gradient" that drifts
// slowly and gets MORE dynamic near the cursor (owner 2026-07-03). Colors stay close to
// the base tints (subtle). `cursor` is view-space; pass (-1,-1) when the mouse is absent.
[[ stitchable ]] half4 pixelGradient(float2 position, half4 color,
                                     float time, float2 size, float2 cursor,
                                     half4 tintA, half4 tintB, float intensity) {
    float2 sz = max(size, float2(1.0, 1.0));
    float2 uv = position / sz;

    // Cursor = a vector WAKE, not a ball of light. A radial train of decaying crests
    // emanates from the pointer and DISPLACES the grid, so the squares themselves ripple
    // and interfere with the drifting gradient — a fluid wake running through the vectors.
    // No bright core: the pointer's presence reads only as ripples in the field.
    float wake = 0.0;
    if (cursor.x >= 0.0) {
        float2 cur = cursor / sz;
        float2 delta = uv - cur;
        float d = length(delta);
        float2 dir = (d > 1e-4) ? delta / d : float2(0.0);
        wake = (sin(d * 40.0 - time * 4.0) + 0.5 * sin(d * 22.0 - time * 2.6)) * exp(-d * 5.0);
        uv += dir * wake * 0.022;   // push the grid along the radial → the cells ripple
    }

    // Quantize to square cells (pixel-art). Middle size — smaller than the original,
    // a touch larger than the previous pass.
    const float cells = 28.0;
    float2 cellCenter = (floor(uv * cells) + 0.5) / cells;

    // Multi-wave drift → several THIN, shifting bands instead of one thick streak.
    float g = 0.5
        + 0.30 * sin((cellCenter.x + cellCenter.y) * 6.0 + time * 0.30)
        + 0.14 * sin((cellCenter.x - cellCenter.y) * 9.0 - time * 0.22)
        + 0.10 * sin(cellCenter.y * 15.0 + time * 0.17);
    g += wake * 0.10;   // the wake reads as a brightness ripple IN the vectors (no bright ball)

    half4 grad = mix(tintA, tintB, half(clamp(g, 0.0, 1.0)));
    half a = half(intensity) * grad.a;   // uniform — no hotspot under the cursor
    return half4(mix(color.rgb, grad.rgb, a), color.a);
}

// ASCII WAVE — a gentle traveling distortion so the revealed word-wake UNDULATES as part of
// the gradient field, not as a flat overlay (owner 2026-07-04). Applied via .distortionEffect.
[[ stitchable ]] float2 asciiWave(float2 position, float time) {
    float y = sin(position.x * 0.035 + time * 1.3) * 2.4
            + sin(position.x * 0.017 - time * 0.7) * 1.2;
    float x = sin(position.y * 0.04 + time * 0.9) * 1.0;
    return position + float2(x, y);
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
