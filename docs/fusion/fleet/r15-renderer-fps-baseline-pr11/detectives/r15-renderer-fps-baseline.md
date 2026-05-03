---
role: detective
slice: r15-renderer-fps-baseline-pr11
concept: R15 live renderer FPS baseline
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §10
tier: Both
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/FUSED_IMPLEMENTATION_QUEUE_2026_04_30.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/r15_graph_ffi_bridge_baseline_pr7_deliberation_2026_05_02.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/Benchmarks/GraphFFIBenchmarkTests.swift
  - /Users/jojo/Downloads/Epistemos/Epistemos/Graph/GraphEngine.swift:132
deliberations_consulted:
  - docs/fusion/deliberation/r15_graph_ffi_bridge_baseline_pr7_deliberation_2026_05_02.md
  - docs/fusion/deliberation/r15_benchmark_evidence_ledger_pr9_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted:
  - none
drift:
  detected: false
  canon_says: "Measure before optimizing."
  code_says: "[paraphrase] GraphFFIBenchmarkTests already creates a live GraphEngine fixture but does not call render."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/EpistemosTests/Benchmarks/GraphFFIBenchmarkTests.swift
load_bearing_quote: "Measure before optimizing."
verdict: open
usefulness: +1
usefulness_reason: Identifies the next code-safe R15 gap without authorizing production renderer edits.
---

## Findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §10 marks graph renderer and graph-engine source as high-risk/protected, so this slice must stay in tests/docs.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 3 explicitly keeps live renderer FPS open after PR7/PR10.
- `r15_graph_ffi_bridge_baseline_pr7_deliberation_2026_05_02.md` proves the test harness can create a real `GraphEngine`/`CAMetalLayer` fixture but deliberately records `render_status=not_live_render_frame_rate`.
- `GraphEngine.swift` exposes `render(width:height:)`, the narrow Swift wrapper around `graph_engine_render`, which is sufficient for a test-owned frame-rate baseline.

## Open questions
- The focused test can measure an offscreen `CAMetalLayer` drawable path, but it is not a five-minute manual thermal soak.

## Recommendation
Approve PR11 as a test-only live renderer frame-rate harness that calls `GraphEngine.render(width:height:)`, writes the reserved R15 renderer JSON artifact when explicitly enabled, and updates the ledger only with honest metadata that still says this is not a five-minute manual thermal soak.
