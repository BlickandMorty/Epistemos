# AgentEvent Local GGUF Generate PR24 Deliberation

Slice:          AgentEvent Local GGUF non-streaming generate provenance PR24
Tier:           Core
Files touched:
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalGGUFClient.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/LocalGGUFClientTests.swift`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/agent-event-local-gguf-generate-pr24/`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md`
Protected paths:
- no `Epistemos/Sovereign/` changes
- no UI, graph, Rust, generated bindings, EventStore schema, Hermes, MCP, subprocess, browser/computer-use, private ANE, entitlement, project-file, or model-loader rewrites
Gate:           SovereignGate touchpoint? none
Risks:          P1 if AgentEvents persist prompt/system/steering/output/model-path data; P1 if stream lifecycle is mixed into this PR; P0 if Core gains subprocess/Hermes/MCP/private-ANE symbols
Verification:   focused red/green Swift tests with logs under `/tmp/epistemos-agent-event-local-gguf-generate-pr24-*.log`; invariant grep; `git diff --check`
Rollback:       remove the recorder injection, lifecycle helper calls, tests, and PR24 doc rows
Stop triggers:
- implementation touches `LocalGGUFClient.stream(...)`
- implementation changes runtime routing, model preparation, BackendRuntimeControlPlane semantics, UI, graph, Rust, generated bindings, or EventStore schema
- persisted event data includes prompt text, system prompt text, steering hints JSON, generated output, model ID, model URL, artifact ID, filesystem path, localized descriptions, or arbitrary error text
- focused red test cannot fail before implementation

## Scope

This slice closes the next narrow local-runtime AgentEvent gap after PR23 by instrumenting only `LocalGGUFClient.generate(...)`. It does not touch streaming GGUF, model loading, prompt trimming semantics, runtime routing, or UI.

## Implementation Order

1. Add a focused failing test to `LocalGGUFClientTests` proving successful non-streaming GGUF generation records requested, started, and completed AgentEvents with sanitized arguments/results.
2. Add a focused failing test proving a backend failure records requested, started, and failed AgentEvents with a bounded failure class and no secret data.
3. Add optional `AgentToolProvenanceRecorder` injection to `LocalGGUFClient`.
4. Record `local-gguf-generate-...` run ids, per-client `local-gguf-generate:N` tool call ids, `local_generate.gguf` tool name, `local_gguf_client` actor/source metadata, bounded prompt/system/max-token/reasoning/runtime counts, elapsed milliseconds, output character count, and bounded failure classes.
5. Run focused tests, invariant grep, and `git diff --check`.

## Acceptance

- Success path emits `.toolCallRequested`, `.toolCallStarted`, `.toolCallCompleted`.
- Failure path emits `.toolCallRequested`, `.toolCallStarted`, `.toolCallFailed`.
- All events share a non-empty `local-gguf-generate-...` run id and `local-gguf-generate:N` tool call id.
- Actor is `local-gguf-client` and tool name is `local_generate.gguf`.
- Persisted arguments/results/errors exclude prompt text, system prompt text, steering hints JSON, generated output, model ID, model URL, artifact ID, filesystem paths, localized descriptions, and arbitrary backend error strings.
- The patch does not touch streaming, UI, graph, Rust, generated bindings, EventStore schema, Hermes, MCP, subprocess, browser/computer-use, private ANE, or model-loader behavior.

## Canon Anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §9
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` §Current closed spine / broader runtime AgentEvent coverage open
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7
- `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §2 substrate spine and §7 build-order graph

## Workcard Match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7 - AgentEvent Tool Provenance
- Deviation: none. This is a future broader-runtime live-emission gate named by exact runtime file and focused tests.

## Failure-Proof Guardrails (post-merge)

- grep: `rg -n "local_gguf_client|local_generate\\.gguf|local-gguf-generate" Epistemos/Engine/LocalGGUFClient.swift EpistemosTests/LocalGGUFClientTests.swift`
- log: `/tmp/epistemos-agent-event-local-gguf-generate-pr24-green-20260503.log` contains `** TEST SUCCEEDED **`
- test: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/LocalGGUFClientTests test`

## Fleet Evidence Packet

- `docs/fusion/fleet/agent-event-local-gguf-generate-pr24/detectives/local-gguf-generate-agent-event.md`
- `docs/fusion/fleet/agent-event-local-gguf-generate-pr24/aggregator.md`
- `docs/fusion/fleet/agent-event-local-gguf-generate-pr24/claude-red-team/attacks.md` (to be added after Red Team)

## Usefulness

usefulness: +1
usefulness_reason: Closes a real local text-generation provenance gap without widening into stream/runtime routing work.
