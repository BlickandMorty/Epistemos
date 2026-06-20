# SUBSTRATE BUILD SEQUENCE — finish the model-agnostic substrate WITHOUT the new model / 70B (2026-06-20)

Owner decision (2026-06-20): Cursor's dual-brain research is DONE (not live) → the AGENT (loop) now BUILDS the substrate,
worked in-loop like every other slice. Complete the FULL substrate architecture **without the new model** (the dual-brain
SSM/M0 interrupt spine) **and without the 70B model** — everything else that is the app. Don't advertise the new model;
users see only the substrate. This doc is the consolidated, ordered, dependency-aware build plan (the EPDOC_MD_V2 equivalent
for substrate). Authority: Cursor's `docs/fusion/*` corpus (ARCHITECTURE_READOUT_2026_06_20, ARCHITECTURE_TIER_PROMOTION_CANON,
POST_RECOVERY_SUBSTRATE_V2_PLAN, SUBSTRATE_READY_FOR_V2, TURBOVEC_QAT_*) + the SS-SUB readout. Online research cycle pending
(web was down — RETRY to validate; local canon is authoritative per CLAUDE.md research-first).

## Do we have enough research to build it? YES.
The substrate is a coherent, honestly-tiered, falsifier-covered SPEC with the interfaces ALREADY in code and per-component
promotion stages already written. What remains is PROMOTION (T1→T4: wire + verify + make reachable), not greenfield. The
model-agnostic half runs on TODAY's models (MLX Qwen / small Gemma). Gaps are buildable + enumerated below.

## EXCLUDED — do NOT build (future / not the loop's): keep behind the seam, never advertised
- **The NEW MODEL (brain-1):** SSM/Mamba-3 generation, M0 interrupt gate (`F-Interrupt-Moves-Loss`), `signal_bus.rs`,
  lattice-WBO quant-safety, ternary/QAT brain-1, interrupt lease economics. (`agent_core/src/research/*` mamba3/active_assembly
  interrupt internals, Mamba2 Metal shaders.) These stay research-tier behind `LocalModelHandoff`; `AnswerPacket.attention_mode`
  stays `static_fallback`/`unavailable` until they land.
- **The 70B model** and any large-model-only path.
- **Companion→Osaurus clones** (still the owner's separate upcoming Cursor work — they will REUSE this substrate via the frozen
  interfaces; do not build the clones here).

## OPENED to the loop (model-agnostic substrate — build/promote to T4-green)
`agent_core/src/agent_runtime_v2/*` (System G runner), `agent_core/src/scope_rex/answer_packet.rs` (+ Swift mirror),
`Epistemos/LocalAgent/RuntimeRouter*.swift`, `agent_core/src/uas/*` ACS-admission (admission logic, not new-model lattice),
`agent_core/src/eml_rerank.rs`, `agent_core/src/cognitive_dag/*` (NOT companions.rs), `provenance/*`, recall/Eidos, and the
model-agnostic SubstrateHealthPanel rows. Honest tiering per the promotion canon (green only at T4: build-green + reachable +
AnswerPacket-visible + witnessed; never fake-green the excluded parts).

## The seam that makes this safe (build against it, freeze it FIRST)
- `SystemGAgentEvent::LocalModelHandoff` (`agent_core/src/agent_runtime_v2/system_g_runtime.rs:81-90`) — Rust owns route
  admission + witness; the model client (MLX today, new SSM later) plugs in here.
- `AnswerPacket.attention_mode ∈ {dynamic, static_fallback, unavailable}` — honest now, flips to `dynamic` when the new model
  lands, zero consumer rework, nothing user-facing says "new model."
- `RuntimeRouter` lanes — the new model is just a future lane.

## ORDERED BUILD (each phase: incremental, test-backed against the 2,679-suite + falsifiers, flag-gated, NO regression to the
## live chat path — respect the SS-CR credentials fix; commit-before-edit savepoint per SS-CLEAN)
- **Phase 0 — FREEZE INTERFACES [S].** Lock the AnswerPacket schema (wire-parity Swift mirror), the RuntimeRouter lane API,
  and the LocalModelHandoff contract. Add contract/round-trip tests. Everything downstream builds against these; the new
  model + clones attach later without rework. (This is the "harden so the agent can easily finish" keystone.)
- **Phase 1 — RuntimeRouter LIVE [M].** Promote STAGE 1b→4: make RuntimeRouter the live authority for TODAY's lanes
  (MLX/GGUF/Apple/cloud) behind `EPISTEMOS_RUNTIMEROUTER_LIVE_V0`, honest escalation log, no silent fallback. (Today:
  scaffolded, 0 live callers — `RuntimeRouter.swift:580` + `RuntimeRouterShadow.swift:27`.) Parity test vs current routing first.
- **Phase 2 — AnswerPacket END-TO-END [M].** Persist the per-turn receipt + claim FFI → T4 (today: rendered, not persisted).
  Durable, queryable provenance on every answer. Tests: persistence round-trip + UI chip render unchanged.
- **Phase 3 — System G real-provider wiring [M].** Drive the current-model providers behind `LocalModelHandoff` through the
  System G runner (today: deterministic V1 stub), emitting honest AnswerPackets (`static_fallback`). Falsifier-witnessed.
- **Phase 4 — Wire the model-agnostic health rows + SS-SH [S→M].** Eidos/VaultRecall/SearchFusion/EML-rerank/ACS-admission
  display/DAG-counts → live witnesses (or honest "fixture", never fake-green); fix the SS-SH blank sidebar (same panel).
- **Phase 5 — EML rerank + recall reachable [M].** Make EML re-rank reachable from the live vault path; W-51 shadow recall
  (model-agnostic retrieval) — build-plan → code.
- **Phase 6 — Surface reuse [M].** Every surface (chat/notes/graph/HTML/mini-chat) consumes the substrate via the frozen
  interfaces (AnswerPacket receipts visible, RuntimeRouter honest status) — the end-to-end reuse the owner wants. Cross-ref
  SS-VIS (capabilities on every surface).
- **Phase 7 — Honest substrate UX/explainer [S].** Make the substrate panel + any user-facing substrate text understandable
  (no new-model jargon; plain "honest, cited, verifiable local answers"). The owner + users find it foreign today.

## Constraints
NO new model, NO 70B, NO Companion-clone code. main-only; honest/no-green-without-witness; preserve thinking blocks + the
SS-CR routing fix; flag-gate live promotions; each phase its own SS-* sub-slice + tests when picked up. Worked in-loop at the
normal cadence (owner: "just work on it in loop like all the other things"). Cross-ref SS-SUB, SS-SH, SS-VIS, SS-CLEAN,
ARCHITECTURE_READOUT, ARCHITECTURE_TIER_PROMOTION_CANON.
