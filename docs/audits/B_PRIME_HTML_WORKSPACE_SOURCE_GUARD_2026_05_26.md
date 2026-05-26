# B-Prime HTML Workspace Source Guard - 2026-05-26

Status: recovered as a focused source-guard slice from `stash@{0}`.

Source: `stash@{0}` (`b-prime-uncommitted-followup-2026-05-26`) and draft
preservation PR #82.

Recovery rule: no stash was popped, dropped, checked out, or bulk-applied. The
stash was inspected with `git show` / `git diff`; only the durable guard intent
was ported onto current `main`.

## What Was Recovered

- `EpistemosTests/HTMLWorkspaceSourceGuardTests.swift` now verifies that the
  active editor bridge exposes `requestHTMLWorkspace` through the outbound
  JS-to-Swift route.
- The guard now proves the app-level menu owns the visible "New HTML Workspace"
  command instead of relying on the older graph workspace container as the
  source of truth.
- The guard now checks `js-editor/webpack.config.js` so Mermaid vendor bundles
  cannot silently re-enter the active editor build.

## What Was Not Restored Raw

`stash@{0}` contains `js-editor/src/extensions/legacy-diagram-node.ts`, a
compatibility-only TipTap node named `mermaid` for old Epdoc diagram blocks.
That file was not restored as live editor code in this slice because current
product direction routes new visual creation to native HTML Workspace, and
PR #86 intentionally removed the live Mermaid route to preserve graph/editor
performance.

If legacy diagram compatibility becomes necessary, recover it as a separate
compatibility importer with an explicit performance/source-guard test. Do not
re-register Mermaid as the active visual creation path.

## Verification Target

- `EpistemosTests/HTMLWorkspaceSourceGuardTests`
