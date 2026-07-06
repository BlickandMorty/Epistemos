---
name: proshell-work-runtime-env-boundary
description: Harden Epistemos Work/OpenCode runtime subprocess boundaries. Use when editing Work runtime, OpenCode, OpenGUI, OpenWork, or adjacent ProShell launch paths that pass loopback auth, PATH, bundled binary locations, or inherited process environments into a child runtime.
---

# ProShell Work Runtime Env Boundary

Use this skill when a Work/OpenCode runtime seam launches a child process or worker and needs a bounded environment that still lets bundled sidecars resolve.

## Method

1. Name the exact child: binary, argv, current directory, loopback host/port, auth env keys, inherited env keys, stdout/stderr owner, and teardown owner.
2. Start from a hostile parent environment. Keep only allowlisted inherited values (`PATH`, `HOME`, `USER`, `LOGNAME`, `TMPDIR`, locale, `TERM`, `TZ`) after rejecting NUL bytes and oversized values.
3. Rebuild `PATH` from deliberate roots: bundled child binary directories first, then safe inherited absolute entries, canonical macOS tool directories, and safe user tool dirs (`~/.local/bin`, `~/bin`) when `HOME` is absolute.
4. Cap every dimension: inherited value size, single path-entry size, total path length, and entry count. Dedupe entries before exposing them to the child.
5. Keep Work loopback credentials fresh and spawn-scoped. Drop inherited auth keys, then inject only the current per-launch username/password into the intended child env.
6. Test the seam with hostile inherited input: stale auth, provider secrets, `NODE_OPTIONS`, `DYLD_*`, relative PATH entries, duplicate PATH entries, NUL bytes, oversized values, and PATH entry-count overflow.

## Checks

- Prefer pure helper tests before runtime spawning.
- Confirm no other `xcodebuild` is active before running Xcode tests.
- Run a focused test like:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' -only-testing:EpistemosTests/WorkRuntimeSupervisorTests test CODE_SIGNING_ALLOWED=NO`
- Before staging, inspect touched paths and confirm they stay inside `Epistemos/Work/**`, `EpistemosTests/**`, `.claude/skills/proshell-*`, and `docs/research/**`.
