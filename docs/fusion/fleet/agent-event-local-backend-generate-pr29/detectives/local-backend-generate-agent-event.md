---
role: detective
slice: agent-event-local-backend-generate-pr29
concept: LocalBackend direct generate AgentEvent provenance
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §8, §9
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalBackendLLMClient.swift:89
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalBackendLLMClient.swift:163
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalBackendLLMClient.swift:465
deliberations_consulted:
  - docs/fusion/deliberation/agent_event_local_backend_stream_pr25_deliberation_2026_05_03.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: true
  canon_says: "does not instrument `LocalBackendLLMClient.generate(...)`"
  code_says: "[paraphrase] generate routes to GGUF/MLX clients without router-level AgentEvent calls"
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:422
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalBackendLLMClient.swift:89
load_bearing_quote: "does not instrument `LocalBackendLLMClient.generate(...)`"
verdict: open
usefulness: +1
usefulness_reason: Opens the exact next bounded provenance gap after PR28.
---

## Findings

- `LocalBackendLLMClient.generate(...)` resolves runtime and delegates directly to `ggufClient.generate` or `mlxClient.generate`; no router-level `recordToolEvent` call appears in the generate path.
- The stream sibling already has the desired lifecycle shape: requested, started, terminal success/failure, sanitized arguments/result JSON, and bounded failure classes.
- PR26 deliberately live-mounted the recorder while excluding `LocalBackendLLMClient.generate(...)`, so this slice can use the existing recorder without touching `AppBootstrap`.
- The lower runtime clients already record their own direct generate provenance. This slice should add router-level LocalBackend provenance, not remove or suppress lower-runtime events.

## Open questions

- None. This is a local code/canon gap with no current external dependency.

## Recommendation

Implement a shared LocalBackend provenance context with separate generate/stream surfaces, then wrap `LocalBackendLLMClient.generate(...)` with requested/started/completed/failed AgentEvents. Preserve routing semantics and sanitize the same fields as PR25.
