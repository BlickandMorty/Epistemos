# SS-CRASH — 🔴 P0 launch crash: app crashes on open (AppBootstrap precondition) (2026-06-20)

Owner: *"the app keeps crashing as soon as I open it. Fix it + add to the plan."* **P0 — blocks all use; jumps ahead of all
feature/substrate work.** Crash-log-grounded.

## Crash signature (from ~/Library/Logs/DiagnosticReports/Epistemos-2026-06-20-182332.000.ips, 18:23-18:41 today)
- `EXC_BREAKPOINT` / `SIGTRAP` via `_assertionFailure(_:_:file:line:flags:)` — a Swift `precondition`/`fatalError` trap (not a
  memory fault).
- Crashed thread: `AppBootstrap.performPrimaryLaunchInitialization()` → a SwiftUI `@Observable` `Attribute.init<A>` closure
  chain → `_assertionFailure`. I.e. a precondition fires while the launch-init evaluates an observable property.

## Root cause (high confidence) — regression from SS-IR diagnostic `3c89ae84f`
`3c89ae84f feat(recall): SS-IR — Instant Recall health diagnostic` touched `AppBootstrap.swift` (+11) +
`ShadowSearchService.swift` (+54); its own diff comment: *"a stats() FFI call racing the live search service; preconditions
are the answer."* The health diagnostic accesses the shadow search service / calls `stats()` (or a lazy service) **during
primary launch init, before the shadow backend is installed**, tripping a `preconditionFailure` — candidates:
`AppBootstrap.swift:938 preconditionFailure("AppBootstrap.<name> accessed before initialization")` (lazy service touched too
early) and/or the new diagnostic precondition near `:3071`/`:3814`. Because the diagnostic is read by an `@Observable`/SwiftUI
attribute during launch, the precondition fires on the launch path → crash on open.

## Fix (P0, NON-INVASIVE, honest)
1. **Do NOT precondition/trap in the launch-init / observable read path.** The health diagnostic must DEGRADE GRACEFULLY:
   when the shadow search service isn't installed yet (no vault / FFI not open / bootstrap not landed), return an honest
   "not ready / no index yet" status — NEVER `precondition`/`fatalError`. Replace the precondition with a `guard`/optional
   that yields the not-ready state. (The SS-IR slice already says the diagnostic should report vault?/FFI?/index-size honestly
   — that honest path must also be the SAFE path.)
2. **Don't call `stats()` FFI during `performPrimaryLaunchInitialization` / from an observable getter.** Defer the diagnostic
   probe until AFTER `initializeShadowBackendIfReady()` completes (or run it lazily/async on first Settings open), so launch
   never races the service. Guard the FFI behind `haloSearchService != nil` + bootstrap-complete.
3. **Verify on a real launch:** app opens cleanly (no crash) with AND without an active vault / shadow index; the diagnostic
   row shows an honest "not ready" instead of crashing. Add a regression test that the launch-init path does not access the
   shadow service before init (or that the diagnostic returns not-ready when the service is nil).

## Auditor note (process)
This is exactly a "green-but-broke-launch" miss — the SS-IR commits were build-green + test-passing but introduced a
launch-time precondition not covered by the tests. Add to SS-CLEAN: substrate/startup-touching commits need a LAUNCH SMOKE
check (does the app actually open?), not just unit-green. Cross-ref SS-IR, SS-CLEAN, AppBootstrap.

## Status
Root-caused; fix is the loop's (AppBootstrap + ShadowSearchService — the SS-IR path it owns). Steered to the loop as P0
ahead of substrate Phase 0. Verify owner can open the app after.
