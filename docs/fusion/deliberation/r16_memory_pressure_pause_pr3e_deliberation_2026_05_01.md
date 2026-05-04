# R16 Memory Pressure Pause PR3E Deliberation - 2026-05-01

## Verdict

Approved for a narrow PR3E slice that wires the app's existing
`DispatchSourceMemoryPressure` observer into the canonical `PowerGate`
background-work predicate.

This gate exists because PR3D already pauses ETL dispatch for low power,
thermal pressure, and low battery, but the R16 definition of done still requires
memory-pressure warnings to halt crawler work. The app already observes memory
pressure in `RuntimeIssueMonitor`; this slice must reuse that signal instead of
adding a second dispatch source.

This gate does not approve ETL worker execution, sidecar badge UI, MAS bookmark
scope enforcement, generated bindings, protected editor/graph work, or Rust ETL
queue changes.

## Scope

- Add a canonical `PowerGate` defer snapshot/reason surface that includes
  memory pressure.
- Have `RuntimeIssueMonitor` publish memory-pressure enter/recovery transitions
  to `PowerGate`.
- Replace `AppBootstrap`'s local pause-reason duplication with the canonical
  `PowerGate` reason mapping.
- Prove Settings background-indexing diagnostics can display
  `Paused - memory pressure`.
- Keep the existing battery, thermal, and low-power behavior intact.

## Authority Evidence

- `docs/plan/00_AUTHORITY_AND_ANTI_DRIFT.md` requires background jobs to hook
  `DispatchSourceMemoryPressure` and yield within 100 ms of `.warning`.
- `docs/plan/01_DOCTRINE.md` repeats the 6 GB realtime budget rule.
- `docs/plan/03_EXECUTION_MAP.md` R16 marks memory pressure as a remaining
  definition-of-done item.
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_034_2026_05_01.md`
  explicitly defers memory-pressure-specific pause beyond PR3D.
- `Epistemos/App/EpistemosApp.swift` already owns the process-wide
  `DispatchSourceMemoryPressure` listener and records memory-pressure
  diagnostics.
- `Epistemos/State/PowerGate.swift` is the existing cross-cutting predicate
  called by R16 ETL dispatch and NightBrain fallback.
- Targeted research log:
  `/tmp/epistemos-r16-memory-pressure-research-rg-20260501.log`.

## Allowed Files

- `Epistemos/State/PowerGate.swift`
- `Epistemos/App/EpistemosApp.swift`
- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/Views/Settings/EditorBundleHealthRow.swift`
- `EpistemosTests/ResourceExhaustionTests.swift`
- `EpistemosTests/ShadowVaultBootstrapperTests.swift`
- `docs/fusion/deliberation/r16_memory_pressure_pause_pr3e_deliberation_2026_05_01.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_052_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`

## Forbidden Files

- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/**`
- `epistemos-shadow/**`
- `agent_core/**`
- Xcode project/workspace files, entitlements, generated bindings, generated
  libraries, DerivedData, `.xcresult`, staging, commit, stash, or branch
  operations.

## Implementation Contract

- `RuntimeIssueMonitor` must reuse its existing memory-pressure dispatch source.
- `PowerGate.shouldDefer()` must return true while memory pressure is active.
- `PowerGate` must expose the current defer reason so callers do not need to
  duplicate low-power, thermal, battery, and memory-pressure checks.
- On `.normal` recovery, the memory-pressure defer state must clear.
- AppBootstrap must record `BackgroundIndexingPauseReason.memoryPressure` when
  ETL dispatch is skipped because memory pressure is active.
- The change must not allocate in render/editor hot paths and must not add a
  polling loop.
- This slice may prove halt-before-dispatch. It does not claim ETL worker
  mid-file cancellation because worker execution is still a later gate.

## Tests

- Red-first focused Swift tests:
  - `PowerGate` returns memory-pressure as the canonical defer reason.
  - `RuntimeIssueMonitor.MemoryPressureTracker` transitions can update and clear
    the `PowerGate` memory-pressure state.
  - `BackgroundIndexingHealthRow` renders paused memory-pressure diagnostics.
- Focused command:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ResourceMemoryPressureTrackingTests -only-testing:EpistemosTests/ShadowVaultBootstrapperTests test`
- Diff and protected-path guardrails for the allowed files and docs.

## Acceptance

- Memory-pressure warning/critical transitions make `PowerGate.shouldDefer()`
  true without requiring another memory-pressure source.
- Memory-pressure recovery clears that defer state.
- AppBootstrap's ETL dispatch pause reason comes from the canonical
  `PowerGate` snapshot.
- Settings diagnostics can distinguish memory-pressure pause from generic
  background policy.
- Full R16 WRV remains deferred until ETL worker execution, generated sidecar
  badge visibility, and MAS bookmark enforcement land.

## Stop Triggers

- The implementation needs protected editor or graph files.
- The implementation needs `graph-engine/**`, `epistemos-shadow/**`, or
  `agent_core/**`.
- The implementation requires a generated binding or Xcode project change.
- The implementation needs a second memory-pressure dispatch source.
- A focused Swift test fails and cannot be fixed inside the allowed write set.

## WRV

Intermediate WRV for PR3E only:

- Wired: the process-wide memory-pressure observer updates `PowerGate`.
- Reachable: R16 ETL dispatch already calls `PowerGate.shouldDefer()` before
  enqueueing.
- Visible: Settings Diagnostics can show `Paused - memory pressure`.

Full R16 WRV remains deferred until worker execution, generated sidecar badge
visibility, and MAS bookmark enforcement are each closed behind their own gates.
