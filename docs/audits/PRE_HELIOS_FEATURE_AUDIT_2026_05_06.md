---
state: audit
scope: pre-Helios feature verification
created: 2026-05-06
owner: Codex
---

# Pre-Helios Feature Audit — 2026-05-06

## Scope

User direction: pause Helios work and verify the features that existed before the Helios push, especially `.epdoc`, Halo, DAG/graph surfaces, image insertion, and document graph affordances. This audit deliberately avoids deleting scaffold unless it is proven-dead/superseded; protected editor and graph paths stay intact unless a focused regression requires touching them.

Local canon read before edits:

- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` §5 Halo / Contextual Shadows / Recall
- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` §7 Editor / `.epdoc`
- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` §10 Graph Engine protected path
- `.agents/skills/epistemos_release_audit/SKILL.md`

## Slice 1 — Epdoc Editor, Images, and Document Graph Button

### Findings

- `.epdoc` now opens as a native macOS document window with the centered curved toolbar and visible placeholder text. Computer Use visual smoke confirmed a live `Untitled` document window with `Start writing your Epistemos document...`, native toolbar controls, and document stats.
- The toolbar image button previously relied on a URL-style insertion path. That did not satisfy the Apple Notes-like expectation that a user can choose a local image and see the actual image in the document.
- The toolbar graph button still effectively behaved like a static Mermaid sample path. That explains the user's observed `Idea -> Evidence` result after pasting a long document.
- A second static graph path existed in the slash-menu Mermaid entry, which also inserted the old `A[Idea] --> B[Evidence]` sample. This meant the stale sample could survive even after the toolbar was fixed.
- Computer Use could inspect the window, but click/type actions against the WKWebView returned macOS accessibility/window errors in this session. Treat interaction smoke as partial, not complete.

### Changes Made

- `Epistemos/Views/Epdoc/EpdocEditorToolbar.swift`
  - Image button now opens a native `NSOpenPanel` restricted to `.image`.
  - Picked images are inserted as displayable `data:<mime>;base64,...` URLs so the WKWebView renders the actual image immediately.
  - Flowchart button now dispatches `insertEpdocGraphFromDocument` instead of inserting the old static Mermaid sample.
  - Icon-only toolbar buttons now use semantic `Label(tip, systemImage:)` plus explicit accessibility labels.

- `js-editor/src/bridge/inbound.ts`
  - Added `insertEpdocImage` handling that calls the real Tiptap image node command.
  - Added `insertEpdocGraphFromDocument`, which reads the live ProseMirror JSON tree and builds a deterministic Mermaid graph from headings, paragraphs, and list items through the shared graph builder.
  - Toolbar/slash-driven edits now post stats and content snapshots immediately after successful commands.

- `js-editor/src/graph/document-graph.ts`
  - Added the shared document-to-Mermaid graph builder used by both toolbar and slash-menu insertion.
  - Removed the duplicated static `Idea -> Evidence` behavior from the `.epdoc` insertion surfaces without touching protected graph renderer internals.

- `js-editor/src/extensions/slash-menu.ts`
  - Renamed the Mermaid slash entry to "Document graph".
  - Rewired it to build from the live editor document instead of inserting the static sample.

- `js-editor/src/editor.css`
  - Added scaled, visible `img[data-epdoc-image]` rendering with rounded document-image styling and selected-node outline.
  - Removed duplicate image styling so one rule owns the visual behavior.

- `EpistemosTests/EpdocVisibilitySourceGuardTests.swift`
  - Added guards that image insertion uses a native file picker and data URLs.
  - Added guards that image nodes render as real document images, not icon-only placeholders.
  - Added guards that the graph affordance is "Graph from document" and reads the live ProseMirror tree.

- `EpistemosTests/EpdocSlashMenuViewTests.swift`
  - Added a guard that the Swift slash-menu catalogue exposes "Document graph" instead of the old static Mermaid sample label.

- `build-agent-core.sh`
  - Hardened the temporary dylib staging path used by the Xcode Rust build phase.
  - Replaced the old macOS-unsafe `mktemp ../build-rust/libagent_core.XXXXXX.dylib` shape with a real unique temp path plus cleanup trap.
  - Added a `ProductionHardeningTests` source guard so the literal-suffix pattern does not regress.

### Verification

- `npm run typecheck` in `js-editor` — PASS
- `./build-tiptap-bundle.sh` — PASS; refreshed `editor.css.br` and `editor.js.br`
- Post-shared-builder rerun:
  - `EpdocVisibilitySourceGuardTests`
  - `EpdocSlashMenuViewTests`
  - Result: 16 Swift Testing tests passed
- Post-structural-builder rerun:
  - `npm run typecheck` — PASS
  - `./build-tiptap-bundle.sh` — PASS
  - First Xcode attempt cancelled before test execution because the Rust build phase used macOS `mktemp` with non-trailing `X` characters (`../build-rust/libagent_core.XXXXXX.dylib`), which can become a literal path and collide.
  - Build-system hardening applied in `build-agent-core.sh`: temp dylib staging now uses a real suffix-free `mktemp` path plus cleanup trap, and `ProductionHardeningTests` guards against the old literal-suffix pattern.
  - Narrow rerun after hardening:
    - `EpdocVisibilitySourceGuardTests`
    - `EpdocSlashMenuViewTests`
    - `ProductionHardeningTests/appStoreBuildCompilesAgentCoreWithMasBuildFeature`
    - Result: `** TEST SUCCEEDED **`; Swift Testing executed 16 selected tests. The `ProductionHardeningTests` selector was accepted by xcodebuild but did not execute a Swift Testing case in this invocation, so the build-script guard still needs a clean selector rerun before it is fully signed off.
  - Follow-up display-name selector rerun for the production-hardening case also produced `** TEST SUCCEEDED **` with 0 executed tests. Do not count that as test evidence; count only source review, `bash -n build-agent-core.sh`, and the manual macOS `mktemp` proof until the Swift Testing selector is repaired.
  - `bash -n build-agent-core.sh` — PASS
  - Manual `mktemp` proof from `agent_core`: produced a unique suffix-free staging basename (`libagent_core.<random>`) and removed it successfully.
- Focused Swift test pass:
  - `EpdocDocumentTests`
  - `EpdocEditorBridgeTests`
  - `EpdocVisibilitySourceGuardTests`
  - `EpdocComplexityCalculatorTests`
  - `ProseMirrorMarkdownProjectorTests`
  - Result: 86 Swift Testing tests passed
- Post-cleanup narrow rerun:
  - `EpdocVisibilitySourceGuardTests`
  - Result: 8 tests passed
- Computer Use visual smoke:
  - Initial Computer Use inspection attached to an older DerivedData app process that still showed the stale "Image URL" path; that result is recorded as stale-build evidence only and is not counted against the latest build.
  - Latest-build smoke launched the exact executable at `.derived-data-epdoc-audit/Build/Products/Debug/Epistemos.app/Contents/MacOS/Epistemos`.
  - `New Doc` opened a native `.epdoc` document window with the visible placeholder, toolbar controls, document stats, and native titlebar/toolbar shape.
  - The image button opened a native `NSOpenPanel` titled "Choose Image" with the prompt "Insert a local image into this Epistemos document." This verifies the picker path replaced the old URL prompt.
  - Computer Use inserted markdown text containing a heading, paragraph, list items, and wikilinks; the editor rendered the text and updated document stats.
  - `Graph from document` inserted a live Mermaid graph rooted at `Document` with derived heading/body/list/wikilink nodes including `Beta` and `Gamma`, not the old static `Idea -> Evidence` sample.
  - A first 142-byte PNG fixture rendered as the selected broken-image fallback; follow-up inspection showed the fixture was not valid enough for `sips` metadata, so it is not counted as app failure.
  - A valid generated PNG fixture opened through the native picker, rendered as an actual bitmap in the editor, saved into `content.pm.json` and `projections/shadow.md` as a `data:image/png;base64,...` URL, and rendered again after close/reopen.
  - Save/reopen exposed a separate status refresh bug: visible content reloaded, including Mermaid and image content, but toolbar/status counters reset to `0 words`, `0 Mermaid`, and `0 embeds` after reopening.
  - Still not signed off in this slice: global graph/Halo visibility after autosave.
- Runtime log check:
  - The smoke process stdout log at `/tmp/epistemos-epdoc-audit.log` was empty, so it provides no app-authored success/failure evidence.
  - Unified log filtering did not surface app-authored `.epdoc` graph-projection failures during the smoke.
  - Unified logs did show existing WKWebView/WebContent sandbox lookup noise around pasteboard, CoreServices, LaunchServices, AppIntents, and AudioComponentRegistrar access. The editor smoke still worked, so this is tracked as a runtime watch item rather than a blocker for the graph-button fix.

## Slice 2 — Graph Artifact Visibility Gate

### Findings

- The Wave 3.3 graph/artifact cases already existed in `GraphNodeType.appLevelCases`, and the FFI contract correctly kept them out of `GraphNodeType.allCases`.
- The default Swift graph filter still initialized from FFI-only cases, so app-level graph nodes such as `.proseNote`, `.document`, `.code`, and `.output` were invisible by default even if a writer eventually persisted them.
- App-level artifact edges (`.producedDuring`, `.generatedBy`, `.derivedFrom`, `.summarizes`) had the same problem: they existed, but the default edge filter started from FFI-only `GraphEdgeType.allCases`.
- This does not by itself persist `.epdoc` documents into SwiftData graph nodes. It removes a downstream invisibility gate so the next persistence slice will not appear broken after writing valid artifact nodes.

### Changes Made

- `Epistemos/Models/GraphTypes.swift`
  - Preserved `GraphNodeType.allCases` as the strict 14-case Rust FFI list.
  - Preserved `GraphEdgeType.allCases` as the strict 12-case Rust FFI list.
  - Expanded `GraphNodeType.visibleCases` to include app-level artifact cases while still excluding `.block`.
  - Added `GraphEdgeType.visibleCases` as FFI edges plus app-level artifact edges.

- `Epistemos/Graph/FilterEngine.swift`
  - Default edge filters now initialize from `GraphEdgeType.visibleCases`.
  - `showAllEdgeTypes()` and `isFiltered` now compare against the graph-visible edge set, not the FFI-only set.

- `Epistemos/Views/Graph/GraphFloatingControls.swift`
  - Updated stale comments that still described the old small visible-type count.

- `EpistemosTests/GraphNodeTypeArtifactBridgeTests.swift`
  - Added a regression test proving Wave 3.3 app-level artifact cases are graph-visible while staying out of the FFI case list.

- `EpistemosTests/FilterEngineTests.swift`
  - Added regression tests proving app-level artifact nodes and edges are visible under the default filter.

### Verification

- Failing-before focused run:
  - `GraphNodeTypeArtifactBridgeTests`
  - `FilterEngineTests`
  - Result: `** TEST FAILED **`; new tests recorded the expected failures for app-level node and edge visibility.
- Passing-after focused rerun:
  - `GraphNodeTypeArtifactBridgeTests`
  - `FilterEngineTests`
  - Result: `** TEST SUCCEEDED **`; 18 Swift Testing tests passed.
- Adjacent graph-control guard rerun:
  - `GraphNodeTypeArtifactBridgeTests`
  - `FilterEngineTests`
  - `NoteWindowManagerTests`
  - Result: `** TEST SUCCEEDED **`; 49 Swift Testing tests passed.
- Runtime logs during the passing run still showed existing non-fatal test-environment noise:
  - `NightBrain search index maintenance requires an initialized SearchIndexService`
  - Metal cache `flock failed` messages
  - These did not fail the selected suites, but remain log evidence to keep watching during broader runtime smoke.

## Slice 3 — Epdoc Graph Persistence Bridge

### Findings

- `EpdocGraphProjector` and `EpdocGraphRenderingMapper` were not dead code, but the projector had no production writer. It could prove a projection in tests, yet saved `.epdoc` content did not materialize document/wikilink/provenance edges into `SDGraphNode` / `SDGraphEdge`.
- `EpdocDocument.projectAndIndexBlocks` only updated readable blocks and FTS. That kept `.epdoc` search alive but left the global graph/Halo path blind to `.epdoc` packages.
- `EpistemosDocumentController` injected a database writer into opened `.epdoc` documents, but it did not inject the app `ModelContainer`, so document packages had no route to the SwiftData graph store.
- `GraphBuilder.persist` could delete app-level artifact `.reference` edges if both endpoints had `sourceId` values because it treated all source-backed reference edges as graph-builder-owned.
- The toolbar/slash graph button now inserts a live structural Mermaid graph into the document. This slice is separate: it makes saved `.epdoc` packages project into the global graph store so graph/Halo surfaces have data to render.

### Changes Made

- `Epistemos/Engine/EpdocGraphPersistence.swift`
  - Added a rebuildable SwiftData writer for `.epdoc` graph projections.
  - Upserts a document node by package manifest ID.
  - Replaces stale outgoing non-manual projected edges for reference/provenance edge kinds on resave.
  - Creates label-backed `.idea` target nodes for wikilinks so `[[Alpha]]` becomes visible graph structure instead of a dangling string.

- `Epistemos/Engine/EpdocDocument.swift`
  - Added `graphModelContainer` dependency.
  - Autosave now calls both readable-block indexing and graph projection persistence.
  - Malformed JSON remains non-fatal; autosave logs and continues instead of crashing.

- `Epistemos/App/EpistemosDocumentController.swift`
  - Stores an optional graph `ModelContainer`.
  - Injects the container into `EpdocDocument` during document dependency wiring.

- `Epistemos/App/EpistemosApp.swift`
  - Wires `AppBootstrap.shared.modelContainer` into the document controller at launch alongside the existing database writer.

- `Epistemos/Engine/EpdocGraphProjector.swift`
  - The projection root now uses the manifest-backed artifact node type (for `.epdoc`, `.document`) instead of collapsing every package into the legacy `.note` type.

- `Epistemos/Graph/GraphBuilder.swift`
  - Preserves app-level artifact edges during graph-builder diff persistence so `.epdoc` projection edges do not disappear during legacy note/chat graph rebuilds.

- `EpistemosTests/EpistemosDocumentControllerTests.swift`
  - Added graph-container injection tests.
  - Added `projectAndPersistGraph` nil-container no-op coverage.
  - Added materialization coverage proving saved `.epdoc` content creates a `.document` node and wikilink edge.
  - Added resave coverage proving stale outgoing projection edges are replaced.

- `EpistemosTests/GraphBuilderComprehensiveTests.swift`
  - Added a regression proving app-level artifact reference edges survive `GraphBuilder.persist`.

### Verification

- Red run before implementation:
  - `EpdocGraphProjectorTests`
  - `EpistemosDocumentControllerTests`
  - `GraphBuilderPersistTests`
  - Result: `** TEST FAILED **`; new tests failed at compile time because `EpdocDocument.graphModelContainer`, `projectAndPersistGraph`, and document-controller model-container injection did not exist yet.
- First implementation rerun:
  - Result: `** TEST FAILED **`; Swift compiler reported "unable to type-check this expression in reasonable time" inside the generated SwiftData `#Predicate` macro for the stale-edge filter.
- Minimal fix:
  - Replaced the complex multi-clause SwiftData predicate with a source-node fetch plus ordinary Swift filtering over `isManual` and projected edge type raw values.
- Passing focused rerun:
  - `EpdocGraphProjectorTests`
  - `EpistemosDocumentControllerTests`
  - `GraphBuilderPersistTests`
  - Result: `** TEST SUCCEEDED **`; 27 Swift Testing tests passed.
- Adjacent regression rerun:
  - `EpdocDocumentTests`
  - `EpdocEditorBridgeTests`
  - `EpdocVisibilitySourceGuardTests`
  - `EpdocComplexityCalculatorTests`
  - `ProseMirrorMarkdownProjectorTests`
  - `EpdocGraphRenderingMapperTests`
  - `GraphNodeTypeArtifactBridgeTests`
  - `FilterEngineTests`
  - `NoteWindowManagerTests`
  - Result: `** TEST SUCCEEDED **`; 141 Swift Testing tests passed.

## Slice 4 — Epdoc Reopen Loader / Autosave Integrity

### Findings

- Reopen smoke exposed a genuine data-integrity bug, not just stale UI counters.
- A stale-build visual pass showed the opened document content, Mermaid preview, and image, but the status strip stayed at `0 words`, `0 chars`, `Mermaid 0`, `Embeds 0`.
- File inspection then showed `content.pm.json` had shrunk from the expected rich document payload to a 101-byte placeholder paragraph. That proved a boot-time snapshot could autosave over the real package.
- Root cause: Tiptap / `UniqueId` can emit an `onUpdate` for the editor's default boot placeholder before Swift pushes package content through `setContent`. The debounced JS `contentDidChange` path treated that placeholder update as a user edit and the Swift autosave pipeline persisted it.
- A secondary counter issue came from JS stats being allowed to overwrite Swift-derived initial counters during load.

### Changes Made

- `js-editor/src/bridge/document-load-state.ts`
  - Added a small bridge-load sentinel that tracks whether native host content has been loaded.

- `js-editor/src/index.ts`
  - `onUpdate` now posts live stats as before, but only emits `contentDidChange` after host package content has been loaded.
  - This preserves user-edit autosave while blocking boot-placeholder autosave.

- `js-editor/src/bridge/inbound.ts`
  - `setContent` still uses `emitUpdate: false`.
  - After successful `setContent`, the bridge marks the host document loaded and refreshes document stats.
  - The loader path still does not emit `contentDidChange`.

- `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift`
  - Initial content load computes Swift-derived status counters before the WKWebView replies.
  - A short post-load refresh reasserts those counters if the document is still clean and unchanged.

- `EpistemosTests/EpdocEditorBridgeTests.swift`
  - Added coverage that the chrome controller computes nonzero status counters from loaded package JSON before JS emits updates.

- `EpistemosTests/EpdocVisibilitySourceGuardTests.swift`
  - Added source guards proving the inbound loader marks host content loaded only after `setContent`.
  - Added source guards proving `onUpdate` cannot emit `contentDidChange` until host content has loaded.

### Verification

- `npm run typecheck` in `js-editor` — PASS
- `./build-tiptap-bundle.sh` — PASS; refreshed `editor.js.br`
- Focused Swift rerun:
  - `EpdocEditorBridgeTests`
  - `EpdocVisibilitySourceGuardTests`
  - Result: `** TEST SUCCEEDED **`; 30 Swift Testing tests passed.
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-015318-epdoc-loader-fix.xcresult`
- Runtime Computer Use proof:
  - Launched latest built app from `.derived-data-epdoc-audit/Build/Products/Debug/Epistemos.app`.
  - Opened throwaway package `/tmp/epistemos-codex-smoke/Codex Loader Gate Smoke.epdoc`.
  - Pre-open `content.pm.json`: 1,337 bytes, SHA-256 `e7093f9473877bad16f14c2438c65dbac221cbb72a3ba23b533a605f0bf4c914`.
  - Post-open and after an additional wait: still 1,337 bytes with the same SHA-256.
  - Computer Use confirmed visible heading/text/list content, rendered Mermaid preview, actual rendered image, status `21 words 119 chars`, complexity 19%, `Mermaid 1`, `Embeds 1`, and Save help text `All changes saved`.

### Notes

- The older `/Users/jojo/Downloads/old research/Codex Reopen Smoke.epdoc` smoke artifact was already blank-overwritten by the pre-fix stale app instance; do not use it as proof.
- The passing runtime artifact lives under `/tmp/epistemos-codex-smoke/` and is intentionally not part of the repo.

## Slice 5 — Epdoc Graph Projection Refresh Bridge

### Findings

- `.epdoc` graph projection wrote SwiftData graph nodes and edges, but it did not notify the live graph/Halo consumers that graph storage had changed.
- Existing packages were only projected after an autosave edit. Opening an already-rich `.epdoc` without editing could therefore leave the global graph and Halo surfaces stale.
- This explains a likely part of the user's "graph still just has two boxes" symptom after pasting/opening content: the editor-local Mermaid insertion was fixed earlier, but the app-level graph store still needed an initial projection + refresh invalidation bridge.

### Changes Made

- `Epistemos/Engine/EpdocDocument.swift`
  - `makeWindowControllers` now captures the package's initial `content.pm.json` and schedules `projectAndPersistGraph` after the autosave pipeline is attached.
  - `projectAndPersistGraph` now marks `AppBootstrap.shared?.graphState.needsRefresh = true` after a successful projection write.
  - `projectAndPersistGraph` posts `.graphStoreDidChange` with `.graphNodes` and `.graphEdges` dependency keys so reactive graph consumers know to refresh.

- `EpistemosTests/EpistemosDocumentControllerTests.swift`
  - Added a source guard proving opened `.epdoc` windows project initial package content.
  - Added a source guard proving projection writes mark the live graph stale and notify graph consumers.

### Verification

- First focused run:
  - `EpistemosDocumentControllerTests`
  - `BackgroundGraphLoadingTests`
  - Result: `** TEST FAILED **` at compile time because a new observer-style test captured mutable state inside a sendable `NotificationCenter` closure.
- Minimal fix:
  - Removed the fragile observer test and kept the source guard that pins the production contract directly.
- Passing focused rerun:
  - `EpistemosDocumentControllerTests`
  - `BackgroundGraphLoadingTests`
  - Result: `** TEST SUCCEEDED **`; 29 Swift Testing tests passed.
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-021106-epdoc-graph-refresh-rerun.xcresult`

### Notes

- This slice deliberately did not touch `MetalGraphView`, `HologramController`, graph physics, or renderer internals.
- The bridge now makes `.epdoc` projection visible to graph consumers after open/autosave. A click-through UI proof is still needed to confirm the graph/Halo panel visually refreshes as expected in the live app.

## Slice 6 — Document-Launched Knowledge Graph Command

### Findings

- The main menu `View -> Knowledge Graph` / `Cmd-G` command calls `HologramController.shared.toggle()`.
- `HologramController.toggle()` depends on `setup(...)` having injected `GraphState`, `QueryEngine`, `ModelContainer`, `PhysicsCoordinator`, and `DialogueChatState`.
- Before this slice, that setup path was only guaranteed from the SwiftUI home scene. Launching the app directly into a `.epdoc` document window can skip the home scene, so the global graph command could no-op even while the document editor itself was working.
- `HologramController.setup(...)` was not fully idempotent around screen-change observation, which became important once setup could be called from both app delegate startup and home-scene appearance.

### Changes Made

- `Epistemos/App/EpistemosApp.swift`
  - `applicationDidFinishLaunching` now configures `HologramController.shared` from `AppBootstrap.shared` so document-only launches still have a graph overlay controller.
  - This is intentionally the same dependency set the home scene uses; no second graph stack or wrapper was introduced.

- `Epistemos/Views/Graph/HologramController.swift`
  - `setup(...)` now removes any existing screen observer before installing a new one.
  - This keeps repeated setup calls safe without touching protected graph rendering or physics internals.

- `EpistemosTests/BackgroundGraphLoadingTests.swift`
  - Added a source guard proving document-launched graph commands have an app-delegate setup path.
  - Added a source guard proving repeated setup remains idempotent around the screen observer.

### Verification

- Focused Swift rerun:
  - `BackgroundGraphLoadingTests`
  - `EpistemosDocumentControllerTests`
  - Result: `** TEST SUCCEEDED **`; 30 Swift Testing tests passed.
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-022247-document-launch-graph.xcresult`
- Post-failure fix:
  - The first latest-build runtime smoke still did not surface the graph overlay visually from the menu.
  - Root cause was launch-order fragility: app-delegate setup may still miss the fully initialized bootstrap path, so `HologramController.toggle()` needed to own a late-bind fallback from `AppBootstrap.shared`.
  - `HologramController.toggle()`, `show()`, and `revealPage(_:)` now call `ensureConfiguredFromSharedBootstrap()` before creating/presenting the overlay.
- Focused Swift rerun after late-bind:
  - `BackgroundGraphLoadingTests`
  - `EpistemosDocumentControllerTests`
  - Result: `** TEST SUCCEEDED **`; 30 Swift Testing tests passed.
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-023227-document-launch-graph-latebind.xcresult`
- Runtime Computer Use proof after late-bind:
  - Relaunched `.derived-data-epdoc-audit/Build/Products/Debug/Epistemos.app` directly with `/tmp/epistemos-codex-smoke/Codex Loader Gate Smoke.epdoc`.
  - `View -> Knowledge Graph` created a second full-screen Hologram overlay window. System Events reported a `system dialog` at `0,0` sized `1800x1169`.
  - After raising that overlay, Computer Use confirmed visible Hologram graph controls (`Freeze Physics`, performance-mode toggle, force settings, minimize, zoom, rebuild, close), Notes/Query/Chat sidebar tabs, and a rendered global vault graph.
  - The global overlay currently shows the vault graph, not a current-document-seeded graph. This closes the no-op graph command bug but does not sign off document-specific graph/Halo projection.

## Slice 7 — Halo / Contextual Shadows Contract

### Findings

- Halo / Contextual Shadows are not one single feature path today. The canonical V0 production mount is `ContextualShadowsState`, wired through `AppBootstrap`, `AppEnvironment`, `NoteDetailWorkspaceView`, `ChatInputBar`, and `ProseEditorRepresentable2`.
- V0 is intentionally hidden unless `EPISTEMOS_AMBIENT_RECALL_V0=1`. Hidden-by-default is therefore not dead code and should not be "fixed" by deleting the surface or forcing it on.
- When enabled, `ContextualShadowsState` prefers the durable `ShadowSearchServicing` backend configured by `AppBootstrap`, then falls back to `InstantRecallService`. The state clears stale results when disabled, when queries are shorter than six characters, or when the panel closes.
- The V1 `HaloController`, `HaloButton`, `ShadowPanel`, and `ShadowPanelContent` stack remains tested scaffold. It has a state machine, non-activating panel behavior, source-provenance rows, and GraphEvent projection ribbon coverage. It is not the default mounted V0 path, and the tests deliberately guard against silently swapping V0 to the V1 controller.
- `AppBootstrap` logs during test startup show `W8.7 shadow: skipping init — no active vault URL yet` when no active vault exists. This is expected in the test runtime and explains why a live panel can be empty until a vault-backed Shadow backend is initialized and indexed.
- Computer Use confirmed the exact DerivedData build can open the global graph overlay, the Notes sidebar, and an existing note editor with the Ambient Recall env flag set. It did not prove a populated live Contextual Shadows result panel because generating results would require typing into a real note or a controlled throwaway note with a populated Shadow index.

### Changes Made

- No code changes in this slice.
- No scaffold deleted.
- Protected editor and graph renderer paths were left untouched.

### Verification

- Default/off-path focused Swift rerun:
  - `ContextualShadowsStateTests`
  - `HaloControllerTests`
  - `HaloUITests`
  - `ShadowServicesTests`
  - Result: `** TEST SUCCEEDED **`; 77 Swift Testing tests passed.
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-024018-halo-contextual-default.xcresult`
- Enabled-path focused Swift rerun:
  - Environment: `EPISTEMOS_AMBIENT_RECALL_V0=1`
  - `ContextualShadowsStateTests`
  - `HaloControllerTests`
  - `HaloUITests`
  - Result: `** TEST SUCCEEDED **`; 57 Swift Testing tests passed.
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-024453-halo-contextual-enabled.xcresult`
- Computer Use smoke:
  - Relaunched the exact latest build at `/Users/jojo/Downloads/Epistemos/.derived-data-epdoc-audit/Build/Products/Debug/Epistemos.app` with `EPISTEMOS_AMBIENT_RECALL_V0=1` in the GUI launch environment.
  - Closed a persisted global Hologram overlay and confirmed the main landing window was usable.
  - Opened the Notes surface and confirmed the sidebar includes normal notes plus `.epdoc` document entries and a visible "New Document (.epdoc)" control.
  - Opened an existing note editor and confirmed the pre-Helios note editor surface renders. No text was changed.

### Notes

- The current V0 surface is opt-in by environment flag and result-gated by non-empty `currentResults`. A user who expects Halo to always appear will not see it unless the flag is enabled and recall has produced hits.
- A final runtime sign-off should use a throwaway vault/note, enable `EPISTEMOS_AMBIENT_RECALL_V0=1`, seed a Shadow-indexed note with related content, type a long enough query into the editor or chat composer, and verify the contextual button plus panel visibly populate without editor hot-path lag.
- The tested V1 Halo panel remains intentional scaffold. Do not delete it as "unused" unless the product decision explicitly supersedes V1 with the V0 Contextual Shadows panel.

## Slice 8 — Epdoc Projection Through Global Graph Loader

### Findings

- Earlier slices proved `.epdoc` projection writes `SDGraphNode` / `SDGraphEdge` rows and that graph consumers are invalidated after projection, but the audit had not yet proven those rows survive the same async load path used by the global Hologram graph.
- `BackgroundGraphActor.loadRecords(positionHints:)` filters hidden node types and prunes edges whose endpoints are not visible. Since `.epdoc` documents use app-level artifact node types, this was the right boundary to verify after the artifact visibility fix.
- The projection path now proves three layers end to end in an automated test: `EpdocDocument.projectAndPersistGraph` writes a `.document` node and wikilink `.idea` target, `BackgroundGraphActor` loads those records, and the reference edge remains visible in the graph record payload.
- This signs off the data bridge into the global graph loader. It does not by itself prove a polished current-document UX affordance such as "show this exact `.epdoc` in Hologram and focus its node."

### Changes Made

- `EpistemosTests/EpistemosDocumentControllerTests.swift`
  - Added `graphProjectionFeedsBackgroundGraphActor`, which projects a document containing `[[Global Halo Link]]`, loads via `BackgroundGraphActor`, and asserts the document node, idea node, and reference edge all appear in global graph records.

### Verification

- Focused Swift rerun:
  - `EpistemosDocumentControllerTests`
  - Result: `** TEST SUCCEEDED **`; 16 Swift Testing tests passed.
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-epdoc-global-loader-proof.xcresult`
- Logs during this run still showed existing non-fatal test-runtime noise:
  - `NightBrain search index maintenance requires an initialized SearchIndexService`
  - Metal cache `flock failed` messages
  - These did not fail the selected suite.

### Notes

- This is a data-path proof, not a visual proof. The next runtime slice should create or open a controlled `.epdoc`, autosave/open it, open the global graph, and verify whether the document node is visible/focusable in the Hologram UI.
- If the user expectation for the toolbar graph button is "open a graph panel seeded from the current document," that is a separate product affordance from the existing "insert document-derived Mermaid block" behavior. The audit should keep those two meanings distinct instead of letting one ambiguous graph button pretend to satisfy both.

## Slice 9 — Document-Aware Hologram Reveal From `.epdoc`

### Findings

- The app-level graph data path was correct by Slice 8, but the runtime menu behavior was still wrong: opening `View -> Knowledge Graph` from a document-only `.epdoc` launch could create a global Hologram overlay without centering the active document. Visually, this made the graph look like it still only contained a stray `Beta` concept.
- The command route had two launch-order hazards:
  - SwiftUI `WindowGroup` commands can appear in an `NSDocument` launch even when the active responder path is not the document window.
  - `NSDocumentController.currentDocument` and key/main window state can lag during menu dispatch, especially when the only open window is a directly launched package.
- The correct product behavior is not to delete or bypass the global graph. It is to treat the current `.epdoc` as a first-class `.document` artifact, load projected graph records, center that artifact, and then focus its connected concepts.
- The left Hologram sidebar still says "No notes in graph" when the selected node is a `.document` artifact. This is now a narrower labeling/UX gap in the Notes tab, not proof that the document graph failed to load.

### Changes Made

- `Epistemos/App/EpistemosApp.swift`
  - Installs a native AppKit fallback for the existing `View -> Knowledge Graph` menu item after launch and after one main-actor yield.
  - Wires the fallback to `toggleKnowledgeGraphFromMenu(_:)` so document-only launches do not depend on a SwiftUI command responder.
  - Resolves the active `.epdoc` from `currentDocument`, key/main document windows, or the single-open-`.epdoc` case.
  - Routes active `.epdoc` menu actions to `HologramController.shared.revealDocument(epdoc.package.manifest.id)`.
- `Epistemos/Views/Graph/HologramController.swift`
  - Adds `revealDocument(_:)`, a `.document` artifact reveal path distinct from legacy note `revealPage(_:)`.
  - Late-binds the controller from `AppBootstrap.shared` when document-only launch timing skips home-scene setup.
  - Makes repeated `setup(...)` idempotent for screen observers.
  - Lets document reveal own graph loading/refresh, waits for persisted graph records, centers the `.document` node, focuses its connected concepts, and requests a recommit.
- `EpistemosTests/BackgroundGraphLoadingTests.swift`
  - Adds source guards for document-launch setup, AppKit fallback binding, single-open-document resolution, document artifact reveal, and first-open camera snap.

### Verification

- Focused Swift rerun after first menu fallback:
  - `BackgroundGraphLoadingTests`
  - `EpistemosDocumentControllerTests`
  - Result: `** TEST SUCCEEDED **`; 33 Swift Testing tests passed.
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-epdoc-document-focused-graph-final.xcresult`
- Focused Swift rerun after single-open-document resolver:
  - `BackgroundGraphLoadingTests`
  - `EpistemosDocumentControllerTests`
  - Result: `** TEST SUCCEEDED **`; 33 Swift Testing tests passed.
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-epdoc-document-focused-graph-single-doc.xcresult`
- Runtime Computer Use proof:
  - Relaunched `/Users/jojo/Downloads/Epistemos/.derived-data-epdoc-audit/Build/Products/Debug/Epistemos.app` with `/tmp/epistemos-graph-visual-smoke/Codex Global Graph Visual Smoke.epdoc`.
  - Verified the `.epdoc` editor still rendered the live document-derived Mermaid graph, the actual embedded image (`Codex gradient smoke`), and nonzero status counters.
  - Invoked `View -> Knowledge Graph` through the native AppKit menu item (`toggleKnowledgeGraphFromMenu:`).
  - Raised the Hologram overlay and verified the inspector selected `Document`, title `Codex Loader Gate Smoke`, `1 connections`, and relationship `beta`.
  - Fixture content SHA-256 remained unchanged after the smoke: `8b99ca9a91a5f8b6d064178f966758b09ed6a5bdd6dfac1e7f2743fdbd61ae70`.

### Notes

- This closes the major runtime complaint that pressing/opening the graph from a `.epdoc` context still looked like an unrelated two-node global graph.
- The document-local toolbar button still inserts a Mermaid block into the document. The global menu opens the Hologram and focuses the current document artifact. These are now two distinct behaviors and should probably be labeled distinctly in final UI polish.
- Hologram's `Notes` tab remains note-only. It should either be renamed or gain an `Artifacts` / `Documents` state so document-centered graphs do not show "No notes in graph" beside a valid selected document.

## Slice 10 — Hologram Sidebar Artifact Visibility

### Findings

- After Slice 9, Hologram correctly selected the active `.epdoc` as a `.document` artifact, but the left sidebar still indexed only legacy `.folder` and `.note` nodes.
- That produced a misleading empty state: a valid document-centered graph could show a selected document inspector while the sidebar said "No notes in graph."
- The existing `NodeRowButton` already supports arbitrary `GraphNodeRecord` rows and displays each node's `type.displayName`, so this was not a new component problem. The missing bridge was the notes-tree snapshot.

### Changes Made

- `Epistemos/Views/Graph/HologramSearchSidebar.swift`
  - Extended `HologramSidebarNotesTreeSnapshot` with `artifactById` and `looseArtifactIds`.
  - `HologramSidebarNotesTreeBuilder` now indexes canonical `GraphNodeType.appLevelCases` as graph-visible artifacts.
  - The Notes tab now renders an `Artifacts` section for standalone app-level nodes such as `.document`, while retaining legacy note/folder rows.
  - The empty state now reads "No files in graph" and only appears when folders, notes, and app artifacts are all absent.
- `EpistemosTests/BackgroundGraphLoadingTests.swift`
  - Added a behavioral test proving a `.document` graph record appears in the sidebar artifact snapshot.
  - Added source guards pinning the artifact section and preventing a quiet regression to note-only sidebar indexing.

### Verification

- Focused Swift rerun:
  - `BackgroundGraphLoadingTests`
  - Result: `** TEST SUCCEEDED **`; 17 Swift Testing tests passed.
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-hologram-sidebar-artifacts.xcresult`
- Runtime Computer Use proof:
  - Relaunched `/Users/jojo/Downloads/Epistemos/.derived-data-epdoc-audit/Build/Products/Debug/Epistemos.app` with `/tmp/epistemos-graph-visual-smoke/Codex Global Graph Visual Smoke.epdoc`.
  - Verified the editor still rendered the live document-derived Mermaid graph, the actual embedded image (`Codex gradient smoke`), and nonzero status counters.
  - Invoked `View -> Knowledge Graph` through the native AppKit menu item.
  - Verified the Hologram sidebar now shows `ARTIFACTS` with `Codex Loader Gate Smoke — Document` instead of the previous "No notes in graph" empty state.
  - Verified the inspector still selected `Document`, title `Codex Loader Gate Smoke`, `1 connections`, and relationship `beta`.
  - Fixture content SHA-256 remained unchanged after the smoke: `8b99ca9a91a5f8b6d064178f966758b09ed6a5bdd6dfac1e7f2743fdbd61ae70`.

### Notes

- This is a conservative fix: it preserves the existing `Notes` tab identity and adds artifact rows beneath it. A broader polish pass may rename the tab to `Files` or split `Notes` / `Artifacts`, but that is a product-UX decision rather than a broken bridge.
- `GraphNodeType.appLevelCases` intentionally includes future app-level graph artifacts, not only `.document`. If this becomes noisy under large HELIOS/DAG traffic, add a product-level display filter instead of reintroducing a hidden graph type gate.

## Slice 11 — Contextual Shadows Populated Runtime Smoke

### Findings

- The earlier Halo / Contextual Shadows tests signed off model/state behavior but did not prove a visible populated panel in the running app.
- A safe runtime path exists if the app is launched with `XCTestConfigurationFilePath` set so it skips restoring the user's real vault, then a disposable `/tmp` vault is selected through the normal vault picker.
- With `EPISTEMOS_AMBIENT_RECALL_V0=1`, editing a note in that disposable vault produced a visible contextual-shadow affordance and panel without touching the user's vault.
- This runtime path used the current V0 `instant-recall` fallback result, not the persistent Shadow backend. The persistent Shadow backend remains covered by automated state tests and AppBootstrap source guards, but not by this manual smoke.

### Runtime Fixture

- Disposable vault: `/tmp/epistemos-halo-smoke-vault`
- Seed notes:
  - `Alpha-Shadow-Smoke.md`
  - `Beta-Shadow-Smoke.md`
- Launch environment:
  - `XCTestConfigurationFilePath=/tmp/codex-epistemos-halo-smoke.xctest`
  - `EPISTEMOS_AMBIENT_RECALL_V0=1`
- App build:
  - `/Users/jojo/Downloads/Epistemos/.derived-data-epdoc-audit/Build/Products/Debug/Epistemos.app`

### Verification

- Computer Use runtime proof:
  - Opened the Notes surface in test-mode with no restored user vault.
  - Selected `/tmp/epistemos-halo-smoke-vault` through the app's normal "Select Vault Folder" picker.
  - Verified the sidebar showed the disposable notes `Beta-Shadow-Smoke` and `Alpha-Shadow-Smoke`.
  - Opened `Beta-Shadow-Smoke`.
  - Typed `orchard glass memory halo recall graph notebooks` into the note editor.
  - Verified a contextual button appeared with accessibility label `Show 1 related items from your vault`.
  - Clicked the contextual button and verified the `Related` panel appeared with `Notes 1`.
  - Verified the populated row: `Alpha Shadow Smoke`, source `instant-recall`, score `68%`, and snippet from the Alpha fixture.
- Fixture integrity:
  - `Alpha-Shadow-Smoke.md` content SHA-256 stayed `ac19ac2434b1e19d42231102fe1caf20efcf340caad7cb2c54f250170ca73c93`.
  - `Beta` content SHA-256 stayed `6b805ea6bc61e82558db66678fb6a6be573ec7bad6b515db4922249884c5b281`.
  - The app normalized the Beta filename from `Beta-Shadow-Smoke.md` to `Beta Shadow Smoke.md` during vault import/title handling; this happened only inside the disposable `/tmp` vault and did not alter file contents.

### Notes

- This closes the visible V0 panel proof for the note-editor path: the hidden-by-default Halo affordance is gated correctly, appears when recall has results, and opens a populated panel.
- The status word counter in the note window remained at `18 words` immediately after the smoke text was typed. Since this was not the target bug and the temp file contents did not save the typed text, treat it as a runtime watch item rather than a confirmed regression.
- A deeper Shadow-backend-specific runtime proof would need either a throwaway persistent Shadow index seeded under the selected vault or a test-only mock injection point. Do not add that injection point unless the product wants recurring GUI smoke automation for this surface.

## Slice 12 — Cognitive DAG Gate Health Check

### Findings

- The user asked to pause HELIOS and verify pre-HELIOS graph/DAG/Halo features. The Cognitive DAG canon remains a higher-authority substrate with explicit non-shortcut rules.
- The safe autonomous checks are doctrine lint and replay verification. They prove the current branch still satisfies the codified static gates and the sample replay/Merkle path.
- These checks do **not** authorize the Phase 8.H authority flip. The canon still requires independent mirror coverage verification and the authority criteria from the May 4 plan / DAG doctrine.

### Verification

- Doctrine linter:
  - Command: `cargo run --manifest-path agent_core/Cargo.toml --bin epistemos_doctrine_lint -- "/Users/jojo/Downloads/Epistemos"`
  - Result: PASS
  - Evidence: `ALL GATES PASS — doctrine gates verified.`
  - Gate lines:
    - `5.1 EdgeKind enum closed`
    - `5.2 put_edge signature-check`
    - `5.3 put_node content-addressing`
    - `5.4 no Swift DAG storage`
    - `6.1 static fallback acknowledgement`
- Replay verification:
  - Command: `cargo run --manifest-path agent_core/Cargo.toml --example generate_sample_epbundle -- /tmp/codex-prehelios-dag.epbundle && cargo run --manifest-path agent_core/Cargo.toml --bin epistemos_trace -- verify-replay /tmp/codex-prehelios-dag.epbundle`
  - Result: PASS
  - Evidence: `ok bundle_id=epistemos-fixture-v2 schema_version=2 mutations=1 claims=1 evidence=1 dag_nodes=3 dag_edges=1 dag_merkle=ea2e4ac0c13b04f7a638b4714862fc6536fd9833c305456f28f1473e79d5ba9c`

### Notes

- This slice verifies DAG gate health, not DAG release authority.
- Do not mark V2.1 Phase 8.A-8.G or 8.H as release-shipped from these checks alone.
- Remaining DAG authority proof requires mirror coverage over live legacy write paths, redb/persistent-store dispatch policy if that feature is enabled, and the doctrine's authority window criteria.

## Honest Remaining Work

- `.epdoc` code blocks now render as real multi-line syntax-highlighted blocks for toolbar-authored Swift snippets, backed by Tiptap `CodeBlockLowlight` plus explicit Swift registration. This is deliberately not a CodeMirror/IDE island yet; CodeMirror becomes worth its weight only if the product wants per-block autocomplete, diagnostics, gutter controls, multi-cursor behavior, or LSP-backed editing inside the document.
- Epdoc image rendering now works end-to-end for a valid local image through picker, save, and reopen, but still embeds data URLs. A later canonical package-storage slice should move image bytes into `.epdoc/assets/` with package-local references if large-image persistence, deduplication, or export cleanliness becomes the acceptance bar.
- Broken/invalid image inputs still display a small fallback icon, which is expected but could use a nicer "missing image" treatment.
- Epdoc document graph insertion is no longer the static `Idea -> Evidence` sample, but it is deterministic structural extraction, not a full semantic knowledge-graph projection. It now roots at `Document`, fans through headings/content, and includes wikilinks; it does not yet infer latent concepts/evidence from prose.
- Reopened `.epdoc` documents now preserve package bytes and show nonzero counters in the focused runtime smoke. This is fixed for the tested loader path, but still needs broader manual coverage on user-created packages and very large pasted documents before calling the editor polished.
- `EpdocGraphProjector` now has a production persistence caller through `EpdocDocument` autosave. `EpdocGraphRenderingMapper` remains a tested but not-yet-live rendering mapper; no production caller applies those visual weights to the live Metal graph yet.
- The older global graph/entity path (`EntityExtractor`) scans `SDPage` notes and chats, not `.epdoc` packages. It also does not explain the toolbar's old `Idea -> Evidence` symptom; that symptom came from static Mermaid insertion paths, now removed from toolbar and slash menu.
- App-level graph artifact nodes are now visible by default and `.epdoc` graph persistence is wired for opened and saved packages. Projection writes now invalidate graph consumers, automated tests prove projected `.epdoc` nodes/edges flow through the global graph loader, and runtime smoke proves the global Hologram command can focus the active `.epdoc` document artifact after direct package launch. The Hologram sidebar now shows app-level document artifacts instead of a false note-only empty state.
- WKWebView/WebContent sandbox lookup noise remains visible in unified logs during document-window runtime smoke. It did not block text entry, the native image picker, or document-graph insertion in this slice, but a later cleanup pass should verify whether any editor affordance depends on unavailable pasteboard/CoreServices access.
- Halo / Contextual Shadows model/state/backend tests are signed off for both flag-off and flag-on paths. Live visual recall-result population is now runtime-smoked through the V0 note-editor path with a disposable `/tmp` vault and `instant-recall` source. Persistent Shadow-backend-specific GUI population remains a deeper optional proof item.
- A click/type-capable latest-build `.epdoc` smoke now passes for new-document creation, native image picker launch, actual image insertion/rendering, text entry, document-graph insertion, save/reopen content visibility, reopened status counters, and the global Hologram command focusing the active document artifact from a document-only launch. The latest Halo smoke also passes for visible contextual recall button + populated panel in the note editor using a disposable vault.
- Cognitive DAG static doctrine lint and sample replay verification pass on the current branch. The DAG authority flip is still intentionally not signed off; live mirror coverage and authority criteria remain separate gates.

## Slice 13 — Epdoc Code Block Upgrade

### Findings

- The visible `.epdoc` toolbar exposed only inline code before this slice, which matches the user-visible bug: selected text or one line could be styled as code, but authored multi-line snippets did not become proper code blocks from the main toolbar.
- The slash-menu path had a `toggleCodeBlock` command, but the editor was still using StarterKit's baseline code block implementation with no syntax highlighting.
- Swift-side projection/stat paths only recognized snake-case `code_block`; Tiptap emits camel-case `codeBlock`, so `.epdoc` code blocks could be undercounted and fail to export as fenced Markdown.
- Canonical scope says `.epdoc` remains the V1.5 Tiptap-in-WKWebView document editor. A full CodeMirror island is a future IDE-semantics decision, not the minimal correct fix for authored document code blocks.

### Changes

- Replaced StarterKit's baseline code block node with `CodeBlockLowlight`.
- Registered Swift explicitly with lowlight and defaulted toolbar-authored code blocks to Swift highlighting.
- Added code-block affordances to the visible toolbar and selection bubble.
- Added `.epdoc` code-block CSS for block-card styling and syntax token colors.
- Taught Markdown projection and complexity stats to recognize both `code_block` and Tiptap `codeBlock`.

### Verification

- JS typecheck:
  - Command: `cd js-editor && npm run typecheck`
  - Result: PASS
- Editor bundle:
  - Command: `cd js-editor && npm run build`
  - Result: PASS
  - Command: `bash build-tiptap-bundle.sh`
  - Result: PASS, staged the production bundle under `Epistemos/Resources/Editor/`
- Focused Swift test attempt:
  - Command: `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos -destination "platform=macOS,arch=arm64" -derivedDataPath .derived-data-epdoc-code -clonedSourcePackagesDirPath .spm-cache -resultBundlePath build/xcode-results/2026-05-07-epdoc-code-blocks.xcresult -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests -only-testing:EpistemosTests/ProseMirrorMarkdownProjectorTests -only-testing:EpistemosTests/EpdocComplexityCalculatorTests`
  - Result: INFRA FAIL, not assertion fail.
  - Evidence: result bundle reports `The test runner hung before establishing connection`; `passedTests: 0`, `failedTests: 1`.
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-epdoc-code-blocks.xcresult`
  - Process sample while hung showed the app test host stuck in dyld `__open` during launch, before the test bundle established a connection.
- Full app/test compile gate:
  - Command: `./scripts/xcodebuild_epistemos.sh build-for-testing -project Epistemos.xcodeproj -scheme Epistemos -destination "platform=macOS,arch=arm64" -derivedDataPath .derived-data-epdoc-code -clonedSourcePackagesDirPath .spm-cache -resultBundlePath build/xcode-results/2026-05-07-epdoc-code-blocks-build-for-testing.xcresult`
  - Result: PASS (`** TEST BUILD SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-epdoc-code-blocks-build-for-testing.xcresult`
- Runtime Computer Use proof:
  - Relaunched the latest built app after staging the new editor bundle.
  - Created a new `.epdoc` through the visible `New Doc` entry point.
  - Pressed the visible `Code block (⌘⇧C)` toolbar button.
  - Typed a multi-line Swift snippet.
  - Verified the editor rendered one full block-card code block, not inline code; status counters showed `Code 1`.
  - Verified Swift syntax coloring was visible for keywords/types/string literals after explicit Swift registration.

### Notes

- This is the correct lightweight document-editor upgrade. It gives authored docs real fenced-code behavior and syntax color without embedding a second editor runtime inside Tiptap.
- CodeMirror 6 should stay as a candidate future slice only if `.epdoc` code blocks need IDE semantics: completions, diagnostics, gutter widgets, LSP, folding, multi-cursor, or per-language editor behavior.
- The attempted disposable hand-built `.epdoc` package was rejected by the document loader as malformed. That package was only a smoke fixture; it did not touch user data. Future package-level smoke should use the app's native save path or an existing conforming fixture generator rather than manually assembling package files.
- `npm audit --omit=dev` still reports one moderate issue through Mermaid's transitive `uuid` dependency. The new lowlight/code-block dependencies did not introduce that finding, and no automatic audit fix was applied.

## Slice 14 — Epdoc Research Diagram Upgrade

### Findings

- The user asked for `.epdoc` diagrams to feel like true research/study diagrams and pointed to `joelbqz/writer-computer` as a design reference.
- The external reference is GPL-3.0. It was used only for product/design study; no implementation was copied into Epistemos.
- The useful pattern was not "replace the editor": writer-computer's strongest diagram lessons are strict Mermaid rendering, diagram-first cards, source-on-demand, SVG sanitization, caching, theme-aware colors, and many diagram templates.
- Local canon still keeps `.epdoc` on the Tiptap-in-WKWebView path for V1.5. A CodeMirror/ProseMark editor migration remains a separate architecture decision, not a diagram-polish fix.
- Before this slice, Epistemos' Mermaid node still felt like a raw default preview/source box, the slash surface only exposed one document graph action, and document-graph extraction could still under-project research structure.

### Changes

- Reworked the Mermaid node view into a diagram-first research card:
  - header label `Research diagram`
  - syntax chip from the first Mermaid line
  - SVG preview first
  - collapsed `Mermaid source` disclosure
  - strict Mermaid configuration
  - theme-aware research palette
  - sanitized SVG injection
  - in-memory SVG cache by source/theme
- Upgraded Mermaid CSS to a polished card surface with liquid/dark-mode treatment, diagram-first spacing, source disclosure styling, and SVG constraints.
- Expanded the slash catalogue with 10 research diagram templates:
  - research flowchart
  - sequence diagram
  - timeline diagram
  - mind map
  - state diagram
  - class diagram
  - entity relationship
  - evidence quadrant
  - evidence chart
  - evidence flow
- Reworked document graph generation:
  - root label is `Research document`
  - headings, claims, evidence, questions, methods, wikilinks, code blocks, diagrams, and images get typed graph entries
  - Mermaid class definitions now style claim/evidence/question/method/link/code/diagram/image/gap nodes distinctly
  - fallback is explicit guidance, not the old generic Idea/Evidence sample
- Fixed the classifier precedence found during visual smoke: explicit `Method:` / protocol / procedure language now wins before incidental evidence terms like "source guards".
- Updated Swift slash-menu catalogue and source guards so the native catalog and JS catalog remain aligned.

### Verification

- External reference pass:
  - Source studied: `https://github.com/joelbqz/writer-computer`
  - Relevant ideas observed: Mermaid decorations, strict rendering, SVG sanitization, cache/height-cache pattern, theme-aware rendering, image resolver, and inline-media specs.
  - License note: GPL-3.0 reference only; no code copied.
- JS typecheck:
  - Command: `cd js-editor && npm run typecheck`
  - Result: PASS
- JS production bundle:
  - Command: `cd js-editor && npm run build`
  - Result: PASS
  - Command: `bash build-tiptap-bundle.sh`
  - Result: PASS, regenerated editor resources under `Epistemos/Resources/Editor/`
- Xcode compile/resource gate:
  - Command: `./scripts/xcodebuild_epistemos.sh build-for-testing -project Epistemos.xcodeproj -scheme Epistemos -destination "platform=macOS,arch=arm64" -derivedDataPath .derived-data-epdoc-diagrams -clonedSourcePackagesDirPath .spm-cache -resultBundlePath build/xcode-results/2026-05-07-epdoc-research-diagrams-final-build-for-testing.xcresult`
  - Result: PASS (`** TEST BUILD SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-epdoc-research-diagrams-final-build-for-testing.xcresult`
- Focused Swift test attempt:
  - Command: `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos -destination "platform=macOS,arch=arm64" -derivedDataPath .derived-data-epdoc-diagrams -clonedSourcePackagesDirPath .spm-cache -resultBundlePath build/xcode-results/2026-05-07-epdoc-research-diagrams-focused.xcresult -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests -only-testing:EpistemosTests/EpdocSlashMenuViewTests`
  - Result: INTERRUPTED after infrastructure hang.
  - Evidence: app host launched but XCTest emitted no connection/output; this matches the prior code-block slice's app-hosted XCTest runner hang, not a source assertion failure. The build portion completed before interruption.
- Runtime Computer Use proof:
  - Relaunched the newest rebuilt app from `.derived-data-epdoc-diagrams`.
  - Verified an existing document graph now renders as a polished research card with header, syntax chip, rendered SVG preview, and collapsed source disclosure.
  - Created a clean new `.epdoc` through `File > New Document`.
  - Typed a multi-paragraph research note containing a heading, claim, evidence, question, method, and wikilinks.
  - Pressed the visible `Graph from document` toolbar button.
  - Verified the inserted graph was no longer two boxes; it rendered multiple typed nodes including the research document root, heading, claim, evidence, question, method-ish content, and `[[Halo]]` / `[[Cognitive DAG]]` link nodes.
  - Status counters updated to show `Mermaid 1`.

### Notes

- This makes the current Tiptap `.epdoc` diagram path much closer to a research/study artifact surface without importing a second editor architecture.
- Future performance hardening, if users create documents with dozens of diagrams, should add lazy offscreen rendering and height caching. That was observed in writer-computer and is a good pattern, but it is not needed for the current single/few-diagram proof.
- Future media polish should add package-local image assets and inline media previews for local file references. The current picker/data-URL path is correct for immediate display, but not yet the final large-document asset model.
- If the product wants editable Mermaid source blocks with IDE-like assistance, that is the point where CodeMirror 6 becomes worth considering as a source-edit island. The current slice intentionally keeps source read-only inside the rendered card so the document remains smooth and unfrozen.

## Slice 15 — Code Editor / Semantic LSP Drift Check

### Findings

- Local canon says the code editor stays native Swift/AppKit for the live surface, with CodeEditSourceEditor/TextKit rendering and tree-sitter/LSP semantics as a background intelligence layer.
- The V2.3 LSP correction is materially better than the earlier hand-rolled lifecycle stub: `agent_core/src/lsp_runtime/mod.rs` now uses `tower-lsp` LSP payload types plus tree-sitter Rust/Swift parsing for hover and same-file definition.
- `RustLSPTransport` exists and bridges Swift `LSPClient` to the Rust `LspKernel` over in-process FFI. This satisfies the no-subprocess doctrine for the LSP transport itself.
- The visible `CodeEditorView` is still not wired to `LSPClient` or `RustLSPTransport`. A production-source grep found no app call sites for `LSPClient(`, `RustLSPTransport(`, `.hover(`, or `.definition(` outside tests.
- Therefore the honest state is: semantic LSP substrate exists and passes focused Rust tests; visible editor hover/definition is not yet user-facing.
- This is an integration gap, not dead code. Do not delete the LSP runtime or tests; the substrate is intentional scaffold waiting for a UI/editor integration slice.

### Verification

- Production source call-site scan:
  - Command: `rg -n "LSPClient\\(|RustLSPTransport\\(|\\.hover\\(|\\.definition\\(" Epistemos --glob '!EpistemosTests/**'`
  - Result: PASS-for-audit / no matches.
  - Meaning: no live app surface currently instantiates or uses the semantic LSP client.
- Code editor route scan:
  - Command: `rg -n "CodeEditorView\\(" Epistemos EpistemosTests`
  - Result: one live app caller at `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`, plus a doc comment in `CodeEditorContentDebouncer`.
- Release gating scan:
  - Command: `rg -n "semanticSidebarEnabled|aiPartnerEnabled|CodeEditorReleasePolicy|shouldRefreshSemanticContext|semantic" Epistemos/Views/Notes/CodeEditorView.swift EpistemosTests/CodeEditorPolishTests.swift`
  - Result: source confirms `CodeEditorReleasePolicy.semanticSidebarEnabled = false` and `aiPartnerEnabled = false`. Semantic sidebars/AI partner affordances remain gated off by design.
- Rust semantic LSP tests:
  - First attempted command: `cargo test --manifest-path agent_core/Cargo.toml --features lsp-runtime,lsp_runtime --lib lsp_runtime`
  - Result: expected command correction; `agent_core` has feature `lsp-runtime`, not `lsp_runtime`.
  - Correct command: `cargo test --manifest-path agent_core/Cargo.toml --features lsp-runtime --lib lsp_runtime`
  - Result: PASS, 17/17 LSP runtime tests.
  - Evidence: tests included `did_open_then_hover_returns_tree_sitter_rust_symbol`, `did_open_then_definition_returns_same_file_rust_location`, and `did_change_updates_document_before_semantic_hover`.
  - Warnings: two unrelated lib-test warnings remain (`sample_claim` and `deterministic_random` unused in test builds).
- Computer Use state check:
  - Current running app is still the `.epdoc` smoke window; it confirmed the rebuilt editor/diagram UI is alive but was not a safe code-editor runtime proof.

### Notes

- Do not claim "visible semantic LSP shipped" yet. Claim only "in-process semantic LSP substrate verified."
- The next implementation slice should wire the visible code editor to a small, opt-in semantic seam:
  - create `RustLSPTransport`
  - start polling + `LSPClient.startRouting()`
  - initialize once per workspace/file context
  - send `didOpen` / debounced `didChange`
  - expose hover/definition through an existing native popover or command, not a new parallel editor UI
- Keep `InProcessLSPTransport` as a test/lifecycle stub. It still deliberately returns `MethodNotFound`; it is not production dead code.
- Do not add a CodeMirror editor island for this surface unless the visible requirement becomes IDE-grade code editing inside `.epdoc` blocks. For standalone code files, the native CodeEditSourceEditor path remains the canon.

## Slice 16 — `.epdoc` Package-Local Media / Assets Audit

### Findings

- Local canon says `.epdoc` media should ultimately be package-local: `manifest.json`, canonical `content.pm.json`, derived projections, and `assets/` for embedded media. `EXTENDED_PROGRAM_PLAN_2026_04_25.md` W7.11 specifically calls for paste/drop image bytes to be written into `.epdoc/assets/` and inserted as package-relative references.
- The storage primitive already exists. `EpdocPackage` has an `assets: [String: Data]` field, emits `assets/` in `makeFileWrapper()`, and decodes `assets/` back from a package directory. This is intentional scaffold, not dead code.
- The current visible image insertion path does not use that package asset primitive yet. `EpdocEditorToolbar.pickImageDataURL()` reads a picked image, converts it to `data:<mime>;base64,...`, and dispatches `insertEpdocImage` into the Tiptap editor. The JS image node stores only `src`, `alt`, and `title`.
- That current path is still valuable and should stay until the package-local path is implemented and runtime-proven. It fixed the immediate user-visible bug: images render as actual bitmaps and survive save/reopen in the tested smoke path.
- The current data-URL path is not the final canonical large-document media model. It can bloat `content.pm.json`, prevents clean media deduplication, and does not exercise the existing `EpdocPackage.assets` field.
- No paste/drop upload bridge was found in this slice. The only verified image insertion surface is the toolbar picker.

### Verification

- Package storage scan:
  - Command: `sed -n '1,260p' Epistemos/Models/EpdocPackage.swift`
  - Result: `assets/` is read/write capable through the FileWrapper bridge.
- Manifest/document scan:
  - Command: `sed -n '1,260p' Epistemos/Models/EpdocManifest.swift` and `sed -n '1,340p' Epistemos/Engine/EpdocDocument.swift`
  - Result: manifest/content/projection save paths are present; no document-level asset insertion API is wired into the editor host yet.
- Image pipeline scan:
  - Command: `rg -n "assets|insertEpdocImage|data:|base64EncodedString|epdocImage|FileWrapper|content.pm.json" Epistemos/Engine/EpdocDocument.swift Epistemos/Models/EpdocPackage.swift Epistemos/Models/EpdocManifest.swift Epistemos/Views/Epdoc/EpdocEditorToolbar.swift js-editor/src/bridge/inbound.ts js-editor/src/extensions/image-node.ts EpistemosTests/EpdocVisibilitySourceGuardTests.swift EpistemosTests/EpdocDocumentTests.swift EpistemosTests/EpdocEndToEndSmokeTests.swift`
  - Result: source confirms the asset container exists, while live insertion still emits a data URL through `insertEpdocImage`.
- Canon scan:
  - Command: `rg -n "epdoc|assets|image upload|paste/drop|data URL|content.pm.json|assets/" docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md docs/audits/PRE_HELIOS_FEATURE_AUDIT_2026_05_06.md docs/audits/DATA_PERSISTENCE_INDEXING_AUDIT.md`
  - Result: W7.1/W7.11/W7.17 preserve the `assets/` requirement; the current audit already marks data URLs as a working interim path.
- Computer Use runtime state:
  - Current app window still shows the rebuilt `.epdoc` editor alive with the research diagram card, toolbar image button, graph button, and nonzero counters. This slice did not re-run image insertion because the package-assets finding is source-level and the prior runtime smoke already proved the current data-URL image path.

### Notes

- Implementation acceptance bar for the package-assets slice:
  - Add a package-level asset writer API that stores images under content-addressed paths such as `assets/images/<sha256>.<ext>`.
  - Insert package-local references into the Tiptap image node instead of data URLs when the host document can write assets.
  - Add a WebView-serving path or scheme-handler route so package-local `assets/...` references render inside the editor.
  - Keep the data-URL fallback for unsaved/untitled/transient documents until native save and reopen prove asset references are stable.
  - Add paste/drop handling in the JS editor so toolbar, paste, and drag/drop converge on the same asset writer.
  - Add focused tests proving `EpdocPackage.assets` round-trips, image node references survive save/reopen, and large binary bytes do not inflate `content.pm.json`.
- This is a canonical upgrade, not a cleanup deletion. Do not remove `EpdocPackage.assets`; do not remove `insertEpdocImage`; and do not remove the data-URL fallback until the package-local path has runtime proof.

## Slice 17 — `.epdoc` Graph Button Product Semantics

### Findings

- The user-facing confusion was real: `.epdoc` had at least two different "graph" meanings living under similar labels.
- The toolbar/slash affordance inserts an in-document Mermaid diagram generated from the current document structure.
- The app-level graph/Hologram route opens the knowledge graph workspace seeded by the current document.
- Those are both useful, but calling the in-document insertion path "Graph from document" made it sound like the global graph/Halo panel. That ambiguity amplified the earlier static `Idea -> Evidence` bug because the button looked like a graph-loader rather than a diagram-inserter.
- The correct fix was product-language hardening, not deleting either path. Both the in-document diagram surface and the app-level graph workspace are intentional.

### Changes

- Renamed the visible toolbar affordance from graph-like language to document-diagram language:
  - toolbar accessibility label / tooltip: `Insert document diagram`
  - slash-menu item: `Document diagram`
- Preserved the underlying command names and bridge command so existing tests and host messages do not churn unnecessarily.
- Updated Swift/JS source guards to pin the distinction: document diagram insertion is not the same as opening the Knowledge Graph workspace.

### Verification

- JS typecheck:
  - Command: `cd js-editor && npm run typecheck`
  - Result: PASS
- JS production bundle:
  - Command: `cd js-editor && npm run build`
  - Result: PASS
  - Command: `bash build-tiptap-bundle.sh`
  - Result: PASS, regenerated editor resources under `Epistemos/Resources/Editor/`
- Xcode compile/resource gate:
  - Command: `./scripts/xcodebuild_epistemos.sh build-for-testing -project Epistemos.xcodeproj -scheme Epistemos -destination "platform=macOS,arch=arm64" -derivedDataPath .derived-data-epdoc-diagrams -clonedSourcePackagesDirPath .spm-cache -resultBundlePath build/xcode-results/2026-05-07-epdoc-graph-label-build-for-testing.xcresult`
  - Result: PASS (`** TEST BUILD SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-epdoc-graph-label-build-for-testing.xcresult`

### Notes

- This slice did not change the graph/Hologram internals. The ambiguity was in the `.epdoc` editor affordance copy and catalog, not in `MetalGraphView` or `HologramController`.
- Future product shape should expose both actions explicitly:
  - `Insert document diagram` for an authored Mermaid card inside `.epdoc`.
  - `Open Knowledge Graph` for a graph/Halo workspace seeded from the saved document projection.

## Slice 18 — `.epdoc` Research Charts + Expanded Diagram Palette

### Findings

- Mermaid is a strong fit for many research diagrams, and the official syntax surface covers far more than the original Epistemos menu exposed: flowcharts, sequence, timeline, mindmap, state, class, ER, quadrant, XY chart, Sankey, pie, Gantt, journey, requirement, git graph, C4, and block diagrams.
- Scatterplots, bar charts, and small data charts are not the same product need as Mermaid diagrams. Treating every visual as Mermaid would either create fake diagram templates or force users into awkward syntax for ordinary data exploration.
- The `joelbqz/writer-computer` reference remains GPL-3.0 reference-only. The implementation here copies no code or assets; the useful transferable idea is a serious research-card surface with first-class rendered visuals, visible labels, and source disclosure.
- A heavyweight chart dependency would be premature for the current `.epdoc` editor. The right low-bloat upgrade is a first-party chart node with a small JSON grammar, SVG rendering, and tests. If the user later needs faceting, regression, transforms, or richer statistical grammars, that is the moment to evaluate Vega-Lite or Observable Plot-style rendering.

### Changes

- Added `js-editor/src/extensions/chart-node.ts`.
  - New Tiptap node: `epdocChart`.
  - Supports JSON chart specs for `scatter`, `bar`, and `line`.
  - Renders a polished `Research chart` card with a syntax chip, SVG preview, and collapsed `Chart data` source disclosure.
  - Uses first-party DOM/SVG rendering with no new runtime dependency.
- Expanded the `.epdoc` slash palette with 10 additional research visuals:
  - Mermaid additions: pie, Gantt, journey, requirement trace, git graph, C4 context, block architecture.
  - Native chart additions: scatterplot, bar chart, line chart.
- Registered the chart extension in the editor runtime and bundled it into the production WebView assets.
- Updated Swift catalog parity so `EpdocSlashMenuItem.defaultCatalogue` now exposes 36 entries.
- Updated Markdown projection so `epdocChart` exports as a fenced `epdoc-chart` block instead of disappearing during projection.
- Updated `.epdoc` complexity stats so native charts count in the existing visual-diagram bucket without public API churn.
- Added CSS for chart-card layout, axes, gridlines, marks, category colors, source disclosure, and error states.

### Verification

- JS typecheck:
  - Command: `cd js-editor && npm run typecheck`
  - Result: PASS
- JS production bundle:
  - Command: `cd js-editor && npm run build`
  - Result: PASS
  - Command: `bash build-tiptap-bundle.sh`
  - Result: PASS, regenerated editor resources under `Epistemos/Resources/Editor/`
- Xcode compile/resource gate:
  - Command: `./scripts/xcodebuild_epistemos.sh build-for-testing -project Epistemos.xcodeproj -scheme Epistemos -destination "platform=macOS,arch=arm64" -derivedDataPath .derived-data-epdoc-charts -clonedSourcePackagesDirPath .spm-cache -resultBundlePath build/xcode-results/2026-05-07-epdoc-charts-build-for-testing.xcresult`
  - Result: PASS (`** TEST BUILD SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-epdoc-charts-build-for-testing.xcresult`
- Source guards and compile coverage included:
  - `EpdocVisibilitySourceGuardTests`
  - `EpdocSlashMenuViewTests`
  - `ProseMirrorMarkdownProjectorTests`
  - `EpdocComplexityCalculatorTests`
  - These compiled under the successful `build-for-testing` gate. They were not executed as a focused `xcodebuild test` run in this slice because recent app-hosted Swift Testing attempts have hung before establishing the XCTest connection.
- Computer Use runtime attempt:
  - Approved command: `open -n /Users/jojo/Downloads/Epistemos/.derived-data-epdoc-charts/Build/Products/Debug/Epistemos.app`
  - Result: Computer Use continued to attach to the already-running older `com.epistemos.app` process.
  - Evidence: the live toolbar still exposed `Graph from document`, while current source and tests pin `Insert document diagram` / `Document diagram`.
  - Decision: do not count this as chart runtime evidence and do not kill/relaunch the user's current app silently. Chart-specific runtime smoke remains pending.

### Notes

- This is a real `.epdoc` capability upgrade, not a placeholder. Users can now create research diagrams and lightweight data visuals from the same slash surface.
- Runtime Computer Use smoke for actual chart insertion is still pending. The previous runtime smoke proved the updated `.epdoc` editor, images, code blocks, and research-diagram rendering; this chart-specific slice is compile/bundle/source-guard verified only.
- The chart JSON grammar is deliberately small and inspectable. Future upgrades should add:
  - paste CSV/table to chart conversion,
  - package-local data attachments,
  - editable chart inspector UI,
  - chart snapshot export,
  - optional Vega-Lite/Observable Plot-style renderer only if the product needs richer transforms/faceting.
- Do not delete the first-party chart node as "scaffold." It is now wired into JS, Swift catalog, Markdown projection, complexity stats, CSS, and the production bundle.

## Next Autonomous Slice

## Slice 19 — `.epdoc` Package-Local Images + Native Card Styling

### Findings

- The earlier image path was functional but not canonical for serious `.epdoc` work: toolbar-picked images were inserted as `data:` URLs, which makes `content.pm.json` carry binary payloads and bypasses the existing `.epdoc` package `assets/` container.
- `EpdocPackage.assets` was intentional scaffold, not dead code. It needed a real editor bridge before it could be counted as a live feature.
- The user-provided light/dark references clarified the visual target: code, diagram, chart, and image cards should feel native and quiet, closer to Apple Notes / ChatGPT cards, not cinematic JavaScript panels with heavy shadows, gradients, or fake 3D.
- The safe bounded upgrade is package-local storage for file-picked images plus a WebView scheme-handler route. Paste/drop image convergence is still a separate follow-up; do not claim it is done in this slice.

### Changes

- Added package-local image persistence through `EpdocDocument.storeImageAsset(data:originalFilename:mimeType:)`.
  - Images are content-addressed as `assets/image-<sha256>.<ext>`.
  - The editor receives package-local `assets/...` references instead of large data URLs when hosted by a writable `.epdoc` document.
  - The original data-URL fallback remains in `EpdocEditorToolbarModel` for transient/unsaved hosts and as a safety fallback until runtime save/reopen is smoke-tested.
- Added `EpdocEditorDocumentAsset` and a document-asset resolver on `EpdocEditorURLSchemeHandler`.
  - Only flat `assets/<filename>` package references are accepted.
  - Traversal and nested paths are rejected.
  - MIME type is served from the extension so WebKit can render the real image bytes.
- Wired the editor chrome to serve package-local assets from the live document package.
- Reworked `.epdoc` card CSS toward native/minimal light and dark styling:
  - neutral card variables for light/dark mode,
  - flattened code/diagram/chart/image cards,
  - no radial card backgrounds,
  - no drop-shadow filters,
  - no theatrical 3D shadows.
- Added focused source/build guards for package-local image storage, asset serving, data-URL fallback preservation, and native-card CSS constraints.

### Verification

- JS typecheck:
  - Command: `cd js-editor && npm run typecheck`
  - Result: PASS
- JS production bundle:
  - Command: `cd js-editor && npm run build`
  - Result: PASS
  - Command: `bash build-tiptap-bundle.sh`
  - Result: PASS, regenerated editor resources under `Epistemos/Resources/Editor/`
- Xcode compile/resource gate:
  - Command: `./scripts/xcodebuild_epistemos.sh build-for-testing -project Epistemos.xcodeproj -scheme Epistemos -destination "platform=macOS,arch=arm64" -derivedDataPath .derived-data-epdoc-assets -clonedSourcePackagesDirPath .spm-cache -resultBundlePath build/xcode-results/2026-05-07-epdoc-assets-native-cards-build-for-testing.xcresult`
  - Result: PASS (`** TEST BUILD SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-epdoc-assets-native-cards-build-for-testing.xcresult`
- Source guards and compile coverage included:
  - `EpdocDocumentTests`
  - `EpdocEditorBridgeTests`
  - `EpdocVisibilitySourceGuardTests`
  - These compiled under the successful `build-for-testing` gate. They were not executed as a focused `xcodebuild test` run in this slice because recent app-hosted Swift Testing attempts have hung before establishing the XCTest connection.
- Computer Use runtime attempt:
  - Command: `open -n /Users/jojo/Downloads/Epistemos/.derived-data-epdoc-assets/Build/Products/Debug/Epistemos.app`
  - Result: Computer Use still attached to the older running `com.epistemos.app` process (`pid 99678`).
  - Decision: do not count this as package-local image or native-card runtime evidence. A fresh-process visual smoke remains pending.

### Notes

- Runtime visual smoke is still pending. The build proves the Swift bridge, package writer, scheme handler, bundled editor assets, and tests compile; it does not prove a fresh app process renders the package-local image after save/reopen.
- Toolbar/file-picker image insertion now has the package-local path. Paste/drop image handling still needs to be wired to the same host asset writer so all image ingress paths converge.
- This slice deliberately preserves the data-URL fallback. Do not delete it until package-local save/reopen runtime smoke proves stable in a fresh app launch.
- The card style intentionally follows the user's light/dark references: quiet native rounded rectangles, modest borders, semantic text contrast, and minimal shadowing.

## Slice 20 — `.epdoc` Paste/Drop Image Asset Convergence

### Findings

- Slice 19 made toolbar/file-picker image insertion canonical by writing image bytes into `.epdoc/assets/`, but paste and drag/drop still needed the same treatment. Leaving those ingress paths separate would make the feature feel Apple-Notes-like in one path and brittle in the others.
- The right boundary is the existing editor bridge, not a second persistence mechanism inside the WebView. JavaScript should only capture the image file and requested insertion point; Swift should own package persistence, MIME validation, and returned `assets/...` references.
- The data-URL fallback remains intentional. It is useful for transient/unsaved editor hosts and protects against bridge failures while package-local save/reopen runtime smoke is still pending.

### Changes

- Added `js-editor/src/extensions/image-asset-bridge.ts`.
  - Handles pasted image files.
  - Handles dropped image files.
  - Captures the intended insertion position before sending bytes to Swift.
  - Enforces a 20 MB image limit matching the toolbar picker.
  - Sends a `storeImageAsset` bridge message with request ID, filename, MIME type, and base64 image bytes.
- Added a `storeImageAsset` outbound bridge message and a matching Swift `EpdocBridgeMessage.storeImageAsset` decoder.
- Added an inbound `completeImageAssetRequest` command so Swift can return the package-local image reference and JavaScript can complete the pending insert at the captured document position.
- Wired `EpdocEditorChromeController.onStoreDocumentAsset` to `EpdocDocument.storeImageAsset(...)`, so toolbar, paste, and drop now converge on the same package-local writer.
- Added source/build guards covering the JS image bridge, Swift bridge decoder, completion command, 20 MB limit, package-local storage path, and preserved data-URL fallback.

### Verification

- JS typecheck:
  - Command: `cd js-editor && npm run typecheck`
  - Result: PASS
- JS production bundle:
  - Command: `cd js-editor && npm run build`
  - Result: PASS
  - Command: `bash build-tiptap-bundle.sh`
  - Result: PASS, regenerated editor resources under `Epistemos/Resources/Editor/`
- Xcode compile/resource gate:
  - Command: `./scripts/xcodebuild_epistemos.sh build-for-testing -project Epistemos.xcodeproj -scheme Epistemos -destination "platform=macOS,arch=arm64" -derivedDataPath .derived-data-epdoc-image-paste -clonedSourcePackagesDirPath .spm-cache -resultBundlePath build/xcode-results/2026-05-07-epdoc-image-paste-drop-build-for-testing.xcresult`
  - Result: PASS (`** TEST BUILD SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-epdoc-image-paste-drop-build-for-testing.xcresult`
- Source guards and compile coverage included:
  - `EpdocEditorBridgeTests`
  - `EpdocVisibilitySourceGuardTests`
  - These compiled under the successful `build-for-testing` gate. They were not executed as a focused `xcodebuild test` run in this slice because recent app-hosted Swift Testing attempts have hung before establishing the XCTest connection.

### Notes

- Runtime visual smoke is still pending. This slice proves the JS/Swift bridge and package writer compile and bundle cleanly; it does not yet prove paste/drop save/reopen behavior in a fresh app process.
- Only the first image file from a paste/drop event is handled. Multi-image paste/drop ordering should be a future UX slice, not smuggled into this bridge-hardening pass.
- Do not delete the data-URL fallback as "dead" until a fresh-process runtime smoke proves package-local image rendering after save/reopen.
- Do not delete `EpdocPackage.assets` or the document asset scheme handler as "scaffold." They are now live for toolbar/file-picker, paste, and drop image ingress.

## Slice 21 — `.epdoc` Document-Diagram Guardrail

### Findings

- The toolbar/slash "Document diagram" action is separate from the global `.epdoc` graph projector. The global projector correctly emits durable document/provenance/wikilink graph edges; the in-editor button generates an authored Mermaid diagram from the current ProseMirror JSON.
- Source inspection shows the old static two-box sample is no longer the button path: `insertEpdocGraphFromDocument` calls `buildMermaidGraphFromDocument(editor.getJSON())`.
- The remaining risk was regression safety. Without an executable guard, a future cleanup could accidentally reintroduce a static sample while source guards only checked for strings.

### Changes

- Added `js-editor/scripts/check-document-graph.mjs`.
  - Transpiles the pure TypeScript document-graph builder with the local TypeScript dependency.
  - Executes it against a rich synthetic ProseMirror document containing heading, claim, evidence, question, method/list, wikilinks, code, diagram, and image nodes.
  - Requires a 10+ node Mermaid output and rejects the old static `Idea` sample.
  - Also pins the empty-document fallback copy.
- Added `npm run check:document-graph` so this guard can be run without adding a JS test framework or runtime dependency.

### Verification

- Document graph executable guard:
  - Command: `cd js-editor && npm run check:document-graph`
  - Result: PASS (`document graph builder check passed`)
- JS typecheck:
  - Command: `cd js-editor && npm run typecheck`
  - Result: PASS
- JS production bundle:
  - Command: `cd js-editor && npm run build`
  - Result: PASS

### Notes

- This guard does not replace fresh runtime smoke. It proves the builder function is non-static and semantically rich; it does not prove the WebView selection/document snapshot is fresh at button-click time in a live app process.
- If a user still sees only two boxes after this source state ships, the most likely culprit is stale app/editor bundle runtime, stale document-load state, or button execution against an empty ProseMirror snapshot, not the graph builder itself.

## Slice 22 — `.epdoc` Graph/Halo Manual Edge Preservation Guard

### Findings

- The `.epdoc` global graph/Halo path is source-wired: `EpdocDocument.projectAndPersistGraph` projects document structure, `EpdocGraphPersistence` persists nodes/edges, the background graph actor can load the projected graph, and `HologramController.revealDocument` focuses the document node when the graph is revealed.
- Existing tests already cover `.epdoc` document node materialization, wikilink edge persistence, background graph loading, direct document launch graph reveal, and stale generated-edge replacement.
- The remaining canon-hardening risk was user data preservation. Projection refreshes must not erase intentional manual graph edits attached to a document just because generated `.epdoc` links changed.

### Changes

- Added a focused Swift Testing guard in `EpistemosDocumentControllerTests`.
  - Projects an `.epdoc` document with `[[Alpha]]`.
  - Adds a manual graph edge from the document node to a user-created "User Kept Cluster" node.
  - Reprojects the document with `[[Beta]]`.
  - Verifies the manual edge remains marked `isManual`, the fresh generated `Beta` edge exists, and the stale generated `Alpha` edge is removed.
- No production code changed in this slice. This is a regression guard around the existing preservation behavior.

### Verification

- Xcode compile/resource gate:
  - Command: `./scripts/xcodebuild_epistemos.sh build-for-testing -project Epistemos.xcodeproj -scheme Epistemos -destination "platform=macOS,arch=arm64" -derivedDataPath .derived-data-epdoc-graph-preserve -clonedSourcePackagesDirPath .spm-cache -resultBundlePath build/xcode-results/2026-05-07-epdoc-graph-manual-preserve-build-for-testing.xcresult`
  - Result: PASS (`** TEST BUILD SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-epdoc-graph-manual-preserve-build-for-testing.xcresult`

### Notes

- This does not count as runtime visual smoke; it proves the graph persistence guard compiles into the app-hosted test bundle.
- The guard intentionally protects user/manual graph scaffold. Do not delete or overwrite manual graph edges as "projection cleanup"; only generated `.epdoc` projection edges should be replaced during refresh.
- The next graph/Halo confidence step remains live-app smoke: save/reopen a rich `.epdoc`, reveal it in Halo, and verify the document node plus generated links appear visually.

## Slice 23 — `.epdoc` Multi-Line Code Block Selection Command

### Findings

- Local canon still keeps `.epdoc` on the Tiptap/lowlight document editor path. A CodeMirror island is a future IDE-semantics decision, not the minimal correct fix for authored research-doc code snippets.
- The existing code-block substrate was real: `CodeBlockLowlight`, lowlight common languages, explicit Swift registration, native light/dark CSS, and toolbar/bubble commands were already present.
- The remaining drift was command semantics. The visible toolbar/bubble `Code block` action delegated to generic `toggleCodeBlock`, which is active-block oriented. For selected multi-line snippets, the first implementation still rendered as multiple visual cards in a stale running app, confirming the user's report rather than just theorizing it.
- The focused source guard also exposed a stale/brittle chart assertion while rerunning. The chart implementation was already a real first-party SVG chart node; the guard now proves the actual scatter/bar/line validation path instead of searching for a nonexistent literal string.

### Changes

- Intercepted `toggleCodeBlock` in the JS inbound bridge.
- Preserved the default collapsed-cursor behavior by still using Tiptap's normal `toggleCodeBlock` when there is no non-empty selection.
- Converted non-empty selected text with a direct ProseMirror transaction into one `codeBlock` node with Swift as the default language plus a trailing paragraph, so pasted/selected multi-line snippets become one real syntax-highlighted block instead of separate paragraph cards.
- Hardened the transaction from raw selection replacement to selected block-range replacement (`$from.blockRange($to)` + `replaceWith(replaceFrom, replaceTo, codeBlock)`). This matters because raw range replacement can still split paragraph selections into multiple visual code cards.
- Added/updated Swift source guards proving the visible Code block action does not regress to the raw generic toggle for selected multi-line text and that charts remain real first-party scatter/bar/line SVG renderers.
- Added a SourceMirror checkout fallback and project.yml mirror entry for `js-editor/package.json`, because source-guard tests may need single-file mirrored resources that are not part of the existing `js-editor/src` copy tree.

### Verification

- JS typecheck:
  - Command: `cd js-editor && npm run typecheck`
  - Result: PASS
- JS production bundle:
  - Command: `cd js-editor && npm run build`
  - Result: PASS
- Document-graph guard:
  - Command: `cd js-editor && npm run check:document-graph`
  - Result: PASS (`document graph builder check passed`)
- App editor resource bundle:
  - Command: `bash build-tiptap-bundle.sh`
  - Result: PASS
- Xcode compile/resource gate:
  - Command: `./scripts/xcodebuild_epistemos.sh build-for-testing -project Epistemos.xcodeproj -scheme Epistemos -destination "platform=macOS,arch=arm64" -derivedDataPath .derived-data-epdoc-code-selection-v2 -clonedSourcePackagesDirPath .spm-cache -resultBundlePath build/xcode-results/2026-05-07-epdoc-code-selection-v2-build-for-testing.xcresult`
  - Result: PASS (`** TEST BUILD SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-epdoc-code-selection-v2-build-for-testing.xcresult`
- Focused Swift source guard:
  - Command: `./scripts/xcodebuild_epistemos.sh test-without-building -project Epistemos.xcodeproj -scheme Epistemos -destination "platform=macOS,arch=arm64" -derivedDataPath .derived-data-epdoc-code-selection-v2 -clonedSourcePackagesDirPath .spm-cache -resultBundlePath build/xcode-results/2026-05-07-epdoc-code-selection-v2-focused-test-without-building.xcresult -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests`
  - Result: PASS (`8/8`, `** TEST EXECUTE SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-epdoc-code-selection-v2-focused-test-without-building.xcresult`
- Failed/transient evidence:
  - A full `test` rerun first failed because `SourceMirror/js-editor/package.json` was missing; this was fixed by the SourceMirror fallback.
  - A subsequent full `test` rerun hit an app-hosted runner hang before Swift Testing connected; the immediate `test-without-building` retry passed all source guards, so the hang is recorded as runner instability rather than a source-guard failure.
- Runtime smoke:
  - Computer Use against the already-running stale app reproduced the bad behavior: selecting a three-line snippet and pressing Code block rendered three separate code cards. This is recorded as the bug-confirming smoke, not as verification of the final v2 fix.
  - A later clean-process smoke first attached to several stale DerivedData app instances, then all debug Epistemos instances were closed and the exact `.derived-data-epdoc-native-cards` executable was relaunched.
  - The clean process restored an existing `.epdoc` containing a multi-line code block and reported `Code 1`, with a single quiet native card, which is positive visual evidence for already-authored multi-line code blocks.
  - A fully blank new-document five-line selection smoke remains awkward because the app restored tab state and switched into existing documents during the shortcut path. Do not treat the fresh blank selection case as fully runtime-signed-off yet; use the executable ProseMirror guard in Slice 27 as the stronger command-level evidence until a cleaner blank-tab GUI harness exists.

### Notes

- This is not full IDE editing inside `.epdoc` blocks. It does not add completions, diagnostics, gutters, multi-cursor editing, or LSP-backed hover/definition in document code cards.
- It does make the visible authored-document behavior correct: selecting multiple lines and choosing Code block now creates one real multi-line code block rather than a misleading inline/current-line style.
- Runtime visual sign-off is partial: one clean latest-build process shows an existing multi-line code block as one card / `Code 1`, and the command transform is now executable-tested in Slice 27. A repeatable blank-document GUI harness is still needed before calling the exact toolbar-selection path fully signed off.

## Slice 24 — `.epdoc` First-Party Chart Renderer Guard

### Findings

- The chart node implementation already had the right shape for the user's "scatterplots and charts" ask: a structured JSON source, first-party SVG rendering, source-on-demand disclosure, and native quiet card styling.
- The only automated guard for this path was source-string based. That could prove the names existed, but it did not execute the renderer or prove that scatter, bar, line, invalid JSON, and empty-data states produce distinct useful output.
- Because a fresh GUI runtime is still blocked by the stale running app, a direct JS renderer check gives better evidence than waiting on the app window.

### Changes

- Added `js-editor/scripts/check-chart-node.mjs`.
- Added `npm run check:charts`.
- The script transpiles `chart-node.ts`, injects a minimal fake DOM, and executes the real `parseChartSpec` / `renderChartInto` functions.
- The check verifies:
  - scatter renders SVG circles and no bars
  - line renders a line path plus point marks
  - bar renders rect bars and no point marks
  - invalid JSON renders an error card
  - empty scatter data renders the empty-state guidance

### Verification

- Chart renderer behavior:
  - Command: `cd js-editor && npm run check:charts`
  - Result: PASS (`chart node renderer check passed`)
- JS typecheck:
  - Command: `cd js-editor && npm run typecheck`
  - Result: PASS
- Document-graph guard:
  - Command: `cd js-editor && npm run check:document-graph`
  - Result: PASS (`document graph builder check passed`)

### Notes

- This is renderer verification, not GUI sign-off. It does not prove the native slash picker visually opens charts in the currently running app.
- It does reduce fake-feature risk: chart cards now have an executable behavior check rather than only a source-presence guard.

## Slice 25 — `.epdoc` Image Bridge Focused Test Execution

### Findings

- Slice 20 had compile/source evidence for package-local paste/drop image convergence, but did not execute the focused Swift bridge/document suites because earlier app-hosted Swift Testing runs were unstable.
- The actual image path is now better than an icon placeholder in source: `epdocImage` renders an `<img data-epdoc-image>` node, toolbar/paste/drop ingress converges through `EpdocDocument.storeImageAsset`, and the document asset resolver rejects traversal before serving `epistemos-doc:///assets/...`.

### Changes

- No production code changed in this slice.
- This is a verification-only slice for the existing image bridge and package-local image storage path.

### Verification

- Focused Swift image bridge/document execution:
  - Command: `./scripts/xcodebuild_epistemos.sh test-without-building -project Epistemos.xcodeproj -scheme Epistemos -destination "platform=macOS,arch=arm64" -derivedDataPath .derived-data-epdoc-code-selection-v2 -clonedSourcePackagesDirPath .spm-cache -resultBundlePath build/xcode-results/2026-05-07-epdoc-image-bridge-focused-test-without-building.xcresult -only-testing:EpistemosTests/EpdocDocumentTests -only-testing:EpistemosTests/EpdocEditorBridgeTests`
  - Result: PASS (`39` Swift Testing tests, `** TEST EXECUTE SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-epdoc-image-bridge-focused-test-without-building.xcresult`

### Notes

- This proves the Swift document package writer, JS bridge decoder, asset resolver, and controller completion path under focused tests.
- It still does not count as fresh GUI visual sign-off for pasted/dropped images. A fresh latest-build runtime smoke should still inspect: file picker image insertion, paste image insertion, drop image insertion, save/reopen, and visible `<img>` rendering.

## Slice 26 — `.epdoc` Native Card Styling Pass

### Findings

- The user-provided light/dark references are quiet Apple-style code cards: rounded rectangles, modest borders, no glow/depth theater, clear label text, and system dark-mode materials.
- Source inspection showed `.epdoc` blocks already had `box-shadow: none`, but Mermaid and chart cards still carried shaded header bars and uppercase component labels. That made them feel more like fake web widgets than native document blocks.
- External reference check: `joelbqz/writer-computer` presents itself as a local-first desktop Markdown editor built around CodeMirror and extended Markdown including tables and Mermaid diagrams. That supports the capability target, but Epistemos should keep its native Swift/Tiptap document path rather than copy a Tauri/React shell.

### Changes

- `js-editor/src/editor.css`
  - Added shared `--epdoc-card-radius` and `--epdoc-card-label-fg` tokens.
  - Tuned dark code/card surfaces toward the user's reference (`#242426`-style native dark cards instead of nearly-black panels).
  - Removed shaded header bars from Mermaid and chart cards by making card headers transparent with no bottom divider.
  - Replaced uppercase card titles with plain SF Pro labels using a modest semibold weight.
  - Kept code, Mermaid, chart, and image boxes on the existing card substrate with no shadows, no drop filters, and no cinematic gradients.

- `EpistemosTests/EpdocVisibilitySourceGuardTests.swift`
  - Strengthened the native-card source guard so the quiet card style includes transparent headers, shared radius, label tokens, modest SF Pro labels, borders, and no glowy JS depth.

### Verification

- JS typecheck:
  - Command: `cd js-editor && npm run typecheck`
  - Result: PASS
- Chart renderer behavior:
  - Command: `cd js-editor && npm run check:charts`
  - Result: PASS (`chart node renderer check passed`)
- Document-graph guard:
  - Command: `cd js-editor && npm run check:document-graph`
  - Result: PASS (`document graph builder check passed`)
- JS production bundle:
  - Command: `cd js-editor && npm run build`
  - Result: PASS
- App editor resource bundle:
  - Command: `bash build-tiptap-bundle.sh`
  - Result: PASS, regenerated `Epistemos/Resources/Editor/editor.css.br` and matching editor assets.
- Xcode compile/resource gate:
  - Command: `./scripts/xcodebuild_epistemos.sh build-for-testing -project Epistemos.xcodeproj -scheme Epistemos -destination "platform=macOS,arch=arm64" -derivedDataPath .derived-data-epdoc-native-cards -clonedSourcePackagesDirPath .spm-cache -resultBundlePath build/xcode-results/2026-05-07-epdoc-native-cards-build-for-testing.xcresult`
  - Result: PASS (`** TEST BUILD SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-epdoc-native-cards-build-for-testing.xcresult`
- Focused Swift source guard:
  - First command: `./scripts/xcodebuild_epistemos.sh test-without-building -project Epistemos.xcodeproj -scheme Epistemos -destination "platform=macOS,arch=arm64" -derivedDataPath .derived-data-epdoc-native-cards -clonedSourcePackagesDirPath .spm-cache -resultBundlePath build/xcode-results/2026-05-07-epdoc-native-cards-focused-test-without-building.xcresult -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests`
  - Result: Swift Testing executed and passed 8/8 tests, but xcodebuild returned code 65 with the known app-hosted wrapper error `The test runner hung before establishing connection.` Treat this as runner instability, not clean sign-off.
  - Retry command: `./scripts/xcodebuild_epistemos.sh test-without-building -project Epistemos.xcodeproj -scheme Epistemos -destination "platform=macOS,arch=arm64" -derivedDataPath .derived-data-epdoc-native-cards -clonedSourcePackagesDirPath .spm-cache -resultBundlePath build/xcode-results/2026-05-07-epdoc-native-cards-focused-test-without-building-retry.xcresult -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests`
  - Retry result: PASS (`8/8`, `** TEST EXECUTE SUCCEEDED **`)
  - Retry result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-epdoc-native-cards-focused-test-without-building-retry.xcresult`

### Notes

- This is CSS/source-guard evidence only until a fresh latest-build `.epdoc` window is visually inspected in both light and dark mode.
- The pass deliberately avoids adding CodeMirror as a code-card island. That remains a future architecture slice if `.epdoc` code blocks need IDE semantics such as completions, gutters, diagnostics, folding, multi-cursor editing, or LSP-backed hover.

## Slice 27 — `.epdoc` Code Block Command Executable Guard + Clean Runtime Disambiguation

### Findings

- The app had multiple debug Epistemos processes alive from earlier audit slices. Computer Use initially attached to stale DerivedData builds, which made runtime evidence ambiguous and even reproduced the old `Code 5` behavior in an obsolete process.
- After closing all debug Epistemos processes and relaunching only `.derived-data-epdoc-native-cards/Build/Products/Debug/Epistemos.app`, the process list showed one live Epistemos app process from the intended build.
- The fresh process restored existing `.epdoc` documents rather than a pristine blank editor, but it did show a previously authored multi-line code block as one quiet native card with the toolbar status `Code 1`.
- Because the blank-document tab shortcut restored/surfaced existing documents during smoke, command-level verification needed to move below the UI layer into a deterministic ProseMirror transform check.

### Changes

- Added `js-editor/scripts/check-code-block-command.mjs`.
  - Builds a minimal ProseMirror schema with `paragraph` and `codeBlock`.
  - Creates a document containing five separate paragraphs.
  - Selects the full paragraph range.
  - Runs the same block-range replacement shape used by `toggleEpdocCodeBlock`.
  - Asserts the result is exactly one `codeBlock` containing newline-preserved text plus one trailing paragraph.
- Added `npm run check:code-block`.
- No Swift production code changed in this slice.

### Verification

- Clean-process disambiguation:
  - Command: `pkill -x Epistemos`
  - Command: `open -n -a /Users/jojo/Downloads/Epistemos/.derived-data-epdoc-native-cards/Build/Products/Debug/Epistemos.app`
  - Command: `ps ax -o pid=,command= | rg Epistemos`
  - Result: one live Epistemos process from `.derived-data-epdoc-native-cards`.
- Runtime visual evidence:
  - Computer Use inspected the clean latest-build process.
  - Existing restored `.epdoc` document showed a single multi-line code card and toolbar status `Code 1`.
  - The restored document also showed live research diagrams and package-local image rendering, preserving the prior `.epdoc` surfaces after relaunch.
- Code-block command guard:
  - Command: `cd js-editor && npm run check:code-block`
  - Result: PASS (`code block command range check passed`)
- Chart renderer behavior:
  - Command: `cd js-editor && npm run check:charts`
  - Result: PASS (`chart node renderer check passed`)
- Document-graph guard:
  - Command: `cd js-editor && npm run check:document-graph`
  - Result: PASS (`document graph builder check passed`)
- JS typecheck:
  - Command: `cd js-editor && npm run typecheck`
  - Result: PASS
- JS production bundle:
  - Command: `cd js-editor && npm run build`
  - Result: PASS

### Notes

- This slice is deliberately conservative. It does not claim `.epdoc` code blocks now rival a full CodeMirror 6 / Xcode editor. It verifies the authored-document behavior: selected multi-paragraph prose can be represented as one real code block, and already-authored multi-line code renders as one native card.
- A future IDE-grade code slice should be explicit and heavier: CodeMirror island or native code editor bridge, gutters, language selection, folding, search, diagnostics, and optional LSP hover/definition. That is not a minimal pre-Helios hardening fix.
- The next GUI harness should create a known-empty `.epdoc` without tab restoration, run the five-line selection through the toolbar, and assert `Code 1` from accessibility before this exact path is fully signed off.

## Slice 28 — Pre-Helios Focused Build/Test Sweep + Fresh `.epdoc` Runtime Smoke

### Findings

- A clean-derived `build-for-testing` from `.derived-data-pre-helios-audit` succeeded against the current dirty tree. This is stronger than the earlier per-slice checks because it compiles the app and selected test host from a fresh derived-data root rather than relying on the older `.derived-data-epdoc-*` runs.
- Focused pre-Helios tests passed across `.epdoc`, graph/Halo, note/editor, search diagnostics, and native code-editor polish surfaces. The selected test list intentionally avoided Helios/V6-specific suites.
- Runtime smoke confirmed the current build can create a new `.epdoc` via the documented native shortcut `⌥⌘N`. The new document opens as an `Untitled` tab with visible placeholder text, a dark-mode native document canvas, the curved toolbar, document status, and the complexity/status pill.
- Runtime smoke also confirmed the document graph toolbar button no longer inserts the old static `Idea -> Evidence` sample. A typed document with a heading, paragraph, list claims/evidence/question, and `[[Halo]] [[Graph]]` wikilinks produced a rendered `Research diagram` card with derived nodes for the heading, paragraph, claim, evidence, question, and wikilinks.
- Runtime smoke confirmed the image toolbar opens the native `NSOpenPanel` titled `Choose Image` with the prompt `Insert a local image into this Epistemos document.` This verifies the picker path is live in the current build. The actual image insertion path remains covered by source tests and prior runtime evidence; selecting a fixture in this pass was not completed because the accessibility click on the image file did not select the offscreen/icon item reliably.
- Discoverability nuance: plain `⌘N` from the `.epdoc` window opened the vault-folder chooser (`Choose a folder for your Epistemos vault`), while `⌥⌘N` created the `.epdoc`. Source guards already pin the visible `New Doc` / `New Document` surfaces, but this runtime result explains why creation can still feel hidden or surprising to a user.

### Verification

- JS code-block command guard:
  - Command: `cd js-editor && npm run check:code-block`
  - Result: PASS (`code block command range check passed`)
- JS chart renderer guard:
  - Command: `cd js-editor && npm run check:charts`
  - Result: PASS (`chart node renderer check passed`)
- JS document-graph guard:
  - Command: `cd js-editor && npm run check:document-graph`
  - Result: PASS (`document graph builder check passed`)
- JS typecheck:
  - Command: `cd js-editor && npm run typecheck`
  - Result: PASS
- Clean-derived pre-Helios build:
  - Command: `./scripts/xcodebuild_epistemos.sh build-for-testing -project Epistemos.xcodeproj -scheme Epistemos -destination "platform=macOS,arch=arm64" -derivedDataPath .derived-data-pre-helios-audit -clonedSourcePackagesDirPath .spm-cache -resultBundlePath build/xcode-results/2026-05-07-pre-helios-focused-build-for-testing.xcresult`
  - Result: PASS (`** TEST BUILD SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-pre-helios-focused-build-for-testing.xcresult`
- Focused pre-Helios Swift test sweep:
  - Command: `./scripts/xcodebuild_epistemos.sh test-without-building ... -only-testing:EpistemosTests/EpdocDocumentTests ... -only-testing:EpistemosTests/LiveCodeEditorControllerTests`
  - Scope: `.epdoc`, graph/Halo, note/window/storage/chat/editor, Search Fusion diagnostics, and code-editor polish.
  - Result: PASS (`382 tests in 30 suites`, `** TEST EXECUTE SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-pre-helios-focused-test-without-building.xcresult`
- Runtime smoke from the same pre-Helios build:
  - Command: `pkill -x Epistemos`
  - Command: `open -n -a /Users/jojo/Downloads/Epistemos/.derived-data-pre-helios-audit/Build/Products/Debug/Epistemos.app`
  - Computer Use: `⌥⌘N` created an `Untitled` `.epdoc` tab with `Start writing your Epistemos document...`, status `0 words 0 chars`, and the native curved toolbar.
  - Computer Use: typed a representative research document; status updated to `35 words 227 chars`.
  - Computer Use: clicked `Insert document diagram`; status updated to `136 words 1,484 chars`, `Mermaid 1`, and the rendered diagram contained document-derived nodes rather than the stale static sample.
  - Computer Use: clicked the image toolbar by coordinate; native `Choose Image` panel opened with the local-image prompt.
- Runtime log check:
  - Command: `/usr/bin/log show --last 10m --predicate 'process == "Epistemos"' --style compact`
  - Result: PASS for this smoke. The visible logs were WebKit memory-pressure/performance/state-restoration entries, including WebContent memory footprints around 103-131 MB and 0.0-0.9% CPU samples. No app-authored `.epdoc`, graph, save, or crash/error log appeared during the smoke window.

### Notes

- This slice materially improves confidence in the pre-Helios surfaces, but it is still not a full release sign-off. The broader app has a very dirty tree, known benchmark JSON churn, and Helios/V6 work intentionally left out of this audit.
- The runtime graph smoke verifies the local `.epdoc` document-diagram card, not the full saved-document-to-global-Halo projection after autosave/reopen. That remains the next strongest autonomous audit target.
- The UI creation path works, but `⌘N` versus `⌥⌘N` is a UX/discoverability issue worth polishing. A user looking for a normal "new document" flow can still hit the vault chooser first.

## Next Autonomous Slice

Continue pre-Helios verification without entering Helios refactor logic. The next autonomous slice should move to app-level graph/Halo document projection, because the blank-document creation and local document-diagram runtime path now have fresh evidence.

Safe next implementation/audit candidates if GUI relaunch remains blocked:

1. App-level graph/Halo document projection smoke: verify a saved `.epdoc` document node appears in the global graph/Halo path after autosave and reopen.
2. `.epdoc` creation discoverability polish: make the normal creation route obvious without compromising the vault-folder flow (`⌥⌘N` works; plain `⌘N` currently opens vault selection).
3. Build a repeatable five-line code-block GUI harness: no stale DerivedData processes, select five lines -> Code block -> `Code 1`.
4. `.epdoc` multi-image media polish: support ordered multi-image paste/drop after the single-image bridge has fresh-runtime evidence.
5. `.epdoc` chart inspector/export polish: add CSV/table-to-chart conversion and snapshot export only if the current chart cards pass runtime smoke.
6. Visible code-editor semantic LSP integration: wire the verified in-process Rust LSP substrate into the native code editor without adding a CodeMirror island.

Do not touch protected `MetalGraphView` / `HologramController` internals unless the audit proves the bridge into them is the failing boundary.

## Slice 29 — `.epdoc` Native Copilot Dock + Visible Metadata Transform

### Findings

- Added a native bottom-right `.epdoc` copilot dock instead of embedding a second React/CopilotKit surface in the editor. This follows the canon invariant that visuals and assistants project canonical document state; they do not invent a separate state universe.
- The dock is intentionally bounded for this slice. It routes recognized prompts/quick actions to concrete editor commands: derive a document graph, add visible frontmatter, insert scatter/bar/line chart cards, and insert a study callout. Unknown free-form prompts still call the existing `onAskAgent` hook, but there is not yet a completed streaming local-agent rewrite loop for arbitrary transformations.
- Added a visible YAML frontmatter transform. It inserts a `yaml` code block at the top only if the document does not already start with frontmatter. The `.epdoc` package manifest remains the persistence authority; this block is user-facing research metadata, not a second hidden manifest.
- Runtime smoke confirmed the dock appears in the native dark-mode `.epdoc` window as an `Ask Epdoc` bubble, opens into a compact native material panel, and can insert frontmatter through the Swift-to-JS editor bridge.
- Runtime smoke also re-confirmed the existing document graph card is not the old fake `Idea -> Evidence` fallback: the visible diagram is derived from headings, prose, claims/evidence/questions, and wikilinks in the current document.
- The first focused XCTest run failed with `The test runner hung before establishing connection`. A stale Epistemos debug app from the previous smoke was still running. After killing Epistemos instances and rerunning the same focused suite from the same derived-data root, the suite passed. Treat this as a test-harness/startup flake worth watching, not as proof of app readiness.

### Verification

- JS typecheck:
  - Command: `cd js-editor && npm run typecheck`
  - Result: PASS
- JS code-block guard:
  - Command: `cd js-editor && npm run check:code-block`
  - Result: PASS (`code block command range check passed`)
- JS document-graph guard:
  - Command: `cd js-editor && npm run check:document-graph`
  - Result: PASS (`document graph builder check passed`)
- JS chart renderer guard:
  - Command: `cd js-editor && npm run check:charts`
  - Result: PASS (`chart node renderer check passed`)
- Focused Swift/Xcode suite, first run:
  - Command: `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos -destination platform=macOS,arch=arm64 -derivedDataPath .derived-data-epdoc-copilot -clonedSourcePackagesDirPath .spm-cache -only-testing:EpistemosTests/EpdocCopilotSurfaceTests -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests`
  - Result: FAIL (`The test runner hung before establishing connection`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-111847-44051.xcresult`
- Focused Swift/Xcode suite, clean rerun after `pkill -x Epistemos`:
  - Command: same focused suite as above
  - Result: PASS (`11 tests in 2 suites`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-113317-48918.xcresult`
- Focused Swift/Xcode suite, Codex verification rerun:
  - Command: same focused suite as above, after another `pkill -x Epistemos`
  - Result: PASS (`11 tests in 2 suites`, `** TEST SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-114331-52181.xcresult`
- Runtime smoke:
  - Command: `open /Users/jojo/Downloads/Epistemos/.derived-data-epdoc-copilot/Build/Products/Debug/Epistemos.app`
  - Computer Use: verified `Ask Epdoc` bubble in the bottom-right of a native `.epdoc` window.
  - Computer Use: opened the dock; accessibility tree exposed `Epdoc Copilot`, quick actions for `Visualize document`, `Add frontmatter`, `Scatterplot`, and `Bar chart`.
  - Computer Use: clicked `Add frontmatter`; the editor text updated with a visible YAML block:
    `title: Untitled`, `status: draft`, `tags: []`, and the current date.
- Runtime smoke, Codex verification rerun:
  - Command: `open /Users/jojo/Downloads/Epistemos/.derived-data-epdoc-copilot/Build/Products/Debug/Epistemos.app`
  - Computer Use: verified dark-mode native `.epdoc` chrome with curved toolbar, document status `4,918 words 43,317 chars`, bottom-right `Ask Epdoc` bubble, and expanded `Epdoc Copilot` panel.
  - Computer Use: verified quick actions remained reachable and the visible document-derived Mermaid card was present in-editor. No mutation action was executed during this rerun.
  - Cleanup: `pkill -x Epistemos`

### Notes

- This is a real usability upgrade, but not the final CopilotKit-class agentic document editor. The next slice should wire the unknown-prompt path into a bounded local document-agent action plan rather than copying `MiniChatView` or adding a JS assistant runtime.
- The next implementation should preserve the dock's native SwiftUI surface and route only structured document transforms back through the bridge. If generative UI cards are added, they should be schema-first and remain projections of `.epdoc` content.
- A later polish pass should make the frontmatter block render as a native-feeling metadata card while preserving the underlying YAML source, matching the user's preference for Apple-native minimal cards over heavy 3D/cinematic boxes.

## Slice 30 — `.epdoc` App-Level Graph Projection Persistence

### Findings

- Audited the app-level `.epdoc` graph path from `EpdocDocument.projectAndPersistGraph(contentJSON:)` through `EpdocGraphProjector` into `EpdocGraphPersistence.upsert(projection:context:)`.
- The source path is real, not a fake local diagram only: autosave/open projection builds a manifest-backed graph projection, persists a document node into SwiftData, replaces generated outgoing projection edges, and posts graph refresh notifications.
- Added persistence tests for the graph/Halo backing store behavior the user was worried about: document nodes materialize as `.document`, `[[wikilink]]` targets create visible lightweight `.idea` nodes, repeated projection edges deduplicate, and regenerated edges do not delete manual user graph edges.
- Corrected the projector comment to match implementation reality: missing wikilink targets are not left dangling; persistence creates lightweight idea nodes so the saved document can be explored immediately.
- The first `xcodebuild test` run failed before executing tests with `The test runner hung before establishing connection`. The same already-built product then passed with `test-without-building`; this is evidence of a harness/startup flake, not a failing graph assertion.

### Verification

- Focused Swift/Xcode suite, first run:
  - Command: `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos -destination platform=macOS,arch=arm64 -derivedDataPath .derived-data-epdoc-graph-persistence -clonedSourcePackagesDirPath .spm-cache -only-testing:EpistemosTests/EpdocGraphPersistenceTests -only-testing:EpistemosTests/EpdocGraphProjectorTests -only-testing:EpistemosTests/EpdocGraphRenderingMapperTests`
  - Result: FAIL before execution (`The test runner hung before establishing connection`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-120115-62830.xcresult`
- Focused Swift/Xcode suite, same build via `test-without-building`:
  - Command: `./scripts/xcodebuild_epistemos.sh test-without-building -project Epistemos.xcodeproj -scheme Epistemos -destination platform=macOS,arch=arm64 -derivedDataPath .derived-data-epdoc-graph-persistence -clonedSourcePackagesDirPath .spm-cache -only-testing:EpistemosTests/EpdocGraphPersistenceTests -only-testing:EpistemosTests/EpdocGraphProjectorTests -only-testing:EpistemosTests/EpdocGraphRenderingMapperTests`
  - Result: PASS (`17 tests in 3 suites`, `** TEST EXECUTE SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-121259-64933.xcresult`
- New persistence coverage:
  - `upsert materializes .epdoc document and wikilink nodes`
  - `upsert updates existing document and replaces only generated projection edges`
  - `upsert deduplicates repeated projection edges`

### Notes

- This slice verifies the data/persistence boundary for saved `.epdoc` projection into the app graph. It does not yet visually smoke the global Metal/Halo route after autosave and reopen.
- The next strongest autonomous slice is a GUI runtime smoke that creates or opens a `.epdoc`, waits for autosave, switches to the global graph/Halo surface, and confirms the persisted document node and wikilink idea nodes are visible.
- Do not touch protected `MetalGraphView` / `HologramController` internals unless that runtime smoke proves the persisted SwiftData graph is correct but the visual projection bridge fails.

## Slice 31 — Runtime `.epdoc` to Global Graph/Halo Smoke

### Findings

- Created a disposable `.epdoc` package under `/private/tmp/epdoc-halo-smoke-2026-05-07.epdoc` with a manifest-backed document id, heading, prose, list items, and two wikilinks: `[[Capability Sandwich]]` and `[[Epdoc Graph]]`.
- Opened that package directly in the current debug build, avoiding mutation of the user's vault. The `.epdoc` editor rendered the package title/content correctly with the native dark window, curved toolbar, complexity pill, and `Ask Epdoc` dock.
- Used the View menu's `Knowledge Graph` item. The menu fallback correctly routed through `toggleKnowledgeGraphFromMenu(_:)`, detected the active `EpdocDocument`, and called `HologramController.shared.revealDocument(epdoc.package.manifest.id)`.
- The global graph/Halo surface selected `Codex Halo Smoke 2026-05-07` as a `Document` node and showed `2 connections`. The visible graph contained the wikilink-derived `Capability Sandwich` and `Epdoc Graph` nodes. This verifies the saved-document-to-global-Halo bridge is real at runtime.
- Nuance found: the `.epdoc` local complexity/status pill still showed `Links 0` while the global graph correctly materialized two wikilinks. That means graph projection sees wiki syntax, but the local stats/complexity counter does not yet count wikilinks as links.

### Verification

- Disposable fixture:
  - Path: `/private/tmp/epdoc-halo-smoke-2026-05-07.epdoc`
  - Files: `manifest.json`, `content.pm.json`
- Runtime launch:
  - Command: `pkill -x Epistemos`
  - Command: `open -n -a /Users/jojo/Downloads/Epistemos/.derived-data-epdoc-graph-persistence/Build/Products/Debug/Epistemos.app /private/tmp/epdoc-halo-smoke-2026-05-07.epdoc`
- Computer Use smoke:
  - Verified `.epdoc` window title `epdoc-halo-smoke-2026-05-07.epdoc`.
  - Verified editor text includes `Codex Halo Smoke`, `[[Capability Sandwich]]`, and `[[Epdoc Graph]]`.
  - Opened View → `Knowledge Graph`.
  - Verified global graph/Halo inspector selected `Codex Halo Smoke 2026-05-07`, type `Document`, with `2 connections`.
  - Verified visible graph labels `Capability Sandwich` and `Epdoc Graph`.
- Runtime log check:
  - Command: `/usr/bin/log show --style compact --last 5m --predicate 'process == "Epistemos" AND (eventMessage CONTAINS[c] "error" OR eventMessage CONTAINS[c] "fault" OR eventMessage CONTAINS[c] "failed" OR eventMessage CONTAINS[c] "undecodable")'`
  - Result: app remained usable and the graph smoke passed, but logs contained WebKit/WebContent sandbox-denial noise for pasteboard/audio/CoreServices/AppIntents bootstrap lookups and one system Synapse backlink-service undecodable XPC fault. No Epistemos-authored `.epdoc` graph projection failure appeared in the smoke window.

### Notes

- This closes the Slice 30 runtime gap: `.epdoc` package → autosave/open projection → SwiftData graph persistence → global graph/Halo reveal is verified with a disposable package.
- The next autonomous `.epdoc` hardening target is the status/complexity mismatch: local `.epdoc` metadata should count `[[wikilinks]]` as links, because the graph already treats them as document relationships.
- The WebKit sandbox log noise is not a functional blocker for this smoke, but it should stay visible in the audit trail. If image paste, pasteboard, audio, or App Intent behavior acts strange later, this log cluster is the first clue to revisit.

## Slice 32 — Global Graph Command Restored + `.epdoc` Local Stats Alignment

### Findings

- The user-reported "I can't see much nodes on my graph" regression was command drift, not graph-data loss. The normal View → `Knowledge Graph` command had been overloaded to reveal the active `.epdoc` document neighborhood when one existed, so users saw a tiny focused artifact graph and reasonably thought the global graph had lost nodes.
- Restored command semantics: `Knowledge Graph` now opens the full global graph through `HologramController.shared.toggle()`. The useful focused behavior is preserved as a separate explicit action, `Reveal Current Document in Graph`, which calls `HologramController.shared.revealDocument(...)`.
- The AppKit View-menu fallback now rebinds both menu items to concrete selectors for document-launched windows. This keeps the direct `.epdoc` launch path native and avoids depending on a generic SwiftUI `menuAction` responder.
- Fixed the `.epdoc` local stats/complexity mismatch discovered in Slice 31. `[[wikilinks]]` now count as document links, and the complexity scanner recognizes the real Tiptap aliases currently used by the editor: `codeBlock`, `inlineMath`, `blockMath`, `epdocChart`, `epdocImage`, and `image`.
- This preserves the intentional `.epdoc` graph scaffold instead of deleting it: global graph and focused document reveal are now two separate, honest affordances.

### Verification

- Focused Swift/Xcode suite, normal run:
  - Command: `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos -destination platform=macOS,arch=arm64 -derivedDataPath .derived-data-epdoc-graph-persistence -clonedSourcePackagesDirPath .spm-cache -only-testing:EpistemosTests/BackgroundGraphLoadingTests -only-testing:EpistemosTests/EpdocComplexityCalculatorTests -only-testing:EpistemosTests/EpdocGraphProjectorTests`
  - Result: PASS (`42 tests in 3 suites`, `** TEST SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-125452-78996.xcresult`
- Runtime smoke:
  - Command: `pkill -x Epistemos`
  - Command: `open -n -a /Users/jojo/Downloads/Epistemos/.derived-data-epdoc-graph-persistence/Build/Products/Debug/Epistemos.app /private/tmp/epdoc-halo-smoke-2026-05-07.epdoc`
  - Computer Use: verified the `.epdoc` status pill reports `Links 2` for the disposable package containing two wikilinks.
  - Computer Use: verified View menu exposes both `Knowledge Graph` and `Reveal Current Document in Graph`; after the final rebind patch, `Reveal Current Document in Graph` is routed to `revealCurrentDocumentInKnowledgeGraph:`.
  - Computer Use: picked `Knowledge Graph` and verified the full global graph appears with many folders/nodes/clusters rather than the two-node focused `.epdoc` neighborhood.

### Notes

- The global graph was not empty. The UI was opening the wrong graph mode for the command the user pressed.
- The explicit document reveal command remains important and should not be removed as "dead code"; it is the correct place for the local `.epdoc` artifact graph.
- Broader graph/Halo readiness still depends on the wider pre-Helios audit loop. This slice only closes the sparse-node command regression and the `.epdoc` local stats mismatch.

## Slice 33 — `.epdoc` Canvas Theme Unification

### Findings

- The `.epdoc` editor was visually stacking two backgrounds in dark mode: the native SwiftUI window theme underneath, plus the embedded WKWebView/Tiptap document area forcing its own OLED-style `#000000` canvas on top.
- Changed the embedded editor canvas to let the native window theme show through. The macOS WKWebView path now disables WebKit background drawing and uses a transparent AppKit layer; the editor CSS sets `--epdoc-bg: transparent` in both light and dark mode.
- Kept card/code/diagram backgrounds intact. Only the document canvas changed; code blocks, charts, diagrams, callouts, image cards, toolbar, slash menu, and copilot surfaces remain visible native cards.
- An initial attempt used iOS-style WKWebView properties (`isOpaque`, `backgroundColor`, `scrollView`) and Xcode correctly rejected it on macOS. The final patch uses the macOS-supported path already present in the codebase: `drawsBackground` KVC + transparent layer + transparent CSS.

### Verification

- Focused Swift/Xcode suite, first post-test patch run:
  - Command: `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos -destination platform=macOS,arch=arm64 -derivedDataPath .derived-data-epdoc-theme-surface -clonedSourcePackagesDirPath .spm-cache -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests`
  - Result: FAIL at build, before runtime tests, because the first patch used non-macOS WKWebView properties.
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-130618-83066.xcresult`
- Focused Swift/Xcode suite, corrected macOS path normal run:
  - Command: same focused suite as above.
  - Result: FAIL before executing tests (`The test runner hung before establishing connection`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-131110-87082.xcresult`
- Focused Swift/Xcode suite, same build via `test-without-building`:
  - Command: `./scripts/xcodebuild_epistemos.sh test-without-building -project Epistemos.xcodeproj -scheme Epistemos -destination platform=macOS,arch=arm64 -derivedDataPath .derived-data-epdoc-theme-surface -clonedSourcePackagesDirPath .spm-cache -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests`
  - Result: PASS (`9 tests in 1 suite`, `** TEST EXECUTE SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-132325-90151.xcresult`
- Runtime smoke:
  - Command: `open -n -a /Users/jojo/Downloads/Epistemos/.derived-data-epdoc-theme-surface/Build/Products/Debug/Epistemos.app`
  - Computer Use: clicked `New Doc` and verified a native `.epdoc` document window opened with visible placeholder text, native toolbar, status footer, and bottom-right `Ask Epdoc`.
  - Computer Use: visually verified the document area no longer appears as a separate pure OLED plate; it blends with the native dark window theme while keeping editor text readable.
- Runtime logs:
  - Command: `/usr/bin/log show --style compact --last 5m --predicate 'process == "Epistemos" AND (eventMessage CONTAINS[c] "error" OR eventMessage CONTAINS[c] "fault" OR eventMessage CONTAINS[c] "failed" OR eventMessage CONTAINS[c] "undecodable")'`
  - Result: app remained usable; logs showed known WebKit/WebContent sandbox-denial noise around pasteboard/CoreServices/AppIntents/audio registration and WebKit layer volatility, with no Epistemos-authored `.epdoc` theme/render failure found.

### Notes

- The current runtime smoke was dark-mode only because the app/system was dark at verification time. The source guard pins the same transparent CSS variable for both light and dark.
- If a future pass wants even less contrast, tune the SwiftUI `EpdocEditorChromeView` gradient/token surface. Do not reintroduce a WebView-level `#000000` or `#ffffff` page background; that recreates the two-layer theme bug.

## Slice 34 — `.epdoc` Native Image Picker Runtime Verification

### Findings

- Re-audited the user-visible image path because the product expectation is Apple Notes-like: choose a local image and see the actual bitmap in the document, not a generic icon.
- No code change was needed in this slice. The current source path is real:
  - `EpdocEditorToolbar` opens a native `NSOpenPanel` titled `Choose Image` with the prompt `Insert a local image into this Epistemos document.`
  - The owning `EpdocDocument` installs `toolbarModel.resolvePickedImageSource`, so toolbar-picked images go through `EpdocDocument.storeImageAsset(...)` instead of living only as WebView-only state.
  - The WebView resolves package-local `assets/...` image references through `EpdocEditorURLSchemeHandler`.
  - `epdocImage` renders an actual `<img data-epdoc-image>` node.
- Runtime verification used the user's real desktop PNG reference, `/Users/jojo/Desktop/IMG_0344.png`. The picker accepted the file and the editor rendered the actual screenshot bitmap inline.
- The status/complexity strip updated to `Embeds 1`, and the toolbar Save control flipped back to `All changes saved` after clicking Save. That is positive runtime evidence that the editor saw the image node and the document save path accepted the mutation.

### Verification

- Source/code audit:
  - Command: `rg -n "resolvePickedImageSource|storeImageAsset|documentAsset|assets/|EpdocEditorToolbarModel" Epistemos/Views/Epdoc/EpdocEditorChromeView.swift Epistemos/Engine/EpdocDocument.swift Epistemos/Engine/EpdocEditorBridge.swift EpistemosTests/EpdocDocumentTests.swift EpistemosTests/EpdocEditorBridgeTests.swift`
  - Result: confirmed the toolbar picker, package-local asset writer, URL-scheme resolver, and bridge tests are wired.
- Focused Swift/Xcode image bridge/document execution:
  - Command: `./scripts/xcodebuild_epistemos.sh test-without-building -project Epistemos.xcodeproj -scheme Epistemos -destination platform=macOS,arch=arm64 -derivedDataPath .derived-data-epdoc-theme-surface -clonedSourcePackagesDirPath .spm-cache -only-testing:EpistemosTests/EpdocDocumentTests -only-testing:EpistemosTests/EpdocEditorBridgeTests`
  - Result: PASS (`39 tests in 2 suites`, `** TEST EXECUTE SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-133450-93651.xcresult`
- Runtime smoke with Computer Use:
  - Command: `open -n -a /Users/jojo/Downloads/Epistemos/.derived-data-epdoc-theme-surface/Build/Products/Debug/Epistemos.app`
  - Created `Untitled 16.epdoc`.
  - Clicked the toolbar `Image` button.
  - Verified the native `Choose Image` panel appeared with the expected local-image prompt.
  - Used Finder's Go-to-path sheet to select `/Users/jojo/Desktop/IMG_0344.png`.
  - Clicked `Insert`.
  - Verified the actual screenshot bitmap rendered inline inside `.epdoc` and the status strip reported `Embeds 1`.
  - Clicked Save and verified the Save help text returned to `All changes saved`.
- Runtime logs:
  - Command: `/usr/bin/log show --style compact --last 10m --predicate 'process == "Epistemos" AND (eventMessage CONTAINS[c] "epdoc" OR eventMessage CONTAINS[c] "image" OR eventMessage CONTAINS[c] "asset" OR eventMessage CONTAINS[c] "fault" OR eventMessage CONTAINS[c] "error" OR eventMessage CONTAINS[c] "failed" OR eventMessage CONTAINS[c] "undecodable")'`
  - Result: the app remained usable and the image rendered. Logs still show the known WebKit/WebContent sandbox-denial cluster and a test-runtime `NightBrain search index maintenance requires an initialized SearchIndexService` line, but no Epistemos-authored `.epdoc` image/asset failure appeared during the smoke.

### Notes

- This slice verifies toolbar/file-picker image insertion in the latest built app. It does not yet visually smoke paste/drop image insertion, although the bridge and document tests cover the same package-local storage route.
- Do not remove the data-URL fallback. It remains intentional for transient editor hosts and bridge-failure protection until paste/drop plus fresh-process save/reopen are runtime-proven.
- Do not remove `EpdocPackage.assets`, `storeImageAsset`, or the document asset URL-scheme handler as "scaffold"; they are live in the toolbar image path and covered by focused tests.

## Slice 35 — `.epdoc` Complexity Meter Truthfulness

### Findings

- The `.epdoc` complexity meter was real, not fake: Tiptap emits document JSON through the bridge, Swift decodes it as `ProseMirrorNode`, and `EpdocComplexityCalculator` computes the score used by `EpdocComplexityMeter`.
- The previous formula was too shallow for research documents. It counted words, heading depth, code, links, math, Mermaid/chart blocks, and embeds, but it under-reported actual research structure such as many sections, tables, list/task density, callouts, citations, and footnotes.
- That made the meter feel like it was "lying" on serious `.epdoc` documents: a document could have substantial epistemic structure while still scoring like a medium prose note.
- A source guard had also drifted from the current JS implementation. The editor now defers heavy JSON/stringify work through a debounced `scheduleContentDidChange(editor)` path, not the old direct `scheduleContentDidChange(JSON.stringify(ed.getJSON()))` shape.

### Changes Made

- `Epistemos/Engine/EpdocComplexityCalculator.swift`
  - Expanded the default scoring model from 7 to 11 sub-metrics while keeping the total weight exactly `1.0`.
  - Added research-structure counters for heading count, tables, list/task items, callouts, and citations/footnotes.
  - Replaced whitespace-only word counting with an alphanumeric Unicode-scalar boundary counter.
  - Changed heading scoring from max-depth-only to a section-count + max-depth composite.
- `Epistemos/Views/Epdoc/EpdocComplexityMeter.swift`
  - Expanded the tooltip so the user can inspect why the score is what it is: words/sections, code/math/visuals, tables/lists/callouts, and links/citations/embeds.
- `EpistemosTests/EpdocComplexityCalculatorTests.swift`
  - Added coverage for research-structure counts and the new heading composite.
  - Updated saturation/default-weight tests so a fully saturated document still clamps to `1.0`.
- `EpistemosTests/EpdocVisibilitySourceGuardTests.swift`
  - Updated the source guard to match the current debounced JS update path and the host-document-loaded sentinel.

### Verification

- First focused Xcode attempt:
  - Command: `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos -destination platform=macOS,arch=arm64 -derivedDataPath .derived-data-epdoc-complexity -clonedSourcePackagesDirPath .spm-cache -only-testing:EpistemosTests/EpdocComplexityCalculatorTests -only-testing:EpistemosTests/EpdocEditorBridgeTests -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests`
  - Result: FAIL at compile time because the new saturation fixture used `$0` inside a closure with an explicit `_` parameter.
  - Fix: changed the fixture closure to use an explicit `index` parameter.
- Corrected focused Xcode rerun:
  - Same command as above.
  - Result: PASS (`55 tests in 3 suites`, `** TEST SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-150506-33997.xcresult`

### Notes

- This makes the metric more honest and inspectable; it does not claim academic-grade cognitive load measurement. Treat it as a useful document-structure signal, not an oracle.
- Future improvement: add calibration fixtures from real user `.epdoc` packages and compare the meter against user-perceived complexity bands.

## Slice 36 — Build Topology / Scheme Reality Check

### Findings

- Xcode currently exposes exactly two shared runnable schemes:
  - `Epistemos`
  - `Epistemos-AppStore`
- `project.yml` defines additional targets (`EpistemosWidgets`, `NightBrainHelper`, `EpistemosTests`, and package dependencies), but those are not separate runnable app schemes. They build as extension/helper/test/package surfaces under the app topology.
- "Pro" and "Research" are not separate Xcode schemes today. The tier distinction is implemented mostly through compile-time feature/config surfaces:
  - The normal `Epistemos` target links the Pro-capable surfaces, including `omega_ax`, and `build-agent-core.sh` builds `agent_core` with `--no-default-features --features "pro-build,lsp-runtime"`.
  - The `Epistemos-AppStore` target builds the MAS-sandboxed sibling app, omits `omega_ax` from Swift bindings/link flags, runs `MAS_SANDBOX=1` for `omega-mcp`, scrubs Pro frameworks after build, and `build-agent-core.sh` builds `agent_core` with `--no-default-features --features "mas-build,lsp-runtime"`.
  - `agent_core` has an independent `research` feature for research surfaces, but neither Xcode scheme enables that feature right now.
- A raw `xcodebuild -list` attempt failed under the Codex sandbox because Xcode tried to write to user cache/module-cache locations outside the workspace. That failure is not counted as a project build failure.

### Verification

- Scheme/source topology:
  - `ls Epistemos.xcodeproj/xcshareddata/xcschemes` — confirmed only `Epistemos.xcscheme` and `Epistemos-AppStore.xcscheme`.
  - `project.yml` audit — confirmed targets and scheme wiring.
  - `agent_core/Cargo.toml` + `build-agent-core.sh` audit — confirmed `mas-build`, `pro-build`, `research`, and `lsp-runtime` feature behavior.
- App Store scheme build:
  - Command: `./scripts/xcodebuild_epistemos.sh build -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination platform=macOS,arch=arm64 -derivedDataPath .derived-data-appstore-build -clonedSourcePackagesDirPath .spm-cache CODE_SIGNING_ALLOWED=NO`
  - Result: PASS (`** BUILD SUCCEEDED **`)

### Notes

- If the product needs explicit visible schemes such as `Epistemos-Pro` or `Epistemos-Research`, that is a future project-organization decision, not a missing build today.
- The current topology is: App Store build = MAS sibling target; normal Epistemos build = Pro-capable/developer build; Research = dormant/opt-in Rust feature unless deliberately wired into a scheme.
