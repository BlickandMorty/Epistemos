#include <metal_stdlib>
using namespace metal;

// ThinkingGlow — Animated radial glow pulse for OmegaPanel thinking state.
//
// Renders a soft, pulsing gradient that indicates active AI reasoning.
// Uses a radial falloff with time-based animation for the pulse effect.
// Designed to be rendered as a fullscreen quad overlay.

struct ThinkingGlowUniforms {
    float time;       // Elapsed seconds since animation start
    float intensity;  // 0.0 = invisible, 1.0 = full glow
    float2 center;    // Glow center in normalized coordinates (0-1)
    float4 glowColor; // RGBA glow color
    float2 resolution; // Viewport size in pixels
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// Fullscreen quad vertex shader (no vertex buffer needed — uses vertex_id).
vertex VertexOut thinking_glow_vertex(uint vertex_id [[vertex_id]]) {
    // Triangle strip covering the full viewport:
    //   vertex 0: (-1, -1)  vertex 1: (1, -1)
    //   vertex 2: (-1,  1)  vertex 3: (1,  1)
    float2 positions[4] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0,  1.0),
    };

    VertexOut out;
    out.position = float4(positions[vertex_id], 0.0, 1.0);
    // Map from clip space [-1,1] to UV [0,1]
    out.uv = positions[vertex_id] * 0.5 + 0.5;
    // Flip Y for Metal's coordinate system
    out.uv.y = 1.0 - out.uv.y;
    return out;
}

// Smooth radial falloff with pulse animation.
fragment float4 thinking_glow_fragment(
    VertexOut in [[stage_in]],
    constant ThinkingGlowUniforms &uniforms [[buffer(0)]]
) {
    // Correct for aspect ratio
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    float2 uv = in.uv;
    uv.x *= aspect;
    float2 center = uniforms.center;
    center.x *= aspect;

    // Distance from glow center
    float dist = distance(uv, center);

    // Pulsing animation: slow breathe cycle (~2s period)
    float breathe = 0.5 + 0.5 * sin(uniforms.time * 3.14159);

    // Two-layer glow: inner bright core + outer soft halo
    float innerRadius = 0.15 + 0.05 * breathe;
    float outerRadius = 0.5 + 0.15 * breathe;

    // Smooth falloff using smoothstep
    float inner = 1.0 - smoothstep(0.0, innerRadius, dist);
    float outer = 1.0 - smoothstep(innerRadius, outerRadius, dist);

    // Combine layers
    float glow = inner * 0.8 + outer * 0.3;

    // Apply intensity (for fade in/out)
    glow *= uniforms.intensity;

    // Final color with premultiplied alpha
    float4 color = uniforms.glowColor;
    color.a *= glow;
    color.rgb *= color.a;

    return color;
}

// MARK: - SS-IL inline-stream materialize (SwiftUI stitchable .colorEffect)
//
// A soft "materialize" shimmer for the inline note-AI answer while it streams: a
// scan band sweeps down the answer region, modulated by ThinkingGlow's breathe
// pulse (reusing the same aesthetic + math as the fragment above). Lives in this
// file (already compiled into default.metallib — see thinking_glow_* membership)
// so SwiftUI's `ShaderLibrary.inline_stream_materialize` always resolves at
// runtime. Pure light: composited over the faint cold-box wash, additive.
//
// `.colorEffect` signature: (float2 position, half4 color, <extra args…>) -> half4.
// position is in the effect view's local point space; we pass `size` to normalize.
[[ stitchable ]] half4 inline_stream_materialize(
    float2 position,
    half4 color,
    float2 size,
    float time,
    float intensity,
    half4 glowColor
) {
    float2 uv = position / max(size, float2(1.0, 1.0));   // → 0…1

    // Scan band sweeps top→bottom on a ~1.4 s loop (the answer "materializing").
    float sweep = fract(time / 1.4);
    float band = 1.0 - smoothstep(0.0, 0.16, fabs(uv.y - sweep));

    // Breathe pulse (identical cadence to thinking_glow_fragment) modulates energy.
    float breathe = 0.5 + 0.5 * sin(time * 3.14159);

    float glow = clamp(band * (0.55 + 0.45 * breathe) * intensity, 0.0, 1.0);

    half4 lit = glowColor;
    lit.a *= half(glow);
    lit.rgb *= lit.a;                       // premultiplied
    // Composite the glow light over the incoming (near-transparent) source.
    return color * half(1.0 - float(lit.a)) + lit;
}
