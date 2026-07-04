# BUILD STATUS — both targets RED (2026-07-04), both from concurrent lanes

**Severity: CRITICAL.** As of this writing the app **does not compile**, and the test target does not
compile either. Neither failure is in the Front & Feel lane — both are from concurrently-working
agent lanes (Pro / Goose). Surfacing per "no known critical breakage undocumented."

## 1. APP TARGET — RED (Pro-agent lane)
```
ProAgentRuntimeSupervisor.swift:957:26 :: main actor-isolated instance method 'claim()' cannot be
                                          called from outside of the actor
ProAgentRuntimeSupervisor.swift:961:26 :: (same)
```
- **Lane:** Pro-agent (`Epistemos/ProAgent/…`) — excluded from Front & Feel; a builder owns it.
- **Nature:** Swift 6 strict-concurrency violation — `claim()` is `@MainActor`-isolated but is called
  from a non-isolated / different-actor context at those two sites. Typical fix is a 1-liner (`await`
  the call from an async main-actor context, or correct the isolation of `claim()` / the call site).
- **Persistence:** observed RED across ≥2 build attempts (~6+ min), not a momentary mid-commit blip.
- **Regression window:** the app built GREEN at the #41 UI commit (`5d3a2d5d9`); the break landed in a
  Pro-lane commit after that.

## 2. TEST TARGET — RED (Goose lane)
`WorkSPAServerTests.swift:227` → removed `GooseWebSurfaceView` symbol. Full detail + the other 5 stale
files in `TEST_SUITE_BLOCKED_GOOSE_SYMBOL_2026_07_04.md`.

## Impact
The app can't be run, shipped, or verified until the app target compiles; no tests run until the test
target compiles. Both block enterprise/App-Store readiness, and **both are outside the Front & Feel
lane** — the Front & Feel surfaces themselves are in good shape (see the hardening handoffs).

## Who fixes
- App target → the **Pro-agent builder** (fix `ProAgentRuntimeSupervisor` actor isolation).
- Test target → the **Goose builders** (update/remove the 6 `GooseWebSurfaceView` references).
Front & Feel must not touch either (excluded lanes, and the Pro lane is mid-refactor — editing it now
risks a conflict).

## Front & Feel work currently HELD on the red build
`NoteLinkClassifier` (extracts + hardens the untrusted-note-link scheme gate — blocks `file://`,
`javascript:`, custom schemes; only http/https/mailto open) + its test are **written and probe-proven
16/16** out-of-target, but the commit is **held** pending a green app build (can't satisfy "BUILD
SUCCEEDED before commit" through no fault of these files). Files sit unstaged in the working tree:
`Epistemos/Views/Notes/NoteLinkClassifier.swift`, the `ProseEditorRepresentable2` handler refactor,
`EpistemosTests/NoteLinkClassifierTests.swift`. Will build-verify + commit the moment the app compiles.
