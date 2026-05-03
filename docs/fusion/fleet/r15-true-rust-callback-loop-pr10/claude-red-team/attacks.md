---
role: codex-red-team
slice: r15-true-rust-callback-loop-pr10
brief: docs/fusion/deliberation/r15_true_rust_callback_loop_pr10_deliberation_2026_05_02.md
date: 2026-05-03
attacks_total: 4
p0_attacks: 0
p1_attacks: 2
p2_attacks: 2
p3_attacks: 0
verdict: brief-revise
usefulness: +1
usefulness_reason: Surfaces staging, generated-binding, and evidence-ledger hazards before code.
---

## Attacks

### A1 — Dirty `agent_core/src/bridge.rs` hunks can be silently swept into PR10 [P1]

**Surface:** `agent_core/src/bridge.rs`
**Attack:** The file already has unrelated dirty changes around memory pressure and JSON serialization. If Codex stages the whole file, PR10 will accidentally commit unrelated runtime behavior. This would violate the slice boundary and make the benchmark commit non-reviewable.
**Evidence:** `docs/fusion/oversight/PREFLIGHT_43_2026_05_02.md`
**Mitigation proposed:** Use exact staged hunks only. Before commit, inspect `git diff --cached -- agent_core/src/bridge.rs` and require it contains only `R15TrueRustCallbackLoopBenchmarkFFI` plus `run_r15_true_rust_callback_loop_benchmark`.

### A2 — Generated-binding regeneration can make the red test ambiguous [P1]

**Surface:** `build-agent-core.sh`, `build-rust/swift-bindings/agent_core.swift`, Swift benchmark test
**Attack:** A Swift test that references the new generated function only proves the binding exists if the build phase regenerated after the Rust export. If a stale generated binding is committed or hand-edited, the test could pass for the wrong reason.
**Evidence:** `build-agent-core.sh` regenerates `agent_core.swift` from the Rust dylib and then applies `patch-uniffi-bindings.py`.
**Mitigation proposed:** Do not hand-edit generated Swift. Run the focused test through Xcode so the build phase regenerates from Rust. Guard with grep in Rust source and generated binding only after build, and stage generated artifacts only if the repo already tracks the generated diff intentionally.

### A3 — Ledger closure must not weaken open MLX/render baselines [P2]

**Surface:** `EpistemosTests/Benchmarks/R15BenchmarkEvidenceLedgerTests.swift`
**Attack:** Moving the callback-loop filename from open to closed could accidentally change the expected count or remove the MLX/render open-baseline sentinels.
**Evidence:** `R15BenchmarkEvidenceLedger.forbiddenOpenBaselineFilenames` currently names MLX tok/s, renderer FPS, and true Rust callback-loop as open.
**Mitigation proposed:** Increase the closed expectation count by exactly one, remove only the true Rust callback-loop filename from forbidden-open, and preserve the MLX/render sentinels.

### A4 — Benchmark could measure Swift-side looping again [P2]

**Surface:** `EpistemosTests/Benchmarks/UniFFICallbackThroughputTests.swift`
**Attack:** The new runner can accidentally call generated `lift`/`lower` inside Swift again, reproducing PR5 rather than measuring a Rust loop.
**Evidence:** PR5 loops over `FfiConverterCallbackInterfaceAgentEventDelegate_lift(handle)` in Swift.
**Mitigation proposed:** Source guard must assert the PR10 runner calls `runR15TrueRustCallbackLoopBenchmark` and its metadata says `rust_loop_status == true_rust_to_swift_loop`.

## Brief verdict

The brief is usable after adding the mitigations above as hard post-merge guards. No P0 blocks code. P1s require exact staging and generated-binding discipline before commit.

CLAUDE-RETURN: role=RED-TEAM | slice=r15-true-rust-callback-loop-pr10 | round=43 | artifact=docs/fusion/fleet/r15-true-rust-callback-loop-pr10/claude-red-team/attacks.md | usefulness=+1 | p0=0 | p1=2
