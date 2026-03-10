# Embedded Graph — Design Spec

**Date:** 2026-03-10
**Status:** Approved

## Overview

A lightweight, embedded graph view that lives inside the Notes workspace tab system. Separate from the existing HologramOverlay (full-screen graph). Reuses the Metal + Rust FFI rendering pipeline but with simplified chrome and lower resource usage.

Inspired by Obsidian's graph view: full-tab graph, pinned split alongside editor, local/global toggle.

## Entry Point

The "Most Recent" button on `NotesWorkspaceLandingView` is replaced with an **"Open Graph"** button. Pressing it opens a new workspace tab containing the embedded graph in global mode.

## Two Modes

### 1. Standalone Graph Tab

- Opens as a regular workspace tab in the tab bar (e.g., `[Home] [Graph] [Note A] [+]`)
- Default scope: **global** (all notes, all connections)
- Toggle in top-left corner switches between Global and Local
- Local toggle in standalone mode uses `notesUI.workspacePageId` (the last active note). If no note has been opened this session, local toggle is disabled/hidden.
- "Pin Split" button in top-right enters split mode (see below)
- Full Metal + Rust rendering, same visual quality as overlay

### 2. Graph Split Mode

- Activated via "Pin Split" button on the graph tab
- Graph moves to the **right side** of the detail pane
- Left side shows the note editor (whatever note is active)
- **Resizable divider** between editor and graph
- `splitRatio` is the fraction of detail pane width allocated to the editor. Default: `0.55`. Range: `0.3–0.8` (clamped to prevent either pane from becoming unusably small). Persisted in `UserDefaults`.
- Default scope: **local** (centered on active note, N-depth neighbors)
- Toggle still available to switch to global
- "Unpin" button closes the split — graph tab is restored (hidden but preserved during split, including its navigation state)
- Tab bar shows a "GRAPH SPLIT" indicator

### Split Sync Behavior

When split is active, the graph **auto-follows navigation**:
- Sidebar click on a different note → editor shows that note, graph re-centers on its node
- Wikilink navigation → same behavior
- The focused node gets a highlight ring to indicate "you are here"
- If active tab is the **landing** (no note), the split is hidden — landing renders without graph. Split reappears when a note tab becomes active.

### Closing the Graph Tab While Split

If the user closes the graph tab (X button) while split is active, the split collapses immediately. `EmbeddedGraphState.isSplitActive` resets to `false`. Detail pane reverts to editor-only (or landing if no note).

## Navigation Stack (Standalone Tab)

The graph tab uses a new `GraphNavigationState` for breadcrumb navigation:
- `GraphNavigationState` wraps `NoteNavigationState` and manages the graph-as-root concept
- `currentPageId` returns `nil` when at graph root (detail pane renders `EmbeddedGraphView`)
- `currentPageId` returns a page ID when navigated to a note (detail pane renders editor)
- **Double-click** a node → pushes note editor onto the stack (replaces graph in the same tab)
- **Right-click → "Open Note"** → same behavior
- **Back button** (top-left) → pops back to the graph
- This avoids modifying `NoteNavigationState`'s existing contract (which requires a real `rootPageId`)

## Node Interactions

### Click/Select → Floating Popover

Single-click a node shows a floating popover near the node:
- **Title** (note name)
- **Subtitle** (connection count, last modified)
- **"Open Note" button** — navigates to note (push in standalone, left-pane in split)
- **"Focus" button** — zooms graph to center on this node + neighbors
- Dismisses on click-away, Escape, or any graph pan/zoom
- **Position**: computed by converting node world coordinates to view coordinates via the engine's coordinate transform, clamped to view bounds to prevent clipping

### Right-Click → Context Menu

Native `NSMenu` context menu on right-click:
- Open Note
- Focus on Node
- Show Connections (highlight edges)
- Copy Link (wikilink to clipboard)

### Double-Click → Open Note

Shortcut for "Open Note" — same as popover button behavior.

## Renderer & Engine

### New NSView (does NOT reuse MetalGraphNSView)

`MetalGraphNSView` is tightly coupled to the overlay's `GraphState` — it writes `graphState?.engineHandle` and reads `graphState.mode`. Reusing it would require invasive changes.

Instead, a new **`EmbeddedGraphNSView`** (NSView subclass) wraps a `CAMetalLayer` with its own `GraphEngine` instance. It follows the same patterns as `MetalGraphNSView` (setup, render loop, hit testing) but reads from `EmbeddedGraphState` instead of `GraphState`. Wrapped by `EmbeddedGraphView` (NSViewRepresentable) for SwiftUI integration.

### Engine Lifecycle

- **Creation**: `EmbeddedGraphNSView.setupMetal()` creates the Rust engine via `graph_engine_create()` when the Metal view first appears. Sets `embeddedGraphState.engineHandle` as a reference.
- **Data loading**: On creation (and on scope change), `EmbeddedGraphState.syncGraph()` reads from the shared `GraphStore` and feeds data to the embedded engine via `graph_engine_add_node` / `graph_engine_add_edge` / `graph_engine_commit`.
- **Destruction**: When the graph tab is closed or the split is dismissed, `EmbeddedGraphNSView.deinit` calls `graph_engine_destroy`. `EmbeddedGraphState.engineHandle` is set to `nil`.
- **Vault switch**: `NotesUIState.resetForVaultSwitch()` also resets `EmbeddedGraphState` — clears engine, resets `isSplitActive`, scope returns to `.global`.

### Data Sync (GraphStore → Embedded Engine)

The embedded engine maintains its own copy of graph data (independent from the overlay engine). Data flows:

1. **On graph tab open**: Full sync — read all nodes/edges from `GraphStore`, feed to engine, commit.
2. **On scope change** (global ↔ local): Re-sync with appropriate subset.
3. **On `GraphStore` mutation** (new note, wikilink edit, vault sync): Incremental update — add new nodes/edges, recommit. Subscribe to `GraphStore` change notifications.

### Performance Optimizations

- **Tick rate**: 30Hz physics (vs 60Hz overlay) — smooth enough for interaction, half the CPU cost
- **Freeze on stable**: Stop physics ticking once layout converges. Reheat on: `GraphStore` mutations (node/edge additions from vault sync or user edits), scope changes, user drag interactions.
- **Culling**: Only render nodes visible in viewport (Rust engine already supports this)
- **Minimal chrome**: No frosted glass overlay, no floating search sidebar, no heavy blur layers

## State Model

New `@MainActor @Observable` class: `EmbeddedGraphState`

Standalone state object injected via `AppEnvironment` (like `GraphState`, `PhysicsCoordinator`).

```
EmbeddedGraphState {
  var isVisible: Bool               // Graph tab exists in workspace
  var isSplitActive: Bool           // Split mode active (distinct from WorkspaceTab.isPinned which means tab-bar pinning)
  var scope: GraphScope             // .global | .local(noteId: String)
  var focusedNodeId: String?        // Currently selected/highlighted node
  var hoveredNodeId: String?        // Own hover state (independent from PhysicsCoordinator)
  var splitRatio: CGFloat           // Editor fraction of detail pane. Default 0.55. Range 0.3-0.8.
  var engineHandle: OpaquePointer?  // Own Rust engine handle (set by EmbeddedGraphNSView)

  func syncGraph(from store: GraphStore)  // Full data load into engine
  func focusOnNode(_ nodeId: String)      // Center + zoom
  func resetForVaultSwitch()              // Clear engine, reset state
}
```

### Hover Isolation

The embedded graph uses `EmbeddedGraphState.hoveredNodeId` for hover tracking — **not** `PhysicsCoordinator.graphHoveredNodeId`. This prevents cross-highlight between the overlay and embedded views. The sidebar `graphReactive` modifier only responds to `PhysicsCoordinator` (overlay hover), not embedded graph hover.

## Integration with NotesUIState

`WorkspaceTab` gains awareness of graph:

```
struct WorkspaceTab {
  let id: String
  var pageId: String?       // nil = landing, set = note
  var isGraphTab: Bool      // true = this tab shows the graph
  // NOTE: WorkspaceTab.isPinned retains its existing meaning (tab-bar pin order).
  // Graph split state lives exclusively in EmbeddedGraphState.isSplitActive.
}
```

When `isGraphTab` is true and `!isSplitActive` → detail pane renders `EmbeddedGraphView`.
When `isSplitActive` is true → detail pane renders `GraphSplitView(editor, graph)` with resizable divider.

## View Hierarchy

```
NotesWorkspaceView (existing)
├─ NotesSidebar (unchanged)
└─ Detail Pane
   ├─ if isSplitActive && activeTab has a page:
   │   └─ GraphSplitView
   │      ├─ NoteDetailWorkspaceView (editor, left)
   │      └─ EmbeddedGraphView (graph, right)
   ├─ if isSplitActive && activeTab is landing:
   │   └─ NotesWorkspaceLandingView (no split — split hidden until note active)
   ├─ if activeTab.isGraphTab && !isSplitActive:
   │   └─ EmbeddedGraphView (full tab, or note editor if navigated via nav stack)
   ├─ if activeTab.pageId != nil && !isSplitActive:
   │   └─ NoteDetailWorkspaceView (editor, unchanged)
   └─ if landing && !isSplitActive:
       └─ NotesWorkspaceLandingView (with "Open Graph" button)
```

## New Files

| File | Purpose |
|------|---------|
| `Views/Notes/EmbeddedGraphView.swift` | NSViewRepresentable wrapping EmbeddedGraphNSView |
| `Views/Notes/EmbeddedGraphNSView.swift` | NSView subclass with CAMetalLayer + own GraphEngine |
| `State/EmbeddedGraphState.swift` | Observable state for embedded graph |
| `State/GraphNavigationState.swift` | Navigation stack with graph-as-root (wraps NoteNavigationState) |
| `Views/Notes/GraphNodePopover.swift` | Floating popover on node click |
| `Views/Notes/GraphSplitView.swift` | Resizable HSplit for split mode |

## Files Modified

| File | Change |
|------|--------|
| `State/NotesUIState.swift` | `WorkspaceTab.isGraphTab`, `resetForVaultSwitch()` resets graph state |
| `Views/Notes/NotesWorkspaceView.swift` | Detail pane routing for graph tab/split |
| `Views/Notes/NotesWorkspaceLandingView.swift` | Replace "Most Recent" with "Open Graph" |
| `App/AppEnvironment.swift` | Inject `EmbeddedGraphState` |
| `App/AppBootstrap.swift` | Create `EmbeddedGraphState` instance |

## Isolation from Overlay Graph

The embedded graph is **completely independent** from `HologramOverlay`:
- Own Rust engine handle (not shared)
- Own NSView subclass (`EmbeddedGraphNSView`, not `MetalGraphNSView`)
- Own hover state (`EmbeddedGraphState.hoveredNodeId`, not `PhysicsCoordinator`)
- Own view hierarchy (inline SwiftUI, not NSWindow/NSPanel)
- Reads from shared `GraphStore` (read-only, same data source)
- No shared mutable state beyond `GraphStore`
- `Cmd+G` still toggles the overlay as before — no interference
- Both can be visible simultaneously without conflict

## Keyboard Shortcuts

Deferred to a future iteration. Mouse interactions (click, right-click, double-click) are the primary input for v1. Keyboard navigation (arrow keys, Cmd+F search, zoom shortcuts) will be added based on usage feedback.

## Not In Scope

- Search within embedded graph (use sidebar search)
- Graph filtering/tagging UI
- Drag-and-drop node rearrangement
- Custom graph layouts (force-directed only, via Rust engine)
- Graph editing (create/delete nodes from graph view)
- Keyboard shortcuts (deferred to v2)
