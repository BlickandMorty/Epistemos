# Ambient Recall / Contextual Shadows — Wiring Plan

Date: 2026-04-25
Authority: PLAN_V2 §22 + EPISTEMOS-NORTH-STAR §"Instant Recall System" + research synthesis (claude work / gpt work / claude opt 2).
Premise: The substrate is real and fast. The UI is absent. This is the highest-leverage V1 differentiator if it can be wired without regressing typing fluency.

## 1. Current state (file-grounded)

- **Rust HNSW substrate**: `graph-engine/src/retrieval_index.rs:1-300+`
  - usearch HNSW: `HNSW_CONNECTIVITY=16`, `HNSW_EXPANSION_ADD=128`, `HNSW_EXPANSION_SEARCH=64` (`:11-13`).
  - `load()` reads manifest + embeddings + documents (`:56-104`); FxHashMap `page_rows` for O(1) lookups (`:93`).
  - `search()` adaptive request-count retry (`:159-173`); returns `Vec<PreparedRetrievalHit>`.
  - Bounds-checked; no unsafe.

- **Swift service**: `Epistemos/KnowledgeFusion/InstantRecallService.swift:1-294`
  - C-FFI: `instantRecallCreate`, `instantRecallInsert`, `instantRecallSearch`.
  - SLA: <3ms vault-wide; logs warning if >10ms (`:230`).
  - Metrics: `documentCount`, `lastSearchLatencyMs`, `averageSearchLatencyMs`, `maxSearchLatencyMs` (`:39-55`).
  - Async rebuild path: `rebuildIndexAsync(notes:)` uses `Self.rebuildSnapshot(handle:notes:)` `nonisolated static` (`:108`, `:267`).
  - Sync rebuild: `rebuildIndex(notes:)` at `:258` — still on @MainActor; risk surface.
  - AppBootstrap wires `snapshotInstantRecallNotes()` initial provider; NoteChatState hooks `indexCurrentNoteForInstantRecall()` on edit.

- **What's missing**:
  - No 200ms continuous-encoding debounce loop in editor.
  - No Contextual Shadows UI surface (panel, button, popover, sidebar).
  - No chat-side trigger (typing in chat composer should also surface related artifacts).
  - InstantRecallService is `@MainActor @Observable` (`:33`) — sync rebuild can stall.

- **Verdict**: Substrate WIRED. UI ABSENT. End-to-end product moment ABSENT.

## 2. Desired V1 product behavior

1. User types in a note or chat composer.
2. After 200ms of typing without keystroke, a **subtle recall button** appears in a corner of the composer (not a floating popup; not a sidebar that steals space).
3. Click → lightweight panel slides in (not modal; not full-width).
4. Panel has two tabs: **Notes** and **Chats**.
5. Notes tab: top-K (default 5) related notes, ranked by HNSW similarity. Hover preview (no disk read in body — uses preview cache). Click opens note in current vault context.
6. Chats tab: top-K related chats. Click opens chat. Right-click → "Summarize this".
7. Closing panel returns focus to composer.
8. **All recall work runs off MainActor.** Typing must remain 60fps (or 120fps on ProMotion).
9. **Indexing never blocks typing or app launch.** Background incremental encoding only.

## 3. Architecture

```
User types → debounce(200ms) → context snapshot (current paragraph + N around)
                              → off-MainActor encode (Model2Vec or local embedder)
                              → InstantRecallService.search(...) (HNSW, off-MainActor)
                              → results to ContextualShadowsState (@Observable, MainActor)
                              → ContextualShadowsButton appears (only if results exist)
                              → user click → ContextualShadowsPanel renders (Notes + Chats tabs)
                              → on close, results discarded; cache flushed
```

Hard rule: the encoder + HNSW search must be on a Task.detached or async-let chain, never on the @MainActor boundary. Cancellation on focus change (per gpt opt 2.md predictive section).

## 4. Files to modify (minimal surface)

| Action | File | Change |
|---|---|---|
| MODIFY | `Epistemos/KnowledgeFusion/InstantRecallService.swift` | Add `searchAsync(query: String, topK: Int = 5) async -> [RecallHit]`. Force `Task.detached(priority: .utility)`. Add `precondition(false, "Use rebuildIndexAsync")` to `rebuildIndex(notes:)` in DEBUG only. |
| MODIFY | `Epistemos/Views/Notes/ProseEditorRepresentable2.swift` | Add 200ms debounce hook on text change → triggers `ContextualShadowsState.requestRecall(snapshot:)`. Cancel in-flight task on each new keystroke. Off-MainActor everywhere except final state mutation. |
| MODIFY | `Epistemos/Views/Chat/ChatInputBar.swift` (or composer wherever messages are typed) | Same 200ms debounce hook on chat input. |
| MODIFY | `Epistemos/State/NoteChatState.swift` | Expose `noteBodyProvider` snapshot at 200ms cadence (already partially wired for AI streaming). |

## 5. New files to create

| File | Purpose |
|---|---|
| `Epistemos/State/ContextualShadowsState.swift` | `@Observable @MainActor` class. Owns `currentResults: [RecallHit]?`, `isVisible: Bool`, `pendingTask: Task<Void, Never>?`. Method `requestRecall(snapshot:in:)` runs off-MainActor query. |
| `Epistemos/Views/Recall/ContextualShadowsButton.swift` | Subtle SwiftUI button shown in composer corner when results exist. Animates in/out (gated by `reduceMotion`). |
| `Epistemos/Views/Recall/ContextualShadowsPanel.swift` | Lightweight panel with Notes + Chats tabs; consumes `ContextualShadowsState`. Uses preview cache for hover (no body disk read). |
| `Epistemos/KnowledgeFusion/RecallContextSnapshot.swift` | `@Sendable struct RecallContextSnapshot { let text: String; let kind: RecallContextKind; let originId: UUID }` to cross task boundary. |

## 6. FFI changes

None required. Existing `instantRecallSearch` C FFI is sufficient. Off-MainActor task wraps the synchronous FFI call.

## 7. Performance budget

- Debounce: 200ms (matches research recommendation; long enough to skip mid-word; short enough to feel ambient).
- Encode (Model2Vec or current local embedder): target <5ms p99 for a paragraph (~200 tokens).
- HNSW search: <3ms p99 vault-wide (current SLA per `InstantRecallService.swift:230`).
- Total: <50ms snapshot-to-results.
- Render of button + panel: must not steal a frame (use `TimelineView` only if results animate; otherwise plain SwiftUI).
- Backpressure: if encoder is busy, the new request supersedes the old (cancel + restart). Never queue.

## 8. Acceptance criteria

1. Type continuously in a note for 30 seconds at 5 chars/sec — typing latency must remain <16ms keystroke-to-glyph (signpost `editor.typing` p99).
2. Pause typing for 200ms+ → recall button appears within one frame.
3. Click button → panel renders within 100ms.
4. Top-5 related notes are visible; click opens correct note (verified by ID).
5. Chats tab shows top-5 related chats; click opens correct chat.
6. Right-click chat → "Summarize this" dispatches to existing chat summarize tool.
7. Close panel → results cleared from memory; no leaked tasks (verified by `Task.isCancelled` checks).
8. Vault import of 1000+ notes does not block typing or app launch. Use existing `rebuildIndexAsync` path.
9. Memory: no unbounded growth during 60-second continuous typing session.
10. No regression in any existing test suite.

## 9. Manual verification steps

1. Cold launch app on a vault with ≥100 notes.
2. Open a note. Begin typing a paragraph about a topic that exists in another note.
3. Pause 200ms. Verify recall button appears.
4. Click. Verify panel opens with related notes ranked by similarity.
5. Hover a result. Verify snippet preview appears without lag.
6. Click result. Verify correct note opens.
7. Open Activity Monitor. Verify no thread spike during typing.
8. Open Instruments → Time Profiler → filter `com.epistemos.bench`. Verify recall path runs off MainActor (no spans on main thread).

## 10. Risk register

- **R1 (HIGH)**: encoder choice. If we use a model that requires GPU, cold-start latency may spike. Default to Model2Vec (CPU, ~1ms/paragraph per North Star §"Instant Recall System").
- **R2 (HIGH)**: vault re-encode storm on import. Mitigated by `rebuildIndexAsync` and incremental encoding only.
- **R3 (MEDIUM)**: chat-side trigger may surface noise during quick acks. Mitigate by minimum 6-char query length.
- **R4 (MEDIUM)**: panel layout shift may feel jarring. Use slide-in from below at constant size; respect `reduceMotion`.
- **R5 (LOW)**: visible recall button may distract. Default OFF in Settings → Recall; user opts in.
  - Actually: default ON behind `EPISTEMOS_AMBIENT_RECALL_V0` flag; ship to TestFlight first.

## 11. Out of scope for V1

- Cross-vault recall.
- Screen-aware recall (Screen2AX → vault).
- Belief-drift cosine charts.
- R2F unlearning UI.
- Music + ambient context capture.

These are part of the larger North Star vision but DEFER. V1 is local recall on the current vault, surfaced through a subtle button.

## 12. Verdict

This is the canonical V1 differentiator. The substrate is ready. The wiring is small and self-contained. The risk is performance regression in the editor — and the entire architecture above is built to keep the recall path off MainActor. Ship under flag, default ON in TestFlight, gather telemetry, then default ON in MAS V1 if budgets hold.
