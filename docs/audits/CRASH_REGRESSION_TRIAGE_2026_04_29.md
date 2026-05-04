# Crash Regression Triage - 2026-04-29

Scope: local macOS crash reports in `~/Library/Logs/DiagnosticReports/Epistemos*.ips`, with emphasis on reports from the last three days and older repeated signatures that could still indicate reachable app instability.

## Summary

Latest three-day window:

- Three crash reports exist: `Epistemos-2026-04-29-075001.ips`, `Epistemos-2026-04-29-075435.ips`, and `Epistemos-2026-04-29-183409.ips`.
- The 07:50 and 07:54 reports have the same signature: `EXC_BREAKPOINT` / `SIGTRAP`, faulting thread `com.apple.root.user-initiated-qos.cooperative`, frame `EpistemosSpeechAnalyzer.swift:195 closure #2 in EpistemosSpeechAnalyzer.startLive(onModelDownload:)`.
- Patch 37 removed the double-bound SpeechAnalyzer live-stream call shape, but the same fresh report set still points at the live start path inside Speech.framework. Patch 47 adds a second hardening layer: it asks SpeechAnalyzer for the best compatible analysis format, prepares the analyzer in that format, converts mic buffers with `AVAudioConverter`, and stops yielding raw input-node buffers directly.
- The 18:34 report is a separate SpeechAnalyzer crash shape: `EXC_BREAKPOINT` / `SIGTRAP` in `_swift_task_checkIsolatedSwift`, faulting at `closure #3 in EpistemosSpeechAnalyzer.startLive(onModelDownload:)`. Patch 48 removes the audio-tap callback's `self?.inputContinuation?.yield` access so the realtime AVAudio queue no longer reaches into the `@MainActor` analyzer instance.

Older reports:

- April 22-23 `EXC_BREAKPOINT` reports in `OmegaToolCallParserTests.swift:211` and `TriageServiceTests.swift:2157` are test assertion/subscript failures, not normal app runtime crash reports.
- April 22 `EXC_BAD_INSTRUCTION` in `agent_core::tools::trajectory::trajectory_export_schema` maps to trajectory tool registration. Current code wraps `register_phase_eight_trajectory()` in `catch_unwind` and provides a disable path; targeted trajectory tests are green.
- April 23-24 `EXC_BAD_ACCESS` reports fault at `objc_release` during main-actor autorelease-pool draining with no Epistemos source frame in the top stack. These are not actionable without a fresh reproduction or symbol-rich runtime log.

## Evidence

Crash inventory commands:

- `ls -lt ~/Library/Logs/DiagnosticReports/Epistemos*.ips`
- `find ~/Library/Logs/DiagnosticReports -maxdepth 1 -name 'Epistemos*.ips' -mtime -3 -print`
- `tail -n +2 <report>.ips | jq ...` for exception and faulting-frame summaries

Patch 37 verification:

- `/tmp/epistemos_speech_analyzer_crash_patch37_tests_ctki_cache.log`: `** TEST SUCCEEDED **`, `EXIT:0`, 29 tests passed.
- `/tmp/epistemos_mas_build_after_speech_analyzer_crash_patch37.log`: `** BUILD SUCCEEDED **`, `EXIT:0`.
- `/tmp/epistemos_speech_analyzer_crash_patch37_gate.log`: focused policy tests, MAS build, and crash-pattern source removal all `PASS`.

Patch 47 verification:

- `/tmp/epistemos_speech_format_patch47_tests.log`: failed before producing compile evidence because the machine ran out of disk and the shell wrapper used the read-only zsh variable name `status`; not counted as product evidence.
- `/tmp/epistemos_speech_format_patch47_tests_rerun.log`: `** TEST SUCCEEDED **`, `EXIT:0`, 32 runtime capability and performance policy tests passed.
- `/tmp/epistemos_mas_build_after_speech_format_patch47.log`: `** BUILD SUCCEEDED **`, `EXIT:0`; CodeEdit SwiftLint script-phase tail noise did not change the xcodebuild exit status.
- `/tmp/epistemos_speech_format_patch47_gate.log`: `GATE_EXIT:0`, production source uses `bestAvailableAudioFormat`, `prepareToAnalyze(in:)`, and `AVAudioConverter`, and production source no longer yields raw `AnalyzerInput(buffer: buffer)` mic buffers.

Patch 48 verification:

- `/tmp/epistemos_speech_tap_isolation_patch48_tests.log`: `** TEST SUCCEEDED **`, `EXIT:0`, 32 runtime capability and performance policy tests passed.
- `/tmp/epistemos_mas_build_after_speech_tap_isolation_patch48.log`: `** BUILD SUCCEEDED **`, `EXIT:0`; CodeEdit SwiftLint script-phase tail noise did not change the xcodebuild exit status.
- `/tmp/epistemos_speech_tap_isolation_patch48_gate.log`: `GATE_EXIT:0`, production source yields through the local `inputCont`, no longer references `self?.inputContinuation?.yield` from the audio tap, and protected ProseEditor/graph paths remain untouched.

Trajectory crash regression verification:

- `/tmp/epistemos_agent_core_trajectory_crash_regression.log`: `EXIT:0`, 3 tests passed.
- Current `agent_core/src/tools/registry.rs` wraps `trajectory_export_schema()` registration with `std::panic::catch_unwind(AssertUnwindSafe(...))` and logs/skips the tool on panic.

## Findings

| Severity | Signature | Evidence | Status |
|---|---|---|---|
| P0 | SpeechAnalyzer live dictation crash | `Epistemos-2026-04-29-075001.ips`, `Epistemos-2026-04-29-075435.ips`; faulting frame `EpistemosSpeechAnalyzer.swift:195` | Patch 37 removed the double-bound stream shape; Patch 47 adds best-compatible-format preparation and mic-buffer conversion. Runtime mic smoke deferred |
| P0 | SpeechAnalyzer audio-tap actor-isolation trap | `Epistemos-2026-04-29-183409.ips`; frame `_swift_task_checkIsolatedSwift` then `closure #3 in EpistemosSpeechAnalyzer.startLive` | Patch 48 removes MainActor instance access from the AVAudio tap callback. Runtime mic smoke deferred |
| P1 | Trajectory registration bad instruction | `Epistemos-2026-04-22-211931.ips`; frame `trajectory.rs:246` | Current code has panic guard and targeted tests pass |
| P2 | Test assertion crashes | April 22-23 reports in test files | Not app-runtime blockers; keep test selectors/logs honest |
| P2 | `objc_release` main-thread crashes | `Epistemos-2026-04-23-115206.ips`, `Epistemos-2026-04-24-005559.ips` | Needs fresh reproduction; no actionable source frame in current reports |

## Next Action

Continue the hardening queue. Do not open another SpeechAnalyzer code patch unless a fresh post-Patch-48 crash report appears or a runtime mic smoke reveals a new, specific failure. The old `objc_release` signature still needs a fresh reproduction or symbol-rich runtime log before it is actionable.
