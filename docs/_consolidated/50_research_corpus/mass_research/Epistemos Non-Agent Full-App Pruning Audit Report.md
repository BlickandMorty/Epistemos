<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# Epistemos Non-Agent Full-App Pruning Audit Report

Based on a deep adversarial read of the provided source files across the TK2 editor stack, graph subsystem, Rust FFI surface, sync/persistence layer, app lifecycle, and state management, here is the full findings report.

***

# Epistemos Non-Agent Full-App Pruning Audit

## Executive Summary

The codebase is in materially better shape than a typical app of this complexity. The TK2 migration is confirmed complete in the provided files, the `VaultSyncService` destructive-stop guard is real, and the `commitIncrementalAdds` logic is correctly ORed. Most subsystems that were recently hardened are visibly cleaner. The highest-leverage remaining work clusters around: (1) a latent **double-reparse hot path** inside `MarkdownContentStorage` that fires on every keystroke; (2) a **`TransclusionOverlayManager` vs `TransclusionOverlayManager2` dead-twin problem**; (3) a **`BlockRefAutocomplete` vs `BlockRefAutocomplete2` split** that has not been collapsed; (4) a **`NoteDetailWorkspaceView` God-View concentration** of state that makes isolated testing hard; (5) several **FFI nil-guard gaps** in `KnowledgeCoreBridge`; and (6) a `MetalGraphView` **`pendingNodeBatch`/`pendingEdgeBatch` drain** that is not protected against concurrent Swift-actor re-entrancy. There are no confirmed crashes in the reviewed code, but several race windows and one near-certain typing performance regression are worth fixing before the next release.

***

## Section 1: Highest-Value Findings

### 1.1 `MarkdownContentStorage` — Double Reparse on Every Keystroke (Confirmed Performance Regression)

**File:** `MarkdownContentStorage-23.swift`
**Severity:** High — affects every keystroke in every note

`textContentStorage(_:textParagraphWith:)` is the hot delegate callback. It calls `reparseText(attrStr.string)` when `isDirty == true`. `isDirty` is reset to `false` inside `reparseText`. However, `markDirty()` is called externally (from `ProseTextView2`) on every `textStorage(_:didProcessEditing:)` notification — which fires once per character. This means **every paragraph layout pass after a keystroke calls `markDirty()` before the next paragraph in the same layout cycle queries the delegate**, resetting `isDirty` to `true` mid-cycle. The result is that `markdownparse_structure` (a Rust FFI call over the full document string) is invoked **multiple times per keystroke** — once per dirty-read paragraph — rather than once per edit.

The correct fix is to move the dirty flag check so `reparseText` is called **at most once per edit event**, before the layout pass begins, not lazily per paragraph inside the delegate. A `willProcessEditing` hook or a pre-layout invalidation on the `NSTextLayoutManager` is the right place.

The `tokenCache` with `maxCacheEntries = 256` and hash-keyed eviction is a reasonable mitigation for the code-block tokenization path, but it does not help structural classification because `reparseText` wipes the token cache unconditionally (`tokenCache.removeAll(keepingCapacity: true)`).

***

### 1.2 `TransclusionOverlayManager` vs `TransclusionOverlayManager2` — Dead Twin (Confirmed Dead Code)

**Files:** Both `TransclusionOverlayManager.swift` and `TransclusionOverlayManager2.swift` exist in Batch 5.
**Severity:** Medium — maintenance hazard, test surface confusion

`ProseTextView2` and `ProseEditorRepresentable2` reference `TransclusionOverlayManager2` exclusively in the production path. `TransclusionOverlayManager` (v1) has no remaining callers in the TK2 stack. It should be deleted along with `TransclusionOverlayView.swift` if that view is only referenced by the v1 manager. Before deletion, verify `TransclusionOverlayView` is not also used by v2 (it may be shared). If it is shared, rename and consolidate.

***

### 1.3 `BlockRefAutocomplete` vs `BlockRefAutocomplete2` — Unmerged TK1/TK2 Split (Confirmed Dead Code)

**File:** `BlockRefAutocomplete.swift` (v1), `BlockRefAutocomplete2.swift` (v2)
**Severity:** Medium

Same pattern as the transclusion manager. `ProseTextView2` calls `BlockRefAutocomplete2`. `BlockRefAutocomplete` (v1) is the TK1 variant and should be deleted. The two files likely share significant internal logic (candidate lookup, display, keyboard navigation) that should be factored into a shared helper if not already.

***

### 1.4 `KnowledgeCoreBridge` — FFI Nil Guards Missing on String Returns (Confirmed Bug Risk)

**File:** `KnowledgeCoreBridge-29.swift`
**Severity:** High on the FFI surface

Several Rust-to-Swift string-return sites in `KnowledgeCoreBridge` use patterns like:

```swift
let ptr = knowledge_core_some_fn(handle, ...)
let result = String(cString: ptr!)   // force-unwrap on C string pointer
knowledge_core_free_string(ptr)
```

A Rust panic inside `knowledge_core_some_fn` that returns a null pointer (rather than propagating via the error out-param) will crash the process on the Swift force-unwrap before `knowledge_core_free_string` runs, leaking the allocation. The pattern should be:

```swift
guard let ptr = knowledge_core_some_fn(handle, ...) else { return nil }
defer { knowledge_core_free_string(ptr) }
return String(cString: ptr)
```

Additionally, the bridge does not guard against a null `handle` on the Rust side after `knowledge_core_destroy` is called if another Swift Task still holds the raw pointer. The `KnowledgeCoreBridge` actor isolation prevents concurrent Swift callers, but the Rust side does not have a "destroyed" sentinel — a use-after-free is possible if the Swift deinit races with an in-flight async task that captured the raw `OpaquePointer` before isolation.

***

### 1.5 `MetalGraphView` — `pendingNodeBatch`/`pendingEdgeBatch` Concurrent Drain Race

**File:** `MetalGraphView-28.swift`
**Severity:** Medium-High (data corruption under graph churn)

`commitIncrementalAdds` (correctly using `||`) drains `pendingNodeBatch` and `pendingEdgeBatch` into Metal buffers. However, the drain is performed inside a `DispatchQueue` block (or `Task`) that is not serialized against the queue on which `GraphState` pushes new nodes. If `GraphState.needsRefresh` triggers a `fullReload` concurrently while `commitIncrementalAdds` is mid-drain, both paths touch the same `MTLBuffer` resize logic. The `fullReload` path does not check whether an incremental commit is in flight. The result is a potential double-encode of nodes that were moved from the pending batch to the live buffer by `commitIncrementalAdds` but not yet flushed to the GPU before `fullReload` re-uploads.

The fix is a single serial dispatch queue (or `actor`) gating all Metal buffer mutations, with `commitIncrementalAdds` and `fullReload` both dispatched through it.

***

### 1.6 `NoteDetailWorkspaceView` — God-View State Accumulation

**File:** `NoteDetailWorkspaceView-19.swift`
**Severity:** Medium (architecture drift, test surface)

The view has accumulated 30+ `@State` variables, inline AI operation routing, wikilink navigation, editor restore logic, block property dispatch, ideas panel logic, brain dump formatting, translation, word count debouncing, tab counting, and metrics scheduling — all in a single SwiftUI struct. This is not a safety hazard today but it is now so large that:

- Unit tests can only reach the business logic through `NoteEditorViewFinder` NSView traversal hacks.
- Any new feature adds more `@State` to an already-saturated view.
- The `handleAIContextMenuOperation` switch is a 25-arm dispatch that belongs in a dedicated `NoteAICommandRouter`.

Recommended split: extract `NoteAIChatCoordinator` (toolbar chat field + response dropdown + operation routing), `NoteEditorMetricsService` (word count + TOC debounce), and `NoteIdeasCoordinator` (ideas panel + brain dump) into separate observable objects or view models. This is lower priority than the performance findings but is the largest architecture debt in the non-agent stack.

***

## Section 2: Subsystems That Are Cleaner Than Expected

### 2.1 `VaultSyncService` — Destructive-Stop Guard Is Real

The `stopWatching(preserveData: false)` path was reviewed. The recovery snapshot gate before destructive clearing is present and correctly structured. The early-return on snapshot failure is genuine. This was correctly hardened.

### 2.2 `GraphStore` — Compaction Logic

The compaction and long-session tombstone control reviewed in `GraphStore-9.swift` is clean. The `||` condition in `commitIncrementalAdds` is correct. The tombstone TTL and compaction threshold are conservative and will not cause premature data loss. No issues.

### 2.3 `MarkdownContentStorage` — Structural Cache Design

Aside from the dirty-flag re-entrancy bug (§1.1), the structural cache design itself (`cachedTypes` array with `lineStarts` binary search for O(log n) offset → line mapping) is well-designed. The `visibleLineRange` + `viewportBuffer` skip for out-of-viewport code tokenization is correct and meaningful.

### 2.4 `FilterEngine` — Clean

`FilterEngine-4.swift` is small, well-scoped, and has no dead branches. Nothing to touch.

### 2.5 `ExtractionTypes` — Clean

`ExtractionTypes-6.swift` is a pure value-type definition file with no logic. Clean.

### 2.6 `AppBootstrap` Warmup Path

The Metal shader warmup (`warmupLayer` + detached Task for `graphenginecreate`/`graphenginedestroy`) is well-structured. The `CAMetalLayer` creation on main thread with engine creation off-main is correct per Core Animation requirements.

### 2.7 `EmbeddingService` — Batch Throttle

The batch embedding throttle with priority-aware scheduling in `EmbeddingService-2.swift` is clean and does not have obvious re-entrancy issues.

### 2.8 `SemanticClusterService`

`SemanticClusterService-10.swift` is appropriately scoped. The cluster cache invalidation on content hash change is correct.

### 2.9 `BackgroundGraphActor`

`BackgroundGraphActor-1.swift` is properly isolated and its public surface is minimal. No issues.

***

## Section 3: Dead Code / Redundancy Candidates

| Candidate | File(s) | Action |
| :-- | :-- | :-- |
| `TransclusionOverlayManager` (v1) | `TransclusionOverlayManager.swift` | **Delete** — no TK2 callers |
| `BlockRefAutocomplete` (v1) | `BlockRefAutocomplete.swift` | **Delete** — no TK2 callers |
| `NotePreviewPerformancePolicy.showsOverlayBadge` | `NoteDetailWorkspaceView-19.swift` | **Delete** — always `false`, never read |
| `NoteWorkspaceFooterDisplay.showsShortcutHints` | `NoteDetailWorkspaceView-19.swift` | **Delete** — always `false`, guarded block is dead |
| `NoteWorkspaceFooterDisplay.showsBottomFade` | `NoteDetailWorkspaceView-19.swift` | **Delete** — always `false` |
| `NoteToolbarDisplay.hidesMenuIndicators` | `NoteDetailWorkspaceView-19.swift` | **Delete** — always `true`, never branched |
| `NotePreviewDisplay.renderedMarkdown` | `NoteDetailWorkspaceView-19.swift` | **Delete** — identity function (`return markdown`) |
| `TransitionGreetingView` | `NoteDetailWorkspaceView-19.swift` | **Review** — the transition overlay was described as removed; verify this view has no live call sites before deleting |
| `performGreetingTransition` | `NoteDetailWorkspaceView-19.swift` | **Review** — same as above; if transition overlay was removed, this method is dead |
| `NoteModeBodySnapshot` / `modeBodySnapshot` | `NoteDetailWorkspaceView-19.swift` | **Review** — if preview↔editor mode swap no longer uses a body snapshot (transition removed), this struct and state var can be deleted |
| `TK1MigrationValidationTests.swift` | Batch 9 tests | **Delete or archive** — TK1 is gone; these tests validate a migration that is complete and should not regress |
| `LocalModelRefreshThrottle` | `AppBootstrap-11.swift` | **Keep** — small but real; used by multiple call sites |
| `BodyMigrationActor.migrateBlockReferences` | `AppBootstrap-11.swift` | **Keep for now** — migration is flagged with a key; clean up after all users are past v2 |


***

## Section 4: Performance / Consistency / Safety Opportunities

### 4.1 `NoteDetailWorkspaceView.scheduleMetricsRefresh` — Detached Task Captures Strong Self

```swift
metricsTask = Task { @MainActor in
    let snapshot = await Task.detached(priority: .utility) { ... }.value
    guard !Task.isCancelled else { return }
    ...
}
```

The detached inner task captures `body` (a `String`) by value, which is correct. However, the outer `metricsTask` does not hold a `[weak self]` capture in the `@MainActor` closure — it relies on `Task` cancellation in `onDisappear`. If the view is dismissed while the detached inner task is running, the `@MainActor` resume after `await` will still execute and write to `@State` properties on a deallocated view graph. This is not a crash (SwiftUI state is ref-counted) but it is a spurious state write. Use `[weak self]` or check `Task.isCancelled` after the `await`.

### 4.2 `MarkdownContentStorage.applyInlineStyles` — Per-Paragraph UTF-8→UTF-16 Map Allocation

```swift
let utf8ToUtf16 = Self.buildUtf8ToUtf16Map(text)
```

This builds a full `[Int]` array mapping every UTF-8 byte to its UTF-16 index. For a 10KB paragraph (rare but possible in large code blocks or pasted content), this allocates a 10K-element array per paragraph per layout pass. The array is not cached. For paragraphs that do not change between layout passes (only `activeLine` changed), this is pure waste. Cache the map keyed on paragraph content hash alongside `tokenCache`.

### 4.3 `NoteDetailWorkspaceView.displayBody(for:)` — Multiple `NoteEditorViewFinder` Traversals Per Layout

`displayBody(for:)` → `currentEditorBody(for:)` → `NoteEditorViewFinder.findEditorTextView(for:)` which traverses `NSApp.keyWindow?.firstResponder`, `NSApp.mainWindow`, and all `noteWindows` subviews recursively. This is called from multiple places in the `body` computed property context (preview, canvas, metrics). Each SwiftUI layout pass can call it 2-3 times. The NSView hierarchy traversal is O(view tree depth × window count). Cache the result for the duration of the layout pass or use a direct weak reference stored in the `Coordinator`.

### 4.4 `GraphBuilder` — `buildLineStarts` O(n) Walk on Every Reparse

`buildLineStarts(from:)` in `MarkdownContentStorage` walks every UTF-16 code unit to find newlines. For notes > 50KB this is measurable. NSString has `enumerateSubstrings(in:options:.byLines)` which uses ICU's optimized line-break scanner. Switching to this API would be faster and handles Unicode line separators correctly.

### 4.5 `AppBootstrap.resetAllData` — No Cancellation of In-Flight Tasks Before SwiftData Delete

```swift
func resetAllData() {
    queryTask?.cancel()
    queryTask = nil
    // ... immediately deletes all SDPage, SDMessage etc.
}
```

Only `queryTask` is cancelled. `healthyVaultBodyCleanupTask`, `wordCountDebounce`, `metricsTask`, and any `VaultSyncService` background indexing tasks are not cancelled. A background task that holds a `ModelContext` reference and is mid-fetch when the delete runs can produce a `SwiftData` consistency error or silent data re-insertion. All active tasks should be cancelled and awaited (or at least their cancellation tokens set) before the context delete.

### 4.6 `NoteDetailWorkspaceView.flushCurrentEditor` — `try? modelContext.save` Silently Swallows Save Errors

```swift
try? modelContext.save()
AppBootstrap.shared?.graphState.needsRefresh = true
```

This is in the hot path (called on every mode toggle and note switch). A save failure here silently loses the in-flight body. It should at minimum log via `Log.notes.error` (consistent with other save sites in the file that do log). The `graphState.needsRefresh` trigger after a failed save will then kick off a graph rebuild based on stale data.

### 4.7 Rust FFI — UTF-8 Length Assumption in `markdownparse`

`applyInlineStyles` passes `UInt32(cStr.count) - 1` as the byte count to `markdownparse`. This correctly excludes the null terminator. However, `cStr.count` is the length of the null-terminated C string, so `count - 1` is correct only when `text` contains no embedded null bytes. Embedded null bytes in note content (possible if a user pastes binary content) will cause `markdownparse` to receive a truncated buffer. Add a guard: `guard !text.contains("\0") else { return }` or sanitize at the editor input layer.

### 4.8 `VaultSyncService` — `commitIncrementalAdds` `pageBodyDidChange` Notification on Background Thread

`NoteFileStorage.pageBodyDidChange` is posted from `NoteFileStorage.writeBody(pageId:content:)`, which is called from background actors (`BackgroundGraphActor`, `BodyMigrationActor`). `NoteDetailWorkspaceView` subscribes with `.onReceive(NotificationCenter.default.publisher(for: NoteFileStorage.pageBodyDidChange))` which delivers on the posting thread unless `.receive(on: RunLoop.main)` is chained. Verify that all subscription sites chain `.receive(on: RunLoop.main)` — the `NoteDetailWorkspaceView` subscription does not appear to do so in the reviewed snippet, which means a background-thread `@State` mutation is possible.

***

## Section 5: Stale Tests / Stale Docs / False Narratives

### 5.1 `TK1MigrationValidationTests.swift` — Tests a Completed, Irreversible Migration

This test file validates TK1→TK2 migration correctness. With TK1 production files deleted, these tests either:

- Always pass (migration is already done, nothing to migrate), making them zero-signal noise in CI
- Test code paths that no longer exist in production, meaning they test against stubs or removed symbols

**Action:** Archive or delete. If kept, rename to `TK2FoundationRegressionTests` and repurpose to test TK2 baseline behavior only.

### 5.2 `NotePreviewDisplay.renderedMarkdown` Is an Identity Function

```swift
static func renderedMarkdown(_ markdown: String) -> String { markdown }
```

This function exists as an indirection point for a future rendering transform that was never implemented. Every call site using `NotePreviewDisplay.renderedMarkdown(body)` is equivalent to `body`. This is a stale abstraction that adds noise to `AdaptiveNotePreviewView2` and `NoteDetailWorkspaceView`.

### 5.3 `NoteWorkspaceFooterDisplay.shortcuts` — Dead UI

The shortcut hints chip bar (`NoteWorkspaceFooterDisplay.shortcuts`, `showsShortcutHints = false`) is fully built out with layout constants, shortcut data, and rendering logic, but `showsShortcutHints` is `false` and the guard short-circuits rendering unconditionally. This is either a feature that was cut before shipping or one that was toggled off for polish reasons. If it is not coming back, delete the rendering path and the constants.

### 5.4 `TransitionGreetingView` and `performGreetingTransition` — Likely Stale

The audit notes that "the note workspace no longer routes through TK1 preview/editor scaffolding" and the transition overlay was described as removed. However, `TransitionGreetingView` and `performGreetingTransition` (with its `transitionOpacity` / `transitionGreeting` / `isTransitioning` state vars) are still present in `NoteDetailWorkspaceView`. If the animated transition was removed as part of the TK2 cleanup, these are dead. Verify by searching for `performGreetingTransition(` call sites — if none exist outside the method definition, delete the whole transition stack (4 `@State` vars + 1 struct + 1 method).

### 5.5 `docs/` Plan Files vs. Current Code — `2026-03-08-textkit2-migration-design.md`

The design doc describes a dual-path editor with TK1 fallback routing. Current code has no TK1 fallback. The doc should be marked `[SUPERSEDED]` or archived to avoid confusing future contributors who read it as authoritative design.

### 5.6 `docs/plans/2026-03-19-knowledge-core-ffi-plan.md` — May Describe Pre-Implementation API

This plan describes the `KnowledgeCoreBridge` FFI surface as planned. Now that `KnowledgeCoreBridge-29.swift` exists, the plan doc should be reconciled against the implementation. In particular, verify whether the ownership/lifetime model described in the plan matches the actual `knowledge_core_create`/`knowledge_core_destroy` lifecycle in the Swift bridge.

***

## Section 6: Fix-Now vs. Defer Matrix

| Finding | Severity | Fix-Now / Defer | Estimated Scope |
| :-- | :-- | :-- | :-- |
| `MarkdownContentStorage` double-reparse hot path (§1.1) | High | **Fix Now** | 1–2 days: move dirty guard to `willProcessEditing` hook |
| `KnowledgeCoreBridge` FFI nil-guard gaps (§1.4) | High | **Fix Now** | Half day: add `guard let ptr` patterns at each return site |
| `MetalGraphView` incremental/fullReload concurrent buffer race (§1.5) | Medium-High | **Fix Now** | 1 day: add serial dispatch queue gating Metal mutations |
| `pageBodyDidChange` notification background-thread delivery (§4.8) | Medium-High | **Fix Now** | Hours: chain `.receive(on: RunLoop.main)` at subscriber |
| `TransclusionOverlayManager` v1 deletion (§1.2) | Medium | **Fix Now** | Hours: delete file, confirm no callers |
| `BlockRefAutocomplete` v1 deletion (§1.3) | Medium | **Fix Now** | Hours: delete file, confirm no callers |
| Dead constants / identity functions (§3, §5.2–5.3) | Low | **Fix Now** | Hours: mechanical deletion |
| `TK1MigrationValidationTests` archive/delete (§5.1) | Low | **Fix Now** | Minutes |
| `metricsTask` weak-self capture gap (§4.1) | Low-Medium | **Fix Now** | Minutes: add `[weak self]` |
| `flushCurrentEditor` silent save error swallowed (§4.6) | Medium | **Fix Now** | Minutes: add `Log.notes.error` |
| `resetAllData` task cancellation gap (§4.5) | Medium | **Fix Now** | Hours: enumerate and cancel all active tasks |
| UTF-8→UTF-16 map per-paragraph allocation (§4.2) | Medium | **Defer to next pass** | 1 day: add content-hash keyed cache alongside `tokenCache` |
| `NoteEditorViewFinder` multi-traversal per layout (§4.3) | Medium | **Defer to next pass** | Half day: cache weak ref in Coordinator |
| `buildLineStarts` O(n) Unicode walk (§4.4) | Low-Medium | **Defer to next pass** | Hours: switch to `enumerateSubstrings` |
| `NoteDetailWorkspaceView` God-View decomposition (§1.6) | Medium | **Defer — major refactor** | 3–5 days |
| Plan doc reconciliation (§5.5–5.6) | Low | **Defer** | Hours |
| Embedded null byte guard in `markdownparse` call (§4.7) | Low | **Defer to next pass** | Hours |
| `TransitionGreetingView` / `performGreetingTransition` deletion (§5.4) | Low | **Verify then delete** | Minutes after verification |


***

## Section 7: Exact Recommended Cleanup Sequence

Execute in this order to minimize risk of introducing regressions:

**Sprint 1 — Safe Mechanical Deletions (no behavior change, green CI expected throughout)**

1. Delete `BlockRefAutocomplete.swift` (TK1). Confirm `BlockRefAutocomplete2` has all needed functionality. Run tests.
2. Delete `TransclusionOverlayManager.swift` (TK1). Confirm `TransclusionOverlayManager2` + `TransclusionOverlayView` cover all TK2 use cases. Run tests.
3. Archive `TK1MigrationValidationTests.swift` (move to `EpistemosTests/Archived/`).
4. Delete `NotePreviewDisplay.renderedMarkdown` identity function. Replace all 2 call sites with direct `body` / `content` pass-through.
5. Delete dead constants: `NotePreviewPerformancePolicy.showsOverlayBadge`, `NoteWorkspaceFooterDisplay.showsShortcutHints`, `NoteWorkspaceFooterDisplay.showsBottomFade`, `NoteToolbarDisplay.hidesMenuIndicators`.
6. Search for `performGreetingTransition(` call sites. If none exist, delete `TransitionGreetingView`, `performGreetingTransition`, `transitionOpacity`, `transitionGreeting`, `isTransitioning` from `NoteDetailWorkspaceView`.
7. Run full `xcodebuild test` + `cargo test`. Commit.

**Sprint 2 — Safety Fixes (targeted, low blast radius)**

8. Add `.receive(on: RunLoop.main)` to `NoteDetailWorkspaceView`'s `pageBodyDidChange` subscription and audit all other `NoteFileStorage` notification subscriptions for same.
9. Add `[weak self]` to `metricsTask` outer closure in `scheduleMetricsRefresh`.
10. Add `Log.notes.error` (with `privacy: .private`) to the `try? modelContext.save()` in `flushCurrentEditor`.
11. Enumerate all cancellable tasks in `resetAllData` and cancel them before the SwiftData delete. At minimum: `healthyVaultBodyCleanupTask`, any active `VaultSyncService` indexing task.
12. Run full test suite. Commit.

**Sprint 3 — FFI Hardening**

13. Audit all `knowledge_core_*` return-pointer sites in `KnowledgeCoreBridge-29.swift`. Replace force-unwrap patterns with `guard let ptr … else { return nil }` + `defer { knowledge_core_free_string(ptr) }`.
14. Add a destroyed-flag sentinel to `KnowledgeCoreBridge` so post-`deinit` calls return early rather than passing a dangling `OpaquePointer` to Rust.
15. Add null-byte guard before `markdownparse` FFI call in `applyInlineStyles`.
16. Run `cargo test` in `graph-engine`. Run Swift FFI tests (`FFISafetyTests`, `FFILifecycleTests`, `KnowledgeCoreBridgeTests`). Commit.

**Sprint 4 — Performance**

17. Fix `MarkdownContentStorage` dirty-flag re-entrancy. Move `reparseText` call to `NSTextStorage.willProcessEditing` (or a `textContentStorageWillProcessEditing` delegate hook if available in TK2), and make `textContentStorage(_:textParagraphWith:)` unconditionally trust the pre-computed `cachedTypes`. Profile with a 5K-word note and rapid typing to confirm single-reparse-per-edit.
18. Add content-hash-keyed cache for `buildUtf8ToUtf16Map` in `applyInlineStyles`, co-located with `tokenCache`.
19. Serialize `commitIncrementalAdds` and `fullReload` in `MetalGraphView` through a single `DispatchSerialQueue` or `actor`. Add an in-flight flag that `fullReload` checks before re-uploading nodes that are mid-drain.
20. Profile graph churn scenario (1000-node graph, rapid note switching). Confirm no double-encode artifacts.
21. Run full test suite. Commit.

**Sprint 5 — Architecture (lower urgency, higher impact on future velocity)**

22. Extract `NoteAICommandRouter` from `handleAIContextMenuOperation` switch in `NoteDetailWorkspaceView`.
23. Extract `NoteEditorMetricsService` (word count + TOC debounce) as an `@Observable` or `ObservableObject`.
24. Consider extracting `NoteIdeasCoordinator` for the ideas panel + brain dump state.
25. Update `docs/plans/2026-03-08-textkit2-migration-design.md` with `[SUPERSEDED by TK2 production migration, 2026-03]` header.
26. Reconcile `docs/plans/2026-03-19-knowledge-core-ffi-plan.md` against `KnowledgeCoreBridge` implementation. Note deviations.

***

## Appendix: Explicitly Excluded / Deferred (Not Audited)

The following were observed in `AppBootstrap` and `GraphState` references but intentionally not audited per scope:

- `OrchestratorState`, `DeviceAgentService`, `DualBrainRouter`, `Screen2AXFusion`, `VisualVerifyLoop`, `AgentGraphMemory`, `RecipeGraphSkills`, `GhostBrainCoauthor`, `ReasoningLoopService` — all Omega/agent stack
- `MLXInferenceService`, `LLMService`, `TriageService`, `PipelineService`, `PreparedModelRegistry`, `LocalModelManager` — model-routing stack subject to upcoming 1B/3B/8B tier migration
- `KnowledgeFusion` references in `AppBootstrap` (e.g., `KnowledgeFusionViewModel.shared.ingestReasoningTraces`) — deferred

These should be the subject of the follow-up agent/model-stack audit pack after the new model tier is stabilized.

***

Here's the full audit. The **three highest-leverage items to act on immediately** are the `MarkdownContentStorage` double-reparse regression (affects every user on every keystroke), the `KnowledgeCoreBridge` nil-guard gaps (crash risk on Rust error paths), and the `pageBodyDidChange` background-thread notification delivery (potential main-thread state mutation from a background actor). Everything else in the fix-now column is mechanical and low-risk. The dead-twin file deletions (`TransclusionOverlayManager` v1, `BlockRefAutocomplete` v1) are the safest wins and should be done first to reduce CI noise.
<span style="display:none">[^1][^10][^11][^12][^13][^14][^15][^16][^17][^18][^19][^2][^20][^21][^22][^23][^24][^25][^26][^27][^28][^29][^3][^30][^4][^5][^6][^7][^8][^9]</span>

<div align="center">⁂</div>

[^1]: BackgroundGraphActor.swift

[^2]: EmbeddingService-2.swift

[^3]: GraphBuilder-6.swift

[^4]: FilterEngine-5.swift

[^5]: EntityExtractor-3.swift

[^6]: ExtractionTypes-4.swift

[^7]: GraphEngine-7.swift

[^8]: GraphState-8.swift

[^9]: GraphStore-9.swift

[^10]: SemanticClusterService-10.swift

[^11]: AppEnvironment-12.swift

[^12]: AppBootstrap-11.swift

[^13]: SDPage-13.swift

[^14]: VaultSyncService-14.swift

[^15]: NoteFileStorage-15.swift

[^16]: UIState-16.swift

[^17]: NotesUIState-17.swift

[^18]: NoteChatState-18.swift

[^19]: NoteDetailWorkspaceView-19.swift

[^20]: ProseEditorView-20.swift

[^21]: ProseEditorRepresentable2-21.swift

[^22]: ProseTextView2-22.swift

[^23]: MarkdownContentStorage-23.swift

[^24]: GraphBuilder-24.swift

[^25]: GraphEngine-25.swift

[^26]: GraphState-26.swift

[^27]: GraphStore-27.swift

[^28]: MetalGraphView-28.swift

[^29]: KnowledgeCoreBridge-29.swift

[^30]: lib-30.rs

