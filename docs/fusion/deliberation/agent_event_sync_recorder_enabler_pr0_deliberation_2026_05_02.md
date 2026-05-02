# AgentEvent Sync Recorder Enabler PR0 Brief - 2026-05-02

This deliberation mirrors `docs/fusion/fleet/agent-event-sync-recorder-enabler-pr0/brief.md`.

Slice:          Add a sync-safe AgentEvent recorder primitive so future nonisolated synchronous chokepoints can emit provenance without main-actor fire-and-forget.
Tier:           Core
Files touched:  `Epistemos/Engine/AgentToolProvenanceRecorder.swift`; `EpistemosTests/CognitiveSubstrateTests.swift`; Round 28 docs.
Protected paths: none
Gate:           SovereignGate touchpoint? none
Risks:          P1 construction drift; P1 accidental PR20 consumer instrumentation; P1 unprotected sequence state.
Verification:   focused Swift Testing plus forbidden-bridge and sync-fused-search greps.
Rollback:       Revert this slice only; no schema or consumer changes are allowed.
Stop triggers:  `Task`, `Task.detached`, `DispatchQueue.main.sync`, `MainActor.assumeIsolated`, EventStore schema edits, or `SearchIndexService.swift` edits.

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
