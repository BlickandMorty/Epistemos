# Ambient Recall / Contextual Shadows Wiring Plan

Date: 2026-04-28

Verdict: PARTIAL V0 IS USER-SURFACED BEHIND FLAG. Do not repeat the stale claim that the UI is absent. The current gap is runtime click/SLA proof, true chat-indexed hit support, visible default policy, and user-facing recovery behavior.

## Current State

- Rust recall substrate exists in `graph-engine/src/retrieval_index.rs` and is bridged through the Instant Recall FFI surface.
- Swift service exists in `Epistemos/KnowledgeFusion/InstantRecallService.swift`.
- Async search path exists: `InstantRecallService.searchAsync(query:topK:)` wraps the FFI search off the caller actor with `Task.detached`.
- Sync vault-wide rebuild/indexBatch entrypoints on `InstantRecallService` are now compile-time unavailable stubs. Production vault rebuild uses `rebuildIndexAsync(notes:)`, and `searchAsync(query:topK:)` now triggers lazy initial snapshot hydration.
- Contextual Shadows state exists in `Epistemos/State/ContextualShadowsState.swift`.
- Note typing hook exists in `Epistemos/Views/Notes/ProseEditorRepresentable2.swift` via `scheduleContextualShadowsRecall`.
- Chat composer support exists in `Epistemos/Views/Chat/ChatInputBar.swift`; the call-site must be reverified after each refactor.
- UI exists in `Epistemos/Views/Recall/ContextualShadowsButton.swift` and `Epistemos/Views/Recall/ContextualShadowsPanel.swift`.
- The V0 button/panel is mounted in `Epistemos/Views/Chat/ChatInputBar.swift` and `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`; source proof is captured in `/tmp/epistemos_contextual_shadows_wiring_audit.log`.
- `ContextualShadowsStateTests` passed 11/11 in `/tmp/epistemos_contextual_shadows_tests.log`, including disabled behavior, cancellation, stale-result clearing, and honest note-only V0 classification.
- App environment injection exists in `Epistemos/App/AppEnvironment.swift` and `Epistemos/App/AppBootstrap.swift`.
- The surface is currently guarded by `EPISTEMOS_AMBIENT_RECALL_V0`.

## Missing Links

| Gap | Evidence | Severity | Required outcome |
|---|---|---:|---|
| True chat recall hits are not supported yet | `InstantRecallService` currently indexes notes; V0 now classifies returned hits as notes and hides the Chat tab when `chatHits` is empty | HIGH | Add real chat indexing/artifact metadata before showing chat hits |
| Right-click summarize for chat hits is not verified | `ContextualShadowsPanel` has Notes/Chats tabs but no proven summarize command path | MEDIUM | Chat rows expose a contextual "Summarize" command only when the chat artifact can be opened/read |
| Open result routing needs runtime smoke proof | Source audit proves chat and note hosts wire `onOpen`, but no live click smoke has been run | HIGH | Click a result and land on the exact artifact/block |
| Large-vault recall p95 proof is missing | Async-only rebuild is source/test gated, but no large-vault signpost proof has been captured | MEDIUM | Capture p95 rebuild/search evidence before default-on recall claims |
| No end-to-end typing SLA proof | Prior tests cover pieces; no trace proves typing -> recall -> panel without hitch | HIGH | Add a deterministic state test plus signpost or focused UI smoke |
| Failure/empty states are thin | V0 can show nothing if index missing or disabled | MEDIUM | Panel/button has clear empty/error state without interrupting typing |

## Minimal V1 Implementation

1. Keep the V0 surface small: contextual button plus lightweight panel only.
2. Keep `EPISTEMOS_AMBIENT_RECALL_V0` until the smoke path is green.
3. Keep V0 notes-first until indexed artifact metadata can classify hits as note or chat.
4. Open notes and chats through the same production routing used elsewhere in the app.
5. Keep inline editing out of V1 unless the result opens in the existing note editor.
6. Add a right-click summarize action for chat hits only after chat artifact lookup is reliable.
7. Move all index rebuild/search work off MainActor; only final state mutation returns to MainActor.

## Files To Modify

| File | Change |
|---|---|
| `Epistemos/KnowledgeFusion/InstantRecallService.swift` | Keep sync rebuild/indexBatch unavailable; add p95 signposts if recall becomes default-on |
| `Epistemos/State/ContextualShadowsState.swift` | Keep stale-hit clearing; later preserve hit kind from index metadata when available; add explicit missing-index/error state |
| `Epistemos/Views/Recall/ContextualShadowsPanel.swift` | Keep notes-first chat-tab hiding; add chat-only summarize context menu after chat lookup is reliable |
| `Epistemos/Views/Chat/ChatInputBar.swift` | Verify debounce call-site and cancellation after message send |
| `Epistemos/Views/Notes/ProseEditorRepresentable2.swift` | Protected path: only touch if a failing test proves the recall hook is broken |
| `Epistemos/App/AppEnvironment.swift` | Keep single-source injection; no manual environment drift |

## New Files To Create

| File | Purpose |
|---|---|
| `EpistemosTests/ContextualShadowsEndToEndTests.swift` | State-level test for typing snapshot -> async recall -> result kind -> open command |
| `/tmp/epistemos_instant_recall_source_gate.log` | Shell source gate proving production rebuild uses async path and sync rebuild/indexBatch APIs are unavailable |

## FFI Changes

No broad FFI rewrite for V1. If the Rust retrieval result does not expose artifact kind, add the smallest compatible field to the existing result bridge. Do not introduce a new vector database or new transport.

## Swift Service Changes

- `ContextualShadowsState.requestRecall` remains the coordinator.
- V0 converts raw hits as notes because the backing index is note-only. Convert raw hits using index metadata once the backing index supports multiple artifact kinds.
- Cancel in-flight recall when the user keeps typing.
- Keep `minimumQueryLength` and top-K small.
- Return an explicit disabled/missing-index state instead of silent nothing when recall is unavailable.

## UI Changes

- Button label stays minimal, for example "Related".
- Panel tabs stay Notes and Chats, but Chats remains hidden when no real chat hits exist.
- Notes: hover preview and open note.
- Chats: open chat; summarize is contextual and can be hidden if the chat summary path is not stable.
- Do not add a permanent sidebar.
- Do not show the button while the user is not actively editing or when there are no hits.

## Performance Budget

| Path | Budget |
|---|---:|
| Typing debounce | 200 ms minimum |
| MainActor work after search | under 2 ms for top 5 |
| Search call after snapshot | under 10 ms p95 for current vault scale |
| Panel open | under 100 ms with cached result rows |
| Index rebuild | background only; never blocks typing or launch |

## Acceptance Criteria

- Typing in a note schedules recall without touching disk or running FFI in a SwiftUI body.
- Typing in chat schedules recall with cancellation on continued typing.
- Button appears only when there are current hits and the feature flag allows it.
- Panel opens and does not mislabel note-only hits as chats.
- Clicking a note hit opens the exact note.
- Clicking a chat hit opens the exact chat if chat recall is shipped; otherwise chat tab stays hidden.
- Missing index and disabled flag have explicit non-crashing behavior.
- Tests prove async state update and no stale hit reuse after cancellation.

## Manual Verification Steps

Manual checks are deferred per the user instruction, but these remain the eventual smoke gates:

1. Launch the app with a disposable vault.
2. Create two notes with overlapping concepts.
3. Type a related paragraph and wait for the recall button.
4. Open the panel and verify top result opens the expected note.
5. Type in chat and verify the chat-side panel either returns chat hits or hides the Chats tab honestly.
6. Restart and verify recall still works after index reload.
