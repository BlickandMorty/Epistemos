---
role: detective
slice: r15-mlx-live-token-throughput-pr8-closure
concept: R15 live MLX token throughput closure
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §9
tier: Pro
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/r15_mlx_live_token_throughput_pr8_deliberation_2026_05_02.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/Benchmarks/MLXThermalBenchTests.swift:215
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/MLXInferenceService.swift:1621
deliberations_consulted:
  - docs/fusion/deliberation/r15_mlx_live_token_throughput_pr8_deliberation_2026_05_02.md
quick_capture_consulted: n/a
worktrees_consulted: []
drift:
  detected: false
  canon_says: "live MLX token throughput under sufficient-memory/thermal-soak conditions"
  code_says: "The opt-in harness still targets DeepSeek 7B and validates finite tokens_per_second."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/EpistemosTests/Benchmarks/MLXThermalBenchTests.swift
load_bearing_quote: "There is no PR8 tok/s JSON artifact yet"
verdict: blocked
usefulness: +1
usefulness_reason: Confirms the remaining R15 gate is still open but unsafe to run under current memory.
---

## Findings

- Current state still lists R15 live MLX token throughput as the remaining code-safe specialized baseline at `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:952` and `:969`.
- Workcard Card 3 keeps PR8 as blocked-run evidence only until a real JSON artifact exists at `AGENT_BUILD_WORKCARDS_2026_05_01.md:333`.
- The harness exists and is opt-in through `EPISTEMOS_RUN_LIVE_MLX_TOKEN_BENCHMARK` or `/tmp/epi-live-mlx-token-benchmark` at `MLXThermalBenchTests.swift:221`.
- The loader preflight blocks insufficient-memory runs before model load at `MLXInferenceService.swift:1621`.
- Round 49 memory preflight reported `available_gib_floor=4`, `required_gib=12`, `headroom_gib=6`, so the decision is `block`.

## Open questions

- None for code. The next successful PR8 closure needs a later sufficient-memory run or a deliberately smaller gated model slice.

## Recommendation

Do not run or edit live MLX inference code in this round. Keep the PR8 JSON filename out of the closed R15 evidence ledger, record the blocked preflight, and continue with the next non-manual code-safe slice.
