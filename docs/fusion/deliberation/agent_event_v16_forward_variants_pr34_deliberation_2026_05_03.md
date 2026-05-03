# agent-event-v16-forward-variants-pr34 deliberation - 2026-05-03

Slice:          AgentEvent v1.6 forward vocabulary seed
Tier:           Pro
Files touched:
- `Epistemos/Models/AgentProvenanceEvent.swift`
- `EpistemosTests/AgentEventV16ForwardVariantTests.swift`
- Round 70 fleet, registry, current-state, workcard, preflight, and guard docs
Protected paths: simulation worktree, `agent_core`, generated UniFFI bindings,
`AgentStreamEvent`, UI, graph, OpLog, Hermes/MCP, Sovereign, ANE/private APIs
Gate:           SovereignGate touchpoint? none
Risks:          P1 if this is described as live steering/summarizer/multi-vault behavior; P1 if emitters or UI are added; P2 if future Rust enum work assumes this Swift vocabulary is enough for the Pro runtime.
Verification:   focused Swift Testing suite plus source greps; logs under `/tmp/epistemos-agent-event-v16-forward-variants-pr34-green-20260503.log`
Rollback:       remove the six enum cases and the focused test file; no schema migration or runtime surface is involved.
Stop triggers:
- Any patch edits `agent_core`, simulation worktree files, generated bindings,
  `Epistemos/Bridge/StreamingDelegate.swift`, UI, graph, OpLog, or EventStore
  schema.
- Any patch emits these events from a runtime path or claims steering, helper
  summaries, vault creation/archive, or dispatch panel behavior is live.
- Any patch persists user messages, summary text, vault paths, or arbitrary
  error text in AgentEvent metadata.

## Intent

Close the smallest useful part of H6: make the durable Swift provenance
vocabulary aware of the six simulation v1.6 forward event kinds, while keeping
all live Pro dispatch/multi-vault runtime work deferred behind a future gate.

## Canon Anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md §0 H6`
- `MASTER_RESEARCH_INDEX_2026_05_02.md §11`
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` provenance spine status
- `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7

## Workcard Match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7, forward-vocabulary
  continuation after PR33.
- Deviation: This is not a live-emission PR. It intentionally implements only
  durable vocabulary and persistence compatibility because main has no live
  simulation `AgentEvent` enum to patch.

## Acceptance

- `AgentProvenanceEventKind` contains the six lower-snake-case v1.6 forward
  raw values: `steer_requested`, `summary_started`, `summary_delta`,
  `summary_completed`, `vault_created`, and `vault_archived`.
- Codable round-trip succeeds for each new kind.
- EventStore can persist and reload each new kind as a tool-less forward-only
  AgentEvent.
- Tests label persisted rows with `status=forward_variant_only`.
- No emitters, UI, Rust enum, stream-event, generated binding, GraphEvent,
  OpLog, Hermes/MCP, biometric, or ANE/private API surface changes.

## Failure-Proof Guardrails (post-merge)

- grep: `rg -n 'steerRequested|summaryStarted|summaryDelta|summaryCompleted|vaultCreated|vaultArchived' Epistemos/Models/AgentProvenanceEvent.swift`
- grep: `rg -n 'forward_variant_only' EpistemosTests/AgentEventV16ForwardVariantTests.swift`
- log: `Test Suite 'Selected tests' passed`
- test: `EpistemosTests/AgentEventV16ForwardVariantTests`

## Fleet Evidence Packet

- `docs/fusion/fleet/agent-event-v16-forward-variants-pr34/aggregator.md`
- `docs/fusion/fleet/agent-event-v16-forward-variants-pr34/claude-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: Converts the H6 canon correction into a safe durable-vocabulary seed while preserving all live Pro behavior for future gates.
