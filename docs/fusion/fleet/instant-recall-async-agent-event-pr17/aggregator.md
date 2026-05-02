---
role: aggregator
source_fleet: codex-own
slice: instant-recall-async-agent-event-pr17
date: 2026-05-02
detectives_consumed:
  - detectives/agent-event-provenance.md
  - detectives/instant-recall-async.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - docs/fusion/fleet/round-15-next-provenance-slice-selection/claude-side-fleet/aggregator.md
canon_gaps_opened:
  - none
conflicts:
  - id: C1
    sources: [aggregator.md, claude-red-team/attacks.md]
    resolution: Claude Red Team P0/P1 attacks refine, not contradict, the slice shape; implementation must add typed async outcome, cancellation terminal rows, independent async ids, empty-result success coverage, and stricter privacy guardrails.
drift_signals: []
tier: Core
sovereign_gate_touchpoint: none
killer_feature_dependency:
  resonance_gate: false
  sovereign_gate: false
  freeform_pulse: false
  residency_rail: false
  unclosed_core_blocker: none
ready_for_pipeline_builder: true
missing_artifacts: []
input_usefulness_rollup:
  plus_one: 3
  zero: 0
  minus_one: 0
usefulness: +1
usefulness_reason: Reconciles the exact PR17 async seam and privacy-preserving implementation boundary.
---

## Reconciled findings
- `MASTER_RESEARCH_INDEX_2026_05_02.md section 2` anchors AgentEvent provenance as a typed substrate-spine event stream, not a UI feature.
- `MASTER_RESEARCH_INDEX_2026_05_02.md section 5` anchors InstantRecall as Core recall substrate used by Contextual Shadows/Halo-adjacent retrieval.
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:889` explicitly names `searchAsync(query:topK:)` as a future InstantRecall provenance path after a new gate.
- `InstantRecallService.swift:477` is the only code seam for PR17. `search(queryText:topK:)` remains PR16 and must not be reworked.
- `InstantRecallService.swift:472` says async search does not mutate MainActor metrics; PR17 must preserve that invariant.

## Recommended slice shape
Approve a Core additive instrumentation slice for `InstantRecallService.searchAsync(query:topK:)` only. Record requested and started AgentEvents after validation and before the detached search. The detached helper must return a typed async outcome carrying results, FFI-only elapsed milliseconds, and an optional closed-set failure class so terminal recording never guesses from an empty result array. Record failed with `failure_class=cancelled` if the parent task is cancelled after the lifecycle starts. Use a separate async sequence for `instant-recall-search-async:N` ids. Persist only sanitized query counts, topK, hit/document counts, elapsed milliseconds, source/surface, and failure class. Do not persist query text, note ids, note bodies, result text, snippets, vault paths, source text, scores, embeddings, Halo/ShadowSearch/editor/graph state, raw FFI payloads, or localized error text.

## Failure-proof guardrails
- grep: `instant-recall-async-`
- grep: `instant-recall-search-async`
- grep: `surface: "instant_recall_async"`
- forbidden grep: `(argumentsJSON|resultJSON|errorMessage).*(query_text|queryText|note_id|noteId|note_body|noteBody|snippet|embedding|score|raw_json|localizedDescription)`
- log: `Test "Async search records sanitized AgentEvents" passed`
- test: `InstantRecall - Service`
