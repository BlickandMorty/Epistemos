---
id: 3B145714-5C4E-4C9D-8CFC-26888776A799
title: SS-SUB_SUBSTRATE_COMPLETION_CLONE_SEQUENCING_2026_06_20
---

# SS-SUB — Substrate-health completion + the clone-sequencing contemplation (2026-06-20)

> **⚠️ SUPERSEDED 2026-06-20 (later same day) for the MODEL-AGNOSTIC SUBSTRATE.** This slice's "loop must NEVER build/wire …
> the IMPLEMENTATION is the owner's Cursor/clone work" wording was written BEFORE the owner authorized the loop to build the
> model-agnostic substrate in-loop ("just work on it in loop like all the other things, I just want it completed"). Current
> authority: `SUBSTRATE_BUILD_SEQUENCE_2026_06_20.md` + monitor SCOPE BOUNDARY + memory `project_substrate_build_authorized_2026_06_20.md`.
> The loop NOW MAY build System G / AnswerPacket(`scope_rex/answer_packet.rs`+Swift mirror) / RuntimeRouter / ACS-admission(`uas/*`)
> / EML(`eml_rerank.rs`) / cognitive_dag(except companions.rs) / provenance / recall-Eidos. STILL off-limits: NEW MODEL brain-1
> internals (SSM/Mamba/M0/`signal_bus.rs`/lattice-WBO/`research/*.rs`), the 70B, and Companion→Osaurus clones. Read the "loop NEVER"
> lines below as applying ONLY to that residual off-limits set, not to the model-agnostic substrate.

Owner: *"Much of the substrate health is unfinished stubs, not wired, etc. I really want to get that all working — idk if
before or after the clones, because the clones would want to use this IP and it'd be most advantageous to be done BEFORE
adding them, but idk… I really want to add them first though, because substrate is heavy backend work. So make sure this
nuance and contemplation is in the plan."* This slice captures (a) the substrate inventory split by BOUNDARY, (b) the
sequencing contemplation + a resolution, (c) what the loop may safely do now. Cross-ref SS-SH (the panel glitch),
SS-CLEAN (honesty/green-with-witness), the two scope-boundary domains.

## The substrate-health surface = ~25 rows in `Views/Settings/SubstrateHealthPanel.swift`
Rows (each a HealthRow with honest status): Eidos, VaultRecall, SearchFusion, EmlRerankGate, EditorBundle, LocalAgentDiagnostics,
SystemG, AnswerPacket, DeterministicSchemaGate, EmlRouteFusion, DeepResearch, NightBrainLoRA, ActOsaurus, LocalRouteHonesty,
WorkBackend, LiteParseImport, FalsifierArtifacts, FUlp, LatticeWBO, ACSAdmission, EmlObservatory, UasAcs, CognitiveDagCounts,
ActiveConstellation. The panel itself documents "fixture, status-only, and dependency rows stay" (`:8`) — i.e. SOME rows are
honest fixtures/status-only by design, others are real wired diagnostics. "Unfinished stubs / not wired" = the rows whose
backend is incomplete or whose status is a placeholder rather than a live probe.

## CRITICAL split — which substrate is the LOOP's vs the OWNER's (this resolves the contemplation)
The substrate rows fall on BOTH sides of the hard scope boundary:
- **OWNER'S CURSOR DOMAIN (loop must NEVER build/wire — this IS the clones' backend IP):** SystemG, AnswerPacket,
  LatticeWBO, ACSAdmission, EmlObservatory, UasAcs, NightBrainLoRA (dual-brain: M0/M1/bus/SSM/lattice/active_assembly,
  research/*.rs, answer_packet.rs, signal_bus.rs) + ActOsaurus, WorkBackend (Companion→Osaurus: ActOsaurus/*, Vendor/Osaurus/*,
  LocalModelServer.swift). The CLONES reuse exactly this substrate, so "substrate before clones" for THESE = the OWNER's own
  Cursor work, not the loop's.
- **LOOP-SAFE (non-boundary — loop MAY complete/wire honestly):** Eidos, VaultRecall, SearchFusion, EmlRerankGate,
  EditorBundle, LocalAgentDiagnostics, DeterministicSchemaGate (verify), DeepResearch, LiteParseImport, FalsifierArtifacts,
  FUlp, CognitiveDagCounts, ActiveConstellation, LocalRouteHonesty. These are general substrate/diagnostics, not the clone IP.

## The sequencing contemplation — resolved (and why the loop isn't blocked either way)
The owner's dilemma is "substrate-before-clones (cleaner, clones reuse it) vs clones-first (substrate is heavy)." Key
realization: **the substrate the clones depend on IS the owner's Cursor/boundary domain.** So:
- **Option A — substrate-before-clones:** advantageous (clones sit on solid backend), BUT that backend (SystemG/lattice/
  AnswerPacket/ACS/ActOsaurus…) is the OWNER's to build in Cursor; the loop can't do it. So "before" means more owner
  Cursor work first.
- **Option B — clones-first (owner's lean):** add the clones on the current substrate, then harden substrate. Risk: clones
  built on stub substrate may need rework when the substrate firms up; mitigate by keeping the clone↔substrate seam
  contract-stable (the clones depend on substrate INTERFACES, not internals, so the backend can firm up behind a stable API
  without reworking the clones).
- **RECOMMENDATION (owner decides — this is a preference/architecture call, not a safety gate):** clones-first is viable IF
  the clone↔substrate boundary is an interface/contract (so substrate can be completed behind it later). Define/freeze that
  interface BEFORE the clones so Option B doesn't cause rework. Either way, the LOOP is unblocked: it independently completes
  the LOOP-SAFE substrate-health rows (honesty + wiring) regardless of clone timing — that work neither blocks nor collides
  with the clones (different files; boundary respected).

## What the LOOP does now (NON-boundary, anytime)
1. Honest audit of the LOOP-SAFE rows: which are live probes vs placeholders vs genuinely-honest fixtures (the panel already
   intends some to be status-only — do NOT fake those green; just make their status truthful). Cross-ref SS-CLEAN green-with-witness.
2. Wire the unwired loop-safe rows to their real backend signal where one exists (Eidos/VaultRecall/SearchFusion/LiteParse/
   CognitiveDagCounts/EditorBundle diagnostics), or mark honestly "not yet wired / fixture" — never a misleading green.
3. Fold in SS-SH (the blank-sidebar glitch is the same panel surface).
NEVER touch the boundary rows' backend (SystemG/AnswerPacket/lattice/ACS/ActOsaurus/WorkBackend/NightBrain) — only their
read-only display is fine; their IMPLEMENTATION is the owner's Cursor/clone work.

## Decision owed to owner (flag, don't force)
The clone-vs-substrate ORDER is an owner preference. DEFAULT per the no-deferral rule's "owner-preference" exception: proceed
with what's loop-safe now (non-boundary substrate honesty), and leave the boundary-substrate + clone ordering to the owner.
If the owner wants the clone↔substrate INTERFACE frozen first (to make Option B safe), that's a small design task the owner
can do in Cursor or ask the loop to draft (interface-only, non-boundary). Cross-ref SS-SH, SS-CLEAN, RESEARCH_FINALIZATION_INDEX.

---

## DEEP RESEARCH v2 — substrate WITHOUT the new model, made understandable (owner 2026-06-20)
Owner: *"This needs research cycles — deep nuanced research; even the informative stuff is foreign to me and users. I'm not
worried about the dual brain rn: if I need the NEW MODEL, I don't want surfaces to depend on that part — they can use all
other things but NOT require a new model (that takes a long time). Basically everything from the substrate + that entire
ontology WITHOUT the new model, and DON'T advertise it as the new model (users shouldn't see new-model-specific things, just
the substrate). The substrate should be completed END-TO-END and reusable by the other surfaces. Multiple cycles of research
(local first, then online) to harden it so the agent builder can EASILY finish it. I really want the substrate finished
BEFORE the other things if beneficial — idk how long; let's deliberate."* + *"remember all the research Cursor did for dual
brain — look at its local research, all the docs/folders it created/iterated."*

Research cycle 1 = LOCAL (done): Explore over Cursor's corpus — **136 `docs/fusion/*` docs** (authoritative; the owner's
Cursor work) incl. `ARCHITECTURE_READOUT_2026_06_20.md` (the spine), `RESEARCH_INTENT_AND_QUERY_LOG_2026_06_20.md`,
`RESEARCH_LOOP_LEDGER_2026_06_20.md`, `SESSION_CHECKPOINT_2026_06_20.md`, the canons (`ARCHITECTURE_TIER_PROMOTION_CANON`,
`TURBOVEC_QAT_RUNTIME_AGNOSTIC_INTAKE`, `MLX_QAT_TURBOVEC_LOCAL_SUBSTRATE_RESEARCH`, `UNIFIED_ACTIVE_SUBSTRATE_CANON`,
`ADDRESSABLE_NEURAL_SUBSTRATE_CANON`, `POST_RECOVERY_SUBSTRATE_V2_PLAN`, `SUBSTRATE_READY_FOR_V2`) + the code. Cycle 2 =
ONLINE: web search was UNAVAILABLE this pass — RETRY later to validate the decouple-behind-interface pattern (the local canon
is authoritative regardless per CLAUDE.md research-first rule).

### Plain-English explainer (the substrate is foreign because half of it is a future model's spec)
The substrate = **brain-2** (the app's governance/verification/authority machinery) + the **Rust bus**. Its job: take ANY
model's raw output and make it an HONEST, CITED, VERIFIABLE, rollback-safe answer. Organs (1 line each):
- **System G** = the run harness (request → plan→tools→tokens event stream → receipt). **AnswerPacket** = the receipt on
  every answer (claims, citations, a UI label, a witness ref). **RuntimeRouter** = picks which runtime/lane runs it
  (MLX/GGUF/Apple/cloud), honest escalation, no silent fallback. **SovereignGate** = biometric/consent gate. **EML** =
  retrieval re-rank + numeric sanity oracle. **ACS-admission** = the bouncer for what context is allowed in. **Cognitive
  DAG / recall / Eidos** = the memory + provenance graph. — These are **model-agnostic** and run on TODAY's models.
- **SSM/Mamba-3, the interrupt gate (M0), signal_bus, lattice-WBO safety, ternary/QAT** = **brain-1 = the NEW MODEL** —
  research-tier, unproven (M0 `F-Interrupt-Moves-Loss` not yet proven; bus is a spec; no tokens generated yet). This is the
  slow part the owner means.

### THE RESOLUTION (this dissolves the owner's tension)
The substrate was DESIGNED model-agnostic. The new model is isolated to brain-1 and plugs in behind an EXISTING seam:
- **`SystemGAgentEvent::LocalModelHandoff`** (`agent_core/src/agent_runtime_v2/system_g_runtime.rs:81-90`) — "Rust owns route
  admission + witnessed policy; the Swift host owns the live local model client." The model (MLX today, new SSM later) is
  swappable behind this.
- **`AnswerPacket.attention_mode ∈ {dynamic, static_fallback, unavailable}`** — with today's models it honestly reports
  `static_fallback`; when the new SSM lands it flips to `dynamic` — SAME struct, ZERO consumer rework, and **nothing
  user-facing says "new model"** (it just says the substrate's honest state). This is exactly the owner's "don't advertise
  the new model."
- **RuntimeRouter** already abstracts lanes ("MLX is one lane among several"); the new SSM is just another lane later.
**So "everything from the substrate + ontology WITHOUT the new model" is achievable NOW:** drive the substrate end-to-end
with current MLX/Gemma behind `LocalModelHandoff`, emit honest AnswerPackets, promote RuntimeRouter to live, wire the
model-agnostic rows, and **FREEZE the AnswerPacket / RuntimeRouter / LocalModelHandoff interfaces**. Other surfaces
(chat/notes/graph/HTML) reuse the substrate via those interfaces. The new SSM is a future lane behind the frozen seam —
unadvertised, no rework.

### Sequencing answer (substrate-first IS viable and beneficial — because it does NOT need the new model)
The owner feared "substrate-first = slow (new model)." FALSE for the model-agnostic substrate: it doesn't need the new model,
so substrate-first is **fast + beneficial** (every surface + the clones reuse a solid, interface-frozen substrate with no
rework). RECOMMENDATION: **do the model-agnostic substrate completion + interface-freeze FIRST**, run the new-model (brain-1)
research on its own slow track behind the frozen seam, never advertised. Estimate: the model-agnostic completion is
promotion/wiring of largely-existing code (T1→T4), not greenfield — weeks-scale, not the months-scale new-model effort.

### Boundary reality (who does it) — the open decision
Most of the high-value substrate completion (RuntimeRouter promotion STAGE 1b→4, AnswerPacket persistence + claim FFI, System
G real-provider wiring) lives in `agent_core/src/*` which is the OWNER's Cursor/dual-brain domain per the standing boundary +
saved memories. So the question is WHO finishes it:
- **Loop-safe NOW (no decision needed):** the diagnostic/retrieval rows (Eidos/VaultRecall/SearchFusion/LiteParse/DAG-counts/
  EditorBundle), the SS-SH blank-sidebar, and the owner-facing EXPLAINER (make the substrate panel + docs understandable, no
  new-model jargon). The loop can also DRAFT the interface-freeze spec (interface-only, non-implementation).
- **Needs owner decision (scope reversal):** whether the LOOP may build the model-agnostic substrate backend (RuntimeRouter
  promotion, AnswerPacket persistence, System G wiring) — that opens part of the previously-Cursor domain to the loop — OR
  keep that as owner-Cursor work with the loop only enabling it via the explainer + interface-draft + loop-safe rows.
This is the deliberation the owner asked for; the scope/sequencing fork is posed to the owner (AskUserQuestion).