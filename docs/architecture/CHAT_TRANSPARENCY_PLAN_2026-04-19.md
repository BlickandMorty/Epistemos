# Unified Chat Transparency Plan

**Date:** 2026-04-19
**Branch where tonight's fixes landed:** `codex/runtime-input-audit`
**Author:** Claude audit pass (follow-up to the Codex handoff 2026-04-18)

Tonight's commits fixed four concrete regressions; this doc captures the
deeper cleanup that emerged from the audit. Everything below is a proposal,
not landed code. Land items in the order listed — each batch is independently
shippable and tested.

---

## What's already done (tonight)

| Batch | SHA | Scope |
|-------|-----|-------|
| A | `254312cd` | Routing UX: explicit stack popover, Settings ↔ picker sync, Codex GPT-5.4 preservation |
| B | `18664605` | Codex backend no longer receives GPT-5 native controls (typo-heavy prose fix) + spelling-hint system prompt |
| C | `06cc013e` | Agent path now routes `.thinkingDelta` into `AgentChatState`; thinking popover state no longer dropped |
| D | `9cf31cf7` | `ChatState` / `AgentChatState` `completeProcessing` surface empty streams as real errors instead of ghost bubbles |
| G | `526b7279` | Main-chat thinking lifecycle regression tests mirroring the Agent coverage |
| H | `98897428` | QwQ 32B flagship reasoner added to the catalog (Perplexity-style cascade: flagship local thinking model now leads `.thinking` preferredOrder on 24GB+ Macs) |
| I | `5ddd6db9` | `ChatMessage.resolvedModelLabel` + `InferenceState.effectiveModelLabel(for:)` helper — data layer for the Perplexity #1 transparency pattern |
| J | `cfad9a99` | `EffectiveModelBadge` rendered under every assistant reply — **P1 #1 complete: routing is now visible** |

Runtime/model batch (Codex pre-staged) remains in the index, separate, untouched.

---

## What the audit + research said about the "black box" feel

Two parallel streams ran while the regressions were landing:
1. Internal audit (Explore agent over all chat paths) — 15 ranked issues with `file:line` evidence.
2. External research (general-purpose agent, primary-source web) — patterns Perplexity, Cursor, Continue.dev, Obsidian Copilot, NotebookLM, Aider, Claude Code, Goose actually ship.

The convergent finding: Epistemos' engineering is sound; the opacity is almost entirely *visibility* — what the user can see about routing, context, and errors — not broken plumbing.

Key research sources (full links in the followups below):
- [Perplexity case study (LangChain)](https://www.langchain.com/breakoutagents/perplexity)
- [Anthropic — Building Effective Agents](https://www.anthropic.com/research/building-effective-agents)
- [Cursor Plan Mode](https://cursor.com/blog/plan-mode)
- [Continue.dev context providers](https://docs.continue.dev/customize/custom-providers)
- [Obsidian Copilot releases](https://github.com/logancyang/obsidian-copilot/releases)
- [Vercel AI SDK error handling](https://ai-sdk.dev/docs/ai-sdk-ui/error-handling)
- [NN/G — Explainable AI in chat interfaces](https://www.nngroup.com/articles/explainable-ai/)

---

## Follow-up backlog — ranked

Severity tiers:
- **P1** = user-visible regression or trust-critical; land next.
- **P2** = high impact, clear design, needs one batch of careful work.
- **P3** = worth doing when the surrounding surface is touched anyway.

Each item states scope, files, test plan, and risk.

### ✅ P1 — Effective-model badge on every assistant message — SHIPPED 2026-04-19

**Landed** as Batch I (`5ddd6db9`, data layer) + Batch J (`cfad9a99`, UI).
`ChatMessage.resolvedModelLabel: String?` is populated at turn completion
from `InferenceState.effectiveModelLabel(for:)`, which resolves Apple →
`"Apple Intelligence"`, local → the local model's displayName, cloud →
`"<Provider> <Model>"`. `EffectiveModelBadge` renders a subtle sparkle-
pill under every assistant reply. Non-interactive in v1 — the click-
through "why this model?" rationale is tracked below as the next P2
item (reuses the same badge as the anchor).

### P1 — Toggleable Brain / Context side panel (stable affordance)

**Why:** `latestBrainSnapshot` already exists (per audit) but the panel is only reachable through a hidden toggle. The user explicitly asked for a "brain of the app" side panel showing loaded context, ambient retrieval, and tool outputs. Research: NotebookLM's Sources panel and Continue.dev's composer pills are the two proven patterns.

**Scope:** two-part landing.
1. Composer-footer pills (Continue.dev model). Every auto-retrieved note + every `@`-mention becomes a removable chip in the composer BEFORE submit. No hidden context. Renders `ChatBrainSnapshot.sections` as live chips.
2. Right-side Context Panel (NotebookLM model). Per-source checkbox. Shows the exact notes/tools that went into the last turn. Clickable rows preview the content. Drag-to-insert as wikilink into the active note (Obsidian Copilot's killer affordance).

**Files touched:** new `ChatContextPanel.swift` + edits to `ChatInputBar.swift` and `ChatView.swift`. **Risk:** moderate — SwiftUI layout for the right sidebar needs to play nicely with the existing hologram/inspector panels.
**Test plan:** assert panel reflects the latest `ChatBrainSnapshot` on every turn change; assert composer pills match the attachments array; assert checkbox toggles filter the snapshot before submit.

### P1 — Tool failure vs. model refusal vs. provider error (typed error surfaces)

**Why:** Issue #4 (ghost reply) is fixed, but the complementary failure — "something broke and the user doesn't know what" — is still generic. Research is unanimous: Vercel AI SDK treats errors as stream parts with typed shapes. We should too.

**Scope:**
- Enumerate the error categories: `.authFailure(provider)`, `.rateLimited(provider, retryAfter)`, `.providerUnreachable(provider)`, `.contentPolicy(provider)`, `.toolFailure(toolName, reason)`, `.cancelled`, `.unknown(String)`.
- Map raw provider errors into this enum inside the existing `UserFacingChatError` helper.
- Render each with a dedicated affordance: 401 → "Open Keychain settings" deep link; 429 → visible countdown + "switch to local" button; tool failure → inline under the tool card (distinct from model error).
- Content-policy refusal: render as regular model output with a badge, not as an error (Anthropic's recommendation).

**Files touched:** `Engine/UserFacingChatError.swift` (or equivalent), chat error views, maybe one new `ErrorMessageBubble` view. **Risk:** low once enum is defined. **Test plan:** one unit test per category, plus a snapshot test per visual.

### P2 — "Why this model?" rationale card

**Why:** When the router downgrades a turn from Pro → Fast or escalates local → cloud (audit's Issue #7), the user sees the outcome with no explanation. Research: NN/G's Explainable AI piece shows the fix is a small, expandable rationale — one sentence, with the decision factor cited.

**Scope:**
- Add `routingDecisionReason: String?` field on `ChatMessage` (populated by the resolved routing path; empty for Apple / explicit cloud selections).
- Small text under the effective-model badge ("Auto-promoted to Agent — task classified as multi-tool") that expands on click.
- Surface is optional — only shown when the decision differed from the user's direct pick.

**Files touched:** `ChatMessage`, `MessageBubble`, one text helper. **Risk:** low. **Test plan:** assert reason text is captured when the router promotes/demotes; assert it's empty when the user's pick was used as-is.

### P2 — Model role assignment (explicit taxonomy)

**Why:** The audit's Issue #14 — roles like overseer, fast-local, reasoning-local, cloud-reasoner, cloud-agent, research are implicit in code flow. The Codex handoff already shipped `ModelCapabilityRole` (enum). This phase makes it the single source of truth.

**Scope:**
- Audit `TriageService.preferredOrder`, `ConfidenceRouter`, `LocalAgentLoop`, and `CommandCenterRequestCompiler` for hardcoded model choices. Replace each with a `role: ModelCapabilityRole` lookup on `InferenceState.resolveModel(for role:, budget:)`.
- Expose the role map in Settings → Inference so the user can override per-role: "What should Fast Local be?" / "What should Cloud Reasoner be?"
- Auto-router decisions become: choose role → resolve role to model → run.

**Files touched:** ~4 services + Settings view + new test file. **Risk:** medium — easy to miss a hardcoded model reference. Use `git grep` for each model enum value before declaring done.
**Test plan:** one test per role resolution; one end-to-end test that asserts a role-override in Settings flows through to the dispatched model.

### P2 — Minimal note tool surface (chat "just read and write notes")

**Why:** The user's own phrasing. Research converges on Claude Code's minimal set (read/write/edit/search/list). For a PKM, add link/tag/rename because they're load-bearing. Everything else becomes a skill (Goose Recipe model).

**Scope:**
- Publish eight tools uniformly across main / note / mini / graph chat, wired through the existing MCP bridge: `read_note`, `write_note`, `edit_note` (diff), `search_notes`, `list_notes`, `link_notes`, `set_tags`, `rename_note`.
- Scope tool permissions per mode (Roo Code pattern): Research mode = read-only. Edit mode = write. Agent mode = everything.
- Action Audit & Undo log per chat (Smashing pattern) for anything that mutates the vault — non-negotiable for a PKM where the content is the user's brain.

**Files touched:** `Engine/AgentHarness/*`, `agent_core/src/tools/*.rs`, new `VaultActionLog` persistence + view. **Risk:** largest batch in this plan — hits Rust tool layer. Land tools first, audit log second, UI third.
**Test plan:** integration tests per tool via MCP; audit log test for create/edit/delete/rename roundtrips.

### P2 — Consolidate the three routers

**Why:** Audit confirmed the architecture diagnosis from the earlier brainstorm — `ConfidenceRouter.swift`, `agent_core/src/routing.rs`, and `epistemos-core/src/agent_runtime/routing.rs` all exist with overlapping responsibilities. Tonight's Batch A made the Swift side consistent; the Rust side still has two parallel routers.

**Scope:**
- Decide canon: `agent_core/src/routing.rs` (complexity-scored heuristics) or `epistemos-core/src/agent_runtime/routing.rs` (keyword + intent).
- Migrate the loser's logic into the winner; delete the dead file.
- Make Swift's `ConfidenceRouter` a pure classifier that feeds the Rust router — not a parallel decider.

**Files touched:** Rust agent_core + epistemos-core, Swift ConfidenceRouter. **Risk:** highest — this is the load-bearing router. Land behind a feature flag for one release cycle before removing the legacy path.
**Test plan:** replay 50+ sample queries through both routers; assert same decision within a small tolerance; ship flag off until samples converge.

### P3 — Streaming display policy as a user setting

**Why:** Audit's Issue #15. Currently `ChatStreamingDisplayPolicy.showsLiveResponseText = true` is a constant. Power users may want a "finalize before showing" mode for focus.

**Scope:** one Settings toggle + one line in the policy.
**Risk:** trivial. **Test plan:** one UserDefaults persistence test.

### P3 — Vault cache invalidation on sidebar edits

**Why:** Audit's Issue #11. `KnowledgeIndexBuilder` caches 30s; if a note is edited in another panel during that window the chat sees stale content.

**Scope:** wire the vault-sync notification to `invalidateCache()` and emit a `.contextRefreshed` event to `ChatState`.
**Risk:** low. **Test plan:** integration test that edits a note, fires the notification, and asserts the next context build sees the new content.

### P3 — Tests for thinking lifecycle and streaming edge cases

**Why:** Audit's Issue #12 surfaced the lack of explicit coverage. Tonight's Batch C added thinking lifecycle tests for `AgentChatState` — the main `ChatState` equivalent still has partial coverage.

**Scope:** mirror the four `AgentChatStateTests` thinking cases into `ChatStateStreamingTests.swift`; add cancellation-mid-stream and network-timeout tests for both surfaces.
**Risk:** trivial. **Test plan:** the tests themselves.

---

## What I explicitly rejected from the audit

- **Issue #8 — Streaming indicator stuck after errors.** On inspection `PipelineService.failActiveRunIfNeeded` already synchronously flips `pipelineState.isProcessing = false` before yielding `.error`, and `ChatState.addErrorMessage` flips `isStreaming = false` in the same frame. No reproducible hang. If the user sees a lingering spinner in practice, it's likely a macOS 26 redraw artifact, not a logic bug — investigate with Instruments, not code changes.
- **Issue #9 — Tool permissions not reflected in `ChatBrainSnapshot` mid-stream.** True but low-impact. Mid-stream permission changes are rare. Revisit if we add a "pause to edit permissions" UX.
- **Issue #13 — Error messages differ across surfaces.** Unifying them is scope-creep for this pass; the typed error enum (P1 above) will naturally converge copy as a side effect.

---

## Commit sequencing recommendation

Order items to maximise reviewability:
1. **P1 — Typed error enum** (foundation for the badge's "why this model" click-through).
2. **P1 — Effective-model badge** (on top of the enum; highest user-visible payoff).
3. **P1 — Context panel (composer pills first, right sidebar second)**.
4. **P2 — Model role taxonomy** (enables role-override UI, sets up for #5).
5. **P2 — Minimal note tool surface + audit log**.
6. **P2 — Router consolidation** (behind a flag; ship flag off).
7. **P3 sweep** last, when context is available.

This interleaves UI wins the user will notice (1-3) with engineering consolidation (4-6) so morale/momentum stays high.

---

## Research appendix (top-10 stealable patterns)

From the external research brief, these are the patterns most directly applicable to a local-first, multi-model notetaking app:

1. **Effective-model badge on every assistant message** — ✔ captured as P1.
2. **Composer-footer context pills** (Continue.dev) — ✔ captured as P1.
3. **Right-side Context Panel with per-source checkboxes** (NotebookLM) — ✔ captured as P1.
4. **Editable plan above execution for anything multi-step** (Cursor Plan Mode) — deferred; only unlock this for turns that touch 3+ notes or run 3+ tool calls.
5. **Progressive disclosure for thinking and tools** — largely in place (collapsed tool cards, thinking popover); cross-check that every new tool inherits the collapsed-by-default pattern.
6. **Streaming status text with specificity** — "Searching 4 notes tagged #health" instead of "Thinking…". Wire into the overseer `ExecutionPlan`; feed its step descriptions into the streaming indicator.
7. **Errors as stream parts, not exceptions** — ✔ captured as P1 typed error enum.
8. **Degraded-mode banner, never silent fallback** — subset of the typed error work; one banner shape for "Cloud unreachable — using Local Reasoning."
9. **Minimal tool surface (8 tools)** — ✔ captured as P2.
10. **Action Audit & Undo log** — ✔ captured as P2.

---

## Non-goals for this plan

- **New local models.** The runtime/model batch Codex pre-staged (`LocalRustRuntime.swift` et al.) remains its own audit. Keep separate.
- **Hermes vs. omega-mcp canonicalization.** Big decision, outside this pass. Called out for a dedicated session.
- **Visual polish** (themes, animation). This plan is functional/transparency; aesthetics follow separately.

---

## Open questions for the user

Before landing P1-P3:

1. **Label format for the model badge.** "Claude Sonnet 4.6" (verbose) vs. "Sonnet" (terse) vs. "Claude • Sonnet" (provider+model). Preference?
2. **Context panel default state.** Always visible on first context load, or always hidden until toggled? Research suggests "default visible on first load, then remember" — but that's a taste call.
3. **Auto-route bias.** Tonight's Batch A made auto-route explicit. For the Codex GPT-5.4 preservation fix, I chose to NOT downgrade to Mini on fast. Want the same policy applied globally (never silently downgrade on auto-fallback), or keep the existing fast-mode auto-downgrade behavior outside Codex?
4. **Typed error UI scope.** Do we ship inline recovery buttons (open Keychain, retry with countdown) in v1, or just improved copy? Recovery buttons are the research-proven win but touch more surfaces.
