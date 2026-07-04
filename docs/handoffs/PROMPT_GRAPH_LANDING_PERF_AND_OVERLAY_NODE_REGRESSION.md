# PROMPT — (A) more perf beneath graph+landing, (B) overlay-graph node-click "halfway" regression

For an agent. Repo `/Users/jojo/Downloads/Epistemos`. Excludes Goose + AI-agents/june + OpenChamber.
Front & Feel lane. **MEASURE, don't guess** (Instruments / GraphFPSHUD / spindump). The Run scheme is
**Debug (-Onone, 10-50× slower than Release)** — compare a Release build FIRST. `BUILD SUCCEEDED`
before commit; never `git add -A`; one `xcodebuild` at a time on a 16 GB machine.

## PART A — squeeze MORE perf from the SHARED layer beneath graph + landing (main lag already fixed)

The HIGH lag was root-caused and FIXED: `MetalGraphView.deinit` ran a synchronous `group.wait()` on
the MAIN THREAD (draining detached embedding tasks before engine destroy), stalling the whole UI;
now off-main (`6fbb052fd` / `bed7b1080` / `b12b41266`). Owner confirms the lag is gone on Release and
now wants to squeeze MORE out of the layer both surfaces share — "beneath the graph and landing,"
not the whole app. Both surfaces are Metal-rendered; nothing else in the app is — so the shared
layer is Metal + the compositor:

- **MTLDevice creation** — `MetalGraphView.swift:892` (`MTLCreateSystemDefaultDevice()` per NSView),
  `CodeEditorView.swift:684`, `MetalRuntimeManager.swift:103`. Is a device (and command queue)
  created PER-SURFACE (expensive) or shared? A single shared `MTLDevice`/queue is the standard win.
- **Landing** — `LiquidMetalBackground.swift`: TWO `TimelineView(.animation(minimumInterval: 1/30,
  paused: false))` running stitchable shaders (`pixelGradient`, `liquidSheen`). `paused:false` is
  hardcoded — do both TimelineViews keep ticking + submitting GPU work when the window is occluded or
  the surface is off-screen? Gate them on occlusion/visibility.
- **Window backdrop** — `UnifiedFrostedGlass.swift` is an `NSVisualEffectView` wallpaper-blur that
  sits BENEATH both surfaces. A live blur kernel under an animating Metal layer is expensive; check
  whether it can be static/opaque behind the graph, or whether both a NSVisualEffectView blur AND a
  Metal gradient are compositing every frame.
- **Do NOT touch the animation math** — owner is explicit: "it's not the animation."

MEASURE: Instruments **Time Profiler** (filter main thread) + **Metal System Trace** (GPU) during the
animation; watch `GraphFPSHUD`. State the measured hot frame/GPU cost before changing anything.

## PART B — NEW REGRESSION: overlay-graph node click makes "the screen half way"

SYMPTOM (owner, verbatim intent): the OVERLAY graph — the full-screen **"Hologram"** graph, NOT the
home-page embedded one — has a layout bug: clicking a NODE makes "the screen like half way," a broken
split with the note/inspector that opens. The **home-page embedded graph (`HomeGraphEmbeddedView`) is
FINE** — so diff the overlay against it. This is a regression.

WHERE TO LOOK (overlay-graph node-selection → inspector/note-panel layout):
- `Epistemos/Views/Graph/HologramOverlay.swift` + `HologramController.swift` — the overlay shell.
- `Epistemos/Views/Graph/HologramNodeInspector.swift` + `NodeInspectorState.swift` — the panel shown
  on node click. The "halfway" is almost certainly THIS inspector/note panel taking ~50% width (or
  the graph shrinking to ~50%) instead of a proper overlay/sidebar ratio.
- `GraphWorkspaceContainer.swift` + `GraphOverlayPanel.swift` — the container split/geometry.
- Compare against `Epistemos/Views/Home/HomeGraphEmbeddedView.swift` (the WORKING one): what does the
  overlay do differently on node-select layout?

BISECT: `git log -p Epistemos/Views/Graph/Hologram*.swift GraphWorkspaceContainer.swift GraphOverlayPanel.swift`
for a recent layout/frame/split change. Recent graph commits to eyeball: `a0ebec156` (PERF-8),
`e6555e31b` (concurrency), plus the graph-view-recreation lineage.

FIX = restore the correct node-panel ratio (a proper overlay/sidebar, not a 50/50 split). VERIFY by
opening a node in the overlay graph and confirming the panel is a sidebar, not half the screen.

RAILS: don't touch Goose/june/OpenChamber or the animation math; measure before fixing; `BUILD
SUCCEEDED` before commit; never `git add -A` (40-50 concurrent dirty files — stage only your files).
