# B-Prime Follow-up Closeout - 2026-05-26

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

Status: closed for current product recovery.

Source surfaces:

- Stash: `stash@{0}` / `recovery/stash-b-prime-uncommitted-followup-2026-05-26`
- Draft preservation PR: `#82`
- Original plan: `docs/audits/B_PRIME_FOLLOWUP_REPROMOTION_PLAN_2026_05_26.md`

Recovery rule: no stash was popped, dropped, checked out, or bulk-applied. This
closeout compares the preserved donor work against current `main` and records
which pieces are now live, which are superseded, and why the draft preservation
PR must remain non-mergeable.

## Closed Slices

| Slice | Current `main` state | Evidence |
|---|---|---|
| Chat provenance rows | Live | `Epistemos/App/ChatCoordinator.swift`, `Epistemos/Views/Chat/MessageBubble.swift`, `Epistemos/Views/Chat/VaultRecallProvenanceCard.swift`, and `docs/audits/CHAT_CITATION_UI_INTEGRATION_2026_05_24.md` carry the row-local `VaultRecallTrace` path. |
| Production VaultRecall search traces | Live | `Epistemos/Sync/SearchIndexService.swift` exposes `vaultRecallTrace(query:limit:results:)` and `vaultRecallTrace(query:limit:fusedResults:)`; `Epistemos/Sync/VaultSyncService.swift` records traces behind `VaultRecallFlags`; `EpistemosTests/VaultRecallWiringTests.swift` verifies real backend detection. |
| Eidos search-index mirroring | Live | `SearchIndexService.upsert`, `upsertPages`, and `rebuildFromSwiftData` call the Eidos mirror when a production vault index is open; `EpistemosTests/EidosBridgeProductionTests.swift` verifies `SearchIndexService` upsert feeds the real Eidos index. |
| HTML Workspace/source guard | Live | `docs/audits/B_PRIME_HTML_WORKSPACE_SOURCE_GUARD_2026_05_26.md` and `EpistemosTests/HTMLWorkspaceSourceGuardTests.swift` guard the current HTML Workspace direction. |
| Legacy diagram compatibility | Live | `docs/audits/B_PRIME_LEGACY_DIAGRAM_COMPATIBILITY_2026_05_26.md` records the safe recovery. Old `mermaid` schema blocks load as inert legacy source; active creation stays on HTML Workspace. |
| UAS/AcsAnchor artifact gates | Live | `docs/audits/B_PRIME_UAS_ACS_ARTIFACT_GATES_2026_05_26.md` and `EpistemosTests/SubstrateHealthPanelTests.swift` guard artifact-backed settings rows. |
| Settings health-row nuance | Live | `docs/audits/B_PRIME_SETTINGS_HEALTH_SUPERSESSION_2026_05_26.md` records the recovered AnswerPacket `claimKindCounts` metric. |
| Local-agent tool repair | No remaining donor delta | Filtered comparison against current `main` shows no remaining diff for `IncrementalToolCallDetector`, `LocalAgentLoop`, `ToolCallParser`, `ToolTierBridge`, or their related tests. |
| Doctrine lint | Live | `agent_core/src/bin/epistemos_doctrine_lint.rs` already carries the T25 ACS naming reconciliation gate. |
| Living Index / no-compromise docs | Superseded by newer main | Current `docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md` is newer than the stash copy. Current main also keeps `docs/fusion/NO_COMPROMISE_DOCUMENT_WORKSPACE_IMPLEMENTATION_PLAN_2026_05_25.md`; the stash tree would delete it. |

## Superseded Or Unsafe To Raw-Merge

- The draft PR `#82` is preservation, not a feature PR. Raw merge would remove
  current main files, including newer HTML Workspace tests and docs, current
  editor-bundle guards, and current ambient playback state.
- The ambient/audio/settings donor slice is older than current main. The only
  filtered ambient delta from `HEAD` to `stash@{0}` is deletion of
  `Epistemos/State/AmbientFrequencyPlaybackState.swift`, so the stash is not a
  recovery source for the current ambient surface.
- The editor-bundle donor tree is stale after the legacy-diagram recovery: it
  would delete `legacy-diagram-node.ts` and the source guard that now protect
  old Epdoc diagram content without reintroducing live Mermaid rendering.
- Reliability artifacts and compressed/generated files are preservation noise
  unless a future source change requires rebuilding them.

## Result

B-prime follow-up is closed for current product recovery. Keep the stash and
draft PR as recovery references until the user approves retiring preservation
branches, but do not dispatch new agents to raw-merge or re-promote `#82`.

Next useful recovery work is outside B-prime:

1. `#81` / Claude shadow-handle donor: extract a focused honest-handle FFI
   slice, not the stale branch tree.
2. `stash@{18}` remaining non-shell UI donor slices: landing/session,
   editor/note UX, chat/runtime presentation, graph/performance, and theme
   nuance.
3. Substrate/research stashes: `stash@{8}`, `stash@{9}`, `stash@{13}`,
   `stash@{14}`, and `stash@{16}`.
