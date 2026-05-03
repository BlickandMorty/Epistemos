---
role: aggregator
source_fleet: codex-own
slice: query-runtime-rrf-fused-fulltext-pr34
date: 2026-05-03
detectives_consumed:
  - detectives/query-runtime-rrf-fused-fulltext.md
web_consumed:
  - none
claude_side_fleet_consumed:
  - none
canon_gaps_opened:
  - MASTER_RESEARCH_INDEX lacked a dedicated Swift RRF Cross-Index Fusion concept; this slice stages the index entry.
conflicts:
  - id: C1
    sources: [docs/RRF_FUSION_DESIGN.md, HEAD:Epistemos/Engine/QueryRuntime.swift]
    resolution: Current code wins as drift evidence; the canonical design remains the intended target, so recover the missing hunk and verify it.
drift_signals:
  - docs/RRF_FUSION_DESIGN.md claims QueryRuntime wired; HEAD lacked the fused path.
tier: Both
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
  plus_one: 1
  zero: 0
  minus_one: 0
usefulness: +1
usefulness_reason: Converts a canonical/code drift into a bounded, tested recovery slice.
---

## Reconciled findings

- RRF canon requires a single SQL fused query and additive flag-gated wiring; `docs/RRF_FUSION_PROMPT.md:27` and `docs/RRF_FUSION_PROMPT.md:67` are the controlling local authority.
- `docs/RRF_FUSION_DESIGN.md:281` and `CLAUDE.md:205` both name `QueryRuntime.fullText` as a Phase 4 fused path, but HEAD lacked the path.
- The candidate hunk is Core-safe while the flag is off and keeps fused search limited to `.all` scope.
- Claude Red Team found that `.all` reactive queries also need readable-block invalidation; this slice now adds `QueryDependencyKey.searchReadable` and `ReadableBlocksIndex` notifications.
- The added QueryRuntime tests use a real file-backed `SearchIndexService`, prove fallback behavior by dropping `readable_blocks_fts`, and prove flag-on `.pages` / `.blocks` do not touch `SearchFusionMetrics`.

## Recommended slice shape

Approve a recovery commit that adopts the existing `QueryRuntime.fullText` hunk, adds the missing readable-block query invalidation dependency, adds QueryRuntime consumer/source-guard tests, updates the master index so future agents can find RRF directly, and records post-merge guards. Keep Phase 6 default flip, Halo Vault UI, Rust agent FFI, and Hermes grammar parity out of this commit.

## Failure-proof guardrails

- grep: `rg -n "RRFFusionFlags\\.isEnabled && scope == \\.all|searchIndex\\.fusedSearch\\(|FusionWeights\\(maxResults: limit\\)|Falling back to legacy per-index dispatch" Epistemos/Engine/QueryRuntime.swift`
- grep: `rg -n "case searchReadable|\\.searchReadable|searchIndexDidUpdate" Epistemos/Models/QueryTypes.swift Epistemos/Sync/ReadableBlocksIndex.swift EpistemosTests/QueryRuntimeTests.swift`
- log: `✔ Test "retrieval runtime keeps page and block scopes on legacy search when RRF flag is enabled" passed`
- log: `✔ Test "retrieval runtime preserves legacy full-text results when RRF fused path falls back" passed`
- log: `✔ Test "retrieval runtime routes all-scope through RRF fused search only behind the flag" passed`
- test: `QueryRuntimeTests`
