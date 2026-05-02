# W10.16 ConversationState Dispatch Read-Site Deliberation - 2026-04-30

## Gate

Approved for a minimal Core/MAS-safe dispatch repair with Kimi allowed to edit only inside the bounded scope below.

## Classification

Core/MAS-safe.

## Scope

- Close the AR2/W10.16 read-site gap in `ChatCoordinator.runRustAgentPath`.
- Use a stable conversation-state key derived from the chat/thread identity instead of a fresh per-run UUID.
- Load `EventStore.loadConversationStateJSON(...)` before agent prompt assembly when a stable state is available.
- Reduce raw conversation-history prompt input for state-backed agent turns to the recent-turn tail, preserving the current request and explicit notes/context.
- Save rebuilt `ConversationState` back under the same stable key.
- Add focused tests/source guards proving stable-key load/save and state-backed prompt compaction.
- Kimi may edit the approved files, but Codex must independently review and run verification before the slice is accepted.

## Allowed Write Scope

- `Epistemos/App/ChatCoordinator.swift`
- `EpistemosTests/*ConversationState*Tests.swift` or an existing focused source-guard test file if reuse is cleaner
- `docs/fusion/deliberation/w1016_conversation_state_dispatch_deliberation_2026_04_30.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_018_2026_04_30.md`

## Explicit Non-Scope

- No protected note editor files.
- No protected graph renderer/controller files.
- No graph-engine/Rust edits.
- No xcodeproj, entitlement, generated artifact, branch, stash, staging, or commit edits.
- No command-center path rewrite unless a focused source test proves the same AR2 read-site bug there and the fix stays inside `ChatCoordinator.swift`.
- No manual app runtime verification in this slice.

## Evidence Before Edit

- `ConversationStateClassifier` and `EventStore` persistence already exist.
- `ChatCoordinator.runRustAgentPath` currently creates `sessionId = UUID().uuidString` for every run.
- The AR2 read-site currently calls `loadConversationStateJSON(conversationId: sessionId)`, so subsequent chat turns cannot reliably find a prior state saved under a previous per-run UUID.
- The same function builds `objective` with `PipelineService.buildPromptEnvelope(... conversationHistory: conversationHistory)` before loading structured state, so state-backed turns can still carry the full/raw history budget.

## Decision

Treat this as a dispatch read-site repair, not a classifier redesign. The canonical behavior is:

- agent session/runtime artifacts can keep using the per-run `sessionId`;
- conversation-state lookup and save use a stable chat/thread key;
- when prior structured state is available, the agent receives that state plus a bounded recent-turn tail rather than the full raw transcript budget.

## Test Plan

- Add failing tests/source guards first for:
  - stable `conversationStateId` derivation separate from `sessionId`;
  - `loadConversationStateJSON` and `saveConversationState` both using the stable conversation-state key;
  - state-backed objective construction using a compacted recent-history variable rather than the original full `conversationHistory`.
- Run the focused test file with:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/<FocusedConversationStateTests> test`

## Stop Triggers

- Any need to change Rust `agent_core/src/compaction.rs`.
- Any need to change EventStore schema or migration.
- Any need to edit protected editor/graph files.
- Any uncertainty about whether the stable key is chat-scoped or session-lineage-scoped that cannot be resolved from current source.

## Kimi Build Permission

The user explicitly granted Kimi permission to edit for this slice. Kimi must follow the allowed write scope, run no destructive git/stash commands, avoid protected paths, and leave final verification to Codex.


## Implementation

- Added `ChatCoordinator.deriveConversationStateId(chatId:parentSessionID:sessionId:)` — stable key is trimmed `chatId`, else trimmed `parentSessionID`, else per-run `sessionId`.
- Added `ChatCoordinator.effectiveConversationHistory(fullHistory:chatState:hasPriorState:)` — returns compacted recent-turn tail (`maxMessages: 4`, `maxCharacters: 4_000`) when prior state exists, otherwise passes full history unchanged.
- Wired both helpers into `runRustAgentPath`:
  - `conversationStateId` computed immediately after per-run `sessionId`.
  - `EventStore.loadConversationStateJSON(conversationId: conversationStateId)` called before prompt assembly.
  - `PipelineService.buildPromptEnvelope` receives `effectiveConversationHistory`.
  - System prompt appends prior state JSON when present.
  - Post-turn save and in-memory classifier state both use `conversationStateId`.
- Per-run `sessionId` retained for agent runtime artifacts, session metrics, and lineage store.
- Codex post-audit removed Kimi's temporary production force unwrap and added source-mirror guards for the actual `runRustAgentPath` load/save and objective call sites.

## Verification

- `EpistemosTests/ConversationStateDispatchTests.swift` — 11 tests, all green.
- Focused test command:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ConversationStateDispatchTests test`
- Log: `/tmp/epistemos-w1016-conversation-state-dispatch-green-20260430.log`
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.04.30_23-11-43--0500.xcresult`
- Re-verified by Codex on 2026-05-01 with the same focused command.
- Re-verification log: `/tmp/epistemos-w1016-conversation-state-dispatch-green-20260501.log`
- Re-verification result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_21-51-52--0500.xcresult`

## Residual Risk

- `ChatCoordinator.swift` had unrelated pre-existing dirty approval-modal queue wiring before this slice; this gate claims only the W10.16 ConversationState read-site repair.
- `runCommandCenterRustAgentPath` does not yet participate in ConversationState persistence; out of scope for this slice.
- `parentSessionID` fallback shifts when `recordCompletedSession` updates the mapping, so nil-`chatId` sessions have weaker cross-turn stability.
