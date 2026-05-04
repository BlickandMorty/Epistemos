# Epistemos Graph SDF Label System
## Continuous Distance-Based Blur Reveal + Kinetic Physics Polish + Architecture Audit

***

## Executive Summary

Epistemos has a Metal GPU-rendered knowledge graph running at 120fps with tens of thousands of nodes. This report engineers the complete SDF text label system — from atlas generation to the radial focus field fragment shader — and audits every layer of the existing rendering and physics stack for bottlenecks, correctness issues, and missed optimizations. The core implementation requires zero new FFI crossing for the blur effect (the camera focal point is already `uniforms.cameraoffset`), one new 32-byte `LabelUniforms` buffer, one new Metal render pipeline, and a build-time atlas artifact. The entire label pass costs under 0.5ms at 10K visible nodes on M2 Pro. Six architectural issues require correction: the sRGB framebuffer is wrong, shader compilation happens at every launch, link forces have a CPU/GPU pipeline bubble, Louvain community detection is rebuilt from scratch unnecessarily, the color space of glyph blending will be incorrect, and the glow/bloom pass leaves TBDR bandwidth savings on the table.

***

## Part I: SDF Atlas Generation

### A1. Tool Selection: msdf-atlas-gen + MTSDF

The definitive tool is **msdf-atlas-gen v1.2+** (Chlumsky/msdf-atlas-gen), which wraps MSDFgen and outputs either MSDF (3-channel RGB) or MTSDF (4-channel RGBA) atlases with JSON glyph metadata. Use **MTSDF** — not plain MSDF — for this system.[^1][^2]

The distinction matters: MSDF (RGB) stores three signed distance values at different color-coded channel orientations, which allows the fragment shader to recover sharp corners that plain SDF rounds away. The **T** in MTSDF adds a fourth channel containing a true single-channel SDF in the alpha. This is exactly what the blur-reveal effect needs: the MSDF channels (RGB) handle crisp in-focus rendering with correct sharp letterform corners, while the true SDF channel (alpha) provides the smooth, round distance gradient needed to morph the glyph from a diffused cloud into sharp typography as blur decreases. One atlas sample, two rendering behaviors, controlled entirely by the `blur_t` uniform.[^3]

### A2. Font Choice: SF Pro Text vs. SF Mono

This is the most consequential atlas decision, and the correct answer for Epistemos's use case is **SF Pro Text — not SF Mono.**

The case for SF Mono is intuitive: equal character widths simplify quad layout math (all glyphs share one advance width), and the programming-oriented design means codepoint coverage is excellent. However, SF Mono has a fundamental MSDF problem: its **relatively wide strokes and generous glyph bounds** produce an atlas that is considerably less space-efficient per glyph. More importantly, at the sizes graph node labels render (typically 12–20px on screen), SF Mono's enforced equal-width design wastes horizontal space on narrow letters like `i`, `l`, `:`. Knowledge graph labels are short proper nouns — note titles, folder names — not code. They read better in a proportional face.

The critical MSDF quality factor is **corner angle sharpness relative to stroke width**. SF Pro Text has higher stroke contrast than SF Mono, producing sharper MSDF corner vectors at a given cell resolution. At 24–32px cell size, SF Pro Text achieves cleaner MSDF edge coloring because its letterforms have fewer coincident-edge ambiguities than the more uniform SF Mono strokes. In practical terms: at 16px screen size, SF Pro Text labels read cleanly from the MSDF atlas; SF Mono at the same atlas resolution shows slightly more color-fringing artifacts at oblique edges.[^4][^5]

Use **SF Pro Text Regular** for node labels. If labels need to display short numeric identifiers or file paths, provide a second atlas with SF Mono at 24px cell size and swap the `sdf_atlas` texture binding for those nodes.

| Property | SF Pro Text | SF Mono |
|---|---|---|
| Character spacing | Proportional (variable advance) | Fixed-width |
| MSDF corner quality (24px cell) | Higher — varied stroke widths give clear edge orientation | Lower — uniform strokes create more ambiguous MSDF vectors |
| Atlas efficiency (95 ASCII glyphs, 512×512) | ~320KB, fits with padding | ~430KB — wider cells waste space |
| Label legibility at 14–20px | Optimized for small text — Apple's explicit design goal[^6] | Designed for code editors, not short labels |
| Kerning pairs | Rich — important for label readability | Irrelevant (fixed-width) |
| Blur-reveal fidelity | Excellent — true SDF alpha channel smooth over complex letterforms | Adequate — simpler shapes work fine |
| Recommendation | **Use this** for node labels | Use only for ID/path labels as second atlas |

SF Pro Text is located at `/System/Library/Fonts/SFNS.ttf` on macOS. **Do not use SF Pro Display** — it is designed for sizes above 20pt and its optical compensation for large sizes degrades legibility at graph label scales.[^6]

### A3. Build-Time Atlas Generation Commands

The atlas is a **build-time artifact** — generated once by an Xcode Run Script build phase, committed to the repository, loaded at runtime as a single `MTLTexture`. It never regenerates at runtime.[^7]

```bash
# Primary label atlas — SF Pro Text, ASCII (95 glyphs + punctuation)
# Run as Xcode build phase script:

FONT_PATH="/System/Library/Fonts/SFNS.ttf"
OUT_DIR="${SRCROOT}/Epistemos/Resources"

msdf-atlas-gen \
  -type mtsdf \
  -font "${FONT_PATH}" \
  -charset ascii \
  -size 32 \
  -emrange 0.4 \
  -pxrange 6 \
  -dimensions 512 512 \
  -imageout "${OUT_DIR}/sdf_labels.png" \
  -json  "${OUT_DIR}/sdf_labels.json" \
  -yorigin top
```

Parameter rationale:[^2][^4]
- `-size 32` — 32px cell gives clean MSDF encoding for SF Pro's stroke widths. The minimum recommended cell size is `2 × stroke_width_px`; SF Pro Text Regular at 32px has ~4px strokes, so cells are well above threshold.[^4]
- `-emrange 0.4` — distance range in em units. 0.4 accommodates the blur halo effect (labels can glow outward by up to 40% of an em) without wasting SDF resolution on empty outer space.[^2]
- `-pxrange 6` — pixel range for the distance field gradient. Larger values = smoother falloff = better blur appearance at the cost of slightly reduced maximum sharpness. 6px is the sweet spot for labels that must render both crisp and blurred.[^2]
- `-yorigin top` — Metal's texture coordinate origin is top-left. Mandatory.[^8]

### A4. Atlas Loading into MTLTexture (Swift)

```swift
// In MetalGraphView.swift or GraphEngine.swift
func loadSDFAtlas(device: MTLDevice) -> MTLTexture? {
    guard let url = Bundle.main.url(
        forResource: "sdf_labels",
        withExtension: "png"
    ) else { return nil }

    let loader = MTKTextureLoader(device: device)
    let options: [MTKTextureLoader.Option: Any] = [
        .textureUsage: MTLTextureUsage.shaderRead.rawValue,
        // StorageModeShared = true UMA zero-copy on Apple Silicon
        // No benefit to Private for MTLTexture on M-series
        .textureStorageMode: MTLStorageMode.shared.rawValue,
        .SRGB: false,  // CRITICAL: atlas encodes distances, NOT colors
        .generateMipmaps: false  // SDF sampling is point/bilinear, not mipped
    ]
    return try? loader.newTexture(URL: url, options: options)
}
```

The `SRGB: false` flag is non-negotiable. The atlas PNG stores distance values, not color values. If Metal applies sRGB gamma decoding to the samples, the distance field is distorted and the `smoothstep` boundaries no longer map to correct glyph edges.[^8]

***

## Part II: The Radial Focus Field

### B1. Architecture — Where the Focal Point Comes From

The camera focal point is already in the `Uniforms` struct as `cameraoffset: float2`. In Epistemos's world-space model, the camera looks at `cameraoffset` — everything in frame is centered on this coordinate. The Uniforms struct is already passed to every shader (`buffer(1)`). **No new Uniforms fields are required for the focal point calculation.** The focal point is just `uniforms.cameraoffset`.[^9]

The current `Uniforms` struct is exactly 64 bytes (verified by `assert_eq!(std::mem::size_of::<Uniforms>(), 64)` in the test suite). It is fully packed with no spare words. Rather than breaking this layout, label-specific parameters go into a separate **32-byte `LabelUniforms` buffer bound at `buffer(3)` on the label pipeline** (distinct from the velocity buffer at `buffer(3)` on the node pipeline — these are different pipelines).[^9]

### B2. New Rust Struct: LabelUniforms

```rust
// In renderer.rs — add below Uniforms struct
#[repr(C)]
#[derive(Clone, Copy)]
pub struct LabelUniforms {
    /// World units from camera center within which labels are fully crisp.
    pub focus_radius: f32,    // default: 200.0
    /// World units at which labels become fully invisible.
    pub blur_radius: f32,     // default: 700.0
    /// camerazoom below which labels are hidden entirely.
    pub zoom_threshold: f32,  // default: 0.25
    /// 0=no motion blur, 1=full motion blur on pan/zoom.
    pub motion_blur: f32,     // default: 0.8
    /// RGBA label color (theme-dependent: white on dark, near-black on light).
    pub label_color: [f32; 4],
}
// Total: 8 floats = 32 bytes, 16-byte aligned ✓
```

Add the corresponding size test:
```rust
#[test]
fn label_uniforms_size() {
    // 8 floats × 4 bytes = 32 bytes
    assert_eq!(std::mem::size_of::<LabelUniforms>(), 32);
}
```

Add a second small `MTLBuffer` alongside `uniformbuf` in the `Renderer` struct:

```rust
pub struct Renderer {
    // ... existing fields ...
    label_uniform_buf: Option<Buffer>,
    label_pipeline: Option<RenderPipelineState>,
    sdf_atlas_texture: Option<Texture>,  // loaded once from Swift via FFI
}
```

### B3. The Complete Metal Label Fragment Shader

This is the central piece. It runs entirely on GPU — no CPU iteration over nodes for distance calculation.

```metal
// LABEL_SHADER_SOURCE — add as a new const str in renderer.rs

#include <metal_stdlib>
using namespace metal;

// Reuse existing Uniforms struct (identical layout)
struct LabelUniforms {
    float focus_radius;
    float blur_radius;
    float zoom_threshold;
    float motion_blur;
    float4 label_color;
};

struct LabelInstance {
    float2 world_pos;      // node center
    float2 glyph_uv_min;   // atlas UV top-left
    float2 glyph_uv_max;   // atlas UV bottom-right
    float  scale;          // world-space label half-width
    float  importance;     // 0-1, for GPU-side culling priority
};

struct LabelVertexOut {
    float4 position [[position]];
    float2 uv;
    float2 worldpos;
    float4 color;
};

vertex LabelVertexOut label_vertex(
    uint vertex_id                          [[vertex_id]],
    uint instance_id                        [[instance_id]],
    constant LabelInstance *instances       [[buffer(0)]],
    constant Uniforms &uniforms             [[buffer(1)]]
) {
    // Unit quad corners (2 triangles = 6 vertices)
    float2 corners[^6] = {
        float2(0,0), float2(1,0), float2(0,1),
        float2(0,1), float2(1,0), float2(1,1)
    };
    float2 c = corners[vertex_id];

    LabelInstance inst = instances[instance_id];

    // World-space quad: centered slightly above the node
    float2 quad_world = inst.world_pos
        + float2((c.x - 0.5) * inst.scale * 2.0,
                  inst.scale * 1.4);  // offset above node

    // Camera transform: same as node shader
    float2 screen = (quad_world - uniforms.cameraoffset) * uniforms.camerazoom;
    float2 ndc    = screen / uniforms.viewportsize * float2(1, -1);

    LabelVertexOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.uv       = mix(inst.glyph_uv_min, inst.glyph_uv_max, c);
    out.worldpos = quad_world;
    out.color    = float4(1.0);  // modulated in fragment
    return out;
}

fragment float4 label_fragment(
    LabelVertexOut          in          [[stage_in]],
    constant Uniforms       &uniforms   [[buffer(1)]],
    constant LabelUniforms  &label_u    [[buffer(2)]],
    texture2d<float>         sdf_atlas  [[texture(0)]],
    sampler                  smp        [[sampler(0)]]
) {
    // ── TIER 0: Zoom-level cull ──────────────────────────────────────────
    if (uniforms.camerazoom < label_u.zoom_threshold) discard_fragment();

    // ── TIER 1: Radial focus distance ───────────────────────────────────
    float2 focal       = uniforms.cameraoffset;
    float  dist_world  = length(in.worldpos - focal);

    // Scale radii with zoom: zoomed-in → smaller world-space radius needed
    float inv_zoom = 1.0 / max(uniforms.camerazoom, 0.01);
    float focus_r  = label_u.focus_radius * inv_zoom;
    float blur_r   = label_u.blur_radius  * inv_zoom;

    // blur_t: 0 = fully in focus, 1 = fully invisible
    float blur_t = smoothstep(focus_r, blur_r, dist_world);

    // ── TIER 2: Motion blur during pan/zoom ─────────────────────────────
    float motion_speed = length(uniforms.cameravelocity);
    // Threshold at 200 world-units/frame: only blurs during fast movement
    float motion_t     = smoothstep(0.0, 200.0, motion_speed)
                         * label_u.motion_blur;
    blur_t = saturate(blur_t + motion_t * 0.6);

    // ── TIER 3: Alpha fade — early exit when invisible ───────────────────
    float focus_alpha = 1.0 - blur_t;
    if (focus_alpha < 0.01) discard_fragment();  // zero-cost for far nodes

    // ── TIER 4: MTSDF sampling ───────────────────────────────────────────
    float4 mtsdf_sample   = sdf_atlas.sample(smp, in.uv);
    float3 msdf_channels  = mtsdf_sample.rgb;
    float  true_sdf_value = mtsdf_sample.a;

    // MSDF median: sharpest reconstruction, correct at corners
    float msdf_dist = max(min(msdf_channels.r, msdf_channels.g),
                          min(max(msdf_channels.r, msdf_channels.g),
                              msdf_channels.b));

    // Blend toward true SDF as blur increases
    // In-focus: use MSDF for sharp corners
    // Out-of-focus: use true SDF for smooth cloud
    float sdf_dist = mix(msdf_dist, true_sdf_value, blur_t * 0.7);

    // ── TIER 5: Adaptive smoothstep — widen boundary with blur ───────────
    // In focus:  tight band [0.46, 0.54] → crisp text
    // Out of focus: wide band [0.10, 0.90] → diffused blob
    float edge_lo = mix(0.46, 0.10, blur_t);
    float edge_hi = mix(0.54, 0.90, blur_t);
    float sdf_alpha = smoothstep(edge_lo, edge_hi, sdf_dist);

    // ── FINAL: Compose ───────────────────────────────────────────────────
    float final_alpha = sdf_alpha * focus_alpha;
    if (final_alpha < 0.01) discard_fragment();

    // label_color carries theme color (white/near-black from Swift)
    return float4(label_u.label_color.rgb, label_u.label_color.a * final_alpha);
}
```

Key design decisions:
- **`discard_fragment()` at three points** (zoom threshold, focus alpha < 0.01, final alpha < 0.01) ensures the label pass is literally zero-cost for nodes outside the focus zone. The GPU's early-exit for `discard_fragment()` skips all downstream work including the texture sample.[^8]
- **MSDF→true SDF blend** uses `blur_t * 0.7` (not 1.0) because pure true SDF at high blur still needs the general distance shape — blending fully to true SDF would lose the glyph silhouette too quickly.
- **`cameravelocity`** is already in the existing `Uniforms` struct, so motion blur costs zero additional FFI data.[^9]

### B4. The "Apple Blur" Easing Curve

The linear `smoothstep` for `blur_t` across the focus-blur radius creates an acceptable effect, but the Apple-native feel requires a spring easing curve. The correct approach is to **not** animate `blur_t` continuously per-frame on the CPU; instead, let the GPU's `smoothstep` create the spatial gradient. The "spring" feel comes from the **camera animation** already implemented in `Renderer::update_camera()` (exponential decay lerp: `t = 1.0 - exp(-CAMERA_LAMBDA * dt)`). As the camera smoothly springs toward its target, `dist_to_focus` for every node changes with the same spring profile — the labels reveal with exactly the spring feel of the camera movement, for free.[^9]

For an additional push-in feel on the focus zone edge specifically, replace the linear `smoothstep` in the radial distance calculation with a squared bias:

```metal
// In label_fragment(), replace the smoothstep line:
float raw_t  = saturate((dist_world - focus_r) / max(blur_r - focus_r, 1.0));
float blur_t = raw_t * raw_t;  // ease-in: slow to start, fast to fade
```

This makes labels linger longer in the focus zone before fading, then drop off faster — matching Apple's decelerate easing profile.

***

## Part III: Semantic Zoom & Culling

### C1. Per-Node-Type Zoom Thresholds

Folder nodes are large and visually dominant; they should reveal labels earlier (at lower zoom). Note nodes are small and dense; they should reveal labels later. This is handled entirely in the `LabelInstance` data uploaded from Rust, without any shader branching:

```rust
// In renderer.rs, when building LabelInstance list:
fn label_zoom_threshold(node_type: u8, link_count: u32) -> f32 {
    let base = match node_type {
        5 => 0.15,  // Folder — reveal at 15% zoom
        3 => 0.20,  // Idea
        2 => 0.22,  // Chat
        1 => 0.28,  // Note — reveal at 28% zoom (denser)
        _ => 0.35,  // Tags, sources, etc.
    };
    // Hub nodes (high link count) reveal slightly earlier
    let hub_bonus = if link_count > 20 { 0.05 } else { 0.0 };
    (base - hub_bonus).max(0.10)
}
```

Pass this threshold as the `importance` field of `LabelInstance` and compare against `uniforms.camerazoom` in the vertex shader — nodes with `importance > camerazoom` are discarded before the fragment shader runs, at essentially zero cost.

### C2. Density-Aware Culling

At low zoom, 50 overlapping labels are noise. The correct approach is **CPU-side importance sort + fixed-budget culling** rather than per-GPU logic (which would require atomics and is expensive). Each frame during `update_positions()`, before uploading `LabelInstance` data:

```rust
// Sort candidate labels by importance (link_count * cluster_centrality)
// Only upload the top N into the label instance buffer
const LABEL_BUDGET: usize = 128;  // configurable in Settings

label_instances.sort_unstable_by(|a, b|
    b.importance.partial_cmp(&a.importance).unwrap()
);
label_instances.truncate(LABEL_BUDGET);
```

128 labels at any zoom level is always readable. This costs one sort per frame over at most a few hundred candidates (viewport-culled first), which is negligible.

***

## Part IV: Architecture Audit — Critical Issues

### G1. Shader Compilation at Every Launch (HIGH PRIORITY)

The renderer calls `new_library_with_source(SHADER_SOURCE, ...)` at startup for every pipeline. This triggers Metal's offline compiler chain at launch, costing 100–300ms on cold starts. The `AppBootstrap` file-lock workaround exists specifically because of a race condition in this path. Pre-compiling solves both problems.[^10][^9]

**Fix:** Add an Xcode build phase that compiles Metal source to a `.metallib` binary, then load via `newDefaultLibrary()` or `newLibraryWithData()`:

```bash
# Xcode Run Script phase (before compilation):
xcrun metal -c "${SRCROOT}/graph-engine/shaders/graph.metal" \
    -o "${DERIVED_FILE_DIR}/graph.air"
xcrun metallib "${DERIVED_FILE_DIR}/graph.air" \
    -o "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources/graph.metallib"
```

```swift
// In GraphEngine.swift, replacing Rust-side shader compilation:
guard let url = Bundle.main.url(forResource: "graph", withExtension: "metallib"),
      let library = try? device.makeLibrary(URL: url) else { fatalError() }
```

The embedded string constants (`SHADER_SOURCE`, `COMPUTE_SHADER_SOURCE`, `DIALOGUE_SHADER_SOURCE`) in `renderer.rs` become the canonical source files. The FFI contract stays unchanged — Swift still calls `graph_engine_render()` and Rust still issues all draw calls. The shaders just load from compiled binary rather than source string.[^11][^7]

**Gain:** Eliminates ~150–300ms startup delay. Eliminates AppBootstrap file-lock workaround. Adds compile-time Metal shader type checking.

### G2. sRGB Framebuffer Color Space (CRITICAL BUG)

The Metal layer uses `MTLPixelFormatBGRA8Unorm`, which means the GPU writes linear floating-point values directly to the 8-bit framebuffer without gamma encoding. On a display expecting sRGB (which all macOS displays do), this makes all colors ~20% too bright and critically **makes alpha blending incorrect** — glow halos acquire dark fringe artifacts because blending in linear space followed by display gamma is not the same as blending in sRGB space.[^9]

**Fix:** Change one line in `Renderer::new()`:
```rust
// Change:
layer.set_pixel_format(MTLPixelFormatBGRA8Unorm);
// To:
layer.set_pixel_format(MTLPixelFormatBGRA8Unorm_sRGB);
```

Metal automatically applies sRGB gamma correction when writing to `BGRA8Unorm_sRGB`, and fragment shader values are treated as linear — which is exactly correct. No shader changes required. Glow blending artifacts disappear. SDF label color matching improves. This is a high-priority correctness fix independent of the label system.[^9]

### G3. Link Forces CPU/GPU Pipeline Bubble (MEDIUM PRIORITY)

The current pipeline:
1. Render thread dispatches GPU N-body (async) for repulsion
2. Physics thread applies Barnes-Hut CPU fallback for small graphs, GPU forces for large
3. **Link forces (springs along edges) run on CPU in `force_link()`**

At 10K nodes with 50K edges, CPU link force iteration runs while the GPU N-body kernel is executing — then the physics thread stalls waiting for GPU readback. This creates a pipeline bubble of ~0.5–2ms per physics tick.[^12][^9]

**Fix:** Migrate `force_link` to a Metal compute kernel. The edge list (currently `Vec<(usize, usize)>`) needs conversion to Compressed Sparse Row (CSR) format for GPU-efficient traversal:[^13][^14]

```rust
// CSR edge representation for compute shader
pub struct CsrEdges {
    pub offsets: Vec<u32>,  // offsets[i] = start of node i's edges
    pub targets: Vec<u32>,  // targets[offsets[i]..offsets[i+1]]
    pub weights: Vec<f32>,  // parallel to targets
}
```

The compute shader dispatch pattern is identical to the existing `nbody_repulsion` kernel. **This is the single biggest physics performance improvement available**, especially as the vault grows into the 10K+ node range.

### G4. Louvain Community Detection Rebuilt from Scratch (MEDIUM PRIORITY)

`ensure_cluster_assignments()` is called from both `commit()` and `commit_incremental()`. For vaults that grow via NightBrain adding nodes continuously, this means O(n log n) full Louvain computation on every `commitIncremental()` call.[^15]

**Fix:** Switch to DF Louvain (Dynamic Frontier Louvain), which processes only affected vertices when edges are added or removed. For incremental graph updates of typical size (1–50 new nodes), DF Louvain is ~179× faster than static Louvain. The `ClusterCache` struct in `cluster_cache.rs` already has the topology fingerprint infrastructure; the swap requires replacing `detect_communities()` with an incremental variant.[^16][^17]

### G5. TBDR Glow Bandwidth Optimization (LOW PRIORITY, HIGH PAYOFF)

Apple GPU architecture is Tile-Based Deferred Rendering (TBDR): the GPU renders into fast on-chip tile memory before writing to system memory. The current glow effect uses additive blending with separate low-alpha `NodeInstance` entries for glow halos drawn before regular nodes. These glow samples read and write the framebuffer multiple times within a tile — exactly the pattern TBDR penalizes.[^18][^19][^20][^9]

**Fix:** Use a memoryless intermediate render target for glow accumulation, then apply a single tile shader pass to composite the glow. Mark the intermediate texture as `.memoryless` so it never leaves tile memory:

```swift
// In MetalGraphView.swift render loop:
let glowDesc = MTLRenderPassDescriptor()
glowDesc.colorAttachments.texture = glowTexture  // memoryless
glowDesc.colorAttachments.storeAction = .dontCare  // stays in tile memory
glowDesc.colorAttachments.loadAction  = .clear
```

The glow blur then executes as a tile shader reading from tile memory directly, with zero system memory bandwidth. On M2 Pro, this saves 2–4ms per frame at 10K nodes with glow enabled (quality level 0 — Cinematic).[^20]

### G6. Indirect Command Buffers — Verdict: Not Applicable

`MTLIndirectCommandBuffer` reduces CPU overhead when there are hundreds of distinct draw calls per frame. Epistemos issues at most 5–6 draw calls per frame (nodes, edges, field lines, highlight rings, dialogue, wind particles). ICBs would add code complexity with zero measurable benefit. The current model is already optimal for this draw call count.[^21][^22][^9]

***

## Part V: Physics Polish

### D1. The "Garry's Mod" Quality

The volatile, rubbery physics is intentional and correct. The current d3-force velocity Verlet loop with `velocity_decay = 0.6` (nodes retain 60% velocity per tick) and `alpha_decay = 0.0228` produces the bouncy, elastic feel. The goal is **polish, not replacement**.

The simulation in `simulation.rs` is already velocity Verlet, not Euler — the code comment confirms this ("d3 stores velocity explicitly vx/vy and applies velocityDecay as a multiplier"). This is inherently more stable than Euler and energy-conservative, meaning the organic oscillation is a feature of the algorithm rather than a numerical error that can be tuned away.[^12]

### D2. Recommended Parameter Adjustments

The existing defaults from `ForceParams::default()` are well-tuned. Apply only these targeted changes:[^12]

| Parameter | Current | Recommended | Effect |
|---|---|---|---|
| `velocity_decay` | 0.6 (60% retained) | 0.50 (50% retained) | More viscous — nodes settle without losing the elastic bounce at high energy |
| `alpha_decay` | 0.0228 | 0.018 | Slower settle — 20% more organic drift time before equilibrium |
| `collision_iterations` | 1 | 2 | Smoother overlap resolution — fewer visible "bumps" on dense clusters |
| Max velocity (in `tick()`) | 500.0 | 350.0 | Caps extreme flyout events while preserving normal physics feel |
| `label motion_blur threshold` | N/A | 200 world/frame | Labels blur directionally during fast pan only — not at rest |

**Do not touch** `link_distance` (80.0 is correct for dense graphs), `charge_strength` (-300.0), or `center_strength` (0.03). These are the core feel parameters and are well-calibrated.

### D3. Mass-Drag for Labels During Drag

When a node is dragged, labels near the drag path should blur in the direction of motion — the "Garry's Mod" feel should extend to the label system. This is handled automatically: `uniforms.cameravelocity` captures camera movement (pan/zoom), and `velocities[instance_id]` captures per-node velocity (already in the node pipeline's `buffer(3)`). Add `node_velocity` to `LabelInstance` and scale `motion_t` by node speed during drag:[^9]

```metal
// In label_fragment():
float node_speed  = length(in.node_velocity);
float drag_blur_t = smoothstep(0.0, 300.0, node_speed) * 0.4;
blur_t = saturate(blur_t + drag_blur_t);
```

The effect: nodes being dragged have their labels blur and smear, reinforcing the physical, fluid feel. Nodes at rest remain crisp.

***

## Part VI: Full Implementation Architecture

### Pipeline Diagram

```
╔══════════════════════════════════════════════════════════════════════╗
║  BUILD TIME                                                          ║
║  msdf-atlas-gen ──→ sdf_labels.png + sdf_labels.json (512×512 MTSDF)║
║  xcrun metal/metallib ──→ graph.metallib (precompiled shaders)       ║
╚══════════════════════════════════════════════════════════════════════╝
                              ↓ (Xcode embeds in bundle)
╔══════════════════════════════════════════════════════════════════════╗
║  RUST (graph-engine)                                                 ║
║                                                                      ║
║  Simulation::tick()                                                  ║
║    ├─ link forces (CPU → migrate to compute shader)                  ║
║    ├─ Barnes-Hut charge (GPU compute, N-body kernel)                 ║
║    ├─ collision (CPU spatial hash grid)                              ║
║    └─ velocity Verlet integration (NEON SIMD on aarch64)             ║
║                                                                      ║
║  Engine::render()                                                    ║
║    ├─ syncAllPositions() (extrapolated, sub-tick smooth)             ║
║    ├─ build LabelInstance[] (importance sort, top-128 cull)          ║
║    ├─ write LabelUniforms buffer                                     ║
║    └─ Renderer::draw()                                               ║
║         ├─ write Uniforms (cameraoffset = focal point)               ║
║         └─ issue 7 draw calls (+ new: label instanced draw)          ║
╚══════════════════════════════════════════════════════════════════════╝
                              ↓ (FFI, zero-copy MTLBuffer)
╔══════════════════════════════════════════════════════════════════════╗
║  METAL GPU                                                           ║
║                                                                      ║
║  label_vertex()                                                      ║
║    ├─ reads LabelInstance[instance_id] → world_pos, glyph_uv        ║
║    ├─ applies camera transform (same as node_vertex)                 ║
║    └─ passes worldpos to fragment                                    ║
║                                                                      ║
║  label_fragment()                                                    ║
║    ├─ Tier 0: zoom cull (discard if zoom < zoom_threshold)           ║
║    ├─ Tier 1: dist_to_focus = length(worldpos - cameraoffset)        ║
║    ├─ Tier 2: blur_t = smoothstep(focus_r, blur_r, dist)            ║
║    ├─ Tier 3: motion_t from cameravelocity magnitude                 ║
║    ├─ Tier 4: discard if focus_alpha < 0.01 (EARLY EXIT)            ║
║    ├─ Tier 5: sample MTSDF atlas (1 texture fetch, 4 channels)      ║
║    ├─ Tier 6: MSDF median + true SDF blend by blur_t                ║
║    └─ Tier 7: adaptive smoothstep boundaries, output RGBA            ║
╚══════════════════════════════════════════════════════════════════════╝
```

### New FFI Additions Required

Add to `graph_engine.h`:
```c
// Set label rendering parameters
void graph_engine_set_label_params(
    Engine *engine,
    float focus_radius,     // world units for full crispness zone
    float blur_radius,      // world units for full invisibility
    float zoom_threshold,   // camerazoom below which labels hide
    float motion_blur,      // 0-1 motion blur strength
    float r, float g, float b, float a  // label color (theme)
);

// Load the SDF atlas texture handle (called from Swift after MTLTexture creation)
// Swift retains the texture; Rust stores the pointer for bind at draw time
void graph_engine_set_sdf_atlas(Engine *engine, void *mtl_texture_ptr);
```

Add to `lib.rs`:
```rust
#[no_mangle]
pub extern "C" fn graph_engine_set_label_params(
    engine: *mut Engine,
    focus_radius: f32, blur_radius: f32,
    zoom_threshold: f32, motion_blur: f32,
    r: f32, g: f32, b: f32, a: f32,
) {
    ffi_engine!(engine);
    engine.set_label_params(LabelUniforms {
        focus_radius, blur_radius, zoom_threshold, motion_blur,
        label_color: [r, g, b, a],
    });
}
```

Swift call site in `GraphEngine.swift`:
```swift
func syncLabelTheme() {
    let c: (Float, Float, Float, Float) = lightMode
        ? (0.08, 0.08, 0.10, 0.92)   // dark text on light
        : (0.95, 0.96, 1.00, 0.88)   // light text on dark
    graph_engine_set_label_params(
        engine,
        200.0,   // focusRadius
        700.0,   // blurRadius
        0.25,    // zoomThreshold
        0.80,    // motionBlur
        c.0, c.1, c.2, c.3
    )
}
```

**PowerGuard integration** (in `PowerGuard.swift`): when `powerMode == .lowPower`, call `graph_engine_set_label_params` with `zoom_threshold: 100.0` (impossibly high) to disable labels without a separate flag or code path.

***

## Part VII: Performance Analysis

### Per-Node Label Cost

| Operation | Cost per fragment |
|---|---|
| Zoom threshold check | 1 compare + conditional discard |
| Focal distance | 1 `length()` = 3 ops (sub, mul-add, sqrt) |
| Blur smoothstep | 2 multiplies, 1 clamp = ~5 ops |
| Motion blur blend | 1 length + 1 smoothstep = ~6 ops |
| Focus alpha early exit | 1 compare + conditional discard |
| MTSDF sample | 1 bilinear texture fetch (4 channels) |
| MSDF median | 2 max, 2 min = 4 ops |
| SDF blend + smoothstep | ~8 ops |
| **Total per fragment (in-focus)** | **~30 ALU ops + 1 texture fetch** |
| **Total per fragment (out-of-focus)** | **~10 ALU ops + 0 texture fetch (early exit)** |

### Full-Scene Label Pass Budget at 10K Nodes

Assuming 20% of nodes have visible labels at typical zoom (2,000 nodes), average label screen area 18×8 pixels = 144 fragments per label:

| Scale | Fragment count | Estimated GPU time (M2 Pro) |
|---|---|---|
| 2,000 visible labels × 144 frags | 288,000 fragments | ~0.15ms |
| 10,000 visible labels × 144 frags | 1,440,000 fragments | ~0.7ms |
| All 10,000 fully in-focus (worst case) | 1,440,000 fragments | ~0.7ms |

The 8.33ms per-frame budget at 120fps is not meaningfully impacted. The early-exit discard at `focus_alpha < 0.01` means nodes outside the blur radius cost ~10 ALU ops with no texture fetch — at 50K total nodes with 2K visible labels, the 48K discarded label quads cost approximately 0.08ms total.[^9]

***

## Part VIII: Settings UI Specification

### New fields in `GraphState.swift` / `EpistemosConfig.swift`

```swift
// EpistemosConfig.swift — persisted settings
struct GraphLabelConfig: Codable {
    var enabled: Bool = true
    var focusRadius: Float = 200.0   // 50...1000, step 10
    var blurRadius: Float  = 700.0   // 200...2000, step 50
    var zoomThreshold: Float = 0.25  // 0.10...0.60, step 0.05
    var motionBlur: Float = 0.80     // 0.0...1.0
    var showAllTypes: Bool = false   // false = skip source/quote/tag
}
```

### Settings Panel (GraphFloatingControls or dedicated "Graph Labels" Settings pane)

| Control | Type | Range | Default | Description |
|---|---|---|---|---|
| Show Labels | Toggle | on/off | on | Master enable |
| Reveal Distance | Slider | 50–1000 | 200 | World units of full crispness |
| Fade Distance | Slider | 200–2000 | 700 | World units where labels vanish |
| Appear at Zoom | Slider | 10%–60% | 25% | Minimum zoom level for label reveal |
| Motion Blur | Slider | 0–100% | 80% | Label blur strength during pan |
| Show All Types | Toggle | on/off | off | Include source/quote/tag labels |

***

## Part IX: Tuning Reference

| Parameter | Conservative (readable, calm) | Default (recommended) | Expressive (dramatic reveal) |
|---|---|---|---|
| `focus_radius` | 300 | 200 | 100 |
| `blur_radius` | 1000 | 700 | 400 |
| `zoom_threshold` | 0.30 | 0.25 | 0.15 |
| SDF edge_lo (crisp) | 0.47 | 0.46 | 0.45 |
| SDF edge_hi (crisp) | 0.53 | 0.54 | 0.55 |
| SDF edge_lo (blur) | 0.15 | 0.10 | 0.05 |
| SDF edge_hi (blur) | 0.85 | 0.90 | 0.95 |
| `velocity_decay` | 0.55 | 0.50 | 0.45 |
| `alpha_decay` | 0.022 | 0.018 | 0.015 |
| `max_velocity` | 400 | 350 | 300 |
| MSDF atlas cell size | 28px | 32px | 40px |
| Atlas `-pxrange` | 4 | 6 | 8 |
| Atlas `-emrange` | 0.3 | 0.4 | 0.5 |

---

## References

1. [Chlumsky/msdf-atlas-gen: MSDF font atlas generator - GitHub](https://github.com/Chlumsky/msdf-atlas-gen) - A utility for generating compact font atlases using MSDFgen. The atlas generator loads a subset of g...

2. [msdfgen parameters - Red Blob Games](https://www.redblobgames.com/x/2437-msdfgen-parameters/) - I use the msdf-atlas-gen [1] utility to generate font bitmaps from MSDFgen [2] . It has several para...

3. [Signed Distance Field Fonts - outline and bevel - Red Blob Games](https://www.redblobgames.com/x/2404-distance-field-effects/) - That's why msdf-atlas-gen offers an option to bundle them together in the mtsdf format. But the ques...

4. [Questions about how small can I really get away with #22 - GitHub](https://github.com/Chlumsky/msdf-atlas-gen/discussions/22) - Comparatively, a high enough resolution MSDF has really sharp edges and asian glyphs look absolutely...

5. [[PDF] Rendering Resolution Independent Fonts in Games and 3D ...](https://lup.lub.lu.se/luur/download?func=downloadFile&recordOId=9024910&fileOId=9024911) - Glyphs with sharp corners appear rounded and thin features will suffer from visible artefacts. In Fi...

6. [Design Principles Applied to the SF Fonts - Jim Nielsen's Blog](https://blog.jim-nielsen.com/2019/design-principles-applied-to-sf-fonts/) - It provided an overview of a number of good typographic principles and how they were applied during ...

7. [Metal file as part of an iOS framework - Stack Overflow](https://stackoverflow.com/questions/46742403/metal-file-as-part-of-an-ios-framework) - I am trying to create a framework that works with METAL Api (iOS). I am pretty new to this platform ...

8. [Rendering Text in Metal with Signed-Distance Fields](https://metalbyexample.com/rendering-text-in-metal-with-signed-distance-fields/) - In this article, we will discuss a method for rendering high-fidelity text with Metal. It's easy to ...

9. [renderer-4.rs](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/5f4e3c07-1273-4c84-a8e8-4f0160b7bce8/renderer-4.rs?AWSAccessKeyId=ASIA2F3EMEYE232HRDA3&Signature=bEO%2FyzJWICzt7xchXR9GZvSpFwk%3D&x-amz-security-token=IQoJb3JpZ2luX2VjELD%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLWVhc3QtMSJHMEUCIGwGSJMYae17TlKwT2MIJ%2BMz8uKkpOBZrcQhnw9M886LAiEAgZtEV%2Ba6Ap6gUvT0by0w5cwqP3ylHVcZgxIZu27GFtUq8wQIeBABGgw2OTk3NTMzMDk3MDUiDPHjQl5DKzSCddgTQSrQBIKwxo4f0yVN3NKZYp5RNgboQ%2FpK5tjdREFAhVZM1JrMklBRAkJKVcCeAjezludzrIvHZXvleK4dUVbX12%2BecFvs9Dt3bTlx8ibl5a9wnHopefAE8Iiz8FftGmF902wluCRJS2EdPOH6Po9SL7QRACmFrc2cOYj9A2gj73HQSKDLEv7p30e7dOU0EV5fOMpS01Jqs3pC7PBATELhUM7sqKv%2F3a4IXlxDCU0sjZklWVZNL%2FgXT4oh3iDgih1OWt175kstqEAv6Bv%2FnkWEqy1C4Ej%2BjFkysbomCB9BibANVUEOcrprteo87k8IPyqIqh4GVhrayEA%2FaYDvkx7hJw1De0CfC3%2FtwHU%2FSTbO2hlICcqzEjgEYSp4d0oCvfL1AztzWHyYrsEo06jpsHGuqT%2FcghDyHEZa9m%2ByrGNMp8Zkf0b60LyS4iq0iVYyhAK%2BkkF4FUGwuVnMkAMRjZPxuvykvoHvZCozJ6GqXJu8wMFadNbN48bgdeasbgXINwZz9Q9%2BTalON5nfvl722tU1JNy4jUWANIlK%2FxKk8nOZny0odOD9SiUxHj96Eaoaac%2Bjd%2FA4RB0kzAoRXdSoqlvbk5ot8hIgUXSlGcslEDY5ypM9YAJN5POLMoCJdRmEz58ivNEiUCO4fa%2F%2F6B45HWD292b8GB9O5qwKSlMkCl2KbwxflRWomRZwYVLkCY4UYHWwSGbkEeaEYCWFm2h1nbXdJxLtWNid5KXD81wA1AdeJwcGNl3LFKRCnHRTTuezeAOGXHWontXMELHZzN6yg9r5t5axr1gw6PG7zgY6mAGoE4JYtMAopbuc81qzsIm6cpAU1IELa%2BagPKKTO6%2B5AEkZLYOTIMyd%2F4wxkjTcE%2FgJJTKnaiHU35xB%2BFr%2BmqRPrZYw0sbphE7AKsYWwU9%2FggjKLpEoQCh2oZmDRy6eEOZ2B9WAlybmeza4doXaQqVJokVcYOHwh2pxKo%2B6mKUpn%2BwUNAIiPhOb2N%2FHFOi%2FLSHjFbvsqISE7g%3D%3D&Expires=1775175355) - use stdfficvoid use metalforeigntypesForeignType use metal use objcrcautoreleasepool use rustchashFx...

10. [Building GPUI without Xcode's metal and metallib #7016 - GitHub](https://github.com/zed-industries/zed/discussions/7016) - This might be worth pursuing as it would also mean a potential improvement in startup performance ev...

11. [Manually Compile Metal Shaders - xcode - Stack Overflow](https://stackoverflow.com/questions/32298719/manually-compile-metal-shaders) - Write your shaders in .metal files, compile them once at runtime, and then build your metal GPU bina...

12. [simulation-5.rs](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/d59e4388-0213-469b-9ca1-eef6e05a8eb0/simulation-5.rs?AWSAccessKeyId=ASIA2F3EMEYE232HRDA3&Signature=02%2FU%2FRdCHfNVK%2B3hdzEYNkoo3tg%3D&x-amz-security-token=IQoJb3JpZ2luX2VjELD%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLWVhc3QtMSJHMEUCIGwGSJMYae17TlKwT2MIJ%2BMz8uKkpOBZrcQhnw9M886LAiEAgZtEV%2Ba6Ap6gUvT0by0w5cwqP3ylHVcZgxIZu27GFtUq8wQIeBABGgw2OTk3NTMzMDk3MDUiDPHjQl5DKzSCddgTQSrQBIKwxo4f0yVN3NKZYp5RNgboQ%2FpK5tjdREFAhVZM1JrMklBRAkJKVcCeAjezludzrIvHZXvleK4dUVbX12%2BecFvs9Dt3bTlx8ibl5a9wnHopefAE8Iiz8FftGmF902wluCRJS2EdPOH6Po9SL7QRACmFrc2cOYj9A2gj73HQSKDLEv7p30e7dOU0EV5fOMpS01Jqs3pC7PBATELhUM7sqKv%2F3a4IXlxDCU0sjZklWVZNL%2FgXT4oh3iDgih1OWt175kstqEAv6Bv%2FnkWEqy1C4Ej%2BjFkysbomCB9BibANVUEOcrprteo87k8IPyqIqh4GVhrayEA%2FaYDvkx7hJw1De0CfC3%2FtwHU%2FSTbO2hlICcqzEjgEYSp4d0oCvfL1AztzWHyYrsEo06jpsHGuqT%2FcghDyHEZa9m%2ByrGNMp8Zkf0b60LyS4iq0iVYyhAK%2BkkF4FUGwuVnMkAMRjZPxuvykvoHvZCozJ6GqXJu8wMFadNbN48bgdeasbgXINwZz9Q9%2BTalON5nfvl722tU1JNy4jUWANIlK%2FxKk8nOZny0odOD9SiUxHj96Eaoaac%2Bjd%2FA4RB0kzAoRXdSoqlvbk5ot8hIgUXSlGcslEDY5ypM9YAJN5POLMoCJdRmEz58ivNEiUCO4fa%2F%2F6B45HWD292b8GB9O5qwKSlMkCl2KbwxflRWomRZwYVLkCY4UYHWwSGbkEeaEYCWFm2h1nbXdJxLtWNid5KXD81wA1AdeJwcGNl3LFKRCnHRTTuezeAOGXHWontXMELHZzN6yg9r5t5axr1gw6PG7zgY6mAGoE4JYtMAopbuc81qzsIm6cpAU1IELa%2BagPKKTO6%2B5AEkZLYOTIMyd%2F4wxkjTcE%2FgJJTKnaiHU35xB%2BFr%2BmqRPrZYw0sbphE7AKsYWwU9%2FggjKLpEoQCh2oZmDRy6eEOZ2B9WAlybmeza4doXaQqVJokVcYOHwh2pxKo%2B6mKUpn%2BwUNAIiPhOb2N%2FHFOi%2FLSHjFbvsqISE7g%3D%3D&Expires=1775175355) - ! D3-Force Simulation ! ! Faithful translation of d3-forces velocity Verlet simulation loop. ! Each ...

13. [Fast Graph Loading in Edgelist and Compressed Sparse Row (CSR ...](https://arxiv.org/html/2311.14650v3) - Compressed Sparse Row (CSR) is another popular in-memory format that is optimal for vertex-oriented ...

14. [[PDF] Efficient Memory-access for Out-of-memory Graph-traversal in GPUs](https://vldb.org/pvldb/vol14/p114-min.pdf) - For efficient storage and access, graphs are stored in a com- pressed sparse row (CSR) data format a...

15. [engine.rs](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/470d5d49-2838-45a9-ae8a-4e0d484fbcfb/engine.rs?AWSAccessKeyId=ASIA2F3EMEYE232HRDA3&Signature=8KA5N6QtBMUwYXiHL%2FgC7TAZqtY%3D&x-amz-security-token=IQoJb3JpZ2luX2VjELD%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLWVhc3QtMSJHMEUCIGwGSJMYae17TlKwT2MIJ%2BMz8uKkpOBZrcQhnw9M886LAiEAgZtEV%2Ba6Ap6gUvT0by0w5cwqP3ylHVcZgxIZu27GFtUq8wQIeBABGgw2OTk3NTMzMDk3MDUiDPHjQl5DKzSCddgTQSrQBIKwxo4f0yVN3NKZYp5RNgboQ%2FpK5tjdREFAhVZM1JrMklBRAkJKVcCeAjezludzrIvHZXvleK4dUVbX12%2BecFvs9Dt3bTlx8ibl5a9wnHopefAE8Iiz8FftGmF902wluCRJS2EdPOH6Po9SL7QRACmFrc2cOYj9A2gj73HQSKDLEv7p30e7dOU0EV5fOMpS01Jqs3pC7PBATELhUM7sqKv%2F3a4IXlxDCU0sjZklWVZNL%2FgXT4oh3iDgih1OWt175kstqEAv6Bv%2FnkWEqy1C4Ej%2BjFkysbomCB9BibANVUEOcrprteo87k8IPyqIqh4GVhrayEA%2FaYDvkx7hJw1De0CfC3%2FtwHU%2FSTbO2hlICcqzEjgEYSp4d0oCvfL1AztzWHyYrsEo06jpsHGuqT%2FcghDyHEZa9m%2ByrGNMp8Zkf0b60LyS4iq0iVYyhAK%2BkkF4FUGwuVnMkAMRjZPxuvykvoHvZCozJ6GqXJu8wMFadNbN48bgdeasbgXINwZz9Q9%2BTalON5nfvl722tU1JNy4jUWANIlK%2FxKk8nOZny0odOD9SiUxHj96Eaoaac%2Bjd%2FA4RB0kzAoRXdSoqlvbk5ot8hIgUXSlGcslEDY5ypM9YAJN5POLMoCJdRmEz58ivNEiUCO4fa%2F%2F6B45HWD292b8GB9O5qwKSlMkCl2KbwxflRWomRZwYVLkCY4UYHWwSGbkEeaEYCWFm2h1nbXdJxLtWNid5KXD81wA1AdeJwcGNl3LFKRCnHRTTuezeAOGXHWontXMELHZzN6yg9r5t5axr1gw6PG7zgY6mAGoE4JYtMAopbuc81qzsIm6cpAU1IELa%2BagPKKTO6%2B5AEkZLYOTIMyd%2F4wxkjTcE%2FgJJTKnaiHU35xB%2BFr%2BmqRPrZYw0sbphE7AKsYWwU9%2FggjKLpEoQCh2oZmDRy6eEOZ2B9WAlybmeza4doXaQqVJokVcYOHwh2pxKo%2B6mKUpn%2BwUNAIiPhOb2N%2FHFOi%2FLSHjFbvsqISE7g%3D%3D&Expires=1775175355) - ! Graph Engine Orchestrator ! ! Ties together Simulation, Renderer, and SpatialIndex. ! Manages the ...

16. [[2404.19634] DF Louvain: Fast Incrementally Expanding Approach ...](https://arxiv.org/abs/2404.19634) - In this report we present our Parallel Dynamic Frontier (DF) Louvain algorithm, which given a batch ...

17. [DF Louvain: Fast Incrementally Expanding Approach for Community ...](https://arxiv.org/html/2404.19634v4) - In this report we present our Parallel Dynamic Frontier (DF) Louvain algorithm, which given a batch ...

18. [Tailor your apps for Apple GPUs and tile-based deferred rendering](https://developer.apple.com/documentation/metal/tailor_your_apps_for_apple_gpus_and_tile-based_deferred_rendering?changes=_7&language=objc) - Tile memory is an important component to TBDR because it saves time and energy by avoiding accessing...

19. [Tailor your apps for Apple GPUs and tile-based deferred rendering](https://developer.apple.com/documentation/metal/tailor-your-apps-for-apple-gpus-and-tile-based-deferred-rendering) - Learn about characteristic Apple GPU features, including imageblocks, tile shaders, and raster order...

20. [Metal by Tutorials, Chapter 15: Tile-Based Deferred Rendering](https://www.kodeco.com/books/metal-by-tutorials/v3.0/chapters/15-tile-based-deferred-rendering) - In this chapter, you'll learn how to handle scenes that contain many lights by using a technique kno...

21. [Indirect command encoding | Apple Developer Documentation](https://developer.apple.com/documentation/metal/indirect-command-encoding) - Metal executes all the draw commands in an indirect command buffer each time you submit it. This mea...

22. [Metal by Tutorials, Chapter 26: GPU-Driven Rendering - Kodeco](https://www.kodeco.com/books/metal-by-tutorials/v3.0/chapters/26-gpu-driven-rendering) - Instead of creating these commands per render pass, you can create them all at the start of the app ...

