# R9 Chat + BrainDump Indexed Entities Deliberation - 2026-05-01

## Gate

Approved for a minimal Core/MAS-safe App Intents entity slice with Kimi allowed to edit only inside the bounded scope below.

## Classification

Core/MAS-safe.

## Scope

- Add `ChatEntity` mirroring `SDChat`.
- Add `BrainDumpEntity` mirroring `QuarantineEntry`.
- Conform both new entities to `IndexedEntity` using Core Spotlight attribute sets.
- Add entity queries that follow the existing `NoteEntityQuery` pattern:
  - return `[]` when `AppBootstrap.shared` is unavailable for SwiftData-backed chat lookup;
  - log and continue on fetch failures;
  - keep query suggestions bounded.
- Add focused tests/source guards proving the entities exist, conform to `IndexedEntity`, expose query types, and map from `SDChat` / `QuarantineEntry`.

## Allowed Write Scope

- `Epistemos/Intents/Entities/ChatEntity.swift`
- `Epistemos/Intents/Entities/BrainDumpEntity.swift`
- `EpistemosTests/*Indexed*Entity*Tests.swift` or another focused App Intents entity test file
- `docs/fusion/deliberation/r9_chat_brain_dump_indexed_entities_deliberation_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_019_2026_05_01.md`

## Explicit Non-Scope

- No `project.yml` or `.xcodeproj` edits; the app target already uses synced folders.
- No App Store entitlement changes.
- No Rust, `graph-engine/**`, protected note editor files, protected graph renderer/controller files, generated artifacts, branch, stash, staging, or commit edits.
- No Spotlight donation call-site wiring in this slice.
- No manual app runtime verification in this slice.

## Evidence Before Edit

- `NoteEntity` and `NoteEntity+IndexedEntity` already establish the canonical AppEntity + IndexedEntity pattern.
- `SDChat` exists as the SwiftData chat-thread model.
- `QuarantineEntry` exists as the append-only raw thought / brain dump record.
- No `ChatEntity`, `ThoughtEntity`, or `BrainDumpEntity` definitions currently exist.

## Decision

Implement `BrainDumpEntity` rather than a generic `ThoughtEntity` because the current production substrate is `QuarantineEntry` / brain-dump capture. This closes the R9 entity scaffold without inventing a separate thought persistence model.

## Test Plan

- Add failing focused tests/source guards first for:
  - `ChatEntity` and `BrainDumpEntity` definitions;
  - `IndexedEntity` conformance for both;
  - query types and bounded suggested/matching query surfaces;
  - `SDChat.toChatEntity(...)` and `QuarantineEntry.toBrainDumpEntity(...)` conversion helpers.
- Run:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/<FocusedIndexedEntityTests> test`

## Stop Triggers

- Any need to change SwiftData schemas.
- Any need to touch project generation or entitlements.
- Any need to wire Spotlight donation call sites.
- Any compile issue requiring protected editor/graph/Rust changes.

## Kimi Build Permission

The user explicitly granted Kimi permission to edit for build slices. Kimi must follow the allowed write scope, run no destructive git/stash commands, avoid protected paths, and leave final verification to Codex.

---

## Build Results - 2026-05-01

### Changed Files

- `Epistemos/Intents/Entities/ChatEntity.swift` - new; `ChatEntity` (AppEntity + IndexedEntity), `ChatEntityQuery` (EntityStringQuery, bounded, logs failures), message-preview extraction, and `SDChat.toChatEntity()`.
- `Epistemos/Intents/Entities/BrainDumpEntity.swift` - new; `BrainDumpEntity` (AppEntity + IndexedEntity), `BrainDumpEntityQuery` (EntityStringQuery, bounded/recent-first via `QuarantineArchive.shared.snapshot()`), anchor-aware matching, and `QuarantineEntry.toBrainDumpEntity()`.
- `EpistemosTests/IndexedEntityTests.swift` - new; 9 focused Swift Testing tests proving entity definitions, IndexedEntity conformance, query types, bounded behavior, and conversion helpers.

### Test Command

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/IndexedEntityTests test
```

### Test Result

**TEST SUCCEEDED** - Codex final verification passed with exit code `0`.
- Suite "Indexed Entity Definitions" passed.
- Test run with 9 tests in 1 suite passed after 0.023 seconds.

Log path: `/tmp/epistemos-r9-indexed-entities-codex-green-20260501.log`

Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_00-32-03--0500.xcresult`

### Codex Reverification - 2026-05-01 22:14 CDT

Re-ran the same focused command before staging this slice.
- Exit code: `0`
- Suite "Indexed Entity Definitions" passed.
- Test run with 9 tests in 1 suite passed after 0.007 seconds.
- Log path: `/tmp/epistemos-r9-indexed-entities-reverify-20260501.log`
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_22-11-06--0500.xcresult`

Note: Xcode still printed SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`; the focused R9 process exited `0`, and those package-lint failures pre-exist this slice.

### Residual Risks

1. **Spotlight donation unwired** - `IndexedEntity.donate()` call sites are not yet added; Core Spotlight indexes will be stale until a follow-up slice wires donations after chat/brain-dump mutations.
2. **AppBootstrap dependency** - `ChatEntityQuery` requires `AppBootstrap.shared` + `modelContainer`; if bootstrap is nil, queries return empty. This matches the `NoteEntityQuery` pattern but means results are unavailable until bootstrap completes.
3. **QuarantineArchive shared state** - `BrainDumpEntityQuery` reads from `QuarantineArchive.shared.snapshot()`; if the archive has been reset or is empty, matching/suggested results will be empty. Boundedness is enforced but data availability depends on prior capture activity.
4. **No runtime intent verification** - this slice validates compile-time correctness and unit-test behavior; actual Siri/Shortcuts/Spotlight surfacing is not exercised.
