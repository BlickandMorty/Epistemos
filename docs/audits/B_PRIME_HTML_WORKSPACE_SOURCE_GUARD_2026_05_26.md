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

`js-editor/src/extensions/legacy-diagram-node.ts` was later recovered as the
separate compatibility slice documented in
`docs/audits/B_PRIME_LEGACY_DIAGRAM_COMPATIBILITY_2026_05_26.md`. It preserves
old Epdoc diagram blocks as inert source and does not restore Mermaid as an
active visual creation path.

## Verification Target

- `EpistemosTests/HTMLWorkspaceSourceGuardTests`
