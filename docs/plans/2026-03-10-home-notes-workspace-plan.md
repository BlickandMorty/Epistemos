# Home Notes Workspace Plan

## Goal

Add Notes as a first-class page inside the main home window, positioned before Library, without creating a second notes implementation.

This must be built as a shared notes workspace that can be mounted:

- inside the home window as a `HomeTab`
- inside separate note windows through the existing AppKit note window shell

## Hard Rules

- Zero copy-paste note UI logic.
- Do not create a separate "home notes editor" stack.
- Keep the existing AppKit note window shell for standalone note windows.
- The new home Notes page must use a native Apple sidebar with native resizing.
- Shared note/editor behavior must live in reusable views, not in `NoteWindowManager.swift`.
- If behavior diverges between home Notes and note windows, that is a bug unless explicitly intended.

## Why This Exists

The current app has:

- a home window with `Home`, `Library`, and `Settings`
- separate AppKit note windows managed by `NoteWindowManager`
- an existing `NotesBrowserView` / `NotesSidebar` browser surface that already contains useful sidebar logic

What it does not have is a shared notes workspace embedded in the main window.

The correct path is extraction and reuse, not duplication.

## Target UX

Add a new `HomeTab.notes` before `library`.

The home window Notes page should feel like a native macOS notes workspace:

- native `NavigationSplitView`
- native resizable sidebar
- note list / folder tree on the left
- selected note detail/editor on the right
- open-in-window behavior still available where useful
- same editor and note actions as standalone notes

## Existing Reuse Targets

These should be reused, not rewritten:

- `Epistemos/Views/Notes/ProseEditorView.swift`
- `Epistemos/Views/Notes/NotesSidebar.swift`
- `Epistemos/Views/Notes/NoteWindowManager.swift`
  - specifically the reusable note content currently trapped inside `NotePageContent`
- `Epistemos/State/NotesUIState.swift`

These are wrappers and should stay thin:

- home-window notes shell
- AppKit note window shell

## Required Refactor Boundary

### Extract Shared Note Detail

Move the reusable note-detail/editor surface out of `NoteWindowManager.swift` into a standalone shared view.

Suggested extraction:

- `SharedNoteDetailView`
- or `NoteWorkspaceDetailView`

This extracted view should own:

- page lookup
- editor mode switching
- preview/document mode toggles
- note chat state wiring
- TOC / word count / backlinks / toolbar note actions
- note editor content

Window-specific behavior should stay outside it:

- native window title syncing
- tab registration
- window delegates
- AppKit window lifecycle

### Refactor Sidebar Actions

`NotesSidebar` currently assumes window-opening behavior in several actions.

Refactor it to take injected actions such as:

- `onSelectPage(pageId)`
- `onOpenInWindow(pageId)`
- `onCreatePage()`
- `onClosePage(pageId)`

That lets the same sidebar drive:

- in-window note selection for the home Notes page
- standalone note window opening where needed

## Home Notes Architecture

Create a new shared container, for example:

- `NotesWorkspaceView`

Structure:

- `NavigationSplitView`
  - sidebar: native notes sidebar host
  - detail: shared note detail view for the selected page

Requirements:

- use native split-view resizing
- sidebar width should be bounded with `navigationSplitViewColumnWidth`
- selection must be driven by `NotesUIState.activePageId`
- selecting a note in the home workspace should not force opening a separate note window

Suggested initial sizing:

- min sidebar width: `240`
- ideal sidebar width: `300`
- max sidebar width: `420`

## Home Router Changes

Update `RootView.swift`:

- add `HomeTab.notes`
- place it before `library`
- update segmented toolbar labels/icons
- route `ContentRouter` to `NotesWorkspaceView`

This should be done without changing the standalone note-window path.

## Window Path Changes

`NoteWindowManager` should keep:

- AppKit `NSWindow`
- native `NSToolbar`
- native window/tab behavior

But it should stop owning reusable note content directly.

It should compose:

- `NoteTabShell`
- extracted shared note detail view

This keeps the window system AppKit-native while removing duplicate note-content logic.

## NotesBrowserView

`NotesBrowserView.swift` is now only a sidebar wrapper.

After the shared workspace lands:

- either repurpose it as the home Notes sidebar wrapper
- or delete it if `NotesWorkspaceView` makes it redundant

Do not keep multiple nearly-identical notes entry surfaces.

## Testing Requirements

At minimum add coverage for:

- `HomeTab.notes` selection and routing
- sidebar selection updates `NotesUIState.activePageId`
- selecting a note in the home workspace updates the detail pane instead of opening a window
- standalone note windows still open correctly
- note detail view can be mounted both in home Notes and in note windows
- no duplicate editor implementation is introduced

Manual verification:

- resize the native sidebar
- switch between Home / Notes / Library / Settings
- select multiple notes in the home workspace
- open a note in a separate window
- confirm editor behavior matches the standalone note path

## Execution Order

1. Extract reusable note detail from `NoteWindowManager.swift`.
2. Refactor `NotesSidebar` to use injected actions instead of hardcoded window behavior.
3. Build `NotesWorkspaceView` on `NavigationSplitView`.
4. Add `HomeTab.notes` before `library`.
5. Wire home Notes selection through `NotesUIState.activePageId`.
6. Reconnect standalone note windows to the extracted shared detail view.
7. Remove any redundant wrapper surface left behind.

## Non-Goals

- Do not redesign the editor stack here.
- Do not replace AppKit note windows with pure SwiftUI windows.
- Do not fork note-window-only toolbar logic into a second home-only implementation.
- Do not mix this plan with the TextKit parity audit work.

## Definition of Done

This plan is complete only when:

- Notes appears in the main home window before Library
- the sidebar is native and resizable
- the note detail/editor is shared code, not copied code
- standalone note windows still work
- home Notes and windowed Notes use the same editor behavior
- any redundant notes-browser wrapper code is removed or clearly repurposed
