# Stash 16 Approval UI Donor Closeout - 2026-05-26

Status: durable approval behavior ported into the current fused approval surface.

Source: `stash@{16}` (`session-stash-2026-04-27: W9.21 PR4 (X salvaged) + W9.8 wire-up partial; restart-fresh per user`).

Recovery rule: no stash was popped, dropped, checked out, or bulk-applied.

## What Was In The Donor

`stash@{16}` mixed several categories:

- older honest-handle FFI work
- an older `ApprovalModalView` patch
- an untracked `Epistemos/State/ChatApprovalQueue.swift`
- editor bundle assets and generated Rust target files

The honest-handle slice is already closed by current `main` and
`docs/audits/CLAUDE_SHADOW_HANDLE_CLOSEOUT_2026_05_26.md`.

The raw donor approval files were not restored because current `main` already
has the newer fused SwiftUI approval sheet in
`Epistemos/Views/Approval/ApprovalModalView.swift`, wired through
`AppBootstrap.chatApprovalQueue` and `EpistemosApp.sheet(...)`.

## What Was Ported

The durable donor behavior was ported into the current queue:

- per-session dedup by SHA-256 of `(toolName, argsJSON)`
- duplicate approved requests short-circuit to `allowOnce`
- JSONL audit rows written to `<session>/approvals.jsonl`
- event kinds for prompt shown, user resolved, timeout denied, overlap denied,
  and dedup short-circuit
- test override for audit-log directories
- AppBootstrap resolver wiring to session folders

## What Was Not Ported

- The old standalone `Epistemos/State/ChatApprovalQueue.swift` file was not
  restored as a separate source file. Current architecture keeps the queue next
  to the approval modal surface.
- The older `Timer.publish(...).autoconnect()` donor path was not restored.
  Current `TimelineView` behavior is more consistent with the no-repeatForever
  / occlusion-aware performance rule.
- Editor assets and Mermaid/vendor files from the untracked stash payload were
  not restored. They need a separate editor-source-guard and performance gate.

## Verification

- `AuditFixRegressionTests.chatApprovalQueueDedupesApprovedArgsAndAppendsAuditJSONL`
  covers the dedup and JSONL audit behavior.
- `AuditFixRegressionTests.chatApprovalQueueResolvesModalDecisions` keeps the
  existing continuation and overlap behavior pinned.

## Result

The approval UI donor value from `stash@{16}` is no longer stranded in the
stash. The remaining `stash@{16}` value is editor/vendor donor material, not
approval UI product work.
