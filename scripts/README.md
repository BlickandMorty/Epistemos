# Epistemos Test Scripts

Convenient shell scripts for running tests, generating test suites, and profiling the Epistemos macOS app.

## Quick Reference

| Script | Purpose | Time |
|--------|---------|------|
| `run_all_tests.sh` | Run everything (Rust + Swift) | ~10-15 min |
| `run_quick_test.sh` | Fast subset for dev feedback | ~2-3 min |
| `run_rust_tests.sh` | Rust/graph-engine only | ~30 sec |
| `run_swift_tests.sh` | Swift tests only | ~8-12 min |
| `launch_audit_app.sh` | Build and launch isolated latest-build audit app | varies |

## Release Scripts

### release/build_release_app.sh
Build the Release app into a dedicated DerivedData folder, optionally sign it with `Developer ID Application`, and run the shipping-bundle preflight.

```bash
# Local unsigned verification
./scripts/release/build_release_app.sh

# Distributable build
EPISTEMOS_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
./scripts/release/build_release_app.sh
```

Output app path:
- `build/release-derived-data/Build/Products/Release/Epistemos.app`

### release/release_preflight.sh
Validate a built `.app` bundle before DMG packaging.

Checks:
- main executable + universal architecture
- Rust dylibs (`libepistemos_core.dylib`, `libagent_core.dylib`, `libomega_mcp.dylib`, `libomega_ax.dylib`)
- privacy manifest + model manifest + font bundle
- Knowledge Fusion runtime assets
- no accidental `Contents/PlugIns`
- no bundled model weights or secret files
- codesign verification when the app is signed

```bash
./scripts/release/release_preflight.sh \
  build/release-derived-data/Build/Products/Release/Epistemos.app
```

### release/create_release_dmg.sh
Create a drag-to-Applications DMG from a preflight-clean app bundle and optionally sign the DMG.

```bash
# Unsigned local packaging test
./scripts/release/create_release_dmg.sh \
  build/release-derived-data/Build/Products/Release/Epistemos.app

# Signed DMG
EPISTEMOS_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
./scripts/release/create_release_dmg.sh \
  build/release-derived-data/Build/Products/Release/Epistemos.app
```

Outputs:
- `build/release-artifacts/Epistemos.dmg`
- `build/release-artifacts/Epistemos.dmg.sha256`

### release/notarize_release_dmg.sh
Submit the DMG to Apple notarization, download the notarization log, staple the ticket, and validate the stapled result.

```bash
# Preferred: keychain profile already configured
EPISTEMOS_NOTARY_PROFILE="epistemos-notary" \
./scripts/release/notarize_release_dmg.sh \
  build/release-artifacts/Epistemos.dmg

# Fallback: explicit credentials
EPISTEMOS_NOTARY_APPLE_ID="you@example.com" \
EPISTEMOS_NOTARY_TEAM_ID="TEAMID1234" \
EPISTEMOS_NOTARY_PASSWORD="app-specific-password" \
./scripts/release/notarize_release_dmg.sh \
  build/release-artifacts/Epistemos.dmg
```

Output:
- notarization logs under `build/notary-logs/`

## Test Runner Scripts

### run_all_tests.sh
Run the complete test suite including both Rust and Swift tests.

```bash
./scripts/run_all_tests.sh
```

**Output:**
- Build status
- Rust test results (2,143 tests)
- Swift test results (10,071 tests)
- Summary with pass/fail counts
- Log files saved to `test_results/`

### run_quick_test.sh
Fast subset of tests for rapid development feedback.

```bash
./scripts/run_quick_test.sh
```

Runs a curated subset of ~20 tests that cover core functionality.

### run_rust_tests.sh
Run only the Rust/graph-engine tests.

```bash
./scripts/run_rust_tests.sh
```

### run_swift_tests.sh
Run only the Swift tests.

```bash
./scripts/run_swift_tests.sh
```

## Category-Specific Test Runners

### run_performance_tests.sh
Run performance benchmarks using XCTest metrics.

```bash
./scripts/run_performance_tests.sh
```

**Includes:**
- Note operation benchmarks
- Graph layout benchmarks
- Chat/Latency benchmarks
- Startup time benchmarks
- Memory pressure tests
- CPU intensive tests
- I/O benchmarks

### run_memory_leak_tests.sh
Run memory leak detection tests.

```bash
./scripts/run_memory_leak_tests.sh
```

**Tests:**
- Basic deallocation
- Retain cycle detection
- Closure capture validation
- Async/await leak detection
- Singleton cleanup
- Memory graph validation

### run_stability_tests.sh
Run crash recovery and stability tests.

```bash
./scripts/run_stability_tests.sh
```

**Tests:**
- Crash detection
- Watchdog termination handling
- App hang detection
- Graceful degradation
- Soft failure handling
- State restoration
- Signal handling

### run_chaos_tests.sh
Run chaos engineering tests.

```bash
./scripts/run_chaos_tests.sh
```

**Tests:**
- Network failures (delay, timeout, packet loss)
- Resource exhaustion (memory, disk, CPU)
- Timing issues (race conditions, deadlocks)
- State corruption
- Dependency failures

## Development Scripts

### launch_audit_app.sh
Build the latest Debug app into dedicated audit `DerivedData`, clone it into a
separate `Epistemos Audit` bundle id/app name, clear sticky restore and vault
defaults for that audit domain, and launch it without drifting back to the
installed `/Applications/Epistemos.app`.

```bash
# Build latest and launch isolated audit app
./scripts/launch_audit_app.sh

# Reuse the existing audit build and launch a bare minimal home scene
./scripts/launch_audit_app.sh --no-build --minimal-home
```

The isolated bundle is written to:
- `build/audit-app/EpistemosAudit.app`

The dedicated build lives under:
- `build/audit-derived-data/`

### test_watch.sh
Watch mode - continuously runs tests on file changes.

```bash
# Requires fswatch: brew install fswatch
./scripts/test_watch.sh
```

Automatically rebuilds and runs quick tests when you save files.

### list_tests.sh
List all available test categories with counts.

```bash
./scripts/list_tests.sh
```

### ci_test.sh
CI/CD optimized test runner.

```bash
./scripts/ci_test.sh
```

Produces machine-readable output and proper exit codes for CI systems.
It uses dedicated `DerivedData` and cloned source package directories under
`test_results/` so cold verification does not depend on Xcode's global package
cache behavior.

## Test Generation Scripts

### generate_all_tests_comprehensive.sh
Generate all test suites (basic + advanced + chaos + property-based).

```bash
./scripts/generate_all_tests_comprehensive.sh
```

**Generates:**
- 6,000 basic category tests
- 642 edge case tests
- 101 performance benchmarks
- 370 memory leak tests
- 215 stability tests
- 250 chaos tests
- 530 property-based tests

### Individual Generators

```bash
# Basic category tests
python3 scripts/generate_tests.py

# Performance benchmarks
python3 scripts/generate_performance_benchmark_tests.py

# Memory leak detection
python3 scripts/generate_memory_leak_tests.py

# Crash/stability tests
python3 scripts/generate_crash_recovery_tests.py

# Chaos engineering
python3 scripts/generate_chaos_tests.py

# Property-based tests
python3 scripts/generate_property_based_tests.py
```

## Usage Examples

### Daily Development Workflow

```bash
# 1. Quick validation during development
./scripts/run_quick_test.sh

# 2. Before committing - run full suite
./scripts/run_all_tests.sh

# 3. Watch mode for continuous feedback
./scripts/test_watch.sh
```

### Debugging Specific Issues

```bash
# Memory leak investigation
./scripts/run_memory_leak_tests.sh

# Performance regression check
./scripts/run_performance_tests.sh

# Stability after crash fixes
./scripts/run_stability_tests.sh
```

### CI/CD Integration

```bash
# In your CI pipeline
./scripts/ci_test.sh

# Check exit code
if [ $? -eq 0 ]; then
    echo "Tests passed!"
else
    echo "Tests failed!"
    exit 1
fi
```

### Deterministic Swift Verification

`ci_test.sh` and `run_swift_tests.sh` both use:

- `xcodebuild build-for-testing`
- `xcodebuild test-without-building`
- an isolated `DerivedData` path under `test_results/`
- an isolated cloned source packages path under `test_results/`

That makes rebuilt verification more reproducible on machines where Xcode's
default global package checkout path is flaky.

### Running Specific Test Suites

```bash
# Run just one test file
xcodebuild test \
    -project Epistemos.xcodeproj \
    -scheme Epistemos \
    -only-testing:EpistemosTests/NotePerformanceBenchmarkTests

# Run multiple specific suites
xcodebuild test \
    -only-testing:EpistemosTests/GraphTypesTests \
    -only-testing:EpistemosTests/GraphModelTests
```

## Output Locations

All scripts save results to `test_results/`:

```
test_results/
├── rust_tests_20260303_120000.log
├── swift_build_20260303_120000.log
├── swift_tests_20260303_120000.log
└── swift_tests_20260303_120000.xcresult
```

View detailed Xcode results:
```bash
open test_results/*.xcresult
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All tests passed |
| 1 | One or more tests failed |

## Requirements

- macOS 14+
- Xcode 15+
- Rust toolchain (for graph-engine tests)
- Optional: `fswatch` for watch mode (`brew install fswatch`)

## Tips

1. **Start with quick tests** during development
2. **Run full suite** before commits
3. **Use watch mode** for TDD workflow
4. **Check logs** in `test_results/` when tests fail
5. **Use Instruments** for performance/memory profiling

## Troubleshooting

### Tests not running
```bash
# Rebuild with the isolated script-managed paths
./scripts/run_all_tests.sh
```

### Permission denied
```bash
chmod +x scripts/*.sh
```

### fswatch not found (for watch mode)
```bash
brew install fswatch
```
