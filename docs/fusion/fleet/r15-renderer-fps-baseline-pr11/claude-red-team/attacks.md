---
role: claude-red-team
slice: r15-renderer-fps-baseline-pr11
brief: docs/fusion/deliberation/r15_renderer_fps_baseline_pr11_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 2
p0_attacks: 0
p1_attacks: 1
p2_attacks: 1
p3_attacks: 0
verdict: brief-revise
usefulness: +1
usefulness_reason: Forces honest thermal-soak wording and exact protected-path staging before implementation.
---

## Attacks

### A1 — Thermal-soak wording can overclaim the artifact [P1]
**Surface:** Brief acceptance and expected JSON artifact name.
**Attack:** The reserved filename includes `renderer_fps_thermal_soak`, but the proposed focused test is an opt-in offscreen renderer fixture, not a five-minute manual thermal soak. The implementation must keep `thermal_soak_status=not_five_min_thermal_soak` in metadata, source guards, ledger requirements, and docs. If the ledger or current state claims manual/product readiness, block the patch.
**Evidence:** `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 3 keeps live renderer FPS open for a later real fixture gate and forbids production renderer edits.
**Mitigation proposed:** PR11 may close only a live offscreen renderer-FPS fixture baseline. It must not claim product-runtime, manual, or five-minute thermal-soak readiness.

### A2 — Shared setup extraction must avoid accidental production touch [P2]
**Surface:** Approved file list.
**Attack:** The brief asks to reuse/extract GraphEngine fixture setup. That extraction is fine inside `EpistemosTests/Benchmarks/GraphFFIBenchmarkTests.swift`, but not in `Epistemos/Graph/GraphEngine.swift` or graph-engine internals. Any helper moved into production would convert a benchmark slice into architecture work.
**Evidence:** `MASTER_RESEARCH_INDEX_2026_05_02.md` §10 marks graph renderer and graph-engine paths high-risk/protected.
**Mitigation proposed:** Keep all helper extraction private to the benchmark test file and run staged diff checks against `Epistemos/Graph/GraphEngine.swift`, `Epistemos/Views/Graph/**`, and `graph-engine/**`.

## Brief verdict

Codex local Red Team would ship the brief after applying the P1 constraint literally during implementation. No P0 attack found. The patch is approved only if it stays test/docs/result-only and records the baseline as an offscreen live renderer fixture with explicit non-manual thermal-soak metadata.

CLAUDE-RETURN: role=RED-TEAM | slice=r15-renderer-fps-baseline-pr11 | round=44 | artifact=docs/fusion/fleet/r15-renderer-fps-baseline-pr11/claude-red-team/attacks.md | usefulness=+1 | p0=0 | p1=1
