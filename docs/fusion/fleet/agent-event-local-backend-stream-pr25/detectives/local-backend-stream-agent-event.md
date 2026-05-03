---
role: detective
slice: agent-event-local-backend-stream-pr25
concept: Local backend stream AgentEvent provenance
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §8, §9
tier: All
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalBackendLLMClient.swift:161
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/LocalBackendLLMClientTests.swift:1
deliberations_consulted:
  - docs/fusion/deliberation/agent_event_local_gguf_generate_pr24_deliberation_2026_05_03.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: false
  canon_says: "remaining broader runtime AgentEvent coverage"
  code_says: "[paraphrase] LocalBackendLLMClient.stream delegates MLX/GGUF streams without AgentEvent recording."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalBackendLLMClient.swift
load_bearing_quote: "remaining broader runtime AgentEvent coverage"
verdict: open
usefulness: +1
usefulness_reason: Identifies the next narrow PR25 AgentEvent surface after PR24 explicitly avoided streaming.
---

## Findings
- `LocalBackendLLMClient.stream(...)` is the routing-layer stream seam for local MLX/GGUF generation and currently only resolves runtime, delegates tokens, and finishes/catches.
- PR24 intentionally instrumented only `LocalGGUFClient.generate(...)`; the current-state doc calls that out as "without touching streaming."
- Card 7 requires bounded AgentEvents with non-empty run id/tool call identity, sanitized metadata, and no prompt/output/model/path leakage.
- The correct scope is routing-layer stream lifecycle provenance only, not GGUF model loading, MLX decoding, runtime-control semantics, UI, graph, Hermes, MCP, ANE, or EventStore schema.

## Open questions
- None blocking. The slice can record requested/started/completed/failed events at the backend router and leave lower runtime stream implementation unchanged.

## Recommendation
Add optional `AgentToolProvenanceRecorder` injection to `LocalBackendLLMClient`, instrument `stream(...)` only, and prove success/failure paths persist sanitized metadata without prompt, system prompt, steering JSON, streamed text, model id, or filesystem path leakage.
