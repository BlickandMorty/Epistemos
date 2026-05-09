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
6. Code-editor semantic LSP follow-up: add diagnostics only after hover/definition UI passes manual runtime smoke.

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

## Slice 37 — Code Editor Search Execution

### Findings

- `CodeEditorView` exposed a visible search bar, but the execution path was still a stub:
  - `findNext()` and `findPrevious()` called `performSearch(direction:)`.
  - `performSearch(direction:)` accepted the query, then discarded the direction with `_ = direction`.
- This was a release-quality problem: a clickable editor control looked implemented but could not select or scroll to matches.
- The vendored `CodeEditSourceEditor` state updater also has a cursor-position self-comparison bug (`cursorPositions != state.cursorPositions` inside the `if let` binding), so relying only on `SourceEditorState.cursorPositions` would not be enough to make selection visibly move.

### Changes Made

- `Epistemos/Views/Notes/CodeEditorView.swift`
  - Added `nonisolated` `CodeEditorSearchDirection` and `CodeEditorSearchEngine` pure helpers.
  - Implemented wrapped forward/backward `NSString` range search with explicit case-sensitivity behavior.
  - Treated `.notFound` cursor ranges as scaffold/no-anchor so search starts from the beginning/end instead of overflowing an invalid range.
  - Added `activeSearchRange` state and invalidation when text, query, or case-sensitivity changes.
  - Replaced the visible search stub with real match selection.
  - Added `EpistemosEditorCoordinator.select(range:scrollToVisible:)`, using CodeEditSourceEditor's public `TextViewController.setCursorPositions`.
- `EpistemosTests/CodeEditorPolishTests.swift`
  - Added behavioral coverage for forward wrap, backward wrap, case sensitivity, `.notFound` cursor ranges, and a source guard that rejects the old `_ = direction` stub.

### Verification

- First focused Xcode attempt:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/CodeEditorPolishTests`
  - Result: FAIL at compile time because the pure search helper inherited the target's default `MainActor` isolation.
  - Fix: marked `CodeEditorSearchDirection` and `CodeEditorSearchEngine` as `nonisolated`, matching other pure parser/helper types in `CodeEditorView.swift`.
- Corrected focused Xcode rerun:
  - Same command as above.
  - Result: PASS (`17 tests in 1 suite`, `** TEST SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-201618-27638.xcresult`
- Runtime GUI smoke attempt:
  - Command/tool: Computer Use `list_apps`
  - Result: BLOCKED; the Computer Use tool timed out after 120 seconds before app interaction could begin.

### Notes

- This slice makes the existing find bar honest and functional; it does not add replacement, regex, multi-file search, or semantic/LSP search.
- Runtime GUI verification is still owed before calling the keyboard/user-flow polish fully signed off: open a code note, show search, enter a repeated term, click next/previous, verify selection and scroll movement.
- Visible semantic LSP hover/definition remains a separate integration slice. Do not claim that the LSP substrate is user-facing just because this search bar now works.

## Slice 38 — Code Editor On-Demand Semantic LSP Hover

### Findings

- The in-process Rust LSP substrate was already real and tested, but the visible code editor still did not instantiate `RustLSPTransport` or `LSPClient`.
- `CodeEditorReleasePolicy.semanticSidebarEnabled` is intentionally `false`, and that should stay true for v1: the sidebar is a larger semantic sidecar with related-note work, not a small release-safe LSP affordance.
- A safe v1 slice exists between "substrate only" and "full semantic sidebar": an explicit user-triggered symbol inspection button for languages the Rust LSP kernel currently supports.

### Changes Made

- `Epistemos/Views/Notes/CodeEditorView.swift`
  - Added `CodeEditorSemanticLSP`, a nonisolated bridge that supports only Swift/Rust, clamps the live cursor to an LSP position, opens the editor buffer with `LSPClient.didOpen`, calls real `textDocument/hover`, summarizes the returned hover, and shuts down the transport.
  - Added an Inspect Symbol icon button to the code editor breadcrumb chrome. Unsupported languages are disabled so they do not look installed/runnable.
  - Added a dismissible status overlay for hover results, no-symbol responses, and honest unavailable/runtime-linkage errors.
  - Kept `CodeEditorReleasePolicy.semanticSidebarEnabled = false`; this slice does not turn on the deferred semantic sidebar.
- `EpistemosTests/CodeEditorPolishTests.swift`
  - Added coverage for LSP position clamping, hover summarization, the editor bridge returning a Rust hover through the FFI-backed transport, and source guards that require the on-demand UI path while keeping the deferred sidebar gated.

### Verification

- First focused Xcode attempt:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/CodeEditorPolishTests -only-testing:EpistemosTests/RustLSPTransportTests`
  - Result: FAIL at compile time because `if let semanticStatusMessage` in `semanticLSPStatusOverlay` shadowed the `@State` value, making the dismiss button assignment target a local `let`.
  - Fix: renamed the optional-binding local to `message`.
- Corrected focused Xcode rerun:
  - Same command as above.
  - Result: PASS (`27 tests in 2 suites`, `** TEST SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-203646-44237.xcresult`

### Notes

- This makes semantic hover user-facing for the native code editor without adding CodeMirror, subprocess LSP, or a new sidebar architecture.
- This does not expose definition navigation, diagnostics gutters, autocomplete, multi-file symbol search, or `.epdoc` code-block LSP semantics.
- Manual GUI verification is still owed because Computer Use timed out earlier: open a Swift or Rust code note, place the cursor on a known symbol, click Inspect Symbol, verify a hover summary appears; then open a non-Swift/Rust code note and verify the button is disabled.

## Slice 39 — Code Editor Same-File LSP Definition Navigation

### Findings

- The Rust LSP substrate already returned same-file definition locations, and the visible hover slice gave the editor a safe on-demand transport/client path.
- The remaining release gap was navigation: a user could ask for symbol info, but could not jump to the verified definition range even when the definition was in the same live buffer.
- Cross-file navigation is not wired in the native code editor, so the correct v1 behavior is to report cross-file targets honestly instead of pretending to open them.

### Changes Made

- `Epistemos/Views/Notes/CodeEditorView.swift`
  - Added `CodeEditorSemanticLSP.definitionLocation`, which opens the live buffer through the canonical `RustLSPTransport` + `LSPClient` path and calls real `textDocument/definition`.
  - Added UTF-16 range mapping from `LSPRange` to `NSRange`, matching the CodeEdit/TextKit selection model.
  - Added a Go to Definition icon button to the code editor chrome, gated to Swift/Rust and disabled while an LSP request is running.
  - Same-file definitions now select and scroll to the returned definition range through `EpistemosEditorCoordinator.select(range:scrollToVisible:)`.
  - Cross-file definitions are reported in the status overlay as found but not navigable.
- `EpistemosTests/CodeEditorPolishTests.swift`
  - Added selection-range mapping coverage.
  - Added FFI-backed bridge coverage for Rust definition lookup.
  - Expanded the source guard so visible definition lookup must call real LSP `definition` and select via the live editor coordinator.

### Verification

- Focused Xcode rerun:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/CodeEditorPolishTests -only-testing:EpistemosTests/RustLSPTransportTests`
  - Result: PASS (`29 tests in 2 suites`, `** TEST SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-204243-48493.xcresult`

### Notes

- This is same-file definition navigation only. It does not add project-wide indexing, cross-file opening, diagnostics gutters, completion, or LSP support inside `.epdoc` code cards.
- Manual GUI verification remains owed: in a Swift/Rust code note, place the cursor on a same-file call, click Go to Definition, and verify selection/scroll lands on the definition range.

## Slice 40 — Epdoc Typed Markdown Links + Wikilinks

### Findings

- The `.epdoc` paste pipeline already converted pasted Markdown links and wikilinks into structured Tiptap link marks, but typed Markdown links stayed as inert bracket syntax until the user reworked the text.
- `js-editor/src/extensions/markdown-input-rules.ts` only owned the custom table input rule. StarterKit covered some common block forms, and the image node owns image syntax, but there was no typed-link or typed-wikilink rule.
- This was a v1 Epdoc ergonomics gap, not a HELIOS substrate gap: the safe fix is an editor input rule that emits the same link mark shape the existing paste path already uses.

### Changes Made

- `js-editor/src/extensions/markdown-input-rules.ts`
  - Added typed Markdown link conversion for `[label](http://...)`, `[label](https://...)`, `[label](mailto:...)`, and `[label](epistemos-doc:...)`.
  - Added typed wikilink conversion for `[[Target]]` and `[[Target|alias]]`, producing `epistemos-doc:wiki/<encoded-target>` link marks with the visible label preserved.
  - Rejected image Markdown (`![alt](...)`) from the link input finder so `EpdocImageNode` remains the owner for image behavior.
  - Kept a strict href allowlist so unsafe schemes such as `javascript:` remain inert text.
- `js-editor/scripts/check-markdown-input-rules.mjs`
  - Added a Node/TypeScript VM harness that exercises the exported input-rule finders and applies the real ProseMirror replacement path against a schema with Tiptap's Link mark.
- `js-editor/package.json`
  - Added `npm run check:markdown-input-rules`.
- `EpistemosTests/EpdocVisibilitySourceGuardTests.swift`
  - Added source guards requiring the typed-link finder, typed-wikilink finder, real link replacement helper, wiki href encoding, and the JS check script.
- Rebuilt the shipped Tiptap resource bundle:
  - `Epistemos/Resources/Editor/editor.js.br`

### Verification

- JS input-rule harness:
  - Command: `npm run check:markdown-input-rules` from `js-editor`
  - Result: PASS (`markdown input rules check passed`)
- Existing Markdown paste harness:
  - Command: `npm run check:markdown-paste` from `js-editor`
  - Result: PASS (`markdown paste parser check passed`)
- JS typecheck:
  - Command: `npm run typecheck` from `js-editor`
  - Result: PASS
- Editor bundle:
  - Command: `./build-tiptap-bundle.sh`
  - Result: PASS; Webpack compiled successfully and refreshed `Epistemos/Resources/Editor/editor.js.br`.
- Focused Swift source guard:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests`
  - Result: PASS (`9 tests in 1 suite`, `** TEST SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-205603-55791.xcresult`
- Diff hygiene:
  - Command: `git diff --check`
  - Result: PASS

### Notes

- Manual GUI verification is still owed because the Computer Use runtime path timed out earlier: in a fresh `.epdoc`, type `[source](https://example.com)` and `[[Capability Sandwich|claim]]`, then verify both become links without backspace/retype.
- This slice does not add new diagram semantics, graph theory, HELIOS stages, or speculative substrate. It makes an existing editor promise reachable and test-backed.

## Slice 41 — Epdoc Image Source Safety Through Visible Commands

### Findings

- `.epdoc` image paste and typed image input already used `parseMarkdownImageLine`, which rejects unsafe image sources before creating an `epdocImage` node.
- The visible slash-menu Image command used `window.prompt('Image URL')` and then called `insertEpdocImage({ src })`; the command itself only checked for a non-empty string.
- That meant the most visible image-insertion path did not share the same image-source safety policy as typed/pasted Markdown. It could present a malformed or unsafe user-entered source as an inserted image node.

### Changes Made

- `js-editor/src/markdown/markdown-paste.ts`
  - Exported the existing `isSafeImageSrc` policy so every image insertion path can use the same allowlist.
- `js-editor/src/extensions/image-node.ts`
  - Reused `isSafeImageSrc` in the `insertEpdocImage` command and rejects unsafe prompt/command sources with an honest console warning.
  - Added `parseHTML` filtering so unsafe pasted/imported `<img src>` HTML is not parsed into an `epdocImage` node.
  - Added a render-time guard for malformed document JSON: unsafe stored `src` values render as a visible blocked-image placeholder instead of an image element.
- `js-editor/scripts/check-markdown-paste.mjs`
  - Added direct assertions for safe `https`, package-local `epistemos-doc`, and `data:image` sources, plus unsafe `javascript:` and quote-injection examples.
- `EpistemosTests/EpdocVisibilitySourceGuardTests.swift`
  - Expanded Epdoc source guards to require image-node command safety, blocked unsafe-source logging, and a blocked render marker.
- Rebuilt the shipped Tiptap resource bundle:
  - `Epistemos/Resources/Editor/editor.js.br`

### Verification

- Markdown paste/image safety harness:
  - Command: `npm run check:markdown-paste` from `js-editor`
  - Result: PASS (`markdown paste parser check passed`)
- Typed link/wikilink regression harness:
  - Command: `npm run check:markdown-input-rules` from `js-editor`
  - Result: PASS (`markdown input rules check passed`)
- JS typecheck:
  - Command: `npm run typecheck` from `js-editor`
  - Result: PASS
- Editor bundle:
  - Command: `./build-tiptap-bundle.sh`
  - Result: PASS; Webpack compiled successfully and refreshed `Epistemos/Resources/Editor/editor.js.br`.
- Focused Swift source guard:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests`
  - Result: PASS (`9 tests in 1 suite`, `** TEST SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-210415-64631.xcresult`

### Notes

- Manual GUI verification is still owed: use the Image slash command with a safe `https://...png` URL and verify it inserts an image; try an unsafe `javascript:` URL and verify no image is inserted.
- This slice does not alter package-local image asset storage or paste/drop byte handling. It only makes visible URL insertion use the same safety contract.

## Slice 42 — Shared Arena Diagnostics Without Authority Claims

### Findings

- The app already had a shared app-group container path and a Swift `ArenaBridge` scaffold with pinned budget constants (`v2`, 16 slots, 2 KiB request payloads, 4 KiB response payloads, 8 artefact refs).
- Settings diagnostics did not surface that arena path or whether `arena.dat` was actually materialized, so the memory/zero-copy surface was opaque to users and to release audit.
- The correct v1 hardening move is read-only visibility, not a new mmap runtime or an authority flip. Current Swift bridge behavior remains an in-memory request/response queue unless another proven runtime materializes the arena file.
- The Settings diagnostics copy still said "Cognitive DAG (V2 final lane)", which is visible v2 language in a v1 release-hardening pass.

### Changes Made

- `Epistemos/Views/Settings/ArenaHealthRow.swift`
  - Added a read-only Shared Arena diagnostics row.
  - Reports the app-group arena path, `ArenaBridge` budget constants, and whether `arena.dat` exists on disk.
  - Uses "not materialized" when no arena file exists, so Settings does not imply mmap/zero-copy runtime activation.
- `Epistemos/Views/Settings/SettingsView.swift`
  - Mounted `ArenaHealthRow()` in General -> Diagnostics.
  - Updated diagnostics copy to describe the Shared Arena row as path/budget visibility "without claiming runtime authority".
  - Removed the visible "V2 final lane" phrase from the Cognitive DAG diagnostics sentence.
- `EpistemosTests/ArenaTests.swift`
  - Added coverage for the arena diagnostics snapshot before and after materializing a temporary `arena.dat`.
  - Added a source guard that Settings mounts the row and does not reintroduce the visible v2 authority phrase.

### Verification

- Focused Swift tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/ArenaTests -only-testing:EpistemosTests/SettingsCategoryTests`
  - Result: PASS (`21 tests in 2 suites`, `** TEST SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-211012-71814.xcresult`

### Notes

- This is diagnostics only. It does not add mmap writes, Rust arena ownership, new memory architecture, new DAG authority, or HELIOS substrate behavior.
- Manual GUI verification is still owed: open Settings -> General -> Diagnostics and confirm Shared Arena shows the app-group `arena.dat` path and either "not materialized" or the real file size.

## Slice 43 — Local Model Picker Subtitle Fan-Out Hardening

### Findings

- `docs/APP_ISSUES_AUTO_FIX.md` still tracked `ISSUE-2026-04-22-001` path B: `LocalModelToolbarMenu.localModelSubtitle(for:)` called `inference.availableOperatingModes(for: .localMLX(model.id))` from each installed/installable local-model row.
- The current `InferenceState.availableOperatingModes(for:)` implementation no longer performs the documented memory-pressure syscall chain, but it still fans through observable runtime/catalog state during SwiftUI row rendering.
- The row copy only needs static model traits: Thinking support, local tool-loop capability, and the interactive memory recommendation. Those traits are already canonical on `LocalTextModelID`; the only dynamic nuance is the existing Qwen 3 unified fast/thinking pair.

### Changes Made

- `Epistemos/App/RootView.swift`
  - Added `localModelSubtitleCache` and a `localModelSubtitleInputsFingerprint` over visible local models plus prepared/installed model IDs.
  - Added `refreshLocalModelSubtitleCache()` to populate subtitle strings outside the row hot path.
  - Replaced the per-row `inference.availableOperatingModes(for:)` call with `staticLocalModelSubtitle(...)`, preserving the existing "Thinking", "Tools", "Fast only", and "Chat N GB+" copy.
  - Preserved the Qwen 3 unified-picker case by treating `Qwen3-4B-MLX-4bit` as Thinking-capable when the paired Thinking checkpoint is prepared or installed.
- `EpistemosTests/RuntimeValidationTests.swift`
  - Added a source guard that the local-model subtitle hot path does not reintroduce `availableOperatingModes(for:)` and keeps the cache/fingerprint refresh scaffold.
- `docs/APP_ISSUES_AUTO_FIX.md`
  - Promoted `ISSUE-2026-04-22-001` from partially fixed to source-fixed, with live memory-pressure/Time Profiler stress still explicitly pending.

### Verification

- Focused Swift tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/RuntimeValidationTests`
  - Result: PASS (`256 tests in 1 suite`, `** TEST SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-211835-82023.xcresult`

### Notes

- This is a source-level hot-path hardening, not a claimed live reproduction fix. Manual launched-app memory-pressure/Time Profiler stress is still owed before closing the historical CPU-loop issue as runtime-verified.
- No model-routing authority, HELIOS behavior, subprocess behavior, or new model catalog entries were added.

## Slice 44 — Production Force-Unwrap Cleanup

### Findings

- A production-only source scan still found avoidable force unwraps in three live surfaces:
  - `Epistemos/Views/Landing/Wave/LandingWaveRenderer.swift` used `raw.baseAddress!` in two per-frame uniform tuple writes.
  - `Epistemos/Engine/EpdocDocument.swift` force-unwrapped static UTF-8 `Data` creation for the default empty `.epdoc` payload.
  - `Epistemos/Engine/LSPMessage.swift` force-unwrapped static UTF-8 `Data` creation for the LSP frame header.
- These were not speculative features; they are v1 runtime/document/codec code paths and fall under the release directive to remove avoidable force unwraps.

### Changes Made

- `Epistemos/Views/Landing/Wave/LandingWaveRenderer.swift`
  - Replaced both `raw.baseAddress!` reads with guarded base-address binding inside the existing `withUnsafeMutableBytes` closures.
  - Kept the same zero-allocation raw-buffer approach; no new hot-path arrays or allocations were introduced.
- `Epistemos/Engine/EpdocDocument.swift`
  - Replaced `.data(using: .utf8)!` with `Data(staticString.utf8)` for the default empty ProseMirror document.
- `Epistemos/Engine/LSPMessage.swift`
  - Replaced `.data(using: .utf8)!` with `Data(headerString.utf8)` in `LSPMessageCodec.encode`.
- `EpistemosTests/NonAgentPruningValidationTests.swift`
  - Extended the existing force-unwrap source guard to cover the landing wave renderer, `.epdoc` document implementation, and LSP message codec.

### Verification

- Focused Swift tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/NonAgentPruningValidationTests -only-testing:EpistemosTests/LSPMessageTests -only-testing:EpistemosTests/EpdocDocumentTests -only-testing:EpistemosTests/LandingWaveChoreographyTests -only-testing:EpistemosTests/LandingWavePerformancePolicyTests -only-testing:EpistemosTests/LandingWaveGlyphAtlasTests`
  - Result: PASS (`76 tests in 6 suites`, `** TEST SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-212446-89742.xcresult`

### Notes

- This slice does not claim every existing test fixture is force-unwrap-free; it removes avoidable production force unwraps found in live v1 surfaces and pins those files with source-guard coverage.
- It does not change landing-wave rendering semantics, `.epdoc` schema, or LSP framing behavior.

## Slice 45 — AppKit Coder Trap Cleanup

### Findings

- A production-only crash-trap scan still found failable `init(coder:)` implementations in live editor/graph AppKit scaffolds that called `fatalError()`.
- These paths are not normal v1 construction paths, but returning `nil` from the failable initializer is a safer release behavior if archive/nib machinery ever reaches them.
- This slice intentionally left AppBootstrap fail-fast guards and semantic replay preconditions alone; those are authority/invariant guards, not failable UI archive entry points.

### Changes Made

- Replaced coder-only `fatalError()` traps with `return nil` in:
  - `Epistemos/Views/Notes/TransclusionOverlayView.swift`
  - `Epistemos/Views/Notes/BlockRefAutocomplete2.swift`
  - `Epistemos/Views/Notes/EditableTransclusionView.swift`
  - `Epistemos/Views/Graph/GraphOverlayPanel.swift`
  - `Epistemos/Views/Notes/NoteWindowManager.swift`
  - `Epistemos/Views/Notes/MarkdownLayoutFragment.swift`
  - `Epistemos/Views/Shared/MarkdownTextView.swift`
- Added `NonAgentPruningValidationTests.coderOnlyAppKitScaffoldsDoNotTrap()` to pin the behavior.

### Verification

- Focused Swift tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/NonAgentPruningValidationTests`
  - Result: PASS (`33 tests in 1 suite`, `** TEST SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-213225-3685.xcresult`

### Notes

- No UI behavior, editor schema, graph rendering, HELIOS substrate, or App Store gating changed.
- Remaining production `fatalError`/`preconditionFailure` sites require separate semantic review before any change; they were not swept mechanically.

## Slice 46 — Local Agent Reflex Unavailable-Stream Hardening

### Findings

- `LocalAgentLoop.run` already keeps reflex mode honest by using the streaming reflex path only when `streamingGenerator != nil`.
- The private `runReflexTurn` still used `preconditionFailure("runReflexTurn called without streamingGenerator")`, which made a future wiring regression a process crash instead of a typed local-agent failure.
- This is local-agent robustness only; no new tool authority, model-routing tier, HELIOS behavior, or subprocess capability is added.

### Changes Made

- `Epistemos/LocalAgent/LocalAgentLoop.swift`
  - Added `LocalAgentLoopError.streamingGeneratorUnavailable` with user-facing error text.
  - Replaced the reflex private-path precondition with `throw LocalAgentLoopError.streamingGeneratorUnavailable`.
- `EpistemosTests/LocalAgentLoopTests.swift`
  - Added a behavioral test proving `reflexMode: true` without a streaming generator still uses the one-shot generator path and emits/returns the plain answer.
- `EpistemosTests/NonAgentPruningValidationTests.swift`
  - Added a source guard so the old reflex precondition trap cannot reappear silently.

### Verification

- Focused Swift tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/LocalAgentLoopTests -only-testing:EpistemosTests/NonAgentPruningValidationTests`
  - Result: PASS (`71 tests in 2 suites`, `** TEST SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-213844-17384.xcresult`

### Notes

- This keeps the existing one-shot fallback semantics for local-agent turns where streaming is unavailable.
- Remaining invariant guards in AppBootstrap, mutation replay, and outline regex compilation are intentionally left for separate semantic review rather than broad mechanical removal.

## Slice 47 — April 21 App-Issues Verification Promotion

### Findings

- `docs/APP_ISSUES_AUTO_FIX.md` still marked three April 21 fixes as `Patched` even though their current v1 coverage exists in the focused Swift suites.
- The verified issues are narrowly scoped to cloud direct-stream tool manifest honesty, fenced `tool_call` parsing, and MLX/Metal idle working-set release.
- Older graph/semantic-neighbor issues in the same ledger remain only `Patched`; this slice did not run current graph-engine coverage and does not promote them.

### Changes Made

- `docs/APP_ISSUES_AUTO_FIX.md`
  - Promoted `ISSUE-2026-04-21-001`, `ISSUE-2026-04-21-002`, and `ISSUE-2026-04-21-003` to `Verified Fixed (2026-05-07)`.
  - Added the exact verification command, pass count, and `.xcresult` bundle under each issue.
- `docs/audits/V1_RELEASE_AUDIT_2026_05_07.md`
  - Added the same focused verification evidence to the runtime evidence section.

### Verification

- Focused Swift tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/RuntimeValidationTests -only-testing:EpistemosTests/OmegaToolCallParserTests -only-testing:EpistemosTests/Mamba2MetalRuntimeTests`
  - Result: PASS (`260 tests in 2 suites`, `** TEST SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-214239-24016.xcresult`

### Notes

- Documentation-only slice; no code or HELIOS behavior changed.
- This does not claim manual GUI runtime verification or graph-engine semantic-neighbor stress coverage.

## Slice 48 — Graph Semantic Embedding Store Race Hardening

### Findings

- The April 15 graph beach-ball fix correctly moved `graph_engine_recompute_semantic_neighbors` off the MainActor and guarded the installed semantic-neighbor result with a `Mutex`.
- A remaining release risk was that the detached Rust recompute still read `Engine.embedding_store` directly while later Swift paths could clear, reset, or batch-write the same store before the detached task finished.
- This is a pre-HELIOS v1 graph performance/stability fix. It does not add graph authority, HELIOS stages, new theory, or new user-facing substrate.

### Changes Made

- `graph-engine/src/engine.rs`
  - Changed `Engine.embedding_store` to `parking_lot::Mutex<EmbeddingStore>`.
- `graph-engine/src/lib.rs`
  - Locked embedding-store mutation and query FFI paths.
  - Changed `graph_engine_recompute_semantic_neighbors` to clone the embedding store under a short lock, then run the O(n^2) KNN cosine pass from the snapshot before swapping the semantic-neighbor result.
- `graph-engine/src/embedding.rs`
  - Made `EmbeddingStore` / `EmbeddingEntry` cloneable.
  - Added a Rust unit test proving cloned snapshots remain stable after later store mutation.
- `EpistemosTests/BlockEmbeddingTests.swift`
  - Extended the semantic recompute teardown source guard to require the mutex-backed store and snapshot-based recompute path.
- `docs/APP_ISSUES_AUTO_FIX.md`
  - Promoted `ISSUE-2026-04-06-002` to `Verified Fixed (2026-05-07)` with the current automated evidence and Metal-test caveat.

### Verification

- Rust focused test:
  - Command: `cargo test embedding::tests::cloned_snapshot_is_stable_after_store_mutation`
  - Working directory: `graph-engine`
  - Result: PASS (`1 passed; 2530 filtered out`)
- Rust compile gate:
  - Command: `cargo test --no-run`
  - Working directory: `graph-engine`
  - Result: PASS
- Rust full crate attempt:
  - Command: `cargo test`
  - Working directory: `graph-engine`
  - Result: PARTIAL (`2499 passed`, `8 ignored`, `24 failed`)
  - Caveat: all 24 failures were Metal-backed engine/renderer tests that panic when `MTLCreateSystemDefaultDevice()` returns nil in this terminal environment.
- Focused Swift/Xcode test:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/BlockEmbeddingTests`
  - Result: PASS (`22 tests in 1 suite`, `** TEST SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-215057-49800.xcresult`
- Formatting/whitespace:
  - `cargo fmt --check` in `graph-engine` passed.
  - `git diff --check` passed.

### Notes

- Manual large-vault graph interaction and Instruments beach-ball validation are still not claimed.
- The full Rust crate remains environment-blocked for Metal-dependent tests from this terminal session; rerun from a Metal-capable GUI/test context before calling the whole graph suite green.

## Slice 49 — NightBrain Live Scheduler Placeholder Honesty

### Findings

- The v1 Swift `NightBrainService` pipeline is real for its store/search/artifact/snapshot/cloud-knowledge jobs, but the separate Rust live scheduler registry still registers canonical `NoOpTask` placeholders.
- Those placeholders previously returned `complete(0)`, which made an ad-hoc live run look like completed maintenance despite doing no work.
- This is a release-honesty fix only. It does not add new NightBrain architecture, HELIOS substrate, task authority, or speculative scheduler bodies.

### Changes Made

- `agent_core/src/nightbrain/mod.rs`
  - Added `TaskOutcome::skipped(items)` for explicit no-work outcomes that should not abort the scheduler loop.
- `agent_core/src/nightbrain/live.rs`
  - Changed canonical `NoOpTask` bodies from `complete(0)` to `skipped(1)`.
  - Updated live-scheduler tests to require placeholder tasks to report skipped bodies while still letting the scheduler walk all registered names.
- `agent_core/src/bridge.rs`
  - Added a small `nightbrain_outcome_status` mapper so FFI strings distinguish `complete`, `skipped`, and `preempted`.
  - Added a unit test pinning that placeholder/skipped outcomes serialize as skipped.
- `Epistemos/State/NightBrainLiveRegistry.swift` and `Epistemos/State/NightBrainService.swift`
  - Updated wrapper comments so future UI work does not present Rust live placeholders as real completed maintenance.
- `docs/audits/V1_RELEASE_AUDIT_2026_05_07.md`
  - Split the verdict between the real Swift maintenance pipeline and the deferred Rust live scheduler.

### Verification

- Focused Rust live-scheduler tests:
  - Command: `cargo test nightbrain::live`
  - Working directory: `agent_core`
  - Result: PASS (`5 passed; 0 failed`)
- Focused Rust FFI status test:
  - Command: `cargo test nightbrain_live_ffi_reports_placeholder_tasks_as_skipped`
  - Working directory: `agent_core`
  - Result: PASS (`1 passed; 0 failed`)
- Focused Rust lib gate:
  - Command: `cargo test --lib nightbrain`
  - Working directory: `agent_core`
  - Result: PASS (`6 passed; 0 failed`)
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/nightbrain/mod.rs agent_core/src/nightbrain/live.rs` passed.
  - `git diff --check` passed.

### Notes

- Whole-crate `cargo fmt --check` in `agent_core` still fails on unrelated pre-existing formatting drift in older bridge/scope_rex files. This slice did not bulk-format those files because doing so would create noisy unrelated HELIOS/research churn.
- The Rust live scheduler remains a registered diagnostic surface, not a v1 maintenance engine, until real task bodies replace the placeholders.

## Slice 50 — NightBrain Trigger Tool Contract Honesty

### Findings

- The Pro-only Rust `nightbrain_trigger` tool was exposing an implemented-looking `vault_integrity_check` job even though `Phase7Bridge` explicitly rejects that alias as unavailable in `NightBrainService`.
- The same tool advertised `priority: normal` as the default and described it as App Nap respecting scheduling, but the bridge call is an immediate single-job path through the app host. Normal/background scheduling is owned by the host NightBrain idle scheduler, not by the agent tool.
- This was a tool-contract honesty issue: no new NightBrain authority, scheduler theory, HELIOS substrate, or speculative job body was needed.

### Changes Made

- `agent_core/src/tools/intelligence.rs`
  - Removed `vault_integrity_check` from the allowed job enum and schema.
  - Changed the default trigger priority from `normal` to `immediate`.
  - Rejected non-immediate priorities with an explicit error that normal scheduling belongs to the host idle scheduler.
  - Updated the schema description so the Pro tool only promises implemented immediate dispatch.
- `agent_core/src/bridge.rs`
  - Updated the `AgentEventDelegate` NightBrain callback contract comment so future FFI callers do not re-advertise `vault_integrity_check` or public `normal` priority dispatch.
- `Epistemos/Bridge/Phase7Bridge.swift`
  - Added explicit `immediate` priority-class normalization so provenance records the intended class rather than falling through to `unknown`.
- `EpistemosTests/Phase7BridgeAgentEventTests.swift`
  - Added coverage that an immediate NightBrain trigger records immediate priority in agent provenance.
- `docs/audits/V1_RELEASE_AUDIT_2026_05_07.md`
  - Added a separate NightBrain trigger verdict and verification evidence.

### Verification

- Focused Rust Pro tool tests:
  - Command: `cargo test --lib --features pro-build nightbrain_trigger`
  - Working directory: `agent_core`
  - Result: PASS (`4 passed; 0 failed`)
- Focused Swift bridge tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/Phase7BridgeAgentEventTests`
  - Result: PASS (`5 tests in 1 suite`, `** TEST SUCCEEDED **`)
  - Result bundle: `/Users/jojo/Downloads/Epistemos/build/xcode-results/2026-05-07-220542-92257.xcresult`
- Whitespace:
  - `git diff --check` passed.

### Notes

- `Phase7Bridge` still keeps its bounded unsupported-job path for direct callers and provenance redaction tests; the public Pro tool no longer advertises the unsupported job.
- The focused Swift test logs still show a missing `SearchIndexService` line when the test bootstrap is absent. That is the existing typed failure path for the search checkpoint job and was not claimed as a successful maintenance run.

## Slice 51 — Self-Evolve Advisory Trace Hardening

### Findings

- The Pro-only `self_evolve` tool was already advisory and read-only, but the analyzer read each `sessions/*/trace.json` file with `read_to_string` before parsing. A single huge trace could turn a diagnostic tool into unnecessary memory pressure.
- Missing, unreadable, or malformed traces were silently ignored, which made the analysis less honest than the rest of the v1 diagnostics surface.
- Mutation proposal skill names were derived directly from raw trace tool names. The tool does not write skills, but advisory names should still be safe slugs before they are handed to any follow-up workflow.

### Changes Made

- `agent_core/src/tools/intelligence.rs`
  - Added a 2 MiB per-trace read cap for `self_evolve` analysis.
  - Added `sessions_skipped` and bounded `skipped_traces` diagnostics with explicit reasons such as `trace_too_large`, `read_failed`, and `invalid_json`.
  - Sanitized advisory `*-optimizer` skill names from trace tool names before emitting proposals.
  - Added unit coverage for oversized trace skips and sanitized advisory skill names.
- `docs/audits/V1_RELEASE_AUDIT_2026_05_07.md`
  - Updated the self-evolution verdict to keep the feature v1-safe as advisory analysis only.

### Verification

- Focused Rust Pro tool tests:
  - Command: `cargo test --lib --features pro-build self_evolve`
  - Working directory: `agent_core`
  - Result: PASS (`6 passed; 0 failed`)
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/intelligence.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not add autonomous promotion, generated tool registration, skill writes, HELIOS self-modification authority, or a new mutation protocol.
- Existing proposal output remains advisory; applying a proposal still requires a separate explicit skill-management path.

## Slice 52 — Mixture of Minds Cloud Fan-Out Honesty

### Findings

- `mixture_of_minds` is a Pro-only external-provider ensemble tool, but before this slice a minimal call with only `problem` would default to Claude, OpenAI, and Gemini. That made external network fan-out too implicit for a release-quality v1 tool surface.
- Unknown model names were accepted into the request set and returned as per-model contribution errors, even though the schema advertised a closed enum. That mismatch made the contract looser than the model-facing catalog.
- Gemini uses an API key in the request URL; echoing raw `reqwest` transport errors risked returning a URL with query-string credentials if the transport layer included the failed URL in its display text.

### Changes Made

- `agent_core/src/tools/intelligence.rs`
  - Added required `allow_cloud_external_requests: true` input before any provider request can be launched.
  - Added a shared allowed-model list and rejects unknown model names before network work.
  - Removed hidden `gpt` / `gpt-4o` aliases from execution so runtime behavior matches the schema.
  - Added `cloud_requests_authorized` to successful tool output.
  - Replaced raw provider transport/parse error echoes with bounded provider failure messages.
  - Added unit coverage for explicit consent, schema-required consent, unknown model rejection, and missing-key behavior.
- `docs/audits/V1_RELEASE_AUDIT_2026_05_07.md`
  - Added a separate v1 verdict for the Pro cloud ensemble surface.

### Verification

- Focused Rust Pro tool tests:
  - Command: `cargo test --lib --features pro-build mom`
  - Working directory: `agent_core`
  - Result: PASS (`7 passed; 0 failed`)
- Broader intelligence module regression:
  - Command: `cargo test --lib --features pro-build tools::intelligence::tests`
  - Working directory: `agent_core`
  - Result: PASS (`19 passed; 0 failed`)
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/intelligence.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not add a new local ensemble engine, HELIOS reasoning substrate, provider abstraction, or streaming multi-agent architecture.
- The tool still requires matching provider API keys at runtime; missing keys are reported as per-model failures and no successful answer is fabricated.

## Slice 53 — Specialty Documentation Contract Alignment

### Findings

- Active specialty documentation still described `nightbrain_trigger` as eleven jobs with `vault_integrity_check` and `priority: normal|immediate`, even after the public Pro schema had been narrowed to implemented immediate jobs.
- The same documentation described `self_evolve` as validating/applying mutations and writing skill versions. The v1 tool is advisory trace analysis only.
- `mixture_of_minds` was documented as a local+cloud ensemble with a local-model aggregator, while the v1 implementation is explicit external cloud fan-out only.

### Changes Made

- `docs/EPISTEMOS_SPECIALTIES.md` and `docs/_consolidated/20_canonical_research/EPISTEMOS_SPECIALTIES.md`
  - Updated NightBrain D1 to ten implemented public jobs and immediate-only public dispatch.
  - Updated self-evolve D3 to advisory `analyze`/`propose` behavior with no writes or apply path.
  - Updated mixture-of-minds D4 to explicit Pro cloud fan-out requiring `allow_cloud_external_requests=true`.
- `docs/CODEX_HANDOFF_2026_04_10.md` and `docs/_consolidated/30_canonical_operational/CODEX_HANDOFF_2026_04_10.md`
  - Replaced the stale NightBrain alias list and added the explicit `vault_integrity_check` non-implementation note.
- `docs/TOOL_TIER_AND_IMESSAGE_INTEGRATION.md` and `docs/_consolidated/60_deferred_research/TOOL_TIER_AND_IMESSAGE_INTEGRATION.md`
  - Updated the `mixture_of_minds` tier note to describe explicit Pro cloud fan-out and required provider keys.

### Verification

- Stale-contract search:
  - Command: `rg -n "vault_integrity_check|parallel frontier models|Local \\+ Cloud Ensemble|write new skill versions|enum\\(normal\\|immediate\\)|local_model.*defaults|cloud_models" docs agent_core/src Epistemos EpistemosTests -g '*.md' -g '*.rs' -g '*.swift'`
  - Result: only deliberate unsupported-job guards/tests, audit explanations, explicit non-implementation notes, and older research sketches remain.
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Whitespace:
  - `git diff --check` passed.

### Notes

- This was documentation hardening only. It did not alter research sketches under `docs/fusion/jordan's research/...`, which remain source material rather than v1 runtime claims.

## Slice 54 — Pro Tool Registry Contract Coverage

### Findings

- The Pro registry tier tests checked that ChatPro adds vision and text-to-speech, but they did not pin the newly hardened `mixture_of_minds` schema at the model-facing catalog boundary.
- An initial assertion that ChatPro should always expose `self_evolve` failed. That failure was useful: `self_evolve` only registers when a vault root exists because it scans vault-local session traces.
- The correct release contract is therefore:
  - `mixture_of_minds` is visible in ChatPro and requires explicit cloud external-request consent.
  - `self_evolve` is visible in ChatPro only when a vault root is configured.

### Changes Made

- `agent_core/src/tools/registry.rs`
  - Extended `chat_pro_adds_vision_and_tts_over_chat_lite` to assert that the ChatPro catalog exposes `mixture_of_minds` with `["problem", "allow_cloud_external_requests"]` required.
  - Added a root-configured ChatPro registry assertion for `self_evolve` instead of pretending it exists without a vault root.

### Verification

- Focused registry test:
  - Command: `cargo test --lib --features pro-build chat_pro_adds_vision_and_tts_over_chat_lite`
  - Working directory: `agent_core`
  - Result: PASS after correcting the vault-root expectation (`1 passed; 0 failed`)
- Broader registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`30 passed; 0 failed`)
- Whitespace:
  - `git diff --check` passed.
  - `rustfmt --edition 2024 --check agent_core/src/tools/registry.rs` remains blocked by unrelated pre-existing formatting drift across the file, so this slice did not bulk-format registry imports or unrelated lines.

### Notes

- This is catalog/test hardening only. It does not move tools between build products or add new authority.

## Slice 55 — CLI Passthrough Executable and Working Directory Hardening

### Findings

- The Pro-only CLI passthrough handlers already run through the hardened subprocess helper (`env_clear`, allowlisted environment, `kill_on_drop`, process group isolation), but binary resolution accepted any regular file in PATH or known install locations.
- The tool schemas describe `working_dir` as an absolute path, but the handler accepted any string and passed it to `current_dir`, making relative or missing paths fail late at spawn time.
- The module header still said "extra env can be set per-invocation" even though the hardened path intentionally does not expose arbitrary environment passthrough.

### Changes Made

- `agent_core/src/tools/cli_passthrough.rs`
  - Added executable-file validation for PATH and known-location binary resolution.
  - Added absolute existing-directory validation for optional `working_dir`.
  - Updated all four handlers (`claude_code`, `codex`, `gemini`, `kimi`) to reject invalid `working_dir` before spawn.
  - Corrected the module docs to say only an absolute existing working directory can be set.
  - Added unit coverage for non-executable candidates, executable candidates, and working-directory validation.

### Verification

- Focused Rust Pro CLI tests:
  - Command: `cargo test --lib --features pro-build cli_passthrough`
  - Working directory: `agent_core`
  - Result: PASS (`8 passed; 0 failed`)
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/cli_passthrough.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not add new CLI providers, subprocess authority, shell execution in MAS/Core, or environment passthrough.
- The previous live smoke remains the runtime evidence for installed CLIs: Claude, Codex, and Kimi were installed and returned the sentinel; Gemini was absent.

## Slice 56 — MCP Stdio Environment Denylist Hardening

### Findings

- `McpClient::connect` correctly hardened stdio MCP subprocesses by clearing inherited environment and applying the canonical subprocess allowlist first.
- It then re-applied every key from user-supplied `config.env`. That is necessary for explicit MCP server credentials, but it also allowed dynamic-loader and interpreter-option hijack variables such as `DYLD_INSERT_LIBRARIES`, `NODE_OPTIONS`, and `PYTHONPATH` to re-enter the child environment.

### Changes Made

- `agent_core/src/mcp/client.rs`
  - Added `mcp_config_env_key_allowed`.
  - Rejects empty keys, keys containing `=`, NUL-bearing keys, and every key in `security::SUBPROCESS_DENYLIST`, case-insensitively.
  - Keeps explicit server credentials allowed, including `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, and `PATH`, so MCP servers can still be configured intentionally.
  - Added unit coverage for blocked loader/interpreter keys and allowed explicit credential keys.

### Verification

- Focused Rust MCP tests:
  - Command: `cargo test --lib mcp_config_env_filter`
  - Working directory: `agent_core`
  - Result: PASS (`2 passed; 0 failed`)
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/mcp/client.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not add new MCP transports, server discovery, browser control, or HELIOS runtime authority.
- Stdio MCP remains a Pro/direct-distribution subprocess surface; MAS/Core must continue to treat it as forbidden or unavailable.

## Slice 57 — Terminal Process Subprocess Denylist Hardening

### Findings

- The Pro terminal/process tool had its own environment scrubber that stripped secret-looking variables (`KEY`, `TOKEN`, `SECRET`, etc.), but it did not reuse the shared subprocess denylist.
- That left dynamic-loader and interpreter-option variables such as `DYLD_INSERT_LIBRARIES`, `NODE_OPTIONS`, and `PYTHONPATH` eligible to survive into `sh -lc` child processes if the parent process had them.
- The command builder also did not explicitly set `kill_on_drop` / Unix process group isolation, unlike the shared CLI hardening helper.

### Changes Made

- `agent_core/src/tools/terminal.rs`
  - Extended `should_strip_env` to reject every key in `security::SUBPROCESS_DENYLIST`, case-insensitively.
  - Added `kill_on_drop(true)` and Unix `process_group(0)` to the terminal command builder.
  - Extended env sanitizer coverage for `DYLD_INSERT_LIBRARIES`, `NODE_OPTIONS`, and `PYTHONPATH`.

### Verification

- Focused env sanitizer test:
  - Command: `cargo test --lib --features pro-build env_sanitizer_strips_secrets`
  - Working directory: `agent_core`
  - Result: PASS (`1 passed; 0 failed`)
- Full terminal module tests:
  - Command: `cargo test --lib --features pro-build tools::terminal::tests`
  - Working directory: `agent_core`
  - Result: PASS (`7 passed; 0 failed`)
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/terminal.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not add terminal capability to MAS/Core or expand the command surface. It only tightens the existing Pro subprocess path.

## Slice 58 — Tirith Runtime Executable Download Removal

### Findings

- `agent_core/src/tirith.rs` still contained a runtime GitHub release download path for the Tirith scanner binary.
- The module header claimed "SHA-256 + cosign provenance verification", but the implementation downloaded bytes and marked them executable without verification.
- That violates the v1 release-hardening rule against runtime executable-code downloads and fake diagnostics.

### Changes Made

- `agent_core/src/tirith.rs`
  - Removed the runtime Tirith download path and the GitHub release constants.
  - Updated the module contract to installed/cached binary detection only.
  - Requires cached `tirith` to be an executable file before using it.
  - Makes `is_available` reject a cached non-executable path.
  - Added a source guard rejecting reintroduction of `download_tirith`, GitHub `releases/download`, and `reqwest::Client::new` in the Tirith module.

### Verification

- Focused Rust Pro Tirith tests:
  - Command: `cargo test --lib --features pro-build tirith`
  - Working directory: `agent_core`
  - Result: PASS (`12 passed; 0 failed`)
- Runtime-download string search:
  - Command: `rg -n "download_tirith|releases/download|reqwest::Client::new|Auto-download|SHA-256 \\+ cosign" agent_core/src/tirith.rs docs/CODEX_FULL_HANDOFF_2026_05_05.md docs/MAS_PRO_SOURCE_GUARD_2026_05_05.md docs/audits/V1_RELEASE_AUDIT_2026_05_07.md docs/audits/PRE_HELIOS_FEATURE_AUDIT_2026_05_06.md`
  - Result: no active matches.
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tirith.rs` passed.
  - `git diff --check` passed.

### Notes

- This preserves the optional Pro scanner path when Tirith is installed or already cached. It does not auto-install, auto-download, add new scanner theory, or change MAS/Core availability.

## Slice 59 — Media Cloud Tool Consent and Diagnostic Honesty

### Findings

- `vision_analyze` is a Pro-only cloud tool that sends either an image URL or base64-encoded local image bytes plus a question to Claude or OpenAI.
- Before this slice, `vision_analyze` defaulted to Claude and could proceed without an explicit per-call cloud-consent field.
- `vision_analyze` also accepted both `image_url` and `image_path`, silently preferring the local file path.
- Cloud error paths for vision and FAL image generation echoed provider transport details and HTTP response bodies into the tool error string.

### Changes Made

- `agent_core/src/tools/media.rs`
  - Added required `allow_cloud_external_requests=true` before `vision_analyze` reads a local file or dispatches any provider request.
  - Rejects ambiguous calls that provide both `image_url` and `image_path`.
  - Validates the provider before cloud dispatch and preserves the existing Claude/OpenAI/GPT-4V provider set.
  - Adds `cloud_requests_authorized: true` to successful cloud vision envelopes.
  - Requires `allow_cloud_external_requests=true` for `image_generate` when `provider="fal"`; the MLX sidecar lane remains local/delegate-backed and does not require this flag.
  - Redacts provider transport/parse/HTTP body detail from Claude/OpenAI vision and FAL errors.
  - Adds coverage for consent-before-file-read, ambiguous image sources, schema-required cloud consent, non-leaky error strings, and FAL consent-before-api-key behavior.
- `agent_core/src/tools/registry.rs`
  - Extended the ChatPro catalog contract test so `vision_analyze` must expose `["allow_cloud_external_requests"]` as required.
- Tool-tier docs now describe `vision_analyze` as explicit Pro cloud vision requiring both user consent and provider API keys.

### Verification

- Focused Rust Pro media tests:
  - Command: `cargo test --lib --features pro-build media`
  - Working directory: `agent_core`
  - Result: PASS (`19 passed; 0 failed`)
- Focused ChatPro registry contract:
  - Command: `cargo test --lib --features pro-build chat_pro_adds_vision_and_tts_over_chat_lite`
  - Working directory: `agent_core`
  - Result: PASS (`1 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/media.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not add a local VLM, Gemini vision route, image-generation substrate, or HELIOS multimodal theory.
- `image_generate provider="mlx"` remains an honest delegate-backed lane that errors when the Swift MLX sidecar is unavailable. The FAL lane now needs both explicit provider selection and explicit cloud-request consent.

## Slice 60 — Text-to-Speech Playback and File-Write Honesty

### Findings

- `text_to_speech` is a Pro-only macOS `say` subprocess tool, not a cloud feature.
- Before this slice, omitting `output_path` played audio immediately with no explicit playback consent.
- Providing `output_path` wrote a file, but the registry classified the whole tool as `ReadOnly` and the resource authorization helper had no output-file target for it.
- `rate` and `voice` inputs were weakly typed: invalid rates could be silently ignored before spawning `say`.

### Changes Made

- `agent_core/src/tools/media.rs`
  - Requires `allow_audio_playback=true` when `output_path` is omitted.
  - Validates `rate` as an integer from 80 to 450 words per minute.
  - Validates `voice` as a non-empty, bounded, control-character-free string.
  - Requires `output_path` to be absolute or `~/`-expanded and to have an existing parent directory before spawning `say`.
  - Returns resolved `output_path`, `played_audio`, and `allow_audio_playback` in the success envelope.
  - Documents playback consent and output-file behavior in the tool schema.
- `agent_core/src/tools/registry.rs`
  - Classifies `text_to_speech` as `RiskLevel::Modification` while keeping it in the ChatPro tier.
  - Extends the ChatPro catalog test to assert the mutating risk label.
- `agent_core/src/resources/tool_authz.rs`
  - Adds `text_to_speech.output_path` to R.5 file-write target inference.
  - Keeps no-output playback calls resource-target-free because there is no stable file resource to authorize.
- Tool-tier docs now say TTS playback is explicit and `output_path` is a file write.

### Verification

- Focused Rust Pro TTS tests:
  - Command: `cargo test --lib --features pro-build text_to_speech`
  - Working directory: `agent_core`
  - Result: PASS (`9 passed; 0 failed`)
- Focused ChatPro registry contract:
  - Command: `cargo test --lib --features pro-build chat_pro_adds_vision_and_tts_over_chat_lite`
  - Working directory: `agent_core`
  - Result: PASS (`1 passed; 0 failed`)
- Non-resourceable mutating-tools guard:
  - Command: `cargo test --lib --features pro-build non_resourceable_mutating_tools_return_none`
  - Working directory: `agent_core`
  - Result: PASS (`1 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/media.rs agent_core/src/resources/tool_authz.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not add TTS to MAS/Core; `text_to_speech` remains forbidden in non-Pro builds by the existing MAS runtime-forbidden list.
- This does not add new audio synthesis backends or HELIOS audio theory.

## Slice 61 — Send Message Webhook and Provider Error Honesty

### Findings

- `send_message` is already Agent-tier/destructive and excluded from ChatLite/ChatPro, but its provider error paths echoed raw HTTP response bodies or request errors.
- Webhook-style platforms (`slack`, `discord`, and generic `webhook`) accepted explicit `webhook_url` overrides without a per-call acknowledgement that the message would be sent to an arbitrary endpoint.
- `validate_outbound_url` and `SIGNAL_CLI_BASE_URL` validation included the rejected URL in errors, which could reveal webhook tokens or local endpoint details.
- Communication tests mutated process-wide environment variables without taking the shared test env lock.

### Changes Made

- `agent_core/src/tools/communication.rs`
  - Added `allow_custom_webhook_url`; explicit `webhook_url` is now rejected unless that flag is true.
  - Keeps configured Slack/Discord env webhooks working without the custom-url flag.
  - Redacts provider request errors and HTTP failure bodies for Slack, Telegram, Discord, generic webhook, Matrix, WhatsApp, and Signal.
  - Redacts URL validation failures for public webhook URLs and Signal base URLs.
  - Adds schema documentation for custom webhook consent.
  - Adds tests for webhook consent, Slack override consent-before-network, redacted URL validation, redacted request/HTTP errors, schema coverage, and existing env failures.
  - Adds the shared env lock to communication tests that mutate provider environment variables.
- Tool-tier docs now state that `send_message` is Agent-tier/destructive and custom webhook URLs require explicit consent.

### Verification

- Focused Rust Pro communication tests:
  - Command: `cargo test --lib --features pro-build tools::communication::tests`
  - Working directory: `agent_core`
  - Result: PASS (`18 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/communication.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not add new message providers, relax destructive permissions, or add communication to MAS/Core.
- Generic webhook remains available only as an explicit Agent/destructive path with SSRF protection and `allow_custom_webhook_url=true`.

## Slice 62 — Web Tool URL and Response-Budget Hardening

### Findings

- `web_search`, `web_extract`, `web_fetch`, and `web_crawl` are v1-visible tools.
- The shared URL guard was string-prefix based. It caught common private IPv4/localhost forms, but did not parse URLs structurally, reject embedded credentials, or handle IPv6 local/private literals robustly.
- `web_extract` and `web_crawl` read full response bodies without the response-byte cap used by `web_fetch`.
- `web_crawl` validated the seed URL but later only checked discovered links with the older private-URL substring helper.
- Search/request errors could echo raw `reqwest` error strings that may include URL query text.

### Changes Made

- `agent_core/src/tools/web_fetch.rs`
  - Replaced prefix-only private URL detection with parsed host checks for literal IPv4, literal IPv6, localhost domains, and metadata hostnames.
  - Rejects leading/trailing whitespace, malformed URLs, missing hosts, and embedded URL credentials.
  - Added shared `read_response_text_limited` for bounded body reads.
  - Switched `WebFetchTool` to the shared limited reader and redacted request/body errors.
  - Added tests for IPv6/private URL rejection, embedded-credential rejection, whitespace rejection, and private-host detection.
- `agent_core/src/tools/web.rs`
  - Uses the shared bounded body reader for `web_extract` and `web_crawl`.
  - Uses full shared URL validation for discovered crawl links.
  - Redacts Tavily/Brave/Perplexity request and parse errors instead of echoing raw provider error strings.
  - Added coverage for redacted web request errors.
- Tool-tier docs now state the web tools use shared SSRF/private-address guards and bounded response reads.

### Verification

- Focused Rust Pro web tests:
  - Command: `cargo test --lib --features pro-build web`
  - Working directory: `agent_core`
  - Result: PASS (`27 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/web.rs agent_core/src/tools/web_fetch.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not add browser automation, remote browser control, or new search providers.
- DNS rebinding remains out of scope for this local HTTP helper; this slice hardens literal URL parsing, redirect validation, and response budgeting without changing the existing fetch/search/crawl product surface.

## Slice 63 — Skill Marketplace Remote Install and Promotion Hardening

### Findings

- `skills_list`, `skill_view`, and `skill_manage` are v1-visible as procedural-memory scaffolding; remote skill installs were reachable through Pro/Agent tool paths.
- `install_from_github` and `install_from_url` could fetch remote skill content without a per-call acknowledgement that new prompt instructions were being imported into the managed skill directory.
- GitHub clone URL validation rejected host spoofs but did not structurally reject embedded credentials before the shared URL guard, which could make token-bearing URLs appear in validation errors.
- `promote_quarantined` trusted the earlier quarantine scan and allowed arbitrary quarantine-path strings instead of proving the promotion source was still inside the managed quarantine root and still clean at approval time.
- `install_from_url` used an unbounded response body read before the existing size cap checked the final string length.

### Changes Made

- `agent_core/src/tools/skills.rs`
  - Added `allow_remote_skill_install`; `install_from_github` and `install_from_url` now require it before any new remote fetch/clone into quarantine.
  - Preserved the existing two-step approval flow: if content is already quarantined, `approve=true` can promote it without re-fetching.
  - Reworked GitHub clone URL parsing to reject whitespace, non-HTTPS URLs, embedded credentials, query strings, fragments, and GitHub host spoofs before spawning `git`.
  - Redacted clone/fetch transport failures so token-bearing URLs are not echoed back into tool output.
  - Switched URL skill imports to the shared bounded response reader.
  - Hardened promotion to reject paths outside the managed quarantine directory, require `SKILL.md`, and re-run the quarantine scanner immediately before copying into the active skills directory.
  - Added tests for remote-consent gating, credential redaction, bounded URL import, promotion re-scan, and quarantine-root enforcement.
- Tool-tier docs now state that remote skill installs require explicit consent and quarantine re-scan at approval time.

### Verification

- Focused Rust Pro skills tests:
  - Command: `cargo test --lib --features pro-build skills`
  - Working directory: `agent_core`
  - Result: PASS (`20 passed; 0 failed`)
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/skills.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not make generated tool runtime registration available in v1 and does not add autonomous skill promotion.
- Remote community skills remain imported as quarantined prompt content only; promotion still requires explicit approval and a clean scanner result.

## Slice 64 — Discovery Tool Consent and Risk Honesty

### Findings

- `model_catalog` is visible in the ChatLite tool set, but its default source was `openrouter`, which made a live external request when the caller omitted `source`.
- `model_catalog` read the OpenRouter JSON response through `reqwest::Response::json()` without the shared response-budget helper used by web fetch/extract/crawl.
- `model_catalog` request/init errors echoed raw transport errors.
- `mcp_discover` was registered as `RiskLevel::ReadOnly`, but `create_missing=true` could create MCP config directories on disk.
- Discovery tests mutated `HOME` and `XDG_CONFIG_HOME` without the shared env lock.

### Changes Made

- `agent_core/src/tools/discovery.rs`
  - Changed `model_catalog` default source to `local`; OpenRouter now requires `allow_cloud_external_requests=true`.
  - Added the shared redirect guard and bounded response reader for OpenRouter catalog fetches.
  - Clamps `limit` to the schema range and redacts request/init/parse failures.
  - Added `allow_create_missing_dirs`; `mcp_discover create_missing=true` now fails before filesystem mutation unless the caller sets the acknowledgement flag.
  - Added env-lock protection around discovery tests that mutate process environment.
  - Added coverage for local default behavior, OpenRouter consent-before-network, schema documentation, create-missing acknowledgement, and limit clamping.
- `agent_core/src/tools/registry.rs`
  - Changed `mcp_discover` risk from `ReadOnly` to `Modification` because it can create missing directories when explicitly acknowledged.
  - Added catalog/risk assertions to the ChatPro registry contract.
- Tool-tier docs now state that `model_catalog` is local by default and that `mcp_discover` directory creation is an explicit modification path.

### Verification

- Focused Rust Pro discovery tests:
  - Command: `cargo test --lib --features pro-build discovery`
  - Working directory: `agent_core`
  - Result: PASS (`8 passed; 0 failed`)
- Focused Rust Pro registry contract:
  - Command: `cargo test --lib --features pro-build chat_pro_adds_vision_and_tts_over_chat_lite`
  - Working directory: `agent_core`
  - Result: PASS (`1 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`30 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting:
  - `rustfmt --edition 2024 --check agent_core/src/tools/discovery.rs agent_core/src/tools/registry.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not add any new model provider, MCP transport, MCP execution, or HELIOS runtime surface.
- OpenRouter catalog lookup remains available as explicit external discovery; default ChatLite model discovery is now local/offline.

## Slice 65 — MCP Discovery Secret Redaction

### Findings

- `mcp_discover` returns model-facing JSON for MCP server configs.
- MCP configs commonly contain provider credentials in `env`, `headers`, and command `args` such as `--key SECRET`, `--token=SECRET`, or `OPENAI_API_KEY=SECRET`.
- The previous response included raw config payloads, which could leak local API keys into agent context, logs, or UI diagnostics.

### Changes Made

- `agent_core/src/tools/discovery.rs`
  - Added recursive MCP config redaction before any discovered config is returned.
  - Redacts sensitive object keys including API keys, tokens, passwords, secrets, authorization headers, bearer credentials, private keys, and credential fields.
  - Redacts command-arg secret forms including `--token=value`, `--password value`, and `KEY=value` assignment strings.
  - Adds `redacted_secrets` per discovered server entry so Settings/diagnostics can show that sensitive material was hidden.
  - Added tests proving discovered OpenClaw-style configs preserve non-secret command metadata while redacting env/header/arg secrets.

### Verification

- Focused Rust Pro discovery tests:
  - Command: `cargo test --lib --features pro-build discovery`
  - Working directory: `agent_core`
  - Result: PASS (`9 passed; 0 failed`)
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/discovery.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not add MCP execution, remote MCP transports, or new Settings UI.
- Users can still inspect raw local MCP config files themselves; the model-facing discovery tool now returns a safe diagnostic view.

## Slice 66 — Shell-Backed Custom Tool Tier Honesty

### Findings

- `tool_manage` can create user-defined JSON tool specs that become callable runtime tools.
- Custom tools are shell-backed: `command_template` is interpolated and run through the terminal handler.
- Specs could declare `risk_level: "read_only"` and `tier: "chat_lite"`, which made subprocess execution appear in normal chat as a safe read-only tool.

### Changes Made

- `agent_core/src/tools/custom_tools.rs`
  - `CustomToolSpec::validate()` now rejects shell-backed tools below Agent tier.
  - `CustomToolSpec::validate()` now rejects `risk_level: "read_only"`; custom shell tools must be `modification` or `destructive`.
  - Updated the `tool_manage` schema description to state the Agent/Full tier contract.
  - Added tests for rejecting read-only shell tools and ChatLite shell tools.
- `agent_core/src/tools/registry.rs`
  - Updated the custom runtime-tool registry test to use the honest `agent`/`modification` contract.

### Verification

- Focused Rust Pro custom tool tests:
  - Command: `cargo test --lib --features pro-build custom_tools`
  - Working directory: `agent_core`
  - Result: PASS (`5 passed; 0 failed`)
- Focused Rust Pro registry runtime-tool test:
  - Command: `cargo test --lib --features pro-build custom_tool_specs_become_runtime_tools`
  - Working directory: `agent_core`
  - Result: PASS (`1 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`30 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting:
  - `rustfmt --edition 2024 --check agent_core/src/tools/custom_tools.rs agent_core/src/tools/registry.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not remove custom tools or their scaffold.
- Existing unsafe custom specs are skipped by validation until updated to Agent/Full and modification/destructive risk.

## Slice 67 — Terminal Workdir Pre-Spawn Validation

### Findings

- The Pro terminal/process tool is the subprocess primitive used directly by Agent-tier terminal calls and indirectly by shell-backed custom tools.
- `workdir` was passed through to `Command::current_dir` without pre-validation.
- Relative, empty, or nonexistent working directories could therefore reach spawn-time behavior instead of a clear tool-contract rejection.

### Changes Made

- `agent_core/src/tools/terminal.rs`
  - Added `parse_workdir()` for terminal invocations.
  - Requires `workdir` to be non-empty, absolute, and an existing directory before any foreground or background process is spawned.
  - Changed command construction to pass a validated `Path`.
  - Updated terminal schema text to say `workdir` must be an absolute existing directory.
  - Added tests for accepting absolute existing workdirs and rejecting relative/missing workdirs before spawn.

### Verification

- Full terminal module tests:
  - Command: `cargo test --lib --features pro-build terminal`
  - Working directory: `agent_core`
  - Result: PASS (`11 passed; 0 failed`)
- Custom tool regression:
  - Command: `cargo test --lib --features pro-build custom_tools`
  - Working directory: `agent_core`
  - Result: PASS (`5 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`30 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting:
  - `rustfmt --edition 2024 --check agent_core/src/tools/terminal.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not add terminal access to MAS/Core or broaden shell capabilities.
- Existing callers that used relative `workdir` must resolve it to an absolute directory before invoking the terminal tool.

## Slice 68 — Contact Route Tool-Tier Cap

### Findings

- The iMessage/channel route doctrine says auto-reply contact routes should cap at Agent tier, not Full.
- `imessage_contacts` and `channel_contacts` both accepted and advertised `tool_tier: "full"` in their schemas.
- A saved Full contact route could make a future driver path appear more privileged than the documented v1 safety model allows.

### Changes Made

- `agent_core/src/tools/imessage_contacts.rs`
  - Added route-tier parsing that accepts only `none`, `chat_lite`, `chat_pro`, and `agent`.
  - Rejects `full` with a clear "not allowed" error.
  - Removed `full` from the schema enum.
  - Added tests for rejecting Full and for schema capping at Agent.
- `agent_core/src/tools/channel_contacts.rs`
  - Applied the same Agent-tier cap for shared relay contact routes.
  - Removed `full` from the schema enum.
  - Added tests for rejecting Full and for schema capping at Agent.

### Verification

- Focused Rust Pro iMessage contacts tests:
  - Command: `cargo test --lib --features pro-build imessage_contacts`
  - Working directory: `agent_core`
  - Result: PASS (`10 passed; 0 failed`)
- Focused Rust Pro channel contacts tests:
  - Command: `cargo test --lib --features pro-build channel_contacts`
  - Working directory: `agent_core`
  - Result: PASS (`4 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`30 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting:
  - `rustfmt --edition 2024 --check agent_core/src/tools/imessage_contacts.rs agent_core/src/tools/channel_contacts.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not implement the Swift iMessage driver or claim live Messages automation was manually verified.
- Existing routes saved with `full` should be downgraded to `agent` before use.

## Slice 69 — AppleScript Tool Output and Error Budgeting

### Findings

- Apple app tools (`apple_notes`, `apple_reminders`, `apple_calendar`, `apple_mail`) are Agent-tier macOS automation surfaces backed by `osascript`.
- The shared AppleScript runner returned raw stderr on non-zero exit, which could echo user data or generated script fragments into model-facing tool errors.
- Successful AppleScript stdout was not bounded before being placed into tool JSON, so large Notes/Mail/Calendar outputs could exceed the intended context budget.

### Changes Made

- `agent_core/src/tools/apple.rs`
  - Added a 512 KiB post-read output cap for AppleScript stdout/stderr conversion.
  - Appends an explicit truncation marker when output is capped.
  - Replaced raw stderr echoing with classified, redacted failure messages for permission errors, missing/unavailable target items, empty stderr, and generic app errors.
  - Added tests for output bounding, stderr redaction, and permission-error classification.

### Verification

- Focused Rust Pro Apple tool tests:
  - Command: `cargo test --lib --features pro-build apple`
  - Working directory: `agent_core`
  - Result: PASS (`12 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`30 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/apple.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not add AppleScript automation to MAS/Core or claim live GUI permission success.
- Manual verification is still required on a machine/session with Automation permissions granted for Notes/Reminders/Calendar/Mail.

## Slice 70 — Browser Vision Cloud Consent Before Screenshot

### Findings

- `browser_vision` captures a browser screenshot and then forwards that image to `vision_analyze`.
- After the media consent hardening, `vision_analyze` requires `allow_cloud_external_requests=true`, but `browser_vision` did not expose or forward that acknowledgement.
- The old flow could create a screenshot before the caller had acknowledged the external vision request.

### Changes Made

- `agent_core/src/tools/browser.rs`
  - `browser_vision` now requires `allow_cloud_external_requests=true` before taking a screenshot.
  - The acknowledgement is forwarded to `vision_analyze`.
  - The schema now documents and requires `allow_cloud_external_requests`.
  - Updated tests to prove the browser CLI is not asked to take a screenshot before cloud acknowledgement.

### Verification

- Focused Rust Pro browser tests:
  - Command: `cargo test --lib --features pro-build browser`
  - Working directory: `agent_core`
  - Result: PASS (`7 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`30 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/browser.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not make browser automation available in MAS/Core and does not claim a live browser permission smoke.
- `agent-browser` is still absent in this environment; runtime browser verification remains manual/deferred.

## Slice 71 — Filesystem Sensitive Symlink Target Blocking

### Findings

- The file tools had lexical blocklists for credential directories and sensitive filenames such as `.env`.
- A safe-looking path could still be a symlink to a blocked filename; `read_file` would read the target and `write_file`/`patch` could read the target for diff/patch preparation before replacing the symlink.
- Search already avoids following links, but direct file operations needed canonical checks for existing targets.

### Changes Made

- `agent_core/src/tools/filesystem.rs`
  - Added canonical target checks for existing read targets.
  - Added canonical target and existing-parent checks for write/patch targets.
  - Tightened protected-prefix matching for exact protected directory paths.
  - `read_file`, `write_file`, `patch`, and search-root validation now use the stronger target guards where applicable.
  - Added Unix symlink tests proving safe-looking links to `.env` are blocked before read/write/patch.

### Verification

- Focused Rust Pro filesystem tests:
  - Command: `cargo test --lib --features pro-build filesystem`
  - Working directory: `agent_core`
  - Result: PASS (`20 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`30 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/filesystem.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not broaden filesystem access or add new write capabilities.
- The guard is intentionally conservative for existing targets; non-existing writes are still controlled by lexical path and nearest existing parent checks.

## Slice 72 — Legacy FileOps Path Guard Alignment

### Findings

- `file_ops` is an older Agent-tier filesystem tool that remains registered alongside the newer `read_file`/`write_file`/`patch` primitives.
- Its path guard blocked `..` traversal and some credential directories, but did not block protected system write prefixes.
- It also used lexical checks only, so a safe-looking path could resolve through a symlink to a blocked sensitive filename.

### Changes Made

- `agent_core/src/tools/file_ops.rs`
  - Added protected system write prefixes aligned with the newer filesystem tools.
  - Split read/write path validation so write actions apply the stricter write policy.
  - Added canonical checks for existing targets and nearest existing parents.
  - Added tests for system-write blocking, symlink-to-sensitive-file blocking, and write rejection without mutating the sensitive target.

### Verification

- Focused Rust Pro file ops tests:
  - Command: `cargo test --lib --features pro-build file_ops`
  - Working directory: `agent_core`
  - Result: PASS (`3 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`30 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/file_ops.rs` passed.
  - `git diff --check` passed.

### Notes

- This keeps the legacy scaffold reachable but less surprising.
- `file_ops` remains Agent-tier modification and should not replace the more specific paginated `read_file` / verified `write_file` / fuzzy `patch` tools in normal docs.

## Slice 73 — Trajectory Export Output Guard and Inline Budget

### Findings

- `trajectory_export` is Pro-build/Agent-tier and correctly excluded from MAS/Core, but the source comment still described it as ChatLite/read-only even though `output_path` writes JSONL files.
- The optional `output_path` accepted relative paths and created parent directories without the protected target/parent checks already added to the file tools.
- Inline mode capped the number of returned sessions but not the total JSONL byte size; a single huge transcript could still produce an oversized tool result.
- File output assembled all exported lines into one joined string before writing, adding avoidable memory pressure for large exports.

### Changes Made

- `agent_core/src/tools/trajectory.rs`
  - Corrected the module contract to document Agent-tier/MAS exclusion for the writing export path.
  - `output_path` now rejects leading/trailing whitespace, relative paths, existing directories, protected system write prefixes, protected credential directories, sensitive filenames, and existing symlinks that resolve to blocked targets.
  - File output now streams lines through `BufWriter` instead of building a single joined output string.
  - Inline output now enforces both the existing 20-session cap and a 512 KiB byte budget, returning `sessions_omitted`, `sessions_processed`, `inline_byte_limit`, and `inline_bytes` diagnostics.
  - Added tests for relative output rejection, protected system path rejection, symlink-to-sensitive-target rejection, and inline session/byte caps.

### Verification

- Focused Rust Pro trajectory tests:
  - Command: `cargo test --lib --features pro-build trajectory`
  - Working directory: `agent_core`
  - Result: PASS (`11 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`30 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/trajectory.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not add trajectory export to MAS/Core or turn the training-data export into a ChatLite feature.
- Large exports should use explicit absolute/`~/` output files and then be read through the normal guarded file tools.

## Slice 74 — iMessage AppleScript Output and Error Honesty

### Findings

- The first-party Apple app tools already bound and redacted `osascript` stdout/stderr, but the separate Pro-only `imessage` tool still decoded raw stderr and returned it directly on send failures.
- A Messages failure could therefore leak recipient/message-adjacent detail or oversized AppleScript output into the tool result.
- The read path remains SQLite/read-only and the write path remains Automation-gated; the missing hardening was the subprocess diagnostic contract.

### Changes Made

- `agent_core/src/tools/imessage.rs`
  - Added a 512 KiB stdout/stderr decode cap with an explicit truncation marker.
  - Replaced raw AppleScript stderr echoing with classified, redacted messages for Automation permission denial, unresolved recipients, Messages app errors, empty stderr, and generic failures.
  - Successful stdout decoding now uses the same bounded helper.
  - Added tests for output bounding, raw-stderr redaction, permission classification, and recipient-resolution classification.

### Verification

- Focused Rust Pro iMessage tests:
  - Command: `cargo test --lib --features pro-build imessage`
  - Working directory: `agent_core`
  - Result: PASS (`25 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`30 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/imessage.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not claim live Messages send success; Automation permission, Full Disk Access, and account availability still need manual runtime testing.
- The iMessage tool remains Pro-only/Agent-tier and MAS-excluded.

## Slice 75 — Browser CLI Output Budget and Redaction

### Findings

- Browser automation runs the optional `agent-browser` CLI and redirects stdout/stderr to temp files.
- The command wrapper read those temp files fully with `read_to_string` after the subprocess exited, so a noisy or broken CLI could still create an oversized in-memory tool result path.
- Non-JSON stdout and failure stderr were echoed into `ToolError`, which could expose page content, URLs with embedded credentials, tokens, or arbitrary CLI noise.
- `agent-browser` is absent in this environment, so runtime browser permission testing remains manual; this slice hardens the wrapper contract using the existing fake CLI tests.

### Changes Made

- `agent_core/src/tools/browser.rs`
  - Added bounded stdout/stderr reads from the temp files with a 512 KiB cap and truncation marker.
  - Stopped echoing raw non-JSON stdout/stderr in failure messages.
  - JSON `success:false` error details are scrubbed for common token, credential, cookie, authorization, and URL-credential shapes, then capped to 512 characters.
  - Added fake `agent-browser` cases for non-JSON output, nonzero stderr failure, and JSON error redaction.

### Verification

- Focused Rust Pro browser tests:
  - Command: `cargo test --lib --features pro-build browser`
  - Working directory: `agent_core`
  - Result: PASS (`10 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`30 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/browser.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not install or claim a working live browser controller; `agent-browser` is still absent here.
- Browser GUI/permission/manual smoke testing remains deferred to an environment with the CLI and browser permissions configured.

## Slice 76 — Text-to-Speech Output Target and Error Hardening

### Findings

- `text_to_speech` already required explicit playback consent when no output file was provided and was correctly classified as a Pro modification tool.
- Its `output_path` validation required absolute/`~/` paths with an existing parent, but did not apply the protected system/credential target checks used by other write-capable tools.
- A safe-looking output path could point through an existing symlink to a sensitive filename.
- Nonzero `say` failures echoed raw stderr into the tool error.

### Changes Made

- `agent_core/src/tools/media.rs`
  - `output_path` now rejects leading/trailing whitespace, existing directories, protected system write prefixes, protected credential directories, sensitive filenames, and symlink targets that resolve to blocked files.
  - Path normalization now collapses `.`/`..` lexically before the write-target checks.
  - `say` failure diagnostics now classify permission/output-path and voice errors and otherwise redact raw stderr.
  - Added tests for protected output path rejection, symlink-to-sensitive-target rejection, and raw stderr redaction.

### Verification

- Focused Rust Pro text-to-speech tests:
  - Command: `cargo test --lib --features pro-build text_to_speech`
  - Working directory: `agent_core`
  - Result: PASS (`12 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`30 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/media.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not add TTS to MAS/Core and does not claim live speaker playback or file-render success.
- The tool remains an explicit Pro local subprocess surface with playback consent and file-write authorization.

## Slice 77 — Vision Local-File Secret Read Guard

### Findings

- `vision_analyze` correctly required `allow_cloud_external_requests=true` before reading local image bytes.
- With that consent present, a caller could still point `image_path` at obvious credential files or a safe-looking symlink to a credential file, and the tool would read those bytes before provider dispatch.
- The right v1 hardening is not a new media architecture; it is a conservative local read guard for credential/sensitive paths before any image bytes are loaded.

### Changes Made

- `agent_core/src/tools/media.rs`
  - Local `image_path` values are normalized lexically before the local read.
  - Blocks protected home credential directories and sensitive filenames such as `.env`, `.netrc`, `.npmrc`, `.pypirc`, `.pgpass`, `credentials`, and `credentials.json`.
  - Existing symlinks are canonicalized so safe-looking image names that resolve to blocked targets are rejected before file read or provider/API-key lookup.
  - Added tests proving direct sensitive file paths and symlinked sensitive files fail before `ANTHROPIC_API_KEY` lookup.

### Verification

- Focused Rust Pro media tests:
  - Command: `cargo test --lib --features pro-build media`
  - Working directory: `agent_core`
  - Result: PASS (`29 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`30 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/media.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not make cloud vision local/offline. It keeps the explicit Pro cloud boundary and prevents obvious local secret files from being used as image sources.
- Manual provider success still requires valid API keys and was not claimed here.

## Slice 78 — PKM Note Tool Bounds and Inventory Safety

### Findings

- Phase 2 note tools are registered and intended for v1, but they had few direct tests.
- `note_linker` recursively scanned the vault with `Path::is_dir`, which follows symlinked directories and could inventory outside the vault or loop through linked trees.
- `research_digest` silently ignored non-string entries in `notes` and accepted unbounded note counts/content.
- `citation_extractor` and `markdown_table` accepted unbounded input sizes; table generation also emitted raw cell pipes/newlines, producing malformed Markdown tables.
- `note_template` allowed unbounded variable maps and rendered output growth before writing.

### Changes Made

- `agent_core/src/tools/note_tools.rs`
  - Added explicit caps for template input/rendered size, variable count/value size, research note count/content size, citation input size, table row/column/cell size, and CSV input size.
  - `research_digest` now rejects non-string notes instead of silently dropping them.
  - `note_linker` inventory now uses `DirEntry::file_type()` so symlinked directories are skipped, and returns `inventory_truncated` when the note-stem cap is reached.
  - `markdown_table` now escapes pipes, flattens newlines inside cells, truncates overlong cells, validates single-character delimiters, and rejects oversized tables.
  - Added tests for template variable caps, research note validation/caps, citation text caps, table escaping/row caps, symlinked directory skipping, and registry presence.

### Verification

- Focused Rust Pro note-tool tests:
  - Command: `cargo test --lib --features pro-build note_tools`
  - Working directory: `agent_core`
  - Result: PASS (`6 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`30 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/note_tools.rs` passed.
  - `git diff --check` passed.

### Notes

- This keeps the existing v1 note-tool surface; it does not add a new notes architecture or HELIOS behavior.
- `note_template` remains Agent-tier modification and still relies on the vault/R.5 write gate for authorization.

## Slice 79 — Curated Memory Persistence Honesty

### Findings

- The `memory` tool is registered as a v1 Agent-tier modification surface and stores curated agent/user memory under the vault `.epistemos/memory` directory when available.
- Invalid targets silently fell through to the `memory` store because any target other than `user` used the default branch.
- Unknown actions returned a success-envelope-shaped JSON error instead of a tool argument error.
- Empty replace/remove substrings could match entries unexpectedly.
- `replace` did not enforce the store character limit after replacement.
- Disk persistence failures during add/replace/remove were ignored, so a response could claim success after an unwritten memory update.
- Oversized on-disk memory files were read fully during load.

### Changes Made

- `agent_core/src/tools/memory.rs`
  - Validates `action` and `target` before locking the store.
  - Uses character counts consistently for the documented memory limits.
  - Rejects empty replace/remove substrings.
  - Enforces the character limit on replacement.
  - Converts persistence into an explicit `Result`, reports write/rename errors, and rolls back in-memory add/replace/remove mutations if persistence fails.
  - Ignores oversized on-disk memory files with a warning instead of reading them into memory.
  - Added tests for invalid action/target rejection, first-entry char accounting, empty substring rejection, replacement limit enforcement, and oversized-file load rejection.

### Verification

- Focused Rust Pro curated-memory tests:
  - Command: `cargo test --lib --features pro-build tools::memory`
  - Working directory: `agent_core`
  - Result: PASS (`5 passed; 0 failed`)
- Broad filter caveat:
  - Command: `cargo test --lib --features pro-build memory`
  - Result: FAIL due unrelated `shared_memory::*` mmap tests returning `Operation not permitted` in this sandbox; the `tools::memory::*` tests all passed in that run.
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`30 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/memory.rs` passed.
  - `git diff --check` passed.

### Notes

- This is the existing curated memory tool, not a new procedural-memory architecture.
- Shared-memory mmap tests remain a separate environment/permission issue and were not claimed as passing here.

## Slice 80 — Cron Scheduling Persistent-Job Consent and Bounds

### Findings

- `cronjob` is a Pro-build persistent scheduling CRUD surface. The source correctly says actual scheduled execution is wired by the caller, but creating/resuming enabled jobs still persists prompts that may run later once a host scheduler is attached.
- `create` defaulted to enabled jobs without an explicit acknowledgement that a prompt could run later.
- `update` and `resume` could alter future scheduled behavior without that acknowledgement.
- Job name, prompt, schedule, id, and list output were not bounded at the tool layer.

### Changes Made

- `agent_core/src/tools/scheduling.rs`
  - `create`, `update`, and `resume` now require `allow_persistent_schedule=true`.
  - Added caps for job names, prompts, cron expressions, ids, and list result count.
  - `list` now accepts/clamps `limit` to 1-100 and returns the effective limit.
  - Schema documents `allow_persistent_schedule` and `limit`.
  - Added tests for required persistent-schedule acknowledgement, oversized prompt rejection, create/list, update, pause/resume, remove, and cron parsing.

### Verification

- Focused Rust Pro scheduling tests:
  - Command: `cargo test --lib --features pro-build scheduling`
  - Working directory: `agent_core`
  - Result: PASS (`8 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`30 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/scheduling.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not add scheduled execution. `cronjob` still manages persisted rows; host-owned job execution remains a separate integration surface.
- `cronjob` remains hidden from ChatLite and MAS/Core.

## Slice 81 — Delegate-Backed Inference Bounds and Response Honesty

### Findings

- `route_private` is a ChatPro routing-audit surface and echoed the full objective without any tool-layer size cap.
- `ssm_resume` and `constrained_generate` are Agent-session delegate-backed tools; they are registered only when a live host delegate is attached.
- Both delegate-backed handlers wrapped non-JSON delegate responses into a JSON object with raw output, which could expose secrets or arbitrary host/runtime diagnostics.
- `ssm_resume` accepted unbounded `session_id` and `label` values before forwarding to the delegate.
- `constrained_generate` accepted unbounded prompts, custom grammars, tool-schema payloads, and unchecked `max_tokens` values before forwarding to the delegate.
- The `ssm_resume` schema claimed fixed state sizes and sub-50 ms zero-copy mmap behavior even though this Rust handler only bridges to the host delegate.

### Changes Made

- `agent_core/src/tools/inference.rs`
  - Added explicit caps for `route_private.objective`, SSM session ids/labels, constrained prompts, custom EBNF, tool-schema payloads, delegate responses, and constrained token counts.
  - Requires SSM `action`, `session_id`, and `label` fields to be strings when supplied.
  - Requires constrained `grammar`, `custom_ebnf`, `tools`, and `max_tokens` to match the schema before the delegate call.
  - Replaces raw non-JSON delegate echoing with a redacted execution error for both `ssm_resume` and `constrained_generate`.
  - Softened `ssm_resume` and `constrained_generate` schema copy so the Rust audit bridge no longer promises performance/storage guarantees it does not own.
  - Added coverage for oversized inputs, invalid token counts, non-string custom grammars, oversized tools payloads, and raw delegate-output redaction.

### Verification

- Focused Rust Pro inference tests:
  - Command: `cargo test --lib --features pro-build inference`
  - Working directory: `agent_core`
  - Result: PASS (`22 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`30 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/inference.rs` passed.
  - `git diff --check` passed.

### Notes

- This keeps Phase 5 inference as existing v1 wiring only. It does not add a new model runtime, SSM storage engine, HELIOS substrate, or grammar-decoding architecture.
- `ssm_resume` and `constrained_generate` remain delegate/Agent-session tools, not silent non-agent chat tools.

## Slice 82 — macOS Delegate Tool Boundary Hardening

### Findings

- `perceive`, `interact`, and `screen_watch` are Pro/Agent-session delegate tools for macOS Accessibility, ScreenCaptureKit/Vision, and UI automation paths.
- All three handlers wrapped non-JSON delegate responses into JSON with raw host output, which could expose permission diagnostics, UI content, or secrets.
- `perceive` accepted unbounded app names and silently defaulted malformed `depth` values to `fast`.
- `interact` accepted unbounded app names, targets, and typed values, and allowed non-string `value` payloads despite the schema.
- `screen_watch` accepted unbounded targets/conditions, silently defaulted malformed timeout values, and clamped out-of-range timeouts rather than reporting the schema violation.
- The `perceive` schema promised concrete latency bands for host-owned work that this Rust bridge cannot guarantee.

### Changes Made

- `agent_core/src/tools/macos.rs`
  - Added explicit caps for app names, interact targets/values, screen-watch targets/conditions, and delegate response size.
  - Rejects non-string optional fields instead of silently defaulting them.
  - Rejects out-of-range `timeout_secs` instead of silently clamping.
  - Replaces raw non-JSON delegate echoing with redacted execution errors for `perceive`, `interact`, and `screen_watch`.
  - Softened `perceive` schema copy to describe requested percept depth and required host permissions without promising fixed latency.
  - Added focused tests for input bounds, invalid value/timeout types, and raw delegate-output redaction.

### Verification

- Focused Rust Pro macOS delegate tests:
  - Command: `cargo test --lib --features pro-build macos`
  - Working directory: `agent_core`
  - Result: PASS (`13 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`30 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/macos.rs` passed.
  - `git diff --check` passed.

### Notes

- This hardens the existing v1 delegate bridge only. It does not enable the deferred VisualVerify loop or claim live macOS UI permission smokes.
- Manual Accessibility/Screen Recording validation is still required on a real launched app session.

## Slice 83 — Intelligence Delegate Response Honesty

### Findings

- `nightbrain_trigger` and `inline_partner` are Agent-session delegate surfaces that depend on the Swift host for actual NightBrain execution and editor-context lookup.
- Both handlers wrapped non-JSON delegate responses into JSON with raw host output, creating the same leak/misrepresentation risk found in the inference and macOS delegate tools.
- `nightbrain_trigger.priority` silently defaulted malformed non-string values.
- `inline_partner.note_id` was unbounded, and malformed non-integer `cursor_offset` values reported as missing instead of invalid.

### Changes Made

- `agent_core/src/tools/intelligence.rs`
  - Added a shared delegate-response cap and redacted non-JSON delegate failure helper for `nightbrain_trigger` and `inline_partner`.
  - `nightbrain_trigger` now rejects non-string `priority` before invoking the delegate.
  - `inline_partner` now bounds `note_id` and reports non-integer `cursor_offset` as an argument error.
  - Added tests for non-string priority, malformed delegate-output redaction, oversized note ids, and non-integer cursor offsets.

### Verification

- Focused Rust Pro NightBrain trigger tests:
  - Command: `cargo test --lib --features pro-build nightbrain_trigger`
  - Working directory: `agent_core`
  - Result: PASS (`6 passed; 0 failed`)
- Focused Rust Pro inline partner tests:
  - Command: `cargo test --lib --features pro-build inline_partner`
  - Working directory: `agent_core`
  - Result: PASS (`5 passed; 0 failed`)
- Broader Rust Pro intelligence tests:
  - Command: `cargo test --lib --features pro-build tools::intelligence::tests`
  - Working directory: `agent_core`
  - Result: PASS (`24 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`30 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/intelligence.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not add new NightBrain jobs, autonomous self-evolution, or HELIOS substrate.
- Live host execution for NightBrain/editor context remains covered by Swift/manual integration paths, not claimed by these Rust unit tests.

## Slice 84 — Clarify Tool Prompt and Delegate Bounds

### Findings

- `clarify` is a delegate-backed ask-the-user surface that can be exposed above ChatLite through the tier catalog.
- The handler had no question, choice, or delegate-response size caps.
- Non-string choices were silently dropped before the question reached the UI, which could make the displayed options differ from the caller's intended schema.
- Non-JSON delegate responses did not echo raw output, but the response was still parsed without an explicit budget.

### Changes Made

- `agent_core/src/tools/clarify.rs`
  - Added caps for question text, number of choices, choice text, and delegate response size.
  - Rejects non-array `choices` and non-string choice entries instead of silently filtering them.
  - Redacts malformed delegate output with a fixed error string and no raw response echo.
  - Added tests for oversized questions/choices, non-string choices, non-JSON delegate redaction, and oversized delegate response rejection.

### Verification

- Focused Rust Pro clarify tests:
  - Command: `cargo test --lib --features pro-build clarify`
  - Working directory: `agent_core`
  - Result: PASS (`7 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`30 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/clarify.rs` passed.
  - `git diff --check` passed.

### Notes

- This preserves the existing v1 user-clarification tool. It does not add a new conversation protocol or UI flow.

## Slice 85 — Delegate Task Bounds and Error Honesty

### Findings

- `delegate_task` is an Agent-tier subagent spawning tool wired by `run_agent_session_inner` after provider resolution.
- Missing or blank objectives returned JSON-shaped success payloads with an `"error"` field instead of a tool argument error.
- Max-depth failures also returned JSON-shaped output instead of an execution failure.
- Objectives and returned subagent text/error output were unbounded at the tool layer.

### Changes Made

- `agent_core/src/tools/delegate_task.rs`
  - Added an objective character cap and trims/rejects blank objectives.
  - Converts missing/blank/oversized objectives into `ToolError::InvalidArguments`.
  - Converts max-depth rejection into `ToolError::ExecutionFailed`.
  - Bounds returned subagent response text and subagent error strings.
  - Updates the schema description to state objective and returned text are bounded.
  - Adds tests for missing/blank/oversized objectives, max-depth rejection before spawn, and truncation behavior.

### Verification

- Focused Rust Pro delegate-task tests:
  - Command: `cargo test --lib --features pro-build delegate_task`
  - Working directory: `agent_core`
  - Result: PASS (`6 passed; 0 failed`, including the registry source guard selected by the filter)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`30 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/delegate_task.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not add new subagent orchestration semantics. Depth remains capped at two levels, and silent-delegate fallbacks still report unavailable delegate-only tools explicitly.

## Slice 86 — Send Message Recipient and Field-Type Honesty

### Findings

- `send_message` is Agent-tier destructive communication; malformed inputs must fail before credential reads or network dispatch.
- Optional `target`, `webhook_url`, and `allow_custom_webhook_url` fields silently defaulted away when supplied with the wrong type.
- Signal recipient arrays silently dropped non-string entries, which could send to a subset of intended recipients.
- WhatsApp `to`, Matrix `room_id`, and email addressing fields were validated after credential/env lookups.
- Message caps used byte length while user-facing errors described character caps.

### Changes Made

- `agent_core/src/tools/communication.rs`
  - Added typed optional-string/optional-bool helpers for top-level send fields.
  - Validates malformed target/webhook/consent fields before dispatch.
  - Parses Signal recipients strictly as a string or array of strings, rejects empty/oversized recipient lists, and no longer drops malformed entries.
  - Validates WhatsApp recipients, Matrix room ids, email recipients/reply-to, and email subject bounds before credential reads.
  - Switches message cap and `chars_sent` accounting to character counts.
  - Preserves redacted request/HTTP errors and custom webhook consent requirements.
  - Adds tests for malformed consent/target values, strict Signal recipient arrays, empty Signal recipients, WhatsApp `to` validation, and oversized email subjects before env reads.

### Verification

- Focused Rust Pro communication tests:
  - Command: `cargo test --lib --features pro-build tools::communication::tests`
  - Working directory: `agent_core`
  - Result: PASS (`24 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`30 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/communication.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not add any new messaging provider. It only makes the existing destructive `send_message` surface stricter and more truthful before credentials/network are touched.

## Slice 87 — Vault Knowledge Tool Input Honesty

### Findings

- `vault_recall`, `contradiction_check`, `session_search`, and `neural_recall` are ChatLite-visible vault-native knowledge tools.
- `vault_recall.note_filter` silently dropped non-string tags before calling the vault backend.
- Numeric knobs such as `top_k`, `limit`, and temporal windows were silently clamped or ignored when malformed.
- Optional string fields such as contradiction context, session query, and provider filters were silently ignored when malformed.
- The `vault_recall` schema promised sub-5ms latency even though the handler measures the actual backend latency and cannot guarantee a fixed bound.

### Changes Made

- `agent_core/src/tools/knowledge.rs`
  - Added input caps for queries, contradiction context, note filter tags, provider filters, and temporal windows.
  - Replaces silent tag filtering with strict `note_filter` array-of-strings validation.
  - Replaces silent numeric clamping/defaulting with typed range validation for knowledge-tool limits and temporal windows.
  - Rejects malformed optional string fields instead of ignoring them.
  - Softens `vault_recall` schema copy to say measured latency, not fixed sub-5ms latency.
  - Adds tests for malformed tag filters, invalid `top_k`, malformed contradiction context, malformed session limits, and invalid temporal windows.

### Verification

- Focused Rust Pro knowledge tests:
  - Command: `cargo test --lib --features pro-build knowledge`
  - Working directory: `agent_core`
  - Result: PASS (`13 passed; 0 failed`, including 2 ScopeRex answer-packet tests selected by the filter)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`30 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/knowledge.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not change the retrieval backend or add new memory substrate. It only makes the current v1 knowledge-tool contract stricter and removes an overclaim from schema text.

## Slice 88 — Web Read Tool Argument Honesty

### Findings

- `web_search`, `web_extract`, `web_fetch`, and `web_crawl` are v1-visible read tools and therefore need argument failures to be explicit, not hidden behind defaults.
- `web_search.limit`, `web_crawl.max_pages`, `web_crawl.max_depth`, and `web_crawl.same_host_only` silently defaulted or clamped malformed values.
- `web_extract.urls` silently dropped non-string entries, which could fetch a subset of caller-intended URLs.
- `web_fetch` converted a missing or non-string `url` into a JSON fetch failure for an empty URL instead of returning a tool argument error.
- `web_fetch` truncated fetched text with a byte index, which could panic on a non-ASCII boundary.
- Perplexity citation normalization could emit empty URL results for malformed provider citation entries.

### Changes Made

- `agent_core/src/tools/web.rs`
  - Adds strict bounded parsing for search queries, backend overrides, crawl bounds, booleans, and URL arrays.
  - Replaces silent `limit`/crawl-bound clamping with typed range errors.
  - Rejects malformed `web_extract.urls` entries instead of dropping them.
  - Filters malformed/unsafe Perplexity citation entries instead of returning empty citation rows.
  - Adds tests for strict search-argument helpers, malformed extract URL entries, and malformed crawl bounds.
- `agent_core/src/tools/web_fetch.rs`
  - Adds a URL character cap to the shared URL validator.
  - Returns `ToolError::InvalidArguments` for missing/non-string `web_fetch.url`.
  - Truncates fetched content by character count instead of byte slicing.
  - Adds tests for missing/non-string URL errors and UTF-8-safe truncation.
- Tool-tier docs now describe strict typed validation for web read/crawl parameters.

### Verification

- Focused Rust Pro fetch tests:
  - Command: `cargo test --lib --features pro-build web_fetch`
  - Working directory: `agent_core`
  - Result: PASS (`5 passed; 0 failed`)
- Focused Rust Pro web handler tests:
  - Command: `cargo test --lib --features pro-build tools::web::tests`
  - Working directory: `agent_core`
  - Result: PASS (`19 passed; 0 failed`)
- Broader Rust Pro web filter:
  - Command: `cargo test --lib --features pro-build web`
  - Working directory: `agent_core`
  - Result: PASS (`33 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`30 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/web.rs agent_core/src/tools/web_fetch.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not add a new browser/search provider or change the HELIOS substrate. It only makes the existing v1 web read surface fail honestly and avoid a UTF-8 truncation panic.

## Slice 89 — Skills Procedural-Memory Argument Honesty

### Findings

- The newer `skill_manage`, `skills_list`, and `skill_view` tools are v1 procedural-memory surfaces; the legacy bundled `skills` CRUD tool is still present and must not silently reinterpret malformed input.
- Legacy `skills` defaulted missing `action` to `list`, defaulted missing action-specific fields to empty strings, and ignored malformed optional fields such as `category` and `replace`.
- `skills_list.tag` and `skill_view.name` treated non-string values as absent/missing rather than type errors.
- `skill_manage` install flows silently treated malformed `approve` and `allow_remote_skill_install` values as `false`, which could hide caller intent around quarantine promotion and remote import consent.
- `skill_manage.category`, local import `name`, and other optional string fields ignored malformed types.

### Changes Made

- `agent_core/src/tools/skills.rs`
  - Adds shared required-string, optional-string, and optional-bool argument parsers.
  - Makes legacy `skills` require an explicit string `action` and validate action-specific fields before dispatch.
  - Makes `skills_list.tag` and `skill_view.name` strictly typed.
  - Makes `skill_manage` create/edit/delete/local/URL/GitHub paths reject malformed optional strings and booleans instead of silently defaulting them.
  - Keeps remote installs quarantined and approval-gated; no autonomous promotion or generated tool registration was added.
  - Adds tests for malformed tag/name/action/category/approve/remote-consent fields.
- Tool-tier docs now state that skill consent and filter fields are strictly typed.

### Verification

- Focused Rust Pro skills tests:
  - Command: `cargo test --lib --features pro-build skills`
  - Working directory: `agent_core`
  - Result: PASS (`24 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`30 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting:
  - `rustfmt --edition 2024 --check agent_core/src/tools/skills.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not expand v1 skill authority. Skills remain prompt/procedural-memory content with quarantine and explicit approval around imports; shell-backed generated tool registration remains deferred.

## Slice 90 — Computer Use Placeholder Honesty

### Findings

- The shipping v1 Computer Use route is native Swift (`ComputerUseBridge`), while `agent_core/src/tools/computer_use.rs` is an orphaned Rust host-intercept scaffold.
- The Rust handler was not registered in the tool registry, but if invoked directly it returned a delegate-looking JSON payload that could be mistaken for an executed action.
- The Rust handler also defaulted missing `action` to `screenshot` and did not validate action-specific coordinate/text/direction fields.
- Manual Accessibility/Screen Recording/UI permission verification remains unavailable from this terminal session; no live GUI pass is claimed.

### Changes Made

- `agent_core/src/tools/computer_use.rs`
  - Adds strict validation for supported actions (`screenshot`, `click`, `type_text`, `scroll`, `get_ax_tree`).
  - Validates click/scroll coordinates, scroll direction, typed text cap, and optional app-name cap.
  - Returns an honest `ExecutionFailed` explaining that v1 execution belongs to the native Swift `ComputerUseBridge` path instead of returning a fake delegate placeholder.
  - Adds tests for missing/unknown actions, action-specific field validation, and honest direct-handler failure.
- `agent_core/src/tools/registry.rs`
  - Adds a source-level registry guard proving `computer` is not registered in the Rust tool catalog.

### Verification

- Focused Rust Pro Computer Use tests:
  - Command: `cargo test --lib --features pro-build computer_use`
  - Working directory: `agent_core`
  - Result: PASS (`3 passed; 0 failed`)
- Registry no-registration guard:
  - Command: `cargo test --lib --features pro-build computer_placeholder_handler_is_not_registered`
  - Working directory: `agent_core`
  - Result: PASS (`1 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`31 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/computer_use.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not add a new Computer Use runtime, browser controller, visual verification loop, or HELIOS substrate. It prevents an orphaned scaffold from presenting fake execution and keeps v1 honest until native-host UI smokes can be run manually.

## Slice 91 — PKM Note Tool Argument Honesty

### Findings

- `citation_extractor` and `markdown_table` are registered v1 PKM helpers and should not silently reinterpret malformed option fields.
- `citation_extractor.format` silently defaulted non-string values to `markdown`.
- `markdown_table.action` silently defaulted missing/non-string values to `from_json`.
- Unknown Markdown table actions returned a JSON error payload instead of a real tool argument error.
- `markdown_table.from_json` accepted non-object rows after the first row and emitted blank rows.
- `markdown_table.from_csv` silently treated an empty delimiter as comma and treated a non-string delimiter as absent.
- Empty JSON/CSV inputs returned JSON payloads with `"error"` instead of failing as invalid arguments.

### Changes Made

- `agent_core/src/tools/note_tools.rs`
  - Adds required/optional string argument helpers for note-tool option fields.
  - Makes citation format strict when supplied.
  - Makes Markdown table action required, string-typed, and enum-checked through real `InvalidArguments`.
  - Makes JSON table rows require objects for every row.
  - Makes CSV delimiter strict: optional string, exactly one non-newline character, and not empty.
  - Converts empty JSON/CSV table inputs into real argument errors.
  - Adds tests for malformed citation format, table action, non-object rows, and bad delimiters.

### Verification

- Focused Rust Pro note-tool tests:
  - Command: `cargo test --lib --features pro-build note_tools`
  - Working directory: `agent_core`
  - Result: PASS (`9 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`31 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/note_tools.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not add a new PKM tool or change vault authority. It only tightens the existing v1 note-tool argument contract and removes JSON-shaped pseudo-errors.

## Slice 92 — Curated Memory Argument Honesty

### Findings

- The Rust `memory` tool is an Agent-tier curated-memory surface, but malformed write intent should not become a default read or empty write.
- `action` silently defaulted to `read` when missing or malformed despite being required by schema.
- `target` silently defaulted to `memory` even when supplied with the wrong type. The documented missing-target default is still valid, but malformed supplied values should fail.
- `content` and `substring` silently defaulted to empty strings; store-level validation then returned JSON-shaped failures instead of argument errors for missing/malformed fields.

### Changes Made

- `agent_core/src/tools/memory.rs`
  - Adds required/optional string argument helpers.
  - Requires a string `action`.
  - Preserves the documented missing `target` default of `memory`, while rejecting malformed supplied `target`.
  - Requires string `content` for `add`/`replace`.
  - Requires string `substring` for `replace`/`remove`.
  - Adds tests for missing action, malformed target, missing content, and malformed substring.

### Verification

- Focused Rust Pro curated-memory tests:
  - Command: `cargo test --lib --features pro-build tools::memory`
  - Working directory: `agent_core`
  - Result: PASS (`6 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`31 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/memory.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not add memory substrate or change the mmap/shared-memory path. The broad `memory` filter remains unsuitable here because it selects unrelated `shared_memory::*` tests that fail under sandboxed mmap permissions; the exact curated-memory filter passes.

## Slice 93 — Legacy File Ops Argument Honesty

### Findings

- `file_ops` remains registered as an Agent-tier legacy filesystem modification scaffold for Goose/Hermes parity.
- The handler silently defaulted missing/malformed `action` to `read` and missing/malformed `path`, `content`, `find`, and `replace` to empty strings.
- Unknown actions returned JSON-shaped failure payloads instead of tool argument errors.
- `start_line` and `end_line` silently ignored malformed values.
- A line range with `start_line > end_line` or a start past the available line count could produce an invalid slice range.

### Changes Made

- `agent_core/src/tools/file_ops.rs`
  - Adds strict required/optional string parsing and strict optional line-number parsing.
  - Requires string `action` and `path` for every operation.
  - Requires `content` for `write`, `find` for `patch`, and keeps missing `replace` as the intentional empty replacement while rejecting malformed supplied `replace`.
  - Converts unknown actions into `InvalidArguments`.
  - Rejects zero/non-integer line fields and `end_line < start_line`.
  - Returns an empty read result when a valid start line is past EOF instead of panicking.
  - Adds tests for malformed action/path/content/find/replace/range inputs and past-EOF reads.

### Verification

- Focused Rust Pro legacy file-op tests:
  - Command: `cargo test --lib --features pro-build file_ops`
  - Working directory: `agent_core`
  - Result: PASS (`7 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`31 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/file_ops.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not expand filesystem authority. The newer filesystem tools remain the preferred v1 surface; `file_ops` stays Agent-tier legacy parity with stricter argument and path safety.

## Slice 94 — Browser Optional Argument Honesty

### Findings

- Pro-build `browser_*` tools are optional/deferred browser automation, but malformed option fields should fail before any browser CLI command can run.
- `browser_snapshot.full` silently defaulted malformed values to `false`.
- `browser_console.clear` silently defaulted malformed values to `false`, and `browser_console.expression` silently ignored non-string values.
- `browser_vision.allow_cloud_external_requests`, `provider`, and `annotate` silently defaulted malformed values before the screenshot/cloud path.

### Changes Made

- `agent_core/src/tools/browser.rs`
  - Adds strict optional bool/string argument helpers.
  - Makes `browser_snapshot.full`, `browser_console.clear`, `browser_console.expression`, `browser_vision.allow_cloud_external_requests`, `browser_vision.provider`, and `browser_vision.annotate` fail as argument errors when supplied with the wrong type.
  - Adds tests proving malformed browser option fields are rejected before CLI execution.

### Verification

- Focused Rust Pro browser tests:
  - Command: `cargo test --lib --features pro-build browser`
  - Working directory: `agent_core`
  - Result: PASS (`11 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`31 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/browser.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not add a browser runtime or claim live UI permission success. It only prevents malformed optional browser arguments from being silently treated as defaults.

## Slice 95 — Mixture-of-Minds Cloud Fan-Out Argument Honesty

### Findings

- `mixture_of_minds` is a Pro-only external cloud fan-out tool, so malformed consent/model fields must fail before any provider request.
- `allow_cloud_external_requests` silently treated malformed values as `false`.
- `models` silently ignored non-array values by using the default model set.
- `models` arrays silently dropped non-string entries, which could call a subset of requested providers without telling the caller.
- `problem` had no blank or bounded-size validation before external-provider dispatch.

### Changes Made

- `agent_core/src/tools/intelligence.rs`
  - Adds problem and model-name bounds for `mixture_of_minds`.
  - Rejects blank/oversized problems.
  - Makes `allow_cloud_external_requests` strictly typed while preserving the existing explicit-true consent requirement.
  - Makes supplied `models` require an array of nonblank strings; malformed entries now fail as arguments instead of being dropped.
  - Adds tests for malformed consent, malformed model list shape/entries, blank/oversized problems, and existing unknown/too-many model checks.

### Verification

- Focused Rust Pro MoM tests:
  - Command: `cargo test --lib --features pro-build mom`
  - Working directory: `agent_core`
  - Result: PASS (`9 passed; 0 failed`)
- Broader Rust Pro intelligence tests:
  - Command: `cargo test --lib --features pro-build tools::intelligence::tests`
  - Working directory: `agent_core`
  - Result: PASS (`26 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`31 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/intelligence.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not make MoM local/offline or add model providers. It only strengthens the existing Pro cloud boundary and keeps missing-key/provider failures honest.

## Slice 96 — Workspace Code Search Argument Honesty

### Findings

- `workspace_search`, `find_symbol`, `get_function_source`, `get_dependencies`, `get_dependents`, and `get_change_impact` are ChatLite-visible read-only codebase helpers.
- The public `workspace_search` description overclaimed fixed SIMD/ARM64/sub-millisecond behavior instead of describing the measured implementation facts.
- `file_extensions` silently ignored non-array values and dropped non-string entries.
- `max_results` and `context_lines` silently defaulted malformed values and did not enforce schema bounds.
- Workspace/query/symbol/path fields lacked blank and size bounds.

### Changes Made

- `agent_core/src/tools/workspace_search.rs`
  - Softens the public description to memory-mapped file reads and byte-pattern scanning with bounded controls.
  - Adds shared strict parsers for workspace paths, query/symbol names, file extensions, and integer ranges.
  - Applies strict extension parsing across workspace search, symbol lookup, function-source lookup, dependents, and impact analysis.
  - Applies result/context range checks for search/symbol/dependent handlers.
  - Adds tests for malformed extension lists, malformed/out-of-range limits, and existing symbol/dependency behavior.
- Tool-tier docs now describe strict typed workspace-search inputs.

### Verification

- Focused Rust Pro workspace-search tests:
  - Command: `cargo test --lib --features pro-build workspace_search`
  - Working directory: `agent_core`
  - Result: PASS (`19 passed; 0 failed`)
- Full Rust Pro registry tier tests:
  - Command: `cargo test --lib --features pro-build tools::registry::tier_tests`
  - Working directory: `agent_core`
  - Result: PASS (`31 passed; 0 failed`)
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `rustfmt --edition 2024 --check agent_core/src/tools/workspace_search.rs` passed.
  - `git diff --check` passed.

### Notes

- This does not add a new search engine or memory substrate. It keeps the existing mmap-backed code-search helpers honest, bounded, and reachable.

## Slice 97 — Landing Search Fake-Affordance Removal

### Findings

- The landing search control strip exposed a disabled paperclip button with `Attach (coming soon)`.
- That control had no landing file-panel/action backing; it only refocused the search field.
- The placeholder was disabled, so it was not a clickable dead path, but it was still visible user-facing chrome presenting a deferred feature as part of the v1 surface.
- The real v1 attachment/reference teaching for landing remains the shared `ComposerAttachmentEntryHints.landingPlaceholder` and the wired `@` mention/reference path.

### Changes Made

- `Epistemos/Views/Landing/LandingView.swift`
  - Removed the disabled paperclip/attach button from `landingSearchControlsRow`.
  - Updated the row comment to describe only paths that are actually wired on landing: send, mention, and cache.
- `EpistemosTests/ComposerAttachmentEntryAuditTests.swift`
  - Added source guards that landing does not reintroduce `Attach (coming soon)`, the disabled `Label("attach", systemImage: "paperclip")`, or the old `visual-only placeholder` comment.
  - Preserved the existing guard that landing still uses `ComposerAttachmentEntryHints.landingPlaceholder`.

### Verification

- Focused Swift composer attachment audit:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/ComposerAttachmentEntryAuditTests`
  - Result: PASS (Swift Testing: `1 test in 1 suite passed`)
  - Result bundle: `build/xcode-results/2026-05-08-004802-16634.xcresult`
- Formatting/whitespace:
  - `git diff --check` passed.

### Notes

- This does not remove file attachment support from the real composer paths.
- Landing can expose a paperclip again only after the file-panel flow is actually wired and tested there.

## Slice 98 — Spend Dashboard Cost Honesty

### Findings

- The Settings Agent spend tab showed real `session_metrics` token/cache rows but mapped provider to `"—"` and `estimatedCostUSD` to `0.0`.
- `CostDashboardView` rendered those untracked values as real `$0.00` totals and per-row costs, which made missing provider/cost telemetry look like measured zero spend.
- The `session_metrics` schema currently supports token/cache transparency, not per-session provider pricing.

### Changes Made

- `Epistemos/Views/Cost/CostDashboardView.swift`
  - Changed `CostDashboardEntry.provider` and `estimatedCostUSD` to optional values.
  - Renders total cost as `—` when no tracked costs exist.
  - Renders per-row cost as `Not tracked` when a session has token telemetry but no provider cost estimate.
  - Keeps cache-hit and token telemetry visible without inventing zero-dollar costs.
- `Epistemos/Views/Settings/AgentSectionDetailView.swift`
  - Maps `session_metrics` provider and per-session cost to `nil` until the schema tracks those fields.
  - Updates Settings copy/comments to describe token usage, cache rate, and budget cap rather than placeholder cost estimates.
- `EpistemosTests/SettingsCategoryTests.swift`
  - Adds a source guard that prevents reintroducing `estimatedCostUSD: 0.0`, `provider: "—"`, `$0.00 placeholder`, or the old placeholder comment language.

### Verification

- First focused Settings run:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/SettingsCategoryTests`
  - Result: FAIL, source guard caught a stale `$0.00 placeholder` comment.
  - Result bundle: `build/xcode-results/2026-05-08-005443-44644.xcresult`
- Focused Settings rerun after comment fix:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/SettingsCategoryTests`
  - Result: PASS (Swift Testing: `9 tests in 1 suite passed`)
  - Result bundle: `build/xcode-results/2026-05-08-005732-53224.xcresult`
- App-review audit:
  - Command: `./Tools/app-review-audit/app-review-audit.sh`
  - Result: PASS.
- Formatting/whitespace:
  - `git diff --check` passed.

### Notes

- This does not add a pricing engine or schema migration.
- Provider names and per-session costs should only appear after `session_metrics` stores measured/provider-priced cost data.

## Slice 99 — Companion Adapter Hot-Swap Gate

### Findings

- The Landing Farm companion context menu exposed `Apply Adapter...`.
- That route opened `CompanionAdapterView`, which accepted a pasted path and used a sleep-based unwrap animation to report a settled state.
- The MLX LoRA adapter loader, file validation, and rollback path are not wired for v1, so this was a visible fake apply flow.

### Changes Made

- `Epistemos/Views/Landing/Farm/CompanionRoamingField.swift`
  - Removed the `Apply Adapter...` context-menu item.
  - Removed the unused `onApplyAdapter` callback from the roaming field.
- `Epistemos/Views/Landing/Farm/LandingFarmView.swift`
  - Removed the adapter callback pass-through and updated the context-menu documentation to only claim Activate/Delete.
- `Epistemos/Views/Landing/LandingView.swift`
  - Removed the `farmAdapterTarget` sheet state and the `CompanionAdapterView` sheet mount.
- `Epistemos/Views/Landing/Farm/CompanionAdapterView.swift`
  - Preserves the scaffold as an honest deferred panel.
  - Removes path input, fake unwrap action, `Task.sleep`, and fake settled success.
- `EpistemosTests/CompanionAvatarGrammarSourceGuardTests.swift`
  - Adds a source guard preventing the landing menu/sheet route and fake sleep-to-success adapter flow from returning.

### Verification

- Focused Swift companion source guards:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/CompanionAvatarGrammarSourceGuardTests`
  - Result: PASS (Swift Testing: `5 tests in 1 suite passed`)
  - Result bundle: `build/xcode-results/2026-05-08-010529-81565.xcresult`

### Notes

- This does not delete the adapter scaffold.
- Adapter hot-swap should return only after the real MLX loader, path validation, permission model, and rollback behavior are wired and tested.

## Slice 100 — CoreML Device-Action Backend Deferral

### Findings

- `AppBootstrap` selected `CoreMLActionBackendLoader.loadIfAvailable()` before AppleOnDevice/SharedGPU when a compiled model bundle existed under Application Support.
- `CoreMLActionBackend.generate` did not run model inference; it returned low-confidence fake JSON with `coreml-action-backend-stub`.
- Because the backend became the selected backend, this did not transparently fall through to the live LLM/device-action backends.

### Changes Made

- `Epistemos/Omega/Inference/DeviceAgentService.swift`
  - Adds `DeviceAgentError.backendUnavailable`.
  - Keeps the CoreML loader slot source-preserved but hard-gated by `actionModelFeatureMappingEnabled = false`.
  - Makes `loadIfAvailable` return `nil` until CoreML action-model input/output feature mapping is implemented.
  - Changes direct `CoreMLActionBackend.generate` calls to throw `backendUnavailable` instead of returning fake selector JSON.
- `EpistemosTests/DeviceAgentServiceTests.swift`
  - Adds a source guard that requires the disabled feature-mapping gate, honest unavailable throw, and absence of `coreml-action-backend-stub`.

### Verification

- Focused Swift device-agent tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/DeviceAgentServiceTests`
  - Result: PASS (Swift Testing: `7 tests in 1 suite passed`)
  - Result bundle: `build/xcode-results/2026-05-08-010956-99575.xcresult`

### Notes

- This does not remove the future CoreML action-model slot.
- The gate should only open after real feature mapping, model validation, failure behavior, and rollback are implemented and tested.

## Slice 101 — FSRS Fallback Honesty

### Findings

- `FSRSDecayStore.recordReview` correctly preferred the Rust `fsrs` scheduler for D/S/R updates when the generated bridge is available.
- The failure log still described the Swift fallback as a `placeholder update`.
- That fallback is not a fake scheduler, but it is degraded: it records timestamp, grade, review count, and resets retrievability without updating difficulty/stability.

### Changes Made

- `Epistemos/Engine/FSRSDecayState.swift`
  - Renamed the Rust-scheduler failure log to `falling back to minimal Swift review-state update`.
  - Updated the `recordReview` doc comment to state the exact degraded fallback contract.
- `EpistemosTests/FSRSDecayStateTests.swift`
  - Added a source guard requiring the minimal-fallback wording, requiring the difficulty/stability limitation, and rejecting the old `placeholder update` text.

### Verification

- Focused Swift FSRS tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/FSRSDecayStateTests`
  - Result: PASS (Swift Testing: `13 tests in 1 suite passed`)
  - Result bundle: `build/xcode-results/2026-05-08-011605-23402.xcresult`

### Notes

- This does not invent Swift-side FSRS scheduling math.
- The Rust bridge remains the authoritative scheduler path for difficulty/stability updates.

## Slice 102 — Resonance FFI Honesty

### Findings

- `agent_core/src/bridge.rs` already exports `compute_resonance_signature_core`.
- The generated Swift bridge already exposes `computeResonanceSignatureCore(claimJson:)`.
- `ResonanceService` had stale source comments and diagnostics that still called the FFI status a stub and counted `stubFallbackCount`.
- `ResonanceChip` and `ResonanceLegendView` remain preview/source-preserved UI; no production call sites were found outside `Epistemos/Views/Resonance/*.swift`.

### Changes Made

- `Epistemos/Engine/ResonanceService.swift`
  - Re-labeled the service as FFI-wired when `agent_coreFFI` is linked.
  - Renamed the fallback path from `computeStub(for:)` to `computeSwiftMirror(for:)`.
  - Renamed `stubFallbackCount` to `swiftMirrorFallbackCount`.
  - Changed the failure log from `Swift stub` to `Swift mirror`.
- `EpistemosTests/ResonanceServiceTests.swift`
  - Added a source guard that requires FFI-wired wording, bridge-entrypoint evidence, and mirror fallback naming while rejecting stale stub labels.

### Verification

- Focused Swift resonance tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/ResonanceServiceTests`
  - Result: PASS (Swift Testing: `17 tests in 1 suite passed`)
  - Result bundle: `build/xcode-results/2026-05-08-012120-59214.xcresult`
- Production mount scout:
  - Command: `rg -n "ResonanceChip\\(|ResonanceLegendView\\(" Epistemos --glob '*.swift' --glob '!Epistemos/Views/Resonance/*.swift'`
  - Result: no production mounts found.
- Repository gates:
  - `git diff --check`: PASS
  - `./Tools/app-review-audit/app-review-audit.sh`: PASS

### Notes

- This does not add a user-facing resonance surface.
- The preview chip/legend should stay source-preserved until a real runtime emission and mount policy exists.

## Slice 103 — Artifact Host Deferred Gate

### Findings

- `ArtifactRoute` is a useful typed route-identity spine, and existing tests already cover route/kind parity.
- `ArtifactHostView` was not mounted in production, but its route bodies displayed internal `T+4.x` pending-slice labels if the host was accidentally invoked.
- The file comments also described route identity as a renderable destination more strongly than the current v1 implementation supports.

### Changes Made

- `Epistemos/Views/Workspace/ArtifactHostView.swift`
  - Re-labeled the host as source-preserved and not a v1 production navigation surface.
  - Renamed `ArtifactRoutePendingPanel` to `ArtifactRouteDeferredPanel`.
  - Replaced internal pending-slice copy with v1-safe deferred reasons.
- `Epistemos/Models/ArtifactRoute.swift`
  - Tightened comments from "renderable surface" to "route identity" so the model does not over-claim shipped viewers.
- `EpistemosTests/ArtifactRouteTests.swift`
  - Added a source guard requiring the deferred panel naming/copy.
  - Added a production Swift source scan that fails if `ArtifactHostView(` is mounted outside its own file while every destination remains deferred.

### Verification

- Focused Swift artifact route tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/ArtifactRouteTests`
  - Result: PASS (Swift Testing: `6 tests in 1 suite passed`)
  - Result bundle: `build/xcode-results/2026-05-08-012951-13606.xcresult`
- Repository gates:
  - `git diff --check`: PASS
  - `./Tools/app-review-audit/app-review-audit.sh`: PASS

### Notes

- This does not delete the artifact route scaffold.
- The host should only become a production navigation surface after real note/document/run/source/code/output resolvers are implemented and tested.

## Slice 104 — Omega Retired Orchestrator Fail-Closed

### Findings

- `OmegaPanel` is still reachable from the utility-window manager, but it only shows a retired/unified-chat message.
- `MainChatSubmissionRouter` routes `.agent` mode through main chat/Rust `agent_core`, not through `OrchestratorState`.
- `OrchestratorState.submitTask` was a silent no-op if called directly.
- The retired compatibility state still used `Stub` type/comment names, which made source audits noisier than the actual runtime status.

### Changes Made

- `Epistemos/Omega/Orchestrator/OrchestratorState.swift`
  - Re-labeled the class as a retired compatibility shim.
  - Changed direct `submitTask` calls to fail closed with `planningError = "Omega task execution is retired; use unified chat."`.
  - Records a failed `AgentStepResult` instead of silently accepting work.
  - Renamed retired compatibility state classes away from `Stub` naming.
- `EpistemosTests/OmegaConfirmationGateTests.swift`
  - Added direct behavior coverage for `submitTask`.
  - Added a source guard rejecting stale `stub` / `no-op` labels in `OrchestratorState.swift`.

### Verification

- Focused Swift Omega retired-orchestrator tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/OmegaRetiredOrchestratorTests`
  - Result: PASS (Swift Testing: `2 tests in 1 suite passed`)
  - Result bundle: `build/xcode-results/2026-05-08-013544-41907.xcresult`
- Repository gates:
  - `git diff --check`: PASS
  - `./Tools/app-review-audit/app-review-audit.sh`: PASS

### Notes

- This does not remove the compatibility shim; `AppBootstrap`, `ChatView`, and `LandingView` still inject/read it while migration is incomplete.
- The v1 task execution path remains the fused main-chat/Rust-agent path, not Omega.

## Slice 105 — Omega Retired Companion Views

### Findings

- `ExecutionProgressView` and `ConfirmationSheet` still carried stale `(Stub)` source labels even though the Omega path is retired.
- `ResearchRequestView` was already empty, but lacked the same retired-compatibility framing.
- `TaskInputBar` had no production mounts, but would render a dead Omega task field/button if accidentally mounted.
- Production source scouting found no call sites for `ExecutionProgressView(`, `ConfirmationSheet(`, `ResearchRequestView(`, or `TaskInputBar(` outside their own declarations.

### Changes Made

- `Epistemos/Views/Omega/ExecutionProgressView.swift`
  - Re-labeled as a retired compatibility view and kept `EmptyView`.
- `Epistemos/Views/Omega/ConfirmationSheet.swift`
  - Re-labeled as a retired compatibility view and kept `EmptyView`.
- `Epistemos/Views/Omega/ResearchRequestView.swift`
  - Added the same retired compatibility label and kept `EmptyView`.
- `Epistemos/Views/Omega/TaskInputBar.swift`
  - Re-labeled as retired compatibility.
  - Removed the live text field/button body so accidental mounts cannot show dead Omega task-entry UI.
- `EpistemosTests/OmegaConfirmationGateTests.swift`
  - Added source guards requiring retired labels and empty bodies.
  - Rejects stale `stub` labels in those retired views.
  - Scans production Swift sources and fails if any retired Omega companion view is mounted while Omega remains retired.

### Verification

- Focused Swift Omega retired-orchestrator tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/OmegaRetiredOrchestratorTests`
  - Result: PASS (Swift Testing: `3 tests in 1 suite passed`)
  - Result bundle: `build/xcode-results/2026-05-08-014231-68783.xcresult`
- Repository gates:
  - `git diff --check`: PASS
  - `./Tools/app-review-audit/app-review-audit.sh`: PASS

### Notes

- This does not delete the retired Omega scaffold.
- The v1 user-facing path remains main chat plus the Rust `agent_core` permission/tool flow.

## Slice 106 — Shadow Fallback Provenance Honesty

### Findings

- The v1 app path already opens persistent Shadow `RealBackend` through `RustShadowFFIClient`.
- The pre-open/test fallback path in `epistemos-shadow/src/state.rs` still described itself as a W8.1 stub and emitted `source: "stub-substring"`.
- Swift's in-memory `InMemoryShadowFFIClient` mirrored that stale source label, and `HaloState` documented `stub-substring` as a possible provenance value.
- This was a source/diagnostic honesty issue, not a request to remove the fallback: pre-open and deterministic tests still need the in-memory path.

### Changes Made

- `epistemos-shadow/src/state.rs`
  - Re-labeled `ShadowState` as an in-memory fallback backend.
  - Renamed the fallback singleton from `STUB_FALLBACK` to `IN_MEMORY_FALLBACK`.
  - Changed fallback hit provenance from `stub-substring` to `in-memory-substring`.
  - Added a Rust assertion that fallback search emits the honest source label.
- `epistemos-shadow/src/lib.rs`
  - Updated module docs to describe app bootstrap opening `RealBackend` and the fallback as pre-open/test only.
  - Expanded the `ShadowHit.source` docs to include `in-memory-substring`.
- `epistemos-shadow/src/backend/mod.rs`
  - Replaced stale "future real backend" and stub wording with current `RealBackend` + fallback wording.
- `Epistemos/Engine/ShadowFFIClient.swift`
  - Updated the in-memory test client to emit `in-memory-substring`.
- `Epistemos/Engine/RustShadowFFIClient.swift`
  - Removed stale W8.1 scaffold wording around the DTO bridge.
- `Epistemos/Models/HaloState.swift`
  - Updated provenance examples to include `in-memory-substring` instead of `stub-substring`.
- `EpistemosTests/ShadowServicesTests.swift`
  - Added a Swift source guard rejecting `stub-substring`, `W8.1 stub`, `ShadowState stub`, and `STUB_FALLBACK` across the Shadow fallback surface.
  - Added direct coverage that the Swift in-memory client returns `in-memory-substring`.

### Verification

- Rust Shadow state tests:
  - Command: `cargo test --lib state::tests` from `epistemos-shadow`
  - Result: PASS (`14 passed; 0 failed; 36 filtered out`)
- Focused Swift Shadow service tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/ShadowServicesTests`
  - Result: PASS (Swift Testing: `21 tests in 1 suite passed`)
  - Result bundle: `build/xcode-results/2026-05-08-014946-9637.xcresult`
- Repository gates:
  - `git diff --check`: PASS
  - `./Tools/app-review-audit/app-review-audit.sh`: PASS

### Notes

- This does not change the production `RealBackend` path.
- The fallback remains source-preserved for deterministic pre-open/test behavior only.

## Slice 107 — Code Index / AgentGrep Fallback Provenance Honesty

### Findings

- `epistemos-code-index` is built by the app build scripts, but `AgentGrepService` currently has no production mount/call site.
- The Rust fallback indexer still described itself as W9.7 stub/base scaffold and emitted `source: "stub-substring"`.
- Swift's in-memory code-index client mirrored the same stale source label.
- This was a provenance-honesty issue: the fallback and test client are useful, but v1 should not make them look like a production persistent code-search backend.

### Changes Made

- `epistemos-code-index/src/state.rs`
  - Re-labeled the fallback as an in-memory backend.
  - Changed fallback hit provenance from `stub-substring` to `in-memory-substring`.
  - Added a Rust assertion that fallback search emits the honest source label.
- `epistemos-code-index/src/lib.rs`
  - Updated public docs to describe the base as an explicitly labeled in-memory fallback indexer.
  - Expanded `CodeIndexHit.source` docs to include `in-memory-substring`.
- `epistemos-code-index/Cargo.toml`
  - Reworded the package comment from base scaffold to base fallback.
- `Epistemos/Engine/AgentGrepService.swift`
  - Re-labeled the in-memory backend client and queue.
  - Renamed `StubCodeIndexClient` to `InMemoryCodeIndexClient` and changed error domains to behavior-based naming.
  - Changed Swift test-client provenance from `stub-substring` to `in-memory-substring`.
- `EpistemosTests/AgentGrepServiceTests.swift`
  - Added direct provenance coverage for `in-memory-substring`.
  - Added a source guard rejecting stale `stub-substring`, `W9.7 stub`, `stub backend`, `codeindex.stub`, and `StubCodeIndexClient` labels across the Rust/Swift fallback surface.

### Verification

- Rust code-index state tests:
  - Command: `cargo test --lib state::tests` from `epistemos-code-index`
  - Result: PASS (`13 passed; 0 failed; 5 filtered out`)
- Focused Swift AgentGrep service tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/AgentGrepServiceTests`
  - Result: PASS (Swift Testing: `11 tests in 1 suite passed`)
  - Result bundle: `build/xcode-results/2026-05-08-020024-65873.xcresult`
- Repository gates:
  - `git diff --check`: PASS
  - `./Tools/app-review-audit/app-review-audit.sh`: PASS

### Notes

- This does not claim AgentGrep is production-wired.
- Next safe promotion would require a real Swift FFI/client path plus app reachability before exposing it as shipped code search.

## Slice 108 — Graph Inspect Mode Fake-Layer Gate

### Findings

- `GraphInspectModeView` was not mounted by production Swift sources.
- The preserved file still rendered synthetic circle/parallax layers and included comments describing missing production graph-layer rendering.
- v1 already has the live graph path through `MetalGraphView` plus `HologramNodeInspector`; the inspect shell should not show fake graph UI if accidentally mounted.

### Changes Made

- `Epistemos/Views/Graph/GraphInspectModeView.swift`
  - Re-labeled the file as a deferred inspect-mode shell.
  - Replaced the synthetic circle/parallax renderer with an empty accessibility-hidden body.
  - Kept `enterInspectMode` / `exitInspectMode` compatibility hooks source-preserved, with no UI mount.
- `EpistemosTests/GraphPhysicsSettingsAuditTests.swift`
  - Added a source guard rejecting the old placeholder rendering language, `Circle()` fallback, parallax marketing copy, and auto-enter behavior.
  - Added a production-source scan that fails if `GraphInspectModeView` or `enterInspectMode()` becomes mounted while the shell is deferred.

### Verification

- Focused Swift graph audit tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/GraphPhysicsSettingsAuditTests`
  - Result: PASS (Swift Testing: `18 tests in 1 suite passed`)
  - Result bundle: `build/xcode-results/2026-05-08-020604-92377.xcresult`

### Notes

- This does not remove the inspect-mode scaffold.
- Promotion requires real graph subset extraction/rendering; until then, v1 should continue using the existing graph overlay and node inspector.

## Slice 109 — Visual Intelligence Intent Deferred Gate

### Findings

- Apple's `visualIntelligence.semanticContentSearch` schema is iOS-only in the SDK surfaced here, so it is not a macOS v1 feature.
- `VisualIntelligenceIntents.swift` still described the macOS facade as a stub and said the future bridge was safe to ship for forward compatibility.
- The iOS `@AppIntent(schema:)` block had no explicit Epistemos release gate, while pixel-buffer conversion still returns `nil`.

### Changes Made

- `Epistemos/Intents/Schemas/VisualIntelligenceIntents.swift`
  - Re-labeled the macOS side as a deferred facade.
  - Added `unavailableOnMacOSMessage` and logs it when the macOS search hook is called.
  - Removed stale stub wording and avoided claiming shipped visual search.
  - Wrapped the iOS Visual Intelligence App Intent bridge and hook behind `EPISTEMOS_ENABLE_VISUAL_INTELLIGENCE_INTENT`.
  - Fixed the deferred iOS bridge call site to await pixel-buffer conversion if the bridge is ever deliberately enabled.
- `EpistemosTests/IndexedEntityTests.swift`
  - Added source/behavior coverage requiring the explicit compile-time gate, rejecting stub wording, and checking the macOS facade returns no results with an unavailable/deferred message.

### Verification

- Focused Swift App Intent entity tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/IndexedEntityTests`
  - Result: PASS (Swift Testing: `10 tests in 1 suite passed`)
  - Result bundle: `build/xcode-results/2026-05-08-021130-17495.xcresult`

### Notes

- This does not implement Visual Intelligence or image-note retrieval.
- Promotion requires real pixel-buffer conversion, actual image-note search, and a deliberate build flag before the App Intent can be exposed.

## Slice 110 — Code Editor LSP Runtime Gate Honesty

### Findings

- The code editor's on-demand semantic LSP hover/definition path is now real when `agent_coreFFI` is linked, but `CodeEditorSemanticLSP.isSupported(language:)` only checked language.
- In a build without the Rust FFI module, Swift/Rust files could still show enabled Inspect Symbol / Go to Definition controls, then fail only after the user clicked.
- `InProcessLSPTransport` is intentionally useful for lifecycle tests, but comments and errors still called it a stub and referenced a future tower-lsp transport that already landed.
- `RustLSPTransport`'s no-FFI fallback returned an FFI error even after shutdown instead of preserving the same fail-closed shutdown semantics as the linked transport.

### Changes Made

- `Epistemos/Views/Notes/CodeEditorView.swift`
  - Split language support from runtime availability with `supportsLanguage`, `runtimeAvailable`, and `canRun`.
  - Disabled visible LSP buttons unless both the language and Rust runtime are available.
  - Reused an explicit unavailable message for tooltips, hover requests, and definition requests when the runtime is unlinked.
- `Epistemos/Engine/LSPTransport.swift`
  - Re-labeled `InProcessLSPTransport` as a test-only lifecycle double.
  - Removed stale "not implemented yet" / future tower-lsp wording from its behavior and error text.
- `Epistemos/Engine/RustLSPTransport.swift`
  - Re-labeled the no-FFI branch as an unlinked fail-closed implementation.
  - Preserved `transportShutdown` behavior after shutdown even when `agent_coreFFI` is not linked.
- `Epistemos/Engine/LSPMessage.swift` and `Epistemos/Engine/LSPClient.swift`
  - Updated stale SourceKit/subprocess and stub-mode comments to match the in-process Rust runtime.
- `EpistemosTests/CodeEditorPolishTests.swift`, `EpistemosTests/LSPTransportTests.swift`, `EpistemosTests/LSPClientTests.swift`, `EpistemosTests/RustLSPTransportTests.swift`
  - Added/updated coverage for runtime availability gating, test-only transport labeling, and no-FFI shutdown behavior.

### Verification

- Focused Swift LSP/code-editor tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/CodeEditorPolishTests -only-testing:EpistemosTests/LSPTransportTests -only-testing:EpistemosTests/LSPClientTests -only-testing:EpistemosTests/RustLSPTransportTests`
  - Result: PASS (Swift Testing: `45 tests in 4 suites passed`)
  - Result bundle: `build/xcode-results/2026-05-08-022026-62284.xcresult`

### Notes

- This does not add diagnostics gutters, completion, cross-file navigation, project-wide symbol indexing, or `.epdoc` code-card LSP.
- Manual UI click/selection smoke is still not claimed from terminal-only verification.

## Slice 111 — Knowledge Fusion Adapter Auto-Activation Gate

### Findings

- `TrainOnVaultView` already told users the output is an adapter they can activate later.
- `TrainingScheduler` also documents that automatic deployment is disabled for v1.
- `KnowledgeFusionViewModel.trainOnVault` contradicted that contract by immediately calling `registry.setActive(record.id, active: true)` on the newly registered adapter, then reporting `adapter active` even though no quality/deploy evaluator is wired.

### Changes Made

- `Epistemos/KnowledgeFusion/UI/KnowledgeFusionViewModel.swift`
  - Replaced the old `evaluating` state with an honest `registering` state.
  - Removed immediate activation after `registry.register(record)`.
  - Refreshes `activeAdapter` from `registry.getActiveAdapters().first` instead of assuming the new adapter is active.
  - Changed completion copy to `Complete — adapter registered, activate after review`.
- `Epistemos/KnowledgeFusion/UI/TrainOnVaultView.swift`
  - Updated progress rendering for the new `registering` state.
- `EpistemosTests/KnowledgeFusionUITests.swift`
  - Added a source guard that rejects reintroducing immediate `setActive(record.id, active: true)` or `activeAdapter = record` in the registration slice.
  - Locks the user-visible completion text to the inactive/manual-review contract.

### Verification

- Focused Swift Knowledge Fusion view-model tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/KnowledgeFusionViewModelTests`
  - Result: PASS (Swift Testing: `8 tests in 1 suite passed`)
  - Result bundle: `build/xcode-results/2026-05-08-022628-1661.xcresult`
- Repository gates:
  - `git diff --check`: PASS
  - `./Tools/app-review-audit/app-review-audit.sh`: PASS

### Notes

- This does not remove train-on-vault or adapter activation.
- v1 now preserves the manual review boundary: training can register an adapter, but activation remains explicit until a real quality/deploy gate exists.

## Slice 112 — Notes Sidebar Vault Selector No-Op Gate

### Findings

- `NotesSidebar` mounted `VaultSelectorView` with one active `Current vault` row.
- The row passed a no-op `onSelect` closure with a comment saying the multi-vault data source would land later.
- `VaultLifecycleService` does not expose `knownVaults` or `switchVault(to:)` in the current code, so presenting this as a live selector was misleading.

### Changes Made

- `Epistemos/Views/Sidebar/VaultSelectorView.swift`
  - Added an explicit `selectionEnabled` gate.
  - Made `onSelect` optional.
  - Rows render as buttons only when selection is enabled, the row is inactive, and a real handler exists.
  - Active/read-only rows render as combined accessibility content instead of clickable buttons that return immediately.
  - Updated file comments to describe the v1 read-only status contract honestly.
- `Epistemos/Views/Notes/NotesSidebar.swift`
  - Replaced the no-op selection closure with `selectionEnabled: false`.
  - Re-labeled the mounted row as active-vault status until a real known-vault list and switch path are mounted.
- `EpistemosTests/NoteWindowManagerTests.swift`
  - Added `VaultSelectorSourceGuardTests.singleVaultSidebarStatusIsReadOnly`.

### Verification

- Focused Swift vault-selector source guard:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/VaultSelectorSourceGuardTests`
  - Result: PASS (Swift Testing: `1 test in 1 suite passed`)
  - Result bundle: `build/xcode-results/2026-05-08-024527-77888.xcresult`
- Repository gates:
  - `git diff --check`: PASS
  - `./Tools/app-review-audit/app-review-audit.sh`: PASS

### Notes

- A broader `EpistemosTests/EpdocVisibilitySourceGuardTests` run is not claimed here: it passed the new guard before stalling in a later existing Epdoc toolbar source-guard test, so the run was stopped and replaced with the isolated source-guard suite above.
- This does not implement multi-vault switching.
- Promotion requires a real known-vault data source plus a tested switch path before inactive vault rows become clickable.

## Slice 113 — EventDrain Fallback Label Honesty

### Findings

- `EventDrain` has a real Rust `substrate-rt` FFI client when `EPISTEMOS_LINK_SUBSTRATE_RT` is linked.
- The deterministic Swift in-memory path is still needed for tests and pre-link fallback behavior.
- Comments and the dispatch-queue label still called that path a stub, which made the fallback look less deliberate and less clear than it is.

### Changes Made

- `Epistemos/Engine/EventDrain.swift`
  - Re-labeled `InMemoryEventRingClient` as the in-memory fallback/test client.
  - Replaced stale test/rest-of-app wording with pre-link fallback wording.
  - Renamed the queue label from `com.epistemos.eventring.stub` to `com.epistemos.eventring.in-memory`.
- `EpistemosTests/EventDrainTests.swift`
  - Added a source guard that requires fallback/test labeling and rejects stale `stub` wording for the in-memory event ring surface.

### Verification

- Focused Swift EventDrain tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/EventDrainTests`
  - Result: PASS (Swift Testing: `12 tests in 1 suite passed`)
  - Result bundle: `build/xcode-results/2026-05-08-025114-4401.xcresult`
- Repository gates:
  - `git diff --check`: PASS
  - `./Tools/app-review-audit/app-review-audit.sh`: PASS

### Notes

- This does not change event-ring authority or add a new memory substrate.
- The fallback stays deterministic for tests and pre-link builds; production event-ring claims remain tied to the linked Rust FFI client.

## Slice 114 — MoLoRA Prompt-Level Routing Honesty

### Findings

- `AdapterRouter.routeToken` was already a nil-returning Swift per-token scaffold.
- The optional Python MoLoRA subprocess chooses one adapter for a generation from prompt hidden states; it is not a token-by-token router.
- Comments and docs still implied Python-side AdaFuse handled Swift per-token routing, and `MoLoRAInferenceService.start` had an unconditional `|| true` state guard.

### Changes Made

- `Epistemos/KnowledgeFusion/Adapters/AdapterRouter.swift`
  - Re-labeled `moloraPerToken` as a deferred v1 scaffold until a kernel path exists.
  - Documented that Swift-side per-token routing is intentionally unavailable in v1.
  - Removed the stale claim that Python-side AdaFuse handles the Swift per-token hook.
- `Epistemos/KnowledgeFusion/Adapters/MoLoRARouter.swift`
  - Clarified the v1 split between Swift intent routing and optional Pro prompt-level decide-once MoLoRA.
- `Epistemos/KnowledgeFusion/MoLoRA/MoLoRAInferenceService.swift`
  - Reworded generation comments around prompt-level decide-once routing from layer-0 hidden states.
  - Replaced the unconditional startup guard with a real loading/generating reentry guard.
- `Epistemos/KnowledgeFusion/MoLoRA/molora_inference.py`
  - Renamed the service docs from per-token routing to decide-once prompt-level routing.
- `docs/knowledge-fusion/architecture.md`
  - Documented that the per-token Swift interface is source-preserved but inactive for v1.
- `EpistemosTests/AdapterManagementTests.swift`
  - Added a source guard that rejects stale per-token runtime claims, stale Python-side "handled" wording, and the unconditional `|| true` state guard.

### Verification

- Focused Swift AdapterRouter tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/AdapterRouterTests`
  - Result: PASS (Swift Testing: `6 tests in 1 suite passed`)
  - Result bundle: `build/xcode-results/2026-05-08-030417-81618.xcresult`
- Repository gates:
  - `git diff --check`: PASS
  - `./Tools/app-review-audit/app-review-audit.sh`: PASS

### Notes

- This does not add HELIOS substrate, new V6 stages, or a speculative per-token kernel.
- v1 can ship request-level adapter routing plus optional Pro prompt-level decide-once MoLoRA, but token-by-token MoLoRA remains deferred until a measured kernel path is implemented.

## Slice 115 — Adapter Export Metadata Test Hardening

### Findings

- `AdapterExporterTests.roundTrip` contained `#expect(imported.metadata.adapterType == "" || true)`, so metadata loss could never fail the test.
- The shared adapter test fixture wrote hardcoded `knowledge` / rank-32 metadata even when the requested `AdapterRecord` type or rank differed.
- A source guard in the same file still depended on the old bundled AdapterAudit helper instead of the current source-mirror support.

### Changes Made

- `EpistemosTests/AdapterManagementTests.swift`
  - Made `makeTestAdapter` throwing instead of using `try!`.
  - Wrote fixture metadata from the requested adapter type and rank.
  - Changed the export/import round-trip to assert exact imported metadata type, rank, and target modules.
  - Added a source guard rejecting unconditional metadata assertions, stale "empty from test stub" comments, and `try!` in the adapter management tests.
  - Updated the adapter no-fusion source guard to read production adapter files through `loadMirroredSourceTextFile`.

### Verification

- Focused Swift adapter export/import tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/AdapterExporterTests -only-testing:EpistemosTests/AdapterFusionSafetyTests`
  - Result: PASS (Swift Testing: `5 tests in 2 suites passed`)
  - Result bundle: `build/xcode-results/2026-05-08-031421-37614.xcresult`
- Repository gates:
  - `git diff --check`: PASS
  - `./Tools/app-review-audit/app-review-audit.sh`: PASS

### Notes

- This does not change adapter bundle format or activation policy.
- The first focused run failed at compile because of the stale bundled-source helper; the final run passed after the source guard was moved to the repo source mirror.

## Slice 116 — Code Editor Large-File Viewport Hardening

### Findings

- The live editor should remain native `CodeEditSourceEditor`; replacing it with a WebKit/CodeMirror island is not justified for v1.
- The sidecar indentation-guide overlay still parsed every line after edit refreshes, and for large buffers its scroll debounce only shifted an already-parsed range instead of refreshing the visible range.
- The dormant right-side fallback gutter was hidden in v1, but its update path could still hydrate line state if re-enabled, and `CodeLineGutterView` prebuilt one line-number string per line.

### Changes Made

- `Epistemos/Views/Notes/CodeEditorView.swift`
  - Added `CodeEditorLargeFilePolicy` with explicit 100k-character/10k-line gates and bounded visible-line windows.
  - Kept line counting as a pure nonisolated helper for tests and Swift 6 default-isolation safety.
  - Routed large-file indentation-guide refreshes through viewport line ranges on scroll.
  - Avoided full line-count recomputation during guide refresh when the coordinator already has the current count.
  - Kept the dormant fallback gutter cache cold while hidden and hydrated it only if deliberately re-enabled.
- `Epistemos/Views/Notes/SegmentedIndentationGuideView.swift`
  - Added optional viewport `lineRange` parsing.
  - Reserved only the requested window and stopped scanning once the upper bound is passed.
- `Epistemos/Views/Notes/CodeLineGutter.swift`
  - Replaced eager `numberStrings` growth with a visible-line `numberStringCache`.
- `EpistemosTests/CodeEditorPolishTests.swift`
  - Added 100k-line line-metrics coverage, bounded viewport policy coverage, huge-file gutter range coverage, and source guards for the large-file sidecar paths.

### Verification

- Focused Swift code-editor tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/CodeEditorPolishTests`
  - Result: PASS (Swift Testing: `28 tests in 1 suite passed`)
  - Result bundle: `build/xcode-results/2026-05-08-040932-24380.xcresult` (latest warning-clean rerun after explicit pure-helper `nonisolated` markers)

### Notes

- `docs/APP_ISSUES_AUTO_FIX.md` issue `ISSUE-2026-05-07-001` is promoted to `Patched`, not `Verified Fixed`.
- Manual launched-app verification remains required: open a large Swift/Rust file, smoke scroll/edit/search/LSP actions, then run Time Profiler and Animation Hitches before claiming runtime fluidity fixed.

## Slice 117 — Shadow In-Memory FFI Naming

### Findings

- The Shadow fallback provenance fix was semantically correct, but the Swift deterministic fallback client still carried stale "stub" naming in production source.
- `ShadowFFIClient.swift` exposed `StubShadowFFIClient` and a `com.epistemos.shadow.stub` queue label even though the current doctrine is "in-memory fallback/test client", not a shipped stub backend.
- Root/consolidated Halo docs still pointed readers at the obsolete test-client name.

### Changes Made

- `Epistemos/Engine/ShadowFFIClient.swift`
  - Renamed the deterministic fallback client to `InMemoryShadowFFIClient`.
  - Renamed the serial queue label to `com.epistemos.shadow.in-memory`.
  - Reworded comments around protocol testing, default timing behavior, and warm no-op behavior to use in-memory fallback wording.
- `EpistemosTests/ShadowServicesTests.swift`
  - Updated the helper/tests to use `InMemoryShadowFFIClient`.
  - Extended the Shadow fallback provenance guard to reject `StubShadowFFIClient` and `com.epistemos.shadow.stub` in production Shadow source.
- `EpistemosTests/ShadowVaultBootstrapperTests.swift`
  - Updated bootstrapper tests to use the renamed in-memory client.
- `CLAUDE.md` and `docs/_consolidated/00_canonical_authority/CLAUDE.md`
  - Updated the Halo implementation map to reference `InMemoryShadowFFIClient`.

### Verification

- Focused Swift Shadow tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/ShadowServicesTests -only-testing:EpistemosTests/ShadowVaultBootstrapperTests`
  - Result: PASS (Swift Testing: `33 tests in 2 suites passed`)
  - Result bundle: `build/xcode-results/2026-05-08-034007-66697.xcresult`

### Notes

- This is a naming/provenance hardening change only; it does not alter the app-open Shadow `RustShadowFFIClient` path or promote the fallback to a user-facing backend.

## Slice 118 — VaultChatMutator Git Subprocess Hardening

### Findings

- `VaultChatMutator` writes approved vault mutations through `VaultVerifiedFileWriter`, then direct builds add a git audit commit.
- The direct-build git path used `/usr/bin/env git` and inherited `ProcessInfo.processInfo.environment`, which could leak unrelated app secrets or dynamic-loader variables to git and repository hooks.
- The MAS branch was behaviorally honest, but still described its returned non-git reference as a "placeholder reference."

### Changes Made

- `Epistemos/Vault/VaultChatMutator.swift`
  - Switched subprocess execution from `/usr/bin/env git` to `/usr/bin/git`.
  - Replaced inherited process environment with a minimal git environment.
  - Added `GIT_TERMINAL_PROMPT=0`, `GIT_CONFIG_NOSYSTEM=1`, and `GIT_CONFIG_GLOBAL=/dev/null`.
  - Added `--no-verify` to app-created git commits so repository hooks do not execute during approval.
  - Changed the MAS return prefix from `mas-skipped-*` to `mas-file-only-*` and removed placeholder wording.
- `EpistemosTests/VaultChatMutatorTests.swift`
  - Added a source guard for the direct binary, no inherited environment, no hooks, disabled prompts, and explicit MAS file-only reference.

### Verification

- Focused Swift vault mutator tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/VaultChatMutatorTests`
  - Result: PASS (Swift Testing: `3 tests in 1 suite passed`)
  - Result bundle: `build/xcode-results/2026-05-08-034630-6362.xcresult`

### Notes

- This preserves direct-build git audit commits and MAS file-only behavior.
- The live test confirms the real git commit path still works with the minimal environment.

## Slice 119 — Knowledge Fusion Python Setup Hardening

### Findings

- `PythonEnvironmentManager` is a direct/Pro Knowledge Fusion setup path, not an App Store runtime feature.
- The setup path could bootstrap Homebrew and install Python with `curl`/`bash`/`brew install python@3.12` from inside the app, which is not v1-safe and violates the no-runtime-executable-download posture.
- The Python/pip subprocess helper inherited the full process environment, which could leak unrelated app secrets or dynamic-loader/interpreter variables into Python package tooling.
- The Python finder used `/usr/bin/env which python3`, adding another inherited-path dependency to a setup path that should be deterministic and honest.

### Changes Made

- `Epistemos/KnowledgeFusion/PythonEnvironmentManager.swift`
  - Removed in-app Homebrew installation and Python package-manager bootstrapping.
  - Replaced `which python3` discovery with deterministic local Python candidates under Homebrew, python.org framework paths, and `/usr/bin/python3`.
  - Requires an existing Python 3.10+ executable and now reports a user-install instruction if none is found.
  - Runs Python/pip subprocesses with a bounded environment instead of `ProcessInfo.processInfo.environment`.
  - Adds noninteractive pip flags: `--disable-pip-version-check` and `--no-input`.
  - Sets `PYTHONNOUSERSITE`, `PIP_DISABLE_PIP_VERSION_CHECK`, `PIP_NO_INPUT`, bounded `PATH`, locale, `HOME`, `TMPDIR`, and `VIRTUAL_ENV` where applicable.
- `EpistemosTests/RuntimeValidationTests.swift`
  - Added a source guard for local-toolchain-only Python setup, bounded subprocess environment, no inherited environment, no `/usr/bin/env`, no `which`, and no Homebrew/curl bootstrap literals.
  - Updated a stale deferred `GraphInspectModeView` source guard so the test now matches the v1 inert shell instead of expecting a fake sleep path.
- `EpistemosTests/AppStoreHardeningTests.swift`
  - Updated the Python setup marker check so App Store hardening expects the Process markers but does not preserve banned installer literals.
  - Updated the VaultChatMutator source guard to match the hardened `/usr/bin/git` path from slice 118.
- `Epistemos/Views/Notes/CodeEditorView.swift`
  - Marked the pure large-file policy constants/functions and line counter explicitly `nonisolated` so the Swift 6 default MainActor build does not warn when non-UI tests call them.

### Verification

- Focused Swift Runtime/App Store hardening tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/RuntimeValidationTests -only-testing:EpistemosTests/AppStoreHardeningTests`
  - Result: PASS (Swift Testing: `277 tests in 2 suites passed`)
  - Result bundle: `build/xcode-results/2026-05-08-040541-2338.xcresult`
- Focused Swift code-editor warning-clean rerun:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/CodeEditorPolishTests`
  - Result: PASS (Swift Testing: `28 tests in 1 suite passed`)
  - Result bundle: `build/xcode-results/2026-05-08-040932-24380.xcresult`
- Repository gates:
  - `git diff --check`: PASS
  - `./Tools/app-review-audit/app-review-audit.sh`: PASS

### Notes

- This does not add a new Python runtime or package manager to v1.
- Knowledge Fusion setup now requires the user/system to provide Python 3.10+ before the app creates its local venv.
- MAS remains compile-gated away from this setup path.

## Slice 120 — Knowledge Fusion Python Subprocess Fallback Hardening

### Findings

- The previous setup slice bounded venv creation, but several Knowledge Fusion fallback runners still spawned Python subprocesses with local ad hoc `Process` setup.
- QLoRA, KTO, AudioTranscriber, and MoLoRA needed the same v1 posture: local executable/script checks, bounded environment, bounded output capture, timeout/cancellation escape hatches, and sanitized errors.
- This remains direct/Pro behavior only; MAS should not present these Python fallbacks as runnable.

### Changes Made

- `Epistemos/KnowledgeFusion/PythonEnvironmentManager.swift`
  - Added a shared subprocess output-capture helper for Knowledge Fusion fallback tools.
  - Centralized bounded subprocess environment construction for Python fallback execution.
  - Added capped stdout/stderr reads plus timeout/cancellation termination behavior.
- `Epistemos/KnowledgeFusion/Training/QLoRATrainer.swift`
- `Epistemos/KnowledgeFusion/Alignment/KTOTrainer.swift`
- `Epistemos/KnowledgeFusion/DataIngestion/AudioTranscriber.swift`
- `Epistemos/KnowledgeFusion/MoLoRA/MoLoRAInferenceService.swift`
  - Moved fallback execution onto the shared bounded environment/output helper.
  - Added local executable/script presence checks before claiming the fallback can run.
  - Sanitized subprocess diagnostics before returning errors to the app surface.
- `EpistemosTests/RuntimeValidationTests.swift`
  - Added source coverage for bounded env/output fallback use across the Knowledge Fusion Python lanes.

### Verification

- Focused Swift Runtime/App Store hardening tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/RuntimeValidationTests -only-testing:EpistemosTests/AppStoreHardeningTests`
  - Result: PASS (Swift Testing: `278 tests in 2 suites passed`)
  - Result bundle: `build/xcode-results/2026-05-08-042521-42606.xcresult`

### Notes

- This does not install Python or any executable toolchain.
- The fallback is still direct/Pro only and must stay hidden/unavailable in MAS.

## Slice 121 — Launch Privacy, Metal Drawable, and App-Review Audit Response

### Findings

- A read-only live audit reported fresh-launch TCC logs for `kTCCServiceListenEvent` and AddressBook/contact surfaces before obvious user action.
- Source review found passive idle checks still using global `CGEventSource.secondsSinceLastEventType`, which can touch Input Monitoring/TCC-sensitive APIs during launch or background scheduling.
- The iMessage setup doctor's status path could probe Automation permission while Settings was merely rendering status.
- The live audit also reported `Each CAMetalLayerDrawable can only be presented once!` and `CAMetalLayer ignoring invalid setDrawableSize width=0 height=0`.
- The app-review audit script missed real Swift subprocess usage because it only scanned older shell forms, and `syntax-core/target/aarch64-apple-darwin/debug/libsyntax_core.rlib` was tracked despite being a generated target artifact.

### Changes Made

- `Epistemos/State/ActivityTracker.swift`
  - Removed system-wide `CGEventSource` idle probing from passive app-idle checks.
  - Tracks app-local activity uptime and exposes process-local app idle seconds.
- `Epistemos/State/NightBrainService.swift`
  - Replaced global input idle probing with process-local quiescence.
  - Added dependency readiness gating before NightBrain starts maintenance work.
- `Epistemos/KnowledgeFusion/Alignment/TrainingScheduler.swift`
  - Replaced system-wide idle probing with process-local quiescence for training/autoresearch scheduling.
- `Epistemos/Omega/iMessageDriver/IMessageNativeSetupDoctor.swift`
- `Epistemos/Views/Settings/ChannelsSettingsView.swift`
- `Epistemos/Views/Settings/IMessageDriverSettingsView.swift`
  - Made passive setup status checks avoid Automation permission probing.
  - Limited Automation probes to explicit refresh/guided setup paths.
- `Epistemos/Views/Graph/MetalGraphView.swift`
  - Uses a 1x1 paused drawable size instead of setting CAMetalLayer drawable size to zero.
- `Epistemos/Views/Landing/Wave/LandingWaveMetalView.swift`
  - Removed async `Task` rendering from `draw(in:)`.
  - Renders synchronously on the main actor with a positive-size guard and reentrancy guard so stale/current drawables are not presented after the delegate callback returns.
- `Tools/app-review-audit/app-review-audit.sh`
  - Added Swift `Process(`, `Process.init(`, and `Pipe()` scanning as W26 stage-0 MAS review warnings.
- `EpistemosTests/RuntimeValidationTests.swift`
- `EpistemosTests/HELIOSInvariantSourceGuardTests.swift`
  - Added/updated source guards for passive TCC probe removal, NightBrain dependency readiness, synchronous MTK rendering, nonzero paused drawable size, and hardened app-review script patterns.
- Git index hygiene:
  - Ran `git rm --cached -- syntax-core/target/aarch64-apple-darwin/debug/libsyntax_core.rlib`; the local file remains ignored on disk, but the generated artifact is no longer tracked.

### Verification

- Focused Swift launch/privacy/Metal/audit tests:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/RuntimeValidationTests -only-testing:EpistemosTests/HELIOSInvariantSourceGuardTests -only-testing:EpistemosTests/MetalGraphViewBootstrapTests -only-testing:EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests`
  - Result: PASS (Swift Testing: `405 tests in 4 suites passed`)
  - Result bundle: `build/xcode-results/2026-05-08-060808-58329.xcresult`
- Repository gates:
  - `./Tools/app-review-audit/app-review-audit.sh`: PASS, with expected W26 stage-0 warnings for real Swift subprocess surfaces.
  - `git diff --check`: PASS

### Notes

- The launch privacy and Metal fixes are source/test patched, not runtime-verified. A fresh launched-app log pass must confirm the original TCC and CAMetalLayer errors are gone before these are marked Verified Fixed.
- The app-review script now sees the real Swift subprocess surfaces, but it is still a stage-0 review signal. The next step is target/config-aware MAS partition checking, not a blanket failure on every direct/Pro subprocess lane.

## Slice 122 — Prose Editor Geometry, Note Ask Accessibility, and BlockMirror Coalescing

### Findings

- The live-audit report confirmed the Prose editor was boxed into a narrow content column and the vertical scrollbar was aligned to that narrowed region instead of the editor surface edge.
- Source review found `NoteDetailWorkspaceView.noteEditorSurface` applying a readable-width frame around the whole `ProseEditorView`, while the lower TextKit stack already owns readable insets.
- The note-level `Ask this note` affordance was visible, but the shared ask bar did not expose a distinct submit control in the accessibility tree.
- Focused test verification exposed a real BlockMirror bug: a superseded background sync body could still create a `ModelContext` and persist stale blocks before the newer generation won.

### Changes Made

- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`
  - Removed the outer readable-width frame from `noteEditorSurface`.
  - Let `ProseEditorView` fill the available editor workspace while preserving TextKit-owned horizontal readable insets.
- `Epistemos/Theme/AssistantComposerStatusViews.swift`
  - Added an explicit icon submit button to `AssistantToolbarAskBar`.
  - Added accessibility labels/hints for the note ask text field, submit button, and streaming stop button.
  - Disabled submit only when the trimmed question text is empty.
- `Epistemos/Sync/BlockMirror.swift`
  - Added a short coalescing delay and generation-current check before background `ModelContext` work starts.
  - Prevents obsolete rescheduled bodies from writing stale block mirrors.
- `EpistemosTests/NoteEditorLayoutTests.swift`
- `EpistemosTests/NoteToolbarGlowTests.swift`
- `EpistemosTests/TextKit2ParityTests.swift`
  - Added/updated source and behavioral coverage for full-width editor geometry, note ask submit reachability, current horizontal inset expectations, and latest-generation-only background block sync.

### Verification

- Focused Swift note editor/TK2 suite:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/NoteEditorLayoutTests -only-testing:EpistemosTests/NoteToolbarGlowTests -only-testing:EpistemosTests/TextKit2ParityTests`
  - First run: FAILED, correctly exposing the stale BlockMirror reschedule bug and stale horizontal-inset expectations.
  - Final run: PASS (Swift Testing: `172 tests in 18 suites passed`)
  - Result bundle: `build/xcode-results/2026-05-08-062235-57126.xcresult`

### Notes

- The width and ask-bar patches are source/test verified, not live-UI verified. A Computer Use visual/AX smoke should confirm the scrollbar position and the `Ask this note` submit button in the launched app before marking the runtime issues Verified Fixed.
- The BlockMirror stale-write fix is covered by a behavioral SwiftData-backed test and can ship as v1 hardening.

## Slice 123 — Epdoc Durable Graph Semantics and Complexity Metadata

### Findings

- The runtime audit was right that the durable `.epdoc` graph projection was too shallow for long documents with no wikilinks: the production projector emitted provenance and wikilink/reference edges, but did not preserve authored section/list/quote concepts as graph labels.
- The visible `.epdoc` complexity meter was live, but saved packages did not persist `manifest.metadata["complexity"]`, even though `EpdocQuery` has shipped complexity-above / complexity-below rules that read that metadata key.
- This is a v1 durability/wiring issue, not HELIOS theory work. The safe fix is bounded authored-content extraction and canonical save-path metadata, not new claims, theorems, or authority.

### Changes Made

- `Epistemos/Engine/EpdocGraphProjector.swift`
  - Added bounded authored semantic label extraction from headings, list items, blockquotes, image alt/title, and long paragraph lead sentences.
  - Emits generated `.contains` label edges for those authored concepts when documents have no wikilinks.
  - Rejects wikilink markup, empty/oversized labels, and generic placeholder labels such as `Idea`, `Evidence`, and `Document`.
  - Truncates at word boundaries so graph labels stay readable.
- `Epistemos/Engine/EpdocGraphPersistence.swift`
  - Treats generated `.contains` edges as replaceable projection edges so stale semantic labels are removed on re-save.
- `Epistemos/Engine/EpdocDocument.swift`
  - Recomputes `manifest.metadata["complexity"]` from canonical `content.pm.json` during `fileWrapper(ofType:)`.
  - Preserves unrelated metadata, removes stale complexity only when scoring fails, and keeps metadata through title edits.
- `EpistemosTests/EpdocGraphProjectorTests.swift`
- `EpistemosTests/EpdocGraphPersistenceTests.swift`
- `EpistemosTests/EpdocDocumentTests.swift`
  - Added coverage for long non-wikilink semantic graph labels, replacement of generated semantic contains edges, and persisted complexity metadata.

### Verification

- Focused Epdoc durable graph/document/query/complexity suite:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/EpdocDocumentTests -only-testing:EpistemosTests/EpdocGraphProjectorTests -only-testing:EpistemosTests/EpdocGraphPersistenceTests -only-testing:EpistemosTests/EpdocQueryTests -only-testing:EpistemosTests/EpdocComplexityCalculatorTests`
  - First run: FAILED at compile on optional title normalization.
  - Second run: FAILED projector tests, correctly exposing wikilink paragraph leakage and mid-word semantic truncation.
  - Final run: PASS (Swift Testing: `65 tests in 5 suites passed`)
  - Result bundle: `build/xcode-results/2026-05-08-063708-61062.xcresult`

### Notes

- This makes the durable graph projection richer and more honest, but it does not infer latent evidence/claims beyond authored document text. The live graph button still needs a launched-app smoke on a long pasted document before the runtime issue is marked Verified Fixed.
- Complexity metadata is save-path covered and backs existing query rules; no new query semantics were added.

## Slice 124 — Shadow Search Degraded Health Visibility

### Findings

- The live audit found `shadow search failed: backendFailure(detail: "secret backend detail")` shortly after launch, but the UI had no visible degraded-health state for the Shadow backend.
- `ShadowSearchService.search` intentionally returns an empty hit list on backend errors so Halo typing paths stay non-throwing, but that made real backend failures look like honest zero-result searches unless a developer had logs open.
- The v1-safe fix is a closed-class process-local health snapshot and a read-only Settings row, not a background probe, not a new Shadow substrate, and not raw backend-detail surfacing.

### Changes Made

- `Epistemos/Engine/ShadowSearchService.swift`
  - Added `ShadowSearchDiagnostics`, a process-local snapshot for total searches, total failures, consecutive failures, last domain, last hit count, last latency, last success/failure timestamps, and closed failure class.
  - Records success/failure from both `search` and `searchOrThrow` without persisting or displaying raw backend detail strings.
  - Marks cancelled searches as non-degraded so user-initiated cancellation is not reported as backend failure.
- `Epistemos/Views/Settings/ShadowSearchHealthRow.swift`
  - Added a read-only Settings diagnostics row driven by `ShadowSearchDiagnostics.didChangeNotification`.
  - Shows operational/degraded status, last search summary, failure budget, and closed failure class without triggering backend work.
- `Epistemos/Views/Settings/SettingsView.swift`
  - Mounted `ShadowSearchHealthRow` in Diagnostics and updated the diagnostics copy to mention Shadow degraded health.
- `EpistemosTests/ShadowServicesTests.swift`
- `EpistemosTests/SearchFusionHealthRowTests.swift`
  - Added coverage for degraded failure snapshots, recovery after a successful search, read-only/event-driven Settings mounting, and the updated direct `searchOrThrow` contract.

### Verification

- Focused Shadow/Settings suite:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/ShadowServicesTests -only-testing:EpistemosTests/SearchFusionHealthRowTests`
  - First run: FAILED at compile on private diagnostic recorder access.
  - Second meaningful run: FAILED a stale source guard that still expected `searchOrThrow` to be a one-line pass-through without diagnostics.
  - Final run: PASS (Swift Testing: `27 tests in 2 suites passed`)
  - Result bundle: `build/xcode-results/2026-05-08-065256-75382.xcresult`

### Notes

- This makes hidden Shadow backend failures visible and sanitized in Settings, but it does not claim the underlying production backend failure is fixed.
- A launched-app smoke should force or observe both a Shadow failure and a later successful search, then verify the Settings row transitions from degraded to operational before the runtime issue is marked Verified Fixed.

## Slice 125 — Companion Farm Idle Animation Throttle

### Findings

- The live audit reported idle CPU around 18-19% while the app sat on an open note, with a sample implicating SwiftUI layout/AttributeGraph work in `CompanionRoamingField`.
- Source audit found `CompanionRoamingField` using a display-style `TimelineView(.animation(minimumInterval: 1.0 / 24.0))`, then each rendered `CompanionView` could create another `TimelineView(.animation(minimumInterval: 1.0 / 8.0))` for breathing. In the Landing Farm this multiplies idle animation invalidations across companions even when no user interaction is happening.
- The fix is an energy/idle hardening patch, not a new companion architecture: keep deterministic roaming, lower the idle cadence, share a single sampled date from the parent, and keep phase math bounded for long-running app sessions.

### Changes Made

- `Epistemos/Views/Landing/Farm/CompanionRoamingField.swift`
  - Replaced the 24Hz animation timeline with a coarse 0.25s periodic clock.
  - Passes the sampled parent date into each `CompanionView` so Farm companions do not create their own breathing timelines.
  - Normalizes x/y roaming cycles before calling sine/cosine, avoiding huge absolute-date phase values during long sessions.
- `Epistemos/Views/Landing/Farm/CompanionView.swift`
  - Accepts an optional sampled animation date from the parent.
  - Falls back to a local 0.25s periodic clock only when rendered outside a parent animation clock.
  - Normalizes breathing phase math to the local cycle before sine evaluation.
- `EpistemosTests/CompanionAvatarGrammarSourceGuardTests.swift`
  - Source-guards the periodic clocks, shared sampled-date path, and removal of the old `.animation(minimumInterval:)` timelines.
  - Adds a large absolute-date behavioral test to keep roaming position and breathing phase finite/bounded.

### Verification

- Focused Companion suite:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/CompanionAvatarGrammarSourceGuardTests`
  - First run: FAILED one stale source guard that expected the old exact sampled-date expression.
  - Final run: PASS (Swift Testing: `6 tests in 1 suite passed`)
  - Result bundle: `build/xcode-results/2026-05-08-070321-42404.xcresult`

### Notes

- This removes an obvious source-level idle animation multiplier. It does not prove the launched app now idles below the release target.
- A live launched-app idle CPU sample on the Landing/open-note path is still required before the runtime issue is marked Verified Fixed.

## Slice 126 — NightBrain Dependency-Readiness Deferral

### Findings

- The runtime audit observed `NightBrain search index maintenance requires an initialized SearchIndexService` in logs shortly after launch.
- The scheduler `canStart()` path already checks broad dependency readiness, but `runPipeline(jobOrder:)` is also used by fallback/manual trigger paths. That entrypoint created an `EventStore` run first, then treated missing SearchIndex, AgentGraphMemory, or cloud-knowledge wiring as a job failure.
- Missing dependencies are an expected readiness state for v1 background maintenance. They should defer without opening a run or logging a failure. Real job exceptions should still interrupt the run and stay visible.

### Changes Made

- `Epistemos/State/NightBrainService.swift`
  - Added a selected-job preflight that checks only the dependencies needed by the requested job order.
  - `runPipeline` now returns `.deferred` before creating an `EventStore` run when a required dependency is absent.
  - Expected dependency races after preflight are logged as informational job deferrals, not errors.
  - Unexpected job exceptions still log as errors and interrupt the existing run.
- `EpistemosTests/CognitiveSubstrateTests.swift`
  - Updated missing SearchIndex, GraphMemory, and cloud-knowledge tests to assert preflight deferral without an interrupted run.
  - Kept failing-job coverage for a real cloud-knowledge exception creating an interrupted run.
- `EpistemosTests/RuntimeValidationTests.swift`
  - Added source guards for the dependency preflight and early-defer log path.

### Verification

- Focused NightBrain/RuntimeValidation suite:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/NightBrainCheckpointResumeTests -only-testing:EpistemosTests/RuntimeValidationTests`
  - Result: PASS (Swift Testing: `272 tests in 2 suites passed`)
  - Result bundle: `build/xcode-results/2026-05-08-071120-9747.xcresult`

### Notes

- This closes the source-level readiness bug without changing the NightBrain job catalog or adding new background work.
- A launched-app log smoke is still required before marking the runtime issue Verified Fixed.

## Slice 127 — Code Editor Visible-Window Indentation Parsing

### Findings

- The earlier large-file patch bounded visible line ranges, but the live audit still found scroll/guide paths that could read the full `textView.string` and scan from the start of a large file up to the visible upper bound.
- That is not yet TK-style visible-only behavior. For v1, the native CodeEdit path should keep sidecar guide work scoped to cached text metadata and the visible window without replacing the editor package.

### Changes Made

- `Epistemos/Views/Notes/CodeEditorView.swift`
  - Added `CodeEditorLineMetrics.lineStartUTF16Offsets(in:)` and `textWindow(in:lineRange:lineStartUTF16Offsets:)`.
  - `EpistemosEditorCoordinator` now caches UTF-16 line-start offsets on text changes.
  - Large-file indentation-guide refresh now uses cached `lastText` and extracts a visible text window before parsing instead of re-reading `textView.string` and scanning from the file start on scroll.
  - Cursor/selection tracking now converts the selected range against cached `lastText`, avoiding a full `NSTextView.string` fetch on movement.
- `Epistemos/Views/Notes/SegmentedIndentationGuideView.swift`
  - `updateFromText` accepts `baseLineNumber`, so pre-sliced visible windows preserve absolute line numbers and editor y positions.
- `EpistemosTests/CodeEditorPolishTests.swift`
  - Added behavioral coverage for extracting CRLF/LF mixed visible text windows by cached UTF-16 offsets.
  - Extended the source guard to require cached line-start offsets, visible-window extraction, cached-text scroll refresh, and base-line-aware guide parsing.

### Verification

- Focused CodeEditorPolish suite:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/CodeEditorPolishTests`
  - First result: PASS (Swift Testing: `29 tests in 1 suite passed`)
  - First result bundle: `build/xcode-results/2026-05-08-072155-12425.xcresult`
  - Selection hot-path rerun: PASS (Swift Testing: `29 tests in 1 suite passed`)
  - Selection hot-path result bundle: `build/xcode-results/2026-05-08-072937-79738.xcresult`

### Notes

- This hardens the most obvious source-level whole-buffer sidecar work found in the live audit.
- It is still not a full editor replacement or a claim of perfect virtualization. A launched-app large-file smoke with Time Profiler and Animation Hitches is still required before `ISSUE-2026-05-07-001` can move to Verified Fixed.

## Slice 128 — Process Memory Diagnostic Visibility

### Findings

- `docs/APP_ISSUES_AUTO_FIX.md` still has an unresolved idle-memory regression. The ledger had already been corrected away from `Verified Fixed`, and the right next v1-safe step was visibility, not a speculative rewrite.
- Source audit found the historical `AppleHybridEmbeddingLookup` suspicion is not the same as the current source shape: `GraphState` now uses `DeferredTextEmbeddingLookup`, so a blind eager-load rewrite would be weak evidence.
- Settings had memory-pressure and arena diagnostics, but no direct process resident-size row for release triage. That made the app less honest during idle-memory investigation.

### Changes Made

- `Epistemos/Views/Settings/ProcessMemoryHealthRow.swift`
  - Added a read-only Settings row for process RSS, physical-memory ratio, and app-wide memory-pressure state.
  - Uses `mach_task_basic_info` / `task_info(mach_task_self_)` for resident bytes.
  - Keeps `ProcessMemoryDiagnostics.snapshot(...)` pure/testable and `liveSnapshot()` main-actor isolated for `PowerGate.isMemoryPressureActive`.
  - Explicitly documents that it does not attempt to classify root allocations or replace an Instruments pass.
- `Epistemos/Views/Settings/SettingsView.swift`
  - Mounts `ProcessMemoryHealthRow` in Diagnostics and updates the Diagnostics description.
- `EpistemosTests/SearchFusionHealthRowTests.swift`
  - Source-guards the row as read-only: no button, background task, timer, or periodic sampler.
  - Adds behavioral coverage for nominal/elevated/pressure snapshots and the Settings mounting.

### Verification

- Focused Settings diagnostics suite:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/SearchFusionHealthRowTests -only-testing:EpistemosTests/SettingsCategoryTests`
  - First attempts: FAILED on Swift 6 main-actor isolation around `PowerGate.isMemoryPressureActive`, then on a brittle source-guard phrase split by a newline.
  - Final run: PASS (Swift Testing: `15 tests in 2 suites passed`)
  - Result bundle: `build/xcode-results/2026-05-08-075045-85970.xcresult`

### Notes

- This is diagnostic visibility only. It does not prove the idle-memory regression is fixed and does not identify top persistent allocations.
- `ISSUE-2026-04-21-004` stays `Investigating` until a launched-app Instruments Allocations pass identifies the root allocations and a follow-up patch verifies the reduction.

## Slice 129 — KnowledgeFusion Local Metadata Build Exclusions

### Findings

- Local disk audit found untracked/generated metadata under `Epistemos/KnowledgeFusion`: top-level `.DS_Store`, `Training/.DS_Store`, MOHAWK `.DS_Store`/`.last_pod_id`, and MoLoRA `__pycache__` bytecode.
- `.gitignore` already covered `.DS_Store`, `__pycache__/`, and `Epistemos/KnowledgeFusion/MOHAWK/.last_pod_id`, and the Xcode synced-root exceptions already excluded MOHAWK and MoLoRA pycache paths.
- The top-level `KnowledgeFusion/.DS_Store` and `KnowledgeFusion/Training/.DS_Store` were not excluded from the synced app roots, so a local Finder metadata file could enter the direct/App Store app source root packaging path.
- The existing `ProjectInclusionTests` broad source-tree walk could wedge under the app-hosted test environment when a parser/source-mirror mismatch produced huge coverage work. That made the guard itself too fragile for release hardening.

### Changes Made

- `project.yml`
  - Added `KnowledgeFusion/.DS_Store` and `KnowledgeFusion/Training/.DS_Store` to both direct and App Store `Epistemos` synced-folder exclusions.
- `Epistemos.xcodeproj/project.pbxproj`
  - Mirrored the two metadata exclusions in both `Epistemos` and `Epistemos-AppStore` synchronized build-file exception sets.
- `EpistemosTests/ProjectInclusionTests.swift`
  - Added source guards for the new metadata exclusions and the existing MoLoRA pycache exclusions.
  - Replaced the broad mirrored-filesystem inclusion sweep with a bounded project-file contract check for synced roots and the App Store-only `omega_ax.swift` binding exclusion.

### Verification

- Focused ProjectInclusion suite:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/ProjectInclusionTests`
  - First attempts: invalid/killed due the old broad app-hosted source-walk guard wedging before a result.
  - Final run: PASS (Swift Testing: `2 tests in 1 suite passed`)
  - Result bundle: `build/xcode-results/2026-05-08-083207-46251.xcresult`

### Notes

- No local metadata files were deleted in this slice; the patch only prevents them from entering synced project roots.
- The staged removal of the tracked generated `syntax-core/.../libsyntax_core.rlib` remains separate generated-artifact hygiene.

## Slice 130 — Cinematic Pixel Graph Nodes and Landing Agent Dock

### Findings

- Graph cinematic mode was still visually and textually tied to the old water-style node identity. The user direction for v1 is exactly two modes: cinematic becomes hard stepped pixel-circle nodes, while performance remains the existing fast regular shader.
- Past SVG/screen-overlay graph experiments failed because they did not stay in the graph's world/camera render path. The v1 fix must stay inside the existing Metal instanced renderer so zoom remains real graph zoom.
- Landing companions were still architected as a roaming farm, with active companions able to walk and the legacy orb body still eligible through creation defaults. The requested v1 posture is landing-only small agents that sit near the top-right, breathe lightly, and are usable as active app personas.
- No production graph mount should render companions or agents; the graph remains node/edge UI only.

### Changes Made

- `graph-engine/src/renderer.rs`
  - Added a quality-level-0 cinematic branch in `node_fragment` that quantizes node UVs to an 11x11 grid, discards outside a stepped circle, and returns monochrome pixel-circle colors before the old water/performance shader path.
  - Disabled cinematic glow instances in the near LOD profile so the pixel edge is not softened.
  - Left the quality-level-2 performance branch and graph interaction/physics untouched.
- `Epistemos/Views/Graph/GraphFloatingControls.swift`
  - Renamed the two user-facing modes to `Pixel` and `Fast`, without adding a third or legacy visual mode.
- `Epistemos/Views/Graph/GraphForceSettings.swift`, `Epistemos/Graph/GraphState.swift`, `Epistemos/Views/Graph/MetalGraphView.swift`
  - Updated comments/copy from water-node wording to cinematic pixel-node wording while preserving the legacy FFI flag name.
- `Epistemos/Views/Landing/Farm/LandingFarmView.swift`
  - Replaced the large companion box with a compact top-right `AGENTS` dock and retro `+` add affordance.
- `Epistemos/Views/Landing/Farm/CompanionRoamingField.swift`
  - Kept the compatibility type name but made the surface a static landing-only shelf with one coarse 0.75s shared breathing clock and no roaming math.
- `Epistemos/Views/Landing/Farm/CompanionView.swift`, `Epistemos/Views/Landing/Farm/CompanionAvatarGlyph.swift`
  - Removed halo/orb presentation from the v1 visual path; active agents no longer walk and hover is the only speak animation.
- `Epistemos/State/Companion/CompanionState.swift`, `Epistemos/Models/Companion/CompanionModel.swift`, `Epistemos/Views/Landing/Farm/CompanionCreationFlow.swift`
  - New agents activate by default, creation defaults to block-style agents rather than orb bodies, and the creation flow uses agent wording plus a broader color preset strip.
- `Epistemos/Engine/PipelineService.swift`, `Epistemos/App/AppBootstrap.swift`, `Epistemos/App/ChatCoordinator.swift`
  - Wired the active landing agent into direct-stream, tool-loop, command-center, and main Rust-agent prompt context as a bounded persona instruction without claiming separate model/tool access.
- `EpistemosTests/CompanionAvatarGrammarSourceGuardTests.swift`, `EpistemosTests/GraphPhysicsSettingsAuditTests.swift`
  - Added source guards for no graph companion mounts, no roaming/walking landing agents, no default orb creation, no halo drawing, pixel-only cinematic graph nodes, and unchanged performance mode.

### Verification

- Graph renderer LOD guard:
  - Command: `cargo test --manifest-path graph-engine/Cargo.toml lod_profile_is_zoom_stable_in_cinematic_mode --lib`
  - Result: PASS (`1 passed; 2530 filtered out`)
- Focused Swift graph/agent source guards:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/CompanionAvatarGrammarSourceGuardTests -only-testing:EpistemosTests/GraphPhysicsSettingsAuditTests`
  - Result: PASS (`26 tests in 2 Swift Testing suites passed`)
  - Result bundle: `build/xcode-results/2026-05-08-114808-1566.xcresult`

### Notes

- This slice is source- and test-verified only. It still needs launched-app visual smoke in light/dark graph modes to confirm the pixel circle reads as intended, and a launched idle CPU sample to promote the landing-agent CPU issue from `Patched` to `Verified Fixed`.
- Legacy orb parsing/rendering remains source-preserved for existing companion rows, but v1 creation and display no longer use it as the active product identity.

## Slice 131 — Mono Graph Labels, Dense Landing Wave, Agent Body Polish

### Findings

- The pixel-node graph identity was visible, but label readability still depended on the previous softer retro SDF atlas and blur tuning. The requested v1 direction is a crisp mono label face that stays sharp beside the pixel nodes.
- The landing click wave/puddle used a large fast-radius bloom. The requested behavior is denser and slower, with a smaller radius.
- The new landing agents were in the right dock posture, but small internal body squares read as noisy dividers at the reduced tamagotchi scale.

### Changes Made

- `scripts/generate-sdf-atlas.sh`, `Epistemos/Resources/sdf_labels.png`, `Epistemos/Resources/sdf_labels.json`, `Epistemos/Graph/SDFLabelAtlas.swift`, `graph-engine/src/renderer.rs`
  - Regenerated the default graph label atlas from JetBrains Mono at 1024px/48pt, made atlas height explicit in the renderer, reduced label blur widening, and kept the retro atlas as an explicit alternate generation target instead of the default.
- `Epistemos/Views/Landing/Wave/LandingWaveDesign.swift`, `Epistemos/Views/Landing/Wave/LandingWaveChoreography.swift`, `Epistemos/Views/Landing/Wave/LandingWaveRenderer.swift`, `Epistemos/Shaders/LandingWave.metal`, `Epistemos/Views/Landing/Wave/LandingWaveHaptics.swift`
  - Increased landing wave character density, expanded the ramp to 16 glyph levels, reduced impact/crown/crater/jet radii, and slowed the click sequence so the puddle is compact rather than a broad fast splash.
- `Epistemos/Models/Companion/CompanionModel.swift`, `Epistemos/Views/Landing/Farm/CompanionAvatarGlyph.swift`
  - Added three more block-style body presets for the add-agent flow and removed tiny internal belt/spine/mouth square dividers from dock-size bodies while preserving the outer body silhouettes, eyes, legs, and antennae.
- `EpistemosTests/GraphPhysicsSettingsAuditTests.swift`, `EpistemosTests/CompanionAvatarGrammarSourceGuardTests.swift`, `EpistemosTests/LandingWaveChoreographyTests.swift`, `EpistemosTests/LandingWaveGlyphAtlasTests.swift`
  - Added source guards for the mono SDF atlas, solid body silhouettes, six body presets, compact/slower wave timings/radii, dense grid policy, and 16-character wave ramp.

### Verification

- Graph renderer LOD guard:
  - Command: `cargo test --manifest-path graph-engine/Cargo.toml lod_profile_is_zoom_stable_in_cinematic_mode --lib`
  - Result: PASS (`1 passed; 2530 filtered out`)
- Focused graph/agent/wave source guards:
  - Command: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/GraphPhysicsSettingsAuditTests -only-testing:EpistemosTests/CompanionAvatarGrammarSourceGuardTests -only-testing:EpistemosTests/LandingWaveChoreographyTests -only-testing:EpistemosTests/LandingWaveGlyphAtlasTests`
  - Result: PASS (`35 tests in 4 Swift Testing suites passed`)
  - Result bundle: `build/xcode-results/2026-05-08-121411-56577.xcresult`

### Notes

- This slice is source- and test-verified only. It still needs launched-app visual smoke for crisp graph labels, the final landing-wave feel, and the no-divider agent body read in light/dark contexts.
- A same-session launched smoke later confirmed the top-right agent dock is visible, reachable, and active-selection aware in AX, but it also showed active search overlay CPU at 15.8% before dropping to 3.4% after closing search. Do not promote the landing/search animation cost to Verified Fixed without a longer Time Profiler pass.
