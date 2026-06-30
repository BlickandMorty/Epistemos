# AGENT FARM — Research Report (2026-06-30)

> Synthesized, **adversarially-verified, cited** findings from the deep-research passes. Pass 1 (broad) below. Pass 2
> (Bevy + Hermes-MoA + robust currency) is still running — appended when it lands. Companion to
> `AGENT_FARM_CONCEPT_2026_06_30.md`. (108 agents · 25 sources · 124 claims → 6 verified.)

## PASS 1 — what VERIFIED (high-confidence, 2–3 adversarial votes)

**THE BIG ANSWER: lift the Stanford Generative Agents architecture (Park et al. 2023, UIST, arXiv:2304.03442) as the
v1 human-likeness core. Memory + Reflection + Planning are ALL load-bearing — ship all three, not just memory.**
- Human-ranked ablation (100 evaluators, TrueSkill): full architecture **μ=29.89** → degrades monotonically as modules
  are removed → fully-ablated **μ=21.21**, which falls **BELOW** a human-crowdworker baseline (μ=22.95). Effect size
  d=8.16; p<0.001. *So a "minimal" v1 still needs all three modules — that's the floor for "feels alive."* [3-0 ✓]
- **The loop to lift:** (1) **Memory Stream** = a complete natural-language record of experiences; (2) **Reflection** =
  synthesize memories into higher-level insights over time; (3) **Planning** = retrieve memories to plan action. [3-0 ✓]

**★ YOUR BRAIN/BODY SPLIT IS CONFIRMED — with exact parameters.**
- **Memory retrieval (the "what surfaces now" function) is a CHEAP DETERMINISTIC weighted sum** — recency (exp decay,
  factor **0.995**) + importance + relevance (embedding cosine), all weights = 1. **ZERO LLM calls at retrieval**; the
  only LLM call is **once at memory creation** (rate importance 1–10). → This is *literally* your cheap **Rust-side,
  every-tick impulse function.** [3-0 ✓]
- **Reflection (the slow-LLM tick) fires on an IMPORTANCE-BUDGET threshold, not a timer** — when summed importance of
  recent events exceeds **150** (~**2–3×/agent/day**): generate 3 questions from the 100 most-recent memories → extract
  ~5 cited insights. → Your concrete cheap-tick (Rust) vs slow-reasoning (LLM) **cadence.** [3-0 ✓]

**The architecture produces the SPONTANEOUS, USEFUL, emergent social behavior you want — bottom-up, no scripting.**
- From a single seed: info diffused (party 4%→52%; candidacy 4%→32%) with no user intervention; social network
  densified (0.167→0.74 over 2 days); agents formed acquaintances, made plans, and **5/12 autonomously coordinated to
  show up** at the right place/time. Hallucination 1.3%, and **none of the diffused info was fabricated.** [2-0 ✓]

## PASS 1 — what did NOT verify (⚠️ rate-limited, NOT refuted — still strong leads)
The verification step hit **API rate limits**, so the entire **economy** and **framework** half came back **0-0
(unverified)** — these are *plausible and well-motivated but unconfirmed*; they need a re-verify pass:
- **Economy (AP2 / x402 / Stripe mandate model → simulated budget):** directionally clean — AP2's **Intent-Mandate
  (upfront spend rules/caps) + Cart-Mandate (auto-execute when conditions met)** maps neatly onto budget tokens; the
  layered model **A2A = agents talk · AP2 = agents pay · x402 = settlement** → mirror it with budget tokens instead of
  money. UNVERIFIED this pass.
- **Frameworks (lift-vs-build):** all 0-0. Directional reads worth re-checking: **AI Town** (MIT, but TS/Convex/PixiJS
  = *design*-lift not code-lift, and itself a Smallville reimplementation) · **Stanford repo** (Apache-2.0, but
  Python/Django = lift the *design*, not the runtime) · **PIANO / Project Sid** (~10 concurrent multi-speed modules +
  a "Cognitive Controller" coherence bottleneck → would *validate* the Rust-impulse/LLM-reasoning split; 30 agents
  self-developed roles) · **CAMEL** (Apache-2.0, Python, role-play, claims 1M-agent scale) · **Voyager**.
- **Minimal world/objects + the ranked agent-action menu** = effectively unanswered this pass.

## Honest caveats (from the report)
- All 6 verified findings trace to **one** (canonical, peer-reviewed, 11k-cite) paper — narrow corpus on the
  human-likeness side; high quality but single-source.
- **Believability ≠ usefulness.** The ablation measured how human-*like* agents seem, not how *useful* their knowledge
  output is — and "believability" as a metric is critiqued (LLM self-eval circularity). A *useful-knowledge* sim may
  need an *additional* objective beyond the Stanford architecture. **Open question worth its own research.**
- Emergence is real but **not reliable** (5/12 turnout) — design for "it emerges sometimes," not "always."
- **Lift the algorithm, not the runtime** — the 0.995 decay / 150-threshold / weighted-sum are language-agnostic and
  Rust-portable; the Python/Django reference impl is not.

## Design implications for the Agent Farm (actionable)
1. **v1 mascot brain = the 3-module Generative-Agents loop** (memory stream + reflection + planning). Non-negotiable floor.
2. **Memory retrieval → a Rust ECS System** (recency 0.995 + importance + cosine, every tick, no LLM). Reflection → an
   LLM call gated on the importance-150 budget (~2–3×/day). *Your split, with real constants to start from.*
3. **Treat economy + framework-lift as STILL-OPEN** — don't commit until the re-verify pass (rate-limited here) confirms.
4. Add a research objective for **"does believable → genuinely useful"** before betting the product on it.

## Sources (Pass 1, verified set)
[Generative Agents (arXiv:2304.03442)](https://ar5iv.labs.arxiv.org/html/2304.03442) ·
[ACM UIST full text](https://dl.acm.org/doi/fullHtml/10.1145/3586183.3606763) ·
[Stanford HAI](https://hai.stanford.edu/news/computational-agents-exhibit-believable-humanlike-behavior)
(economy/framework source leads — unverified: Google AP2, Coinbase x402, a16z AI Town, Project Sid arXiv:2411.00114,
joonspk-research/generative_agents, camel-ai/camel, MineDojo/Voyager.)
