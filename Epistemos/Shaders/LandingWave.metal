#include <metal_stdlib>
using namespace metal;

// LandingWave — GPU pipeline for the landing-page liquid ASCII wave search.
//
// Entry points:
//   - `landing_wave_step`     : compute — advances the 2D wave height field by
//                               one FDTD tick and injects any pending drop
//                               impulses. Ping-pongs between two R32Float
//                               textures (prev ↔ curr → next).
//   - `landing_wave_clear`    : compute — zeros a height texture (warm boot).
//   - `landing_wave_vertex`   : fullscreen triangle-strip vertex.
//   - `landing_wave_fragment` : samples the height field, maps to the ASCII
//                               luminance ramp, samples the glyph atlas, and
//                               tints by the theme gradient.
//
// See docs/LANDING_WAVE_SEARCH_PLAN.md for the full spec.

// MARK: - Shared types

// Must match Swift's `LandingWaveUniforms` byte-for-byte. Keep in sync.
struct LandingWaveUniforms {
    float     time;               // seconds since renderer start
    float2    resolution;         // drawable size in pixels (for aspect)
    int2      gridSize;           // ASCII grid in cells (width, height)
    float     waveSpeedSquared;   // c² for the wave equation (CFL-stable ≤ 0.5)
    float     waveDamping;        // per-tick multiplier, 0.995 typical
    float     ambientAmplitude;   // idle micro-wave amplitude (reserved)
    int       dropCount;          // number of drops to inject this frame (0..8)
    float4    drops[8];           // each: (cellX, cellY, radiusCells, strength)
    float4    barRect;            // (cellX, cellY, widthCells, heightCells)
    float     barEmergenceT;      // 0..1 emergence progress (for water trail)
    int       reduceMotion;       // 0 = animate, 1 = collapse
    float4    themeBase;          // RGBA base wave color
    float4    themeAccent;        // RGBA crest color (mixed by |height|)
    int2      atlasGridSize;      // atlas grid dimensions (cells)
    int       rampIndexCount;     // number of entries in rampCellIndices (≤12)
    int2      rampCellIndices[12];// atlas cell index per luminance ramp position
};

struct LandingWaveVertexOut {
    float4 position [[position]];
    float2 uv;
};

// MARK: - Helpers

// Safe neighbour sample: Dirichlet boundary (height = 0 outside the grid).
static float sampleHeight(texture2d<float, access::read> tex, int2 pos, int2 gridSize) {
    if (pos.x < 0 || pos.y < 0 || pos.x >= gridSize.x || pos.y >= gridSize.y) {
        return 0.0;
    }
    return tex.read(uint2(pos)).r;
}

// MARK: - Compute: wave step (FDTD + impulse injection)

kernel void landing_wave_step(
    texture2d<float, access::read>   prevHeight [[texture(0)]],
    texture2d<float, access::read>   currHeight [[texture(1)]],
    texture2d<float, access::write>  nextHeight [[texture(2)]],
    constant LandingWaveUniforms &uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    int x = int(gid.x);
    int y = int(gid.y);
    if (x >= uniforms.gridSize.x || y >= uniforms.gridSize.y) {
        return;
    }

    if (uniforms.reduceMotion != 0) {
        // Reduce-motion collapse: keep the field at zero every tick. The host
        // won't run continuous updates in this mode but we still guard the
        // kernel in case a stale frame is dispatched.
        nextHeight.write(float4(0.0), gid);
        return;
    }

    int2 gridSize = uniforms.gridSize;
    int2 pos = int2(x, y);

    float h_prev = sampleHeight(prevHeight, pos, gridSize);
    float h_curr = sampleHeight(currHeight, pos, gridSize);

    float h_up = sampleHeight(currHeight, int2(x,     y - 1), gridSize);
    float h_dn = sampleHeight(currHeight, int2(x,     y + 1), gridSize);
    float h_lf = sampleHeight(currHeight, int2(x - 1, y    ), gridSize);
    float h_rt = sampleHeight(currHeight, int2(x + 1, y    ), gridSize);

    // Linear 2D wave equation, explicit FDTD:
    //   h[t+1] = 2·h[t] − h[t−1] + c² · (Σneighbours − 4·h[t])
    float laplacian = h_up + h_dn + h_lf + h_rt - 4.0 * h_curr;
    float h_next = 2.0 * h_curr - h_prev + uniforms.waveSpeedSquared * laplacian;

    // Amplitude damping (per-tick). Damping > 1 would amplify — clamp for safety.
    h_next *= min(uniforms.waveDamping, 1.0);

    // Drop injection. Each entry in `drops` is fired for exactly one frame
    // (the host removes it after dispatching). Strength is the peak amplitude,
    // radius controls the Gaussian width in cells.
    for (int i = 0; i < uniforms.dropCount && i < 8; ++i) {
        float4 drop = uniforms.drops[i];
        float dx = float(x) - drop.x;
        float dy = float(y) - drop.y;
        float d2 = dx * dx + dy * dy;
        float radius = max(drop.z, 0.5);
        float gauss = exp(-d2 / (radius * radius));
        h_next += drop.w * gauss;
    }

    nextHeight.write(float4(h_next, 0.0, 0.0, 0.0), gid);
}

// MARK: - Compute: clear

kernel void landing_wave_clear(
    texture2d<float, access::write> target [[texture(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    target.write(float4(0.0), gid);
}

// MARK: - Render: fullscreen vertex

vertex LandingWaveVertexOut landing_wave_vertex(uint vertex_id [[vertex_id]]) {
    const float2 positions[4] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0,  1.0),
    };

    LandingWaveVertexOut out;
    out.position = float4(positions[vertex_id], 0.0, 1.0);
    out.uv = positions[vertex_id] * 0.5 + 0.5;
    out.uv.y = 1.0 - out.uv.y;
    return out;
}

// MARK: - Render: fragment (ASCII ramp + glyph atlas sample)

fragment float4 landing_wave_fragment(
    LandingWaveVertexOut in [[stage_in]],
    constant LandingWaveUniforms &uniforms [[buffer(0)]],
    texture2d<float, access::read> heightTex [[texture(0)]],
    texture2d<float> atlasTex [[texture(1)]],
    sampler atlasSampler [[sampler(0)]]
) {
    if (uniforms.reduceMotion != 0) {
        return float4(0.0);
    }

    int2 gridSize = uniforms.gridSize;
    if (gridSize.x <= 0 || gridSize.y <= 0) {
        return float4(0.0);
    }

    // Cell coordinate in the wave grid (fractional).
    float2 cellF = in.uv * float2(gridSize);
    int2 cell = int2(clamp(cellF, float2(0.0), float2(gridSize - int2(1))));

    float h = heightTex.read(uint2(cell)).r;

    // Vertical gradient → fake 3D shading. Crests brighten, troughs darken.
    float h_up = sampleHeight(heightTex, int2(cell.x, cell.y - 1), gridSize);
    float h_dn = sampleHeight(heightTex, int2(cell.x, cell.y + 1), gridSize);
    float gradY = h_dn - h_up;
    float shaded = abs(h) + 0.3 * gradY;

    // Map shaded value (0..~1) to ramp index ∈ [0, rampIndexCount - 1].
    int rampMax = max(uniforms.rampIndexCount - 1, 0);
    int index = clamp(int(round(saturate(shaded) * float(rampMax))), 0, rampMax);
    int2 atlasCell = uniforms.rampCellIndices[index];
    if (uniforms.atlasGridSize.x <= 0 || uniforms.atlasGridSize.y <= 0) {
        return float4(0.0);
    }

    // Local UV within the current ASCII cell (0..1). We sample the atlas cell
    // using the cell-local UV rather than a global atlas UV, which means each
    // ASCII cell renders its full glyph.
    float2 cellLocalUV = fract(cellF);
    float2 atlasUV = (float2(atlasCell) + cellLocalUV) / float2(uniforms.atlasGridSize);
    float coverage = atlasTex.sample(atlasSampler, atlasUV).r;

    // Tint: base → accent mixed by saturated |height|.
    float4 tint = mix(uniforms.themeBase, uniforms.themeAccent, saturate(abs(h)));
    return float4(tint.rgb, tint.a * coverage);
}
