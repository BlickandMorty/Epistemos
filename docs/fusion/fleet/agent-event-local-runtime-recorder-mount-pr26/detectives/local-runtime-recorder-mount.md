---
role: detective
slice: agent-event-local-runtime-recorder-mount-pr26
concept: Local runtime AgentEvent recorder mount
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §2, §8, §22
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/App/AppBootstrap.swift:1358
  - /Users/jojo/Downloads/Epistemos/Engine/LocalGGUFClient.swift:621
  - /Users/jojo/Downloads/Epistemos/Engine/LocalBackendLLMClient.swift:14
deliberations_consulted:
  - docs/fusion/deliberation/agent_event_local_gguf_generate_pr24_deliberation_2026_05_03.md
  - docs/fusion/deliberation/agent_event_local_backend_stream_pr25_deliberation_2026_05_03.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: true
  canon_says: "AgentEvent PR25 now instruments `LocalBackendLLMClient.stream(...)`"
  code_says: "[paraphrase] AppBootstrap does not pass a recorder into LocalBackendLLMClient or LocalGGUFClient."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/App/AppBootstrap.swift
load_bearing_quote: "PR25 LocalBackend stream provenance is also closed."
verdict: partial
usefulness: +1
usefulness_reason: Finds a live mount gap for already-closed PR24/PR25 instrumentation.
---

## Findings

- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:386` marks `LocalGGUFClient.generate(...)` instrumentation closed.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:400` marks `LocalBackendLLMClient.stream(...)` instrumentation closed.
- `LocalGGUFClient.swift:625` accepts `agentProvenanceRecorder`, and `LocalBackendLLMClient.swift:21` accepts the same injection point.
- `AppBootstrap.swift:1358` and `AppBootstrap.swift:1374` construct the live clients without passing a recorder, so the live app path does not yet benefit from PR24/PR25.

## Open questions

- None for this mount. MLX text-generation provenance remains unclaimed and should not be implied by this slice.

## Recommendation

Create one `AgentToolProvenanceRecorder` near the local runtime client construction in `AppBootstrap`, pass it to `LocalGGUFClient` and `LocalBackendLLMClient`, and add a source-guard test proving the mount remains present without adding EventStore schema, graph, Hermes/MCP, or lower runtime behavior changes.
