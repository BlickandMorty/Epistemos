---
role: aggregator
source_fleet: codex-own
slice: local-agent-reflex-detector-eof-flush-completion-pr31
date: 2026-05-03
detectives_consumed:
  - detectives/local-agent-reflex-eof-detector.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - none
conflicts:
  - id: C1
    sources: [UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md, HEAD detector source]
    resolution: current-state closure is correct only after committing the working-tree detector method and tests
drift_signals:
  - HEAD LocalAgentLoop calls flushOnStreamEnd but HEAD IncrementalToolCallDetector lacks it; working tree closes the seam.
tier: Core
sovereign_gate_touchpoint: none
killer_feature_dependency:
  resonance_gate: false
  sovereign_gate: false
  freeform_pulse: false
  residency_rail: false
  unclosed_core_blocker: none
ready_for_pipeline_builder: true
missing_artifacts:
  - none
input_usefulness_rollup:
  plus_one: 1
  zero: 0
  minus_one: 0
usefulness: +1
usefulness_reason: promotes a branch/canon drift signal into a narrow verified completion slice
---

## Reconciled Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §8` makes the local-stream truncation fix a preservation watch, not optional cleanup.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` says the LocalAgent EOF flush is closed; the committed branch is only coherent when `IncrementalToolCallDetector.flushOnStreamEnd()` also lands.
- The implementation must preserve privacy: safe plaintext tag-prefixes flush at EOF, but unterminated hidden scratchpad or malformed tool-call buffers do not become visible text.
- No web validation is required because this is pure local Swift streaming behavior with no external API, OS, model-card, or package-version dependency.

## Recommended Slice Shape

Approve a narrow Core completion slice that commits `IncrementalToolCallDetector.flushOnStreamEnd()` plus focused detector tests. Re-run the focused detector and LocalAgentLoop suites, then commit only these two code/test files plus the slice evidence docs.

## Failure-Proof Guardrails

- grep: `rg -n "flushOnStreamEnd|Drops unterminated hidden and tool buffers at stream end|reflex mode flushes trailing tag-prefix plaintext" Epistemos/LocalAgent EpistemosTests`
- log: `TEST SUCCEEDED`
- test: `IncrementalToolCallDetectorTests`
