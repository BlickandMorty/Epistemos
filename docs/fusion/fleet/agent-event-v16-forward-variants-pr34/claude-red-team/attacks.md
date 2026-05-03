---
role: claude-red-team
slice: agent-event-v16-forward-variants-pr34
brief: docs/fusion/deliberation/agent_event_v16_forward_variants_pr34_deliberation_2026_05_03.md
date: 2026-05-03
attacks_total: 2
p0_attacks: 0
p1_attacks: 0
p2_attacks: 2
p3_attacks: 0
verdict: brief-approved
usefulness: +1
usefulness_reason: Narrows the slice to vocabulary-only and blocks accidental live-runtime claims.
---

## Attacks

### A1 - Forward vocabulary can be misread as live simulation runtime [P2]

**Surface:** Brief intent, acceptance, and current-state updates.
**Attack:** H6 names Pro dispatch and multi-vault concepts that are not live in
main. If the brief or docs say PR34 "implements v1.6 AgentEvents," future agents
may skip the actual Rust/stream/UI gates.
**Evidence:** `MASTER_RESEARCH_INDEX_2026_05_02.md §0 H6`; `docs/fusion/fleet/agent-event-v16-forward-variants-pr34/aggregator.md`
**Mitigation proposed:** Keep the wording "forward vocabulary seed" and
`forward_variant_only` everywhere. Do not add emitters, UI, Rust enum changes,
or runtime claims.

### A2 - Durable Swift provenance is not the generated UniFFI AgentEvent [P2]

**Surface:** `Epistemos/Models/AgentProvenanceEvent.swift`,
`epistemos-core/uniffi/epistemos_core.udl`, and
`Epistemos/Bridge/StreamingDelegate.swift`.
**Attack:** The app already has generated and streaming event surfaces named
AgentEvent. Patching the wrong surface would create drift or generated-binding
noise.
**Evidence:** `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7 naming warning.
**Mitigation proposed:** Touch only `AgentProvenanceEventKind` plus tests, and
guard no generated bindings or stream-event files are staged.

## Brief Verdict

Approved after the brief's vocabulary-only boundary is preserved. No P0/P1
attacks remain because the accepted slice avoids emitters, UI, Rust enum
changes, generated bindings, and EventStore schema changes.
