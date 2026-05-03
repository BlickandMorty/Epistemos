---
role: detective
slice: agent-event-mlx-image-generation-pr23
concept: MLX image generation AgentEvent provenance
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §17
tier: Core
canonical_source: /Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2_UPDATED.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/architecture/CLAUDE_CANONICALIZATION_REDO_HANDOFF_2026_04_14.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Engine/MLXImageGenerationService.swift:64
deliberations_consulted:
  - docs/fusion/deliberation/agent_event_tool_provenance_pr1_deliberation_2026_05_01.md
quick_capture_consulted: false
worktrees_consulted:
  - none
drift:
  detected: true
  canon_says: "never silently rerouted to cloud"
  code_says: "[paraphrase] generate returns explicit mlx error envelope with fal opt-in hint, but emits no durable AgentEvent."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2_UPDATED.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Engine/MLXImageGenerationService.swift
load_bearing_quote: "hidden from normal user-visible catalogs until the local runtime lane actually works"
verdict: partial
usefulness: +1
usefulness_reason: Identifies a narrow agent-facing image-generation runtime path with no durable provenance yet.
---

## Findings
- `docs/architecture/PLAN_V2_UPDATED.md` keeps image generation deferred and explicit: local MLX first, hidden until real, no silent cloud reroute.
- `Epistemos/Engine/MLXImageGenerationService.swift` is an honest attempt-and-fail scaffold, not a fake success path.
- The Swift service names the Rust bridge context: `AgentEventDelegate::generate_image` can call this path, making it valid AgentEvent coverage.
- The safe instrumentation boundary is the public `generate(prompt:aspectRatio:)` method only. `resolveFluxPipeline()` must remain unchanged.

## Open questions
- None for this slice. Real Flux/MLX inference remains out of scope.

## Recommendation
Add bounded AgentEvents around `MLXImageGenerationService.generate(prompt:aspectRatio:)` only. Persist prompt length, aspect ratio, provider, elapsed time, and closed failure class; never persist prompt text, image paths, result envelope bodies, or error prose.
