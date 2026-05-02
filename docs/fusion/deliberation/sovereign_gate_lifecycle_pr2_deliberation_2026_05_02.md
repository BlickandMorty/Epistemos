# Sovereign Gate Lifecycle PR2 Deliberation - 2026-05-02

```text
Slice:          Sovereign Gate Lifecycle PR2 - app-owned gate plus grace clearing
Tier:           Core
Files touched:
- Epistemos/Sovereign/SovereignGateLifecycleObserver.swift
- Epistemos/App/AppBootstrap.swift
- EpistemosTests/SovereignGateTests.swift
- docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md
- docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md
- docs/fusion/deliberation/sovereign_gate_lifecycle_pr2_deliberation_2026_05_02.md
Protected paths:
- Epistemos/Views/Notes/ProseEditor*.swift
- Epistemos/Views/Notes/ProseTextView2.swift
- Epistemos/Views/Graph/**
- graph-engine/**
- agent_core/**
- epistemos-core/**
- generated bindings / libraries
- Epistemos.xcodeproj
- entitlements
Gate:           SovereignGate touchpoint? lifecycle only
Risks:          P0 if this migrates existing dialogs or owns app action classes; P0 if LocalAuthentication moves outside SovereignGate.swift; P1 if grace survives app resign-active, system sleep, or observer teardown leaks tokens.
Verification:   focused Swift test logs under /tmp/epistemos-sovereign-gate-pr2-*-20260502.log; LocalAuthentication confinement grep; diff-only invariant greps; staged protected-path audit.
Rollback:       Remove lifecycle observer file, AppBootstrap property/start/stop lines, tests, and PR2 docs/status lines.
Stop triggers:
- The slice needs Rust action-class matrix, generated UniFFI, existing dialog migration, protected editor/graph files, project files, entitlements, or generated artifacts.
- Swift starts deciding action sensitivity instead of hosting and clearing the gate.
- LocalAuthentication, LAContext, canEvaluatePolicy, evaluatePolicy, biometric prompting, or Touch ID appears outside Epistemos/Sovereign/SovereignGate.swift.
- Observer notifications are not removable, or tests require real app/system notifications.
```

## Doctrine Anchor

PR1 created the single Swift executor. PR2 makes it app-owned and clears
Sensitive grace at security boundaries without migrating any confirmation
surface. This preserves the doctrine split: Rust will eventually decide the
requirement; Swift presents and owns lifecycle hygiene.

## Implementation Contract

- Add `SovereignGateLifecycleObserver` under `Epistemos/Sovereign/`.
- Observe app/system security-boundary notifications and call
  `SovereignGate.clearGrace()`.
- AppBootstrap owns exactly one `sovereignGate` instance and starts/stops the
  observer with the rest of runtime observer lifecycle.
- Tests use custom `NotificationCenter` instances and fake authenticators.
- Do not inject the gate into UI environment or migrate dialogs in this PR.
- Do not touch Rust, generated bindings, entitlements, project files, graph,
  note editor internals, or existing approval queues.

## Verification

Red first:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/SovereignGateTests test 2>&1 | tee /tmp/epistemos-sovereign-gate-pr2-red-20260502.log
```

Green focused:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/SovereignGateTests test 2>&1 | tee /tmp/epistemos-sovereign-gate-pr2-green-20260502.log
```

Guardrails:

```bash
git diff --check -- Epistemos/Sovereign Epistemos/App/AppBootstrap.swift EpistemosTests/SovereignGateTests.swift docs/fusion
rg -n 'LAContext|canEvaluatePolicy|evaluatePolicy|deviceOwnerAuthentication|TouchID|Touch ID|biometric|LocalAuthentication' Epistemos EpistemosTests --glob '!Epistemos/Sovereign/SovereignGate.swift' --glob '!EpistemosTests/SovereignGateTests.swift'
git diff -- Epistemos/Sovereign Epistemos/App/AppBootstrap.swift EpistemosTests/SovereignGateTests.swift | rg -n 'Process\(\)|swift-subprocess|Foundation\.Process|std::process::Command|memcpy|memmove|\.copyMemory|Data\(bytes:|storageModeManaged|storageModePrivate|z3|kani|kissat|lean|cvc5|alloy' || true
git diff --name-only -- Epistemos/Views/Notes Epistemos/Views/Graph Epistemos/Graph graph-engine agent_core epistemos-core Epistemos.xcodeproj
```

Actual evidence:

- Red log: `/tmp/epistemos-sovereign-gate-pr2-red-20260502.log` failed on the
  missing `SovereignGateLifecycleObserver`, as intended.
- First green attempt: `/tmp/epistemos-sovereign-gate-pr2-green-20260502.log`
  proved the observer behavior but exposed a brittle source-file test hang in
  `String(contentsOf:)`; the test was replaced by a runtime AppBootstrap
  observer-start assertion plus shell wiring audits.
- Final focused green log:
  `/tmp/epistemos-sovereign-gate-pr2-green-20260502-r2.log` passed 10
  `SovereignGateTests`. Xcode still printed the existing SwiftLint package
  plugin failures for CodeEditTextView/CodeEditSourceEditor after
  `TEST SUCCEEDED`; the command exited 0.
- Notification-name check:
  `NSWorkspaceWillSleepNotification`,
  `NSWorkspaceSessionDidResignActiveNotification`, and
  `NSWorkspaceScreensDidSleepNotification` resolve on this SDK.
- Guardrails before staging:
  `git diff --check` passed for the PR2 write set; the source confinement grep
  found no `LocalAuthentication` / `LAContext` / Touch ID usage outside
  `Epistemos/Sovereign/SovereignGate.swift`; the diff-only subprocess,
  solver, tensor-copy, and hot-memory grep returned no matches; and AppBootstrap
  wiring audit found the exact shared gate, start, and stop lines.

## Acceptance

- Wired: `AppBootstrap` owns the shared `SovereignGate` and lifecycle observer.
- Reachable: tests prove app resign-active and system sleep notifications clear
  Sensitive grace without real Touch ID.
- Visible: tests prove `stop()` removes observers and AppBootstrap starts/stops
  the observer.
- Boundary: no existing confirmation surfaces are migrated; no action-class
  matrix, Rust, generated bindings, project files, entitlements, graph,
  protected editor, subprocess, solver, or hot memory paths are touched.
