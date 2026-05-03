# QueryRuntime RRF fused full-text PR34 deliberation brief

Slice: `query-runtime-rrf-fused-fulltext-pr34`
Date: 2026-05-03
Tier: Core-safe flag-off; Pro/Research/dev-dogfood when `EPISTEMOS_RRF_FUSION_V1=1`

## Decision

Approved for a narrow recovery of RRF Phase 4 site 3: `RetrievalRuntime.fullText(query:scope:)` may route `.all` full-text retrieval through `SearchIndexService.fusedSearch(query:weights:now:)` when `RRFFusionFlags.isEnabled` is true, then fall back to the legacy page + block searches when the flag is off or fused search throws.

## Evidence

- `docs/RRF_FUSION_PROMPT.md` names RRF as a single SQL query and requires every Phase 4 wiring site to be additive behind `EPISTEMOS_RRF_FUSION_V1`.
- `docs/RRF_FUSION_DESIGN.md` §14 says `QueryRuntime.fullText(query:scope:)` is the Epdoc slash menu / at-mention block-link autocomplete fused path.
- `CLAUDE.md` lists `QueryRuntime.fullText` as flag-aware RRF Phase 4 wiring.
- HEAD did not contain `RRFFusionFlags.isEnabled && scope == .all` or `searchIndex.fusedSearch(` in `QueryRuntime.swift`, so the candidate dirty hunk is a real recovery, not a duplicate.

## Allowed files

- `Epistemos/Engine/QueryRuntime.swift`
- `Epistemos/Models/QueryTypes.swift`
- `Epistemos/Sync/ReadableBlocksIndex.swift`
- `EpistemosTests/QueryRuntimeTests.swift`
- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
- Round 66 fleet, deliberation, current-state, workcard, registry, preflight, and guard docs

## Forbidden files

- `Epistemos/Sync/SearchIndexService.swift`
- `Epistemos/Sync/RRFFusionQuery.swift`
- `Epistemos/Sync/VaultSyncService.swift`
- `Epistemos/Views/**`
- `Epistemos/Graph/**`
- `graph-engine/**`
- `agent_core/**`
- `epistemos-core/**`
- generated bindings, entitlements, Xcode project files

## Acceptance

- The RRF fused path is guarded by `RRFFusionFlags.isEnabled && scope == .all`.
- Flag-off behavior remains the existing two-index page + block dispatch.
- Fused-path failures fall through to legacy dispatch.
- `.pages` and `.blocks` do not use `fusedSearch`.
- `.all` reactive queries invalidate on readable-block projection changes through `QueryDependencyKey.searchReadable`.
- A real DB QueryRuntime test proves readable-block-only content appears only in the flag-on `.all` fused path.
- A non-skipped QueryRuntime test drops the readable FTS table and proves flag-on retrieval preserves legacy page hits when fused search throws.
- A non-skipped QueryRuntime test proves flag-on `.pages` and `.blocks` stay on legacy search by asserting `SearchFusionMetrics` remains untouched.
- Source guards keep the slice out of async fused search, GraphEvent writes, MutationEnvelope writes, InstantRecall, MeaningAnchor, graph renderer, timers, and subprocesses.

## Verification

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-pr34 -parallel-testing-enabled NO -only-testing:EpistemosTests/QueryRuntimeTests test
```

## Rollback

Remove the QueryRuntime fused block, `searchReadable` dependency wiring, the QueryRuntime tests, the master-index RRF entry, and this slice's fleet/deliberation/guard docs.

## Canon anchors

- MASTER_RESEARCH_INDEX_2026_05_02.md §2, Swift RRF Cross-Index Fusion
- `docs/RRF_FUSION_PROMPT.md` Phase 4
- `docs/RRF_FUSION_DESIGN.md` §14
- `CLAUDE.md` "Swift RRF Cross-Index Fusion"

## Workcard match

- AGENT_BUILD_WORKCARDS_2026_05_01.md card: new Card 11 - RRF QueryRuntime Phase-4 Recovery
- Deviation: This is a drift-recovery slice for a claimed wired site, not a new feature expansion. It deliberately avoids Phase 6 flag flip and deferred Rust/Hermes FFI sites.

## Failure-proof guardrails (post-merge)

- grep: `rg -n "RRFFusionFlags\\.isEnabled && scope == \\.all|searchIndex\\.fusedSearch\\(|FusionWeights\\(maxResults: limit\\)|Falling back to legacy per-index dispatch" Epistemos/Engine/QueryRuntime.swift`
- grep: `rg -n "case searchReadable|\\.searchReadable|searchIndexDidUpdate" Epistemos/Models/QueryTypes.swift Epistemos/Sync/ReadableBlocksIndex.swift EpistemosTests/QueryRuntimeTests.swift`
- log: `✔ Test "retrieval runtime keeps page and block scopes on legacy search when RRF flag is enabled" passed`
- log: `✔ Test "retrieval runtime preserves legacy full-text results when RRF fused path falls back" passed`
- log: `✔ Test "retrieval runtime routes all-scope through RRF fused search only behind the flag" passed`
- test: `QueryRuntimeTests`

## Fleet evidence packet

- docs/fusion/fleet/query-runtime-rrf-fused-fulltext-pr34/aggregator.md
- docs/fusion/fleet/query-runtime-rrf-fused-fulltext-pr34/claude-red-team/attacks.md

## Usefulness

usefulness: +1
usefulness_reason: Closes a local-canon/code drift on an RRF Phase 4 wiring site with a real DB consumer test.
