# Graph Motion Overlay — Implementation Plan

**Date**: 2026-04-24
**Author**: Claude (Opus 4.7), synthesising v3 unified spec + GPT correction
**Mandate**: "Fortnite's considered motion, not Garry's Mod ragdoll. Authored water, not literal fluid."
**Scope**: `graph-engine/` and `Epistemos/Graph/` only. Explicitly does NOT touch `Epistemos/Sync/VaultIndexActor.swift` or `EpistemosTests/RuntimeValidationTests.swift` (Codex's deadlock patch in flight).

---

## 0. Non-goals

- No new `graph-motion` crate. Work inside `graph-engine/src/`.
- No custom `AlignedF32` allocator. Use padded `Vec<f32>`; upgrade later only if Instruments demands it.
- No full XPBD migration. No Eulerian wave equation on the grid. No "nodes as SPH particles" framing.
- No `RuntimeValidationTests.swift` edits (even if the test's string-scan needs updating — deferred to post-Codex).

## 1. Three-commit intervention (this plan's scope)

The GPT correction is explicit: validate perceptual feel with three surgical changes before building out the full motion stack. Each lands as its own commit:

### Task 1 — Edge endpoint trimming
**Files**: `graph-engine/src/renderer.rs`
**What**: Extend `LineEdgeInstance` + `CurveEdgeInstance` with `r0`, `r1`, `gap`. CPU-side trim endpoints before upload (tangent-preserving for curves). Update MSL structs + vertex shaders. Add fragment-shader occlusion test that discards edge fragments inside either endpoint disc.
**Why first**: Pure rendering win. No physics regression risk. Immediate shift from "physics debug view" to "designed product" (spec §0).
**Tests**: `trim_line_returns_both_ends_advanced_by_radius`, `trim_curve_preserves_tangent`, `trim_collapses_when_nodes_overlap`.

### Task 2 — Release velocity inheritance
**Files**: `graph-engine/src/simulation.rs` (rewrite `unfix_node`), `graph-engine/src/engine.rs` (hook `mouse_up`), existing test `unfix_node_zeroes_velocity` flipped to `unfix_node_preserves_velocity` semantics.
**What**: Add a `DragTracker` struct tracking smoothed pointer velocity (EMA α = 0.72) during drag. On release, do NOT zero `vx`/`vy` — seed them with the smoothed release velocity. Re-heat `alpha` to 0.08 so the graph breathes back to life.
**Why second**: Single-line change to a single function that produces the largest perceptual delta in the app (kills "dead snap").
**Tests**: `unfix_node_preserves_release_velocity`, `drag_tracker_smooths_jitter`, `release_reheats_alpha`.

### Task 3 — WaveEvent rings
**Files**: NEW `graph-engine/src/motion/mod.rs` + `graph-engine/src/motion/waves.rs`, hook into `simulation.rs::tick` after snap-back and before integration, `Cargo.toml` adds `smallvec = "1.13"`.
**What**: `WaveEvent` struct — expanding Gaussian shell with baked speed (320 px/s default, calibrated to capillary waves), amplitude from release-velocity magnitude via `sqrt`, `decay_s = 0.9`, `sigma_px = 80`, `max_radius_px = 1400`. `ActiveWaves` = `SmallVec<[WaveEvent; 8]>`. Emit on `DragTracker::on_release` AND every 40ms during fast drag. Retire when past `max_radius_px` OR amplitude dropped below 5%.
**Why third**: Validates the "instant contact, delayed propagation" aesthetic on top of the now-alive release path. Authored envelope — NOT a solved grid — means control over amplitude, speed, count (spec §4.2).
**Tests**: `wave_force_zero_before_birth`, `wave_force_zero_beyond_max_radius`, `wave_peaks_at_expanding_front`, `active_waves_cap_at_eight`.

## 2. Layered architecture (for future commits, not this one)

```
Layer 4 — Product     (Swift: 3 controls — Motion / Spacing / Appearance)
Layer 3 — Rendering   (Metal: SDF discs + trimmed edges + 120Hz interp)
Layer 2 — Motion      (Rust: FluidGrid current + WaveEvent rings + curl-noise breath)
Layer 1 — Physics     (Rust: springs + repulsion + semi-implicit Euler + per-node mass)
```

The three tasks above touch Layer 2 (task 3) and Layer 3 (task 1) and the Physics/Layer-2 boundary (task 2). Layers 4 (GraphState simplification) and the rest of Layer 1 (semi-implicit Euler migration, per-node mass/damping, NEON) land in a follow-up after feel is validated.

## 3. Tick pipeline insertion

Current `Simulation::tick()` in `simulation.rs:762` runs in this order (19 stages). Task 3's wave accumulation inserts between stage 13 (snap-back) and stage 14 (fluid grid), so classical graph forces settle first, then the overlay layer perturbs on top:

```
...
13. snap-back spring
14. [NEW] wave_events.accumulate_forces()   ← Task 3 lands here
15. fluid grid diffuse/decay/sample
16. mass-based drag
17. integrate (velocity Verlet for now; semi-implicit Euler in follow-up)
18. haptic detection
19. drift accumulation
```

## 4. Anti-collision notes (for Codex + future me)

- **Off-limits during this session**: `Epistemos/Sync/VaultIndexActor.swift`, `EpistemosTests/RuntimeValidationTests.swift`. Codex is patching a Swift 6 data-race there; re-integrating those files belongs to Codex's commit.
- **Build cadence**: wait ≥60s after starting a new xcodebuild before queuing another (Codex's Xcode + DerivedData conflict).
- **Only Rust cargo tests block**: the three tasks above are validated by `cargo test --manifest-path graph-engine/Cargo.toml`. A full `xcodebuild` is only needed at the end, once Codex's data-race fix is in.
- **Swift FFI surface is unchanged this session**. No `graph_engine.h` edits. Swift doesn't need to know about edge gap, drag tracker, or wave events — everything lands behind the existing `mouse_down` / `mouse_moved` / `mouse_up` calls. Task 1's edge gap uses a fixed default (2.0 px) that can later be exposed via a single `graph_engine_set_motion_config(...)` bulk-update when we wire in the GraphState simplification.

## 5. Verification gates

Per commit:

- `cargo test --manifest-path graph-engine/Cargo.toml` — all existing tests pass, all new tests pass.
- No new Swift or xcodebuild output — changes are pure Rust + Metal-inside-Rust-string.
- Test mandated by existing suite (`unfix_node_zeroes_velocity`) is replaced, not deleted, with its invariant inverted AND explained in the commit message.

At the end of all three:

- `cargo test` green.
- `make test-rust` green.
- Wait on `xcodebuild` until Codex lands their patch.

## 6. Parameter starting values (from v3 §4.2)

| Param | Default | Why |
|---|---|---|
| `WaveEvent.speed_px_s` | 320 | capillary-wave perceptual calibration |
| `WaveEvent.amplitude` | 45 × √(release_speed / 300) | sublinear stacking |
| `WaveEvent.sigma_px` | 80 | ring thickness (FWHM ≈ 2.35σ = 188px) |
| `WaveEvent.decay_s` | 0.9 | 1/e fold; ~3 visible oscillations |
| `WaveEvent.max_radius_px` | 1400 | viewport-scale upper bound |
| `DragTracker.alpha` | 0.72 | EMA — suppresses pointer jitter |
| `DragTracker.v_thresh` | 5.0 px/s | below this, no wave on release |
| `DragTracker.wake_interval` | 40 ms | periodic wake during fast drag |
| Edge gap | 2.0 px | beyond node radius; keeps stroke from piercing |
| `release_reheat_alpha_floor` | 0.08 | post-release, graph stays alive |

These are the shipped defaults for this intervention. Tuning happens in a follow-up commit informed by the test criteria below.

## 7. Perceptual acceptance criteria

Per v3 §12 targets, the post-intervention graph should satisfy:

- **Overshoot ratio** (peak displacement beyond equilibrium / original release velocity magnitude): `0.15–0.35`
- **Settling time** (5% threshold): `1.0–2.5s`
- **Period of oscillation**: `0.4–0.8s`
- **Damping ratio**: `0.35–0.65`

Tests in `physics_audit_test.rs` will assert these ranges post-Task-3 as a follow-up commit; this plan's scope stops at the three surgical changes landing clean.

## 8. Sources

- `docs/` local: `Claude fluid one of them.pdf`, `Claude fluid 2.pdf`, `Claude fluid final.pdf`, `Claude fluid.pdf`, `gpt fluid.md`, `Fluid perplex.md` — three independent research passes + the unified v3 executive spec + GPT's surgical-first correction.
- `project_landing_wave_redesign.md` in memory (prior landing-wave work confirmed the authored-ring-over-field layering works on the landing surface — same principle reused here at graph scale).
