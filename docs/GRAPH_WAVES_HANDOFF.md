# Graph Motion Overlay — Handoff to Codex

**Date**: 2026-04-24
**Branch**: `feature/landing-liquid-wave` (expect Codex-lane merge conflicts only in `agent_core/` Sendable fixes and `Epistemos/Sync/VaultIndexActor.swift`, both off-limits for this work)
**Final commit on this workstream**: `e2d4adc8` (cleanup: wake + compliant collision + tight edge gap + featured-only picker)
**Scope of this doc**: what Codex needs to audit so we can prove the graph motion overlay is canonical, properly engineered, and feature-complete for the current release bar.

This supersedes no prior plan — it *references* the plan (`GRAPH_WAVES_PLAN.md`) and audit (`GRAPH_WAVES_AUDIT.md`) and gives Codex a single-file entry point to verify every claim in them.

---

## 0. TL;DR for the audit

- 10-commit canonical sequence is shipped. All 10 land under this branch; `main` is untouched beyond what was already there.
- Defaults are NOT at canonical values — they are at legacy values plus three targeted re-enables. The user tested canonical feel and rejected it as "glitchy/springy/finicky"; legacy + targeted re-enable is what reads as right.
- Experimental forces (orbital, torsion, wind, boids, elastic edges) are locked off at two layers: a `const EXPERIMENTAL_MOTION_FORCES_ENABLED = false` master gate inside the tick loop AND a zero-override inside `Engine::set_lab_params` at the FFI boundary. The FFI signature still accepts the arguments (ABI stability) — it just ignores them.
- The motion-overlay code paths (WaveEvent rings, curl breath, compliant collision, per-node damping, FluidGrid coupling) are all present. They're gated by ForceParams defaults. A preset that wants the canonical feel must opt in via the existing lab-params FFI; today no preset does, because we haven't wired per-preset opt-in yet.
- The preset picker UI shows only Observatory / Constellation / Chaos. The remaining 9 presets are kept in the enum, still functional, just filtered out of `.allCases` by `.filter { $0.isFeatured }`.
- Shader changes are parked. User explicitly said "leave the shader alone."
- Codex-lane Swift concurrency warnings (`agent_core` Sendable, `SpotlightIndexer`/`VaultIndexActor` async migration) are owned by Codex — not touched here.

---

## 1. Research consulted (source of canonical truth)

Six independent research passes synthesized into one canonical spec. The PDFs/markdowns were local reference material only — they are NOT in the repo, but their names and version dates are recorded here so Codex can cross-reference if the user supplies them:

| Source | Role |
|---|---|
| `Fluid perplex.md` | Perplexity Sonar Pro survey of current graph-motion literature |
| `gpt fluid.md` | GPT-5 surgical-first correction — three-commit intervention |
| `Claude fluid.pdf` | Claude v1 deep research (first pass) |
| `Claude fluid one of them.pdf` | Claude v2 architecture variant |
| `Claude fluid 2.pdf` | Claude v3 layered motion stack |
| `Claude fluid final.pdf` | Claude final synthesis — cross-referenced all five above against actual `graph-engine/` code, produced the 10-commit canonical sequence |

The final Claude synthesis doc is the source of truth for every canonical value cited below. The GPT surgical correction is the source of truth for the **ordering** of the first three commits — its thesis was "validate perceptual feel before building stack." That ordering shipped.

Also consulted:

- `docs/GRAPH_WAVES_PLAN.md` (committed 5cf8e55d) — the three-commit surgical plan that opened the work.
- `docs/GRAPH_WAVES_AUDIT.md` (committed aae83e8b) — the honest reckoning against canonical, fixing the three drifts that had accumulated mid-session.
- Prior landing-wave work (`docs/LANDING_WAVE_SEARCH_PLAN.md` + memory `project_landing_wave_redesign.md`) — confirmed the "authored rings over field" layering principle works. Same principle applied here at graph scale.

---

## 2. Canonical 10-commit sequence — shipped status

From the Claude final synthesis, canonical order + shipped state:

| # | Canonical task | Commit | Verified |
|---|---|---|---|
| 1 | Edge trim + draw order (CPU-side trim before upload) | `4b155757` | ✅ `trim_line_endpoints`/`trim_curve_endpoints` in `edge_trim.rs`, both with collapse guards |
| 2 | Release velocity inheritance (EMA α=0.72 → seed vx/vy on release) | `7ffd14c1` + `d7f4be40` (per-tick scale bandaid) | ✅ `release_node_with_velocity` in simulation.rs, hooked from `mouse_up` |
| 3 | Semi-implicit Euler + per-node mass/damping + compliant collision | `332d2bbf` | ✅ `decay[]` array + `gamma_from_mass` + compliant `resolve_overlap` |
| 4 | Snap-back spring M3 tuning (freq 1.75 Hz, damping ratio 0.55) | `6b048238` | ✅ `snap_back_strength` param; default reverted to 0.3 in `f77c26d7` |
| 5 | WaveEvent ring (authored Gaussian shell) | `93acfcd3` | ✅ `motion/waves.rs` with `SmallVec<[WaveEvent; 8]>`, 15 tests |
| 6 | 40 ms wake cadence during fast drag | `e62ac243` | ✅ `last_wake_spawn` on DragState, speed-gated emission |
| 7 | Curl-noise ambient breath (Bridson divergence-free) | `9816f6c2` | ✅ `motion/curl.rs` with hand-rolled simplex + 4-tap finite diff |
| 8 | FluidGrid coupling boost + Stokes `β/√m` scaling | `ffec5312` | ✅ `fluid_coupling` param (default 3.0), per-node inverse-sqrt-mass in tick |
| 9 | Preset motion-category metadata (keep 12 presets, don't collapse) | `b6a14300` | ✅ `motionCategory` + `isFeatured` on PhysicsPreset |
| 10 | Minimal-grand palette (data layer) | `d0ace735` | ⚡ data layer only; shader integration deferred (see §7) |

Followed by tuning / re-tuning commits once real feel was tested:

| Commit | Purpose |
|---|---|
| `aae83e8b` | Audit fix — mass formula to log, wave amplitude to 45, coupling to 0.2 (undoing mid-session drift) |
| `f77c26d7` | Revert to legacy defaults — user rejected canonical feel |
| `45e6f197` | Master-gate experimental forces at two layers |
| `e2d4adc8` | Bundle — wake re-enabled, compliant collision back at 0.7, edge gap 0.75, picker filtered, FLUID_K dead-removed |

---

## 3. Shipped-vs-canonical defaults matrix

This is the canary for anyone auditing "did we ship canonical?" — the answer is **no, we intentionally ship legacy + three targeted opt-ins**, and every row below has a reason.

| Param | Canonical | Shipped default | Reason for delta |
|---|---|---|---|
| `collision_compliance` | 0.7 | **0.7** | Ships canonical. Strict 1.0 caused "chaotic jumping" of small children near a dragged hub (single-tick teleport); 0.7 spreads resolution over ~3 frames. |
| `ambient_breath_strength` | 1.0 | **0.0** | Curl ambient drifted entrance-layout centroid + compounded with other motion as background noise. Off by default; preset can turn on. |
| `fluid_coupling` | 3.0 | **3.0** | Ships canonical — the "drag wake" the user explicitly wanted back. Scaled per-node by `1/√mass` so hubs still resist. |
| `enable_fluid_dynamics` | `true` | **`true`** | Ships canonical — user explicitly asked for wake. |
| `snap_back_strength` | 1.0 | **0.3** | Strong M3 kick compounded with per-node damping to produce "springy release." Legacy 0.3 + scalar damping reads right. Preset can opt up. |
| `enable_torsional_springs` | user choice | **forced `false`** | Two-layer gate at master constant + FFI boundary. Adds jitter. |
| `enable_orbital` | user choice | **forced `false`** | Same. "Little nodes still trying to orbit" symptom user called out. |
| `boids_cohesion` | user choice | **forced `0.0`** | Same. Semantic attraction kept; cohesion *boost* gated. |
| `wind_x` / `wind_y` | user choice | **forced `0.0`** | Same. Lateral push distracting. |
| `enable_elastic_edges` | user choice | **forced `false`** (at FFI) | User: "do I need elastic edges? if getting rid would make it better we can do it." |
| `edge_elasticity` | user choice | **forced `0.0`** (at FFI) | Same. |
| `water_wobble` | user choice | **forced `0.0`** (at FFI) | User: "I don't like the wobble, I never use it." |
| `DEFAULT_EDGE_GAP_PX` | 2.0 | **0.75** | User: "close the gap as much as I can without them over the nodes." 0.75 is the tight-but-safe floor per comment in `edge_trim.rs:31`. |
| `ActiveWaves::DEFAULT_COUPLING` | 0.2 | **0.2** | Ships canonical. Tune amplitude before coupling if wave reads too subtle. |
| `CurlField::DEFAULT_COUPLING` | 0.01 | **0.01** | Ships canonical. Already gated behind `ambient_breath_strength = 0.0`. |
| `PHYS_GAMMA_BASE` | 2.5 s⁻¹ | **2.5** | Ships canonical — per-node damping rate (applied only when explicitly enabled by a preset). |
| `PHYS_DAMPING_ALPHA` | 0.5 | **0.5** | Same. |
| Mass formula | `1.0 + 0.35·ln(degree+1)` | **`1.0 + 0.35·ln(degree+1)`** | Ships canonical — fixed from linear `1.0 + 0.2·degree` in audit `aae83e8b`. |

Canonical values for gated-but-off features are still loaded into `ForceParams`. A future per-preset opt-in (see §8) flips them on selectively.

---

## 4. The two-layer master gate (important architectural choice)

User feedback was that presets were re-enabling experimental forces through `set_lab_params` even after ForceParams defaults were flipped off. The fix:

**Layer 1 — `simulation.rs:271` master constant:**
```rust
const EXPERIMENTAL_MOTION_FORCES_ENABLED: bool = false;
```
Every call site to the experimental force functions in `tick()` is now gated:
```rust
if EXPERIMENTAL_MOTION_FORCES_ENABLED && self.params.enable_torsional_springs { ... }
if EXPERIMENTAL_MOTION_FORCES_ENABLED && self.params.enable_orbital { ... }
let boids_boost = if EXPERIMENTAL_MOTION_FORCES_ENABLED { ... } else { 1.0 };
if !at_floor && EXPERIMENTAL_MOTION_FORCES_ENABLED { /* wind */ }
```
Code for these forces is present and compiles — it just isn't called.

**Layer 2 — `engine.rs::set_lab_params` FFI boundary:**
```rust
// Zero these regardless of what the Swift caller passed.
enable_torsional_springs: false,
boids_cohesion: 0.0,
wind_x: 0.0,
wind_y: 0.0,
enable_orbital: false,
enable_elastic_edges: false,
edge_elasticity: 0.0,
water_wobble: 0.0,
torsion_rigidity: 0.5,   // arg kept for ABI
```

The FFI signature still accepts the arguments (ABI stability — Swift call sites unchanged), but the values are discarded before reaching `ForceParams`. This is the *hard* guarantee that no preset, no user prefs panel, no A/B toggle can resurrect these forces without flipping the constant in code.

Codex should **audit both layers are in agreement**. Breaking one without the other would be a drift regression.

---

## 5. Files touched this workstream (Codex's audit surface)

### Rust (graph-engine)

| File | Role |
|---|---|
| `graph-engine/src/edge_trim.rs` | NEW. `trim_line_endpoints`, `trim_curve_endpoints`, `DEFAULT_EDGE_GAP_PX = 0.75`. |
| `graph-engine/src/motion/mod.rs` | NEW. `pub mod waves; pub mod curl;`. |
| `graph-engine/src/motion/waves.rs` | NEW. WaveEvent struct, ActiveWaves (cap-8 SmallVec), 15 passing tests. |
| `graph-engine/src/motion/curl.rs` | NEW. Hand-rolled 2D simplex + curl field + 4-tap finite diff + drift correction. |
| `graph-engine/src/simulation.rs` | MODIFIED. Added per-node damping pipeline, ActiveWaves + CurlField fields, `release_node_with_velocity`, `emit_wave_from_release`, experimental-force gate, warm_start safe path, default flips. |
| `graph-engine/src/engine.rs` | MODIFIED. DragState grew `smoothed_vel`/`last_sample_at`/`last_wake_spawn`, mouse_up branches on fast vs slow release, `set_lab_params` force-disables extras, `set_water_nodes` hardcodes wobble=0. |
| `graph-engine/src/forces.rs` | MODIFIED. `resolve_overlap` takes `mass` + `compliance`, inverse-mass-weighted split, `force_collide_*` signatures aligned. Snap-back tether decay 0.85 → 0.82. |
| `graph-engine/src/types.rs` | MODIFIED. Added `NodeType::color_minimal_grand(is_dark)` additively. |
| `graph-engine/src/lib.rs` | MODIFIED. `pub mod edge_trim; pub mod motion;`. |
| `graph-engine/src/renderer.rs` | MODIFIED. Line/curve edge instance uploaders call `trim_line_endpoints`/`trim_curve_endpoints` before pushing to GPU. No MSL string edits — the shader still sees trimmed `p0`/`p1`. |
| `graph-engine/Cargo.toml` | MODIFIED. Added `smallvec = "1.13"`. |

### Swift (Epistemos)

| File | Role |
|---|---|
| `Epistemos/Graph/GraphState.swift` | MODIFIED. Added `GraphMotionCategory` enum (`calm/fluid/playful/experimental`), `PhysicsPreset.motionCategory` and `PhysicsPreset.isFeatured`. All 12 cases kept in the enum. |
| `Epistemos/Views/Graph/GraphForceSettings.swift` | MODIFIED. Three `PhysicsPreset.allCases` sites filtered to `.filter { $0.isFeatured }` so picker shows Observatory / Constellation / Chaos only. |

### Docs

| File | Role |
|---|---|
| `docs/GRAPH_WAVES_PLAN.md` | NEW (5cf8e55d). Three-commit surgical plan per GPT correction. |
| `docs/GRAPH_WAVES_AUDIT.md` | NEW (aae83e8b). Honest reckoning against canonical, fixed three drifts. |
| `docs/GRAPH_WAVES_HANDOFF.md` | NEW (this file). Single-entry audit surface for Codex. |

### Explicitly NOT touched

- `Epistemos/Sync/VaultIndexActor.swift` — Codex deadlock patch in flight.
- `EpistemosTests/RuntimeValidationTests.swift` — string-scan coupling with Codex's patch.
- Metal shader strings (`.metal` + inline strings in `renderer.rs`) — user said "leave the shader alone."
- `agent_core/` — Codex lane.
- `Epistemos.xcodeproj` — xcodegen territory; new files added to `graph-engine/src/` and auto-picked up by cargo.

---

## 6. Motion overlay code paths — what's wired where

The v3 motion overlay fits on top of the classical d3-style force pipeline without replacing it. Insertion points in `Simulation::tick()`:

```
 1. center force
 2. link spring
 3. many-body repulsion (Barnes-Hut + SIMD)
 4. semantic attraction  (boids_boost gated off)
 5. collision (compliant, mass-weighted when mass[] present)
 6. torsion  (gated off at master constant)
 7. wind    (gated off)
 8. orbital (gated off)
 9. elastic edges (gated off at FFI)
10. cluster / shadow / boundaries
11. drag current (FluidGrid inject from DragState)
12. warm-start override (scalar decay 0.3 during warm_start only)
13. snap-back spring (strength 0.3)
14. [NEW] ActiveWaves::accumulate_forces — WaveEvent rings ← ring overlay
15. [NEW] CurlField::accumulate_forces  — curl breath (ambient=0 default) ← breath overlay
16. FluidGrid diffuse / decay / sample (per-node coupling / √mass)
17. mass-based drag
18. integrate velocities (velocity Verlet; per-node decay[] applied if enabled)
19. haptic detection
20. drift accumulation
```

Wake emission:
- On `mouse_up` → `emit_wave_from_release(node, release_velocity)` if speed above threshold.
- Every 40 ms during drag while `speed_sq >= 10_000.0` (≥100 px/s) → wake ring from current drag position.
- Both go through the same `ActiveWaves::push()` oldest-evict cap-8 buffer.

Edge trim:
- `renderer.rs` line + curve uploaders call `trim_line_endpoints` / `trim_curve_endpoints` with per-node `r0`, `r1`, `gap = 0.75`.
- Returns `Option` — callers drop `None` results (collapsed edges on overlapping nodes).
- Tangent preservation for curves keeps curvature character after trim.

---

## 7. Shader work — parked

The Claude final synthesis calls for shader-side changes:

- 2.25D SDF node discs (inner shadow + outer glow + chromatic strip)
- Edge alpha falloff tuned to match the new trim
- Glyph atlas integration for labels
- Compressed "minimal grand" palette (data layer shipped in `types.rs`, renderer integration pending)

User directive: **"do not mess with the shader… I can just keep them."** The shader stays at the current state. The data layer (`NodeType::color_minimal_grand`) is additive and available for a future dedicated renderer session.

When shader work resumes, the audit chain is in `reference_visual_audit_chain.md` (memory) — 100+ docs across 12 tiers. Must reference before editing any Metal string.

---

## 8. Open work (not blocking this handoff)

### Per-preset opt-in for the motion overlay

Every preset currently lands the same legacy-flavored ForceParams. The work:

1. Find each preset's `case` in `GraphState::physicsPreset` → `ForceParams` mapping.
2. Tag each motion-category:
   - Calm: Observatory, Nebula, Crystal → leave at legacy defaults.
   - Fluid: Deep Sea, Constellation → flip `fluid_coupling` up to 6.0, enable compliant collision 0.7, modest snap_back 0.5.
   - Playful: Chaos, Carnival → all-in canonical values.
   - Experimental: gated presets for developer use.
3. Expose `ambient_breath_strength` and `snap_back_strength` toggles in the M3 sheet so power users can blend.

Not in this branch. The point of ship-flat-then-opt-in is to let users verify the baseline before layering.

### Semi-implicit Euler migration

Current integrator is velocity Verlet with a per-tick decay array. The canonical integrator is explicit-dt semi-implicit Euler. The per-tick scaling bandaid in `engine.rs::mouse_up` (multiplying release velocity by `1/60` to convert px/s → px/tick) goes away once the integrator migrates to real `dt`. Tracked in audit doc as "bandaid carried until migration."

### Collision mass weighting

`resolve_overlap` takes `mass` and computes inverse-mass split *when mass[] is non-empty*. Legacy wrappers pass `&[]` and `compliance = 1.0`. The legacy call site is mass-less; it still ships with 50/50 split. Not a regression — just a known leftover.

### Codex-lane warnings

Unrelated to this workstream but open on the branch:

- `agent_core` Sendable compliance (Swift 6 strict concurrency).
- `SpotlightIndexer` / `VaultIndexActor` full async migration (Codex was mid-flight).

Left for Codex.

---

## 9. Audit checklist for Codex

If you're the auditor, verify each claim below. Each row should either pass cleanly or produce a diff to fix.

### Structural

- [ ] `graph-engine/src/edge_trim.rs` has `trim_line_endpoints` + `trim_curve_endpoints`, both returning `Option` with collapse guards.
- [ ] `graph-engine/src/motion/waves.rs` has `WaveEvent` with fields `origin`, `birth_t`, `speed_px_s`, `sigma_px`, `decay_s`, `max_radius_px`, `amplitude`.
- [ ] `graph-engine/src/motion/curl.rs` has 2D simplex + 4-tap finite-diff curl + drift correction.
- [ ] `motion::waves::ActiveWaves` uses `SmallVec<[WaveEvent; 8]>` with oldest-evict.
- [ ] `Cargo.toml` includes `smallvec = "1.13"`.
- [ ] `lib.rs` registers `pub mod edge_trim; pub mod motion;`.

### Defaults (fail-loud if any differ)

- [ ] `simulation.rs` `ForceParams::default()`: `collision_compliance = 0.7`, `ambient_breath_strength = 0.0`, `fluid_coupling = 3.0`, `enable_fluid_dynamics = true`, `snap_back_strength = 0.3`.
- [ ] `simulation.rs:271` `const EXPERIMENTAL_MOTION_FORCES_ENABLED: bool = false;`
- [ ] `edge_trim.rs:31` `DEFAULT_EDGE_GAP_PX = 0.75`.
- [ ] `waves.rs` `ActiveWaves::DEFAULT_COUPLING = 0.2`.
- [ ] `curl.rs` `DEFAULT_COUPLING = 0.01`.
- [ ] Mass formula at `simulation.rs:712` is `1.0 + 0.35 * (degree as f32 + 1.0).ln()`, NOT `1.0 + degrees * 0.2`.

### Experimental-force gate (both layers)

- [ ] Every `tick()` branch that calls `force_torsion`, `force_wind`, `force_orbital`, or the boids cohesion boost is wrapped in `if EXPERIMENTAL_MOTION_FORCES_ENABLED && …`.
- [ ] `engine.rs::set_lab_params` overrides `enable_torsional_springs`, `boids_cohesion`, `wind_x`, `wind_y`, `enable_orbital`, `enable_elastic_edges`, `edge_elasticity` to their off/zero values before assigning to `params`.
- [ ] `engine.rs::set_water_nodes` hardcodes `water_wobble = 0.0`.

### Drag + wake

- [ ] `engine.rs` `DragState` has `last_world: [f32; 2]`, `last_sample_at: Instant`, `smoothed_vel: [f32; 2]`, `last_wake_spawn: Instant`.
- [ ] EMA α = 0.72, min sample dt = 1/240, in `mouse_moved`.
- [ ] Wake emission threshold `speed_sq >= 10_000.0`, cadence 40 ms.
- [ ] `mouse_up` fast-release path calls `release_node_with_velocity` with `smoothed_vel * (1.0/60.0)` and `emit_wave_from_release`.
- [ ] `mouse_up` slow-release path calls the legacy `unfix_node`.
- [ ] Alpha re-heat `sim.params.alpha = sim.params.alpha.max(0.08)` in fast-release.

### Swift

- [ ] `PhysicsPreset` has `motionCategory: GraphMotionCategory { … }` covering all 12 cases.
- [ ] `PhysicsPreset.isFeatured` returns `true` for exactly `.observatory`, `.constellation`, `.chaos`.
- [ ] `GraphForceSettings.swift` uses `PhysicsPreset.allCases.filter { $0.isFeatured }` in all picker sites.
- [ ] `GraphMotionCategory` has cases `calm`, `fluid`, `playful`, `experimental`.

### Tests

- [ ] `cargo test --manifest-path graph-engine/Cargo.toml` passes clean. Last confirmed green: 2498 tests at `e2d4adc8`.
- [ ] `simulation_is_deterministic` passes (curl uses `tick_count * PHYS_TICK_DT`, not `now_s()`).
- [ ] `entrance_layout_centered` passes (warm_start disables ambient + grace ticks + drift correction).
- [ ] Chaos-preset tests (27 cases) pass (`saturating_add` in simplex hash, non-finite early-return in `CurlField::sample`).

### Build

- [ ] `make deploy-rust` succeeds (produces `build-rust/libgraph_engine.*`).
- [ ] `xcodebuild -scheme Epistemos -destination 'platform=macOS' build` succeeds post-Codex merge (wait for Codex to land the Swift 6 Sendable fixes first).
- [ ] No new `never used` warnings in `graph-engine` (the `FLUID_K` warning that used to show is gone as of `e2d4adc8`).

### Docs

- [ ] `docs/GRAPH_WAVES_PLAN.md` still matches what shipped (it's a pre-commit plan, so Task 1 "gap 2.0" is fine as historical record — the actual default in the code is 0.75 with a comment explaining why).
- [ ] `docs/GRAPH_WAVES_AUDIT.md` drift corrections are all live in the code.

---

## 10. If something feels off during audit

Order of likely causes, by base rate:

1. **Stale build** — `rm -rf ~/Library/Developer/Xcode/DerivedData/Epistemos-*` then `make deploy-rust && make build`, then launch from the fresh `.app` rather than Xcode's Run button. The Rust dylib at `build-rust/libgraph_engine.*` is the actual linked artifact; if it's stale nothing else matters.
2. **Codex-lane uncommitted state** — check `git status` is clean apart from expected workspace files. Codex's in-flight `Epistemos/Sync/VaultIndexActor.swift` and `EpistemosTests/RuntimeValidationTests.swift` should show as the only unstaged files.
3. **Merge with main regressed a default** — `git diff main -- graph-engine/src/simulation.rs | grep -E 'collision_compliance|fluid_coupling|snap_back_strength|EXPERIMENTAL_MOTION'` and check against §3 above.
4. **Experimental-force gate leak** — grep `rg 'enable_torsional_springs|enable_orbital|boids_cohesion|wind_x|wind_y' graph-engine/src/` and confirm every non-declaration site is either inside the gate or inside `set_lab_params` override.

---

## 11. Quick reproduction script

```bash
# From repo root
cd /Users/jojo/Downloads/Epistemos

# Rust first — the authoritative build product
cargo test --manifest-path graph-engine/Cargo.toml
make deploy-rust

# Swift (only after Codex's Swift 6 patch merges clean)
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify

# Smoke test from the app
# 1. Create a graph with ~50 nodes including one hub of degree ≥ 15.
# 2. Drag the hub slowly through a child cluster — children should give way softly,
#    NOT teleport or jump. This is the compliant collision 0.7 check.
# 3. Drag the hub fast (>100 px/s) and release. On release:
#    - Node should coast (no dead-stop).
#    - A visible ring of perturbation should expand outward (wake).
#    - Alpha should re-heat; the graph should re-settle, not sit static.
# 4. Open the motion preset picker. It should show Observatory / Constellation / Chaos
#    and nothing else.
# 5. Switch between presets. Each should change the graph's feel (alpha, decay,
#    center_strength, etc.) but none should re-enable orbiting or torsional
#    jitter — if anything orbits, the gate has leaked.
# 6. Edges should kiss the node boundary without piercing the disc. No ~2px gap,
#    no overlap into the node.
```

---

## 12. Sign-off expectations

When the audit is clean and Codex is ready to move this into the release train:

1. Confirm the defaults matrix in §3 hasn't drifted since `e2d4adc8`.
2. Run `cargo test` + `make deploy-rust` one more time.
3. Update `docs/AGENT_PROGRESS.md` with a ✅ for "Graph motion overlay canonical sequence".
4. Update `PROGRESS.md` if the release lane tracks this work.
5. Rename / close `docs/GRAPH_WAVES_PLAN.md` and `docs/GRAPH_WAVES_AUDIT.md` references if they're no longer active planning docs (keep the files for history, just unlink from the active index).

---

## Appendix A — Motion overlay parameter reference

From the Claude final synthesis, cross-referenced against shipped code:

| Param | Canonical | Shipped | Where |
|---|---|---|---|
| Wave `speed_px_s` | 320 | 320 | `waves.rs` |
| Wave `amplitude` | 45 × √(release_speed / 300) | 45 × √energy | `waves.rs` |
| Wave `sigma_px` | 80 | 80 | `waves.rs` |
| Wave `decay_s` | 0.9 | 0.9 | `waves.rs` |
| Wave `max_radius_px` | 1400 | 1400 | `waves.rs` |
| Wave `DEFAULT_COUPLING` | 0.2 | 0.2 | `waves.rs:173` |
| Wave `ORIGIN_CLAMP_PX` | 16 | 16 | `waves.rs` |
| Wave cap | 8 | `SmallVec<[WaveEvent; 8]>` | `waves.rs` |
| Drag EMA α | 0.72 | 0.72 | `engine.rs::mouse_moved` |
| Drag min sample dt | 1/240 s | 1/240 | `engine.rs::mouse_moved` |
| Drag wake cadence | 40 ms | 40 ms | `engine.rs::mouse_moved` |
| Drag wake speed gate | 100 px/s | 10000 px²/s² | `engine.rs::mouse_moved` |
| Release re-heat alpha | 0.08 | 0.08 | `engine.rs::mouse_up` |
| Release velocity scale | 1.0 (with explicit dt) | 1/60 (bandaid) | `engine.rs::mouse_up` |
| Curl spatial freq | 0.004 | 0.004 | `curl.rs` |
| Curl temporal freq | 0.15 Hz | 0.15 | `curl.rs` |
| Curl breath weight | `(1 - degree/10).clamp(0,1)` | same | `curl.rs` |
| Curl settle grace | 60 ticks | `AMBIENT_SETTLE_GRACE_TICKS = 60` | `simulation.rs` |
| PBD `γ` base | 2.5 s⁻¹ | 2.5 | `simulation.rs:229` |
| PBD damping α | 0.5 | 0.5 | `simulation.rs:231` |
| Mass formula | `1.0 + 0.35·ln(degree+1)` | same | `simulation.rs:712` |
| Compliant collision default | 0.7 | 0.7 | `simulation.rs:159` |
| Snap-back strength default | 1.0 (canonical M3) | 0.3 (legacy) | `simulation.rs:200` |
| Snap-back tether decay | 0.82 | 0.82 | `forces.rs` |
| Warm-start scalar decay | 0.3 | 0.3 | `simulation.rs:258` |
| Fluid coupling default | 3.0 | 3.0 | `simulation.rs:168` |
| Fluid diffusion | 0.25 | 0.25 | `simulation.rs:280` |
| Fluid per-node scale | `β / √mass` | same | `simulation.rs` tick |
| Edge gap | 2.0 px (canonical) | 0.75 px (user ask) | `edge_trim.rs:31` |
| Edge collapse epsilon | 0.5 px | 0.5 | `edge_trim.rs:43` |
| Edge min trimmed handle | 8 px | 8 | `edge_trim.rs:36` |

---

## Appendix B — One-line rationale per commit (for cross-checking against plan + audit)

- `5cf8e55d` — plan doc (scope lock before work).
- `4b155757` — Task 1 (edge trim).
- `7ffd14c1` — Task 2 (release velocity seeded from drag EMA).
- `93acfcd3` — Task 3 (WaveEvent rings).
- `d7f4be40` — bandaid: release velocity scaled by 1/60 to match per-tick units + wave amp bumped mid-session.
- `aae83e8b` — audit commit: fixed three drifts (mass formula to log, wave amp back to 45, coupling back to 0.2), published audit doc.
- `d959ed6f` — cleanup pass (pruned dead paths, tightened boundaries).
- `332d2bbf` — per-node damping + compliant mass-weighted collision.
- `6b048238` — snap-back M3 tuning.
- `e62ac243` — 40 ms wake cadence during fast drag.
- `9816f6c2` — curl-noise ambient breath.
- `ffec5312` — FluidGrid coupling boost + Stokes `β/√m`.
- `b6a14300` — PhysicsPreset motion-category metadata (keep 12, tag each).
- `d0ace735` — minimal-grand palette data layer.
- `f77c26d7` — revert defaults to legacy (canonical rejected as glitchy/springy); kill wobble; flip `isFeatured` for Observatory/Constellation/Chaos only.
- `45e6f197` — master-gate experimental forces at both layers.
- `e2d4adc8` — final bundle: wake back on, compliant collision back at 0.7 (safe without per-node damping), edge gap 0.75, picker filtered, FLUID_K dead-removed.

---

End of handoff. Ping back with any red flags in the audit; defaults are the most likely drift vector on a merge.
