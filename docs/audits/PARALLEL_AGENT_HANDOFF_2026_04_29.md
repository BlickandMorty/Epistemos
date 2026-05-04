# Parallel Agent Handoff — 2026-04-29

Purpose: safely add parallel audit capacity while the primary Codex session finishes Patch 47, the SpeechAnalyzer crash hardening gate.

## Current Primary Session

Primary Codex is actively verifying Patch 47:

- SpeechAnalyzer best-available-format + `AVAudioConverter` hardening.
- Targeted Swift policy suite passed: `/tmp/epistemos_speech_format_patch47_tests_rerun.log`.
- MAS build is still running: `/tmp/epistemos_mas_build_after_speech_format_patch47.log`.

Do not duplicate this work.

## Global Forbidden Files

Parallel agents must not edit these files without explicit handoff clearance:

- `Epistemos/Engine/EpistemosSpeechAnalyzer.swift`
- `Epistemos/Views/Shared/VoiceInputButton.swift`
- `EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests.swift`
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `Epistemos/Graph/HologramController.swift`
- `graph-engine/**`
- `syntax-core/**/libsyntax_core.rlib`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/STABILITY_ERROR_HANDLING_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`

Primary Codex owns those docs until Patch 47 is accepted because it must append the exact verification logs.

## Global Rules

- Do not stage, commit, clean, reset, or delete unrelated files.
- Do not touch generated artifacts.
- Do not edit protected ProseEditor or graph renderer paths.
- Do not modify app behavior unless the assigned task explicitly says code edits are allowed.
- Prefer read-only audit outputs under new filenames to avoid merge conflicts.
- Every claim must cite file paths, log paths, or crash report paths.
- If you find a P0/P1 issue, write a fix order; do not patch outside the assigned write set.

## Safe Work For Parallel Codex

### Task C1 — Crash Regression Triage, Read-Only

Write only:

- `docs/audits/CRASH_REGRESSION_TRIAGE_PARALLEL_CODEX_2026_04_29.md`

Allowed reads:

- `/Users/jojo/Library/Logs/DiagnosticReports/*.ips`
- `Epistemos/**`
- `docs/audits/**`

Forbidden edits:

- All global forbidden files.
- Any Swift/Rust source file.

Prompt:

```text
You are Codex acting as a read-only crash regression auditor for Epistemos.

Repo: /Users/jojo/Downloads/Epistemos

Do not edit source code. Do not stage or commit. Do not clean the repo.

Task:
1. Read recent crash reports in /Users/jojo/Library/Logs/DiagnosticReports for Epistemos and epistemos_shadow.
2. Group crashes by process, exception type, faulting thread, top app frame, and likely subsystem.
3. Separate fresh Apr 29 SpeechAnalyzer crashes from older epistemos_shadow reports.
4. For each unique crash signature, cite the exact .ips path and key frames.
5. Identify whether the crash is already covered by Patch 47 or remains open.
6. Produce a P0/P1/P2 triage table.

Output only:
docs/audits/CRASH_REGRESSION_TRIAGE_PARALLEL_CODEX_2026_04_29.md

Do not touch:
Epistemos/Engine/EpistemosSpeechAnalyzer.swift
Epistemos/Views/Shared/VoiceInputButton.swift
EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests.swift
Epistemos/Views/Notes/ProseEditor*.swift
Epistemos/Views/Graph/MetalGraphView.swift
graph-engine/**
any existing shared audit docs.
```

Acceptance:

- New report exists.
- No source files changed.
- No shared audit docs changed.
- Each crash signature has file evidence.

## Safe Work For Kimi

### Task K1 — MAS Privacy, Entitlements, And Bundle-Bloat Audit, Read-Only

Write only:

- `docs/audits/MAS_PRIVACY_ENTITLEMENTS_PARALLEL_KIMI_2026_04_29.md`

Allowed reads:

- `Epistemos.entitlements`
- `Epistemos-AppStore.entitlements`
- `Epistemos/Resources/**`
- `Epistemos.xcodeproj/**`
- `docs/audits/APP_BUNDLE_SIZE_AUDIT_2026_04_29.md`
- `docs/architecture/**`
- `Epistemos/**`

Forbidden edits:

- All source files.
- All shared audit docs.
- Project file edits.

Prompt:

```text
You are Kimi acting as a read-only Mac App Store privacy, entitlement, and bundle-bloat auditor for Epistemos.

Repo: /Users/jojo/Downloads/Epistemos

Do not edit source code. Do not edit project files. Do not stage or commit. Do not clean the repo.

Task:
1. Inspect App Store entitlements, sandbox settings, network permissions, file access, automation/accessibility/screen recording surfaces, model/download surfaces, helper tools, and PrivacyInfo.xcprivacy.
2. Inspect bundle-size evidence from docs/audits/APP_BUNDLE_SIZE_AUDIT_2026_04_29.md and identify the largest likely MAS bloat sources.
3. Classify each feature as:
   - App Store V1 safe
   - App Store V1 safe with entitlement/disclosure
   - Direct build only
   - Hidden behind disabled flag
   - Remove from V1 surface
4. Identify exact missing disclosures or risky claims.
5. Do not propose removing important product features; prefer gating, lazy loading, optional downloads, or direct-build-only switches.

Output only:
docs/audits/MAS_PRIVACY_ENTITLEMENTS_PARALLEL_KIMI_2026_04_29.md

Do not touch:
Epistemos/Engine/EpistemosSpeechAnalyzer.swift
Epistemos/Views/Shared/VoiceInputButton.swift
EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests.swift
Epistemos/Views/Notes/ProseEditor*.swift
Epistemos/Views/Graph/MetalGraphView.swift
graph-engine/**
Epistemos.xcodeproj/**
any existing shared audit docs.
```

Acceptance:

- New report exists.
- No source or project files changed.
- Every App Store risk cites a file path.
- Recommendations are gating/lazy-loading/disclosure first, not destructive removal.

## Optional Narrow Code Task After Patch 47 Clears

Do not start this until primary Codex says Patch 47 has passed.

### Task T1 — Test Warning Cleanup Only

Allowed files:

- `EpistemosTests/PipelineServiceTests.swift`
- `EpistemosTests/EpdocEndToEndSmokeTests.swift`
- `EpistemosTests/AgentHarnessTests.swift`

Known warnings to fix:

- `EpistemosTests/PipelineServiceTests.swift:3508`: redundant `#require(history)`.
- `EpistemosTests/EpdocEndToEndSmokeTests.swift:220` and `:288`: `try` around non-throwing calls.
- `EpistemosTests/AgentHarnessTests.swift:179`: deprecated `String(contentsOf:)`; use explicit encoding.

Forbidden:

- No production source edits.
- No behavior changes.
- No broad test rewrites.
- No formatting churn.

Acceptance:

- Focused relevant tests pass.
- MAS build still compiles if feasible.
- Diff limited to the three allowed test files.
