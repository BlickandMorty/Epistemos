# Graph Motion Overlay — Audit Against Canonical

**Date**: 2026-04-24 (second pass)
**Reference**: Claude-final synthesis doc (user-supplied 2026-04-24), which cross-references all 6 research docs (Perplexity, GPT, Claude v1-v3) against the actual `graph-engine/` codebase.
**Prior work**: 4 commits on `feature/landing-liquid-wave`: plan (`5cf8e55d`), edge trim (`4b155757`), release velocity (`7ffd14c1`), WaveEvent (`93acfcd3`), per-tick scale fix (`d7f4be40`).

This doc is the honest reckoning between what I shipped and what the canonical says. It supersedes any informal tuning decisions I made in-session — the synthesis is the source of truth.

---

## ✅ What I shipped that matches canonical

### Task 1 — Edge trimming (`4b155757`)
Lines and curves both trim both endpoints by `r0 + gap` and `r1 + gap`. Curves preserve tangent direction and handle length. Returns `None` on collapse so degenerate edges are dropped rather than reversed. Default gap `2.0 px` — matches spec §6 starting value.

✓ Matches canonical §1.5 exactly.

### Task 2 — Release velocity inheritance (`7ffd14c1`)
`DragState` carries `smoothed_vel: [f32; 2]` with EMA α=0.72 and a `min(1/240s)` clamp on the dt divisor. `release_node_with_velocity()` seeds `vx/vy` on unfix instead of the legacy zero-out. Re-heat floor at α=0.08 keeps the sim from sleeping through the follow-through.

✓ Matches synthesis recommendation 1.1 (semi-implicit superset), §2.1 session language.
⚠️ Caveat: my 1/60 scaling (`d7f4be40`) is a **bandaid** for a deeper issue — the canonical fix is the explicit-dt semi-implicit Euler migration (synthesis §1.1, Commit 3). I'm carrying this bandaid until that migration lands; then the scale comes out and velocities live on a real time axis.

### Task 3 — WaveEvent rings (`93acfcd3`)
Authored Gaussian shell with baked speed, sigma, decay, max-radius. `SmallVec<[WaveEvent; 8]>` cap with oldest-evict policy. Retirement when temporal envelope folds below 5% or front passes `max_radius_px`. Radial 1/√r falloff clamped at 16 px origin. `ORIGIN_CLAMP_PX = 16` guard against 1/0 spike.

✓ Matches canonical §1.4 exactly. `WaveEvent` struct shape matches synthesis §1.4's recommendation letter-for-letter.

---

## ❌ Where I drifted from canonical (fixing in this commit)

### Drift 1 — Mass formula still linear

**Found at `graph-engine/src/simulation.rs:712`:**

```rust
self.mass[i] = 1.0 + self.degrees[i] as f32 * 0.2;   // LINEAR
```

**Canonical (synthesis §1.2):**

```rust
self.mass[i] = 1.0 + 0.35 * ((self.degrees[i] as f32) + 1.0).ln();   // LOGARITHMIC
```

**Why this matters**: a degree-50 hub currently gets `mass = 11.0` — so heavy it becomes an immovable black hole under the existing force pipeline. The logarithmic formula gives `mass ≈ 2.38`, which still anchors hubs visibly but lets them participate in the graph's relaxation. This is the difference between "hub as gravity well" and "hub as anchor." Every model in the research converged on the logarithmic form.

**Action**: fix in this audit commit. One-line change; no test surface to update because the existing tests don't assert exact mass values.

### Drift 2 — Wave amplitude bumped to 90

**Found at `graph-engine/src/motion/waves.rs:209`:**

```rust
let amplitude = 90.0 * energy.sqrt();   // I bumped this mid-session
```

**Canonical (synthesis §6)**: `wave_amplitude = 45.0`.

**Why this drifted**: user reported the wave felt subtle; I doubled the base amplitude. In hindsight, the subtlety was masked by the rubber-band kick (from the per-tick/per-second unit mismatch, since fixed in `d7f4be40`). Doubling the amplitude on top of a fixed release wasn't the right tuning move — the synthesis says 45 is the perceptually-calibrated starting value, and 1/60 release scaling was the real cure.

**Action**: revert to 45 in this commit. Re-test; if still too subtle, tune up in a dedicated tuning commit with a proper A/B before/after, not in a diagnostic patch.

### Drift 3 — Wave coupling bumped to 0.5

**Found at `graph-engine/src/motion/waves.rs:170`:**

```rust
pub const DEFAULT_COUPLING: f32 = 0.5;   // I bumped this too
```

**Canonical (synthesis §2.2, §6)**: `fluid_coupling = 3.0-6.0` for FluidGrid drag current, but for WaveEvent rings the canonical reads from the FluidGrid parity (`FLUID_K = 0.2`). The two coupling values conflate in my head last session — waves and fluid-grid currents have different dynamics. For wave rings, 0.2 is the starting parity; it should be tuned against the amplitude once the perceptual loop is complete.

**Action**: revert to 0.2 in this commit. If wave reads as absent at canonical defaults, first verify the integrator fix is live, then bump amplitude before coupling (amp and coupling compound multiplicatively — changing both at once double-counts the correction).

---

## 🟡 Not drift, but flagged by synthesis for fixup later

### Collision is still 50/50 split (synthesis §2.1)

**Found at `graph-engine/src/forces.rs` — `resolve_overlap()` near L327-376**

Currently splits the overlap correction 50/50 between the two colliding nodes. Canonical says: weight by inverse mass. Same PBD-style single-pass Jacobi, just with `w_i / (w_i + w_j)` weighting. Synthesis explicitly rejects a full XPBD migration as unnecessary — "XPBD does position projection, which kills overshoot by construction."

**Action**: land alongside Commit 3 (per-node mass/damping). Same surface, same tests to update.

### `FluidGrid` coupling is dormant (synthesis §2.2, §6)

**Found at `graph-engine/src/simulation.rs:154`**: `const FLUID_K: f32 = 0.2;`

`FluidGrid` infrastructure is fully wired (bilinear inject, 9-point stencil diffuse/decay, bilinear sample) but the coupling from grid velocity into node velocity is 0.2 and dormant under `enable_fluid_dynamics` flag. Canonical recommends 3.0 starting, tunable to 6.0, with the Stokes-style `coupling = β / sqrt(mass)` per-node weighting so heavy nodes feel less current than leaves.

**Action**: Commit 8 in the 10-commit sequence. Not in this audit.

### Curl-noise ambient breath not built (synthesis §1.3, §6)

**Missing module**: `graph-engine/src/motion/curl.rs`

Bridson curl noise (divergence-free 2D field sampled from scalar simplex potential ψ) is the canonical choice over Perlin flow fields. Synthesis §6 specifies 4-tap finite-difference sampling at `curl_spatial_freq = 0.004` (wavelength ≈ 250 px) and `curl_temporal_freq = 0.15 Hz` (cycle ≈ 6.7s). Amplitude weighted by `1 - degree/10` so hubs barely breathe.

**Action**: Commit 7 in the 10-commit sequence. Not in this audit.

---

## 🔄 What synthesis tells me about my Task 4 plan (settings simplification)

I previously proposed **collapsing** the 12 presets (Observatory, Nebula, Crystal, …) behind a developer panel and exposing only `Motion / Spacing / Appearance`. **Synthesis §3.4 rejects this** — quote:

> Claude v3 says "twelve presets, that's a lab, not a product" and recommends collapsing to 3×3. But looking at `GraphState.swift`, your presets serve as **discoverable starting points** for exploration. The issue isn't the count — it's that the underlying physics don't feel good enough to make the presets matter. **My advice:** Keep the presets but rename them to match the new motion vocabulary (Calm, Fluid, Playful as top-level categories). Don't delete anything — just reorganize. The physics improvements will make the presets actually feel different from each other.

**Action**: when I get to Commit 9, it's a **rename-and-reorganize** pass, not a collapse. The 12 presets stay; each gets tagged with a `MotionCategory` (Calm / Fluid / Playful) and the Swift UI groups them under the three category headers. Users still pick `Observatory` or `Deep Sea` — but the menu reads as "Observatory (Calm)" under the Calm header, not as one of 12 flat options.

---

## 🗺️ Remaining work, in canonical order

Per the synthesis's 10-commit sequence, with my checkbox of what's landed:

| # | Canonical task | Status |
|---|---|---|
| 1 | Edge trim + draw order | ✅ `4b155757` |
| 2 | Release velocity inheritance | ✅ `7ffd14c1` (+ `d7f4be40` per-tick scale) |
| 3 | Semi-implicit Euler + per-node mass/damping + compliant collision | ✅ `332d2bbf` |
| 4 | Snap-back spring M3 tuning (freq 1.75, damping 0.55) | ✅ `6b048238` |
| 5 | WaveEvent ring | ✅ `93acfcd3` |
| 6 | 40ms wake cadence during fast drag | ✅ `e62ac243` |
| 7 | Curl-noise ambient breathing | ✅ `9816f6c2` |
| 8 | FluidGrid coupling boost + Stokes scaling | ✅ `ffec5312` |
| 9 | Preset motion-category metadata (keep, don't collapse) | ✅ `b6a14300` |
| 10 | Minimal-grand palette (additive, renderer integration pending) | ⚡ `NEXT` |

**Status**: 9 of 10 canonical commits shipped as of 2026-04-24.
Commit 10's data layer (minimal-grand palette on `NodeType::color_minimal_grand`)
is in place additively; the shader-side integration that actually
flips the graph to the restrained 2.25D-disc aesthetic is a
dedicated renderer session — too invasive to bundle into this
motion sweep without Metal regression risk.

---

## ⚠️ The warm_start risk the synthesis flagged

Synthesis closing note, my copy of the quote:

> Your `warm_start()` at L709-745 runs with `velocity_decay = 0.3` (heavy damping). When you switch to per-node damping, warm-start needs to use the **heaviest** per-node damping (hub damping) as the override, not a single scalar. Otherwise warm-start will under-damp leaves and they'll fly off the screen during initial layout. This is a real regression risk — test it.

**Action plan for Commit 3**: warm_start will compute the heaviest per-node damping (clamped to the already-existing `0.3` floor) and use that as a scalar override for the warm-start pass only. After warm-start completes, per-node damping resumes normally. I'll add a regression test that ingests a 500-node graph and asserts no node position exceeds 2× the viewport during warm-start.

---

## What this means for "panel not showing"

The audit found no code changes in my branch that would disable a panel. Possible causes, in descending likelihood:

1. **Stale DerivedData** — Xcode cached a pre-rebuild Rust dylib; symbol lookup finds nothing. `rm -rf ~/Library/Developer/Xcode/DerivedData/Epistemos-*` + `make deploy-rust && make build`, then launch from the fresh `.app` (not via Xcode's Run, which can reuse the old build).
2. **Codex's `46b6878f`** — App Store runtime preflight; only touched `agent_core/`, shouldn't interact with panel code.
3. **Uncommitted Swift state from Codex's parallel session** — can't see it from my branch. User should confirm `git status` is clean apart from expected workspace files.

I'm not proposing any panel-related code changes in this audit because no change I made should have caused a panel regression. If a specific error message is available, that points at the real cause immediately.
