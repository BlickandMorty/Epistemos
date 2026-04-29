# Simulation Mode — Implementation Plan

> **Status:** CANONICAL build plan, reconciled against `DOCTRINE.md` v1.0.
> **Authority:** `DOCTRINE.md` is truth. This file is the build path that produces it. If they conflict, the doctrine wins; this file is wrong and gets fixed.
> **Worktree:** `simulation` (this branch). Land slices to `main` only after acceptance gates pass.
> **Doctrine version reconciled against:** 1.6
> **Plan version:** 1.6
> **Plan v1.6 changes:** absorbed DOCTRINE v1.6 expansion (§3.2.1 farm-game cosmetic random walking; §3.2.2 working badge + inline dispatch chat + steering on the farm; §3.3.1 multi-room theater — one room per active session, single MTKView with viewport tiling for performance; §3.3.2 graph as full chat replacement; §3.4.1 persistent vault hierarchy from Model down; §3.4.2 multi-toggle sidebar with display-tree decoupled from active workspace; §3.4.3 knowledge-brick design language for the sidebar; §3.4.4 multi-vault UI affordances; §3.4.5 helper-model summariser via ConfidenceRouter; §11 v1.6 six new AgentEvent variants — SteerRequested, SummaryStarted/Delta/Completed, VaultCreated, VaultArchived). **Affected slices:** S5 (already shipped; walk implementation lands as a follow-up commit or rolls into S10 polish — Rust reducer state already supports `IDLE_AMBIENT` flag); S6 (Notes Sidebar) now reads against §3.4 + §3.4.1 through §3.4.5 — multi-toggle picker UI, per-entity nested vault trees, persistent on-disk vault layout, knowledge-brick design language, multi-vault UI affordances, and helper-model summariser pipe; S7 (Graph Live Theater) now reads against §3.3 + §3.3.1 + §3.3.2 — multi-room viewport tiling on a single MTKView, full-chat replacement role; S8 (creation flow) gains the §3.4.4 inline `New vault…` sheet pattern; S9 (Hermes graph faculty) inherits the multi-room model when Hermes is in any active session. **No invariant changes.** All performance budgets from §12 hold: per-frame budget ≤ 5 ms p99 holds at N rooms because pipeline / atlas / sampler are shared across rooms, only viewport + camera + buffer-region differ.
> **Plan v1.4 changes:** absorbed DOCTRINE §3.4 v1.4 (three-level Company → Model → Agent picker), §8.2 v1.4 (opulent canonical Hermes landing ritual: 7-phase sequence, canonical NousResearch sources, gold halo additive pulse, ASCII portrait), §10.4 + §10.7 v1.4 (added `branding/hermes-agent-pixel/` and `ascii/` directories; hermes-agent dual-sourced). Added Slice S5.7 (Hermes canonical assets fetcher + landing ritual integration). Updated S5.6 acceptance to require three-level picker. Updated S9 (Hermes graph faculty) to consume canonical assets and implement the opulent ritual. New asset directory `Resources/CompanionAssets/ascii/` (text-based ASCII art; not subject to I-16). New additive-pass effect textures `effects/halo_hermes_gold.png` and `effects/glare_hermes.png`. New script `Tools/branding_pipeline/fetch_hermes_canonical.py` (read-only probe of NousResearch/hermes-agent + joeynyc/hermes-skins + NousResearch/brand + NousResearch/assets).
> **Plan v1.3 changes:** absorbed DOCTRINE §10.7 (Provider Brand Icon System) and §3.4 v1.3 update (Companions picker). Added Slice S5.6 (Provider brand icon fetcher + integration: LobeHub fetch script `Tools/branding_pipeline/fetch_lobe_icons.py`, color/mono Swift consumers, sidebar Companions picker, settings provider rows, chat-header chips). Updated `Tools/branding_pipeline/validate.py` (Slice S5.5) to branch by `provenance.json` `"category"` flag — `pixel-art-mascot` enforces I-16 stepped vectors, `smooth-vector-brand` skips path-command checks. Updated §2.3 pipeline-split table with provider-icon row. Forbidden-patterns table updated with explicit carve-out: `.interpolation(.high)` is allowed for `branding/<smooth>/` SVGs and forbidden for `branding/<pixel-art>/` SVGs. Reconciliation map updated.
> **Plan v1.2 changes:** absorbed DOCTRINE I-16 + §5.7 (bit-perfect pixel rendering). Added §2.4.1 (sampler/scale/snap rules with Metal + Swift code). Updated S4 acceptance to verify nearest-neighbor sampling, MSAA off, integer scale, snap-to-pixel; added halo additive-pass acceptance. Updated S5.5 SVG validator to reject `<circle>`, `<ellipse>`, `C/S/Q/T/A` path commands and non-integer coordinates. Updated S10 atlas authoring to require stepped halo textures (no runtime blur). Forbidden-patterns table extended with linear sampler, MSAA, Bezier branding paths, mipmaps, fractional scale, sub-pixel scroll. Pre-merge ritual sweep extended.
> **Plan v1.1 changes:** added Slice S5.5 (SVG branding pipeline) reflecting DOCTRINE §5.6 + §10.6; updated S10 scope to clarify it is the *animated raster atlas* pipeline only; updated §2.3 with SVG/Metal pipeline split; reconciliation map updated.

---

## 0. How to use this document

Each slice (S0–S14) is a self-contained build unit with:

- **Goal** — one paragraph; what this slice accomplishes.
- **Doctrine refs** — which invariants and sections of DOCTRINE.md it satisfies.
- **Files touched** — the surface this slice modifies.
- **Architecture choice** — multiple options analyzed; the recommended zero-copy native pick called out explicitly.
- **Code snippets** — concrete, idiomatic, native-first.
- **Acceptance criteria** — testable conditions; if any fail, the slice is incomplete.
- **Verification commands** — paste-and-run.
- **Anti-drift checks** — `rg` invocations that should return empty if the slice is clean.
- **Non-goals** — explicit.

Slices land in order. Skipping ahead is forbidden — each slice depends on the substrate the prior slice built. If a slice exposes a flaw in the doctrine, fix the doctrine first, then re-plan affected slices.

---

## 1. Phasing Overview

| Phase | Slices | Outcome |
|---|---|---|
| **V0 — Substrate** | S0–S4 | Rust reducer + companion registry + event log + placeholder Metal renderer. No real sprites; just colored rectangles. End-to-end pipeline runs deterministically. |
| **V1 — Three Placements** | S5–S7 | Landing Farm + Sidebar Skin + Graph Live Theater all working with placeholder geometry. The full visual architecture is buildable end-to-end. |
| **V2 — Real Companions** | S8–S10 | Creation flow with 3 head shapes; real pixel-art assets generated through the pipeline; Hermes graph faculty wired through MCP; landing transformation ritual working. |
| **V3 — Adapters & Mechanics** | S11–S13 | Adapter gift-box; subagent/handoff visual events; replay/scrub timeline; Deep Deliberation visual integration begins. |
| **V4 — Polish & Release** | S14 | Reduce-motion, accessibility, performance gating, MAS profile validation. |

Roughly: V0–V1 = ~2 sprints (foundational); V2 = ~2 sprints (the "wow" moment); V3–V4 = ~2 sprints (depth).

---

## 2. Cross-cutting Architecture Decisions

These apply across all slices. Each lists multiple options analyzed; the **chosen path** is the canonical one. Other options are listed so future implementers understand why we picked what we picked.

### 2.1 Reducer architecture

**Options analyzed:**

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **A. Custom Rust event-sourced reducer (FSM per agent)** | Pure function, deterministic, trivial to test, ≤1ms per event, no runtime/scheduler overhead, replay-friendly. | Need to hand-write state machine; must maintain enum exhaustiveness. | **CHOSEN** for V0–V2. |
| **B. `bevy_ecs` (ECS crate only, no Bevy app)** | Mature ECS query system; handy if entity count or system composition explodes. | Adds a dependency; ECS scheduler not aligned with our event-sourced model; impedance with async event ingestion; over-abstracts ≤50-entity simulation. | Hold for V3+ if needed. |
| **C. Actor-based (each companion is a tokio actor)** | Natural for async; easy parallelism. | Coordination cost; non-deterministic without strict ordering; harder replay. | Rejected. |
| **D. Redux-style with hooks/middleware** | Familiar patterns. | Reinventing what a pure FSM gives us; more allocation. | Rejected. |

**Chosen: A.** A pure `fn reduce(state: &mut SimulationState, event: AgentEvent) -> Vec<FrameDelta>` reducer. Deterministic. Testable. Zero runtime cost when idle. Replay is just `events.iter().fold(initial_state, reduce)`.

The reducer is **single-threaded** and lives on a dedicated tokio task. Events come in through a `tokio::sync::broadcast` channel from provider streams; deltas go out through a `crossbeam::channel::bounded(256)` to the FFI layer. Backpressure is `bufferingNewest` semantics: if the FFI consumer is slow, intermediate position deltas are coalesced (newest-wins per companion); state-changing deltas (animation state transitions, spawns, errors) are NEVER coalesced (always preserved).

```rust
// crates/agent_core/src/simulation/reducer.rs

use crate::events::{AgentEvent, FrameDelta};
use crate::simulation::state::{SimulationState, AgentVisualState, AnimationState};

/// Pure reducer. Determines new state and produces frame deltas.
/// Forbidden inside this function: Date::now(), arc4random, thread_rng, SystemTime,
/// any I/O, any allocation outside the deltas Vec. (See DOCTRINE I-13.)
pub fn reduce(state: &mut SimulationState, event: AgentEvent) -> Vec<FrameDelta> {
    let mut deltas = Vec::with_capacity(4);
    match event {
        AgentEvent::ParticipantJoined { agent_id, role } => {
            let visual = AgentVisualState::initial_for_role(role);
            state.agents.insert(agent_id, visual);
            deltas.push(FrameDelta::AgentEntered { agent_id, visual });
        }
        AgentEvent::ThinkingStarted { agent_id, .. } => {
            if let Some(agent) = state.agents.get_mut(&agent_id) {
                agent.transition_to(AnimationState::Think);
                deltas.push(FrameDelta::AgentAnimation { agent_id, state: AnimationState::Think });
            }
        }
        AgentEvent::ToolCallStarted { agent_id, tool_name, .. } => {
            if let Some(agent) = state.agents.get_mut(&agent_id) {
                agent.transition_to(AnimationState::Tool);
                agent.held_prop = Some(tool_to_prop(&tool_name));
                deltas.push(FrameDelta::AgentAnimation { agent_id, state: AnimationState::Tool });
                deltas.push(FrameDelta::AgentProp { agent_id, prop: agent.held_prop });
            }
        }
        AgentEvent::SubagentSpawned { parent_id, child_id, count } => {
            if let Some(parent) = state.agents.get(&parent_id) {
                let parent_pos = parent.position;
                state.agents.insert(child_id, AgentVisualState::subagent_of(parent, count));
                deltas.push(FrameDelta::SubagentSpawned {
                    parent_id, child_id, parent_pos, count
                });
            }
        }
        AgentEvent::AwaitingApproval { agent_id, action, deadline_ms } => {
            if let Some(agent) = state.agents.get_mut(&agent_id) {
                agent.transition_to(AnimationState::Gate);
                agent.gate = Some(GateInfo { action, deadline_ms });
                deltas.push(FrameDelta::ApprovalGate { agent_id, deadline_ms });
            }
        }
        AgentEvent::CompanionActivityStateChanged { companion_id, from, to } => {
            // Activity state transitions update farm/sidebar/theater visibility.
            deltas.push(FrameDelta::ActivityState { companion_id, from, to });
        }
        // ... (exhaustive matching: every AgentEvent variant must be handled or
        //      explicitly noted as no-op)
        _ => {}
    }
    deltas
}

fn tool_to_prop(tool_name: &str) -> PropKind {
    match tool_name {
        s if s.starts_with("code_") || s == "git" => PropKind::Wrench,
        s if s.starts_with("graph.search") || s == "web_search" => PropKind::Magnifier,
        s if s.starts_with("graph.create_") || s == "note_create" => PropKind::Scroll,
        "vault_read" | "vault_write" => PropKind::Folder,
        _ => PropKind::Lantern,
    }
}
```

### 2.2 FFI bridge — three-tier strategy

**Options analyzed:**

| Option | When to use | Pros | Cons |
|---|---|---|---|
| **A. UniFFI for control calls** | low-frequency commands (create companion, switch workspace, unwrap gift box) | great ergonomics, async support, generated bindings | per-call serialization cost; not suitable for >100 Hz |
| **B. Lock-free SPSC ring buffer for hot deltas** | high-frequency frame deltas | zero-copy, no syscalls in steady state | needs careful lifetime/ownership; one writer, one reader |
| **C. IOSurface for texture data** | atlas textures, frame buffers | true GPU-shareable zero-copy across processes | macOS-specific (which is fine); careful lifecycle |
| **D. Protocol Buffers / FlatBuffers / rkyv over a single channel** | uniform serialization | single code path | adds a serialization tax to hot paths; not as fast as raw shared memory |

**Chosen: hybrid A + B + C.**

- Control calls (companion creation, customization edits, gift-box unwrap, Hermes mode toggle) → **UniFFI**.
- Per-frame deltas (sprite positions, animation frame indices, props, palette tints) → **SPSC ring buffer**, zero-copy, written by Rust reducer, read by Swift Metal renderer once per `MTKViewDelegate` draw call.
- Sprite atlas textures → **IOSurface-backed** `MTLTexture`. Asset pipeline writes into IOSurface from Rust at app startup; Swift wraps IOSurface as `MTLTexture` and binds it for the lifetime of the app.

Code: SPSC ring buffer skeleton in Rust:

```rust
// crates/agent_core/src/ffi/delta_ring.rs

use crossbeam_queue::ArrayQueue;
use std::sync::Arc;

#[repr(C)]
#[derive(Copy, Clone)]
pub struct PerInstanceData {
    pub agent_id_lo: u64,           // ULID low 64 bits
    pub agent_id_hi: u64,           // ULID high 64 bits
    pub position: [f32; 2],         // x, y in scene units
    pub scale: [f32; 2],
    pub atlas_index: u32,           // which 2D slice of texture array
    pub frame_index: u32,           // which frame in the animation rig
    pub palette_id: u32,
    pub tint: [f32; 4],             // RGBA
    pub state_flags: u32,           // bit-packed: gate=1, error=2, idle_ambient=4, ...
    pub _padding: u32,              // align to 64 bytes
}
const _: () = assert!(std::mem::size_of::<PerInstanceData>() == 64);

pub struct DeltaRing {
    queue: Arc<ArrayQueue<PerInstanceData>>,
}

impl DeltaRing {
    pub fn new(capacity: usize) -> Self {
        Self { queue: Arc::new(ArrayQueue::new(capacity)) }
    }
    /// Producer: rust reducer side. Push or coalesce-and-overwrite-newest-by-agent.
    pub fn push(&self, delta: PerInstanceData) {
        // Coalesce: if queue has an entry for the same agent_id, replace it.
        // (Implementation detail: we use a small drained pass; for V0 simplicity
        // we accept O(N) coalesce; V1 upgrades to per-agent slot map.)
        // ...
        let _ = self.queue.push(delta); // overwrites oldest if full
    }
    /// Consumer: Swift Metal renderer drains via FFI per frame.
    pub fn drain_into(&self, buffer: &mut [PerInstanceData]) -> usize {
        let mut n = 0;
        while n < buffer.len() {
            match self.queue.pop() {
                Some(d) => { buffer[n] = d; n += 1; }
                None => break,
            }
        }
        n
    }
}

// FFI exports (raw C ABI for lowest overhead; UniFFI is overkill for hot path).
#[no_mangle]
pub unsafe extern "C" fn epistemos_delta_ring_drain(
    ring: *const DeltaRing,
    out_buffer: *mut PerInstanceData,
    capacity: usize,
) -> usize {
    let ring = unsafe { &*ring };
    let buffer = unsafe { std::slice::from_raw_parts_mut(out_buffer, capacity) };
    ring.drain_into(buffer)
}
```

Swift side:

```swift
// Epistemos/Simulation/DeltaRingBridge.swift

import Metal

actor DeltaRingBridge {
    private let ringHandle: OpaquePointer  // *const DeltaRing from Rust
    private let instanceBuffer: MTLBuffer  // pre-allocated, persistent-mapped
    private let capacity: Int

    init(ringHandle: OpaquePointer, device: MTLDevice, capacity: Int = 256) {
        self.ringHandle = ringHandle
        self.capacity = capacity
        self.instanceBuffer = device.makeBuffer(
            length: capacity * MemoryLayout<PerInstanceData>.stride,
            options: [.storageModeShared]
        )!
    }

    /// Called once per draw, off the main actor.
    nonisolated func drain() -> Int {
        let ptr = instanceBuffer.contents()
            .bindMemory(to: PerInstanceData.self, capacity: capacity)
        return epistemos_delta_ring_drain(ringHandle, ptr, capacity)
    }

    nonisolated var buffer: MTLBuffer { instanceBuffer }
}
```

This is **zero-copy** end-to-end: Rust writes `PerInstanceData` into the ring; Swift drains directly into a `MTLBuffer.contents()` pointer; the GPU reads that buffer in the next vertex shader invocation. No serialization, no allocation, no copy.

### 2.3 Rendering pipeline split — SVG via SwiftUI vs raster atlas via Metal

Per DOCTRINE §5.6 + §10.7, **three** rendering pipelines run in parallel and never cross-pollute:

| Pipeline | Asset shape | Rendered by | Smoothing | Bound by I-16? | Examples |
|---|---|---|---|---|---|
| **A. Pixel-art SVG branding** | stepped vectors, integer coords, only M/L/H/V/Z commands | SwiftUI `Image` / `NSImage` with `imageInterpolation = .none`, `.interpolation(.none)`, `.antialiased(false)` | NONE (bit-perfect) | YES | Claude Code mascot SVG, Claude Code pixel wordmark, V1 sidebar mascot pin |
| **B. Smooth-vector provider icons** | Bezier curves, gradients, multi-fill (LobeHub source) | SwiftUI `Image` with `.interpolation(.high)`, `.antialiased(true)` | DEFAULT (smooth) | NO (carved out) | Anthropic logo, OpenAI mark, Gemini glyph, Hermes Agent caduceus, Apple, GitHub |
| **C. Raster atlas (Metal)** | hand-authored pixel-art frames | Metal `MTLTexture` array + instanced quads | NONE (bit-perfect) | YES | Animated theater sprites, speech bubbles, props, gates, particles |

Disambiguation rule: read the provider directory's `provenance.json`. If `"category": "pixel-art-mascot"` → pipeline A. If `"category": "smooth-vector-brand"` → pipeline B. If the asset is in `atlas/` → pipeline C. Validator branches on the same flag (Slice S5.5). Mixing the rules in either direction is drift.

The sidebar mascot pin is the one ambiguous case: V1 ships it as SVG static (pipeline A for pixel-art mascots, pipeline B for provider-derived companions); V2 promotes it to Metal MTKView for idle animation when the workspace companion is `Active`.

### 2.4 Metal rendering — instanced quads + texture array + IOSurface + bit-perfect (DOCTRINE I-16)

#### 2.4.1 Sampler, scale, snap — the bit-perfect contract

Per DOCTRINE I-16 + §5.7, the renderer is **strictly nearest-neighbor with integer scale and pixel-snapped positions**. This is the visual contract — the user-supplied Kimi orb is the reference: stepped silhouette, sharp eyes, soft halo as a *separate quad*.

**Sampler — exact configuration (Swift):**

```swift
// Epistemos/Simulation/MetalSimulationRenderer.swift — at init
let samplerDesc = MTLSamplerDescriptor()
samplerDesc.minFilter = .nearest      // I-16: forbidden to be .linear
samplerDesc.magFilter = .nearest
samplerDesc.mipFilter = .notMipmapped  // sprites must not have mipmaps
samplerDesc.sAddressMode = .clampToEdge
samplerDesc.tAddressMode = .clampToEdge
self.spriteSampler = device.makeSamplerState(descriptor: samplerDesc)!
```

**MSAA — off for sprite passes:**

```swift
view.sampleCount = 1                  // I-16: any value > 1 is forbidden on sprite passes
view.colorPixelFormat = .bgra8Unorm   // not .bgra8Unorm_srgb (no gamma re-encoding for sharp pixels)
view.framebufferOnly = true
```

**Snap-to-pixel — vertex shader rounds positions to physical pixels:**

```metal
// Companion.metal — vertex transform with snap
struct Camera {
    float2 viewport_size;       // physical pixels
    float pixel_density;        // 1.0 for 1x, 2.0 for Retina @2x, 3.0 for @3x
    float2 view_offset;
};

vertex VertexOut companion_vertex(
    VertexIn vin [[stage_in]],
    uint instance_id [[instance_id]],
    constant PerInstanceData* instances [[buffer(1)]],
    constant Camera& camera [[buffer(2)]]
) {
    PerInstanceData inst = instances[instance_id];

    // Integer-scale only: inst.scale is restricted to {1, 2, 3, 4} per I-16.
    // Validation happens on the Rust side before the delta crosses FFI.
    float2 world = vin.position * inst.scale + inst.position - camera.view_offset;

    // Snap to physical pixel grid. This is the I-16 snap rule.
    float2 snapped = round(world * camera.pixel_density) / camera.pixel_density;

    // Convert to clip space.
    float2 ndc = (snapped / camera.viewport_size) * 2.0 - 1.0;
    ndc.y = -ndc.y;

    VertexOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.uv = computeAtlasUV(vin.uv, inst.frame_index, inst.atlas_index);
    out.atlas_index = inst.atlas_index;
    out.palette_id = inst.palette_id;
    out.tint = inst.tint;
    return out;
}
```

**Integer-scale validation (Rust side, before FFI):**

```rust
// crates/agent_core/src/simulation/state.rs
impl AgentVisualState {
    pub fn snapshot_for_render(&self) -> PerInstanceData {
        // Hard-clamp scale to integer; debug build asserts the source was already integer.
        debug_assert!(
            (self.scale - self.scale.round()).abs() < 1e-6,
            "fractional sprite scale {}: violates I-16",
            self.scale
        );
        PerInstanceData {
            scale: [self.scale.round(), self.scale.round()],
            ..self.snapshot_inner()
        }
    }
}
```

#### 2.4.2 Halo / eye-bloom as separate additive passes

Per DOCTRINE §5.7 and the Kimi orb reference, glow is a *separate quad*, not a blur.

Per active companion the renderer issues up to three quads in this order:

1. **Body** (alpha blend, nearest sampler, atlas slice = body)
2. **Eye-highlight** (additive blend, nearest sampler, atlas slice = `effects/eye_glow.png`) — only when companion is `Active`
3. **Halo** (additive blend, nearest sampler, atlas slice = `effects/halo_active.png`, sized ~1.5× body) — only when companion is `Active`

Pipeline state for the additive passes:

```swift
let additiveDesc = MTLRenderPipelineDescriptor()
additiveDesc.colorAttachments[0].pixelFormat = view.colorPixelFormat
additiveDesc.colorAttachments[0].isBlendingEnabled = true
additiveDesc.colorAttachments[0].rgbBlendOperation = .add
additiveDesc.colorAttachments[0].alphaBlendOperation = .add
additiveDesc.colorAttachments[0].sourceRGBBlendFactor = .one
additiveDesc.colorAttachments[0].destinationRGBBlendFactor = .one
additiveDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
additiveDesc.colorAttachments[0].destinationAlphaBlendFactor = .one
additiveDesc.sampleCount = 1   // I-16
self.haloPipelineState = try device.makeRenderPipelineState(descriptor: additiveDesc)
```

The `effects/halo_active.png` and `effects/eye_glow.png` textures are pre-baked at design time with deliberate radial falloff (stepped, not Gaussian). The renderer never computes blur.

#### 2.4.3 SwiftUI side — branding SVG bit-perfect rules

Branding SVGs render through SwiftUI / NSImage with anti-aliasing **disabled** for the rasterization step:

```swift
// Epistemos/Simulation/Branding/SVGCachedRenderer.swift — bit-perfect rasterization
extension SVGCachedRenderer {
    private func rasterize(_ image: NSImage, at scale: CGFloat) -> NSImage {
        let physicalSize = NSSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(physicalSize.width),
            pixelsHigh: Int(physicalSize.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 32
        )!
        let ctx = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        ctx.imageInterpolation = .none      // I-16: no bilinear
        ctx.shouldAntialias = false         // I-16: no AA
        image.draw(in: NSRect(origin: .zero, size: physicalSize))
        NSGraphicsContext.restoreGraphicsState()
        let output = NSImage(size: physicalSize)
        output.addRepresentation(bitmap)
        return output
    }
}
```

```swift
// SwiftUI Image consumption — disable interpolation
Image(nsImage: SVGCachedRenderer.shared.image(for: asset, scale: 2.0)!)
    .interpolation(.none)               // I-16: no SwiftUI smoothing
    .antialiased(false)
    .frame(width: 32, height: 32)       // integer pixel size; never 32.5
```

#### 2.4.4 MTKView delegate + draw loop

**Surface options analyzed:**

| Option | Verdict |
|---|---|
| `MTKView` with `MTKViewDelegate` | **CHOSEN** — native, well-trodden, integrates with NSView hierarchy, frame pacing handled by CADisplayLink + `preferredFramesPerSecond`. |
| `CAMetalLayer` directly on a custom NSView | Possible but reinvents frame pacing. Defer. |
| `SpriteKit` | Hide complexity but limits zero-copy and binary archive control. Rejected. |
| Pure SwiftUI animation | Cannot meet 120fps for 12+ sprites; allocation-heavy. Rejected. |

The renderer issues **one draw call per frame** for all companions on screen, using `drawIndexedPrimitives:instanceCount:`. Per-instance data (position, atlas index, palette, tint, state flags) comes from the `MTLBuffer` populated by the SPSC ring drain.

Pipeline state is **pre-compiled** at app launch via `MTLBinaryArchive` (per CLAUDE.md DETERMINISTIC PERF rules; never compile pipelines on the main thread).

```swift
// Epistemos/Simulation/MetalSimulationRenderer.swift

import Metal
import MetalKit

@MainActor
final class MetalSimulationRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState  // pre-compiled, archive-backed
    private let companionAtlas: MTLTexture             // IOSurface-backed, texture array
    private let palettes: MTLBuffer                    // const palette table
    private let bridge: DeltaRingBridge
    private let quadVertices: MTLBuffer                // 4 vertices, persistent
    private let quadIndices: MTLBuffer                 // 6 indices, persistent

    init(view: MTKView, bridge: DeltaRingBridge) throws {
        guard let device = view.device, let queue = device.makeCommandQueue() else {
            throw RendererError.deviceUnavailable
        }
        self.device = device
        self.commandQueue = queue
        self.bridge = bridge
        // Load pre-compiled binary archive (built at first launch or shipped pre-built).
        self.pipelineState = try Self.loadCompanionPipeline(device: device, view: view)
        self.companionAtlas = try Self.loadAtlasIOSurface(device: device)
        self.palettes = try Self.loadPalettes(device: device)
        self.quadVertices = device.makeBuffer(bytes: Self.quadVerts, length: 32, options: [])!
        self.quadIndices = device.makeBuffer(bytes: Self.quadIdx, length: 12, options: [])!
        super.init()
        view.delegate = self
        view.preferredFramesPerSecond = 120
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // viewport update (cheap)
    }

    func draw(in view: MTKView) {
        // Pull deltas off the ring directly into bridge.buffer (zero-copy).
        let instanceCount = bridge.drain()
        guard instanceCount > 0 else {
            // Idle: skip the draw call entirely. Saves power.
            return
        }
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(quadVertices, offset: 0, index: 0)
        encoder.setVertexBuffer(bridge.buffer, offset: 0, index: 1)
        encoder.setFragmentTexture(companionAtlas, index: 0)
        encoder.setFragmentBuffer(palettes, offset: 0, index: 1)
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: quadIndices,
            indexBufferOffset: 0,
            instanceCount: instanceCount
        )
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
```

Vertex/fragment shaders: see Slice S4 below for the MSL.

### 2.5 Hot-path coalescing strategy

Position deltas can fire many times per second. Two policies:

| Event class | Coalesce policy |
|---|---|
| Position/scale/tint deltas | **newest-wins per agent_id**; old deltas overwritten in the ring before the consumer drains |
| Animation state transitions, spawns, errors, gates | **NEVER coalesced**; preserved in order; if the ring fills, log a regression |

Implementation V0: O(N) scan of the ring on each push to find existing entry by agent_id; if found, overwrite. V1 upgrade: per-companion slot map indexed by `agent_id` for O(1) coalesce.

### 2.6 Sprite atlas strategy

**Texture array** with one 2D slice per head shape (Block, Sage, Orb, Hermes_Snake). Each slice contains all 14 animation states packed in a fixed grid. Overlays (eyes, arms, props) are **separate texture arrays** rendered as additional instanced quads in the same pipeline.

This means a single companion = 4–6 quads (body + eyes + arms + prop + optional accessory + optional speech bubble), all instanced into one draw call.

Atlas layout per head shape:
```
Atlas 256×256 px (small enough to fit easily; large enough for headroom):
Row 0 (y=0):   idle_f0..f3  walk_f0..f7
Row 1 (y=64):  think_f0..f5 speak_f0..f3 tool_f0..f5
Row 2 (y=128): spawn_f0..f4 handoff_give_f0..f7
Row 3 (y=192): handoff_receive_f0..f5 retrieve_f0..f5 error_f0..f3
Row 4 (y=256): recover_f0..f5 success_f0..f3 sleep_f0..f3 gate_f0..f1
```
Stored UV coordinates per (state, frame) in `atlas.json`; loaded once at startup.

---

## 3. Slice-by-Slice Build Plan

### Slice S0 — Worktree, signposts, perf gates

**Goal:** Set up the simulation worktree with signpost instrumentation and a perf-gate harness. No simulation logic yet. This is the canonical foundation that every later slice depends on for measurement.

**Doctrine refs:** I-15 (perf contract), §12 (budgets).

**Files touched:**
- `crates/agent_core/src/perf.rs` (new) — signpost macros wrapping `os_signpost`
- `Epistemos/Simulation/Perf.swift` (new) — Swift signpost helpers
- `crates/agent_core/benches/reducer_bench.rs` (new) — criterion bench skeleton
- `Tools/perf_check.sh` (new) — local CI gate script

**Architecture choice — signpost framework:**
- **Chosen:** `os_signpost` (Apple's native low-overhead signpost API). Rust uses `os-signpost` crate or raw `os_signpost_interval_begin/end` C bindings.
- Rejected: `tracing` alone (great for logs, not aligned with Instruments timeline).

**Code:**

```rust
// crates/agent_core/src/perf.rs
use std::ffi::CString;

// Minimal os_signpost wrapper for Rust. (V0 — replace with crate later if useful.)
extern "C" {
    fn os_log_create(subsystem: *const i8, category: *const i8) -> *mut std::ffi::c_void;
    fn os_signpost_id_generate(log: *mut std::ffi::c_void) -> u64;
    fn os_signpost_interval_begin(log: *mut std::ffi::c_void, id: u64, name: *const i8);
    fn os_signpost_interval_end(log: *mut std::ffi::c_void, id: u64, name: *const i8);
}

pub struct Signpost { /* ... */ }

#[macro_export]
macro_rules! signpost_interval {
    ($name:literal, $body:block) => {{
        let _g = $crate::perf::Signpost::begin($name);
        $body
    }};
}
```

```swift
// Epistemos/Simulation/Perf.swift
import OSLog

enum SimSignpost {
    static let log = OSLog(subsystem: "com.epistemos.simulation", category: "theater")
}

@inline(__always)
func signpostInterval<T>(_ name: StaticString, _ body: () throws -> T) rethrows -> T {
    let id = OSSignpostID(log: SimSignpost.log)
    os_signpost(.begin, log: SimSignpost.log, name: name, signpostID: id)
    defer { os_signpost(.end, log: SimSignpost.log, name: name, signpostID: id) }
    return try body()
}
```

**Acceptance:**
- [ ] `cargo test --manifest-path crates/agent_core/Cargo.toml` passes (no logic added; structural tests only).
- [ ] `cargo bench --manifest-path crates/agent_core/Cargo.toml --bench reducer_bench` runs and emits a baseline.
- [ ] Instruments → Signposts can see `epistemos.simulation.theater.*` intervals when the empty harness runs.
- [ ] `Tools/perf_check.sh` script runs locally and outputs go/no-go per budget category from `DOCTRINE.md` §12.

**Verification:**
```bash
cargo test --manifest-path crates/agent_core/Cargo.toml -p agent_core --lib perf
cargo bench --manifest-path crates/agent_core/Cargo.toml --bench reducer_bench -- --quick
./Tools/perf_check.sh
```

**Anti-drift:**
```bash
rg -n 'os_signpost|signpostInterval|signpost_interval' Epistemos crates 2>/dev/null | wc -l
# expect non-zero after S0
```

**Non-goals:** real reducer logic, real renderer, real assets.

---

### Slice S1 — CompanionRegistry + activity hysteresis

**Goal:** Implement the Rust-owned `CompanionRegistry` with atomic create/update/archive transactions, activity-state machine with hysteresis, and SQLite persistence. This is the substrate that all three placements project from (DOCTRINE §3.1).

**Doctrine refs:** I-9, §3.1, §3.5, §6.

**Files touched:**
- `crates/agent_core/src/companions/mod.rs` (new)
- `crates/agent_core/src/companions/registry.rs` (new)
- `crates/agent_core/src/companions/activity.rs` (new)
- `crates/agent_core/src/companions/transaction.rs` (new)
- `crates/agent_core/src/companions/audit.rs` (new)
- Migration: `crates/substrate-core/migrations/NNN_companions.sql` (new)

**Architecture choice — registry storage:**
- **Chosen:** SQLite (already in repo via GRDB on Swift side; substrate-core's Rust SQLite layer for write-side). Strong durability, transactional, queryable.
- Rejected: filesystem-only TOML registry (no atomicity across multiple files); in-memory only (loses state across restarts).

**SQL schema:**

```sql
-- migrations/NNN_companions.sql
CREATE TABLE companions (
    id TEXT PRIMARY KEY,                 -- ULID
    name TEXT NOT NULL UNIQUE,
    head_shape TEXT NOT NULL,            -- 'Block' | 'Sage' | 'Orb' | 'HermesSnake'
    palette_ref TEXT NOT NULL,
    eyes TEXT NOT NULL,
    arms TEXT NOT NULL,
    prop_ref TEXT,
    accessory_ref TEXT,
    role TEXT NOT NULL,                  -- ProviderRole
    base_model TEXT NOT NULL,            -- ModelProfile FK
    system_prompt_preset TEXT NOT NULL,
    tool_affinities BLOB NOT NULL,       -- packed bitset
    vault_path TEXT NOT NULL UNIQUE,
    graph_slice TEXT NOT NULL UNIQUE,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    archived_at TEXT,                    -- NULL = active
    farm_position_x REAL NOT NULL DEFAULT 0,
    farm_position_y REAL NOT NULL DEFAULT 0,
    config_version INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE companion_audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    companion_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    payload TEXT NOT NULL,               -- JSON
    created_at TEXT NOT NULL,
    FOREIGN KEY(companion_id) REFERENCES companions(id)
);

CREATE INDEX idx_companion_audit_companion ON companion_audit_log(companion_id, created_at);
CREATE INDEX idx_companions_archived ON companions(archived_at) WHERE archived_at IS NULL;

CREATE TABLE companion_adapters (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    companion_id TEXT NOT NULL,
    epbox_id TEXT NOT NULL,
    epbox_type TEXT NOT NULL,
    applied_at TEXT NOT NULL,
    config_diff TEXT NOT NULL,           -- JSON
    reversible INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY(companion_id) REFERENCES companions(id)
);
```

**Activity state machine:**

```rust
// crates/agent_core/src/companions/activity.rs

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ActivityState {
    Active,
    Recent,    // within last 30s after last event
    Dormant,   // ≤ 7 days since last run
    Parked,    // > 7 days
    JustAcquired,
}

pub struct ActivityTracker {
    last_event_at: HashMap<CompanionId, Instant>,
    state: HashMap<CompanionId, ActivityState>,
    hysteresis: Duration,         // 30s default
    parked_after: Duration,       // 7 days default
}

impl ActivityTracker {
    pub fn observe_event(&mut self, id: CompanionId, now: Instant) -> Option<ActivityState> {
        let prev = self.state.get(&id).copied();
        self.last_event_at.insert(id, now);
        let next = ActivityState::Active;
        self.state.insert(id, next);
        (prev != Some(next)).then_some(next)
    }

    /// Called by a tokio interval task every 1s. Returns transitions to broadcast.
    pub fn tick(&mut self, now: Instant) -> Vec<(CompanionId, ActivityState, ActivityState)> {
        let mut transitions = Vec::new();
        for (id, last) in &self.last_event_at {
            let elapsed = now.duration_since(*last);
            let prev = self.state[id];
            let next = if elapsed < self.hysteresis { ActivityState::Active }
                       else if elapsed < Duration::from_secs(60) { ActivityState::Recent }
                       else if elapsed < self.parked_after { ActivityState::Dormant }
                       else { ActivityState::Parked };
            if prev != next {
                transitions.push((*id, prev, next));
                self.state.insert(*id, next);
            }
        }
        transitions
    }
}
```

**Atomic creation transaction (DOCTRINE §6.3):**

```rust
// crates/agent_core/src/companions/transaction.rs

pub struct CreationTransaction<'a> {
    sqlite: &'a mut SqliteConnection,
    companion_id: CompanionId,
    rollback_actions: Vec<Box<dyn FnOnce() -> Result<(), Error>>>,
}

impl<'a> CreationTransaction<'a> {
    pub fn create_companion(spec: CompanionSpec, db: &'a mut SqliteConnection) -> Result<Companion, CreationError> {
        let _signpost = signpost_interval!("companion.create", {});
        let mut txn = db.transaction()?;
        let id = CompanionId::new_ulid();

        // Step 2: vault folder + companion.toml (durability: fsync after write)
        let vault_path = ensure_vault_folder(&spec.vault_path)?;
        let cleanup_vault = || std::fs::remove_dir_all(&vault_path);

        // Step 3: registry insert
        if let Err(e) = txn.execute("INSERT INTO companions ...", params![/* ... */]) {
            cleanup_vault().ok();
            return Err(CreationError::RegistryWrite(e));
        }

        // Step 4: ModelProfile materialize
        if let Err(e) = materialize_model_profile(&txn, &id, &spec) {
            cleanup_vault().ok();
            return Err(CreationError::ModelProfile(e));
        }

        // Step 5: graph slice allocate
        if let Err(e) = allocate_graph_slice(&txn, &id, &spec.graph_slice_name()) {
            cleanup_vault().ok();
            return Err(CreationError::GraphSlice(e));
        }

        // Step 6: audit log write (CRITICAL — fsync required)
        if let Err(e) = write_audit_entry(&txn, AuditEntry::CompanionRegistered { /* ... */ }) {
            cleanup_vault().ok();
            return Err(CreationError::Audit(e));
        }

        // Commit (all-or-nothing at SQLite layer; vault folder is the only OOB resource)
        txn.commit()?;

        // Step 7: emit observer event
        emit_companion_registered(&id, &spec);

        Ok(Companion::from_spec(id, spec))
    }
}
```

**Acceptance:**
- [ ] `cargo test -p agent_core --lib companions` passes.
- [ ] Activity tracker correctly transitions Active → Recent → Dormant → Parked under simulated time.
- [ ] Creation transaction rolls back fully on synthetic failure at each step (use injection of `FailAt::Step(N)`).
- [ ] Audit log entry written with full diff on creation.
- [ ] SQLite migrations apply cleanly on a fresh DB and idempotently on existing DB.
- [ ] No `Date::now()` / `arc4random` inside the reducer or simulation paths (per I-13).

**Verification:**
```bash
cargo test --manifest-path crates/agent_core/Cargo.toml -p agent_core --lib companions -- --nocapture
cargo bench --manifest-path crates/agent_core/Cargo.toml --bench companion_create_bench
rg -n 'Date::now|SystemTime::now|arc4random|thread_rng' crates/agent_core/src/simulation crates/agent_core/src/companions 2>/dev/null
```

**Anti-drift:**
```bash
# Registry must not be mutated from Swift directly
rg -n 'CompanionRegistry|companions\[' Epistemos/ | rg -v 'FFI\|Bridge'
# expect empty
```

**Non-goals:** rendering, FFI exposure to Swift, sprites, asset pipeline.

---

### Slice S2 — AgentEvent normalization, persistence, replay infrastructure

**Goal:** Implement the canonical `AgentEvent` enum, provider-stream normalization (Hermes / Claude / Kimi / GPT / local MLX), append-only event log persistence, and replay infrastructure that takes `&[AgentEvent]` → `SimulationState` deterministically.

**Doctrine refs:** I-3, I-4, I-13, §11.

**Files touched:**
- `crates/agent_core/src/events.rs` (expand)
- `crates/agent_core/src/normalize/mod.rs` (new)
- `crates/agent_core/src/normalize/anthropic.rs` (new)
- `crates/agent_core/src/normalize/openai.rs` (new)
- `crates/agent_core/src/normalize/kimi.rs` (new)
- `crates/agent_core/src/normalize/hermes.rs` (new)
- `crates/agent_core/src/normalize/local_mlx.rs` (new)
- `crates/agent_core/src/event_log.rs` (new — append-only JSONL)
- `crates/agent_core/src/replay.rs` (new)

**Architecture choice — event log persistence:**
- **Chosen:** Append-only JSONL files per session, fsync on commit, with a SQLite index pointing to byte offsets. Best for replay; simplest to reason about; aligns with Raw Thoughts pattern from `claude opt 2` doc.
- Rejected: pure SQLite (writes are slower; no natural ordering preservation across restarts); pure file-per-event (creates millions of tiny files).

**Code skeleton:**

```rust
// crates/agent_core/src/event_log.rs

use std::io::Write;

pub struct AppendOnlyEventLog {
    path: PathBuf,
    file: std::fs::File,         // O_APPEND
    bytes_written: u64,
}

impl AppendOnlyEventLog {
    pub fn append(&mut self, event: &AgentEvent) -> std::io::Result<u64> {
        let line = serde_json::to_string(event)?;
        let offset = self.bytes_written;
        self.file.write_all(line.as_bytes())?;
        self.file.write_all(b"\n")?;
        self.file.sync_data()?;     // fsync (data only, faster than full sync)
        self.bytes_written += line.len() as u64 + 1;
        Ok(offset)
    }
}

// crates/agent_core/src/replay.rs

pub fn replay(events: impl IntoIterator<Item = AgentEvent>) -> SimulationState {
    let mut state = SimulationState::initial();
    for event in events {
        let _ = crate::simulation::reducer::reduce(&mut state, event);
    }
    state
}
```

**Provider normalization example (Anthropic SSE → AgentEvent):**

```rust
// crates/agent_core/src/normalize/anthropic.rs

pub fn normalize_anthropic_event(raw: AnthropicSseEvent, agent_id: CompanionId) -> Vec<AgentEvent> {
    match raw {
        AnthropicSseEvent::MessageStart { message_id, .. } => {
            vec![AgentEvent::MessageStarted { message_id, agent_id }]
        }
        AnthropicSseEvent::ContentBlockStart { content_block: Block::Thinking { .. }, message_id } => {
            vec![AgentEvent::ThinkingStarted { agent_id, message_id }]
        }
        AnthropicSseEvent::ContentBlockDelta { delta: Delta::ThinkingDelta { tokens }, message_id, .. } => {
            vec![AgentEvent::ThinkingDelta { message_id, token_count: tokens }]
        }
        AnthropicSseEvent::ContentBlockStop { content_block: Block::ToolUse { id, name, input }, .. } => {
            vec![AgentEvent::ToolCallStarted {
                tool_call_id: id.into(),
                agent_id,
                tool_name: name,
                input_hash: blake3::hash(&serde_json::to_vec(&input).unwrap_or_default()),
            }]
        }
        // ... exhaustive
        _ => vec![],
    }
}
```

**Acceptance:**
- [ ] All 30+ AgentEvent variants from DOCTRINE §11 are defined.
- [ ] Normalization round-trip: a recorded provider stream replays through the normalizer and produces the same AgentEvent sequence twice.
- [ ] Replay test: given `events.jsonl`, `replay(events) == replay(events)` byte-for-byte at the SimulationState hash level.
- [ ] Append-only: external attempts to truncate or modify `events.jsonl` are detected by a content-hash chain check.
- [ ] No timestamp source other than the event itself enters the reducer.

**Verification:**
```bash
cargo test -p agent_core --lib events normalize replay
cargo run --manifest-path crates/agent_core/Cargo.toml --bin replay_test fixtures/sessions/sample_anthropic.jsonl
rg -n 'Date|Instant::now|SystemTime' crates/agent_core/src/simulation crates/agent_core/src/replay.rs
```

**Anti-drift:**
```bash
# Provider-specific code must NOT leak into reducer
rg -n 'anthropic|openai|kimi|hermes|moonshot' crates/agent_core/src/simulation 2>/dev/null
# expect empty
```

**Non-goals:** UI, FFI exposure, rendering.

---

### Slice S3 — Honesty audit ledger

**Goal:** Implement the audit ledger that records, for every visible animation, the triggering event class and event ID. This is what makes the honesty doctrine inspectable.

**Doctrine refs:** I-5, §9.

**Files touched:**
- `crates/agent_core/src/audit/ledger.rs` (new)
- `crates/agent_core/src/audit/mod.rs` (new)
- Integration: every `FrameDelta` emission in the reducer carries an `AuditOrigin` tag.

**Code:**

```rust
// crates/agent_core/src/audit/ledger.rs

#[derive(Debug, Clone, Serialize)]
pub enum AuditOrigin {
    Event { event_id: EventId, event_kind: AgentEventKind },
    CosmeticIdle { companion_id: CompanionId, since_event: EventId },
    StateTransition { companion_id: CompanionId, from: ActivityState, to: ActivityState },
}

pub struct AuditLedger {
    sqlite: SqliteConnection,
}

impl AuditLedger {
    /// Called for every frame delta produced by the reducer.
    pub fn record(&mut self, delta_id: DeltaId, origin: AuditOrigin) -> Result<(), AuditError> {
        // Insert into audit table; this is async-batched (writes flushed every 500ms).
        Ok(())
    }

    /// User-facing query: "Why did this animation happen?"
    pub fn query_animation_origin(&self, delta_id: DeltaId) -> Option<AuditOrigin> {
        // ...
    }
}
```

Frame deltas now carry origin:

```rust
pub struct FrameDelta {
    pub delta_id: DeltaId,
    pub origin: AuditOrigin,
    pub kind: FrameDeltaKind,  // AgentAnimation, AgentProp, ApprovalGate, ...
}
```

**Acceptance:**
- [ ] Every `FrameDelta` produced by the reducer has a non-null `AuditOrigin`.
- [ ] An assertion in debug builds: `assert!(matches!(origin, AuditOrigin::Event { .. } | AuditOrigin::CosmeticIdle { .. } | AuditOrigin::StateTransition { .. }))`.
- [ ] User-facing query returns the originating event for any visible animation.
- [ ] Cosmetic idle is correctly labeled and never carries a fake event_id.

**Verification:**
```bash
cargo test -p agent_core --lib audit
# property test: random AgentEvent stream → every produced FrameDelta has valid origin
cargo test -p agent_core --test audit_property
```

**Anti-drift:**
```bash
# Forbid creating FrameDelta without origin
rg -n 'FrameDelta\s*\{' crates/agent_core/src | rg -v 'origin:'
# expect empty (every FrameDelta must specify origin)
```

**Non-goals:** UI surface for the audit; that's S14.

---

### Slice S4 — Theater Metal renderer (placeholder geometry)

**Goal:** First end-to-end render. Rust reducer pushes deltas through SPSC ring → Swift drains into MTLBuffer → Metal pipeline draws colored rectangles labeled with companion ID. No real sprites yet. This validates the full zero-copy pipeline.

**Doctrine refs:** I-6, I-7, I-8, I-15, §2.2, §2.3.

**Files touched:**
- `crates/agent_core/src/ffi/delta_ring.rs` (new — ring buffer, raw C ABI)
- `Epistemos/Simulation/DeltaRingBridge.swift` (new)
- `Epistemos/Simulation/MetalSimulationRenderer.swift` (new)
- `Epistemos/Simulation/Shaders/Companion.metal` (new — placeholder shaders)
- `Epistemos/Simulation/PipelineArchive.swift` (new — MTLBinaryArchive loading)
- `Epistemos/Simulation/Views/TheaterMTKView.swift` (new — NSViewRepresentable wrapper)
- `Tools/build_pipeline_archive.sh` (new — pre-compile shaders → binary archive)

**Metal shader (placeholder; real fragment in S10):**

```metal
// Epistemos/Simulation/Shaders/Companion.metal
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
};

struct PerInstanceData {
    uint2  agent_id_hi_lo;
    float2 position;
    float2 scale;
    uint   atlas_index;
    uint   frame_index;
    uint   palette_id;
    float4 tint;
    uint   state_flags;
    uint   _padding;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
    uint   atlas_index;
    uint   frame_index;
    uint   palette_id;
    float4 tint;
};

vertex VertexOut companion_vertex(
    VertexIn vin [[stage_in]],
    uint instance_id [[instance_id]],
    constant PerInstanceData* instances [[buffer(1)]]
) {
    PerInstanceData inst = instances[instance_id];
    VertexOut out;
    float2 world = vin.position * inst.scale + inst.position;
    out.position = float4(world, 0.0, 1.0);  // V4: pass through view/projection matrix
    out.uv = (vin.position * 0.5) + 0.5;     // V0: just barycentric for color
    out.atlas_index = inst.atlas_index;
    out.frame_index = inst.frame_index;
    out.palette_id = inst.palette_id;
    out.tint = inst.tint;
    return out;
}

fragment float4 companion_fragment_placeholder(VertexOut in [[stage_in]]) {
    // V0 placeholder: just return tint with subtle UV-based striping for visual debugging.
    float stripe = step(0.5, fract(in.uv.x * 4.0 + in.uv.y * 4.0));
    return in.tint * (0.7 + 0.3 * stripe);
}

// Real fragment in Slice S10 will sample atlas + apply palette mask.
```

**Pipeline archive build:**

```bash
# Tools/build_pipeline_archive.sh
xcrun -sdk macosx metal -c Companion.metal -o Companion.air
xcrun -sdk macosx metallib Companion.air -o Companion.metallib
# Build the binary archive at first launch; cache in app support directory.
```

**Acceptance:**
- [ ] Empty harness: open Theater view; see "no active agents" empty state.
- [ ] Synthetic harness: feed 5 mock companions through the reducer; see 5 colored rectangles at expected positions.
- [ ] Frame time at 60Hz: ≤ 5ms p99 (signposts: `theater.frame`).
- [ ] Idle: zero draw calls when no events for ≥500ms.
- [ ] No main-thread Metal pipeline compilation (verified by `MTLBinaryArchive.add(library:)` logging on first launch only, never thereafter).
- [ ] FFI: ring drain measured at < 5µs p95.
- [ ] **Bit-perfect (I-16):** sampler is `.nearest` for both min and mag; mip is `.notMipmapped`. Sample count is 1. Programmatic test: capture a frame, find a known-fill pixel, assert RGBA matches the atlas pixel exactly (no interpolated intermediates).
- [ ] **Bit-perfect (I-16):** snap-to-pixel — render a sprite at world position `(10.4, 7.7)` and capture the frame; the sprite's leftmost-filled pixel must be at integer screen coordinate `(10, 7)` × pixel_density (no half-pixel ghost). Round-trip property test in CI.
- [ ] **Bit-perfect (I-16):** integer-scale only — fuzz the reducer with random scale floats; `snapshot_for_render()` must round to integer; debug-build assertion fires on fractional source.
- [ ] **Bit-perfect (I-16):** halo and eye-bloom render as separate additive-blend draws with `effects/halo_active.png` / `effects/eye_glow.png`. Source confirms `MTLBlendFactorOne` × `MTLBlendFactorOne`. No Gaussian blur shader exists in the bundle.

**Verification:**
```bash
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
# Run app, open Theater, exercise via debug menu "Inject Mock Companions"
# Open Instruments → Signposts; record 30s; verify theater.frame intervals < 5ms
swift test --filter MetalSimulationRendererBitPerfectTests
```

**Anti-drift:**
```bash
rg -n 'makeRenderPipelineState|makeComputePipelineState' Epistemos/Simulation 2>/dev/null
# expect: only inside PipelineArchive.swift, only at app launch path
rg -n 'AnyView|\[String: Any\]' Epistemos/Simulation 2>/dev/null
# expect empty

# Bit-perfect (I-16) sweeps
rg -n '\.linear|MTLSamplerMinMagFilter\.linear' Epistemos/Simulation 2>/dev/null
# expect empty
rg -n 'sampleCount\s*=\s*[2-9]|sampleCount\s*=\s*1[0-9]' Epistemos/Simulation 2>/dev/null
# expect empty
rg -n 'mipmapped|generateMipmaps' Epistemos/Simulation 2>/dev/null
# expect empty
rg -n 'GaussianBlur|gaussianBlur|MPSImageGaussianBlur' Epistemos/Simulation 2>/dev/null
# expect empty
rg -n '\.interpolation\(\.high\)|\.interpolation\(\.medium\)|\.interpolation\(\.low\)' Epistemos/Simulation 2>/dev/null
# expect empty
rg -n 'imageInterpolation\s*=\s*\.high|imageInterpolation\s*=\s*\.medium|imageInterpolation\s*=\s*\.low|imageInterpolation\s*=\s*\.default' Epistemos/Simulation 2>/dev/null
# expect empty
```

**Non-goals:** real assets, customization UI, three-placement projections.

---

### Slice S5 — Landing Farm placement

**Goal:** Implement Placement A (Landing Farm) with all companions visible regardless of activity. Persistent positions per companion. Activity-state visual variations (Active / Recent / Dormant / Parked / JustAcquired).

**Doctrine refs:** I-9, §3.2, §3.5.

**Files touched:**
- `Epistemos/Simulation/Views/LandingFarmView.swift` (new)
- `Epistemos/Simulation/ViewModels/LandingFarmViewModel.swift` (new — `@MainActor`)
- `Epistemos/Simulation/Bridges/CompanionRegistryBridge.swift` (new — UniFFI for control + ring for activity deltas)

**ViewModel sketch:**

```swift
// Epistemos/Simulation/ViewModels/LandingFarmViewModel.swift

@MainActor
final class LandingFarmViewModel: ObservableObject {
    @Published private(set) var companions: [CompanionFarmEntry] = []
    private let registry: CompanionRegistryBridge
    private var observerTask: Task<Void, Never>?

    init(registry: CompanionRegistryBridge) {
        self.registry = registry
    }

    func startObserving() {
        observerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await snapshot in self.registry.allCompanionsStream() {
                self.companions = snapshot.map(CompanionFarmEntry.init)
            }
        }
    }

    deinit {
        observerTask?.cancel()
    }
}

struct CompanionFarmEntry: Identifiable, Sendable, Equatable {
    let id: CompanionId
    let name: String
    let headShape: HeadShape
    let palette: PaletteRef
    let activity: ActivityState
    let farmPosition: CGPoint
    let lastActiveAt: Date?
}
```

**Acceptance:**
- [ ] Landing view shows all companions, dormant included.
- [ ] Each companion's visual reflects its `ActivityState` per DOCTRINE §3.2 table.
- [ ] Companion creation (mock from S1) makes the new companion appear with rainbow-flash entrance.
- [ ] Click a companion → focus inspector pane (Pro: also drag to rearrange position).
- [ ] Empty state with "tap to begin" affordance when registry is empty.

**Verification:**
```bash
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
# Manual: open app, view Landing Farm, verify all activity states render correctly
swift test --filter LandingFarmViewModelTests
```

**Anti-drift:**
```bash
# ViewModel must be MainActor; bridge must be actor-isolated
rg -n '@MainActor|actor ' Epistemos/Simulation/ViewModels Epistemos/Simulation/Bridges
rg -n 'AnyView' Epistemos/Simulation/Views
# expect empty
```

**Non-goals:** Graph theater, sidebar skin, real sprites.

---

### Slice S5.5 — SVG branding asset pipeline (NEW v1.1)

**Goal:** Land the static SVG branding pipeline so Sidebar Skin (S6) and Graph Theater inspector chips can use real provider iconography. Ingest user-supplied Claude Code SVGs; create V1 placeholders for Kimi/Codex/GPT/Hermes/Local; build a runtime SVG renderer with cached CGImage per-scale; add provenance + audit-ledger integration.

**Doctrine refs:** §5.6, §10.6.

**Files touched:**
- `Resources/CompanionAssets/branding/<provider>/icon-color.svg` (5–6 files)
- `Resources/CompanionAssets/branding/<provider>/icon-mono.svg` (where applicable)
- `Resources/CompanionAssets/branding/claude-code/wordmark-color.svg` (user-supplied)
- `Resources/CompanionAssets/branding/<provider>/provenance.json` (one per provider)
- `Tools/branding_pipeline/validate.py` (new — build-time validator)
- `Epistemos/Simulation/Branding/CompanionBrandingService.swift` (new)
- `Epistemos/Simulation/Branding/SVGCachedRenderer.swift` (new)
- `Epistemos/Simulation/Branding/ProvenanceLedger.swift` (new)

**Architecture choice — SVG renderer:**
- **Chosen:** `NSImage(byReferencing: bundleURL).representations` with on-demand `CGImage` rasterization at the requested scale; cache by `(asset_path, scale, tint?)` keyed `NSCache`. SwiftUI `Image(nsImage:)` consumes.
- Rejected: third-party SVG library (adds dependency for what AppKit handles natively). Rejected: pre-rasterize all assets at all scales at build time (wastes binary size; macOS HiDPI scales are runtime-known).

**SVG renderer skeleton:**

```swift
// Epistemos/Simulation/Branding/SVGCachedRenderer.swift

@MainActor
final class SVGCachedRenderer {
    static let shared = SVGCachedRenderer()
    private let cache = NSCache<CacheKey, NSImage>()

    func image(for asset: BrandingAssetRef, scale: CGFloat, tint: Color? = nil) -> NSImage? {
        let key = CacheKey(path: asset.path, scale: scale, tint: tint?.cgColor.hashable)
        if let cached = cache.object(forKey: key) { return cached }
        guard let url = Bundle.main.url(forResource: asset.path, withExtension: nil),
              let image = NSImage(contentsOf: url) else {
            ProvenanceLedger.shared.recordRenderFailure(asset: asset)
            return nil
        }
        // Rasterize at scale + tint if requested
        let rendered = tint.map { tinted(image, color: $0, scale: scale) } ?? image
        cache.setObject(rendered, forKey: key)
        ProvenanceLedger.shared.recordRender(asset: asset, scale: scale, tint: tint)
        return rendered
    }
}
```

**Provenance.json schema:**

```json
{
  "asset_id": "claude-code-icon-color-v1",
  "asset_path": "branding/claude-code/icon-color.svg",
  "type": "icon",
  "origin": "user-supplied:anthropic-public-asset",
  "license": "see Anthropic brand guidelines; identification use only",
  "usage_scope": ["sidebar-pin", "command-palette-glyph", "titlebar-chip"],
  "recoloring_policy": { "locked": ["#D97757"] },
  "commercial_use_ok": true,
  "canonical_hex": "#D97757",
  "size_viewbox": { "width": 24, "height": 24 },
  "added": "2026-04-29",
  "added_by": "user"
}
```

**Validator (build-time CI) — bit-perfect / stepped-vector enforcement (DOCTRINE I-16 + §5.7):**

```python
# Tools/branding_pipeline/validate.py
import re
import xml.etree.ElementTree as ET
from pathlib import Path
import json
from glob import glob

# Forbidden SVG path commands per I-16: only M, L, H, V, Z (case-insensitive) allowed.
_FORBIDDEN_PATH_CMDS = re.compile(r"[CcSsQqTtAa]")
# Forbidden SVG elements per I-16: no <circle>, <ellipse>.
_FORBIDDEN_ELEMENTS = {"circle", "ellipse"}

def _localname(tag: str) -> str:
    return tag.split("}", 1)[-1] if "}" in tag else tag

def validate_svg(path: Path) -> list[str]:
    errors: list[str] = []
    tree = ET.parse(path)
    root = tree.getroot()
    for el in root.iter():
        name = _localname(el.tag)
        if name in _FORBIDDEN_ELEMENTS:
            errors.append(f"{path}: forbidden <{name}> (use stepped <path> per I-16)")
        if name == "path":
            d = el.attrib.get("d", "")
            if _FORBIDDEN_PATH_CMDS.search(d):
                errors.append(f"{path}: <path d='...'> contains curve/arc command (only M,L,H,V,Z allowed per I-16)")
            # Coordinates must be integers (stepped, no sub-pixel).
            for tok in re.findall(r"-?\d+\.\d+", d):
                errors.append(f"{path}: non-integer coordinate {tok} in <path> (I-16 requires integer pixel positions)")
    return errors

def validate_branding():
    """Validator branches by provenance.json `category` flag (DOCTRINE §10.7 carve-out).

    - "pixel-art-mascot"      → enforce I-16 stepped vectors (no curves, no <circle>/<ellipse>, integer coords)
    - "smooth-vector-brand"   → only validate license/usage/manifest fields; skip path-command checks
    - missing/unknown category → fail (every directory must declare)
    """
    all_errors: list[str] = []
    for provider_dir in glob("Resources/CompanionAssets/branding/*/"):
        pdir = Path(provider_dir)
        if pdir.name.startswith("_"):  # skip _index.json etc.
            continue
        prov_path = pdir / "provenance.json"
        if not prov_path.exists():
            all_errors.append(f"{pdir}: missing provenance.json")
            continue
        prov = json.loads(prov_path.read_text())
        # Required common fields
        for k in ("commercial_use_ok",):
            if k not in prov:
                all_errors.append(f"{prov_path}: missing required key '{k}'")

        category = prov.get("category")
        if category == "pixel-art-mascot":
            for k in ("license", "usage_scope", "recoloring_policy"):
                if k not in prov:
                    all_errors.append(f"{prov_path}: pixel-art-mascot requires '{k}'")
            for svg_path in pdir.glob("*.svg"):
                all_errors.extend(validate_svg(svg_path))
        elif category == "smooth-vector-brand":
            for k in ("license_compilation", "license_marks", "usage_scope", "sources"):
                if k not in prov:
                    all_errors.append(f"{prov_path}: smooth-vector-brand requires '{k}'")
            # I-16 stepped-vector path-command check is INTENTIONALLY SKIPPED here.
            # Validate only that the SVG parses and uses no <script> elements.
            for svg_path in pdir.glob("*.svg"):
                try:
                    tree = ET.parse(svg_path)
                    for el in tree.iter():
                        if _localname(el.tag) == "script":
                            all_errors.append(f"{svg_path}: <script> not allowed in any branding SVG")
                except ET.ParseError as e:
                    all_errors.append(f"{svg_path}: SVG parse error {e}")
        else:
            all_errors.append(f"{prov_path}: missing or unknown 'category' (must be 'pixel-art-mascot' or 'smooth-vector-brand')")

    if all_errors:
        for e in all_errors:
            print(f"FAIL: {e}")
        raise SystemExit(1)
    print("OK: all branding assets validated.")

if __name__ == "__main__":
    validate_branding()
```

**Acceptance:**
- [ ] User-supplied `claudecode-color.svg`, `claudecode-text.svg` ingested into `branding/claude-code/` with `provenance.json`.
- [ ] Placeholder SVGs created for Kimi (blue Compact Block, stepped silhouette), Codex (white-body recolor), GPT (stepped Orb), Hermes (caduceus, orthogonal-only path), Local (teal Block) with appropriate `provenance.json`.
- [ ] `SVGCachedRenderer` returns correct `NSImage` for any registered asset; `nil` with audit-log entry for missing.
- [ ] Build-time validator passes (`python Tools/branding_pipeline/validate.py`) — every branding SVG uses only `M`/`L`/`H`/`V`/`Z` commands and integer coordinates; no `<circle>` / `<ellipse>`.
- [ ] **Bit-perfect (I-16):** rasterization context sets `imageInterpolation = .none` and `shouldAntialias = false`; SwiftUI `Image` consumers set `.interpolation(.none).antialiased(false)`. Property test renders the same SVG at 1×, 2×, 3× and asserts each output is *exactly* a nearest-neighbor scaling of the 1× output (no smoothed intermediate pixels).
- [ ] Cache hit ratio ≥ 95% under simulated UI load (every render after first is cached).
- [ ] Render call latency p95 ≤ 0.5ms (after first load).
- [ ] No SVG asset enters the Metal renderer (`rg` sweep returns empty).

**Verification:**
```bash
python Tools/branding_pipeline/validate.py
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
swift test --filter SVGCachedRendererTests
```

**Anti-drift:**
```bash
# SVG must NOT enter Metal pipeline
rg -n '\.svg' Epistemos/Simulation/Shaders Epistemos/Simulation/MetalSimulationRenderer.swift 2>/dev/null
# expect empty

# Every branding/ subfolder must have provenance.json
ls Resources/CompanionAssets/branding/*/ | while read d; do
  [ -f "$d/provenance.json" ] || echo "MISSING PROVENANCE: $d"
done
# expect no output
```

**Non-goals:** raster atlases (S10); Metal-rendered animated mascot pin (V2 polish, deferred); browser-side SVG manipulation (out of scope); provider/company brand icons (those land in Slice S5.6, not here).

---

### Slice S5.6 — Provider brand icon fetcher + integration (NEW v1.3)

**Goal:** Land the smooth-vector provider/company brand icon system per DOCTRINE §10.7. Fetch all available variants (icon, wordmark, combine, brand) for the 18 providers in §10.7 from LobeHub via the prebuilt `Tools/branding_pipeline/fetch_lobe_icons.py` script. Generate mono variants via `currentColor` substitution. Integrate into the chat-header chip, sidebar Companions picker, settings provider rows, command palette, and audit attribution. Settings uses `icon-color.svg`; everywhere else uses `icon-mono.svg` with `.foregroundStyle(...)`.

**Doctrine refs:** §3.4 (Companions picker), §10.4 (asset directory), §10.7 (Provider Brand Icon System), I-16 carve-out.

**Files touched:**
- `Tools/branding_pipeline/fetch_lobe_icons.py` (already authored in worktree v1.3 — verify and run)
- `Resources/CompanionAssets/branding/<provider>/{icon-color.svg, icon-mono.svg, wordmark-color.svg, wordmark-mono.svg, combine-color.svg, combine-mono.svg, brand-color.svg, provenance.json}` for all 18 providers
- `Resources/CompanionAssets/branding/_index.json` (generated by the script)
- `Epistemos/Simulation/Branding/ProviderSlug.swift` (new — `ProviderSlug` enum + display metadata)
- `Epistemos/Simulation/Branding/ProviderIcon.swift` (new — `ProviderIcon` SwiftUI view per DOCTRINE §10.7 recipe)
- `Epistemos/Simulation/Branding/BrandingVariant.swift` (new — `BrandingVariant.color | .mono`)
- `Epistemos/Simulation/Branding/BrandingSurface.swift` (new — `BrandingSurface` enum: `.settings`, `.sidebarPicker`, `.sidebarAgentLabel`, `.chatHeader`, `.chatHeaderActive`, `.commandPalette`, `.auditView`, `.tabChrome`, `.inlineLabel`)
- `Epistemos/Settings/SettingsProviderListView.swift` (modify — surface `ProviderIcon(.color, .settings)` per row)
- `Epistemos/Views/Notes/CompanionsPickerView.swift` (new — collapsible company-grouped picker per DOCTRINE §3.4 v1.3)
- `Epistemos/Views/Chat/ChatHeaderProviderChip.swift` (new — mono chip per chat)
- `Epistemos/Views/CommandPalette/ProviderRoutingRow.swift` (modify — mono icon column)
- `Epistemos/Views/Audit/AuditEventRow.swift` (modify — mono attribution glyph)

**Architecture choice — fetch source:**
- **Chosen:** jsDelivr CDN serving `@lobehub/icons-static-svg` (`https://cdn.jsdelivr.net/npm/@lobehub/icons-static-svg@latest/icons/<id>.svg`). Public CDN, no auth, version-pinnable, faster than GitHub raw.
- Rejected: GitHub raw (rate-limited, slower); npm install in-tree (no Node toolchain in this Swift/Rust app); manual Figma export (slow, error-prone, version drift).

**Architecture choice — mono generation:**
- **Chosen:** post-process color SVG via regex replacement of `fill="#..."` / `stroke="#..."` / `fill: #...` style attributes with `currentColor`. Preserves `fill="none"` and existing `currentColor`. Robust for the variety of authoring conventions LobeHub uses across icons.
- Rejected: shipping LobeHub's React `<...Mono />` components (would require bundling a JS runtime); generating per-icon hand-edited mono assets (doesn't scale to 18 providers × 3-4 variants each).

**Provider catalog (matches DOCTRINE §10.7):** `anthropic`, `claude`, `claude-code`, `openai`, `codex`, `kimi`, `moonshot`, `gemini`, `google`, `gemma`, `perplexity`, `deepseek`, `qwen`, `apple`, `huggingface`, `github`, `hermes-agent`, `mcp`. The catalog is encoded in `Tools/branding_pipeline/fetch_lobe_icons.py` `PROVIDERS` constant — adding a provider is a one-line change there.

**Swift consumer skeleton:**

```swift
// Epistemos/Simulation/Branding/ProviderSlug.swift
public enum ProviderSlug: String, CaseIterable, Sendable {
    case anthropic, claude
    case claudeCode = "claude-code"
    case openai, codex
    case kimi, moonshot
    case gemini, google, gemma
    case perplexity, deepseek, qwen
    case apple, huggingface, github
    case hermesAgent = "hermes-agent"
    case mcp

    public var displayName: String {
        switch self {
        case .anthropic:    return "Anthropic"
        case .claude:       return "Claude"
        case .claudeCode:   return "Claude Code"
        case .openai:       return "OpenAI"
        case .codex:        return "OpenAI Codex"
        case .kimi:         return "Kimi"
        case .moonshot:     return "Moonshot AI"
        case .gemini:       return "Gemini"
        case .google:       return "Google"
        case .gemma:        return "Gemma"
        case .perplexity:   return "Perplexity"
        case .deepseek:     return "DeepSeek"
        case .qwen:         return "Qwen"
        case .apple:        return "Apple"
        case .huggingface:  return "Hugging Face"
        case .github:       return "GitHub"
        case .hermesAgent:  return "Hermes Agent"
        case .mcp:          return "Model Context Protocol"
        }
    }
}

// Epistemos/Simulation/Branding/BrandingVariant.swift
public enum BrandingVariant: String, Sendable {
    case color = "icon-color"
    case mono  = "icon-mono"
    case wordmarkColor = "wordmark-color"
    case wordmarkMono  = "wordmark-mono"
    case combineColor  = "combine-color"
    case combineMono   = "combine-mono"
}

// Epistemos/Simulation/Branding/BrandingSurface.swift
public enum BrandingSurface: Sendable {
    case settings
    case onboardingHero
    case sidebarPicker
    case sidebarAgentLabel
    case chatHeader
    case chatHeaderActive
    case commandPalette
    case auditView
    case tabChrome
    case inlineLabel
}

// Epistemos/Simulation/Branding/ProviderIcon.swift
import SwiftUI

public struct ProviderIcon: View {
    let provider: ProviderSlug
    let variant: BrandingVariant
    let surface: BrandingSurface
    var pointSize: CGFloat = 16

    public var body: some View {
        Image(svgResource: "branding/\(provider.rawValue)/\(variant.rawValue).svg")
            .resizable()
            .interpolation(.high)              // OK: smooth-vector-brand category, I-16 carve-out
            .antialiased(true)                 // OK: I-16 carve-out
            .scaledToFit()
            .frame(width: pointSize, height: pointSize)
            .foregroundStyle(tint)
            .accessibilityLabel(provider.displayName)
    }

    private var tint: AnyShapeStyle {
        switch (variant, surface) {
        case (.color, _),
             (.wordmarkColor, _),
             (.combineColor, _):
            return AnyShapeStyle(.tint)        // identity; SVG is already brand-colored
        case (.mono, .sidebarPicker),
             (.mono, .auditView):
            return AnyShapeStyle(.secondary)
        case (.mono, .chatHeaderActive):
            return AnyShapeStyle(Color.accentColor)
        case (.mono, .tabChrome):
            return AnyShapeStyle(.tertiary)
        case (.mono, _),
             (.wordmarkMono, _),
             (.combineMono, _):
            return AnyShapeStyle(.primary)
        }
    }
}
```

**Companions picker (DOCTRINE §3.4 v1.3):**

```swift
// Epistemos/Views/Notes/CompanionsPickerView.swift
struct CompanionsPickerView: View {
    @ObservedObject var registry: CompanionRegistryViewModel
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            ForEach(registry.companiesByProvider) { group in
                Section {
                    ForEach(group.companions) { c in
                        CompanionRow(companion: c, isCurrent: registry.workspace == c.id)
                            .onTapGesture { registry.setWorkspace(c.id) }
                    }
                } header: {
                    HStack(spacing: 6) {
                        ProviderIcon(provider: group.provider,
                                     variant: .mono,
                                     surface: .sidebarPicker,
                                     pointSize: 14)
                        Text(group.provider.displayName).font(.caption.weight(.medium))
                        Spacer()
                        Text("\(group.companions.count)").foregroundStyle(.tertiary).font(.caption2)
                    }
                }
            }
        } label: {
            Text("Companions").font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 8)
    }
}
```

**Settings row:**

```swift
// Epistemos/Settings/SettingsProviderListView.swift
ForEach(ProviderSlug.allCases) { p in
    HStack(spacing: 12) {
        ProviderIcon(provider: p, variant: .color, surface: .settings, pointSize: 24)
        VStack(alignment: .leading) {
            Text(p.displayName).font(.body)
            Text(apiKeyPresent(p) ? "Connected" : "Not configured")
                .font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        // ... API key field, default-model picker, telemetry consent
    }
}
```

**Acceptance:**
- [ ] `python3 Tools/branding_pipeline/fetch_lobe_icons.py` runs from repo root and writes 18 provider directories under `Resources/CompanionAssets/branding/`.
- [ ] Each provider directory has at minimum `icon-color.svg`, `icon-mono.svg`, and `provenance.json`. Wordmark/combine/brand variants are present where LobeHub publishes them; absent variants are recorded as `null` in `provenance.json` (not an error).
- [ ] Each `provenance.json` declares `"category": "smooth-vector-brand"`.
- [ ] `python Tools/branding_pipeline/validate.py` passes: smooth-vector-brand directories skip the I-16 path-command check; pixel-art-mascot directories continue to enforce it.
- [ ] `Resources/CompanionAssets/branding/_index.json` is generated and lists all 18 provider slugs.
- [ ] `ProviderIcon(provider: .anthropic, variant: .color, surface: .settings)` renders the colored Anthropic logo in Settings.
- [ ] `ProviderIcon(provider: .anthropic, variant: .mono, surface: .chatHeader)` renders the same shape tinted to `.primary`; switching to `.chatHeaderActive` retints to `Color.accentColor` without re-loading the SVG.
- [ ] `CompanionsPickerView` renders the **three-level Company → Model → Agent picker** per DOCTRINE §3.4 v1.4. Company headers use mono provider icons; model rows use mono provider/model icons; agent leaves use pixel-art Tamagotchi mascots. Clicking an agent under a model switches workspace; clicking a company name or a model name does NOT (navigation only — preserves I-9).
- [ ] Each model row has a `+` affordance that opens the creation flow (Slice S8) pre-seeded with that model as the agent's `base_model`.
- [ ] Local models appear under a synthetic `Local` company whose mono icon is `branding/apple/icon-mono.svg`. Each MLX model variant (Qwen3-4B, Qwen3-7B, Mamba-2-2.7B, etc.) is its own model row.
- [ ] Empty company sections (zero models or zero total agents) are hidden. Empty model rows (zero agents) are hidden by default; revealed via "Show models with no agents" toggle.
- [ ] Provider config (API keys, default model) lives in Settings only; the picker is read-only navigation.
- [ ] Mono icons inherit the dark-/light-mode primary text color automatically via `.foregroundStyle(.primary)`.
- [ ] VoiceOver: every `ProviderIcon` has an `.accessibilityLabel` matching `provider.displayName`. Each model row reads `"<Provider> <Model> — <count> agents"`. Each agent leaf reads `"<Agent name>, runs on <Provider> <Model>"`.
- [ ] Missing-variant fallback: requesting a `.combineColor` for a provider that has no upstream combine variant returns a generic SF Pro `"Provider: <name>"` label, not a broken image; the fallback is logged.
- [ ] No SVG asset enters the Metal renderer (`rg` sweep returns empty as in S4/S5.5).

**Verification:**
```bash
# 1. Fetch
cd /Users/jojo/Downloads/Epistemos/.claude/worktrees/simulation
python3 Tools/branding_pipeline/fetch_lobe_icons.py

# 2. Inspect
ls Resources/CompanionAssets/branding/anthropic/
cat Resources/CompanionAssets/branding/anthropic/provenance.json | head -30

# 3. Validate
python3 Tools/branding_pipeline/validate.py

# 4. Build & UI smoke test
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
swift test --filter ProviderIconTests
swift test --filter CompanionsPickerViewTests
```

**Anti-drift:**
```bash
# Smooth-vector-brand directories must NOT be referenced from Metal pipeline
rg -n 'branding/(anthropic|claude|openai|codex|gemini|google|gemma|perplexity|deepseek|qwen|apple|huggingface|github|hermes-agent|mcp|moonshot|kimi)/' Epistemos/Simulation/Shaders Epistemos/Simulation/MetalSimulationRenderer.swift 2>/dev/null
# expect empty

# ProviderIcon must use .interpolation(.high) for smooth-vector-brand (NOT .none)
rg -n 'ProviderIcon\b.*\.interpolation\(\.none\)' Epistemos
# expect empty (smooth icons must NOT have I-16 stepping forced on them)

# Settings is the only legal home for API keys / default model config
rg -n 'apiKey|defaultModel' Epistemos/Views/Notes/CompanionsPickerView.swift Epistemos/Views/Notes/NotesSidebarView.swift 2>/dev/null
# expect empty (config lives in Settings only)
```

**Non-goals:** model-specific branding within a provider (e.g., `claude-3-5-sonnet` getting its own glyph — V2+); animated provider icons (V3+); user-uploaded custom company icons (V3+); browser-side icon manipulation (out of scope); Hermes canonical assets (Slice S5.7).

---

### Slice S5.7 — Hermes canonical assets + opulent landing ritual (NEW v1.4)

**Goal:** Land the canonical NousResearch Hermes pixel-art assets (hero typography, snake mascot, ASCII portrait, optional ASCII banner) and wire them into the §8.2 v1.4 7-phase landing ritual. Ship the additive-pass effect textures (`halo_hermes_gold.png`, `glare_hermes.png`). This is what makes Hermes Mode feel cinematic and canonical — not a generic "AI mode" but the unmistakable NousResearch identity, elevated with the same I-16-compliant rendering discipline as the Kimi orb.

**Doctrine refs:** §8.2 (landing ritual), §8.2.1 (canonical asset sources), §8.2.2 (7-phase sequence), §8.2.3 (rendering rules), §8.2.4 (reduce-motion), §10.4 (asset directories), §10.7 (hermes-agent dual sourcing), I-16 (bit-perfect for pixel-art categories).

**Files touched:**
- `Tools/branding_pipeline/fetch_hermes_canonical.py` (already authored in worktree v1.4 — verify and run)
- `Resources/CompanionAssets/branding/hermes-agent-pixel/` — promoted canonical files:
  - `wordmark-hero-color.svg` (the big "HERMES-AGENT" yellow/orange-shadow title — user's reference image is the visual contract)
  - `wordmark-hero-mono.svg` (currentColor)
  - `mascot-snake-color.svg` (canonical caduceus / serpent)
  - `mascot-snake-mono.svg`
  - `provenance.json` (`"category": "pixel-art-mascot"`, source = NousResearch/hermes-agent commit SHA, license = MIT, attribution string)
- `Resources/CompanionAssets/ascii/` (NEW directory):
  - `hermes-agent-portrait.txt` (ASCII Nous Research character)
  - `hermes-agent-portrait-extended.txt` (larger variant)
  - `hermes-agent-banner.txt` (optional)
  - `provenance.json`
- `Resources/CompanionAssets/effects/halo_hermes_gold.png` (pre-baked soft radial gold gradient; additive blend; phase-4 of ritual)
- `Resources/CompanionAssets/effects/glare_hermes.png` (single-frame additive flash; phase-6)
- `Epistemos/Hermes/HermesLandingRitualView.swift` (new — orchestrates 7-phase animation timeline)
- `Epistemos/Hermes/HermesLandingPhases.swift` (new — phase enum + per-phase duration constants)
- `Epistemos/Hermes/AsciiPortraitView.swift` (new — `Text` rendering with `.system(.body, design: .monospaced)`, `.lineSpacing(0)`, `.foregroundStyle(...)`)
- `Epistemos/Hermes/HermesGoldHaloView.swift` (new — additive-blend halo quad consumer)
- `Tools/branding_pipeline/validate.py` (modify — accept the new `branding/hermes-agent-pixel/` and `ascii/` paths; existing category-aware branching applies)

**Architecture choices:**

- **Asset acquisition — chosen:** read-only probe via the GitHub tree API for `NousResearch/hermes-agent`, `joeynyc/hermes-skins`, and adjacent NousResearch org repos. Stage candidates in `raw/<repo-label>/`. Human reviewer promotes canonical files. The script never auto-promotes — picking the canonical file is a creative-direction decision.
- **Asset acquisition — rejected:** auto-promote by filename heuristics (too brittle); embedded npm/git submodule of hermes-skins (adds dependency churn for what's a one-time asset import); manual screenshot extraction from docs (loses fidelity).

- **Hero typography rendering — chosen:** SwiftUI `Image(svgResource:)` with `.interpolation(.none).antialiased(false)` per I-16 pixel-art rules. The wordmark is bit-perfect at integer scales. Type-on animation reveals one *glyph* per tick (not one pixel) — the SVG is sliced at glyph boundaries at build time and individual glyph SVGs are composed in sequence.
- **Hero typography rendering — rejected:** rasterizing at non-integer scale (breaks pixel-perfect aesthetic); CoreText with a custom pixel font (CoreText's hinter introduces its own anti-aliasing); single SVG with CSS animation (SwiftUI doesn't render CSS animations on SVG; would require WebKit).

- **ASCII portrait rendering — chosen:** SwiftUI `Text(asciiContent).font(.system(.body, design: .monospaced)).lineSpacing(0).foregroundStyle(.cyan)` (or whichever palette suits the phase). Loaded once at view init from `ascii/hermes-agent-portrait.txt` as a `String`.
- **ASCII portrait rendering — rejected:** rasterizing the ASCII to a bitmap (defeats the point — the visual identity comes from monospaced character shapes); custom Metal shader with character atlas (unnecessary complexity for static text).

- **Gold halo + glare — chosen:** separate additive-blend Metal quads sampled from pre-baked PNG textures (`halo_hermes_gold.png`, `glare_hermes.png`) with deliberate stepped radial falloff baked at design time. Same discipline as the Kimi orb halo (DOCTRINE §5.7).
- **Gold halo + glare — rejected:** runtime Gaussian blur of the wordmark (forbidden by I-16); CoreImage filter chain (introduces sub-pixel artifacts on the bit-perfect wordmark behind it).

**Ritual orchestration skeleton:**

```swift
// Epistemos/Hermes/HermesLandingPhases.swift
enum HermesLandingPhase: Int, CaseIterable {
    case anchor          // 0     (300ms)
    case portrait        // 1     (600ms)
    case asciiWave       // 2     (800ms)
    case heroTitleType   // 3    (1000ms)
    case goldHaloPulse   // 4     (500ms)
    case snakeCoil       // 5     (700ms)
    case glareFlash      // 6     (200ms)
    case chatSurface     // 7     (600ms)

    var duration: Duration {
        switch self {
        case .anchor:        return .milliseconds(300)
        case .portrait:      return .milliseconds(600)
        case .asciiWave:     return .milliseconds(800)
        case .heroTitleType: return .milliseconds(1000)
        case .goldHaloPulse: return .milliseconds(500)
        case .snakeCoil:     return .milliseconds(700)
        case .glareFlash:    return .milliseconds(200)
        case .chatSurface:   return .milliseconds(600)
        }
    }
}

// Epistemos/Hermes/HermesLandingRitualView.swift
@MainActor
struct HermesLandingRitualView: View {
    @StateObject var orchestrator: HermesLandingOrchestrator
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            Color(red: 0.039, green: 0.039, blue: 0.122)  // #0A0A1F
                .opacity(orchestrator.backgroundOpacity)

            HStack(spacing: 24) {
                AsciiPortraitView(text: orchestrator.portraitAscii)
                    .opacity(orchestrator.portraitOpacity)

                HeroWordmarkView(reveal: orchestrator.heroReveal)
            }

            HermesGoldHaloView(opacity: orchestrator.haloOpacity)
            HermesSnakeView(coilProgress: orchestrator.snakeProgress)
            GlareFlashView(progress: orchestrator.glareProgress)

            VStack {
                Spacer()
                HermesChatSurface()
                    .offset(y: orchestrator.chatSurfaceOffset)
            }
        }
        .task {
            await orchestrator.run(reduceMotion: reduceMotion)
        }
    }
}
```

**Acceptance:**
- [ ] `python3 Tools/branding_pipeline/fetch_hermes_canonical.py` runs from repo root and writes a non-empty `_probe.json` with at least one source repo (`NousResearch/hermes-agent`) reachable.
- [ ] Human reviewer promotes the chosen canonical files to `branding/hermes-agent-pixel/wordmark-hero-color.svg`, `branding/hermes-agent-pixel/mascot-snake-color.svg`, `ascii/hermes-agent-portrait.txt`. Mono variants are derived. The `raw/` staging directories are deleted from the canonical commit.
- [ ] `branding/hermes-agent-pixel/provenance.json` declares `"category": "pixel-art-mascot"`, cites the NousResearch source URLs and commit SHA, records the MIT license, and includes an attribution string for the in-app `About → Acknowledgments` view.
- [ ] `ascii/provenance.json` records origin, license, and attribution.
- [ ] `python3 Tools/branding_pipeline/validate.py` passes: the new pixel-art directory is enforced under I-16 stepped-vector rules; the ASCII directory passes a separate well-formed-text check.
- [ ] `effects/halo_hermes_gold.png` and `effects/glare_hermes.png` are present, each with deliberate stepped radial falloff (no Gaussian blur of source). Spot-check via Hex Fiend / image inspector confirms hard pixel boundaries.
- [ ] Cold launch: invoking Hermes Mode (`⌘⇧H` or double-click) runs the full 7-phase ritual in ~4.4s (±200ms tolerance for animation framing). No phase exceeds its declared duration by >10%.
- [ ] Reduce-motion: with `accessibilityReduceMotion = true`, the ritual collapses to ~450ms (cross-fade + instant assets + halo hold). No looping animation. No per-character typing. No coil. Verified by snapshot test.
- [ ] Audit View shows: ritual triggered by `companion_activity_state_changed → Active` for Hermes companion + `session_started`. Asset provenance (canonical-NousResearch vs Epistemos-fallback) is visible per asset.
- [ ] **Bit-perfect (I-16):** the hero wordmark renders at integer scale; nearest-neighbor sampling; no MSAA on the ritual render pass; halo and glare are separate additive quads with pre-baked textures.
- [ ] **No fake substitution:** if a canonical asset is missing, the Epistemos-fallback original is used and labeled in Audit. The ritual never silently substitutes another provider's brand or renders a broken-image placeholder.

**Verification:**
```bash
# 1. Probe
cd /Users/jojo/Downloads/Epistemos/.claude/worktrees/simulation
python3 Tools/branding_pipeline/fetch_hermes_canonical.py

# 2. Review
cat Resources/CompanionAssets/branding/hermes-agent-pixel/_probe.json

# 3. Promote (manual review step — pick canonical files, copy to canonical paths,
#    derive mono variants, write provenance.json, then delete raw/)

# 4. Validate
python3 Tools/branding_pipeline/validate.py

# 5. Build & smoke test
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
swift test --filter HermesLandingRitualTests
swift test --filter HermesLandingRitualReduceMotionTests

# 6. Visual capture: invoke ⌘⇧H, record screen, confirm 7-phase sequence + ~4.4s total
```

**Anti-drift:**
```bash
# Pixel-art Hermes assets must NOT use smooth-vector rendering
rg -n 'hermes-agent-pixel.*\.interpolation\(\.high\)' Epistemos
rg -n 'hermes-agent-pixel.*\.antialiased\(true\)' Epistemos
# expect empty (these assets are pixel-art, not smooth-vector)

# Smooth Hermes provider icon (LobeHub-sourced) must NOT be rendered as if it were pixel-art
rg -n '"branding/hermes-agent/[^p][^i].*\.interpolation\(\.none\)' Epistemos
# expect empty (smooth-vector provider icon must use default smoothing)

# ASCII portrait must render as Text, not as Image
rg -n 'Image\(\s*svgResource:\s*"ascii/' Epistemos
# expect empty (ASCII renders as Text)

# No runtime Gaussian blur of the hero wordmark
rg -n 'gaussianBlur|MPSImageGaussianBlur' Epistemos/Hermes
# expect empty

# Each ritual phase must be event-driven or labeled cosmetic_idle / state_transition
rg -n 'play_animation|trigger_animation' Epistemos/Hermes | rg -v 'AgentEvent\|cosmetic_idle\|state_transition'
# expect empty
```

**Non-goals:** animated SVG hero wordmark (V2+); ANSI color sequences in the ASCII portrait (V2+ — V1 is monochrome with single SwiftUI tint); ritual sound design (V3+); per-companion landing rituals beyond Hermes (V3+ — only Hermes has the privileged ritual in V1/V2).

---

### Slice S6 — Notes Sidebar agent-themed skin

**Goal:** Implement Placement C — when the user selects a companion as workspace, the sidebar re-skins (palette, title font, mascot at top, contents = that companion's vault/subagents/artifacts/adapters/sessions).

**Doctrine refs:** §3.4, §3.5.

**Files touched:**
- `Epistemos/Views/Notes/NotesSidebarView.swift` (modify — add skin layer)
- `Epistemos/Simulation/ViewModels/SidebarSkinViewModel.swift` (new)
- `Epistemos/Simulation/Skinning/CompanionTheme.swift` (new — Theme struct: palette, font, accent rules)
- `Epistemos/Simulation/Skinning/SidebarMascotPin.swift` (new — embedded mascot view)

**Theme application strategy:**

Use SwiftUI environment values + Color.dynamic to apply theme without re-rendering child trees:

```swift
struct CompanionTheme: Sendable, Equatable {
    let backgroundColor: Color
    let accentColor: Color
    let separatorColor: Color
    let titleFont: Font
    let mascot: HeadShape
    let mascotPalette: PaletteRef
}

extension EnvironmentValues {
    @Entry var companionTheme: CompanionTheme = .neutral
}

struct NotesSidebarView: View {
    @StateObject var skinVM: SidebarSkinViewModel
    var body: some View {
        VStack(spacing: 0) {
            SidebarMascotPin(headShape: skinVM.theme.mascot, palette: skinVM.theme.mascotPalette)
            CompanionVaultsSection()
            CompanionAdaptersSection()
            // ...
        }
        .background(skinVM.theme.backgroundColor)
        .environment(\.companionTheme, skinVM.theme)
        .animation(.easeInOut(duration: 0.25), value: skinVM.theme)
    }
}
```

**Acceptance:**
- [ ] Selecting a companion in the farm changes the sidebar skin (palette + font + mascot + contents) within 250ms.
- [ ] Cycling companions with `⌘⇧[` / `⌘⇧]` works.
- [ ] Neutral mode (workspace = nil) shows union view across companions.
- [ ] Sidebar re-skin is contained to the sidebar pane (titlebar / toolbar / content pane unaffected).
- [ ] No animation glitches during cross-fade transitions.

**Verification:**
```bash
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
swift test --filter SidebarSkinViewModelTests
# Manual: cycle through companions; verify visual transitions
```

**Anti-drift:**
```bash
rg -n '\.foregroundStyle\(Color\.|UIColor|NSColor\.controlAccent' Epistemos/Views/Notes/NotesSidebarView.swift
# expect: only neutral mode fallback uses system colors directly; companion skin uses theme
```

**Non-goals:** filesystem migration of existing sidebar contents; real adapter inventory UI (that's S11).

---

### Slice S7 — Graph Live Theater sub-toggle

**Goal:** Implement Placement B — the Graph view's `Nodes / Live / Theater` sub-toggle. Theater mode shows only active companions (per hysteresis), with companions spatially anchored to the graph nodes they're operating on.

**Doctrine refs:** I-9, §3.3, §3.5, §4.1.

**Files touched:**
- `Epistemos/Views/Graph/GraphView.swift` (modify — add sub-toggle)
- `Epistemos/Simulation/Views/GraphTheaterOverlay.swift` (new — Metal layer overlaid on graph)
- `Epistemos/Simulation/ViewModels/GraphTheaterViewModel.swift` (new)
- `Epistemos/Simulation/Spatial/AgentGraphAnchor.swift` (new — maps companion → current target node)

**Anchor strategy:**

When a companion fires `graph_node_accessed(node_id)`, the renderer animates the companion's position toward the node's screen-space coordinates over 400ms (eased). When no active access, the companion drifts to its "home" position relative to its current spatial role (Hermes hovers above; workers ground level).

**Acceptance:**
- [ ] Theater sub-mode shows only Active companions; transitioning to Recent maintains visibility for 30s tail; transitioning to Dormant fades out.
- [ ] Empty state shows "No active agents" (literal text from §3.6).
- [ ] Hermes hovers above graph plane; workers anchored to current target node.
- [ ] Subagent emergence works: parent glows, children pop out radially, despawn correctly on `subagent_completed`.
- [ ] Click companion → opens inspector with current task/event chain.
- [ ] Frame time ≤ 5ms p99 with 12 active companions.
- [ ] No flicker on micro-event activity (hysteresis prevents on/off churn).

**Verification:**
```bash
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
# Multi-companion scenario test
swift test --filter GraphTheaterViewModelTests
# Inject 12 simultaneous companions; record Instruments signposts; verify p99 < 5ms
```

**Anti-drift:**
```bash
rg -n 'theater.*all\(\)|.*all_companions' Epistemos/Simulation/Views/GraphTheaterOverlay.swift
# Theater overlay must use active filter, never all
```

**Non-goals:** real sprites (still placeholders); creation flow; adapter UI.

---

### Slice S8 — Companion creation flow (3 head shapes + customization)

**Goal:** Implement the 8-step creation flow with live preview, 3 head-shape options, palette/eyes/arms/prop/workspace/name customization, atomic transaction (S1 enables this), and audit log per step.

**Doctrine refs:** §5, §6, I-10.

**Files touched:**
- `Epistemos/Simulation/Creation/CompanionCreationFlow.swift` (new — sheet UI)
- `Epistemos/Simulation/Creation/CreationStep.swift` (new — enum)
- `Epistemos/Simulation/Creation/CompanionPreviewView.swift` (new — live composed sprite preview)
- `Epistemos/Simulation/Creation/PresetCatalog.swift` (new — Claude Code (Block-Wide), Kimi (Block-Compact), Codex (Block-Compact white), GPT (Orb), Hermes (Snake), Local (Block-Compact teal); see DOCTRINE §5.4)
- `Epistemos/Simulation/ViewModels/CreationFlowViewModel.swift` (new)
- `crates/agent_core/src/companions/spec.rs` (new — `CompanionSpec` validation)

**Compile-time route enum (avoid AnyView):**

```swift
enum CreationStepRoute: Hashable {
    case presetPick
    case headShape
    case palette
    case eyes
    case arms
    case prop
    case workspace
    case name
    case review
}

@MainActor
struct CompanionCreationFlow: View {
    @StateObject var vm: CreationFlowViewModel
    var body: some View {
        NavigationStack(path: $vm.route) {
            CreationPresetPickStep(vm: vm)
                .navigationDestination(for: CreationStepRoute.self) { route in
                    switch route {
                    case .headShape:  CreationHeadShapeStep(vm: vm)
                    case .palette:    CreationPaletteStep(vm: vm)
                    case .eyes:       CreationEyesStep(vm: vm)
                    case .arms:       CreationArmsStep(vm: vm)
                    case .prop:       CreationPropStep(vm: vm)
                    case .workspace:  CreationWorkspaceStep(vm: vm)
                    case .name:       CreationNameStep(vm: vm)
                    case .review:     CreationReviewStep(vm: vm)
                    case .presetPick: EmptyView()
                    }
                }
        }
    }
}
```

**Live preview composes sprite axes in real time:**

```swift
struct CompanionPreviewView: View {
    let spec: CompanionSpec
    var body: some View {
        ZStack {
            BodyLayer(headShape: spec.headShape, palette: spec.palette)
            ArmsLayer(arms: spec.arms)
            EyesLayer(eyes: spec.eyes)
            if let prop = spec.prop { PropLayer(prop: prop) }
        }
        .frame(width: 96, height: 96)
        .accessibilityLabel("Companion preview")
    }
}
```

(Preview uses SwiftUI image layers for the wizard; actual gameplay rendering uses Metal — preview is small enough that SwiftUI is fine here.)

**Acceptance:**
- [ ] 8 steps navigable forward and backward.
- [ ] Live preview updates per step.
- [ ] Validation per DOCTRINE §6.2 (each step blocks until valid).
- [ ] Atomic transaction completes in ≤ 300ms p95 (per §12).
- [ ] Audit log entry written with full diff.
- [ ] Cancel at any step rolls back cleanly (no orphaned vault folders).
- [ ] Preset selection pre-fills downstream steps but allows override.
- [ ] Creation produces a working companion: appears on Landing Farm with rainbow-flash entrance.

**Verification:**
```bash
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
swift test --filter CreationFlowViewModelTests
cargo test -p agent_core --lib companions::transaction
```

**Anti-drift:**
```bash
rg -n 'AnyView' Epistemos/Simulation/Creation
# expect empty
rg -n 'CompanionSpec\s*\{' crates/agent_core/src | rg -v 'validate'
# every spec construction must validate
```

**Non-goals:** Hermes preset (separate slice S9); adapter-time customization (S11); real-time fine-tuning during creation.

---

### Slice S9 — Hermes graph faculty + landing transformation

**Goal:** Wire Hermes Agent through MCP-over-stdio with the seven graph verbs; implement the landing-page transformation ritual; add the Hermes Snake mascot atlas.

**Doctrine refs:** §8, I-1, I-2.

**Files touched:**
- `crates/omega-mcp/src/graph_tools.rs` (modify or new — expose seven verbs)
- `crates/omega-mcp/src/hermes_session.rs` (new — Hermes session lifecycle)
- `Epistemos/Hermes/HermesLandingTransform.swift` (new — ASCII wave + glare + type-on)
- `Epistemos/Hermes/HermesSession.swift` (new)
- `Resources/CompanionAssets/atlas/hermes_snake.png` (asset; legal-safe original drawing)

**MCP graph tool registration:**

```rust
// crates/omega-mcp/src/graph_tools.rs

pub fn register_graph_tools(server: &mut McpServer, graph: Arc<GraphEngine>) {
    server.register_tool("graph.search_semantic", graph_search_semantic_tool(graph.clone()));
    server.register_tool("graph.search_fulltext", graph_search_fulltext_tool(graph.clone()));
    server.register_tool("graph.get_node", graph_get_node_tool(graph.clone()));
    server.register_tool("graph.traverse", graph_traverse_tool(graph.clone()));
    server.register_tool("graph.create_node", graph_create_node_tool(graph.clone()));
    server.register_tool("graph.create_edge", graph_create_edge_tool(graph.clone()));
    server.register_tool("graph.commit_session", graph_commit_session_tool(graph.clone()));
}

fn graph_search_semantic_tool(graph: Arc<GraphEngine>) -> Tool {
    Tool::new()
        .name("graph.search_semantic")
        .description("Search the cognitive graph by semantic similarity.")
        .input_schema(json!({
            "type": "object",
            "properties": {
                "query": { "type": "string" },
                "k": { "type": "integer", "default": 10, "minimum": 1, "maximum": 100 },
                "scope": { "type": "string", "description": "GraphSlice id; defaults to active companion's slice" }
            },
            "required": ["query"]
        }))
        .handler(move |args, ctx| {
            let graph = graph.clone();
            async move {
                let q: SemanticQuery = serde_json::from_value(args)?;
                let results = graph.search_semantic(&q.query, q.k.unwrap_or(10), q.scope).await?;
                // Emit AgentEvent::GraphTraverseStarted/Completed for each hit
                ctx.emit_event(AgentEvent::GraphTraverseCompleted {
                    agent_id: ctx.companion_id(),
                    visited: results.iter().map(|r| r.node_id).collect(),
                });
                Ok(json!({ "results": results }))
            }
        })
}
```

**Acceptance:**
- [ ] All seven graph tools callable via MCP from a Hermes subprocess.
- [ ] Each call emits the correct AgentEvent / GraphEvent (verified via fixture replay).
- [ ] Hermes mode toggle (`⌘⇧H` or double-click on Hermes companion) plays the landing transformation in 2.5s total.
- [ ] Session created, audit log entry written, registry updated.
- [ ] Hermes Snake atlas renders correctly above worker companions in graph theater.
- [ ] Hermes-specific sidebar skin applies (gold palette, New York Bold Italic font).
- [ ] Terminal pane (debug) toggleable via dev menu; not source of truth.

**Verification:**
```bash
cargo test -p omega-mcp --lib graph_tools
# integration: spawn a mock MCP client, invoke each tool, verify event emission
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
# manual: trigger Hermes mode, verify ritual + functioning chat surface
```

**Anti-drift:**
```bash
rg -n 'hermes.*Worker\|HeadShape::(Block|Sage|Orb).*[Hh]ermes' Epistemos crates 2>/dev/null
# Hermes must use HermesSnake head shape, never share Block/Sage/Orb
```

**Non-goals:** Deep Deliberation visual integration (S13); auto-companion synthesis from Hermes (V3+).

---

### Slice S10 — Animated raster atlas pipeline (V1 sprites)

**Goal:** Replace placeholder geometry with real pixel-art animated sprites for Block (Compact and Wide variants), Orb, Sage, Hermes_Snake; build the atlas pipeline (concept → ControlNet → Aseprite refinement → atlas pack → manifest); migrate fragment shader from placeholder to real palette-mask sampling. **This slice is the *animated atlas* pipeline; static branding SVGs are handled by Slice S5.5 — do not conflate them.**

**Doctrine refs:** §5, §10, I-15.

**Files touched:**
- `Tools/asset_pipeline/concept_gen.py` (new)
- `Tools/asset_pipeline/aseprite_refine.lua` (new — Aseprite scripting)
- `Tools/asset_pipeline/auto_slice.py` (new — OpenCV slicing)
- `Tools/asset_pipeline/atlas_pack.py` (new)
- `Tools/asset_pipeline/manifest_gen.py` (new)
- `Tools/asset_pipeline/validate.py` (new — CI check)
- `Resources/CompanionAssets/atlas/*.png` (assets)
- `Resources/CompanionAssets/atlas/*.json` (manifests)
- `Resources/CompanionAssets/provenance/*.json` (legal record)
- `Epistemos/Simulation/Shaders/Companion.metal` (modify — real fragment with palette mask)
- `docs/simulation-mode/character-dna/*.md` (Character DNA per preset, human-authored)

**Real fragment shader:**

```metal
// Epistemos/Simulation/Shaders/Companion.metal (real version)

struct Palette {
    float4 body;       // RGBA
    float4 accent;
    float4 eye;
};

fragment float4 companion_fragment(
    VertexOut in [[stage_in]],
    texture2d_array<float> atlas [[texture(0)]],
    constant Palette* palettes [[buffer(1)]],
    sampler s [[sampler(0)]]
) {
    float2 atlas_uv = computeAtlasUV(in.uv, in.frame_index, in.atlas_index);
    float4 mask = atlas.sample(s, atlas_uv, in.atlas_index);
    Palette p = palettes[in.palette_id];
    // R channel = eye region, G = accent region, B = body region; A = alpha
    float3 color = mask.b * p.body.rgb
                 + mask.g * p.accent.rgb
                 + mask.r * p.eye.rgb;
    return float4(color * in.tint.rgb, mask.a * in.tint.a);
}
```

**Pipeline gate (CI):**

```python
# Tools/asset_pipeline/validate.py
REQUIRED_STATES = ["idle", "walk", "think", "speak", "tool", "spawn",
                   "handoff_give", "handoff_receive", "retrieve",
                   "error", "recover", "success", "sleep", "gate"]

def validate_atlas(atlas_path, manifest_path):
    manifest = json.load(open(manifest_path))
    states = set(manifest["states"].keys())
    missing = set(REQUIRED_STATES) - states
    assert not missing, f"Missing animation states: {missing}"
    # ... atlas dimensions, region reachability, provenance presence
```

**Acceptance:**
- [ ] Atlases built for Block, Sage, Orb, Hermes_Snake.
- [ ] All 14 animation states present per atlas.
- [ ] Provenance manifest exists for every atlas (license, seed, human editor, model used).
- [ ] CI validation passes.
- [ ] Real fragment shader renders sprites correctly with palette mask.
- [ ] Custom palette slider in creation flow updates sprite color in real time.
- [ ] Texture memory ≤ 50 MB (per §12).
- [ ] No verbatim copying of Kimi CLI / Claude Code mascot pixels (visual diff against reference + human review documented in provenance).

**Verification:**
```bash
python Tools/asset_pipeline/validate.py
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
# Frame capture: open Theater, capture frame, verify sprite renders correctly with palette mask
```

**Anti-drift:**
```bash
# Every atlas must have provenance
ls Resources/CompanionAssets/atlas/*.png | while read f; do
  prov="Resources/CompanionAssets/provenance/$(basename "$f" .png).json"
  test -f "$prov" || echo "MISSING PROVENANCE: $f"
done
# expect no output
```

**Non-goals:** overlay assets for V2 customization (deferred to S11 if not done here); accessory unlocks (V2+).

---

### Slice S11 — Adapter gift-box system

**Goal:** Implement the `.epbox` package format, the unwrap UX flow with honesty-bound animation duration, the Mailroom sidebar surface, and the seven V1 gift-box content types.

**Doctrine refs:** §7, I-11, I-12.

**Files touched:**
- `crates/agent_core/src/adapters/epbox.rs` (new — package parser/validator)
- `crates/agent_core/src/adapters/applier/*.rs` (new — one per content type)
- `Epistemos/Simulation/GiftBox/MailroomView.swift` (new)
- `Epistemos/Simulation/GiftBox/UnwrapAnimationView.swift` (new)
- `Epistemos/Simulation/ViewModels/MailroomViewModel.swift` (new)

**Honesty-bound animation:**

```swift
@MainActor
final class UnwrapAnimationViewModel: ObservableObject {
    @Published var phase: UnwrapPhase = .idle
    enum UnwrapPhase { case idle, approaching, opening, waiting, success, failure }

    func unwrap(_ box: GiftBoxRef, on companion: CompanionRef) async {
        phase = .approaching
        try? await Task.sleep(for: .milliseconds(400))
        phase = .opening
        try? await Task.sleep(for: .milliseconds(300))
        phase = .waiting
        // Apply runs in parallel; we LOOP the wait animation until apply completes.
        let applyTask = Task { try await rustBridge.applyGiftBox(box, to: companion) }
        // Loop the wait animation; honesty: NEVER complete before apply.
        var loopCount = 0
        while !applyTask.isFinished && loopCount < 8 {
            try? await Task.sleep(for: .milliseconds(500))
            loopCount += 1
        }
        // If still not done, keep waiting with progress chip.
        do {
            let result = try await applyTask.value
            phase = .success
        } catch {
            phase = .failure
        }
    }
}
```

**Acceptance:**
- [ ] Seven V1 epbox types parse, validate, and apply atomically.
- [ ] Unwrap animation duration ≥ apply duration in all cases (test: synthetic adapter with 2s apply must show ≥ 2s animation).
- [ ] Failed apply shows failure state; gift box returns to mailroom.
- [ ] Audit log entry written with full config diff.
- [ ] MAS profile rejects sideloaded `.epbox` files; only registry-fetched ones allowed.
- [ ] Pro profile allows filesystem import.
- [ ] Reversible adapters can be reverted via mailroom UI.

**Verification:**
```bash
cargo test -p agent_core --lib adapters
swift test --filter UnwrapAnimationViewModelTests
# property test: for any synthetic apply duration in [50ms, 5s], animation duration >= apply duration
```

**Anti-drift:**
```bash
rg -n 'phase = \.success' Epistemos/Simulation/GiftBox | rg -v 'await applyTask'
# success phase must follow await of apply
```

**Non-goals:** auto-companion gift boxes (V3); LoRA adapters (V2 Pro-only, separate slice).

---

### Slice S12 — Subagent + handoff visual events

**Goal:** Implement the multi-companion mechanics: subagent spawn/despawn, handoff scroll passing, memory retrieval visuals, approval gates physically blocking execution.

**Doctrine refs:** §4.

**Files touched:**
- Reducer additions in `crates/agent_core/src/simulation/reducer.rs`
- Effects atlas in `Resources/CompanionAssets/effects/`
- Animation wiring in `Epistemos/Simulation/MetalSimulationRenderer.swift`

**Acceptance:**
- [ ] All animations from DOCTRINE §4.2–§4.7 render correctly.
- [ ] Subagent stack discipline enforced (V1: depth ≤ 1; warning logged on attempt to spawn deeper).
- [ ] Approval gates physically block companion animation (cosmetic_idle frozen until resolved).
- [ ] Stale handoffs (no `handoff_completed` within 5s) show "?" emote until resolved or session ends.
- [ ] Frame time still ≤ 5ms p99 with 12 active + 24 subagents.

**Verification:**
```bash
cargo test -p agent_core --test multi_companion_replay
swift test --filter SubagentAnimationTests
```

**Non-goals:** Deep Deliberation stage layout (S13).

---

### Slice S13 — Replay/scrub timeline + Deep Deliberation visual integration

**Goal:** Add a session timeline scrubber (drag to replay simulation state at any point); introduce the Deep Deliberation stage layout (Optimist / Pessimist / Researcher groups visible per role).

**Doctrine refs:** I-13, §4.8.

**Files touched:**
- `Epistemos/Simulation/Timeline/SessionTimelineView.swift` (new)
- `Epistemos/Simulation/Timeline/TimelineViewModel.swift` (new)
- `Epistemos/Simulation/Deliberation/DeliberationStageView.swift` (new)
- `crates/agent_core/src/replay.rs` (extend with seek API)

**Replay seek:**

```rust
pub fn seek_to(events: &[AgentEvent], target_event_id: EventId) -> SimulationState {
    let mut state = SimulationState::initial();
    for event in events {
        if event.id() > target_event_id { break; }
        let _ = reduce(&mut state, event.clone());
    }
    state
}
```

**Acceptance:**
- [ ] Drag scrubber → simulation re-renders state at that timestamp deterministically.
- [ ] Deliberation stage layout positions companions by role (optimist left, pessimist right, researcher center, moderator hovering).
- [ ] Cross-bubble lines (claim → objection) draw correctly.
- [ ] Replay performance ≤ 100ms for sessions up to 10K events.

**Non-goals:** Browser Witness mode (Pro-only, V4+); Research Council artifact storage (separate doc/feature).

---

### Slice S14 — Polish, accessibility, reduce-motion, MAS validation

**Goal:** Final polish, accessibility audit, reduce-motion full coverage, MAS profile shipping validation.

**Doctrine refs:** I-12, I-14.

**Files touched:**
- All views — add `.accessibilityLabel` / `.accessibilityValue`
- Reduce-motion hooks in renderer
- MAS gate audit script

**Acceptance:**
- [ ] Reduce-motion mode: all looping animations stop; activity transitions use color/badge only; subagent spawn shows children with flash, no radial burst.
- [ ] VoiceOver: every companion, every prop, every animation state has a meaningful label.
- [ ] MAS build compiles with `EPISTEMOS_PROFILE_MAS` flag.
- [ ] No `Process()`, `posix_spawn`, AX-without-entitlement, or arbitrary file import in MAS code paths.
- [ ] All performance budgets from §12 met or under.
- [ ] Full audit pass per `docs/simulation-mode/MASTER_PROMPT` style audit ontology.

**Verification:**
```bash
xcodebuild -scheme Epistemos -configuration Release -destination 'platform=macOS' \
  EPISTEMOS_PROFILE=MAS build 2>&1 | xcbeautify
xcodebuild -scheme Epistemos -configuration Release -destination 'platform=macOS' \
  EPISTEMOS_PROFILE=PRO build 2>&1 | xcbeautify
swift test
cargo test --workspace
```

**Anti-drift:**
```bash
# MAS gate: forbid Process() in MAS-included files
rg -n 'Process\(|Process\.init\(|posix_spawn|fork\(' \
  Epistemos --include='*.swift' \
  | grep -v 'EPISTEMOS_PROFILE_PRO'
```

---

## 4. Forbidden Patterns (Implementation-time)

In addition to DOCTRINE §14 and §5.7 (bit-perfect), these implementation-specific patterns are forbidden:

| Pattern | Reason |
|---|---|
| `let _ = reduce(...)` ignoring deltas in production | always handle deltas; ignore is for tests only |
| `Box<dyn Fn>` in reducer hot path | allocation per call |
| Creating new MTLBuffer per frame | allocate once, reuse |
| Implicit `Any` in JSON manifest parsing | use typed `serde_json` deserialization |
| Spinning loop for waiting on async result | use proper await / signal |
| Creating MTLSamplerState per draw | cache; samplers are cheap to keep |
| `MTLSamplerMinMagFilter.linear` anywhere on a sprite or branding atlas | I-16; smooths pixels |
| `view.sampleCount > 1` on any sprite render pass | I-16; introduces MSAA bleed |
| Mipmaps generated for sprite atlases (`generateMipmaps:`) | I-16; wrong filter at distance |
| Fractional sprite scale matrices (`scale * 1.5`, `2.5x`) crossing FFI | I-16; breaks pixel grid |
| Sub-pixel camera position interpolation (eased smooth-scroll) | I-16; ghost trails |
| `MPSImageGaussianBlur` / runtime blur of sprite textures | I-16; halos must be pre-baked separate-quad textures |
| SVG `<circle>` / `<ellipse>` in `Resources/CompanionAssets/branding/` | I-16; use stepped `<path>` |
| SVG `<path d="...">` containing `C`, `S`, `Q`, `T`, or `A` commands in `branding/` | I-16; only M/L/H/V/Z |
| SwiftUI `Image(...).interpolation(.high\|.medium\|.low)` for **pixel-art** branding (`branding/<slug>/` where `provenance.json` `"category": "pixel-art-mascot"`) | I-16; must be `.none` |
| `NSGraphicsContext.imageInterpolation = .high\|.medium\|.low\|.default` when rasterizing **pixel-art** branding SVGs | I-16; must be `.none` |
| `colorPixelFormat = .bgra8Unorm_srgb` on sprite passes | I-16; gamma re-encode adds intermediate values |
| `.interpolation(.none)` / `.antialiased(false)` / `imageInterpolation = .none` on **smooth-vector-brand** provider icons (`branding/<slug>/` where `provenance.json` `"category": "smooth-vector-brand"`) | I-16 carve-out (DOCTRINE §10.7); these icons are smooth-vector and must use `.interpolation(.high)` / `.antialiased(true)` to render correctly. Forcing pixel-snap on a Bezier logo creates broken artifacts. |
| Provider brand icon (`anthropic`, `openai`, `gemini`, etc.) sampled by Metal sprite pipeline | DOCTRINE §10.7 — smooth provider icons render through SwiftUI only. They are **not** companion sprites. |
| Pixel-art mascot SVG used in Settings provider list | DOCTRINE §10.7 — Settings uses `icon-color.svg` from a smooth-vector-brand provider directory (e.g., `branding/anthropic/icon-color.svg`), not a pixel-art mascot. |
| Provider API keys stored or edited in `CompanionsPickerView` (sidebar) | DOCTRINE §3.4 v1.3 — sidebar picker is read-only navigation; per-provider config lives in Settings only. |

---

## 5. Required Instrumentation per Slice

Every slice must add signposts at the boundaries it crosses:

| Slice | Required signposts |
|---|---|
| S0 | (sets up framework) |
| S1 | `companion.create`, `companion.archive`, `activity.tick` |
| S2 | `event.normalize.<provider>`, `event_log.append`, `replay` |
| S3 | `audit.record` |
| S4 | `theater.frame`, `ffi.delta_drain` |
| S5 | `landing.refresh` |
| S6 | `sidebar.skin_change` |
| S7 | `graph_theater.frame` (if separate from S4), `hysteresis.transition` |
| S8 | `companion.create_flow.<step>` |
| S9 | `hermes.tool.<tool_name>`, `hermes.landing_transform` |
| S10 | `atlas.load` (startup only) |
| S11 | `gift_box.unwrap.<type>` |
| S12 | `subagent.spawn`, `handoff.start`, `handoff.complete` |
| S13 | `timeline.seek`, `deliberation.stage` |
| S14 | (final audit) |

---

## 6. Verification Command Reference

For local CI / pre-merge:

```bash
# Build
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
cargo build --workspace --release

# Tests
swift test
cargo test --workspace

# Lints
swiftlint
cargo clippy --workspace -- -D warnings

# Anti-drift sweep
./Tools/anti_drift_check.sh

# Performance gate
./Tools/perf_check.sh

# MAS / Pro split validation
./Tools/profile_split_check.sh

# Asset pipeline validation
python Tools/asset_pipeline/validate.py

# Audit log self-consistency
cargo test -p agent_core --test audit_consistency_property
```

---

## 7. Cross-slice invariants (always-true)

Across all slices, these must remain true. If a slice violates one, the slice is incomplete:

1. The 2,679-test suite (and its successor) must pass after every slice.
2. App must launch and reach Landing Farm within 2 seconds (cold start).
3. Idle CPU ≤ 1%.
4. Idle memory ≤ 300 MB.
5. No new use of `AnyView`, `[String: Any]`, `try!`, `as!`, force-unwrap, `Process()` (in MAS), `arc4random` in reducer.
6. Every visible animation has a corresponding audit ledger entry.
7. Every companion-state mutation goes through `CompanionRegistry::transaction()`.
8. Every cloud-message thinking block is preserved (per CLAUDE.md).
9. Every `MTLRenderPipelineState` is loaded from `MTLBinaryArchive`, never compiled on the main thread post-launch.
10. Every signpost matches the form `epistemos.simulation.<slice>.<operation>`.

---

## 8. Drift detection — pre-merge ritual

Before any commit on a slice:

```bash
git status --short --untracked-files=all
git diff --stat
git diff --check                    # whitespace check
./Tools/anti_drift_check.sh         # forbidden patterns sweep (includes I-16 sweeps below)
swift test
cargo test --workspace
./Tools/perf_check.sh               # budget gate
./Tools/profile_split_check.sh      # MAS/Pro gate
python Tools/branding_pipeline/validate.py   # I-16 stepped-vector SVG gate
git diff -- docs/simulation-mode/   # ensure docs reconciled

# Bit-perfect (I-16) sweeps — must all return empty
rg -n 'MTLSamplerMinMagFilter\.linear' Epistemos
rg -n 'sampleCount\s*=\s*[2-9]|sampleCount\s*=\s*1[0-9]' Epistemos
rg -n 'generateMipmaps|mipFilter\s*=\s*\.linear' Epistemos
rg -n 'MPSImageGaussianBlur|gaussianBlur' Epistemos
rg -n '\.interpolation\(\.(high|medium|low)\)' Epistemos
rg -n 'imageInterpolation\s*=\s*\.(high|medium|low|default)' Epistemos
rg -n 'colorPixelFormat\s*=\s*\.bgra8Unorm_srgb' Epistemos/Simulation
```

If any check fails: **commit is blocked**. Fix in place. Do NOT bypass with `--no-verify`. Do NOT comment out failing tests. Do NOT widen the test name to make it green falsely.

---

## 9. Slice ↔ Doctrine reconciliation map

| Doctrine section | Implementing slice(s) |
|---|---|
| §1 Invariants | enforced across all slices |
| §3.1 Registry | S1 |
| §3.2 Landing Farm | S5 |
| §3.3 Graph Theater | S7 |
| §3.4 Sidebar Skin | S6 (uses S5.5 pixel-art branding + S5.6 provider icons) |
| §3.4 v1.4 three-level Companions picker | S5.6 (CompanionsPickerView with Company → Model → Agent levels), S6 (sidebar integration), S8 (model-row `+` seeds creation flow) |
| §5.6 SVG vs Metal hybrid | S5.5 (pixel-art SVG side), S5.6 (smooth-vector SVG side), S5.7 (canonical Hermes pixel-art), S10 (atlas side), §2.3 |
| §8.2 v1.4 Hermes opulent landing ritual | S5.7 (canonical assets + 7-phase sequence + reduce-motion variant), S9 (Hermes graph-faculty session wiring) |
| §10.6 Pixel-art SVG branding pipeline | S5.5 |
| §10.7 Provider Brand Icon System | S5.6 (fetch + integration), validator branch in S5.5 |
| §10.4 v1.4 ASCII art directory | S5.7 (canonical Hermes portrait + banner) |
| §3.5 Cross-placement sync | S5, S6, S7 (foundation), continuous |
| §4 Agent-to-agent mechanics | S12 |
| §4.8 Deep Deliberation visuals | S13 |
| §5 Body grammar | S8, S10 |
| §6 Creation flow | S8 |
| §7 Adapter gift-box | S11 |
| §8 Hermes graph faculty | S9 |
| §9 Honesty doctrine | S3 (audit), enforced everywhere |
| §10 Asset pipeline | S10 |
| §11 Event schema | S2 |
| §12 Performance budgets | S0 (framework), enforced in S4, S7, S11, S14 |
| §13 MAS / Pro split | S14 (validation), enforced in S11 |
| §14 Anti-drift rules | enforced everywhere |
| §15 Non-goals | enforced through review |

If a doctrine section has no implementing slice, the doctrine is over-scoped or the plan is missing a slice. Reconcile before proceeding.

---

## 10. Open questions for V3+ (deferred)

Listed here so they don't get lost:

- Browser Witness Mode for Deep Deliberation (Pro-only; needs careful UX around provider TOS compliance).
- Auto-companion synthesis from Hermes observation patterns (V3+).
- Cross-vault graph slice federation (Pro-only, V3+).
- Local fine-tune subprocess for adapter generation (Pro-only, V3+).
- LoRA application via MLX through MLX-Swift bindings (Pro-only, V2/V3).
- Companions on the lock screen / menu bar (rejected per §15 unless reconsidered).
- AI-driven farm-position arrangement (companions auto-cluster by usage pattern).

These are placeholders for future doctrine extensions. Do not implement until the doctrine is updated to include them.

---

## 11. Versioning and reconciliation

- **Plan version:** 1.6
- **Doctrine version reconciled against:** 1.6
- **Created:** 2026-04-29 (in `simulation` worktree)
- **v1.0 → v1.1:** added Slice S5.5 (SVG branding pipeline) reflecting DOCTRINE §5.6 + §10.6; updated S10 scope to clarify it is the *animated raster atlas* pipeline only; updated §2.3 with SVG/Metal pipeline split; reconciliation map updated.
- **v1.1 → v1.2:** absorbed DOCTRINE I-16 + §5.7 (bit-perfect pixel rendering). Added §2.4.1–§2.4.4 (sampler/scale/snap/halo Metal contract with code). Updated S4 acceptance to verify nearest-neighbor sampling, MSAA off, integer scale, snap-to-pixel; added halo additive-pass acceptance. Updated S5.5 SVG validator to reject `<circle>`, `<ellipse>`, `C/S/Q/T/A` path commands and non-integer coordinates. Updated S8 PresetCatalog reference to Block-Wide / Block-Compact / Orb / Snake (no Sage in Big-Four). Forbidden-patterns table extended with linear sampler, MSAA, Bezier branding paths, mipmaps, fractional scale, sub-pixel scroll, sRGB sprite format, runtime Gaussian blur. Pre-merge ritual sweep extended.
- **v1.2 → v1.3:** absorbed DOCTRINE §10.7 (Provider Brand Icon System) + §3.4 v1.3 (Companions picker). Added Slice S5.6 (provider icon fetcher + integration) — `Tools/branding_pipeline/fetch_lobe_icons.py` script, ProviderSlug enum, ProviderIcon SwiftUI view, BrandingVariant + BrandingSurface enums, CompanionsPickerView, Settings provider rows, chat-header chips, command-palette glyphs, audit attribution. Updated `Tools/branding_pipeline/validate.py` (S5.5) to branch by `provenance.json` `"category"` flag — `pixel-art-mascot` enforces I-16; `smooth-vector-brand` skips path-command checks. Updated §2.3 pipeline-split table from 2 pipelines to 3 (pixel-art SVG, smooth-vector SVG, raster atlas). Added 4 new forbidden-pattern rows covering the carve-out (smooth icons must NOT use `.interpolation(.none)`; pixel-art mascots must NOT use `.high`; cross-category sampling forbidden; Settings is the only legal home for API keys). Reconciliation map extended.
- **v1.3 → v1.4:** absorbed DOCTRINE §3.4 v1.4 (three-level Company → Model → Agent picker), §8.2 v1.4 (opulent canonical Hermes landing ritual: 7-phase sequence sourced from NousResearch hermes-agent), §10.4 + §10.7 v1.4 (added `branding/hermes-agent-pixel/` and `ascii/` directories; hermes-agent dual-sourced). Added Slice S5.7 (Hermes canonical assets + opulent landing ritual). Updated S5.6 acceptance for the three-level picker (Company → Model → Agent, with model-row `+` affordance, Local company synthesis, empty-state hide rules). Updated reconciliation map with §3.4 v1.4 and §8.2 v1.4 entries. New script `Tools/branding_pipeline/fetch_hermes_canonical.py` (read-only probe). New asset directories `branding/hermes-agent-pixel/` and `ascii/`. New additive-pass effect textures `halo_hermes_gold.png` and `glare_hermes.png`.
- **v1.4 → v1.6:** absorbed the cohesive DOCTRINE v1.6 expansion in a single revision (no published v1.5 — the v1.6 doctrine pass combines what would have been v1.5's farm walking + multi-toggle vault changes with v1.6's dispatch / multi-room / knowledge-brick additions). Sections added: §3.2.1 (farm walking), §3.2.2 (working badge + inline dispatch + steering), §3.3.1 (multi-room theater — one room per active session, single MTKView with viewport tiling), §3.3.2 (graph as full chat replacement), §3.4.1 (persistent vault hierarchy from Model down), §3.4.2 (multi-toggle sidebar), §3.4.3 (knowledge-brick design language), §3.4.4 (multi-vault UI affordances), §3.4.5 (helper-model summariser). Six new `AgentEvent` variants in §11 (`SteerRequested`, `SummaryStarted` / `SummaryDelta` / `SummaryCompleted`, `VaultCreated`, `VaultArchived`). **All §1 invariants unchanged.** Performance budgets from §12 hold: multi-room is N tile draws on one shared pipeline + atlas + sampler — only viewport + camera + buffer-region differ per room, so the §12 ≤ 5 ms p99 frame budget covers ~6 rooms at 12 companions total.

When DOCTRINE.md is updated:
- MAJOR doctrine bump → this plan must be re-walked end-to-end; affected slices flagged for re-audit.
- MINOR doctrine bump → identify which slices are affected; reconcile their acceptance criteria.
- PATCH doctrine bump → editorial sync only; no implementation impact.

The plan version trails the doctrine version with `<doctrine>.<plan_revision>`.

---

End of plan.
