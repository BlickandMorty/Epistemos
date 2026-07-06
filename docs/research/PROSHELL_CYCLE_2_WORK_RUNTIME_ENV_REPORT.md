# ProShell Cycle 2 - Work Runtime Env Boundary

Date: 2026-07-06

## Scout

Cycle 2 reused `proshell-subprocess-env-hardening` against the next deepest OpenChamber child-process seam. `Epistemos/Work/WorkRuntimeSupervisor.swift` launched the managed `opencode serve` child with a full copy of `ProcessInfo.processInfo.environment`, prepended the runtime bin directory, and then injected per-launch `OPENCODE_SERVER_USERNAME` / `OPENCODE_SERVER_PASSWORD`.

Finding: the Work runtime was loopback-bound and per-launch authenticated, but its child environment still allowed inherited provider secrets, dynamic-loader variables, `NODE_OPTIONS`, stale OpenCode auth keys, relative PATH entries, duplicate PATH entries, and oversized values to cross into the child.

## Forge

- Added `Epistemos/Work/WorkSubprocessEnvironment.swift` as a Work-owned allowlisted environment builder.
- Rebuilt Work child `PATH` from the bundled runtime bin directory, safe inherited absolute entries, canonical macOS tool directories, and safe user tool directories.
- Routed `WorkRuntimeSupervisor.processEnvironment(...)` through the new helper, then injected only the fresh per-launch Work auth credentials.
- Added regression coverage in `EpistemosTests/WorkRuntimeSupervisorTests.swift` for hostile inherited input, stale auth replacement, PATH dedupe, relative-entry rejection, and PATH entry-count caps.

## Temper

Four-lens review:

- Correctness: the simple PATH + auth behavior is preserved for the managed runtime.
- Security: inherited secrets and injection variables no longer cross the runtime boundary; stale inherited OpenCode auth is replaced by the current per-launch credentials.
- Memory/data leak: no new retained state or async lifecycle path was introduced.
- Robustness: malformed inherited values are rejected; PATH construction is bounded by value size, entry size, total length, and entry count.

Open HIGHs: 0.

## Boundary

Touched paths are in ProShell scope: `Epistemos/Work/**`, `EpistemosTests/**`, `.claude/skills/proshell-*`, and `docs/research/**`.

Protected edits: none.

## Ascend

This cycle makes Work runtime environment hardening reusable. The next Work subprocess frontier is `WorkOpenGUISupervisor.processEnvironment(...)` and `WorkOpenWorkSupervisor.workerEnvironment(...)`, which still have broader inherited-env behavior and can be tightened with `proshell-work-runtime-env-boundary`.
