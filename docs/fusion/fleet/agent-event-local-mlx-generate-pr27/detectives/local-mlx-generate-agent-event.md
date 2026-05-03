---
role: detective
slice: agent-event-local-mlx-generate-pr27
concept: Local MLX generate AgentEvent provenance
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §9
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/MLXInferenceService.swift:513
  - /Users/jojo/Downloads/Epistemos/Epistemos/App/AppBootstrap.swift:1344
  - /Users/jojo/Downloads/Epistemos/Epistemos/LocalAgent/LocalAgentLoop.swift:133
deliberations_consulted:
  - docs/fusion/deliberation/agent_event_local_runtime_recorder_mount_pr26_deliberation_2026_05_03.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: true
  canon_says: "Add remaining broader runtime AgentEvent coverage"
  code_says: "[paraphrase] LocalMLXClient.generate has no AgentToolProvenanceRecorder injection or AgentEvent recording."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Engine/MLXInferenceService.swift
load_bearing_quote: "Local Model / MLX Inference"
verdict: open
usefulness: +1
usefulness_reason: Identifies direct MLX generate as the next narrow runtime provenance gap after PR26.
---

## Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §9` anchors MLX/GGUF as the local model lane; PR27 belongs in runtime provenance, not UI.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` closes PR24/PR25/PR26 while explicitly avoiding any MLX text-generation claim.
- `Epistemos/Engine/MLXInferenceService.swift:513` defines `LocalMLXClient`; its `generate(...)` method routes through the runtime control plane but records no AgentEvent.
- `Epistemos/App/AppBootstrap.swift:1344` constructs `LocalMLXClient`; PR26's shared recorder can be passed into that constructor without a second recorder.
- `Epistemos/LocalAgent/LocalAgentLoop.swift:133` and iMessage/device direct paths can call local MLX generate directly, so router-only provenance is incomplete.

## Open questions

- Stream provenance should remain a future PR28 because direct stream instrumentation is a separate async lifecycle.

## Recommendation

Add optional recorder injection to `LocalMLXClient`, mount the existing shared local runtime recorder from `AppBootstrap`, and record requested/started/completed/failed AgentEvents around `LocalMLXClient.generate(...)` only.
