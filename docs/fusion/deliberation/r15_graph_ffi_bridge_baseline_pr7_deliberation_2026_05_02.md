# R15 Graph FFI Bridge Baseline - PR7 Deliberation

Date: 2026-05-02
Branch: feature/landing-liquid-wave
Scope: R15 benchmark harness only

## Gate

Replace the disabled/proxy Graph FFI benchmark with an enabled, test-owned
baseline that proves the benchmark crosses the live `GraphEngine`/C FFI bridge.
This is a benchmark fixture gate, not a renderer or physics optimization gate.

## Approved

- `EpistemosTests/Benchmarks/GraphFFIBenchmarkTests.swift`
- `EpistemosTests/BenchmarkHarnessSourceGuardTests.swift`
- `benchmarks/results/2026-05-02t00-00-00-000z-r15-graph-ffi-bridge-baseline-graph_ffi_bridge_fixture_250.json`
- This deliberation record
- R15 current-state/workcard docs

## Explicitly Not Approved

- `graph-engine/**` source changes
- Graph renderer/UI changes
- Live frame-rate claims
- Physics tuning or optimization
- Generated bindings/libraries
- Xcode project or entitlement changes
- Note editor changes

## Evidence

Red:
`/tmp/epistemos-r15-graph-ffi-pr7-red-20260502.log`

The new source guard failed against the old disabled/proxy benchmark because it
lacked `GraphFFIBaselineRunner`, `GraphEngine(device:)`,
`graph_engine_node_screen_pos`, and `live_graph_engine_ffi_fixture`, and still
contained `try? BenchmarkRunRecorder` plus disabled suite text.

Green:
`/tmp/epistemos-r15-graph-ffi-pr7-green-20260502.log`

Focused command:

```bash
set -o pipefail
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/GraphFFIBenchmarkTests -only-testing:EpistemosTests/BenchmarkHarnessSourceGuardTests test 2>&1 | tee /tmp/epistemos-r15-graph-ffi-pr7-green-20260502.log
```

Result: `TEST SUCCEEDED`; 11 Swift Testing tests passed. Existing SwiftLint
package-plugin lines appeared after success, same as earlier R15 slices.

## Runtime Claim

The baseline creates a live `GraphEngine` with `CAMetalLayer`, adds and commits
a 250-node fixture, runs Rust-backed search, calls raw C
`graph_engine_node_screen_pos`, exercises visibility refresh and force-parameter
surfaces, and records the result through `BenchmarkRunRecorder`.

It explicitly does not claim live graph renderer FPS; metadata records
`render_status=not_live_render_frame_rate`.

## Artifact

`benchmarks/results/2026-05-02t00-00-00-000z-r15-graph-ffi-bridge-baseline-graph_ffi_bridge_fixture_250.json`

- p50: 68,846,708 ns per fixture roundtrip
- p95: 100,320,625 ns per fixture roundtrip
- p99: 102,145,625 ns per fixture roundtrip
- sample count: 5
- node count: 250
- edge count: 280
