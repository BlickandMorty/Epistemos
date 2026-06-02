# HTML Workspace Hardening And Feature Checklist - 2026-06-02

## Scope

- Checkpoint commit: `2931a507fc Harden HTML workspace document opening`.
- Branch: `codex/inline-tool-loop-transcript-2026-05-27`.
- Protected areas left untouched: `~/Epistemos-RETRO/`, `src-tauri/`, `~/meta-analytical-pfc/`, and protected graph renderer/camera/physics internals.
- Merge status: not merge-ready while the worktree still has hundreds of unrelated dirty/untracked entries and recursive app audit has not reached three zero-fail passes.

## Verified

- `xcodebuild build -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO` passed on the current tree.
- `npm run typecheck` passed in `js-editor`.
- `cargo +stable-aarch64-apple-darwin test --quiet` passed in `graph-engine`.
- `/Users/jojo/Downloads/Epistemos-Latest.app` was rebuilt, signed locally, and smoke-opened `/Users/jojo/all research/My mind 2/Untitled HTML Workspace 30.htmlworkspace` without a new crash report after `Epistemos-2026-06-02-001844.ips`.

## Not Fully Cleared

- The focused hosted Xcode test run for `HTMLWorkspaceSourceGuardTests` reached the app host and hung under LLDB; do not count it as passed.
- The broader hardening suite previously had unrelated failures in `omegaPlannerSchemasStayAligned` and `vaultDestructiveUIFlowsUseAsyncSnapshotSwitching`.
- Current build verification includes the dirty working tree; the checkpoint commit should be retested from a clean worktree before merging.

## Fixed In Checkpoint

- HTML Workspace package opens now route through a dedicated `EpistemosDocumentController.openHTMLWorkspaceDocument(at:)` path instead of generic AppKit document opening.
- Opened package state is loaded into `HTMLWorkspaceDocument` before showing it.
- Sidebar and graph workspace package open actions use the dedicated HTML Workspace opener.
- File watcher debounce/ignore state is held in a private reference object outside direct `@Observable` tracked storage.
- Source guard tests were added for the HTML opener route and watcher state shape.

## Hardening Queue

1. Centralize vault child-name validation and reject `/`, `..`, control characters, and hidden package/control names before constructing relative paths.
2. Standardize symlink-resolved containment checks across vault sync, live note execution, chat mutation, package import, and code file access.
3. Add native size, count, extension, and filename bounds to `.epdoc` package ingest and asset import.
4. Add HTML Workspace package/import bounds and make trust/network policy session-scoped unless the user explicitly persists trust.
5. Unify Tiptap link sanitization across paste, markdown input rules, inbound conversion, toolbar insertion, and native Markdown projection.
6. Cap PDF ingestion by file size, page count, text length, image extraction count, and extraction time.
7. Verify manifest content hashes on open for `.epdoc` and `.htmlworkspace`, then surface a repair path instead of silently trusting package contents.
8. Run the release audit skill and recursive app audit until three successive zero-fail passes before calling the app finished.

## Feature Queue

1. Native PDFKit reader/annotator for vault PDFs: highlights, page anchors, quote-to-note, backlinks, and annotation export.
2. Quick Look attachment preview for images, PDFs, videos, audio, and unknown files from vault/package contexts.
3. Core Spotlight indexing for notes, `.epdoc`, HTML Workspace metadata, PDF annotations, tags, and backlinks.
4. Tiptap backlink/link autocomplete with block IDs, title aliases, and safe URL policy reuse.
5. Tiptap document outline/table-of-contents panel using existing headings and unique IDs.
6. Lightweight properties/frontmatter editor with typed fields, tag picker, and vault search facets.
7. HTML Workspace diagnostics drawer: console, blocked navigation log, package manifest, resource sizes, and trust state.
8. HTML Workspace safe asset browser/importer with package budget display and repair tools.
9. Daily note, template, and command palette actions wired to native menus and keyboard shortcuts.
10. Graph filters for tags, modified date, document type, backlink depth, and orphaned notes.
11. Markdown/PDF quote capture that creates a note block with source document, page, and selection anchors.
12. Import/export passes for Markdown folders, PDF annotation summaries, and HTML Workspace packages.

## External Baselines Checked

- Apple PDFKit `PDFView`: native PDF viewing and interaction baseline.
- Apple Quick Look `QLPreviewPanel`: native attachment preview baseline.
- Apple WebKit `WKWebView` and `WKContentWorld`: WebKit isolation and scripting baseline.
- Apple Core Spotlight: native local search indexing baseline.
- Tiptap docs/repo: editor extension baseline.
- Logseq, SiYuan, AFFiNE, and AppFlowy repositories: PKM feature baselines for backlinks, blocks, local-first workspaces, graph/database views, and collaboration scope.
