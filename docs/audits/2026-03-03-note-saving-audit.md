# Note Saving Bug — Deep Audit Plan

> **Index status**: CANONICAL-OPERATIONAL — Append-only audit log; needed for state reconstruction. No copy to _consolidated.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



> **For the investigating model:** This is a systematic debugging plan. Follow it step by step. Do NOT propose fixes until Phase 1 is complete. Read every file referenced — don't skip.

## Problem Statement

Notes are not saving. The user reports that note content is lost. Previous investigation found:
- 823 zero-byte note-body files in `~/Library/Application Support/Epistemos/note-bodies/`
- Content written to note-body files gets overwritten or lost

## What Has Already Been Fixed (committed)

1. **Vault import overwrite guard** (`Epistemos/Sync/VaultIndexActor.swift:491-550`): `upsertPage()` now compares note-body file modification date vs vault `.md` file modification date. If note-body is newer, body overwrite is skipped.

2. **needsVaultSync persistence** (`ProseEditorView.swift`, `NoteWindowManager.swift`, `WriterModeView.swift`): All code paths that set `page.needsVaultSync = true` now call `try? modelContext.save()`.

**Despite these fixes, the user reports notes still don't save.** There must be another code path causing data loss.

## Architecture Context (read these first)

### Storage Model
- Post-migration, note bodies are stored as files: `~/Library/Application Support/Epistemos/note-bodies/{pageId}.md`
- SwiftData `page.body` property is always `""` post-migration (inline storage cleared)
- `page.loadBody()` reads from `NoteFileStorage.readBody(pageId:)`, falls back to `page.body` if file empty
- `page.saveBody(content)` writes to `NoteFileStorage.writeBody()`, then sets `page.body = ""`

### Save Flow (typing → disk)
```
User types → NSTextView (ClickableTextView)
  → textDidChange notification
  → Coordinator's textDidChange handler
  → [300ms debounce] → sets parent.text = textView.string (binding)
  → ProseEditorView.bodyText changes (@State)
  → .onChange(of: bodyText) fires
  → debouncedSave(newValue) called
  → [5s debounce] → page.needsVaultSync = true
  → modelContext.save()
  → NoteFileStorage.writeBody(pageId, content) [background thread]
  → lastPersistedBody = newValue
```

### Critical Files to Read

| File | What to look for |
|------|-----------------|
| `Epistemos/Views/Notes/ProseEditorRepresentable.swift` | **Coordinator** — how text binding flows between NSTextView and SwiftUI. Look for updateNSView, textDidChange, binding sync, page swap logic. THIS IS THE MOST LIKELY BUG LOCATION. |
| `Epistemos/Views/Notes/ProseEditorView.swift` | Save flow: debouncedSave, flushIfNeeded, onChange handlers. Already partially fixed. |
| `Epistemos/Views/Notes/MarkdownTextStorage.swift` | NSTextStorage subclass. processEditing. Could it clear content? |
| `Epistemos/Views/Notes/ClickableTextView.swift` | NSTextView subclass. shouldChangeTextIn zone protection. Could it reject edits? |
| `Epistemos/Sync/VaultSyncService.swift` | Auto-save timer (every 15s), saveAllDirtyPages(), exportPage flow |
| `Epistemos/Sync/VaultIndexActor.swift` | importVault(), upsertPage() — already partially fixed |
| `Epistemos/Sync/NoteFileStorage.swift` | File I/O — writeBody, readBody |
| `Epistemos/Models/SDPage.swift` | loadBody(), saveBody(), isDirtyVault |
| `Epistemos/Views/Notes/NoteTabView.swift` | How ProseEditorView is created, what parent queries exist |
| `Epistemos/State/PageStoragePool.swift` | MarkdownTextStorage pool — could pool return wrong storage? |

## Phase 1: Reproduce and Gather Evidence

### Step 1: Check live file state
```bash
# Count zero-byte files
find ~/Library/Application\ Support/Epistemos/note-bodies -name "*.md" -size 0 | wc -l

# Show recent file modifications (most recent first)
ls -lt ~/Library/Application\ Support/Epistemos/note-bodies/ | head -20

# Check if any files are being modified right now
fswatch -r ~/Library/Application\ Support/Epistemos/note-bodies/ &
# Then edit a note in the app and observe
```

### Step 2: Add diagnostic logging
Add temporary logging to trace the EXACT save flow. In `ProseEditorView.swift`:

```swift
// In debouncedSave, before the file write:
Log.app.info("SAVE-AUDIT: debouncedSave writing pageId=\(pageId) len=\(newValue.count)")

// In flushIfNeeded, before saveBody:
Log.app.info("SAVE-AUDIT: flushIfNeeded writing pageId=\(page.id) len=\(bodyText.count)")

// In onPageFlush, before saveBody:
Log.app.info("SAVE-AUDIT: onPageFlush writing oldPageId=\(oldPageId) len=\(currentText.count)")
```

In `NoteFileStorage.swift`:
```swift
// In writeBody, at the start:
logger.info("SAVE-AUDIT: NoteFileStorage.writeBody pageId=\(pageId.prefix(8)) len=\(content.count)")

// In readBody, at the start:
logger.info("SAVE-AUDIT: NoteFileStorage.readBody pageId=\(pageId.prefix(8)) result_len=\(text.count)")
```

In `VaultIndexActor.swift` `upsertPage()`:
```swift
// After the preserveBody check:
log.info("SAVE-AUDIT: upsertPage preserveBody=\(preserveBody) currentBody_len=\(currentBody.count) vaultBody_len=\(body.count)")
```

### Step 3: Reproduce
1. Build and launch the app with logging
2. Open a note with content
3. Type something new
4. Wait 10 seconds (for debouncedSave to fire)
5. Close the note / switch tabs
6. Reopen the note
7. Check: is the content still there?
8. Quit and relaunch the app
9. Check: is the content still there?

### Step 4: Check logs
```bash
log stream --process Epistemos --predicate 'eventMessage CONTAINS "SAVE-AUDIT"' --level info
```

## Phase 2: Suspect Code Paths (investigate each)

### Suspect 1: ProseEditorRepresentable.Coordinator.updateNSView
**This is the #1 suspect.** The Coordinator mediates between SwiftUI (@State bodyText) and NSTextView. If `updateNSView` is called with stale data during a SwiftData refresh, it could overwrite the NSTextView with old content.

Check:
- Does `updateNSView` read from `page.loadBody()`? If so, that's a disk read on EVERY view update.
- Does it compare before writing to the text storage?
- Is there a flag like `isFlushingTokens` that suppresses sync during programmatic changes?
- Could a SwiftData `@Query` refetch trigger `updateNSView` with stale page data?

### Suspect 2: PageStoragePool returning wrong MarkdownTextStorage
If the pool returns a storage instance for a DIFFERENT page, the text would appear to be "lost" (actually showing wrong page's content). Check:
- How does the pool key storages? By pageId?
- Could a race condition return wrong storage during rapid tab switching?

### Suspect 3: .onChange(of: page.body) overwriting bodyText
Post-migration, `page.body` is always `""`. But if `modelContext.save()` triggers a SwiftData merge that temporarily sets `page.body` to some value then back to `""`, the onChange could fire with `""` and clear bodyText.

Check:
- Add logging to `.onChange(of: page.body)` to see if it fires unexpectedly:
```swift
.onChange(of: page.body) { old, newBody in
    Log.app.info("SAVE-AUDIT: page.body onChange old_len=\(old.count) new_len=\(newBody.count) bodyText_len=\(bodyText.count)")
    guard newBody != bodyText else { return }
    // ...
}
```

### Suspect 4: modelContext.save() in debouncedSave triggering view re-evaluation
The `try? modelContext.save()` added by Kimi's fix saves SwiftData. This triggers `@Query` refetch in parent views. If the parent view reconstructs ProseEditorView with a fresh SDPage object, `.onAppear` might fire again, loading stale content from disk.

Check:
- Add logging to `.onAppear`:
```swift
.onAppear {
    Log.app.info("SAVE-AUDIT: onAppear for page \(page.id.prefix(8)) body_len=\(page.loadBody().count)")
}
```
- Does onAppear fire multiple times during editing?

### Suspect 5: debouncedSave writes file AFTER modelContext.save()
In the current code:
```swift
page.needsVaultSync = true
try? modelContext.save()           // ← triggers auto-save to check dirty pages
// ... time passes ...
NoteFileStorage.writeBody(...)     // ← file actually written LATER
```
If auto-save (15s interval) runs between `modelContext.save()` and the file write, it would:
1. See `needsVaultSync = true`
2. Call `exportPage()` → `buildMarkdown()` → `page.loadBody()` → reads OLD file content
3. Write stale content to vault .md
4. Set `needsVaultSync = false`

Then the `NoteFileStorage.writeBody` completes with new content, but `needsVaultSync` is already false → vault never updated.

This isn't data loss in the note-body file itself, but creates a stale vault that could overwrite on next import.

**Fix if confirmed:** Move `modelContext.save()` AFTER the file write completes.

### Suspect 6: WriterModeView has its own save path
WriterModeView (`Epistemos/Views/Notes/Writer/WriterModeView.swift`) has its own `debouncedSave` and `flushIfNeeded`. Check if it uses the same page and could race with ProseEditorView.

### Suspect 7: NoteWindowManager.flushCurrentEditor
`NoteWindowManager.swift:920-928` has a separate save path that calls `page.saveBody(fullText)`. Check if `fullText` could be stale.

### Suspect 8: Concurrent access to note-body files
`NoteFileStorage.writeBody` is called from:
- `debouncedSave` (background thread via `Task.detached`)
- `flushIfNeeded` (main thread via `page.saveBody()`)
- `onPageFlush` (main thread via `oldPage.saveBody()`)
- `VaultIndexActor.upsertPage` (background actor)
- `NoteWindowManager.flushCurrentEditor` (main thread)

If two paths write the same file concurrently, last-writer-wins. Check if a stale writer could overwrite a newer write.

## Phase 3: Specific Diagnostic Tests

### Test A: Does content survive a simple edit cycle?
1. Launch app
2. Create a new note, type "TEST CONTENT 12345"
3. Wait 10 seconds
4. Verify file exists: `cat "~/Library/Application Support/Epistemos/note-bodies/{pageId}.md"`
5. Quit app
6. Verify file still has content
7. Relaunch
8. Open the note — does it show "TEST CONTENT 12345"?

### Test B: Does content survive tab switching?
1. Open note A, type "AAA"
2. Switch to note B
3. Switch back to note A — does it show "AAA"?

### Test C: Does content survive app restart without quit?
1. Open note, type "RESTART TEST"
2. Wait 10s
3. Force-quit (kill -9) the app
4. Relaunch — is content there?

### Test D: Check for empty-write race
```bash
# Watch for zero-length writes
fswatch -r ~/Library/Application\ Support/Epistemos/note-bodies/ | while read f; do
  size=$(stat -f%z "$f" 2>/dev/null)
  echo "$(date +%H:%M:%S.%N) $f size=$size"
done
```

## Phase 4: Fix Guidelines

Once root cause is identified:
1. Write a failing test FIRST
2. Fix the SMALLEST thing possible
3. Do NOT refactor surrounding code
4. Run `xcodebuild test` (1480 tests) AND `cargo test` (2158 tests)
5. Verify with the diagnostic logging that the fix works
6. Remove all diagnostic logging before committing

## Key Constraints

- `page.body` is ALWAYS `""` post-migration. The file system is the source of truth.
- `page.loadBody()` reads from `NoteFileStorage` first, falls back to inline `body`.
- `NoteFileStorage.writeBody` uses atomic writes (`atomically: true`).
- The 300ms Coordinator debounce and 5s debouncedSave debounce mean there's always a window where the latest text exists only in NSTextView, not on disk.
- `flushIfNeeded()` on disappear/terminate is the safety net for that window.
- Zero per-frame allocations rule: never call `page.loadBody()` in a SwiftUI view body.
