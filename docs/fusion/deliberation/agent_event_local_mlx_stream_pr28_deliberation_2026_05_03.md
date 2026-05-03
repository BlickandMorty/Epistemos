# AgentEvent LocalMLX Direct Stream PR28 Deliberation

Slice: `agent-event-local-mlx-stream-pr28`
Tier: Core
Decision: Approved for implementation after red-team pass.
Usefulness: +1 - closes the direct MLX stream sibling to PR27 without broadening runtime architecture.

## File Scope

Allowed source files:
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MLXInferenceService.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/LocalBackendLLMClientTests.swift`

Allowed docs:
- `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/agent-event-local-mlx-stream-pr28/`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/agent_event_local_mlx_stream_pr28_deliberation_2026_05_03.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/oversight/PREFLIGHT_60_2026_05_03.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/REGISTRY.md`

Forbidden:
- AppBootstrap remounting; PR27 already mounted the shared recorder.
- UI, graph, Rust, generated bindings, EventStore schema, Hermes/MCP, browser/computer-use, LocalAuthentication, ANE/private API, routing policy, model loading, runtime selection, and lower runtime semantics.

## Report Before Code

Current truth:
- PR25 instruments router-level `LocalBackendLLMClient.stream(...)`.
- PR27 instruments direct `LocalMLXClient.generate(...)`.
- Direct `LocalMLXClient.stream(...)` still emits runtime-control-plane lifecycle data but no durable AgentEvent provenance.

Implementation order:
- Add failing focused tests for successful and failed direct MLX stream AgentEvents.
- Instrument only `LocalMLXClient.stream(...)` plus shared direct-MLX provenance helpers.
- Reuse PR27's sanitization policy and bounded failure classes.
- Run focused `LocalBackendLLMClientTests`, then staged source/diff guards.

Acceptance:
- Direct stream records requested, started, and completed AgentEvents on success.
- Direct stream records requested, started, and failed AgentEvents on policy/runtime failure.
- Direct stream records requested, started, and a bounded cancelled AgentEvent when the task is cancelled or the consumer drops the stream.
- Tool identity is explicit: `toolName=local_stream.mlx`, `toolCallID=local-mlx-stream:N`, and `runID=local-mlx-stream-...`.
- Success result records `success=true`, elapsed milliseconds, `chunk_count` including zero, and output character count, never streamed text.
- Failure and cancellation results record `success=false`, elapsed milliseconds, bounded failure class, `chunk_count`, and output character count, with no localized/arbitrary error text.
- Tests prove no prompt text, system prompt, steering hint JSON, streamed output, model id, artifact id, file path, Hermes/MCP, browser/computer-use, LocalAuthentication, or ANE/private API detail enters persisted AgentEvents.

Non-goals:
- No routing change.
- No model loading change.
- No AppBootstrap remounting.
- No EventStore schema work.
- No UI, graph, Rust, generated bindings, Hermes/MCP, browser/computer-use, LocalAuthentication, or ANE/private API work.

## Canon anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md` §8
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §9
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` PR27 and remaining runtime AgentEvent coverage paragraphs
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7

## Workcard match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7 - AgentEvent Tool Provenance
- Deviation: none

## Failure-proof guardrails (post-merge)

- grep: `rg -n "local_stream\\.mlx|local-mlx-stream|surface.*stream" Epistemos/Engine/MLXInferenceService.swift EpistemosTests/LocalBackendLLMClientTests.swift`
- log: `Test run with 13 tests in 1 suite passed`
- test: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/LocalBackendLLMClientTests`

## Fleet evidence packet

- `docs/fusion/fleet/agent-event-local-mlx-stream-pr28/aggregator.md`
- `docs/fusion/fleet/agent-event-local-mlx-stream-pr28/claude-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: Gives the builder exact files, tests, sanitization requirements, and non-goals for PR28.
