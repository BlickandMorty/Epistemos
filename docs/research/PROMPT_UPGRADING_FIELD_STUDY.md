# Prompt-Upgrading Field Study — how to sharpen the 3 build prompts + the "Prompt Forge" feature

Two questions, one corpus: **(1) how do the best prompt systems work, and what should we borrow to
upgrade our three agent build prompts; (2) how do we build an in-app feature that deeply upgrades a
user's prompt the moment they submit it** — added to all three agent surfaces. Researched 2026-07-05
against primary sources (cited inline).

## Part 1 — The field (five paradigms)

**A. Composition + token budgeting — priompt (Cursor/anysphere).** Prompts as *priority-ordered
components* (JSX): `<scope p=…>`, `<first>` (fallbacks — "when the result is too long say (result
omitted)"), `<isolate>` (independent budget → cacheable prefixes), `<empty>` (reserve space for the
answer), `<capture>` (parse output in-prompt), sourcemaps to debug what got included. The engine renders
`Prompt(p_cutoff)` where the cutoff is the **minimum priority such that the prompt fits the token limit**
— low-priority elements prune first when the window is tight. Caveat, in their own words: *"priorities
are an anti-pattern"* in overuse, and *"it is easy to make hard-to-cache prompts."* **Lesson: what's
load-bearing must be marked and survive compression; inject context budget-aware, not maximally.**
[priompt](https://github.com/anysphere/priompt)

**B. Meta-refinement — Anthropic's Prompt Improver.** Takes a prompt and rewrites it via: a **CoT
reasoning section** (fills the reasoning between ideal input→output), **example standardization to XML**,
**example enrichment** with aligned CoT, **rewriting for clarity/structure**, and **assistant prefill**
to enforce output format. Reported **+30% accuracy** on a classification task, 100% word-count adherence
on summarization. **Lesson: structure + CoT scaffold + standardized examples + explicit output format is
the core recipe — and worked examples are the single biggest lever.**
[Anthropic prompt improver](https://www.anthropic.com/news/prompt-improver) ·
[docs](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/prompt-improver)

**C. Programmatic optimization — DSPy / MIPROv2 (Stanford).** Prompts as code: **signatures**
(input/output fields), **modules** (reasoning), **metrics** (measured quality). Optimizers *generate
multiple instruction variants + bootstrap few-shot examples, grade each against the metric, cache the
winner* — assembled at inference with no optimization loop running. **Lesson: name a measurable metric
per task; generate variants and pick the best against it; the best prompt is found, not hand-written.**
[MIPROv2](https://dspy.ai/api/optimizers/MIPROv2/)

**D. The enhancer *product* pattern — how to do it in a UI.** Show the rewrite and let the user keep
editing — "a first draft of their intent without abdicating agency." **Preserve intent + voice** (keep
key nouns, constraints, style cues); enhancement ≠ intent-clarification (the former preserves + adds,
the latter may reinterpret). One-click **accept / copy / retry / undo**. Keep latency low (debounce, fast
model). A rewrite study found **74% of rewrites strongly preserved intent, only 5% low** — rewrites are
overwhelmingly intent-safe *when designed to be*. [ShapeofAI enhancer](https://www.shapeof.ai/patterns/prompt-enhancer)
· [UX Tigers](https://www.uxtigers.com/post/prompt-augmentation) ·
[intent-preservation study, arXiv 2503.16789](https://arxiv.org/abs/2503.16789)

**E. The technique menu — the taxonomy.** The Prompt Report catalogs **58 text prompting techniques**;
the 2025 taxonomy groups them into **profile/instruction, knowledge, reasoning/planning, reliability**.
The enhancer draws from this menu — few-shot, CoT, decomposition, self-consistency, role, output-format,
clarity — but applies **only what fits the specific task** (per priompt's anti-overuse caveat).
[The Prompt Report, arXiv 2406.06608](https://arxiv.org/abs/2406.06608) ·
[2025 taxonomy (Springer)](https://link.springer.com/article/10.1007/s11704-025-50058-z)

**The Epistemos differentiator (unifies with the embedded-agent thesis):** every tool above rewrites a
prompt *in a vacuum*. Epistemos can **ground the upgrade in the user's own vault + graph + prior
sessions** — retrieve the right notes (RRF + graph), inject the highest-priority context that fits the
budget (priompt-style), cite them, and remember the user's preferences across sessions (DSPy-style
self-improvement). That is the "much more robust/useful/effective" no standalone enhancer can match.

## Part 2 — Upgrades for the three build prompts (apply these)
1. **READ-FIRST PRIORITY LEDGER (from priompt's priority idea).** The whole failure mode this session
   was agents *skimming* long prompts. Add a tiny top-of-file block listing the 3–5 rules that must
   survive even if everything else is skimmed. Highest-leverage, lowest-bloat fix. **[APPLIED to all 3.]**
2. **A worked example of one ideal cycle (from Anthropic: examples = +30%).** Each prompt should show,
   compactly, one SCOUT→FORGE→TEMPER→CRYSTALLIZE→ASCEND cycle done right — the target, not just abstract
   phases. (Recommended; add as the loop matures so it reflects a real shipped cycle.)
3. **A measurable metric per cycle (from DSPy).** Alongside each DoD, name the one number/observable that
   proves the cycle worked (e.g. "cold-open ≤1500 ms", "0 protected-path edits", "a real vault-cited
   transcript"). Turns "done" from a vibe into a measurement. (Several DoDs already do this — make it
   explicit each cycle.)
4. **XML/structured output where the agent must emit structured artifacts** (audits, reviews) — the
   Anthropic-improver standardization lesson.
5. **Self-consistency on the thermonuclear review** (from the taxonomy): run the deep review from ≥2
   independent lenses/passes and keep only findings that survive — reduces false "done."

## Part 3 — THE FEATURE: "Prompt Forge" (submission-time prompt upgrader; all 3 surfaces)

**What.** When the user submits a prompt to any agent surface, Prompt Forge deeply upgrades it *before it
reaches the model* — more robust, useful, effective — while **preserving the user's intent and voice**.

**The pipeline (grounded in Part 1):**
1. **Intent + gaps** — extract goal, constraints, done-bar; detect the underspecification that would
   actually change the outcome.
2. **Clarity + structure** — rewrite for clarity, add structure (sections/XML), **keep the user's key
   nouns, constraints, and style** (intent-preservation research). Enhancement, never reinterpretation.
3. **Technique injection (from the taxonomy, task-matched only)** — CoT scaffold / decomposition /
   output-format / role / few-shot **only where they help this task** (priompt: don't over-apply).
4. **⭐ Vault-grounding (the Epistemos edge)** — retrieve the most relevant vault notes / graph context /
   prior-session decisions (RRF + graph), inject the **highest-priority context that fits the model's
   budget** (priompt-style prune), and cite. This is what makes it beat every standalone enhancer.
5. **Budget-aware assembly** — respect the selected engine's context window; priority-prune injected
   context; never blow the window.
6. **Clarify-don't-guess** — if a genuine ambiguity remains that changes the result, surface ≤3 crisp
   clarifying questions instead of inventing an answer.

**UX (from the enhancer product pattern):** show original → upgraded (diff / side-by-side); one-click
**Accept / Edit / Retry / Revert**; never silently change intent; optional auto-mode with a visible
indicator + easy opt-out; low latency (debounce, a **fast/small model**, stream the upgrade); briefly
**externalize what changed** (added context, structure) so the user learns + trusts.

**Guardrails:** intent + voice preserved; the user always sees and can reject; honest (if it can't ground
in the vault, it says so and enhances anyway — never fabricates a citation); never leaks secrets; the
upgrade is auditable; fast enough to feel instant.

**Self-improving (DSPy-style, a frontier extension):** learn which upgrades the user accepts vs edits,
store the preference in the vault/graph, and adapt — Prompt Forge gets better at **this user's** prompts
over cycles. A natural CRYSTALLIZE skill.

**Per-surface build:**
- **Pro + rest-of-app agent** builds the **canonical shared `PromptForge` service** (it owns shared
  shell services) + the OpenChamber composer integration — the reusable core the other surfaces adopt.
- **1Code Experimental** wires its renderer composer + backend enhance step; grounds via the vault MCP;
  budgets to the selected engine's window.
- **MAS June** wires the June composer + gateway enhance; grounds via the vault; the enhance itself can
  run **on-device** (local model) for privacy (honest capability — say when it's local vs cloud).

Each surface ships it as a real, DoD-gated feature (diff-UX + intent preservation + vault-grounding +
one real "underspecified prompt → upgraded, vault-cited prompt" transcript), not a stub.
