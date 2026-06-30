# AGENT FARM — Deep-Research Prompt: "Everything a minimal agent world should simulate" (2026-06-30)

> Paste this to a web-research agent (or run via the `deep-research` skill). It commissions an exhaustive, CITED survey
> of what AI agents in a MINIMAL, native, fluid simulated world should be able to *do/simulate* to feel **human-like AND
> be genuinely useful**. Companion to `AGENT_FARM_CONCEPT_2026_06_30.md`. Re-runnable — go deeper each pass.

---

```
You are a deep-research agent. Produce an EXHAUSTIVE, CITED report answering: "What should AI agents in a MINIMAL,
native, fluid 2D simulated world be able to SIMULATE and DO — to feel maximally HUMAN-LIKE while being genuinely
USEFUL (they make real knowledge/artifacts) — and what should I lift from existing work vs. build fresh?"

THE PRODUCT THIS SERVES (constraints that shape every answer):
  - A frosted-MINIMAL native game (Bevy/Rust ECS, cross-platform). Looks like a calm blurred app; is secretly a society
    of budgeted agents. Restraint is the differentiator — reject anything that adds messiness for its own sake.
  - Currency = BUDGET (tokens/compute). Agents earn/spend a real-but-SIMULATED economy; NO real money, NO SSN.
  - Aesthetic: objects POP IN/OUT of existence with FLUID blur-reveal/dissolve, ProMotion 120fps, minimal motion; but
    everything is ALWAYS findable (a quiet menu/search). "Mix Rust ops + agent code": cheap deterministic drives + LLM
    reasoning. NOT generative/model-rendered UI — hand-authored, deterministic ECS.

RESEARCH DIMENSIONS — go deep on each, with primary sources:

1. THE ECONOMY (budget-as-currency, simulated minimally):
   - What can agents BUY: tools, skills, MCP servers, compute, more budget, "infrastructure" (servers/storage), data,
     access. What can they SELL: finished notes, research reports, artifacts, services to each other.
   - How "shops" work minimally: pop-in/out vendors vs a menu option vs autonomous procurement. Designs that feel alive
     but stay minimal. How a budget/compute market self-balances (supply/demand of tokens).
   - What REAL agent-payment systems teach a SIMULATED one (Google AP2, Coinbase x402, Stripe agent toolkit,
     Skyfire) — the MANDATE/spend-limit model — but adapted to in-game currency. (Honest: never raw SSN/identity.)
   - Lessons from economy sims (The Sims, Dwarf Fortress, Eco, RimWorld, idle/incremental games like Universal
     Paperclips) on minimal-but-deep simulated economies.

2. HUMAN-LIKE BEHAVIOR / SPONTANEITY (the hard part):
   - Needs/drives systems (Sims-style) that generate believable impulses cheaply on a Rust tick.
   - MEMORY + REFLECTION + PLANNING (Stanford Generative Agents) — the model worth stealing; how it works, its cost,
     its failure modes.
   - Personality / "character DNA" / mood; spontaneous goal-formation; unpredictable-but-coherent action.
   - SOCIAL dynamics: relationships, gossip, collaboration, competition, reputation, trust, coalitions.
   - What makes agent behavior feel ALIVE vs robotic (concrete patterns + anti-patterns). The split between
     deterministic impulse (Rust) and LLM reasoning — where the line should be.

3. THE WORLD / OBJECTS (minimal but meaningful):
   - The full vocabulary of affordances a minimal agent world needs: shops, "phones"/messaging, servers, tools, vaults,
     boards, meeting spots, workstations. Which are essential vs noise.
   - How objects pop in/out fluidly + stay always-findable; spatial vs menu interaction; the "calm app" feel.

4. THE EXHAUSTIVE MENU — "things an agent should be able to do":
   - Enumerate EVERY believable+useful agent action (research, write/auto-edit markdown, trade, build, communicate
     A2A, form/abandon goals, collaborate, compete, rest, LEARN (overnight fine-tune), fork/breed, teach, hire, etc.).
   - RANK each by (human-likeness x usefulness x minimalism-fit) with a one-line rationale.

5. EXISTING FRAMEWORKS — robustness + fit assessment (mine, don't fork):
   - Stanford Generative Agents (Smallville), a16z AI Town, Project Sid / Altera, Voyager (Minecraft), CAMEL,
     AutoGen/AG2, crewAI, ELIZA/ai16z, any 2026 agent-society repos.
   - For each: what it does, maturity, stack, license, what's GENUINELY worth lifting (memory? reflection? proximity?
     economy?), and whether it fits "minimal + native (Rust) + truly-useful." Flag the messy/web ones to avoid.

6. THE AESTHETIC (so usefulness stays minimal):
   - Minimal "secretly-a-society" game/app design; fluid blur reveal/dissolve patterns; how calm UIs convey rich
     underlying simulation without clutter. Reference apps to study (incl. Paseo's agent-presence feel).

REQUIRED OUTPUT:
  - A RANKED "simulation design menu" (the §4 table) — the spine of the answer.
  - A recommended MINIMAL-BUT-DEEP v1 feature set (what makes the cut, what's deferred) honoring the constraints.
  - A "LIFT vs BUILD" table for the §5 frameworks.
  - The economy model (currency=budget) spelled out concretely + the spontaneity (Rust-drive + LLM) split.
  - Every claim cited (primary sources / repos / papers). Adversarially sanity-check the "human-like" claims — flag
    what's hype vs. what actually works in shipped/studied systems. No fluff; ranked, concrete, buildable.
```
