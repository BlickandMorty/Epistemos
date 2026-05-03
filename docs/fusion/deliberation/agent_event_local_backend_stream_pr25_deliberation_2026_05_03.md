# AgentEvent Local Backend Stream PR25 Deliberation - 2026-05-03

## Verdict
Approved for a narrow implementation after red-team review.

## Tier Classification
- Tier: All.
- Distribution: Core-safe local provenance. No Pro-only tools, browser/computer-use, subprocess inference, Hermes/MCP, external network, or Research/private APIs.

## Sovereign Gate Touchpoint
- None. No biometric, `LAContext`, approval modal, destructive action, delete/reset/disconnect, or authority mutation.

## Killer-Feature Dependency Check
- Resonance Gate: false.
- Sovereign Gate: false.
- Freeform Pulse: false.
- Residency Rail: false.
- Unclosed Core blocker: none.

## Proposed Change
Add optional `AgentToolProvenanceRecorder` injection to `LocalBackendLLMClient` and instrument only `stream(...)` with requested, started, completed, and failed AgentEvents. The events must use `local-backend-stream-...` run ids, `local-backend-stream:N` tool call ids, `local_backend.stream` tool name, `local-backend-llm-client` actor metadata, bounded runtime/reasoning/max-token/count metadata, and completed/failed result JSON with elapsed milliseconds plus chunk/output character counts where successful.

## Allowed Files
- `Epistemos/Engine/LocalBackendLLMClient.swift`
- `EpistemosTests/LocalBackendLLMClientTests.swift`
- `docs/fusion/fleet/agent-event-local-backend-stream-pr25/**`
- `docs/fusion/oversight/PREFLIGHT_57_2026_05_03.md`
- `docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/fleet/REGISTRY.md`

## Forbidden Files And Subsystems
- No EventStore schema changes.
- No generated UniFFI `AgentEvent` changes.
- No Rust, graph, OpLog, GraphEvent, Halo, Theater, SearchIndex, Hermes/MCP, browser/computer-use, cloud provider, Sovereign Gate, LocalAuthentication, ANE/private API, or UI changes.
- Do not instrument `generate(...)` in this slice because PR24 already instruments non-streaming GGUF generation below this router.

## Acceptance
- Focused Swift Testing suite first fails on missing stream AgentEvent support.
- Green suite proves successful stream records requested/started/completed events.
- Green suite proves failed stream records requested/started/failed events with bounded failure class.
- Tests prove persisted events exclude prompt text, system prompts, steering hints JSON, streamed output, model ids, artifact ids, arbitrary error strings, and filesystem paths.
- Existing stream routing behavior remains unchanged.

## Canon Anchors
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §2
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §8
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §9
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` AgentEvent PR24 / next-best build-card section

## Workcard Match
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7 - AgentEvent Tool Provenance.
- Deviation: none. This is a follow-on PR25 runtime surface using the existing Card 7 pattern.

## Failure-Proof Guardrails (post-merge)
- grep: `rg -n 'local_backend\\.stream|local-backend-stream-|agentProvenanceRecorder' Epistemos/Engine/LocalBackendLLMClient.swift EpistemosTests/LocalBackendLLMClientTests.swift`
- log: `** TEST SUCCEEDED **` in `/tmp/epistemos-agent-event-local-backend-stream-pr25-green-20260503.log`
- test: `Local Backend LLM Client`

## Fleet Evidence Packet
- `docs/fusion/fleet/agent-event-local-backend-stream-pr25/aggregator.md`
- `docs/fusion/fleet/agent-event-local-backend-stream-pr25/claude-red-team/attacks.md`

## Usefulness
usefulness: +1
usefulness_reason: Converts the PR24 "not streaming" gap into a concrete PR25 with bounded tests and no architecture drift.
