# Codex/Kimi Oversight Round 049 - 2026-05-01

## Slice

GraphEvent Durable Mapping PR1.

## Question

Can committed graph-affecting `MutationEnvelope`s persist deterministic durable
graph provenance rows transactionally in EventStore without touching graph UI,
graph engine, OpLog workers, AgentEvent live emission, Omega, hooks, protected
editor files, generated bindings, or project configuration?

## Kimi Audit

Raw audit log:

- `/tmp/epistemos-graph-event-pr1-kimi-audit-20260501-r1.log`

Kimi was asked for a read-only P0/P1 audit after Codex red/green verification.
The process produced no output and was terminated, so PR1 closed on Codex
red/green evidence and shell guardrails rather than Kimi approval.

## Codex Decision

Closed PR1 after focused red/green verification and guardrails.

Implemented:

- `DurableGraphEvent`, `DurableGraphEventKind`, and
  `DurableGraphEventRelation`.
- EventStore `graph_events` table with bounded save/load/list APIs.
- Deterministic mutation-id-plus-index event ids.
- Same-transaction graph-event emission for committed graph-affecting
  envelopes.
- Pending-envelope exclusion.

Not implemented in this round:

- Live graph, retrieval, Halo, Theater, or audit projections.
- Graph renderer/controller/editor integration.
- Rust graph engine, OpLog worker, AgentEvent, Omega, hook, generated binding,
  or project changes.

## Evidence

- Red:
  `/tmp/epistemos-graph-event-pr1-red-20260501.log`
- Green:
  `/tmp/epistemos-graph-event-pr1-green-20260501-r1.log`
- Result: `28` tests in `1` suite passed.
- Xcode reported `** TEST SUCCEEDED **`; inherited SwiftLint package-plugin
  noise for CodeEdit packages appeared after the success marker.

## Guardrails

- No graph renderer/controller/editor edit.
- No graph-engine or `agent_core` edit.
- No OpLog worker, Rust OpLog FFI, PipelineService, ChatCoordinator, Omega, or
  hook edit.
- No generated binding, generated library, project, entitlement, branch, stash,
  stage, or commit operation.
- The implementation model is named `DurableGraphEvent` to avoid colliding with
  the existing public FFI `GraphEvent` in `EventDrain.swift`.
- Broad branch diff still contains earlier dirty protected-path changes; PR1
  did not modify those surfaces.

## Next Recommended Gate

Pick exactly one:

- Live GraphEvent projection into graph/retrieval surfaces.
- OpLog incremental replay or ReplayBundle export hardening.
- Omega/hook/broader runtime AgentEvent provenance.
- R15 real benchmark baselines.

Do not reopen durable EventStore graph-event mapping unless a regression is
found.
