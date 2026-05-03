# LocalAgent Reflex / EOF Completion Audit — 2026-05-03

> Read-only audit of `LocalAgentLoop.swift` reflex streaming and EOF/plaintext completion paths for AgentEvent lifecycle completeness (Gap-2 from PR45 inventory).
>
> Authority: `AGENTS.md` §8, `OMEGA_LOCALAGENT_AGENT_EVENT_INVENTORY_2026_05_03.md` §Gap-2, `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 7 (PR11).

---

## Files and Line Ranges Inspected

| File | Lines | What was read |
|---|---|---|
| `Epistemos/LocalAgent/LocalAgentLoop.swift` | 519–657 | `runReflexTurn` — streaming loop, EOF flush, reflex detection, fallback parse, repair paths |
| `Epistemos/LocalAgent/LocalAgentLoop.swift` | 587–592 | EOF flush call site (`detector.flushOnStreamEnd()`) |
| `Epistemos/LocalAgent/LocalAgentLoop.swift` | 1021–1062 | `executeToolCalls` and `executeToolCall` — the only AgentEvent emission site for local tool execution |
| `Epistemos/LocalAgent/LocalAgentLoop.swift` | 1070–1100 | `recordLocalAgentToolEvent` helper and `resolvedAgentProvenanceRecorder` |
| `Epistemos/LocalAgent/IncrementalToolCallDetector.swift` | 110–126 | `flushOnStreamEnd()` — returns plaintext, does not produce tool-call detections |

---

## Evidence Quotes (exact, ≤25 words)

1. `flushOnStreamEnd() -> String { guard !buffer.isEmpty else { return "" }` — detector returns `String`, never `Detection?`.
2. `// Stream EOF without a tool-call detection: the detector may` — comment confirming EOF flush is for plaintext only.
3. `let result = await toolExecutor(call.name, call.argumentsJson)` — single suspension point inside `executeToolCall`.
4. `await recordLocalAgentToolEvent(... kind: .toolCallRequested, status: .requested)` — first event in `executeToolCall`.
5. `await recordLocalAgentToolEvent(... kind: result.isError ? .toolCallFailed : .toolCallCompleted` — terminal event always follows.
6. `private func executeToolCall(_ call: ParsedToolCall, runID: String) async -> LocalToolResult` — function is non-throwing with zero early returns.
7. `if let detection = reflexDetection { ... let result = await executeToolCall(toolCall, runID: runID)` — reflex path always routes into `executeToolCall`.
8. `let toolResults = await executeToolCalls(toolCalls, runID: runID)` — fallback-parse path routes into `executeToolCall`.

---

## Verdict: **closed**

### Reasoning

1. **Only one emission site.** `recordLocalAgentToolEvent` is called exclusively from `executeToolCall` (lines 1034, 1041, 1051). No other function in `LocalAgentLoop.swift` emits AgentEvents for tool execution.

2. **Zero early exits.** `executeToolCall` is non-throwing, has no `guard` returns, no `if` early returns, and no nested `try`. After emitting `.requested` (line 1034) and `.started` (line 1041), it always reaches the terminal emission at line 1051 (`.completed` or `.failed`) before returning.

3. **EOF flush does not create tool calls.** `flushOnStreamEnd()` returns `String` plaintext (or empty). It cannot return a `Detection`, so the EOF path (lines 587–592) never produces a tool call and therefore never emits a `requested` event.

4. **Fallback parse is fully covered.** If the incremental detector misses a tool call that straddles the EOF boundary, the fallback `parseToolCalls(from: output)` at line 660 may find it. Any found tool calls are executed via `executeToolCalls` → `executeToolCall`, which emits the full lifecycle.

5. **Repair paths are safe.** When `reflexDetection` or `fallbackParse` yields an invalid tool call that triggers a repair prompt (lines 599–628, 836–861), the function returns `nil` *before* reaching `executeToolCall`. No `requested` event is emitted for a tool call that is never executed.

6. **Cancellation does not create a gap.** `executeToolCall` is not `throws`. If the containing Task is cancelled while suspended at `toolExecutor`, the suspension resumes (the callee also cancels) and the terminal event is still emitted with the error result.

---

## If This Were Open (hypothetical follow-up)

> This section is included because the PR45 inventory requested it, but the audit found **no gap**.

- **Smallest safe future PR slice:** patch `executeToolCall` to add a `defer` or `do/catch` guard around the tool-execution suspension if a future refactor introduces throwing or early-return paths.
- **Allowed files:** `Epistemos/LocalAgent/LocalAgentLoop.swift` (single-function patch), `EpistemosTests/LocalAgentReflexEOFCompletionTests.swift` (NEW).
- **Forbidden files:** all Bridge files, all canon-in-flight docs, `ProseEditor*`, `MetalGraphView.swift`, `HologramController.swift`, graph internals, project/package files.
- **Focused test name:** `EpistemosTests/LocalAgentReflexEOFCompletionTests` — assert that every `.requested` row in the EventStore `agent_events` table has a matching `.completed` or `.failed` row for the same `toolCallID` after a synthetic reflex turn.

---

## Usefulness

**+1**

This read-only audit resolves the PR45 Gap-2 candidate with source evidence. It confirms PR11 (LocalAgentLoop tool execution provenance) is complete for the reflex/EOF path and prevents a future agent from opening an unnecessary code slice.
