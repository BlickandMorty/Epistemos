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

## PASS 2 — Bevy capability · Hermes/MoA · currency (111 agents · verified set)

**★ BEVY CAN DO THIS — every required primitive VERIFIED (3-0), proven by official examples + shipped Steam games.**
- **Thousands of 2D ECS entities ✅** — official `bevymark` spawns 10,000 sprites/sec; render benchmarks hit ~100K–130K
  sprites. "Thousands" is a conservative floor, not the ceiling. Your society scales.
- **Blur + reveal/dissolve shaders ✅** — via a custom post-process pass that reads the main-pass texture (official
  `custom_post_processing.rs` + `motion_blur`/`bloom`/`depth_of_field` examples). ⚠️ **CAVEAT: blur is NOT a built-in
  toggle** — it's custom-shader work (the built-in stack is only chromatic-aberration/vignette/lens-distortion).
- **Transparent, borderless "widget" windows ✅** — `transparent_window.rs` + `desk_toy.rs` ("feel more like a widget
  than a window"). ⚠️ needs `ClearColor(Color::NONE)` + per-OS `composite_alpha_mode`; historically flaky on Linux.
- **Cross-platform native ✅** — wgpu → Metal (Mac) / DX12 (Win) native; **WebGPU on web is still experimental** (WebGL2
  is the safe default).
- **Bridging a Python/Hermes brain into ECS ✅** — documented **crossbeam-channel-in-a-Resource** pattern (non-blocking
  out-of-process agent brain → ECS). This is your brain/body bridge, proven.
- ⚠️ **Two honest weaknesses:** (a) blur/vibrancy = out-of-engine custom work (NSVisualEffectView vibrancy is native,
  not Bevy); (b) **Bevy's RENDERER is immature** enough that the flagship shipped games (Tiny Glade, Tunnet) **keep
  `bevy_ecs` but replace the renderer.** Mitigation: lean on `bevy_ecs` (rock-solid) + accept custom-shader work for
  the frosted look, or pair ECS with a lighter 2D renderer if Bevy's bites.

**HERMES / MIXTURE-OF-AGENTS — important nuance (don't conflate two repos).**
- **`Hermes-Function-Calling` = single-model, single-agent tool calling** — it only supplies the canonical
  `<tool_call>/<tool_response>/<tools>` XML grammar. NO multi-agent / A2A / routing code lives there.
- The **multi-agent + Mixture-of-Agents capability is the SEPARATE `hermes-agent` framework.** So "use Hermes" = the
  grammar (for tool-calling mascots) + `hermes-agent` (for the society). Vendor the right one for the right job.
- **Mixture-of-Agents is REAL + peer-reviewed** (Together AI, arXiv:2406.04692, ICLR 2025): layered draft-then-aggregate
  (default 3 layers × 6 proposers); open-model ensembles beat GPT-4o on AlpacaEval 2.0 (65.1% vs 57.5%). ⚠️ **BUT
  contested** — **Self-MoA** (aggregating one strong model's own samples) can beat mixing different models, and MoA costs
  **~4× latency.** Verdict: MoA "works but is not a free win" — use it for *quality-critical* super-agents, not every
  mascot. (Several Hermes-MoA-specific claims were rate-limited/unverified.)

**ROBUST CURRENCY — STILL an open gap (rate-limited AGAIN).** Pass 2's verifier hit rate limits on the *entire* economy
set (EVE / Eco / Universal Paperclips / AP2 / x402 / Stripe) — same as Pass 1. So after two passes the economy design
is *still unconfirmed by adversarial verification*. → Needs a dedicated, tighter currency-only pass (or direct synthesis
from the well-established economy-design literature, since the sources exist — only the verification keeps failing).

### Pass 2 sources (Bevy verified)
[bevymark](https://bevy.org/examples/stress-tests/bevymark/) · [custom post-processing](https://bevy.org/examples/shaders/custom-post-processing/) · [transparent_window.rs](https://github.com/bevyengine/bevy/blob/main/examples/window/transparent_window.rs) · [Window docs](https://docs.rs/bevy/latest/bevy/window/struct.Window.html) · MoA (arXiv:2406.04692, ICLR 2025)
