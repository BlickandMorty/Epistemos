// SimulationQuads.metal
//
// WAVE G G2 — Sprite atlas + instanced Metal quads.
//
// G-G2-METAL guard (substrate floor; not yet wired by any Swift
// dispatcher).
//
// Per `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
// §5 Phase B.3 G2 + `agent_core/src/tamagotchi/sprite_atlas.rs`
// (Rust substrate, 13 tests).
//
// **Acceptance bar (per G3):** 50 sprites · 24 emotes · 60 FPS
// (deterministic idle/walk) on M2 Pro 16 GB. Substrate floor lands
// the shader + Rust uniform structs; the Swift dispatch + frame
// scheduler live in `Epistemos/Views/Simulation/` (deferred per §1.5
// scope boundary — Swift edits need xcodebuild + app run).
//
// **Block layout (matches Rust InstancedQuad):**
//   * world_x / world_y : per-instance world-space position
//   * cell_row / cell_col : sprite-atlas cell index (computed UV in
//     the shader to avoid a CPU round-trip)
//   * scale : per-instance scale multiplier
//
// **HARDWARE-BUDGET:** Apple GPU drawIndexedPrimitives with
// instanceCount handles 1000+ quads at 60 FPS comfortably on M2 Pro.
// 50-sprite Tamagotchi load is well within budget.
//
// Build flags: -O3 -ffast-math

#include <metal_stdlib>
using namespace metal;

struct InstancedQuad {
    float  world_x;
    float  world_y;
    uint   cell_row;
    uint   cell_col;
    float  scale;
};

struct AtlasGeometry {
    uint cell_pixels;
    uint cols;
    uint rows;
};

struct VertexOut {
    float4 position [[position]];
    float2 texcoord;
};

/// Instanced vertex shader: 4 vertices per quad (corner mask in
/// `vid % 4`), `instance` indexes into the InstancedQuad buffer.
/// UVs are computed from the cell index + the atlas geometry uniform.
vertex VertexOut simulationQuadVertex(
    uint                   vid           [[vertex_id]],
    uint                   instance      [[instance_id]],
    constant InstancedQuad*  quads      [[buffer(0)]],
    constant AtlasGeometry&  atlas      [[buffer(1)]]
) {
    InstancedQuad q = quads[instance];
    uint corner = vid % 4u;
    float2 corner_offset = float2(
        (corner == 1u || corner == 2u) ? 1.0f : 0.0f,
        (corner == 2u || corner == 3u) ? 1.0f : 0.0f
    );
    float cell_w_uv = 1.0f / float(atlas.cols);
    float cell_h_uv = 1.0f / float(atlas.rows);
    float2 uv_origin = float2(
        float(q.cell_col) * cell_w_uv,
        float(q.cell_row) * cell_h_uv
    );

    VertexOut out;
    out.position = float4(
        q.world_x + corner_offset.x * q.scale,
        q.world_y + corner_offset.y * q.scale,
        0.0f,
        1.0f
    );
    out.texcoord = uv_origin + corner_offset * float2(cell_w_uv, cell_h_uv);
    return out;
}

fragment float4 simulationQuadFragment(
    VertexOut         in    [[stage_in]],
    texture2d<float>  atlas [[texture(0)]],
    sampler           samp  [[sampler(0)]]
) {
    return atlas.sample(samp, in.texcoord);
}
