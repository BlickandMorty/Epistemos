# B-Prime Legacy Diagram Compatibility - 2026-05-26

Status: recovered as a focused editor compatibility slice from `stash@{0}`.

Source: `stash@{0}` (`b-prime-uncommitted-followup-2026-05-26`) and draft
preservation PR #82.

Recovery rule: no stash was popped, dropped, checked out, or bulk-applied. The
stash was inspected with `git show` / `git diff`; only the durable compatibility
intent was ported onto current `main`.

## What Was Recovered

- `js-editor/src/extensions/legacy-diagram-node.ts` now preserves old Epdoc
  diagram blocks under the historical `mermaid` schema name.
- The node renders old diagram content as inert source in
  `pre[data-legacy-diagram]`.
- `js-editor/src/index.ts` registers `LegacyDiagramNode` so old documents and
  Markdown-paste output can load without reintroducing active Mermaid rendering.
- `js-editor/src/editor.css` now styles legacy diagrams as code-like source
  blocks instead of live rendered graph cards.
- `EpistemosTests/HTMLWorkspaceSourceGuardTests.swift` verifies the compatibility
  node is inert and that the old live Mermaid renderer file is absent.

## What Was Explicitly Not Restored

- No Mermaid package dependency.
- No `vendor/mermaid` bundle.
- No dynamic `/vendor/mermaid/mermaid.min.js` loader.
- No `MermaidNode` registration.
- No slash-command path that creates new Mermaid visuals.

New visual creation still routes to native HTML Workspace. This slice only keeps
old document data readable without a hidden WebKit rendering path.

## Verification Target

- `npm run typecheck`
- `EpistemosTests/HTMLWorkspaceSourceGuardTests`
