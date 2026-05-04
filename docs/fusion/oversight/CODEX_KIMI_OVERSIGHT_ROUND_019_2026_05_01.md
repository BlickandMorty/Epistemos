# Codex / Kimi Oversight Round 019 - 2026-05-01

## Slice

R9 Chat + BrainDump Indexed Entities.

## Scope

- `Epistemos/Intents/Entities/ChatEntity.swift`
- `Epistemos/Intents/Entities/BrainDumpEntity.swift`
- `EpistemosTests/IndexedEntityTests.swift`
- `docs/fusion/deliberation/r9_chat_brain_dump_indexed_entities_deliberation_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

## Decision

Approved for minimal Core/MAS-safe App Intents entity work per deliberation gate `docs/fusion/deliberation/r9_chat_brain_dump_indexed_entities_deliberation_2026_05_01.md`.

## Kimi Work

- Kimi created the first pass for `ChatEntity`, `BrainDumpEntity`, and `IndexedEntityTests`.
- Kimi ran a focused xcodebuild test with `tee`; the test output reported `** TEST SUCCEEDED **` with 9/9 focused tests green, but the pipe made the shell exit code less authoritative.
- Kimi updated the R9 deliberation doc with preliminary evidence.

## Codex Audit And Fixes

- Removed non-ASCII marks from the new code files.
- Hardened `ChatEntity` so it carries a trimmed `contentPreview` field and exposes that preview to Core Spotlight.
- Hardened `ChatEntityQuery` so matching checks chat title, chat type, linked page id, and recent message preview instead of title only.
- Hardened `BrainDumpEntity` Spotlight titles so indexed brain dumps are distinguishable by body preview.
- Hardened `BrainDumpEntityQuery` so matching checks body, kind, and anchor context.
- Reworked focused tests so they verify bounded result surfaces without depending on an empty app bootstrap or empty test store.
- Re-ran the focused test under Codex with output redirected to a log file and the real xcodebuild exit code preserved.

## Test Results

- Command:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/IndexedEntityTests test`
- Log: `/tmp/epistemos-r9-indexed-entities-codex-green-20260501.log`
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_00-32-03--0500.xcresult`
- Exit code: `0`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result: 9 tests passed in 1 suite.

## Guardrails

- No protected note editor files (`ProseEditor*`) changed.
- No protected graph renderer/controller files (`MetalGraphView`, `HologramController`) changed.
- No `graph-engine/**` Rust edits were made by this slice.
- No `project.yml`, `.xcodeproj`, entitlements, generated artifacts, branch, stash, staging, or commit edits were made by this slice.
- `git diff --check` on touched R9 files is clean.
- New code files are ASCII-clean.

## Risks

- `IndexedEntity.donate()` call sites remain unwired; this slice only adds entity/query/indexable surfaces.
- Actual Siri/Shortcuts/Spotlight runtime surfacing was not manually verified in this slice.
- Xcode still prints SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; this is package-plugin noise that pre-exists R9 and did not block the focused test exit code.
