# HOLOGRAM GRAPH — content not filling/aligned with its window (handoff 2026-07-04 ~17:45)

REPO /Users/jojo/Downloads/Epistemos, branch feat/goose-surface. EXCLUDE Goose/june/OpenChamber lanes.

## CURRENT SYMPTOM (owner, after all fixes below)
The hologram overlay graph STILL does not take up its full surface. Owner: "it needs to just simply be
aligned with the window — it was working before, something we did today made it break." Interpretation to
verify FIRST: the overlay WINDOW may now be full-screen, but the GRAPH CONTENT (Metal canvas) renders in
a sub-region (likely the old ~900×900 square) instead of filling/aligning with the window. Do not assume —
reproduce and measure (tools below).

## KEYWORD + ROLLBACK
"change it back" = revert graph/metal/landing regressions to checkpoint tag
`checkpoint/change-it-back-2026-07-04` (= c2f1232b0, pre-loop HEAD; there is also a
...-dirty-snapshot tag). Selective revert of today's graph commits (do NOT hard-reset the branch —
other lanes commit concurrently):
  git revert 23d3f881a   # full-screen window revival (most likely interacting with the new symptom)
  git revert 1b45cd057   # shared MTLDevice (unlikely culprit, revert only if implicated)
  git revert fcaef6cc4   # inspector self-heal + eject glyph (fixes a REAL bug — keep unless implicated)

## WHAT WAS DONE TODAY (all committed, all in the owner's running builds)
1. f157d883a (absorbed into another lane's commit): LandingView.swift — LiquidMetalSurface `active:` gate
   extended with `&& ui.homeContent != .graph` (shader was ticking behind the opaque embedded-graph cover).
2. fcaef6cc4: HologramOverlay/HologramController —
   - observeNodeSelection: node click ALWAYS re-embeds the in-graph inspector card (self-heals the sticky
     "ejected" state; external floating panel had been spawning at graphFrame.minX-342 = mid-screen).
   - Eject button glyph arrow.up.left.and.arrow.down.right → macwindow.on.rectangle (it was identical to
     the expand button = accidental ejects).
   - toggle()/presentFullOverlay(): stopped routing minimized/soft-hidden state into restore() which was
     `guard false` DEAD CODE — Cmd+G no-op'd during the 10s soft-hide window.
3. 1b45cd057: MetalGraphView.swift — one static shared MTLDevice for all graph views (was
   MTLCreateSystemDefaultDevice per NSView). Rust FFI verified safe first: graph-engine/src/renderer.rs
   Renderer::new does dev_ref.to_owned() (retain, released on engine drop); queues stay per-engine.
4. 23d3f881a: THE BIG ONE — full-screen window revival:
   - restore() revived (guard false removed); frames to screen.visibleFrame at .floatingPanel level
     (NOT .screenSaver — that level was the May-10 lag source).
   - prepareImmersiveOverlayWindow(): fresh opens (!window.isVisible) now setFrame(screen.visibleFrame)
     instead of GraphMiniPanelLayout.frame (the right-pinned ≤900pt square).
   - createWindow(): isMinimized now starts FALSE + miniPanel nil (was true/aliased — broke minimize()'s
     !isMinimized guard on first open).
   - presentFullOverlay(): minimized+visible → restore(), else show().

## EVIDENCE BASE / WHAT WAS RULED OUT (don't re-tread)
- Live window probe (CGWindowList swift script, see TOOLS) measured the original bug: overlay = 900×900
  square at x=934 on 1920 screen (left edge = horizontal midpoint) + external inspector window 330×520 at
  x=592. "Half screen split" = that composition. Home-embedded graph fine (inspector is a SwiftUI card
  hard-framed 320×500 inside HomeGraphEmbeddedView.swift:181-207).
- Embedded overlay inspector card is hard-clipped 330×520 (HologramNodeInspector.swift:121-123
  inspectorWidth/Height + .clipped()) — it CANNOT be the half-screen panel.
- GraphWorkspaceContainer routes and GraphNotePage/NoteDetailWorkspaceView(.embeddedGraph) are full-width
  (maxWidth .infinity); note-toolbar maxWidth 900 is centered chrome only.
- Page mode disabled (HologramController.pageModeEnabled=false). showMini() has no callers.
- History: overlay was genuinely full-screen until 004b15537 (2026-05-10 "Fuse full-screen + mini graph
  into single mini ontology"); inspector default external→embedded flipped in 453fbafd9 (2026-05-22).
- Recent-week graph diffs (a0ebec156, f6c4336d9, cb435e5aa, e6555e31b, e00edcbd9…) contain NO
  layout/frame/split geometry change.

## PRIME SUSPECTS FOR THE REMAINING SYMPTOM (verify in order)
1. CAMetalLayer drawableSize vs window re-frame: my revival re-frames the window PROGRAMMATICALLY
   (setWindowFrame → animator().setFrame). Check MetalGraphNSView's resize handling — where does
   layer.drawableSize get updated (setFrameSize/layout/viewDidChangeBackingProperties)? If it misses the
   animated programmatic resize, the engine keeps rendering at the old 900×900 drawable → content sits in
   a corner/stretch = "graph not aligned with window". renderFrame reads layer.drawableSize at
   MetalGraphView.swift:1842-1848.
2. contentView was created at the 900-square initialFrame (createWindow, HologramOverlay.swift:2075);
   subviews autoresize [.width,.height] — verify contentView + graphView + blurView frames actually track
   the visibleFrame re-frame (probe with winlist + Accessibility inspector or log frames).
3. Rust engine camera/zoomToFit after resize: engine viewport w/h comes from drawableSize per frame; a
   stale camera fit could also read as "content in part of the window" — graphView.zoomToFit() exists.
4. If owner means the overlay should align with the MAIN APP WINDOW (1100×720) rather than the screen:
   that is a DESIGN decision — ask the owner ONE question ("full screen, or sized to match the app
   window?") before re-architecting. attachFloatingPanelToMainWindow already parents it to the main window.

## TOOLS THAT WORKED (reuse)
- Window probe: /private/tmp/claude-501/-Users-jojo/b0be0307-4d9f-4a7c-833e-77bb418b88f4/scratchpad/winlist.swift
  (CGWindowList dump of Epistemos windows: `swift winlist.swift`). Copy it somewhere durable.
- Which binary has a fix: `strings <App>.app/Contents/MacOS/Epistemos.debug.dylib | grep <marker>` — the
  main executable is a 59KB stub; code lives in Epistemos.debug.dylib. Known marker for fcaef6cc4:
  "macwindow.on.rectangle".
- Owner launches builds from OTHER lanes' DerivedData (~/.cache/epistemos-dd-mas, various scratchpad
  dd-pro/dd-agentA) — ALWAYS check the running binary's dylib mtime + marker before concluding a fix
  failed. This burned us twice today (both directions).
- Idle GPU baseline measured: 30s Metal System Trace attached to the app = ZERO CAMetalDrawable presents
  at rest. Landing stitchable shaders run in the RENDER SERVER, not the app process — an attach-scoped
  trace cannot attribute them.

## RAILS (unchanged)
Don't touch Goose/june/OpenChamber or the animation math. MEASURE before fixing (Instruments Time
Profiler + Metal System Trace + GraphFPSHUD — Settings→Graph performance, UserDefaults key
epistemos.graph.showFPSHUD). BUILD SUCCEEDED before commit. NEVER git add -A (stage only your files).
One xcodebuild at a time — NOTE: this session's xcodebuilds were repeatedly KILLED by other lanes even on
a clear queue; if that happens validate via another lane's green full-tree build of the same working tree
(dylib link time > your last edit mtime + marker string) before committing. Release builds were failing in
ProAgent lane's ProAgentRuntimeSupervisor.swift (their dirty file, they were mid-fix ~17:00).

## VERIFY BAR
Open the hologram overlay → the GRAPH CONTENT fills the overlay window edge-to-edge (allowing the 28pt
rounded corners) at whatever frame the window has; click a node → inspector is the embedded 330×520 card
near the node; double-click → note page fills the window; minimize → right square; expand button → back
to full. Confirm with the winlist probe + a screenshot, not by reading code.
