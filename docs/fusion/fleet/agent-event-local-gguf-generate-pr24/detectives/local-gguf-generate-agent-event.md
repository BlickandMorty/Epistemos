---
role: detective
slice: agent-event-local-gguf-generate-pr24
concept: Local GGUF generate AgentEvent provenance
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §9
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalGGUFClient.swift:669
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentToolProvenanceRecorder.swift:26
  - /Users/jojo/Downloads/Epistemos/EpistemosTests/LocalGGUFClientTests.swift:76
deliberations_consulted:
  - docs/fusion/deliberation/agent_event_mlx_image_generation_pr23_deliberation_2026_05_03.md
quick_capture_consulted: n/a
worktrees_consulted:
  - main
drift:
  detected: false
  canon_says: "Local text generation: GGUF primary"
  code_says: "[paraphrase] LocalGGUFClient.generate resolves a GGUF request and calls the in-process runtime."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalGGUFClient.swift
load_bearing_quote: "Local text generation: GGUF primary"
verdict: open
usefulness: +1
usefulness_reason: Identifies the next clean local text-generation provenance gap after PR23.
---

## Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §9 names GGUF as the primary local text-generation lane.
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` keeps broader runtime AgentEvent coverage open beyond the already-closed PR1-PR23 surfaces.
- `LocalGGUFClient.generate(...)` at `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalGGUFClient.swift:669` resolves a local GGUF request, asks `BackendRuntimeControlPlane` for a local launch, then calls `runtime.generate(request:)`.
- Existing tests in `/Users/jojo/Downloads/Epistemos/EpistemosTests/LocalGGUFClientTests.swift:76` already exercise generated output and profile publication, making a focused AgentEvent test feasible without a real model.

## Open Questions

- None for this slice. Streaming GGUF should remain a follow-up PR because it has cancellation and token-loop semantics.

## Recommendation

Instrument only non-streaming `LocalGGUFClient.generate(...)` with requested, started, and completed/failed AgentEvents. Persist bounded metadata and counts, not prompt/system text, steering hints, generated output, model URLs, artifact IDs, paths, or arbitrary error strings.
