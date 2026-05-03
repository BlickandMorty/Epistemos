# R15 Live MLX Tok/s Harness — Go / No-Go Decision Note — 2026-05-03

> **Verdict: NO-GO (today). Conditional GO once §3 prerequisites hold.**
>
> This note summarizes the existing preflight artifact at `docs/fusion/fleet/r15-live-mlx-memory-preflight/R15_LIVE_MLX_MEMORY_PREFLIGHT_2026_05_03.md` and converts the captured machine state into a single decision. **No live MLX benchmark was run** to produce this note.
>
> Doctrine §7 lane: Core open — R15 remaining specialized baselines. Generated per `PARALLEL_WORK_MANIFEST.md` round-82 P3.

---

## 1. Cited preflight evidence

**Source artifact:** `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/r15-live-mlx-memory-preflight/R15_LIVE_MLX_MEMORY_PREFLIGHT_2026_05_03.md`

Captured at **2026-05-03T15:25:10Z** on a 16 GiB Apple Silicon Mac (`hw.model: Mac14,9`, macOS 26.3.1, build 25D2128). The four numbers that drive the decision:

| Class | Value |
|---|---|
| Free + Inactive + Speculative + Purgeable (reclaimable headroom) | **≈ 3.15 GiB** |
| Free disk on `/` | 188 GiB (ample) |
| Power state | AC, 100% charged |
| User's hardware memory budget per `user_hardware.md` | "16 GB unified memory ceiling; realistic budget ~10–11 GB for weights+KV; 4-bit 7-8B is the sweet spot" |

---

## 2. Decision: NO-GO today

**Reasoning (one paragraph as required by acceptance §125 of `PARALLEL_WORK_MANIFEST.md` P3):**

The preflight captured ≈ 3.15 GiB of reclaimable headroom on a 16 GiB host whose realistic working budget for an MLX run is ~10–11 GiB (per the user's documented hardware ceiling). A 4-bit 7B model loads at ~4 GiB resident weights plus 1–2 GiB KV under streaming, plus the existing Active + Wired footprint of ~6 GiB the snapshot already shows in use. Loading the harness now would force memory-pressure swap or trigger the existing `MLXInferenceService` `.warning` / `.critical` handlers (drop `persistentSSMSession`, unload model container) **mid-bench**, which would contaminate the tok/s number and waste the run. The R15 PR8 closure status in `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` already records "PR8 has an opt-in live MLX tok/s harness and a documented blocked sentinel run" — this note confirms the blocked sentinel still applies to today's host state.

---

## 3. Conditions for a future GO

Re-evaluate via a fresh preflight (timestamped re-capture of the §1 numbers) before any attempted run. The harness becomes safe when **all** of the following hold:

1. `vm_stat` reports ≥ **8 GiB** in `Free + Inactive + Speculative + Purgeable` (≥ 2.5× today's 3.15 GiB).
2. Other heavy apps (Chrome, Cursor, Slack, Xcode, Codex GUI) are quit or paused — they account for most of today's Active + Wired footprint.
3. The Mac is on AC power AND has been idle for ≥ 60 s (so thermal state is at baseline).
4. The harness uses a 4-bit 7–8B model per the user's stated sweet spot, not Q4 13B or Q8 7B.
5. The harness does NOT spool a per-token log to memory or disk during the run (would skew the tok/s number).

If any one fails, defer.

---

## 4. Recommended next action

**Don't run the harness.** The next R15 step is **not** the benchmark itself — it is one of:

- **Option A (zero-effort, recommended):** wait. Re-run preflight before the next attempt; defer until §3 holds. The R15 lane's other PRs (PR2–PR7, PR9–PR11) are already closed; the live tok/s number is a single missing data point, not a build blocker.
- **Option B (small effort):** write `scripts/r15-mlx-preflight.sh` — a one-liner that prints the four §1 numbers + verdict — so the user can spot-check headroom without re-reading the preflight artifact each time. (This appeared as a candidate in the prior `CODEX_PARALLEL_WORK_RATIONALE_PROMPT_2026_05_03.md` E1 list; it is **not** in this round's manifest, so do not open it without coordination.)
- **Option C (deferred):** if the user wants the tok/s number this week, free memory by quitting heavy apps + restart, then re-capture preflight + re-evaluate against §3. The harness itself is not the slow step; the readiness check is.

---

## 5. What this note does NOT do

- ❌ It does not run any live MLX benchmark.
- ❌ It does not modify the existing preflight artifact.
- ❌ It does not modify any code, test, project file, package file, or build script.
- ❌ It does not edit canon-in-flight docs.
- ❌ It does not stage or commit anything.

---

## 6. Reservation respect

This note was generated without editing any of:

- `docs/fusion/fleet/r15-live-mlx-memory-preflight/R15_LIVE_MLX_MEMORY_PREFLIGHT_2026_05_03.md` (read-only source)
- `Epistemos/Bridge/ClarifyPromptBridge.swift` (closed by Codex PR43; unrelated to this R15 note)
- `EpistemosTests/ClarifyPromptBridgeAgentEventTests.swift` (closed by Codex PR43; unrelated to this R15 note)
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/fleet/REGISTRY.md`
- `docs/fusion/fleet/PARALLEL_WORK_MANIFEST.md`
- Any current-slice deliberation file in `docs/fusion/deliberation/`
- Any current-round oversight file in `docs/fusion/oversight/`
- Protected paths: `ProseEditor*.swift`, `MetalGraphView.swift`, `HologramController.swift`, graph physics/render internals
- `project.pbxproj`, `Cargo.toml`, `Package.swift`, build scripts
