# Epistemos — Master Remediation Checklist

> Cross-referenced from **5 audit documents** + independent source verification on March 25, 2026.
> Each item is tagged with its source audit(s), current status, and priority tier.

---

## Status Legend

- ✅ **DONE** — Verified in source code
- 🔧 **DO NOW** — Blocking launch or causing active bugs
- ⚠️ **DO SOON** — Architectural debt, correctness risk, or perf regression
- 📋 **DO LATER** — Polish, defense-in-depth, or future-proofing

---

## TIER 1 — TK1 Deletion (Blocking Full Migration)

These are the remaining steps to fully remove TextKit 1 from the binary. The active editor path is already clean, but these files still compile.

| # | Item | Status | Source | Notes |
|---|------|--------|--------|-------|
| 1 | Delete `ProseEditorRepresentable.swift` from Xcode target, verify build | 🔧 | All 5 audits | 66KB TK1 coordinator wrapping ClickableTextView + PageStoragePool. No callers in production path. Deletion is the compile-time proof. |
| 2 | Delete `ClickableTextView.swift` from Xcode target, verify build | 🔧 | All 5 audits | 51KB NSTextView subclass for TK1. Should compile clean after #1. |
| 3 | Delete `PageStoragePool.swift` from Xcode target, verify build | 🔧 | All 5 audits | 10KB singleton. No callers remain after hardening pass cleaned all 5 production files. |
| 4 | Delete `MarkdownTextStorage.swift` — migrate shared style constants first | ⚠️ | Hardening Audit §3 | Still used as shared style-constant provider (`headingParagraphStyle`, `bodyParagraphStyle`). Must extract to a shared `MarkdownStyleConstants` struct that both TK1 deletion and MarkdownContentStorage (TK2) can use. Then delete. |
| 5 | Collapse `NotePreviewRenderer` enum — delete `.textKit1` case | ⚠️ | My audit, TK1 Migration Audit | `resolved()` discards the parameter and always returns `.textKit2`. The `.textKit1` case is dead code. Simplify or remove the enum entirely. |
| 6 | Simplify `NotePreviewDisplay.renderedMarkdown` | ⚠️ | My audit | The heading transformation branch (`guard renderer == .textKit1 else { return markdown }`) is dead. The function can be deleted or simplified to a passthrough. |
| 7 | Delete `useTK2Editor` flag from `NotesUIState` + all call sites | ⚠️ | My audit, Hardening Audit | The setter snaps back to `true`, and `resolved()` ignores it. Pure ceremony. Remove the flag, the didSet, the UserDefaults key, and all consumers. |
| 8 | Verify `MarkdownContentStorage` (TK2 delegate) calls shared `MarkdownTextStorage.headingParagraphStyle` | ⚠️ | Hardening Audit NBK-7 | If it duplicates the constants internally, a visual regression on H2/H3 spacing is possible. Build + visual test required. |
| 9 | Update `ProseEditorView` header comment describing TK1 `PageStoragePool` architecture | 📋 | Hardening Audit §3 | Documentation-only. The MARK comment still describes the old data flow. |
| 10 | Full-repo `grep` sweep after deletion: `ClickableTextView`, `PageStoragePool`, `MarkdownTextStorage`, `ProseEditorRepresentable[^2]` | 🔧 | My audit | Final straggler check. Do this after steps 1-4. |
| 11 | Run full test suite including `TK1MigrationValidationTests` | 🔧 | My audit | Gate merge on green tests after all deletions. |

**Already done (confirmed in source):**
- ✅ Active editor path pinned to TK2 unconditionally (ProseEditorView → ProseEditorRepresentable2)
- ✅ `useTK2Editor` snap-back setter prevents disabling
- ✅ `NotePreviewRenderer.resolved()` unconditionally returns `.textKit2`
- ✅ `NoteEditorViewFinder` only resolves `ProseTextView2` (hard type guard)
- ✅ All 5 `ClickableTextView` notification subscriptions migrated to `ProseTextView2` names
- ✅ `PageStoragePool.shared` removed from NoteDetailWorkspaceView, MiniChatView, NotesSidebar, AppBootstrap
- ✅ `NotePreviewView` (TK1 struct) deleted from NoteDetailWorkspaceView
- ✅ `NoteOutlineOverlay` ternary fixed (no longer references `PageStoragePool`, uses `tocItems` directly)
- ✅ `PageStoragePool` pre-warm removed from AppBootstrap
- ✅ TK1MigrationValidationTests cover text-presence regressions for 8 critical patterns
- ✅ NoteEditorViewFinderTests verify TK2 resolution and generic NSTextView rejection

---

## TIER 2 — Note Editor (Active Bugs & Zone Protection)

| # | Item | Status | Source | Notes |
|---|------|--------|--------|-------|
| 12 | AI zone protection: verify response body below divider is editable-but-safe | ✅ DONE | Hardening Audit NBK-2 | `shouldChangeText` blocks edits touching the `<!-- ai-response -->` marker when `hasProtectedInlineResponseDivider == true`. Text below the divider is intentionally editable (user can fix AI typos). The divider guard is correct and minimal. |
| 13 | Double-divider prevention on back-to-back `submitQuery` | ✅ DONE | Full Codebase Audit §6, Hardening Audit NBK-1 | `replacePendingResponseIfNeeded()` calls `discardResponse()` before any new submission. |
| 14 | `stopWatching` snapshot failure: `catch` block swallows error and proceeds to `clearVaultData` | ⚠️ | Hardening Audit NBK-3 | If snapshot fails (disk full), data is destroyed without user alert. Surface the error before clearing, or abort the clear. |
| 15 | TK2 viewport scroll jitter on rapid scrolling of large documents | 📋 | TK1 Migration Audit | Framework-level behavior (TextKit 2 block-based height estimation). Document internally as expected system behavior, not a fixable bug. Cannot be resolved in application code — Apple must fix. |
| 16 | Confirm `MarkdownContentStorage` uses shared heading paragraph styles (TK2 heading parity) | ⚠️ | Hardening Audit NBK-7 | If MarkdownContentStorage duplicates style constants, H2/H3 spacing will diverge from TK1 baseline. Visual test required. |

---

## TIER 3 — Graph Engine

| # | Item | Status | Source | Notes |
|---|------|--------|--------|-------|
| 17 | `GraphStore` tombstone compaction: `nodeIds`/`edgeIds` grow monotonically | ⚠️ | Full Codebase Audit §2, Refactoring Plan Part III | After N deletion/addition cycles, arrays accumulate tombstones. `trigramCandidatesFor` and `AdjacencyProxy` iterate all slots including tombstones. Implement generational compaction after bulk deletions or when tombstone ratio exceeds threshold (e.g., 15%). |
| 18 | `neighborLabelsCache` capacity never shrunk | 📋 | Full Codebase Audit §2 | `removeAll(keepingCapacity: true)` retains capacity indefinitely. Add periodic capacity reset after bulk operations. |
| 19 | `commitIncrementalAdds` condition: `&&` should be `||` | 🔧 | Full Codebase Audit §5 | `commitIncremental` only fires if *both* nodePayload AND edgePayload are non-empty. First note in a fresh vault (nodes with no edges) silently fails to commit. Change to `!nodePayload.ids.isEmpty || !edgePayload.isEmpty`. |
| 20 | `searchCacheOrder.removeFirst()` is O(N) on Array | 📋 | Full Codebase Audit §2 | At capacity cap of 64, negligible. Switch to `Deque` for correctness under future capacity increases. |

**Already confirmed correct:**
- ✅ MetalGraphNSView.renderFrame: no per-frame heap allocations
- ✅ Batch send functions use `reserveCapacity` correctly
- ✅ Trigram index correctly maintained on deletion (`removeFromTrigramIndex` called in `removeNode`)
- ✅ `commitIncrementalRemovals` called before `commitIncrementalAdds` (correct drain order)
- ✅ FFI pointer validity ensured via `withStableCStringArray`

---

## TIER 4 — AI Pipeline

| # | Item | Status | Source | Notes |
|---|------|--------|--------|-------|
| 21 | `NoteChatState`: inject `reasoningLoopService` as dependency instead of `AppBootstrap.shared?` | ⚠️ | Full Codebase Audit §4 | Singleton coupling makes unit testing the reasoning path impossible. Pass as injected dependency. |
| 22 | `NotesOperation.ask(query:)` complexity base too low for complex queries | 📋 | Full Codebase Audit §4 | Base complexity `0.20` (light). Complex free-form analysis questions may misroute to Apple Intelligence when local Qwen is more appropriate. Consider detecting synthesis/analysis keywords to bump complexity. |
| 23 | `ConstrainedDecodingService` still declared unavailable (soft guidance only) | ⚠️ | Hardening Audit NBK-8 | Grammar is compiled but `isAvailable == false`. Omega planning output is unconstrained in production. The grammar compiler is correct code shipping with no effect. This is honestly labeled, but means tool-call parse failures remain possible. |

**Already confirmed correct:**
- ✅ TriageService routing with 5 complexity tiers correctly specified
- ✅ `NoteChatState.submitQuery` correctly gates ReasoningLoop behind config check
- ✅ Binding cascade correctly debounced at 300ms in `textDidChange`
- ✅ Table alignment debounced at 500ms

---

## TIER 5 — Vault Sync

| # | Item | Status | Source | Notes |
|---|------|--------|--------|-------|
| 24 | `clearVaultData` + `importVault` transactional safety | ⚠️ | Full Codebase Audit §3 | If `importVault` throws after `clearVaultData`, vault data is permanently destroyed. Wrap in transactional pattern, or always snapshot before clearing. |
| 25 | Implement Write-Ahead Logging (WAL) for sync batches | 📋 | Refactoring Plan Part IV | Current sync relies on UI-bound undo manager for rollback. WAL + background ModelActor eliminates rollback gap. Major architectural change — schedule for v2. |
| 26 | Move heavy sync I/O to background `ModelActor` | 📋 | Refactoring Plan Part IV | Currently saturates main thread via @Query macros during background syncs. ModelActor offloads parsing/insertion to background thread. |
| 27 | Verify no active `@Query` on `SDPage` during vault sync | ⚠️ | Full Codebase Audit §2 | `VaultSyncService.syncFromVault` calls `context.save()` before reimport, which may cascade change notifications to active `@Query` consumers. Low risk but should be verified. |

**Already confirmed correct:**
- ✅ `stopWatching(preserveData: false)` calls `snapshotLocalState()` before `clearVaultData()`
- ✅ `modelContext.save()` called after every dirty flag mutation (no orphaned dirty flags found)

---

## TIER 6 — Omega Agent System

| # | Item | Status | Source | Notes |
|---|------|--------|--------|-------|
| 28 | Add unit test: `XCTAssertEqual(OmegaToolRegistry.allTools.count, 20)` | ⚠️ | Full Codebase Audit §4, Hardening Audit NBK-4 | Registry is correct and single-source-of-truth, but no compile-time or test-time count invariant exists. Prevents silent schema drift. |
| 29 | Validate Rust grammar tool list is generated from (or checked against) Swift registry at build time | ⚠️ | Full Codebase Audit §7 | A miscount between Swift and Rust currently has no compile-time detection. |
| 30 | Implement real logit-level grammar constraints when ConstrainedDecodingService is available | 📋 | Refactoring Plan Part V, Comprehensive Audit §4 | Requires fully constraining generator, not just soft EOS penalties. Major inference infrastructure work. |
| 31 | Make all MCP tool endpoints strictly idempotent | 📋 | Refactoring Plan Part V | Agent retry loops can fire write-operations twice. Idempotency prevents duplication. |
| 32 | Add middle-layer validator for harmless type coercion before tool runtime | 📋 | Refactoring Plan Part V | If agent passes `1` instead of `"1"`, coerce silently instead of crashing. |

**Already confirmed correct:**
- ✅ `OmegaToolRegistry.all` is single source of truth for all 20 tools
- ✅ `ToolSchemaGrammar` calls `OmegaToolRegistry.agentFor(toolName:)` — no separate hardcoded lists
- ✅ No "guaranteed JSON" false advertising — honestly labeled as soft guidance

---

## TIER 7 — Knowledge Fusion / Training

| # | Item | Status | Source | Notes |
|---|------|--------|--------|-------|
| 33 | `KnowledgeCoreBridge.decode(slice:)`: add log warning when `slice.len > 0` but result is empty | ⚠️ | Full Codebase Audit §5 | `String(decoding:as:UTF8.self)` produces empty string on invalid UTF-8. Silent data loss corrupts training flywheel annotation data. |
| 34 | `KnowledgeCoreShadowRuntime.applyBatch`: add `droppedFrames` threshold monitor | 📋 | Full Codebase Audit §7 | Emit Logger warning when `projection.summaries` reports dropped frames so training pipeline can flag incomplete annotation batches. |
| 35 | ODIA telemetry: capture graph engine spatial state at moment of user correction | 📋 | Comprehensive Audit §4, Refactoring Plan Part V | QLoRA pipeline currently only sees terminal text output, never the underlying node connectivity. Limits spatial reasoning fine-tuning. |
| 36 | Local LLM finetuning: migrate from LoRA to QLoRA with NF4 | 📋 | Refactoring Plan Part VI | Standard LoRA crashes on <32GB machines. QLoRA with 4-bit NormalFloat reduces memory footprint while preserving 16-bit task performance. |

**Already confirmed correct:**
- ✅ `TriageService.generateRawLocal` exists as ODIA data-capture tap
- ✅ `KnowledgeCoreShadowRuntime` drains ring-buffer frames into projection cache
- ✅ ask(query:) undercount is correct behavior (semantic deduplication filter, not a bug)

---

## TIER 8 — Theme, Visual Polish & App Lifecycle

| # | Item | Status | Source | Notes |
|---|------|--------|--------|-------|
| 37 | Cache `NSColor` from theme hex as lazy stored properties in `EpistemosTheme` | 📋 | Full Codebase Audit §7 | Eliminates repeated `nsColor(hex:)` conversions on every paragraph restyle in MarkdownTextStorage. |
| 38 | `HologramOverlay` `repeatForever` animation: confirm gated by window occluded | ⚠️ | Full Codebase Audit §2 | `MetalGraphNSView.pauseEngine`/`resumeEngine` exist. Confirm `HologramController` calls `pauseEngine` when overlay hidden. If `.repeatForever` runs via SwiftUI animation system, it consumes CPU even when off-screen. |
| 39 | `PulseAnimationModifier` (line 44): gate `repeatForever` by `windowOccluded` | ⚠️ | Comprehensive Audit §2 | Continuous hidden background rendering drains battery and monopolizes GPU cycles. |
| 40 | `MetalGraphNSView` `nonisolated(unsafe)` properties: replace with `@MainActor`-isolated wrapper struct | 📋 | Full Codebase Audit §1, §7 | Latent data-race surface at AppKit/SwiftUI boundary. No race today (only AppKit event handlers touch them), but future background callers would produce undefined behavior with no compile-time warning. |
| 41 | `KnowledgeCoreProjectionCache`: constrain to `KnowledgeCoreBridge` actor | 📋 | Full Codebase Audit §1 | Currently a `nonisolated final class` called from actor's `drain()` path. Safe today, but unconstrained type allows future callers to introduce races. |
| 42 | `MetalGraphNSView.renderFrame`: add explicit `.isFinite` check on `drawableSize` before `UInt32()` cast | 📋 | Full Codebase Audit §3 | Existing `guard w > 0, h > 0` doesn't catch NaN/Infinity. Low risk on Apple Silicon but defensive. |

**Already confirmed correct:**
- ✅ `withAppEnvironment()` consolidation complete — no stray `.environment()` chains
- ✅ `@Observable` migration complete — no `ObservableObject` conformances remain
- ✅ `DispatchQueue.main.asyncAfter` eliminated
- ✅ No `try!` or force-unwraps on runtime values in production paths
- ✅ Bootstrap sequencing is clean

---

## Invalidated Findings (Do NOT allocate resources)

These were investigated across the audits and confirmed to be non-issues:

| Finding | Why Invalidated | Source |
|---------|-----------------|--------|
| Incremental-adds commit bug | Intentional LSM-tree debouncing. Correct by design. | Refactoring Plan Part I |
| `ask(query)` undercount | Post-retrieval semantic deduplication filter. Correct by design. | Refactoring Plan Part I |
| UTF-8 empty string FFI corruption | Upstream SwiftUI TextField anomaly, not FFI boundary issue. Bridging layer is sound. | Refactoring Plan Part I |
| Minor cache eviction oscillations | Correct NSCache integration with macOS `vm_pressure` heuristics. Overriding would violate Apple memory guidelines. | Refactoring Plan Part I |
| `liveNoteEditorRemainsPinnedToTK2Stack` test logic bug | Test checks `"ProseEditorRepresentable("` (with trailing paren). `"ProseEditorRepresentable2("` does NOT contain this substring. Test is correct. | My independent audit |
| `NotePreviewRenderer.resolved()` runtime reachability risk | Function discards its parameter with `_ = useTK2Editor` and unconditionally returns `.textKit2`. Cannot return `.textKit1` regardless of input. | My independent audit |
| Circular dependency between NoteViewModel and GraphEngineState | Not found in audited files. Full Codebase Audit confirmed dependency graph is acyclic at subsystem level. | Full Codebase Audit §1 vs. Comprehensive Audit §1 |
| `loadBody()` called inside SwiftUI view body | Not found. `ProseEditorRepresentable.updateNSView` uses pre-loaded `pageBody` parameter. | Full Codebase Audit §1 |

---

## Recommended Execution Order

**Sprint 1 — TK1 Hard Deletion (items 1-4, 10-11)**
Remove files from build target one at a time, verify build after each. This is the single highest-leverage work — it eliminates 130KB+ of dead code and removes the last TK1 compile-time dependency. End with full-repo grep and green test suite.

**Sprint 2 — Active Bug Fixes (items 5-7, 14, 19)**
Clean up dead enum cases, remove vestigial flags, fix the `commitIncrementalAdds` `&&`→`||` condition, and surface the `stopWatching` snapshot error. These are small, high-impact fixes.

**Sprint 3 — Defensive Hardening (items 8, 16, 21, 23, 28-29, 33, 38-39)**
Heading parity verification, dependency injection for testability, tool registry unit tests, UTF-8 decode logging, and animation gate checks. These prevent future regressions.

**Sprint 4 — Architectural Improvements (items 17, 24-27, 30-32, 34-37, 40-42)**
Tombstone compaction, vault sync WAL, constrained decoding, QLoRA migration, NSColor caching, and actor isolation. These are larger efforts that improve long-term health.
