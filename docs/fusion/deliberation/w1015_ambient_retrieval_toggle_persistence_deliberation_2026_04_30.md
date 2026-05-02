# W10.15 Ambient Retrieval Toggle Persistence Deliberation — 2026-04-30

## Gate

Approved for a minimal Core/MAS-safe persistence repair.

## Classification

Core/MAS-safe.

## Scope

- Verify the existing W10.15 `AmbientRetrievalToggle` contract.
- Persist `defaultForNewConversations` and per-conversation overrides to `UserDefaults`.
- Add isolated tests proving per-conversation overrides and reset fallback survive a reload.
- Use Kimi only as read-only design advisory; no Kimi repo mutation.

## Explicit Non-Scope

- No ambient retrieval UI/header redesign.
- No retrieval-tool expansion into `QuarantineArchive`.
- No SQLite/Rust quarantine backend.
- No protected note editor, protected graph renderer/controller, graph-engine/Rust, project, entitlement, generated artifact, branch, stash, staging, or commit edits.
- No manual app runtime verification in this slice.

## Evidence Before Edit

- `QuarantineArchive.swift` documents per-conversation ambient retrieval persistence.
- `AmbientRetrievalToggle` only stored `defaultForNewConversations` and `perConversation` in memory.
- `ToggleAmbientRetrievalIntent` calls `AmbientRetrievalToggle.shared.setEnabled(...)`, so a process restart would lose the user's explicit ambient-retrieval choice.
- `QuarantineArchive.swift` already had unrelated dirty sliding-window archive changes before this persistence slice; those are not claimed as W10.15 persistence work here.

## Decision

Treat W10.15 as a targeted persistence hardening slice. The correct minimal implementation is a namespaced `UserDefaults` store with test-only defaults injection/reload hooks so focused tests do not pollute the user's real defaults.

## Test Plan

- Add `AmbientRetrievalToggleTests` proving:
  - default ambient mode and explicit per-conversation overrides survive reload;
  - `reset(_:)` removes an explicit override and falls back to the persisted default.
- Run:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/AmbientRetrievalToggleTests test`

## Stop Triggers

- Any need to alter retrieval visibility semantics.
- Any need to edit chat UI, protected note editor files, graph renderer/controller files, graph-engine/Rust, project files, or generated artifacts.

## Kimi Advisory

Kimi was run from `/tmp` with pasted context only. It recommended:

- inject `UserDefaults` for test isolation;
- load on initialization/reload and write on mutation;
- preserve observable stored properties;
- avoid singleton pollution and namespacing collisions.

Kimi did not edit code, run repo mutation commands, or control the worktree.

## Result

Red verification failed exactly on the missing persistence test hooks:

- Log: `/tmp/epistemos-w1015-ambient-toggle-red-20260430.log`
- Result: `** TEST FAILED **`
- Expected failures:
  - `AmbientRetrievalToggle` had no `resetForTesting`;
  - `AmbientRetrievalToggle` had no `setUserDefaultsForTesting`;
  - `AmbientRetrievalToggle` had no `reloadFromUserDefaultsForTesting`.

Implemented the minimal fix:

- `AmbientRetrievalToggle` now hydrates persisted defaults and per-conversation overrides from namespaced `UserDefaults` keys.
- `defaultForNewConversations` writes through on mutation while suppressing writes during load.
- `setEnabled(_:, for:)` and `reset(_:)` persist the per-conversation map.
- DEBUG-only test hooks inject isolated `UserDefaults`, reload persisted state, and reset the singleton after tests.

Green verification passed:

- Log: `/tmp/epistemos-w1015-ambient-toggle-green-20260430.log`
- Result: `** TEST SUCCEEDED **`
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_22-29-47--0500.xcresult`
- Swift Testing result: `2` tests passed in `1` suite.

Codex reverification before staging also passed:

- Log: `/tmp/epistemos-w1015-ambient-toggle-reverify-20260501.log`
- Result: `** TEST SUCCEEDED **`
- Result bundle:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_22-26-26--0500.xcresult`
- Swift Testing result: `2` tests passed in `1` suite.
- Staging note: `QuarantineArchive.swift` has unrelated dirty sliding-window archive changes in the working tree; this commit stages only the ambient retrieval persistence section.
