# Non-Goose UI Deep Clean Handoff - 2026-07-02

## Scope lock

- Goose is explicitly out of scope. The owner is working on Goose in another agent.
- This handoff covers the non-Goose editor, note, MarkEdit, Epdoc, graph, Instant Recall, and HTML Workspace cleanup.
- The worktree contains Goose changes from outside this lane. Do not revert them from this handoff.

## User concern checklist

- Notes should be real `.md` files immediately: routed note creation through a single coordinator so landing/sidebar creation creates a path-backed markdown note that can be opened instantly.
- One note creation affordance: added one create path that asks for the surface kind instead of separate scattered buttons.
- Open any markdown note in Prose, Epdoc/Document, Preview, or Source: preserved the surface picker and kept Source as another markdown surface.
- Source/MarkEdit toolbar should keep the surface picker and settings: source chrome keeps surface switching without the duplicate under-toolbar row.
- MarkEdit source content should not go blank when switching from Prose/Epdoc: source route now seeds from the same note markdown and updates snapshots immediately.
- MarkEdit eye/render controls and tables: repaired preview bridge, table rendering affordance, and source rendered-table overlay guards.
- MarkEdit and code editor theme mismatch: theme override wiring now reaches MarkEdit/code-editor body, preview, and chrome for preset/custom themes including Ember/Platinum.
- Code files should stay code files when renamed: rename preserves the original extension instead of falling back to `.md`.
- Code file identity: code editor title/file chrome uses language-specific icons and labels instead of the paper note icon.
- Prose/Epdoc/Preview duplicate title/chrome clutter: removed duplicate middle title surfaces and kept the dynamic title.
- Note preview top gap: removed the fake top padding path; preview content is no longer pushed down. The title/toolbar now gets a solid chrome backdrop, including graph-embedded preview.
- Prose/Epdoc heading sizes: reduced default heading scale and restored adaptive shrinking for long headings.
- Graph embedded page artifacts: canvas sidebar and route-only controls are hidden on note/code/page routes; graph animation is paused/hidden while an embedded page owns the route.
- Graph inspector preview font: preview body uses the plain reading font/body sizing while keeping the panel title pixel-styled.
- Instant Recall offscreen search icon: removed old magnifying-glass affordance from note/graph surfaces; mounted a more visible `IR` chip and simplified native-feeling panel.
- Epdoc duplicate word counts: Epdoc/document mode hides the outer note footer so only one counter remains.
- Epdoc frontmatter: frontmatter commands now write real document metadata instead of only visual/frontmatter text.
- Epdoc complexity meter: visible complexity meter was replaced with an agent-token counter. Internal complexity metadata/scoring still exists for document metadata/tests.
- HTML Workspace clutter: regenerate was split and simplified into a chat-first surface; legacy context sidebar/drop clutter was removed; toolbar labels and token estimate were added; default sizing was enlarged.
- HTML Workspace file size debt: `HTMLWorkspaceRegenerateSurface.swift` was reduced to 410 lines by extracting support/regeneration files. `HTMLWorkspaceEditorView.swift` was then reduced to 994 lines by extracting package/file/export actions into `HTMLWorkspaceEditorPackageActions.swift` (462 lines).

## Main files changed in this lane

- `Epistemos/Views/Notes/NoteCreationCoordinator.swift`
- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`
- `Epistemos/Views/Notes/NotePreviewSurfaceView.swift`
- `Epistemos/Views/Notes/CodeEditorView.swift`
- `Epistemos/Views/Notes/CodeFileIconView.swift`
- `Epistemos/Views/Notes/MarkEditCoreEditorView.swift`
- `Epistemos/Views/Notes/MarkEditCoreEditorState.swift`
- `Epistemos/Views/Notes/MarkEditCoreEditorThemePalette.swift`
- `Epistemos/Views/Notes/ProseEditorRepresentable2.swift`
- `Epistemos/Views/Notes/ProseEditorView.swift`
- `Epistemos/Views/Notes/WebKitCodeEditorView.swift`
- `Epistemos/Views/Epdoc/EpdocComplexityMeter.swift`
- `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift`
- `Epistemos/Views/Epdoc/EpdocEditorToolbar.swift`
- `Epistemos/Engine/EpdocDocument.swift`
- `Epistemos/Views/Graph/GraphWorkspaceContainer.swift`
- `Epistemos/Views/Graph/HologramOverlay.swift`
- `Epistemos/Views/Graph/HologramSearchSidebar.swift`
- `Epistemos/Views/Graph/HologramNodeInspector.swift`
- `Epistemos/Views/Home/HomeGraphEmbeddedView.swift`
- `Epistemos/Views/Recall/ContextualShadowsButton.swift`
- `Epistemos/Views/Recall/ContextualShadowsPanel.swift`
- `Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift`
- `Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorPackageActions.swift`
- `Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorSupport.swift`
- `Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorRegeneration.swift`
- `Epistemos/Views/HTMLWorkspace/HTMLWorkspaceRegenerateSurface.swift`
- `Epistemos/Views/HTMLWorkspace/HTMLWorkspaceRegenerateSupport.swift`
- Deleted: `Epistemos/Views/HTMLWorkspace/HTMLWorkspacePreviewContextPicker.swift`
- Deleted: `Epistemos/Views/HTMLWorkspace/HTMLWorkspaceRegenerateContextSidebar.swift`
- `js-editor/src/editor.css`
- `js-editor/src/index.ts`
- `LocalPackages/MarkEdit/CoreEditor/src/modules/preview/index.css`
- `LocalPackages/MarkEdit/CoreEditor/src/modules/preview/index.ts`

## Verification artifacts

- `/tmp/epi_preview_graph_padding_green_20260702.xcresult`: Passed, 78 selected tests, 77 passed, 1 skipped.
- `/tmp/epi_graph_note_chrome_green_20260702.xcresult`: Passed, 4 selected graph note composition tests.
- `/tmp/epi_html_regenerate_split_green2_20260702.xcresult`: Passed, 43 HTML regenerate/source-guard tests.
- `/tmp/epi_ui_artifact_sweep_green_20260702.xcresult`: Passed, 237 selected artifact/layout tests, 236 passed, 1 skipped.
- `/tmp/epi_html_workspace_cleanup_green4_20260702.xcresult`: Passed, 17 HTML Workspace cleanup tests.
- `/tmp/epi_epdoc_frontmatter_metadata_green_20260702.xcresult`: Passed, 67 Epdoc/frontmatter tests.
- `/tmp/epi_heading_adaptive_green2_20260702.xcresult`: Passed, 118 heading/adaptive selected tests, 117 passed, 1 skipped.
- `/tmp/epi_markedit_chrome_code_identity_green_20260702.xcresult`: Passed, 13 MarkEdit/code identity chrome tests.
- `/tmp/epi_html_workspace_actions_split_source_green_20260702.xcresult`: Passed, 43 HTML Workspace source/regenerate guard tests after extracting package actions.
- `npm run typecheck` passed for `js-editor`.
- `bash build-tiptap-bundle.sh` completed after heading/source edits.

## Source sweeps

- Old HTML preview-context sidebar/drop identifiers are present only in negative source-guard tests.
- Old preview fake-padding identifiers are present only in negative source-guard tests.
- Old Prose bridge Halo mounts are absent from the Prose bridge; note workspace mounts the new `ContextualShadowsButton`.
- `git diff --name-only | rg -i 'goose|goose_'` shows Goose files dirty in the worktree, but this lane did not intentionally edit Goose and should not touch those changes.

## Remaining risks / next pass

- Full app test suite was not rerun end-to-end after all UI changes; targeted suites are green.
- `HTMLWorkspaceEditorView.swift` is now under 1k lines after the package-action extraction. The next structural cleanup target should be chosen from the remaining large SwiftUI files by line count and active bug pressure, not from HTML Workspace actions.
- Manual visual QA is still valuable for: Ember/Platinum theme parity, graph embedded note preview top chrome, HTML Workspace initial window sizing, and Instant Recall animation feel.
- The broad graph/runtime sweep previously surfaced unrelated runtime-validation failures outside this cleanup lane. Do not confuse those with the focused graph note/page chrome checks, which passed.
