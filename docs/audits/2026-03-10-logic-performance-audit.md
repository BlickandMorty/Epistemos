# 2026-03-10 Logic + Performance Audit

> **Index status**: CANONICAL-OPERATIONAL — Append-only audit log; needed for state reconstruction. No copy to _consolidated.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



> **Historical snapshot:** This audit was written before the later TK2-only editor cutover and pruning pass. References to deleted prose-editor files or then-current hot paths should be read as historical findings, not as claims about the current production tree.

## Executive Summary

I audited the note/editor, sync, graph, and graph-engine paths in:

- `/Users/jojo/Epistemos/Epistemos/Views/Notes`
- `/Users/jojo/Epistemos/Epistemos/State`
- `/Users/jojo/Epistemos/Epistemos/Sync`
- `/Users/jojo/Epistemos/Epistemos/Graph`
- `/Users/jojo/Epistemos/graph-engine/src`

I also did a broader concurrency scan across the app for `@MainActor`, `Task`, `Task.detached`, and `nonisolated` usage to catch obvious cross-cutting hotspots. Outside the requested subsystems, the highest-density files were `/Users/jojo/Epistemos/Epistemos/Engine/LLMService.swift`, `/Users/jojo/Epistemos/Epistemos/Engine/PipelineService.swift`, and `/Users/jojo/Epistemos/Epistemos/Views/Landing/CommandPaletteOverlay.swift`. I did not turn those into release findings because this pass was scoped to notes, sync, and graph logic, and I did not trace those other pipelines end-to-end.

The app is coherent enough to ship, but there are still real internal costs:

- editor-side data detection was still doing the expensive scan work from a main-actor debounce path
- vault bulk-save and sync flows can overlap or do too much work on the main actor
- graph structural rebuild still has an avoidable N+1 fetch path
- page-mode graph building still copies and parses large note bodies on the main actor
- the Rust physics loop still has a per-tick viewport-mask clone when viewport culling is enabled

I implemented exactly one safe optimization in this pass:

- `P1 High-Value Safe Optimization`: move debounced editor data detection off the caller's actor, keep attribute application on the main actor, and drop stale results before styling

Everything else stayed read-only because the next biggest wins touch persistence ordering, sync ownership, or graph hot paths where a “simple” change could create stale-state bugs right before release.

## Logic Coherence Risks

### Finding LC-1

- Classification: `P2 Worthwhile But Needs Care`
- Exact file path: `/Users/jojo/Epistemos/Epistemos/Views/Notes/ProseEditorRepresentable2.swift`
- Exact function / code path: `Coordinator2.handlePageChangeIfNeeded()`, `Coordinator2.persistCurrentTextIfNeeded()`, `Coordinator2.scheduleDirectSave(_:)`
- Why it is logically wrong, slow, or fragile: note persistence ownership is intentionally split across a 300 ms binding sync, a 3 s direct disk write, an `onPageFlush` path on page switch/dismantle, and the 5 s SwiftData persist in `/Users/jojo/Epistemos/Epistemos/Views/Notes/ProseEditorView.swift` `debouncedSave(_:)`. The current behavior is not obviously wrong, but it is brittle because disk state, binding state, and SwiftData dirty state are owned by different timers and closures.
- Likely user-facing consequence: if this area regresses, the failure mode is not cosmetic. It becomes “recent text exists in one layer but not another,” especially during note switches, crashes, or external reads that assume disk is current.
- Lowest-risk improvement: keep the current defense-in-depth design for release, but explicitly serialize the persistence stages behind one small state machine after release so “binding synced,” “disk flushed,” and “SwiftData persisted” are represented as separate states instead of implied by timer order.
- Implemented or left alone: deliberately left alone

### Finding LC-2

- Classification: `P2 Worthwhile But Needs Care`
- Exact file path: `/Users/jojo/Epistemos/Epistemos/Sync/VaultSyncService.swift`
- Exact function / code path: `saveAllDirtyPages()`, `restartAutoSaveTimer()`
- Why it is logically wrong, slow, or fragile: `saveAllDirtyPages()` returns a `Task`, but the service does not retain or gate that task. The auto-save timer calls `self.saveAllDirtyPages()` on every interval without checking whether a previous bulk save is still exporting. Manual save triggers can hit the same path at the same time.
- Likely user-facing consequence: redundant vault exports, repeated Spotlight indexing, longer save bursts, and harder-to-reason dirty-flag timing if two bulk saves finish in a different order than they started.
- Lowest-risk improvement: add a single-flight task handle for bulk save work and coalesce later save requests into a “run again after current save finishes” flag.
- Implemented or left alone: deliberately left alone

## Performance Hot Paths

### Finding PH-1

- Classification: `P1 High-Value Safe Optimization`
- Exact file path: `/Users/jojo/Epistemos/Epistemos/Engine/DataDetectionService.swift`
- Exact function / code path: `detectAsync(in:priority:)`
- Why it is logically wrong, slow, or fragile: the detector itself is CPU-bound text scanning. Running that scan from the editor debounce path on the main actor means typing pauses can turn into visible UI stalls on large notes.
- Likely user-facing consequence: short hitch after typing stops, especially on large documents where `NSDataDetector` has more text to scan.
- Lowest-risk improvement: run only the scan off the caller's actor, return the matches, then apply styling back on the main actor.
- Implemented or left alone: implemented

### Finding PH-2

- Classification: `P1 High-Value Safe Optimization`
- Exact file path: `/Users/jojo/Epistemos/Epistemos/Views/Notes/ProseEditorRepresentable.swift`
- Exact function / code path: `Coordinator.scheduleDataDetection(_:)`
- Why it is logically wrong, slow, or fragile: the debounce task was paying the full data-detection cost before it could resume normal main-thread work. It also had no stale-text guard after the async boundary.
- Likely user-facing consequence: editor pauses after typing and a chance of styling outdated ranges if text changes while a background scan is still running.
- Lowest-risk improvement: call `DataDetectionService.detectAsync(in:)`, then bail out if the task was cancelled or `storage.string` no longer matches the scanned snapshot.
- Implemented or left alone: implemented

### Finding PH-3

- Classification: `P1 High-Value Safe Optimization`
- Exact file path: `/Users/jojo/Epistemos/Epistemos/Views/Notes/ProseEditorRepresentable2.swift`
- Exact function / code path: `Coordinator2.scheduleDataDetection(_:)`
- Why it is logically wrong, slow, or fragile: the TextKit 2 editor had the same debounce pattern and the same stale-result risk as the legacy editor path.
- Likely user-facing consequence: identical typing-pause hitch in the TK2 path, plus occasional styling of out-of-date ranges after rapid edits.
- Lowest-risk improvement: same as TK1: background scan only, then main-actor styling guarded by cancellation and text equality checks.
- Implemented or left alone: implemented

### Finding PH-4

- Classification: `P2 Worthwhile But Needs Care`
- Exact file path: `/Users/jojo/Epistemos/Epistemos/Graph/GraphBuilder.swift`
- Exact function / code path: `build(context:)`, block-reference resolution pass
- Why it is logically wrong, slow, or fragile: the second pass resolves each referenced block ID with its own `FetchDescriptor<SDBlock>`. That is an N+1 fetch pattern inside structural graph rebuild.
- Likely user-facing consequence: graph rebuild time scales badly when many notes reference many blocks, especially during rebuilds or first-load structural scans.
- Lowest-risk improvement: batch-fetch referenced blocks in one descriptor and build the `blockId -> pageId` lookup from that result.
- Implemented or left alone: deliberately left alone

### Finding PH-5

- Classification: `P2 Worthwhile But Needs Care`
- Exact file path: `/Users/jojo/Epistemos/Epistemos/Sync/VaultSyncService.swift`
- Exact function / code path: `syncFromVault()`
- Why it is logically wrong, slow, or fragile: after import, the service fetches every page on the main context and recomputes `lastSyncedBodyHash` from `page.loadBody(mapped: true)` in a full loop. That is a lot of file I/O and hashing on the main actor after an already-heavy sync path.
- Likely user-facing consequence: sync completion hitch on larger vaults, especially when many pages are unchanged but still rehashed anyway.
- Lowest-risk improvement: move the hash recompute decision closer to the importer so only changed pages are rehashed, or batch the file/body hash work off-main and apply only the resulting metadata mutations on the main actor.
- Implemented or left alone: deliberately left alone

### Finding PH-6

- Classification: `P2 Worthwhile But Needs Care`
- Exact file path: `/Users/jojo/Epistemos/Epistemos/Graph/GraphState.swift`
- Exact function / code path: `buildPageSubgraph(for:context:)`
- Why it is logically wrong, slow, or fragile: page-mode graph building loads the full note body, creates a C string, then copies the full body into a `[UInt8]` buffer for span slicing, all on the main actor.
- Likely user-facing consequence: entering page graph mode can stall on very large notes, even before Rust-side layout begins.
- Lowest-risk improvement: keep the SwiftData fetch on the main actor, but move the markdown span parsing and byte slicing preparation into an off-main worker that returns a compact intermediate result for main-actor graph insertion.
- Implemented or left alone: deliberately left alone

### Finding PH-7

- Classification: `P3 Interesting But Not Worth Touching Before Release`
- Exact file path: `/Users/jojo/Epistemos/graph-engine/src/simulation.rs`
- Exact function / code path: viewport mask build inside the integration loop
- Why it is logically wrong, slow, or fragile: the code clones `self.active_mask` into `viewport_mask` every tick when viewport bounds are active. That is an avoidable allocation and full-buffer copy in a render-loop path.
- Likely user-facing consequence: higher CPU and memory bandwidth during graph motion with viewport culling enabled, especially on large graphs.
- Lowest-risk improvement: reuse a second scratch mask buffer instead of cloning the active mask vector every tick.
- Implemented or left alone: deliberately left alone

## Threading / Multi-Core Opportunities

### Finding TM-1

- Classification: `P2 Worthwhile But Needs Care`
- Exact file path: `/Users/jojo/Epistemos/Epistemos/Sync/VaultSyncService.swift`
- Exact function / code path: `rebuildIndex()`
- Why it is logically wrong, slow, or fragile: `rebuildIndex()` starts a `Task` from a main-actor service, fetches all pages from the index actor, then calls `SearchIndexService.rebuildFromSwiftData(_:)` synchronously inside that task. Because the task originates from the main actor and never explicitly escapes it, the expensive rebuild can still occupy main-actor time.
- Likely user-facing consequence: the UI can feel blocked during manual index rebuild even though the code appears “async.”
- Lowest-risk improvement: snapshot rebuild inputs, then run the GRDB rebuild in a detached background task or in the search/index actor itself, with only the `isIndexing` flag bouncing through the main actor.
- Implemented or left alone: deliberately left alone

### Finding TM-2

- Classification: `P2 Worthwhile But Needs Care`
- Exact file path: `/Users/jojo/Epistemos/graph-engine/src/engine.rs`
- Exact function / code path: `ensure_cluster_assignments(...)` and incremental cluster-cache rebuild near cluster-state capture
- Why it is logically wrong, slow, or fragile: the engine clones `cluster_ids`, and later clones cluster state pieces again when building cache/world synchronization payloads. This is not a correctness bug, but it means the clustering path pays extra copy cost instead of sharing or reusing state.
- Likely user-facing consequence: cluster rebuilds cost more CPU and memory than necessary on larger graphs, which can lengthen heavy relayout phases.
- Lowest-risk improvement: restructure the cluster-cache build API so it can borrow or take ownership of the already-produced vectors instead of cloning them again.
- Implemented or left alone: deliberately left alone

### Finding TM-3

- Classification: `P3 Interesting But Not Worth Touching Before Release`
- Exact file path: `/Users/jojo/Epistemos/Epistemos/State/NotesUIState.swift`
- Exact function / code path: `scheduleDebouncedSearch()`
- Why it is logically wrong, slow, or fragile: this path spawns a new main-actor task on each keystroke and cancels the old one. That is mechanically fine, but it is not a real performance issue because the debounce window is short and the payload is trivial.
- Likely user-facing consequence: effectively none at current scale.
- Lowest-risk improvement: no change before release; only revisit if Instruments shows task churn here is material.
- Implemented or left alone: deliberately left alone

## Safe Optimizations You Can Implement Now

### Finding SO-1

- Classification: `P1 High-Value Safe Optimization`
- Exact file path: `/Users/jojo/Epistemos/EpistemosTests/TextKit2FoundationTests.swift`
- Exact function / code path: `DataDetectionServiceTests`
- Why it is logically wrong, slow, or fragile: the new background detection path needed a regression lock so editor scans do not drift from synchronous detection behavior.
- Likely user-facing consequence: without a lock, a future change could make the async path fast but semantically different.
- Lowest-risk improvement: add a narrow regression test that compares async and synchronous detection on mixed content and verifies the empty-text fast path.
- Implemented or left alone: implemented

### Finding SO-2

- Classification: `P1 High-Value Safe Optimization`
- Exact file path: `/Users/jojo/Epistemos/Epistemos/Views/Notes/ProseEditorRepresentable.swift`
- Exact function / code path: `Coordinator.scheduleDataDetection(_:)`
- Why it is logically wrong, slow, or fragile: after the async boundary, old scan results could still be applied if the buffer changed before styling.
- Likely user-facing consequence: stale underline ranges flashing in briefly after rapid edits.
- Lowest-risk improvement: compare the current storage string to the scanned snapshot before applying attributes.
- Implemented or left alone: implemented

### Finding SO-3

- Classification: `P1 High-Value Safe Optimization`
- Exact file path: `/Users/jojo/Epistemos/Epistemos/Views/Notes/ProseEditorRepresentable2.swift`
- Exact function / code path: `Coordinator2.scheduleDataDetection(_:)`
- Why it is logically wrong, slow, or fragile: same stale-result risk as TK1.
- Likely user-facing consequence: same stale underline artifact in the TK2 editor.
- Lowest-risk improvement: same snapshot equality guard before applying styles.
- Implemented or left alone: implemented

## Optimizations That Are Real But Too Risky Right Now

### Finding RT-1

- Classification: `P2 Worthwhile But Needs Care`
- Exact file path: `/Users/jojo/Epistemos/Epistemos/Views/Notes/ProseEditorView.swift`
- Exact function / code path: `debouncedSave(_:)`
- Why it is logically wrong, slow, or fragile: the 5 s persist path writes the body to disk on a detached task, then mirrors blocks and saves SwiftData on the main actor. That can still hitch on large notes because `BlockMirror.sync(...)` parses and reconciles the whole block tree after the file write completes.
- Likely user-facing consequence: short pause after the debounce fires on large outline-heavy notes.
- Lowest-risk improvement: only move block parsing off-main if you first prove the parsed-block result can be applied without violating SwiftData or editor ordering assumptions.
- Implemented or left alone: deliberately left alone

### Finding RT-2

- Classification: `P2 Worthwhile But Needs Care`
- Exact file path: `/Users/jojo/Epistemos/Epistemos/Sync/VaultSyncService.swift`
- Exact function / code path: `saveAllDirtyPages()`, `syncFromVault()`
- Why it is logically wrong, slow, or fragile: these flows mix disk export/import, SwiftData mutation, dirty-flag clearing, and Spotlight indexing in a way that is logically coherent today but very sensitive to reordering.
- Likely user-facing consequence: a bad optimization here would look like silent stale-state bugs, not just slower performance.
- Lowest-risk improvement: do not parallelize these flows before release. First split them into explicit phases with clear ownership of “disk truth,” “model truth,” and “index truth.”
- Implemented or left alone: deliberately left alone

### Finding RT-3

- Classification: `P3 Interesting But Not Worth Touching Before Release`
- Exact file path: `/Users/jojo/Epistemos/graph-engine/src/simulation.rs`
- Exact function / code path: viewport-mask preparation inside the physics step
- Why it is logically wrong, slow, or fragile: the allocation is real, but this is deep inside the render loop and changing scratch-buffer ownership here is easy to get subtly wrong.
- Likely user-facing consequence: any regression would show up as broken viewport filtering or incorrect neighbor activation, which is worse than the current copy cost right before release.
- Lowest-risk improvement: profile first, then add a second reusable scratch buffer with test coverage around viewport-limited physics behavior.
- Implemented or left alone: deliberately left alone

## Suggested Profiling Targets

1. Notes editor typing pause on 25k, 50k, and 100k character notes, especially the 1 s post-typing window where data detection and delayed saves fire.
2. `/Users/jojo/Epistemos/Epistemos/Sync/VaultSyncService.swift` `saveAllDirtyPages()` with 50 to 200 dirty pages to measure overlap, export time, and Spotlight indexing cost.
3. `/Users/jojo/Epistemos/Epistemos/Sync/VaultSyncService.swift` `syncFromVault()` on a large vault with many unchanged files to quantify the main-actor rehash loop.
4. `/Users/jojo/Epistemos/Epistemos/Graph/GraphBuilder.swift` structural rebuild on a corpus with heavy `((block-ref))` usage to measure the N+1 fetch penalty.
5. `/Users/jojo/Epistemos/Epistemos/Graph/GraphState.swift` `buildPageSubgraph(for:context:)` on very large notes to measure UTF-8 copy and markdown span parse cost.
6. `/Users/jojo/Epistemos/graph-engine/src/simulation.rs` physics step with viewport bounds active and inactive on large graphs to see whether the mask clone is actually material.
7. Outside this audit scope but worth next-pass profiling: `/Users/jojo/Epistemos/Epistemos/Engine/LLMService.swift`, `/Users/jojo/Epistemos/Epistemos/Engine/PipelineService.swift`, and `/Users/jojo/Epistemos/Epistemos/Views/Landing/CommandPaletteOverlay.swift`, because they have the highest actor/task density outside notes/sync/graph.

## Final Priority List

1. `P1 High-Value Safe Optimization` completed: keep the off-main editor data-detection scan and stale-result guards in both editor stacks.
2. `P2 Worthwhile But Needs Care`: make vault bulk save single-flight so auto-save and manual save cannot overlap freely.
3. `P2 Worthwhile But Needs Care`: batch block-reference fetches in `GraphBuilder.build(context:)`.
4. `P2 Worthwhile But Needs Care`: remove or narrow main-actor rehash/index rebuild work in `VaultSyncService.syncFromVault()` and `VaultSyncService.rebuildIndex()`.
5. `P2 Worthwhile But Needs Care`: move page-subgraph parsing prep off the main actor without moving SwiftData ownership off the main actor.
6. `P2 Worthwhile But Needs Care`: only revisit the split note-persistence pipeline after release, because it is currently coherent but fragile.
7. `P3 Interesting But Not Worth Touching Before Release`: Rust viewport-mask and cluster-copy reductions should wait for targeted profiling and focused tests.
