# Build, Test, and Verification Audit

Date: 2026-04-25

## Commands available

| Command | Purpose | State |
|---|---|---|
| `xcodegen generate` | regenerate `Epistemos.xcodeproj/project.pbxproj` from `project.yml` | runs in CI (`.github/workflows/ci.yml:103`) |
| `bash build-rust.sh` | build all Rust crates as static/dynamic libs | chained in pre-build (`project.yml:94-100`) |
| `bash build-syntax-core.sh` | build syntax-core | chained |
| `bash build-omega-mcp.sh`, `build-omega-ax.sh`, `build-epistemos-core.sh`, `build-agent-core.sh` | per-crate builds | chained |
| `bash bundle-app-runtime-assets.sh` | post-build asset bundling | chained |
| `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build` | Swift app build | per CLAUDE.md |
| `xcodebuild ... test -only-testing:EpistemosTests/...` | focused Swift tests | per CLAUDE.md |
| `cargo test --manifest-path agent_core/Cargo.toml` | Rust tests per crate | per CLAUDE.md |
| `bash scripts/run_reliability_quality_gates.sh` | reliability gate (baseline + sanitizers) | manual |

## Test counts

**Swift Testing**: 201/212 test files have `@Test`/`@Suite` (~95% enabled).

**Rust**: 191+ test blocks across 7 crates; 0 `#[ignore]` directives.

**Phase R regression suites** (verified present):
- `EpistemosTests/ResourceRuntimeRegressionTests.swift` — 8 @Test (300 lines)
- `EpistemosTests/ResourceRuntimeToolPathE2ETests.swift` — 4 @Test (329 lines)
- `EpistemosTests/PhaseRPermissionBridgeTests.swift` — 9 @Test (217 lines)
- `EpistemosTests/PhaseR4DropdownBackfillTests.swift` — 20 @Test (366 lines)
- `EpistemosTests/PhaseR5ChatGrantWiringTests.swift` — 9 @Test (231 lines)
- Total: 50 Phase R tests (matches expected ~41 + margin)

**App Store hardening** (S.4): `EpistemosTests/AppStoreHardeningTests.swift` — 16-test suite covering policy profile recognition, MAS entitlements drift, Pro-only exclusions, bookmark coverage, file-I/O cost, per-file MAS-branch regressions.

**Privacy manifest drift**: AppStoreHardeningTests `:74-85` enforces `PrivacyInfo.xcprivacy` shape.

**Benchmarks**:
- `EpistemosTests/Benchmarks/GraphFFIBenchmarkTests.swift` — disabled-by-default (`@Suite(.disabled)` at `:17`); manual via `xcodebuild test -only-testing:EpistemosTests/GraphFFIBenchmarkTests`.
- `EpistemosTests/Benchmarks/CodeEditorBenchmarkTests.swift` — same pattern.
- `graph-engine/benches/graph_ffi_baselines.rs` — criterion benchmarks.
- Signpost subsystem: `com.epistemos.bench`.

## Disabled tests (TRUSTWORTHINESS GAP)

CORRECTION 2026-04-25: direct verification (`head` of each file) shows three test
files are disabled, not four. `InstantRecallTests.swift` is active (has `@Suite`
and `@Test` at top, calls into the service). Earlier parallel-agent count of
~2,140 disabled lines was approximate.

| File | Lines | Status (verified 2026-04-25) | Re-enable reason annotated? |
|---|---|---|---|
| `EpistemosTests/InstantRecallTests.swift` | 306 | **ACTIVE** — has `@Suite("InstantRecall — Service")` + `@Test` blocks at top | n/a (active) |
| `EpistemosTests/HermesSubprocessTests.swift` | 1697 | DISABLED at `:5` `#if false`; **annotated 2026-04-25** with explicit re-enable plan (Phase Omega-2) | YES (Patch 14a) |
| `EpistemosTests/ExecutionContextTests.swift` | 136 | DISABLED at `:4` `#if false`; pre-existing reason comment ("legacy ExecutionContext type absent") | YES (already) |
| `EpistemosTests/HermesBridgeIntegrationTests.swift` | unknown | DISABLED at `:10` `#if false`; pre-existing reason comment ("legacy HermesRuntimeRoute bridge absent") | YES (already) |
| `EpistemosTests/RuntimeValidationTests.swift` | 6 conditional `#if false` blocks | non-blocking; gates 6 specific tests | n/a (intentional sub-block gates) |

**Total disabled (corrected)**: ~1,830 lines across 3 files. All three have
explicit re-enable rationale comments.

**Severity**: MEDIUM (down from HIGH after correction). The trustworthiness gap is
documented; the disabled code is gated by absent legacy types/bridges and would
not compile if re-enabled today. Re-introduction would require the
corresponding feature returning first.

**Recommendation**: For each disabled block, either (a) re-enable with current code, (b) delete code if intentionally deprecated, or (c) annotate with explicit re-enable date / condition + linked issue.

## Reliability gate (S.5) state

**Decoupling**: `scripts/run_reliability_quality_gates.sh:17-43` separates `DERIVED_DATA_ROOT` from `RESULT_ROOT`. If project root is in TCC-protected folder (`~/Downloads`, `~/Desktop`, `~/Documents`), DerivedData routed to `${TMPDIR:-/tmp}/epistemos-reliability-derived-data/${timestamp}` (`:36`). Otherwise artifact directory (`:39`). Timestamp prevents cross-run cache collisions (`:30`).

**Gates available**: baseline, perf_diagnostics, asan, tsan, ubsan, soak_repeat (`:9`).

**Recent commits**:
- `a6f0fa99 docs(S.5): record full reliability gate green evidence`
- `4a35105b fix(S.5): timestamp protected reliability DerivedData roots`
- `d46594c8 fix(S.5): decouple reliability DerivedData from RESULT_ROOT and record /tmp baseline green`

**Gate state**: claim is GREEN per recent commits; the doc-truth verification I would do (running the gate fresh) is TBD this session.

**Severity**: MEDIUM until I personally run baseline and observe a clean tail. Documented evidence is recent; trust but verify.

## CI

`.github/workflows/ci.yml:1-148`:
1. Rust build + test in order: graph-engine → epistemos-core → omega-ax → omega-mcp → agent_core (`cargo test --target aarch64-apple-darwin`).
2. Cargo clippy + fmt check on all 5 crates.
3. `xcodegen generate` (`:103`).
4. SPM dependency resolution (10-min timeout, `:105-111`).
5. Swift build-for-testing (`:113-121`).
6. Swift test-without-building with result bundle upload, 14-day retention (`:123-139`).

**CI runs full pipeline on every push/PR to main.** Confidence: HIGH.

## Build products (verified in `build-rust/`)

- `libagent_core.dylib` ✓
- `libepistemos_core.dylib` ✓
- `libgraph_engine.a` ✓
- `libomega_ax.dylib` ✓ (Pro-only; scrubbed from MAS)
- `libomega_mcp.dylib` ✓
- `libsyntax_core.a` ✓
- `librust_all.a` ✓ (unified)

**Swift bindings**:
- `omega_mcp.swift`, `omega_ax.swift`, `epistemos_core.swift`, `agent_core.swift` ✓
- Module maps: `omega_mcpFFI.modulemap`, `omega_axFFI.modulemap`, `epistemos_coreFFI.modulemap`, `agent_coreFFI.modulemap` ✓

## Smoke test plan (recommended for every release candidate)

1. Cold launch app.
2. Open / create a vault.
3. Create a note. Type 200 chars. Save.
4. Edit the note. Save.
5. Search for note (FTS5).
6. Open graph view. Pan + zoom 30s.
7. Start a chat with cloud model in Fast mode.
8. Stream AI response.
9. Switch to Pro mode + cloud model. Send "find my note about X". Verify tool invocation (per BLOCKER G1).
10. Switch to Agent mode + cloud model. Send a multi-step task. Verify thinking trail + tool use.
11. Trigger Contextual Shadows recall (when wired). Open related note from results.
12. Right-click chat → "Open run" (when wired). Verify Raw Thoughts folder appears with manifest + events.
13. Open Settings → Privacy. Verify pane content matches deployment profile.
14. Restart app. Verify data persists. Verify bookmark restore. Verify previously-stored permission grants survive.
15. Open Activity Monitor + Instruments. Verify no thread spike during typing; no unbounded memory growth.

## Required new tests (P0/P1 for V1)

| Test | Priority | Surface |
|---|---|---|
| Pro+Cloud invokes `vault_search` for "find note" intent | P0 | ChatCoordinator + PipelineService |
| Raw Thoughts artifact is emitted with manifest+events on chat completion | P0 | agent_core session_store + Swift consumer |
| Code editor: 4k-line .swift file open <500ms; keystroke-to-highlight <16ms | P1 | CodeEditorView + syntax-core |
| Contextual Shadows panel renders top-K results within 100ms of click | P1 | ContextualShadowsState + Panel |
| Sync `InstantRecallService.rebuildIndex` panics in DEBUG | P1 | InstantRecallService precondition |
| MAS bundle size CI gate (<600MB) | P2 | CI workflow |
| Re-enable disabled InstantRecallTests / HermesSubprocessTests after design review | P2 | tests directory |

## Verdicts

**(a) Test trustworthiness**: MEDIUM. 95% of files enabled, but ~2,140 lines of high-leverage tests disabled with no documented plan. This is the dominant build-test risk for V1.

**(b) Reliability gate currently green?**: ASSUMED GREEN per recent commit messages, NOT INDEPENDENTLY VERIFIED in this session. Trust but plan to re-run before ship.

**(c) Top build/test gap**: re-enable or document the disabled blocks (InstantRecallTests, HermesSubprocessTests). Add a 4k-line code editor regression test. Add automated agent-stream baseline (currently TBD in `AGENT_STREAM_BASELINES.csv`).

**(d) Signposts + benchmarks for regression detection**: PARTIAL. Foundation in place (signpost subsystem, benchmark harness, baselines CSV) but automated gating is incomplete. Swift benchmarks are manual-only. Move at least one benchmark suite to CI nightly.

Confidence: HIGH on test inventory + CI structure (verified); MEDIUM on reliability gate freshness (not re-run this session).
