# THE BIG IDEA — Epistemos Grand Convergence (2026-06-22)

Owner asked: what is the big idea? What does it all do, how does it converge, is it ONE brain or two/three?
Is it all folded into the plan? Any conflicts / gaps / missing IP? This is the single unifying picture +
a finalization audit. Grounded in the committed research (unification, TRINITY, Fugu, ADOPT-vs-IP, Osaurus).

## THE ONE-SENTENCE BIG IDEA
Epistemos is a **local-first agentic workspace** where a **knowledge brain** (your IP) and a **coordination
brain** (the orchestrator) sit on **one model-agnostic substrate**, drive **swappable engine-lanes**
(act = Osaurus, work = OpenCode, local, cloud), and surface through **two modes (act + work)** over a
**markdown PKM (Prose + MD-V2) + graph + agent-native vault** — minimal pixel-art native, no real competitor.

## IS IT ONE BRAIN, OR TWO/THREE? → ONE brain, TWO faculties, on a shared substrate (70B/new-model EXCLUDED — not part of it)
Think of it like a human brain: one brain, distinct faculties.
- **FACULTY 1 — COORDINATION ("which mind handles this, how"):** System G (the one orchestrator) + the TRINITY
  loop (Thinker/Worker/Verifier coordinator core) + RuntimeRouter (route-to-best-model-per-task). This is the
  "be our own Fugu, local-first" layer — it decides + routes + verifies across the model pool. Fugu (the paid
  API) is just one optional pool member, NEVER the coordinator.
- **FACULTY 2 — KNOWLEDGE / MEMORY ("what it knows, remembers, grounds on"):** your IP brain — Eidos/recall +
  cognitive DAG + provenance ledger + honesty gating + per-model system prompts. This is what makes answers
  YOURS: grounded in your vault, remembered, cited, honest.
- **THE SUBSTRATE (the body both faculties live in):** the model-agnostic substrate — System G, scope_rex/
  AnswerPacket, RuntimeRouter, uas/ACS-admission, eml_rerank, recall/Eidos, ModelVaults/KnowledgeFusion,
  graph-engine, Halo/Shadow. Coordination + Knowledge are not separate apps — they're two faculties wired into
  ONE substrate, attaching at ONE point (the unification "real prize").
- **ENGINE-LANES (interchangeable muscles, adopted not built):** act=Osaurus, work=OpenCode, cloud
  (agent_loop.rs), local (LocalAgentLoop), MLX inference. Swappable under the orchestrator — kept SEPARATE on
  purpose (honest-capability gating), not merged.
→ **So: ONE brain (coordination + knowledge faculties) on one substrate, driving swappable engines.** Not
two rival brains — two faculties of one. The convergence = unifying them onto a single attach point + a single
orchestrator + a single inference chokepoint, so they stop drifting (the drift caused the Qwen/codex/<think> bugs).

## THE SEPARATE TRACK — the 70B / custom runtime / "new model brain-1"
This is the one thing that is NOT part of the current convergence, on purpose:
- The **from-scratch NEW MODEL** (SSM/Mamba-3, M0 interrupt, signal_bus, lattice-WBO, ternary/QAT) and the
  **70B** are HARD OFF-LIMITS for the autonomous build + are a SEPARATE, future research track — a potential
  future "third brain" (a model you'd own end-to-end), distinct from the current model-agnostic substrate +
  adopted-engine direction.
- **Why separate:** the current convergence is deliberately MODEL-AGNOSTIC (route to ANY model — local Gemma/
  Qwen/VibeThinker, cloud, Fugu). The 70B/new-model is about OWNING a model. Those are different bets. The app
  works fully WITHOUT the 70B (it routes to existing models); the 70B would later become one more (powerful)
  lane in the pool. **It converges LATER as a pool member, not as the architecture.**
- **OPEN OWNER DECISION (flagged, not blocking):** is the 70B/custom-runtime still wanted, and when does it
  re-enter scope? Today it's off-limits + deferred; the architecture has a clean slot for it (another engine-
  lane) when you choose. No conflict — just sequenced out of the current build.

## WHY YOU "ONLY SAW EIDOS WORK ONCE" (grounded — this is a real bug, now in the plan)
The unification research found it: the LIVE `eidos.query` tool **bypasses the real `eidos/` module** and hits
VaultBackend ("Eidos-in-name-only", tools/knowledge.rs:244), AND the real eidos/ retriever is gated/fixture-
seeded. So Eidos memory is FRAGMENTED across 4 disconnected paths, none on the live decision path. That's
exactly why it worked once then not reliably — it was never truly wired live. **The brain-unification step
(UNIFY the IP brain onto one live attach point + route eidos.query through the real module) is the fix.** It's
folded into the plan (UNIFICATION verdict, "DELETE/FIX" + "unify the brain"). Finalizing Eidos = part of the
convergence, not a side quest.

## HOW IT ALL CONVERGES (the flow, end state)
User acts in **act or work** → the **one inference chokepoint** → **System G orchestrator** (TRINITY
Thinker/Worker/Verifier) asks **RuntimeRouter** to pick the best engine-lane/model for each subtask → the
**KNOWLEDGE brain** (Eidos/DAG/provenance) grounds + remembers + cites → the chosen **engine-lane** (Osaurus/
OpenCode/local/cloud/Fugu) generates → **provenance/honesty** gate the output → result streams back, same path
for every surface (main/mini/note/graph chat). One brain, one substrate, many swappable engines, two modes.

## IS IT ALL FOLDED INTO THE PLAN? — YES (audit)
All in docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md + the research docs it references:
- Osaurus act (clone+reskin), OpenCode work (real TUI, Bun bundled), Goose unique-bits, the two-mode UX,
  motion language, per-clone settings, vault-deep-integration pillar, Prose+MD-V2 coexist, model lab/Epistemos
  Picks, per-model system prompts, Tamagotchi, MAS dual-build, quarantine→delete chat, NEVER-IDLE,
  code-more-build-less, the P0 <think> regression, Fugu (provider + own-orchestrator), TRINITY (complete port,
  heuristic-first), the UNIFICATION verdict (one orchestrator/router/brain, keep-separate engine lanes), and
  THIS big-idea synthesis. The plan KNOWS it converges to a single thing: one brain + one substrate + swappable
  engines + two modes.

## CONFLICTS / GAPS / MISSING IP (finalization audit)
- **No architecture conflict found** — the pieces are layers, and "keep cloud/local engines separate" is the
  only deliberate non-merge (correct). The "one brain" + "one chokepoint" directives are consistent.
- **GAP 1 (decision): the 70B / custom-runtime / new-model brain-1** — currently off-limits/deferred; needs an
  owner decision on if/when it re-enters as a pool lane. Not blocking; slot reserved.
- **GAP 2 (build, in plan): Eidos not truly live** — finalize the brain-unification + real eidos.query wiring
  (the "worked once" bug). Tracked.
- **GAP 3 (license): TRINITY adapted-weights** — heuristic-route first, learned router after license clearance/
  re-derivation. Tracked, non-blocking.
- **IP CHECK — nothing missing:** the brain (Eidos/DAG/provenance/honesty/prompts), the editors (Prose 120fps +
  MD-V2), graph+Metal, model lab (QAT/Picks/per-model), motion/UI, vault-integration, the orchestrator-as-IP
  (TRINITY method) — all captured as IP-LAYER (kept/built, never commoditized). The substrate is the foundation;
  adopted engines are explicitly NOT IP (Osaurus/OpenCode/Goose).
- **FINALIZED:** the big idea is coherent, folded, and converges to ONE thing. The only true open item is the
  70B re-entry decision (owner), everything else is a build/sequence item already in the plan.
