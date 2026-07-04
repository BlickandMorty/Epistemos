# TEST SUITE BLOCKED — stale `GooseWebSurfaceView` references (2026-07-04)

**Severity: HIGH (cross-lane).** The `EpistemosTests` target does not compile, so **no tests run at
all** — the full suite (~2,679 tests per CLAUDE.md) is unverifiable until this is fixed. This blocks
test-verification for *every* lane, including Front & Feel.

## Root cause
`GooseWebSurfaceView` was **removed** — renamed to `ProAgentSurfaceView` by the Pro-agent lane. There
is no `struct/class/typealias GooseWebSurfaceView` anywhere in the app anymore; the only remaining
app-side mention is a doc comment at `Epistemos/ProAgent/ProAgentSurfaceView.swift:137`. But **6 test
files still reference the removed symbol**, so the test target fails to compile. First compiler error:
`WorkSPAServerTests.swift:227:34: cannot find 'GooseWebSurfaceView' in scope`.

## The 6 stale test files (all Goose / Work lane — NOT Front & Feel)
- `EpistemosTests/GooseLiveIntegrationTests.swift`
- `EpistemosTests/GooseWebPromptLiveIntegrationTests.swift`
- `EpistemosTests/GooseRuntimeSupervisorTests.swift`
- `EpistemosTests/GooseWebOnlySurfaceTests.swift`
- `EpistemosTests/GooseWebRouteLiveIntegrationTests.swift`
- `EpistemosTests/WorkSPAServerTests.swift`

## Who fixes it
The **Goose / Pro / MAS builders** who did the `GooseWebSurfaceView → ProAgentSurfaceView` rename own
these files. The Front & Feel lane must not touch them (excluded). Fix = update the references to
`ProAgentSurfaceView` (or delete the now-obsolete Goose-surface tests if that surface is gone).

## Caveat — there may be more
`xcodebuild` stops at the first batch of errors, so fixing these 6 may reveal *additional* stale
Goose-symbol references (33 test files touch `Goose*` symbols total; only the 6 above are confirmed
broken so far). Re-run `xcodebuild test -only-testing:…` after the fix to surface any remainder.

## Front & Feel workaround in the meantime
New Front & Feel tests still get written and committed (they compile), but can't be *run* in-target
until this unblocks. Pure-logic ones are verified out-of-target with a standalone `swiftc` probe of
the verbatim logic — e.g. `DataviewBlockRunnerTests` (#41) was proven 10/10 that way. That's a
stopgap, not a substitute for a green suite.
