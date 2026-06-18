# Non-70B Primitive Upgrades — deep-mine of Living Index + Lattice Explainer (2026-06-18)

Owner-mandated deep-mine for NON-70B, primitive-based, buildable LOCAL chat/agent/
memory/retrieval/routing upgrades (70B runtime stays owner-gated; no Hermes).
Sources: `docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md` (8,578 lines), the lattice
explainer (`docs/june 1/artifacts/lattice-coordinate-explainer/index.html`),
verified against `agent_core/src/research/*` + `uas/*` + `variant_ladder/` +
`lattice_wbo/`.

## ⚠ THE FIRST DOMINO (needs owner decision before the A/C/D/F batch)
The entire `agent_core/src/research/` tree is **`#[cfg(feature="research")]`,
default-OFF, NEVER compiled into the shipping app** (`build-agent-core.sh:24`
builds `--no-default-features --features "mas-build,lsp-runtime"` / `pro-build`).
So the cores are REAL + test-covered (1,800+ tests, zero stubs except 2 noted),
but a "win" = **(1) decide `research` compiles into the MAS/Pro lib (or promote the
module out of `research/`) + (2) UniFFI export in bridge.rs + (3) Swift call-site**
= M-size, not a free switch. **FLAG: get owner sign-off on the research-compile/
promotion policy first.** (Contrast: `lattice_wbo/` + `variant_ladder/` are
always-compiled live-path.) EML disambiguation re-confirmed: EML = elementary-math
IR `eml(x,y)=exp(x)−ln(y)`, not episodic memory.

## Tier-1 fast wins (real Rust + LOCAL + clear call-site; M each, modulo the domino)
- **A1 EML-2 ConfidenceRouter scoring** — `eml_integration/potential.rs:195`
  `EmlPotential::from_score` (AUC-preserving, 37 tests) → route to lowest
  confidence-potential model. `ConfidenceRouter.swift` (zero eml refs today).
- **A2 EML-3 VaultRecall re-rank** — secondary re-rank `eml(-log(bm25+ε),
  recall_fraction)`; ≥2pp on F-VaultRecall-50; `storage/vault.rs` (Rust-side).
- **A4 EML-1 FFI + EmlEnergyHealthRow** — `bridge.rs:4773` already reaches
  `observatory::summarize` (hardcoded 4-sample); promote to a real Settings row
  (visible determinism). S.
- **B1 T20 Variant Ladder** — `variant_ladder/mod.rs` (1023 LOC, LIVE) +
  `tools/vault_search_ladder.rs` (577 LOC, already wraps vault.search as a T3
  retrofit). Add tiers T2/T4-T6 (deterministic→embedding→classical→small/mid-LLM→
  cloud→defer) + a visible Swift routing surface. **Mostly live already.**
- **F1 Active Assembly minimizer** — `research/active_assembly/selector.rs:73`
  (MarginAnchoredGreedyPull, 15 tests) → wake the smallest sufficient context set
  before a turn (context-budget win).
- **F3 brain_routing (Sinkhorn)** — `research/brain_routing.rs:209` (real
  Sinkhorn-Knopp, 23 tests, 0 callers) → Birkhoff-polytope mode/lane routing.
- **F4 confidence_floors** — `research/confidence_floors.rs:172` (T1≥.85/T2≥.75/
  T3≥.70 cascade, 32 tests, 0 callers) → calibrated accept/escalate gate.
- **F5 interrupt_calibration** — `research/interrupt_calibration.rs:94` (Youden-J +
  AUROC, 29 tests, 0 callers) → calibrate the interrupt/escalation threshold
  (ties V6.1 interrupt-score).
- **F6 hybrid_memory** — `research/hybrid_memory.rs:140` (soul/skill/episode/
  semantic validators, 36 tests, 0 callers) → per-model native-memory-folder
  format (pairs with REG-6 chat-as-graph-node).
- **C1 info_ir→AnswerPacket.confidence** — `info_ir/mirror_descent.rs:87`
  (KL/Bregman, 397 tests) → wire into AnswerPacket.confidence.
- **D1 ternary KV-fingerprint + steering** — `research/ternary/` (3.5K LOC, 173
  tests — largest): `kv_fingerprint.rs`/`steering.rs`/`gemv.rs` → local KV/memory
  lane.

## Tier-2 (real but perf/proof/gated): A3 Tri-Fusion argmin, A5 EML corpus+Lean,
C2 geometry_ir rotor, C3 scan_ir SSD, C4 tropical, C5 operator_ir, C6 Primitive-IR→
Metal fusion, C7 action_to_eml, F7 attention_sinks, F8 hyperdynamic schema-repair
into the live agent loop, D2 Sherry/E8 VQ, G1 make WBO budgets actually gate
real approximation stages (today `direct_gate.rs:56` LatticeBudget always None).

## Tier-3 (real but capability-ceiling-gated — owner sign-off, must NOT move bytes
until gated): E1 LI-2 Residency PatternBoost (`uas/pattern_boost.rs`, 2610 LOC),
E2 LI-3 ColdStream transport (`uas/coldstream.rs`, 1381 LOC).

## NOT cheap (the only 2 real stubs): `research/ane_direct/` (only MockAneClient;
real ANE private-framework binding unwritten, Pro/Dev-ID); `sherry_lattice/
leech.rs:206` `nearest_leech_point_placeholder` (Z²⁴-rounding stand-in; E8/Sherry
paths around it are real).

## Build order recommendation
1. **Owner decision: research-compile/promotion policy** (the domino).
2. Then Tier-1 in order: B1 (most-live) → A2 (Rust-side, no FFI needed) → A1 → F4
   → F1 → A4 → F3/F5/F6/C1/D1. Each per-feature-hardened (own tests + HARDENED log).
3. Tier-2/3 after, gated as noted.
