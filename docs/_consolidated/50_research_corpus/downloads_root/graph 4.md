<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# \# Graph SDF Label System — Deep Research Prompt

## Continuous Distance-Based Blur Reveal + Kinetic Physics Polish

**Purpose:** Research and engineer the optimal implementation of SDF text labels with continuous radial blur reveal, kinetic physics polish, and semantic zoom for the Epistemos Metal graph renderer.

---

## CONTEXT

Epistemos has a Metal GPU-rendered knowledge graph (Rust physics engine + Metal shaders) running at 120fps with tens of thousands of nodes. Currently nodes have NO text labels — they're just colored circles/shapes. The plan:

1. Add SDF (Signed Distance Field) text labels that blur-reveal as you zoom in
2. Labels are distance-based: only nodes near the camera focal point are crisp, others blur away
3. As you pan, labels continuously reveal/blur based on proximity — not a toggle, a gradient
4. The "Apple blur" aesthetic: text morphs from a diffused cloud into sharp typography
5. The existing volatile/viscous "Garry's Mod" physics should be preserved and polished

---

## FILES TO READ (20 files — the complete graph + rendering stack)

### Rust Physics Engine

1. `graph-engine/src/engine.rs` — main engine: force simulation, N-body, commit, render dispatch
2. `graph-engine/src/simulation.rs` — force-directed layout: springs, charge repulsion, velocity decay, Barnes-Hut
3. `graph-engine/src/forces.rs` — individual force implementations: link, charge, center, collision, semantic boids
4. `graph-engine/src/renderer.rs` — Metal shader compilation, pipeline creation, draw calls, uniforms
5. `graph-engine/src/lib.rs` — FFI exports: all `#[no_mangle] pub extern "C"` functions Swift calls

### Rust Graph Data

6. `graph-engine/src/knowledge_core/ring.rs` — zero-copy shared memory ring buffer (128-byte cache lines)
7. `graph-engine/src/knowledge_core/mod.rs` — knowledge core module (subscription, query, diff)

### Metal Shaders (embedded in Rust as string constants)

8. `graph-engine/src/renderer.rs` (lines containing `SHADER_SOURCE`, `COMPUTE_SHADER_SOURCE`, `DIALOGUE_SHADER_SOURCE`) — the actual Metal Shading Language code

### Swift Graph Layer

9. `Epistemos/Views/Graph/MetalGraphView.swift` — NSView subclass, display link, render loop, frame skip, physics push
10. `Epistemos/Views/Graph/HologramOverlay.swift` — hologram overlay controller, glass effects
11. `Epistemos/Graph/GraphEngine.swift` — Swift wrapper around Rust FFI (addNode, setForceParams, render)
12. `Epistemos/Graph/GraphState.swift` — observable state: force params, quality level, visual theme, performance mode
13. `Epistemos/Graph/GraphBuilder.swift` — builds graph from vault data (nodes, edges, types)
14. `Epistemos/Graph/EmbeddingService.swift` — pushes semantic embeddings to Rust for clustering

### Swift Graph UI

15. `Epistemos/Views/Graph/GraphFloatingControls.swift` — overlay controls for graph interaction
16. `Epistemos/Views/Graph/HologramController.swift` — hologram window management

### Bridge

17. `graph-engine-bridge/graph_engine.h` — C header for all FFI functions (the contract between Rust and Swift)

### State Management

18. `Epistemos/State/PowerGuard.swift` — power mode affects graph quality and physics dampening
19. `Epistemos/State/EpistemosConfig.swift` — feature flags and settings

### Reference

20. `docs/VISION_BACKLOG.md` — sections 3-PRIME, 3-SHADOW, 3-GRAPH, 3-PHYSICS, 3A, 3B, 3C for full graph vision

---

## RESEARCH OBJECTIVES

### A. SDF Text Rendering in Metal

**The core technique:** Instead of rasterized font textures, use Signed Distance Fields where each pixel stores the distance to the nearest font edge. This allows the fragment shader to control sharpness mathematically.

Research and provide:

1. **SDF atlas generation:** Best tool for generating MSDF (Multi-channel SDF) font atlases for Metal. Evaluate: msdfgen, msdf-atlas-gen, slug (commercial). Output format must be compatible with MTLTexture.
2. **Font choice:** `NSFont.monospacedSystemFont` or SF Pro — which renders better as SDF? Considerations for Apple Silicon texture sampling.
3. **Atlas packing:** How to pack 95+ ASCII glyphs + common Unicode into a single texture atlas with metadata (glyph bounds, UV coordinates, advance widths).
4. **Integration path:** The SDF atlas is a build-time artifact (generated once, shipped with app) or runtime-generated?

### B. The Radial Focus Field (Continuous Blur Reveal)

**The effect:** As you zoom in or pan, labels near the camera focal point sharpen continuously. Labels far from focus blur and fade. It's not a toggle — it's a smooth gradient driven by distance.

Research and provide:

1. **Camera focal point:** How to extract the world-space coordinate the user is looking at from the current camera transform (zoom + pan state in `engine.rs`).
2. **Distance calculation:** Must happen in the GPU (fragment shader), NOT CPU. Each node's vertex shader passes `world_position` to the fragment shader. The fragment shader computes `distance(world_position, camera_focus)`.
3. **Blur mapping:** `blur_intensity = smoothstep(focus_radius, blur_radius, dist_to_focus)`. The `focus_radius` and `blur_radius` scale with zoom level.
4. **SDF boundary manipulation:** Widen the `smoothstep` edge boundaries as blur increases:
    - In focus: `smoothstep(0.45, 0.55, sdf_distance)` → crisp text
    - Out of focus: `smoothstep(0.1, 0.9, sdf_distance)` → diffused blob
    - Fully out: alpha → 0 (invisible)
5. **Performance:** This must be zero-cost when labels are invisible (early exit). Benchmark: adding labels to 10K nodes must not drop fps by >5%.

### C. Semantic Zoom Thresholds

Research and provide:

1. **When labels appear:** At what zoom level should labels start revealing? Should it be configurable via a slider in Settings?
2. **Per-node-type thresholds:** Folder nodes (large) should reveal labels earlier than leaf notes (small). How to pass per-node threshold to the shader?
3. **Density-aware culling:** If 50 labels would overlap at current zoom, only show the N most important. How to implement importance-based culling on GPU?

### D. Kinetic Physics Polish

The current physics feel "Garry's Mod rubbery." This is intentional and should be preserved but polished.

Research and provide:

1. **Spring constant tuning:** What values for Hooke's law spring stiffness + dampening create a "viscous but settling" feel vs "bouncy and chaotic"?
2. **Velocity clamping:** Should there be a max velocity to prevent nodes from flying off screen?
3. **Settling behavior:** How to ensure nodes always reach equilibrium (not oscillate forever)? Current `alpha_decay` controls this but may need tuning.
4. **The mass-drag system (from VISION_BACKLOG 3-PHYSICS):** Mass-based drag resistance, snap-back ripple, motion blur, haptics. How does this interact with the SDF label system? (Labels should blur MORE during drag due to motion).

### E. Implementation Architecture

Research the optimal split:

1. **What Rust owns:** Camera state, node positions, node metadata (type, mass, importance), zoom level. Passed to Swift via existing uniform buffer.
2. **What the Metal shader owns:** Distance-to-focus calculation, SDF text rendering, blur intensity, alpha fade, label culling. ALL per-pixel math on GPU.
3. **What Swift owns:** SDF texture atlas loading, render pipeline setup, user interaction (zoom gestures → camera state → Rust).
4. **New FFI additions needed:** What new data must cross the Rust→Swift boundary? (Likely just `camera_focal_x/y` added to existing Uniforms struct).

### F. The "Apple Feel" Polish

Research how to make the blur reveal feel native:

1. **Easing curve:** The blur→crisp transition should not be linear. What easing function matches Apple's UIKit/CoreAnimation spring animations?
2. **Glow interaction:** Labels should interact with the node's glow effect. When a label is fully crisp, the glow dims slightly. When blurred, the glow is stronger (the node "shines through" the blur).
3. **Color:** Labels should match the theme (white on dark, black on light). How to pass theme color to the shader?
4. **Motion blur on labels:** During drag/pan, labels should blur in the direction of motion (directional blur, not radial). How expensive is this in a fragment shader?

---

## OUTPUT FORMAT

1. **Architecture diagram** (text): Rust → FFI → Swift → Metal pipeline for SDF labels
2. **SDF atlas generation guide** (step-by-step with tool commands)
3. **Metal shader code** for the radial focus field SDF renderer
4. **Rust FFI additions** (new uniform fields, new functions if needed)
5. **Swift integration code** (texture loading, render pipeline modifications)
6. **Performance analysis** (expected cost per node, total cost at 10K/50K nodes)
7. **Settings UI spec** (label visibility threshold slider, blur radius control)
8. **Tuning guide** (recommended values for focus_radius, blur_radius, smoothstep boundaries, spring constants)

---

## G. CHALLENGE THE CURRENT ARCHITECTURE (Critical — find what's wrong)

The current graph system works but may have non-obvious bottlenecks, suboptimal patterns, or missed opportunities. Research must CONTEST the existing implementation, not just extend it.

### G1. Renderer Architecture Audit

The current renderer (`renderer.rs`, ~3500 lines) compiles shaders from source strings at startup via `new_library_with_source()`. It creates separate pipelines for nodes, edges, straight edges, field lines, dialogue, and compute.

Challenge and research:

1. **Should shaders be precompiled as .metallib at build time?** Current approach recompiles every launch. What's the startup cost? Would `new_library_with_data()` from a precompiled binary eliminate the flock contention entirely (instead of the file-lock workaround in AppBootstrap)?
2. **Is instanced rendering optimal for this use case?** Current draws nodes via instanced draw calls. Would indirect draw commands (`drawIndexedPrimitives(type:indexCount:indexType:indexBuffer:indexBufferOffset:instanceCount:)` from an `MTLIndirectCommandBuffer`) be faster for variable-count node types?
3. **Should the renderer use tile-based deferred rendering on Apple Silicon?** Apple GPUs are tile-based — is the current immediate-mode pipeline leaving performance on the table? Would a tile shader reduce bandwidth for the glow/blur effects?
4. **Triple buffering:** The Metal layer uses `maximumDrawableCount = 3`. Is this optimal? Should the render loop use a semaphore to gate frame-ahead, or does the atomic `framePending` flag suffice?

### G2. Physics Simulation Audit

The simulation runs Barnes-Hut N-body repulsion on the GPU compute shader plus CPU-side spring/link forces.

Challenge and research:

1. **Is Barnes-Hut the right algorithm at this scale?** For 10K-50K nodes, would a GPU-parallel Fast Multipole Method (FMM) be faster? Barnes-Hut is O(n log n), FMM is O(n) — but FMM has higher constant factors. Where's the crossover on Apple Silicon?
2. **Are link forces computed on CPU or GPU?** If CPU, should they move to a compute shader? Iterating 10K edges on CPU while GPU handles N-body creates a pipeline bubble.
3. **Velocity integration scheme:** Is the current simulation using Euler integration? Would Verlet integration provide more stable, less "rubbery" physics without losing the organic feel?
4. **Spatial hashing vs quadtree:** Barnes-Hut uses a quadtree. Would a grid-based spatial hash be faster for collision detection and nearby-node queries on the GPU (more cache-friendly, fewer pointer chases)?
5. **Force calculation frequency:** Do forces need to run every frame (120hz)? Would running physics at 60hz and interpolating positions for rendering at 120hz reduce compute by 50% with no visible difference?

### G3. Ontology and Data Model Audit

The graph has a 5-layer hierarchy: folders → nested folders → notes → chats → ideas. Node types are encoded as `UInt8` (0-6).

Challenge and research:

1. **Is a flat node array with type tags optimal?** Would separating node types into distinct buffers (one buffer per type) improve GPU cache coherence during rendering? Each type has different rendering (different shaders, different sizes).
2. **Edge storage:** How are edges stored? Adjacency list? Edge list? For GPU traversal, would a Compressed Sparse Row (CSR) format be faster for force propagation?
3. **The 5-layer hierarchy:** Is this enforced in the physics or just visual? If a folder node has 200 children, does the simulation treat them as 200 independent spring connections or as a hierarchical composite body? Hierarchical body simulation (treating a cluster as a single mass for distant interactions) would be dramatically faster.
4. **Semantic clustering:** Currently uses embedding cosine similarity to cluster. Is this clustering computed incrementally or rebuilt from scratch? Would an incremental Louvain community detection algorithm provide better clusters with less compute?
5. **Dynamic Level of Detail (LOD):** At extreme zoom-out, individual notes in a folder are invisible. Should the renderer collapse a folder's children into a single aggregate node at low zoom, reducing draw calls from 200 to 1?

### G4. Memory and Data Transfer Audit

The graph uses `MTLResourceOptions.storageModeShared` for zero-copy UMA buffers.

Challenge and research:

1. **Buffer growth strategy:** When new nodes are added, does the buffer reallocate? What's the growth factor? Should it use a geometric growth (2x) or a pool allocator with fixed-size slabs?
2. **Per-frame data transfer:** How much data crosses the Rust→Swift→Metal boundary per frame? What's the minimum? Could the Rust engine write directly to a mapped MTLBuffer and Swift just issues the draw call (true zero-copy)?
3. **SoA vs AoS completeness:** The research says positions are SoA (all X together, all Y together). But are ALL node attributes SoA? If colors, sizes, or types are in an AoS struct, cache misses during rendering could be significant.
4. **Ring buffer for mutations:** The `SharedRingBuffer` (128-byte cache lines, mmap) handles knowledge core updates. Should graph mutations (add/remove node, move) also go through a ring buffer instead of direct FFI calls?

### G5. Rendering Quality Audit

Challenge the visual output:

1. **Anti-aliasing:** Are nodes anti-aliased? SDF circles should have smooth edges via `smoothstep` in the fragment shader. If using triangle-based geometry, is MSAA enabled?
2. **Glow implementation:** How is the glow effect rendered? Bloom pass? Additive blending? A dedicated glow compute shader? Would a simple Gaussian blur post-process on a downsampled glow buffer be more efficient?
3. **Edge rendering:** Are edges Bezier curves or straight lines? Curved edges (quadratic Bezier) are more visually appealing for a knowledge graph. Are they tessellated on CPU or evaluated in the vertex shader?
4. **Color space:** Are colors in sRGB or linear space? Metal fragment shaders should work in linear space and let the framebuffer do the sRGB conversion. If colors are in sRGB, blending will produce incorrect results (dark halos around glowing edges).
5. **HDR and ProMotion:** Does the renderer take advantage of EDR (Extended Dynamic Range) for the glow? On ProMotion displays (120Hz), is the display link properly synced to the variable refresh rate?

### G6. Scalability Stress Points

Where will the current architecture break as the vault grows?

1. **At 100K nodes:** Will the single instanced draw call still be efficient, or should nodes be split into batches by screen region (frustum culling)?
2. **At 500K edges:** Will the edge buffer fit in VRAM? What's the memory footprint per edge?
3. **At 1M total entities:** Should the graph adopt a virtual scrolling approach (like NSTableView) where only visible nodes are in the draw buffer?
4. **Concurrent modification:** If NightBrain adds 50 nodes while the user is interacting with the graph, does the render loop handle this safely? Is there a double-buffer or snapshot mechanism?

---

## CONSTRAINTS

- Must run at 120fps on M2 Pro with 10K+ visible nodes with labels
- SDF distance calculation MUST be GPU-only (never per-node CPU iteration)
- Labels must be zero-cost when not visible (shader early exit)
- Must integrate with existing PowerGuard (60fps cap in lowPower, labels can be disabled)
- Must integrate with existing performance mode (quality level 2 = no labels)
- Must respect disabled node types (source, quote, person — no labels for these)
- The volatile "Garry's Mod" physics is a FEATURE, not a bug. Preserve it. Polish, don't sterilize.
- F_FULLFSYNC for any new persistent data (SDF atlas cache, label settings)
- Zero-copy: SDF atlas should be a single MTLTexture loaded once, shared across all draw calls

Here’s the deep research report. The strongest conclusion is that Epistemos should add labels as a separate instanced MSDF text pass, driven entirely by GPU focus-distance math, while keeping Rust responsible for camera/world state and Swift responsible for atlas/pipeline setup; trying to fold label logic into the existing node shader would raise coupling, increase overdraw, and make tuning much harder.[^1][^2][^3][^4]

The current architecture is already closer to a good label system than it looks: the renderer already has camera offset/zoom, world-space node positions, camera velocity and zoom velocity in uniforms, and instanced node rendering with shared Metal buffers, so the missing pieces are mostly a glyph atlas, a label instance buffer, a few extra uniform fields, and a dedicated text pipeline rather than a wholesale rewrite.[^2][^5][^1]

# Graph SDF Label System for Epistemos

## Executive Summary

Epistemos already has the key runtime ingredients needed for an SDF label system: a Rust renderer that owns camera state and uploads a compact `Uniforms` struct, a Swift layer that manages the Metal view lifecycle and quality modes, and a D3-like force simulation with explicit velocity, alpha decay, GPU-assisted many-body force, and quality gating. The optimal implementation is to add a **separate MSDF label render pass** after nodes and before dialogue overlay, driven by **per-label instance data** and a **single shared atlas texture**, with all focus blur, alpha falloff, and motion blur computed in the fragment shader.[^1][^6][^2][^7][^8][^3][^4]

The most important architectural recommendation is to **avoid CPU-side per-label focus decisions**. The CPU should only cull labels coarsely by quality mode, disabled node type, and rough zoom band; the GPU should compute radial focus distance and blur continuously from world-space label anchor to a camera focus point. This matches the current renderer’s style, preserves the 120 fps target better than CPU iteration, and keeps pan/zoom reveal smooth instead of toggled.[^2][^1]

The second major recommendation is to **use MSDF, not single-channel SDF**, and generate atlases **offline at build time**. Multi-channel distance fields preserve sharp corners much better for UI text, especially at small sizes, and Apple’s Metal toolchain explicitly rewards moving expensive compilation and preprocessing work out of runtime. For Epistemos, that means: precompute atlas PNG + JSON metadata, load once into one `MTLTexture`, and never generate glyphs at runtime except as a future fallback path for rare Unicode expansion.[^3][^4][^9][^10]

The third major recommendation is to **challenge the current renderer startup path**. The existing renderer compiles large shader strings at startup with `new_library_with_source()`, and Apple explicitly recommends precompiled libraries and dynamic libraries to avoid runtime compilation cost. Labels are a good forcing function to move the renderer toward offline `.metallib`, because adding more embedded shader source only increases launch-time contention and complexity.[^4][^9][^2]

***

## Current Architecture Snapshot

### Rust owns most runtime truth

The renderer already owns `cameraoffset`, `camerazoom`, `time`, `pulseorigin`, `pulsetime`, `focallength`, `cameravelocity`, `zoomvelocity`, `litemode`, `impactintensity`, and `dialoguetheme` in a compact `Uniforms` struct mirrored between Rust and Metal. That is exactly the right ownership boundary for a focus-field label system, because label blur should depend on camera and motion state that already lives in Rust and is already uploaded each frame.[^1][^2]

The engine also already exposes world/screen coordinate conversions and camera targeting logic, including `screentoworld`, `nodescreenpos`, `zoomtofit`, `centeronnode`, and smooth camera animation using a lambda-based easing path. That means adding a world-space focus point is low-friction: the renderer can derive it directly from camera center or from cursor-anchored zoom logic without introducing a new ownership model.[^5][^1]

### The current renderer is instanced and buffer-driven

Nodes are drawn as instanced quads using a `NodeInstance` struct containing position, radius, z, color, and face type, with shared Metal buffers allocated in storage mode shared. This is a good match for label rendering too: a label system should use a separate `LabelInstance` buffer with anchor position, label size, glyph range offset/count, importance, node type, and threshold parameters, and then draw glyph quads by instancing or by expanding per-glyph quads from a packed glyph stream.[^2]

The renderer already uses culling, LOD, density clustering, velocity-driven deformation, and highlight flag buffers. Those mechanisms indicate the label system should not become a bespoke side path; it should reuse the renderer’s existing ideas: quality-gated feature enablement, per-frame scratch buffers, and shared, amortized buffer growth.[^2]

### Simulation is D3-like, not true Verlet

The simulation file describes itself as a D3-force style loop with explicit `vx`/`vy`, alpha decay, force application, and velocity integration, and it explicitly says there is “no position-Verlet.” That matters because some of the prompt’s questions assume Verlet may already be in use; it is not. If physics feel “rubbery,” that comes from low damping and alpha reheat behavior more than from a Verlet integrator.[^6][^7]

***

## Recommended Label Architecture

### The correct split

The clean split is:


| Layer | Owns |
| :-- | :-- |
| Rust engine | Camera state, world positions, node labels/metadata, quality mode, node importance, disabled label eligibility flags, optional focus point and motion metrics.[^1][^2][^5] |
| Swift | Atlas loading, atlas metadata decoding, Metal texture creation, render pipeline creation, settings/UI plumbing, app persistence.[^7][^8] |
| Metal | Distance-to-focus, blur width, alpha fade, motion-directed blur, final MSDF reconstruction, optional overlap weighting and fine culling.[^2] |

This split is optimal because it minimizes CPU per-frame work while keeping platform-specific texture and resource lifecycle in Swift, where the app already manages Metal resources and power/quality behavior.[^2][^7][^8]

### Add a dedicated label pass

Do **not** merge label rendering into the current node shader. The node shader is already carrying circle shading, glow logic, face overlays, highlight rings, and motion deformation. Adding glyph sampling, atlas lookups, edge-color median logic, and focus blur there would bloat a hot path and increase overdraw for nodes that may not need labels.[^2]

Instead:

1. Draw edges.
2. Draw node glow.
3. Draw nodes.
4. Draw labels in a separate transparent pass.
5. Draw dialogue overlay.[^2]

This gives clean control over blend state, easier debugging, easier performance measurement, and per-quality disabling without branching through the node shader.[^8][^2]

***

## Text Architecture Diagram

```text
SwiftUI / App Settings
    ↓
GraphState (quality mode, theme, label settings, PowerGuard)
    ↓
MetalGraphView / GraphEngine.swift
    ↓ FFI calls
Rust Engine
    ├─ Simulation (positions, velocities, alpha, drag state)
    ├─ Renderer state (camera offset/zoom, motion, uniforms)
    └─ World metadata (node type, label text, importance, visibility)
    ↓
Per-frame upload
    ├─ Uniform buffer
    ├─ Node instance buffer
    ├─ Label instance buffer
    └─ Glyph stream buffer / atlas metadata buffer
    ↓
Metal pipelines
    ├─ Edge pass
    ├─ Node glow pass
    ├─ Node pass
    ├─ MSDF label pass  ← radial focus + blur reveal + motion blur
    └─ Dialogue overlay
```

This architecture preserves the renderer’s current ownership model and avoids forcing Swift to do per-node label policy every frame.[^1][^2][^7]

***

## SDF Atlas Strategy

### Best tool

The best fit is **`msdf-atlas-gen`** from Chlumsky, because it supports MSDF generation, atlas packing, and metadata export, and it has both offline and dynamic workflows documented by the project. `msdfgen` alone is lower-level and better as a library component than as the top-level atlas pipeline; `msdf-atlas-gen` is the practical choice for shipping a font atlas artifact.[^3][^11]

A commercial option like Slug can outperform DIY systems for advanced shaping and text layout, but it would be overkill for Epistemos’s immediate need, which is short labels on graph nodes rather than rich multilingual text paragraphs. The current app would benefit more from a simple, inspectable build artifact than from a heavyweight runtime text engine.[^7][^3]

### Build-time, not runtime

The atlas should be generated at build time and shipped with the app. Apple explicitly recommends moving compilation-heavy work offline where possible, and the current renderer already pays runtime shader compilation cost that should not be compounded with runtime font atlas generation. Build-time generation also makes startup deterministic and preserves the “loaded once, shared across all draw calls” constraint from the prompt.[^2][^4]

### Font choice

For this graph, **SF Pro Text** is the best primary atlas font if licensing and packaging constraints allow it inside the app bundle; otherwise the fallback should be a metrically stable system-like sans rather than `NSFont.monospacedSystemFont`. Monospaced fonts are great for code, but they tend to feel less “Apple-native” in a semantic graph UI and waste horizontal density on short labels. MSDF benefits most when the source font has clean counters and balanced stroke transitions, which favors SF-style UI faces over monospaced system fonts for this use case.[^7][^3]

### Charset scope

Ship at least:

- ASCII printable set.
- Common punctuation used in note titles.
- Latin-1 supplement.
- Smart quotes, en/em dashes, bullets, ellipsis.
- A runtime fallback path for missing glyphs, but not full dynamic atlas mutation in v1.[^3]

The ideal v1 is one atlas covering the dominant UI language set, because rare runtime glyph misses are less damaging than the complexity and synchronization cost of live atlas mutation in a 120 fps renderer.[^2][^3]

### Atlas packing guide

Recommended atlas artifact set:

- `EpistemosLabelAtlas.png` or `.ktx2`/raw texture asset.
- `EpistemosLabelAtlas.json` containing glyph metrics:
    - unicode codepoint
    - atlas UV rect
    - plane bounds
    - advance
    - bearing / offset
    - optional kerning pairs if you decide to support them.[^3]

For a Metal pipeline, the atlas should be loaded into one `MTLTexture` as `rgba8Unorm` for MSDF channels, with the JSON parsed into a Swift dictionary and packed into a Metal buffer for quick lookup.[^7][^3]

### Example generation command

A representative build-time command should look like this conceptually:

```bash
msdf-atlas-gen \
  -font "SF-Pro-Text-Regular.otf" \
  -charset "charset.txt" \
  -type msdf \
  -dimensions 1024 1024 \
  -pxrange 6 \
  -imageout EpistemosLabelAtlas.png \
  -json EpistemosLabelAtlas.json
```

The exact flags depend on your packaging, but the important choices are **MSDF**, a single atlas, and enough pixel range to allow controlled blur widening without edge collapse.[^3]

***

## Radial Focus Field Design

### Camera focus point

The easiest correct focus point is **the world-space coordinate at the center of the viewport**, which in the current renderer is effectively `cameraoffset` because screen-to-world transforms are `screen = (world - cameraoffset) * zoom`. Since the engine already converts screen coordinates to world coordinates for input, it can also derive a cursor-weighted focus point later if you want labels to sharpen under the mouse rather than under the view center.[^1][^2]

Recommended v1:

- `cameraFocusWorld = cameraoffset`
- optional v2 blend:
    - 80% camera center
    - 20% cursor world point during active hover/drag

That preserves predictability and avoids jitter from transient cursor motion.[^1]

### GPU-side distance math

The fragment shader should receive a world anchor for each label and compute:

$$
d = \text{distance}(labelWorldPos, cameraFocusWorld)
$$

Then derive a normalized blur weight:

$$
b = \text{smoothstep}(focusRadius, blurRadius, d)
$$

This is exactly aligned with the current architecture because the node shader already passes world position information through to the fragment stage for other effects.[^2]

### Zoom scaling

Focus and blur radii should scale in **world units**, but be derived from a desired screen-space behavior. A practical approach is:

$$
focusRadiusWorld = focusRadiusScreen / cameraZoom
$$

$$
blurRadiusWorld = blurRadiusScreen / cameraZoom
$$

This keeps the reveal band visually stable as users zoom. If radii are fixed in world space, the reveal will feel too abrupt at some zoom levels and too broad at others.[^1][^2]

### Blur reconstruction with MSDF

For MSDF, the typical crisp reconstruction is based on the median of RGB channels and a narrow antialias window, not a single-channel alpha distance. The prompt’s proposed widening of the smoothstep thresholds is directionally correct, but with MSDF the better formulation is to vary the edge softness around the median distance rather than hardcoding `0.45/0.55` and `0.1/0.9` directly.[^12][^3]

Recommended fragment logic:

```metal
float msdf = median(sample.r, sample.g, sample.b);
float blur = smoothstep(focusRadius, blurRadius, distToFocus);
float edgeWidth = mix(crispWidth, blurredWidth, blur);
float alpha = smoothstep(0.5 - edgeWidth, 0.5 + edgeWidth, msdf);
alpha *= focusFade;
```

Where:

- `crispWidth` ≈ 0.04 to 0.06
- `blurredWidth` ≈ 0.22 to 0.35
- `focusFade` is a second falloff that fades labels to zero beyond a farther threshold.[^3][^12]


### Early exit

The fragment shader should bail out early when:

- quality level is performance mode,
- node type is label-disabled,
- zoom is below reveal threshold,
- `focusFade <= 0.0`,
- or atlas sample alpha coverage is trivially zero.[^2][^7][^8]

That will not make invisible labels literally zero-cost, because quads are still rasterized, but it will keep the expensive reconstruction and blending path minimal.[^2]

***

## Metal Shader Skeleton

Below is the recommended structure for the label shader path.

```metal
struct LabelUniforms {
    float2 viewportSize;
    float2 cameraOffset;
    float cameraZoom;
    float time;

    float2 cameraVelocity;
    float zoomVelocity;

    float2 cameraFocusWorld;
    float focusRadiusScreen;
    float blurRadiusScreen;
    float fadeRadiusScreen;

    float2 panDirectionScreen;
    float panSpeed;

    float4 textColor;
    float4 textColorSecondary;

    float qualityLevel;
    float lightMode;
};

struct LabelInstance {
    float2 worldAnchor;
    float2 labelSizeScreen;
    float2 atlasMinUV;
    float2 atlasMaxUV;
    float2 bearingScreen;
    float2 glyphSizeScreen;

    float importance;
    float nodeType;
    float revealZoomStart;
    float revealZoomEnd;

    float motionBlurScale;
    float pad[^3];
};

struct LabelVertexOut {
    float4 position [[position]];
    float2 uv;
    float2 worldAnchor;
    float2 screenPos;
    float importance;
    float nodeType;
    float reveal;
};

float median3(float a, float b, float c) {
    return max(min(a, b), min(max(a, b), c));
}

vertex LabelVertexOut labelVertex(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    constant LabelInstance *instances [[buffer(0)]],
    constant LabelUniforms &u [[buffer(1)]]
) {
    float2 corners[^6] = {
        float2(0,0), float2(1,0), float2(0,1),
        float2(0,1), float2(1,0), float2(1,1)
    };

    LabelInstance inst = instances[instanceID];
    float2 corner = corners[vertexID];

    float reveal = smoothstep(inst.revealZoomStart, inst.revealZoomEnd, u.cameraZoom);

    float2 glyphOffsetScreen = inst.bearingScreen + corner * inst.glyphSizeScreen;
    float2 world = inst.worldAnchor + glyphOffsetScreen / u.cameraZoom;
    float2 screen = (world - u.cameraOffset) * u.cameraZoom;
    float2 ndc = screen / (u.viewportSize * 0.5);

    LabelVertexOut out;
    out.position = float4(ndc.x, -ndc.y, 0.0, 1.0);
    out.uv = mix(inst.atlasMinUV, inst.atlasMaxUV, corner);
    out.worldAnchor = inst.worldAnchor;
    out.screenPos = screen;
    out.importance = inst.importance;
    out.nodeType = inst.nodeType;
    out.reveal = reveal;
    return out;
}

fragment float4 labelFragment(
    LabelVertexOut in [[stage_in]],
    texture2d<float> atlas [[texture(0)]],
    sampler atlasSampler [[sampler(0)]],
    constant LabelUniforms &u [[buffer(1)]]
) {
    if (u.qualityLevel >= 2.0) discard_fragment();
    if (in.reveal <= 0.001) discard_fragment();

    float2 focusDeltaWorld = in.worldAnchor - u.cameraFocusWorld;
    float distWorld = length(focusDeltaWorld);

    float focusRadius = u.focusRadiusScreen / max(u.cameraZoom, 0.01);
    float blurRadius  = u.blurRadiusScreen  / max(u.cameraZoom, 0.01);
    float fadeRadius  = u.fadeRadiusScreen  / max(u.cameraZoom, 0.01);

    float blur = smoothstep(focusRadius, blurRadius, distWorld);
    float fade = 1.0 - smoothstep(blurRadius, fadeRadius, distWorld);

    if (fade <= 0.001) discard_fragment();

    float2 uv = in.uv;

    float motionAmount = min(u.panSpeed * 0.015, 1.0);
    float2 blurDir = normalize(u.panDirectionScreen + float2(0.0001, 0.0001));
    float2 texel = 1.0 / float2(atlas.get_width(), atlas.get_height());

    float3 s0 = atlas.sample(atlasSampler, uv).rgb;
    float3 s1 = atlas.sample(atlasSampler, uv + blurDir * texel * 1.5 * motionAmount).rgb;
    float3 s2 = atlas.sample(atlasSampler, uv - blurDir * texel * 1.5 * motionAmount).rgb;

    float3 sampleRGB = mix(s0, (s0 + s1 + s2) / 3.0, motionAmount * 0.5);
    float sd = median3(sampleRGB.r, sampleRGB.g, sampleRGB.b);

    float crispWidth = 0.045;
    float softWidth  = 0.28;
    float edgeWidth = mix(crispWidth, softWidth, blur);

    float alpha = smoothstep(0.5 - edgeWidth, 0.5 + edgeWidth, sd);
    alpha *= fade * in.reveal;

    if (alpha <= 0.001) discard_fragment();

    float glowBlend = blur;
    float3 color = mix(u.textColor.rgb, u.textColorSecondary.rgb, glowBlend * 0.15);

    return float4(color, alpha * u.textColor.a);
}
```

This structure matches the existing renderer’s uniform style and keeps the label pass mostly orthogonal to node shading.[^2]

***

## Semantic Zoom Policy

### When labels should appear

The current graph clamps zoom between 1.0 and 10.0 in Rust camera helpers, which means the label system can be tuned around that actual runtime range rather than an arbitrary infinite scale. A good default policy is:[^1]

- Folder / high-level nodes: start reveal at zoom 1.15
- Notes / chats / ideas: start reveal at zoom 1.5
- Tiny leaf nodes or low-importance nodes: start reveal at zoom 1.9
- Full crisp band by zoom 2.2 to 2.8 depending on node type.[^7][^1]

This should definitely be configurable via Settings, but the default needs to be type-aware or the graph will feel cluttered immediately.[^7]

### Per-node thresholds

The best way to pass per-node threshold is directly in the `LabelInstance` as two floats:

- `revealZoomStart`
- `revealZoomEnd`

That avoids shader branching on node type tables and lets Rust/Swift compute thresholds from node type, importance, radius, or cluster role.[^2][^7]

### Density-aware culling

Pure GPU overlap resolution is possible, but expensive and complex if you want stable, importance-aware results. The best v1 is a **hybrid**:

- CPU coarse candidate generation by zoom/type/importance.
- GPU per-fragment fade and blur.
- CPU optional cap on maximum candidate labels in dense views using importance sorting within screen-space bins.[^2]

The existing renderer already clusters dense nodes into proxies for certain LOD paths. That suggests the label system should reuse a similar idea: divide the screen into bins, keep top-N importance labels per bin, and let the GPU do the continuous reveal for the survivors.[^2]

Importance metric should combine:

- node type weight,
- node degree or hubness,
- current selection/highlight state,
- confidence,
- optional recency for notes.[^1][^2]

A full GPU overlap solver would be harder to make stable than a CPU binning pass and would likely not pay off until much larger scales.[^2]

***

## Physics Polish Recommendations

### What the current system actually is

The simulation already uses explicit velocity arrays, alpha decay, collision, center, semantic, and wind/orbital forces, with a hard max velocity clamp of 500 and optional impact damping frames. It is not using Verlet despite the file’s “velocity Verlet” language; the implementation is fundamentally a D3-style explicit velocity integrator with damping.[^6]

### Spring tuning for “viscous but settling”

The current defaults are already sensible for a dense graph:

- link distance 80
- charge strength -300
- charge range 400
- velocity decay 0.6
- center strength 0.03
- collision radius 26.[^6]

For the requested “Garry’s Mod rubbery but polished” feel, recommended presets are:


| Feel | linkStrength | velocityDecay | alphaDecay | Notes |
| :-- | --: | --: | --: | :-- |
| Viscous settling | 0.0 auto or 0.15 | 0.72–0.82 | 0.020–0.030 | Better for day-to-day navigation.[^6] |
| Rubbery interactive | 0.25–0.45 | 0.45–0.60 | 0.010–0.018 | Keeps organic wobble without perpetual chaos.[^6][^7] |
| Chaotic showcase | 0.0–0.15 | 0.08–0.25 | 0.004–0.012 | Great demo feel, bad for readable labels.[^7] |

The current `GraphState` presets confirm that many of the wilder modes use very low velocity decay, sometimes as low as 0.05 or 0.10, which explains the intentionally loose motion. For label readability, the default interactive preset should be a little more damped than the showiest chaos preset.[^7]

### Velocity clamping

Yes, there should be a max velocity, and there already is one at 500 in simulation. That is probably too high for a graph with readable labels; a lower cap around 180–260 world units per tick would better suppress explosive flyoffs while preserving the “snap” feel.[^6]

Recommended:

- simulation max velocity: 220 for normal modes
- keep 500 only for explicit chaos/demo mode.[^7][^6]


### Settling behavior

The biggest settling lever is not spring stiffness; it is the interplay between `alpha`, `alphadecay`, and `velocitydecay`. The simulation already marks itself settled when alpha falls to a floor and no nodes are fixed. If nodes appear to oscillate too long, raising `velocityDecay` modestly and slightly increasing `alphaDecay` will help more predictably than cranking spring force.[^6]

Recommended defaults for label-friendly interaction:

- `velocityDecay`: 0.72
- `alphaDecay`: 0.026
- `alphatarget` during drag: 0.02–0.03
- post-interaction hold target: keep current 0.015, but shorten hold for ordinary panning if desired.[^1][^6]


### Motion-linked label blur

The prompt’s idea is correct: labels should blur more during drag or fast pan. The renderer already has `cameravelocity` and `zoomvelocity` fields in uniforms, and the simulation already tracks impact frames and drag wake behavior. The label system should consume those existing motion signals to widen edge width and reduce alpha slightly during motion instead of requiring new per-node blur state.[^6][^2]

***

## FFI and Data Additions

### Minimal new fields

The prompt guesses only `camera_focal_x/y` may be needed. That is close, but not sufficient for the full polish path. Recommended additions to `Uniforms`:[^2][^5]

- `float2 cameraFocusWorld`
- `float focusRadiusScreen`
- `float blurRadiusScreen`
- `float fadeRadiusScreen`
- `float2 panDirectionScreen`
- `float panSpeed`
- `float labelsEnabled`
- `float4 labelColor`
- `float4 secondaryLabelColor`.[^2]

Because `Uniforms` is already tightly mirrored and size-checked, add these in a new `LabelUniforms` struct rather than mutating the hot node `Uniforms` if you want to minimize risk. That is the safer path.[^2]

### New instance structs

Add something like:

```rust
#[repr(C)]
struct LabelInstance {
    world_anchor: [f32; 2],
    label_size_screen: [f32; 2],
    atlas_min_uv: [f32; 2],
    atlas_max_uv: [f32; 2],
    bearing_screen: [f32; 2],
    glyph_size_screen: [f32; 2],
    importance: f32,
    node_type: f32,
    reveal_zoom_start: f32,
    reveal_zoom_end: f32,
    motion_blur_scale: f32,
    pad: [f32; 3],
}
```

And likely a packed glyph indirection buffer if labels are multi-glyph rather than one quad per label.[^2]

### New FFI calls

At minimum the C bridge should gain:

- set label system enabled/disabled
- set label tuning values
- optionally upload atlas metadata if Swift owns parsing
- optionally set theme label colors.[^13][^5]

The existing FFI already has display settings, quality level, visual theme, and force parameters, so labels fit naturally as another display subsystem rather than a new engine domain.[^5][^13]

***

## Swift Integration Plan

### What Swift should do

Swift should:

- load the atlas texture once at startup,
- parse glyph metadata JSON,
- build an atlas metadata buffer,
- create a dedicated label render pipeline,
- pass settings from `GraphState`,
- disable labels when low-power/performance mode requires it.[^7][^8]

That is consistent with the current Swift role as state coordinator and quality gatekeeper.[^8][^7]

### Quality and power behavior

`GraphState` already maps performance mode to renderer quality level 2, and `PowerGuard` already forces rendering throttles and low-power behavior. The label system should obey:[^7][^8]

- `qualityLevel == 2` → labels fully off.
- low power mode → labels off by default, optional user override later.
- eco/full mode → labels available.[^8][^7]

That aligns with the prompt’s constraint that quality level 2 has no labels.[^7]

### Settings UI spec

Add a “Labels” settings group:

- Labels enabled: toggle
- Reveal start zoom: slider
- Focus radius: slider
- Blur radius: slider
- Fade radius: slider
- Motion blur strength: slider
- Show folder labels earlier: toggle
- Density cap per screen region: slider
- Theme color mode: automatic / custom
- Disable labels in low power: toggle default on.[^7][^8]

These belong beside current graph display and physics controls in `GraphState` rather than buried inside renderer code.[^7]

***

## Architecture Audit: What’s Wrong Today

## Renderer audit

### Runtime shader compilation is a real weakness

The renderer compiles shader source strings at startup via `new_library_with_source()`. Apple’s guidance is clear that precompiled libraries and dynamic libraries can avoid runtime compilation and shorten startup cost. For a renderer this large, embedding giant source strings is increasingly the wrong tradeoff.[^2][^4][^9]

**Recommendation:** move to offline `.metallib` for the core renderer and label pass first, then consider dynamic libraries if modular reuse grows.[^4][^9]

### Instancing is still the right default

Current node rendering via instanced quads is appropriate for thousands of homogeneous node billboards. Indirect command buffers are powerful, but they add complexity and are most beneficial when the CPU is spending too much time issuing many heterogeneous draw calls; Epistemos already uses few large instanced draws. For labels, stay with instancing until profiling proves command generation is the bottleneck.[^2][^14]

### Tile-based deferred rendering is not the first optimization to chase

Apple GPUs are tile-based, but the current renderer’s biggest likely pain points are overdraw and startup compilation, not absence of a tile shader path. For glow and label blur, the lower-risk win is downsampled offscreen glow or simpler pass ordering, not a renderer-wide tile-shader redesign.[^2][^15][^4]

### Frame gating is only halfway there

The renderer uses `maximumDrawableCount = 3` and a frame-pending style mechanism on the Swift side, but the code visible here does not indicate a fully explicit semaphore-based frame-ahead budget. Triple buffering is fine, but pairing it with a semaphore would give more deterministic back-pressure under heavy load than a simple pending flag.[^2][^7]

## Physics audit

### Barnes-Hut is still the right algorithm here

Barnes-Hut at 10K–50K nodes is still the practical choice for this engine. FMM has better asymptotic complexity and is cited in force-directed graph literature, but it comes with significantly higher implementation complexity and constant factors. On Apple Silicon, the crossover point where a full GPU FMM beats a well-tuned Barnes-Hut for this app is unlikely to be worth the engineering cost until graph scale and force frequency grow much further.[^6][^16]

### Link force CPU/GPU split is suspect

The simulation explicitly does many-body on GPU when large enough, but link forces remain in CPU-side simulation code. That means there is likely a pipeline bubble: the render thread dispatches GPU repulsion, the physics thread later drains results, but spring/link work remains serial CPU work.[^1][^6]

**Recommendation:** do not rush all link force to GPU first; instead profile edge-heavy workloads. If CPU link processing dominates at 50K+ edges, move link forces and maybe collision into compute together so force accumulation lives in one domain.[^6]

### The integrator is simpler than the prompt assumes

The simulation is already explicit-velocity D3 style, not pure Euler position stepping and not position Verlet. Switching wholesale to Verlet would alter the feel substantially. If polish is the goal, tune damping and alpha first; only revisit integrators if you want a fundamentally different motion signature.[^6][^17]

### Physics frequency decoupling is promising

The engine already adapts physics tick rate by node count and extrapolates positions for smooth rendering between ticks. That means the architecture already accepts decoupled physics/render cadence. Running physics at 60 Hz with 120 Hz render interpolation is therefore not a theoretical change; it is already partially the model. This is a strong sign that label focus and motion blur should read interpolated render positions, not raw physics positions.[^1]

## Data model audit

### Flat node arrays are okay, but type-segregated render buffers would help

A flat node array with type tags is acceptable for simulation, but rendering could benefit from splitting label-eligible vs non-label-eligible nodes, and possibly major node types into separate buffers. Since some types should never show labels, keeping them in the same label candidate path wastes bandwidth.[^2][^5]

### Static layout threshold is a major UX breakpoint

At 9000 visible nodes, the simulation enters static layout and zeroes velocities. That is a practical safety valve, but it means your label system must expect sharp behavioral changes around large graphs: labels may still render while physics is frozen. The UX needs explicit messaging or visual behavior tuned for that mode.[^6][^7]

### LOD collapse is missing for extreme zoom-out

The renderer has density clustering for nodes in some LOD conditions, but the architecture does not yet appear to have a true semantic aggregate-node LOD that collapses a folder and many children into one surrogate entity at distance. For 100K+ nodes, that becomes more important than micro-optimizing label blur math.[^2]

## Memory and transfer audit

### Shared memory is good, but growth strategy should be more deliberate

Buffers are reallocated when capacity is insufficient, using a roughly 1.5x growth style in places. That is decent, but for label buffers and glyph streams you should establish a uniform geometric growth rule and reuse buffers aggressively to avoid heap churn during graph edits.[^2]

### Full zero-copy isn’t complete yet

The renderer uses shared Metal buffers and Rust-owned upload data, which is good. But the current architecture still stages some data through CPU-side scratch vectors and Swift manages draw calls separately. A future optimization path is to let Rust fill mapped Metal buffers directly while Swift stays a thin presentation layer, but that is a bigger ownership change and not required for labels v1.[^2][^7]

## Rendering quality audit

### Anti-aliasing is shader-based for nodes, which is fine

Node circles are already shader-shaped with smooth boundaries rather than mesh edges, so the renderer is leaning on analytic antialiasing instead of MSAA for nodes. That philosophy pairs naturally with MSDF text and supports the label pass well.[^2]

### Glow should become more explicitly layered

Glow today is encoded as low-alpha node instances with radial falloff in the node fragment path. That works, but the label prompt’s desired interaction—glow stronger when text is blurred, dimmer when text is crisp—argues for a more explicit relationship between node glow and label focus rather than two independent effects. In practice, pass a per-node glow attenuation term or compute it from the same focus blur value.[^2]

### Color space may need scrutiny

The renderer uses `BGRA8Unorm` attachments and alpha blending, but the visible snippets do not prove a fully linear-light workflow. For glow and blurred text, blending in the wrong space can produce muddy halos. This deserves explicit audit when implementing labels.[^2]

***

## Performance Expectations

### Cost model

A label pass costs:

- additional instance buffer upload,
- glyph quad rasterization,
- texture sampling from the MSDF atlas,
- fragment reconstruction and blending.[^2][^3]

The biggest cost is usually **fill rate and overdraw**, not the distance formula itself. That is why dense candidate suppression matters more than the `distance()` call.[^2]

### Practical expectations

At 10K visible nodes, if all 10K had labels, the scene would likely be overdraw-limited before it is ALU-limited. But that is not the intended operating mode. With zoom/type/density gating, a realistic active label count should be more like:[^2]

- 100–400 crisp or semi-blurred labels in a wide graph view,
- 500–1500 in a zoomed-in dense neighborhood,
- near-zero in performance mode.[^7][^2]

Under that regime, a separate label pass should stay within the prompt’s “under 5% fps drop” target on M2 Pro, provided:

- labels are fully off in quality 2,
- screen-bin density caps are used,
- atlas is loaded once,
- shaders are precompiled,
- and motion blur sampling stays small, e.g. 3 taps not 9+ taps.[^8][^4][^7]


### 50K node scenario

At 50K nodes, the real bottleneck is not MSDF math; it is candidate management and scene complexity. You should assume:[^6][^2]

- no all-node labels,
- stronger density culling,
- cluster/aggregate labels at far zoom,
- likely lower physics fidelity or more aggressive static/LOD behavior.[^2][^6]

***

## Tuning Guide

### Label tuning defaults

| Parameter | Recommended default | Notes |
| :-- | --: | :-- |
| Reveal start zoom (folders) | 1.15 | Show structure earlier.[^1][^7] |
| Reveal start zoom (notes) | 1.55 | Avoid clutter.[^7] |
| Reveal full zoom | 2.25 | Crisp by close-in navigation.[^1] |
| Focus radius | 90 px | Crisp core around center. |
| Blur radius | 240 px | Main reveal band. |
| Fade radius | 420 px | Full disappearance after blur. |
| Crisp edge width | 0.045 | MSDF reconstruction. |
| Blurred edge width | 0.28 | “Apple cloud” feel. |
| Motion blur sample count | 3 taps | Cheap directional blur. |
| Max labels per screen bin | 2–4 | Stable density cap. |

### Physics tuning defaults

| Parameter | Recommended default | Why |
| :-- | --: | :-- |
| linkDistance | 80–100 | Keeps graph compact.[^6] |
| chargeStrength | -280 to -340 | Similar to current stable default.[^6] |
| chargeRange | 350–500 | Avoids runaway spread.[^6] |
| velocityDecay | 0.72 | More settled than current 0.6.[^6] |
| alphaDecay | 0.026 | Faster settling.[^6] |
| drag alphaTarget | 0.025 | Keeps motion responsive.[^1][^6] |
| post-drag hold | 0.015 | Existing value is good.[^1][^7] |
| max velocity | 220 | Less flyoff than current 500.[^6] |


***

## Apple Feel Polish

### Easing curve

The renderer’s camera already uses an exponential smoothing formula with `CAMERA_LAMBDA = 3.0`, which creates a cinematic glide. For label reveal, the blur interpolation should similarly avoid feeling linear. A good fit is a cubic or smootherstep-shaped reveal on top of the radial blur term rather than a raw linear remap.[^2]

### Glow interaction

Use the same blur factor to modulate node glow:

- blurred label → stronger node glow
- crisp label → dimmer glow

This will make the transition feel designed rather than coincidental. The renderer already distinguishes glow instances and normal nodes, so this can be implemented as a lightweight per-node modulation term rather than a new effect family.[^2]

### Theme color

`GraphState` already owns light/dark mode and visual theme, and the renderer already receives theme-related fields. Label colors should therefore be theme-driven in Swift and uploaded as uniforms, not recomputed in the shader from node colors.[^2][^7]

### Directional motion blur cost

Directional motion blur in the label fragment shader is affordable if it is tiny: 3 taps, only when camera pan speed exceeds a threshold, and disabled in low power/performance mode. A full radial or long-kernel blur would be too expensive and unnecessary.[^7][^8]

***

## Final Implementation Plan

### Phase 1: Infrastructure

1. Move renderer shaders toward precompiled `.metallib` for at least the new label pipeline.[^4][^9]
2. Add build-time `msdf-atlas-gen` step and ship atlas + metadata.[^3]
3. Add Swift atlas loading and label pipeline setup.[^7]

### Phase 2: Data plumbing

1. Add label settings to `GraphState`.[^7]
2. Add Rust-side label eligibility and importance extraction from node metadata.[^1][^2]
3. Add label instance buffer generation and growth policy.[^2]

### Phase 3: Shader path

1. Implement dedicated MSDF label vertex/fragment shaders.
2. Add radial focus field in fragment shader.
3. Add motion blur and glow coupling.
4. Gate by quality level and power mode.[^2][^7][^8]

### Phase 4: Density and polish

1. Add screen-bin importance culling.
2. Add per-node-type reveal thresholds.
3. Tune defaults against real vaults at 10K+ visible nodes.
4. Add optional aggregate labels for zoomed-out folders.[^2][^7]

## Bottom line

The best version of this system is **offline-generated MSDF atlas + separate Metal label pass + GPU-only radial focus blur + Swift-owned atlas resources + Rust-owned world/camera truth**. The biggest architectural flaw to fix first is not label math but the renderer’s growing dependence on runtime shader compilation and monolithic shader source strings, because adding labels without fixing that will worsen startup and maintainability.[^1][^2][^3][^4][^9]

If you want, I can next turn this into a concrete patch plan with:

- Rust structs and FFI signatures,
- exact Swift code skeletons,
- and a drop-in Metal shader file split from the current embedded source.
<span style="display:none">[^100][^101][^102][^103][^104][^105][^106][^107][^108][^109][^110][^111][^112][^113][^114][^115][^116][^117][^118][^119][^120][^121][^122][^123][^124][^125][^126][^127][^128][^129][^130][^131][^132][^133][^134][^135][^136][^137][^138][^139][^140][^141][^142][^143][^144][^145][^146][^147][^148][^149][^150][^151][^152][^153][^154][^155][^156][^157][^158][^159][^160][^161][^162][^163][^164][^165][^166][^167][^168][^169][^170][^171][^172][^173][^174][^175][^176][^177][^178][^179][^18][^180][^181][^182][^183][^184][^185][^186][^187][^188][^189][^19][^190][^191][^192][^193][^194][^195][^196][^197][^198][^199][^20][^200][^201][^202][^203][^204][^205][^206][^207][^208][^209][^21][^210][^211][^212][^213][^214][^215][^216][^217][^218][^219][^22][^220][^221][^222][^223][^224][^225][^226][^227][^228][^229][^23][^230][^231][^232][^233][^234][^235][^236][^237][^238][^239][^24][^240][^241][^242][^243][^244][^245][^246][^247][^248][^249][^25][^250][^251][^252][^253][^254][^255][^256][^257][^258][^259][^26][^260][^261][^262][^263][^264][^27][^28][^29][^30][^31][^32][^33][^34][^35][^36][^37][^38][^39][^40][^41][^42][^43][^44][^45][^46][^47][^48][^49][^50][^51][^52][^53][^54][^55][^56][^57][^58][^59][^60][^61][^62][^63][^64][^65][^66][^67][^68][^69][^70][^71][^72][^73][^74][^75][^76][^77][^78][^79][^80][^81][^82][^83][^84][^85][^86][^87][^88][^89][^90][^91][^92][^93][^94][^95][^96][^97][^98][^99]</span>

<div align="center">⁂</div>

[^1]: engine.rs

[^2]: renderer-4.rs

[^3]: https://github.com/Chlumsky/msdf-atlas-gen/discussions/28

[^4]: https://developer.apple.com/videos/play/wwdc2023/10127/

[^5]: graph_engine-17.h

[^6]: simulation-5.rs

[^7]: GraphState-14.swift

[^8]: PowerGuard-19.swift

[^9]: https://developer.apple.com/documentation/metal/metal-libraries?language=objc

[^10]: https://developer.apple.com/documentation/Metal/minimizing-the-binary-size-of-a-shader-library

[^11]: https://github.com/Chlumsky/msdf-atlas-gen/discussions

[^12]: https://stackoverflow.com/questions/44927204/how-to-fix-edged-signed-distance-fields-output

[^13]: lib-3.rs

[^14]: https://metalbyexample.com/a-decade-of-metal-early-years/

[^15]: https://stackoverflow.com/questions/55450380/error-when-using-metal-indirect-command-buffer-fragment-shader-cannot-be-used

[^16]: https://www.bu.edu/exafmm/files/2012/02/YunisYokotaAhmadia2012.pdf

[^17]: https://www.ijeat.org/wp-content/uploads/papers/v9i2/B3067129219.pdf

[^18]: forces-2.rs

[^19]: ring-7.rs

[^20]: mod-6.rs

[^21]: HologramOverlay-8.swift

[^22]: MetalGraphView-9.swift

[^23]: GraphEngine-10.swift

[^24]: EmbeddingService-11.swift

[^25]: GraphBuilder-12.swift

[^26]: GraphEngine-13.swift

[^27]: GraphFloatingControls-15.swift

[^28]: HologramController-16.swift

[^29]: EpistemosConfig-18.swift

[^30]: EpistemosConfig-20.swift

[^31]: PowerGuard-21.swift

[^32]: https://arxiv.org/pdf/1605.04614.pdf

[^33]: https://arxiv.org/html/2312.09222v1

[^34]: https://arxiv.org/abs/2302.14859

[^35]: http://arxiv.org/pdf/2410.23218v1.pdf

[^36]: https://arxiv.org/html/2502.17712v1

[^37]: https://arxiv.org/pdf/2206.01791.pdf

[^38]: https://arxiv.org/html/2404.02899

[^39]: https://dl.acm.org/doi/pdf/10.1145/3588432.3591536

[^40]: https://github.com/Chlumsky/msdf-atlas-gen

[^41]: https://www.redblobgames.com/articles/sdf-fonts/

[^42]: https://www.youtube.com/watch?v=eQefdC2xDY4

[^43]: https://www.youtube.com/watch?v=iMuiim9loOg

[^44]: https://metalbyexample.com/rendering-text-in-metal-with-signed-distance-fields/

[^45]: https://tympanus.net/codrops/2024/06/12/shape-lens-blur-effect-with-sdfs-and-webgl/

[^46]: https://www.kodeco.com/books/metal-by-tutorials/v2.0/chapters/15-gpu-driven-rendering

[^47]: https://www.reddit.com/r/opengl/comments/bzh2b4/msdfgl_gpuaccelerated_multichannel_distancefield/

[^48]: https://stackoverflow.com/questions/34563475/sdf-text-rendering-in-perspective-projection

[^49]: https://www.kodeco.com/books/metal-by-tutorials/v3.0/chapters/26-gpu-driven-rendering

[^50]: https://github.com/DJBen/MSDFTextRender-Metal

[^51]: https://www.reddit.com/r/gamedev/comments/kluz4d/using_signed_distance_field_textures_for_sharp/

[^52]: https://developer.apple.com/documentation/metal/indirect-command-encoding

[^53]: https://badecho.com/index.php/2023/09/24/msdf-fonts/

[^54]: https://github.com/ShoYamanishi/SDFont

[^55]: http://arxiv.org/pdf/1009.3457.pdf

[^56]: http://arxiv.org/pdf/1311.1006.pdf

[^57]: https://arxiv.org/pdf/2107.14008.pdf

[^58]: https://arxiv.org/pdf/2411.13055.pdf

[^59]: https://arxiv.org/pdf/1207.2367.pdf

[^60]: https://arxiv.org/pdf/2311.14114.pdf

[^61]: https://arxiv.org/pdf/2205.09682.pdf

[^62]: https://arxiv.org/pdf/2502.05317.pdf

[^63]: https://forums.developer.nvidia.com/t/barnes-hut-cuda-simulation-performance/344140

[^64]: https://arxiv.org/html/2506.02219v1

[^65]: https://www.reddit.com/r/programming/comments/i75hu/gorgeous_description_of_the_barneshut_algorithm/

[^66]: https://www.dgp.toronto.edu/projects/stochastic-barnes-hut/Stochastic_Barnes_Hut.pdf

[^67]: https://nhsjs.com/2024/efficient-numerical-methods-for-n-body-simulations-with-modern-computational-techniques/

[^68]: https://gamedev.net/forums/topic/289699-why-verlet-more-stable-than-euler/

[^69]: https://www.kodeco.com/books/metal-by-tutorials/v3.0/chapters/15-tile-based-deferred-rendering

[^70]: https://www.cs.cmu.edu/~scandal/papers/dimacs-nbody.html

[^71]: https://www.gorillasun.de/blog/euler-and-verlet-integration-for-particle-physics/

[^72]: https://developer.apple.com/videos/play/wwdc2020/10602/

[^73]: https://www.reddit.com/r/Physics/comments/1qxfuhf/20kparticle_nbody_simulation_of_an_exponential/

[^74]: https://barbegenerativediary.com/en/tutorials/verlet-integration/

[^75]: https://developer.apple.com/br/videos/play/wwdc2020/10632/?time=535

[^76]: https://www.linkedin.com/posts/sachdvipu_cuda-highperformancecomputing-computationalphysics-activity-7197543932879155200-G4nY

[^77]: https://www.cs.rpi.edu/~cutler/classes/advancedgraphics/F05/assignments/final_projects/mccarj7/index.html

[^78]: https://arxiv.org/html/2406.08392v1

[^79]: https://arxiv.org/html/2405.14580v3

[^80]: https://arxiv.org/html/2407.02430

[^81]: https://arxiv.org/html/2407.02445v1

[^82]: https://arxiv.org/pdf/2303.12675.pdf

[^83]: https://folk.computer/guides/createafont

[^84]: https://www.redblobgames.com/x/2403-distance-field-fonts/

[^85]: https://www.reddit.com/r/gamedev/comments/fgas6v/msdfatlasgen_new_free_tool_for_generating_font/

[^86]: https://github.com/grovesNL/glyphon/discussions/51

[^87]: https://blog.pkh.me/p/47-text-rendering-and-effects-using-gpu-computed-distances.html

[^88]: https://jvm-gaming.org/t/solved-signed-distance-field-fonts-look-crappy-at-small-pt-sizes/49617

[^89]: https://www.youtube.com/watch?v=J2Fe6wUcXpo

[^90]: https://arxiv.org/abs/2406.19859

[^91]: https://www.int-arch-photogramm-remote-sens-spatial-inf-sci.net/XLVI-4-W2-2021/51/2021/isprs-archives-XLVI-4-W2-2021-51-2021.pdf

[^92]: https://arxiv.org/pdf/2312.10540.pdf

[^93]: https://www.youtube.com/watch?v=OI1uGNhdnmA

[^94]: https://github.com/Chlumsky/msdf-atlas-gen/discussions/30

[^95]: https://developer.apple.com/la/videos/play/wwdc2020/10631/?time=880

[^96]: https://www.themoonlight.io/en/review/stochastic-barnes-hut-approximation-for-fast-summation-on-the-gpu

[^97]: https://www.redblobgames.com/x/2437-msdfgen-parameters/

[^98]: https://conan.io/center/recipes/msdf-atlas-gen

[^99]: https://www.michaelstinkerings.org/apple-m5-gpu-roofline-analysis/

[^100]: https://stackoverflow.com/questions/52210831/text-rendering-in-metal

[^101]: https://developer.apple.com/videos/play/wwdc2020/10632/

[^102]: https://arxiv.org/pdf/2502.13862.pdf

[^103]: https://dl.acm.org/doi/pdf/10.1145/3613424.3614248

[^104]: https://arxiv.org/html/2502.18403v1

[^105]: https://arxiv.org/pdf/1501.05387.pdf

[^106]: http://arxiv.org/pdf/1708.04701.pdf

[^107]: https://arxiv.org/pdf/2306.17801.pdf

[^108]: https://arxiv.org/pdf/2501.09398.pdf

[^109]: http://arxiv.org/pdf/2412.09337.pdf

[^110]: https://developer.apple.com/documentation/metal/improving-cpu-performance-by-using-argument-buffers

[^111]: https://www.reddit.com/r/GraphicsProgramming/comments/1puhaeo/vulkan_what_is_the_performance_difference_between/

[^112]: https://github.com/gpuweb/gpuweb/issues/2189

[^113]: https://community.khronos.org/t/gpu-vertex-dispatch-for-multidrawindirect-and-or-instanced-draw-calls/77308

[^114]: https://www.gamedev.net/forums/topic/664183-gldrawelementsinstanced-vs-gldrawelementsindirect/

[^115]: https://stackoverflow.com/questions/32298719/manually-compile-metal-shaders

[^116]: https://developer.apple.com/la/videos/play/wwdc2023/10127/

[^117]: https://metalbyexample.com/instanced-rendering/

[^118]: https://discuss.tvm.apache.org/t/tvm-fails-to-compile-metal-lib-on-macos-due-to-version/9515

[^119]: https://stackoverflow.com/questions/74630753/poor-performance-in-metal-drawing-app-when-render-more-than-4000-strokes

[^120]: https://juniperphoton.substack.com/p/pitfalls-and-solutions-when-building

[^121]: https://www.mdpi.com/2079-9292/12/7/1561/pdf?version=1679819718

[^122]: https://arxiv.org/html/2412.00136

[^123]: http://arxiv.org/pdf/2502.00250.pdf

[^124]: http://arxiv.org/pdf/2502.11399.pdf

[^125]: http://arxiv.org/pdf/2403.16964.pdf

[^126]: https://www.redblobgames.com/blog/2026-02-26-writing-a-guide-to-sdf-fonts/

[^127]: https://www.facebook.com/groups/shadertoy/posts/737510490163313/

[^128]: https://www.youtube.com/watch?v=KLOGaHgo2GY

[^129]: https://www.youtube.com/watch?v=oFmkT09lJIo

[^130]: https://halisavakis.com/my-take-on-shaders-radial-blur/

[^131]: https://www.youtube.com/watch?v=0nEY6h9fcVk

[^132]: https://developer.nvidia.com/gpugems/gpugems3/part-iv-image-effects/chapter-28-practical-post-process-depth-field

[^133]: https://snowb.org/en/docs/font-design/sdf-rendering/

[^134]: https://github.com/MiniMax-AI/skills/blob/main/skills/shader-dev/techniques/camera-effects.md

[^135]: https://github.com/chlumsky/msdfgen

[^136]: https://www.reddit.com/r/Unity3D/comments/96qndg/new_shader_tutorial_on_a_radial_blur_image_effect/

[^137]: https://arxiv.org/pdf/1704.05316.pdf

[^138]: http://arxiv.org/pdf/2411.05491.pdf

[^139]: https://arxiv.org/pdf/2204.13719.pdf

[^140]: https://dl.acm.org/doi/pdf/10.1145/3640537.3641580

[^141]: https://arxiv.org/pdf/1903.06498.pdf

[^142]: https://arxiv.org/pdf/2503.00408.pdf

[^143]: https://arxiv.org/pdf/2311.07422.pdf

[^144]: https://dl.acm.org/doi/pdf/10.1145/3578245.3585025

[^145]: https://huggingface.co/datasets/Kubermatic/stackoverflow_QAs

[^146]: https://towardsdatascience.com/programming-apple-gpus-through-go-and-metal-shading-language-a0e7a60a3dba/

[^147]: http://kahrstrom.com/gamephysics/2011/08/03/euler-vs-verlet/

[^148]: https://www.embeddedrelated.com/showarticle/474.php

[^149]: https://themaister.net/blog/2020/08/30/compressed-gpu-texture-formats-a-review-and-compute-shader-decoders-part-2/

[^150]: https://www.reingold.co/force-directed.pdf

[^151]: https://developer.apple.com/metal/Metal-Feature-Set-Tables.pdf

[^152]: https://aras-p.info/blog/2021/01/18/Texture-Compression-on-Apple-M1/

[^153]: https://itnext.io/d3-force-directed-graph-forces-experiments-for-dummies-20a5682935

[^154]: https://www.ludicon.com/castano/blog/2026/01/choosing-texture-formats-for-webgpu-applications/

[^155]: http://hplgit.github.io/num-methods-for-PDEs/doc/pub/vib/pdf/vib-4screen.pdf

[^156]: https://developer.apple.com/documentation/metal/mtlpixelformat/bc7_rgbaunorm_srgb

[^157]: https://natureofcode.com/physics-libraries/

[^158]: https://ieeexplore.ieee.org/document/10820815/

[^159]: https://ieeexplore.ieee.org/document/11342682/

[^160]: https://ieeexplore.ieee.org/document/9798812/

[^161]: https://dl.acm.org/doi/10.1145/3727505.3727527

[^162]: https://ieeexplore.ieee.org/document/10181734/

[^163]: http://link.springer.com/10.1007/s11265-016-1216-4

[^164]: https://link.springer.com/10.1007/s42514-023-00155-x

[^165]: http://ieeexplore.ieee.org/document/7013051/

[^166]: https://dl.acm.org/doi/10.14778/3425879.3425883

[^167]: https://dl.acm.org/doi/10.1145/3631882.3631898

[^168]: http://arxiv.org/pdf/1203.2946.pdf

[^169]: https://arxiv.org/pdf/1203.5737.pdf

[^170]: https://arxiv.org/pdf/1503.05032.pdf

[^171]: http://downloads.hindawi.com/journals/mpe/2016/8471283.pdf

[^172]: https://arxiv.org/pdf/2311.14650.pdf

[^173]: http://downloads.hindawi.com/journals/mpe/2016/4596943.pdf

[^174]: https://arxiv.org/pdf/1904.02241.pdf

[^175]: https://dl.acm.org/doi/pdf/10.1145/3673038.3673129

[^176]: https://www.sciencedirect.com/science/article/abs/pii/S0743731523000357

[^177]: https://itshelenxu.github.io/files/papers/pcsr.pdf

[^178]: https://www.vldb.org/pvldb/vol18/p4255-gan.pdf

[^179]: https://arxiv.org/html/2311.14650v3

[^180]: https://people.cs.vt.edu/yongcao/publication/pdf/chao13_i3d.pdf

[^181]: https://docs.nvidia.com/gameworks/content/technologies/mobile/gles2_perf_fragment.htm

[^182]: https://www.osti.gov/servlets/purl/2498445

[^183]: https://www.youtube.com/watch?v=TmTpxja5KWk

[^184]: https://devstreaming-cdn.apple.com/videos/wwdc/2016/606oluchfgwakjbymy8/606/606_advanced_metal_shader_optimization.pdf?dl=1

[^185]: https://users.cs.utah.edu/~kirby/Publications/dynamic-csr.pdf

[^186]: https://www.tandfonline.com/doi/full/10.1080/10106049.2026.2614146

[^187]: https://developer.apple.com/videos/play/wwdc2016/606/

[^188]: https://isprs-archives.copernicus.org/articles/XLVIII-4-W14-2025/143/2025/isprs-archives-XLVIII-4-W14-2025-143-2025.pdf

[^189]: https://github.com/gpuweb/gpuweb/issues/361

[^190]: https://arxiv.org/pdf/2110.06688.pdf

[^191]: https://arxiv.org/pdf/2104.03064.pdf

[^192]: http://arxiv.org/pdf/2403.06453.pdf

[^193]: https://news.ycombinator.com/item?id=42093037

[^194]: https://www.metal.graphics/chapter8_distance_fields

[^195]: https://github.com/Chlumsky/msdf-atlas-gen/discussions/47

[^196]: https://www.kodeco.com/books/metal-by-tutorials/v3.0/chapters/7-the-fragment-function

[^197]: https://webgpu.github.io/webgpu-samples/?sample=textRenderingMsdf

[^198]: https://www.youtube.com/watch?v=d8cfgcJR9Tk

[^199]: https://arxiv.org/pdf/2501.14925.pdf

[^200]: https://arxiv.org/pdf/2101.11049.pdf

[^201]: http://arxiv.org/pdf/1801.08058.pdf

[^202]: https://arxiv.org/pdf/2208.13707.pdf

[^203]: https://developer.apple.com/documentation/metal/mtlindirectcommandbuffer

[^204]: https://www.reddit.com/r/GraphicsProgramming/comments/1qn2c0y/what_would_the_performance_difference_look_like/

[^205]: https://www.reddit.com/r/vulkan/comments/1fy9p80/fully_gpu_driven_bindless_indirect_draw_calls/

[^206]: https://mgarland.org/files/papers/layoutgpu.pdf

[^207]: https://developer.apple.com/videos/play/wwdc2023/10127/?time=128

[^208]: https://developer.apple.com/documentation/metal/specifying-drawing-and-dispatch-arguments-indirectly

[^209]: https://github.com/zed-industries/zed/discussions/7016

[^210]: https://arxiv.org/pdf/2211.00720.pdf

[^211]: https://arxiv.org/pdf/1807.09449.pdf

[^212]: https://arxiv.org/pdf/2404.06156.pdf

[^213]: https://arxiv.org/pdf/2202.10533.pdf

[^214]: https://arxiv.org/pdf/2109.06132.pdf

[^215]: https://developer.apple.com/documentation/metal/tailor_your_apps_for_apple_gpus_and_tile-based_deferred_rendering?changes=_7\&language=objc

[^216]: https://developer.apple.com/documentation/metal/tailor-your-apps-for-apple-gpus-and-tile-based-deferred-rendering

[^217]: https://www.youtube.com/watch?v=il-TXbn5iMA

[^218]: https://nonstrict.eu/wwdcindex/tech-talks/10859/

[^219]: https://developer.nvidia.com/gpugems/gpugems3/part-v-physics-simulation/chapter-34-signed-distance-fields-using-single-pass-gpu

[^220]: https://stackoverflow.com/questions/2769466/why-is-verlet-integration-better-than-euler-integration

[^221]: https://developer.apple.com/la/videos/play/wwdc2021/10153/

[^222]: https://www.reddit.com/r/GraphicsProgramming/comments/1q6nmtr/game_engine_based_on_dynamic_signed_distance/

[^223]: http://arxiv.org/pdf/2304.05587.pdf

[^224]: https://arxiv.org/pdf/2006.06890.pdf

[^225]: https://arxiv.org/pdf/2203.05096.pdf

[^226]: https://stackoverflow.com/questions/32900522/compressed-sparse-row-matrix-vs-adjacency-list

[^227]: https://unbreakablebonds101.wordpress.com/2025/02/10/the-gold-standard-edge-lists-are-preferred-in-99-of-graphs-over-adjacency-matrices-for-network-analyses/

[^228]: https://www.usenix.org/system/files/login/articles/login_winter20_16_kelly.pdf

[^229]: https://vldb.org/pvldb/vol14/p114-min.pdf

[^230]: https://github.com/Chlumsky/msdf-atlas-gen/issues/2

[^231]: https://research.nvidia.com/sites/default/files/pubs/2011-08_High-Performance-and/BFS%20TR.pdf

[^232]: https://www.redblobgames.com/blog/2024-08-27-sdf-font-outlines/

[^233]: https://webpages.charlotte.edu/ddai/data/dong-ccgrid-22.pdf

[^234]: https://www.redblobgames.com/blog/2024-12-08-sdf-halos/

[^235]: https://swiftpackageindex.com/AdaEngine/msdf-atlas-gen

[^236]: https://arxiv.org/pdf/2108.08593.pdf

[^237]: https://arxiv.org/pdf/1912.07109.pdf

[^238]: https://arxiv.org/html/2411.15468v1

[^239]: https://arxiv.org/pdf/2310.09463.pdf

[^240]: https://arxiv.org/pdf/2308.11408.pdf

[^241]: https://arxiv.org/abs/2212.03293

[^242]: https://arxiv.org/html/2409.16178v2

[^243]: https://www.reddit.com/r/vulkan/comments/1jj2xea/how_to_handle_text_efficiently/

[^244]: https://www.youtube.com/watch?v=J26hm7r-k6A

[^245]: https://arxiv.org/html/2412.07766

[^246]: https://arxiv.org/pdf/2303.14017.pdf

[^247]: https://arxiv.org/pdf/2303.11396.pdf

[^248]: http://arxiv.org/pdf/2405.14025.pdf

[^249]: https://arxiv.org/html/2403.02460v2

[^250]: https://www.irjmets.com/upload_newfiles/irjmets71100109845/paper_file/irjmets71100109845.pdf

[^251]: https://shashankshekhar.com/blog/apple-metal-vs-nvidia-cuda

[^252]: https://github.com/philipturner/metal-benchmarks

[^253]: https://joss.theoj.org/papers/10.21105/joss.05165.pdf

[^254]: https://arxiv.org/pdf/2305.13241.pdf

[^255]: https://arxiv.org/pdf/2311.10800.pdf

[^256]: https://linkinghub.elsevier.com/retrieve/pii/S2352711018300426

[^257]: http://arxiv.org/pdf/2011.03516v1.pdf

[^258]: https://arxiv.org/pdf/2304.14908.pdf

[^259]: https://www.reddit.com/r/GraphicsProgramming/comments/1g588j8/apple_metal_shader_compilation_time/

[^260]: https://github.com/google/filament/discussions/8940

[^261]: https://tomroth.dev/fdg-basics/

[^262]: https://github.com/scalameta/metals/issues/5334

[^263]: https://github.com/libsdl-org/SDL_shadercross/issues/39

[^264]: https://twosixtech.com/blog/faster-force-directed-graph-layouts-by-reusing-force-approximations/

