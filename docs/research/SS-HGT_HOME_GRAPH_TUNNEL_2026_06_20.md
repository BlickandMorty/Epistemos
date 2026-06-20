# SS-HGT — Home-graph tunnel: access ALL note/workspace surfaces inline (Epdoc + HTML workspace) (2026-06-20)

Owner: *"on the home graph I want to be able to access Epdocs and HTML workspace — literally access all note/workspace
surfaces through the home-graph tunnel itself. it's almost there; there are several things in the detached note
workspace not included in the home graph."* Code-grounded. NON-INVASIVE: TK2/Prose untouched, Metal graph engine
untouched, no vault mutation, reuse-not-duplicate. NOT a scope-boundary domain (no Companion/dual-brain).

## What the tunnel reaches TODAY
`HomeGraphEmbeddedView` (`Views/Home/HomeGraphEmbeddedView.swift:166-174`) → `GraphWorkspaceContainer`
(`Views/Graph/GraphWorkspaceContainer.swift:50-93`) switches on `graphState.currentRoute: GraphWorkspaceRoute`
(`Graph/Workspace/GraphWorkspaceRoute.swift:5-12`), which has only THREE cases:
- `.canvas` → Metal graph + inspector (`:58-60`)
- `.note(id)` → `GraphNotePage` → `NoteDetailWorkspaceView(presentation:.embeddedGraph)` (`:62-67`, `GraphNotePage.swift:23-30`) — so the tunnel ALREADY hosts inline: **Prose/TK2** (`NoteDetailWorkspaceView.swift:1254`), **Code editor** (`:1242`), **Markdown preview** (`:976`).
- `.folder(id)` → `GraphFolderPage` (`:69-78`)

Two surfaces are reachable from graph chrome but **break OUT into detached windows** (not inline):
- **HTML workspace:** `GraphHTMLWorkspaceDock` only previews open docs; "Edit" → `selected.document.showWindows()` (`GraphWorkspaceContainer.swift:545-547`) = separate window.
- **Epdoc:** clicking a `.document` node (`MetalGraphView.activateNode:1963-1980`) + search-sidebar menu (`HologramSearchSidebar.swift:1172-1184`) call `EpdocDocumentOpening.openDocument` → detached `EpdocDocument` NSWindow (`App/EpistemosDocumentController.swift:431-458`).

## The GAP (what the detached side has that the tunnel doesn't host inline)
| Surface | In tunnel? | Gap |
|---|---|---|
| Prose/TK2 note, Code, MD preview | ✅ inline (`.note`) | — |
| **Epdoc editor** (`EpdocEditorChromeView`, hosted by `EpdocDocument`) | ❌ detached window | no `.epdoc` route; `MetalGraphView.activateNode:1965`/`HologramSearchSidebar:1172` route to a window; `GraphState.openNode:759-766` has no `.document` case |
| **HTML workspace** (`HTMLWorkspaceEditorView`, hosted by `HTMLWorkspaceDocument`) | ❌ preview dock + detached window | no `.htmlWorkspace` route; dock "Edit" → `showWindows()` |
| PDF viewer | ❌ does not exist anywhere (only VaultParser ingests PDFs) | owner aspiration; `DocumentSurfaceKind.pdf` exists but has no view (see SS-T) |

Net: the two real missing tunnel surfaces are **Epdoc** and **HTML workspace** — both already have working SwiftUI
editor views; they're only ever mounted in detached `NSDocument` windows, and the graph open-paths deliberately route
around the tunnel into those windows. There is no unified doc-type→view router on either side; the closest taxonomy is
`Models/DocumentSurface.swift:DocumentSurfaceKind` (note/epdoc/htmlWorkspace/visualization/pdf/canvas/code) — a data
model, not a router.

## Plan (4 coordinated edits; reuse the route switch, don't duplicate editor hosting)
1. **[S] Extend the route enum** — `Graph/Workspace/GraphWorkspaceRoute.swift:5-12`: add `case epdoc(id:String)` +
   `case htmlWorkspace(id:String)` with `serializationKey`s (`epdoc:<id>`, `htmlworkspace:<id>`). Central seam.
2. **[M] Add view arms to the container switch** — `GraphWorkspaceContainer.swift:57-79`, mirroring `.note`:
   - `.epdoc(id)` → resolve/own an `EpdocDocument`/`EpdocEditorController` by manifest id, mount
     `EpdocEditorChromeView(controller:)` inline inside the same `graphNoteBackdrop` + `EmbeddedGraphRouteChrome`.
   - `.htmlWorkspace(id)` → resolve `HTMLWorkspaceDocument`, mount `HTMLWorkspaceEditorView(package:theme:)` inline.
   Both views accept a theme override → inherit the embedded landing theme. The route arm must OWN/retain the
   `NSDocument` (or look it up via `NSDocumentController.shared.documents`) so autosave + `dismantleNSView` teardown
   (`EpdocEditorChromeView.swift:330-365`) still fire on route exit — `GraphHTMLWorkspaceDock` already does this lookup
   (`GraphWorkspaceContainer.swift:382-391`) = the reuse template.
3. **[S→M] Redirect open-paths to push routes (keep window as explicit "Open in Window")** — `MetalGraphView
   .activateNode:1965-1976` (`.document` node) → `graphState.openEpdoc(manifestID)` (add to `GraphState` next to
   `openNote`/`openFolder` `:769-775` + a `.document` case in `openNode:759-766`); `HologramSearchSidebar:1172-1184`
   same; `GraphHTMLWorkspaceDock` Edit `:545-547` → push `.htmlWorkspace(id:)`.
4. **[M/L — the bigger piece, the real reason they feel absent] `GraphBuilder` project Epdoc/HTML as clickable nodes**
   — `GraphBuilder` (`Graph/GraphBuilder.swift:126,143,285,342`) emits only `.note/.idea/.folder/.chat/.source` today;
   add `.document` (Epdoc) nodes (`sourceId = manifest.id`) + optionally HTML-workspace nodes so they're reachable.

## Watch-outs
- `ArtifactHostView` (`Views/Workspace/ArtifactHostView.swift`) LOOKS like a doc-type router but is a v1-deferred stub
  (renders `ArtifactRouteDeferredPanel`) — do NOT route through it.
- Epdoc/HTML are `NSDocument`-backed → the route arm owns lifecycle; ensure teardown on route exit.
- Cross-ref SS-O/SS-EM/SS-P (Epdoc), SS-T (PDF — separate, no viewer yet). Order: enum+arms (1,2) first = inline Epdoc/
  HTML in the tunnel; then GraphBuilder nodes (4) = discoverable. Each test-backed; single targeted swift build.
