# AgentEvent MLX Image Generation PR23 Deliberation - 2026-05-03

## Slice

Card 7 AgentEvent Tool Provenance PR23 instruments the Swift
`MLXImageGenerationService.generate(prompt:aspectRatio:)` bridge path.

## Tier

Core-safe local Swift runtime provenance. No Hermes, FAL, subprocess, browser,
computer-use, private framework, biometric, Rust, generated binding, UI, graph,
or EventStore schema change.

## Gate

Add additive AgentEvent lifecycle rows around the existing attempt-and-explicit-
failure MLX image-generation scaffold: requested, started, and completed/failed.
Use run ids prefixed `mlx-image-generation-`, actor `mlx-image-generation-service`,
tool name `image_generate.mlx`, and metadata for `source=mlx_image_generation_service`,
`surface=image_generate`, `provider=mlx`, aspect ratio, prompt character count,
elapsed milliseconds, and closed failure class.

## Boundaries

Do not make image generation real in this slice. Do not change
`resolveFluxPipeline()`, FAL/cloud routing, Rust `image_generate`, tool catalogs,
Agent Command Center, UI cards, model registry, Flux package dependencies,
generated bindings, EventStore schema, GraphEvent, OpLog, Halo, Theater, or
SearchIndex.

## Privacy

Persist only bounded shape metadata. Do not persist prompt text, result envelope
body, image paths, model paths, stack traces, localized error prose, FAL hints,
provider credentials, or arbitrary error text.

## Tests

Write failing Swift Testing coverage first:

- successful call with injected pipeline records requested/started/completed
  without prompt text or image path.
- current unavailable pipeline records requested/started/failed with
  `failure_class=flux_pipeline_unavailable`.
- source guard proves no FAL/Hermes/subprocess/provider-routing/UI/Rust/schema
  changes and no prompt text/result body persistence.

## Canon anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §2
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §17
- `docs/architecture/PLAN_V2_UPDATED.md` §16

## Workcard match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7 - AgentEvent Tool Provenance
- Deviation: Adds PR23 as the next narrow runtime coverage gate after PR22; real image generation remains deferred.

## Failure-proof guardrails (post-merge)

- grep: `rg -n 'mlx-image-generation|image_generate\\.mlx|recordImageGenerationAgentEvent' Epistemos/Engine/MLXImageGenerationService.swift EpistemosTests`
- log: `/tmp/epistemos-agent-event-mlx-image-generation-pr23-green-20260503.log` contains `** TEST SUCCEEDED **`
- test: `MLXImageGenerationServiceTests`

## Fleet evidence packet

- `docs/fusion/fleet/agent-event-mlx-image-generation-pr23/aggregator.md`
- `docs/fusion/fleet/agent-event-mlx-image-generation-pr23/claude-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: Adds durable provenance to an agent-facing deferred image-generation bridge without changing runtime capability.
