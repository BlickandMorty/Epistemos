---
role: detective
slice: bridge-no-double-count-source-guards-pr44
concept: Bridge no-double-count AgentEvent source guards
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §6
tier: Both
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/agent-event-runtime-coverage-map/AGENT_EVENT_RUNTIME_COVERAGE_MAP_PR42_DELTA_2026_05_03.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/agent-event-runtime-coverage-map/AGENT_EVENT_RUNTIME_COVERAGE_MAP_2026_05_03.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/PARALLEL_WORK_MANIFEST.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/StreamingDelegate.swift
  - /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/ChunkedMCPFraming.swift
  - /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/CoTStreamInterceptor.swift
  - /Users/jojo/Downloads/Epistemos/Epistemos/Bridge/ToolTierBridge.swift
deliberations_consulted:
  - n/a
quick_capture_consulted: n/a
worktrees_consulted:
  - none
drift:
  detected: false
  canon_says: "Adding rows here would double-count, flood the timeline, or race the Rust FFI."
  code_says: "[paraphrase] No direct AgentToolProvenanceRecorder, recordToolEvent, or AgentProvenanceEvent markers in the four files."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/fleet/agent-event-runtime-coverage-map/AGENT_EVENT_RUNTIME_COVERAGE_MAP_PR42_DELTA_2026_05_03.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Bridge
load_bearing_quote: "The next safe AgentEvent expansion lane is Omega runtime + LocalAgent, not Bridge."
verdict: closed
usefulness: +1
usefulness_reason: Turns a completed-Bridge canon rule into an executable source guard.
---

## Findings

- `AGENT_EVENT_RUNTIME_COVERAGE_MAP_PR42_DELTA_2026_05_03.md` §3.2 marks Bridge high-payload-risk coverage complete after PR43.
- `AGENT_EVENT_RUNTIME_COVERAGE_MAP_PR42_DELTA_2026_05_03.md` §4 explicitly skips `ChunkedMCPFraming`, `CoTStreamInterceptor`, `StreamingDelegate`, and `ToolTierBridge`.
- Code grep found no direct `AgentToolProvenanceRecorder`, `recordToolEvent`, or `AgentProvenanceEvent` markers in those four files.
- `PARALLEL_WORK_MANIFEST.md` round-82 P5 names a source-guard test as the safe next safety-net slice.

## Open questions

- None for this slice. Future AgentEvent expansion should inventory Omega and LocalAgent separately.

## Recommendation

Add one Swift Testing source-guard suite that reads the four no-instrument bridge files through `loadMirroredSourceTextFile` and fails if direct AgentEvent recording is introduced there.
