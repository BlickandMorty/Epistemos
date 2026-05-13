---
state: research
created_on: 2026-05-12
scope: V6.2 — wire emitted AnswerPacket → message bubble (state: rendered FULL)
verdict: TWO_OPTIONS_RECOMMEND_OPTION_B
---

# V6.2 Per-Bubble VRMLabelView Binding — Architecture Research

The V6.2 audit channel is at `state: rendered (PARTIAL)` — the
diagnostics row shows live emitter state, but each chat message
bubble has no visible indication that its turn was audited.

The next ladder step (`state: rendered FULL`) is: render
`VRMLabelView` (plus an attention-mode + interrupt-bucket chip) on
each assistant message bubble. That requires binding the emitted
`AnswerPacket` to the corresponding `ChatMessage.id`.

This doc captures the binding seams, the race condition, and the
two architectural options. No code change yet — implementation is
queued behind explicit user sign-off.

## The two emit/finalize sites

### Site 1 — `StreamingDelegate.onComplete` (today's emit point)

`Epistemos/Bridge/StreamingDelegate.swift` lines ~454-485 (after the
2026-05-12 attention_mode + interruptBucket wiring):

```swift
func onComplete(stopReason: String, inputTokens: UInt32, outputTokens: UInt32) {
    Log.agentStreaming.emitEvent("delegate.complete", ...)
    let inTokens = Int(inputTokens)
    let outTokens = Int(outputTokens)
    Task {
        let attentionMode = await AnswerPacketEmitter.currentAttentionMode()
        let interruptBucket = InterruptScoreCpu.sampleTurnBucket(
            stopReason: stopReason,
            inputTokens: inTokens,
            outputTokens: outTokens
        )
        let packet = AnswerPacket.turnCompletionStub(
            stopReason: stopReason,
            inputTokens: inTokens,
            outputTokens: outTokens,
            attentionMode: attentionMode,
            interruptBucket: interruptBucket
        )
        await AnswerPacketEmitter.shared.emit(packet)
    }
    continuation.yield(
        .complete(stopReason: stopReason, ..., history: nil)
    )
    continuation.finish()
}
```

The packet is built + emitted INSIDE an unstructured `Task { … }`.
The `continuation.yield(.complete)` fires CONCURRENTLY — so the
`.complete` stream event may arrive at the consumer BEFORE the
`emit(packet)` await completes. **This is the race.**

### Site 2 — `ChatState.swift` ~line 808 (finalize site)

```swift
let assistantMessage = ChatMessage(
    id: messageId,            // ← THIS is what the bubble shows
    chatId: chatId,
    role: .assistant,
    content: answerText,
    ...
)
messages.append(assistantMessage)
eventBus?.emit(.queryCompleted(chatId: ChatId(chatId), messageId: MessageId(assistantMessage.id)))
```

This is where the `ChatMessage.id` (UUID, MainActor-isolated) is
established. It's the only place that knows both the new message id
AND that the turn is complete. **This is the binding site.**

## The race in concrete terms

Today's flow:

```
Rust agent_core finishes
   ↓
StreamingDelegate.onComplete (called from FFI)
   ├──► Task { … await emit(packet) }              [Task A: async]
   └──► continuation.yield(.complete(...))         [synchronous]

ChatCoordinator (consumes stream)
   ↓ receives .complete
   ↓ dispatches to ChatState (MainActor hop)
   ↓
ChatState.recordCompletedTurn(...)
   ↓
let assistantMessage = ChatMessage(id: messageId, ...)
messages.append(assistantMessage)
```

By the time `messages.append` runs, Task A may or may not have
finished. If we tried `AnswerPacketEmitter.shared.last` here, we'd
either:
- get the packet (Task A finished first — usually true on M-series
  Macs because actor hops are fast), OR
- get nil / a stale packet (Task A is still mid-flight).

Either way: **no deterministic binding between the new
`assistantMessage.id` and the packet that was just emitted for it**.

## Two architectural options

### Option A — Side-table sink with timestamp matching

Add `LatestAnswerPacketSink` (`@MainActor @Observable`) that
mirrors `AnswerPacketEmitter.shared.last`. ChatState reads from
it at finalize time and assumes "latest packet = this turn's
packet."

**Pros:**
- Minimal cross-cutting change (single new file + 1-line
  ChatState hook).
- AnswerPacket schema stays put.
- AgentStreamEvent enum stays put.

**Cons:**
- The race is still there. Heuristic mitigation: wait up to
  ~10 ms for the sink to update before binding. Probabilistic.
- Wrong if two assistant messages complete in quick succession
  (regenerate-then-resume pattern).
- The bubble's chip can briefly flicker to a wrong packet if the
  sink updates while the user is scrolling.

### Option B — Pass packetId through `AgentStreamEvent.complete` ✅ RECOMMENDED

Extend the stream-event case with the packet id, build the packet
+ emit it BEFORE yielding `.complete`:

```swift
// AgentStreamEvent.complete gains an answerPacketId field:
case complete(
    stopReason: String,
    inputTokens: Int,
    outputTokens: Int,
    answerPacketId: String?,    // NEW — nil if emit failed
    history: [[String: String]]?
)

// StreamingDelegate.onComplete becomes:
func onComplete(...) {
    Task {
        let mode = await AnswerPacketEmitter.currentAttentionMode()
        let bucket = InterruptScoreCpu.sampleTurnBucket(...)
        let packet = AnswerPacket.turnCompletionStub(
            ..., attentionMode: mode, interruptBucket: bucket
        )
        await AnswerPacketEmitter.shared.emit(packet)
        // packet.id is now committed in the ring before .complete fires
        continuation.yield(
            .complete(
                stopReason: stopReason,
                inputTokens: inTokens,
                outputTokens: outTokens,
                answerPacketId: packet.id,
                history: nil
            )
        )
        continuation.finish()
    }
}

// ChatState.recordCompletedTurn receives the id (already in the
// .complete event payload) and stamps it on the ChatMessage.

// ChatMessage gains an optional `answerPacketId: String?` field
// with Codable backward-compat (decodeIfPresent → nil).

// MessageBubble reads `message.answerPacketId` (if present) and
// looks up the packet via AnswerPacketEmitter.snapshot's recent
// packets list, OR via a small `LatestAnswerPacketSink` that holds
// the recent ring mirrored on MainActor.
```

**Pros:**
- Zero race. The packet id is committed BEFORE the stream event
  references it. By construction, `recentPackets()` contains the
  packet by the time the event arrives.
- Regenerate-then-resume works correctly — each turn has its own
  packet id in the message.
- The binding is durable: persisted with the ChatMessage. Scrollback
  through a session-restart preserves the chip (after Rust-side FFI
  threading lands the actual packet body too).

**Cons:**
- Touches more files:
  - `AgentStreamEvent.complete` payload (new field with backward-compat)
  - `StreamingDelegate.onComplete` (move packet build above yield)
  - Every `.complete` consumer (ChatCoordinator, the agent-bridge
    test fakes, ChatState) needs to ignore the new field or thread
    it through.
  - `ChatMessage.answerPacketId: String?` schema bump with
    Codable `decodeIfPresent`.
- One Task hop on the streaming completion path (already there;
  the `Task { await emit }` wraps the whole sequence now).

## Recommendation

**Ship Option B.** The race is unacceptable for an audit channel that
claims to bind a packet to a specific turn. Option A is faster to
ship but the bound packet is heuristic; an auditor reviewing a
ChatMessage exported as `.epbundle` would have no deterministic
way to verify which AnswerPacket the message corresponds to. Option B
gives the audit channel a hard contract.

The cross-cutting touch list is moderate but well-bounded:
1. `Epistemos/Bridge/StreamingDelegate.swift::AgentStreamEvent` —
   add `answerPacketId: String?` to `.complete`. ~4 consumers to
   audit (`ChatCoordinator`, agent-bridge tests, any internal fake).
2. `Epistemos/Bridge/StreamingDelegate.swift::onComplete` — move
   packet build above `continuation.yield`. ~10 LOC.
3. `Epistemos/Models/ChatTypes.swift::ChatMessage` — add
   `answerPacketId: String?` with Codable `decodeIfPresent`. ~6 LOC.
4. `Epistemos/State/ChatState.swift::recordCompletedTurn` (or
   wherever the .complete event lands) — thread `answerPacketId`
   from the event into the ChatMessage init. ~3 LOC.
5. `Epistemos/Views/Chat/MessageBubble.swift::assistantBubble` —
   render `VRMLabelView` + attention/bucket chips when
   `message.answerPacketId != nil`. ~15 LOC.
6. Test: round-trip a `ChatMessage` with `answerPacketId` through
   Codable. Verify a packet emitted at onComplete is referenced
   by id in the resulting `.complete` event.

Estimated effort: 1 focused commit (or 2 if we split schema bump
from UI render). Risk: low — every new field is optional + backward-
compat. The hardest part is auditing the `.complete` consumers for
ones that pattern-match the case shape.

## Open questions for the user

1. **Ship Option B as one commit or two?** Two commits would let
   the schema + binding land first (no UI impact), then the
   MessageBubble render second (visible). One commit ships the
   whole feature.
2. **Should `VRMLabelView` chip default to compact form?** Compact
   = single icon, full = icon + short label. The compact form is
   already implemented in `VRMLabelView.swift`. Per-bubble might
   want full so the user can scan modes quickly.
3. **Show the chips on user messages too?** Today the audit channel
   only tracks assistant turns. User messages have no packet. The
   chip should NOT render on user bubbles — which is the current
   default (the user-bubble path doesn't touch `assistantBubble`).
