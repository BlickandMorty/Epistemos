# UI/UX Audit — Composer cloud-no-tools nudge + Prose reparse debounce

- **Auditor**: Codex T6 (codex/t6-uiux-2026-05-16)
- **Date**: 2026-05-17 (iter 10)
- **Driver**: §4.C — two functional commits from the 14-day window.
- **Trigger commits**:
  - `951a74c38` (2026-05-13) — *fix(composer): nudge
    cloud-no-tools providers to OpenAI on agent-intent*
  - `ca12083b3` (2026-05-15) — *fix(c4): prose reparse debounce
    machinery + 3-test source-guard (RCA4-P1-002)*
- **Verification mode**: Static. iter-1 env constraints unchanged.

## 1. Composer cloud-no-tools nudge (951a74c38)

`Epistemos/Views/Chat/ChatInputBar.swift:182-237` extends
`pillNeedsCloudWarning` from a single-case classifier (user on local +
intent needs cloud) to a two-case one:

- **Case (1)**: user on local model + intent needs cloud → nudge.
  (Unchanged behavior.)
- **Case (2)** (new): user on **cloud**, but the cloud provider
  doesn't publish a Claude/OpenAI-shaped tool-calling API (Google,
  Z.AI, Kimi, MiniMax, DeepSeek) + intent is `.agent` or `.research`
  → nudge to OpenAI.

The new helper `cloudSurfaceSupportsAgentTier` (lines 230-237) reads
the active provider's `supportsAgentTier` flag via
`InferenceState.CloudModelProvider`.

**Verdict**: textbook honest-capability-gating. Without this nudge,
agent-intent turns on Google/Z.AI/Kimi/MiniMax/DeepSeek silently fall
through to the toolless direct-stream path — guaranteed
hallucination ("I can't read your vault" or wrong refusal). The
nudge surfaces the constraint at composition time so the user can
switch providers before submitting.

**Strengths preserved**:

- Single banner action ("promote to OpenAI") covers both cases — UX
  uniformity.
- Honest disclosure comment at lines 182-200 names the five-provider
  set explicitly.
- `predictIntent` is reused (no duplicate intent logic).
- `chat.isAgentExecuting || isProcessing` guard at line 202 prevents
  the banner from flickering mid-turn.

### Findings

**P0/P1**: none.

**P2-1 — Five-provider denylist drifts when a new provider lands.**

The list of "no-agent-tier" providers is encoded inside
`CloudModelProvider.supportsAgentTier`. A new provider that doesn't
ship tool-calling will be invisible to this nudge until the flag is
flipped. Single source of truth is already the right pattern; just
worth recording for a follow-up review when a new provider integrates.

**P2-2 — Case (2) requires both predictIntent + provider gate.**

`predictIntent` is a heuristic NLP classifier. A false negative (the
classifier judges "rewrite this for me" as `.other` rather than
`.agent`) leaves a Google-user on Kimi without the nudge. Same root
classifier concern flagged in iter 9 P2-2.

**P3** — observation: the comment at lines 200-202 mentions
"falling through to the toolless direct-stream path" — verify in a
future iter that the Rust agent_loop actually gracefully degrades
(returns a structured "no-tools-on-this-provider" message) rather
than emitting a hallucinated tool-result. Out of T6's scope; for a
backend audit.

## 2. ProseTextView2 reparse debounce machinery (ca12083b3)

`Epistemos/Views/Notes/ProseTextView2.swift:423-471` adds an opt-in
debounce window for the per-keystroke reparse:

```swift
nonisolated(unsafe) var reparseDebounceWindow: TimeInterval = 0
private var pendingDebouncedReparse: DispatchWorkItem?

override func didChangeText() {
    super.didChangeText()
    if reparseDebounceWindow > 0 {
        pendingDebouncedReparse?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.reparseAndInvalidate() }
        pendingDebouncedReparse = work
        DispatchQueue.main.asyncAfter(deadline: .now() + reparseDebounceWindow, execute: work)
    } else {
        reparseAndInvalidate()
    }
    // ...activity tracking
}
```

**Verdict**: defensive opt-in optimization with the V1 UX preserved
by default (`window = 0` → synchronous reparse, identical to the
pre-§C.4 behavior). A future operator-profiling pass can flip the
window > 0 only for long-doc instances.

`EpistemosTests/LocalReparseDebounceTests.swift` (+46 LOC) is the
3-test source-guard mentioned in the commit subject: pins
default-zero behavior + debounce-coalesces-bursts invariant.

**Strengths preserved**:

- **Default-zero discipline**: no UX regression for the typical
  short-note case.
- **DispatchWorkItem cancel-and-re-arm** is the canonical
  type-burst-coalesce pattern.
- **`[weak self]` capture** prevents retain cycles on a delayed
  closure.
- **Activity tracker call** stays outside the if/else so notes-
  active heartbeats fire even when the reparse is deferred.
- **`nonisolated(unsafe)` annotation** on the setter is the right
  Swift 6 strict-concurrency answer for a class-level tunable that's
  only mutated from a single configurator.

### Findings

**P0/P1**: none.

**P2-1 — `DispatchQueue.main.asyncAfter` keeps the user-event main
queue loaded.**

For very long debounce windows (e.g., 500ms+), the scheduled work
sits in the main runloop queue. If the user navigates away mid-burst,
the closure fires anyway and calls `reparseAndInvalidate()` on a
potentially stale view. The `[weak self]` guard returns no-op if
`self` is gone, so the worst case is a no-op — no use-after-free
risk. Defensible.

- Consideration: instead of `DispatchWorkItem`, an
  `await Task.sleep(for: ...)` inside a `Task` with proper
  cancellation could express the cancel-on-retype more naturally.
  Stylistic, not P1.

**P3 — observation**: `pendingDebouncedReparse` is mutated only on
main (per `didChangeText` being called on main), so no @MainActor
isolation annotation is needed. The field is implicitly main-bound
via NSTextView's main-actor lifecycle.

## Action taken this iter

- Filed this audit doc.
- **No code edits.** Both commits are well-scoped fixes; carry-overs
  are stylistic / future-work.

## Carry-overs

- P2-1 (cloud nudge) — provider denylist drift when new providers
  land.
- P2-2 (cloud nudge) — same classifier-accuracy concern as iter 9.
- P2-1 (prose debounce) — `DispatchWorkItem` vs `Task.sleep`
  stylistic choice; defer.

## Iter 1-10 surface coverage update

Per-iter summary same as iter 9 plus:

| 10 | Composer cloud-no-tools nudge + Prose reparse debounce | this doc |
