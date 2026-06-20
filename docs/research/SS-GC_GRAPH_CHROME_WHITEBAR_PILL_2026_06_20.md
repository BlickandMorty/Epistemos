# SS-GC — Graph-tunnel chrome: code-editor white bar + landing-only pill + tunnel perf (2026-06-20)

Owner: *"the code editor is good but it has a top portion that is not the theme so there is a white bar at the top on
the graph when I open the code editor. also there is the pill that has the settings, the greeting, and the recent chats
that is always there — I only want it to exist on the landing page, so once I open graph I want the pill at the top to
disappear as well as the other surfaces… also deep research on ways to optimize performance + quality with the
home-graph tunnel."* Code-grounded, NON-INVASIVE (SwiftUI-layer only; TK2/Prose + Metal untouched). Extends SS-HGT/SS-AN.

## (B) Code-editor WHITE BAR in the graph — root + fix
Root: `codeEditorTopBar` (filename + line-count + Live-Preview/Find/etc. buttons), `Views/Notes/CodeEditorView.swift:2097-2179`,
rendered first in `editorContent` VStack (`:2069-2095`). Its fill = `flatBackground(for: ui.theme.surfaceVariant(.other))`
at `CodeEditorView.swift:2167` → `theme.card.opacity(...)` (`MarkdownTextView.swift:729-731`) = near-white card token.
**Why white only in the graph:** `CodeEditorView` is presentation-BLIND — `NoteDetailWorkspaceView` mounts it
(`:1242-1250`) passing NO `themeOverride` (unlike the prose branch `:1254-1260` which passes `noteWorkspaceTheme`). In
the embedded graph the surround paints the **landing background** token (darker: `NoteDetailWorkspaceView.noteWorkspaceTheme`
→ `surfaceVariant(.landing)` `:715-717`; `GraphWorkspaceContainer.embeddedPageSurface` `:44-48,162-165`;
`HomeGraphEmbeddedView` backdrop `:72,83`), so the `card`-colored bar pops as a white slab (in a detached window the canvas
is itself card-derived, so it blends).
**Fix [S]:** thread `themeOverride: EpistemosTheme? = nil` into `CodeEditorView` (`:1782-1868`) + pass `noteWorkspaceTheme`
from `NoteDetailWorkspaceView.swift:1250` (mirror the prose branch :1259); change `:2167` to
`AppWindowBackdropStyle.background(for: themeOverride ?? ui.theme)` (or `flatBackground(for:(themeOverride ?? ui.theme)
.surfaceVariant(.landing))`); apply same to canvas `:2317` + `WebKitCodeEditorView.swift:315` for full consistency.
Simpler alt: HIDE the top bar for `.embeddedGraph` (the graph already renders its own nav chrome —
`GraphWorkspaceContainer.embeddedGraphPageHeader:185`, `NoteDetailWorkspaceView.overlayGraphEmbeddedToolbar:1417` — so
the bar duplicates it). Test: render/snapshot or assert the bar uses the embedded theme token, not `.other`.

## (C) PILL — ⚠ REVISED (owner 2026-06-20): KEEP it (it's load-bearing for the curved window), swap its buttons
**OWNER NUANCE:** the pill must STAY mounted on the graph — WITHOUT a principal `ToolbarItem`, the window's unified-
titlebar treatment drops and the window REGRESSES to square (non-curved) corners (owner-confirmed empirically; the
toolbar's presence is what keeps the curve). So do NOT unmount it on graph (the original "landing-only/remove on graph"
plan below is SUPERSEDED). Instead: keep the pill mounted + visible on BOTH landing and graph (≥1 button → curve
preserved), but make its BUTTON SET PAGE-RELEVANT — landing shows the landing buttons; on the graph show graph-relevant
controls (e.g. settings + a graph/back control), NOT the landing greeting/recent-chats set. **DROP the recent-chat
(history) button** (`historyToolbarButton` RootView.swift:512-526) — owner says it caused issues; remove it (or make it
landing-only). Also revise the SS-AN pill blur: do NOT blur the pill fully away on graph (that defeats "keep it") — swap
contents instead; SS-AN's blur can remain for the OTHER non-pill toolbar items. Net: window stays curved everywhere; the
pill's buttons are contextual; recent-chats gone. Test: pill `ToolbarItem(.principal)` is present in BOTH landing AND
graph states (curve preserved); the button set differs by `embeddedHomeGraphContentVisible`; no history button.

### (original landing-only analysis — SUPERSEDED by the curve nuance above, kept for the file:line map)
Pill = `rootToolbarControls` `ControlGroup` (`App/RootView.swift:448-471`), `ToolbarItem(.principal)` `:300-311`:
`settingsToolbarButton` (`:473-479`), `landingGreetingToolbarButton` (`:497-510`), `historyToolbarButton`
(recent-chats `:512-526`). **Bug:** gated by `showLandingToolbarControls || showEmbeddedGraphToolbarControls`
(`:450`, `:300-302`); `showEmbeddedGraphToolbarControls` (`:234-236` = `embeddedHomeGraphCanvasVisible`) keeps the pill
MOUNTED on the graph. The SS-AN blur (`:460-462`, `.blur`/`.opacity` on `embeddedHomeGraphContentVisible`) only
VISUALLY hides it on the canvas route; on a graph note/folder route it leaks, and it's conceptually a graph-toolbar
member. **Fix [S]:** drop `showEmbeddedGraphToolbarControls` from the pill's gate (`:450`, `:300-302`) so the pill
mounts ONLY when `showLandingToolbarControls` (landing/empty-chat, never embedded graph); keep the SS-AN blur for the
landing→graph fade-out. Net: pill is landing-only (blurs out on graph reveal, then unmounts). Test: assert pill not in
tree when `embeddedHomeGraphContentVisible`.

## (A) Tunnel PERF (lighter pass — non-invasive observations)
- `.note(id)` route mounts `GraphNotePage(...).id(id)` → full `NoteDetailWorkspaceView` + WKWebView code-editor reinit
  on EVERY tunnel nav (`GraphWorkspaceContainer.swift:62-67`, `GraphNotePage.swift:25`, CodeEditor `.id` `NoteDetailWorkspaceView.swift:1250`). Inherent to `.id`-swap; a small page cache would help if nav feels heavy (optional).
- `switch graphState.currentRoute` re-evals the whole container body (incl. HTML dock + DAG layers) on any route change
  (`GraphWorkspaceContainer.swift:50-93`).
- `GraphHTMLWorkspaceDock.workspaces` = O(documents) `NSDocumentController` scan recomputed each body pass
  (`:382-391`, again in `selected` `:393-400`) — cache it; only mounts off-canvas so impact is route-overlay.
- `HomeGraphEmbeddedView` `.animation(.smooth, value: selectedNodeId)` spans the WHOLE ZStack (`:144-147`) — tighten to
  the inspector only (which already has scoped animation `:200-203`) to avoid full-chrome passes.
- Healthy: Metal single-instance + visibility-gated, physics frozen off-canvas, `shouldRenderCanvas` gates.

Order [S]: (B) white-bar + (C) landing-only pill first (quick, high-visibility); then the perf cache tweaks. Each
test-backed; single targeted swift build. Cross-ref SS-AN, SS-HGT, SS-PERF2.
