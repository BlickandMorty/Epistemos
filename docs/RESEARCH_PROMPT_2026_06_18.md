# R-PROMPT — priompt + context engineering verdict (2026-06-18)

Research-first verdict on **anysphere/priompt** (JSX, priority-based context
budgeting, by the Cursor team) and 2026 context-engineering practice → what
sharpens our **hyper-deterministic schema** + the `CapabilityManifestBuilder` /
context-assembly path. take/skip + free-vs-paid + license + on-device + UX.

## TL;DR

**SKIP priompt as a dependency** (TS/JSX, not native Swift; and the authors
themselves warn its core idea is often the wrong abstraction). **ADOPT two
context-engineering principles** that fit our determinism thesis and mostly
reinforce what we already do: **cache-stable prefixes** (the real 2026 cost/
latency lever) and **explicit, ordered context assembly** (deterministic
inclusion, not heuristic priority-juggling).

| Idea | Verdict | Why |
|---|---|---|
| priompt the library | **SKIP** | TS/JSX, MIT — not native; a port is more work than value |
| Priority-based inclusion | **PARTIAL / fallback only** | Authors: "adding priorities to everything is an anti-pattern… may be the wrong abstraction" + it **breaks caching**. Use only as a budget-overflow fallback, not the primary mechanism |
| **Cache-stable prefix** | **TAKE (reinforce)** | Anthropic prompt caching = ~90% cheaper cache reads — the biggest lever. Keep system prompt + capability manifest STABLE; put volatile context LAST |
| Explicit ordered assembly | **TAKE (reinforce)** | We already do bounded, explicit context (CapabilityManifestBuilder, resolveNotesContext caps) — keep it deterministic, not priority-heuristic |
| LLMLingua-style token compression | **SKIP for now** | 2–5× compression but lossy → conflicts with verifiability/provenance (we want exact, replayable context) |

## What priompt gets right (and its own caveats)

priompt renders prompts from JSX with per-element **priorities** to decide what
fits the window. Genuinely useful for "include this big file line-by-line until
the budget runs out." **But the authors explicitly caution:** priorities-on-
everything is an anti-pattern, priorities may be the wrong abstraction, and the
renderer has **no built-in cacheable-prompt support** — overusing priorities
creates hard-to-cache prompts that *raise* cost/latency. That caveat is the
whole verdict: priorities are a niche overflow tool, not the architecture.

## The real 2026 lesson: context engineering, not prompt-shortening

Token cost/latency is driven by **bloated context, idle tool schemas, stale
history** — and the dominant fix is **prompt caching** (≈90% on cache reads with a
high hit rate) plus a smart context engine. Translation for us:

1. **Cache-stable prefix.** Order context so the *stable* parts come first
   (identity + capability manifest + tool schemas) and *volatile* parts last
   (the user's turn, freshly-loaded notes). This maximizes cache hits on our
   existing `agent_core/src/prompt_caching.rs`. ACTION: audit the main-chat
   system-prompt assembly order (CapabilityManifestBuilder → executionPlan
   prompt → notes) so the volatile note/query content is appended last, not
   interleaved into the stable prefix.
2. **Trim idle tool schemas.** Only attach tools that can actually run this turn
   — which our **capability ceiling (P7.1)** + **tool toggles (P2.1)** +
   `disabledToolNames` already do. Reinforce: don't advertise tools the tier/mode
   can't use (we already filter — keep it tight).
3. **Bounded, explicit inclusion** beats heuristic priority. Our determinism
   thesis says: include exactly what the route needs, deterministically, and show
   "why this route". That's *stronger* than priompt's priority guessing and it's
   replayable (ClaimLedger/AnswerPacket). Keep it.

## Founding-Thesis fit

priompt is heuristic (priorities); our edge is **deterministic + verifiable**
context (grammar/json-schema constraint, explicit manifest, provenance). So we
do NOT adopt priority-juggling as the architecture. We adopt the two boring,
high-leverage wins — **cache-stable prefix** + **lean tool schemas** — and keep
context assembly explicit and replayable. The one concrete code follow-up worth a
slice: a context-assembly audit that guarantees the cacheable prefix is stable
across turns (volatile content strictly appended), measured against
prompt_caching's hit rate.

## Sources

- [anysphere/priompt (GitHub, MIT)](https://github.com/anysphere/priompt)
- [priompt README (priorities + caveats)](https://github.com/anysphere/priompt/blob/main/README.md)
- [Arvid Lunnemark — Prompt design (priompt blog)](https://arvid.xyz/posts/prompt-design/)
- [Context Engineering: reduce token usage (Token Optimize)](https://www.tokenoptimize.dev/guides/context-engineering-reduce-token-usage)
- [LLM token cost optimization playbook 2026](https://www.the-ai-corner.com/p/llm-token-cost-optimization-playbook-2026)
