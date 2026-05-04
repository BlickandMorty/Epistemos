# Codex/Kimi Oversight Round 044 - 2026-05-01

## Slice

EventStore OpLog Projection Visibility PR3D.

## Kimi Role

Read-only advisory. Kimi was asked to review whether the next safe provenance
slice should expose projection/dead-letter visibility, and to identify blockers
before code edits.

Advisory logs:

- Failed first model attempt: `/tmp/epistemos-oplog-dead-letter-visibility-kimi-advisory-20260501.log`
- Completed advisory: `/tmp/epistemos-oplog-dead-letter-visibility-kimi-advisory-2-20260501.log`

## Outcome

Kimi supported a narrow read-only Settings diagnostics row backed by bounded
EventStore queries. Kimi did not mutate the worktree. Codex kept raw OpLog ABI,
projection mutation, repair controls, timers, and polling loops out of the UI.

## Codex Verification

- Initial focused log:
  `/tmp/epistemos-oplog-visibility-pr3d-focused-20260501.log`
- Green focused log:
  `/tmp/epistemos-oplog-visibility-pr3d-focused-2-20260501.log`

Focused result:

- `EventStoreSchemaTests` plus `OpLogFFIBoundaryGuardTests`: `20` tests in `2`
  suites passed.
- Xcode printed `** TEST SUCCEEDED **` and exited `0`.

## Guardrail Decision

PR3D is closed. Basic projection and dead-letter visibility should not be
rebuilt. Future provenance work should open fresh gates for replay/rollback,
AgentEvent/tool provenance, GraphEvent mapping, or deeper audit/repair UX.
