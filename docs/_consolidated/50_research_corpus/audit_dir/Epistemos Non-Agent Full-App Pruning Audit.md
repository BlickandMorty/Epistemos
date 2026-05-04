# Epistemos Non-Agent Full-App Pruning Audit
**Scope:** Batch 1 (App Lifecycle, Core Services, Engine) — adversarial quality audit
**Date:** March 26, 2026
**Status:** Current codebase — green build assumed, TK1 migration complete
**Excluded:** Omega stack, KnowledgeFusion, model-routing/inference tier, deferred AI stack

***

## Executive Summary

The codebase is architecturally sound at the macro level. The TK1 → TK2 migration appears complete with no remnant production TK1 files visible in the audited batches. The Bootstrap/Coordinator/ChatCoordinator decomposition is well-executed. The FFI surface is carefully managed with correct lifetime control for C strings. However, there are four confirmed bugs (one FFI, one persistence, one UI, one dead enum value), several performance risks that compound at vault scale, and a meaningful amount of dead-weight from the Omega stack that bleeds into non-agent paths. The highest-leverage cleanup opportunities are concentrated in `ChatCoordinator.swift`, `NoteInsightService.swift`, `KnowledgeCoreBridge.swift`, and `AppBootstrap.swift`.

***

## Section 1: Highest-Value Findings

### 1.1 — CONFIRMED BUG: `BlockEditTranslator.updateBlock` bypasses `initialized` guard

**File:** `Epistemos/Engine/BlockEditTranslator.swift`
**Severity:** High — latent FFI crash / Rust UB

`updateBlock` is declared `static` and calls `graph_engine_btk_update_block(engine, pageIdPtr, buf.baseAddress, contentPtr)` directly. It never checks the `initialized` instance flag on `BlockEditTranslator`. This means any caller with a valid engine handle can invoke a BTK update for a page that was never initialized via `graph_engine_btk_init` / `graph_engine_btk_load_blocks`. On the Rust side, an update to an unregistered page ID is undefined behavior depending on how the BTK handles unknown page IDs — at best a no-op, at worst a panic or memory corruption.

**Fix:** Add a pre-condition check or convert `updateBlock` to an instance method so the `initialized` flag is accessible.

***

### 1.2 — CONFIRMED BUG: `AppCoordinator.saveDailyBrief` fallback path skips vault persistence

**File:** `Epistemos/App/AppCoordinator.swift` — `saveDailyBrief(content:)`
**Severity:** High — silent data loss on vault write failure

When `vaultSync.createPage` returns `nil` (vault write failure or no vault attached), the fallback path creates an `SDPage` in the SwiftData context and calls `BlockMirror.sync`, but never writes the note to the vault folder on disk. The note exists in the SwiftData database only, which means it is invisible to Spotlight, missing from the VaultManifest, and will not appear in vault-backed search. Additionally, the `Task { }` wrapping the vault path runs without `[weak self]` — a potential retain cycle if `AppCoordinator` is torn down during the async op.

**Fix:** The fallback path should either write to disk via `NoteFileStorage.writeBody` or propagate the failure clearly to the UI. The bare `Task { }` should capture `self` weakly.

***

### 1.3 — CONFIRMED BUG: `EpistemosCommands` duplicates "New Mini Chat" with conflicting shortcuts

**File:** `Epistemos/App/EpistemosApp.swift` — `EpistemosCommands.body`
**Severity:** Medium — duplicate menu item, shortcut conflict risk

`EpistemosCommands` declares "New Mini Chat" twice:

1. `CommandGroup(after: .sidebar)` → `.keyboardShortcut("3", modifiers: .command)`
2. Later group → `.keyboardShortcut("m", modifiers: [.command, .shift])`

Both create distinct `Button("New Mini Chat")` entries that appear in the same macOS menu. Two menu items doing the same thing is a UX defect and a maintenance hazard.

**Fix:** Remove one of the two entries. Canonical shortcut is Cmd+3 (aligns with the sidebar group numbering), so remove the Cmd+Shift+M duplicate.

***

### 1.4 — CONFIRMED BUG: `DataDetectionService.open(.date)` opens stale URL scheme

**File:** `Epistemos/Engine/DataDetectionService.swift` — `open(_ item:)` switch `.date` branch
**Severity:** Medium — silently broken UX for date tap action

```swift
case .date:
    if let calendarURL = URL(string: "x-apple-calevent://")
        ?? URL(string: "webcal://") {
        NSWorkspace.shared.open(calendarURL)
    }
```

`x-apple-calevent://` opens Calendar app but with no event pre-selected — it is effectively just "open Calendar." The correct behavior for a detected date is to either open Calendar with a new event pre-populated for that date, or do nothing and show a contextual menu. The current implementation is a stub masquerading as a working feature.

**Fix:** Either implement `calshow://` with a timestamp parameter to jump to the date, or remove the date case's action body and leave it as a no-op until properly implemented.

***

### 1.5 — CONFIRMED DEAD ENUM VALUE: `KnowledgeCoreSubscriptionKind.links` with no `subscribeLinks` method

**File:** `Epistemos/Engine/KnowledgeCoreBridge.swift`
**Severity:** Medium — API inconsistency, false promise in public type

`KnowledgeCoreSubscriptionKind` declares four cases: `.outline`, `.tasks`, `.properties`, `.links`. The bridge exposes `subscribeOutline`, `subscribeTasks`, and `subscribeProperties` — but no `subscribeLinks`. The `.links` case is therefore unreachable via the Swift API. Any code that tries to handle `.links` payloads from `drainPayloads` will receive responses that can never be produced.

**Fix:** Either implement `subscribeLinks(pageId:)` wrapping `graph_engine_kc_subscribe_links`, or remove the `.links` case and update all switch exhaustiveness guards.

***

## Section 2: Subsystems That Are Cleaner Than Expected

### 2.1 — `BlockEditTranslator` FFI lifetime management (aside from bug #1.1)

The instance path (`initIfNeeded`, `translateEdit`) correctly manages `strdup`/`free` pairs in lockstep with the `ffiBlocks` array. The pattern of building `cStrings` separately and freeing after the FFI call is correct and avoids use-after-free. UUID → 16-byte tuple expansion is verbose but correct and type-safe.

### 2.2 — `Keychain.swift`

Clean, minimal, well-commented. The update-before-add pattern is correct. Use of `kSecUseDataProtectionKeychain` avoids legacy ACL dialogs. `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` is an appropriate accessibility level for this app. No issues except the minor migration re-run concern (§4.4).

### 2.3 — `DataDetectionService.detect` / `detectAsync` (core detection path)

The synchronous `detect(in:)` correctly uses `items.reserveCapacity(16)`, does range bounds validation before accessing `NSTextStorage`, and runs `NSDataDetector` with the minimal necessary checking types. The `detectAsync` path correctly uses `Task.detached(priority: .utility)` to keep the main actor free during long scans.

### 2.4 — `AmbientManifestRefreshDriver` actor

The `while/pendingRefresh` pattern in `AmbientManifestRefreshDriver` is a clean solution to the coalescing problem: concurrent vault-change events serialize through the actor and only one extra refresh fires after the in-progress one completes. No issues.

### 2.5 — `QueryCompiler.swift`

Complete, correct, and compact. All `QueryAST` cases are handled. `makeDateFilter` is appropriately simplified. No dead branches, no missing cases.

### 2.6 — `SystemAppearanceObserver.swift`

The observation of `AppleInterfaceThemeChangedNotification` on `DistributedNotificationCenter` is the correct macOS API for appearance changes. The `stop()` method correctly cleans up both tokens. The space-change subscription is redundant (see §4.2) but harmless.

### 2.7 — `AppCoordinator.wireVaultEvents` vault-change propagation

The `vaultChanged` → `refreshAmbientManifest() + reindex()` and `vaultPageChanged` → `refreshAmbientManifest() + reanalyze(pageId:)` split is correctly scoped. Per-page changes use the single-page path instead of triggering a full reindex.

***

## Section 3: Dead Code / Redundancy Candidates

### 3.1 — `AppBootstrap`: `localLLMClient` and `localMLXClient` are both `LocalMLXClient`

**File:** `Epistemos/App/AppBootstrap.swift`

Both `let localMLXClient: LocalMLXClient` and `let localLLMClient: LocalMLXClient` are declared. These appear to be two names for the same concrete type. If they point to the same instance, one name is dead. If they point to different instances, the naming is confusing (the same class serving two roles). **Investigate and consolidate to one name.**

### 3.2 — Omega-stack services injected into every view via `withAppEnvironment`

**File:** `Epistemos/App/AppEnvironment.swift`

`withAppEnvironment` injects `orchestratorState`, `mcpBridge`, `dualBrainRouter`, `screen2AXFusion`, `visualVerifyLoop`, and `ghostBrainCoauthor` into every view. These are exclusively Omega-path. Non-agent views receive environment objects they will never consume, creating noise in Swift's environment lookup and potentially keeping Omega objects alive longer than needed.

**Recommendation:** These should remain in the environment for now since the Omega UI still exists, but this is a target for the follow-up Omega-pack cleanup.

### 3.3 — `ThinkingPreludeSyntax` and `ThinkingTagSyntax` inside `Extensions.swift`

**File:** `Epistemos/Engine/Extensions.swift`

`Extensions.swift` contains two large, domain-specific LLM-response parsing enums (`ThinkingPreludeSyntax`, `ThinkingTagSyntax`) alongside general-purpose `FoundationSafety` utilities. These parser enums are 250+ lines of complex heuristics with no connection to the surrounding utilities. **Move to `LLMResponseParser.swift` or `ThinkingTagParser.swift`.**

### 3.4 — `FoundationSafety.dataDetector` factory vs. inline `NSDataDetector` in `DataDetectionService`

`FoundationSafety.dataDetector(types:)` is a `try?`-wrapping factory for `NSDataDetector`. `DataDetectionService.detect(in:)` creates its own `NSDataDetector` inline with the same `try?` pattern. These are functionally identical. `DataDetectionService` should use `FoundationSafety.dataDetector(types:)` to avoid the duplication.

### 3.5 — `UtilityPanel.omega` creates live Omega UI in non-agent path

**File:** `Epistemos/App/UtilityWindowManager.swift`

`UtilityPanel.omega` is a live case in `UtilityPanel.allCases` (iterated by `StatusBar.buildMenu()` to create menu items). When a user selects it, `OmegaPanel()` is instantiated. This means the Omega UI is fully wired and accessible even when the Omega stack is deferred. **Deferred: flagged for the Omega cleanup pass.**

### 3.6 — `NLAnalysisService` declared `@MainActor` with all `nonisolated` methods

**File:** `Epistemos/Engine/NLAnalysisService.swift`

The enum is marked `@MainActor` but every method is `nonisolated`. The `@MainActor` annotation on the enum type has zero effect — no stored state, all static, all nonisolated. Remove the `@MainActor` annotation from the enum declaration.

### 3.7 — `QueryAST.semanticSimilar` label drift vs. `QueryCompiler`

`QueryAST.semanticSimilar(to: String, threshold: Float, limit: Int)` uses `to:` as the first label. `QueryCompiler` maps this to `.semanticSearch(query:...)`. The label naming is inconsistent (`to` vs `query`). Minor but creates a readability gap when tracing from AST to plan.

***

## Section 4: Performance / Consistency / Safety Opportunities

### 4.1 — `NoteInsightService.computeRelatedness` is O(n²) on every single-note edit

**File:** `Epistemos/Engine/NoteInsightService.swift`
**Severity:** High performance risk for vaults with 500+ notes

`scheduleRelatedness()` is called after every per-note `reanalyze` completes (debounced at 300ms coalesce). `computeRelatedness` fetches all `SDNoteInsight` records, builds IDF-weighted entity sets for every note, and runs pairwise similarity across all \( n \times (n-1)/2 \) pairs. For a vault of 1,000 notes this is ~500,000 pair comparisons, run on a background thread 800ms after every save (500ms phase-1 debounce + 300ms phase-2 coalesce).

No vault-size guard exists. A user with a large vault editing rapidly will trigger this computation repeatedly.

**Fix:** Add an early exit: `guard allInsights.count < 250 || onlyForPageId != nil else { return }` for incremental calls. When `onlyForPageId` is set, only recompute pairs involving that page (`O(n)` instead of `O(n²)`). The full pass should only run during `reindex()`.

### 4.2 — `SystemAppearanceObserver` fires a spurious theme notification on Space changes

**File:** `Epistemos/App/SystemAppearanceObserver.swift`

`NSWorkspace.activeSpaceDidChangeNotification` fires when the user switches Mission Control spaces. The observer then calls `notifyNow()`, which reads `UserDefaults.globalDomain` and fires `onAppearanceChange`. If the user's theme hasn't changed, this propagates a no-op but triggers `UIState.isSystemDark` to be re-written with the same value — which in turn triggers all `onChange(of: ui.appearanceSyncKey)` listeners (theme sync on all utility windows, hologram theme sync). Remove the `activeSpaceDidChangeNotification` subscription; `AppleInterfaceThemeChangedNotification` alone is sufficient.

### 4.3 — `ChatCoordinator.preparedManifestSearchEntries` is recomputed on every search

**File:** `Epistemos/App/ChatCoordinator.swift` — `searchReferenceResults` and `autoMatchedReferencedNoteIDs`

`preparedManifestSearchEntries(for:)` normalizes all manifest entries (title, folder, snippet, tags) into searchable form. It is called once inside `searchReferenceResults` and potentially again inside `autoMatchedReferencedNoteIDs` for the same query flow. For a vault of 500+ notes, each call processes all entries.

The manifest itself is cached (`bootstrap.ambientManifest`), but its prepared form is recomputed from scratch each call. A simple `[ObjectIdentifier: [PreparedManifestSearchEntry]]` cache keyed on manifest identity (or a generation counter) would eliminate redundant preparation.

### 4.4 — `Keychain.migrateFromLegacyKeychain` re-queries on every launch

**File:** `Epistemos/Engine/Keychain.swift`

`migrateFromLegacyKeychain(keys:)` has no "already migrated" guard. Every launch iterates all keys and queries the legacy keychain for each. Once migrated, all legacy items return `errSecItemNotFound`, so the actual cost is low, but it is unnecessary I/O. Add a `UserDefaults` flag (`epistemos.keychain.v2MigrationComplete`) and skip the migration if already set.

### 4.5 — `WindowThemeStyler.refreshChrome` forces 5-layer redraw

**File:** `Epistemos/App/UtilityWindowManager.swift` — `WindowThemeStyler.refreshChrome(of:)`

```swift
window.contentView?.needsDisplay = true
window.contentView?.displayIfNeeded()
window.contentViewController?.view.needsDisplay = true
window.contentViewController?.view.displayIfNeeded()
window.contentView?.superview?.needsDisplay = true
window.contentView?.superview?.displayIfNeeded()
window.standardWindowButton(.closeButton)?.superview?.needsDisplay = true
window.standardWindowButton(.closeButton)?.superview?.displayIfNeeded()
```

This is called on every `onChange(of: ui.appearanceSyncKey)` for each open utility window. The `displayIfNeeded()` calls are synchronous main-thread forced redraws. In practice theme changes are rare, so this is low-frequency and the cost is absorbed. However, `contentView.superview` is the internal `NSThemeFrame` — mutating it directly is AppKit-private territory and may break under future macOS versions. **Defer this to the theme-revamp pass; flag as fragile.**

### 4.6 — `ModularZoomWindowObserver.updateNSView` called on every SwiftUI invalidation

**File:** `Epistemos/App/EpistemosApp.swift`

`updateNSView` calls `schedulePolicyApply()` unconditionally, which cancels and reschedules a 1ms `Task`. Every SwiftUI re-render of the main window calls this. The 1ms delay coalesces the scheduling, so only one Task fires per render cycle, but the cancel/reschedule overhead on every update is unnecessary. **Add a simple dirty flag:** only reschedule if the window policy needs reapplication.

### 4.7 — `AppCoordinator.saveDailyBrief` missing `[weak self]` on bare `Task`

**File:** `Epistemos/App/AppCoordinator.swift`

```swift
Task {
    if let pageId = await self.vaultSync.createPage(...) {
```

The bare `Task { }` captures `self` strongly. If `AppCoordinator` is released (app teardown during save), the task holds a strong reference and continues running. Should be `Task { [weak self] in guard let self else { return } ... }`.

### 4.8 — `NLAnalysisService` creates new `NLTagger` / `NLLanguageRecognizer` per call

**File:** `Epistemos/Engine/NLAnalysisService.swift`

During `NoteInsightService.runReindex`, `ContentPersonalitySignals.analyze(body)` is called for every note in the vault. If `ContentPersonalitySignals` internally calls `NLAnalysisService.extractEntities`, `NLAnalysisService.sentiment`, and `NLAnalysisService.detectLanguage` for each note, three separate NL model initializations fire per note. `NLTagger` initialization loads the NLP model from disk — not free. For a 500-note vault this means up to 1,500 model-load operations in the reindex pass.

**Fix:** Thread a single reusable `NLTagger` (or thread-local pool) through the batch analysis path, or confirm that `NLTagger` is singleton-cached by Apple's framework (not documented to be).

***

## Section 5: Stale Tests / Stale Docs / False Narratives

### 5.1 — `EpistemosApp.swift` stale comment about save panel

```swift
// Save-on-quit dialog is now handled via WorkspaceSavePanel (SwiftUI overlay).
// The panel posts .proceedWithQuit when the user confirms, which triggers performTeardown + reply.
```

This comment exists in the `applicationShouldTerminate` path — but the code path immediately *above* it also contains `QuitSavePanelController.showQuitSave { ... }`, which is an NSPanel-based quit flow. The comment claims this is "now" SwiftUI but the code still uses the AppKit-based `QuitSavePanelController`. Either the migration to the SwiftUI overlay was planned but not completed, or the comment is stale. **Clarify which quit-save implementation is canonical.**

### 5.2 — `AppEnvironment.swift` missing entries compared to AppBootstrap

`withAppEnvironment` does not inject `noteInsightService` or `activityTracker` despite both being top-level `AppBootstrap` properties. If any view needs access to these, it would have to reach through `AppBootstrap.shared` rather than environment — an architecture inconsistency. Either they're intentionally not exposed (fine, then document why) or they're missing from the injection list.

### 5.3 — `QueryAST.OrderBy.connections` — no test coverage, unclear execution path

`OrderBy.connections` is defined but `QueryCompiler` passes `orderBy` to the plan without showing how `.connections` is handled by the runtime. Without seeing `QueryRuntime.swift` (not provided in this batch), it is impossible to confirm this is not a dead case. **Flag for follow-up in QueryRuntime audit.**

### 5.4 — `NLAnalysisService` comment claims word count is "more accurate than NSSpellChecker"

The comment `// Counts words using NL tokenizer — more accurate than NSSpellChecker for non-English text` is technically true but a stale comparison. `NSSpellChecker` is not the typical word-counting method in Swift — the natural comparison is `components(separatedBy:)`. The comment references an implementation choice that no longer has a visible counterpart, making it read as historical noise.

### 5.5 — `AppBootstrap.swift` comment `"Pure state/service factory"` is no longer fully accurate

The `AppBootstrap` is described as a pure factory with "all behavioral orchestration delegated to AppCoordinator." However, `AppBootstrap` still contains `loadChat(chatId:)`, `ambientManifest` mutation, `queryTask` ownership, and `healthyVaultBodyCleanupTask`. The factory/coordinator split is improving but incomplete. **This is a directional inconsistency, not a bug — document the remaining items for migration.**

***

## Section 6: Fix-Now vs Defer Matrix

| # | Finding | Severity | Action |
|---|---------|----------|--------|
| 1.1 | `BlockEditTranslator.updateBlock` bypasses initialized guard | **High / FFI Bug** | **Fix Now** |
| 1.2 | `saveDailyBrief` fallback path skips vault persistence | **High / Data Loss** | **Fix Now** |
| 1.3 | Duplicate "New Mini Chat" in EpistemosCommands | Medium / UX | **Fix Now** (1-line delete) |
| 1.4 | `DataDetectionService.open(.date)` broken | Medium / UX | **Fix Now** (remove stub or implement) |
| 1.5 | `KnowledgeCoreSubscriptionKind.links` dead enum case | Medium / API | **Fix Now** (add or remove) |
| 4.1 | `computeRelatedness` O(n²) on per-note save | **High / Perf** | **Fix Now** (add vault-size guard + incremental path) |
| 4.7 | `saveDailyBrief` bare Task strong-captures `self` | Medium / Memory | **Fix Now** (weak capture) |
| 4.2 | `SystemAppearanceObserver` space-change false positives | Low / Perf | **Fix Now** (remove one subscription) |
| 4.4 | `Keychain.migrateFromLegacyKeychain` re-runs every launch | Low / I/O | **Fix Now** (migration flag) |
| 3.3 | `ThinkingPreludeSyntax` / `ThinkingTagSyntax` in Extensions.swift | Low / Org | **Fix Soon** (file relocation) |
| 3.4 | `FoundationSafety.dataDetector` factory duplication | Low / Redundancy | **Fix Soon** |
| 3.6 | `@MainActor` on `NLAnalysisService` is a no-op | Low / Stale | **Fix Soon** (remove annotation) |
| 4.3 | `preparedManifestSearchEntries` recomputed per search | Medium / Perf | **Fix Soon** (add generation cache) |
| 4.6 | `ModularZoomWindowObserver.updateNSView` over-schedules | Low / Perf | **Fix Soon** (dirty flag) |
| 3.1 | `localLLMClient` vs `localMLXClient` duplicate | Medium / Clarity | **Fix Soon** (investigation + consolidate) |
| 5.1 | Stale comment on quit-save path | Low / Docs | **Fix Soon** (clarify canonical path) |
| 4.5 | `WindowThemeStyler.refreshChrome` fragile superview access | Low / Fragile | **Defer** (theme pass) |
| 3.2 | Omega-stack services in `withAppEnvironment` | Low / Noise | **Defer** (Omega cleanup pass) |
| 3.5 | `UtilityPanel.omega` in non-agent path | Low / Noise | **Defer** (Omega cleanup pass) |
| 4.8 | `NLTagger` re-init per call in batch NLP | Medium / Perf | **Defer** (confirm Apple caches or add pool) |
| 5.2 | `noteInsightService` / `activityTracker` not in `withAppEnvironment` | Low / Arch | **Defer** (intentional or document) |
| 5.3 | `OrderBy.connections` coverage | Low / Stale | **Defer** (QueryRuntime audit) |

***

## Section 7: Exact Recommended Cleanup Sequence

### Phase 1 — Bug Fixes (do these first, in order)

**Step 1:** `BlockEditTranslator.swift` — convert `updateBlock` from `static func` to an instance method so it can check `guard initialized`. Alternatively, convert it to a guard that returns `false` if the engine has not been initialized for this page (check via the FFI if an API exists, or track a `Set<String>` of initialized page IDs on the instance).

**Step 2:** `AppCoordinator.saveDailyBrief` — add `[weak self]` to the bare `Task`. Add `NoteFileStorage.writeBody` to the fallback path so the note reaches disk even when vault sync fails. Emit a toast warning when the fallback fires.

**Step 3:** `EpistemosApp.swift / EpistemosCommands` — delete the second `Button("New Mini Chat")` (the `Cmd+Shift+M` one). Keep `Cmd+3` as canonical.

**Step 4:** `DataDetectionService.open(.date)` — remove the action body or replace with `calshow://\(Int(date.timeIntervalSinceReferenceDate))` to open Calendar at the detected date.

**Step 5:** `KnowledgeCoreBridge.swift` — either add `subscribeLinks(pageId: String?) -> UInt64?` wrapping `graph_engine_kc_subscribe_links`, or remove `.links` from `KnowledgeCoreSubscriptionKind` and add a comment explaining it is reserved for future use.

### Phase 2 — Performance Fixes

**Step 6:** `NoteInsightService.scheduleRelatedness` — add `guard allInsights.count < 300 else { return }` inside `computeRelatedness` when called from the coalesced path. Keep full O(n²) only in `reindex()`. For the incremental path, iterate only pairs involving `onlyForPageId`.

**Step 7:** `SystemAppearanceObserver.start()` — remove the `NSWorkspace.activeSpaceDidChangeNotification` block. Theme changes are captured correctly by `AppleInterfaceThemeChangedNotification` alone.

**Step 8:** `Keychain.migrateFromLegacyKeychain` — add `UserDefaults.standard.set(true, forKey: "epistemos.keychainMigrationV2Complete")` after a successful migration pass. Guard on that key at the top of the method.

**Step 9:** `ChatCoordinator.searchReferenceResults` and `autoMatchedReferencedNoteIDs` — extract `preparedManifestSearchEntries(for:)` result to a local variable at the `ChatCoordinator` init level, caching against a `VaultManifest` generation counter or the manifest's `entries.count + lastModified` signature.

### Phase 3 — Refactoring and Organization

**Step 10:** `Extensions.swift` — extract `ThinkingPreludeSyntax` and `ThinkingTagSyntax` into `Epistemos/Engine/LLMResponseParser.swift`. Update all call sites.

**Step 11:** `DataDetectionService.detect(in:)` — replace inline `try? NSDataDetector(types:...)` with `FoundationSafety.dataDetector(types:)`.

**Step 12:** `NLAnalysisService.swift` — remove `@MainActor` from the enum declaration (the annotation is a no-op on an all-nonisolated, no-stored-state enum). Run the compiler to confirm no isolation errors surface.

**Step 13:** `AppBootstrap.swift` — resolve `localLLMClient` vs `localMLXClient`: if both point to the same `LocalMLXClient` instance, remove one and update all callers. If they point to different instances, rename to reflect purpose (e.g., `cloudFallbackLocalClient` vs `primaryLocalClient`).

**Step 14:** `EpistemosApp.swift` — flatten the nested `Task { @MainActor in Task { @MainActor in } }` in `.onAppear` into a single `Task { @MainActor in ... }` block. The inner task has no reason to be nested.

**Step 15:** `AppCoordinator.swift` — annotate `saveDailyBrief` to clearly document which path is primary vs fallback. Add a `// TODO: merge into VaultSyncService` comment or move the fallback into `VaultSyncService.createPage` error handling.

### Phase 4 — Documentation Corrections

**Step 16:** `EpistemosApp.swift` — reconcile the stale comment about `WorkspaceSavePanel` vs `QuitSavePanelController`. Identify the canonical quit-save path and remove the comment for the deprecated one.

**Step 17:** `AppBootstrap.swift` — update the `// Pure state/service factory` comment to acknowledge the remaining behavioral items (`loadChat`, `queryTask`, etc.) as migration targets, not bugs.

**Step 18:** `NLAnalysisService.swift` — update or remove the stale `NSSpellChecker` comparison comment in `wordCount`.

***

## Appendix: Observations on Subsystems Not Yet Audited

The following areas were referenced in the provided files but not included in this batch. They are flagged for the next audit pass:

- **`QueryRuntime.swift`** — needs audit for `OrderBy.connections` execution, FTS5 query construction, and graph-store filtering correctness.
- **`VaultSyncService.swift`** — the `stopWatching(preserveData: false)` safety fix from the recent hardening pass should be verified against the test coverage in `VaultSyncServiceAuditTests.swift`.
- **`GraphStore.swift`** — compaction and tombstone improvements should be cross-checked against `GraphStoreComprehensiveTests.swift`.
- **`TransclusionOverlayManager2.swift`** (Batch 5) — the `2` suffix implies a migration from `TransclusionOverlayManager`. Confirm the original is fully deleted from disk and Xcode membership, parallel to TK1 cleanup.
- **`BlockRefAutocomplete` vs `BlockRefAutocomplete2`** — same naming pattern as transclusion manager. Verify original removal.