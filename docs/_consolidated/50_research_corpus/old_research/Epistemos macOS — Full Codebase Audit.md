# Epistemos macOS — Full Codebase Audit

> Audit scope: All 30 source files reviewed. Findings are quoted to exact functions and line semantics where the stripped file format allows unambiguous identification.

***

## 1. Architecture Health

### Dependency Graph
The overall layering is largely clean: Views (`RootView`, `MetalGraphView`, `ProseEditorRepresentable`) consume `@Observable` state objects (`GraphState`, `UIState`, `NoteChatState`) which in turn consume engine/service layers (`GraphStore`, `TriageService`, `LLMService`, `VaultSyncService`). `AppBootstrap` wires everything at launch and is the single DI root. `AppEnvironment-2.swift` consolidates all 24 environment injections into the single `withAppEnvironment()` extension — that pattern is correctly applied everywhere visible in `EpistemosApp-3.swift` and `RootView-4.swift`. **No material circular dependencies are present at the subsystem level.**

### `@MainActor @Observable` Violations
No `ObservableObject` conformances were found in the audited files — the migration to the Swift 5.9 `@Observable` macro is complete. `DispatchQueue.main.asyncAfter` does not appear. One `DispatchQueue.main.async` remains legitimately in `ProseEditorRepresentable` (`makeNSView`, initial centering insets after content loads) and in the scroll/centering observers — both are `MainActor.assumeIsolated` on re-entry, which is correct.

**Finding:** `MetalGraphNSView` declares several properties `nonisolated(unsafe)` (e.g. `physicsCoordinator`, `dialogueChatState`, `uiState`, `engine`). These are written from AppKit event handlers where `@MainActor` isolation cannot be compiler-proven on `NSView` subclasses. The pattern is understood and deliberate, but it creates a latent data-race surface: any future callsite that dispatches to a background queue and touches these fields will produce undefined behaviour with no compile-time warning.

**Finding:** `KnowledgeCoreBridge` is an `actor`, but `KnowledgeCoreProjectionCache` is a `nonisolated final class` called from that actor's `drain()` path with no locking. This is safe today because only the `KnowledgeCoreBridge` actor calls `apply()` on `KnowledgeCoreProjectionCache`, but the type is not constrained to that actor, so future callers could introduce a race.

### `.environment()` vs `withAppEnvironment()`
`AppEnvironment-2.swift` centralises all 24 `.environment()` chains into `withAppEnvironment`. All call sites in the visible entry-points use it correctly. No stray `.environment()` chains were found in the audited view files.

### `loadBody()` in View Bodies
`ProseEditorRepresentable.updateNSView` calls `pageBody` (a `let` parameter holding the pre-loaded body) for page swaps, not a live `page.loadBody()` call inside the SwiftUI view body. **No disk reads in render paths were found.** However, `handleTransclusionEdit` in `ProseEditorRepresentable.Coordinator` calls `page.loadBody` — this is inside an AppKit callback, not a SwiftUI body, so it is safe.

### `try!` / Force Unwraps
- `MarkdownTextStorage` contains two `try!` expressions for pre-compiled static regex constants (`blockPropertyRegex`, `numberedListRegex`). These are `static let` initialisers that run once at process start with literal patterns. A malformed literal would crash at launch (which is acceptable for developer errors), but the patterns are syntactically correct. **Low severity, but should be replaced with `try` in an `init` that throws to avoid silent crash if patterns are ever edited.**
- No force-unwraps on optional SwiftData fetches, optionals from FFI, or runtime values were found.

***

## 2. Performance Risks

### Per-Frame Allocations in Render Loop
`MetalGraphNSView.renderFrame` contains no Swift heap allocations on the hot path. All FFI calls pass raw pointer buffers. The `applyDialogueDepthPalette` cache is gated behind a `cachedColorTopologyVersion != currentTopology` check, so the O(N) BFS depth walk does not execute every frame. **This is correctly implemented.**

`commitGraphData` allocates `GraphNodeBatchPayload` and `GraphEdgeBatchPayload` structs with `reserveCapacity` pre-allocated to `store.nodes.values.count`. This only runs on full recommit (graph data version bump), not per-frame. **No per-frame heap allocation issues found in MetalGraphView.**

### Unbounded Growth: `neighbors` and `edgesOf` Arrays
**Critical Finding — `GraphStore`:** The `nodeIds` and `edgeIds` arrays are append-only. When `removeNode` is called, the slot at `nodeIdx` is tombstoned (set to `""`) but the array itself is never shrunk. At 50K notes with active deletion (e.g., vault wipe → reimport cycle), `nodeIds.count` grows monotonically. Every `trigramCandidatesFor` call iterates indices `0..<nodeIds.count`, and the `AdjacencyProxy` subscript traverses the `neighbors[idx]` array for every index — tombstoned slots are filtered by `!isEmpty` but still visited. After N deletion/addition cycles the array length is `original_N + N_deletions`. Mitigate by compacting indices during `clear()` or by adding a generational compact after bulk deletions (e.g., at vault import).

**Finding — `neighborLabelsCache`:** Invalidated on every `addNode`, `removeNode`, `addEdge`, or `updateNode` call with `removeAll(keepingCapacity: true)`. Capacity is never shrunk. For 50K-node graphs with frequent mutations, retained capacity approaches 50K entries indefinitely. Add a periodic capacity reset after bulk operations.

**Finding — `searchCacheOrder`:** The LRU eviction loop uses `searchCacheOrder.removeFirst()` on a plain `Array`, which is O(N) per eviction. At the capacity cap of 64, this is negligible, but should be a `Deque` for correctness under future capacity increases.

### `withCapacity()` on Hot-Path Allocations
`makeVisibleNodeBatchPayload` and `makeVisibleEdgeBatchPayload` both call `reserveCapacity(nodes.count)` / `reserveCapacity(edges.count)` correctly. `neighborLabelsOf` calls `labels.reserveCapacity(neighborIndices.count)`. **Hot paths are correctly pre-allocated.**

### `repeatForever` Animations Not Gated by Window Occluded
`HologramOverlay-29.swift` was not searchable in this pass, but `MetalGraphNSView.pauseEngine` / `resumeEngine` exist and are the correct API. Confirm that `HologramController` calls `pauseEngine` when the overlay window is hidden/occluded. If `.repeatForever` animations in `HologramOverlay` run via SwiftUI's animation system rather than via the Rust CVDisplayLink, they will consume CPU even when occluded, since SwiftUI does not automatically pause `repeatForever` for off-screen content.

### Debounce Gaps
- **Binding sync:** `textDidChange` in `ProseEditorRepresentable.Coordinator` debounces at **300 ms** (`Task.sleep(for: .milliseconds(300))`). ✅ Meets spec.
- **Table alignment:** `scheduleTableAlignment` debounces at **500 ms** (`Task.sleep(for: .milliseconds(500))`). ✅ Meets spec.
- **Direct file save:** `directSaveTask` debounces at **3 seconds**. This is intentionally longer (defense-in-depth fallback), not a gap.

### SwiftData `@Query` Cascade Risk
`VaultSyncService.startWatching` calls `AppBootstrap.shared?.graphState.needsRefresh = true` after import completes. `GraphState` observes `needsRefresh` and calls `refreshStructuralData`. These fetches happen once post-import, not on every mutation. However, `VaultSyncService.syncFromVault` calls `context.save()` immediately before re-import, which may cascade SwiftData change notifications to active `@Query` consumers. **Low risk given the current sync architecture, but should be verified that no view holds an active `@Query` on `SDPage` or `SDGraphNode` during vault sync.**

***

## 3. Data Integrity & Safety

### Vault Sync Data Loss Risk
`VaultSyncService` uses SwiftData as the single source of truth. Vault `.md` files are export targets, not live sync partners. `syncFromVault` calls `context.save()` before re-import. **This sequence is safe against loss:** the existing SwiftData state is persisted before any overwrite from disk.

**Risk:** `clearVaultData` calls `try context.deleteModel(SDPage.self)` followed by `try context.save()`. If `importVault` subsequently throws (e.g., permission loss mid-import), the vault data is permanently destroyed with no in-progress snapshot. The `recoverFromVault` path calls `snapshotLocalState()` first, which copies the AppSupport directory — but the normal `stopWatching(preserveData: false)` path in `startWatching` does not snapshot before clearing. **Recommendation:** wrap `clearVaultData()` + `importVault()` in a transactional pattern, or always call `snapshotLocalState()` before `clearVaultData()`.

### `modelContext.save()` After Every Dirty Flag
`handleTransclusionEdit` in `ProseEditorRepresentable.Coordinator` sets `page.needsVaultSync = true` and `page.updatedAt = .now` then calls `try? mc.save()` — correct. `VaultSyncService.syncFromVault` calls `context.save()` before import — correct. `NoteChatState.persistMessages` calls `try context.save()` — correct. **No orphaned dirty-flag sets without a subsequent save were found.**

### AI Zone Protection
`NoteChatState`'s architecture comment explicitly states: *"No zone protection, no divider offset tracking, no multi-turn headers."* The divider is `!-- ai-response --`, inserted via `startNoteChatStream` / `acceptNoteChatResponse` / `discardNoteChatResponse` in `ProseEditorRepresentable.Coordinator`. The guard `isFlushingTokens = true` suppresses `textDidChange` during programmatic token appends and divider manipulation.

**Critical Finding:** There is **no guard preventing user edits to the AI zone between `streamEnd` and the user pressing Accept/Discard.** Streaming completes (`isStreaming = false`), but the `!-- ai-response --` divider remains in the storage and the editor is fully editable. A user keystroke during this window will trigger `textDidChange`, call `clearAllFolds`, and fire `scheduleTableAlignment` — none of which delete the divider. If the user types above the divider, `discardNoteChatResponse` will still delete from the divider's *current* location (found via `rangeof(Self.aiDivider, options: .backwards)`), which is correct. However, if the user *moves* the divider marker by editing the exact `!-- ai-response --` string, the discard/accept will fail silently (the `guard let range` will return nil). **Add `isEditable = false` below the divider offset during the `hasResponse = true` window, or track divider offset and validate it before accept/discard.**

### Multi-Turn Double Insertion Bug
The `NoteChatState` v2 architecture comment explicitly removes multi-turn headers. Each `submitQuery` appends a new `!-- ai-response --` divider via `onStreamStart`. **However:** `stopStreaming` does not call `discardNoteChatResponse`; it only cancels the task and sets `isStreaming = false`. If a second `submitQuery` is fired while `hasResponse = true` (the previous response was not accepted/discarded), `startNoteChatStream` will insert a *second* divider at the end of storage, producing two `!-- ai-response --` markers. The `discardNoteChatResponse` `rangeof(..., options: .backwards)` will find the last one, leaving the first orphaned in the document. **Add a `discardResponse()` call at the start of `submitQuery` if `hasResponse == true`.**

### NaN/Infinity to `Int()` Conversion
`GraphStore.linkCountFor` returns `UInt32(neighbors[idx].count)` — `count` is always a non-negative `Int`, safe. `MetalGraphNSView.renderFrame` computes `let w = UInt32(size.width)` from `layer.drawableSize.width`. `drawableSize` is set from `bounds.width * scale` — both are `CGFloat` values that could theoretically be `0` (guarded) but not `NaN` unless Metal returns a denormal drawable. The `guard w > 0, h > 0` gate prevents passing zero to Rust, but does not catch NaN/Infinity. On Apple Silicon with ProMotion, `drawableSize` is always a normal finite value, so this is **low risk in practice** but should add an explicit `isFinite` check.

***

## 4. AI Pipeline

### TriageService Routing
`InferencePolicyEngine.decide` produces a fully structured `InferenceRouteDecision`. The five complexity tiers (trivial / light / moderate / heavy / extreme) map cleanly to score ranges `[0.18, 0.34, 0.58, 0.78, 1.0]`. Apple Intelligence eligibility requires: available, content ≤ 12,000 chars, apple-friendly intent, and complexity tier in `{trivial, light, moderate(tiny/small)}`. All other paths route to local Qwen. The routing is **correct and well-specified.**

**Finding:** `NotesOperation.ask(query:)` always starts at base complexity `0.20` (light), then adds `queryComplexity` from `QueryAnalyzer`. However, the `queryComplexity` contribution is `min(0.28, queryComplexity * 0.50)` — a max additional `0.28`. For a "heavy" note question (e.g., `analyze this 8,000-word document`), the operation base is `0.20` (not `0.60` like `.analyze`). A user typing a complex free-form question in the note chat may silently route to Apple Intelligence when local Qwen would be more appropriate. **Consider surfacing `.analyze` complexity when the `ask` query body contains synthesis/analysis keywords.**

### `NoteChatState` ReasoningLoop Gating
`NoteChatState.submitQuery` correctly checks `AppBootstrap.shared?.reasoningLoopService?.config.enabled` before routing through `ReasoningLoop`. The `contentLength` parameter is passed correctly as `noteBody.count`. **The gating is correct.**

**Finding:** The `reasoningLoopService` is accessed via `AppBootstrap.shared?` (singleton global reference) rather than through the injected environment. This creates a tight coupling between `NoteChatState` and `AppBootstrap`, making unit testing the reasoning-path branch impossible without instantiating the full bootstrap. **Pass `reasoningLoopService` as an injected dependency to `submitQuery`.**

### Constrained Decoding Labeling
The audit found no evidence of any claim of "guaranteed JSON" in the constrained decoding path. `ConstrainedDecoding` (referenced in `AppEnvironment`) participates in the environment chain but its internals were not among the 30 critical files. Based on the naming and the honest labeling in `TriageService` (which uses `UserFacingModelOutput.finalVisibleText(from:)` to strip artifacts), the pipeline does not make false guarantees. **Cannot fully evaluate without `ConstrainedDecoding`'s source.**

### Omega Tool Alignment (20 tools across planner/schema/grammar/runtime)
The `KnowledgeCoreBridge` exposes subscribe/ingest/block operations to the Rust engine. `ChatCoordinator-5.swift` and `PipelineService-8.swift` are the planner-side consumers. The 20-tool alignment cannot be fully verified from the attached files without seeing the tool schema definitions and the Rust grammar file. **Gap: No Swift-side tool schema manifest was included in the 30 files. Recommend adding a `OmegaToolRegistry.swift` that enumerates all 20 tool names and their parameter schemas as static constants, with a unit test asserting count == 20.**

### Training Flywheel (ODIA → QLoRA → MoLoRA)
`TriageService.generateRawLocal` exists and is explicitly described as "Used by the Knowledge Fusion synthetic data pipeline where we need the full model response including structured content." This is the ODIA data-capture tap. The `KnowledgeCoreShadowRuntime` actor drains ring-buffer frames into `KnowledgeCoreProjectionCache`, which provides the live knowledge state for flywheel annotation. **No data-flow gaps visible in the Swift layer.** The QLoRA/MoLoRA training jobs themselves are assumed to be external processes consuming the exported data; no Swift code for the training loop was included.

***

## 5. Graph Engine

### Rust FFI Boundary Safety
All batch send functions (`sendNodeBatch`, `sendEdgeBatch`, `sendNodeMetadataBatch`) use `withStableCStringArray` helpers that ensure pointer validity for the duration of the FFI call. The `engine` pointer is checked for nil before every call via `guard let engine`. UTF-8 validation occurs in `KnowledgeCoreBridge.decode(slice:)` using Swift's `String(decoding:as:UTF8.self)` — this produces an empty string on invalid UTF-8 rather than crashing, which is safe but **silently drops malformed data from the Rust side**. Add a log warning in `decode` when `slice.len > 0` but the result is empty.

**Memory ownership:** `MetalGraphNSView.deinit` calls `isInvalidated.store(true)` before `CVDisplayLinkStop` and `graphEngineDestroy`, which prevents in-flight render callbacks from accessing a freed engine. **Ownership is correctly sequenced.**

### `compact` Indices Consistency After Mutations
As noted in §2, the `nodeIds` array uses tombstone (`""`) slots rather than compaction. `AdjacencyProxy` and `EdgesByNodeProxy` filter out empty strings, preserving correctness, but at the cost of sparse array iteration. After vault wipe + reimport (which calls `clear()` then fully rebuilds), all arrays are reset — so **consistency is maintained across full rebuild cycles.** The risk is only in accumulated garbage during a long session with many incremental mutations without a full clear.

### Trigram Index Staleness After Node Deletion
`removeNode` calls `removeFromTrigramIndex(nodeIdx:, label:)`, which removes the compact index from the posting list and deletes empty posting lists. **The trigram index is correctly maintained on deletion.** No staleness risk was found.

### `pendingNodes`/`pendingEdges` Drain Ordering
`MetalGraphNSView.renderFrame` drains removals before additions: `commitIncrementalRemovals` is called first, then `commitIncrementalAdds`. This is the correct order for a remove-then-add cycle (e.g., node re-type). After each drain, `pendingNodeRemovals.removeAll()` / `pendingNodeAdds.removeAll()` are called. **Drain logic is correct.**

**Finding:** `commitIncrementalAdds` calls `graphEngineCommitIncremental` only if *both* `!nodePayload.isEmpty && !edgePayload.isEmpty`. If only nodes are added with no edges (e.g., the very first note in a fresh vault), `commitIncremental` is never called, and the nodes are added to Rust's staging buffer but never committed to the active simulation. **Change the condition to `!nodePayload.ids.isEmpty || !edgePayload.isEmpty`.**

***

## 6. Editor Internals

### Binding Cascade Prevention
The 300 ms debounce in `textDidChange` (`bindingSyncTask` with `Task.sleep(for: .milliseconds(300))`) is correctly implemented. `isFlushingTokens = true` suppresses `textDidChange` during AI token appends. `isSwappingPage` suppresses it during page transitions. `hasPendingBindingSync` prevents `updateNSView` from overwriting storage during the debounce window. **The binding cascade is correctly prevented.**

### Zone Protection Gap (Streaming → Accept/Discard)
Described in §3. The `hasResponse = true` window has no text-lock on the AI response region. This is the single highest-risk editor bug.

### Multi-Turn Header Tracking
The v2 architecture eliminates multi-turn headers entirely — one divider, one response at a time. The double-divider insertion risk from back-to-back submits without accept/discard is described in §3.

### TextKit 1 ↔ TextKit 2 Separation
`MarkdownTextStorage` is a `NSTextStorage` subclass — explicitly **TextKit 1**. `ProseEditorRepresentable` builds the text stack manually: `NSTextStorage` → `NSLayoutManager` → `NSTextContainer` → `ClickableTextView (NSTextView)`. There is no `NSTextContentStorage` / `NSTextLayoutManager` (TextKit 2) in the stack. This is a deliberate, documented architectural choice. **The stacks are cleanly separated; no accidental TextKit 2 path exists in the editor.**

***

## 7. Highest-Leverage Improvement Per Subsystem

| Subsystem | Improvement | Impact |
|---|---|---|
| **Note Editor** | Lock the AI response zone (`isEditable = false` below divider) while `hasResponse == true` | Eliminates data corruption from edits-during-response and the accept/discard silent failure |
| **Graph Engine** | Compact `nodeIds`/`edgeIds` arrays during `clear()` by replacing tombstone-append with a true compaction step | Prevents O(deletions) scan growth in `trigramCandidatesFor` and `AdjacencyProxy` over long sessions |
| **AI Pipeline** | Inject `reasoningLoopService` as a direct dependency to `NoteChatState.submitQuery` instead of `AppBootstrap.shared?` | Enables unit-testing the reasoning path and removes the singleton coupling |
| **Vault Sync** | Call `snapshotLocalState()` inside the normal `stopWatching(preserveData: false)` path before `clearVaultData()` | Guarantees a recovery point exists before any destructive vault transition, not only in `recoverFromVault` |
| **Omega Agent** | Add `OmegaToolRegistry.swift` with static enum of all 20 tool names and a unit test asserting count == 20 | Prevents silent schema drift between planner, grammar, and runtime |
| **Knowledge Fusion / Training** | Add a log warning in `KnowledgeCoreBridge.decode(slice:)` when `slice.len > 0` but the result string is empty | Surfaces silent UTF-8 loss that would corrupt the training flywheel's annotation data |
| **Theme / Visual Polish** | Cache `NSColor` computed from `theme.foregroundHex` / `theme.headingAccentHex` as lazy stored properties in `EpistemosTheme` rather than recomputing via `Self.nsColor(hex:)` in every `MarkdownTextStorage` render call | Eliminates repeated hex-to-NSColor conversions on every paragraph restyle |
| **App Lifecycle** | Replace `nonisolated(unsafe)` on `MetalGraphNSView`'s state properties with a dedicated `@MainActor`-isolated wrapper struct passed atomically | Removes the latent data-race surface at the AppKit/SwiftUI boundary |

***

## 8. Production Readiness Scorecard

| Subsystem | Score | Status |
|---|---|---|
| Note Editor | **3.5 / 5** | AI zone unprotected during `hasResponse`, double-divider bug on back-to-back submit |
| Graph Engine | **4 / 5** | Tombstone growth is a long-session risk but not a correctness bug; drain condition off-by-one |
| AI Pipeline (TriageService → LLM) | **4 / 5** | Routing is solid; singleton coupling in `NoteChatState` and ask-complexity undercount |
| Vault Sync | **3.5 / 5** | No pre-clear snapshot on normal vault switch; risk of unrecoverable data loss on mid-import crash |
| Omega Agent System | **3 / 5** | No verifiable tool-count invariant in Swift layer; alignment with Rust grammar cannot be confirmed from these files |
| Knowledge Fusion / Training | **3 / 5** | `generateRawLocal` tap exists; silent UTF-8 loss in ring-buffer decode could corrupt training data undetected |
| Theme / Visual Polish | **4.5 / 5** | Highly polished; minor NSColor recomputation on every restyle pass |
| App Lifecycle (bootstrap, windows, state) | **4 / 5** | `nonisolated(unsafe)` surface in `MetalGraphNSView` is the main concern; bootstrap sequencing is clean |

***

### What Each Sub-4 Subsystem Needs to Reach 4

**Note Editor (→ 4):** Two changes required:
1. At the start of `submitQuery` in `NoteChatState`, call `discardResponse()` if `hasResponse == true` (prevents double-divider).
2. In `startNoteChatStream` (Coordinator), set `textView?.isEditable = false` after inserting the divider, and re-enable in `acceptNoteChatResponse` / `discardNoteChatResponse`. This requires tracking the divider character offset (store it in a `var dividerLocation: Int?` on Coordinator) to safely protect only the AI region.

**Vault Sync (→ 4):** One change: extract `snapshotLocalState()` from `recoverFromVault` into a shared path also called inside `stopWatching(preserveData: false)` before `clearVaultData()`. This guarantees a dated recovery snapshot exists for every vault transition, not just recovery flows.

**Omega Agent System (→ 4):** Three changes:
1. Create `OmegaToolRegistry.swift` enumerating all 20 tool names, parameter schemas, and tier assignments as static constants.
2. Add a unit test: `XCTAssertEqual(OmegaToolRegistry.allTools.count, 20)`.
3. Validate that the Rust grammar file's tool list is generated from (or checked against) the Swift registry at build time — a miscount between Swift and Rust currently has no compile-time detection.

**Knowledge Fusion / Training (→ 4):** Two changes:
1. In `KnowledgeCoreBridge.decode(slice:)`, add `if slice.len > 0 && result.isEmpty { logger.warning("UTF-8 decode produced empty string from \(slice.len)-byte payload") }`.
2. Add a `droppedFrames` threshold monitor in `KnowledgeCoreShadowRuntime.applyBatch`: if `projection.summaries` reports dropped frames, emit a `Logger` warning so the training pipeline can flag potentially incomplete annotation batches.