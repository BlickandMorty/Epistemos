# AgentEvent Sync Recorder Enabler PR0 Brief - 2026-05-02

Slice:          Add a sync-safe AgentEvent recorder primitive so future nonisolated synchronous chokepoints can emit provenance without main-actor fire-and-forget.
Tier:           Core
Files touched:
- `Epistemos/Engine/AgentToolProvenanceRecorder.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- `docs/fusion/fleet/agent-event-sync-recorder-enabler-pr0/**`
- `docs/fusion/deliberation/agent_event_sync_recorder_enabler_pr0_deliberation_2026_05_02.md`
- `docs/fusion/oversight/POST_MERGE_GUARDS_2026_05_02.md`
Protected paths: none
Gate:           SovereignGate touchpoint? none
Risks:          P1 if event construction diverges from the existing recorder; P1 if the enabler sneaks PR20 consumer instrumentation into this slice; P1 if sequence state is not lock-protected.
Verification:   focused Swift Testing log at `/tmp/epistemos-agent-event-sync-recorder-enabler-pr0-green-20260502.log`; source greps for forbidden main-actor bridging and sync fused-search noninstrumentation.
Rollback:       Revert this slice's recorder/test/docs changes; no schema or consumer changes are allowed.
Stop triggers:
- Any edit to `Epistemos/Sync/SearchIndexService.swift` beyond source-guard-only tests.
- Any use of `Task`, `Task.detached`, `DispatchQueue.main.sync`, or `MainActor.assumeIsolated` in the recorder enabler.
- Any EventStore schema change.
- Any Pro/Research, Hermes, MCP, graph, editor, Rust, generated-binding, or UI touch.

## Scope
Implement only the additive sync-safe recorder primitive. Do not instrument `SearchIndexService.fusedSearch(...)` yet. This PR0 exists so PR20 has a proven primitive instead of an unsafe main-actor bridge.

## Acceptance
- `AgentToolProvenanceRecorder` keeps its existing API and behavior.
- New `AgentToolProvenanceSyncRecorder` can be called from a synchronous context and returns the actual persistence result.
- Sync recorder preserves per-run sequence ordering.
- Sync recorder persists lower-snake-case `AgentProvenanceEvent` JSON through `EventStore.saveAgentEvent(_:)`.
- Source guard proves the recorder file contains no `DispatchQueue.main.sync`, `MainActor.assumeIsolated`, `Task.detached`, or `Task {`.
- Source guard proves `SearchIndexService.fusedSearch(...)` remains uninstrumented in this slice.

## KIMI ORDER - ROUND 28
Scope:
Add the sync-safe AgentEvent recorder enabler only.

Tier:
Core

Allowed files/subsystems:
- `Epistemos/Engine/AgentToolProvenanceRecorder.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- Round 28 docs and guard files under `docs/fusion/`

Forbidden files/subsystems:
- `Epistemos/Sync/SearchIndexService.swift`
- `EventStore` schema changes
- Graph/editor/Rust/generated bindings/UI/provider routing/Omega/Hermes/MCP
- Any main-actor bridging hack: `Task`, `Task.detached`, `DispatchQueue.main.sync`, `MainActor.assumeIsolated`

Task:
1. Write failing tests for a sync-safe recorder sibling.
2. Extract shared event construction so the existing main-actor recorder and new sync recorder do not duplicate payload semantics.
3. Add `AgentToolProvenanceSyncRecorder` with lock-protected sequence state and a synchronous persist closure.
4. Run focused Swift tests and source greps.

Evidence:
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §2 and §22.1.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7.
- `docs/fusion/fleet/search-index-service-fused-sync-agent-event-pr20/codex-red-team/attacks.md`.
- `docs/fusion/fleet/agent-event-sync-recorder-enabler-pr0/aggregator.md`.

Acceptance:
- Focused tests pass.
- No forbidden main-actor bridging in recorder file.
- No sync fused-search consumer instrumentation in this slice.

Tests/commands:
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EventStoreSchemaTests test`
- `rg -n 'DispatchQueue\\.main\\.sync|MainActor\\.assumeIsolated|Task\\.detached|Task \\{' Epistemos/Engine/AgentToolProvenanceRecorder.swift`
- `git grep -n -A 35 "nonisolated public func fusedSearch(" Epistemos/Sync/SearchIndexService.swift | grep -E "(agentProvenanceRecorder|recordToolEvent)"` must return empty.

Sovereign Gate touchpoint:
- none

## Canon Anchors
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §2
- `MASTER_RESEARCH_INDEX_2026_05_02.md` §22.1

## Workcard Match
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7 - AgentEvent Live Tool Provenance
- Deviation: PR20 is blocked, so this PR0 enabler is the smallest safe prerequisite.

## Failure-Proof Guardrails (post-merge)
- grep: `final class AgentToolProvenanceSyncRecorder`
- grep: `private let sequenceLock = NSLock()`
- forbidden grep: `rg -n 'DispatchQueue\\.main\\.sync|MainActor\\.assumeIsolated|Task\\.detached|Task \\{' Epistemos/Engine/AgentToolProvenanceRecorder.swift`
- forbidden sync grep: `git grep -n -A 35 "nonisolated public func fusedSearch(" Epistemos/Sync/SearchIndexService.swift | grep -E "(agentProvenanceRecorder|recordToolEvent)"` returns empty
- log: `Test run with`
- test: `Agent tool provenance sync recorder persists ordered lifecycle events`

## Fleet Evidence Packet
- `docs/fusion/fleet/agent-event-sync-recorder-enabler-pr0/aggregator.md`
- `docs/fusion/fleet/agent-event-sync-recorder-enabler-pr0/claude-red-team/attacks.md`

## Usefulness
usefulness: +1
usefulness_reason: Unblocks a recurring AgentEvent architecture constraint while keeping PR20 consumer instrumentation separate.
