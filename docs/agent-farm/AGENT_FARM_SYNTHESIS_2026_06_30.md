# AGENT FARM — Master Synthesis (2026-06-30)

> Distills **8 research efforts** into ONE buildable spec: my 3 adversarial deep-research passes (`AGENT_FARM_RESEARCH_REPORT`)
> + 5 owner-commissioned reports (Gemini-1/2, Claude, GPT-1/2). **RESEARCH COMPLETE — the DESIGN is SETTLED; the only
> remaining risk is engineering (Bevy churn, macOS fps, the Python-bridge wiring).** Where ≥4 sources agree → CONVERGENT
> (build it). Where they conflict or one is wrong → CONTESTED/CORRECTED (read first).
>
> **★ THE SHARPENED THESIS (GPT-1/2 nailed it):** build a **budgeted PRODUCTION society**, not a cute LLM-NPC city — a
> *minimal world with STRONG economics*, not a rich world with weak ones. The economy is the spine; the mascots feel
> alive via cheap drives/habits/gossip, but are genuinely USEFUL because scarce budget forces them to produce real,
> inspectable artifacts (notes, research, code, verified outputs). Minimal + human-like + actually-helpful, at once.

## ★ THE CONVERGENT BLUEPRINT — what every source agrees on (HIGH confidence)

**1. The cheap-tick / slow-tick split is THE core decision (unanimous, 6/6).**
| Rust ECS, every tick (120 Hz, deterministic, cheap) | Async LLM, slow tick (off-thread, expensive) |
|---|---|
| Sims-style needs/drives decay + **utility scoring** (action selection) | Reflection (memories → insights) |
| Movement, pop-in/out transitions, collision | Planning (daily plan → sub-goals) |
| **Memory retrieval math** (recency/importance/relevance) | Writing the markdown artifact |
| Budget ledger: settlement, caps, faucets/sinks | Conversation/gossip generation · importance-scoring new memories |
| Reputation/relationship scalar updates | Spontaneous goal generation · tool-purchase decisions |
*Aliveness = constant cheap motion that LOOKS spontaneous; robotic = every action waits on the LLM.*

**2. Brain = Generative Agents (memory+reflection+planning) + Sims needs/drives on top.** Memory stream + retrieval
score `wᵣ·recency + wᵢ·importance + wₛ·cosine`; reflection fires on an importance-budget threshold; planning is
top-down/recursive. Add the Sims **Infinite Axis Utility System** (Dave Mark, GDC 2015) as the cheap drive layer
(curiosity→research, social→gossip, energy/budget→earn, order→organize vault).
→ **Use the VERIFIED constants: recency decay `0.995`, reflection threshold `150` (from the paper) — NOT the `0.99`/`100`
approximations some reports used.**

**3. PIANO concurrency (Project Sid) — mine, rebuild in Rust.** Concurrent multi-speed modules + a single Cognitive
Controller that broadcasts one coherent decision (prevents "says one thing, does another"). Maps onto Bevy's ECS scheduler.

**4. Economy = closed compute-budget; EVE faucet/sink discipline is non-negotiable (unanimous).**
- **Currency = simulated token/compute budget** (never real money/SSN). Earn by selling kept artifacts to a deterministic
  Rust appraiser; spend on tools/skills/compute/data.
- **Every minted unit needs a SINK** (tool fees, memory-rent/upkeep decay, idle tax, market tax) or you get Diablo-3
  hyperinflation. **Per-agent balance caps** + per-tick/day spend caps (Stripe-Issuing model). Treasury mints at a fixed rate.
- **AP2 mandate model = the in-ECS purchase flow:** two-phase commit — LLM emits `IntentMandate` (goal + cap) → Rust
  matches a shop offer → writes `CartMandate` → settlement system validates the cap + debits + writes an immutable
  `LedgerEntry`. All money logic deterministic + auditable in Rust. (x402 = the "402 handshake" pattern; build the
  handshake, not the blockchain.)

**5. Believable ≠ Useful — add a VERIFY loop (the key to genuine usefulness).** "Implement-then-verify": a worker emits
a draft → a peer reviewer critiques (capped at 3–5 turns) → a cheap "judge" model passes/fails. Grounding + citation +
task-reward on top of the Generative-Agents believability loop. *Without this you get a charming toy, not a useful one.*

**6. Frameworks = MINE, DON'T FORK (unanimous — all Python/TS, stack-mismatched for Rust).** Lift the IDEAS:
| Source | Lift this one idea |
|---|---|
| Stanford Generative Agents | memory-retrieval scoring + reflection trigger |
| Voyager | **skill-library-as-vector-DB** (skills indexed by docstring embedding, composed) → buyable skills |
| Project Sid / PIANO | concurrent-modules + central decision (the tick split) |
| elizaOS / AI Town | JSON **character-file = personality DNA**; proximity-based conversation states |
| CAMEL | inception-prompting guardrails (anti role-flip/echo/loop) + adversarial-debate termination |
| AP2 / x402 / Stripe | mandate data model · 402 handshake · spending caps |
→ Build the Rust runtime FRESH.

**7. Hermes brain + MoA offline-only.** Hermes function-calling (`<tool_call>` tags, JSON-schema adherence) = the mascot
brain; maps cleanly to ECS shop/tool affordances. **Mixture-of-Agents is real (AlpacaEval 65.1% vs GPT-4o 57.5%) but
SLOW + contested (Self-MoA can beat it) → use ONLY on the offline "produce serious research" path, never the live loop.**

**8. Bevy = build on it.** 100k+ sprites at framerate (way past your 25–50 agents); async LLM bridge via
`AsyncComputeTaskPool` / `bevy_tokio_tasks` / crossbeam channels (LLM never stalls the frame); WGSL Gaussian-blur +
noise-dissolve shaders; transparent borderless vibrancy window (`transparent:true` + `Color::NONE` + per-OS
`composite_alpha_mode` + `window-vibrancy`/`bevy_blur_regions`); `hit_test:false` for desktop-overlay passthrough. UI =
`bevy_ui` (retained, ECS-native, custom WGSL) + `egui` for debug panels.

**9. Minimal world = 6 affordances only:** shops · message/board surface · per-agent vaults (mapped to real disk, e.g.
`~/.hermes/vaults/`) · meeting spots (proximity → conversation) · servers/tools · messaging hubs. Objects always exist in
the data layer; only *rendered* (blur-revealed) when relevant — **findability in data, ephemerality in render.**

**10. Ranked agent-action menu (convergent top set):** (1) research a self-generated question → markdown note ·
(2) reflect → update beliefs · (3) buy a tool/skill via mandate · (4) gossip with a co-located agent · (5) sell artifact
→ earn budget · (6) maintain/prune vault · (7) coalition co-author (offline MoA) · (8) plan + decompose · (9) upkeep/decay ·
(10) wander/idle (cheap texture).

## ⚠️ CORRECTIONS + CONTESTED — do NOT build on these blind
- ❌ **"Tiny Glade is a Bevy game" — FALSE.** Gemini-1 asserts it; Gemini-2 implies it. **Claude's report + my Pass-2
  research correctly catch it:** Tiny Glade uses a *custom* Rust engine and only `bevy_ecs`. Real shipped Bevy games are
  few (Tunnet, Jarl, Foresight, Times of Progress). **Takeaway: you're an early adopter — budget for Bevy 0.x API churn;
  pin a version for v1.** (Trust Claude's report over the Geminis on Bevy facts — it's the most rigorous of the three.)
- **Constants:** use the paper-verified **`0.995` decay / `150` reflection threshold**, not Gemini's `0.99`/`100`.
- **Python bridge — CONSENSUS IS SIDECAR (now 6/8 explicit).** Run Hermes/Python/model workers **out-of-process** (gRPC/
  Tonic or local IPC + crossbeam/flume channels); Rust owns world state + render; exchange only typed tasks/summaries/
  embeddings/artifacts. Both GPTs + Claude + Gemini-1 + my research warn AGAINST putting **PyO3/PyBevy in-process** on the
  hot path (the GIL becomes part of your frame budget; crashes aren't isolated). Gemini-2's in-process PyBevy is the
  OUTLIER — use it ONLY if you genuinely need zero-copy GPU buffers; **default = sidecar.**
- **Hermes reliability caveats (GPT-2, from Hermes's own docs + 2026 issue tracker):** Hermes-4 *chat* models are **NOT
  recommended for agent/tool-calling work** (tuned for chat/reasoning); there are recurring 2026 tool-calling instability
  reports (malformed calls, empty post-tool responses). → Use Hermes as an **external brain-WORKER**, never let it own the
  world loop; pick the function-calling-tuned variant; validate tool-call parsing.
- **ProMotion 120fps is an ENGINEERING TARGET, not a settled fact** — Claude AND both GPTs explicitly could not source
  guaranteed macOS 120fps pacing; open Bevy bugs exist. **Profile on real ProMotion hardware; ship 60fps if 120 won't hold.**
- **macOS 120fps/ProMotion has OPEN BUGS** (Claude cites issues #12097, #16087 — capped ~60–80 despite AutoNoVsync).
  Verify on real ProMotion hardware; `bevy_framepace` mitigates; **ship 60fps if 120 won't hold.**
- **MoA latency may not pay for itself** — cut it if artifact quality doesn't justify the ~4× cost.

## THE STAGED BUILD PLAN (Claude's, the cleanest — prove each stage before the next)
1. **Prove the split, ZERO LLM** — Rust drives (Sims utility) + deterministic budget ledger; 25 agents wander/trade vs a
   stubbed appraiser. **Gate: stable 120fps (or 60) w/ 50 agents + 200 objects; ledger never violates caps under fuzzing.**
2. **Bridge ONE brain** — `bevy_tokio_tasks` + Hermes; memory stream + retrieval + reflection. **Gate: one mascot makes one
   markdown artifact a human would actually keep, with no main-thread stall.**
3. **Economy + society** — AP2 Intent→Cart→settle flow, shop, gossip/reputation, appraiser mints budget for kept
   artifacts; tune EVE faucets/sinks. **Gate: budget supply stays bounded over a long run; agents specialize unscripted.**
4. **Offline super-agent (optional)** — MoA/Self-MoA for serious-research artifacts only, off the live loop.

## ★ FINAL ADDITIONS (GPT-1 + GPT-2 sharpened these — now convergent)
- **The VERIFIER is a first-class economic ROLE — this is the believable→useful fix made concrete.** "Router-and-verifier
  society, not a permanently-layered MoA cathedral." A worker drafts → a **verifier/judge agent** critiques (capped 3–5
  turns) → **reward only releases on a verifier pass** (or deterministic check). Verification *earns budget*, so quality
  control is an in-world job. Partial pay for useful intermediate output only if the verifier approves.
- **Anti-exploit economics (detailed, convergent):** anti-hoarding = mild **demurrage / upkeep rent** on idle balances &
  stored skills/data (NOT blanket inflation — Eco's lesson); **anti-rich-get-richer** = progressive upkeep on big holdings
  + diminishing reputation dividends + capped passive income; **anti-loop-farming** = novelty/duplicate detector (no reward
  for near-duplicate artifacts) + cooldowns + board quotas; **no recursive self-purchase of authority**, escrow/deposits
  for large actions, treasury mints at a fixed rate, a global "austerity" governor that can raise congestion multipliers.
- **A2A vs MCP — the clean society wiring:** **MCP = agent→TOOL** ("using a hammer" — search/browser/files/servers, sold as
  in-world infrastructure); **A2A = agent→AGENT** ("hiring a carpenter" — discover/delegate/exchange artifacts). They're
  complementary. **For a single-process Rust app you may model BOTH as internal ECS events in v1** — adopt real MCP only
  for *external* tools and real A2A (it has a Rust SDK now) only for *external* agents.
- **"State permanence beneath visual impermanence"** (both GPTs independently): objects may **blur/dissolve out of the
  render** when irrelevant, but their identity/address/searchability **persist in the data layer** — plus a persistent
  spotlight/command surface to summon any object by name. Findability in data; ephemerality in render. (Resolves your
  pop-in/out-yet-always-findable requirement.)
- **Don't over-promise emergence (validation caveat, reinforced):** Project-Sid-style emergent roles/laws/culture are
  *possible* but **contested** — recent critique argues some "emergent conventions" may reflect simulation mechanics, and
  validation is a known weak point. Seed simple relationship/reputation scalars + gossip; **don't bet the product on
  de-novo institutions** appearing.
- **Ranked action menu (now 3-source convergent top set):** claim a board task · message/delegate · research/search · buy
  tool/model-tier · write a markdown artifact · **verify/critique another's artifact** · store/retrieve memory+skill ·
  meet/coordinate · rest/reflect/replan · update relationship · publish to archive. **Cut for v1:** romance, combat,
  full consumer-shopping sim, elaborate lawmaking.

## Status — RESEARCH COMPLETE ✅
- **8 efforts distilled. The design is SETTLED.** Independent researchers (including 3 adversarially-verified passes) all
  landed on the same architecture: the cheap-tick/slow-tick split · Generative-Agents brain + Sims drives · closed
  compute-budget with EVE faucet/sink discipline + AP2 mandates + a verifier role · mine-don't-fork · Hermes brain-sidecar
  · MoA offline-only · Bevy-as-foundation · 6 world affordances · state-permanence-beneath-visual-impermanence.
- **All remaining risk is ENGINEERING, not design:** Bevy 0.x churn (pin a version) · macOS 120fps (profile; ship 60 if
  needed) · the Python sidecar wiring · don't-over-promise-emergence. There is no open *design* question left.
- **Next move is to BUILD** — Stage 1 (prove the split, zero LLM) is the entry point. When you're ready, I can turn this
  synthesis into a paste-ready build prompt (like your Epistemos plans) or scaffold the Stage-1 Rust/Bevy core.
