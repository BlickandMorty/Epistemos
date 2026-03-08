# TextKit 1 vs TextKit 2 Parity Comparison Plan

## Goal

Before deleting the TextKit 1 prose stack, run a full comparison audit that proves the TextKit 2 stack has either:

- copied the old behavior,
- deliberately redesigned it with a better equivalent, or
- explicitly dropped it with a conscious product decision.

This is not a shallow checklist. It is a file-by-file, block-by-block comparison of the old note editor stack against the new one, plus an app-wide scan to ensure nothing important is still routed to TextKit 1 by accident.

## Why This Plan Exists

The migration work now spans multiple sessions and multiple adjacent fixes:

- TextKit 2 prose foundation
- document-mode gap fixes
- note-window integration fixes
- graph/body/NL contracts
- note-performance fixes outside the migration itself

That means the final delete pass for TextKit 1 cannot be based on memory or a simple grep. It needs a formal parity audit.

## Hard Rules

- Do not delete the TextKit 1 prose stack until this plan is complete.
- Compare current `HEAD`, not old patches or stale assumptions.
- Treat parity as both feature parity and behavior parity.
- Treat performance as part of parity.
- Protected integration files must be checked on every migration phase review.

## Protected Files

These files are merge-sensitive and must be diffed on every phase review before approving more migration work:

1. `Epistemos/Views/Notes/NoteWindowManager.swift`
2. `Epistemos/Graph/GraphBuilder.swift`
3. `Epistemos/Views/Notes/Document/DocumentEditorRepresentable.swift`
4. `Epistemos/Sync/NoteFileStorage.swift`

These are protected because they carry note/document/graph contracts that are easy to overwrite indirectly while working on the editor migration.

## Audit Inputs

Use these docs as the migration baseline:

- `docs/plans/2026-03-08-textkit2-migration-design.md`
- `docs/plans/2026-03-08-docmode-gap-fixes-plan.md`

Use these historical implementation baselines:

- `a48c758` — Phase 1 foundation
- `db8b5c6` — Phase 0 document-mode gap fixes

## Phase 1: Full Notes Stack Inventory

Read the note/editor filesystem and inventory the old and new stacks side by side.

### Old TextKit 1 Stack

At minimum, audit these files:

- `Epistemos/Views/Notes/ClickableTextView.swift`
- `Epistemos/Views/Notes/MarkdownTextStorage.swift`
- `Epistemos/Views/Notes/ProseEditorRepresentable.swift`
- `Epistemos/Views/Notes/ProseEditorView.swift`
- `Epistemos/Views/Notes/PageStoragePool.swift`
- `Epistemos/Views/Notes/PageEditorCache.swift`
- `Epistemos/Views/Notes/BlockRefAutocomplete.swift`
- `Epistemos/Views/Notes/TransclusionOverlayManager.swift`
- `Epistemos/Views/Notes/EditableTransclusionView.swift`

### New TextKit 2 Stack

At minimum, audit these files:

- `Epistemos/Views/Notes/ProseTextView2.swift`
- `Epistemos/Views/Notes/MarkdownContentStorage.swift`
- any `ProseEditorRepresentable2` / `ProseStoragePool2` / replacement bridge files added later
- any TextKit 2-specific overlay, pool, or cache files added in later phases

### Required Output

Create a comparison matrix with one row per major responsibility:

- old file / old block
- new file / new block
- status: `copied`, `improved`, `redesigned`, `missing`, `intentionally removed`
- notes on behavior differences

This comparison must be block-by-block in the important hot paths, not just file names.

## Phase 2: Protected File Integrity Audit

Before approving any migration phase, verify these contracts are still intact.

### `NoteWindowManager.swift`

Must preserve:

- document-mode wiring
- `noteChatState` integration
- `onWikilinkClick`
- `onTocChanged`
- `onTextViewCreated`
- note UI actions that depend on the editor
- newer debounce/performance fixes

### `GraphBuilder.swift`

Must preserve:

- `page.loadBody()` usage for graph rebuilds
- NL entity extraction from note bodies
- graph-body contracts needed by document mode and note storage

### `DocumentEditorRepresentable.swift`

Must preserve:

- rich-text save ordering
- plain-text mirror writes
- body-change notifications
- document-mode parity integrations already landed

### `NoteFileStorage.swift`

Must preserve:

- canonical note-body storage behavior
- external reload notifications
- any assumptions the old and new editors both rely on

### Required Output

For each protected file:

- current behavior summary
- what changed since the last approved checkpoint
- whether the migration touched it directly or indirectly
- whether anything regressed or drifted

## Phase 3: App-Wide Wiring Scan

Rescan the whole app for anything that still calls, instantiates, or depends on the TextKit 1 prose path.

### Search Targets

- `ClickableTextView`
- `MarkdownTextStorage`
- `ProseEditorRepresentable`
- `PageStoragePool`
- `PageEditorCache`
- direct `NSLayoutManager`-dependent prose behavior
- old TextKit 1-specific geometry helpers used only by prose

### Required Classification

Every remaining call site must be classified as one of:

- `must migrate to TextKit 2`
- `intentionally retained legacy path`
- `document mode only`
- `writer mode only`
- `dead code / removable`

This scan must include:

- notes UI
- note windows
- sidebars and toolbars
- command/menu actions
- note chat entry points
- note search/navigation hooks
- integrations that expect an editor instance

## Phase 4: Feature Parity Matrix

Compare the old prose stack to the new TextKit 2 stack across all meaningful note-editor behaviors.

At minimum include:

- plain markdown editing
- structural styling
- inline styling
- active-line live preview
- marker collapsing
- headings / lists / quotes / code fences
- tables
- wikilinks
- block references
- block property chips
- find / incremental search
- focus mode
- data detection
- OCR insertion
- QuickLook hooks
- drag and drop
- image insertion
- AI streaming
- note chat hooks
- word count
- TOC
- undo/redo
- save pipeline
- external reload behavior
- page swap behavior
- pooled storage behavior
- cached selection / scroll behavior
- transclusion overlays
- autocomplete positioning
- fold / unfold behavior

### Required Output

For every item:

- old implementation location
- new implementation location
- parity status
- whether behavior is equal, better, worse, or missing

## Phase 5: Optimization Parity Audit

This is mandatory. Do not sign off on the migration using feature parity alone.

### TextKit 1 Optimizations To Compare Against

At minimum audit these old optimizations:

- incremental paragraph-scoped `processEditing()` styling
- no whole-document restyle per keystroke
- deferred reflow during live resize
- progressive theme restyle instead of brute-force restyle
- pooled storage/page-swap behavior
- cached selection and scroll restore
- debounce and buffering behavior in save/AI paths

### TextKit 2 Equivalents

For each optimization, record whether the new stack:

- matches it
- improves it
- replaces it with a different but equivalent strategy
- still lacks it

## Phase 6: Pathological Document Parity

This is the hard edge-case gate before deleting TextKit 1.

### Required Test Shape

Audit a note that is one extremely large paragraph.

Measure both TextKit 1 and TextKit 2 for:

- initial open
- first paint
- typing latency
- cursor move latency
- selection changes
- scroll smoothness
- theme switch
- window resize
- active-line updates
- marker-collapse updates

### Current Known Risk

The current TextKit 2 path is at risk because it can still do:

- full-document reparse
- full-document layout invalidation
- fresh attributed paragraph rebuilds through the delegate
- inline parsing on a pathological giant paragraph

The audit must verify that the new stack reaches at least TextKit 1 baseline behavior for this shape before old prose code is removed.

If parity is not achieved, one of these must happen before deletion:

1. optimize the TextKit 2 path to parity
2. add a deliberate fallback/degradation guard for pathological paragraphs
3. postpone deletion of the TextKit 1 prose path

## Phase 7: Manual UX Comparison

Run the old and new stacks through the same editor flows and compare behavior directly.

At minimum:

- open note
- switch tabs/pages
- type rapidly
- paste large content
- resize window
- toggle theme
- click links
- use note chat
- use document mode round-trips
- trigger TOC/word-count updates
- use find
- test large notes and weird notes

## Phase 8: Deletion Gate

TextKit 1 prose files can only be deleted when all of the following are true:

1. no critical feature is still `missing`
2. protected files are confirmed intact
3. app-wide call sites are either migrated or intentionally retained
4. large-single-paragraph performance is at least at old baseline, or explicitly guarded
5. the migration diff no longer depends on accidental behavior from the old stack
6. manual comparison does not reveal hidden regressions

## Deliverables

This audit must produce:

1. a file-by-file parity matrix
2. a block-by-block hot-path comparison for the main editor stack
3. a protected-file integrity report
4. an app-wide call-site migration report
5. an optimization parity report
6. a pathological-document performance report
7. a final `safe to delete / not safe to delete` conclusion

## Final Decision Rule

Do not delete TextKit 1 because the new stack "mostly works."

Delete it only after proving:

- the important behaviors were rebuilt,
- the non-migration integrations stayed intact,
- the app is actually routing the right paths to TextKit 2,
- and the new stack is not slower in the exact edge cases the old stack already handled well.
