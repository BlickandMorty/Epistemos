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
| 3 | `codesign -d --entitlements` on MAS build shows App Sandbox = YES, no `allow-unsigned-executable-memory` | Source plist confirmed minimal (section 2 above). **Runtime `codesign -d --entitlements -` against the built MAS bundle (Debug, adhoc-signed) verified 2026-04-25**: 5 expected keys present (`com.apple.security.app-sandbox = true`, `com.apple.security.cs.allow-jit = true`, `com.apple.security.files.bookmarks.app-scope = true`, `com.apple.security.files.user-selected.read-write = true`, `com.apple.security.network.client = true`); zero Pro-only blockers (no `allow-unsigned-executable-memory`, `disable-library-validation`, `automation.apple-events`, `files.bookmarks.document-scope`, `temporary-exception.mach-lookup.global-name`). Embedded entitlements match the source plist exactly. **Non-claim**: this proof is on a Debug `xcodebuild build` output (`Format=app bundle with Mach-O thin (arm64)`, `Signature=adhoc`, `TeamIdentifier=not set`); a Distribution-signed Archive build for App Store submission has NOT been produced and is not part of this evidence. See §7 + §10 for the exact command and remaining gaps. |
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
- **S.3 accessibility + localization:** active implementation -- see Section 9 (especially 9.5 prioritized slice list) for the 2026-04-25 inventory and execution plan. Each slice ships small, ProseEditor excluded by hard constraint until last. Not "defer by default".
- **S.2 (this doc):** ✅ Runtime `codesign -d --entitlements -` proof landed 2026-04-25. Captured on the Debug MAS bundle most recently produced by `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' build` (the same MAS gate the slice 4 corrective commit ran), located at `~/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Build/Products/Debug/Epistemos.app` with `CFBundleIdentifier = com.epistemos.appstore`. Embedded entitlements (5 keys: `com.apple.security.app-sandbox = true`, `com.apple.security.cs.allow-jit = true`, `com.apple.security.files.bookmarks.app-scope = true`, `com.apple.security.files.user-selected.read-write = true`, `com.apple.security.network.client = true`) match the source plist documented in §2 exactly. Zero Pro-only blockers in the embedded set. **Non-claim**: this is a Debug bundle (`Format=app bundle with Mach-O thin (arm64)`, `Signature=adhoc`, `TeamIdentifier=not set`); a Distribution-signed (Mac App Store Distribution / `3rd Party Mac Developer Application`) Archive build for App Store submission has NOT been produced. The codesign output captured here proves the entitlements pipeline is wired correctly from `project.yml` -> `Epistemos-AppStore.entitlements` -> linked binary; it does NOT replace the App Store Distribution signing + `xcodebuild archive` + App Store Connect upload + review step that exit criterion #5 will require.
- **S.4 tests:** ✅ Three deliverables landed (commit subject: `test(S.4): add App Store boundedness and bookmark coverage`).
  - Rust `mas-sandbox` test run via `cargo test --manifest-path agent_core/Cargo.toml --features mas-sandbox -- mas_` -> **9 passed / 0 failed** in <0.01 s after a 23 s feature-set recompile. Disk pressure that originally deferred this run (13 GB free at audit time) has cleared (155 GiB free now); `agent_core/target` stayed at ~50 GB and the `mas-sandbox` feature compile stayed under that ceiling. The 6 named MAS-runtime tests from §4 plus `mas_runtime_allows_explicit_bounded_internal_mutation` and `mas_runtime_requires_grant_for_file_write` all pass; 3 incidental provider-schema tests matched the substring filter.
  - Bounded-agent `max_turns` ceiling on the Swift side covered in **two layers**: `EpistemosTests/LocalAgentLoopTests.swift::localLoopStopsWhenToolCallsNeverConverge` tightened from `LocalAgentLoopError.self` to a strict `error == .maxTurnsExceeded(2)` assertion (matching the existing `localLoopStopsAfterRepeatedInvisibleRepairTurns` shape); and a new `EpistemosTests/AppStoreHardeningTests.swift::agentQueryEngineHaltsAtMaxTurnsCeiling` that exercises the parallel ceiling on the Swift `AgentQueryEngine` harness with `maxTurns: 1`, asserts turn 1 yields `.success` and turn 2 yields `.errorMaxTurns(turns: 2)`, and uses an actor-counted recording backend with a per-call unique identifier to assert the engine does NOT call the backend again after the ceiling fires.
  - Security-scoped bookmark + write-cycle in-process round-trip covered by the new `EpistemosTests/VaultSyncServiceAuditTests.swift::securityScopedBookmarkRoundTripsAcrossWriteCycle`. Real `persistVaultSelection(_:)` (no `setBookmarkDataWriterForTesting` mock), then production `service.startupBookmarkValidation()` is asserted in-process: `bookmarkExists == true`, `isReadyForAutomaticRestore == true`, `failureReason == nil` -- the same shape the launched app sees on next start. After that, bookmark read-back via the production `URL(resolvingBookmarkData:options:relativeTo:bookmarkDataIsStale:)` path with security-scope-then-plain fallback, real `saveAllDirtyPages()` cycle that uses the existing `setExportPageOverrideForTesting` seam to write a sentinel file under the resolved vault URL with a hash-aligned page body so `runDirtySaveLoop`'s post-export hash check matches cleanly, then a second bookmark re-resolve confirms `isStale == false` and the URL still matches. **Non-claim**: this is an in-process re-resolve + write-cycle proof for the test bundle's host process, NOT cross-relaunch persistence under a real MAS sandbox container — that gate is TestFlight (Phase S.8). `startAccessingSecurityScopedResource()` is exercised conditionally (balanced start/stop only when start returned true). Stale-after-rename intentionally NOT asserted (platform/file-system dependent; existing stale/corrupt recovery tests cover the messaging path).
- **S.5 perf:** see Section 8 below for the 2026-04-25 audit + GraphPerformanceTests baseline + signpost coverage map + the two added signposts on Phase S verified-write paths. Status update from the 2026-04-25 S.5 evidence pass: the `perf_diagnostics` reliability gate has been refreshed (artifact `artifacts/reliability/20260425-053639/`, see §8.6); the four standalone perf suites have a refreshed cross-suite baseline (see §8.2b). The 2026-04-25 follow-up attempt to refresh the remaining five quality gates (`baseline`, `asan`, `tsan`, `ubsan`, `soak_repeat`) hit an xcodebuild test-runner connection hang on the first gate and did not produce evidence on any of them; see §8.7 for the exact failure shape. A clean-state baseline-only retry the same morning hung again with the same shape (see §8.8), so the `Generated Reliability Matrix` test-runner-launch failure is now treated as reproducible on this machine rather than a one-off flake. Remaining S.5 follow-ups: diagnose the test-runner-launch failure (xctestrun / test-host scheme inspection) before retrying the sanitizer + soak gates; Instruments trace capture under typing+streaming load (still deferred -- needs a launched-app run).
- **S.6 privacy:** `PrivacyInfo.xcprivacy` is already minimal. The residual Settings -> Privacy transparency pane landed 2026-04-25 as a new sidebar entry under the existing `Privacy & Storage` category (`SettingsSection.privacy`, dispatched to `Epistemos/Views/Settings/PrivacyDetailView.swift`). The pane summarizes the manifest fields (the four `NSPrivacyAccessedAPI*` categories with their reason codes, the `NSPrivacyTracking = false`, the empty `NSPrivacyTrackingDomains`, the empty `NSPrivacyCollectedDataTypes`), enumerates what stays on this Mac vs what leaves it to cloud-model API endpoints when the user picks one (Anthropic/OpenAI/Gemini/Perplexity), states there is no Epistemos-operated telemetry server, and gates the deployment-profile copy on `EPISTEMOS_APP_STORE || MAS_SANDBOX` so MAS users see the App Sandbox / security-scoped-bookmark posture and Pro users see the Apple-events / file-access-at-discretion posture. Three new `EpistemosTests/AppStoreHardeningTests` regression tests guard the manifest against drift (`privacyManifestDeclaresNoTracking`, `privacyManifestCollectsNoData`, `privacyManifestDeclaresFourAccessedAPITypesWithReasons`). **Non-claim**: this pane summarizes the manifest-backed posture and the audit doc; it does NOT verify that the privacy policy URL is live, does NOT verify the App Store Connect "App Privacy" questionnaire is filled in, and does NOT replace either of those. Both remain Phase S.7 ASC-setup tasks.
- **S.7 ASC setup:** pure ops work, not code.
- **S.8 TestFlight:** not started, open-ended per master plan.
- **S.9 submission:** not started.

---

## 8. S.5 performance trace evidence (2026-04-25)

**Approach:** log-first / evidence-first. Inspected existing perf infrastructure before any code change.

### 8.1 Existing infrastructure mapped

- `Epistemos/Engine/Log.swift` defines six `OSSignposter` categories: `appPerf`, `notesPerf`, `vaultPerf`, `graphPerf`, `ffiPerf`, `agentStreaming`. Roughly 100 begin/end/event sites across `Epistemos/`.
- Phase 0 commit `e19037c0` added three intervals on master-plan critical paths: `graph.frame.ms` (MetalGraphView per-frame), `graph.embed.push.ms` (EmbeddingService MainActor FFI push), `chat.exchange.save.ms` (ChatCoordinator persistChatExchange context.save).
- `scripts/run_reliability_quality_gates.sh` runs `EpistemosTests/GeneratedReliabilityMatrixTests` with `-enablePerformanceTestsDiagnostics YES`, `-enableAddressSanitizer YES`, `-enableThreadSanitizer YES`, `-enableUndefinedBehaviorSanitizer YES`, plus a soak-repeat gate. The prior `perf_diagnostics` run before this S.5 refresh is `artifacts/reliability/20260303-021913/perf_diagnostics.log` -- 6 reliability-matrix tests passed in 31.418 s, all 200-iteration parametric cases (e.g., "benchmark parser throughput envelope", "graph load and traversal budget", "memory growth bounded for repeated query cycles", "soft failure recovery keeps core paths healthy", "malformed inputs are crash resistant", "concurrent parser and diff stress"). The 2026-04-25 refresh of this gate is recorded in §8.6.
- Standalone perf-test files: `EpistemosTests/GraphPerformanceTests.swift` (22 tests), `EpistemosTests/SearchPerformanceTests.swift`, `EpistemosTests/PerformanceTest.swift`, `EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests.swift`.
- `Epistemos/State/MainThreadWatchdog.swift` runs a background GCD watchdog with a 500 ms hang threshold and an `onHangDetected` emission callback.

### 8.2 Fresh baseline (2026-04-25, scope-limited)

Ran `EpistemosTests/GraphPerformanceTests` against the Pro target after the Phase S.2 surgical-gate work landed. Raw log + trailing-echo exit capture verified:
- 22/22 passed in **2.565 s** total. xcodebuild exit `xcodebuild_ok`, `** TEST SUCCEEDED **` in raw log.
- Largest individual test: "Memory usage during node loading" at 0.757 s.
- Largest scale-test: "Fuzzy search with 5000 nodes" at 0.351 s; "Load 5000 nodes performance" at 0.254 s.
- All 100/500/1000/5000-node graph load tests, all BFS/connected/shortestPath tests, all GraphBuilder persist tests pass within fractions of a second.

**Scope of this baseline:** GraphPerformanceTests covers the **graph store / builder / search** layer -- node and edge loading at scale, GraphBuilder persist, BFS/shortestPath traversal, fuzzy-search scoring. It does **NOT** prove `MetalGraphView` render-loop or hover-loop FPS at 60 Hz under realistic vault load -- those need an Instruments trace under a launched-app session, which is not run here. The Phase 0 `graph.frame.ms` signpost is wired (see 8.3) but its p99 has not been measured against the <12 ms budget. Treat the baseline as "graph data layer is healthy", not "graph rendering is healthy".

### 8.2b Refreshed standalone-suite perf baseline (2026-04-25, S.5 evidence pass)

After S.4 acceptance, re-ran the four standalone perf test suites against the Pro target via:

```
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos \
    -destination 'platform=macOS' test \
    -only-testing:EpistemosTests/GraphPerformanceTests \
    -only-testing:EpistemosTests/SearchPerformanceTests \
    -only-testing:EpistemosTests/PerformanceTest \
    -only-testing:EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests
```

Result: **59 passed / 0 failed**, `** TEST SUCCEEDED **`, total wall clock **4.156 s**. Per-suite breakdown reported by the raw log (four named suites):
- Graph Performance: 2.678 s.
- Search Performance: 1.313 s.
- Performance and Speed: 0.161 s.
- Runtime Capability And Performance Policies: 0.002 s.

Top 5 slowest individual tests in the refreshed run:

| Test | Time |
|---|---|
| "Memory usage during node loading" | 0.818 s |
| "Prefix search performance" | 0.370 s |
| "Fuzzy search with 5000 nodes" | 0.350 s |
| "Load 5000 nodes performance" | 0.282 s |
| "GraphBuilder persist with large changes" | 0.252 s |

Same scope caveat as 8.2 applies: graph data-layer + search ranking + capability-policy resolution are healthy; this run does NOT prove `MetalGraphView` render/hover FPS at 60 Hz, prose editor typing latency, or any signpost p99 budget.

### 8.3 Signpost coverage map by hot surface

| Hot surface | Coverage state | Sites |
|---|---|---|
| Launch / startup | Solid | `Log.appPerf.beginInterval("bootstrapInit")`, `migrateBodiesToFileStorage` (AppBootstrap.swift) |
| Code editor typing (`Views/Notes/CodeEditorView.swift`) | Solid | `os_signpost("textDidChange")` begin/end + `selectionChanged` event on `perfLog`. This is the syntax-highlighted code editor only. |
| Prose note editor typing (`ProseEditorView.swift` / `ProseEditorRepresentable2.swift` / `ProseTextView2.swift`) | **Gap** | No `os_signpost` / `OSSignposter` / `Log.notesPerf` calls in any of the three Prose editor files. The Prose editor is the primary user-facing note editor; its typing/insertion/save hot path has no Phase 0 instrumentation. Tracked as an S.5 follow-up. |
| Note save / verified write | **Was a gap** | Phase S touched `NoteFileStorage.atomicWriteUTF8` and `VaultVerifiedFileWriter.writeUTF8` (added the readback verification step) but neither had a `Log.notesPerf` interval. Fixed in this pass -- see 8.4. |
| AI streaming / chat | Solid | 18 `Log.agentStreaming` sites: `accAgentSession` interval + per-event begin/end + `chat.exchange.save.ms` Phase 0 interval (ChatCoordinator.swift, StreamingDelegate.swift) |
| Graph render / hover | Solid | `graph.frame.ms` per-frame, `graph.embed.push.ms`, `loadGraphAsync`, `buildStructuralGraph`, `refreshStructuralDataAsync`, `revealPage`, `graph_engine_pin_node` FFI (Phase 0 + GraphState + HologramController) |
| Vault sync / file watcher | Solid | `restoreVaultFromBookmark`, `startWatching`, `switchToVaultAsync`, `initialVaultImport`, `initialVaultDiffSync` (VaultSyncService.swift) |
| FFI boundary (Rust ↔ Swift) | Solid | `executeComputerAction`, `waitForPermission`, `perceiveApp`, `interactWithApp` (StreamingDelegate.swift) + `graph_engine_pin_node` |

### 8.4 Phase S verified-write signposts added (2026-04-25)

The note-save hot path picked up readback-verification overhead during Phase R / Phase S. Two narrow `Log.notesPerf` intervals added so future regressions are visible:

- `NoteFileStorage.atomicWriteUTF8(_:to:itemLabel:)` -- `notes.save.atomicWriteUTF8.ms`. Wraps the full five-step flow: UTF-8 encode, temp write, F_FULLFSYNC of temp, atomic rename, F_FULLFSYNC of parent dir, readback verification.
- `VaultVerifiedFileWriter.writeUTF8(_:to:readBack:)` -- `notes.save.vaultVerifiedWrite.ms`. Wraps the verified-write contract used by `VaultMutationIO.commit(diff:)` for every approved staged vault mutation -- atomic UTF-8 write + readback verification.

Both signposts are zero-behavior changes (`OSSignposter.beginInterval` / `endInterval` are NOPs when no signpost listener is attached). No test regression expected; the AppStoreHardeningTests Pro slice plus the Epistemos-AppStore MAS build were re-run and verified after the additions.

### 8.5 What S.5 explicitly does NOT prove yet

- **No fresh Instruments trace under realistic load.** Capturing an Instruments `.trace` requires a launched-app session against a representative vault; that is a launched-app dogfood task tracked alongside S.1. Without a trace, the Phase 0 signposts are wired but unmeasured.
- **No live MetalGraphView render/hover FPS proof.** GraphPerformanceTests covers the graph store/builder/search layer only; the `graph.frame.ms` per-frame signpost has not been exercised against the master-plan <12 ms p99 budget at 60 Hz under realistic vault load.
- **No prose note editor typing perf proof.** The prose editor (the primary user-facing note typing surface) has no Phase 0 instrumentation today (see 8.3 row). Adding signposts to `ProseEditorView` / `ProseTextView2` is tracked as an S.5 follow-up.
- ~~**No fresh `run_reliability_quality_gates.sh perf_diagnostics` run.**~~ **Resolved as of S.5 evidence pass (2026-04-25).** A single-gate refresh landed at `artifacts/reliability/20260425-053639/perf_diagnostics.xcresult`; see §8.6 below. The remaining 5 gates (`baseline`, `asan`, `tsan`, `ubsan`, `soak_repeat`) were attempted in a follow-up 5-gate run (artifact `artifacts/reliability/20260425-063404/`); the `baseline` gate hit an xcodebuild test-runner connection hang and the script's `set -euo pipefail` halted before `asan`/`tsan`/`ubsan`/`soak_repeat` could run. None of the five produced TEST SUCCEEDED evidence in this pass. Classified as an infrastructure/tooling failure rather than a code regression (no test in the suite was actually executed). See §8.7 for the exact log line and disk footprint. A clean-state baseline-only retry was attempted shortly after and hung again with the same shape; see §8.8. The failure is now treated as reproducible on this machine, not a one-off flake. Re-running the sanitizer + soak gates remains gated on diagnosing the test-runner-launch failure.
- **No p99 budget verification for any of the three Phase 0 intervals.** `graph.frame.ms <12 ms p99 @ 60 Hz`, `graph.embed.push.ms <2 ms p99`, `chat.exchange.save.ms <5 ms p99` -- targets named, signposts wired, numbers not yet measured.

S.5 is therefore in a **partial-evidence** state: signpost coverage is broader after this pass (with two new verified-write intervals on Phase S surgical paths), and the graph data-layer baseline is healthy, but the Instruments traces and prose-editor instrumentation needed to call S.5 fully ready remain follow-ups.

### 8.6 Reliability quality-gate refresh (2026-04-25, perf_diagnostics only)

`scripts/run_reliability_quality_gates.sh` was invoked with `GATES=perf_diagnostics` (single gate) so the disk impact stayed bounded. Command:

```
GATES=perf_diagnostics scripts/run_reliability_quality_gates.sh
```

Result: `** TEST SUCCEEDED **`, the `Generated Reliability Matrix` suite ran **6 tests / 1 suite** with 200 parametric cases per test (1200 sub-cases total), wall-clock **47.482 s**. Per-test breakdown from `artifacts/reliability/20260425-053639/perf_diagnostics.log`:

| Reliability-matrix test | Refreshed run (200 cases) |
|---|---|
| benchmark parser throughput envelope | 3.629 s |
| graph load and traversal budget | 4.622 s |
| memory growth bounded for repeated query cycles | 29.459 s |
| malformed inputs are crash resistant | 0.229 s |
| soft failure recovery keeps core paths healthy | 2.364 s |
| concurrent parser and diff stress | 7.172 s |

Comparison vs the prior archived run at `artifacts/reliability/20260303-021913/perf_diagnostics.log` (cited in 8.1): the older log reports **31.418 s** total wall clock for the same six tests; the 2026-04-25 refresh reports **47.482 s** -- ~51% slower in wall clock. Honest read of the delta:

- **Not enough evidence to call a regression; treat as a follow-up measurement question.** No per-test wall-clock budget is asserted by the harness today (the 6 tests assert correctness invariants over 200 randomized inputs each, not timing budgets), and the two runs were taken on different machine states under different workloads months apart, with no controlled environment. A real regression read would need a stable baseline harness with named per-test budgets and a controlled run environment (no concurrent indexing, fixed thermal headroom). None of those controls existed for either log.
- **Older log shape limits per-test diff.** Early-March Swift Testing logs report per-test "passed after X" using a cumulative-from-suite-start clock for several tests, which prevents per-test deltas. The 2026-04-25 log reports clean per-test timings (see the table above), but the asymmetry means we cannot pinpoint which test or tests account for the wall-clock increase.
- **Codebase has grown between the two runs.** Agent-harness, graph-engine, and Phase R/S work has accumulated; the parametric tests exercise integration paths that grew with those phases. Some of the wall-clock increase reflects more code under test, not regressed code -- but again, this is not a measured claim, just a plausible structural factor.

**Follow-up:** if a future S.5 pass wants to read wall-clock deltas as regression signals, it needs named per-test budgets in the reliability-matrix harness (or a separate Instruments trace) plus a controlled run environment before any "regression" call is justified.

Disk impact of this refresh (all under `artifacts/reliability/20260425-053639/`):
- `derived-data-perf_diagnostics/`: 8.4 GB.
- `perf_diagnostics.log`: 5.0 MB.
- `perf_diagnostics.xcresult`: 10 MB.

The artifact directory remains **local evidence only** and is NOT staged or committed in this S.5 evidence pass. The derived-data bundle, the log, and the xcresult are all left on local disk for reproducibility; this audit doc records the paths and results so they can be re-located against a future re-run. (`.git/info/exclude` provides local protection against an accidental `git add`; that is a local-only ignore, not a tracked repo change.)

### 8.7 Reliability five-gate follow-up attempt (2026-04-25, baseline gate hung)

After §8.6's single-gate refresh was accepted, a follow-up run targeted the remaining five reliability gates with:

```
GATES=baseline,asan,tsan,ubsan,soak_repeat scripts/run_reliability_quality_gates.sh
```

The `baseline` gate (the first in the list) failed with an xcodebuild test-runner connection hang. The exact tail of `artifacts/reliability/20260425-063404/baseline.log`:

```
2026-04-25 06:44:46.017 xcodebuild[19252:27974018] [MT] IDETestOperationsObserverDebug: 382.595 elapsed -- Testing started completed.
Testing failed:
	Epistemos (21860) encountered an error (The test runner hung before establishing connection.)
** TEST FAILED **
```

Classification: **infrastructure / tooling flake, not a code regression.** No test in the `Generated Reliability Matrix` suite was actually executed; the runner could not establish its connection within the 382-second window before xcodebuild gave up. The Pro AppStoreHardeningTests slice (94 tests) and the perf_diagnostics gate (1200 sub-cases) ran cleanly against the same source tree the same day, which makes a source-level regression less likely for this specific failure shape but does not prove the gate healthy.

Because `scripts/run_reliability_quality_gates.sh` runs under `set -euo pipefail`, the baseline failure halted the script before `asan`, `tsan`, `ubsan`, or `soak_repeat` ran. Per-gate evidence summary:

| Gate | Status | Notes |
|---|---|---|
| `baseline` | TEST FAILED (infra hang) | runner connection hang at 382.595 s; no tests executed |
| `asan` | NOT RUN | script halted on baseline failure |
| `tsan` | NOT RUN | same |
| `ubsan` | NOT RUN | same |
| `soak_repeat` | NOT RUN | same |

Disk footprint of the partial artifact directory: 8.5 GB (a single `derived-data-baseline/` dir plus the failing log and xcresult). 132 GiB free remained after the run, so disk was not the cause.

`artifacts/reliability/20260425-063404/` remains **local evidence only** following the same pattern as §8.6; it is NOT staged or committed and is covered by `.git/info/exclude`'s `artifacts/reliability/20260425-*/` rule.

**Honest non-claims**: S.5 is not closed by this attempt. The remaining five gates do not have green evidence under this audit. A retry on a clean macOS state (no concurrent xcodebuild instances, no parallel DerivedData locks) is the right next step before drawing conclusions, and even a clean retry does not by itself close S.5 -- the Instruments trace under launched-app load and the prose-editor typing perf proof from §8.5 remain open follow-ups. (Update: a clean-state baseline-only retry was attempted shortly after; see §8.8 below for its result.)

---

### 8.8 Reliability baseline-only clean-state retry (2026-04-25, hung again)

After §8.7 was committed, the recommended clean-state retry was attempted with no concurrent xcodebuild instances and 126 GiB free disk. Scope was narrowed to a single gate to isolate the failure mode:

```
GATES=baseline scripts/run_reliability_quality_gates.sh
```

The `baseline` gate hung again with the same shape (xcodebuild test-runner connection hang before any test executed). Tail of `artifacts/reliability/20260425-065331/baseline.log`:

```
2026-04-25 07:02:53.061 xcodebuild[23685:28013632] [MT] IDETestOperationsObserverDebug: 354.322 elapsed -- Testing started completed.
Testing failed:
	Epistemos (26228) encountered an error (The test runner hung before establishing connection.)
** TEST FAILED **
```

| Attempt | Artifact | Elapsed before hang | Outcome |
|---|---|---|---|
| 1 (063404) | `artifacts/reliability/20260425-063404/baseline.log` | 382.595 s | TEST FAILED, runner hung |
| 2 (065331) | `artifacts/reliability/20260425-065331/baseline.log` | 354.322 s | TEST FAILED, runner hung |

Both attempts failed before the `Generated Reliability Matrix` suite could establish its test-runner connection; in neither attempt did any of the 6 × 200 parametric cases execute. Same failure shape, same outcome.

`artifacts/reliability/20260425-065331/` is 8.5 GB and remains **local evidence only**, NOT staged or committed; it is covered by the existing `.git/info/exclude` rule `artifacts/reliability/20260425-*/`. After the second attempt, 126 GiB of free disk remained.

Classification update: a single hang is consistent with a transient flake; two hangs in a row, on a clean machine with no concurrent xcodebuild and ample disk, is no longer comfortably described as "transient". The honest read is that the `Generated Reliability Matrix` suite under the current xcodebuild/runner configuration on this machine is reproducibly failing the test-runner-launch handshake. This is still classified as an infrastructure / tooling failure (no test code executed), but it is a *reproducible* one until further diagnosis -- not a one-off flake.

**Honest non-claims (updated)**: S.5 remains NOT closed. The five reliability gates (`baseline`, `asan`, `tsan`, `ubsan`, `soak_repeat`) still have no green evidence under this audit. The next investigative step is no longer "just retry"; it is to diagnose why the test-runner cannot connect for this scheme/suite combination on this machine (e.g. inspect xctestrun, scheme test-host configuration, derived-data scheme, recent macOS / Xcode update interactions). The Instruments trace under launched-app load and the prose-editor typing perf proof from §8.5 remain separate, still-open S.5 follow-ups.

### 8.9 Read-only diagnostics on the two hung baseline runs (2026-04-25, evidence only)

After §8.8 was committed, three read-only diagnostics were run against the two hung-runner artifact dirs (`20260425-053639/`, `20260425-063404/`, `20260425-065331/`) plus the local source tree. **No source / project / entitlements edits were made.** Findings (one row per diagnostic):

**(1) `codesign -dv --entitlements - --requirements -`** against `Epistemos.app` and the embedded `EpistemosTests.xctest` in all three derived-data dirs returns the same shape on every bundle:

```
Format=app bundle with Mach-O thin (arm64)
CodeDirectory v=20400 ... flags=0x20002(adhoc,linker-signed) ...
Signature=adhoc
Info.plist=not bound
TeamIdentifier=not set
Sealed Resources=none
# designated => cdhash H"<cdhash>"
```

`--entitlements -` returns **no embedded entitlements blob** on any of the six bundles, and `--requirements -` returns no Designated Requirement other than the cdhash fallback. Reading: `xcodebuild test` (with an implicit build) for the Debug `Epistemos` scheme is producing a linker-signed-only bundle, with the configured `CODE_SIGN_ENTITLEMENTS = Epistemos/Epistemos-Debug.entitlements` (line 951 of `Epistemos.xcodeproj/project.pbxproj`) effectively not embedded into the test-host binary. This is consistent with how Xcode's automatic-signing path treats `CODE_SIGN_IDENTITY = "-"` for a Debug build with `app-sandbox = false` — the post-link sign step is short-circuited and only the linker's adhoc signature survives — and it is not in itself a sandbox / hardened-runtime block (no hardened-runtime flag is set, the Debug entitlements explicitly disable app-sandbox), but it does mean every rebuild presents a fresh cdhash to TCC, defeating per-binary consent caching. (See diagnostic 3 below for the consent-cache consequence.)

**(2) `git log --since=2026-04-22` against the entitlements / Info.plist / xcodeproj paths.** Touching commits, all in the App Store target work plus the unrelated landing-wave feature:

| Commit | Date | Subject | Touched |
|---|---|---|---|
| `ec4d6b73` | 2026-04-24 07:54 | feat(landing-wave): Metal liquid-wave search with flat-bar emergence | `project.pbxproj` |
| `0ab57d80` | 2026-04-24 00:17 | fix(release): compile bounded agent core for app store | `project.pbxproj` |
| `f763fbce` | 2026-04-23 23:47 | fix(release): stub native computer use in app store build | `project.pbxproj` |
| `5be4067a` | 2026-04-23 23:30 | fix(release): scrub app store runtime script assets | `project.pbxproj` |
| `e87fbb6d` | 2026-04-23 23:17 | fix(release): gate pro settings from app store profile | `project.pbxproj` |
| `ae62c93e` | 2026-04-23 23:05 | scaffold(release): add sandboxed app store target | `project.pbxproj` + new `Epistemos-AppStore.entitlements` |
| `40bcd115` | 2026-04-23 16:03 | fix(R.2): wire AliasRegistry to Swift sidebar; fix I-001 gpt-5.4 split-brain | `project.pbxproj` |

`Epistemos/Epistemos.entitlements` and `Epistemos/Epistemos-Debug.entitlements` themselves were NOT modified in this window. The new `Epistemos-AppStore.entitlements` is bound only to the `Epistemos-AppStore` target/configurations (lines 747, 875 of `project.pbxproj`); it is not bound to the `Epistemos` Debug config used by the failing `baseline` reliability gate. Reading: nothing in the recent entitlements / Info.plist / project history explains the runner-hang regression for the Pro `Epistemos` Debug test target.

**(3) `log show` for `process == "sandboxd" OR process == "syspolicyd"` and TCC / spindump events around 2026-04-25 06:34–07:13.** The two consecutive hangs in §8.7 (PID 21860) and §8.8 (PID 26228) trace to the same fingerprint:

| Event | First hang (run 063404) | Second hang (run 065331) |
|---|---|---|
| Test host launch | 06:38:25 — `launchd: Successfully spawned Epistemos[21860]` from `…/20260425-063404/derived-data-baseline/Build/Products/Debug/Epistemos.app/Contents/MacOS/Epistemos` | xcodebuild test action started 06:53:58.879; no direct test-host spawn log line captured for PID 26228 in this window |
| TCC prompt fires | 06:38:28.529 — `tccd: AUTHREQ_PROMPTING msgID=21819.9, service=kTCCServiceSystemPolicyDownloadsFolder, subject={com.epistemos.app}Resp:{TCCDProcess: identifier=Epistemos, pid=21860, binary_path=/Users/jojo/Downloads/Epistemos/artifacts/reliability/20260425-063404/derived-data-baseline/Build/Products/Debug/Epistemos.app/Contents/MacOS/Epistemos}` | 06:57:03 — `tccd: AUTHREQ_PROMPTING` for `kTCCServiceSystemPolicyDownloadsFolder` attributed to PID 26228 (same subject shape as run 1) |
| testmanagerd watchdog | 06:43:45.323 — `testmanagerd: Requesting spindump to be generated for Epistemos [21860]` (≈ 5 min 20 s after launch) | 07:02:20.552 — `testmanagerd: Requesting spindump to be generated for Epistemos [26228]` (matches the 354.322 s figure in §8.8) |
| spindump reaped | 06:44:27.476 — `spindump: Epistemos [21860]: generate spindump: saved report (requested by testmanagerd [83200])` | 07:02:39.067 — same shape |
| Concurrent system memory pressure | `kernel: process spotlightknowled [21997] crossed memory high watermark (45 MB); EXC_RESOURCE` at 06:43:38; many `memorystatus_update_jetsam_snapshot_entry_locked: failed` errors across PIDs 16265–17143 in the 06:36 window | `kernel: process fileproviderd [95580] crossed memory high watermark (20 MB); EXC_RESOURCE` at 06:53:21; `kernel: process contactsd [17885] crossed memory high watermark` at 07:04:09 |

Sandbox `deny` events in the same window are background-system, not the test host: `linkd(73039) deny file-issue-extension target:/Applications/Epistemos.app extension-class:com.apple.app-sandbox.read` (Spotlight document-linker indexing the unrelated `/Applications/Epistemos.app` install) and `spindump(22066) deny file-read-data /Users/jojo/Downloads/Epistemos/build-rust/libgraph_engine.a / libsyntax_core.a` (the spindump child blocked from reading the Rust archives — the spindump's own sandbox profile, not the test host's). Neither denies anything to the test host process itself.

**Reading.** The reproducible failure shape is:

1. The test host launches from `~/Downloads/Epistemos/artifacts/.../Epistemos.app`, which lives under `kTCCServiceSystemPolicyDownloadsFolder` protection.
2. macOS TCC fires `AUTHREQ_PROMPTING` for Downloads-folder access against the just-spawned test host. Under `xcodebuild test` running from a non-foreground Terminal session, the prompt has no foreground hosting and no automatic-grant mechanism, and the test host blocks waiting for a consent decision that does not arrive.
3. Because the test-host bundle is `Signature=adhoc`, `Sealed Resources=none`, no Designated Requirement, every rebuild presents a fresh cdhash to TCC and any prior consent for an older cdhash does not transfer — the prompt re-fires on every fresh artifact directory.
4. The xctest <-> test-host XPC handshake never completes; testmanagerd's runner-launch watchdog elapses at ≈ 354–382 s and fires `XCTDSpindumpProvider`, producing the `The test runner hung before establishing connection.` line in `baseline.log`.
5. Concurrent system-wide memory-watermark reaps of unrelated daemons (`spotlightknowledged`, `fileproviderd`, `contactsd`) are consistent with the 16 GB-Mac baseline and aggravate the timing window but are not themselves the proximate cause.

This matches the existing hint in §9.5 slice 2: that commit explicitly hardened `AppStoreHardeningTests` source-file reads to the DerivedData mirror "instead of `#filePath` (which pointed at `~/Downloads/Epistemos` and could hang on macOS TCC under xcodebuild test)." The §8.7 / §8.8 hangs reproduce that same TCC-Downloads class of failure at the test-host-launch boundary, not at a `#filePath` read site, so the slice 2 mitigation was necessary but not sufficient for the reliability-matrix gate.

**This sub-section is evidence-only.** No fix is landed here. Candidate next moves (none chosen yet, all gated behind further evidence): run the `baseline` gate from a derived-data dir outside `~/Downloads` (e.g., `~/Library/Developer/Xcode/DerivedData/...` or a `/tmp` scratch); pre-grant Downloads to `xcodebuild` / `Terminal` via System Settings → Privacy & Security → Files & Folders; codesign the test host with a stable Developer ID identity so its TCC consent caches across rebuilds; or move the reliability artifacts root out of `~/Downloads` entirely. Each candidate has its own tradeoffs (CI portability, security posture, signing-identity availability) and needs its own scope decision before any change lands. S.5 stays **open**.

---

## 9. S.3 accessibility + localization -- active implementation work (2026-04-25)

**Status:** active implementation, NOT defer-by-default. The 2026-04-25 inventory below is the size-of-work, but the red-flag findings (fixed-size fonts, missing accessibility hints/values, keyboard reachability gaps, reduce-motion one-shot gaps, English-only shipping state) are now treated as prioritized implementation tasks, not "documented and shelved". Work proceeds in small, surgical slices ranked by release risk and blast radius.

**Hard constraint:** ProseEditor (`ProseEditorView.swift`, `ProseEditorRepresentable2.swift`, `ProseTextView2.swift`) is the most polished surface in the app. S.3 work avoids ProseEditor by default. Any future ProseEditor touch -- even instrumentation -- must (1) state exactly which behaviors are unchanged (undo semantics, `isFlushingTokens`, 300 ms binding debounce, AI streaming callbacks, divider protection, IME composition, text storage flow), (2) avoid restructuring or debounce/timing changes, (3) run focused build + tests, (4) show a tight diff, (5) not claim no-regression without evidence. Prefer implementing S.3 Dynamic Type / a11y upgrades first in lower-risk SwiftUI surfaces outside ProseEditor.

### 9.1 Surface counts (raw `grep` over `Epistemos/`, Swift sources only)

| Surface | Sites | Acceptance criterion (S.3 plan) | Honest read |
|---|---|---|---|
| `.accessibilityLabel(...)` | 79 | "Every UI element has accessibilityLabel + Hint + Value where applicable" | Coverage exists but is partial; 79 is well below the SwiftUI element count of the codebase. Quality of existing labels looks reasonable on a sample (`"Back to Home"`, `"Chat title"`, `"\(modelName) model"`), not placeholder text. |
| `.accessibilityHint(...)` | 7 | Same row | **Sparse.** Most labels lack the supplemental hint that VoiceOver speaks after the label. |
| `.accessibilityValue(...)` | 0 | Same row | **Zero.** No element exposes a current value (toggles, sliders, progress states). |
| `.accessibilityIdentifier(...)` | 0 | UI testing hook (orthogonal to VoiceOver) | **Zero.** Not strictly required by S.3 but worth noting -- the AppStoreHardeningTests source-text scanner cannot also verify UI-test reachability without identifiers. |
| `.accessibilityElement(...)` / `.accessibilityAddTraits(...)` | 5 | Same row | Minimal -- combined-element grouping and trait declarations are largely absent. |
| `@Environment(\.accessibilityReduceMotion)` / `reduceMotion` | 54 | "Honor `isReduceMotionEnabled`; no RepeatForever animations without check" | **Partial.** Continuous-effect coverage is solid: 0 active `repeatForever` usages (the 2 grep hits are explicit `// NO .repeatForever` warning comments in `Theme/EpistemosTheme.swift` + `Theme/PhysicsModifiers.swift`), and `PhysicsModifiers.swift` documents that all continuous effects pause under `accessibilityReduceMotion`. **However**, the codebase has 99 `withAnimation(...)` sites + 53 `.animation(...)` modifier sites, and only 1 of them appears within 5 lines of a `reduceMotion` check by static scan. Most one-shot animations are not visibly gated. Static scan rates the continuous-effect / repeatForever risk as low; full reduce-motion compliance still needs a launched-app / manual review of the one-shot animations. |
| `@Environment(\.dynamicTypeSize)` / `DynamicTypeSize` / `@ScaledMetric` | **0** | "UI scales from xSmall to accessibility5; no clipped text" | **Zero explicit handling.** SwiftUI's relative-font fonts (`Font.body`, `.callout`, `.headline`, etc.) are present in 294 sites and scale automatically -- but the codebase ALSO has 786 sites of `.font(.system(size: <fixed>))` which do NOT scale. See 9.2. |
| `@FocusState` / `.focusable` / `.focused` | 26 | "Every interactive element reachable via Tab" | Partial. Substantial use exists, but full Tab-reachability is a launched-app verification, not a static count. |
| `String(localized: ...)` calls | 0 | "First-tier locales (EN/ES/FR/DE/JA/ZH) localized" | **Zero explicit `String(localized:)` call sites.** Note: SwiftUI `Text("Some literal")` uses `LocalizedStringKey` by default, so existing `Text(...)` literals ARE localization-ready call sites at the syntax level -- they just lack a catalog to look the key up against. The 0 count here is for the explicit `String(localized:)` API only. |
| `Localizable.strings` / `*.xcstrings` catalogs | 0 | Same row | **Zero catalogs.** Combined with 0 explicit `String(localized:)` calls, the app's effective shipping state is English-only at runtime regardless of the latent localization-readiness of `Text(...)` initializers. |

### 9.2 Dynamic Type gap quantified

The biggest single S.3 finding is the Dynamic Type gap. SwiftUI scales relative fonts (`Font.body`, `Font.callout`, `Font.headline`, `Font.title`, `Font.caption`, `Font.footnote`, `Font.system(.body, design:)` etc.) automatically with the user's chosen text size; explicit fixed point sizes do NOT scale.

- 294 sites use a relative font shape and will scale.
- **786 sites use `.font(.system(size: <fixed>))`** and will NOT scale.

A representative sample from `KnowledgeFusion/UI/TrainOnVaultView.swift` shows the pattern: `.font(.system(size: 32))`, `.font(.system(size: 11, weight: .semibold))`, `.font(.system(size: 9))`. None of these honor user accessibility text size. The right replacement shape is either `.font(.system(.body))` etc. (fully relative) or `.font(.system(size: 14, weight: .semibold)).dynamicTypeSize(...)` with a min/max range, depending on whether the layout can grow.

The 786-site rewrite is the largest S.3 punch-list item and is not landed in this audit pass; it needs a focused S.3 commit (or several) and visual QA against an actually launched app.

### 9.3 Localization gap

The app's effective shipping state is **English-only at runtime**. Static evidence as of slice 4 scaffold (2026-04-25):

- 1 `Localizable.xcstrings` catalog at `Epistemos/Resources/Localizable.xcstrings` — empty when this audit was first written, scaffolded with English base + 4 manual seed strings (Cancel / Delete / Done / Save) in slice 4. The catalog is bundled in BOTH the Pro and MAS targets via the existing `Epistemos/Resources` directory entry in `project.yml`. Pipeline evidence: every `xcodebuild` run on either scheme emits a `CompileXCStrings` step against this catalog and a `CopyStringsFile` step writing `Epistemos.app/Contents/Resources/en.lproj/Localizable.strings` into the bundle (verified in both MAS and Pro build logs). Each of the 4 seeded keys is referenced by at least one existing SwiftUI `Button("...")` / `Text("...")` / `Label("...")` call site (which compile to `LocalizedStringKey` lookups), so the seeded keys are not orphaned manual entries.
- 0 explicit `String(localized:)` call sites — still zero. **Runtime locale verification is deferred** — the slice 4 scaffold proves catalog compile + bundle, NOT runtime resolution under a non-en locale. That requires either a launched macOS app session under an `AppleLanguages` / `LANG` override or a small `Bundle` / `Locale` integration harness, neither of which is run here. Migrating non-`Text` strings (alert messages, error descriptions, menu labels passed as `String`) to `String(localized:)` is tracked as a separate slice 4b follow-up; bulk auto-extraction of the existing `Text("...")` literals into the catalog runs on Xcode-IDE builds (CLI `xcodebuild` invokes `xcstringstool compile` against the existing catalog but does not auto-extract).

### 9.4 What this S.3 inventory does NOT prove

- **No live VoiceOver session.** All counts are static `grep` results; the actual VoiceOver navigation flow has not been exercised. A real S.3 pass needs Xcode's Accessibility Inspector pointed at a launched app.
- **No Dynamic Type visual QA.** The 786-site finding is a code-shape inventory, not "how the UI actually looks at accessibility5". Some fixed-size fonts may be in surfaces (e.g., a debug overlay) where scaling is intentionally not desired; the punch-list will need per-site review.
- **No keyboard navigation walk.** Tab-reachability requires launched-app testing.
- **No RTL screenshot diff.** RTL layout correctness needs an Arabic/Hebrew locale setup, not a grep.
- **No localization plan.** Adding `Localizable.xcstrings` plus migrating ~thousands of inline literals is the bulk of an S.3 calendar week.

S.3 is therefore in **active implementation** state after this pass. Reduce Motion is partial -- continuous / `repeatForever` risk is low by static scan, one-shot animations need manual review. The remaining S.3 rows (VoiceOver hints/values, Dynamic Type, keyboard, RTL, localization-catalog) are prioritized implementation tasks, not deferred punch-list items.

### 9.5 Implementation prioritization (release risk x blast radius)

Slices are ordered by `(impact on release readiness) x (1 / blast radius)`. ProseEditor is excluded by hard constraint (see 9 header). The first three slices below are the safest starting wedges; deeper work proceeds slice-by-slice with verification between each.

1. **Settings + Toolbar Dynamic Type pass.** ✅ Landed across `c8d189e2`, `0bb13b90`, `74ce6fd8`, `8643b76e`, `814a85ae` — fixed-size `.font(.system(size: <fixed>))` replaced with relative-font shapes across the three Settings surfaces (SettingsView, OverseerSettingsView, AgentControlSettingsView), plus a corrective layout-resilience pass (LocalModelRow + LandingGreetingEditorRow) using nested ViewThatFits + `.fixedSize(horizontal: true, vertical: false)` on compact candidates so the stacked fallbacks actually trip at large Dynamic Type sizes, and `durationControls` refactored from a `@ViewBuilder` TupleView into an explicit HStack so `.fixedSize` at the call site has predictable semantics.
2. **Settings + Toolbar accessibility hint/value pass.** ✅ Landed in `d1833d4c`. Toolbar sidebar toggle, SettingsHelpHeader question-mark, workspace trash, LandingGreetingEditorRow (toggle + ordering arrows + trash + duration controls), and LocalModelRow (action buttons + install ProgressView) gain `.accessibilityLabel` / `.accessibilityHint` / `.accessibilityValue`. Title+badges and meta rows in LocalModelRow combined into single VoiceOver elements so users hear "Hermes 4, Recommended, Available" as one stop. OverseerFactRow + OverseerMetric: decorative SF Symbol hidden, surrounding HStack/VStack combined. AgentControlSettingsView: active-grant rows, Rust-backed grant rows, custom-tool Load/Delete, and approvalPattern xmark gain contextual labels. Install-progress percent uses an `isFinite`-guarded helper to avoid the `Int(Double)` NaN trap. Same commit also hardens AppStoreHardeningTests source-file reads to use `sourceMirrorURL(for:)` (DerivedData mirror) instead of `#filePath` (which pointed at `~/Downloads/Epistemos` and could hang on macOS TCC under xcodebuild test).
3. **Reduce-motion one-shot animation pass.** ✅ Landed across `c36dd3b3` (Onboarding), `5de5c195` (Landing), `aa200eee` (Chat + Notes excluding ProseEditor), `209dfcbc` (Graph + Capture + MiniChat + Shared, including AppKit `NSAnimationContext` sites in HologramOverlay refactored to bypass animator() entirely under Reduce Motion). Synthetic `Task.sleep` post-animation delays in TimeMachineView / SessionIntelligenceOverlay / WorkspaceSwitcherOverlay dismiss, NoteDetailWorkspaceView page transition, GraphInspectModeView exit, and CodeAskBar focused-panel dismiss are also conditional on `reduceMotion` so users get instant dismiss. GraphFirstOpenTitle's intro/outro choreography short-circuited under Reduce Motion to a static-display + same-hold-duration. ProseEditor explicitly excluded by hard constraint and confirmed untouched across every slice.
4. **Localization catalog scaffold + first batch.** ✅ Scaffold landed (commit subject: `phase(S.3): localization catalog scaffold + 4-string first batch`). `Epistemos/Resources/Localizable.xcstrings` created with English source language + 4 manual seed strings (Cancel / Delete / Done / Save). Each seed key is referenced by at least one existing SwiftUI `Button("...")` / `Text("...")` / `Label("...")` call site, so they are not orphaned entries. Catalog is bundled in both targets via the existing `Epistemos/Resources` resource entry — no `project.yml` change required. Pipeline evidence: both MAS and Pro build logs include `CompileXCStrings` against the catalog and `CopyStringsFile` writing `en.lproj/Localizable.strings` into the bundle. Runtime locale verification (resolving a key under a non-en locale) is **deferred** — needs a launched-app session or `LANG=` integration harness. Translation passes for first-tier locales (ES/FR/DE/JA/ZH) and migrating non-`Text` strings to `String(localized:)` are out of scope here and tracked as slice 4b follow-up.
5. **KnowledgeFusion UI Dynamic Type pass.** ✅ Landed across two commits — initial fixed-font conversion (commit subject `fix(S.3): KnowledgeFusion UI Dynamic Type pass — TrainOnVaultView`) and a corrective pass that extended the scope to fixed-frame red flags around scalable text/glyphs (commit subject `fix(S.3): KnowledgeFusion UI fixed-frame correction (slice 5b)`).

    **Fixed-font conversions (3 sites, all in `TrainOnVaultView.swift`).** Hero icon `.font(.system(size: 32))` → `.font(.largeTitle)`. descriptionRow inline icon `.font(.system(size: 11, weight: .semibold))` → `.font(.caption.weight(.semibold))` (matches the surrounding `.caption.weight(.semibold)` title). analysisChip inline icon `.font(.system(size: 9))` → `.font(.caption2)` (matches the chip's `.caption2.weight(.medium)` label).

    **Fixed-frame red flags around scalable text/glyphs (7 sites across 3 files).** Decorative glyph badges paired with scalable text: TrainOnVaultView descriptionRow background circle `.frame(width: 20, height: 20)` and TrainingHistoryView typeBadge background `.frame(width: 20, height: 20)` both replaced with `@ScaledMetric(relativeTo: .caption)` / `@ScaledMetric(relativeTo: .caption2)` so the badge container resizes alongside the glyph/letter inside it. Numeric value column: TrainOnVaultView settingRow `.frame(width: 40, alignment: .trailing)` and SettingsView KFTrainingConfigSection.kfSettingRow `.frame(width: 40, alignment: .trailing)` both relaxed to `.frame(minWidth: 40, alignment: .trailing)` so monospaced int values can grow under Dynamic Type without clipping. Two-column hardware guide rows: TrainOnVaultView hardwareGuideRow `.frame(width: 150, alignment: .leading)` and SettingsView KFTrainingConfigSection.kfHardwareRow `.frame(width: 160, alignment: .leading)` both wrapped in `ViewThatFits(in: .horizontal)` with the compact HStack pinned to its natural intrinsic width via `.fixedSize(horizontal: true, vertical: false)` and a stacked `VStack` fallback (machine label above config string) at extreme Dynamic Type sizes — same pattern slice 1's corrective pass uses for LocalModelRow. Detail row label column: TrainingHistoryView detailRow `.frame(width: 80, alignment: .leading)` relaxed to `.frame(minWidth: 80, alignment: .leading)`.

    **Truly decorative non-text glyphs left alone (explicit non-action).** FeedbackIndicatorView's 6×6 `Circle().fill(.green).frame(width: 6, height: 6)` is a pure status-indicator dot — no text or glyph inside, no Dynamic Type relevance — left as-is. The 220pt feedback popover width (`.frame(width: 220)`) is a popover container size, not a frame around scalable text directly; flagged as out-of-scope for slice 5 and tracked for visual QA at extreme Dynamic Type if review surfaces issues.

    No `.dynamicTypeSize(...max:)` clamps or `.minimumScaleFactor(...)` shortcuts applied — both would silently blunt the Dynamic Type gain.

    **MAS posture.** KnowledgeFusion UI is runtime/entry-point gated out of MAS (the Settings sidebar entry + AppBootstrap calls into `KnowledgeFusionViewModel.shared` are wrapped in `#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)`), so MAS users do not reach this UI at runtime. The source files themselves still compile in the MAS target — there is no whole-file `#if` gate on `TrainOnVaultView.swift` or `TrainingHistoryView.swift`, so the slice 5 + 5b changes must keep MAS compilation healthy. MAS build (`xcodebuild -scheme Epistemos-AppStore`) ran green on both commits and remains required evidence; "MAS blast radius is zero" is NOT a correct framing.
6. **Code editor Dynamic Type pass.** ✅ Landed (commit subject: `fix(S.3): code-editor UI chrome Dynamic Type pass — CodeEditorView`). Per-site classification: the actual code-editor text canvas is rendered by the external `CodeEditSourceEditor` package, not by SwiftUI `.font` modifiers, so editor metrics / caret / selection / `textDidChange` instrumentation are not at risk. The 24 fixed-font sites and 8 of 9 fixed-frame sites in `CodeEditorView.swift` were all UI chrome surrounding scalable text/glyphs (CodeCompanionToast, toolbar gear/eye menus, CodeSemanticSidebar, RelatedNoteRow, SemanticCodeSearchSheet, CodeInsightsPanel, InsightCard, GoToLineSheet, TabButton) and got relative `.body` / `.callout` / `.subheadline` / `.caption` / `.caption2` / `.largeTitle` styles plus `@ScaledMetric` containers (toastWidth 320, toolbarMenuWidth 20, sidebarWidth 300, sheetWidth 400 + sheetHeight 500, panelWidth 320, sheetWidth 250) and `minWidth: 100` for the GoToLine input. One intentional exception left fixed: `SearchBar`'s decorative non-text vertical Divider `.frame(height: 16)`. CodeAskBar.swift had two fixed hits but both inside a `#Preview` block (not shipped UI), so the file was left untouched per slice scope. No `.minimumScaleFactor` / `.dynamicTypeSize(...max:)` clamps. No new ViewThatFits wrappers; layouts were vertical stacks where relative growth flows naturally. CodeEditorBenchmarkTests is `.disabled("Manual benchmark suite — run via Instruments")`, so AppStoreHardeningTests is the most relevant runnable Pro test slice — green at 16/16. MAS build green.
7. **ProseEditor (LAST, by hard constraint).** ✅ Read-only audit landed (commit subject: `docs(S.3): record ProseEditor no-op slice`). **Decision: ship slice 7 as a documented no-op. No source edit to `ProseEditorView.swift` / `ProseEditorRepresentable2.swift` / `ProseTextView2.swift`.**

    Audit evidence (scoped scan over the three protected files):
    - `\.font\(\.system\(size:` / `\.font\(\.custom\(` — **0 hits** across all three files.
    - `\.frame\(width: [0-9]+|\.frame\(height: [0-9]+` — **0 hits** across all three files.
    - `withAnimation` / `\.animation\(` (SwiftUI) — **0 hits**.
    - `NSAnimationContext` / `animator()` / `runAnimationGroup` (AppKit) — **0 hits**.
    - SwiftUI `.accessibilityLabel` / `.accessibilityHint` / `.accessibilityValue` / `.accessibilityElement` — **0 hits**.
    - AppKit `setAccessibilityLabel` / `setAccessibilityHelp` / `setAccessibilityRole` / `isAccessibilityElement` — **0 hits**.

    Two AppKit `NSFont.systemFont(ofSize:)` call sites exist in `ProseTextView2.swift` and are classified as **intentional interlocked editor metrics, not isolated UI chrome**:
    - **Line 249** — body typing-font: `let bodyFont = NSFont.systemFont(ofSize: MarkdownEditorStyle.noteBaseFontSize)`. `MarkdownEditorStyle.noteBaseFontSize` (`MarkdownEditorStyle.swift:10`, `nonisolated static let = 15`) cascades through `MarkdownContentStorage.swift` (heading/list/code paragraph styling, indent math, block chrome frame computations), `Views/Shared/MarkdownTextView.swift` (preview surface), and the `bodyParagraphStyle()` / `headingParagraphStyle(...)` / `bodyIndent` / `leadingH1SpacingBefore` / `sectionH1SpacingBefore` constants in `MarkdownEditorStyle`. Changing the typing-font in isolation breaks caret/selection geometry stability, adds work to the per-keystroke `typingAttributes` write path, can interleave with `isFlushingTokens`-gated AI streaming `textStorage.replaceCharacters(...)` writes (introducing attribute-merge edge cases that could trip `NoteChatInlineResponse.editTouchesDivider`), and creates editor-vs-preview-vs-block-chrome metric disagreement.
    - **Line 1337** — fold-indicator chevron drawing inside `draw(_ dirtyRect:)` / `enumerateVisibleFragments(in:)`: `.font: NSFont.systemFont(ofSize: 9, weight: .medium)`. The chevron is positioned by `floor(indicator.lineRect.midX - glyphSize.width / 2)` / `floor(indicator.lineRect.midY - glyphSize.height / 2)` against the body text-fragment center, which is itself computed off the body font. Scaling the chevron with Dynamic Type while the body font stays fixed shifts the chevron off the heading row's optical axis at large sizes; coordinated scaling requires changing the body font first (per the F1 risk above).

    `NSTextView` (the parent class of `ProseTextView2`) ships built-in VoiceOver support via the standard `NSAccessibility` text protocol — text content, selection range, line counts, and word-boundary navigation are announced without manual `setAccessibilityLabel` / `setAccessibilityRole` calls. The editor canvas itself therefore does not need manual a11y instrumentation, and adding any would risk overriding the framework defaults. The toolbar/breadcrumb chrome around the editor lives outside the three protected files (`NoteDetailWorkspaceView`, `BreadcrumbBuilder`, etc.) and either was already touched in earlier slices or is out of scope here.

    Zero animation sites means there is nothing to gate for Reduce Motion in the editor. Visual updates come from TextKit 2 text-layout flow driven by user input or programmatic content writes, not from decorative timed animations.

    **Deferred (NOT slice 7): coordinated note-body Dynamic Type project.** A future slice would have to anchor at `MarkdownEditorStyle.noteBaseFontSize`, cascade through `MarkdownContentStorage` (paragraph styling, heading scaling, list indent), `Views/Shared/MarkdownTextView` (preview surface), and the block-chrome frame helpers, then re-validate caret/selection stability, `isFlushingTokens` interleave, divider protection, IME composition, undo, transclusion overlays, and per-keystroke performance under launched-app conditions. That is its own multi-week project with required visual QA and is explicitly out of S.3 single-slice scope. Slice 7's deliverable is the read-only audit + this decision record; further ProseEditor S.3 work happens, if at all, under a separate phase with its own scope and verification gate.

---

## 10. What this audit explicitly did NOT prove

This audit is source-level inspection plus one Swift Testing regression. It does NOT constitute App Store submission readiness. Explicit non-claims:

- **No Distribution-signed MAS Archive / submission build was produced.** A Debug `xcodebuild -scheme Epistemos-AppStore -destination 'platform=macOS' build` MAS bundle exists at `~/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Build/Products/Debug/Epistemos.app` (`CFBundleIdentifier = com.epistemos.appstore`, `Signature=adhoc`, `TeamIdentifier=not set`) and was inspected with `codesign -d --entitlements -` against the embedded entitlements (see §6 exit-criterion #3 + §7 S.2 follow-up). What was NOT produced: an `xcodebuild archive` Distribution-signed (`3rd Party Mac Developer Application`) bundle for App Store Connect upload. The Debug-bundle entitlements match the source plist exactly, so the pipeline claims in sections 1 and 2 are now backed by a runtime capture; they do not depend on a signed Archive.
- ~~**No `codesign -d --entitlements -` runtime check was run.**~~ **Partially closed 2026-04-25**: `codesign -d --entitlements -` was run against the Debug MAS bundle and the embedded entitlements match the source plist documented in §2 exactly (see exit-criterion #3 row in §6 and the §7 S.2 follow-up entry). What is still NOT proven by this pass: the Distribution-signed Archive bundle (`xcodebuild archive` with the `3rd Party Mac Developer Application` signing identity, then App Store Connect upload + review) for App Store submission has not been produced. The captured proof is a Debug `xcodebuild build` adhoc-signed bundle, which is sufficient evidence that the entitlements pipeline is wired correctly but is NOT a submission-ready signed binary.
- ~~**No `cargo test --features mas-sandbox` was run in this pass.**~~ **Resolved as of S.4 (commit subject: `test(S.4): add App Store boundedness and bookmark coverage`).** The named Rust MAS-gated tests in §4 plus two adjacent `mas_runtime_*` tests passed 9/0 under `cargo test --manifest-path agent_core/Cargo.toml --features mas-sandbox -- mas_`. Disk has cleared (155 GiB free at S.4 run vs 13 GB at original audit).
- **No TestFlight, no App Store Connect submission.** Sub-phases S.7, S.8, and S.9 are untouched.
- **No security-scoped bookmark persistence tests across relaunch under a real sandbox container.** Partially closed in S.4: `securityScopedBookmarkRoundTripsAcrossWriteCycle` exercises in-process re-resolve + a real `saveAllDirtyPages()` write cycle through the production bookmark store/resolve path (no mocks). Cross-relaunch under a real MAS sandbox container remains an explicit non-claim of the unit-test bundle and is the TestFlight (Phase S.8) gate.
- **No stricter Swift 6 concurrency audit under the sandbox.** Planned for S.4.
- **No UX-level dogfood evidence.** S.1 requires human-time using a released build; not started.
- **This is not a release-readiness statement.** It is a baseline audit so subsequent Phase S work has a documented starting point.

When these gaps close, update this doc rather than creating a new one, so the audit history stays single-source.
