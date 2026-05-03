# agent-event-local-runtime-recorder-mount-pr26 Deliberation - 2026-05-03

## Scope

Tier: Core

Mount the existing AgentEvent provenance recorder into the live local runtime
client construction path so PR24 `LocalGGUFClient.generate(...)` and PR25
`LocalBackendLLMClient.stream(...)` become reachable in normal app boot.

## Allowed Files

- `Epistemos/App/AppBootstrap.swift`
- `EpistemosTests/LocalBackendLLMClientTests.swift`
- `docs/fusion/fleet/agent-event-local-runtime-recorder-mount-pr26/**`
- `docs/fusion/oversight/PREFLIGHT_58_2026_05_03.md`
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
- `Epistemos/Models/MutationEnvelope.swift`
- `Epistemos.xcodeproj/**`
- Generated bindings, entitlements, Hermes/MCP, LocalAuthentication, ANE/private API, OpLog workers.

## Implementation Order

1. Add a failing source-guard test proving `AppBootstrap` mounts one shared
   local runtime `AgentToolProvenanceRecorder`.
2. In `AppBootstrap`, construct `let localRuntimeAgentProvenanceRecorder =
   AgentToolProvenanceRecorder()` beside the local runtime clients.
3. Pass that recorder to `LocalGGUFClient(agentProvenanceRecorder:)`.
4. Pass the same recorder to `LocalBackendLLMClient(agentProvenanceRecorder:)`.
5. Run the focused `LocalBackendLLMClientTests` test.

## Acceptance

- `AppBootstrap` contains exactly one local runtime recorder variable for this mount.
- `LocalGGUFClient` receives that recorder.
- `LocalBackendLLMClient` receives that recorder.
- The slice does not instrument `LocalBackendLLMClient.generate(...)`, claim MLX text-generation provenance, change local routing, change EventStore schema, or touch graph/Rust/Hermes/MCP/Sovereign/ANE surfaces.

## Canon anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md §2`
- `MASTER_RESEARCH_INDEX_2026_05_02.md §8`
- `MASTER_RESEARCH_INDEX_2026_05_02.md §22`

## Workcard match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7 - AgentEvent Tool Provenance
- Deviation: This is a mount/WRV follow-through for PR24/PR25 rather than a new AgentEvent source.

## Failure-proof guardrails (post-merge)

- grep: `let localRuntimeAgentProvenanceRecorder = AgentToolProvenanceRecorder()`
- log: `✔ Test "bootstrap mounts local runtime AgentEvent recorder" passed`
- test: `LocalBackendLLMClientTests/bootstrapMountsLocalRuntimeAgentEventRecorder`

## Fleet evidence packet

- `docs/fusion/fleet/agent-event-local-runtime-recorder-mount-pr26/aggregator.md`
- `docs/fusion/fleet/agent-event-local-runtime-recorder-mount-pr26/claude-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: Makes closed local runtime AgentEvent instrumentation live in the app boot path.
