# agent-a0550f9c Worktree Inspection - 2026-05-23

Terminal: T4 worktree and auxiliary branch salvage
Donor branch: `worktree-agent-a0550f9c`
Donor path: `/Users/jojo/Downloads/Epistemos/.claude/worktrees/agent-a0550f9c`
Inspection branch: `salvage/agent-a0550f9c-inspection-2026-05-23`

## Decision

Do not mine code from this worktree.

The committed branch head is already reachable from `origin/main`, and the
remaining dirty patch is stale rework against spine-critical FFI files. The
worktree should be kept until the user approves cleanup. Recommended next
action is an archive tag / worktree cleanup only with explicit user approval.

## Acceptance Bar

- No wholesale branch merge: passed; no merge attempted.
- No worktree deletion: passed; donor worktree was inspected only.
- Pure-additive requirement: failed; dirty patch modifies existing Swift and
  Rust FFI files plus `agent_core/Cargo.lock`.
- Compile without dragging old architecture: failed; dirty patch would remove
  current main FFI surface.
- Preserve product doctrine: failed; dirty patch would regress currently wired
  honest-handle and Halo timing/ETL surfaces.

## Current State

`git status --short --branch` in the donor worktree:

```text
## worktree-agent-a0550f9c
 M Epistemos/Engine/RustShadowFFIClient.swift
 M agent_core/Cargo.lock
 M epistemos-shadow/src/honest_handle.rs
```

Donor head:

```text
6cd4748119
ancestor_of_origin_main=yes
```

Dirty diff size:

```text
Epistemos/Engine/RustShadowFFIClient.swift | 249 +++++++++---
agent_core/Cargo.lock                      |  44 +-
epistemos-shadow/src/honest_handle.rs      | 632 +++++++++++++++++++++++++----
3 files changed, 770 insertions(+), 155 deletions(-)
```

Diff versus `origin/main`:

```text
Epistemos/Engine/RustShadowFFIClient.swift |  412 +++------
agent_core/Cargo.lock                      | 1265 +---------------------------
epistemos-shadow/src/honest_handle.rs      |  384 +++++----
3 files changed, 357 insertions(+), 1704 deletions(-)
```

## WRV Audit

What exists:

- The honest-handle FFI work is already on main.
- Main has advanced past this worktree with Halo timing support:
  `shadow_handle_last_timings_json` and Swift `lastSearchTimings()`.
- Main also has current Swift FFI bindings for `shadow_warm` and ETL queue
  helpers in `RustShadowFFIClient.swift`.

Fixture/stub/status-only:

- No salvageable additive fixture was found in this worktree.
- The only remaining work is uncommitted local modification of production
  files.

Production caller chain:

- Current main uses `RustShadowFFIClient` over per-instance
  `shadow_handle_*` FFI.
- The donor dirty patch touches that production caller chain directly.

Missing for WRV:

- Wired: not unique; current main is already wired.
- Reachable: donor committed work is already reachable from main.
- Visible: no new visible product path; dirty patch would remove current
  instrumentation surface.
- Verified: no compile proof for the dirty patch, and it is not suitable for
  compile proof because it regresses main-owned files.

## Donor-Mining Test

| Test | Result | Evidence |
| --- | --- | --- |
| Unique vs main? | No for committed work; stale/unsafe for dirty work | Donor head is an ancestor of `origin/main`; `/tmp/audit/04_donors.md` records W9.21 PR1+PR4 as already landed. |
| Pure-additive? | No | Dirty patch modifies `RustShadowFFIClient.swift`, `honest_handle.rs`, and `agent_core/Cargo.lock`. |
| Compiles without old architecture? | No proof; treat as failed | Patch would delete newer main FFI surface, including `shadow_handle_last_timings_json`. |
| Preserves doctrine? | No | It would regress current honest-handle/Halo instrumentation doctrine. |
| Spine class | Spine-critical but already current-wired on main | Honest-handle FFI is core search/spine infrastructure. |

## Dirty Patch Findings

`Epistemos/Engine/RustShadowFFIClient.swift`:

- Dirty patch is not additive.
- Against `origin/main`, it would remove the current `shadow_handle_last_timings_json`
  binding and `lastSearchTimings()` method.
- It would also remove current `shadow_warm` and ETL queue FFI declarations.
- It changes `search(limit:)` to pass raw `limit` instead of main's
  `max(0, limit)` guard.

`epistemos-shadow/src/honest_handle.rs`:

- Dirty patch is not additive.
- Against `origin/main`, it would remove current
  `shadow_handle_last_timings_json`.
- Most surviving additions are comments/test reshaping around behavior that
  main already implements.

`agent_core/Cargo.lock`:

- Dirty patch is not independently meaningful as salvage.
- It changes existing lockfile contents and cannot be accepted as a pure
  additive donor.

## Classification

`archive-candidate`, `current-wired-on-main`, `no-code-mined`, `inspect-only`.

## Recommendation

Do not cherry-pick or salvage this worktree. If cleanup is desired, create an
archive/preservation tag for operator clarity, then remove the worktree only
after explicit user approval.
