# H-1 Startup Hang Time Profiler - User Decision Research

**Status:** COMPLETE_RESEARCH_READY
**Date:** 2026-05-16
**Terminal E scope:** user-decision preparation only; no implementation.

## Problem Statement

The user needs to decide how to handle `ISSUE-2026-05-12-011`, a startup responsiveness regression recorded as two watchdog events:

- 969 ms after `Workspace restored: 0 notes, 0 mini chats` and `Activity tracking started`.
- 3182 ms, coalesced across 3 samples, after `app_became_active`.

The current issue log already identifies four plausible causes: SwiftUI body re-evaluation around vault-reprompt UI, MLX model warmup, graph initialization or first-activate relayout, and startup subscriber fan-out. Those hypotheses are not interchangeable. Fixing the wrong one could add churn while leaving the visible 3-second startup hang intact.

The immediate decision is whether to require a Time Profiler trace before implementation, authorize a small speculative cleanup set, defer the issue, or rely on watchdog logs alone.

## Options

### Option A - Run Instruments Time Profiler before any fix

Keep H-1 operator-required. Build the app in Debug, launch through Xcode Product -> Profile, select Time Profiler, record from process launch through the first idle home screen, then inspect the main-thread heaviest stacks for the first 4 seconds.

**Pros**
- Produces frame-level evidence for the actual main-thread blocker.
- Separates SwiftUI body churn, MLX warmup, graph relayout, and subscriber fan-out.
- Avoids making several unrelated startup changes at once.
- Matches the existing MAS A.7 operator-required row and the issue log's investigation state.

**Cons**
- Requires human action on the Mac.
- Blocks the implementation slice until the trace is available.
- Does not itself reduce the hang.

### Option B - Apply low-risk speculative fixes now

Make only changes that are plausibly useful regardless of the trace, such as moving direct `UserDefaults.standard` reads out of hot SwiftUI body predicates, deferring model warm paths behind first agent invocation, and detaching heavy first-activate work.

**Pros**
- May improve startup without waiting for a trace.
- Some changes are locally sensible even if they are not the root cause.
- Can reduce obvious main-thread work before profiling.

**Cons**
- Risks hiding the real cause behind partial improvement.
- Can create multiple small behavior changes in one slice.
- MLX and graph deferrals are not purely cosmetic; they need runtime verification.

### Option C - Defer H-1 until after V1

Leave the issue as operator-required and ship only if current users no longer reproduce the hang.

**Pros**
- Avoids late release churn.
- Reasonable if the current startup path no longer reproduces the 969 ms / 3182 ms events.

**Cons**
- The 3182 ms hang is user-visible.
- Startup latency is release-polish-critical.
- Deferring without a fresh non-repro trace leaves the issue unresolved.

### Option D - Use watchdog logs and signposts only

Add or rely on structured watchdog/lifecycle diagnostics, then infer the culprit from log ordering rather than Instruments.

**Pros**
- Fully terminal-friendly.
- Can improve future diagnosis and regression detection.
- Lower operator burden than Instruments.

**Cons**
- Watchdog logs show that the main queue was blocked, not which stack blocked it.
- Lifecycle ordering can mislead when several startup tasks race.
- Insufficient for choosing among the four current hypotheses.

## Canonical Sources

### `docs/APP_ISSUES_AUTO_FIX.md`

- Lines 180-194: ISSUE-2026-05-12-011 records the two startup watchdog events and the 500 ms threshold.
- Lines 196-208: suspected causes are SwiftData/RootView first render, SwiftUI body re-evaluation, MLX warmup, graph init or relayout, and subscriber fan-out.
- Lines 210-217: safe auto-fix candidates are cached vault-reprompt predicate inputs, deferred MLX load, and detached heavy startup work.
- Lines 222-227: investigation says the hangs predate vault fixes and need an Instruments Time Profiler trace.

### `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md`

- Lines 155-188: Phase A.7 already classifies H-1 as operator-required, gives the Time Profiler recipe, lists the four hypotheses, and sets the acceptance bar at <=500 ms main-thread occupancy.
- Section 8 already contains the original H-1 surfacing row; this decision research doc narrows the user choice and default recommendation.

### `docs/RESEARCH_COVERAGE_GAP_AUDIT_2026_05_15.md`

- Lines 79-83: PASS 1 H-1 identifies the startup hang as HIGH priority, user-visible, and dependent on Instruments Time Profiler.

### `Epistemos/State/MainThreadWatchdog.swift`

- Lines 6-14: watchdog uses a background GCD timer to ping the main queue and detect UI hangs.
- Lines 90-97: default threshold is 0.5 seconds with a 1.0 second check interval and 0.1 second coalescing delay.
- Lines 129-168: `checkMainThread` emits `Main thread hang detected` when the main-queue pong exceeds the threshold and coalesces nearby samples.

### `Epistemos/App/AppBootstrap.swift`

- Lines 1867-1870: startup installs `MainThreadWatchdog` unless tests or low-power background suppression disable it.
- Lines 2341-2354: app bootstrap logs the selected local agent model, matching one issue-log clue before the 3182 ms hang.

### `Epistemos/App/EpistemosApp.swift`

- Lines 126-134: the vault-reprompt sheet predicate reads `UserDefaults.standard` directly while evaluating presentation conditions.
- Lines 586-590: app lifecycle wiring records `app_became_active`, which is the lifecycle marker preceding the second hang.

### `Epistemos/Sync/VaultSyncService.swift`

- Lines 1204-1215: a prior launch I/O path was already moved off-main because directory scanning and snapshot pruning could contribute to the same startup-hang class. That confirms the current policy: startup hang fixes should move proven blockers off the main thread, but only after identifying the blocker.

## Code Impact Estimate

### Option A - Time Profiler first

Implementation now: docs only.

Follow-up implementation depends on trace result:

- SwiftUI body cascade: likely small SwiftUI/defaults cleanup in `Epistemos/App/EpistemosApp.swift`, `Epistemos/Views/Notes/NotesSidebar.swift`, or adjacent presentation predicates.
- MLX warmup: moderate startup-policy change in `Epistemos/App/AppBootstrap.swift`, `Epistemos/State/InferenceState.swift`, or local model service initialization.
- Graph relayout: moderate graph startup change in `Epistemos/Graph/GraphState.swift` or graph view initialization.
- Subscriber fan-out: targeted `.onReceive` or `NotificationCenter` handler changes, probably moving work to detached tasks or narrowing first-activate work.

Tests after a trace-driven fix:

- Relevant unit tests for the touched subsystem.
- Manual launch smoke test.
- Runtime watchdog log check showing no `Main thread hang detected` event above 500 ms in the same launch window.
- Preferably a saved before/after Time Profiler trace.

### Option B - Speculative cleanup

Estimated implementation: 50-400 LOC depending on how far the deferrals go.

Likely risks:

- `@AppStorage` or cached predicate changes may affect onboarding/vault prompt timing.
- Deferring MLX can change first-agent latency or UI readiness indicators.
- Detaching graph/subscriber work can introduce ordering races if existing code assumes main-thread sequencing.

### Option C - Defer

Estimated implementation: docs/status only.

Risk is product-quality rather than code complexity: a 3-second startup hang remains unresolved unless a fresh launch run proves non-repro.

### Option D - Watchdog/signpost-only

Estimated implementation: 50-250 LOC for extra diagnostics, depending on signpost coverage.

Risk is diagnostic false confidence. Signposts can narrow timing windows, but they still do not replace a sampled main-thread stack when choosing among UI, model, graph, and subscriber work.

## Recommendation

Recommend **Option A: run Instruments Time Profiler before implementing H-1 fixes**.

Recommended decision record:

> H-1 remains operator-required until a Time Profiler trace identifies the main-thread heaviest stack for the first startup window. Do not ship speculative startup churn as the H-1 fix. After the trace, apply the smallest targeted fix and rerun the same launch window until the watchdog stays below 500 ms.

Reasoning:

- The current evidence already proves a main-thread hang, but not the stack.
- Four hypotheses point at different ownership areas and different risk levels.
- The watchdog threshold is clear in code: 500 ms.
- Previous startup I/O was already moved off-main, so one historical cause is fixed; the remaining 3182 ms hang needs a fresh sampled stack.
- A trace-driven patch will be easier to verify and safer to review.

## Acceptance Criteria

If the user chooses **Option A**:

- Save a Time Profiler trace for a Debug launch through first idle home screen.
- Store the trace at `artifacts/perf/ISSUE-2026-05-12-011-time-profiler.trace` or attach it to the issue log.
- Paste or summarize the main-thread heaviest stack frames above 50 ms for the first 4 seconds.
- Identify which hypothesis the trace confirms or rejects.
- Apply only the targeted fix for the confirmed blocker.
- Rerun the same launch window.
- Confirm no startup `Main thread hang detected` event exceeds 500 ms, or document the remaining heaviest stack as the next H-1 sub-issue.

If the user chooses **Option B**:

- Keep speculative fixes split by ownership area, not batched into one broad startup patch.
- Add before/after watchdog log evidence.
- Do not close H-1 unless a follow-up launch run stays below 500 ms.

If the user chooses **Option C**:

- Record the defer decision in MAS and `APP_ISSUES_AUTO_FIX.md`.
- Require a fresh non-repro launch log before treating H-1 as release-safe.

If the user chooses **Option D**:

- Add signposts/watchdog metadata only as diagnostic support.
- Keep H-1 open until a sampled stack or a verified <=500 ms rerun exists.

## Decision-Ready Prompt

Choose the H-1 startup-hang path:

1. **Recommended:** Run Instruments Time Profiler now, paste the main-thread heaviest stacks, and implement only the confirmed fix.
2. Authorize small speculative cleanup before the trace, with H-1 staying open until watchdog evidence passes.
3. Defer H-1 post-V1 only if a fresh launch run no longer reproduces the >500 ms watchdog event.
4. Add watchdog/signpost diagnostics only, accepting that this does not identify the sampled stack.
