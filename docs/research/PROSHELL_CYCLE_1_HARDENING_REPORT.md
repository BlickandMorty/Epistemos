# ProShell Cycle 1 Hardening Report

Date: 2026-07-05

Frontier: OpenChamber subprocess environment hardening.

Continuation check: 2026-07-06.

## Change

- Extracted ProAgent child environment construction into `Epistemos/ProAgent/ProAgentSubprocessEnvironment.swift`.
- Preserved the existing `ProAgentRuntimeSupervisor.childEnvironment` and `withUserToolPath` APIs because `ExperimentalRuntimeSupervisor` currently calls the Pro wrapper.
- Hardened inherited child env handling: allowlisted keys only, NUL rejection, max env value length, absolute-only path-like values, max PATH entry count, max PATH entry length, max PATH length, PATH dedupe, and deliberate binary/canonical/user-tool directories only.
- Added focused regression coverage in `EpistemosTests/ProAgentRuntimeSupervisorTests.swift`.
- Gated stale Goose WebView/Electron tests behind `EPISTEMOS_LEGACY_GOOSE_WEBVIEW` after the current checkout removed those production symbols in `0b10f728b`; active Goose ACP/snapshot/provider tests remain compiled, and the deleted WebView surface was not resurrected with fake types.

## Thermonuclear Review

- HIGH: 3 found, fixed.
- MED: 0 open.
- LOW: 0 open.

Fixed HIGH:
- `ProAgentRuntimeSupervisor.swift` crossed the 1,000-line maintainability threshold in the first implementation. Remediation: moved the implementation into `ProAgentSubprocessEnvironment.swift`; supervisor is now 965 lines and the helper is 101 lines.
- The first extracted helper bounded inherited PATH entries but still accepted relative entries, and forwarded relative `HOME`/`TMPDIR` if they were otherwise small and NUL-free. Remediation: path-like env values and PATH entries now must be absolute POSIX paths, with tests covering child env and goosed path augmentation.
- Thermonuclear re-review found that total PATH byte length was bounded, but the advertised total PATH entry count was only partially enforced for inherited entries. Remediation: `boundedPath` now enforces the total entry cap across binary, inherited, canonical, and user-tool directories, with regression coverage for oversized binary directory input.

## Verification

Passed:
- `swiftc -typecheck Epistemos/ProAgent/ProAgentSubprocessEnvironment.swift`
- Standalone helper behavior check compiled with `swiftc` and printed `helper-behavior-ok` after the absolute-path hardening.
- `swift test --package-path LocalPackages/EpistemosLlama` passed; the pinned `llama.xcframework` exists and the package's `import llama` path works outside the app target.
- `git diff --check` for this cycle's files.
- `python3 /Users/jojo/.codex/skills/.system/skill-creator/scripts/quick_validate.py .claude/skills/proshell-subprocess-env-hardening`
- Final non-Xcode re-run after the Goose test maintenance, thermonuclear re-review fix, final Xcode report update, and result recording passed: `git diff --check` over scoped tracked files, `swiftc -typecheck Epistemos/ProAgent/ProAgentSubprocessEnvironment.swift`, skill `quick_validate`, `swift test --package-path LocalPackages/EpistemosLlama`, and an `rg` trailing-whitespace/conflict-marker scan over the untracked cycle files.
- Standalone helper behavior check after the entry-cap fix compiled `Epistemos/ProAgent/ProAgentSubprocessEnvironment.swift` with a temporary `/tmp` harness and printed `helper-entry-cap-ok`, proving total PATH entry cap enforcement and unsafe inherited env stripping without starting Xcode.
- Clean focused Xcode test:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/epistemos-proagent-env-dd-codex-cycle1c -only-testing:EpistemosTests/ProAgentRuntimeSupervisorTests test CODE_SIGNING_ALLOWED=NO`
- Result: `** TEST SUCCEEDED **`; the Swift Testing suite "Pro agent runtime supervisor" executed 2 tests in 1 suite with 0 failures. Result bundle: `/tmp/epistemos-proagent-env-dd-codex-cycle1c/Logs/Test/Test-Epistemos-2026.07.05_23-00-32--0500.xcresult`.
- Final exact focused Xcode rerun after the entry-cap fix:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/epistemos-proagent-env-dd-codex-cycle1d -only-testing:EpistemosTests/ProAgentRuntimeSupervisorTests test CODE_SIGNING_ALLOWED=NO`
- Result: `** TEST SUCCEEDED **`; the Swift Testing suite "Pro agent runtime supervisor" executed 2 tests in 1 suite with 0 failures. Result bundle: `/tmp/epistemos-proagent-env-dd-codex-cycle1d/Logs/Test/Test-Epistemos-2026.07.05_23-45-49--0500.xcresult`.

Project-source inclusion evidence:
- `project.yml` declares the app source root as `Epistemos` with `type: syncedFolder`, so `Epistemos/ProAgent/ProAgentSubprocessEnvironment.swift` is in the generated target's source walk.
- `project.yml` declares `EpistemosTests` with `type: syncedFolder`, and the current generated project contains `PBXFileSystemSynchronizedRootGroup` / `fileSystemSynchronizedGroups` entries for `EpistemosTests`, so `EpistemosTests/ProAgentRuntimeSupervisorTests.swift` is in the test target's source walk without hand-editing `Epistemos.xcodeproj/project.pbxproj`.

Xcode retry history:
- Focused Xcode test command:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ProAgentRuntimeSupervisorTests test CODE_SIGNING_ALLOWED=NO`
- Initial result: failed before executing tests because the app target cannot resolve module dependency `llama` through `EpistemosLlama`.
- 2026-07-06 retry result: the Xcode lane was clear, so the command was retried. It completed build-script phases, reached app Swift compilation, and failed again before test execution with `Unable to resolve module dependency: 'llama'`. Xcode result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.07.05_22-22-35--0500.xcresult`.
- Read-only classification: `LocalPackages/EpistemosLlama/Package.swift` defines `llama` as a binary target at `Binary/llama.xcframework` and documents that it is a per-checkout pinned upstream XCFramework fetched by `scripts/fetch-llama-xcframework.sh`. This is the MAS/local-llama runtime lane and is outside the ProShell/OpenChamber edit boundary; this cycle does not edit it.
- Follow-up diagnosis: the local binary target is present (`Binary/llama.xcframework`) with a macOS arm64/x86_64 slice, headers, and `module.modulemap`; the package's own tests pass.
- Clean DerivedData retry attempt:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-proagent-env-dd-codex-cycle1 -only-testing:EpistemosTests/ProAgentRuntimeSupervisorTests test CODE_SIGNING_ALLOWED=NO`
- Result: started from a fresh DerivedData path, resolved packages, compiled dependencies, and reached the app target script chain. Before the app compile/test result, an external `xcodebuild -scheme Epistemos-AppStore -configuration Debug -destination platform=macOS -derivedDataPath /tmp/epistemos-appstore-dd-june-cycle1-localgate build CODE_SIGNING_ALLOWED=NO` process started concurrently. To restore the one-Xcode invariant, this focused ProAgent retry was interrupted. Exit code: 75. Xcode result bundle: `/tmp/epistemos-proagent-env-dd-codex-cycle1/Logs/Test/Test-Epistemos-2026.07.05_22-40-08--0500.xcresult`.
- Clean DerivedData retry after the external Xcode lane cleared:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/epistemos-proagent-env-dd-codex-cycle1b -only-testing:EpistemosTests/ProAgentRuntimeSupervisorTests test CODE_SIGNING_ALLOWED=NO`
- Result: exited 65 before executing tests. The app target compiled far enough to include `Epistemos/ProAgent/ProAgentRuntimeSupervisor.swift` and `Epistemos/ProAgent/ProAgentSubprocessEnvironment.swift`, then the `EpistemosTests` bundle failed compiling existing Goose web tests. First diagnostics: `EpistemosTests/GooseACPClientTests.swift:1640` cannot find `GooseWebNativePromptBridge`; `EpistemosTests/GooseLiveIntegrationTests.swift:246` cannot find `GooseWebBootstrap`; follow-on errors also reference missing `GooseWebConfig`, `GooseWebSurfaceView`, `GooseWebAffordanceDisposition`, `GooseWebNativeAffordanceBridge`, `GooseElectronFallbackLauncher`, and `GooseWebUIResolver`. Result bundle: `/tmp/epistemos-proagent-env-dd-codex-cycle1b/Logs/Test/Test-Epistemos-2026.07.05_22-44-02--0500.xcresult`.
- Read-only classification: those Goose web production sources are not present under `Epistemos/Goose` in the current checkout, while the tests still reference them. This blocked Xcode test-target verification for this cycle but was not caused by the ProAgent subprocess environment change. The retry left no generated Rust binding diffs.
- Maintenance applied in the Goose lane: stale WebView/Electron suites and helpers are now opt-in behind `EPISTEMOS_LEGACY_GOOSE_WEBVIEW`, preserving the historical tests for a future surface restoration while keeping the current Goose engine/ACP test target honest.
- Final clean DerivedData retry:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/epistemos-proagent-env-dd-codex-cycle1c -only-testing:EpistemosTests/ProAgentRuntimeSupervisorTests test CODE_SIGNING_ALLOWED=NO`
- Result: the app and test targets compiled, the scoped ProAgent suite ran, and the command succeeded.
- Exact final-diff rerun after the entry-cap fix:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/epistemos-proagent-env-dd-codex-cycle1d -only-testing:EpistemosTests/ProAgentRuntimeSupervisorTests test CODE_SIGNING_ALLOWED=NO`
- Result: after the external `Epistemos-Experimental` build cleared, the app and test targets compiled, the scoped ProAgent suite ran, and the command succeeded with 2 Swift Testing tests in 1 suite and 0 failures. Result bundle: `/tmp/epistemos-proagent-env-dd-codex-cycle1d/Logs/Test/Test-Epistemos-2026.07.05_23-45-49--0500.xcresult`.

## Boundary

This cycle intentionally does not edit protected paths, MAS June, Experimental, build scripts, or the generated Xcode project. Existing dirty changes in those areas predate this cycle and remain untouched.

Boundary scan note: a protected-path `git diff --name-only` still reports pre-existing dirty files outside this cycle, including `Epistemos.xcodeproj/project.pbxproj`, `Epistemos/AgentWorkspace/EpistemosProxyClient.swift`, `Epistemos/Engine/EpistemosSpeechSynthesizer.swift`, `Epistemos/Engine/VoicePreferences.swift`, `Epistemos/ExperimentalAgent/ExperimentalSurfaceView.swift`, `Epistemos/JuneAgent/**`, `Epistemos/Sync/VaultIndexActor.swift`, `Epistemos/Views/Epdoc/EpdocBubbleMenuView.swift`, and `Epistemos/Views/Notes/NotePreviewSurfaceView.swift`. They are not part of the scoped cycle file list below and were not edited here.

Scoped cycle file list:

- `.claude/skills/PROSHELL_SKILLS_INDEX.md`
- `.claude/skills/proshell-subprocess-env-hardening/SKILL.md`
- `.claude/skills/proshell-subprocess-env-hardening/agents/openai.yaml`
- `Epistemos/ProAgent/ProAgentRuntimeSupervisor.swift`
- `Epistemos/ProAgent/ProAgentSubprocessEnvironment.swift`
- `EpistemosTests/GooseACPClientTests.swift`
- `EpistemosTests/GooseAppContextSnapshotTests.swift`
- `EpistemosTests/GooseLiveIntegrationTests.swift`
- `EpistemosTests/GooseRuntimeSupervisorTests.swift`
- `EpistemosTests/GooseWebOnlySurfaceTests.swift`
- `EpistemosTests/GooseWebPromptLiveIntegrationTests.swift`
- `EpistemosTests/GooseWebRouteLiveIntegrationTests.swift`
- `EpistemosTests/ProAgentRuntimeSupervisorTests.swift`
- `docs/research/APP_SHELL_DEEP_AUDIT.md`
- `docs/research/OPENCHAMBER_DEEP_AUDIT.md`
- `docs/research/PROSHELL_CYCLE_1_HARDENING_REPORT.md`
