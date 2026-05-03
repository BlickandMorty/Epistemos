---
role: detective
slice: phase7-nightbrain-trigger-provenance-pr36
concept: Phase7 NightBrain trigger AgentEvent provenance
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §4
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/Phase7Bridge.swift:45
  - /Users/jojo/Downloads/Epistemos/Epistemos/State/NightBrainService.swift:41
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentToolProvenanceRecorder.swift:26
deliberations_consulted:
  - none
quick_capture_consulted: false
worktrees_consulted:
  - none
drift:
  detected: false
  canon_says: "Layer 7 (NightBrain) runs overnight against accumulated Layer 6 trace."
  code_says: "[paraphrase] Phase7Bridge exposes explicit nightbrain_trigger job dispatch."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/Phase7Bridge.swift
load_bearing_quote: "Layer 7 (NightBrain) runs overnight against accumulated Layer 6 trace."
verdict: open
usefulness: +1
usefulness_reason: Identifies a live bridge surface lacking AgentEvent provenance and safe non-running failure-path tests.
---

## Findings
- `Phase7Bridge.triggerNightbrainJob(jobType:priority:)` is the live Swift bridge for the Rust-side `nightbrain_trigger` specialty.
- `NightBrainService.Job` is a bounded enum, so supported job names can be persisted safely as canonical raw values.
- Unsupported raw `jobType` and raw `priority` can contain arbitrary agent input and should not be persisted in AgentEvent arguments/results/errors.
- Existing `CognitiveSubstrateTests` only checked the alias map; no provenance tests existed.

## Open questions
- None for this slice; supported success-path execution remains covered structurally but not run in tests to avoid background job side effects.

## Recommendation
Add an injected recorder and bootstrap provider, emit requested/started/completed/failed AgentEvents with bounded metadata, reject unsupported jobs before bootstrap lookup, and test unsupported/bootstrap-unavailable paths without running NightBrain jobs.
