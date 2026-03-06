# NoteInsightService — Audit Plan for Codex Review

## Purpose

This document provides a structured checklist for reviewing the NoteInsightService implementation. Each section has specific verification criteria and test commands.

---

## 1. Data Model Audit

### SDNoteInsight.swift

- [ ] Model has `@Attribute(.unique)` on `pageId`
- [ ] All JSON-encoded fields have computed property wrappers for type-safe access
- [ ] Model is registered in the SwiftData schema (`EpistemosSchema.models`)
- [ ] No force unwraps on JSON decoding — graceful fallback to empty arrays
- [ ] `contentHash` uses CryptoKit SHA256

### Verification

```bash
grep -r "SDNoteInsight" Epistemos/Models/EpistemosSchema.swift
grep -n "try!" Epistemos/Models/SDNoteInsight.swift  # should return nothing
```

---

## 2. Processing Pipeline Audit

### NoteInsightService.swift

- [ ] `reindex()` dispatches to `Task.detached(priority: .utility)` — NOT main thread
- [ ] Actual work runs in `nonisolated static func runReindex()` — no MainActor in hot path
- [ ] Content hash comparison skips unchanged notes
- [ ] NLTagger is used with `.sentimentScore` and `.lexicalClass` schemes (in `ContentPersonalitySignals.analyze`)
- [ ] Named entity extraction uses `.nameType` scheme
- [ ] Processing uses a single detached task with one `ModelContext`, saving every 50 notes
- [ ] `ContentPersonalitySignals.analyze()` returns `.empty` for empty input AND for notes under 50 characters (short-note skip to avoid noise from titles/stubs)
- [ ] Phase 2 (`computeRelatedness`) fetches all insights eagerly for O(n^2) comparison — acceptable for ~1000 notes

### Verification

```bash
grep -n "MainActor" Epistemos/Engine/NoteInsightService.swift
# Only the UI state update (isIndexing, indexedCount) should touch MainActor

grep -n "try!" Epistemos/Engine/NoteInsightService.swift  # should return nothing
```

---

## 3. Anti-Blurriness Audit (CRITICAL)

This is the most important section. The system MUST NOT become noise.

### Threshold Enforcement

- [ ] Hard minimum relatedness threshold is 0.35 (max possible score without embeddings is 0.70, so 0.35 = strong overlap on 2+ signals)
- [ ] Gap detection cuts results when score drops > 0.15 between consecutive entries
- [ ] Maximum 5 related notes per note (hard cap, not configurable)
- [ ] Each relatedness entry has a non-empty `reasons` array
- [ ] No relatedness entry exists without at least one qualifying signal
- [ ] Tone similarity (signal 3) only contributes when at least one content signal already qualifies

### Signal Weights

| Signal | Weight | Threshold | Description |
|--------|--------|-----------|-------------|
| Entity IDF Jaccard | 0.30 | idfJaccard > 0.10 | NER entities with IDF weighting |
| Topic noun Jaccard | 0.25 | jaccard > 0.15 | Frequent nouns (4+ chars) |
| Tone similarity | 0.15 | toneSimilarity > 0.75 AND other signals present | Sentiment + formality closeness |
| Embedding cosine | 0.30 | TODO | Not yet implemented |

### Hub Pollution Check

- [ ] Entity frequency is IDF-weighted (common entities get lower contribution)
- [ ] Verify: a note mentioning "JavaScript" doesn't relate to ALL other JS notes equally
- [ ] Verify: folder-type nodes don't get artificial relatedness to all their children

---

## 4. Integration Audit

### Dialogue (DialogueChatState) — IMPLEMENTED

- [ ] `DialogueNodeProfile.derive()` accepts `cachedSignals` parameter, reads from `SDNoteInsight` when available
- [ ] Falls back to live `ContentPersonalitySignals.analyze()` if no insight cached
- [ ] System prompt includes up to 3 ML-identified related notes with reasons
- [ ] Total prompt size capped at ~12K: 6K body + 3K neighbors + 2K related + ~1K chrome
- [ ] `buildRelatedNotesSection()` reads note bodies via `NoteFileStorage.readBody` (synchronous file I/O on MainActor — acceptable for 3 reads of 1K each)

### Search (SearchIndexService) — NOT YET INTEGRATED

- [ ] SDNoteInsight facets (sentiment, formality) are NOT yet merged into FTS search
- [ ] This is future work — search currently uses plain FTS5

### Note Chat (NoteChatState) — NOT YET INTEGRATED

- [ ] Related note context is NOT yet injected into NoteChatState system prompt
- [ ] This is future work

### Graph (suggested edges) — NOT YET IMPLEMENTED

- [ ] Suggested edges from relatedness are NOT yet rendered
- [ ] This is future work

---

## 5. Performance Audit

### Startup Impact

- [ ] Main thread is never blocked by NoteInsightService
- [ ] App is usable immediately — insights populate in background
- [ ] No UI freezes during reindex

### Memory

- [ ] NLTagger instances are stack-local in `analyze()` — not retained
- [ ] Phase 2 fetches all insights into memory — acceptable for ~1000 notes (~50KB)

### Incremental Updates

- [ ] Editing a single note emits `vaultPageChanged(pageId:)` → triggers `reanalyze(pageId:)` (not full reindex)
- [ ] `reanalyze` also updates peer notes that previously listed the changed note as related
- [ ] Batch vault sync (startup, file watcher) emits `vaultChanged` → triggers full `reindex()` (with content hash skipping)
- [ ] Deleting a note removes its `SDNoteInsight` (wired in NotesSidebar, VaultIndexActor, and bulk wipe paths)

---

## 6. Test Coverage

### Required Tests (Swift Testing framework) — NOT YET WRITTEN

These tests should be created:

```
NoteInsightServiceTests.swift:
- test_contentHashSkipsUnchangedNotes
- test_sentimentAnalysisRange          // -1.0 to 1.0
- test_entityExtractionFindsNames      // known entities in test text
- test_emptyNoteReturnsEmptySignals
- test_relatednessThresholdEnforced    // all scores >= 0.35
- test_relatednessCapAt5
- test_gapDetectionCutsCorrectly
- test_relatednessHasReasons           // no empty reason arrays
- test_hubPollutionMitigated           // common entity doesn't connect everything
- test_incrementalUpdateOnlyChangedNote
- test_deletedNoteRemovesInsight
- test_concurrentReindexSafe           // no crashes under rapid calls

NoteInsightIntegrationTests.swift:
- test_dialogueProfileReadsFromInsight
- test_systemPromptSizeUnder12K
- test_relatedNotesInDialoguePrompt
```

---

## 7. Code Quality

- [ ] No `DispatchQueue` usage — all `Task`/`TaskGroup`
- [ ] No `try!` or force unwraps
- [ ] All JSON encoding/decoding has error handling
- [ ] Follows existing patterns: `@MainActor @Observable` for service class
- [ ] NLTagger cleanup: no retained references after analysis
- [ ] contentHash uses `CryptoKit.SHA256`
- [ ] Logging at key milestones: start, skip count, completion time, error count

---

## 8. Run Commands

```bash
# Rust tests (should still pass — no Rust changes for this feature)
cd graph-engine && cargo test

# Swift build
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build

# Swift tests
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test

# Quick grep for anti-patterns
grep -rn "try!" Epistemos/Engine/NoteInsightService.swift
grep -rn "DispatchQueue" Epistemos/Engine/NoteInsightService.swift
grep -rn "force" Epistemos/Models/SDNoteInsight.swift
```

---

## Sign-Off Criteria

All of the following must be true:
1. All tests pass
2. Build succeeds with zero warnings in NoteInsight files
3. Reindex completes in < 15s for 1014 notes
4. No note has > 5 related notes
5. No relatedness score < 0.35 in the database
6. System prompt size < 12K characters in dialogue path
7. Main thread never blocked during reindex
8. Incremental update works for single note edit (vaultPageChanged event)
9. Deleting a note removes its SDNoteInsight row
