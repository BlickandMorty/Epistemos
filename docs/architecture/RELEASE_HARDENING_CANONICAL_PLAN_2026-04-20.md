# Epistemos Release Hardening — Canonical Plan

Date: 2026-04-20
Branch baseline: `codex/runtime-input-audit`
Status: Canonical plan for remaining release-hardening work

This document is the release-hardening source of truth.

Use this plan when deciding:
- what is actually broken
- which research conclusions are accepted vs rejected
- what order the remaining work should happen in
- what must be verified before calling the app release-ready

Relationship to existing docs:
- `docs/architecture/MASTER_PLAN_2026-04-19.md` remains the broad historical sprint log.
- `docs/AGENT_PROGRESS.md` remains the running status ledger.
- `docs/handoffs/2026-04-20-claude-to-codex-verification.md` is the audit trail for Claude's `da06929e` batch.
- This file is the tighter operational plan for finishing release blockers cleanly.

Do not treat older research notes or handoffs as authoritative if they conflict with this document.

---

## 1 · Canonical Findings

These are the findings that should drive implementation. Each one is either verified directly in the tree or accepted after cross-checking multiple research inputs.

### 1.1 Silent-answer failures are primarily a post-processing bug

Primary hotspot:
- `Epistemos/Engine/Extensions.swift`

Canonical conclusion:
- The biggest cross-model "it thinks and then says nothing" failure is not the think-tag parser.
- The real problem is the user-facing output cleanup layer being too willing to classify normal answer prose as reasoning and collapse to an empty visible answer.

Accepted implications:
- `ThinkTagStreamRouter` is fundamentally the right primitive and should stay.
- `UserFacingModelOutput` must fail open when it cannot confidently split reasoning from answer text.
- Heuristic stripping should be a narrow fallback, not the primary answer pipeline.

### 1.2 Local freezing is fundamentally an actor/lifecycle problem

Primary hotspots:
- `Epistemos/KnowledgeFusion/MLXInferenceBridge.swift`
- `Epistemos/LocalAgent/LocalAgentLoop.swift`

Canonical conclusion:
- Local inference still touches `@MainActor` in the wrong places.
- The real long-term fix is not detached tasks around main-thread code; it is a dedicated inference actor and a stricter model supervisor.

Accepted implications:
- UI state must stay on `@MainActor`.
- Model load/generate/unload must not.
- Token generation and matmul paths must never hop through `MainActor.run` in the hot loop.

### 1.3 Local model safety is a runtime-policy gap, not just a picker problem

Primary hotspots:
- `Epistemos/Engine/MLXInferenceService.swift`
- `Epistemos/State/InferenceState.swift`
- `Epistemos/App/EpistemosApp.swift`

Canonical conclusion:
- The app already has memory-pressure observation at the app shell.
- The missing piece is unified runtime policy: admission control before load, one-active-model discipline, eviction on pressure, and explicit refusal instead of swap death.

Accepted implications:
- Do not merely hide big models from the picker and call it fixed.
- The user must get an honest "this model cannot load safely on this machine right now" error.
- The memory-pressure listener should eventually feed one model supervisor instead of scattered logging/ad hoc reactions.

### 1.4 FFI multi-turn continuity is the biggest engine-level win still missing

Primary hotspots:
- `agent_core/src/bridge.rs`
- `agent_core/src/agent_loop.rs`
- `agent_core/src/context_loader.rs`

Canonical conclusion:
- Swift already holds the conversation.
- Rust still starts fresh each session call.
- Flattening prior turns into XML system context is not a substitute for a true multi-turn message array.

Accepted implications:
- Native prior-message support remains a P1 architectural task.
- Tool-call continuity, prompt caching, and thinking-signature preservation all improve once the FFI becomes natively conversational.

### 1.5 The current thinking UI is serviceable but not the right end-state

Primary hotspots:
- `Epistemos/Views/Chat/ThinkingPopoverView.swift`
- `Epistemos/Views/Chat/MessageBubble.swift`

Canonical conclusion:
- Detached popover thinking is not aligned with the user request or current best-in-class UX.
- The correct target is an inline, in-bubble reasoning panel that auto-expands while thinking and auto-collapses on first answer token.

Accepted implications:
- This is a real product requirement, not polish.
- It is still secondary to correctness and runtime safety.

### 1.6 The context panel has good bones but is not yet a live X-Ray

Primary hotspot:
- `Epistemos/Views/Chat/ChatView.swift` (`ChatBrainPanelView`)

Canonical conclusion:
- The current panel is a snapshot of routing/context state, not a live inspector of what the model is actively seeing.

Accepted implications:
- The next-level version should show live mounts, retrieval pulse, reconciled token counts, and per-turn provenance.
- This is important, but not a release blocker ahead of correctness and runtime safety.

### 1.7 Send-path latency is still doing too much before the user feels acknowledged

Primary hotspot:
- `Epistemos/App/ChatCoordinator.swift`

Canonical conclusion:
- The app still performs expensive retrieval/workspace preparation before the turn visibly settles.
- The right product behavior is acknowledge first, enrich second.

Accepted implications:
- Route cheaply.
- Create the pending assistant turn immediately.
- Push expensive retrieval/context building into concurrent enrichment wherever correctness allows.

### 1.8 Generated project truth is non-negotiable

Primary hotspot:
- `project.yml`

Canonical conclusion:
- The project spec must remain the source of truth.
- `Epistemos.xcodeproj/project.pbxproj` should be treated as generated output, not hand-maintained state.

Accepted implications:
- Run `xcodegen generate` whenever membership changes matter.
- Prefer CI or a verification step that catches drift.

---

## 2 · Accepted, Rejected, and Deferred Advice

### 2.1 Accepted

- Narrow the visible-output reasoning heuristics and fail open.
- Move toward a dedicated inference actor.
- Add or preserve memory admission control and pressure-driven runtime policy.
- Defer synchronous bootstrap/send-path work out of the first interactive path.
- Keep `ThinkTagStreamRouter`.
- Use generated project flow via `project.yml` + `xcodegen`.
- Treat native multi-turn FFI as a real architectural priority.

### 2.2 Rejected

- Replacing the thinking surface with `DisclosureGroup`.
  Reason:
  - poor fit for streaming, growing text
  - eager content behavior
  - higher layout invalidation risk on macOS SwiftUI surfaces

- Deleting the overseer/router because it "must be the RAM problem."
  Reason:
  - the heuristic planner is not the main memory sink
  - resident model lifecycle is the bigger issue

- Parsing or displaying raw OpenAI chain-of-thought by default.
  Reason:
  - summary-safe reasoning streams are the right user-facing contract

### 2.3 Deferred

- Full FFI multi-turn lift
- Inline thinking accordion
- Live context X-Ray overhaul
- Cmd+K model palette
- Unified single model supervisor consuming all pressure signals
- Broad isolation cleanup beyond the inference path

Deferred does not mean unimportant. It means "not ahead of correctness + runtime safety + launch-path responsiveness."

---

## 3 · Official Execution Order

This is the order that should be followed unless fresh evidence forces a reprioritization.

### Phase 0 — Finish and verify the current blocker batch

Goal:
- close the current 11/12-file blocker batch cleanly
- get trustworthy focused test signal
- do not widen scope

Why first:
- it already contains fixes for silent endings, answer salvage, bootstrap deferral, and memory guard work
- it is the narrowest path to immediate user-visible relief

Exit criteria:
- focused build/test signal is trustworthy
- launched app confirms the core symptom no longer reproduces
- batch is committed alone

### Phase 1 — Runtime safety and responsiveness

Goal:
- remove the major freeze/crash classes without a large UX rewrite

Work includes:
- local model admission control and refusal path
- pressure-driven eviction/degradation policy
- inference off `@MainActor`
- remaining synchronous bootstrap/send-path deferrals
- cloud reasoning budget/continuation hardening where needed

Exit criteria:
- local oversized models refuse safely
- local thinking no longer freezes the UI
- send path acknowledges quickly
- foreground tap no longer stalls on startup registry/model prep

### Phase 2 — Streaming correctness and visible trust

Goal:
- make the assistant visibly coherent and never silently disappear

Work includes:
- inline thinking panel
- always-terminal assistant state machine
- structured tool progress cards
- reasoning-summary routing polish per provider

Exit criteria:
- thinking stays in a dedicated panel tied to the message
- answer always appears or a typed error is shown
- tool use never feels like dead air

### Phase 3 — Engine continuity and transparency

Goal:
- make the backend truly conversational and the frontend truly inspectable

Work includes:
- FFI multi-turn
- prompt-cache instrumentation
- richer context X-Ray
- per-turn provenance / "why this model" / cache indicators

Exit criteria:
- prompt cache is meaningfully active on multi-turn chats
- tool continuity survives across turns
- the user can inspect what the model saw and why it was routed that way

---

## 4 · Official Engineering Principles

These should govern the remaining implementation work.

### 4.1 Structure beats heuristics

If a provider or local parser already emitted:
- reasoning
- answer
- tool start
- tool result
- terminal state

then downstream layers should render that structure directly instead of re-guessing from plain text.

### 4.2 A turn must always end in a terminal state

Every chat turn must finish as one of:
- final answer
- explicit refusal
- recoverable typed error
- partial salvage with honest message

Never:
- vanish silently
- stop after reasoning with no answer and no explanation
- leave the chat stuck in "streaming" with no terminal state

### 4.3 One active local model unless and until the supervisor is smarter

Until a richer residency manager exists:
- keep one active local model
- evict or unload before loading another
- do not try to keep a fleet of local models warm

### 4.4 Acknowledge first, enrich second

The app should:
- create the pending assistant turn immediately
- route cheaply
- enrich with retrieval/workspace context concurrently when possible

Users perceive responsiveness by first visible motion, not by invisible precomputation.

### 4.5 Generated artifacts are disposable

The repo truth lives in:
- source files
- `project.yml`
- reproducible generators

Not in manually curated IDE output.

---

## 5 · Official Non-Goals For This Release Pass

Do not let these distract the remaining release-hardening work:

- broad UI redesign unrelated to reasoning/context/tool visibility
- deleting the overseer on performance superstition alone
- speculative rewrites of working subsystems because another app does it differently
- hand-curating the Xcode project
- mixing large architecture work into narrow blocker commits

---

## 6 · Verification Gates

No release-ready claim should happen without these.

### 6.1 Focused code/test verification

Must-have:
- targeted focused suites for the current blocker batch
- clean build on current branch state
- no fake "green" from empty filtered runs

### 6.2 Live app verification

Must-have:
- a cloud reasoning turn that previously disappeared now yields a real final answer
- a local reasoning turn yields an answer without freezing the UI into uselessness
- oversized local model selection refuses or degrades honestly instead of freezing the machine
- thinking is kept out of the main answer lane

### 6.3 Build/project verification

Must-have:
- if project membership changes, regenerate from `project.yml`
- confirm generated project output is stable

### 6.4 Documentation verification

Must-have:
- `MASTER_PLAN_2026-04-19.md` can stay broad/history-oriented
- `AGENT_PROGRESS.md` must reflect real open blockers, not optimistic assumptions
- this file should be updated when canonical conclusions change

---

## 7 · Current Canonical Open Blockers

As of this document, the remaining blockers to treat as real are:

1. Silent/empty final answers still require live confirmation after recent fixes
2. Local inference still needs the actor/lifecycle fix for real freeze relief
3. Large local model safety needs a unified runtime policy, not just picker hiding
4. Bootstrap/send-path responsiveness still needs more deferral and concurrency
5. Inline thinking UX is still not in the form the user asked for
6. FFI multi-turn continuity is still missing
7. Generated-project discipline still needs to be enforced as process, not preference

---

## 8 · The Canonical One-Paragraph Summary

Epistemos does not need a ground-up rebuild. It needs a disciplined hardening pass around six boundaries: answer extraction, local inference isolation, model admission/eviction policy, terminal stream state, native multi-turn backend continuity, and generated-project hygiene. The right near-term strategy is to finish and verify the current blocker batch, then remove local inference from `@MainActor`, unify model safety policy, and only after that move into the inline-thinking and FFI multi-turn upgrades that make the app feel fully alive.
