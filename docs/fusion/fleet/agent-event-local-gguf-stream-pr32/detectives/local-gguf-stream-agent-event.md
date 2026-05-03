---
role: detective
slice: agent-event-local-gguf-stream-pr32
concept: LocalGGUF direct stream AgentEvent provenance
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §9
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalGGUFClient.swift:764
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/LocalGGUFClientTests.swift:166
deliberations_consulted:
  - docs/fusion/deliberation/agent_event_local_gguf_generate_pr24_deliberation_2026_05_03.md
  - docs/fusion/deliberation/agent_event_local_backend_stream_pr25_deliberation_2026_05_03.md
  - docs/fusion/deliberation/agent_event_local_mlx_stream_pr28_deliberation_2026_05_03.md
quick_capture_consulted: n/a
worktrees_consulted:
  - none
drift:
  detected: true
  canon_says: "remaining broader runtime AgentEvent coverage"
  code_says: "[paraphrase] LocalGGUFClient.stream delegates GGUF runtime chunks without AgentEvent records."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalGGUFClient.swift
load_bearing_quote: "Future CloudLLM paths beyond generate/stream/structured output"
verdict: open
usefulness: +1
usefulness_reason: Identifies one clean, exact, non-UI AgentEvent seam left after PR29/PR31.
---

## Findings
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:1221` keeps broader runtime AgentEvent coverage open after PR29 and Runtime Contract PR30.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:1170` allows future runtime instrumentation only after a new gate names exact files and tests.
- `LocalGGUFClient.swift:764` exposes the direct GGUF stream path; it resolves a request, opens the runtime-control-plane stream, yields chunks, and finishes completed/failed/cancelled.
- `LocalGGUFClient.swift:1035` already has a sanitized generate provenance pattern that can be mirrored without changing model loading, routing, or runtime-control-plane behavior.
- `LocalGGUFClientTests.swift:166` already proves generate AgentEvent sanitization and provides local sink/test helpers.

## Open questions
- None for this slice. The only acceptable write set is `LocalGGUFClient.swift`, `LocalGGUFClientTests.swift`, and round docs.

## Recommendation
Instrument only `LocalGGUFClient.stream(...)` with requested, started, completed, failed, and cancelled AgentEvents. Persist bounded metadata and counts, not prompt text, system prompt, steering hint JSON, streamed output, model id, artifact id, filesystem paths, localized descriptions, arbitrary errors, Hermes/MCP, browser/computer-use, LocalAuthentication, or ANE/private API details.
