# Epistemos Non-Agent Full-App Pruning Audit
**Scope:** Batch 3 files (Models, State, Sync) — March 26, 2026
**Baseline:** TK2 migration complete, TK1 production files removed, VaultSync destructive-stop hardened, GraphStore compaction improved, full green build + test pass confirmed.
**Excluded:** Omega/agent stack, KnowledgeFusion, model-routing/inference stack (InferenceState, LLMService, etc.).

***

## Executive Summary

The audit covered all 30 attached source files across `SDModels`, `State`, `Sync`, and supporting services. The codebase is in materially better shape post-TK2 migration than prior audit cycles reported. The SearchIndexService, BlockPropertyParser, PipelineState, and NotesUIState are clean and require no changes beyond one minor fix each.

**The highest-leverage problems are concentrated in three subsystems:**
1. **TimeMachineService** — duplicate compute loop, synchronous disk I/O on MainActor at scale.
2. **DialogueChatState** — entire archetype/portrait taxonomy is permanently stubbed dead code; synchronous disk I/O before every dialogue prompt.
3. **BlockMirror** — O(n²) Levenshtein in the note sync hot path.

Seven confirmed bugs are worth fixing immediately. Four performance risks require action before large-vault UX degrades further.

***

## Section 1: Highest-Value Findings

### BUG-15 (CRITICAL): `TimeMachineService.computeDiff` — Duplicate For-Loop With Double Disk I/O

**File:** `Epistemos/State/TimeMachineService.swift` · `computeDiff(from:)`

`computeDiff` contains two *identical* `for pastNote in pastState.noteSnapshots { ... }` loops. Both call `NoteFileStorage.readBody(pageId: currentPage.id, mapped: true)`, split the result for word count, and append to `diff.modifiedNotes`. The first loop's appended results are silently overwritten by the second loop — making the first loop entirely dead and causing every diff computation to read every open note body from disk *twice*.

```
// Loop 1 (dead — results overwritten by Loop 2)
for pastNote in pastState.noteSnapshots {
    let currentBody = NoteFileStorage.readBody(...)
    diff.modifiedNotes.append(...)       // ← OVERWRITTEN
}
// ... addedChats, removedChats, graphDelta ...
// Loop 2 (survives, but runs duplicate reads)
for pastNote in pastState.noteSnapshots {
    let currentBody = NoteFileStorage.readBody(...)  // ← second read for same files
    diff.modifiedNotes.append(...)
}
```

**Fix:** Delete Loop 1 entirely. Loop 2 is the correct one — it executes after `pastPageIds` and `currentPageIds` are fully populated and produces the intended output. This halves disk I/O for every Time Machine diff invocation.

**Priority: Fix now.**

***

### BUG-6 (HIGH): `EventStore` Read Methods Are Not Queue-Serialized — Use-After-Free Risk

**File:** `Epistemos/State/EventStore.swift`

Write operations (`appendEvent`, `saveSnapshot`) dispatch through `queue.async`. However, all read methods (`nearestSnapshot(before:)`, `events(from:to:)`, `allSnapshots()`, `eventDensityByDay()`) are called directly on the caller's thread with no queue hop. The `db: OpaquePointer?` handle is annotated `nonisolated(unsafe)`.

The race: `deinit` calls `sqlite3_close(db)` (unqueued), while a MainActor caller is mid-read in `nearestSnapshot`. SQLite's `FULLMUTEX` protects the handle during actual query execution, but does not prevent the `db` pointer from being closed and set to `nil` *between* the nil-check and the first `sqlite3_*` call in the reader.

**Fix:** Route all reads through `queue.sync { }`, or use a separate concurrent read queue with a barrier-write pattern. At minimum, make `deinit` synchronous via `queue.sync { sqlite3_close(db) }`.

**Priority: Fix now — persistence safety.**

***

### BUG-3 (HIGH): `DialogueChatState` — Archetype/Portrait Subsystem Is Entirely Stubbed

**File:** `Epistemos/State/DialogueChatState.swift`

`deriveArchetype(body:tokens:linkedNodeLabels:ml:)` ignores all parameters and always returns `.sentinel`. `deriveMood(...)` always returns `.steady`. `portraitAsset(for:mood:)` always returns the same SF Symbol regardless of inputs.

The entire supporting taxonomy — `DialogueArchetype` (6 cases: `archivist`, `examiner`, `dreamer`, `synthesist`, `chronicler`, `navigator`), `DialogueMood.displayName`, `DialogueDepthTier.displayName`, all private signal helpers (`questionSignalCount`, `citationSignalCount`, `ideaSignalCount`) — computes signal data that is passed into `deriveArchetype` and immediately discarded.

The `DialogueNodeProfile.derive(...)` path computes richness scores, keyword signals, content signals, and portrait asset lookups on every graph node open — all generating zero observable differentiation in the UI.

**Fix (two options):**
- **Delete path:** Remove `deriveArchetype`, `deriveMood`, `portraitAsset`, the three signal-count helpers, and the 6-case `DialogueArchetype` enum. Change `DialogueNodeProfile` to use a flat `isActive: Bool` + `richness: Double` profile only. This is safe because the stubs already produce no visible differentiation.
- **Implement path:** Wire `deriveArchetype` to actually return one of the 6 archetypes based on the signal data already being collected (it's computed but discarded). The signals are good quality; the mapping is the only missing piece.

**Priority: Fix now — dead code with active CPU cost (signals computed but discarded).**

***

### PERF-1 (HIGH): `DialogueChatState.buildRelatedNotesSection` — Synchronous Disk I/O on MainActor Before Every Dialogue Query

**File:** `Epistemos/State/DialogueChatState.swift` · `submitQuery` → `buildPrompt` → `buildRelatedNotesSection(for:)`

`buildRelatedNotesSection` is called synchronously on the MainActor inside `buildPrompt`. It performs:
1. A `mainContext.fetch` (SwiftData, synchronous)
2. Up to 3 calls to `NoteFileStorage.readBody(pageId:)` (disk I/O, synchronous)

All of this happens before the async streaming task launches, meaning every dialogue query blocks the UI thread on disk reads proportional to the size of the related notes.

**Fix:** Move `buildRelatedNotesSection` into a `Task.detached` or `BackgroundModelActor` context, or pre-fetch related note bodies when a node is opened (not at query time). The streaming token delivery path should not share a thread with disk I/O.

**Priority: Fix now — user-visible UI jank on every dialogue query.**

***

### PERF-6 (HIGH): `BlockMirror.alignRun` — O(n²) Levenshtein in the Note Sync Hot Path

**File:** `Epistemos/Sync/BlockMirror.swift` · `alignRun` / `contentSimilarity`

`contentSimilarity(lhs:rhs:)` runs a full Levenshtein edit distance algorithm over `[UInt16]` arrays. This is called for every pair in the cost matrix during `alignRun` — the block-level diff that fires on every note save/sync cycle. For a 100-block note with 20 changed blocks, approximately 400 pair comparisons are made, each allocating two `Int` arrays of size `rhs.utf16.count + 1`.

```swift
// contentSimilarity — called ~400x per sync on large notes
var current = Array(repeating: 0, count: right.count + 1)  // allocation per call
var previous = Array(repeating: 0, count: right.count + 1) // allocation per call
```

For a 200-block note with 1,000-character blocks, each array is ~8KB. 400 pairs = ~6.4MB of short-lived heap allocations per sync cycle.

**Fix:** Replace `contentSimilarity` with a faster approximate similarity (e.g., Jaccard over trigrams of UTF-16, or leading/trailing common prefix/suffix ratio — O(n) with no allocation). Reserve the full Levenshtein only for blocks that pass a cheap pre-filter (same length ± 30%). Alternatively, use Myers diff (git-style) via the existing `LineDiff` infrastructure.

**Priority: Fix now — observable memory pressure on large-note editing.**

***

### BUG-7 (MEDIUM): `BlockParser` — UTF-16 Offset Overruns EOF for Notes Not Ending With `\n`

**File:** `Epistemos/Sync/BlockParser.swift`

The parser accumulates `utf16Offset += lineUtf16Count + 1` for *every* line, including the final one, regardless of whether the string ends with a newline. For a note body that does not end with `\n`, the last line's computed `utf16Range` has an `upperBound` of `utf16Offset + count + 1 > maxUtf16`. The clamping in `BlockMirror.applyRewrite` prevents an out-of-bounds access, but makes the rewrite silently skip applying to the last block of such notes.

**Reproduction:** Create a note ending with `foo` (no trailing newline). Edit only the last word. The rewrite is silently swallowed — the edit is not reflected in the synced block.

**Fix:** In the last line's range computation, do NOT add `+ 1` to the upper bound when the line is the final line and the source string does not end with `\n`. Check `utf16Offset + lineUtf16Count == maxUtf16`.

**Priority: Fix now — silent data loss on notes without trailing newline.**

***

### BUG-8 (MEDIUM): `NoteChatState.streamingTask` — Not Nil'd on Successful Completion

**File:** `Epistemos/State/NoteChatState.swift`

After a streaming response completes successfully (no cancellation, no error), `streamingTask` is left pointing to a finished-but-non-nil `Task<Void, Never>`. On the next `submitQuery`, `replacePendingResponseIfNeeded` calls `stopStreaming()` → `streamingTask?.cancel()` on the finished task (harmless), but `streamingTask` is never set to `nil`. Over many queries on a long-lived per-note chat tab, this accumulates a chain of dangling completed `Task` references.

**Fix:** Add `streamingTask = nil` at the end of the successful completion branch inside the streaming continuation.

**Priority: Fix now — memory growth proportional to query count per note-chat tab.**

***

## Section 2: Subsystems That Are Cleaner Than Expected

### SearchIndexService (`Epistemos/Sync/SearchIndexService.swift`)

This is the strongest subsystem in the batch. Notable design quality:
- **FTS5 content-sync triggers** are correctly defined at the SQLite level — inserts, updates, and deletes all maintain the virtual FTS5 table automatically without any Swift-level sync logic.
- **`OffloadedSearchState` cancellation** correctly handles the race between task cancellation and completion via a lock-guarded `completed` flag. The `sqlite3_progress_handler` cooperative cancellation hook is a sophisticated technique correctly applied.
- **`diffSync`** uses timestamp comparison (not SHA256 hashing) for O(n) stale detection, which is efficient and correct given that `updatedAt` is indexed.
- **`upsertPages`** batches all inserts in a single GRDB write transaction — correct.
- **The one real finding:** `deletePages(ids:)` issues individual `DELETE WHERE id = ?` per page inside a single `dbPool.write` block, which is correct for transaction isolation but sub-optimal for the FTS5 triggers (each delete fires the trigger in a loop rather than a batched `DELETE WHERE id IN (...)`). For 500-page vault reimports, this is ~500 trigger invocations vs ~1. Low-priority but worth filing.

### BlockPropertyParser (`Epistemos/Sync/BlockPropertyParser.swift`)

Clean, stateless, correctly compiled. The trailing-only property logic (backward scan for contiguous trailing group) is correct and handles whitespace gaps properly. `parseValue` priority ordering (Bool → Int → Float → String) is sensible. Pre-compiled regex avoids per-call compilation cost.

### PipelineState (`Epistemos/State/PipelineState.swift`)

14 lines. Correct MainActor isolation. Nothing to change.

### NotesUIState (`Epistemos/State/NotesUIState.swift`)

Clean ephemeral state with correct debounce pattern (cancel-before-recreate with 100ms sleep). Appropriate separation from data layer. **One minor bug:** `debouncedSearchQuery` and `searchQuery` are not cleared in `resetForVaultSwitch()`, leaving stale search terms visible after vault switching. Fix: add `searchQuery = ""; debouncedSearchQuery = ""` to `resetForVaultSwitch`.

### SDPageVersion (`Epistemos/Models/SDPageVersion.swift`)

The intentional decision to denormalize `pageId` as a `String` rather than a `Relationship` is correct for SwiftData Predicate compatibility and documented clearly. The inline-body-in-SQLite tradeoff is acknowledged. The only action item is for *callers* (TimeMachineService) to use `propertiesToFetch` to avoid loading all version bodies into memory on timeline-only queries.

### VaultManifest (`Epistemos/Models/VaultManifest.swift`)

Correctly structured, well-separated `asContext()` and `asManifestOnly()`. The only finding is cosmetic: both methods share an identical header-building block that creates a copy-paste drift risk when the format changes. Extract a shared `buildHeader()` helper. `VaultContextPack.renderedContext()` correctly uses `asManifestOnly` (not `asContext`) for ambient injection.

***

## Section 3: Dead Code / Redundancy Candidates

| ID | Location | What | Action |
|----|----------|------|--------|
| DEAD-1 | `DialogueChatState` | `deriveArchetype`, `deriveMood`, `portraitAsset`, all 3 signal-count helpers, `DialogueArchetype` 6-case enum | Delete stubs or implement. Currently 100% dead. |
| DEAD-2 | `SDMessage` | `var safetyState: String?` | Never written in any code path. Delete field and migration. |
| DEAD-3 | `SDPage` | `var body: String` inline fallback in `loadBody()` | TK2 migration complete. Remove fallback after confirming no pre-migration data remains. Low risk. |
| DEAD-4 | `SDPage` | `var wordCount: Int = 0` (legacy field) | Never updated by current code. Remove after confirming no Predicate query reads it. |
| DEAD-5 | `VaultManifest` | Identical header block in `asContext()` and `asManifestOnly()` | Extract `buildHeader()`. Cosmetic but active drift trap. |
| DEAD-6 | `PhysicsCoordinator` | `activityPulse` spring animation | Verify views observe this property. If not, remove. |
| DEAD-7 | `UIState` | `clearLegacyLandingGreetingDefaults()` runs 20+ UserDefaults removals every launch | Set a one-time migration version flag. Run cleanup once, not every cold start. |
| DEAD-8 | `SDPageVersion` | Inline body loaded on all broad fetches | Not dead, but requires `propertiesToFetch` at call sites in TimeMachineService. |
| DEAD-9 | `PipelineState` | Duplicates loading-state pattern | Not worth merging now; flag if a 4th identical object appears. |
| DEAD-10 | `BlockPropertyParser` | `FoundationSafety.regularExpression` reference | Verify `FoundationSafety` is in the Xcode project. If missing, the parser silently returns empty for all lines. |
| DEAD-11 | `NotesUIState` | `debouncedSearchQuery` not cleared in `resetForVaultSwitch` | Add one-line fix. |
| DEAD-12 | `TimeMachineService` | Loop 1 in `computeDiff` (see BUG-15) | Delete the entire first loop. |
| DEAD-13 | `ThreadState` | O(n) `firstIndex(where:)` pattern across all 15+ methods | Refactor to `[String: Int]` index dictionary for O(1) lookups. |

***

## Section 4: Performance / Consistency / Safety Opportunities

### Hot-Path Disk I/O — Consolidated View

The single largest class of performance risk in this batch is **synchronous `NoteFileStorage.readBody` calls on the MainActor** across multiple services. These calls are individually fast (mmap), but aggregate in ways that become visible:

| Call Site | Reads Per Cycle | Actor | When |
|-----------|----------------|-------|------|
| `ActivityTracker.scanOpenNotes` | 1 per open note | MainActor | Every 5s idle |
| `DailyBriefState.recentContextNotes` | Up to 18 | MainActor | On brief generation |
| `DialogueChatState.buildRelatedNotesSection` | Up to 3 | MainActor | Every query |
| `WorkspaceSummaryService.generatePerWindowSummaries` | Up to 8 | MainActor | Every interval |
| `WorkspaceSummaryService.buildReducePrompt` | Up to 5 | MainActor | Every summary |
| `TimeMachineService.reconstructState` (fallback) | 1 per tab | MainActor | On timeline tap |
| `TimeMachineService.computeDiff` (Loop 1, dead) | 1 per note | MainActor | Duplicate |
| `TimeMachineService.computeDiff` (Loop 2) | 1 per note | MainActor | On diff render |

The most impactful single fix: move `buildRelatedNotesSection` off MainActor (PERF-1). The second most impactful: move `generatePerWindowSummaries` body reads into an async context that doesn't block the SwiftUI render loop.

A medium-term improvement would be a lightweight in-process body cache (weak references keyed by `pageId + modificationDate`) that de-duplicates reads within a single user action. A 500ms TTL would cover all the concurrent callers without stale data risk.

### `SearchIndexService.diffSync` — Serial Async Provider

**File:** `Epistemos/Sync/SearchIndexService.swift` · `diffSync`

```swift
for sd in swiftDataPages {
    if needsUpsert {
        if let full = await fullPageProvider(sd.id) { ... }  // SERIAL
    }
}
```

For a 1,000-page vault on first launch, this serializes 1,000 `NoteFileStorage.readBody` calls through the `fullPageProvider` closure. Using `withTaskGroup` with a concurrency limit of 8 would reduce startup sync time proportionally.

### `EventStore` Read/Write Queue Asymmetry

**File:** `Epistemos/State/EventStore.swift`

Beyond the use-after-free risk (BUG-6), routing reads through `queue.sync` would eliminate the possibility of a reader seeing a partially-committed write. The write queue is serial; adding reads to it (or using a separate concurrent read queue with barrier writes) is the standard pattern for SQLite actor isolation in Swift.

### `SDPageVersion` Memory Footprint in TimeMachineService

**File:** `Epistemos/State/TimeMachineService.swift` · `reconstructState`

```swift
let versionDesc = FetchDescriptor<SDPageVersion>(predicate: ..., sortBy: ...)
let version = try? context.fetch(versionDesc).first
```

This `FetchDescriptor` loads the full `SDPageVersion` row including `body` (inline SQLite). For the timeline overlay, only `title`, `wordCount`, and `createdAt` are needed. Setting `propertiesToFetch = [\.title, \.wordCount, \.createdAt]` would avoid loading potentially megabytes of version body data just to display the timeline.

**Note:** A separate `.body`-included fetch should only happen when the user explicitly taps "View Version."

***

## Section 5: Stale Tests / Stale Docs / False Narratives

### STALE-1: `TK1MigrationValidationTests.swift`

TK1 production files (`ClickableTextView.swift`, `MarkdownTextStorage.swift`, `PageStoragePool.swift`, `ProseEditorRepresentable.swift`) have been deleted from disk and Xcode. Any test that asserts TK1-specific rendering behavior (rather than data-migration from old format to new format) is asserting against removed code.

**Action:** Audit the file. If it validates the data migration path (old inline body → new TK2 model), it should be kept and renamed `LegacyDataMigrationTests`. If it tests ClickableTextView or MarkdownTextStorage behavior, delete it.

### STALE-2: `SDPage.body` Fallback Comment

The comment `// Legacy inline body — post-migration always ""` in `SDPage.loadBody()` is accurate but represents acknowledged debt. The fallback `if diskBody.isEmpty && !body.isEmpty { return body }` will only fire for pre-TK2 data. Given TK2 migration is complete, this can be removed after confirming no production data has `body != ""`. One safe verification: run `context.fetch(FetchDescriptor<SDPage>(predicate: #Predicate { !$0.body.isEmpty })).count`. If zero, remove the fallback.

### STALE-3: `SDMessage.safetyState` Documentation Drift

`var safetyState: String?` has an explicit comment domain (`"green", "yellow", "orange", "red"`) but is never written. Either:
- It belongs to the deferred agent/safety stack → add `// DEFERRED: agent safety stack` and leave.
- It was abandoned → delete the field and its migration.

The current state (documented but inert) is a false positive for code readers expecting the field to contain live data.

### STALE-4: `DailyBriefState.recentContextNotes` — `limit: Int = 18` Is Undocumented

The default limit of 18 notes appears to be chosen for token budget reasons but is not explained in the comment. If the token budget changes with the upcoming model-tier migration (excluded), this becomes a surprise latency bomb. Add a comment explaining the token budget rationale.

***

## Section 6: Fix-Now vs Defer Matrix

| # | Finding | File | Severity | Decision |
|---|---------|------|----------|----------|
| BUG-15 | Duplicate for-loop in `computeDiff`, double disk I/O | `TimeMachineService` | 🔴 High | **Fix now — 3 lines to delete** |
| BUG-6 | EventStore reads unqueued — use-after-free risk | `EventStore` | 🔴 High | **Fix now** |
| BUG-3 | `deriveArchetype`/`deriveMood` permanently stubbed, dead CPU cost | `DialogueChatState` | 🔴 High | **Fix now — delete stubs** |
| PERF-1 | Sync disk I/O on MainActor before every dialogue query | `DialogueChatState` | 🔴 High | **Fix now** |
| PERF-6 | O(n²) Levenshtein in `BlockMirror.alignRun` | `BlockMirror` | 🔴 High | **Fix now** |
| BUG-7 | BlockParser EOF utf16Offset overrun → silent rewrite miss | `BlockParser` | 🟠 Medium | **Fix now** |
| BUG-8 | `streamingTask` not nil'd on success → memory growth | `NoteChatState` | 🟠 Medium | **Fix now — 1 line** |
| DEAD-2 | `SDMessage.safetyState` never written | `SDMessage` | 🟠 Medium | **Fix now — delete or document** |
| DEAD-1 | Archetype/portrait subsystem entirely dead | `DialogueChatState` | 🟠 Medium | **Fix now — delete** |
| BUG-17/18 | `WorkspaceSummaryService` sync body reads on MainActor | `WorkspaceSummaryService` | 🟠 Medium | **Fix this sprint** |
| DEAD-8 | SDPageVersion bodies loaded on all FetchDescriptor calls | `TimeMachineService` callers | 🟠 Medium | **Fix this sprint — add `propertiesToFetch`** |
| PERF-9 | `diffSync` serial `fullPageProvider` awaits | `SearchIndexService` | 🟠 Medium | **Fix this sprint** |
| BUG-13 | ThreadState O(n) scan across all thread operations | `ThreadState` | 🟡 Low-Med | Defer — correctness fine, refactor when thread count grows |
| BUG-10 | `SearchIndexService.deletePages` — individual writes not batched | `SearchIndexService` | 🟡 Low | Defer — only matters at vault reimport |
| DEAD-11 | `NotesUIState.resetForVaultSwitch` missing search query clear | `NotesUIState` | 🟡 Low | **Fix opportunistically — 1 line** |
| DEAD-5 | `VaultManifest.asContext` / `asManifestOnly` header duplication | `VaultManifest` | 🟡 Low | Defer — cosmetic |
| DEAD-7 | `UIState.clearLegacyLandingGreetingDefaults` every launch | `UIState` | 🟡 Low | Defer — harmless but wasteful |
| DEAD-3/4 | `SDPage.body` / `wordCount` legacy fields | `SDPage` | 🟡 Low | Defer until migration confirmed zero |
| STALE-1 | `TK1MigrationValidationTests` — possible stale scope | Tests | 🟡 Low | Audit contents before deleting |
| BUG-11 | `VaultManifest` copy-paste drift between two format methods | `VaultManifest` | 🟢 Noise | Do not touch |
| BUG-2 | Double `revealedCharCount = 0` in `DialogueChatState.open` | `DialogueChatState` | 🟢 Noise | Delete one line opportunistically |
| BUG-4 | `ActivityTracker.idleScanDelay` unused static property | `ActivityTracker` | 🟢 Noise | Delete or use |
| DEAD-9 | `PipelineState` duplicates loading-state pattern | Multiple | 🟢 Noise | Do not touch |

***

## Section 7: Exact Recommended Cleanup Sequence

Execute in this order to minimize destabilization risk. Each step is independently buildable and testable.

### Pass 1: Zero-Risk Line Deletions (< 30 minutes, no behavioral change)

1. **`TimeMachineService.computeDiff`** — Delete the first `for pastNote in pastState.noteSnapshots { ... }` loop (approximately 15 lines). Run `xcodebuild test -only-testing EpistemosTests/VaultSyncServiceAuditTests` to confirm.

2. **`NoteChatState`** — Add `streamingTask = nil` at the end of the successful completion branch. Run `NoteChatStateTests`.

3. **`NotesUIState.resetForVaultSwitch`** — Add `searchQuery = ""; debouncedSearchQuery = ""`.

4. **`ActivityTracker`** — Delete `private static let idleScanDelay: Duration = .seconds(5)` if unused, or wire it to the `Task.sleep` call.

5. **`DialogueChatState.open()`** — Delete the duplicate `revealedCharCount = 0` line.

***

### Pass 2: Dead Code Deletions — Archetype Subsystem (1–2 hours)

6. **`DialogueChatState`** — Delete:
   - `deriveArchetype(body:tokens:linkedNodeLabels:ml:)` and its body
   - `deriveMood(...)` and its body
   - `portraitAsset(for:mood:)` and its body
   - `questionSignalCount(in:)`, `citationSignalCount(in:)`, `ideaSignalCount(in:)` private helpers
   - All call sites that pass their results to the now-deleted functions (the signal computations can stay if they feed other consumers, but verify first)
   - `DialogueArchetype` enum if no consumer remains
   - `DialogueMood.displayName` computed property if no view reads it

   Run full `xcodebuild test` — the stubs never affected behavior so no test should fail.

7. **`SDMessage`** — Delete `var safetyState: String?` and its SwiftData migration entry (or add `// DEFERRED: agent safety stack` comment if it's intentionally deferred).

***

### Pass 3: Persistence Safety (EventStore Queue Fix, ~1 hour)

8. **`EventStore`** — Route `nearestSnapshot(before:)`, `events(from:to:)`, `allSnapshots()`, `eventDensityByDay()` through `queue.sync { }`. Update `deinit` to `queue.sync { sqlite3_close(db); db = nil }`.

   Run `EventStoreTests`, `TimeMachineServiceTests`, `WorkspaceSnapshotTests`.

***

### Pass 4: Performance — Off-MainActor Body Reads (2–3 hours)

9. **`DialogueChatState.buildRelatedNotesSection`** — Extract into a `Task` and `await` the result before `buildPrompt` constructs the final prompt string. The streaming task launch should be gated on this async fetch completing, not racing it.

10. **`WorkspaceSummaryService.generatePerWindowSummaries`** — Move the `NoteFileStorage.readBody` calls into an async fan-out using `withTaskGroup`. Since the method is already `async`, the actor hop is free.

11. **`WorkspaceSummaryService.buildReducePrompt`** — Promote from `private func` to `private func ... async`, collect bodies via `await`, pass them in. Or pre-collect them in `generateAndStoreSummary` before calling `buildReducePrompt`.

***

### Pass 5: BlockMirror / BlockParser Correctness (2–3 hours)

12. **`BlockParser` EOF offset** — Fix the final-line `utf16Offset` accumulation. Add a `guard lineIndex < lines.count - 1 || body.hasSuffix("\n") else { upperBound = maxUtf16; break }` in the offset accumulation loop.

13. **`BlockMirror.contentSimilarity`** — Replace Levenshtein with a trigram Jaccard approximation or a leading/trailing common-prefix ratio. Benchmark against the existing `TextKit2BenchmarkTests` to confirm the hot-path allocation reduction.

***

### Pass 6: Deferred / Lower Priority

14. **`SearchIndexService.deletePages`** — Batch `DELETE WHERE id IN (?, ?, ...)` in one statement.
15. **`ThreadState`** — Refactor to Dictionary-backed O(1) lookup when thread count becomes a measured issue.
16. **`SDPage.body` / `wordCount` legacy fields** — Remove after verifying `context.fetch(FetchDescriptor<SDPage>(predicate: #Predicate { !$0.body.isEmpty })).count == 0`.
17. **`UIState.clearLegacyLandingGreetingDefaults`** — Gate behind a migration version UserDefaults key.
18. **`TK1MigrationValidationTests`** — Audit contents, rename or delete.
19. **`SearchIndexService.diffSync` serial provider** — Wrap with `withTaskGroup(of: ...) { group in }` bounded to 8 concurrent reads.

***

*This audit was performed against the attached Batch 3 files only. Batches 1–2 (App Lifecycle, Graph, Intents, Models) and Batches 4–11 (Sync, Theme, Views, Tests, Docs, Rust FFI) were not attached to this research pack and have not been audited in this pass. The Omega/agent stack and model-routing/inference stack remain explicitly out of scope.*