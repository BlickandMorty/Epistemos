# R15 UniFFI Callback Handle Baseline PR5 Deliberation - 2026-05-02

## Gate

Approved action: replace the disabled UniFFI callback placeholder with an
honest test-only fixture baseline over the generated UniFFI callback handle
path that already exists in the app build.

This does not claim true Rust -> Swift callback-loop throughput, because no
dedicated Rust benchmark export exists and this gate does not approve generated
binding edits. The baseline must say exactly what it measures: generated
`AgentEventDelegate` handle lowering/lifting plus Swift delegate dispatch.

## Authority Evidence

- Card 3 keeps R15 benchmark work test-only until real fixture gates exist.
- `EpistemosTests/Benchmarks/UniFFICallbackThroughputTests.swift` is currently a
  disabled manual placeholder and explicitly says the Rust bridge is missing.
- Generated `agent_core.swift` already exposes the
  `AgentEventDelegate` callback interface plus public handle converter helpers.
- Adding a new Rust callback-loop export would require generated UniFFI binding
  work, so that belongs in a later generated-transport gate.

## Files Approved

- `EpistemosTests/Benchmarks/UniFFICallbackThroughputTests.swift`
- `EpistemosTests/BenchmarkHarnessSourceGuardTests.swift`
- `benchmarks/results/2026-05-02t00-00-00-000z-r15-uniffi-callback-baseline-uniffi_callback_handle_roundtrip_10000.json`
- `docs/fusion/deliberation/r15_uniffi_callback_handle_baseline_pr5_deliberation_2026_05_02.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`

## Files Forbidden

- `agent_core/**`
- generated Swift/header bindings
- generated libraries
- `graph-engine/**`
- `Epistemos/Views/Graph/**`
- `Epistemos/Views/Notes/ProseEditor*.swift`
- production FFI replacement code
- Xcode project files, entitlements, DerivedData, `.xcresult`, stashes, or
  branch operations. Exact-file staging/commit by the overseer is allowed only
  under the user's active commit-as-you-go instruction.

## Implementation Contract

- Remove the disabled placeholder status from `UniFFICallbackThroughputTests`.
- Use `BenchmarkRunRecorder` and the existing machine-readable JSON schema.
- Measure only deterministic generated callback-handle work available today.
- Metadata must explicitly say this is not the future true Rust callback-loop
  export.
- Keep this out of production hot paths.

## Tests And Logs

Red:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/BenchmarkHarnessSourceGuardTests test
```

Expected red reason: the new source guard detects the existing disabled
placeholder in `UniFFICallbackThroughputTests.swift`.

Green:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/BenchmarkHarnessSourceGuardTests test
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/UniFFICallbackThroughputTests test
```

Guardrails:

```bash
git diff --check -- EpistemosTests/Benchmarks/UniFFICallbackThroughputTests.swift EpistemosTests/BenchmarkHarnessSourceGuardTests.swift docs/fusion benchmarks/results
git diff --cached --name-only | rg '^(agent_core/|graph-engine/|Epistemos/Views/Graph/|Epistemos/Views/Notes/ProseEditor|build-rust/|Epistemos.xcodeproj|.*\\.xcresult$)'
```

## Acceptance

- Wired: the UniFFI callback benchmark suite is an enabled Swift Testing suite.
- Reachable: the focused test writes one deterministic JSON baseline report.
- Visible: report metadata distinguishes generated callback-handle throughput
  from a future true Rust -> Swift callback-loop export.

## Stop Triggers

- A true Rust callback loop is required to satisfy this PR.
- Any generated UniFFI binding or `agent_core` edit becomes necessary.
- The fixture cannot produce finite repeatable samples.
- The slice starts touching graph/editor/production FFI files.

## Closeout - 2026-05-02

Closed as implemented and verified.

Artifacts:

- `benchmarks/results/2026-05-02t00-00-00-000z-r15-uniffi-callback-baseline-uniffi_callback_handle_roundtrip_10000.json`
- p50: `332.35` ns/call
- p95: `354.97204` ns/call
- p99: `358.44104799999997` ns/call
- samples: `7`
- iterations per sample: `10000`

Logs:

- Red source guard:
  `/tmp/epistemos-r15-uniffi-callback-pr5-red-20260502.log`
- Green source guard:
  `/tmp/epistemos-r15-uniffi-callback-pr5-source-guard-green-20260502.log`
- Green UniFFI callback handle baseline:
  `/tmp/epistemos-r15-uniffi-callback-pr5-green-20260502.log`

Verification:

- `EpistemosTests/BenchmarkHarnessSourceGuardTests`: 6 Swift Testing tests
  passed.
- `EpistemosTests/UniFFICallbackThroughputTests`: 2 Swift Testing tests passed.
- Xcode printed the existing SwiftLint package-plugin failures after
  `TEST SUCCEEDED`; the focused test commands exited 0.

Boundary:

This closes only the generated UniFFI callback-handle lowering/lifting fixture
baseline. The true Rust-to-Swift callback-loop benchmark remains open for a
later generated-transport gate.
