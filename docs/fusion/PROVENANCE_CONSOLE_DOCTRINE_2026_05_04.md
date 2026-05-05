# Provenance Console Doctrine

Date: 2026-05-04
Track: T2 Provenance + Sovereign Gate
Status: Canonical doctrine and first implementation slice

## Purpose

The Provenance Console is the user-visible audit surface for the substrate's
durable trust history. It closes the MAS feature trio alongside the rich
`.epdoc` surface and local Companion Farm by making committed agent, graph,
mutation, and ClaimLedger retraction provenance visible without adding a second
owner of truth.

The console is a read-only projection. It may summarize, filter, and render
existing events, but it must not repair, replay, mutate, approve, deny, lease,
or mark work as projected.

## Four Planes

The console names and preserves the four-plane event hierarchy:

1. RunEventLog records durable runtime history.
2. MutationEnvelope records durable state and graph mutations.
3. AgentEvent projects agent, tool, hook, routing, and vault activity.
4. GraphEvent projects graph-affecting mutations for UI and render consumers.

Commit order remains canonical: receive runtime event, validate any
MutationEnvelope, commit durable state, then emit AgentEvent and GraphEvent
projections. The console observes only the committed result.

ClaimLedger `RetractionPropagated` is not a fifth write plane. It is the typed
subscriber event emitted by the provenance substrate when a retraction walk marks
claims at risk. The console may project it as a read-only trace so users can see
cascading truth failures without granting the UI mutation authority.

## GenUI Contract

The first UI contract is schema-first GenUI. Provenance Console payloads use
`GenUIPayload.provenanceTrace` and render through `GenUIDispatcher`; no per-pane
bespoke renderer may bypass the dispatcher. A missing or empty event plane must
render as an empty trace, not as a crash, blocking alert, or silent settings row.

## Read Boundary

The console may read:

- recent AgentEvent rows through a bounded chronological projection.
- recent GraphEvent rows through the existing bounded chronological projection.
- MutationEnvelope projection diagnostics from the outbox.
- ClaimLedger `RetractionPropagated` subscriber events through a bounded cursor.
- aggregate diagnostics for committed durable rows.

The console may not call save methods, claim leases, mark projections complete,
record failures, start timers, or run background repair loops.

## Privacy And Redaction

The console is local-first and MAS-compatible. It should show stable IDs,
event kinds, status, counts, tool names, and trace/run/mutation prefixes. It
should not expand full argument or result JSON by default. Full payload
inspection, when added, must remain local and explicit.

## MAS / Pro Separation

The Provenance Console is MAS-safe because it observes the same local database
and app-group trust spine used by the main app. Pro-only services may emit
events, but the console surface itself must not depend on Pro-only entitlements
or weaken MAS peer validation.

## Current Slice

The current implementation slice mounts a Settings detail pane that renders a
summary, RetractionPropagated trace, AgentEvent trace, GraphEvent trace, and
MutationEnvelope projection health through GenUIDispatcher. It intentionally
avoids repair actions until a separate Sovereign Gate doctrine defines explicit
approval requirements for operator-initiated replay or recovery.
