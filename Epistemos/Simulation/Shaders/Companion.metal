//
//  Companion.metal
//  Simulation Mode S4 (placeholder) → S10 (real palette mask).
//
//  Per DOCTRINE I-16 (bit-perfect pixel rendering for pixel-art
//  categories): the vertex shader snaps world positions to the
//  physical pixel grid via `round(world * pixel_density) /
//  pixel_density` BEFORE conversion to NDC. No sub-pixel
//  positioning. No interpolation between atlas frames (frame
//  index changes step-wise, never blended).
//
//  S10 swaps the placeholder fragments for real mask-channel
//  sampling of `texture2d_array<float>` atlases (one slice per
//  head shape). Per DOCTRINE §10.5 the atlas pixels carry:
//
//      R channel = eye region
//      G channel = accent region
//      B channel = body region
//      A channel = alpha (negative-space cutouts use A=0 with
//                          B/G/R also 0 to make the cutout
//                          visible against the backdrop)
//
//  The fragment shader reads a `Palette` uniform indexed by
//  `palette_id` and recolors at draw time. This is what makes
//  custom palettes (sRGB hex) update instantly without a
//  re-rasterization round-trip.
//
//  The placeholder fragment functions (`*_placeholder`) are
//  KEPT in the file so the S4 acceptance harness keeps working
//  for synthetic tests that don't have real atlases bound.
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

// Per-palette uniform buffer entry. Mirrors the JSON schema in
// `Resources/CompanionAssets/palettes/*.json`. The renderer
// builds a `[Palette]` array at boot from the loaded palette
// JSONs and binds it to `buffer(3)` for the body fragment.
struct Palette {
    float4 body;    // RGBA 0…1
    float4 accent;
    float4 eye;
};

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
    uint   frame_index;
    uint   palette_id;
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
    out.frame_index = inst.frame_index;
    out.palette_id  = inst.palette_id;
    out.state_flags = inst.state_flags;
    return out;
}

// MARK: - Real body fragment — palette-mask sampling (S10)

/// Compute the atlas-space UV for a given (state row, frame col)
/// inside an atlas grid. The atlas is laid out as
/// (max_frames_columns × 14_state_rows). Each cell is one
/// frame's pixel block. The frame_index encodes (atlas_row << 4)
/// | frame_col in the renderer when binding the per-frame
/// instance — 4 bits is enough for the V1 8-frame max + 14
/// rows = 14×8 = 112 cells which fits in a single uint.
inline float2 computeAtlasUV(
    float2 quad_uv,
    uint frame_index,
    constant float4& atlas_grid // (cell_w_norm, cell_h_norm, max_cols, _pad)
) {
    uint row = frame_index >> 4;        // upper 4 bits — state row
    uint col = frame_index & 0xFu;      // lower 4 bits — frame col
    float cw = atlas_grid.x;
    float ch = atlas_grid.y;
    float u = quad_uv.x * cw + float(col) * cw;
    float v = quad_uv.y * ch + float(row) * ch;
    return float2(u, v);
}

/// Real body fragment — samples the per-head atlas and recolors
/// via the palette uniform. Per DOCTRINE §10.5:
///
///     atlas pixel.b * palette.body
///   + atlas pixel.g * palette.accent
///   + atlas pixel.r * palette.eye
///
/// Output alpha is the atlas pixel's alpha (so negative-space
/// eye cutouts in the §5.1 Block(Wide) silhouette show through
/// the backdrop). Tint multiplies for state flashes (e.g. error
/// red, recovery blue) per §4.7.
fragment float4 companion_fragment(
    VertexOut in [[stage_in]],
    texture2d_array<float> atlas [[texture(0)]],
    constant Palette* palettes [[buffer(3)]],
    constant float4& atlas_grid [[buffer(4)]],
    sampler s [[sampler(0)]]
) {
    float2 atlas_uv = computeAtlasUV(in.uv, in.frame_index, atlas_grid);
    float4 mask = atlas.sample(s, atlas_uv, in.atlas_index);
    Palette p = palettes[in.palette_id];

    float3 color = mask.b * p.body.rgb
                 + mask.g * p.accent.rgb
                 + mask.r * p.eye.rgb;

    // Tint multiplies; alpha rides through unchanged so the
    // I-16 hard-edge contract holds (no soft alpha bleeding).
    return float4(color * in.tint.rgb, mask.a * in.tint.a);
}

// MARK: - Real halo fragment — samples halo_active.png (S10)

/// Halo / eye-bloom fragment — samples a pre-baked single-slice
/// halo texture. The fragment ONLY emits when the
/// `STATE_FLAG_ACTIVE_HALO` bit is set. Output is multiplied by
/// the body palette's accent so each companion's halo carries
/// its palette family (e.g. orange for Claude, indigo for Kimi,
/// gold for Hermes). Additive blend in the pipeline state per
/// DOCTRINE §5.7.
fragment float4 halo_fragment(
    VertexOut in [[stage_in]],
    texture2d<float> halo_tex [[texture(1)]],
    constant Palette* palettes [[buffer(3)]],
    sampler s [[sampler(0)]]
) {
    bool active = (in.state_flags & STATE_FLAG_ACTIVE_HALO) != 0u;
    if (!active) {
        return float4(0.0, 0.0, 0.0, 0.0);
    }
    float4 halo = halo_tex.sample(s, in.uv);
    Palette p = palettes[in.palette_id];
    return float4(p.accent.rgb * halo.a * in.tint.rgb, halo.a * in.tint.a);
}

// MARK: - Placeholder fragments (kept for S4 synthetic harness)

fragment float4 companion_fragment_placeholder(VertexOut in [[stage_in]]) {
    // S4 placeholder: striped colour from tint + UV. S10's
    // `companion_fragment` above is the production fragment.
    float stripe = step(0.5, fract(in.uv.x * 4.0 + in.uv.y * 4.0));
    return in.tint * (0.7 + 0.3 * stripe);
}

fragment float4 halo_fragment_placeholder(VertexOut in [[stage_in]]) {
    float2 centered = in.uv - float2(0.5, 0.5);
    float dist = length(centered) * 2.0;
    float intensity = max(0.0, 1.0 - dist);
    intensity = floor(intensity * 4.0) / 4.0; // STEPPED per I-16
    bool active = (in.state_flags & STATE_FLAG_ACTIVE_HALO) != 0u;
    float gate = active ? 1.0 : 0.0;
    return float4(in.tint.rgb * intensity * gate, intensity * gate);
}
