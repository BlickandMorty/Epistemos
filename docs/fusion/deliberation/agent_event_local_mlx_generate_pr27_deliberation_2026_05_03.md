# agent-event-local-mlx-generate-pr27 Deliberation - 2026-05-03

## Scope

Tier: Core

Record bounded AgentEvents around direct `LocalMLXClient.generate(...)` calls so MLX fallback/direct-generation paths no longer sit outside the provenance spine.

## Allowed Files

- `Epistemos/Engine/MLXInferenceService.swift`
- `Epistemos/App/AppBootstrap.swift`
- `EpistemosTests/LocalBackendLLMClientTests.swift`
- `docs/fusion/fleet/agent-event-local-mlx-generate-pr27/**`
- `docs/fusion/oversight/PREFLIGHT_59_2026_05_03.md`
- `docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/fleet/REGISTRY.md`

## Forbidden Files

- `Epistemos/Views/**`
- `Epistemos/Graph/**`
- `graph-engine/**`
- `agent_core/**`
- `Epistemos/State/EventStore.swift`
- Generated bindings, entitlements, Hermes/MCP, LocalAuthentication, ANE/private API, OpLog workers, Xcode project files.

## Implementation Order

1. Add failing tests for sanitized successful and failed MLX generate AgentEvents.
2. Add optional `AgentToolProvenanceRecorder` injection to `LocalMLXClient`.
3. Pass the PR26 shared recorder into `LocalMLXClient` from `AppBootstrap`.
4. Record requested/started/completed/failed events around `LocalMLXClient.generate(...)`.
5. Run focused `LocalBackendLLMClientTests`.

## Acceptance

- Successful direct MLX generate emits requested, started, completed AgentEvents.
- Failed direct MLX generate emits requested, started, failed AgentEvents with bounded failure class.
- Persisted arguments/results/metadata include only counts, runtime/reasoning labels, success, elapsed time, and output character count.
- Persisted AgentEvent data excludes prompt text, system prompt text, steering hint JSON, generated output, model id, artifact id, image URLs, filesystem paths, localized descriptions, arbitrary error text, Hermes/MCP/subprocess details, browser/computer-use surfaces, LocalAuthentication, and ANE/private API details.
- No stream instrumentation, routing changes, model loading changes, EventStore schema changes, UI, graph, Rust, generated binding, or project changes.

## Canon anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md §2`
- `MASTER_RESEARCH_INDEX_2026_05_02.md §9`
- `MASTER_RESEARCH_INDEX_2026_05_02.md §22`

## Workcard match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7 - AgentEvent Tool Provenance
- Deviation: This is the MLX text generate runtime source left explicitly unclaimed by PR26.

## Failure-proof guardrails (post-merge)

- grep: `toolName: "local_generate.mlx"`
- log: `✔ Test "local mlx generate records sanitized AgentEvents" passed`
- test: `LocalBackendLLMClientTests`

## Fleet evidence packet

- `docs/fusion/fleet/agent-event-local-mlx-generate-pr27/aggregator.md`
- `docs/fusion/fleet/agent-event-local-mlx-generate-pr27/claude-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: Closes direct MLX generate provenance without broadening the runtime surface.
