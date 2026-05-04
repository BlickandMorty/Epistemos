# Simulation Mode — Canonical Doctrine — v1.6

> **Status:** CANONICAL. This is the source of truth for Simulation Mode in Epistemos.
> **Authority:** Any code, ViewModel, asset, or doc that contradicts this file is DRIFT and must be reconciled before merge.
> **Companion doc:** `docs/simulation-mode/IMPLEMENTATION.md` (build plan, code snippets, slice order).
> **Change protocol:** Invariants in §1 may not be edited without explicit user approval. Sections §3–§9 may be expanded but not reduced. Any contradiction between this doc and the implementation is a defect in the implementation, not the doc.
> **Worktree:** This doctrine is maintained in the `simulation` worktree. Land it on `main` only after the user reviews.

---

## 0. Why this doc exists

Big-tech AI surfaces will copy chat sidebars, source-grounded summaries, and MCP tool integration. They cannot easily copy a **deterministic visual projection of a graph-native agent runtime built on a typed cognitive substrate**. That is the moat.

Simulation Mode makes the moat **felt** in 60 seconds. Without this surface, the architectural depth of Epistemos is invisible to a new user. With it, the system becomes an embodied cognitive workspace where agents are physically present, memory is spatial, and provenance is watchable.

This doctrine exists because the surface only works if it never lies. A pretty animation that doesn't correspond to real backend work would corrode trust faster than no animation at all. Every rule below exists to enforce that line.

---

## 1. Non-Negotiable Invariants

These are the rules. They do not negotiate. If a feature requires breaking one, the feature is wrong, not the rule.

### I-1. Graph is semantic truth.
Every artifact, mutation, recall, claim, plan, run, and tool call lives in the Rust-owned graph (substrate-core / SQLite / FTS5). Simulation Mode reads. It does not write parallel state.

### I-2. Session is the canonical runtime unit.
A session has an ID, a mode, participants, an event log, artifacts, graph links, and a status. Every visible companion action belongs to a session. There is no "ambient agent activity" outside a session.

### I-3. AgentEvent is the runtime bloodstream.
All providers (Hermes, Claude, GPT, Kimi, local MLX) normalize their streams into a single `AgentEvent` enum. Simulation Mode never reads provider-specific payloads. It reads `AgentEvent`.

### I-4. GraphEvent is the proof of mutation.
Any change to the graph (node/edge created, accessed, traversed) emits a `GraphEvent`. Simulation Mode animates from `GraphEvent`s only. No simulation animation may imply a graph mutation that didn't happen.

### I-5. Every animation maps to a real event.
This is the honesty doctrine. There are exactly three classes of allowed animation:
- **Event-driven:** triggered by an `AgentEvent` or `GraphEvent`. Always allowed.
- **Idle ambient:** bound to "no events for ≥ N seconds" — looped breathing, blinking, micro-fidget. Labeled `cosmetic_idle` in the audit ledger.
- **Approval/error gates:** triggered by `awaiting_approval` / `error` / `recovery_*` events. The companion physically pauses; the gate blocks until the corresponding `approval_*` / `recovery_completed` event fires.

A "thinking" pose without a backing `thinking_started` event is a defect. A "spawning subagent" pose without a backing `subagent_spawned` event is a defect. Period.

### I-6. Native rendering only.
The app spine is Swift 6.2 / SwiftUI / AppKit / Metal. **Full Bevy is forbidden as the app spine.** It hijacks the main loop, fights `MainActor`, and degrades battery (empty Bevy app ≈ 50% CPU on Apple Silicon).
- `bevy_ecs` (the ECS crate alone, no app/runtime) is **conditionally allowed** but only after Slice S12, only behind a feature flag, and only if entity count exceeds ~50 active sprites or behavior composition demands it. Until then: pure Rust event-sourced reducer.

### I-7. Rust owns simulation state. Swift owns rendering and lifecycle.
The reducer, registry, persistence, hysteresis, and event log live in Rust. The Metal renderer, view-models, MainActor lifecycle, and AppKit/SwiftUI bindings live in Swift. The boundary is a typed FFI envelope.

### I-8. FFI is zero-copy where measured to matter.
- Frame deltas (sprite position/scale/atlas index/tint) cross the boundary as `UnsafeBufferPointer<PerInstanceData>` written directly into a `MTLBuffer`-backed allocation.
- Atlas textures are `IOSurface`-backed so Rust-side asset pipeline and Swift-side `MTLTexture` share memory.
- Control events (registry mutations, gift-box unwraps) cross via UniFFI for ergonomics; they are not hot-path.
- Hot deltas (>100 Hz) cross via a lock-free SPSC ring buffer in shared memory; UniFFI is **forbidden** for these.

### I-9. Companions exist in three placements. Not four. Not two.
**Landing Farm**, **Graph Live Theater**, **Notes Sidebar Skin**. Cross-placement state derives from a single `CompanionRegistry`. See §3.

### I-10. Customization choices map to real config.
Every cosmetic choice in the creation flow either (a) maps to a real `ModelProfile` config knob, or (b) is explicitly labeled `cosmetic` in the audit ledger. There is no third category. See §6.

### I-11. Adapter unwrap animation duration ≥ adapter apply duration.
If applying a LoRA takes 800ms, the unwrap animation runs for 800ms. If apply fails, the unwrap shows the failure state. The animation never completes ahead of the work. See §7.

### I-12. App Store profile must remain shippable.
Simulation Mode core is MAS-safe (no shell, no `Process()`, no AX outside entitlements, no arbitrary file import). Power features (Pro-only adapter sideload, browser-witness deliberation, raw subprocess spawning) live behind compile gates and runtime profile checks.

### I-13. Determinism and replay.
Given the same event log and the same `DeterministicAnimationSeed`, the simulation produces pixel-identical playback. No `Date.now()` / `random()` / system clock leaks into the reducer. All time comes from event timestamps; all randomness comes from a seeded PRNG keyed by `(session_id, agent_id, event_id)`.

### I-14. Reduce-motion is first-class, not an afterthought.
When `NSAccessibility.shouldDifferentiateWithoutColor` or the user's reduce-motion toggle is on, all sprite animation collapses to: static pose + state badge + audit-readable text label. Companions still visibly enter/exit, but no continuous motion.

### I-15. No production hot path may use string-keyed dispatch, `AnyView`, allocation in render frames, or main-thread Metal pipeline compilation.
This is the deterministic performance contract. Pre-compile pipelines via `MTLBinaryArchive`. Route via compile-time enums. Pre-allocate instance buffers. Never `[String: Any]` in a frame loop.

### I-16. Bit-perfect pixel rendering — for pixel-art assets only. No smoothing. Ever.

**Scope (v1.3 clarification):** I-16 governs the **pixel-art asset categories** — companion sprite atlases (Block / Sage / Orb / Snake), pixel-art branding mascots (the user-supplied Claude Code mascot SVG and equivalents), and pixel-art wordmarks (the Claude Code pixel font). It does **not** govern smooth provider brand icons (Anthropic logo, OpenAI logo, Gemini glyph, etc.) sourced from LobeHub or equivalent — those are a separate asset category (DOCTRINE §10.7) and render through default SwiftUI/CoreGraphics smoothing.

The two are not interchangeable. The simulation companion is bit-perfect pixel art; the in-app provider icon next to a chat header is a smooth vector logo. Mixing the rules in either direction is drift.

For the pixel-art categories, the contract is: companion sprites and the Kimi orb's stepped silhouette establish the visual contract — pixel-art aesthetic, vector-clean appearance, *zero* anti-aliasing, *zero* bilinear smoothing on sprites. Specifically:
- All sprite texture sampling uses `MTLSamplerMinMagFilter.nearest` (both min and mag) with `MTLSamplerMipFilter.notMipmapped`. Linear/bilinear/trilinear filtering on a sprite atlas is a defect.
- Sprite scale is restricted to **integer multiples** of the atlas's native resolution (1×, 2×, 3×, 4×). Fractional scaling on sprite quads is forbidden.
- Sprite positions **snap to the nearest physical pixel** before vertex transformation: `position = round(position * pixelDensity) / pixelDensity` happens in the vertex shader, not the CPU.
- MSAA is **off** for sprite render passes (`view.sampleCount = 1`).
- SVG branding paths use only orthogonal commands (`M`, `L`, `H`, `V`, `Z`). No Bezier curves (`C`, `S`, `Q`, `T`), no arcs (`A`), no `<circle>` / `<ellipse>` elements. "Circles" are constructed from stepped rectangles (Bresenham circle silhouette technique). The validator enforces this — see §10.6.
- Glow and halo effects (the soft outer ring on the Kimi orb, eye-bloom highlights) render as **separate additive-blend passes** with pre-rasterized soft-edge halo textures. They are never Gaussian blurs of the sprite. The sprite stays sharp; the halo is its own quad.
- SVG-to-bitmap rasterization at app launch uses **nearest-neighbor at integer multiples only**. Never bilinear. Never fractional output dimensions.
- Camera/view transforms operate at integer pixel coordinates in scene space. No sub-pixel scrolling. No tweened sub-pixel motion (animations move in whole-pixel steps; smoothness comes from frame rate, not sub-pixel interpolation).

The visual reference is the user-supplied Kimi orb sprite: chunky stepped silhouette, sharp pixel edges, two crisp rectangular eye highlights with a soft *separate-quad* bloom, and a soft outer halo that lives in its own additive texture. Anything that smooths the sprite itself — bilinear sampling, sub-pixel positioning, fractional scale, MSAA bleed — is a defect.

---

## 2. One-paragraph thesis

Simulation Mode is a **deterministic visual projection of session state** rendered natively in Metal, driven by a Rust event-sourced reducer, where pixel-art companions physically embody real agent runtimes, sub-agent dispatches show as spawn animations, memory retrievals show as graph node pulses, hand-offs show as scrolls passing between companions, and approval gates physically block execution until the user resolves them. Companions appear in three coherent placements (Landing Farm always, Graph Live Theater only when active, Notes Sidebar as agent-themed workspace skin) all derived from a single Rust-owned `CompanionRegistry`. Companion bodies compose from three head-shape templates (Block / Sage / Orb), a provider-locked or user-chosen palette, eye/arm/prop overlays, and a fine-tune adapter loadout delivered as in-world gift boxes whose unwrap is honest about the underlying config change.

---

## 3. Three-Placement Companion System

This is the load-bearing visual architecture. It is not optional. It is not three separate features that happen to share assets. It is **one registry projected through three filters**.

### 3.1 Registry (single source of truth)

```
CompanionRegistry (Rust, in agent_core)
├── companions: HashMap<CompanionId, Companion>
├── activity: HashMap<CompanionId, ActivityState>
├── workspace: Option<CompanionId>          // currently selected for sidebar skin
└── observers: Vec<RegistryObserver>        // each placement subscribes to a filtered view
```

Every placement is a *projection* of this registry through a different filter. They do not maintain independent state.

### 3.2 Placement A — Landing Page (Farm View)

**Visibility rule:** ALL companions in the registry appear here, regardless of activity state. A companion created today appears here today. A companion that hasn't run in a month appears here too. Dormant ≠ deleted.

**Layout:** farm-game spatial arrangement. Companions occupy positions on a soft grid with subtle randomization for organic feel. Position is persistent per-companion (saved in registry); user can re-arrange via drag (Pro-only; MAS = layout fixed).

**Per-companion visual state on the farm:**
| Activity state | Appearance |
|---|---|
| `Active` (currently running in some session) | full-color, looping idle/walk cycle, soft glow halo |
| `Recent` (active within last 30s, hysteresis tail) | full-color, idle, no glow |
| `Dormant` (idle >30s, ≤7d since last run) | desaturated 15%, slow breathing loop, no glow |
| `Parked` (no run in 7d) | desaturated 35%, sleeping pose, "z" emote occasional |
| `Just-acquired` (created or unwrapped from gift-box in current session) | rainbow flash entrance once, then settles to Active/Dormant |

**Interaction:**
- Click → focus that companion in Notes Sidebar (placement 3) and surface the "open chat with this companion" affordance.
- Long-press / right-click → contextual radial: Inspect / Open Workspace / Archive / Adapter Inventory / Delete.
- Hover → show tooltip with companion name, model, last-active timestamp, current activity.

**Empty state:** no companions yet → onboarding flow (Slice S8 creation), with a single "tap to begin" affordance and one preset companion offered (Local Helper / teal Block, the safe MAS-friendly default).

**Honesty rule for the farm:** companions on the farm may *blink, breathe, micro-fidget, occasionally shift weight, and walk a short random path within a home-position radius* (cosmetic_idle, labeled — see §3.2.1 v1.6 below for the precise constraints). They may NOT pretend to converse with each other unless a real `handoff_*` event exists. Cross-companion ambient interaction is forbidden by default.

#### 3.2.1 Cosmetic ambient motion (v1.6 — farm-game idle elaboration)

Per the v1.6 expansion, `cosmetic_idle` motion on the Landing Farm is allowed to include short pixel-art random-walk paths so the farm reads as a living game-world rather than a row of static sprites. The constraints are tight so the honesty doctrine (I-5) and bit-perfect rendering (I-16) both hold:

- **Per-companion only.** A companion's walk path is sampled independently of every other companion. No coordination, no relative-position lock, no ambient "two companions drift toward each other." Cross-companion proximity is a defect.
- **Home-position bounded.** Each companion has a `farm_position` (the persistent grid slot from §3.2). Walks are constrained to a square radius of **±32 pixels at 1× scale** (±64 at 2×, etc.) around `farm_position`. The companion never leaves its home cell.
- **Integer pixel motion only.** Per I-16 the walk advances in whole-pixel increments per frame. Sub-pixel tweens, smooth-scroll curves, or fractional `position += velocity * dt` style updates are forbidden.
- **Discrete step cadence.** A walk leg lasts 4–12 frames at the companion's animation frame rate, then a 2–8 frame pause, then a new leg. The next direction is picked from {N, S, E, W, NE, NW, SE, SW, idle} via a seeded PRNG keyed by `(companion_id, walk_tick)` (per I-13 — no `arc4random` in the reducer; the farm view-model fetches each tick deterministically).
- **Audit label `cosmetic_idle:<companion_id>`.** Every emitted FrameDelta carries the canonical `AuditOrigin::CosmeticIdle` per §9.1 — no fake `event_id`, no synthesised `AgentEvent`. Audit-View "Why is this happening?" answers "ambient idle motion — no work happening" for every walk-step.
- **Activity-state gating.** Walking is suppressed when the companion is in `Parked` (sleeping) or in any `awaiting_approval` / `error` / `recovery_*` state — the gate / error / recovery animations physically block the companion per §4.4 + §4.7.
- **Reduce-motion mode.** When `NSAccessibility.isReduceMotionEnabled` is on (DOCTRINE I-14), walking collapses to static + activity badge, same as every other looping animation. The motion is removed; the visual state is preserved.

The walk is **rendered through the same Metal pipeline as every other sprite update** (DOCTRINE I-7 / IMPLEMENTATION §2.4) — position deltas cross the SPSC ring as ordinary `PerInstanceData` entries with `state_flags & IDLE_AMBIENT` set, and the renderer's vertex shader applies the same I-16 snap-to-pixel transform. No bypass path, no smoothing, no exception.

#### 3.2.2 Working badge + inline dispatch chat (v1.6 — landing-page direct interaction)

Per the v1.6 expansion, the Landing Farm is the **lightweight dispatch surface** for active sessions: every companion always lives on the farm (created or active, walking per §3.2.1), and any session-active companion gains a small in-tile **working badge** + an **inline dispatch chat panel** the user can open to ask questions or steer the running session without opening the full chat / graph surface.

**Working badge.** When `state_flags & ACTIVE_HALO` is set on a companion's snapshot (i.e. the §3.2 activity tracker says `Active` because at least one event in the last 30 s belongs to a session this companion is participating in), the renderer paints a small badge in the **upper-right corner** of the tile:

- A **3-dot animated typing indicator** (looped 4-frame atlas, dots fading in/out left → right) when the agent is *streaming text* (`message_started` → `message_completed` window).
- A **wrench / scroll / magnifier / etc. mini-prop sprite** when the agent is *running a tool call* — the prop matches `held_prop` from the agent's `AgentVisualState` per §5.5 Category A.
- A **gate icon** when the agent is `awaiting_approval` per §4.4 (badge is non-decorative — physically gates the dispatch panel below).

The badge renders as **a separate additive-blend draw** (same I-16 contract as the active-state halo per §5.7) — it never warps the body sprite.

**Inline dispatch chat panel.** Click on a companion tile (active or not) opens a **dispatch panel** anchored to the tile, ~300 pt tall, 240 pt wide:

- Header strip: companion mascot (pixel-art atlas-rendered) + name + helper-model summary line ("currently editing `auth.swift`…", "thinking through API design", etc. — see §3.4.4 v1.6 below).
- A scrollable read-only ribbon of the **last 10 events** for this companion, rendered as compact rows: `[12:34] 🪛 ran code_edit on auth.swift`, `[12:35] 💬 message: "Refactoring the validator…"`, etc. Newest at top, ellipsised long messages.
- A single **input field** at the bottom: `Ask or steer…`. Sending emits `AgentEvent::SteerRequested { agent_id, message }` (§11 v1.6).
- Three small action chips below the input: **Approve** / **Deny** / **Inspect** — visible only when the companion is in `awaiting_approval`. Approve / Deny emit the corresponding §11 events; Inspect opens the full Graph theater room for that session.

**Steering semantics (§11 `SteerRequested` — v1.6).** A steer message is *queued into the session's next-turn user input* by default — the running tool call completes, then the steer message lands as the next user turn. Provider-specific overrides:

- **Anthropic streams** support mid-turn interrupt — if the user sends a steer while a `tool_use` is in flight, the runtime issues a `tool_use` cancellation and folds the steer into the current turn's reply. Implementation lives in `agent_core::providers::claude`.
- **OpenAI / Kimi / Hermes / local** fall back to the queued behaviour. The dispatch panel reflects this with a hint ("steer queued for next turn").

**Honesty.** The dispatch panel is **read-only against the same `AgentEvent` stream the reducer consumes** — it cannot show events that didn't happen. Per I-5, every visible row in the panel traces to a real event id, surfaced via the `crate::audit::AuditLedger` query. The summary line (next §) is itself a streamed event series.

### 3.3 Placement B — Graph Live Theater (sub-toggle of Graph view)

**Visibility rule:** ONLY companions whose backend is currently executing appear. If zero companions are active, the graph theater shows an empty state with the literal text **"No active agents"** (or the localized equivalent — see §3.6 for naming research).

**Sub-toggle position:** inside the Graph view, segmented control: **Nodes / Live / Theater** (or `Structure / Live Session / Simulation` — see §3.6). Default sub-mode is `Nodes`. Theater is opt-in.

**Activation hysteresis:**
- A companion enters the graph theater the moment its first `AgentEvent` of a session fires (≤ 16ms after event ingestion, one frame).
- A companion exits the graph theater after **30 seconds of no events**, with a soft fade (1.5s).
- "Active" for hysteresis purposes excludes pure `cosmetic_idle` ambient ticks.
- A companion in `awaiting_approval` does not exit, even if no further events fire — the gate holds it on stage.

**Spatial behavior in graph theater:**
- Hermes (graph faculty) hovers above the graph plane at z+1, coiled around or near accessed nodes. Hermes does not stand on the ground.
- Worker companions (Claude / Kimi / GPT / local) stand on a virtual ground at z=0, near the node they are currently operating on (current `graph_node_accessed` target, last 5 seconds).
- Subagents emerge from their parent companion's location (small entrance animation), live near the parent, and despawn on `subagent_completed`.
- Edges along which a `graph_traverse_*` is in flight pulse with a directional gradient.

**Interaction in graph theater:**
- Click companion → focus inspector (right side panel) showing current task, current event, last 10 events, current cost/token usage.
- Click speech bubble → expand into the full message in Text view (jumps view).
- Click subagent → reveal provenance chain (parent, spawn event, current task).
- Click handoff arrow → open the handoff artifact (the scroll/document being passed).

**Empty state copy:** Default English: `"No active agents. Start a session to bring this stage to life."` Localizable. Decorate with a subtle ambient graph pulse so the empty state isn't dead. Do not show silhouettes of dormant companions — that breaks the live-only rule.

#### 3.3.1 Multi-room theater (v1.6 — one room per active session)

Per the v1.6 expansion, the Graph Live Theater is **multi-room** — each active **session** (not each active companion) renders in its own dedicated tile within a single MTKView. Companions that share a session (parent + sub-agents per §4.5; handoff sender + receiver per §4.3) share a room. Companions in *different* sessions get separate rooms.

**Cardinality rule.** N concurrent sessions ⇒ N rooms. A user running 1 Kimi-with-3-subagents session + 1 Claude Code session = **2 rooms** (the Kimi room shows 4 companions co-located; the Claude room shows 1).

**Session-toggle chip row.** Above the room area sits a horizontal **toggle row** with one chip per active session — chips are session-scoped, not companion-scoped (a Kimi-with-3-subagents session is one chip, not four). Each chip carries: the session's lead-companion mascot (pixel-art, 16 pt), the session label, the participating-companion count, and a working-state pulse when at least one event for that session fired in the last 30 s. Clicking a chip transitions to **drill-in mode for that session** (see §3.3.3 v1.6). When zero sessions are active the toggle row is empty + the empty-state copy (`"No active agents"`) renders below.

**Performance — single MTKView, viewport tiling (I-15 + §12).** Multi-room is rendered as **one MTKView with one Metal pipeline state and one command buffer per frame**. Each room is a `MTLViewport` rectangle within the same drawable. The renderer iterates rooms in a single render pass:

```
for each room in active_rooms:
    encoder.setViewport(room.viewport)            // tile rect in physical pixels
    encoder.setVertexBuffer(camera_for(room), …)  // per-room camera offset
    encoder.drawIndexedPrimitives(... instanceCount: room.companions.count)
encoder.endEncoding()
```

This means **N rooms cost ~N × per-companion-render**, NOT N × full-pipeline-rebuild. Pipelines are NOT recompiled per room (per I-15, no main-thread compile). Per-frame budget per §12 stays ≤ 5 ms p99 even at N = 6 rooms with 12 companions total — the budget allocates fairly across rooms.

**Layouts.** Rooms tile within the MTKView's drawable size:

| Active sessions | Layout | Aspect-aware tiling |
|---|---|---|
| 1 | Single full-screen room | 1 × 1 |
| 2 | Side-by-side | 2 × 1 (landscape) or 1 × 2 (portrait) |
| 3 | One large + two small | 1 + (1 × 2 stacked) |
| 4 | Quad | 2 × 2 |
| 5–6 | Three-up + two-down | 3 × 2 |
| 7–9 | 3 × 3 grid | (cap; further sessions queue) |
| ≥10 | Same 3 × 3 with carousel | excess sessions cycle every 5 s; user can pin |

**Per-room components.**

- **Stage** (Metal sprite area): companions + edges + speech bubbles per §4. Same I-16 bit-perfect contract.
- **Title strip** (top): session id (truncated), participating companions, elapsed time, total tokens.
- **Inspector panel** (right, collapsible): focused-companion details — current task, last 10 events, cost.
- **Chat input strip** (bottom): full chat surface for THIS session — see §3.3.2 below.

Click any room → **expand to fullscreen** (other rooms collapse to thumbnails on the side; user can pop back to multi-room view via Esc or the layout toggle).

**Per-room cameras.** Each room has its own Camera uniform — independent `view_offset` for room-local panning, independent `viewport_size` for the room's tile. The shared `pixel_density` is the MTKView's Retina scale.

**Tagging deltas to rooms.** Every `PerInstanceData` carries an `agent_id`; the reducer joins agent → session via `SimulationState.active_sessions`; the renderer routes the delta to the correct room's instance buffer slice. Per-room buffer allocation is a single `MTLBuffer` divided into N contiguous regions (no separate buffer per room — keeps `binding count` flat).

**Shared resources, isolated content.** Body + halo pipeline states are shared across rooms (built once per launch). Atlas texture is shared (one IOSurface for the whole simulation). Only viewport + camera + buffer-region differ per room. This is what keeps the per-frame cost bounded.

#### 3.3.2 Graph as full chat surface (v1.6 — chat-replacement role)

Per the v1.6 expansion, the Graph Live Theater is **the canonical full chat surface for active sessions** — every action available in the traditional chat sidebar is available *inside the room's chat input strip*:

- Send message (typed text or voice-dictated)
- Attach files (drag-drop into the chat strip)
- Cancel turn (interrupt the running stream — emits the same cancellation signal the existing sidebar Cancel button does)
- Regenerate / branch (emits `AgentEvent::TaskCreated` for the alternate branch)
- Edit history (only for the local message immediately before the cursor — same constraint as the existing chat sidebar)
- Tool result inspection (click any tool-call event in the timeline; opens the in-room inspector)

The traditional chat sidebar continues to work — it is NOT removed by v1.6. Both surfaces drive the same `AgentEvent` stream; per I-5 typing in the graph chat is identical event-stream-wise to typing in the sidebar chat.

**Precedence.** When BOTH surfaces are open for the same session, the most-recently-focused surface takes input. The other surface mirrors the stream read-only. This is enforced by a single-input-focus invariant in the simulation Swift layer.

#### 3.3.3 Overview vs. drill-in modes (v1.6 — "entering the room")

Per the v1.6 expansion, the Graph Live Theater has **two modes** that the session-toggle row (§3.3.1) switches between:

**Overview mode** — default when ≥ 2 sessions are active. The full multi-room viewport tiling is visible (per the §3.3.1 layout table); each room renders simplified, glanceable content:

- Stage with sprite motion (companions doing their per-event animations).
- Working-state badge in each room's upper-right corner — same 3-dot / mini-prop / gate-icon vocabulary as the farm dispatch badge per §3.2.2.
- One-line helper-model summary at the bottom of each room (per §3.4.5).
- Title strip with session id + companion count + elapsed time + total tokens.
- **No chat input strip** in overview mode — typing requires drill-in.
- **No inspector panel** in overview mode — clicking a companion shows a hover tooltip only.

Overview mode is the *glance-and-monitor* surface — the user sees everything that's running at a glance and decides where to go next.

**Drill-in mode** — entered by clicking a session-toggle chip OR clicking inside a room's stage area in overview mode. The selected session's room expands to fill the view; the other rooms collapse to a **thumbnail strip** along the right edge (32-pt mascot tiles + working-state badge + click to switch). The drilled-in room renders the full inspection chrome:

- **Stage** at full size with all companions, edges, speech bubbles, sub-agent orbits, hand-off scrolls per §4.
- **Full event timeline** — scrollable ribbon (right side, ~280 pt wide) showing every `AgentEvent` for this session, not just the last 10. Filtering by event kind (messages / tool calls / graph mutations / approvals) via chip toggles at the top.
- **Inspector panel** for the focused companion (left side, ~240 pt wide) showing current task, current animation state, held prop, palette, current frame, recent tool input/output values, cost / token usage breakdown, sub-agent provenance chain.
- **Graph-node activity ribbon** (bottom, ~80 pt tall) — live pulse of which graph nodes the agents in this session have accessed in the last 30 s, with click-to-jump to the node in the underlying graph view.
- **Chat input strip** (per §3.3.2) — full chat surface for THIS session (send / cancel / regenerate / branch / attach / inspect).
- **Per-companion mini-inspectors** — clicking another companion in the drilled-in room swaps the inspector panel content; the focused companion is the chat input target by default.

Drill-in mode is the *deep work* surface — when the user wants to understand exactly what an agent is doing or steer the session at high resolution.

**Transitions.**

- Click a session-toggle chip OR click inside a room's stage in overview → drill in to that session (220 ms ease-out, room scales up while neighbours fade to thumbnails).
- Press `Esc` OR click the overview-toggle button (top-left of the drilled-in room) → return to overview (220 ms ease-in, thumbnails expand back to viewport tiles).
- Click a thumbnail in the drill-in side strip → switch drill-in target (no overview transition; cross-fade between rooms 180 ms).
- When only ONE session is active, drill-in mode IS overview mode — there's no second room to overview between, so the chrome simply renders the drill-in shape (no thumbnail strip).

**Performance.** Overview mode runs the simpler per-tile chrome (badge + summary + title strip — all SwiftUI overlays, not Metal-rendered). Drill-in mode runs the full inspector chrome but only for one session at a time + N-1 small thumbnails (each thumbnail is one Metal viewport drawing the same companion sprites at lower res, no inspector chrome). Both fit comfortably in the §12 ≤ 5 ms p99 budget — drill-in even has more headroom because only one room renders at full fidelity, not all N. The transition animation is a SwiftUI scale + opacity layer over the Metal render, not a re-render.

### 3.4 Placement C — Notes Sidebar (Agent-Themed Workspace Skin)

**Visibility rule:** ONE companion at a time — the currently-selected workspace companion (`registry.workspace`). Switching workspace re-skins the entire sidebar.

**What re-skins:**
- **Color palette:** sidebar background, accent bar, hover/selection states, separator lines, link colors. Provider-derived for non-Custom companions; user-chosen for Custom.
- **Title font:** the sidebar header font is per-companion (within a curated set of macOS-native fonts; see §5.4 — never trademark-imitating fonts).
- **Mascot sprite:** pinned at top, animated idle, clickable to open inspector.
- **Section labels:** subtitle text uses companion-specific phrasing where natural (`Hermes' Vault` vs `Claude's Workspace` vs `Local Notes`).
- **Sidebar contents:** the listed items are the companion's vaults, subagents, artifacts, sessions, skills, claims, adapters — everything scoped to that `ModelProfile`.

**What does NOT re-skin:**
- The titlebar, toolbar, content pane, status bar. Sidebar skinning is contained to the sidebar pane.
- Global shortcuts, global commands, command palette layout.

**Switching companions:**
- Keyboard: `⌘⇧[` previous companion, `⌘⇧]` next companion.
- Mouse: click another companion on the Landing Farm, or use the workspace switcher chip at the top of the sidebar.
- Animation: re-skin transitions in 250ms with a soft cross-fade. No abrupt re-paint.

**Companion picker (v1.4 — three-level Company → Model → Agent hierarchy):** at the very top of the sidebar above the mascot pin, a collapsible disclosure section called `Companions` lists all registered companions grouped first by their underlying **provider/company**, then by the **specific model** they bind to, with **agents (companions)** as leaves under each model. This is the canonical visualization of the user's underlying ModelProfile architecture (each agent has a base_model; multiple agents may share a model; one company can host multiple model variants).

Each level uses a different visual weight:

| Level | Visual | Source | Weight |
|---|---|---|---|
| Company | mono provider icon (~14pt) + display name + agent count | smooth-vector-brand from `branding/<provider>/icon-mono.svg` (DOCTRINE §10.7) | section header |
| Model | mono model/provider icon (~14pt) + model display name (e.g., "Claude Sonnet 4.6", "Qwen3-4B") | smooth-vector-brand; uses parent provider icon if no model-specific icon exists | subsection header |
| Agent | Tamagotchi pixel-art mascot (~20pt) + agent name | pixel-art-mascot from `atlas/<head_shape>.png` rendered through SwiftUI Image at the agent's preset (color/eyes/arms/prop) | leaf (most prominent) |

```
▾ Companions                                              ⊕  (creation flow)
  📁 Anthropic                                       [3 agents]
       ◔ Claude Sonnet 4.6                            [2]
            🪛 Sage Reviewer (current) ●
            🪛 Code Critic
       ◔ Claude Opus 4.7                              [1]
            📜 Doc Editor
  📁 Moonshot AI                                     [1 agent]
       ◔ Kimi K2                                      [1]
            🔭 Kimi Explorer
  📁 OpenAI                                          [1 agent]
       ◔ GPT-5.5                                      [1]
            🪄 GPT Conductor
  📁 Local                                           [2 agents]
       ◔ Qwen3-4B (MLX)                               [1]
            📂 Note Helper
       ◔ Qwen3-7B (MLX)                               [1]
            🧮 Memory Clerk
```

(The ◔ glyph above is shorthand for the model-level mono provider icon; 🪛/📜/🔭/🪄/📂/🧮 are shorthand for each agent's pixel-art Tamagotchi mascot rendered with its prop. In actual UI, both are real SVG / atlas renders.)

Rules:
- **Provider and model icons are mono-variant smooth-vector** (`.foregroundStyle(.primary)`); the active agent's accent dot adopts the company's brand color from `provenance.json`.
- **Agent icons are pixel-art Tamagotchi mascots** rendered bit-perfect per I-16 — preserving the visual hierarchy: smooth abstract identity at company/model levels, embodied Tamagotchi at agent level.
- The picker is purely a *navigation affordance*. It does **not** introduce a company-workspace or a model-workspace — clicking a company name or a model name does not change workspace; only clicking a specific agent does. This preserves I-9 (one workspace at a time).
- **Where to create new agents:** each model row has a small `+` affordance that opens the creation flow (Slice S8) pre-seeded with that model as the agent's `base_model`. Creating from the company row instead opens a model-picker step first.
- Provider-level configuration (API keys, default model defaults, base-URL overrides, telemetry consent) and per-model configuration (max tokens, temperature defaults, MLX quantization for local) live **only in Settings**, never in the sidebar picker. The sidebar picker is read-only navigation.
- When the picker is collapsed (`▸ Companions`), only the active agent's mascot + name + parent model + parent provider mini-icons are visible — minimal vertical real-estate when the user wants the sidebar focused on the current workspace.
- Empty state: company sections with zero models or zero total agents are hidden. Model rows with zero agents are hidden by default but can be revealed via a "Show models with no agents" toggle (helpful for "I configured this model in Settings but haven't created an agent yet").
- **Local models** (Qwen, Mamba/SSM variants, future custom adapters) live under a synthetic `Local` company whose mono icon is the `branding/apple/icon-mono.svg` (Apple Silicon = the platform). Each local model variant is its own Model row — `Qwen3-4B (MLX)`, `Qwen3-7B (MLX)`, `Mamba-2-2.7B (MLX)`, etc. This makes local-only mode feel native and equivalent in stature to cloud providers.

**Default / neutral mode:** users may set workspace = `None`, which gives a neutral system theme and the sidebar contents become the union view (all artifacts across all companions, deduplicated by content hash). This is the "no companion" affordance for users who don't want skinning.

**MAS profile:** all skinning behavior is fully available in MAS. Custom companion fonts are limited to the curated set (no arbitrary font sideload). Custom palette accepts only sRGB hex codes (no shader sideload).

#### 3.4.1 Persistent vault hierarchy (v1.6 — multi-vault per entity)

Per the v1.6 expansion, vault folders now live at every level **from the model down**:

```
EpistemosVault/
├── Companies/
│   ├── Anthropic/                                (no vault — list of models only)
│   │   └── Models/
│   │       ├── Claude-Sonnet-4.6/
│   │       │   ├── vault/                        ← Model vault (persistent)
│   │       │   │   ├── notes/
│   │       │   │   ├── claims/
│   │       │   │   ├── sessions/
│   │       │   │   └── …
│   │       │   ├── vaults/                       ← optional multi-vault siblings
│   │       │   │   ├── research/
│   │       │   │   └── private/
│   │       │   └── Agents/
│   │       │       ├── Sage-Reviewer/
│   │       │       │   ├── vault/                ← Agent vault (persistent)
│   │       │       │   │   ├── notes/
│   │       │       │   │   └── …
│   │       │       │   ├── vaults/               ← optional multi-vault per agent
│   │       │       │   │   └── code-review-archive/
│   │       │       │   └── Subagents/
│   │       │       │       └── X1/
│   │       │       │           ├── vault/        ← Sub-agent vault (persistent)
│   │       │       │           ├── vaults/       ← optional multi-vault per sub-agent
│   │       │       │           └── Subagents/    (further nesting permitted)
│   │       │       └── Code-Critic/
│   │       │           └── vault/
│   │       └── Claude-Opus-4.7/
│   │           ├── vault/
│   │           └── Agents/…
│   ├── Moonshot-AI/
│   │   └── Models/…
│   └── Local/                                    (synthetic Apple-icon company)
│       └── Models/
│           ├── Qwen3-4B-MLX/
│           │   ├── vault/
│           │   └── Agents/…
│           └── Mamba-2-2.7B-MLX/
│               └── vault/
```

Rules:

1. **Companies have no direct vault.** A company is a *list of models*. Toggling a company in the sidebar reveals its models; the sidebar's notes pane below the toggle row still shows the union of the toggled company's models' vault trees.

2. **Models, Agents, and Sub-agents each have at least one vault** (`vault/`) plus an optional `vaults/` directory containing additional sibling vault trees. Multi-vault is canonical at every level — a Model can have a `research/` vault and a `private/` vault; an Agent can have a `code-review-archive/` vault separate from its primary one; etc.

3. **Persistent on disk like the user's own vault.** Each vault is a real folder on the user's disk under `EpistemosVault/`. Files are markdown / plain text / images / etc. — the same shape as the user's regular workspace. Editing a note inside a Model vault writes the file to disk just like editing any other note.

4. **Sub-agents nest indefinitely.** A sub-agent can have its own `Subagents/` folder containing further sub-agents, each with their own vault, recursively. The depth cap from §4.5 ("V1 children may not spawn grandchildren") applies to *runtime* sub-agent spawning, not to the persistent vault directory tree — the directory tree may be deeper than the runtime spawning limit so long as those deeper sub-agents only run as direct invocations, not as nested spawns.

5. **Vault path is registered.** The `companions.vault_path` SQLite column points at the canonical `vault/` folder for that companion (Model row → `Models/<id>/vault/`, Agent row → `…/Agents/<id>/vault/`, Sub-agent row → `…/Subagents/<id>/vault/`). Multi-vault siblings are discovered at view-model load time by scanning `<entity>/vaults/*/`.

6. **MAS profile:** all vault folders are under `EpistemosVault/` (the user's selected vault root). Cross-vault federation is Pro-only per §13.

#### 3.4.2 Multi-toggle sidebar (v1.6 — display-tree decoupled from active workspace)

Per the v1.6 expansion, the picker's selection model is **two-track**:

- **Active workspace** (canonical, `registry.workspace`) — still **ONE entity at a time**, per the original §3.4 rule and DOCTRINE I-9. The active workspace drives the sidebar's *skin* (palette, mascot pin, title font, accent color), the chat input target, and audit attribution. Clicking an *Agent* (or Sub-agent) leaf sets the active workspace; clicking a Model or Company name does not.

- **Display-tree toggles** (new at v1.6) — each entity at every level (Company, Model, Agent, Sub-agent) has a toggle chip in the picker row. Toggling **adds** that entity's vault tree to the displayed sidebar; un-toggling removes it. Multiple toggles at any level are permitted simultaneously.

The displayed sidebar tree below the picker is the **union of toggled entities' vault trees**. Each toggled entity becomes a top-level group in the tree:

```
[Anthropic ✓] [Claude Sonnet 4.6 ✓] [Sage Reviewer ✓] [Local ✓] [Qwen3-4B ✓] [Note Helper]
─────────────────────────────────────────────────────────────────────────────────────────
▾ Anthropic
   ▾ Claude Sonnet 4.6                   ← Model vault appears
      📁 vault/
         📄 ...
      📁 vaults/research/
      ▾ Sage Reviewer                    ← Agent vault appears
         📁 vault/
         📁 vaults/code-review-archive/
         ▾ Subagents/
            ▾ X1
               📁 vault/
▾ Local
   ▾ Qwen3-4B (MLX)
      📁 vault/
      …
```

Rules:

1. **Active workspace ⊆ toggled.** The active workspace's path (Company → Model → Agent leaf) is implicitly toggled. Un-toggling any ancestor of the active workspace is permitted — the sidebar simply shows nothing — but does NOT change the active workspace; the user must click another agent leaf to switch.

2. **Visual weight follows the §3.4 v1.4 hierarchy.** Company nodes are smooth-vector mono icon section headers; Models are smooth-vector subsection headers; Agents are pixel-art Tamagotchi leaves. This is unchanged.

3. **Skin is set by the active workspace, not by toggle count.** The sidebar's accent color, mascot pin, and title font are still the active agent's attributes. Multi-toggle changes the *content tree* below; the *chrome* is single-agent per I-9.

4. **Empty toggle set.** If the user un-toggles every entity, the sidebar reverts to the **Default / neutral mode** described above — the union view of all artifacts across all companions, deduplicated by content hash. The neutral state is reached by zero toggles, not by an explicit "None" workspace.

5. **Persistence.** Toggle state is per-window, persisted across launches in `~/Library/Preferences/com.epistemos.app.plist` under `simulation.sidebarToggles.<windowId>`. Re-opening a window restores its last toggle set.

6. **Performance.** The sidebar tree refreshes on toggle change (debounced 50 ms) and on `companion_registered` / `companion_archived` / file-watcher events from the toggled vault paths. Per I-15 the refresh path is non-allocating in steady state — the tree is a `BTreeMap<EntityKey, NodeRef>` mutated in place.

#### 3.4.3 Knowledge-brick design language (v1.6 — sidebar as the app's centerpiece)

Per the v1.6 expansion, the Notes Sidebar is **the highest-density, most-expressive surface in the app** — its visual identity is the load-bearing anchor for "this isn't a chat client, this is a cognitive workspace." The design language is **knowledge-brick**: dense, layered, beautiful at a glance, lossless under scrutiny.

**Typography.**
- Sidebar title (workspace name): **New York semibold 16 pt** (matches the hermes/canonical-doctrine warmth; SF Pro reads too neutral here).
- Picker section headers (Company): SF Pro Text **semibold 11 pt**, lowercase variant numbers preserved (`anthropic`, `moonshot ai`, `local`).
- Model rows: SF Pro Text **medium 12 pt**, model display name verbatim.
- Agent leaves: **SF Compact Rounded medium 13 pt**, paired with the pixel-art Tamagotchi mascot at 20 pt — the rounded-text family is intentional warmth against the precise pixel-art mascot.
- Note titles: **SF Pro Text regular 13 pt**; truncation 2 lines max with ellipsis.

**Density.** The sidebar lives in a 240-pt-wide column (resizable 200–360). Within that column, four hierarchy levels must be legible simultaneously: company section header / model subsection / agent leaf with mascot / per-agent vault tree. Achieved by:

- **Indent step = 12 pt per level** (not 16 — the sidebar can't afford 64 pt of left margin at depth 4).
- **Row height = 22 pt** for tree rows (compact); 32 pt for agent leaves (mascot demands height); 28 pt for model headers (mid-density).
- **Section header treatment:** uppercase tracked +0.06em, brand-color underline 1 pt at the row baseline (matches the per-company brand color from `provenance.json`), expanded/collapsed chevron at the right edge.

**Motion.** Sidebar motion is restrained but expressive — never decorative-only:

- **Collapse / expand** of any disclosure: 220 ms spring-loaded easeOut. Children fade in 80 ms after the height animation lands so users see the structure before the content.
- **Selection pulse:** clicking an agent leaf pulses the row's accent dot (palette color → 1.5× brightness → palette color) over 180 ms. The pulse uses a **separate additive draw** at I-16 integer pixels — same contract as the active-state halo on the farm.
- **Mascot pin idle:** the active workspace's mascot pin (top of sidebar, 32 × 32 pt) plays its 4-frame `idle` cycle continuously while the workspace is selected. Reduce-motion → static frame 0.
- **Multi-toggle chip pulse:** toggling a chip on/off pulses the chip border (accent color, 140 ms) so the user gets immediate feedback before the tree refreshes 50 ms later.

**Color.** Per-companion accent color comes from `branding/<provider>/provenance.json` (DOCTRINE §10.7). The sidebar reads the active workspace's brand color and applies it to:

- Title underline (1 pt below sidebar title).
- Active agent leaf's accent dot (8 pt circle to the right of the name).
- Selection pulse glow (above).
- Section-header underline of the active workspace's COMPANY (so the user sees "I'm in the Anthropic section" without reading text).

Other companies' section headers use **`.secondary` foreground** for restraint — only the active company gets the brand color, ensuring visual focus.

**Pixel-art accents.** Every agent leaf carries its **Tamagotchi mascot** rendered bit-perfect per I-16 (20 pt tile, atlas-sourced, nearest-neighbor). The active workspace's mascot pin (top of sidebar) is the same atlas at 32 pt. These are the *only* pixel-art surfaces in the sidebar — everything else is smooth-vector / SF text. The deliberate split (smooth chrome, pixel-art identity anchors) is the visual signature of the knowledge-brick.

**Rule of thumb for adding to the sidebar.** Any new affordance in the sidebar must answer "is this a knowledge-brick element or a control?" Knowledge bricks (mascot pin, accent colors, per-agent vault tree, helper-model summary line) belong in the sidebar. Controls (preferences, raw provider settings, account management) belong in **Settings**, never the sidebar (per §3.4 v1.4 rule).

#### 3.4.4 Multi-vault UI affordances (v1.6 — sibling vault management)

Per the v1.6 expansion, every entity that owns a vault (Model, Agent, Sub-agent per §3.4.1) gains **explicit UI affordances** for managing its sibling vaults under `vaults/`. The sidebar is the canonical surface — vault management lives where the user already navigates notes.

**Per-entity vault disclosure.** Each agent leaf (and each model row, when expanded) gets a **`Vaults` sub-disclosure** that lists:

```
▾ Sage Reviewer                     [active workspace]
  📁 vault                          (default; always present)
  ▸ Vaults                          [3]
       📁 code-review-archive
       📁 design-snippets
       📁 personal
       ⊕  New vault…                (opens an inline "create sibling vault" sheet)
```

Clicking a sibling vault temporarily *re-roots* the displayed tree below for THIS entity — the user navigates that vault's notes inline, with a small breadcrumb at the top (`Sage Reviewer › code-review-archive › ...`).

**Inline create-sibling-vault sheet.** Click `⊕ New vault…`:

- A small sheet drops in with ONE text field: `Vault name`.
- Validation: filesystem-safe, ≤ 64 chars, unique within the entity's `vaults/` directory.
- On confirm: emits `AgentEvent::VaultCreated { entity_id, vault_path }` (§11 v1.6); the registry creates the folder + writes a `vault.toml` provenance file; the sidebar refreshes within 50 ms.

**Drag-rearrange.** Sibling vaults can be dragged to reorder within the `Vaults` disclosure. Order persists in the entity's row metadata (a small `vault_order JSON` column added to the `companions` table). MAS profile: drag is allowed (no escalated entitlements needed).

**Delete vault.** Right-click → `Archive vault…` (Pro-only hard delete; MAS = archive only, same as companion archival per §3.5). Archive moves the folder to `<entity>/.vaults_archive/` with a 30-day TTL.

**Multi-vault for Models too.** Same UI affordances apply at the Model level — a Model row's `Vaults` disclosure shows the model's sibling vaults. This makes "the Model's reference library" a first-class concept (e.g., `Claude-Sonnet-4.6 / vaults / examples` for canonical example outputs that all agents on this model can read).

**Sub-agents nest inline.** A sub-agent's `Vaults` disclosure renders inside its parent agent's tree expansion. The visual hierarchy is preserved — sub-agent vault management never opens a separate window. Multi-toggle (§3.4.2) interacts naturally: toggling a sub-agent shows its primary `vault/` and any siblings under `Vaults`.

**Honesty.** Vault creation / rename / archive are real persisted operations on disk + audit ledger entries (§6.4 / §3.5 patterns). The UI never shows a vault that doesn't exist on disk; conversely, file-watcher events from the disk side (e.g., user creates `vaults/foo/` manually) trigger sidebar refresh within 50 ms (debounced).

#### 3.4.5 Helper-model summariser (v1.6 — landing-page dispatch summary)

Per the v1.6 expansion, the Landing Farm dispatch panel (§3.2.2) and any sidebar agent tile show a **one-line live summary** of what the agent is currently doing — answering the user's "what's it doing?" without making them open the full chat / graph view.

**Summariser model.** A fast helper model produces the summary. Default selection per §3.4 v1.4 rule (provider config in Settings only):

- **Primary**: Claude Haiku 4.5 (fast, cheap, no tools).
- **Local fallback**: Qwen3-4B-MLX (when offline or user prefers local-only).
- **User-overridable**: Settings → Simulation → Helper model.

**Trigger cadence.**

- Re-summarise every **2 seconds** while the target agent is streaming, OR when the agent's `current_animation` transitions (Speak → Tool → Recover etc.).
- Stop summarising when the agent enters `Idle` after `MessageCompleted`.
- Cache: the most recent summary persists for 30 s after the agent stops; afterwards the dispatch panel shows "Idle" until the next event.

**Routing.** The summariser request is dispatched via the existing `agent_core::routing::ConfidenceRouter` — a tiny prompt that fits in 1024 tokens and asks "summarize the last 30 s of this companion's activity in one sentence." The reasoning-trajectory metrics (`agent_core::reasoning_metrics`) record cost so users can audit how much summarisation is consuming.

**New AgentEvent variants (§11 v1.6).**

```rust
pub enum AgentEvent {
    // ... existing 41 variants ...

    // §3.2.2 + §3.4.5 v1.6 — dispatch + summariser
    SteerRequested {
        agent_id: CompanionId,
        message: String,
    },
    SummaryStarted {
        for_agent_id: CompanionId,
        helper_model: String,         // e.g., "claude-haiku-4-5"
        prompt_id: String,             // for cost / replay tracking
    },
    SummaryDelta {
        prompt_id: String,
        delta: String,
    },
    SummaryCompleted {
        prompt_id: String,
        final_text: String,
        token_count: u32,
    },

    // §3.4.4 v1.6 — multi-vault UI
    VaultCreated {
        entity_id: CompanionId,        // model / agent / sub-agent owning the vault
        vault_path: String,            // relative to vault root
        vault_name: String,
    },
    VaultArchived {
        entity_id: CompanionId,
        vault_path: String,
    },
}
```

**Honesty.** The summary is itself an `AgentEvent` stream (`SummaryStarted` → `SummaryDelta` → `SummaryCompleted`) — per I-5 every summary line traces to a real prompt id and a real helper-model invocation. The dispatch panel never invents a summary; if the helper model fails or times out, the panel shows "Working…" with an error chip.

### 3.5 Cross-placement synchronization rules

- Activity state changes propagate to all three placements within one frame (≤16ms at 60Hz, ≤8ms at 120Hz).
- Workspace change (placement C) emits a `workspace_focused` event but does not affect placement A or B visibility (a companion can be selected as workspace while inactive on the graph theater).
- Creating a new companion (Slice S8 flow) inserts into the registry, triggers a `companion_registered` event, and the companion appears on the Landing Farm with the rainbow-flash entrance. It does NOT auto-appear on graph theater (no events yet) and does NOT auto-become workspace.
- Archiving a companion removes it from all three placements but preserves its vault/graph/runs on disk.
- Deleting a companion (Pro-only operation, MAS = archive only) removes registry entry; vault/graph/runs are moved to a `_trash` folder with 30-day TTL.

### 3.6 Naming and labels (final picks)

After internal debate (Nodes/Live/Theater vs Structure/Live Session/Simulation):

- **Sub-toggle labels (graph view):** `Nodes` / `Live` / `Theater`. Reasons: short, memorable, doesn't overload the word "Simulation" which implies "fake," and "Theater" emphasizes the projection metaphor.
- **Top-level placement names (internal):** `LandingFarm`, `GraphTheater`, `SidebarWorkspace`. User-facing names follow the sub-toggle convention.
- **Empty state on graph theater:** `"No active agents"` (English default).
- **Companion plural noun:** `Companions` (user-facing). `agents` is reserved for the runtime concept (which may or may not have a companion sprite).

---

## 4. Agent-to-Agent Visual Mechanics

When more than one companion is active, the simulation must communicate their relationship clearly without becoming chaotic. Every interaction below is event-driven; nothing is invented for ambience.

### 4.1 Spatial hierarchy (z-order)

| z-layer | Inhabitant | Reason |
|---|---|---|
| z+2 (sky) | Cosmic ambient (graph background pulse) | atmosphere |
| z+1 (hover) | Hermes (graph faculty) | Hermes is *above* workers, not among them |
| z+0 (ground) | Worker companions (Claude / Kimi / GPT / Local / Custom) | the working surface |
| z-1 (below ground) | Subagent shadows when retreating to parent | spawn/despawn |

Hermes does not walk on the ground. It coils, hovers, drifts. This is the visual signature of "graph faculty."

### 4.2 Speech and message bubbles

- `message_started` → speech bubble fades in above the speaker, body shows three animated dots (typing indicator).
- `message_delta` → typing dots continue; the bubble does NOT show partial text in the simulation (text streams to Text View, not Theater — Theater shows the *act* of speaking, not the content).
- `message_completed` → bubble briefly shows a 1-line summary (first 80 chars of message, ellipsized), then the bubble shrinks into a small icon docked next to the speaker for 5 seconds (clickable: opens full message in Text View), then fades.
- Two companions speaking simultaneously: bubbles offset vertically; never overlap.
- Hermes speaking → bubble appears above hovering position, slightly larger font, gold border.

### 4.3 Handoff animations

`handoff_started(from, to, payload_id)`:
1. Source companion pulls a scroll/document sprite out of its prop slot (frame 1-3).
2. Source walks toward target companion (frames 4-12, eased; total 600ms).
3. Source extends scroll; target reaches up (frames 13-15).
4. Scroll changes ownership; source returns to its position (frames 16-22, 400ms).

`handoff_completed`: target stows scroll into its prop slot; brief glow at the moment of stowing.

If `handoff_completed` doesn't arrive within 5 seconds, the scroll hovers between them with a "?" emote until the event fires or the session ends. This is honest: the visual reflects an in-flight handoff that hasn't completed.

### 4.4 Approval gates

`awaiting_approval`:
- Companion stops walking immediately.
- A pixel-art gate or warning glyph drops in front of the companion (1 frame, snappy).
- Companion turns to face the user (camera).
- All ambient cosmetic_idle on this companion freezes (no breathing, no fidget). It is *physically blocked*.
- A small chip appears at the bottom of the screen: `"<Companion> awaits approval — [Approve] [Deny] [Inspect]"`.

`approval_granted`: gate dissolves, companion resumes; brief green flash.
`approval_denied`: gate slams red, companion drops the prop it was holding (if any), error pose for 1s, then back to idle. Audit log records denial.

The companion does not animate "thinking about the approval" while waiting. It physically waits.

### 4.5 Subagent spawn and despawn

`subagent_spawned(parent, child, count)`:
- Parent companion glows (300ms ramp).
- `count` small worker sprites (50% scale of parent) emerge from parent's location (radial burst, eased; 600ms).
- Each child is positioned in a small orbit around parent.
- Child has its own state machine but inherits parent's role and palette (slight desaturation).

`subagent_completed(child, result)`:
- Child returns to parent (300ms inward arc).
- Brief merge flash; child sprite dissolves into parent.
- If `result == failed`, parent shakes briefly.

**Stack discipline:** children may not spawn grandchildren in V1. This is enforced by the Rust reducer (any `subagent_spawned` event whose parent is itself a subagent is logged as a warning and does not spawn a visible child; the audit ledger records the suppressed depth). V2+ may relax this with a depth cap of 3.

### 4.6 Memory retrieval visuals

`memory_retrieved(agent, node_id)`:
- The graph node corresponding to `node_id` pulses with a node-type-specific color (8 frames, 250ms).
- A small scroll sprite emerges from the node, travels to the retrieving companion (eased 400ms).
- Retrieving companion performs a "read" pose for 600ms (head down, scroll held).
- Scroll dissolves into companion's "memory" inventory (cosmetic indicator: brief shimmer above head).

If the retrieving companion is Hermes, the snake coils tighter around the source node during the read pose.

### 4.7 Error and recovery

`error(agent, code)`:
- Companion wobbles (4-frame oscillation, 300ms).
- Red flicker overlay (tinted multiply, 500ms).
- "!" glyph above for 1s.
- Companion returns to last stable pose.

`recovery_started(agent)`:
- Companion sits/kneels (depending on body grammar — Block sits, Sage kneels, Orb pulses).
- Tiny gear/wrench prop appears in hands or beside (Block/Sage) or rotating around (Orb).
- "fix" animation loops for 600ms minimum or until `recovery_completed`.

`recovery_completed`: tools fade, companion stands, brief green flash. If `recovery_completed` never fires (session ends in error state), companion remains in recovery pose; on next session the pose persists until a successful event clears it.

### 4.8 Multi-companion deliberation (Deep Deliberation visual integration — V3)

When the user invokes Deep Deliberation / Research Jury (per `project_master_session` and the user's brainstorm on optimist/pessimist/researcher groups), the companions involved arrange themselves on stage in their assigned roles:

- Optimist group: stage left, slight upward pose
- Pessimist/Critic group: stage right, slight downward/skeptical pose
- Researcher (neutral): stage center, holding scroll/magnifier
- Moderator (Hermes-like or a designated neutral): hovering above center
- Clerk: small companion at bottom corner with quill/scroll

Speech bubbles flow according to the deliberation protocol. Cross-bubble lines (claim → objection → response) draw briefly between speakers. The user can scrub the deliberation timeline. The full transcript saves to a `Research Council/<date-topic>/` artifact (per the user's brainstorm). This is V3 polish — V0/V1/V2 deliver the foundation.

---

## 5. Companion Body Grammar (Customization System)

Companions are **composable** sprites. There is one shared animation rig and three head-shape variants (V1). Customization is honest: every choice maps to a real config knob or is explicitly cosmetic.

### 5.1 Body-shape families (V1.1 — reality-grounded)

> v1.1 update: the user supplied the official Claude Code mascot SVG (`claudecode-color.svg`, hex `#D97757`). That asset is a **wide pixel block with multi-leg bottom notches**, not a humanoid. The v1.0 "Claude = Sage" assumption was wrong. The grammar below is the corrected taxonomy. Sage remains available but is only used by Custom companions — none of the Big-Four provider presets use it.

The body grammar is now **parameterized**. Three families. Block is parameterized; Orb and Sage are simpler.

#### Block family (parameterized; covers Claude / Kimi / Codex)

A square/rectangular pixel block with composable shape parameters.

| Parameter | Values | Drives |
|---|---|---|
| `aspect` | Compact (1:1, ~48×48), Wide (1.4:1, ~64×48), Tall (1:1.3, ~48×64) | overall body proportion |
| `legs` | None, Stubs (2 short legs), Multi (4–6 leg notches at bottom) | bottom silhouette |
| `antennae` | None, Single (top-right protrusion), Double | top silhouette |
| `eye_treatment` | NegativeSpace (transparent cutouts), Filled (overlay sprite) | how eyes render |

Reference fits derived from the user-supplied SVG inventory:

| Provider preset | Block parameters | Reference asset |
|---|---|---|
| **Claude Code worker** | Block(Wide, Multi, Single, NegativeSpace) | `claudecode-color.svg` (hex `#D97757`) |
| **Kimi worker** | Block(Compact, Stubs, None, Filled) | Kimi CLI mascot screenshots |
| **Codex worker** | Block(Compact, Stubs, None, Filled-black eyes) | white-body recolor of Codex SVG |

Same family, different parameters. The Metal renderer composes the silhouette from the atlas slice for each parameter combination (or, V2+, from an SDF shader — see §5.6).

#### Orb family (covers GPT / abstract orchestrators)

Circle or sphere with optional thin floating arms, no legs (drifts). Calm, hovering, planner-feel. Roughly 48×48. Inspiration: the Kimi CLI logo's circular variant; abstract conductor archetype.

#### Sage family (Custom companions only; not used by Big-Four presets)

Tall humanoid with discrete head/body/arms/legs (~48×64). Deliberate, careful feel. Available in the creation flow for users who want a humanoid Custom companion. **No provider preset selects Sage in v1.1.** (v1.0's "Claude = Sage" entry was retired.)

#### Snake (Hermes-only; separate atlas)

Coiling caduceus/serpent. Different rig: no legs, hovers, slithers between graph nodes. Not in the Block/Orb/Sage taxonomy. Dedicated atlas. See §8.

**Crucial:** sprite atlases are **redrawn as Epistemos-original assets** following the Character DNA process (§10.2). User-supplied SVGs are kept as the canonical *static branding/icon* assets (§5.6, §10.6); animated atlases are not raster-converted from those SVGs.

### 5.2 Composable customization axes

Each companion is a tuple:

```
Companion {
  head_shape: { Block | Sage | Orb }
  palette: PaletteRef            // provider-locked or user-chosen for Custom
  eyes: EyeStyle                 // 4 options V1 (Round / Slit / Visor / Closed)
  arms: ArmStyle                 // None | Short | Long
  prop: PropRef                  // tied to tool affinity; multiple options
  accessory: Option<AccessoryRef> // cosmetic only; gift-box-unlockable
  name: String
  role: ProviderRole
  base_model: ModelProfileRef
  vault_path: PathBuf
  graph_slice: GraphSliceId
  adapter_loadout: Vec<AdapterRef>
  system_prompt_preset: PresetRef
  tool_affinities: BitSet
}
```

**Rendering composition:**
1. Base atlas slice for `head_shape` (e.g., `block_idle_f0.png`)
2. Apply `palette` via fragment shader (channel-keyed recolor, NOT pre-baked atlases — see §10.5)
3. Composite `eyes` overlay (separate atlas)
4. Composite `arms` overlay (separate atlas; layered for in-front / behind body during animation)
5. Composite `prop` if present and current animation state binds props
6. Composite `accessory` if present

Each composition layer is a separate instanced quad in the same draw call. Total: ~6 quads per companion. At 12 active companions on graph theater, ~72 quads = trivial GPU load.

### 5.3 Shared animation rig (14 core states)

All head shapes share the same animation state set. Each state has a different sprite atlas slice per head shape, but the same frame count and timing. This is what makes the system "composable":

| State | Frames | Loop? | Trigger |
|---|---|---|---|
| `idle` | 4 | yes | default; cosmetic_idle ambient |
| `walk` | 8 | yes | spatial movement (handoff, retrieval) |
| `think` | 6 | yes | `thinking_*` events |
| `speak` | 4 | yes | `message_*` events |
| `tool` | 6 | yes | `tool_call_*` events |
| `spawn` | 5 | no | `subagent_spawned` (parent glow + child entrance) |
| `handoff_give` | 8 | no | `handoff_started` (source side) |
| `handoff_receive` | 6 | no | `handoff_completed` (target side) |
| `retrieve` | 6 | no | `memory_retrieved` |
| `error` | 4 | no | `error` |
| `recover` | 6 | yes (until completed) | `recovery_started` |
| `success` | 4 | no | `recovery_completed` / `task_completed` / `session_committed` |
| `sleep` | 4 | yes | `Parked` activity state |
| `gate` | 2 | yes (until resolved) | `awaiting_approval` |

Total atlas slices per head shape: 14 states × ~5.5 frames avg ≈ 77 frames × (48×48 px or 48×64) ≈ ~180KB per head shape atlas. Three head shapes ≈ 540KB total base. Palette is shader-applied so we do not multiply by colors. Texture memory budget (50MB cap, see §12) is preserved by orders of magnitude.

### 5.4 Provider presets

These are factory-default companion configurations. Users can edit any axis after creation, but presets are the recommended starting point and they enforce legal-safe palette/role mappings:

| Preset name | Body shape | Palette family | Eyes | Arms | Default prop | Role | Base model recommendation |
|---|---|---|---|---|---|---|---|
| **Claude Code worker** | Block(Wide, Multi-leg, Single antenna, NegativeSpace eyes) | warm orange `#D97757` / cream / amber | NegativeSpace cutouts (no overlay) | None on body (props held by virtual hands) | Wrench / scroll | careful code worker | Anthropic API or Claude Code CLI |
| **Kimi worker** | Block(Compact, Stubs, None, Filled) | indigo / blue / purple (`#5B8DEF` family) | Filled (Round / Slit) | Short | Magnifier / context-scroll backpack | fast explorer / long-context | Kimi API or Kimi CLI |
| **Codex worker** | Block(Compact, Stubs, None, Filled-black) | white / black accents | Filled black-on-white | Short | Wrench / patch-scroll | code patcher / auditor | OpenAI Codex CLI / API |
| **GPT Orchestrator** | Orb | white / gray / blue-gray | Closed | None (or floating Long) | Baton / command ring | calm planner / router | OpenAI API |
| **Hermes Faculty** | *Snake — separate atlas, NOT in Block/Orb/Sage* | gold / orange / bronze | Slit | n/a | Caduceus / scroll | graph-native faculty | Hermes Agent (Nous) |
| **Local Helper** | Block(Compact, Stubs, None, Filled) | teal / muted green | Filled (Round) | Short | Folder / abacus | classifier / memory clerk / router | local Qwen3 / MLX |
| **Custom** | user picks any of Block/Orb/Sage with full parameter access | user-chosen sRGB | user-chosen | user-chosen | user-chosen | user-defined | user-chosen ModelProfile |

**Critical:** Hermes is **not** a normal head shape. The snake/caduceus is its own dedicated atlas with a different rig (no legs; coiling motion; hovering; speaks down to workers). See §8.

**Font choices for sidebar skin (§3.4):** all from macOS-native or open-source curated set:
| Companion | Title font | Reason |
|---|---|---|
| Claude Worker | New York (semibold) | warm, editorial |
| Kimi Worker | SF Mono (medium) | fast, technical |
| GPT Orchestrator | SF Pro Display (light) | clean, neutral |
| Hermes Faculty | New York (bold italic) | scholarly, memorable |
| Local Helper | SF Compact Rounded (regular) | humble, approachable |
| Custom | user-pickable from set above | — |

No imitations of trademarked logo fonts. macOS-native + open + curated.

### 5.5 Honest mapping: cosmetic ↔ config

Every customization choice falls into exactly one of three categories:

**Category A — Real config (audit ledger entry per change):**
| Choice | Real config knob |
|---|---|
| `head_shape` | (cosmetic only — but role-suggestive; logged as `cosmetic_role_hint`) |
| `palette` (when Custom) | sidebar skin color, sprite recolor — cosmetic, but logged |
| `prop` | tool affinity bitset (e.g., wrench → enables `code_edit` and `git` tools; magnifier → enables `web_search`; scroll → enables `note_create`) |
| `arms` | gesture set selection; affects `handoff_give/receive` animation choice — cosmetic but logged |
| `role` | `ProviderRole` enum (Orchestrator / Researcher / Worker / Critic / etc.) — drives system prompt preset and routing rules |
| `base_model` | actual model invoked for inference |
| `system_prompt_preset` | system prompt prepended to every session |
| `tool_affinities` | which MCP tools this companion is allowed to invoke |
| `vault_path` | which folder this companion writes/reads |
| `graph_slice` | which subgraph this companion mutates |

**Category B — Cosmetic only (labeled `cosmetic` in audit):**
- `eyes`, `accessory` (in V1 — V2+ may bind accessories to skill unlocks)
- companion `name` (display label)
- farm position

**Category C — Forbidden (would create dishonesty):**
- Any cosmetic choice that silently changes model behavior. Example: a "hat" that secretly raises `max_tokens` without showing it in the audit. This is a hard no.

**The audit ledger is queryable via `companion.audit_log()` and surfaced in the Audit View.**

### 5.6 Static SVG branding vs Metal-rendered sprites — the rendering hybrid (v1.1)

These are different rendering problems and they use different pipelines. Mixing them up degrades both.

#### The split (canonical pipeline routing)

| Surface | Renderer | Asset format | Why |
|---|---|---|---|
| Titlebar provider chip | SwiftUI `Image` | SVG (`branding/<provider>/icon-color.svg`) | scales across HiDPI, native macOS rendering, tiny file |
| Sidebar wordmark header | SwiftUI `Image` | SVG (`branding/<provider>/wordmark-color.svg`) | provider-branded text needs vector fidelity at multiple zoom levels |
| Command palette icon | SwiftUI `Image` (currentColor tinted) | SVG mono (`branding/<provider>/icon-mono.svg`) | matches macOS palette/symbol rendering idiom |
| Settings UI rows | SwiftUI `Image` | SVG | static, infrequent, scales |
| File-type indicators | SwiftUI `Image` | SVG | static |
| Sidebar mascot pin | SwiftUI `Image` (V1) → Metal MTKView (V2 polish) | SVG (V1) → atlas (V2) | V1 simplicity; V2 unlocks idle animation |
| Landing Farm companion | Metal | raster atlas (`atlas/<head_shape>.png` + `.json`) | needs frame-perfect 14-state animation; zero-copy from reducer |
| Graph Theater companion | Metal | raster atlas | same as Landing |
| Speech bubbles, props, gates | Metal | raster atlas | composed in same draw call as bodies |
| Particle effects (subagent burst, recovery sparks) | Metal | procedural shader | runtime parametric |

#### When to use each

**Use SVG when:**
- The asset is **static** (or has no ≥4-frame animation requirement).
- It must scale cleanly across UI sizes (16, 24, 32, 48, 96 px).
- It is rendered by a system that handles SVG natively (`SwiftUI.Image`, `NSImage`).
- File size matters (an SVG is ~1 KB vs ~10–100 KB for a comparable PNG).
- `currentColor` tinting suffices for variant rendering.

**Use Metal-rendered raster atlas when:**
- The asset has **multi-frame animation** (the 14-state rig per §5.3).
- **Pixel-perfect** frame control is required (SVG rasterization can introduce sub-pixel aliasing — bad for pixel-art aesthetic).
- **Zero-copy** Rust reducer → GPU is required (DOCTRINE I-8, §2.2 of IMPLEMENTATION).
- Composition with other instanced quads in a single draw call (body + eyes + arms + prop + accessory) is needed.

**Use procedural SDF Metal shader when (V2+, optional, not in V1):**
- Customization parameters change frequently (user toggles eye style / leg count / antenna in real time).
- Shader recomputes silhouette from `BlockParams { aspect, legs, antennae, eye_treatment }` uniforms.
- Trade-off: harder to author; aesthetic may diverge from hand-pixeled atlases.
- Recommended only if customization combinatorics make atlases impractical (>30 distinct combinations).

#### What the user supplied (canonical SVG inventory)

The user provided four official Claude Code SVG files and Kimi reference imagery:

| File | Type | Color | Use |
|---|---|---|---|
| `claudecode-color.svg` | mascot icon | warm orange `#D97757` | titlebar, sidebar pin V1, command palette |
| `claudecode.svg` | mascot icon | currentColor (mono) | tintable in any UI surface |
| `claudecode-text.svg` | wordmark | currentColor (mono) | sidebar header when workspace=ClaudeWorker |
| `claudecode-text (1).svg` | wordmark variant | currentColor | same as above; canonical-pick the smaller of the two |

For Kimi: the user provided screenshots, not finished SVGs. **Action:** ship V1 with a placeholder Kimi SVG redrawn from the screenshot (blue Compact Block, hex `#5B8DEF` family). The atlas (animated) is generated separately via the §10 pipeline.

For Codex (white-body): no user-supplied SVG. **Action:** create one in V1 by recoloring the Claude Code SVG path (white body, black eye-rect overlay since the original eyes are negative-space). Validate license/branding fit before shipping (Codex is OpenAI; we use a generic white pixel block, not OpenAI logo art).

For GPT Orchestrator: Orb form, neutral gray. Original Epistemos vector. No external brand asset.

For Hermes: gold caduceus. Original Epistemos vector following Character DNA in §10.2.

For Local Helper: teal Block, original Epistemos vector.

#### Brand-trademark policy (load-bearing)

- Provider wordmarks may be displayed when they accurately describe the active provider integration ("this companion calls Claude Code"). This is identification, not endorsement, similar to "Made for Mac."
- They are **never** Epistemos branding. They never appear in Epistemos chrome (about box, splash screen, marketing copy).
- If a wordmark license is unverified for a given provider, fall back to a generic SF Pro text label like `Provider: Claude Code` instead of the wordmark SVG.
- Audit-ledger requirement: every SVG branding render call records `{ provider, surface, asset_path, timestamp }` so brand usage is reviewable.

#### Rendering rules summary

1. SVG goes through SwiftUI/AppKit; never through Metal directly. (If you need an SVG inside a Metal scene, rasterize it once at app startup to a CGImage at the required scales, upload to a `MTLTexture`, and treat it as a static atlas region.)
2. Animated theater sprites never sample SVG at runtime.
3. The Block-family parameter combinations (Compact/Wide/Tall × None/Stubs/Multi × None/Single/Double × NegativeSpace/Filled) are 36 combos — too many for hand-authored atlases, just barely enough for a **shared base atlas + parameter-conditioned overlay strategy**. V1 ships only the 4–5 named provider-preset combinations as full atlases; Custom companions in v1.1 are restricted to those preset shapes (different eye/arm/prop overlays allowed). V2 introduces SDF shader for full parameter freedom.
4. Palette is **always shader-applied** at runtime via channel-mask uniform (DOCTRINE §10.5), never baked into atlases. This applies to Metal renderer; SVG branding tints via `currentColor` / `.foregroundStyle(...)`.

---

### 5.7 Bit-perfect pixel rendering — visual contract (v1.2)

This section is the operational spec backing Invariant I-16. The reference visual is the user-supplied Kimi orb: stepped silhouette, sharp edges, separate halo, no smoothing of the sprite.

#### What "bit-perfect" means concretely

| Element | Rendering rule |
|---|---|
| Sprite body | nearest-neighbor sampling, integer scale, snap-to-pixel positioning |
| Eye highlights | separate overlay quad with pre-baked bloom in the texture, additive blend |
| Outer halo (active state) | separate additive-blend quad, pre-rasterized soft-edge texture, sized larger than the sprite |
| Speech bubble | nearest-neighbor sampled atlas, no smoothing on the bubble border |
| In-bubble text | bitmap pixel font (no MSDF for the in-bubble text); pixel font matches body grammar |
| Animation interpolation | discrete frame steps (no tween between atlas frames); position moves in integer-pixel increments |
| Camera/scroll | integer pixel coordinates; no sub-pixel scroll, no ease-curves with sub-pixel intermediate values |

#### The pixel circle (Orb head shape) construction

A circular silhouette like the Kimi orb cannot be `<circle r="..."/>` in branding SVG and cannot be a smoothed disc in the atlas. It is constructed from rectangles arranged in a Bresenham-style stepped pattern. For a 32-radius orb at 1× scale, the silhouette has roughly 12 visible "steps" on each edge. The atlas authors this as a hand-pixeled image; the SVG branding version uses `<rect>` elements (or stepped `<path>` with `H`/`V` commands only) to match.

```xml
<!-- Pixel-stepped circle in SVG; orthogonal commands only, no curves -->
<svg viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg">
  <path fill="#5B8DEF" d="
    M10 0 H22 V2 H26 V4 H28 V6 H30 V10 H32 V22 H30 V26 H28 V28 H26 V30 H22 V32 H10 V30 H6 V28 H4 V26 H2 V22 H0 V10 H2 V6 H4 V4 H6 V2 H10 Z
  "/>
</svg>
```

(Example only; the actual Kimi-orb path is generated by the asset pipeline. The constraint is the *commands used* — only `M`, `L`, `H`, `V`, `Z` — not these specific coordinates.)

#### Glow / halo as separate additive quad — never a sprite blur

The Kimi orb's soft outer halo and eye-bloom are *additional draws*, not post-processes on the body. The Metal renderer issues per active companion:

1. **Body quad** — `MTLBlendFactorOne` × `MTLBlendFactorOneMinusSourceAlpha`, nearest sampler, sharp.
2. **Eye-highlight quad** (when companion is `Active`) — additive blend, sampled from a pre-baked eye-glow texture; the softness is in the *texture*, not in the sampler.
3. **Halo quad** (when companion is `Active`) — additive blend, sized ~1.5× body, sampled from a pre-baked soft-radial-gradient texture; again, softness lives in the texture, not in any blur shader.

The body texture is *never* blurred at runtime. Halo softness is hand-baked at design time in Aseprite (or pixel editor of choice) with deliberate stepped radial falloff. This keeps the body razor-sharp while still supporting the active-state aura visible on the reference Kimi orb.

#### Anti-drift: forbidden Metal pipeline patterns

| Forbidden | Why |
|---|---|
| `MTLSamplerMinMagFilter.linear` on sprite atlases | smooths pixels |
| `view.sampleCount > 1` on sprite passes | introduces MSAA bleed |
| Fractional scale matrix `scale(1.5, 1.5)` for sprite quads | breaks pixel grid |
| `position.x = camera.smoothScroll * t` (sub-pixel tween) | sub-pixel ghost trails |
| Gaussian blur applied to a sprite as a post-process | softens the sprite |
| SVG `<circle>`, `<ellipse>`, or path with `C`/`S`/`Q`/`T`/`A` commands in `branding/` | curve smoothing |
| Bilinear interpolation when rasterizing SVG to CGImage | blurred edges |
| Mipmaps generated for sprite atlases | wrong filter at distance |
| `Image(...).interpolation(.high)` in SwiftUI for branding SVGs | smoothing |

These also appear in IMPLEMENTATION §4 forbidden-patterns and in the per-slice anti-drift sweeps.

---

## 6. Robust Creation Flow

The creation flow is the user's first contact with the companion as a configurable agent. It must be hardened: validated, atomic, rollback-capable, audit-logged.

### 6.1 Step sequence (8 steps, dismissible at any point)

1. **Start point** — "Begin from preset" (Claude/Kimi/GPT/Hermes/Local/Custom) or "Bring in via gift-box" (Pro-only adapter sideload skipped here).
2. **Head shape** — Block / Sage / Orb (3 options V1). Skipped for Hermes preset (snake is fixed).
3. **Palette** — locked to provider for non-Custom presets; user-pickable from a curated palette wheel for Custom.
4. **Eyes** — 4 options (Round / Slit / Visor / Closed).
5. **Arms** — None / Short / Long.
6. **Prop / tool affinity** — 6 default props in V1: Wrench (code), Scroll (notes), Magnifier (search), Folder (vault), Baton (route), Lantern (deep-think). Each maps to a tool affinity bitset.
7. **Workspace location** — pick the vault folder this companion lives in. Default: `~/EpistemosVault/Companions/<name>/`. Power user: any folder under `EpistemosVault/`.
8. **Name** — free text, validated for filesystem-safety, uniqueness within registry.

Live preview pane shows the composed sprite updating in real time as the user moves through steps. A "skip to default" button at any step jumps to the preset default for the remaining axes.

### 6.2 Validation per step

| Step | Validation | Failure recovery |
|---|---|---|
| Start | preset exists | re-show preset list |
| Head | shape is Block/Sage/Orb (or fixed for Hermes) | re-show |
| Palette | Custom: sRGB hex, contrast ratio ≥ 4.5:1 against macOS dark+light backgrounds | suggest auto-correction |
| Eyes/Arms | enum validation | re-show |
| Prop | tool affinity grants exist for this companion's role + base_model | warn user; allow override |
| Workspace | path under EpistemosVault root; not used by another companion; writable | suggest alternative |
| Name | non-empty; ≤ 64 chars; filesystem-safe (no `/`, `\`, `\0`); unique in registry | inline error |

If validation fails on a step, the flow does NOT advance. The user fixes or cancels.

### 6.3 Atomic commit / rollback

When the user clicks "Create":

```rust
let txn = registry.begin_transaction();
txn.allocate_companion_id();
txn.write_companion_record();
txn.create_vault_folder();
txn.materialize_model_profile();
txn.create_graph_slice();
txn.write_audit_entry(CompanionRegistered { ... });
txn.commit()?;  // all-or-nothing
```

If any step fails, the entire transaction rolls back: vault folder deleted, registry record removed, graph slice deallocated, audit entry retracted. The user sees the failure with a specific error code. No half-created state.

Exact ordering (durability requirements):
1. Allocate `CompanionId` (in-memory, monotonic ULID).
2. Create vault folder + write `companion.toml` (filesystem; fsync).
3. Insert registry record (SQLite transaction; durable on commit).
4. Materialize `ModelProfile` (separate SQLite row; same transaction).
5. Allocate graph slice (graph DB transaction).
6. Write `companion_registered` event to audit log (append-only JSONL with fsync).
7. Emit `CompanionRegistered` to all observers.

If step 2 succeeds but step 3 fails, step 2 is rolled back (folder removed). If step 6 fails, steps 1–5 are rolled back. Crash recovery (next app launch) detects orphaned vault folders or graph slices and reconciles them via the audit log.

### 6.4 Audit ledger entry (created automatically)

```json
{
  "event_type": "companion_registered",
  "companion_id": "01JZ4...",
  "name": "Sage Reviewer",
  "preset": "Claude Code worker (Block-Wide)",
  "head_shape": "Sage",
  "palette": "claude_warm_v1",
  "eyes": "Round",
  "arms": "Short",
  "prop": "Wrench",
  "role": "CodeWorker",
  "base_model": "claude-sonnet-4-6",
  "system_prompt_preset": "careful_reviewer_v1",
  "tool_affinities": ["code_edit", "code_read", "test_run"],
  "vault_path": "EpistemosVault/Companions/Sage Reviewer",
  "graph_slice": "slice_sage_reviewer_01JZ4",
  "created_at": "2026-04-29T20:00:00Z",
  "created_by": "user",
  "registration_duration_ms": 220
}
```

This entry is the canonical record. Every later customization writes a delta (`companion_updated`) entry. Renames, palette changes, prop swaps, adapter unwraps — all logged.

### 6.5 Failure modes and recovery

| Failure | Detection | Recovery |
|---|---|---|
| Disk full during vault creation | step 2 fsync fails | rollback; user-visible error; suggest cleanup |
| Registry SQLite locked | step 3 timeout (5s) | retry once with backoff; if still locked, rollback |
| Graph slice allocation fails | step 5 returns error | rollback steps 1-4 |
| Audit log write fails | step 6 fsync fails | **CRITICAL** — cannot proceed without audit; rollback registry; surface fatal error |
| App crashes mid-transaction | next launch | reconciliation pass: find orphaned vault folders without registry records, orphan registry records without audit entries; quarantine and surface to user |
| User cancels mid-flow | UI cancel button | discard all transient state; no rollback needed (transaction not started) |

---

## 7. Adapter Gift-Box System

The adapter gift-box is a real, hardened system, not a metaphor. Each gift box on disk is a real artifact whose unwrap performs a real config change.

### 7.1 Gift-box content types (V1 → V3)

| Type | V0/V1 status | Description |
|---|---|---|
| `system_prompt_preset` | V1 | swap or augment companion's system prompt |
| `tool_affinity_bundle` | V1 | enable/disable specific tools for this companion |
| `prop_unlock` | V1 | unlock new prop sprite (cosmetic + tool affinity bind) |
| `accessory_unlock` | V1 | unlock cosmetic accessory (V1 = pure cosmetic) |
| `palette_unlock` | V1 | unlock new palette option |
| `head_shape_unlock` | V2 | unlock new head shape variant |
| `lora_adapter` | V2 (Pro-only) | apply LoRA fine-tune adapter to companion's local model |
| `skill_pack` | V2 | bundle of skill nodes added to companion's skill registry |
| `memory_transplant` | V3 | bootstrap companion vault with a prebuilt subset |
| `auto_generated_companion` | V3 | entire new companion delivered as a gift box |

### 7.2 Gift-box file format

`.epbox` package (folder):
```
my_skill.epbox/
├── manifest.json         // type, version, signature, applies_to (companion role/model), apply_duration_estimate_ms
├── content/              // type-specific payload
│   ├── prompt.txt        // for system_prompt_preset
│   ├── tools.json        // for tool_affinity_bundle
│   ├── adapter.safetensors  // for lora_adapter (Pro-only)
│   └── ...
├── preview/
│   ├── icon.png          // 64×64 gift-box icon
│   └── unwrap.gif        // optional preview animation
└── provenance.json       // origin, license, signature chain
```

Manifest schema:
```json
{
  "epbox_version": "1.0",
  "id": "01JZ...",
  "type": "system_prompt_preset",
  "title": "Careful Reviewer v2",
  "applies_to": {
    "role": ["CodeWorker", "Critic"],
    "models": ["claude-sonnet-*", "claude-opus-*"]
  },
  "apply_duration_estimate_ms": 50,
  "reversible": true,
  "license": "CC0-1.0",
  "origin": "official:epistemos:starter-pack-v1",
  "signature": "...",
  "applied_audit_template": { /* what audit entry this generates */ }
}
```

### 7.3 Origin and trust

Three origin classes:
- **Official** (`origin: "official:..."`): bundled with Epistemos or downloaded from the official registry; signed by the Epistemos team key. Auto-trusted.
- **Community** (`origin: "community:..."`): from public registries (HuggingFace adapter hub, Epistemos Community Registry); signed by registry; user must approve first install per source.
- **User-created** (`origin: "user:local:..."`): user-generated locally (e.g., from local fine-tuning); auto-trusted within the user's machine.

**Filesystem import** (drag .epbox into app) is **Pro-only**; MAS profile only accepts gift-boxes from the official registry to maintain App Store sandbox compliance.

### 7.4 Unwrap UX flow

1. User selects a gift-box from the companion's `Mailroom` surface (an inventory pane in the sidebar).
2. Confirmation dialog: shows what will change. For `lora_adapter` type, surfaces estimated quality/risk warnings.
3. User clicks Unwrap.
4. **Animation duration is dynamically bound to actual apply duration:**
   - On click, the unwrap animation begins (sprite walks to gift box, opens lid).
   - The Rust core begins applying the change in parallel.
   - The animation has a "wait" loop in the middle (gift box hovering, particles emanating) that loops until the apply completes.
   - Maximum wait loops: 8 (≈ 4 seconds). If apply isn't done, the loop continues with a progress chip showing % complete.
   - On apply success, the wait loop transitions to "open + success" frames (1 second).
   - On apply failure, the wait loop transitions to "fizzle + return-to-mailroom" frames (1 second), and the gift box returns to the inventory.
5. On success, the audit ledger writes a `gift_box_unwrapped` event with the full change diff.
6. The companion's appearance updates immediately to reflect any cosmetic changes (new prop, new palette, new accessory).

### 7.5 Permanent visual changes after unwrap

Cosmetic changes from gift-boxes (new prop, accessory, palette unlock) become available in the companion's customization options after unwrap. They are NOT auto-applied unless the gift box is type `palette_swap` or `prop_swap` (which explicitly does so by design).

### 7.6 Auto-generated companions (V3)

A gift-box of type `auto_generated_companion` contains a complete companion definition (head_shape, palette, prop, role, base_model, system_prompt_preset, optional adapter). Unwrap performs the full creation transaction (§6.3) atomically.

Origins:
- **Local fine-tune product:** user fine-tunes a small model on their own data; the resulting adapter + system prompt is bundled as an auto-companion.
- **Hermes synthesis:** Hermes observes the user's working patterns over time and proposes a specialized companion (e.g., "Documentation Companion specialized in your project's conventions"). Surfaces as a gift-box for the user to accept or decline.
- **Milestone reward:** completing certain user goals (100 sessions, first published research artifact, etc.) unlocks a themed companion.

Auto-generated companions are visually marked (subtle glow tint) until the user "adopts" them (one-click action in the inspector); adoption clears the tint. Unadopted auto-companions are auto-archived after 30 days.

---

## 8. Hermes Graph-Native Faculty

Hermes is privileged. It is not "another companion." It is the graph faculty.

### 8.1 Identity

- **Visual:** snake / caduceus / scholarly-serpent. Gold / orange / bronze palette. Dedicated atlas, separate from Block/Sage/Orb.
- **Spatial role:** hovers above the graph plane (z+1). Coils around accessed nodes. Speaks down to worker companions.
- **Behavioral signature:** does not walk; coils, drifts, slithers between nodes.
- **Sidebar skin:** New York Bold Italic title font; gold/bronze accent palette; "Hermes' Vault" label.

### 8.2 Landing-page transformation ritual (v1.4 — opulent canonical Hermes)

The ritual is intentionally elaborate. Hermes is the privileged graph faculty; its entrance is the most cinematic moment in the app. The visual identity is **canonical NousResearch Hermes** (the official typography, the Nous Research character, the snake/caduceus motif) elevated with Epistemos's bit-perfect pixel-art rendering treatment — same separate-quad halo discipline as the Kimi orb (DOCTRINE §5.7), applied here in gold.

#### 8.2.1 Canonical asset sources (NousResearch first, redraw as fallback)

These assets are sourced directly from the official NousResearch publication of hermes-agent and adjacent repos. The `Tools/branding_pipeline/fetch_hermes_canonical.py` probe script lists every visual asset present in:

- `NousResearch/hermes-agent` (primary)
- `joeynyc/hermes-skins` (community themes / variants)
- `NousResearch/brand` and `NousResearch/assets` (probed if they exist)

Run the probe once, review the `_probe.json` summary, promote the canonical files, then delete the `raw/` staging directory. The probe is read-only and conservative — it doesn't auto-promote; the human decides which file is canonical.

Each canonical asset lands at:

| Canonical path | Source | What it is |
|---|---|---|
| `branding/hermes-agent-pixel/wordmark-hero-color.svg` | NousResearch/hermes-agent | the big "HERMES-AGENT" pixel-art title — yellow `#FFCC00` primary with offset orange `#D97757` shadow on black; the user's reference image is the visual contract |
| `branding/hermes-agent-pixel/wordmark-hero-mono.svg` | derived (`currentColor`) | mono variant for surfaces where gold is wrong |
| `branding/hermes-agent-pixel/mascot-snake-color.svg` | NousResearch | the canonical snake / caduceus / serpentine spirit (used as inspiration for the Theater atlas; rendered as-is in landing) |
| `branding/hermes-agent-pixel/mascot-snake-mono.svg` | derived | mono variant |
| `ascii/hermes-agent-portrait.txt` | NousResearch | the Nous Research character ("the girl") rendered as ASCII art for the landing-page entrance |
| `ascii/hermes-agent-banner.txt` | NousResearch / hermes-skins | optional ANSI banner / splash text |
| `ascii/hermes-agent-portrait-extended.txt` | NousResearch | larger / more detailed variant (used in the full-screen ritual) |

If the canonical NousResearch asset cannot be obtained or its license is unclear, V1 ships a hand-drawn original Epistemos asset following the same palette and silhouette direction (yellow/orange/gold pixel typography, serpentine mascot), with provenance recording the substitution. **Never silently substitute one provider's brand for another; never render a placeholder that pretends to be the canonical asset.** The Audit View shows which assets are canonical-NousResearch vs Epistemos-fallback at all times.

License handling: NousResearch publishes hermes-agent under the MIT License (verify each release's `LICENSE` file at fetch time). MIT permits redistribution with attribution. The `provenance.json` for each promoted file records: source URL, source commit SHA, license at time of fetch, and attribution string to render in the in-app `About → Acknowledgments` surface.

#### 8.2.2 The ritual sequence (opulent treatment)

When the user double-clicks the Hermes companion on the Landing Farm, picks Hermes from the Companions picker (DOCTRINE §3.4), or invokes `⌘⇧H`:

| Phase | Duration | What happens | Asset(s) used |
|---|---|---|---|
| **0. Anchor** | instant | The active SwiftUI scene fades to a deep indigo (`#0A0A1F`) base layer; existing Landing Farm sprites cross-fade out (300ms). | — |
| **1. Portrait emerges** | 600ms | The ASCII Nous Research portrait fades in at the **left half** of the canvas, rendered as `Text` in SF Mono pixel-aligned, monochrome cyan-white at first; finishes at full opacity. | `ascii/hermes-agent-portrait.txt` |
| **2. ASCII wave sweeps** | 800ms | A rightward ASCII-character wave sweeps across the canvas (the canonical Hermes wave). Each frame is a discrete pixel-aligned step; no sub-frame interpolation per I-16. | `ascii/hermes-agent-banner.txt` (or generated procedurally) |
| **3. Hero title types on** | 1000ms | The "HERMES-AGENT" pixel-art wordmark types on character-by-character at the **right half** of the canvas, aligned to the portrait's vertical axis. Each character is a discrete pixel-art glyph; the typing is per-glyph, not per-pixel. | `branding/hermes-agent-pixel/wordmark-hero-color.svg` |
| **4. Gold halo pulse** | 500ms | A separate **additive-blend** quad (per I-16 §5.7) overlays the wordmark and portrait area with a pre-baked soft-radial gold gradient (`effects/halo_hermes_gold.png`). It pulses once: opacity 0 → 0.6 → 0.3, then holds at 0.3 for the duration of the Hermes session. The portrait and title themselves are **not** blurred — softness lives in the halo texture, never in a runtime blur. | `effects/halo_hermes_gold.png` |
| **5. Snake coils in** | 700ms | The canonical snake mascot fades in at the **lower center**, performs a single coil animation (5 frames, integer-pixel motion), and settles into its hovering pose at z+1. | `branding/hermes-agent-pixel/mascot-snake-color.svg` (landing) → `atlas/hermes_snake.png` (Theater) |
| **6. Glare flash** | 200ms | A single-frame additive flash texture (`effects/glare_hermes.png`) sweeps left-to-right; portrait/title hold; snake remains. | `effects/glare_hermes.png` |
| **7. Chat surface emerges** | 600ms | The Hermes chat / search / plan UI panel slides up from the bottom edge (250pt height, easeOut), partially overlapping the lower edge of the portrait and snake. The portrait and title remain visible at the top. | — |

Total duration: ~4.4 seconds. The ritual is bound to a single `companion_activity_state_changed: Active` event for the Hermes companion plus the start of a `session_started` event — it never plays without those backing events (per I-5).

#### 8.2.3 Rendering rules (Hermes-specific)

- The hero wordmark (`wordmark-hero-color.svg`) is **pixel-art**: `provenance.json` declares `"category": "pixel-art-mascot"`, the I-16 SVG validator enforces stepped vectors, and SwiftUI renders it with `.interpolation(.none).antialiased(false)`. Rasterization at integer multiples only.
- The ASCII portrait is **text**: rendered as `Text` with `Font.system(.body, design: .monospaced)` at a fixed integer point size; `.lineSpacing(0)`; no kerning adjustments. Monochrome via `.foregroundStyle(...)`.
- The gold halo is a **separate additive quad** with a pre-baked soft texture — never a Gaussian blur of the wordmark.
- The glare flash is a **separate additive quad** with a pre-baked single-frame texture, drawn after the wordmark and snake.
- The snake (landing-page version) uses the canonical NousResearch SVG. The **simulation-theater snake** (active-companion sprite per §4.1) uses the redrawn-original `atlas/hermes_snake.png` per the §10 atlas pipeline; the canonical landing SVG is the *visual reference* for the redrawn atlas, not its source.

#### 8.2.4 Reduce-motion variant

When `NSAccessibility.isReduceMotionEnabled` is on, the ritual collapses to:

1. Cross-fade to indigo background (150ms).
2. ASCII portrait + hero title + snake all appear instantly together (no typing, no wave, no coil).
3. Gold halo holds at 0.3 opacity (no pulse).
4. Chat surface fades in (300ms).

Total: ~450ms. No looping animation, no per-character typing. The visual identity is preserved; the motion is removed.

The transformation is **purely visual ceremony** — the underlying Hermes session is created in parallel via the same registry/session machinery as any other session. The ritual is theatre over honest substrate; the session itself begins the moment the user invokes the action, not when the ritual finishes.

### 8.3 Seven graph verbs (canonical MCP tools)

These are exposed via the `omega-mcp` Rust crate as MCP tools over stdio:

| Tool | Input | Output | Graph effect |
|---|---|---|---|
| `graph.search_semantic` | `{ query: string, k: int, scope?: GraphSlice }` | `[{ node_id, score, snippet }]` | emits `graph_traverse_*` events for traversed paths |
| `graph.search_fulltext` | `{ query: string, k: int, scope?: GraphSlice }` | `[{ node_id, score, snippet }]` | emits FTS access events |
| `graph.get_node` | `{ node_id: NodeId }` | `Node { kind, title, body, edges, metadata }` | emits `graph_node_accessed` |
| `graph.traverse` | `{ start: NodeId, max_depth: int, edge_kinds?: [EdgeKind] }` | `[{ node_id, edge_kind, depth }]` | emits `graph_traverse_*` per step |
| `graph.create_node` | `{ kind: NodeKind, title: string, body: string, parent_refs: [NodeId] }` | `{ node_id }` | emits `graph_node_created` and `graph_edge_created` |
| `graph.create_edge` | `{ from: NodeId, to: NodeId, kind: EdgeKind, metadata?: Json }` | `{ edge_id }` | emits `graph_edge_created` |
| `graph.commit_session` | `{ session_id: SessionId }` | `{ committed: int, artifacts: [NodeId] }` | emits `session_committed` and finalizes session subgraph |

These are the **only** graph mutations Hermes is allowed to perform. Other capabilities (filesystem write, network, computer-use) are not in this faculty scope; they would route through other tools per the standard MCP catalog.

### 8.4 Terminal pane is debug-only

Hermes mode includes an optional terminal-style debug pane showing:
- Raw stdio JSON-RPC frames
- Tool call/response cycles
- Latency per call
- Token usage

This pane is **not the source of truth**. The source of truth is the normalized event log + graph mutations. The terminal is for debugging the Hermes ↔ Epistemos integration.

---

## 9. Honesty Doctrine (Detailed)

This expands on Invariant I-5.

### 9.1 The three classes of allowed animation

| Class | Triggered by | Audit label | Examples |
|---|---|---|---|
| Event-driven | `AgentEvent` or `GraphEvent` | `event:<event_id>` | speak, think, tool, retrieve, spawn, handoff, error, recover, gate |
| Cosmetic idle | "no events for ≥ N seconds" timer | `cosmetic_idle:<companion_id>` | breathing, blinking, micro-fidget, occasional weight-shift |
| Activity transition | `companion_activity_state_changed` | `state_transition:<from>:<to>` | dormant→active glow-up, active→dormant fade-out |

Anything outside these three classes is a **defect** and must be removed.

### 9.2 What is forbidden

- Companion appearing to "type a message" with no `message_*` event.
- Subagents popping out without `subagent_spawned`.
- Companions chatting with each other on the farm without `handoff_*` or `message_*` events.
- Approval gates that resolve without `approval_*` events.
- "Memory retrieval" sparkles without `memory_retrieved`.
- Adapter unwrap completing before the actual apply.
- Companion appearing on graph theater while inactive.

### 9.3 Audit View integration

Every visible animation can be inspected:
- Right-click any animating companion → "Why is this happening?" → opens Audit View at the triggering event.
- Cosmetic idle animations show "this is ambient — no work happening" in the inspector.
- Approval gates show the pending action and approval requestor.

This is the user-visible enforcement of the doctrine.

### 9.4 Reduce-motion mode

When system reduce-motion is on:
- All looping animations stop at frame 0.
- Activity state changes use color/badge transitions instead of motion (e.g., dormant→active = palette desaturation reverses; no glow-up animation).
- Approval gates show a static "warning" badge instead of dropping in.
- Subagent spawn shows children appearing instantly with a brief flash, no radial burst.
- Speech bubbles appear/disappear instantly.

The audit ledger continues to record everything; only the rendering changes.

---

## 10. Companion Asset Pipeline (legal-safe + automated)

### 10.1 The legal-safe doctrine

The reference visuals (Kimi CLI mascot, Claude Code mascot direction, Hermes/Nous caduceus motif, OpenAI/GPT visual cues) are **inspiration**, not source assets. We never ship verbatim mascot pixels. Provider-specific identity is conveyed through:

- **Color palette family** (legally safer; colors alone are rarely protectable outside exact logo contexts)
- **Role behavior** (Kimi-style fast-explorer motion vs Claude-style careful-craftsperson motion)
- **Prop category** (wrench/scroll/magnifier/baton — generic categories)

It is **not** conveyed through:
- Verbatim silhouettes, traced pixels, or recolored copies of proprietary mascot art
- Logos, trademark imagery, or distinctive brand glyphs
- Trademarked names ("Tamagotchi" is a Bandai trademark — we use **Companion** / **Session Sprite** / **Agent Pet** in user-facing copy)

### 10.2 The Character DNA doc

For each preset companion, a human-authored Character DNA file lives in `docs/simulation-mode/character-dna/<preset>.md`. This file:
- States the character's role and personality in plain English
- Specifies palette family with sRGB hex codes
- Specifies silhouette direction in original terms
- Specifies allowed and forbidden inspirations
- Specifies animation personality

This file is what makes the asset copyrightable per US Copyright Office guidance (substantial human authorship).

### 10.3 Generation pipeline (V1 → V2)

**V0 (Slice S4):** placeholder geometry — colored rectangles with text labels for head shape and palette. No real sprites yet. Validates the rendering pipeline end-to-end.

**V1 (Slice S10):** hand-pixeled or AI-assisted-then-refined sprites. Pipeline:

1. **Concept:** Character DNA doc → AI concept image (Midjourney v7 / Flux.2 / SDXL with pixel-art LoRA + ControlNet pose constraint).
2. **Pose-locked sheet:** ControlNet pose enforcement to lock the 14 animation states into a pose sheet at 48×48 (or 48×64 for Sage).
3. **Aseprite refinement:** human edits in Aseprite — palette quantization to 16 colors, anti-alias removal, frame alignment, hand-correction of anatomy. Programmatic via Aseprite CLI or Aseprite MCP server for batch operations.
4. **Auto-slice:** Python + OpenCV detects frame boundaries on the sheet; alpha-trim; normalize to grid.
5. **Atlas pack:** texture array packing (one 2D slice per head shape, animation states laid out in fixed grid). Generated `atlas.json` describes UV coordinates per state per frame.
6. **Provenance manifest:** records seed, model, human editor, license (CC0 or Epistemos-original), date.
7. **Build-time validation:** CI check — every preset must have all 14 animation states; every atlas region must be reachable from the manifest; every sprite must have a provenance entry; no missing license.

**V2 (Slice S11+):** add Eye/Arm/Prop/Accessory overlay atlases as separate assets composing onto base body atlases. This is what enables fast customization without combinatorial atlas explosion.

### 10.4 Asset directory layout (v1.3 — adds smooth-vector provider icons)

Branding SVGs split into **two sub-categories**:

- `branding/<companion-slug>/` — pixel-art companion mascots and pixel-art wordmarks. Bound by I-16 (bit-perfect, stepped paths only). Examples: `claude-code` (user-supplied wide pixel block), Kimi-orb pixel mascot.
- `branding/<provider-slug>/` — smooth-vector provider/company brand icons fetched from LobeHub via `Tools/branding_pipeline/fetch_lobe_icons.py`. **Exempt from I-16** because they are not pixel-art assets. See §10.7.

The two sub-categories share a directory tree but use distinct provenance flags so the validators distinguish them.

```
Epistemos/Resources/CompanionAssets/
├── branding/                                     // STATIC SVG (SwiftUI/AppKit consumes)
│   │
│   │ — PIXEL-ART CATEGORY (bound by I-16; stepped vectors, integer coords) —
│   │
│   ├── claude-code/                              // pixel-art mascot (user-supplied)
│   │   ├── icon-color.svg                        // orange wide-block, hex #D97757
│   │   ├── icon-mono.svg                         // currentColor
│   │   ├── wordmark-color.svg                    // pixel-art "Claude Code" font
│   │   ├── wordmark-mono.svg
│   │   └── provenance.json                       // origin, license, usage scope, "category": "pixel-art-mascot"
│   ├── kimi-mascot/                              // pixel-art Kimi orb (V1 placeholder)
│   │   ├── icon-color.svg                        // stepped circle, blue
│   │   ├── icon-mono.svg
│   │   └── provenance.json                       // "category": "pixel-art-mascot"
│   ├── hermes-agent-pixel/                       // pixel-art Hermes assets (canonical NousResearch)
│   │   ├── wordmark-hero-color.svg               // big "HERMES-AGENT" yellow/orange-shadow on black; landing hero
│   │   ├── wordmark-hero-mono.svg                // currentColor
│   │   ├── mascot-snake-color.svg                // canonical caduceus / serpent (used in landing ritual)
│   │   ├── mascot-snake-mono.svg
│   │   ├── raw/                                  // staging from fetch_hermes_canonical.py probe; delete after promotion
│   │   ├── _probe.json                           // generated by probe; never canonical
│   │   └── provenance.json                       // "category": "pixel-art-mascot"; sources cite NousResearch hermes-agent commit SHA
│   │
│   │ — SMOOTH PROVIDER ICON CATEGORY (exempt from I-16; fetched from LobeHub) —
│   │
│   ├── anthropic/                                // smooth Anthropic logo
│   │   ├── icon-color.svg                        // brand color
│   │   ├── icon-mono.svg                         // currentColor
│   │   ├── wordmark-color.svg                    // text/wordmark variant
│   │   ├── wordmark-mono.svg
│   │   ├── combine-color.svg                     // hero icon + wordmark composed
│   │   ├── combine-mono.svg
│   │   ├── brand-color.svg                       // on-brand background variant (optional)
│   │   └── provenance.json                       // "category": "smooth-vector-brand"
│   ├── claude/                                   // smooth Claude logo
│   ├── openai/
│   ├── codex/
│   ├── kimi/                                     // smooth Kimi brand (distinct from kimi-mascot)
│   ├── moonshot/
│   ├── gemini/
│   ├── google/
│   ├── gemma/
│   ├── perplexity/
│   ├── deepseek/
│   ├── qwen/
│   ├── apple/
│   ├── huggingface/
│   ├── github/
│   ├── hermes-agent/                             // smooth Hermes Agent (Nous Research)
│   ├── mcp/                                      // Model Context Protocol mark
│   ├── _index.json                               // generated; lists all provider slugs and source versions
│   └── README.md                                 // distinguishes the two categories; license summary
├── atlas/                                        // RASTER ATLAS (Metal consumes)
│   ├── block_compact.png                         // Compact Block (Kimi/Codex/Local), all 14 states
│   ├── block_compact.json                        // UV map
│   ├── block_compact.provenance.json
│   ├── block_wide.png                            // Wide Block (Claude Code), all 14 states
│   ├── block_wide.json
│   ├── block_wide.provenance.json
│   ├── orb.png                                   // Orb (GPT, Custom)
│   ├── orb.json
│   ├── orb.provenance.json
│   ├── sage.png                                  // Sage (Custom only)
│   ├── sage.json
│   ├── sage.provenance.json
│   └── hermes_snake.png                          // Hermes dedicated; different rig
├── overlays/                                     // composable, palette-aware
│   ├── eyes/{round,slit,visor,closed,negative_space}.png
│   ├── arms/{none,short,long}.png
│   ├── antennae/{none,single,double}.png         // top-overlay for Block-family
│   ├── legs/{none,stubs,multi}.png               // bottom-overlay for Block-family
│   ├── props/{wrench,scroll,magnifier,folder,baton,lantern}.png
│   └── accessories/                              // V2+, gift-box-unlockable
├── palettes/                                     // shader uniforms, hex tuples
│   ├── claude_warm_v1.json                       // body=#D97757, accent=#FFF1E5, eye=transparent
│   ├── kimi_indigo_v1.json
│   ├── codex_neutral_v1.json
│   ├── gpt_neutral_v1.json
│   ├── hermes_gold_v1.json
│   └── local_teal_v1.json
└── effects/
    ├── speech_bubble.png
    ├── handoff_scroll.png
    ├── approval_gate.png
    ├── error_flash.png
    ├── recovery_gear.png
    ├── halo_active.png         // pre-baked soft radial gradient for active companion halo (additive)
    ├── halo_hermes_gold.png    // pre-baked gold radial gradient for Hermes landing ritual (additive; §8.2.2 phase 4)
    ├── glare_hermes.png        // pre-baked single-frame glare flash for Hermes ritual (additive; §8.2.2 phase 6)
    └── eye_glow.png            // pre-baked eye-bloom texture (additive)
```

The repo also adds an ASCII-art directory parallel to `branding/`:

```
Epistemos/Resources/CompanionAssets/
└── ascii/                                        // ASCII art (TEXT, not raster, not vector)
    ├── hermes-agent-portrait.txt                 // canonical NousResearch character ASCII
    ├── hermes-agent-portrait-extended.txt        // larger / more-detailed variant
    ├── hermes-agent-banner.txt                   // optional ANSI banner / splash
    ├── raw/                                      // staging from fetch_hermes_canonical.py; delete after promotion
    └── provenance.json                           // origin, license, attribution string for in-app About → Acknowledgments
```

ASCII art is rendered as `SwiftUI.Text` with `.font(.system(.body, design: .monospaced))`. It is **not** subject to I-16 (it's not raster pixel art; it's literal characters). It is rendered with whatever font smoothing the system applies to monospaced text (typically subpixel-AA on macOS). The visual identity comes from the character shapes, not from rendering tricks.

### 10.6 SVG static branding pipeline (v1.1)

A separate, much simpler pipeline runs alongside the atlas pipeline.

**Inputs:** SVG files in `Resources/CompanionAssets/branding/<provider>/`.

**Pipeline (build-time + runtime):**

1. **Build-time validation** (`Tools/branding_pipeline/validate.py`):
   - Every `branding/<provider>/icon-*.svg` parses correctly.
   - Every `branding/<provider>/` has `provenance.json`.
   - Every `provenance.json` declares: `origin`, `license`, `usage_scope`, `recoloring_policy`, `commercial_use_ok` (bool).
   - Color-only icons declare their canonical hex (and tolerate ≤2 ΔE drift in the SVG fill from the declared canonical).

2. **Runtime loading:**
   - First reference of an SVG triggers SwiftUI native render (`Image(svgResource:)` if available, else `NSImage(byReferencing: bundleURL)`).
   - Cache the rendered `CGImage` in a per-scale dictionary (1x, 2x, 3x for HiDPI).
   - Tinted variants use SwiftUI's `.foregroundStyle(...)` against a mono `currentColor` SVG; do NOT pre-cache tinted bitmaps unless the same tint is used >100 times per session.

3. **Audit:**
   - Every render call emits `branding.render` signpost with `{ provider, surface, asset_path, tint? }`.
   - Logged to ledger so brand-usage review can produce a complete usage report.

4. **Failure mode:**
   - SVG fails to load → fall back to a generic SF Pro text label (`"Provider: <name>"`) and a system symbol icon. Never crash, never display a broken image placeholder, never substitute another provider's brand.

**Recoloring policy per provider** (encoded in `provenance.json`):

| Provider | `recoloring_policy` | Reason |
|---|---|---|
| Claude Code (user-supplied) | `locked: ["#D97757"]` (color preserved as-is) | match Anthropic brand identity exactly |
| Kimi | `palette_family: ["#5B8DEF"]` (placeholder; user may swap to brand-locked) | placeholder until canonical brand asset confirmed |
| Codex | `recolorable: true` (Epistemos-original) | original asset |
| GPT Orchestrator | `recolorable: true` (Epistemos-original) | original asset |
| Hermes | `recolorable: true` (Epistemos-original) | original asset |
| Local | `recolorable: true` (Epistemos-original) | original asset |

If a `locked` provider's palette must change for the user (e.g., dark-mode contrast), use SwiftUI's `.opacity()` / `.brightness()` rather than re-tinting.

### 10.7 Provider Brand Icon System (v1.3) — smooth vectors, color/mono variants

This is the **third asset category** alongside (1) raster sprite atlases and (2) pixel-art branding. It covers the provider/company logos that label agents, providers, models, and tools throughout the app.

**Source of truth:** LobeHub's `@lobehub/icons-static-svg` package on jsDelivr CDN, fetched at build time by `Tools/branding_pipeline/fetch_lobe_icons.py`. The script downloads every variant LobeHub provides (icon, wordmark, combine, brand) and generates a mono variant of each via `currentColor` substitution. License: MIT for the package; underlying marks are trademarks used for identification only (similar to "Made for Mac" badges).

**I-16 carve-out (load-bearing):** these icons are smooth vector logos. They contain Bezier curves, gradients, multiple fills, and `<circle>`/`<ellipse>` elements. They render through default SwiftUI / CoreGraphics smoothing. **The I-16 SVG validator must skip directories whose `provenance.json` declares `"category": "smooth-vector-brand"`.** Conversely, the I-16 validator **must continue to enforce** stepped-vector rules on directories declaring `"category": "pixel-art-mascot"`.

#### V1 provider catalog (matches the user's LobeHub URL list)

| Slug | LobeHub id | Display name | Brand color hint | Notes |
|---|---|---|---|---|
| `anthropic` | `anthropic` | Anthropic | `#D97757` | parent of claude / claude-code |
| `claude` | `claude` | Claude | `#D97757` | model family |
| `claude-code` | `claudecode` | Claude Code | `#D97757` | CLI/companion |
| `openai` | `openai` | OpenAI | `#000000` | parent of codex / GPT |
| `codex` | `codex` | OpenAI Codex | `#000000` | code-focused variant |
| `kimi` | `kimi` | Kimi | `#5B8DEF` | Moonshot product |
| `moonshot` | `moonshot` | Moonshot AI | `#5B8DEF` | parent of kimi |
| `gemini` | `gemini` | Gemini | `#4285F4` | Google model |
| `google` | `google` | Google | `#4285F4` | parent |
| `gemma` | `gemma` | Gemma | `#4285F4` | open Google model |
| `perplexity` | `perplexity` | Perplexity | `#1FB8CD` | research-focused |
| `deepseek` | `deepseek` | DeepSeek | `#5B8DEF` | open model lab |
| `qwen` | `qwen` | Qwen | `#615CED` | Alibaba (local-MLX-target) |
| `apple` | `apple` | Apple | `#000000` | platform; Foundation Models |
| `huggingface` | `huggingface` | Hugging Face | `#FFD21E` | model hub |
| `github` | `github` | GitHub | `#000000` | code provider |
| `hermes-agent` | `hermesagent` | Hermes Agent (Nous Research) | `#D4AF37` | graph faculty — **dual-sourced**: smooth provider mark via LobeHub goes here (`branding/hermes-agent/`); separately, the canonical pixel-art landing assets (hero typography, snake mascot, ASCII portrait) come from NousResearch via `Tools/branding_pipeline/fetch_hermes_canonical.py` and live in `branding/hermes-agent-pixel/` + `ascii/` per §8.2.1 |
| `mcp` | `mcp` | Model Context Protocol | `#000000` | tool protocol |

#### Variant naming (per provider directory)

Every provider that LobeHub publishes for ends up with up to seven files:

| File | Source | When to use |
|---|---|---|
| `icon-color.svg` | `<id>-color.svg` or `<id>.svg` | **Settings** rows; onboarding hero where the provider is the subject |
| `icon-mono.svg` | derived | sidebar agent label (next to agent name); chat header chip; command palette glyph; tab/window chrome; Audit View attribution |
| `wordmark-color.svg` | `<id>-text.svg` | Settings header strip when introducing a provider section |
| `wordmark-mono.svg` | derived | inline labels alongside text where a wordmark is more legible than an icon |
| `combine-color.svg` | `<id>-combine.svg` | hero/marketing surfaces (icon + wordmark together); registry/marketplace headers |
| `combine-mono.svg` | derived | rarely used; dark-on-light / light-on-dark hero where color is inappropriate |
| `brand-color.svg` | `<id>-brand.svg` | optional; on-brand background variant (rarely needed) |

If a variant is missing upstream, that file is absent and `provenance.json` records `null` for the source. UI code that requests a missing variant must fall back to a generic SF Pro text label (`"Provider: <display>"`) — never to a different provider's icon.

#### The user-facing rule (load-bearing)

> **Color in Settings. Mono everywhere else. Icon-first; words on hover or for accessibility.**

| Surface | Variant | Reasoning |
|---|---|---|
| Settings → Providers | `icon-color.svg` | settings is where users *manage* providers; brand recognition matters |
| Settings → API key row | `icon-color.svg` | same |
| Settings → Default model picker | `icon-color.svg` | same |
| Onboarding hero (provider subject) | `combine-color.svg` (with explicit consent) or `icon-color.svg` | first-touch identification |
| Notes sidebar — agent label | `icon-mono.svg`, tinted `.foregroundStyle(.primary)` | reduces visual noise; respects active workspace skin |
| Notes sidebar — Companions picker (§3.4) section header | `icon-mono.svg`, tinted `.secondary` | navigation aid, not the focus |
| Chat header — provider chip | `icon-mono.svg`, tinted `.primary`; `.accentColor` when active | identifies who is being talked to |
| Command palette — provider routing entry | `icon-mono.svg`, tinted `.primary` | menu item glyph |
| Tab / window chrome | `icon-mono.svg`, tinted `.tertiary` | running-companion indicator |
| Audit View — per-event attribution | `icon-mono.svg`, tinted `.secondary` | dense list; mono prevents visual chaos |
| Inline text label ("running on Anthropic") | `icon-mono.svg`, tinted `.primary`, 12pt | sentence-level glyph |

#### Icon-first vs words

The doctrine is **icon-first with optional words**. Three rules govern when text appears:

1. **Icon alone** (default): when the surface is dense, when the provider is recognizable, and when an accessible label is provided via `.accessibilityLabel("Anthropic Claude Code")`.
2. **Icon + word** (selectively): when introducing a provider in onboarding, in Settings rows, and when the icon is unfamiliar to first-time users (e.g., MCP, Hermes Agent, DeepSeek). Configured per-surface, not per-icon.
3. **Word alone fallback**: only when an icon variant is missing AND the surface needs the brand reference. Renders in SF Pro Text, prefixed with `Provider:` to make the fallback explicit.

VoiceOver accessibility labels are **always** populated regardless of which mode is shown.

#### Rendering recipe (Swift)

```swift
struct ProviderIcon: View {
    let provider: ProviderSlug
    let variant: BrandingVariant     // .color / .mono
    let surface: BrandingSurface     // .settings / .sidebar / .chatHeader / ...

    var body: some View {
        Image(svgResource: "branding/\(provider.rawValue)/\(variant.fileSegment).svg")
            .interpolation(.high)              // OK here — smooth vector, NOT pixel art
            .antialiased(true)                 // OK here — see I-16 carve-out
            .foregroundStyle(tint(for: surface))
            .accessibilityLabel(provider.displayName)
    }

    private func tint(for surface: BrandingSurface) -> AnyShapeStyle {
        switch (variant, surface) {
        case (.color, _):                     return AnyShapeStyle(.tint)  // identity
        case (.mono, .sidebarPicker):         return AnyShapeStyle(.secondary)
        case (.mono, .chatHeaderActive):      return AnyShapeStyle(Color.accentColor)
        case (.mono, .auditView):             return AnyShapeStyle(.secondary)
        case (.mono, _):                      return AnyShapeStyle(.primary)
        }
    }
}
```

`.interpolation(.high)` and `.antialiased(true)` are explicitly **legal here** because of the I-16 carve-out. The same call sites are **forbidden** for pixel-art assets.

#### Validator rule

`Tools/branding_pipeline/validate.py` reads each `provenance.json`:
- If `"category": "pixel-art-mascot"` → enforce stepped vectors per I-16 (no curves, no `<circle>` / `<ellipse>`, integer coordinates).
- If `"category": "smooth-vector-brand"` → only validate that `provenance.json` is well-formed and license/usage fields are populated. Skip path-command checks.

This is the carve-out gate. Agents implementing the validator must respect both branches.

---

### 10.5 Palette application (shader-based, not atlas-baked)

Sprites are drawn in grayscale + a 2-channel mask (R=eye region, G=accent region). The fragment shader recolors at draw time using a `PaletteRef` uniform. This means:
- One atlas per head shape (no per-color duplicates) — saves ~10× texture memory.
- User palette changes apply instantly without re-rasterizing.
- Custom palettes are just sRGB hex tuples in the uniform.

```metal
// Pseudocode in Metal Shading Language
fragment float4 companion_fragment(
    VertexOut in [[stage_in]],
    texture2d_array<float> atlas [[texture(0)]],
    constant Palette& palette [[buffer(1)]],
    sampler s [[sampler(0)]]
) {
    float4 base = atlas.sample(s, in.uv, in.atlas_index);
    // R channel = eye region, G = accent, B = base body
    float3 color = base.b * palette.body
                 + base.r * palette.eye
                 + base.g * palette.accent;
    return float4(color, base.a);
}
```

Implementation detail in `IMPLEMENTATION.md` §3.3.

---

## 11. Event Schema (Canonical)

The full canonical `AgentEvent` enum lives in Rust (`agent_core::events`). Swift mirrors it as a `Sendable` struct via UniFFI generation + post-process.

```rust
// agent_core/src/events.rs
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", content = "payload")]
pub enum AgentEvent {
    SessionStarted { session_id: SessionId, mode: SessionMode },
    SessionCompleted { session_id: SessionId, summary: Option<String> },
    SessionCommitted { session_id: SessionId, artifacts: Vec<NodeId> },

    ParticipantJoined { agent_id: CompanionId, role: ProviderRole },
    ParticipantLeft { agent_id: CompanionId },

    MessageStarted { message_id: MessageId, agent_id: CompanionId },
    MessageDelta { message_id: MessageId, delta: String },
    MessageCompleted { message_id: MessageId, full_text_ref: ArtifactRef },

    ThinkingStarted { agent_id: CompanionId, message_id: MessageId },
    ThinkingDelta { message_id: MessageId, token_count: u32 },
    ThinkingCompleted { message_id: MessageId, summary_ref: Option<ArtifactRef> },

    ToolCallStarted { tool_call_id: ToolCallId, agent_id: CompanionId, tool_name: String, input_hash: Blake3Hash },
    ToolCallDelta { tool_call_id: ToolCallId, partial: serde_json::Value },
    ToolCallCompleted { tool_call_id: ToolCallId, output_ref: ArtifactRef },
    ToolCallFailed { tool_call_id: ToolCallId, error: String },

    MemoryRetrieved { agent_id: CompanionId, node_id: NodeId, score: f32 },
    GraphTraverseStarted { agent_id: CompanionId, start: NodeId, max_depth: u32 },
    GraphTraverseCompleted { agent_id: CompanionId, visited: Vec<NodeId> },
    GraphNodeAccessed { agent_id: CompanionId, node_id: NodeId },
    GraphNodeCreated { agent_id: CompanionId, node_id: NodeId, kind: NodeKind },
    GraphEdgeCreated { agent_id: CompanionId, edge_id: EdgeId, from: NodeId, to: NodeId, kind: EdgeKind },

    ArtifactCreated { artifact_id: ArtifactId, kind: ArtifactKind, generated_by_run: RunId },
    TaskCreated { task_id: TaskId, agent_id: CompanionId, description: String },
    TaskCompleted { task_id: TaskId, result: TaskResult },

    SubagentSpawned { parent_id: CompanionId, child_id: CompanionId, count: u8 },
    SubagentCompleted { child_id: CompanionId, result: TaskResult },

    HandoffStarted { from_id: CompanionId, to_id: CompanionId, payload_id: ArtifactRef },
    HandoffCompleted { from_id: CompanionId, to_id: CompanionId, payload_id: ArtifactRef },

    AwaitingApproval { agent_id: CompanionId, action: PendingAction, deadline_ms: u64 },
    ApprovalGranted { agent_id: CompanionId, action_id: ActionId },
    ApprovalDenied { agent_id: CompanionId, action_id: ActionId, reason: Option<String> },

    Error { agent_id: CompanionId, code: String, message: String },
    RecoveryStarted { agent_id: CompanionId, error_id: String },
    RecoveryCompleted { agent_id: CompanionId, error_id: String, success: bool },

    // Companion lifecycle (registry events, not session events)
    CompanionRegistered { companion_id: CompanionId, /* ... */ },
    CompanionUpdated { companion_id: CompanionId, diff: ConfigDiff },
    CompanionArchived { companion_id: CompanionId },
    CompanionActivityStateChanged { companion_id: CompanionId, from: ActivityState, to: ActivityState },
    GiftBoxReceived { companion_id: CompanionId, epbox_id: String },
    GiftBoxUnwrapped { companion_id: CompanionId, epbox_id: String, applied_diff: ConfigDiff },
    WorkspaceFocused { companion_id: Option<CompanionId> },
}
```

Per-event animation impact is documented in §4 above (search the relevant subsection by event name).

---

## 12. Performance Budgets

Strict, measured, signpost-instrumented.

| Subsystem | Budget | Measurement |
|---|---|---|
| Metal rendering (theater frame, ≤12 active companions) | ≤ 5 ms / frame | `os_signpost` interval `theater.frame`; CI assertion p99 |
| Rust reducer (per event) | ≤ 1 ms | `criterion` bench `reducer.apply_event` |
| FFI control call (UniFFI) | ≤ 50 µs | `os_signpost` interval `ffi.<call_name>` |
| FFI hot delta (ringbuffer) | ≤ 5 µs | `os_signpost` interval `ffi.delta_push`; sampled |
| Graph FTS5 query (semantic search) | ≤ 10 ms p95 | SQLite EXPLAIN ANALYZE in tests |
| Idle CPU (no active sessions) | ≤ 1% | `powermetrics --samplers cpu_power -i 1000` |
| Idle memory resident | ≤ 300 MB | `vmmap` at startup + 60s idle |
| Active session (1 cloud + 1 local model) memory | ≤ 6 GB | `vmmap` during active session |
| Companion atlas total | ≤ 3 MB on disk | `du -sh Resources/CompanionAssets/atlas/` |
| Composed texture memory (VRAM) | ≤ 50 MB | Metal Frame Capture |
| Local model inference (Fast-tier role) p95 | ≤ 500 ms | per-role MLX bench |
| Companion creation transaction (§6.3) | ≤ 300 ms p95 | `os_signpost` interval `companion.create` |
| Adapter unwrap (system_prompt_preset) | ≤ 50 ms | `os_signpost` interval `gift_box.unwrap.<type>` |

If a budget is exceeded, the offending change is a **REGRESSION** and must be fixed or rolled back before merge.

---

## 13. App Store / Pro Profile Distinction

### 13.1 Always-shippable in MAS profile

- All three placements (Landing Farm, Graph Theater, Sidebar Skin)
- Companion creation flow (presets only; no arbitrary file import)
- Hermes graph faculty (MCP-over-stdio is allowed in sandbox; verify entitlement)
- Adapter gift-box from official registry only
- Cosmetic customization
- Replay/scrub timeline
- Audit View

### 13.2 Pro-only

- Custom companion with arbitrary palette (any sRGB)? **MAS-allowed**
- Filesystem import of `.epbox` files (sideload) → Pro-only
- LoRA adapter application requiring local fine-tuning subprocess → Pro-only
- Browser-witness deliberation mode (Slice S13+ Deep Deliberation) → Pro-only
- Companion graph slice cross-vault federation → Pro-only
- Subprocess-spawned local fine-tune training jobs → Pro-only

### 13.3 Compile gates (canonical pattern)

```swift
#if EPISTEMOS_PROFILE_PRO
import EpistemosProSubsystems
#endif

func unwrapGiftBox(_ box: GiftBoxRef) async throws -> UnwrapResult {
    if box.requiresProProfile {
        #if EPISTEMOS_PROFILE_PRO
        return try await ProGiftBoxApplier.apply(box)
        #else
        throw GiftBoxError.requiresProProfile
        #endif
    }
    return try await CoreGiftBoxApplier.apply(box)
}
```

---

## 14. Anti-Drift Rules

These are the tripwires. If an implementer violates any of these, the change is rejected at audit.

### 14.1 Forbidden patterns in code

| Pattern | Why forbidden |
|---|---|
| `AnyView` in companion routing or theater rendering | breaks I-15; loses SwiftUI identity; allocates per render |
| `[String: Any]` in any frame/event hot path | breaks I-15 |
| `try!`, `as!`, force-unwrap in production paths | violates project standards |
| `Process()` / `Process.init()` / `posix_spawn` in MAS profile code | breaks I-12 |
| Bevy app/runtime imports anywhere | breaks I-6 |
| `DispatchQueue.main.sync` from UniFFI callback | deadlock per CLAUDE.md |
| Unbounded `AsyncStream` (use `.bufferingNewest(256)`) | per CLAUDE.md |
| Strip thinking blocks from cloud message history | per CLAUDE.md |
| `Date()` / `Date.now()` / `arc4random()` in the simulation reducer | breaks I-13 |
| Direct mutation of `CompanionRegistry` from Swift | breaks I-7; must go through FFI |
| Animation triggered without backing event | breaks I-5 |
| Companion appearing on graph theater while inactive | breaks I-9 |
| Skipping the audit ledger on companion creation/customization | breaks I-10 |
| Adapter animation completing before apply | breaks I-11 |

### 14.2 Forbidden patterns in docs

- Saying "implemented" without a test/log reference
- Saying "fixed" without showing the failing case before and the passing case after
- Claiming MAS-shippable for any feature using `Process()` / unbounded subprocess / arbitrary file import
- Renaming/refactoring a slice's acceptance criteria after it's "done" (bumps version, requires re-audit)

### 14.3 How implementers detect drift

Before every merge:

```bash
# Forbidden source patterns
rg -n 'AnyView\(|as\? AnyView|\[String: Any\]|try!|fatalError\(|Process\(|Process\.init\(|posix_spawn' Epistemos crates/agent_core/src 2>/dev/null

# Bevy imports
rg -n 'use bevy::|use bevy_app::|extern crate bevy' crates 2>/dev/null

# Date/random in reducer
rg -n 'Date\(\)|Date\.now\(\)|arc4random|thread_rng\(\)|SystemTime::now' crates/agent_core/src/reducer.rs crates/agent_core/src/simulation.rs 2>/dev/null

# Honesty doctrine: animations without event triggers
rg -n 'fn animate_|trigger_animation\(|play_animation\(' Epistemos | rg -v 'AgentEvent\|GraphEvent\|cosmetic_idle\|state_transition'

# Companion registry direct-write from Swift
rg -n 'CompanionRegistry\.|registry\.companions\[' Epistemos
```

If any of these return non-empty (other than legitimate test-only matches), the change is DRIFT.

---

## 15. Non-Goals (Explicit)

These are not in scope for V0–V2. They are listed here to prevent scope creep and to give implementers a clean "no" to point at:

- **Full Bevy engine** (forbidden by I-6).
- **Agent-to-agent free-form chat on the farm** (forbidden by I-5; requires real `handoff_*` events).
- **Companion physics simulation** (gravity, collision) — companions tween between positions; no physics engine.
- **3D rendering** — strictly 2D pixel-art with depth-layering via z-order.
- **Networked multi-user farms** — single-user only; companions live in user's vault, not a shared cloud.
- **Companion procedural generation from raw prompts** — V0–V2 uses presets + customization axes; auto-generated companions (V3) come from explicit pipelines (Hermes synthesis, milestone rewards, local fine-tune products).
- **Web-only Simulation Mode** — Simulation Mode is a native macOS feature; no web fallback.
- **Voice acting / TTS for companions** — speech bubbles only; no audio in V1/V2.
- **Companions on the lock screen / menu bar / notification center** — confined to Epistemos app surface.
- **Tamagotchi-style maintenance loops (feeding, hunger, decay)** — explicitly rejected; companions persist forever, dormant ≠ dying.
- **Real-time collaborative editing of a companion's vault by multiple users** — not in scope.

---

## 16. References and prior context

- `CLAUDE.md` (project root) — architecture invariants, build commands, forbidden patterns
- `docs/architecture/PLAN_V2.md` — overarching architecture plan (if exists)
- `docs/EPISTEMOS_DETERMINISTIC_PERF_PLAN.md` — performance constraints
- `docs/HERMES_INTEGRATION_RESEARCH.md` — Hermes graph faculty background
- `docs/EPISTEMOS_FUSED_v3.md` — full-build spec
- `docs/agent-system/AGENT_ARCHITECTURE.md` — agent runtime architecture
- User's brainstorm conversation in this worktree (saved as memory entries)
- Reference images: Kimi CLI welcome screen, Kimi CLI mascot close-up, KIMI CLI logo, Hermes Agent thumbnail (used as silhouette/identity inspiration only; never copied)

---

## 17. Versioning

- **Version:** 1.6
- **Created:** 2026-04-29 (in `simulation` worktree)
- **Last invariant change:** 2026-04-29 — v1.2 added I-16; v1.3 clarified its scope; v1.4 + v1.6 invariants unchanged from v1.3 (no published v1.5 — the v1.6 doctrine pass combined v1.5's farm-walking + multi-toggle work with v1.6's dispatch / multi-room / knowledge-brick additions in a single revision). Invariants I-1..I-15 unchanged from 1.0.
- **v1.6 expansion (2026-04-29) — landing-page dispatch + multi-room theater + knowledge-brick sidebar:**

  *Farm + landing-page direct interaction (§3.2.x):*
  - §3.2.1 added — per-companion pixel-art random-walk paths within ±32-px home-position radius ("farm-game idle elaboration"). Constraints: integer-pixel motion (I-16), seeded PRNG (I-13), audit-labelled `cosmetic_idle:<companion_id>` (I-5), reduce-motion collapse (I-14), suppressed during gate / error / recovery / parked states. Cross-companion ambient interaction remains forbidden absent `handoff_*` events.
  - §3.2.2 added — working badge (3-dot streaming, mini-prop tool, gate icon) + inline dispatch chat panel anchored to companion tiles. Read-only event ribbon + steer input + approve/deny/inspect chips when gated. Honest: read against the same `AgentEvent` stream the reducer consumes.

  *Graph theater multi-room (§3.3.x):*
  - §3.3.1 added — multi-room theater. ONE room per active **session** (companions sharing a session share a room; parallel sessions get separate rooms). Single MTKView with viewport tiling — N rooms cost ~N × per-companion-render, NOT N × pipeline-rebuild. Layouts: 1, 2, 3 (1+2), 2×2, 3×2, 3×3 + carousel ≥10. Pipelines + atlas shared across rooms (one IOSurface for the whole simulation); per-room camera + viewport + buffer-region differ. Per-room cost stays inside the §12 5 ms p99 budget.
  - §3.3.2 added — graph as full chat replacement. Each room's chat input strip carries every action available in the traditional chat sidebar (send / cancel / regenerate / branch / attach / inspect). Both surfaces drive the same `AgentEvent` stream; single-input-focus invariant prevents double-typing.
  - §3.3.3 added — Overview vs drill-in modes ("entering the room"). Session-toggle chip row at the top (one chip per active session, scoped to session not companion). **Overview mode** (default, ≥ 2 sessions): tiled rooms with simplified glance-able chrome (working badge, helper summary, title strip — no chat / inspector). **Drill-in mode** (entered by clicking a chip / room): selected session expands to full view; thumbnail strip of other sessions on the right; full inspector + event timeline + graph-node activity ribbon + chat input strip render. Single-session-active collapses overview into drill-in shape automatically. Transitions are SwiftUI scale + opacity over the Metal render — not a re-render.

  *Sidebar as knowledge-brick (§3.4.x):*
  - §3.4.1 added — persistent vault hierarchy (Models / Agents / Sub-agents each have `vault/` + optional `vaults/` siblings; Companies have no direct vault). Sub-agents nest indefinitely on disk.
  - §3.4.2 added — multi-toggle sidebar (display tree decoupled from active workspace; active workspace remains ONE per I-9 for chrome).
  - §3.4.3 added — knowledge-brick design language. Typography (New York semibold for sidebar title, SF Pro Text for picker, SF Compact Rounded for agent leaves), density (12 pt indent step, 22 pt tree row, 32 pt agent leaf, 28 pt model header), motion (220 ms spring expand, 180 ms selection pulse, mascot-pin idle loop, 140 ms toggle-chip pulse), per-companion brand color from `provenance.json` applied to title underline + active-agent accent dot + selection pulse + section-header underline of the active company. Pixel-art accents at agent leaves + mascot pin only — everything else is smooth-vector / SF text. Knowledge-brick rule: any new affordance must answer "knowledge-brick or control?" — bricks live in the sidebar, controls live in Settings.
  - §3.4.4 added — multi-vault UI affordances (per-entity `Vaults` sub-disclosure with sibling vaults; inline `⊕ New vault…` create sheet emitting `VaultCreated`; drag-rearrange order persisted in `vault_order` JSON column; archive vault flow mirrors the §3.5 companion-archive pattern). Models also get `Vaults` so "the Model's reference library" is a first-class concept.
  - §3.4.5 added — helper-model summariser. Fast helper model (Claude Haiku 4.5 default; Qwen3-4B-MLX local fallback; user-overridable in Settings) produces a one-line live summary of the active agent for the dispatch panel. Cadence: every 2 s while streaming + on `current_animation` transitions; stops on `Idle`. Cache 30 s after stop. Routes through `ConfidenceRouter`; cost recorded in `reasoning_metrics`.

  *Event schema (§11):*
  - §11 v1.6 — six new `AgentEvent` variants: `SteerRequested`, `SummaryStarted`, `SummaryDelta`, `SummaryCompleted`, `VaultCreated`, `VaultArchived`. Per I-5 every UI-visible affordance traces to a real event; per I-3 these are normalized into the canonical enum like every other event.
- **v1.4 expansion (2026-04-29):**
  - §3.4 Companions picker upgraded to **three-level hierarchy** (Company → Model → Agent). Models use smooth provider mono icons; agents use pixel-art Tamagotchi mascots. Each model row gets its own `+` to seed the creation flow with that model as `base_model`. Local models (Qwen3-4B, Mamba-2 variants, MLX) live under a synthetic `Local` company.
  - §8.2 Hermes landing ritual fully redesigned with **opulent canonical treatment**: 7-phase sequence (anchor → portrait → ASCII wave → hero title type-on → gold halo additive pulse → snake coil → glare flash → chat surface) totalling ~4.4s; reduce-motion variant collapses to ~450ms. Canonical assets sourced from NousResearch hermes-agent.
  - §8.2.1 added — canonical asset sources table with NousResearch primary, joeynyc/hermes-skins community secondary; explicit license handling and Audit-View provenance display.
  - §10.4 added `branding/hermes-agent-pixel/` (pixel-art Hermes assets) and `ascii/` (text-based ASCII art) directories.
  - §10.7 hermes-agent row updated to note **dual sourcing**: smooth provider mark via LobeHub at `branding/hermes-agent/`; canonical pixel-art landing assets from NousResearch at `branding/hermes-agent-pixel/` + `ascii/`.
  - `effects/halo_hermes_gold.png` and `effects/glare_hermes.png` added for the landing ritual additive passes.
  - `Tools/branding_pipeline/fetch_hermes_canonical.py` — read-only probe script that lists every visual asset in NousResearch/hermes-agent, joeynyc/hermes-skins, and adjacent NousResearch repos; stages candidates in `raw/` for human review and promotion. Conservative: never auto-promotes.
- **v1.3 expansion (2026-04-29):**
  - Refined I-16 scope: pixel-art categories only; smooth provider brand icons exempt.
  - §3.4 Notes Sidebar — added the collapsible company-grouped Companions picker affordance (preserves I-9 single-workspace rule; navigation only; configuration stays in Settings). [v1.4 deepened this to three-level.]
  - §10.4 split into pixel-art vs smooth-vector branding sub-categories sharing the `branding/` tree, distinguished by `provenance.json` `"category"` flag.
  - §10.7 (NEW) — Provider Brand Icon System: full LobeHub catalog (18 providers), color/mono variant rules ("Color in Settings, Mono everywhere else"), icon-first-with-optional-words doctrine, SwiftUI rendering recipe, validator carve-out gate.
  - `Tools/branding_pipeline/fetch_lobe_icons.py` — script to fetch all variants from LobeHub CDN, generate mono via `currentColor` substitution, emit provenance manifest per provider.
- **v1.2 (2026-04-29):** added I-16 + §5.7 (bit-perfect pixel rendering visual contract: nearest-neighbor sampling, integer scale, snap-to-pixel positioning, MSAA off, stepped-vector SVG, separate-quad halos, no Gaussian blur of sprites). Reference visual: user-supplied Kimi orb.
- **v1.1 (2026-04-29):** added §5.6 (SVG/Metal hybrid), §10.6 (pixel-art SVG branding pipeline), revised §5.1/§5.4 (Block parameterization) to match user-supplied Claude Code SVG.

When this doctrine is updated:
- Invariants in §1 changed → MAJOR version bump (1.0 → 2.0); requires user approval and full audit pass on existing implementation.
- Sections §3–§9 expanded → MINOR version bump (1.0 → 1.1); update implementation plan to match.
- Editorial fixes, examples, references → PATCH (1.0 → 1.0.1); no implementation impact.

The implementation plan (`IMPLEMENTATION.md`) tracks doctrine version it was last reconciled against.
