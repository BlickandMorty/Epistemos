# AgentEvent Variants v1.6 — Simulation Forward Bridge — 2026-05-04

Track: T6 Simulation Mode / T1 AgentEvent substrate / T2 provenance.

This document promotes the Simulation Mode v1.6 event additions into a compact
implementation bridge. It keeps the event spine explicit so Landing Farm,
Graph Live Theater, Notes Sidebar, Provenance Console, and future Rust
normalizers do not invent separate vocabularies.

## Canon Authority

Source:

- `docs/fusion/simulation/DOCTRINE.md` §3.4.5 and §11.
- `docs/fusion/simulation/IMPLEMENTATION.md` Slice S2.

Current main evidence:

- `Epistemos/Models/AgentProvenanceEvent.swift`
- `EpistemosTests/AgentEventV16ForwardVariantTests.swift`

## Six v1.6 Variants

| Canon variant | Swift provenance kind | Purpose |
|---|---|---|
| `SteerRequested` | `steer_requested` | Landing Farm dispatch input queues or interrupts a running session according to provider policy |
| `SummaryStarted` | `summary_started` | Helper-model summary request begins for a companion |
| `SummaryDelta` | `summary_delta` | Helper-model summary streams visible text |
| `SummaryCompleted` | `summary_completed` | Helper-model summary finishes with token accounting |
| `VaultCreated` | `vault_created` | Multi-vault UI creates a real persisted vault for model / agent / sub-agent |
| `VaultArchived` | `vault_archived` | Multi-vault UI archives an existing persisted vault |

These are forward variants in Swift provenance today. The full canonical Rust
`AgentEvent` enum remains a recovery target for `agent_core::events`.

## Honesty Semantics

- A dispatch panel row traces to a real `AgentEvent`.
- A helper summary line is itself an event stream:
  `SummaryStarted -> SummaryDelta -> SummaryCompleted`.
- If the helper model fails or times out, the UI shows an error/working state;
  it does not invent a summary.
- Vault events imply real disk/audit operations. The UI must not show a vault
  that does not exist on disk.
- Farm steering is queued into the next turn by default. Anthropic mid-turn
  interrupt is provider-specific; OpenAI, Kimi, Hermes, and local paths use
  queued behavior unless their provider brief says otherwise.

## Live State

Live Swift state already includes:

- `AgentProvenanceEventKind.steerRequested`
- `AgentProvenanceEventKind.summaryStarted`
- `AgentProvenanceEventKind.summaryDelta`
- `AgentProvenanceEventKind.summaryCompleted`
- `AgentProvenanceEventKind.vaultCreated`
- `AgentProvenanceEventKind.vaultArchived`

`EpistemosTests/AgentEventV16ForwardVariantTests.swift` verifies:

- the raw vocabulary includes all six strings;
- each kind round-trips through Codable;
- `EventStore` persists and reloads each variant;
- diagnostics see the latest forward variant.

## Remaining Gap

The Rust-owned canonical `AgentEvent` enum is not yet present as
`agent_core::events` in main. Current main has Swift provenance events and an
`AgentEventDelegate` callback surface, but not the complete Simulation v1.6
Rust event spine, provider normalizers, append-only session JSONL log, replay,
or hash-chain verification described in `IMPLEMENTATION.md` Slice S2.

Recovery rule: do not treat the Swift forward variants as the whole event
system. They are the compatibility vocabulary that keeps UI/provenance from
blocking while the Rust event spine lands.

## Next Implementation Slice

1. Add source guards that keep the six Swift variants present.
2. Introduce `agent_core::events` with the full §11 enum.
3. Normalize Hermes / Claude / OpenAI / Kimi / local streams into the enum.
4. Persist append-only per-session event logs with content-hash chain checks.
5. Replay event logs into deterministic SimulationState.
6. Project the same stream into Landing Farm, Graph Live Theater, Notes Sidebar,
   and Provenance Console.
