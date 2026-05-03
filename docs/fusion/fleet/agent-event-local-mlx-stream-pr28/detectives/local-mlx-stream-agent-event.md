---
role: detective
slice: agent-event-local-mlx-stream-pr28
concept: LocalMLX direct stream AgentEvent provenance
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §8, §9
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/MLXInferenceService.swift:759
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/LocalBackendLLMClientTests.swift:701
deliberations_consulted:
  - docs/fusion/deliberation/agent_event_local_mlx_generate_pr27_deliberation_2026_05_03.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: true
  canon_says: "remaining broader runtime AgentEvent coverage"
  code_says: "[paraphrase] Direct LocalMLX stream has runtime-control-plane events but no AgentEvent recorder calls."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Engine/MLXInferenceService.swift
load_bearing_quote: "remaining broader runtime AgentEvent coverage"
verdict: open
usefulness: +1
usefulness_reason: Identifies a concrete uninstrumented sibling surface after PR27.
---

## Findings

- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` lists PR27 as closed, then names broader runtime AgentEvent coverage as the next safe lane.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7 keeps runtime provenance in scope but requires exact runtime files and focused tests.
- `MLXInferenceService.swift` direct stream constructs a `BackendGenerationRequest`, starts runtime-control-plane tracking, yields chunks, and finishes completed/failed/cancelled without AgentEvent calls.
- PR27 already added direct MLX generate tests and helper patterns; PR28 should reuse that policy rather than creating a parallel provenance dialect.

## Open questions

- None for implementation. Claude red-team may still attack the brief before code starts.

## Recommendation

Instrument only direct `LocalMLXClient.stream(...)` with requested, started, completed, failed, and cancelled AgentEvents using sanitized counts/metadata. Add focused success and failure tests that prove no prompt text, system prompt, steering JSON, streamed output, model id, artifact id, path, localized description, Hermes/MCP, browser/computer-use, LocalAuthentication, or ANE/private API content is persisted.
