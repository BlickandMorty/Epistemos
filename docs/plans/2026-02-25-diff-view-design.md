# Note Diff View & Version History

**Date:** 2026-02-25
**Status:** Approved

## Problem

Epistemos has no way to see what changed in a note. `SDPageVersion` exists in the schema but no code creates versions. The user wants GitHub-style diff viewing with version history.

## Design Decisions

- **UI placement:** Sheet overlay (`.sheet`) — large enough for side-by-side, dismissible
- **Diff display:** Unified (default) + side-by-side (toggleable). GitHub-style red/green/yellow
- **Entry points:** Cmd+D shortcut on editor, click in Changes panel
- **Version capture:** On every explicit save + auto-capture every 10 min while editing
- **Diff source:** Current body vs any past version; defaults to current vs last saved
- **Max versions:** 50 per note (prune oldest)

## Architecture

### 1. Version Capture (`VersionCaptureService`)

Hooks into the save path and runs a background timer:

- **On explicit save** (`savePage` / `saveAllDirtyPages`): Create `SDPageVersion` if body differs from most recent version for that page.
- **Auto-capture timer:** Every 10 minutes, check all pages that have been edited (tracked via `PageStoragePool` access times). Snapshot if body changed >50 chars since last version.
- **Pruning:** After insert, if page has >50 versions, delete oldest to stay at 50.

```
savePage() ──> captureVersionIfNeeded(pageId:) ──> insert SDPageVersion
                                                 ──> pruneVersions(pageId:)
```

### 2. Diff Engine (`LineDiff`)

Pure value types, no UI dependency. Testable in isolation.

```swift
enum DiffLineKind {
    case unchanged(String)
    case added(String)
    case removed(String)
    case modified(old: String, new: String, wordDiffs: [WordDiff])
}

struct WordDiff {
    let range: Range<String.Index>
    let kind: WordDiffKind  // .added, .removed
}

struct LineDiff {
    let lines: [DiffLineKind]
    let addedCount: Int
    let removedCount: Int

    static func compute(old: String, new: String) -> LineDiff
}
```

**Algorithm:**
1. Split old/new into lines
2. `old.difference(from: new)` via `CollectionDifference`
3. Pair up removed+added lines that are "close" (Levenshtein ratio >0.5) as `.modified`
4. For `.modified` pairs: word-level diff by splitting on whitespace, running `CollectionDifference` again

### 3. Diff UI (`DiffSheetView`)

```
DiffSheetView
├── Header: title, version picker, unified/split toggle, stats (+X/-Y)
├── UnifiedDiffView (default)
│   └── ScrollView > LazyVStack of DiffLineRow
│       - red background for .removed
│       - green background for .added
│       - yellow word highlights for .modified
│       - no background for .unchanged
└── SplitDiffView (toggle)
    └── HStack of two synchronized ScrollViews
        - Left: old version (removed lines in red)
        - Right: new version (added lines in green)
```

**Version picker:** Dropdown listing all `SDPageVersion` entries for the page, sorted by `createdAt` descending. Shows relative time ("2 hours ago", "Yesterday"). Selecting a version recomputes the diff.

**Default comparison:** When opened from Changes panel or Cmd+D, compares current body vs most recent version. If no versions exist, shows "No previous versions — save to create the first snapshot."

### 4. Entry Points

| Trigger | Action |
|---------|--------|
| Cmd+D in editor | Open `DiffSheetView` for `activePageId`, current vs latest version |
| Click dirty note in Changes panel | Open `DiffSheetView` for that page, current vs last synced version |
| Version history picker in sheet | Recompute diff between selected version and current |

### 5. Theme Integration

Diff colors adapt to light/dark theme:
- **Added (light):** `#e6ffec` bg, `#dafbe1` word highlight
- **Removed (light):** `#ffebe9` bg, `#ffd7d5` word highlight
- **Added (dark):** `#0d1117` bg with green-tinted, `#1a3a2a` word highlight
- **Removed (dark):** `#0d1117` bg with red-tinted, `#3a1a1a` word highlight

Use `EpistemosTheme` for exact color values.

## Files to Create/Modify

**New files:**
- `Models/LineDiff.swift` — diff computation engine
- `Views/Notes/DiffSheetView.swift` — main sheet with header + unified/split views
- `Views/Notes/DiffLineRow.swift` — individual diff line rendering

**Modified files:**
- `Sync/VaultSyncService.swift` — add `captureVersionIfNeeded()`, auto-capture timer, prune
- `Views/Notes/VaultChangesPanel.swift` — add tap handler to open diff sheet
- `Views/Notes/PopOutNoteView.swift` — add Cmd+D shortcut, `.sheet` presentation
- `Models/SDPageVersion.swift` — already fixed `.externalStorage` removal
