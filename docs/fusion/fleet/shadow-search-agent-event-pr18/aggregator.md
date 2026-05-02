---
role: aggregator
source_fleet: codex-own
slice: shadow-search-agent-event-pr18
date: 2026-05-02
detectives_consumed:
  - detectives/agent-event-provenance.md
  - detectives/shadow-search.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - docs/fusion/fleet/round-17-next-master-plan-slice-selection/claude-side-fleet/aggregator.md
canon_gaps_opened:
  - none
conflicts:
  - id: C1
    sources: [detectives/agent-event-provenance.md, detectives/shadow-search.md]
    resolution: No conflict; both point to a narrow Card 7 provenance slice at ShadowSearchService.search.
drift_signals:
  - none
tier: Core
sovereign_gate_touchpoint: none
killer_feature_dependency:
  resonance_gate: false
  sovereign_gate: false
  freeform_pulse: false
  residency_rail: false
  unclosed_core_blocker: none
ready_for_pipeline_builder: true
missing_artifacts:
  - none
input_usefulness_rollup:
  plus_one: 3
  zero: 0
  minus_one: 0
usefulness: +1
usefulness_reason: Converts Round 17 selection plus local code truth into a bounded PR18 brief.
---

## Reconciled findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md §5` identifies `ShadowSearchService` as the production-mounted V0 Shadow backend route and code anchor.
- `MASTER_RESEARCH_INDEX_2026_05_02.md §2` makes AgentEvent part of the substrate spine; PR18 extends the provenance rail without touching GraphEvent or OpLog.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md Card 7` has already closed PR16/PR17 for InstantRecall sync/async and explicitly keeps ShadowSearch out of those patches.
- Current code at `ShadowSearchService.swift:31` has one async chokepoint and no provenance rows today.

## Recommended slice shape
Add bounded, sanitized AgentProvenanceEvent lifecycle rows to `ShadowSearchService.search(text:domain:limit:)` only. Preserve the existing success return and catch-to-empty behavior. Invalid/no-op inputs (`text` trims empty or `limit <= 0`) return `[]` and emit zero events. Persist only counts, domain, limit, elapsed milliseconds, status, and the closed failure-class set: `invalid_input`, `not_found`, `io_failure`, `backend_failure`, `rust_panic`, `unknown_code`, `cancelled`, `unknown_error`. Never persist query text, hit IDs, titles, snippets, scores, sources, bodies, vault paths, raw FFI payloads, localized descriptions, or arbitrary error text.

## Failure-proof guardrails
- grep: `rg -n "(query_text|queryText|snippet|score|doc_id|docId|title|body|vault|path|localizedDescription|String\\(describing:.*error)" Epistemos/Engine/ShadowSearchService.swift EpistemosTests/ShadowServicesTests.swift`
- log: `/tmp/epistemos-shadow-search-agent-event-pr18-green-20260502.log` contains `** TEST SUCCEEDED **`.
- test: `EpistemosTests/ShadowServicesTests`
