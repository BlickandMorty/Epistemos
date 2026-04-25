# Phase S -- App Store Hardening Audit

**Date:** 2026-04-24
**Scope:** audit the current App Store (MAS) build hardening state immediately after Phase R closure. This is the first Phase S deliverable. It does not add new hardening; it documents what exists so subsequent sub-phases can target real gaps instead of rehardening things that are already in place.

**Companion code:** `EpistemosTests/AppStoreHardeningTests.swift` (7-test Phase S hardening suite -- policy-profile FFI drift, entitlements plist drift, Info.plist drift; see section 5 for the full enumeration).

Master plan section: [AMBIENT_RECALL_HALO_MASTER_PLAN.md §1.7 "App Store First"](AMBIENT_RECALL_HALO_MASTER_PLAN.md).
Plan section: [IMPLEMENTATION_PLAN_FROM_ADVICE.md §Phase S](IMPLEMENTATION_PLAN_FROM_ADVICE.md).

---

## 1. MAS build target wiring

Project `project.yml` defines two app targets:

- `Epistemos` (Pro / default) -- bundle id `com.epistemos.app`, entitlements `Epistemos/Epistemos.entitlements`.
- `Epistemos-AppStore` -- bundle id `com.epistemos.appstore`, entitlements `Epistemos/Epistemos-AppStore.entitlements`, Info.plist `Epistemos-AppStore-Info.plist`, compilation flags `EPISTEMOS_APP_STORE MAS_SANDBOX`.

The MAS binary is kept clean by two independent mechanisms. Both matter; neither alone is sufficient.

### 1a. Source-set exclusions in `project.yml`

The `Epistemos-AppStore` target omits these files from compilation at all:

- `Engine/ClaudeManagedRuntime.swift`
- `Engine/LocalRustRuntime.swift`
- `KnowledgeFusion/Alignment/scripts/**`
- `KnowledgeFusion/MOHAWK/**`
- `KnowledgeFusion/MoLoRA/...` (python training surfaces)
- `Omega/Knowledge/ODIATraceGenerator.swift`
- `Omega/Knowledge/TraceDataMixer.swift`
- `Vault/KnowledgeGraphService.swift`
- `build-rust/swift-bindings/omega_ax.swift` (AXorcist computer-use bindings)

These files do not exist in the MAS compilation unit at all.

### 1b. Compile-condition pruning with App Store stubs

A separate set of Pro-only files remains in the MAS source set but is pruned at compile time with `#if !EPISTEMOS_APP_STORE` / `#if EPISTEMOS_APP_STORE` branches. `Epistemos/AppStore/AppStoreComputerUseStubs.swift` supplies no-op or safe replacements so the Swift type graph still links. Current call sites using this pattern include `AppBootstrap.swift`, `EpistemosApp.swift`, `AppEnvironment.swift`, `Phase4Bridge.swift`, `ComputerUseBridge.swift`, `NightBrainService.swift`, `GhostComputerAgent.swift`, `AXMutationDetector.swift`, `VisualVerifyLoop.swift`.

Practical difference: under (1a) the code genuinely does not exist in the binary, so no re-enable-by-flag risk. Under (1b) the code exists in source and is gated; correctness depends on every gate being written correctly. Phase S drift watch should sample new `#if !EPISTEMOS_APP_STORE` sites when they land and confirm the stub-side path preserves MAS safety.

---

## 2. Entitlements comparison

### MAS (`Epistemos/Epistemos-AppStore.entitlements`)

| Key | Value | Justification |
|---|---|---|
| `com.apple.security.app-sandbox` | true | Required by App Store. No exceptions. |
| `com.apple.security.cs.allow-jit` | true | MLX Metal compute shader JIT. Apple-approved for on-device AI; needs a note in the review submission. |
| `com.apple.security.files.bookmarks.app-scope` | true | Security-scoped bookmarks for vault folder persistence across launches. |
| `com.apple.security.files.user-selected.read-write` | true | User-picked vault folder and attachment files. |
| `com.apple.security.network.client` | true | Cloud model API calls (Anthropic / OpenAI / Perplexity). |

### Pro-only (`Epistemos/Epistemos.entitlements`) -- NOT in MAS

| Pro key | Why it cannot ship to MAS |
|---|---|
| `com.apple.security.cs.allow-unsigned-executable-memory` | Arbitrary dylib loading; blocked by App Review. |
| `com.apple.security.cs.disable-library-validation` | Same. |
| `com.apple.security.automation.apple-events` | AppleScript dispatch to other apps (iMessage, etc.); Pro-only per deployment-profile decision. |
| `com.apple.security.files.bookmarks.document-scope` | Per-document sandbox bookmarks; Pro-only scope. |
| `com.apple.security.temporary-exception.mach-lookup.global-name` | `com.apple.accessibility.api` mach service used by AXorcist for computer use; Pro-only. |

**Audit result:** the MAS plist is a minimal, review-safe entitlement profile. It is NOT a strict subset of the Pro plist -- MAS declares `com.apple.security.app-sandbox` (which Pro omits since Pro is distributed Developer ID outside the sandbox), while omitting all Pro-only entitlements that would trigger App Review blockers (unsigned executable memory, disable library validation, AppleScript automation, document-scope bookmarks, and the accessibility mach-lookup exception used by the computer-use feature). No action required for Phase S.2 entitlements scope.

---

## 3. Privacy manifest

`Epistemos/Resources/PrivacyInfo.xcprivacy` declares:

- `NSPrivacyTracking = false` -- no ad/attribution tracking.
- `NSPrivacyTrackingDomains = []` -- no tracking SDK domains.
- `NSPrivacyCollectedDataTypes = []` -- zero user-data collection categories.
- `NSPrivacyAccessedAPITypes` -- 4 required-reason APIs declared:
  - `NSPrivacyAccessedAPICategoryFileTimestamp` / reason `C617.1` (display timestamps to user).
  - `NSPrivacyAccessedAPICategorySystemBootTime` / reason `35F9.1` (measure elapsed time for a user interaction).
  - `NSPrivacyAccessedAPICategoryDiskSpace` / reason `E174.1` (show storage info to user).
  - `NSPrivacyAccessedAPICategoryUserDefaults` / reason `CA92.1` (read/write app-local defaults).

**Audit result:** manifest is minimal and App-Store-submission-ready. Any future code path that calls a fifth required-reason API must be added here with a valid reason code at the time the call lands.

---

## 4. Rust `mas-sandbox` feature gate coverage

The `mas-sandbox` Cargo feature is the compile-time switch that removes Pro-only tool registrations and runtime behaviors from the shipped binary. Survey:

- 40+ `#[cfg(feature = "mas-sandbox")]` and `#[cfg(not(feature = "mas-sandbox"))]` gates across `agent_core/src/`, concentrated in `tools/registry.rs` (tool registration) and `bridge.rs` (FFI surfaces).
- Three dedicated MAS-runtime helpers live under `#[cfg(feature = "mas-sandbox")]`:
  - `mas_runtime_forbids_tool(&str) -> bool`
  - `mas_allows_bounded_internal_mutation(&str, &Value) -> bool`
  - `mas_runtime_preflight(...)`
- Registry defaults flip for MAS: `enable_bash = !cfg!(feature = "mas-sandbox")`.

### Existing Rust tests (gated to run only under `cargo test --features mas-sandbox`):

- `mas_sandbox_registry_excludes_unbounded_tools`
- `mas_runtime_denies_forbidden_tool_even_if_registered`
- `mas_runtime_denies_destructive_tool_even_if_registered`
- `mas_runtime_denies_unscoped_mutating_tool`

**Audit result:** Rust-side gate coverage is dense and tested. The drift risk is at the LINK boundary, not the code boundary: a Pro-built `libagent_core` accidentally linked into the MAS Xcode target would silently fail the gate. Bootstrap check `AppBootstrap.verifyAgentCorePolicyProfile()` fatals on this at launch; `AppStoreHardeningTests` now also asserts it from Swift Testing so CI catches it before a user can.

---

## 5. Policy-profile FFI

`agent_core/src/bridge.rs:239 agent_core_policy_profile() -> String` returns one of:

- `"direct"` -- built without `--features mas-sandbox` (Pro).
- `"mas_sandbox"` -- built with `--features mas-sandbox` (MAS).

Swift side: `Epistemos/App/AppBootstrap.swift:2686 verifyAgentCorePolicyProfile()` runs at launch and fatalError's if the `EPISTEMOS_APP_STORE || MAS_SANDBOX` build flag and the linked Rust profile disagree. This is the single point that catches the link-mismatch drift case.

`EpistemosTests/AppStoreHardeningTests.swift` replicates the check from Swift Testing with sixteen tests (each may contain multiple assertions):

1. `policyProfileReturnsRecognizedValue` -- fails if the FFI returns an unrecognized string (drift catcher for future profile additions).
2. `policyProfileMatchesBuildFlag` -- fails when `EPISTEMOS_APP_STORE || MAS_SANDBOX` is set but the linked profile is not `"mas_sandbox"`, and vice versa. This is the same invariant the bootstrap check enforces.
3. `masEntitlementsDeclareRequiredKeys` -- parses `Epistemos/Epistemos-AppStore.entitlements` via `#filePath` and asserts the four keys the MAS archive needs are present (`app-sandbox`, `network.client`, `files.user-selected.read-write`, `files.bookmarks.app-scope`).
4. `masEntitlementsOmitProOnlyKeys` -- asserts the MAS plist does NOT contain any of the Pro-only review blockers (`allow-unsigned-executable-memory`, `disable-library-validation`, `automation.apple-events`, `temporary-exception.mach-lookup.global-name`, `files.all`, `files.bookmarks.document-scope`).
5. `proEntitlementsStillCarryProOnlyKeys` -- asserts the Pro plist still carries the Pro-only keys so the MAS forbidden-keys test cannot pass trivially if Pro narrows.
6. `masInfoPlistDeclaresExportComplianceAnswer` -- asserts the MAS `Info.plist` declares `ITSAppUsesNonExemptEncryption`, so App Store Connect does not prompt the export-compliance questionnaire on every submission.
7. `masInfoPlistKeepsUsageDescriptionsNonEmpty` -- asserts five usage-description strings (`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `NSDocumentsFolderUsageDescription`, `NSDesktopFolderUsageDescription`, `NSDownloadsFolderUsageDescription`) are present and non-empty in the MAS `Info.plist`.
8. `audioTranscriberMASBranchHasNoProcessInit` -- per-file MAS-branch regression for `AudioTranscriber.swift`. Strips lines inside `#if !EPISTEMOS_APP_STORE ... #endif` to simulate what the MAS compiler sees, then asserts the MAS-visible source contains no `Process.init(`. Also asserts the gate marker is still present and the Pro-visible source still contains `Process.init(` so a future change that deletes the subprocess fallback entirely is flagged (the Pro/direct release needs MLX Whisper + whisper.cpp).
9. `vaultSyncServiceMASBranchHasNoTMUtilProcessInit` -- per-file MAS-branch regression for `Sync/VaultSyncService.swift`. Walks the file line by line, tracks `#if !EPISTEMOS_APP_STORE` and `#else` boundaries explicitly (because the gate uses an `#else` clause that the simple `masVisibleSource` parser does not interpret), and asserts every `Process.init(` occurrence is inside an `#if !EPISTEMOS_APP_STORE` block. Also asserts the Pro-visible source still contains `Process.init(` so a future change that deletes the tmutil layer entirely is flagged.
10. `vaultChatMutatorMASBranchHasNoGitProcessInit` -- per-file MAS-branch regression for `Vault/VaultChatMutator.swift`. Uses the shared `scanForMarkerInGateBranches(source:marker:)` helper (the explicit-`#else`-aware per-line parser also used by the VaultSyncService test) and asserts on TWO independent markers:
    - **Marker 1 -- `Process.init(`**: the literal subprocess-spawn primitive must appear only inside an `#if !EPISTEMOS_APP_STORE` block (and must still appear there so a future change ripping out the Pro git audit-trail layer entirely gets flagged separately).
    - **Marker 2 -- `process.arguments = ["git"]`**: the git-launch argv shape must also appear only inside an `#if !EPISTEMOS_APP_STORE` block. This catches the drift where someone keeps `Process.init(` gated but moves the git-specific argv prep outside the gate -- which would silently let MAS prepare a git command line even when it cannot run it. The two markers must agree on the gate.
11. `adapterExporterMASBranchHasNoDittoLaunchMarkers` -- per-file MAS-branch regression for `KnowledgeFusion/Adapters/AdapterExporter.swift`. Driven by a `KFMASGateSpec` row + `runKFMASGateRegression(_:)` runner; checks five markers via `assertMarkerIsMASGated(source:fileLabel:marker:)`: `Process.init(`, `process.executableURL`, `process.arguments`, `try process.run()`, `/usr/bin/ditto`.
12. `ktoTrainerMASBranchHasNoPythonLaunchMarkers` -- per-file MAS-branch regression for `KnowledgeFusion/Alignment/KTOTrainer.swift`. Four Process API markers: `Process.init(`, `process.executableURL`, `process.arguments`, `try process.run()`.
13. `qLoRATrainerMASBranchHasNoPythonLaunchMarkers` -- per-file MAS-branch regression for `KnowledgeFusion/Training/QLoRATrainer.swift`. Same four Process API markers as KTOTrainer: `Process.init(`, `process.executableURL`, `process.arguments`, `try process.run()`.
14. `moLoRAInferenceServiceMASBranchHasNoPythonLaunchMarkers` -- per-file MAS-branch regression for `KnowledgeFusion/MoLoRA/MoLoRAInferenceService.swift`. Four markers using the `proc` variable name (this file uses `proc`, not `process`): `Process.init(`, `proc.executableURL`, `proc.arguments`, `try proc.run()`.
15. `pythonEnvironmentManagerMASBranchHasNoInstallerMarkers` -- per-file MAS-branch regression for `KnowledgeFusion/PythonEnvironmentManager.swift`. Eight markers: the four Process API markers (`Process.init(`, `process.executableURL`, `process.arguments`, `try process.run()`) plus the four installer-pipeline literals (`/bin/bash`, `curl`, `/opt/homebrew/bin/brew`, `/usr/bin/env`). Catches Homebrew installer, brew install, env-which python sweep, and the Process Foundation API together.
16. `chunkedMCPFramingHasNoDlopenWorkaround` -- regression for the Phase S.2 Category B C-shim replacement. Asserts (a) `epistemos_shm_open` is referenced (so the shim path is still wired) and (b) `dlopen(`, `dlsym(`, `RTLD_LAZY` do not appear in non-comment code anywhere in `Epistemos/Bridge/ChunkedMCPFraming.swift`. Reuses the existing `scanForMarkerInGateBranches(source:marker:)` helper; for this file there is no `#if !EPISTEMOS_APP_STORE` gate, so any non-comment occurrence shows up in `outsideExcludedBlock`. Both flags must be false for each marker to pass.

**Runtime characteristic (observed, highly variable):** three consecutive Xcode app-hosted Swift Testing runs of this suite show the wall-clock cost attributed to the first file-I/O test swings across two orders of magnitude. No causal explanation has been proven.

| Run | Tests | Total | First-I/O test (`masEntitlementsDeclareRequiredKeys`) | Other tests | Exit |
|---|---|---|---|---|---|
| 1 | 5 | 48.282 s | 48.259 s | 0.001-0.021 s each | 0 |
| 2 | 7 | 250.093 s | 250.058 s | 0.001-0.031 s each | 0 |
| 3 | 7 | **7.485 s** | **7.451 s** | 0.001-0.028 s each | 0 |

Run 3 used the same 7 tests as Run 2 (same suite, same code), so the cost delta is NOT caused by test contents. Plausible explanations (none measured): thermal throttling on the Macbook after sustained CPU use in a prior run, concurrent background indexing competing for file-system resources, test-harness caching behavior, or variance in app-hosted runner launch time. `IDETestOperationsObserverDebug` reports the same wall clock as the first test (Run 3: 16.698 s elapsed total including build).

**Operational posture:** cold runs CAN be cheap (~7 s) but are not guaranteed to be. Expect highly variable cost. Do not assume "7/7 green" means "cheap to run"; do not panic at a 250 s run either. Before expanding this suite with file-I/O-heavy tests, measure; if a profiling run is warranted, the test-harness cost question is a Phase S follow-up, not a blocker on Phase S.2 drift testing.

---

## 6. Phase S exit criteria state (from master plan §1.7 memory note)

The master plan defines 6 hard exit criteria for Phase S. Current state:

| # | Criterion | Status |
|---|---|---|
| 1 | Register issues resolved (master plan phrasing mentions "19"; the register itself tracks 18 live items: I-001..I-017 plus I-019; I-018 was never assigned) | 15/18 FIXED, 3 PARTIAL by design (I-001 write-edge, I-002 sync holdouts, I-003 observer pattern). The 3 PARTIALs are architectural scope-guards with per-issue rationale in [KNOWN_ISSUES_REGISTER.md](KNOWN_ISSUES_REGISTER.md), not correctness regressions. |
| 2 | Full 2,679-test suite + S.4 additions pass in CI | Phase R slice (9 suites, 86 tests) green 2026-04-24. Full suite not yet re-run this session. |
| 3 | `codesign -d --entitlements` on MAS build shows App Sandbox = YES, no `allow-unsigned-executable-memory` | Source plist confirmed minimal (section 2 above). Runtime `codesign` check requires an actual MAS build; see follow-ups. |
| 4 | TestFlight: 10+ testers, 2+ cycles, zero critical open bugs | Not started. Open-ended section per master plan guidance. |
| 5 | App Store Connect: submission accepted, app live on MAS | Not started. |
| 6 | First 48h post-launch: no crash spike, rating >= 4.5 | Not applicable until launch. |

---

## 6a. Static-analysis scan for App Review blocker APIs (Phase S.2)

**Superseded-claim correction 2026-04-24:** an earlier pass of this section used a too-narrow `Process\(\)` regex that only matched the zero-argument call and missed `Process.init(...)` and `Process(launchPath: ...)` forms. A commit messaged "Process() is no longer referenced in the Swift source tree" was based on that narrow sweep and was wrong. This rewrite uses the broader ripgrep pattern and classifies every real hit against the MAS build target honestly.

### Sweep command (canonical, use this for follow-ups)

```
rg -n "Process\.init\(|Process\(|NSTask|dlopen\(|dlsym\(|posix_spawn|execv|fork\(" Epistemos --glob '*.swift'
```

After filtering out the RootView `.inProcess(...)` enum cases (substring false positives) and the comment-only mentions in the iMessage Doctor fix, the real hits break down as follows.

### Category A -- MAS-safe by compile gate (no action needed)

Two distinct gating shapes are used. Both make raw-tree subprocess-launch hits NOT emit into the MAS binary, but they differ in scope: file-top gates exclude the entire file from the MAS compilation unit; surgical gates leave the file in MAS and wrap only the subprocess-launch portions.

#### A1. File-top gates (`#if !EPISTEMOS_APP_STORE` wrapping the entire file)

The file is excluded from the MAS compilation unit in its entirety. No symbols from these files are visible to MAS-compiled code.

- `Epistemos/Omega/Vision/ScreenCaptureService.swift:153` -- `Process.init()` calling `/bin/launchctl kickstart` to restart replayd. Pre-existing file-top gate.
- `Epistemos/Harness/CompletionChecker.swift:208` -- `Process.init()` for `/usr/bin/env` harness eval runner. File-top gate added 2026-04-24.
- `Epistemos/Harness/EvalSandbox.swift:226` -- `Process.init()` sandboxed command runner. File-top gate added 2026-04-24.
- `Epistemos/Harness/HarnessLab.swift:947` -- `Process.init()` proposer-agent subprocess. File-top gate added 2026-04-24.
- `Epistemos/Harness/HarnessIntegration.swift` -- no raw Process.init in this file, but it references `CompletionResult` and `CompletionCheckerRegistry` from the now-gated `CompletionChecker.swift`. Gated with the same `#if !EPISTEMOS_APP_STORE` so the MAS build does not try to resolve those symbols.
- `Epistemos/Harness/HarnessRegistry.swift` -- no raw Process.init in this file, but `saveCandidateScores(...)` takes an `EvalSuiteResult` parameter (defined in the now-gated `HarnessLab.swift`). Gated with `#if !EPISTEMOS_APP_STORE` for the same reason.
- `Epistemos/Omega/Safety/ShadowGitCheckpoint.swift:82, 119` -- `Process.init()` calling `/usr/bin/git` for shadow-git checkpoint init and commit. Self-contained actor, zero external references in non-test MAS-compiled code. Gated at file-top.
- `Epistemos/KnowledgeFusion/SyntheticData/EmbodiedCaptureService.swift:267` -- `Process.init()` calling `/usr/sbin/screencapture` for synthetic-data trajectory capture. Audit confirmed zero type-level references anywhere in `Epistemos/` or `EpistemosTests/`; only source-text reads via `loadRepoTextFile` / `loadProductionHardeningRepoTextFile` (which are unaffected by compile gating because they read the file as text). MOHAWK Python scripts and JSON data files that mention the name are in the already-MAS-excluded `MOHAWK/**` directory. Gated at file-top.

The five gated Harness files were validated as a closed internal dependency set: grepping every Harness-exported type that comes from one of the gated files against the full Swift source tree showed zero references from MAS-compiled code outside `Harness/`. External references to Harness types from MAS-compiled code are only against `TraceCollector` (used by `Engine/TextCapturePipeline.swift`), which stays ungated because it does not use subprocess-launch APIs or depend on any gated type. `ShadowGitCheckpoint` is likewise self-contained -- only RuntimeValidationTests loads the file as raw text (not by symbol reference) so gating does not affect test compilation.

#### A2. Surgical in-file gates (MAS still compiles the file; only the subprocess-launch portions are wrapped)

The file stays in the MAS compilation unit because its public types are live API for MAS-reachable callers. `#if !EPISTEMOS_APP_STORE` wraps only the subprocess-using code (methods, fields, enum cases, switch arms, error-string variants). MAS callers' API is unchanged.

- `Epistemos/KnowledgeFusion/DataIngestion/AudioTranscriber.swift:292` -- `Process.init()` powering the `runProcess` helper used by `runMLXWhisper` (Python) and `runWhisperCpp` (`/usr/local/bin/whisper`). The file's `AudioTranscriber` actor + `AudioSegment` / `TranscribedAudio` / `AudioTranscriberError` types are live MAS API used by `Engine/ComposerVoiceInputService.swift` and `Views/Capture/QuickCaptureView.swift`, so whole-file gating was rejected. Surgical gate applied instead: `#if !EPISTEMOS_APP_STORE` wraps (a) the `.mlxWhisper` and `.whisperCpp` enum cases, (b) the matching switch arms in `transcribe()`, (c) the fallback detection branches in `detectBackend()`, (d) `runMLXWhisper` + `runWhisperCpp` + `runProcess` methods, (e) the `pythonPath` stored field (replaced with a `_ = pythonPath` discard in MAS init so callers' API stays unchanged). The MAS error description for `AudioTranscriberError.noBackendAvailable` is also gated -- MAS reports "Apple Speech is unavailable or not authorized. Audio transcription is unavailable." (no false promise of mlx-whisper / whisper.cpp), Pro keeps the original three-tool description. A `audioTranscriberMASBranchHasNoProcessInit` regression test in `EpistemosTests/AppStoreHardeningTests.swift` strips `#if !EPISTEMOS_APP_STORE` blocks and asserts the MAS-visible source contains no `Process.init(`.
- `Epistemos/Sync/VaultSyncService.swift:1261` -- `Process.init()` calling `/usr/bin/tmutil` for the OPTIONAL APFS safety-snapshot maintenance layer. Core vault sync (file-copy recovery snapshots via `pruneRecoverySnapshots`, SQLite backup, watcher-driven syncing) does NOT use tmutil and stays active in MAS. The file's `VaultSyncService` actor + `TMUtilCommandRunner` typealias + `setTMUtilCommandRunnerForTesting` injection point + every test seam are live MAS API. Surgical gate applied with TWO complementary guards: (i) inside `createAPFSSafetySnapshotIfPossible` and `pruneAPFSSafetySnapshotsIfNeeded`, an `#if EPISTEMOS_APP_STORE` early-return that fires when no `tmutilCommandRunnerOverride` has been injected, so MAS exits the optional layer silently with no soft-log noise; tests that wire a custom `TMUtilCommandRunner` still go through unchanged. (ii) the body of `runTMUtilCommand` is gated `#if !EPISTEMOS_APP_STORE` (Pro impl) `#else` (throws an "tmutil unavailable in App Store sandbox" `NSError`), as defense-in-depth in case a future caller wires up a path that bypasses the early-return. A `vaultSyncServiceMASBranchHasNoTMUtilProcessInit` regression test in `EpistemosTests/AppStoreHardeningTests.swift` walks the file line by line, tracks `#if !EPISTEMOS_APP_STORE` and `#else` boundaries explicitly (the simple-shape `masVisibleSource` parser does not interpret `#else`), and asserts every `Process.init(` occurrence is inside an `#if !EPISTEMOS_APP_STORE` block.
- `Epistemos/Vault/VaultChatMutator.swift:647` -- `Process.init()` calling `/usr/bin/env git` from `runGitOffMain`, used by `VaultMutationIO.commit(diff:)` to record an audit-trail git commit after the user approves a staged vault mutation. The file's `VaultChatMutator` final class is live user-facing API: `EpistemosApp.swift` reads `bootstrap.vaultChatMutator.stagedDiff` and calls `approvePendingDiff()` / `rejectPendingDiff()` directly from the SwiftUI sheet; `LiveNoteExecutor.swift` calls `stageFileMutation(...)` to stage AI-proposed file edits. Whole-file gating would break the user-approved-mutation flow in MAS. Surgical gate with TWO complementary changes: (i) inside `VaultMutationIO.commit(diff:)`, the unconditional `VaultVerifiedFileWriter.writeUTF8(...)` call (which durably writes the new bytes and validates a readback) stays first AND unconditional, so user-approved mutations always land on disk in MAS exactly the same as in Pro. The git block (`ensureGitRepository` + 3 `runGitOffMain` calls) is wrapped `#if !EPISTEMOS_APP_STORE` (Pro path: same git audit-trail commit returning the commit SHA) `#else` (MAS path: returns a placeholder reference `"mas-skipped-<UUID>"` so `lastCommitReference` records the approval honestly without faking a git SHA). Existing call sites already discard the return value (`_ = try await ... approvePendingDiff()` in `EpistemosApp.swift`), so the placeholder is safe. (ii) the body of `runGitOffMain` is gated `#if !EPISTEMOS_APP_STORE` (Pro impl) `#else` (throws `VaultChatMutatorError.gitCommandFailed("git is not available in the App Store sandbox build; staged vault mutations are committed file-only without a git audit trail.")`) as defense-in-depth in case a future caller bypasses the commit-level skip. A `vaultChatMutatorMASBranchHasNoGitProcessInit` regression test asserts BOTH that every `Process.init(` AND every `process.arguments = ["git"]` argv-shape line is inside an `#if !EPISTEMOS_APP_STORE` block. The two-marker check catches the drift case where someone keeps `Process.init(` gated but lets the git-specific argv prep slip outside the gate. The test uses a shared `scanForMarkerInGateBranches(source:marker:)` helper that is also used by the VaultSyncService regression so the explicit-`#else`-aware per-line parser is not duplicated.

#### A2.KF -- KnowledgeFusion training/export/inference cluster (Phase S.2 design call)

**Design call (locked in 2026-04-24):** KnowledgeFusion training, adapter export/import, and MoLoRA inference are NOT MAS user-facing today. Two layers of UI/bootstrap gating already keep the cluster unreachable in MAS:

1. `Views/Settings/SettingsView.swift` lines 106-108 wrap `sections.append(.knowledgeFusion)` in `#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)`, and lines 293-295 wrap `case .knowledgeFusion: KnowledgeFusionDetailView()` in the same gate. MAS users never see the section or the detail view.
2. `App/AppBootstrap.swift` wraps every `KnowledgeFusionViewModel.shared` call in `#if !EPISTEMOS_APP_STORE` (lines 1494, 1502, 2082).

The five Category C subprocess-source files inside `KnowledgeFusion/` are therefore unreachable in MAS at runtime. The surgical defense-in-depth gates below remove the subprocess-launch markers (`Process.init(`, `process.executableURL`, `process.arguments`, the `/usr/bin/ditto` / `/bin/bash` / `curl` / `/opt/homebrew/bin/brew` / `/usr/bin/env` literals) from the MAS-visible source so that automated review tooling that scans for them does not flag the binary. **Pro/direct behavior is preserved exactly** -- Python training, KTO alignment, venv setup, adapter zip/unzip, and MoLoRA inference all run unchanged when the file is compiled without `EPISTEMOS_APP_STORE`.

The four files that REFERENCE these five (`KnowledgeFusionViewModel`, `TrainOnVaultView`, `TrainingHistoryView`, `TrainingScheduler`) are deliberately NOT whole-file gated: per the design call they remain compileable in MAS so the source set stays consistent. They are unreachable in MAS at runtime anyway because their entry points are gated.

- `Epistemos/KnowledgeFusion/Adapters/AdapterExporter.swift:163, 176` -- `Process.init()` calling `/usr/bin/ditto` for adapter zip / unzip. Both `createZip(from:to:)` and `extractZip(from:to:)` bodies wrapped `#if !EPISTEMOS_APP_STORE` / `#else (throw existing error)` / `#endif`. Regression test `adapterExporterMASBranchHasNoDittoLaunchMarkers` checks five markers: `Process.init(`, `process.executableURL`, `process.arguments`, `try process.run()`, and `/usr/bin/ditto`.

- `Epistemos/KnowledgeFusion/Alignment/KTOTrainer.swift:86` -- `Process.init()` calling `pythonPath` to run `train_kto.py`. `runKTOUpdate(...)` body wrapped `#if !EPISTEMOS_APP_STORE` / `#else (throw QLoRATrainerError.trainingFailed("KTO training is not available in the App Store sandbox build."))` / `#endif`. Regression test `ktoTrainerMASBranchHasNoPythonLaunchMarkers` checks the four Process API markers: `Process.init(`, `process.executableURL`, `process.arguments`, `try process.run()`.

- `Epistemos/KnowledgeFusion/Training/QLoRATrainer.swift:173` -- `Process.init()` calling `pythonPath` to run `train_knowledge.py` / `train_style.py`. `runTraining(...)` body wrapped `#if !EPISTEMOS_APP_STORE` / `#else (throw QLoRATrainerError.trainingFailed("QLoRA training is not available in the App Store sandbox build."))` / `#endif`. Regression test `qLoRATrainerMASBranchHasNoPythonLaunchMarkers` checks the same four Process API markers as KTOTrainer.

- `Epistemos/KnowledgeFusion/MoLoRA/MoLoRAInferenceService.swift:115` -- `Process.init()` calling `pythonPath` to run `molora_inference.py`. The launch block inside `start(modelPath:adapterConfigs:centroidsPath:)` wrapped `#if !EPISTEMOS_APP_STORE` / `#else (state = .error("MoLoRA inference is not available in the App Store sandbox build."))` / `#endif`. The state-machine `.error` outcome is honest -- callers that observe the state handle the error path naturally. Regression test `moLoRAInferenceServiceMASBranchHasNoPythonLaunchMarkers` uses the `proc` variable name (not `process`) and checks four markers: `Process.init(`, `proc.executableURL`, `proc.arguments`, `try proc.run()`.

- `Epistemos/KnowledgeFusion/PythonEnvironmentManager.swift:393` -- `Process.init()` plus the entire installer pipeline (`/bin/bash` + `curl` Homebrew installer, `/opt/homebrew/bin/brew install python@3.12`, venv create, pip install loops, `/usr/bin/env which python3` candidate sweep). FIVE separate gates land in this file:
  1. `executeProcess(...)` body -- where `Process.init`, `process.executableURL`, `process.arguments`, and `try process.run()` live.
  2. `ensureHomebrew()` -- ENTIRE method body, including the FileManager probes for `/opt/homebrew/bin/brew` and `/usr/local/bin/brew` AS WELL AS the `/bin/bash` + `curl` Homebrew installer call. The brew literal is removed from MAS-visible source even though the probes are sandbox-blocked anyway.
  3. `ensureModernPython()` -- install branch + recheck loop + last-resort `/opt/homebrew/opt/python@3.12/bin/python3.12` lookup, all inside a single `#if !EPISTEMOS_APP_STORE` block. The Pro branch ends with `throw PythonEnvError.noPythonFound` and the MAS `#else` throws the same; nothing remains after `#endif` so MAS has no compiled code after the throw.
  4. `findSystemPython()` -- the `/usr/bin/env which python3` candidate-sweep block.
  5. `ensureReady()` -- Steps 3-8 (venv create, pip upgrade, required + optional package install loops, deploy training scripts, verify mlx import, write marker) ALL inside the `#if !EPISTEMOS_APP_STORE` block, so MAS has no compiled code after the defense-in-depth `state = .failed; return`. (Earlier review caught two unreachable-code warnings at lines 225 and 322 from a smaller initial gate; both are gone now.)
  Each gate has an `#else` branch that either throws `PythonEnvError.processExitCode(-1, detail: "Python environment management is not available in the App Store sandbox build.")` / `PythonEnvError.noPythonFound`, or sets `state = .failed`, depending on context. Regression test `pythonEnvironmentManagerMASBranchHasNoInstallerMarkers` checks eight markers: the four Process API markers (`Process.init(`, `process.executableURL`, `process.arguments`, `try process.run()`) plus the four installer-pipeline literals (`/bin/bash`, `curl`, `/opt/homebrew/bin/brew`, `/usr/bin/env`).

### Category B -- dlopen / dlsym (POSIX header workaround)

_Empty as of 2026-04-25. The `ChunkedMCPFraming.swift` `dlopen(nil, RTLD_LAZY)` + `dlsym` workaround was the only entry; it has been replaced with a fixed-signature C shim and moved to Category D below._

### Category C -- in MAS binary today, no compile gate, blocked by sandbox at runtime

Every entry below is compiled into the MAS binary (verified: file-top has no `#if !EPISTEMOS_APP_STORE` guard AND the file is not in the `project.yml` `Epistemos-AppStore` exclude list). The sandbox will block the spawn at runtime if the code is ever reached in MAS. A paranoid App Review static scan may flag the symbols regardless of reachability. **Most of these are Pro-only workflows by intent**; the right Phase S fix is to exclude them from the MAS source set, wrap the call sites in `#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)`, or introduce a type that disables the code path at compile time under MAS. Do NOT delete the calls -- the Pro/direct release needs them.

_Category C is now empty for the original Phase S.2 cohort: the five KnowledgeFusion subprocess-source files have moved to Category A2 (surgical gates) above. Their previous rows lived in this table; they remain in the file source as Pro-only `#if !EPISTEMOS_APP_STORE` branches but no longer reach the MAS binary._

### Category D -- FIXED across this and the prior Phase S.2 session

- `Epistemos/Views/Settings/IMessageDriverSettingsView.swift:570-574` -- the old iMessage Doctor "Relaunch Epistemos" action used a zero-argument `Process()` + `launchPath = "/usr/bin/open"` + `try? task.run()` + `NSApp.terminate(nil)`. Replaced with `NSWorkspace.shared.openApplication(at:configuration:completionHandler:)`.
- `Epistemos/Harness/{CompletionChecker,EvalSandbox,HarnessLab,HarnessIntegration,HarnessRegistry}.swift` -- five files wrapped at file-top with `#if !EPISTEMOS_APP_STORE` / `#endif`. The three Process.init subprocess-launch sites move from Category C to Category A; the two dependent files (HarnessIntegration, HarnessRegistry) are gated alongside them because they reference gated types (`CompletionResult`, `CompletionCheckerRegistry`, `EvalSuiteResult`). MAS build validation: `xcodebuild -scheme Epistemos-AppStore -configuration Debug build` -> `** BUILD SUCCEEDED **` with 0 compile errors (raw-log verification; the "(2 failures)" at the tail is pre-existing SwiftLint noise on the CodeEditSourceEditor + CodeEditTextView SPM deps, not a build failure).
- `Epistemos/Omega/Safety/ShadowGitCheckpoint.swift` -- file-top gated in a follow-on batch. Two `Process.init()` sites (lines 82 and 119, both calling `/usr/bin/git`) move from Category C to Category A. MAS build re-verified: `** BUILD SUCCEEDED **` with `xcodebuild_ok` exit, 0 compile errors.
- `Epistemos/KnowledgeFusion/SyntheticData/EmbodiedCaptureService.swift` -- file-top gated in a follow-on batch after a corrected per-file dependency audit (the earlier cluster-audit that lumped 7 KnowledgeFusion files together was rejected because several of them have live UI/scheduler/user-capture references). EmbodiedCaptureService is the only one of the seven that is safe in isolation: zero type-level external refs, only source-text test reads. MAS build re-verified: `xcodebuild_ok` + `** BUILD SUCCEEDED **` + 0 compile errors.
- `Epistemos/KnowledgeFusion/DataIngestion/AudioTranscriber.swift` -- **surgical** gate (the file is NOT whole-file gated because its public types are live MAS API used by composer/quick-capture). Subprocess fallbacks (`mlx-whisper` Python, `/usr/local/bin/whisper`, `/usr/bin/which whisper`) and the `runProcess` helper they share are wrapped in `#if !EPISTEMOS_APP_STORE`. MAS keeps Apple Speech transcription only and reports an honest "Apple Speech only" no-backend error. Pro keeps the full three-backend ladder. Verification: MAS build `BUILD SUCCEEDED` + `xcodebuild_ok`; Pro test slice 8/8 green including a new `audioTranscriberMASBranchHasNoProcessInit` regression test that strips `#if !EPISTEMOS_APP_STORE` blocks and asserts the MAS-visible source contains no `Process.init(`.
- `Epistemos/Sync/VaultSyncService.swift` -- **surgical** gate (the file is NOT whole-file gated because `VaultSyncService` is core vault infrastructure). The optional APFS safety-snapshot layer that shells out to `/usr/bin/tmutil` is the only MAS-incompatible portion. MAS gets a silent early-return inside `createAPFSSafetySnapshotIfPossible` / `pruneAPFSSafetySnapshotsIfNeeded` (so no soft-log noise is generated when the optional layer skips), plus a defense-in-depth gate on the `runTMUtilCommand` body. Core file-copy recovery snapshots, SQLite backups, and watcher-driven sync stay active in MAS. Pro keeps the full tmutil layer. Tests that wire a custom `TMUtilCommandRunner` continue to bypass the gate and run unchanged.
- `Epistemos/Vault/VaultChatMutator.swift` -- **surgical** gate. `VaultChatMutator` is live user-facing API for the approve/reject staged-mutation sheet (`EpistemosApp.swift`) and AI staged file edits (`LiveNoteExecutor.swift`); whole-file gating would break the entire approval flow in MAS. The verified durable file write inside `VaultMutationIO.commit(diff:)` stays unconditional, so user-approved mutations always land on disk identically in MAS and Pro. Only the optional git audit-trail layer (`ensureGitRepository` + three `runGitOffMain` calls) is gated; under MAS the function returns a `"mas-skipped-<UUID>"` placeholder reference instead of a git SHA. The MAS placeholder is honest -- callers store it in `lastCommitReference` and either discard it (`EpistemosApp.swift`) or use it for diagnostics (`VaultChatMutatorTests.swift` runs against Pro). Defense-in-depth: `runGitOffMain` body throws `VaultChatMutatorError.gitCommandFailed` under MAS so a future caller bypassing the `commit(diff:)` skip cannot accidentally spawn `/usr/bin/env git`.
- `Epistemos/Bridge/ChunkedMCPFraming.swift` + `Epistemos/Bridge/ShmPosixShim.{h,c}` (NEW files) -- replaces the previous `dlopen(nil, RTLD_LAZY)` + `dlsym("shm_open" / "shm_unlink")` workaround with a fixed-signature C shim. Rationale: the Darwin headers declare `shm_open` as variadic (`int shm_open(const char *, int, ...)`), which Swift cannot import directly. The earlier file used `dlopen` + `dlsym` to reach the symbol at runtime; that was sandbox-safe (`dlopen(nil, ...)` returns the self-handle and does not load an external dylib) but the literal `dlopen` / `dlsym` / `RTLD_LAZY` strings in MAS-visible source could attract paranoid App Store review tooling. The new C shim (`epistemos_shm_open`, `epistemos_shm_unlink`) wraps the POSIX functions with their canonical fixed ABI and is exposed to Swift via the existing `Epistemos-Bridging-Header.h`. ChunkedMCPFraming's two private Swift thunks now forward to the C shim instead of doing runtime symbol lookup. Pro and MAS builds get identical runtime behavior; the dlopen/dlsym/RTLD_LAZY markers are gone from non-comment source. Regression test `chunkedMCPFramingHasNoDlopenWorkaround` asserts (a) the file still references `epistemos_shm_open` (so the shim path is wired), and (b) `dlopen(`, `dlsym(`, `RTLD_LAZY` do not appear in non-comment code anywhere in the file. MAS build verified: `xcodebuild -scheme Epistemos-AppStore -configuration Debug build` -> `** BUILD SUCCEEDED **` with 0 new compile warnings or errors; the C shim builds cleanly into the MAS target alongside the rest of the bridge code.

- `Epistemos/KnowledgeFusion/{Adapters/AdapterExporter,Alignment/KTOTrainer,Training/QLoRATrainer,MoLoRA/MoLoRAInferenceService,PythonEnvironmentManager}.swift` -- the five remaining Phase S.2 subprocess-source files in `KnowledgeFusion/`. **Surgical** gates only -- `KnowledgeFusionViewModel`, `TrainOnVaultView`, `TrainingHistoryView`, and `TrainingScheduler` stay UNGATED per the design call so the MAS source set keeps the type surface compileable. Each of the five files wraps the subprocess-launch portion of one or more methods with `#if !EPISTEMOS_APP_STORE` / `#else (throw or set state to error)` / `#endif`. PythonEnvironmentManager has FIVE separate gated regions: (1) `executeProcess(...)` body where the Process API lives; (2) `ensureHomebrew()` ENTIRE body including the `/opt/homebrew/bin/brew` + `/usr/local/bin/brew` FileManager probes and the `/bin/bash` + `curl` installer call; (3) `ensureModernPython()` install + recheck + last-resort lookup all inside one `#if !EPISTEMOS_APP_STORE` block (no compiled code after the throw in either branch); (4) `findSystemPython()` `/usr/bin/env which python3` candidate sweep; (5) `ensureReady()` Steps 3-8 -- venv create, pip upgrade, required + optional package install loops, deploy training scripts, verify mlx import, write marker -- all inside the gate so MAS has no compiled code after the defense-in-depth `state = .failed; return`. Pro/direct release retains identical Python training, KTO alignment, MoLoRA inference, adapter zip/unzip, and venv bootstrap. Five regression tests added in `EpistemosTests/AppStoreHardeningTests.swift`, table-driven via a `KFMASGateSpec` struct + `runKFMASGateRegression(_:)` runner so adding another file or marker is a one-line edit. All five tests funnel through the shared `assertMarkerIsMASGated(source:fileLabel:marker:)` wrapper, which calls the existing `scanForMarkerInGateBranches(source:marker:)` helper. Strengthened per-file marker sets: AdapterExporter checks `Process.init(`, `process.executableURL`, `process.arguments`, `try process.run()`, `/usr/bin/ditto`; KTOTrainer / QLoRATrainer each check the four `process.*` Process API markers; MoLoRAInferenceService uses the `proc` variable name and checks `Process.init(`, `proc.executableURL`, `proc.arguments`, `try proc.run()`; PythonEnvironmentManager checks the four `process.*` Process API markers plus `/bin/bash`, `curl`, `/opt/homebrew/bin/brew`, `/usr/bin/env` (eight markers total).

Category C sites NOT landed in this batch are still present in the MAS binary -- see the remaining Category C table above.

### Phase S.2 follow-up work (landed in this batch + still outstanding)

**Landed across Phase S.2 so far:**

- Harness subprocess-launch gating (5 files listed in Category D).
- ShadowGitCheckpoint gating (Category D).
- EmbodiedCaptureService gating (Category D, after a rejected bulk-gate attempt).
- AudioTranscriber surgical gating (Category D, MAS-vs-Pro split with a new regression test).
- VaultSyncService tmutil surgical gating (Category D, silent-no-op early return + defense-in-depth body gate + per-line regression test that handles `#else`).
- VaultChatMutator git surgical gating (Category D, file-write stays unconditional + git audit-trail gated + placeholder MAS reference + defense-in-depth body gate + per-line regression test).
- KnowledgeFusion 5-file surgical cluster: AdapterExporter ditto / KTOTrainer python / QLoRATrainer python / MoLoRAInferenceService python / PythonEnvironmentManager (five regions: executeProcess + ensureHomebrew + ensureModernPython + findSystemPython + ensureReady venv-pip loop). UI-layer + AppBootstrap entry points already gated; the five surgical body gates remove launch markers from the MAS binary as defense-in-depth. Five new regression tests check per-file marker sets.
- ChunkedMCPFraming dlopen/dlsym workaround replaced by a fixed-signature C shim (`Epistemos/Bridge/ShmPosixShim.{h,c}`) wired through the existing `Epistemos-Bridging-Header.h`. dlopen / dlsym / RTLD_LAZY markers gone from non-comment Swift source. Category B is now empty.
- iMessage Doctor relaunch replacement (Category D).

**Corrected dependency model (required for the rest of the KnowledgeFusion cluster):**

An earlier cluster-audit that grouped all 7 KnowledgeFusion subprocess-launch files together and proposed bulk-gating was rejected: the audit only checked for exact-name refs to the top-level exported types and missed live UI/scheduler/user-capture callers such as `Engine/ComposerVoiceInputService.swift` and `Views/Capture/QuickCaptureView.swift` for `AudioTranscriber`, and `KnowledgeFusionViewModel` / `TrainOnVaultView` / `TrainingHistoryView` / `TrainingScheduler` / `AutoresearchLoop` for the trainer surfaces. Future gating of the remaining files must start from the dependency closure of each concrete file, not from its directory.

**Still outstanding, tracked:**

_None as of 2026-04-25. The ChunkedMCPFraming dlopen/dlsym workaround was replaced with a C shim. Category B is empty. The five KnowledgeFusion subprocess-source files moved to A2.KF._

---

## 7. Known follow-ups (non-blocking, scoped by sub-phase)

- **S.1 UX polish:** requires launched-app dogfood time; out of scope for this audit pass.
- **S.2 (this doc):** run `codesign -d --entitlements -` on an actual built `Epistemos-AppStore.app` and attach output. Requires a clean release build, deferred because disk is tight (13 GB free at audit time; `agent_core/target` is 50 GB and another feature-set compile would add 1-3 GB).
- **S.4 tests:**
  - Run the Rust `mas-sandbox` tests under `cargo test --manifest-path agent_core/Cargo.toml --features mas-sandbox -- mas_` (deferred for the same disk reason).
  - Add bounded-agent termination tests for the Swift side (`max_turns` ceiling invariants).
  - Security-scoped bookmark round-trip tests after a sandbox-container write cycle.
- **S.5 perf:** Phase 0 measurement slot already exists with signpost instrumentation landed in `e19037c0`; the Instruments trace capture is the next step.
- **S.6 privacy:** `PrivacyInfo.xcprivacy` is already minimal; the only residual is a Settings -> Privacy transparency pane for the end user.
- **S.7 ASC setup:** pure ops work, not code.
- **S.8 TestFlight:** not started, open-ended per master plan.
- **S.9 submission:** not started.

---

## 8. What this audit explicitly did NOT prove

This audit is source-level inspection plus one Swift Testing regression. It does NOT constitute App Store submission readiness. Explicit non-claims:

- **No actual MAS build was produced.** No `xcodebuild archive` of the `Epistemos-AppStore` scheme was run in this pass. The claims in sections 1 and 2 are from `project.yml` and the plist source files, not from a signed `.app`.
- **No `codesign -d --entitlements -` runtime check was run.** There is no output capturing the real embedded entitlements of a shipped binary. A future Phase S.2 follow-up must archive an MAS build and grep the codesign output against this audit.
- **No `cargo test --features mas-sandbox` was run in this pass.** The Rust MAS-gated tests are known to exist (names listed in section 4); their last recorded green state predates this pass. Disk (13 GB free, 50 GB in `agent_core/target`) was the reason for deferral.
- **No TestFlight, no App Store Connect submission.** Sub-phases S.7, S.8, and S.9 are untouched.
- **No security-scoped bookmark persistence tests across relaunch under a real sandbox container.** Planned for S.4.
- **No stricter Swift 6 concurrency audit under the sandbox.** Planned for S.4.
- **No UX-level dogfood evidence.** S.1 requires human-time using a released build; not started.
- **This is not a release-readiness statement.** It is a baseline audit so subsequent Phase S work has a documented starting point.

When these gaps close, update this doc rather than creating a new one, so the audit history stays single-source.
