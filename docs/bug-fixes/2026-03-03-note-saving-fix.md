# Bug Fix: Notes Not Saving to Vault

> **Index status**: CANONICAL-HISTORICAL — Bug fix record (2026-03-03). Kept for historical reference.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



**Date:** 2026-03-03  
**Reporter:** User ("notes not saving")  
**Fixer:** Claude Code CLI

---

## Problem Statement

User reported that after refactoring and implementing features, notes were not being saved. When typing in the editor, content would appear to work but wouldn't persist to the vault `.md` files.

## Root Cause Analysis

The issue was in the **dirty flag persistence mechanism**:

1. `SDPage.needsVaultSync` is a SwiftData boolean that marks a page as having unsaved changes
2. The sidebar uses `@Query(filter: #Predicate { $0.needsVaultSync == true })` to show the dirty indicator
3. `VaultSyncService.saveAllDirtyPages()` uses `isDirtyVault` which checks this flag
4. **The bug:** `needsVaultSync = true` was being set in memory but **never persisted to SwiftData** via `modelContext.save()`

### Why It Broke

The save flow looks like this:
```
User types → NSTextView → debouncedSave(5s) → NoteFileStorage.writeBody() ✓ (worked)
                                       ↓
                              page.needsVaultSync = true (in-memory only) ✗ (broken)
                                       ↓
                              modelContext.save() ← MISSING
```

Without the `modelContext.save()`:
- Sidebar `@Query` never sees the page as dirty (no red badge)
- `isDirtyVault` returns `false` because `needsVaultSync` was never persisted
- Vault export skips the page because it appears clean
- `.md` file is never written

## Files Modified

| File | Change |
|------|--------|
| `Epistemos/Views/Notes/ProseEditorView.swift` | Added `try? modelContext.save()` in `debouncedSave()` after setting `needsVaultSync = true` |
| `Epistemos/Views/Notes/ProseEditorView.swift` | Added `try? modelContext.save()` in `onPageFlush` closure |
| `Epistemos/Views/Notes/NoteWindowManager.swift` | Added `try? modelContext.save()` in `flushCurrentEditor()` |
| `Epistemos/Views/Notes/Writer/WriterModeView.swift` | Added `try? modelContext.save()` in `debouncedSave()` |
| `Epistemos/Views/Notes/Writer/WriterModeView.swift` | Added `try? modelContext.save()` in `flushIfNeeded()` |

## Code Pattern

### Before (Broken)
```swift
private func debouncedSave(_ newValue: String) {
    saveTask?.cancel()
    let pageId = page.id
    saveTask = Task { @MainActor in
        try? await Task.sleep(for: .seconds(5))
        guard !Task.isCancelled else { return }
        guard newValue != lastPersistedBody else { return }
        page.needsVaultSync = true  // ← In-memory only!
        // File write off main thread
        await Task.detached(priority: .utility) {
            NoteFileStorage.writeBody(pageId: pageId, content: newValue)
        }.value
        lastPersistedBody = newValue
    }
}
```

### After (Fixed)
```swift
private func debouncedSave(_ newValue: String) {
    saveTask?.cancel()
    let pageId = page.id
    saveTask = Task { @MainActor in
        try? await Task.sleep(for: .seconds(5))
        guard !Task.isCancelled else { return }
        guard newValue != lastPersistedBody else { return }
        page.needsVaultSync = true
        // Persist the dirty flag so @Query in sidebar sees it and vault sync finds it.
        try? modelContext.save()  // ← PERSISTED!
        // File write off main thread
        await Task.detached(priority: .utility) {
            NoteFileStorage.writeBody(pageId: pageId, content: newValue)
        }.value
        lastPersistedBody = newValue
    }
}
```

## Verification Steps

1. Open a note in Epistemos
2. Type some content
3. Wait 5 seconds (debounce period)
4. **Check sidebar:** Dirty badge should appear on the note
5. **Check vault folder:** `.md` file should be created/updated
6. Press Cmd+S (Save) - should trigger immediate vault export
7. Press Shift+Cmd+S (Save All) - should export all dirty pages

## Architecture Note

This is a **SwiftData persistence pattern issue**, not a file I/O issue. The note body was always being saved correctly to `NoteFileStorage` (in `~/Library/Application Support/Epistemos/note-bodies/`), but the **dirty flag** that triggers vault export was lost because SwiftData requires explicit `modelContext.save()` to persist changes.

The `@Query` in `NotesSidebar.swift` uses a `#Predicate` filter on `needsVaultSync`, which only works if the value is actually saved to the database.

## Related Code

- `SDPage.isDirtyVault` - computed property that checks `needsVaultSync`
- `VaultSyncService.saveAllDirtyPages()` - filters by `isDirtyVault`
- `NotesSidebar.swift:1548` - `@Query` that displays dirty indicator
