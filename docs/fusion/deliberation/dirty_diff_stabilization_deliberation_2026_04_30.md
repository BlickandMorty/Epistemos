# Dirty-Diff Stabilization Deliberation - 2026-04-30

## Gate

Approved for documentation/audit only. No source edits, cleanup, stash operations, staging, commits, branch changes, or file deletion are approved.

## Context

The build/test floor is now green after the verification repair gates recorded in `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`. The next queue item is to stabilize the dirty-diff boundary before any feature implementation starts.

## Evidence Commands

- `git status --short -uall`
- `git status --short -uall | ruby ...` for status counts
- `git diff --stat`
- `git worktree list`
- `git stash list`
- `git stash show --stat stash@{0..3}`
- per-worktree `git status --short -uall`
- protected-path diff audit for `ProseEditor*`, `MetalGraphView`, and `HologramController`

## Current Findings

- Main worktree: `1316` status entries: `516 M`, `800 ??`.
- Full Swift floor and Rust floors are green despite the dirty state.
- Protected paths remain clean:
  - `Epistemos/Views/Notes/ProseEditor*.swift`
  - `Epistemos/Views/Graph/MetalGraphView.swift`
  - `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/` remains dirty and high risk. It passed `cargo test`, but broad graph-engine implementation is not approved.
- Four stashes exist. All remain suspect; none may be popped without a dedicated gate.
- Worktree donor branches remain raw-merge rejected. Only conceptual extraction through future narrow gates is allowed.

## Decision

Create a durable stabilization audit document that records the current dirty-state boundary and salvage policy. Do not alter any source or clean generated files. The worktree is intentionally dirty and must not be normalized by automated cleanup while the user is away.

## Approved Outputs

- `docs/fusion/DIRTY_DIFF_STABILIZATION_AUDIT_2026_04_30.md`

## Forbidden Actions

- No `git stash pop`, `git stash drop`, or stash application.
- No `git reset`, `git checkout --`, `git clean`, or deletion of generated artifacts.
- No staging or commits.
- No branch/worktree deletion.
- No source edits for this item.
- No protected-path edits.

## Acceptance Criteria

- The audit records the green floor baseline, status counts, stash risk, worktree decisions, protected-path state, and next-gate recommendations.
- It clearly separates Codex-approved repairs from unapproved donor/dirty work.
- It names stop triggers for the next implementation gate.

## Stop Triggers

- Any request to clean/delete generated files without user confirmation.
- Any need to apply a stash or raw-merge a worktree.
- Any protected-path drift.
- Any new source change during this documentation-only gate.
