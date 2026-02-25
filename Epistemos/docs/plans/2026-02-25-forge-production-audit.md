# Epistemos Production Hardening Audit

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Harden the Epistemos macOS app — fix crash paths, propagate errors to UI, refactor the monolithic pipeline, add a test target with coverage of core logic, and tighten resilience across the board.

**Architecture:** Epistemos is a Swift 6 / SwiftUI / SwiftData macOS app using @Observable state, @MainActor default isolation, and GRDB for FTS5 search. Changes are additive — we harden what exists without redesigning.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, AppKit (NSTextView), GRDB.swift 7.10, xcodegen (project.yml), os.Logger

---

## Phase 1: Reconnaissance — COMPLETE

See recon findings in conversation. Key numbers:
- **~30k lines** across ~110 Swift files
- **0 test files**, no test target
- **3 unsafe force unwraps** that can crash
- **Silent SwiftData errors** in persistence layer
- **PipelineService** is 1843 lines with ~600-line `run()` method
- Logging is clean (os.Logger), no debug artifacts

---

## Phase 2: Crash Safety & Type Hardening

### Task 1: Fix force unwraps that can crash at runtime

**Files:**
- Modify: `Epistemos/Views/Library/LibraryView.swift:654-657`
- Modify: `Epistemos/Intents/Custom/ResearchIntents.swift:83`

**Step 1: Fix LibraryView.swift — AuthorCard yearRange**

The `author.years` array could be empty. `.min()!` and `.max()!` crash on empty arrays. The `guard` on line 654 returns `""` for empty, but the force unwraps still exist after the guard:

```swift
// BEFORE (lines 653-657):
private var yearRange: String {
    guard !author.years.isEmpty else { return "" }
    let mn = author.years.min()!
    let mx = author.years.max()!
    return mn == mx ? "\(mn)" : "\(mn)–\(mx)"
}

// AFTER — use safe unwrap:
private var yearRange: String {
    guard let mn = author.years.min(), let mx = author.years.max() else { return "" }
    return mn == mx ? "\(mn)" : "\(mn)–\(mx)"
}
```

**Step 2: Fix ResearchIntents.swift — extractField colon index**

`match.firstIndex(of: ":")!` will crash if the match somehow has no colon. Defensive unwrap:

```swift
// BEFORE (line 83):
let colonIndex = match.firstIndex(of: ":")!
return String(match[match.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

// AFTER:
guard let colonIndex = match.firstIndex(of: ":") else { return nil }
return String(match[match.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
```

**Step 3: Verify build compiles**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```
audit: fix force unwraps in LibraryView and ResearchIntents
```

---

### Task 2: Guard `layoutManager` access in ProseEditorRepresentable

**Files:**
- Modify: `Epistemos/Views/Notes/ProseEditorRepresentable.swift:238`

**Step 1: Replace force unwrap with guard**

The `tv.layoutManager!` on line 238 can crash during edge cases (view teardown, rapid page switches). Add a guard:

```swift
// BEFORE (line 237-238):
if !pageId.isEmpty {
    let layoutManager = tv.layoutManager!

// AFTER:
if !pageId.isEmpty {
    guard let layoutManager = tv.layoutManager else { return }
```

**Step 2: Verify build compiles**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```
audit: guard layoutManager unwrap in ProseEditorRepresentable
```

---

## Phase 3: Error Propagation & Resilience

### Task 3: Surface SwiftData save errors to the user via toast

**Files:**
- Modify: `Epistemos/App/AppBootstrap+NotesContext.swift`
- Modify: `Epistemos/State/EventBus.swift` (verify `.error` and `.toast` events exist)

**Context:** Currently `try? context.save()` silently discards errors in `executeVaultActions()`. The app already has an EventBus with `.error` and `.toast` events. We should use them.

**Step 1: Check EventBus for error/toast event types**

Read `Epistemos/State/EventBus.swift` and confirm the event types available for error surfacing.

**Step 2: Replace silent `try?` with do/catch + toast**

In `AppBootstrap+NotesContext.swift`, the `executeVaultActions` function uses `try?` for SwiftData fetches, which is acceptable (query failure = no match). But we should make sure vault mutation errors (TAG/MOVE/CREATE actions) at minimum log properly. The existing code already uses `try?` for fetches and the mutations are through property assignments (no explicit save call in this function — the context auto-saves or is saved elsewhere).

Audit each `try?` in the file:
- Lines 30, 44-47, 60: `try? context.fetch(...)` — acceptable, fetch failure = empty result, already guarded by `if let`/`guard let`
- Lines 95-96, 100, 122, 126: `try? context.fetch(...)` in `executeVaultActions` — same pattern, acceptable

No changes needed here — the `try?` usage is on fetch operations, not save operations. The save happens in `VaultSyncService` which should be audited.

**Step 3: Audit VaultSyncService save error handling**

Read `Epistemos/Sync/VaultSyncService.swift` and find all `try? context.save()` or `try? modelContext.save()` calls. Replace silent discards with logged errors + toast notification.

For each silent save, replace with:

```swift
// BEFORE:
try? context.save()

// AFTER:
do {
    try context.save()
} catch {
    Log.vault.error("Failed to save: \(error.localizedDescription, privacy: .public)")
}
```

The logging is the minimum — if there's an EventBus available in the service, also emit a toast for user-facing operations (page save, version capture, etc.).

**Step 4: Verify build compiles**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```
audit: propagate SwiftData save errors with logging
```

---

### Task 4: Add per-pass timeouts to enrichment pipeline

**Files:**
- Modify: `Epistemos/Engine/PipelineService.swift` (enrichment section in `run()`, around lines 400-600)

**Context:** Currently there's a single 600s hard cutoff for the entire enrichment block. If one pass hangs (e.g., Gemini SSE drops connection), all subsequent passes are blocked. Each pass should have its own timeout.

**Step 1: Add a `withTimeout` helper**

Add a small helper function at the bottom of PipelineService (before the closing brace):

```swift
/// Run an async operation with a timeout. Returns nil if the timeout elapses.
nonisolated private func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @Sendable () async throws -> T
) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask { try? await operation() }
        group.addTask {
            try? await Task.sleep(for: .seconds(seconds))
            return nil
        }
        let result = await group.next() ?? nil
        group.cancelAll()
        return result
    }
}
```

**Step 2: Wrap each enrichment pass call with a 30-second timeout**

In the enrichment section of `run()`, wrap each pass (2-6) with the timeout helper. When a pass times out, use the existing fallback methods. Example for Pass 2:

```swift
// BEFORE:
let raw = await generateRawAnalysisAsync(...)

// AFTER:
let raw = await withTimeout(seconds: 30) { [self] in
    await self.generateRawAnalysisAsync(...)
} ?? fallbackRawAnalysis(signals: signals)
```

Apply the same pattern to passes 3-6 using their respective fallback methods (`fallbackLaymanSummary`, `fallbackReflection`, `fallbackArbitration`, `fallbackTruthAssessment`).

**Step 3: Remove or reduce the 600s global timeout**

If all passes now have individual timeouts, the global timeout can be reduced to a sanity check (e.g., 180s = 6 passes × 30s).

**Step 4: Verify build compiles**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```
audit: add per-pass 30s timeouts to enrichment pipeline with fallbacks
```

---

## Phase 4: Pipeline Refactor

### Task 5: Extract enrichment passes into EnrichmentController

**Files:**
- Create: `Epistemos/Engine/EnrichmentController.swift`
- Modify: `Epistemos/Engine/PipelineService.swift`

**Context:** PipelineService is 1843 lines. The enrichment logic (Passes 2-6, fallbacks, JSON extraction, concept parsing) accounts for ~1100 lines. Extract these into a dedicated `EnrichmentController` that PipelineService delegates to.

**Step 1: Create EnrichmentController.swift**

Move the following from PipelineService into the new file:
- `generateRawAnalysisAsync()` and `generateRawAnalysis()` (Pass 2)
- `generateLaymanSummary()` (Pass 3)
- `generateReflection()` (Pass 4)
- `generateArbitration()` (Pass 5)
- `generateTruthAssessment()` (Pass 6)
- All `fallback*` methods
- `extractJSON()`, `countEpistemicTags()`, `extractUncertaintyTags()`
- `parseConceptsTag()`, `extractResponseConcepts()`
- `withTimeout()` (added in Task 4)
- The shared preamble methods

The class should be `nonisolated` (all enrichment methods already are) and take `LLMService` + `TriageService` as init params:

```swift
import Foundation
import os

/// Handles Passes 2-6 of the analytical pipeline.
/// All methods are nonisolated — designed to run in Task.detached contexts.
final class EnrichmentController: Sendable {
    private let llmService: LLMService
    private let triageService: TriageService

    init(llmService: LLMService, triageService: TriageService) {
        self.llmService = llmService
        self.triageService = triageService
    }

    // ... moved methods ...
}
```

**Step 2: Update PipelineService to delegate to EnrichmentController**

Replace direct calls in `run()` with `enrichmentController.generateRawAnalysis(...)`, etc.

Add `private let enrichment: EnrichmentController` property, initialized in PipelineService.init.

**Step 3: Verify build compiles**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```
audit: extract enrichment passes into EnrichmentController
```

---

### Task 6: Extract prompt composition from PipelineService

**Files:**
- Modify: `Epistemos/Engine/PromptComposer.swift` (check if it exists and what's already there)
- Modify: `Epistemos/Engine/PipelineService.swift`

**Context:** `generateStageDetail()` and the shared preamble methods generate prompt text. If `PromptComposer.swift` already exists, move `generateStageDetail` there. If it's already doing prompt composition, integrate. Don't create a new file if one exists.

**Step 1: Read PromptComposer.swift**

Determine what's already in the file and whether `generateStageDetail` belongs there.

**Step 2: Move `generateStageDetail()` to PromptComposer**

This method (lines 1757-1820) generates stage detail strings. Move it to PromptComposer as a static method.

**Step 3: Verify build compiles + commit**

```
audit: move stage detail generation to PromptComposer
```

---

## Phase 5: Test Foundation

### Task 7: Add test target to project.yml and create first test file

**Files:**
- Modify: `project.yml`
- Create: `EpistemosTests/LineDiffTests.swift`

**Context:** No test target exists. We need to add one to `project.yml` and regenerate the Xcode project. Start with `LineDiff` — it's a pure value type with zero dependencies, perfect for testing.

**Step 1: Add test target to project.yml**

```yaml
  EpistemosTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: EpistemosTests
    dependencies:
      - target: Epistemos
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.epistemos.tests
```

**Step 2: Create EpistemosTests directory and LineDiffTests.swift**

```swift
import Testing
@testable import Epistemos

@Suite("LineDiff")
struct LineDiffTests {

    @Test("identical strings produce no changes")
    func identicalStrings() {
        let diff = LineDiff.compute(old: "hello\nworld", new: "hello\nworld")
        #expect(diff.stats.added == 0)
        #expect(diff.stats.removed == 0)
        #expect(diff.stats.modified == 0)
        #expect(diff.lines.count == 2)
    }

    @Test("added line detected")
    func addedLine() {
        let diff = LineDiff.compute(old: "line1", new: "line1\nline2")
        #expect(diff.stats.added == 1)
        #expect(diff.stats.removed == 0)
    }

    @Test("removed line detected")
    func removedLine() {
        let diff = LineDiff.compute(old: "line1\nline2", new: "line1")
        #expect(diff.stats.removed == 1)
        #expect(diff.stats.added == 0)
    }

    @Test("modified line detected when similar")
    func modifiedLine() {
        let diff = LineDiff.compute(
            old: "the quick brown fox",
            new: "the quick red fox"
        )
        // "brown" → "red" should be detected as modified (Jaccard > 0.4)
        #expect(diff.stats.modified == 1)
    }

    @Test("empty strings produce empty diff")
    func emptyStrings() {
        let diff = LineDiff.compute(old: "", new: "")
        #expect(diff.lines.count == 1) // one empty line
        #expect(diff.stats.added == 0)
        #expect(diff.stats.removed == 0)
    }

    @Test("completely different strings are removals + additions")
    func completelyDifferent() {
        let diff = LineDiff.compute(old: "aaa\nbbb", new: "xxx\nyyy")
        // Jaccard similarity of "aaa"/"xxx" is 0 — should be remove + add, not modified
        let totalChanges = diff.stats.added + diff.stats.removed + diff.stats.modified
        #expect(totalChanges == diff.lines.filter { if case .unchanged = $0 { return false }; return true }.count)
    }

    @Test("word-level diffs identify changed words")
    func wordDiffs() {
        let (removed, added) = LineDiff.wordDiffs(
            old: "the quick brown fox",
            new: "the quick red fox"
        )
        #expect(!removed.isEmpty)
        #expect(!added.isEmpty)
    }

    @Test("sectioned groups changes with context lines")
    func sectioning() {
        // 10 unchanged, 1 changed, 10 unchanged
        let oldLines = (0..<21).map { "line \($0)" }
        var newLines = oldLines
        newLines[10] = "CHANGED line 10"
        let diff = LineDiff.compute(old: oldLines.joined(separator: "\n"), new: newLines.joined(separator: "\n"))
        let sections = diff.sectioned(contextLines: 2)
        // Should have: collapsed | visible (context + change + context) | collapsed
        #expect(sections.count >= 2)
    }

    @Test("chunkStartIndices finds contiguous change blocks")
    func chunkStarts() {
        let diff = LineDiff.compute(
            old: "a\nb\nc\nd\ne",
            new: "a\nB\nC\nd\nE"
        )
        let chunks = diff.chunkStartIndices
        // Two change blocks: [B,C] and [E]
        #expect(chunks.count == 2)
    }
}
```

**Step 3: Regenerate Xcode project and run tests**

Run: `cd /Users/jojo/epistemos && xcodegen generate`
Run: `xcodebuild test -project Epistemos.xcodeproj -scheme EpistemosTests -configuration Debug 2>&1 | tail -20`
Expected: All tests pass

**Step 4: Commit**

```
audit: add test target and LineDiff unit tests
```

---

### Task 8: Add tests for QueryAnalyzer and SignalGenerator

**Files:**
- Create: `EpistemosTests/QueryAnalyzerTests.swift`
- Create: `EpistemosTests/SignalGeneratorTests.swift`

**Context:** These are pure functions — `QueryAnalyzer.analyze()` and `SignalGenerator.generate()` take value types and return value types. No mocking needed.

**Step 1: Read QueryAnalyzer.swift and SignalGenerator.swift**

Understand the input/output types and write tests against the public API.

**Step 2: Write QueryAnalyzer tests**

Test key behaviors:
- Short vs long queries produce different complexity scores
- Question marks detected
- Technical vs conversational language classification
- Edge cases: empty string, very long string, unicode

**Step 3: Write SignalGenerator tests**

Test key behaviors:
- Signal values stay within expected ranges (0.0-1.0 for confidence, entropy, etc.)
- Different query types produce meaningfully different signals
- Steering bias affects output
- Edge: nil context, default controls

**Step 4: Run tests, verify passing, commit**

```
audit: add QueryAnalyzer and SignalGenerator tests
```

---

### Task 9: Add tests for gradeFromConfidence

**Files:**
- Create: `EpistemosTests/GradeTests.swift`

**Step 1: Write boundary tests**

```swift
import Testing
@testable import Epistemos

@Suite("Evidence Grading")
struct GradeTests {
    @Test("grade A for high confidence")
    func gradeA() {
        #expect(AppBootstrap.gradeFromConfidence(0.90) == .a)
        #expect(AppBootstrap.gradeFromConfidence(0.85) == .a)
        #expect(AppBootstrap.gradeFromConfidence(1.0) == .a)
    }

    @Test("grade B for moderate-high confidence")
    func gradeB() {
        #expect(AppBootstrap.gradeFromConfidence(0.84) == .b)
        #expect(AppBootstrap.gradeFromConfidence(0.70) == .b)
    }

    @Test("grade C for moderate confidence")
    func gradeC() {
        #expect(AppBootstrap.gradeFromConfidence(0.69) == .c)
        #expect(AppBootstrap.gradeFromConfidence(0.50) == .c)
    }

    @Test("grade D for low confidence")
    func gradeD() {
        #expect(AppBootstrap.gradeFromConfidence(0.49) == .d)
        #expect(AppBootstrap.gradeFromConfidence(0.30) == .d)
    }

    @Test("grade F for very low confidence")
    func gradeF() {
        #expect(AppBootstrap.gradeFromConfidence(0.29) == .f)
        #expect(AppBootstrap.gradeFromConfidence(0.0) == .f)
    }

    @Test("negative confidence gets F")
    func negativeConfidence() {
        #expect(AppBootstrap.gradeFromConfidence(-0.5) == .f)
    }
}
```

**Step 2: Run tests, commit**

```
audit: add evidence grading boundary tests
```

---

## Phase 6: Gemini SSE Parsing Hardening

### Task 10: Harden Gemini streaming SSE parser

**Files:**
- Modify: `Epistemos/Engine/LLMService.swift` (around lines 300-330)

**Context:** The current Gemini SSE parser does a simple `line.hasPrefix("data: ")` check. Proper SSE protocol has edge cases: multi-line data, empty data lines, comment lines starting with `:`, and the `[DONE]` sentinel.

**Step 1: Add SSE edge case handling**

```swift
// In the Gemini streaming section, replace the simple parser with:
for try await line in bytes.lines {
    guard !Task.isCancelled else { break }
    // SSE: skip empty lines and comment lines
    if line.isEmpty || line.hasPrefix(":") { continue }
    guard line.hasPrefix("data: ") else { continue }
    let json = String(line.dropFirst(6))
    // SSE: [DONE] sentinel signals end of stream
    if json.trimmingCharacters(in: .whitespaces) == "[DONE]" { break }
    guard let d = json.data(using: .utf8),
          let chunk = try? JSONDecoder().decode(GeminiResponse.self, from: d),
          let text = chunk.candidates.first?.content.parts.first?.text
    else { continue }
    continuation.yield(text)
}
```

**Step 2: Verify build compiles, commit**

```
audit: harden Gemini SSE parser with proper protocol handling
```

---

## Phase 7: Accessibility

### Task 11: Audit icon-only buttons for accessibility labels

**Files:**
- Modify: Multiple view files (DiffSheetView, VaultChangesPanel, ChatView, LandingView, etc.)

**Context:** macOS VoiceOver needs accessible names on icon-only buttons. Many buttons in the app use `.help()` (tooltip) but not `.accessibilityLabel()`. VoiceOver reads the tooltip as a fallback on macOS, but explicit labels are more reliable.

**Step 1: Search for icon-only buttons missing accessibility labels**

Grep for `Image(systemName:` inside `Button` bodies that lack `.accessibilityLabel`.

**Step 2: Add `.accessibilityLabel()` to icon-only buttons**

For buttons that already have `.help("...")`, add a matching `.accessibilityLabel("...")`. For those without, add both. Focus on interactive controls (buttons, pickers), not decorative icons.

Priority files:
- `DiffSheetView.swift` — chunk navigation, restore, close buttons
- `VaultChangesPanel.swift` — save, view changes buttons
- `ChatView.swift` — send, stop, settings buttons
- `NotesSidebar.swift` — folder actions, new note buttons

**Step 3: Verify build compiles, commit**

```
audit: add accessibility labels to icon-only buttons
```

---

## Final Verification

### Task 12: Full build + test suite verification

**Step 1: Run full build**

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug build 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED, 0 warnings (or document remaining warnings)

**Step 2: Run full test suite**

```bash
xcodebuild test -project Epistemos.xcodeproj -scheme EpistemosTests -configuration Debug 2>&1 | tail -20
```

Expected: All tests pass

**Step 3: Verify no force unwraps remain**

```bash
grep -rn '\.min()!' --include='*.swift' Epistemos/
grep -rn '\.max()!' --include='*.swift' Epistemos/
grep -rn 'firstIndex.*!' --include='*.swift' Epistemos/
```

Expected: Zero matches (excluding safe compile-time literals like URL/Regex)

**Step 4: Git log review**

```bash
git log --oneline | head -15
```

Verify each audit commit is atomic and descriptive.

**Step 5: Commit any final fixes, present scorecard**

---

## Task Dependency Graph

```
Task 1 (force unwraps) ──────┐
Task 2 (layoutManager guard) ─┤── Phase 2: independent, can run in sequence
                               │
Task 3 (SwiftData errors) ─────┤── Phase 3: independent of Phase 2
Task 4 (per-pass timeouts) ────┘
                               │
Task 5 (EnrichmentController) ─┤── Phase 4: depends on Task 4 (timeout helper moves)
Task 6 (PromptComposer) ───────┘── depends on Task 5
                               │
Task 7 (test target + LineDiff)─┤── Phase 5: depends on Phase 4 (code must compile)
Task 8 (QueryAnalyzer tests) ──┤── depends on Task 7
Task 9 (grade tests) ──────────┘── depends on Task 7
                               │
Task 10 (Gemini SSE) ──────────┤── Phase 6: independent
Task 11 (accessibility) ───────┘── Phase 7: independent
                               │
Task 12 (final verification) ──── depends on ALL above
```
