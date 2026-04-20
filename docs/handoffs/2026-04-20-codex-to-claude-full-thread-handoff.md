# Codex → Claude full-thread handoff · April 20 2026

Purpose: this is the comprehensive baton pass for Claude to audit all
work from this thread, cross-check it against the research we fused,
and verify the remaining runtime/product risks without losing the
through-line of what the user actually experienced.

Use this as the source-of-truth companion to:
- `docs/architecture/RELEASE_HARDENING_CANONICAL_PLAN_2026-04-20.md`
- `docs/handoffs/2026-04-20-codex-to-claude-release-blockers-handoff.md`
- `docs/handoffs/2026-04-20-claude-to-codex-verification.md`

If any older handoff conflicts with this document, prefer this file plus
the canonical plan above.

---

## 0 · Read first

1. `/Users/jojo/Downloads/Epistemos/AGENTS.md`
2. `/Users/jojo/Downloads/Epistemos/.agents/skills/epistemos_release_audit/SKILL.md`
3. `/Users/jojo/Downloads/Epistemos/docs/architecture/RELEASE_HARDENING_CANONICAL_PLAN_2026-04-20.md`
4. `/Users/jojo/Downloads/Epistemos/docs/handoffs/2026-04-20-codex-to-claude-release-blockers-handoff.md`
5. `/Users/jojo/Downloads/Epistemos/docs/handoffs/2026-04-20-claude-to-codex-verification.md`
6. This file

Branch:
- `codex/runtime-input-audit`

Project-file rule:
- The user explicitly wants the project to stay aligned with the real
  source tree through generation.
- Prefer `project.yml` + `xcodegen`.
- Do not hand-maintain `Epistemos.xcodeproj/project.pbxproj` unless
  there is truly no alternative.

User directive for Claude:
- check all of Codex's work
- treat the research as canonical context
- verify the fixes, not just the commit messages
- preserve the UX intent: simpler, smarter, clearer, less glitchy

---

## 1 · What the user was actually experiencing

These are the pain points Claude should treat as first-class product
requirements, not just bug descriptions.

1. The app would think and then say nothing.
2. The thinking surface could be blank even though the model clearly
   "did something."
3. ChatGPT/OpenAI replies could degrade into gibberish or malformed
   mixed reasoning/answer output.
4. The answer could begin while reasoning was still streaming, making it
   feel like the scratchpad never actually finished.
5. The app could claim `cache` on cloud queries, which confused the user
   because it looked like a local-runtime concept.
6. Picking one local model could still route to a different one
   automatically, especially DeepSeek.
7. The app could feel "dumb" in a way that suggested stale memory or
   contaminated prior-session context.
8. Launch/foreground/send could feel hangy or too synchronous.
9. Oversized local models could get too far into swap-thrash territory
   before failing.
10. The landing page had an intro animation the user did not want.
11. The model/runtime dropdown was too crowded and needed to be split
    into direct bar controls.
12. The user wanted provider-native runtime controls:
    - Anthropic extended thinking
    - OpenAI effort controls
    - Google grounding
    - only when the current effective model actually supports them
13. The user wanted these controls applied across the shared chat
    surfaces wherever the shared toolbar is used.

Claude should evaluate success against those user-facing outcomes, not
just the internal implementation narrative.

---

## 2 · Canonical research conclusions

These are the research conclusions that survived multiple passes and
should still guide Claude's review.

### 2.1 Silent-answer failures were primarily post-processing, not parsing

Canonical conclusion:
- `ThinkTagStreamRouter` was not the main bug.
- The bigger issue was the user-facing output cleanup path being too
  willing to reinterpret normal answer prose as reasoning and collapse
  to nothing.

Implication:
- fail open
- trust structured reasoning separation first
- do not aggressively strip normal answer openers

### 2.2 Local freezing is still fundamentally an actor/lifecycle issue

Canonical conclusion:
- MLX/local inference safety got better, but the long-term architecture
  issue remains: heavy generation still needs to move off the main-actor
  hot path.

Implication:
- do not mistake memory pre-flight or pressure listeners for the final
  fix to "freezes while thinking"

### 2.3 Local model safety is a runtime policy problem

Canonical conclusion:
- the right end-state is admission control + one active model policy +
  pressure-driven behavior, not just hiding models in the picker

### 2.4 Native multi-turn FFI is still a major missing architecture step

Canonical conclusion:
- Swift has the real conversation
- Rust still starts fresh too often
- the XML-context workaround is not a real replacement for native prior
  messages

### 2.5 Inline reasoning is the right UX direction

Canonical conclusion:
- detached popover thinking was the wrong end-state
- inline, in-bubble, auto-collapse-on-answer is the intended direction

### 2.6 Provider-native controls should be model-aware, not generic

Canonical conclusion:
- OpenAI, Anthropic, and Google should not all share one vague global
  toggle surface
- the runtime UI should only show provider-specific controls when the
  active/effective model can actually use them

---

## 3 · Commits landed on this thread/branch

This is the relevant commit chain from `30b7d733` forward.

```text
da06929e Fix silent-answer bug, add memory safety, and defer bootstrap load
b82f775e docs: handoff to next session covering the da06929e batch
68d50b08 docs: Codex verification handoff for the da06929e batch
c25a7777 Harden answer salvage and inline live thinking
daefbd98 Harden graph persistence and renderer safeguards
c7973e82 Harden intent fetch failures and local routing state
fa6b1b0b Harden Omega runtime fallbacks and channel routing
9fd199af Consolidate release hardening docs and handoffs
bd4b176f Add code editor benchmark coverage
4c0b5c56 Harden landing overlays and native setup doctor
8d50102f Harden KnowledgeFusion ingestion and training fallbacks
5088d2dd Harden notes and vault persistence rollback paths
7adca401 Refresh non-agent pruning source guards
2895714e Add MLX Metal warning patch helper
83487714 Format agent relay and tooling sources
6d549518 Refresh theme and settings source guards
2be60ef2 Harden cloud reasoning and tagged answer streams
2bd00476 Honor pinned local models during auto route
89dae777 Retire stale agent working memory
c7997ca6 Split chat runtime controls into toolbar buttons
9c58e0af Remove landing intro backdrop animation
befaa63a Use interactive chat budget for MLX preflight
d9100a25 Lock model mode exposure contracts
7b480447 docs: research brief for Hermes Expert Mode v1.1 feature
2b4c9a8b Stabilize reasoning boundaries across chat surfaces
2c7d724a Add model-aware runtime provider controls
```

Claude should not treat every one of these as equally central to the
user's runtime complaints, but they are all now part of the branch state
that must be reviewed coherently.

---

## 4 · What each major batch accomplished

### 4.1 `da06929e` + its paired docs

Commits:
- `da06929e`
- `b82f775e`
- `68d50b08`

What landed:
- fail-open answer salvage groundwork
- memory pre-flight/safety work
- bootstrap deferral work
- verification and next-session handoff docs

Why it mattered:
- this was the first serious pass at the research-backed release
  blockers

Key references:
- `docs/handoffs/2026-04-20-claude-to-codex-verification.md`

### 4.2 `c25a7777` — answer salvage + inline live thinking

What landed:
- tightened visible-answer salvage
- live thinking surface moved inline instead of detached popover logic
  dominating the experience

User pain points addressed:
- "it thought and said nothing"
- "the thinking surface feels wrong/detached"

### 4.3 Subsystem audit commits after that

Commits:
- `daefbd98`
- `c7973e82`
- `fa6b1b0b`
- `9fd199af`
- `bd4b176f`
- `4c0b5c56`
- `8d50102f`
- `5088d2dd`
- `7adca401`
- `2895714e`
- `83487714`
- `6d549518`

What to know:
- these are real committed branch state now
- several of them were subsystem-sized cleanup/hardening batches
- Claude should inspect them, but should not assume they are all part of
  the main chat/runtime regression story

The most relevant user-facing one in that cluster is:
- `5088d2dd` — notes/vault persistence rollback hardening

### 4.4 `2be60ef2` — cloud reasoning and tagged-answer hardening

What landed:
- OpenAI/ChatGPT visible thinking path now prefers summary-safe reasoning
  instead of raw reasoning text
- local tagged `<think>` / `<thinking>` / related traces now preserve the
  answer lane instead of swallowing it
- prompt-cache badge wording clarified so cloud prompt caching no longer
  looks like a local-runtime-only feature

User pain points addressed:
- gibberish from ChatGPT
- blank thinking pane
- confusion about cache on cloud models

### 4.5 `2bd00476` — pinned local model selection honored

What landed:
- if the user explicitly pins a local model, the shared routing/presentation
  path stops overriding it with another local family

User pain points addressed:
- "I picked Qwen but it still tried DeepSeek"

### 4.6 `89dae777` — stale agent working memory retired

What landed:
- hidden per-session working-memory files are now retired properly when
  sessions finish
- loaders prefer the newest running memory instead of arbitrary stale
  leftovers

User pain points addressed:
- "the app feels dumb like some old memory is conflicting"

### 4.7 `c7997ca6` — split runtime controls into toolbar buttons

What landed:
- the crowded runtime dropdown was split into direct bar controls for
  mode/model/routing/settings

User pain points addressed:
- dropdown clutter
- desire for a ChatGPT-like cleaner composer/runtime bar

### 4.8 `9c58e0af` — landing intro fade removed

What landed:
- removed the black/blue startup animation from the landing page

User pain points addressed:
- user explicitly wanted the launch animation gone

### 4.9 `befaa63a` — MLX pre-flight now uses interactive chat budget

What landed:
- local MLX admission checks now use the stricter interactive-chat memory
  budget instead of the weaker baseline requirement

User pain points addressed:
- oversized local models getting too close to swap-thrash before refusal

### 4.10 `d9100a25` — model mode exposure contracts locked

What landed:
- explicit tests covering model-mode exposure and UI contract behavior

User pain points addressed:
- "I don't trust which modes these models are exposing"

### 4.11 `2b4c9a8b` — reasoning boundaries stabilized across chat surfaces

What landed:
- late reasoning deltas no longer keep mutating after answer text begins
- note/chat surfaces stop leaking raw `Final Answer:`-style markers
- OpenAI raw reasoning text is kept out of the visible answer path

User pain points addressed:
- scratchpad still changing while the answer is already being written
- malformed/gibberish mixed output

### 4.12 `2c7d724a` — model-aware runtime provider controls

What landed:
- shared toolbar now shows `Effort` only when the effective model
  supports native effort controls
- shared toolbar now shows `Native Controls` only when the provider/model
  supports them
- settings now expose provider-native controls using the selected model
  for that provider
- reasoning tiers are expressed coherently:
  - `Thinking` → `Low / Medium / High / Heavy`
  - `Pro / Agent` → `Standard / Extended`

User pain points addressed:
- missing Anthropic/OpenAI/Google native controls in settings
- desire for provider-aware controls in the chat bar

Files:
- `Epistemos/App/RootView.swift`
- `Epistemos/State/InferenceState.swift`
- `Epistemos/Views/Settings/SettingsView.swift`
- associated tests

---

## 5 · Current product state after these landings

As of `2c7d724a`, the branch now contains these key behavioral changes:

1. Shared answer-salvage logic is much harder to collapse into an empty
   visible answer.
2. Cloud reasoning and local tagged reasoning are less likely to leak
   gibberish into the answer surface.
3. Pinned local model selections are respected instead of being silently
   replaced by auto-route.
4. Stale agent working memory is retired, reducing cross-session context
   contamination.
5. The main runtime controls are split into direct toolbar buttons.
6. The landing-page intro fade is gone.
7. MLX pre-flight uses the stricter interactive chat budget.
8. DeepSeek R1 local remains `Thinking`-only intentionally, not by
   accident.
9. Prompt cache wording now explicitly covers provider prompt caching,
   including cloud models.
10. Provider-native runtime controls now exist in both settings and the
    shared runtime toolbar when supported.

---

## 6 · Verification evidence already gathered

The strongest recent focused signals from this thread:

- `42 tests in 2 suites passed`
  - `UserFacingModelOutputTests`
  - `ChatPresentationTests`
- `80 tests in 4 suites passed`
  - cloud parsing / pipeline / agent chat / presentation slice
- `69 tests in 3 suites passed`
  - reasoning-boundary stabilization slice
- `248 tests in 2 suites passed`
  - toolbar/runtime presentation slice
- `225 tests passed`
  - runtime validation slice for MLX preflight
- `309 tests in 3 suites passed`
  - model-mode exposure / runtime UI audit
- `2 passed, 0 failed`
  - Rust `working_memory` tests
- `288 tests in 3 suites passed`
  - `TriageServiceTests`
  - `ChatPresentationTests`
  - `RuntimeValidationTests`
  - this is the latest focused run for the provider-native controls batch

Important nuance:
- Xcode repeatedly emits third-party `SwiftLint` package-plugin noise for
  `CodeEditSourceEditor` / `CodeEditTextView`
- in this repo, those lines can appear even when the selected Epistemos
  tests themselves succeeded
- Claude should judge by executed test output and final `TEST SUCCEEDED`
  lines, not by package-plugin chatter alone

---

## 7 · What Claude should manually re-check

These are the highest-value runtime/product checks still worth doing
manually in the launched app.

### 7.1 Main chat correctness

1. Ask OpenAI / GPT-5.4 to analyze a note with visible reasoning on.
   Confirm:
   - thinking is populated, not blank
   - answer is coherent, not gibberish
   - answer does not start while reasoning keeps visibly mutating

2. Ask Anthropic on a reasoning task.
   Confirm:
   - extended-thinking toggle behaves coherently
   - answer still appears cleanly after visible reasoning

3. Ask a local tagged-thinking model.
   Confirm:
   - `<think>` output stays in the scratchpad lane
   - the final answer still appears

### 7.2 Model selection and routing

1. Pin Qwen, enable cloud auto-route, send a local-capable turn.
   Confirm:
   - the app stays on the pinned local model
   - it does not silently route DeepSeek or another local family

2. Open a local DeepSeek R1 surface.
   Confirm:
   - `Fast` is hidden
   - `Thinking` is available
   - this is consistent across the shared toolbar surfaces

### 7.3 Memory and runtime safety

1. Try selecting a too-large local model on a constrained-memory setup.
   Confirm:
   - refusal happens early and honestly
   - the app does not lurch toward swap death first

2. Exercise the app after several chats/sessions.
   Confirm:
   - no stale prior working memory is contaminating fresh turns

### 7.4 Shared toolbar/settings UX

1. Open main chat, mini chat, note workspace, and graph search surfaces
   that use the shared toolbar.
   Confirm:
   - split toolbar controls render cleanly
   - `Effort` only appears when supported
   - `Native Controls` only appears when supported
   - settings and toolbar stay coherent with each other

2. Specifically verify:
   - OpenAI: effort controls
   - Anthropic: extended-thinking controls
   - Google: grounding controls

---

## 8 · Remaining dirty state on the branch

As of this handoff, these files are still uncommitted and outside the
provider-controls commit:

- `agent_core/src/agent_loop.rs`
- `agent_core/src/command_center.rs`
- `agent_core/src/providers/claude.rs`
- `agent_core/src/routing.rs`
- `syntax-core/target/aarch64-apple-darwin/debug/libsyntax_core.rlib`
- `Epistemos/Engine/StreamingTextCoalescer.swift`
- `LocalPackages/GGUFRuntimeBridge/.swiftpm/`
- `docs/research/hermes-bundling-build-phase.md`
- `docs/research/hermes-expert-mode-implementation-spec.md`
- `docs/research/hermes-expert-view-ui-spec.md`
- `docs/research/hermes-preset-research-notes.yaml`
- `docs/research/hermes-risks-and-failure-modes.md`
- `docs/research/hermes-strategic-fork-analysis.md`
- `docs/research/hermes-tool-catalog.md`
- `docs/research/hermes-update-strategy.md`
- `docs/research/hermes-wire-protocol.md`

Interpretation:
- these are not part of `2c7d724a`
- Claude should review them intentionally, not accidentally sweep them
  into a runtime/UI validation pass
- `libsyntax_core.rlib` is a build artifact drift, not user-facing source
  work
- `StreamingTextCoalescer.swift` was previously an unwired experiment and
  should be treated carefully

---

## 9 · Do not regress

Claude should not roll back these behaviors unless there is fresh,
strong evidence they are wrong:

1. Do not reintroduce broad reasoning-prefix stripping that can eat
   legitimate answer prose.
2. Do not surface raw OpenAI reasoning text as user-visible thinking by
   default.
3. Do not let cloud auto-route override an explicit pinned local model.
4. Do not put the runtime controls back into one crowded dropdown.
5. Do not hide provider-native controls behind generic, model-agnostic
   UI again.
6. Do not hand-edit `project.pbxproj` if the real fix belongs in
   `project.yml` + `xcodegen`.

---

## 10 · Still not fully closed

Even after all of the above, these are still the bigger structural items
that Claude should keep in view:

1. MLX/local inference architecture still needs the deeper off-main-actor
   cleanup.
2. Native multi-turn Rust FFI is still not the final form.
3. The app does not yet have one unified model supervisor consuming all
   runtime/memory signals.
4. Live launched-app verification is still more trustworthy than source
   or focused tests for the user's original complaints.
5. The context X-Ray and full inline reasoning UX vision are still ahead
   of the current implementation.

This means the branch is much harder and more honest than it was at the
start of the thread, but Claude should not overclaim that every
architecture-level issue is finished.

---

## 11 · One-line baton pass

Audit the branch by treating this thread's product complaints as the
checklist: verify that answer salvage, reasoning boundaries, local pin
respect, memory contamination cleanup, split runtime controls, and the
new provider-native settings/toolbar controls all work coherently in the
launched app, then review the remaining dirty Rust/docs/artifact state
without broadening scope or regressing the now-landed runtime fixes.
