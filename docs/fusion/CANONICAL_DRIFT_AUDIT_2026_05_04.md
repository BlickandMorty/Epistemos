# Canonical drift audit — 2026-05-04

Compares the original Epistemos vision (per `FINAL_SYNTHESIS.md`,
`PLAN_V2.md`, `EPST_UNIFIED_SUBSTRATE_MASTER_PLAN_V2_SCOPE_REX_2026_05_01.md`,
`COMPASS_ARTIFACT_2026_04_26.md`, and the user-authored `jordan's research/`
canon — all now lifted into `docs/fusion/research/`) against the CURRENT
shipped substrate.

**Bottom line**: ~65% MATCHES the original vision · ~15% SUPERSEDES
(ships beyond original) · ~15% DRIFTED (diverges) · ~5% MISSING.

The 3 highest-impact drifts are flagged at the top so V2.1 sub-plan can
either close them or explicitly accept them.

---

## §1. The 3 highest-impact drifts (act before V2.1)

### Drift A — Live File Compiler (Wave 7) deferred to indefinite

`FINAL_SYNTHESIS.md §1` pivots the original "markdown directly executes"
framing to "compiled signed LivePlan is law" — Wave 7 first-class
executable primitive. Current docs (`COGNITIVE_KERNEL_DOCTRINE`,
`POST_RECOVERY_SUBSTRATE_V2_PLAN`) **don't mention Live Files at all**.
No timeline. No row in `SUBSTRATE_TRACK_REGISTER`.

**Direction**: deferral. This is a Wave 7 feature; current substrate
sequence is V2.1-V2.7 then V3 (Helios). Wave 7 has no carrier.

**Action**: either (a) add a Wave-7 row to the Track Register with an
explicit "behind V3" note, or (b) demote the Live File Compiler in
`FINAL_SYNTHESIS.md` to "research-tier" and stop letting future agents
treat it as canon.

### Drift B — Cognitive Weight Class System (4-tier) collapsed to monolithic search tuning

`FINAL_SYNTHESIS.md §3` specifies four tiers with policy-grade gating:
`soft_memory` / `preferred_context` / `strong_project_anchor` /
`policy_grade`. Each tier has different retrieval-bias ranges + write
authority. Current Track Register T8 (Halo §160-168) mentions "RRF
fusion at k=60" + "recency boost" but **no weight class semantics**.
The four-tier authority model is gone.

**Direction**: scope reduction. Original was rich; current is coarse.

**Action**: explicitly note in `COGNITIVE_KERNEL_DOCTRINE` whether the
weight-class system is (a) deferred to V2.5+ Halo work, (b) replaced by
the simpler RRF k=60 model, or (c) recoverable in V3. Right now the
silence reads as "lost," not "deliberate."

### Drift C — Variant Ladder (Plan §1.4 No-LLM-First A→B→C→D) missing from dispatcher

The new `agent_core/src/route/{variant_a,b,c}.rs` modules implement
the route-capture variant ladder for **structure routing** (a separate
narrow domain). `Plan §1.4`'s broader variant ladder discipline (every
tool starts with a deterministic predecessor, escalates only when the
predecessor underdelivers) has no equivalent in `agent_core/src/dispatcher.rs`
or the ChatCoordinator orchestrator path.

**Direction**: principle was wider than implementation captured.

**Action**: lift the variant-ladder discipline into a doctrine doc
(`COGNITIVE_VARIANT_LADDER_DOCTRINE_2026_05_05.md` or similar) so future
work that adds tool routing knows to honor it. Verify the existing
route-capture ladder is the canonical reference implementation.

---

## §2. Subsystem-by-subsystem audit

| Subsystem | Verdict | Evidence (current vs original) |
|---|---|---|
| **The Reflective Loop (Layers 1-7)** | SUPERSEDES | FINAL_SYNTHESIS §2.1-2.2 framed as philosophical scaffolding; current code architecturally instances it (Layer 6 = `agent_core/src/mutations/envelope.rs` + `provenance/ledger.rs`; Layer 4 = SovereignGate; Layer 7 = nightbrain canonical task registry) |
| **Live File Compiler (Wave 7)** | DRIFTED | See §1 Drift A above |
| **Cognitive Weight Class System (4-tier)** | DRIFTED | See §1 Drift B above |
| **The 7-Verb MCP Graph Boundary** | MATCHES | `omega-mcp/src/graph_tools.rs:12` `const GRAPH_TOOL_NAMES: [&str; 7]` exact spec match (search_semantic / search_fulltext / get_node / traverse / create_node / create_edge / commit_session). Vault-scoped UniFFI confirmed. b118d361 added pluggable backend trait + deterministic BM25/trigram scoring. |
| **Provenance Plane (MutationEnvelope + ClaimLedger + RetractionPropagated)** | MATCHES | All three exist in main: `agent_core/src/mutations/envelope.rs`, `agent_core/src/provenance/ledger.rs:222`, `LedgerEvent::RetractionPropagated` shipped in c78deb17. Swift mirrors at `Epistemos/Models/MutationEnvelope.swift`. Parity tests pinned. |
| **Cognitive DAG (Phase 8 sub-phases A-H)** | POSTPONED | Doctrine doc written; implementation gated on "kernel Phases 1-7 + 2 weeks CI green" per V2 plan. Phase 8.A keystone (RetractionPropagated + budget_gate) shipped this session but full DAG awaits V2.1 RESUME signal. |
| **Variant Ladder (Plan §1.4 A→B→C→D)** | DRIFTED + PARTIAL | Route-capture domain: implemented (`route/variant_a/b/c.rs` + b118d361 deterministic scorers + beebfb79 default classifiers + 720552c5 default factory). Broader principle: missing (see §1 Drift C). |
| **Kernel Doctrine Phases 1-7** | MATCHES | One agent loop, one memory store, one provenance ledger, one skill registry, one privilege boundary — all confirmed. Recovery loop closed Stages A-F per `RECOVERY_LOOP_FINDINGS_2026_05_04`. |
| **A2UI Catalog (~25 components)** | PARTIALLY SHIPPED | Seed in commit 58b3d14b: `Epistemos/A2UI/` with `A2UICatalog.allComponents == [.noteCard]`, `A2UIValidator`, no AnyView fallback, schemars schema in Rust. 1 of ~25 components shipped; full expansion deferred to V2.6 UI work per Track Register. |
| **NightBrain (10 canonical tasks)** | PARTIALLY SHIPPED | Infrastructure: `agent_core/src/nightbrain/live.rs` (b0d229be) + Swift `NightBrainLiveRegistry` (720552c5). All 10 task names registered. Real task BODIES are NoOp placeholders; replace incrementally per slice. |
| **Honest Handle FFI** | MATCHES | `RustShadowFFIClient.swift:15` uses `@_silgen_name("shadow_handle_open_at")` — new honest handle. Doctrine doc at `HONEST_HANDLE_FFI_DOCTRINE_2026_05_04.md`. |
| **Sovereign Gate Coverage** | MATCHES | Single LAContext owner (Track Register T2). Action-class matrix (Trivial / Reversible / Sensitive / Destructive / Sovereign) honored. budget_gate route added in c78deb17. |
| **Helios v3 + SCOPE-Rex (V3 ultimate goal)** | POSTPONED | V3 research tier; gated on "RESUME RESEARCH TIER" signal + Week-0 ternary experiment. User-authored canon now in `docs/fusion/research/user-authored/{helios v2.md, helios v3.md, scope rex.md, scope rex omega.md, ternary kernel.md}`. |
| **Skill Discovery (Voyager-style)** | POSTPONED | Tier C salvage at `salvage/from-vigorous-goldberg/agent_core_src/skill_discovery/`. DAG-blocked per triage. |

**Tally**: 6 MATCHES · 1 SUPERSEDES · 3 DRIFTED · 0 MISSING (was 1 — Variant Ladder is now PARTIAL after the route-capture deterministic implementations) · 4 POSTPONED.

---

## §3. Research lifted into `docs/fusion/research/` this pass (commit pending)

177 files now indexed. Key additions per the disk-scan agent's
exhaustive findings:

| Subdir | Count | What |
|---|---|---|
| (top level) | 11 | PLAN_V2 / FINAL_SYNTHESIS / SCOPE-Rex master / COMPASS / 6 iCloud architecture specs + master quant + RESEARCH-REFERENCE-v2 |
| `user-authored/` | 10 | jordan's research: helios v2/v3, scope rex (+ omega), gate register, codex prompt, ternary kernel, deterministicapp, mac store edition, hermes |
| `okcomputer/` | 10 | OKComputer Global Research Consortium: FINAL_CONSENSUS_REPORT + plan + 8 prof_*_findings |
| `icloud-loose/` | 10 | recon_dim03-05, landslide_dim08-10, helios_shadow_memory, epistemos_resonance_gate, ternary_code_scaffolds, XPC |
| `quickcapture-addenda/` | 3 | BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT + OBSCURA_BROWSER + LIVE_FILES_AND_SUBSTRATE addenda |
| `kimi-latest/` | 7 | Kimi(2): SIMULATION_MODE_V16_SUMMARY + epistemos_{capstone_unified, definitive_master, final_master_specification, mas_release} + helios_shadow_memory + hermes_gateway_architecture |
| `cms-doctrine/` | 3 | CMS-X-final + CMS-X-v3 + CMS-v2-Final-Definitive |
| `lets-start-here/` | ~120 | User's "intentional priority" folder (My mind 2/LETS START HERE/) including AppBootstrap.swift snapshot + brain dump + guides + how tos + ideas + wisdom |

---

## §4. Research still off-disk (pointed at, not lifted)

These are too large to absorb into the repo wholesale; future agents
read directly from source paths:

- `~/Downloads/Kimi_Agent_Deterministic AI Deep Dive (3).zip` (May 3) — UNEXTRACTED
- `~/Downloads/Kimi_Agent_Deterministic AI Deep Dive (4).zip` (May 4 18:37) — UNEXTRACTED
- `~/Downloads/Kimi_Agent_Deterministic AI Deep Dive (5).zip` (May 4 18:45) — UNEXTRACTED
- `~/Library/Mobile Documents/com~apple~CloudDocs/OKComputer_Deterministic_AI_Deep_Dive.zip` (May 4 18:36) — UNEXTRACTED
- `~/Library/Mobile Documents/com~apple~CloudDocs/research/OKComputer_Deterministic_AI_Deep_Dive/` (full UASA + OSFT + PSOFT + COSO research, ~50 files)
- `~/Downloads/Kimi_Agent_Deterministic AI Deep Dive/` and iCloud sibling (38 MB / 376 files each — UASA agent + memory breakthrough sections)
- `~/Documents/Epistemos-QuickCapture/` (4.7 MB — addenda lifted; CATCHUP_PROMPT / AUDIT_PROMPT / BUILDER_PROMPT / INDEX / older PLAN remain)
- `~/Downloads/release/new agents/` (~8 hermes/agent integration research files)
- `~/Downloads/release/reference research for features to return to/` (21 deferred-feature docs)
- `~/Downloads/last feature after new agents/` (LIVING_VAULT + OPERATOR_MANUAL + sprint-omega-5)
- `~/Downloads/new make sures/` (Architectural Hardening Total Victory Plan)
- `~/Downloads/meta-analytical-pfc/` (full PFC subproject with brainiac-2.0)
- `~/Downloads/LivingBrain/` (actual Rust crate scaffold)
- `~/Downloads/epistenos_os_scaffold/` (pre-extracted scaffold; Cargo workspace)
- `~/Downloads/Kimi_Agent_Deterministic AI Deep Dive (2)/epistenos/` — Rust + Swift reference implementation matching Sovereign Gate doctrine
- `~/Downloads/audit/` (March 2026 pruning audit pack)
- `~/Downloads/Advice/` (Claude/Gemini/GPT/Perplexity papers)
- `~/Downloads/old research/` (TurboQuant + Mamba + MoLoRA + MLX Constrained Decoding)
- `~/Downloads/fluid/` (6 fluid landing-wave docs)
- `/Users/jojo/codex-full-snapshot-20260503-154858.tar.gz` (2.32 GB — full Codex env snapshot)
- `~/Library/Mobile Documents/com~apple~CloudDocs/Epistemos.zip` (1.87 GB — old repo snapshot, pre-recovery)

---

## §5. What the audit changes for V2.1

When the user types `RESUME SUBSTRATE V2`:

1. **Phase 8.A first deliverable** stays as already framed (extend
   ledger + ProvenanceConsole). Most provenance keystone work is done.

2. **Add an explicit Wave-7 / Live File Compiler decision** to V2.x
   plan — either accept deferral with a row in the Track Register or
   demote the Live File Compiler from canonical to research-tier in
   `FINAL_SYNTHESIS`.

3. **Make a deliberate decision on the Cognitive Weight Class System** —
   collapse it, defer it explicitly, or pull tier semantics into the
   T8 Halo work.

4. **Lift the Variant Ladder discipline** from `Plan §1.4` into a
   doctrine doc so future tool routing honors it. The route-capture
   ladder is the reference implementation.

5. **Read the user-authored `jordan's research/` canon** before the
   V3 RESEARCH TIER signal — it's the user's own framing of Helios v3
   + SCOPE-Rex + ternary kernel and supersedes any prior V3 framing.

The rest of V2.1 stays on track. The audit reveals the substrate is
in much better shape than older docs suggest, with two specific
deferred features (Live Files, Weight Classes) that need explicit
disposition before the Cognitive DAG lands on top.

---

## §6. Future audit hygiene

- Re-run the disk scan every 1-2 weeks; the user's research output
  cadence is high (3 new Kimi zips in 24 hours on May 3-4).
- Lift small individual files into `docs/fusion/research/<category>/`
  immediately on discovery.
- Big archives stay out-of-tree; index by path only.
- The `RESEARCH_INDEX_2026_05_04.md` + this drift audit are the two
  doc surfaces future Codex runs read first when picking V2.x or V3.x
  work.
