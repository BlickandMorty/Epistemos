//
//  Companion.metal
//  Simulation Mode S4 — placeholder body + halo shaders.
//
//  Per DOCTRINE I-16 (bit-perfect pixel rendering for pixel-art
//  categories): the vertex shader snaps world positions to the
//  physical pixel grid via `round(world * pixel_density) /
//  pixel_density` BEFORE conversion to NDC. No sub-pixel
//  positioning. No interpolation between atlas frames (frame
//  index changes step-wise, never blended).
//
//  S4 ships placeholder fragment shaders — striped tint for body,
//  stepped radial falloff for halo — so the end-to-end pipeline
//  can render colored rectangles for the synthetic harness. S10
//  replaces both fragments with real atlas sampling.
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Mirrors of agent_core::ffi::PerInstanceData

struct PerInstanceData {
    uint   agent_id_lo;
    uint   agent_id_lo_hi; // upper 32 bits of agent_id_lo
    uint   agent_id_hi_lo;
    uint   agent_id_hi_hi;
    float2 position;
    float2 scale;
    uint   atlas_index;
    uint   frame_index;
    uint   palette_id;
    float4 tint;
    uint   state_flags;
};

// State flag bit positions (mirror crate::ffi::StateFlags).
constant uint STATE_FLAG_GATE        = 1u << 0;
constant uint STATE_FLAG_ERROR       = 1u << 1;
constant uint STATE_FLAG_IDLE_AMB    = 1u << 2;
constant uint STATE_FLAG_ACTIVE_HALO = 1u << 3;
constant uint STATE_FLAG_RECOVERY    = 1u << 4;

struct Camera {
    float2 viewport_size; // physical pixels (Retina-aware)
    float  pixel_density; // 1.0 / 2.0 / 3.0
    float  _pad;
    float2 view_offset;   // scene-space scroll (integer pixels)
};

struct VertexIn {
    float2 position [[attribute(0)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
    float4 tint;
    uint   atlas_index;
    uint   state_flags;
};

// MARK: - Vertex (snap-to-pixel; integer-scale; I-16)

vertex VertexOut companion_vertex(
    VertexIn vin [[stage_in]],
    uint instance_id [[instance_id]],
    constant PerInstanceData* instances [[buffer(1)]],
    constant Camera& camera [[buffer(2)]]
) {
    PerInstanceData inst = instances[instance_id];

    // World-space position. `vin.position` is the unit-quad
    // vertex (one of {(-0.5,-0.5), (0.5,-0.5), (0.5,0.5),
    // (-0.5,0.5)}); inst.scale is integer (1×/2×/3×/4× per I-16,
    // validated Rust-side); inst.position is the per-instance
    // origin in scene units.
    float2 world = vin.position * inst.scale + inst.position
                   - camera.view_offset;

    // I-16 SNAP-TO-PIXEL. Round to the physical pixel grid
    // BEFORE NDC conversion so the rasteriser's pixel-coverage
    // determination lands on integer pixels regardless of
    // sub-unit drift in the source position.
    float2 snapped = round(world * camera.pixel_density)
                   / camera.pixel_density;

    // NDC (Metal: y-down → top-up flip).
    float2 ndc = (snapped / camera.viewport_size) * 2.0 - 1.0;
    ndc.y = -ndc.y;

    VertexOut out;
    out.position    = float4(ndc, 0.0, 1.0);
    out.uv          = vin.position * 0.5 + 0.5; // [0,1]^2
    out.tint        = inst.tint;
    out.atlas_index = inst.atlas_index;
    out.state_flags = inst.state_flags;
    return out;
}

// MARK: - Body fragment (placeholder — striped tint)

fragment float4 companion_fragment_placeholder(VertexOut in [[stage_in]]) {
    // S4 placeholder: striped colour from tint + UV. S10
    // replaces with real atlas sampling.
    float stripe = step(0.5, fract(in.uv.x * 4.0 + in.uv.y * 4.0));
    return in.tint * (0.7 + 0.3 * stripe);
}

// MARK: - Halo fragment (placeholder — STEPPED radial falloff)

// Per DOCTRINE §5.7: "softness lives in the texture, not in any
// blur shader" — the real halo will sample a pre-baked PNG with
// stepped radial falloff. The S4 placeholder simulates the same
// stepped pattern procedurally so the additive blend wiring is
// verifiable end-to-end before the real texture lands at S10.
fragment float4 halo_fragment_placeholder(VertexOut in [[stage_in]]) {
    float2 centered = in.uv - float2(0.5, 0.5);
    float dist = length(centered) * 2.0; // 0 at centre, 1 at edge

    // STEPPED falloff per I-16 — 4 discrete intensity levels.
    float intensity = max(0.0, 1.0 - dist);
    intensity = floor(intensity * 4.0) / 4.0;

    // Halo only visible when ACTIVE_HALO bit is set (the
    // renderer issues this draw only for active companions, so
    // this is belt-and-braces).
    bool active = (in.state_flags & STATE_FLAG_ACTIVE_HALO) != 0u;
    float gate = active ? 1.0 : 0.0;

    // Output is multiplied additively by the body tint so each
    // companion's halo carries its palette. Alpha = intensity to
    // play correctly with the additive blend factors (one × one).
    return float4(in.tint.rgb * intensity * gate, intensity * gate);
}
