---
role: aggregator
source_fleet: codex-own
slice: agent-event-mlx-image-generation-pr23
date: 2026-05-03
detectives_consumed:
  - detectives/mlx-image-generation-agent-event.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - claude-side-fleet/selection.md
canon_gaps_opened:
  - none
conflicts:
  - id: C1
    sources: [claude-side-fleet/selection.md]
    resolution: Claude CLI was not logged in; ignore failed artifact and proceed with Codex local evidence.
drift_signals:
  - MLXImageGenerationService is an agent-facing image-generation bridge path without durable AgentEvent lifecycle rows.
tier: Core
sovereign_gate_touchpoint: none
killer_feature_dependency:
  resonance_gate: false
  sovereign_gate: false
  freeform_pulse: false
  residency_rail: false
  unclosed_core_blocker: none
ready_for_pipeline_builder: true
missing_artifacts: []
input_usefulness_rollup:
  plus_one: 1
  zero: 0
  minus_one: 1
usefulness: +1
usefulness_reason: Converts the MLX image-generation provenance gap into a bounded no-runtime-behavior-change slice.
---

## Reconciled findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §17 anchors image generation as deferred/hidden until the local runtime works.
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §2 anchors AgentEvent as part of the canonical provenance substrate.
- `MLXImageGenerationService.generate(prompt:aspectRatio:)` is narrow enough for additive provenance because it already owns the returned success/error envelope.
- Real image generation, FAL/cloud provider routing, Rust media tools, tool catalogs, and user-visible image cards are out of scope.

## Recommended slice shape
Instrument only `MLXImageGenerationService.generate(prompt:aspectRatio:)` with requested, started, and completed/failed AgentEvents. Keep current error-envelope behavior, do not wire Flux, do not change provider routing, and do not surface image generation.

## Failure-proof guardrails
- grep: `rg -n 'mlx-image-generation|image_generate\\.mlx|recordImageGenerationAgentEvent' Epistemos/Engine/MLXImageGenerationService.swift EpistemosTests`
- log: `/tmp/epistemos-agent-event-mlx-image-generation-pr23-green-20260503.log` contains `** TEST SUCCEEDED **`
- test: `MLXImageGenerationServiceTests`
