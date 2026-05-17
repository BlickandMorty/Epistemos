# L-2 V6.2 Per-Bubble VRM Binding - User Decision Research

**Status:** COMPLETE_RESEARCH_READY
**Date:** 2026-05-16
**Terminal E scope:** user-decision preparation only; no production implementation.

## Problem Statement

The original L-2 research asked the user to choose how to bind an emitted `AnswerPacket` to the assistant `ChatMessage` that renders a per-bubble `VRMLabelView` chip. The old design offered two options:

- Option A: side-table sink with timestamp matching.
- Option B: pass `answerPacketId` through `AgentStreamEvent.complete`, emit the packet before yielding `.complete`, stamp the id onto `ChatMessage`, and let `MessageBubble` look up the packet by id.

Current main has moved past that question. Option B is already implemented in code: `AgentStreamEvent.complete` carries `answerPacketId`, `StreamingDelegate.onComplete` emits before yielding, `ChatCoordinator` threads the id to chat state, `ChatMessage` stores it, `LatestAnswerPacketSink` exposes a bounded lookup table, and `MessageBubble` renders `VRMLabelView` plus attention/bucket chips when the packet is still in the ring.

The user decision is no longer "Option A or B?" It is whether to ratify the current Option B implementation as the canonical V6.2 rendered-FULL path, require additional durability work before calling it complete, or roll back/reopen sign-off because implementation landed before the old research document was updated.

## Options

### Option A - Ratify current Option B and verify it

Accept the current code as the intended resolution of L-2. Keep `answerPacketId` on `.complete` and `ChatMessage`, keep emit-before-yield ordering, keep compact per-bubble chips, and require focused tests/source guards to stay green.

**Pros**
- Matches the architecture recommended by the original research.
- Eliminates the race described in that research.
- Current implementation is additive and backwards-compatible: legacy messages have nil `answerPacketId`.
- Current tests already cover ChatMessage Codable compatibility and the sink lookup path.
- Avoids churn from rolling back working audit-channel code.

**Cons**
- The old docs still contain stale "awaiting sign-off" language unless updated.
- Packet bodies live in the bounded 32-packet ring; older messages or app restarts can lose chip lookup until packet persistence lands.
- The implementation should still be verified on the current branch before closure.

### Option B - Ratify Option B but require packet-body persistence as the closure gate

Keep the current implementation, but do not mark L-2 fully closed until the actual `AnswerPacket` body is persisted alongside the message or session artifact, so scrollback and app restarts can render chips beyond the 32-packet in-memory ring.

**Pros**
- Stronger product behavior than the current first-rendering posture.
- Aligns with the original research's durability argument for exported `.epbundle` review.
- Avoids treating a ring-backed lookup as a permanent canonical surface.

**Cons**
- Turns a binding decision into a storage/schema follow-up.
- More implementation than needed to resolve the race.
- Should likely be a V1.1/canonical-product-surface follow-up, not a blocker for rendered-FULL.

### Option C - Roll back and reopen sign-off

Treat the current implementation as premature, remove or disable the Option B path, and wait for explicit user approval before re-landing it.

**Pros**
- Strictly honors the old research document's "no code change until sign-off" wording.
- Gives the user a chance to re-choose A/B before code remains canonical.

**Cons**
- Reintroduces churn around a solution that matches the research recommendation.
- Risks losing a working deterministic binding path.
- Does not improve architecture unless the user now rejects Option B.

### Option D - Replace with Option A side-table matching

Abandon `answerPacketId` threading and use "latest packet" / timestamp matching at message finalization.

**Pros**
- Smaller stream-event surface.
- Fewer cross-module payload changes.

**Cons**
- Reintroduces the race the original research was written to avoid.
- Mis-binding remains possible when completions arrive close together.
- Weak audit story for exported messages.

## Canonical Sources

### `docs/audits/V6_2_PER_BUBBLE_BINDING_RESEARCH_2026_05_12.md`

- Lines 1-6: frontmatter marks the research as `TWO_OPTIONS_RECOMMEND_OPTION_B`.
- Lines 10-21: original state said rendered-PARTIAL existed, rendered-FULL needed per-bubble binding, and no code change had landed yet.
- Lines 58-61 and 81-110: the race is the unstructured emit task versus synchronous `.complete` yield, so `ChatMessage.id` could bind to nil or a stale packet.
- Lines 135-182: Option B adds `answerPacketId` to `.complete`, emits before yield, stamps the id on `ChatMessage`, and resolves via recent packets or a sink.
- Lines 185-193: Option B's core benefit is zero race and per-turn id durability on the message.
- Lines 207-237: recommendation is to ship Option B; expected touch list is stream event, `onComplete`, `ChatMessage`, chat finalization, bubble render, and tests.
- Lines 239-252: old user questions about one-vs-two commits, compact chip default, and user-message chips. Current code effectively chose one implementation path, compact chips, assistant-message-only.

### `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md`

- Lines 290-300: §3.17 records AnswerPacket schema, Rust production caller, FFI, and `LatestAnswerPacketSink` + per-bubble `VRMLabelView` chip as landed, with state ladder still at rendered.
- Lines 873-873: Wave C9 still carries the stale "awaiting user sign-off" cross-link. This is historical doc drift against current code, not current implementation state.

### `docs/RESEARCH_COVERAGE_GAP_AUDIT_2026_05_15.md`

- Lines 201-204: PASS 1 L-2 records the old user-decision gate and notes the cross-link landed in Wave C. Its "FULL not yet implemented" statement is stale against current code.

### `Epistemos/Bridge/StreamingDelegate.swift`

- Lines 169-194: `AgentStreamEvent.complete` includes `answerPacketId: String?` and documents the Option B guarantee.
- Lines 595-635: `onComplete` builds the packet, awaits `AnswerPacketEmitter.shared.emit(packet)`, then yields `.complete(... answerPacketId: packet.id ...)`.

### `Epistemos/App/ChatCoordinator.swift`

- Lines 807-815: agent-chat completion threads `answerPacketId` into `agentChat.completeProcessing`.
- Lines 2927-2944: main chat completion threads `answerPacketId` into `chatState.completeProcessing`.

### `Epistemos/State/ChatState.swift` and `Epistemos/State/AgentChatState.swift`

- `ChatState.swift` lines 852-857: assistant message creation stamps the audit-channel packet id for `MessageBubble`.
- `AgentChatState.swift` lines 450-455: the agent-chat path does the same.

### `Epistemos/Models/ChatTypes.swift`

- Lines 281-292: `ChatMessage.answerPacketId` is documented as the V6.2 Option B binding field and nil for legacy/error/bypass paths.
- Lines 294-345: initializer accepts and stores the optional `answerPacketId`.

### `Epistemos/Engine/AnswerPacketEmitter.swift`, `Epistemos/Engine/LatestAnswerPacketSink.swift`, and `Epistemos/Views/Chat/MessageBubble.swift`

- `AnswerPacketEmitter.swift` lines 24-30: current state claims rendered-FULL: per-turn packet emit, packet id threading, and per-bubble chip render.
- `AnswerPacketEmitter.swift` lines 219-249: turn completion first tries the Rust producer path, then falls back to Swift stub and stamps the interrupt bucket.
- `LatestAnswerPacketSink.swift` lines 1-17: sink mirrors the recent packet ring and returns nil when packets age out, with packet persistence named as a follow-on.
- `LatestAnswerPacketSink.swift` lines 95-105: sink refreshes from the actor ring and provides O(1) lookup by id.
- `MessageBubble.swift` lines 452-490: `AnswerPacketChipRow` looks up `answerPacketId` and renders compact `VRMLabelView`, attention mode, and interrupt bucket chips.

### `EpistemosTests`

- `AnswerPacketCodableTests.swift` lines 94-154: `ChatMessage` round-trips non-nil `answerPacketId`, decodes legacy messages as nil, and omits nil as key-null.
- `LatestAnswerPacketSinkTests.swift` lines 24-166: sink starts empty, mirrors the actor ring, looks up by id, returns nil for evicted packets, refreshes via notification, and has idempotent start.

## Code Impact Estimate

### Option A - Ratify current Option B and verify it

Implementation now: docs and verification only.

Recommended checks:

- Run focused Swift tests for `AnswerPacketCodableTests` and `LatestAnswerPacketSinkTests`.
- Search `.complete` consumers to ensure all pattern matches handle `answerPacketId`.
- Record that `docs/audits/V6_2_PER_BUBBLE_BINDING_RESEARCH_2026_05_12.md` is now historical rather than pending.

Future doc cleanup:

- Update `MASTER_FUSION` Wave C9 or the next handoff to remove stale "awaiting sign-off" language.
- Keep a separate follow-up for packet-body persistence beyond the 32-packet ring.

### Option B - Ratify with packet persistence as closure gate

Estimated implementation: 150-600 LOC.

Likely files:

- `Epistemos/Models/ChatTypes.swift`
- `Epistemos/Engine/AnswerPacketEmitter.swift`
- `Epistemos/State/ChatState.swift`
- `Epistemos/State/AgentChatState.swift`
- `Epistemos/Views/Chat/MessageBubble.swift`
- Session export / `.epbundle` code if chips must survive export review.

Risks:

- Persisting full packets changes storage size and migration surface.
- Need a policy for redaction and packet retention.
- Should not be mixed into the already-landed binding path unless the user explicitly wants the stronger close gate.

### Option C - Roll back and reopen sign-off

Estimated implementation: 100-300 LOC to remove `answerPacketId` threading, sink lookup, bubble row, and tests.

Risks:

- Reopens the original race.
- Removes tests that now protect backwards-compatible schema behavior.
- Creates churn against code that matches the source research recommendation.

### Option D - Replace with Option A side-table matching

Estimated implementation: 80-250 LOC.

Risks:

- The result is intentionally weaker than current code.
- Timestamp/latest matching can mis-bind and is difficult to prove correct.
- Would need new tests demonstrating behavior under quick successive completions, but those tests would still be probabilistic if the design remains heuristic.

## Recommendation

Recommend **Option A: ratify the current Option B implementation and verify it**.

Recommended decision record:

> L-2 is no longer an A/B implementation decision. The branch already implements the recommended Option B path: emit-before-yield, `answerPacketId` on `.complete`, id stamping on `ChatMessage`, and id-based chip lookup in `MessageBubble`. Ratify this path as the V6.2 rendered-FULL binding. Treat packet-body persistence beyond the 32-packet ring as a separate canonical-product-surface follow-up.

Reasoning:

- The code matches the original research recommendation and removes the race.
- The old sign-off gate is stale; rolling back would reduce correctness.
- The remaining limitation is durability of the packet body, not per-turn binding.
- Focused tests already exist for the schema and sink behavior; rerunning them is the right closure check.

## Acceptance Criteria

If the user chooses **Option A**:

- Keep `AgentStreamEvent.complete(answerPacketId:)`.
- Keep `StreamingDelegate.onComplete` emit-before-yield ordering.
- Keep `ChatMessage.answerPacketId` optional and backward-compatible.
- Keep assistant-bubble-only chip rendering through `LatestAnswerPacketSink`.
- Run focused tests for `AnswerPacketCodableTests` and `LatestAnswerPacketSinkTests`.
- Verification note: Terminal E attempted those focused Xcode tests on 2026-05-16, but the run was build-blocked before test execution by missing generated input `build-rust/swift-bindings/omega_ax.swift`; rerun after the Rust binding generation issue is restored.
- Record packet-body persistence beyond the 32-packet ring as a separate follow-up, not a blocker for rendered-FULL.
- Update stale doctrine language in a later doc-cleanup slice or when the user asks for canonical doc reconciliation.

If the user chooses **Option B**:

- Keep current Option B code.
- Add packet-body persistence and migration tests before closing L-2.
- Define retention/redaction rules for persisted packets.

If the user chooses **Option C**:

- Roll back the Option B code as one explicit revert-style change.
- Restore the old user-signoff gate.
- Leave L-2 open until a new decision is made.

If the user chooses **Option D**:

- Remove deterministic `answerPacketId` threading.
- Add side-table matching tests and document the remaining heuristic risk.
- Do not claim audit-grade deterministic binding.

## Decision-Ready Prompt

Choose the L-2 V6.2 per-bubble VRM binding path:

1. **Recommended:** Ratify current Option B implementation, run focused tests, and treat packet-body persistence as a follow-up.
2. Keep Option B but require packet-body persistence before closing L-2.
3. Roll back the current implementation and reopen explicit user sign-off.
4. Replace Option B with timestamp/latest side-table matching, accepting weaker audit guarantees.
