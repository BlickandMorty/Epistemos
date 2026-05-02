# Halo V1 Domain Re-query PR2 Deliberation — 2026-05-02

## Decision

Approve the narrow Halo V1 domain-picker repair.

The mounted V1 panel must not expose an inert Notes / Chats segmented control. Changing domains should re-run the current Halo query through the existing `HaloController` debounce/search path and keep the panel open when the user switches while browsing results.

## Approved Write Set

- `Epistemos/Engine/HaloController.swift`
- `Epistemos/Views/Halo/ShadowPanelContent.swift`
- `EpistemosTests/HaloControllerTests.swift`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`

## Forbidden In This Slice

- No protected note editor files.
- No graph, Rust, generated binding, or FFI edits.
- No new search service abstraction.
- No synchronous search on the MainActor.

## Implementation Shape

- `HaloController` remembers the latest meaningful query context.
- `selectDomain(_:)` changes the domain, cancels stale work, and reuses the existing async search scheduling.
- If the panel was open, a successful domain switch keeps the state at `.open(domain:)`.
- `ShadowPanelContent` calls `controller.selectDomain(_:)` from the segmented picker.

## Acceptance

- Failing controller test first for open-panel domain switch re-query.
- Focused Halo controller/UI tests pass.
- Source audit confirms no production `HaloEditorBridge` mount and no protected editor changes.
