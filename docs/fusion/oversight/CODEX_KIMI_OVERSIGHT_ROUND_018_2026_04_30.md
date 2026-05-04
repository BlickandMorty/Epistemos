# Codex / Kimi Oversight Round 018 — 2026-04-30

## Slice

W10.16 ConversationState dispatch read-site repair.

## Scope

- `Epistemos/App/ChatCoordinator.swift`
- `EpistemosTests/ConversationStateDispatchTests.swift`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

## Decision

Approved for minimal Core/MAS-safe dispatch repair per deliberation gate `docs/fusion/deliberation/w1016_conversation_state_dispatch_deliberation_2026_04_30.md`.

## Implementation Summary

- Stable `conversationStateId` derived as trimmed `chatId`, else trimmed `parentSessionID`, else per-run `sessionId`.
- `EventStore.loadConversationStateJSON(conversationId: conversationStateId)` called before prompt assembly.
- When prior state exists, `conversationHistory` passed to `PipelineService.buildPromptEnvelope` is compacted to a recent-turn tail (`maxMessages: 4`, `maxCharacters: 4_000`).
- Prior state JSON injected into system prompt.
- Rebuilt `ConversationState` saved back under the same stable id.
- In-memory classifier state keyed by stable id.
- Per-run `sessionId` retained for runtime artifacts (agent session, metrics, lineage store).
- Codex post-audit removed a production force unwrap from Kimi's patch and added source-mirror guards for the actual `runRustAgentPath` load/save and objective call sites.

## Test Results

- 11/11 focused tests pass.
- Log: `/tmp/epistemos-w1016-conversation-state-dispatch-green-20260430.log`
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_23-11-43--0500.xcresult`
- Full suite not re-run in this slice; focused test gate is green.

## Risks

- `ChatCoordinator.swift` had unrelated pre-existing dirty approval-modal queue wiring before this slice; this round claims only the W10.16 ConversationState read-site repair.
- `parentSessionID` fallback changes each time `recordCompletedSession` updates the mapping, so persistence across nil-`chatId` sessions is only as stable as the last recorded parent. This is acceptable per deliberation (fallback behavior).
- AFM unavailability on pre-26 machines keeps existing best-effort/nonfatal swallow.
- Command-center Rust agent path (`runCommandCenterRustAgentPath`) was not modified; it does not yet participate in ConversationState persistence. Addressing it is out of scope for this slice.
