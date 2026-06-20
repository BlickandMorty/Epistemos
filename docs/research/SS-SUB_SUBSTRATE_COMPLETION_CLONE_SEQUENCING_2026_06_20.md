# SS-SUB — Substrate-health completion + the clone-sequencing contemplation (2026-06-20)

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
