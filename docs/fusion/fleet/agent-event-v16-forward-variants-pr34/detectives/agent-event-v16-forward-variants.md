---
role: detective
slice: agent-event-v16-forward-variants-pr34
concept: AgentEvent v1.6 forward variants
index_anchor: MASTER_RESEARCH_INDEX_2026_05_02.md §0 H6 and §11
tier: Pro
canonical_source: /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
sister_sources:
  - /Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
  - /Users/jojo/Downloads/Epistemos/.claude/worktrees/simulation/docs/simulation-mode/DOCTRINE.md
code_anchors:
  - /Users/jojo/Downloads/Epistemos/Epistemos/Models/AgentProvenanceEvent.swift:3
  - /Users/jojo/Downloads/Epistemos/Epistemos/State/EventStore.swift:217
  - /Users/jojo/Downloads/Epistemos/.claude/worktrees/simulation/agent_core/src/events.rs:272
deliberations_consulted:
  - docs/fusion/deliberation/agent_event_tool_provenance_pr1_deliberation_2026_05_01.md
quick_capture_consulted: n/a
worktrees_consulted:
  - simulation
drift:
  detected: true
  canon_says: "Six v1.6 `AgentEvent` variants are NOT yet in main's enum."
  code_says: "[paraphrase] Main has Swift AgentProvenanceEventKind, not a live Rust simulation AgentEvent enum."
  canon_path: /Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
  code_path: /Users/jojo/Downloads/Epistemos/Epistemos/Models/AgentProvenanceEvent.swift
load_bearing_quote: "six v1.6 AgentEvent variants remain forward references"
verdict: partial
usefulness: +1
usefulness_reason: Converts H6 into a safe forward-vocabulary seed while preserving the no-live-runtime boundary.
---

## Findings

- `MASTER_RESEARCH_INDEX_2026_05_02.md §0 H6` says the six v1.6 variants are
  forward references for Pro tier sidebar dispatch and multi-vault UI, not live
  main-checkout runtime behavior.
- `MASTER_RESEARCH_INDEX_2026_05_02.md §11` names simulation DOCTRINE v1.6 as
  donor-only design DNA and `worktree:simulation/agent_core/src/events.rs` as
  the current code audit target.
- `Epistemos/Models/AgentProvenanceEvent.swift:3` is the live durable Swift
  provenance vocabulary in main; it is distinct from generated UniFFI
  `AgentEvent` and Swift stream `AgentStreamEvent`.
- `Epistemos/State/EventStore.swift:217` stores `agent_events.kind` as TEXT and
  persists full event JSON, so new raw values need no schema migration if the
  Codable enum can decode them.
- `worktree:simulation/agent_core/src/events.rs:272` remains donor/frozen and
  does not contain the six new v1.6 variants.

## Open Questions

- Should the future Pro dispatch/multi-vault implementation add the same names
  to a Rust enum, or should main keep durable Swift provenance as the canonical
  ingest boundary and map external event vocabularies into it? This slice does
  not answer that.

## Recommendation

Add only the six lower-snake-case raw values to `AgentProvenanceEventKind` and
focused tests proving CaseIterable visibility, Codable round-trip, and EventStore
persistence. Do not add emitters, UI, Rust enum changes, stream-event changes,
or behavior claims in this slice.
