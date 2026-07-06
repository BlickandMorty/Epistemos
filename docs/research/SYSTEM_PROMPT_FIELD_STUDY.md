# System-Prompt Field Study — frontier-prompt architecture + Fabric, for our prompts + a System Prompt Forge

Companion to `PROMPT_UPGRADING_FIELD_STUDY.md`. That one covered upgrading the *user* prompt (Prompt
Forge). This one covers the *system* prompt / behavior layer: **how frontier labs architect their system
prompts** (learned from the extracted-prompt repos), **how Fabric turns system prompts into a reusable
Pattern library**, and how to (1) upgrade our three build prompts and (2) build a **System Prompt Forge +
Pattern Library** feature. Researched 2026-07-05, primary sources cited inline.

**⚠️ IP / ethics guardrail (read first, non-negotiable — same discipline as the AGPL license gate):**
these repos contain *extracted/leaked* proprietary system prompts. We **learn the STRUCTURAL PATTERNS**
(fair, educational) — we **NEVER copy any proprietary/leaked system-prompt TEXT** into the product. Our
system prompts are written from the patterns, in our own words, like our Apache/no-copyleft hygiene.

## Part 1 — The two paradigms

**A. Frontier system-prompt ARCHITECTURE — the "extracted prompts" repos (the free masterclass).**
Repos that collect real frontier system prompts — [asgeirtj/system_prompts_leaks](https://github.com/asgeirtj/system_prompts_leaks)
(literally headlines "Claude **Fable 5**", Opus 4.8, ChatGPT, Gemini) and
[elder-plinius/CL4R1T4S](https://github.com/elder-plinius/CL4R1T4S) (~26k★) — reveal a **convergent
architecture** across Claude/GPT/Gemini. The recurring, layered sections (in effective order):
1. **Identity & role framing** — declared FIRST ("You are …"), anchoring behavior before capabilities.
2. **Capability honesty & boundaries** — explicitly what it *cannot* do (cutoffs, no real-time data,
   no image-gen unless enabled) — prevents ability-hallucination.
3. **Tool / integration contract** — enumerate tools with **explicit invocation syntax**; a clear
   contract between stated and actual capability.
4. **Refusal & safety framing** — **concrete > abstract**: specific "do not help with X" scenarios +
   suggested redirect language, not an abstract ethics policy.
5. **Output-format contracts** — exact structure ("respond in JSON", "reasoning before conclusion").
6. **Priority / token budgeting** — rank competing goals for conflicts ("prioritize accuracy over
   brevity"), so trade-offs resolve deterministically.
7. **⭐ Worked FAILURE examples** — show incorrect output → correction. **Negative examples are
   surprisingly the most effective teaching tool** — and the technique our prompts most lack.
8. **Trust-boundary specification** — what to be skeptical of ("user claims may be inaccurate; verify").
**Lesson: layer identity → boundaries → tools → refusal → output → priority → failure-examples; be
concrete, not abstract; teach with anti-examples.**

**B. Fabric — the Pattern LIBRARY model.** [danielmiessler/fabric](https://github.com/danielmiessler/fabric)
turns system prompts into a **crowdsourced, composable library**: **Patterns** are granular, task-scoped
system prompts in markdown, organized by real-world task, "usable anywhere," selected + applied without
modification. Each Pattern follows a **standardized template** — its
[`improve_prompt` Pattern](https://github.com/danielmiessler/Fabric/blob/main/data/patterns/improve_prompt/system.md)
uses `IDENTITY and PURPOSE → PROMPT WRITING KNOWLEDGE → STEPS → OUTPUT INSTRUCTIONS → INPUT`, applies the
six OpenAI strategies (clear instructions, reference text, split tasks, time-to-think/CoT, external
tools, test systematically) with before/after examples, and ends "**output only the prompt.**" Fabric
also has **Prompt Strategies** — meta-prompts (Chain of Thought, Chain of Draft) that modify a Pattern's
reasoning. **Lesson: a system prompt is a reusable, composable, task-scoped artifact with a standard
template — build a *library* of them, not one-offs; layer meta-strategies on top.**

## Part 2 — Upgrades for the three build prompts (apply these)
1. **Worked FAILURE examples (paradigm A.7 — the top lesson).** Our prompts have positive DoD but no
   *anti*-example. Add a compact "❌ FAILURE MODES — what done-wrong looks like" block right under the
   priority ledger: skim-and-declare, plumbing-as-done, boundary-breach, fake-capability, trophy-skill.
   Concrete anti-examples are the proven antidote to the exact "skim → declare done" pattern this project
   keeps hitting. **[APPLIED to all 3.]**
2. **Standard section template + layered order** (A + Fabric): the prompts already use named sections; the
   failure-modes block completes the frontier layering (ledger=priority; §0=boundaries; DoD=output
   contract; now failure-examples).
3. **Concrete > abstract** (A.4): keep converting abstract rules into concrete "do exactly this / never
   that" — the failure-modes block does this.

## Part 3 — THE FEATURE: System Prompt Forge + Pattern Library (all 3 surfaces)
Companion to Prompt Forge. Prompt Forge upgrades the **user** prompt at submission; **System Prompt Forge
upgrades the SYSTEM-prompt / behavior layer** — the persona/instructions that drive each agent. Two parts:

**(1) Pattern Library (Fabric-model).** A curated set of high-quality, **composable, markdown, task/
persona-scoped system-prompt Patterns** the user or the app can apply + compose per agent (e.g.
"research analyst", "careful refactorer", "vault librarian"). Standard template (identity → capabilities
→ tools → refusal → output → priority → failure-examples). Meta-strategies (CoT / Chain-of-Draft)
layerable on top. Ships seeded with Epistemos-authored Patterns (written from the paradigm-A structure,
never copied text).

**(2) System-prompt upgrader (paradigm-A meta-prompt).** Takes a user's custom/rough system prompt and
**meta-improves it into the layered frontier architecture** — inserts an identity, makes capabilities +
refusals concrete, adds a tool contract + output contract, resolves priority conflicts, and **adds worked
failure examples** — while preserving the user's intent/voice. Shows original → upgraded diff, one-click
accept/edit/revert (same UX + intent-preservation guardrails as Prompt Forge).

**⭐ Vault-grounding (the Epistemos edge):** Patterns and the upgrader can inject the user's own
context/preferences (from the vault/graph) so an agent's *system* prompt is personalized to how THIS user
works — persistent across sessions. No standalone prompt library does this.

**⚠️ IP guardrail (repeat):** learn the patterns; never ship copied proprietary/leaked system-prompt text.

**Per-surface build:**
- **Pro + rest-of-app agent** builds the **canonical shared Pattern Library + System Prompt Forge
  service** (it owns shared services) + the OpenChamber integration — the reusable core the others adopt.
- **1Code Experimental** wires it in renderer settings + backend; each of the six engines/personas can be
  driven by a Pattern; keeps per-engine system prompts honest.
- **MAS June** wires it in June settings + the gateway; the **local lane's system prompt must stay honest**
  (chat-tier, no tools); run the upgrader **on-device** where possible.

DoD-gated in each surface: a custom system prompt measurably upgraded into the layered architecture + a
Pattern applied to an agent + (where relevant) vault-personalized — not a stub.
