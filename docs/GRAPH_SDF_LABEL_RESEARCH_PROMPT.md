# Graph SDF Label System — Deep Research Prompt
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
