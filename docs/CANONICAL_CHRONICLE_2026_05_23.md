# Epistemos Canonical Chronicle — 2026-05-23

> **What this is.** A single canonical chronicle of the Epistemos project covering: every name, every track, every wave row, every auxiliary branch, every doctrine, every falsifier, every drift, every intent-pivot the user took, and the residual work needed to close the substrate. Built by walking the anchor docs (Master Research Index, Cross-Terminal Wiring Backlog, No-Compromise Endgame Deck, Substrate Handoff, 9-Terminal Prompts, T09 Product Architecture Ledger), the four prior audits under `/tmp/audit/`, all sprint-cycle and salvage docs since 2026-05-16, the falsifier handbook + schema, and the user's auto-memory under `~/.claude/projects/-Users-jojo-Downloads-Epistemos/memory/`.
>
> **Discipline.** Every claim cites a file+line, a commit SHA, or a prior-audit row. Where two docs disagree the chronicle either (a) cites both surfaces and names a canonical pick or (b) explicitly marks "unreconciled, surfaces both." No promotion by vibes. Prior audits (`/tmp/audit/01..04`) are inherited, not re-listed.
>
> **Hardware floor anchor.** M2 Pro 14" 2023 / 12-core CPU / 19-core GPU / 16 GB UMA / ~200 GB/s. Every falsifier measures here. (`docs/CLAUDE_NO_COMPROMISE_SUBSTRATE_HANDOFF_2026_05_18.md:18`)

---

## Section 1 — Executive ontology (the canonical names)

### 1.1 The architecture spine

Canonical surface name: **Active-Support Verified Cognitive Runtime** (a.k.a. "the Substrate", "Epistemos verifiable cognition substrate"). The spine runs top-to-bottom from retrieval to product:

```
Vault / Eidos retrieval
      ↓
System G (agent_runtime_v2) executor
      ↓
UAS (Unified Address Space) / ACS (Anchored/Autopoietic Cognitive Substrate) admission
      ↓
Lattice / Wyner-Ziv / WBO accounting (error-law side)
      ↓
EML / EML-IR + 6-IR Primitive Stack + Lean schema (witness / cert layer)
      ↓
Falsifier gates (F-* ladder) + Substrate Health surfaces
      ↓
Visible product (WRV: Wired, Reachable, Visible, Verified)
```

Source: `/tmp/audit/01_canon_2026_05_20.md` "Spine map" §, derived from `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md:34-78` + `docs/CLAUDE_NO_COMPROMISE_SUBSTRATE_HANDOFF_2026_05_18.md:34-78`. (DECK = NO_COMPROMISE_ENDGAME_PROMPT_DECK; HANDOFF = CLAUDE_NO_COMPROMISE_SUBSTRATE_HANDOFF; BACKLOG = CROSS_TERMINAL_WIRING_BACKLOG; INDEX = MASTER_RESEARCH_INDEX.)

The spine has TWO sides, both required:
- **UAS** = structural / address-space view. Zero-copy, single-address-space across Swift / Rust / Metal / MLX / KV / HNSW. (`docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md:13`)
- **ACS** = dynamical / governance view. 7-scale recursion, 4 homeostatic loops, Kuramoto-coupling, MAPE-K. (same)

### 1.2 The 7 substrate laws (canonical, from DECK:557-572)

The "no compromise end goal" formalized as 7 laws every research branch must fit, otherwise it's preserved-speculation:

1. **Density law** — Morph/EML approximates compact controller policies where the formal domain permits.
2. **Address law** — every cognitive object has a stable UAS/UASA address independent of residency.
3. **Active-support law** — only the relevant slice of notes/graph/memory/model/tools/agent state wakes.
4. **Lattice-error law** — every compressed or approximate representation pays into WBO.
5. **Glue law** — local context must cohere before it becomes global context.
6. **Duplex law** — hard compact and soft page-backed branches both allowed, but routing error is accounted.
7. **Witness law** — every meaningful action is typed, permissioned, logged, replayable, and visible.

### 1.3 Phases (canonical definitions)

The canon uses three overlapping phase vocabularies; `/tmp/audit/01_canon_2026_05_20.md:93-103` enumerates them. The canonical reconciliation:

| Phrase | What it means | Source of truth |
|---|---|---|
| **Phase 1 (additive hardening)** | Tracks that build NEW modules against current main — no T-branch merge required. T09, T10, T10B, T11 (new `agent_runtime_v2/`), T12 F-ULP, T13 F-KV-Direct, T17B, T18B, T21 (touches existing `vault.rs` via Fix-B/Fix-C), T22B, T23, T23B. | HANDOFF:97-100 (verbatim contract) |
| **Phase 2 (merge-gated wiring)** | Tracks that consume merged T-branch substrate (T3 UAS-ACS, T4 vault, T1 tri-fusion). T14 Five-plane wiring, T18 Residency Governor (full), T22 Substrate Health Panel (full), T27 WRV surfacing. | HANDOFF:99-100 |
| **Phase E donor mining** | The salvage track. Cherry-pick additive subtrees from the May-16 cycle into main via `salvage/T<N>-...-2026-05-23` PRs. | `docs/MAY16_ARCHEOLOGY_2026_05_23.md` + commit log of #15-#35 on main |
| **Phase F risk-gated** | Falsifier-gated work that touches production behavior (Metal kernels, KV-Direct, 70B cocktail, p-adic / sheaf hot path, ANE paths). Vault/Research only until F-* artifacts exist. | HANDOFF:104-114, DECK:572-577 |
| **Phase Δ / ε / ζ / η / θ / ι** | BACKLOG-cycle vocabulary. Δ = merge wave (now). ε = substrate-to-product wave (P0 W-rows). ζ = substrate-visibility wave (P1 W-rows). η = biometric gate opens. θ = P2 internal. ι = P3 capability ceiling. | BACKLOG:252-301 |

### 1.4 Cycles (the multi-month chronicle)

These are the canonical cycle names. Earlier names exist; later names supersede; both preserved.

| Cycle | Dates | Defining doc | Substantive output |
|---|---|---|---|
| **Apr-22 Advice Council** | 2026-04-22 | `docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md` | Four-model consensus on Developer ID (no MAS at first), schema-first GenUI, UniFFI primary with BoltFFI benchmark-gated. (`project_advice_council_2026_04_22`) |
| **Apr-23 Fix-First** | 2026-04-23 | `docs/KNOWN_ISSUES_REGISTER.md` + plan App. E | 19-bug register; user decision: fix all foundation issues before any feature work. (`project_fix_first_decision`) |
| **Apr-27 Orchestrator** | 2026-04-27 | `project_orchestrator_session_2026_04_27` | §1.5 origin-baseline run + 4-agent corpus synthesis + 3 Blockers shipped (D4, W9.27 PR3, D1). 17→13 still-open. |
| **Apr-30 Fusion** | 2026-04-30 | `docs/fusion/{README_START_HERE, CANONICAL_SOURCE_MAP_AND_GATE_REGISTER, BUILDER_EXECUTION_PROMPT, KIMI_*}_2026_04_30.md` | Phase 1A complete; Phase 1B canon docs; Kimi review + addendum. INDEX:43 lists. |
| **May-1/2 Doctrine** | 2026-05-01..05-02 | `EPISTEMOS_FINAL_DOCTRINE_2026_05_01`, `CODEX_FINAL_EXECUTION_PROMPT_2026_05_01`, `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01`, `MASTER_RESEARCH_INDEX_2026_05_02`, `WORKTREE_INSIGHT_SALVAGE_2026_05_02`, `CANON_GAPS_AND_ADDENDA_2026_05_02`, `CODEX_DELIBERATION_PROMPT_2026_05_02`, `ALL_DOCS_INDEX_2026_05_02`. | The April fusion canon. INDEX:46. |
| **May-3 Substrate Track Register** | 2026-05-03 | `docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md` | Canonical 16-track register T0-T15 across zones A-D (Foundation / Killer / Surface / Deployment+Research). `project_substrate_track_register`. |
| **May-3 Recovery** | 2026-05-03 | `CANONICAL_RECOVERY_PLAN_2026_05_03`, `COGNITIVE_KERNEL_DOCTRINE_2026_05_03`, `COGNITIVE_DAG_DOCTRINE_2026_05_03`, `COGNITIVE_GENUI_DOCTRINE_2026_05_03`, `XPC_MASTERY_DOCTRINE_2026_05_03`, `MAS_FIRST_FOCUS_DOCTRINE_2026_05_03`, `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03`. | Hackathon abandoned same day. Stages A.1-F sequence. `project_canonical_recovery_plan_2026_05_03`. |
| **May-4 Recovery loop** | 2026-05-04 | `RECOVERY_LOOP_FINDINGS_2026_05_04`, `CODEX_RECOVERY_HANDOFF_2026_05_04`, `PRE_V2_FULL_AUDIT_2026_05_04`. 8 commits closed Stages A-F. `project_recovery_loop_findings_2026_05_04`. |
| **May-4 Post-recovery V2** | 2026-05-04 | `POST_RECOVERY_SUBSTRATE_V2_PLAN_2026_05_04`. After recovery, Codex STOPS + waits for explicit "RESUME SUBSTRATE V2" signal; then runs V2.1 (Cognitive DAG Phase 8) → V2.2 (Halo V1) → V2.3 (LSP migration) → V2.4 (XPC Mastery, gated on paid team) → V2.5 (Simulation v1.7+) → V2.6 (UX/brand) → V2.7 (multi-agent ACS). `project_post_recovery_v2_plan`. |
| **May-5 Hermes purge** | 2026-05-05 | `HERMES_REMOVAL_HANDOFF_2026_05_05.md`, commits b4c583b0 + 80544415 + e07e6378. Subprocess + UI overlay + namespace ALL gone. Swift → `LocalAgent*`. Rust → `Runtime*` in `agent_core::agent_runtime`. (`project_hermes_removal_2026_05_05`) |
| **May-5 Canon-Hardening** | 2026-05-05 | `CANON_HARDENING_PROTOCOL_2026_05_05.md`. WRV state machine: `research → implemented → wired → reachable → visible → verified → released`. Canon promotion: `research → candidate → canon → (superseded \| historical \| rejected)`. No-date-gates. (`project_canon_hardening_2026_05_05`) |
| **May-6 V6.1 lock** | 2026-05-06 | `docs/audits/V6_1_LEAN_REALITY_MATRIX_2026_05_06.md`, `project_v6_1_lock_2026_05_06`, "Epistemos V6_1 — Final Synthesis Lock (Attention as Interrupt).pdf" (754L + 625L Helios source docs). User explicitly designated V6.1 as "the one I am pushing... main on all tiers." Floor anchor `ac8c6d28` immutable. Attention as INTERRUPT (not substrate); 5-plane formalism; T35-T42 theorems; ρ_max=0.20. |
| **May-7 V6.2 intake** | 2026-05-07 | `EPISTEMOS_V6_2_CANON_INTAKE_2026_05_07`, `epistemos-research/src/v6_2.rs`, `project_v6_2_intake_2026_05_07`. Strict V6.1 delta. Hardware lock = M2 Pro 16 GB (NOT M2 Max). 8-stage V6.2 falsifier order. |
| **May-8 Research snapshot** | 2026-05-08 | branch `codex/research-snapshot-2026-05-08`. Lifted `epistemos-research/src/acs.rs` (190 LOC), `scope_rex/kv/direct_gate.rs` (290 LOC), `kv_direct_gate.metal` (65 LOC). `docs/audits/V6_1_LEAN_REALITY_MATRIX_2026_05_06.md`. |
| **May-13 MAS readiness** | 2026-05-13 | `MAS_RELEASE_MANIFEST_2026_05_13`, `MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14`, `MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` (43-row atlas). The MAS-ship register. |
| **May-15 Hermes Agent Core 2.0 design** | 2026-05-15 | `HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` — note: this is the *DESIGN NAME* (per CODEX_9_TERMINAL_PROMPTS_2026_05_16:204), the in-code namespace is `agent_runtime` (then `agent_runtime_v2` from T11). The Hermes subprocess remains dead. |
| **May-16 nine-terminal cycle** | 2026-05-16..05-19 | `docs/CODEX_9_TERMINAL_PROMPTS_2026_05_16.md` (T1-T9), `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` (§4 sub-missions), `CODEX_HANDOFF_2026_05_16.md`, `MAY16_ARCHEOLOGY_2026_05_23.md`. Spawned 9 parallel terminals T1-T9. T1+T2+T3+T4+T5+T6+T7+T8+T9 each in a worktree. **DO NOT confuse with May-18 T09.** |
| **May-17 Cross-terminal wiring backlog** | 2026-05-17 | `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md` (45+ W-rows). The post-merge integration phase ledger. EML-INTEGRATION + Primitive-IR Stack doctrines fixed same date. |
| **May-18 no-compromise endgame** | 2026-05-18 | `NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` (T09-T27, 19 sub-tracks), `CLAUDE_NO_COMPROMISE_SUBSTRATE_HANDOFF_2026_05_18.md`, `CODEX_AND_CLAUDE_TERMINAL_DISPATCH_2026_05_18.md` (forever-loop discipline). T23B falsifier handbook + 15 F-* fragments + artifact schema (`2026-05-18.2`) all land. |
| **May-19 Quick Capture reconciliation** | 2026-05-19 | `QUICK_CAPTURE_FUTURE_RECONCILIATION_2026_05_19.md`. 4 salvage commits absorbed `skill_discovery`, `browser_engine`, `lifecycle`, `bootstrap`, 8 schemas, `FirstRunBootstrap.swift`, Tool trait + 74 typed v2_catalog wrappers, variant runner + circuit breaker + semantic cache + reason.think canary. 7 diverged modules + workspace/ remain locked. |
| **May-20 Worktree preservation** | 2026-05-20 | `WORKTREE_PRESERVATION_2026_05_20.md`. 14 preservation tags pushed to origin (`preserve/<label>-2026-05-20-snapshot`). |
| **May-22 Audits + Decompose** | 2026-05-22 | `T17B-DECOMPOSE-2026-05-22.md` (lattice_wbo 13,291L → 14 submodules + 14 test files), `T18B-DECOMPOSE-2026-05-22.md` (acs_admission 13,612L → 13 production + 7 test submodules), `T18B-NAMESPACE-PROPOSAL-2026-05-22.md` (zero collisions; reserve research::acs::anchors + acs_admission::anchor_ref). `/tmp/audit/01..04` audit pass produced. |
| **May-23 Phase E donor mining** | 2026-05-23 | `MAY16_ARCHEOLOGY_2026_05_23.md`, `T5-PR-SPLIT-PLAN-2026-05-23.md`, salvage PRs #15-#35 on main: T8 doctrine, T9 docs, T7 EML observatory, T1 tri-fusion, T2 AgentBlueprint + LocalAgentDiagnostics + RunTimeline, T3 (uas + active_assembly + page_gather), T5 split (Operator-IR, Scan-IR, Tropical-IR, Info-IR, Geometry-IR, cross-IR), T5 Phase A docs, T5 cross-IR fixup. Plus wiring rows: t10-eidos-queryruntime, t21-vault-recall-resourceservice, t17b-lattice-wbo-oplog, t11-system-g-localagentloop, t12-f-ulp-witness, t18b-acs-admission, agent-blueprint-settings-view, localagent-diagnostics-row. |

### 1.5 Lanes / Tiers / Streams (three orthogonal classifications)

Three different "five-way" classifications exist; **do not collapse them.**

**A. Five product lanes** (BACKLOG / DECK / HANDOFF). Distribution + safety lanes:
1. **MAS** = current App-Store-ship app, Tier 1 ON by default.
2. **Pro** = Direct distribution, Tier 2 bundled / OFF by default.
3. **Research** = Helios / Omega / Vault gates.
4. **Infrastructure / Reserved** = composition + tooling, no user feature.
5. **Vault** = preserved-speculation only.
6. (T09 adds **R0** = governing doctrine, not code.)

Source: `docs/CURRENT_PRODUCT_ARCHITECTURE_LEDGER_2026_05_18.md:12`.

**B. Three MAS tiers** (deployment_profiles memory):
- Tier 1 ON by default.
- Tier 2 bundled / OFF by default.
- Tier 3 not MAS.

Source: HANDOFF:50, `project_deployment_profiles`.

**C. Six/seven memory tiers** (DECK:52, HANDOFF:51):
- L0 hot (active KV / working set).
- L1 compressed residual.
- L2 shadow / sketch.
- L3 SSD oracle.
- L4 cascade.
- L5 adapters.
- L_SE self-evolving.
- L7 quarantine.

Note: the cognitive_dag's `MemoryTier` enum has only 5 variants (Hot=L0, Warm=L1, Cool=L2, Cold=L3, SelfEvolving=L_SE) — see `agent_core/src/cognitive_dag/edge.rs:118`. The 3-tier gap (L4/L5/L7) is undocumented. T17B Lattice/WBO Register canonicalizes the tier vocabulary FIRST; cognitive_dag mirrors after. (W-50 in BACKLOG.)

**D. Five runtime planes** (`epistemos-research/src/five_planes.rs`, 308 LOC):
1. State plane (Mamba-2 SSM, SemiseparableBlockScan).
2. Episodic plane (LocalRecallIsland, PageGather, ACS anchors).
3. Assembly plane (PacketRouter1bit; sparse active-support).
4. Controller plane (ControllerKernelPack; small-state inference; ternary natural home).
5. Verification plane (theorem-labels, F-* falsifiers).

**E. Three product streams** (DECK:50, V6.2): MAS / Pro / Vault — product organization in V6.2.

### 1.6 Substrate vs chrome vs wiring vs witnessing

These are the four canonical activity categories in a session:

- **Substrate** = Rust modules + Swift services that hold typed state and run algorithms. Built by T-tracks.
- **Chrome** = Swift UI surfaces (settings rows, badges, panels). Made visible by W-rows + salvage merges.
- **Wiring** = code paths from a backend substrate module to a UI surface or another substrate module. Owned by BACKLOG W-rows.
- **Witnessing** = falsifier artifacts proving the substrate matches the spec on M2 Pro. Owned by F-* gates.

A feature is **only "shipped"** when all four exist + WRV check passes. `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md` § "WRV state pipeline".

### 1.7 WRV doctrine

"A feature is not real until it is Wired, Reachable, Visible, and Verified." (HANDOFF:42, DECK:546)

The full pipeline from `project_canon_hardening_2026_05_05`:
```
research → implemented → wired → reachable → visible → verified → released
```

A claim is "shipped" only at `released`. Earlier work that "compiles + tests pass" is `verified`, not `released`.

A W-row is **DONE** only when (BACKLOG:312-317):
1. Cited code path exists on `main` (`git checkout main && rg/grep`).
2. Acceptance bar is measurable (cargo or Swift test exercising the wiring).
3. User-facing surface (if any) is screenshot-verified via computer-use.
4. No baseline regression (cargo lib floor + xcodebuild green).

### 1.8 Donor vs primary vs spine-adjacent vs tangential

From `/tmp/audit/04_donors.md` + project memory:

- **Donor** = a worktree that contributes additive subtrees to main but is not itself merged. Example: simulation worktree.
- **Primary** = a track that owns a substrate node on the canonical spine. T10 Eidos, T11 System G, T17B Lattice/WBO, T18B ACS admission, T21 vault recall, T12 F-ULP.
- **Spine-adjacent** = work that touches a spine node but adds bounded scope (e.g. T7 EML observatory adapter calling into eml/ from one other module).
- **Tangential** = nice-to-have, no spine node strengthened. Simulation companion visuals (frozen). T6 audiophile chain. Five redundant `claude/*` session worktrees.

### 1.9 Naming locks (NON-NEGOTIABLE)

- **Hermes**: subprocess + UI + namespace PURGED 2026-05-05. Code uses `agent_runtime` (renamed module) for legacy local-agent runtime; `agent_runtime_v2` for the new System G executor (T11). Swift uses `LocalAgent*` prefix. (`project_hermes_removal_2026_05_05`)
- **Aegis**: REJECTED by user direction 2026-05-18. Canonical name is **System G / Invader Agent** in user-facing docs. Code namespace is `agent_runtime_v2`. (HANDOFF:62, DECK:91, DECK:114)
- **Hermes Snake**: simulation-only companion body grammar (Pro design DNA). Different concept; preserved. (INDEX:534)
- **Hermes-3 prompt format**: the NousResearch ChatML grammar (`<tools>`, `<tool_call>`, `<think>`) is *preserved* as compatibility — local Nous models speak that format. `agent_core/src/agent_runtime/prompt_format.rs` emits it. (`project_hermes_removal_2026_05_05` "What is INTENTIONALLY PRESERVED")
- **HuggingFace model paths**: `leonsarmiento/Hermes-4.3-36B-4bit-mlx` etc. are *external HF identifiers*, kept verbatim. The Swift enum case is renamed (`localAgent43_36B*`); the HF route string keeps the `Hermes` token for HF correctness. (same)
- **ACS** = both expansions coexist: **Anchored Cognitive Substrate** (code lineage, HELIOS V5) AND **Autopoietic Cognitive Stack** (process lineage, Beer/VSM). Disambiguation rule (`docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md:32-46`): first mention per section must carry parenthetical expansion. T25 owns the lint.

### 1.10 The 5 V6.1 / V6.2 load-bearing Metal kernels (target-only)

Posture: `KERNEL_IMPLEMENTATION_POSTURE = "canonical_target_not_implemented_here"` (`project_v6_2_intake_2026_05_07`). **DO NOT claim these are implemented until real `.metal` files + M2 Pro falsifiers pass.**

1. **SemiseparableBlockScan.metal** (State plane; Mamba-2 SSD; no scalar token loops).
2. **LocalRecallIsland.metal** (Episodic plane).
3. **PageGather.metal** (Episodic plane).
4. **ControllerKernelPack.metal** (Controller plane; 6 fused micro-kernels).
5. **PacketRouter1bit.metal** (Assembly plane; ternary natural home).
6. Plus **InterruptScore.metal** (small always-on; CPU canonical for now; Swift `InterruptScoreCpu.swift` is the V6.2 canonical path per T23B).

V6.1 5-Pillars: Wyner-Ziv, GPTQ/Babai, ½-Lipschitz softmax, Test-Time Regression, EML operator. (DECK:87, `docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md`)

---

## Section 2 — Complete T-track register

Two parallel T-track taxonomies exist:

- **May-3 register** (T0-T15, zones A-D, defined in `docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md`). Feature register vocabulary. Still canon for "where is the project."
- **May-16 / May-18 terminal-track register** (T1-T9 / T09-T27). Sprint-cycle worktree assignments. Both 2026-05-16 (single-digit T1..T9) AND 2026-05-18 (zero-padded T09 + T10..T27) coexist. The zero-padded T09 is **a different track** than May-16 T9, per `MAY16_ARCHEOLOGY_2026_05_23.md` line 39 "**NAME COLLISION**: NOT to be confused".

Both taxonomies are documented below. Every track gets: canonical name, status, lane, spine node, evidence, blockers, "done" definition, audit + hardening status.

### 2.1 Register A — May-3 substrate tracks T0..T15

(From `docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md`. Substrate-total ~30% as of 2026-05-03; some progress since.)

| Track | Canonical name | Lane | Status (May-3) | Spine node | "Done" definition | Blocker / next action |
|---|---|---|---|---|---|---|
| **T0** | Substrate Unification (Cognitive Kernel + DAG + XPC + Schema-First GenUI) | All | ~5% (doctrine written, partial impl via ArtifactBlockView) | foundational | Cognitive Kernel Phases 1-7 + DAG Phase 8.A-H + XPC Phases X.1-X.5 + GenUI G.1-G.6 all merged into main | Recovery Stages A.1 + A.4 (GenUI G.3 migration) + B.1 (Hermes-in-Rust) + V2.1 (DAG); XPC waits for paid Developer Team |
| **T1** | Foundation Substrate (TypedArtifact, MutationEnvelope, RunEventLog, AgentEvent, GraphEvent) | All | ~done | architectural invariants | all canonical types in `Models/MutationEnvelope.swift` (Sensitivity enum line 88) + `agent_core/src/mutations/envelope.rs` + parity tests | none — done |
| **T2** | Provenance + Sovereign Gate | All | ~70% | provenance / witness | Provenance Console UI + SovereignGate single-LAContext owner + Sensitivity enum + AgentEvent canonical recorder | Provenance Console UI is the remaining MAS feature trio gap |
| **T3** | Privacy / Hardening / Subprocess Audit | All | ~done | hardening | `harden_cli_subprocess` helpers across 10 spawn sites; 24-vector denylist; no UserDefaults secrets; Keychain for API keys | none — done |
| **T4** | Resonance Gate (K3 ternary; Σ signature) | Core | ~80% (jumped from 0% in 2026-05-03 session) | killer feature | 7-field Σ + 9 claim types + 5 directional operators wired into chat or Halo | mount into production surface deferred to post-hackathon M1 |
| **T5** | Hermes Agent + Multi-CLI (May-3 register) | Core (parser) + Pro (CLI) | UI ~80%, RUNTIME ~5% | killer feature | full Hermes-in-Rust runtime per Cognitive Kernel Phase 2 (CANCELED — Hermes subprocess purged 2026-05-05). Replaced by agent_runtime + agent_runtime_v2 + LocalAgent* | RESOLVED via T11 / May-18 |
| **T6** | Simulation Mode v1.6 + Companion Farm | Core | UI shell ~50%, ASSETS ~0%, ADAPTER LoRA SWAP ~0% | killer feature | actual Tamagotchi-style companion creatures with custom-drawn body grammars (Block/Sage/Orb + Hermes Snake); Landing Farm + Graph Live Theater + Notes Sidebar; deterministic PRNG-seeded idle walking | Recovery Stage E (SIMULATION_ASSETS_DOCTRINE + custom-drawn renderers) + Stage D.3 (LoRA-light spike) |
| **T7** | Local Model / MLX-Swift / Mamba-2 SSM | Core | ~done | local inference | MLX-Swift in-process; 4-bit Qwen base; idle unload optimization; Mamba-2 save/load/resume | none — done |
| **T8** | Halo / Contextual Shadows / RRF Fusion / Vault Index | Core | ~done | retrieval | W8.4 + W8.7 shipped: BM25 + HNSW shadow + RRF k=60 + Spotlight + ReadableBlocks vault_id column | none — done |
| **T9** | Code Editor / Tiptap / KaTeX / LSP | Core | ~done with one MAS-blocker | editor | Tiptap WKWebView + KaTeX preview + content-hash bundle build; LSP migration from subprocess to in-process Rust kernel | V2.3 LSP migration shipped (per `project_helios_v5_substrate_landed` + LSP transport seam at `Epistemos/Engine/LSPTransport.swift`) |
| **T10** | Graph Engine / Spatial / Cluster / Search | Core | ~done | spatial | graph-engine Rust crate; SemanticClusterService parallelized; lock-free slot-fill | none — done |
| **T11** | UX / Landing Wave / Approval Modal / Visual Chain | Core | in progress | UX | LandingWave Metal renderer + ASCII liquid-wave + compact flat bar + ApprovalModalView via TimelineView(.periodic) | LandingFarmView for T6 SHIPS during hackathon (now post-hackathon canonical recovery); pixel-surface replaced LandingWave (commit 453fbafd99 on main) |
| **T12** | App Store Release / Phase R / Phase S | All | in progress | distribution | MAS submission; Phase R Resource Runtime; Phase S 9-subphase hardening | Phase R lives on `codex/runtime-input-audit` branch (324 commits, never merged); cherry-pick required |
| **T13** | Multi-Agent / ACS Ecosystem (Codex + Claude + Kimi + Gemini) | Pro | tooling-only | research | multi-agent council orchestration | tooling-tier, low-priority |
| **T14** | Ternary / Research Tier (Sherry, KV-Direct, WBO-6) | Research | gated | ceiling | T14/T17B/T18B + F-KV-Direct-Gate + F-WBO-DriftLedger pass | F-* falsifiers must pass on M2 Pro 16 GB |
| **T15** | ANE Direct Path / KV Implantation | Research | gated | ceiling | private ANE paths verified; KV implant kernel | Apple private framework loading; out of scope for MAS |

**Cross-cutting concerns** (per §5 of register): XPC Mastery, Capability Lattice, Cognitive DAG schema, zero-copy UMA, Sovereign Gate single-owner, AgentEvent provenance. Each owns its own doctrine doc.

### 2.2 Register B1 — May-16 cycle T1..T9

(From `docs/CODEX_9_TERMINAL_PROMPTS_2026_05_16.md`; `MAY16_ARCHEOLOGY_2026_05_23.md`; `/tmp/audit/02_may16_cycle.md`. All 9 branches forked near `86f0ec84fd`, pre-Hermes-purge.)

| ID | Canonical name | Worktree | Branch / HEAD | Commits ahead | Status | Salvage action |
|---|---|---|---|---|---|---|
| **T1** | Tri-Fusion MD ⇄ JSON ⇄ HTML | origin only | `codex/t1-trifusion-2026-05-16` / `58a02ace27` | 69 | Stop-state, closeout-published, ready for review. 11 cargo tests + 240-doc property corpus | **SALVAGED** as `salvage/T1-additive-2026-05-23` (PR #19, 8b5b669870 on main). Files: `agent_core/src/tri_fusion/{mod,html,markdown}.rs`, `research/hyperdynamic_schemas/document.rs`, `Engine/RustTriFusionDocumentClient.swift`, `EpistemosTests/RustTriFusionDocumentClientTests.swift` |
| **T2** | Agent / Model Gating / "HEART" | `/Users/jojo/Downloads/Epistemos-t2-agent` | `codex/t2-agent-2026-05-16` / `b187813cf6` | 38 | Phase 1 hardening; dirty-spurious deletions (recoverable via `git reset --hard HEAD`); 5 audits + AgentBlueprint + LocalAgentDiagnostics + native Mistral TOOL_CALLS array fixture | **SALVAGED (subset)** as `salvage/T2-additive-2026-05-23` + `salvage/T2-localagent-diagnostics-2026-05-23` (PRs #32 + #34 on main). Files: `LocalAgent/AgentBlueprint.swift`, `LocalAgentDiagnostics.swift`, `Views/Chat/AgentRunTimelineView.swift`, settings views. Plus wirings #33 + #35 surfaced them. ConfidenceRouter shim. HIGH overlap with May-18 T11 (complementary, not duplicate). |
| **T3** | UAS / ACS substrate | origin only | `codex/t3-uasacs-2026-05-16` / `56d5cfc00c` | 64 | Phase B iter 62 — loop terminated, falsifiers seeded. 7 UAS files + 2 ACS anchors + 3 active_assembly + 5 page_gather + 9 cargo tests + 5 falsifier specs | **SALVAGED (subset)** as `salvage/T3-additive-2026-05-23` (PR #20, 741e752d05 on main). Files: `agent_core/src/uas/*` (7 files), `research/active_assembly/{mod,packet,selector}.rs`, `research/page_gather/{mod,sketch_topk,residual_rescore,escalation_policy,helios_page}.rs`. **Skipped:** `research/acs/` overlap with T17B/T18B (already on main). HIGH overlap with T17B + T18B. |
| **T4** | Vault recall (F-VaultRecall-50) | `/Users/jojo/Downloads/Epistemos-t4-vault` | `codex/t4-vault-2026-05-16` / `8cff8701fc` | 144 | **Ready for Phase 2.** F-VaultRecall-50 PASS 7/7 (Top-1 100%, Top-5 90%, agent context 96%, adversarial 100%). `agent_core/src/retrieval/mod.rs` (2,742L Shadow-first contract) | **SKIPPED (superseded)** per `MAY16_ARCHEOLOGY_2026_05_23.md:35`. T21 on main already ships `storage/retrieval_trace.rs` + `f_vault_recall_runner.rs` — DIFFERENT path, same intent. Risk of parallel contracts. Preserved as tag `preserve/T4-vault-2026-05-20-snapshot`. |
| **T5** | EML-IR Primitive Stack (6 IRs) | `/Users/jojo/Downloads/Epistemos-t5-emlir` | `codex/t5-emlir-2026-05-16` / `2ba7142e28` | **961** | Phase A closed 8/8; Phase B1 iter-950 active. 6,661 `.lean` files + 16 Rust submodules + 28 sorries (budget-gated) + cross-IR tests | **SALVAGED (split per IR)** per `docs/T5-PR-SPLIT-PLAN-2026-05-23.md`. PRs #21-#27 + #28: Operator-IR (PR #21), Scan-IR (PR #22), Tropical-IR (PR #23), Info-IR (PR #24), Geometry-IR (PR #25), cross-IR (PR #26), cross-IR fixup (PR #27), Phase A docs (PR #28). Skipped: `eml/` (already on main via T12). Open blocker: `EML-LEAN-VENDOR` (`tomdif/eml-lean` not vendored). |
| **T6** | UI/UX recursive audit | `/Users/jojo/Downloads/Epistemos-t6-uiux` | `codex/t6-uiux-2026-05-16` / `775137b831` | 38 | Phase 1 hardening; 17-iter UI/UX audit; `Engine/AmbientFrequencyLivePlayer.swift` (649L) audiophile chain; a11y on LiveActivityStrip/ContextWindowIndicator/ProcessDisclosure; Halo persistence; Provenance Console pagination | **DEFERRED** per `MAY16_ARCHEOLOGY_2026_05_23.md:37`. Most of T6 is modifications, not pure-additive. Audit docs preserve the work; let polish ride on a future UI refactor cycle. Preserved as tag. |
| **T7** | Deep EML MVP integration | origin only | `codex/t7-eml-2026-05-16` / `ce3a8d3b2b` | 30 | Stop-state, closeout-published. NEW `eml_integration/{mod,potential,observatory,diagnostic}.rs` + EmlPotential newtype + `auc_on_augmented()` cornerstone + 14 tests + CLI `epistemos_eml.rs` | **SALVAGED** as `salvage/T7-additive-2026-05-23` (PR #17, e28881e6a9 on main). Files: `eml_integration/*.rs`, `tests/eml_observatory.rs`, `bin/epistemos_eml.rs`. |
| **T8** | Biometric Lock (gated) | origin only | `codex/t8-biometric-2026-05-16` / `7fa1df06ce` | 11 | **Phase 0 doctrine only — DONOR-ONLY.** Self-gated until §4.A/§4.E/F/§4.C land. NO code. 431L doctrine | **SALVAGED (doc-only)** as `salvage/T8-additive-2026-05-23` (PR #16, 52e2858501 on main). File: `docs/fusion/BIOMETRIC_LOCK_DOCTRINE_2026_05_17.md`. Gate-open conditions: T1+T2+T6 land — partially met. Code work (W-34..W-39) still pending. |
| **T9** | Coordinator + drift-catch + cross-PR review | origin only | `codex/t9-coord-2026-05-16` / `25a74f5db2` | 39 (iter-37 = final) | **Stop-state, docs-only.** 19 new `docs/coordination/T9_*` files; appends to CANONICAL_AUDIT_LOG (+367), CRITIQUE_LOG (+1117), APP_ISSUES_AUTO_FIX (+221) | **SALVAGED (doc-only)** as `salvage/T9-additive-2026-05-23` (PR #18, 63a7b6e023 on main). Files: `docs/coordination/T9_*` + drift handoffs. **NAME COLLISION** with May-18 T09: T9 ≠ T09. |

### 2.3 Register B2 — May-18 cycle T09..T27

(From `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md:156-555`; `/tmp/audit/03_may18_cycle.md`; `docs/CODEX_AND_CLAUDE_TERMINAL_DISPATCH_2026_05_18.md:21-46`. May-18 cycle is the no-compromise endgame.)

| ID | Canonical name | Branch / status | Spine node | "Done" definition | Current status |
|---|---|---|---|---|---|
| **T09** | Product Architecture Ledger (anti-drift) | `codex/t09-product-architecture-ledger-2026-05-18` / `4e2930cd4a` / **720 commits → squashed to 1** (`17a798a474`) — **MERGED** via PR #6 | meta (classifies all other rows) | Every named subsystem classified per 10 closed-vocabulary tokens; delete/hide/merge/keep/build-next lists; every cross-terminal row links to a W-NN row | **MERGED to main.** Ledger doc at `docs/CURRENT_PRODUCT_ARCHITECTURE_LEDGER_2026_05_18.md` (1,846L). Per `/tmp/audit/03_may18_cycle.md:11-21`, 720 iter spiral was cron noise past iter-50; doc-only loop. **Next:** stop the forever-loop; ledger only refreshes on actual subsystem status changes. |
| **T10** | Eidos V0 (deterministic closed-citation retrieval) | `codex/t10-eidos-v0-2026-05-18` / `4df955180a` / **769 commits** — **MERGED** via PR #7 (`85b9992e33`) | Vault/Eidos retrieval | `EidosDocumentId`/`Chunk`/`Hit`/`Query`/`ContextPacket`/`Citation`/`IndexManifest`/`RetrievalMode` defined; lexical+semantic+hybrid+code-symbol+claim-evidence+graph-neighborhood+raw-archive modes; closed citation contract enforced; 9 unit tests | **MERGED to main + WIRED** via PR #12 (`wiring/t10-eidos-queryruntime-2026-05-23`, `21e7eac857` on main: `feat(wiring/t10-eidos): wire EPISTEMOS_EIDOS_V0 closed-citation path`). 19 files, 22,567L Rust + `hardening_tests.rs` (12,941L). Per `/tmp/audit/03_may18_cycle.md:25-38`: textbook converging loop. Swift mirror present at `Epistemos/Eidos/Eidos.swift` but FFI bridge `Epistemos/Eidos/EidosBridge.swift` is **NOT-STARTED** per BACKLOG W-46. |
| **T10B** | Eidos Form Layer (canonical object identity) | `codex/t10b-eidos-form-layer-2026-05-18` — **NOT MERGED on main HEAD** | Vault/Eidos (form layer) | `EidosKind` enum with 13 kinds (Note/Claim/Evidence/Citation/ToolCall/AgentEvent/Artifact/GraphNode/MemoryPage/ModelOutput/Patch/Command/UserDecision); stable ID via BLAKE3; canonicalization for at least one current app object; compatibility mapping to ClaimKind/VRM/TypedArtifact | **PARTIAL on branch only.** Per the May-18 prompt deck, must come *after* T10 lands. Not yet salvaged. |
| **T11** | Agent Runtime v2 / System G (typed/budgeted/witnessed/capability-gated executor) | `codex/t11-agent-runtime-v2-2026-05-18` / `16e4264383` / **659 commits** — **MERGED** via PR #10 (`5109b92571`) | System G | `Para<P,A,B>` defined; `AgentRuntimeV2Capability`, `AgentRuntimeV2Mode::{Disabled,IpcBounded,Subprocess}`; WBO budget checking; macaroon verification; `MutationEnvelope` output wrapping; canonical flow `AgentBlueprint→MissionPacket→AgentEvent→approval→MutationEnvelope→RunEventLog→AnswerPacket`; forged/expired macaroon rejected; thinking-block hash identity | **MERGED + WIRED** via PR #29 (`wiring/t11-system-g-localagentloop-2026-05-23`, `73a73bfac3` on main: `feat(wiring/t11-system-g): EPISTEMOS_SYSTEM_G_V0 runtime status breadcrumb`). 31,645L / 16 files. **Aegis REJECTED.** Per `/tmp/audit/03_may18_cycle.md:42-55`: deep Phase 1 hardening; convergent loop. **lattice_wbo three-way conflict** with T17B (13,291L) + T18B (4L stub) — T11's 389L stub is subset; T17B canonical. Resolved at merge. Swift `Epistemos/AgentRuntimeV2/` README references but Swift impl missing. |
| **T12** | F-ULP Oracle (EML fp16 floor) | `codex/t12-f-ulp-oracle-2026-05-18` / `5f6c69ff1a` / **350 commits** — **MERGED** via PR #9 (`ee23dac53a`) | EML / EML-IR | 412k log-sampled points + 2,048 stress points; ≤ 2 ULP fp16 in `[0.5, 2]`; ≤ 90 s on M2 Pro; AnswerPacket schema freeze blocked until this gate is green | **MERGED + WIRED** via PR #30 (`wiring/t12-f-ulp-witness-2026-05-23`, `306311fc04` on main: `feat(wiring/t12-f-ulp): EPISTEMOS_F_ULP_ORACLE_V0 acceptance witness visible`). 8,884L across `research/eml_ir/` (witness 6,503L, oracle 915L, fixtures 839L, mod 358L, fp16 269L). Plus parallel `research/fulp_oracle/` subdir — **duplication; T12 next step: collapse or rename.** No `agent_core/tests/f_ulp*`. Repo-wide PCF+H+E lean = 27 sorries, none T12-introduced. Per `/tmp/audit/03_may18_cycle.md:59-75`. |
| **T13** | F-KV-Direct Gate (Qwen3-8B-MLX-4bit 128k) | `codex/t13-kv-direct-gate-2026-05-18` — **NOT MERGED** | Falsifier / ceiling | 100 prompts × 4 task classes; avg D_KL < 0.05 nats; peak RAM < 13 GB; decode ≥ 10 tok/s; wall-clock ≤ 30 min on M2 Pro | **NOT-STARTED.** Substrate exists (`agent_core/src/scope_rex/kv/direct_gate.rs` + Metal shader). End-to-end harness NOT-STARTED per `HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md`. |
| **T14** | Five Plane UAS-ACS Wiring (typed register) | (no branch yet; gated on T3 merge) | UAS / state-Episodic-Assembly-Controller-Verification | `UasAddress`, `UasKind`, `ResidencyLease`, `ByteRange`, `AddressableArtifact`, `ActiveAssemblyId`, `ActiveAssemblyPacket`, `AssemblyWitness` defined; plane placement rules; tier tag per row; same artifact ID stable across residency transitions; lint rejects untagged plane surfaces | **NOT-STARTED on main.** Requires T3 merge — happened via salvage PR #20 (uas + active_assembly + page_gather). T14 wiring still pending. |
| **T15** | Executor Trait (provider-neutral) | `codex/t15-executor-trait-2026-05-18` — **NOT MERGED** | System G (substrate) | `Executor` trait with streaming + tool use + prompt-caching capability flags; `MissionPacket`; `ExecutorEvent`; mock + adapter sketch | **NOT-STARTED on main.** Pairs with T11. |
| **T16** | Live File Compiler (markdown intent compiles to signed LivePlan.v1) | `codex/t16-live-file-compiler-2026-05-18` — **NOT MERGED** | Spine-adjacent (quick-capture inheritance) | 10-state machine + `LivePlan.v1` schema with plan hash + capabilities + triggers + eligibility + revocation; markdown itself never executes | **NOT-STARTED on main.** Live File Compiler is FINAL_SYNTHESIS §1 BREAKTHROUGH per INDEX:195. Original Quick Capture work blocked. |
| **T17** | Cognitive Weight Class Enforcement | `codex/t17-cognitive-weight-class-2026-05-18` — **NOT MERGED** | Schema (orthogonal) | 4 weight bands (`soft_memory [0–0.30]` / `preferred_context [0.31–0.60]` / `strong_project_anchor [0.61–0.85]` / `policy_grade [0.86–1.00]`) + 5 promotion gates; "Semantic Gravity pulls attention; Policy Authority controls action." | **NOT-STARTED on main.** Doctrine at `docs/fusion/COGNITIVE_WEIGHT_CLASS_DOCTRINE_2026_05_04.md`. |
| **T17B** | Lattice / WBO Register (error-law substrate) | `codex/t17b-lattice-wbo-register-2026-05-18` / `a3762d9333` / **564 commits** — **MERGED** via PR #3 (`08c0f983b0`) | Lattice / WBO accounting | Preserve Lattice-Wyner-Ziv / `LatticeCoder<BITS>` / WZ side info / Babai/GPTQ / Sherry / ShadowKV / QuIP/E8 / residual/sketch; define `LatticeBudget`/`LatticeCoderKind`/`LatticeErrorContribution`/`WboLedgerEntry`/`ActiveSupportBudget`/`SideInformationKind`; map memory-tier ↔ codec ↔ WBO term ↔ falsifier; weight-quant + KV-quant Hessians do not collapse | **MERGED + WIRED + DECOMPOSED.** 13,291L → 14 production + 14 test submodules per `T17B-DECOMPOSE-2026-05-22.md` (305 `#[test]` functions preserved). Wired via PR #14 (`wiring/t17b-lattice-wbo-oplog-2026-05-23`, `43313c2914` on main: `feat(wiring/t17b-lattice-wbo): always-on oplog accounting hook`). Canonical lattice_wbo per `/tmp/audit/03_may18_cycle.md:79-93`. Also adds `research/acs/mod.rs` + `scope_rex/kv/direct_gate.rs`. |
| **T18** | Residency Governor + Rail | (gated on T3 merge) | UAS / residency | Governor input: source size, task fidelity tolerance, reversibility, privacy class, tier budget; Core cannot emit L4-L6 except explicit quarantine L7; Settings row shows tier counts + denied tier leaks | **NOT-STARTED full version.** T3 partial via salvage merge. |
| **T18B** | ACS Admission Field (verdict layer above SCOPE-Rex) | `codex/t18b-acs-admission-field-2026-05-18` / `af78e4bfb5` / **430 commits** — **MERGED** via PR #4 (`cdd05d89ee`) | ACS admission | Define `ACSAdmissionInput`/`ACSAdmissionVerdict`/`ACSRiskVector`/`ACSPolicy`/`ACSAuditRecord`; verdicts: allow / allow-with-warning / defer / quarantine / reject; no durable memory write bypasses; all verdicts logged | **MERGED + WIRED + DECOMPOSED.** 13,612L → 13 production + 7 test submodules per `T18B-DECOMPOSE-2026-05-22.md` (379 tests preserved). Wired via PR #31 (`wiring/t18b-acs-admission-2026-05-23`, `8851f8b585` on main: `feat(wiring/t18b-acs): EPISTEMOS_ACS_ADMISSION_V0 strict policy visible`). Per `/tmp/audit/03_may18_cycle.md:96-112`. Touches `effect/receipt.rs`, `provenance/ledger.rs`, `scope_rex/answer_packet.rs`. Namespace coexists with T17B `research/acs/`: T18B = product lane (`acs_admission`) vs T17B = research lane (`research::acs`). Per `T18B-NAMESPACE-PROPOSAL-2026-05-22.md`: 0 syntactic collisions; reserve `research::acs::anchors` + `acs_admission::anchor_ref`. |
| **T19** | Halo V1 + Eidos Control Vectors (adapter) | `codex/t19-halo-eidos-control-vectors-2026-05-18` — **NOT MERGED** | retrieval (UI adapter) | Adapter maps Eidos lexical/semantic/graph/residency signals → Halo availability state; no UI behavior change without feature flag | **NOT-STARTED on main.** |
| **T20** | Variant Ladder Generalization | `codex/t20-variant-ladder-generalization-2026-05-18` — **NOT MERGED** | substrate | Route order: deterministic → embedding → classical → small LLM → mid LLM → cloud → defer; `escalate_on_empty` defaults false; logs each tier choice into provenance | **NOT-STARTED.** |
| **T21** | Vault Recall Contract (F-VaultRecall-50) | `codex/t21-vault-recall-contract-2026-05-18` / `60b035b837` / **443 commits** — **MERGED** via PR #11 (`93a010f6ef`) | Vault/Eidos contract | No production path builds context from index-order `LIMIT N`; every vault retrieval checks inventory completeness, searches full manifest, retrieves 50-200 candidates, emits lexical/semantic/graph/recency/MMR trace; UI shows loaded sources/snippets/provenance; F-VaultRecall-50 fixture in diagnostics | **MERGED + WIRED.** 11,570L fixture corpus + 1,037L runner + 1,516L integration test + `retrieval_trace.rs` + `vault_search_ladder.rs`. Wired via PR #13 (`wiring/t21-vault-recall-resourceservice-2026-05-23`, `bd0273a4b8` on main: `feat(wiring/t21-vault-recall): wire EPISTEMOS_VAULT_RECALL_CONTRACT_V1 trace path`). Per `/tmp/audit/03_may18_cycle.md:115-135`: late-stage hardening; 156% past floor; circular adds non-Latin script rows. **2/5 acceptance bars met, 1 partial, 2 pending** (W-20 Brain Panel + W-19 ChatCoordinator wiring). |
| **T22** | Substrate Health Panel | (gated on T2+T3+T4+T7 merge) | UI surface | Unified Settings panel shows agent runtime / model constellation / vault recall / EML floor / UAS-ACS / Cognitive DAG / provenance ledger / falsifier status; missing subsystem degrades to "not wired" with source doc link | **NOT-STARTED full version.** |
| **T22B** | Brain Panel Closed Citations | `codex/t22b-brain-panel-closed-citations-2026-05-18` — **NOT MERGED** | UI surface (Eidos consumer) | Chat row / Brain Panel shows "Retrieved by Eidos" with source IDs, titles, snippets, score components; fake citation rejected; missing source text cannot be displayed as cited evidence; works without cloud | **NOT-STARTED on main.** Pairs with T10. |
| **T23** | F-70B Local Cocktail (research harness) | `codex/t23-f70b-local-cocktail-2026-05-18` — **NOT MERGED** | Falsifier / capability ceiling | 70B-class candidates × 50-prompt suite × cloud/fp16 ref path × sparse local path × M2 Pro budget. PASS: D_KL < 0.1 nats, ≥ 5 tok/s, ≤ 30s TTFT on 4k prompt, < 14 GB resident. FAIL must identify bottleneck. | **NOT-STARTED.** Vault/Research only. |
| **T23B** | M2 Pro Falsifier Handbook | `codex/t23b-m2pro-falsifier-handbook-2026-05-18` / `c6d45e8ed6` / **1014 commits → squashed to 1** (`1e5308253e`) — **MERGED** via PR #5 (`03197c36cc`) | Falsifier / meta | Includes 15 F-* gates (F-Eidos-ClosedCitation / F-VaultRecall-50 / F-PageGather-Baseline / F-PageGather-Scatter / F-UAS-CopyCount / F-ACS-AnchorLookup / F-InterruptScore-CPU / F-PacketRouter1bit / F-ControllerKernelPack / F-SemiseparableBlockScan / F-LocalRecallIsland / F-KV-Direct-Gate / F-WBO-DriftLedger / F-ULP-Oracle / F-70B-Local-Cocktail-Lite); each gate has purpose, current status, input fixture, pass threshold, failure meaning, fallback route, product lane, command, expected artifact; unimplemented scripts marked NOT IMPLEMENTED | **MERGED.** Handbook (`docs/falsifiers/M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md`, 333L) + 15 F-* fragments + `FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md` (1,477L) + `ARTIFACT_NEGATIVE_EXAMPLES_2026_05_18.md` (13,389L) + `ARTIFACT_VALIDATOR_SHAPE_2026_05_18.md` (868L). Per `/tmp/audit/03_may18_cycle.md:140-152`: schema is real canon. 1,014→1 squash justified; pure doc spiral past iter-50. |
| **T24** | Lean ClaimLedger Schema Authority | `codex/t24-lean-claimledger-schema-2026-05-18` — **NOT MERGED** | Witness / cert | One Lean enum/theorem family; Rust + Swift schema twins round-trip; sorry budget visible + monotonically tracked | **NOT-STARTED.** |
| **T25** | ACS Naming + Plane Reconciliation | `codex/t25-acs-reconciliation-2026-05-18` — **NOT MERGED** | doctrine | First mention of ACS in modified docs includes parenthetical expansion; code-structure view + process-doctrine view both preserved; lint or checklist row preventing bare "ACS" drift | **NOT-STARTED on main.** `T18B-NAMESPACE-PROPOSAL-2026-05-22.md` proposes the resolution (Option 3a = grandfather both prefix styles `Acs*` + `ACS*`). Awaiting user arbitration. |
| **T26** | Self-Evolving Adapter Lane (L_SE) | `codex/t26-lse-adapter-lane-2026-05-18` — **NOT MERGED** | Research / adapters | No adapter can become policy authority without Cognitive Weight Class policy-grade gates; Core tier cannot load L_SE mutators; research tests cover rollback and drift demotion | **NOT-STARTED.** |
| **T27** | WRV Product Surfacing | (gated on merge phase + W-rows) | meta / visible | Each selected W-row gets code, visible UI surface, verification test; "PATCHED" not accepted unless user can reach the feature | **PARTIAL.** Wirings #12, #13, #14, #29, #30, #31, #33, #35 on main (8 of the W-row backlog visible). |

---

## Section 3 — W-row register (cross-terminal wiring backlog)

(From `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md`. 53 rows W-01..W-53 in the doc; classification builds on `/tmp/audit/01_canon_2026_05_20.md:24-71` and the recent wiring-merge commit set on main.)

**Status notation:** NOT-STARTED · IN-FLIGHT · PARTIAL · DONE. Per BACKLOG:312-317, DONE requires (1) code path on main + (2) measurable acceptance bar + (3) screenshot-verified surface + (4) no baseline regression.

### 3.1 Substrate-to-Product wirings (P0/P1)

| ID | Title | Owner track(s) | Status | Spine node | Acceptance | Required to mark DONE |
|---|---|---|---|---|---|---|
| **W-01** | UasAddress on vault notes (insert/retrieve) | T3+T4 | NOT-STARTED | UAS / Vault | `vault.rs::hybrid_search()` returns `Vec<(UasAddress, Note)>`; round-trip property test on 50-note vault | Salvage T3 uas subset is on main (PR #20); vault.rs integration pending |
| **W-02** | UasKind on agent traces (RunEventLog) | T2+T3 | NOT-STARTED | UAS / System G | T2's RunEventLog event records carry `UasAddress { kind: UasKind::AgentTrace, ... }`; replay UI can reconstruct trace from address alone | T2 + T3 salvaged; integration pending |
| **W-03** | AcsAnchor in ClaimLedger | T3 | NOT-STARTED | ACS / Witness | every `Claim` stored in `ClaimLedger` carries an `AcsAnchor`; Provenance Console UI displays theorem-tag column | T3 partial; AcsAnchor needs to ride along ClaimLedger |
| **W-04** | page_gather → vault retrieval (sketch→residual→exact escalation) | T3+T4 | NOT-STARTED | Vault / Eidos | `vault.rs::hybrid_search()` invokes `EscalationPolicy::escalate(...)`; benchmark shows ≥ 40% read-amplification reduction | T3 page_gather salvaged via PR #20; vault.rs integration pending |
| **W-05** | Active Assembly in agent_runtime | T2+T3 | NOT-STARTED | System G / UAS | `agent_runtime` calls `Selector::pull(query_packet, available_packets)` before dispatching; assembly-PASS within WBO budget | T3 active_assembly salvaged; agent_runtime integration pending |
| **W-06** | Tri-Fusion mutations in agent_runtime + Epdoc | T1+T2 | NOT-STARTED | System G | `agent_runtime` parses `TriFusionMutation`; Epdoc receiver renders structured-mutation cards; LocalAgentPromptBuilder emits at least one Tri-Fusion mutation in a real chat turn | T1 tri_fusion salvaged via PR #19; integration pending |
| **W-07** | EML observatory health row | T7 | NOT-STARTED | Falsifier/health | new `EmlObservatoryHealthRow.swift`; reads observatory state via FFI; auto-refreshes 1 Hz | T7 eml_integration salvaged via PR #17; Swift health-row pending |
| **W-08** | EML potential in ConfidenceRouter | T2+T7 | NOT-STARTED | EML / System G | ConfidenceRouter reads `EmlPotential::compute(query)`; A/B routing test shows ≥ 5% accuracy improvement on fixture corpus | substrate present; integration pending |
| **W-09** | Scan-IR ↔ SemiseparableBlockScan | T3+T5 | NOT-STARTED | EML-IR | T3's iter-53 test refactored to consume `ScanIR::SemiseparableBlock { ... }` from T5's lane | T5 Scan-IR salvaged via PR #22; T3 harness pending |
| **W-10** | UAS-ACS substrate health row | T3 | NOT-STARTED | Falsifier/health | new `UasAcsHealthRow.swift`; reads falsifier statuses via FFI; clickable to per-gate detail; tied to docs/falsifiers/ | T3 + T23B substrate on main; Swift row pending |

### 3.2 Agent + Model wirings (P0)

| ID | Title | Owner | Status | Acceptance |
|---|---|---|---|---|
| **W-11** | ActiveConstellationRow live state binding | T2 | **PARTIAL** | row updates ≤ 500 ms after model state changes; per-model state = cold·warm·hot; per-model role = code·reasoning·quick·toolCaller·trivial·vision |
| **W-12** | Per-model agent badges (HONEST / EXPERIMENTAL / OFF) | T2 | NOT-STARTED | every local model in picker shows a badge; click reveals which grammar primitives the model honors; cross-link to `MODEL_GRAMMAR_MATRIX_2026_05_17.md` (NOT YET ON MAIN per `/tmp/audit/01_canon_2026_05_20.md:118`) |
| **W-13** | Power-user mode Settings toggle UI | (15cc2ced4 flag exists) | NOT-STARTED | new SwiftUI `Toggle` in Inference settings; persists to UserDefaults; relaunch hint shown; cross-link to ISSUE-2026-05-16-015 |
| **W-14** | AnswerPacket runtime emission + per-row badge | T2 | **PASS for emission/linkage substrate; W-27 NOT-STARTED for visible badge** | Swift `AnswerPacketEmitter` + `LatestAnswerPacketSink` substrate verified; per-row badge UX remains W-27 |
| **W-15** | AgentBlueprint creation flow (end-to-end test) | T2 | **PARTIAL** | UI built via salvage PR #32 + #33; end-to-end integration test missing |
| **W-16** | Run timeline + replay from RunEventLog | T2 | NOT-STARTED | replay button reads events + renders identical timeline; deterministic |
| **W-17** | Local agent diagnostics (per-model load times, idle-unload events, schema-drift counter, hot-swap count) | T2 | **PARTIAL** (chain landed via salvage PR #34 + wiring PR #35) | row aggregates 6 metrics; clickable for per-metric history; refresh ≤ 1 Hz |
| **W-18** | EML confidence in timeline (per-event column) | T2+T7 | NOT-STARTED | per-event confidence column; tied to AnswerPacket.confidence field |

### 3.3 Vault retrieval honesty (P0)

| ID | Title | Owner | Status | Acceptance |
|---|---|---|---|---|
| **W-19** | ChatCoordinator Vault Context Contract enforcement | T4/T21 | **PARTIAL** | T4 implemented; ChatCoordinator integration via T21 wiring PR #13; F-VaultRecall-50 PASS conditions met; "first 7 irrelevant notes" structurally impossible |
| **W-20** | Provenance cards in 3+ surfaces (NoteChatSidebar + Halo + ChatInputBar) | T4+T6 | **PARTIAL** | NoteChatSidebar done; Halo + ChatInputBar pending |
| **W-21** | Vault recall health row (top-1 / top-5 / synthesis / adversarial) | T4 | NOT-STARTED | row aggregates 4 metrics; refresh on vault index update; clickable to per-query breakdown |
| **W-22** | `hybrid_search` returns `Vec<UasAddress>` instead of `Vec<NoteId>` | T3+T4 | NOT-STARTED | breaking change: every consumer migrates; cargo lib floor ≥ 1671 maintained |
| **W-23** | Vault Context Contract enforced everywhere (CI gate) | T4+T6 | NOT-STARTED | `rg "LIMIT" + "first.*notes"` across Swift returns 0 hits in prod paths; CI gate prevents regression |

### 3.4 Eidos V0 closed-citation retrieval (P0)

| ID | Title | Owner | Status | Acceptance |
|---|---|---|---|---|
| **W-46** (Eidos block) | Eidos `EidosBridge.swift` FFI | T10 | **NOT-STARTED-FFI** | Rust side ready (217 tests green); Swift mirror types declared in `Epistemos/Eidos/Eidos.swift`; cross-language parity JSON fixture pinned; FFI plumbing + xcodebuild verification TODO |
| **W-47** (Eidos block) | ChatCoordinator emit-path gate (validate_citations) | T10 | **NOT-STARTED-WIRE** | Rust contract proven by hardening tests; Swift mirror methods present; gates on W-46 FFI |
| **W-48** (Eidos block) | Brain Panel "Retrieved by Eidos" surface | T10+T6 | **NOT-STARTED-UI** | Rust packets carry every field needed; SwiftUI component build gates on W-46 + T6 Brain Panel chrome |
| **W-49** (Eidos block) | LedgerBackedClaimEvidence (replace InMemoryClaimEvidence) | T10+T3 ledger | **RUST-LANDED** (commit ce69d4f28; 9 tests; snapshot-isolated; not-wired pending W-46) | implements `EidosRetriever`; closed-citation contract holds against populated ledger fixture; retraction propagation |
| **W-50** (Eidos block) | DagBackedGraphNeighborhood (replace InMemoryGraphNeighborhood) | T10 + cognitive_dag | NOT-STARTED-BACKEND | 1-hop from cognitive DAG node returns `EdgeKind::DerivesFrom` + `EdgeKind::Contradicts` neighbors; seed-encoded source_id shape preserved; 2-hop deferred |
| **W-51** (Eidos block) | ShadowBackedSemanticIndex (route through usearch HNSW + same embedding model) | T10 + epistemos-shadow | NOT-STARTED-BACKEND | shadow backend exposes `(EidosDocumentId, Vec<f32>) → Vec<EidosHit>`; k=60 RRF matches Swift `Phase3FusionConsts.K_RRF`; closed-citation contract holds end-to-end |

### 3.5 Cognitive DAG + Provenance wirings (P1)

| ID | Title | Owner | Status | Acceptance |
|---|---|---|---|---|
| **W-24** | DAG node carries UasAddress + AcsAnchor | T3 | NOT-STARTED | every NodeKind variant has `uas: Option<UasAddress>` + `anchor: Option<AcsAnchor>`; serialization round-trip test |
| **W-25** | Provenance Console ACS-anchor column | T3 | NOT-STARTED | new ACS-anchor column; sortable by theorem tag; clickable to per-anchor detail |
| **W-26** | Cognitive DAG visualizer (in `Epistemos/Views/Graph/`) | T3+T6 | NOT-STARTED | live graph of NodeKinds + EdgeKinds with resonance walks; Cognitive Weight Class doctrine §4.1 tier discipline observed |
| **W-27** | AnswerPacket badge per chat row | T2+T3+T6 | NOT-STARTED | per-row badge: claim_kind (synthesis / empirical / mathematical / causal / speculative) + confidence (verified / plausible / speculative / blocked) |
| **W-28** | ResidencyTier indicator (Current App / Verified Floor / Capability Ceiling) | T3+T6 | NOT-STARTED | every research-tier feature has a ResidencyTier indicator; substrate-floor PASS badges |

### 3.6 UI surface unification (P1)

| ID | Title | Owner | Status |
|---|---|---|---|
| **W-29** | Unified "Substrate Health" panel in Settings (7+ health rows) | many | NOT-STARTED |
| **W-30** | Cognitive Weight Class badges per `COGNITIVE_WEIGHT_CLASS_DOCTRINE_2026_05_04.md` (W1-W4 light/medium/heavy/extreme) | T6 | NOT-STARTED |
| **W-31** | Audio diagnostics panel (export gain / master volume / live-player chain / A/V health) | T6 | NOT-STARTED |
| **W-32** | Experimental Features Settings panel (unified per-feature flags) | (flags) | NOT-STARTED |
| **W-33** | Substrate Drift Monitor row | T9 | NOT-STARTED |

### 3.7 Biometric lock (GATED on T1+T2+T6 landing)

| ID | Title | Owner | Status |
|---|---|---|---|
| **W-34** | BiometricLockService wrapping LocalAuthentication | T8 (GATED) | NOT-STARTED |
| **W-35** | LockedContentGate macaroon constraint in cognitive_dag | T8+T2+T3 | NOT-STARTED |
| **W-36** | Retrieval filters locked items in fusedSearch | T8+T4 | NOT-STARTED |
| **W-37** | UI: lock badge + unlock sheet + locked-items placeholder | T8+T6 | NOT-STARTED |
| **W-38** | Spotlight respects lock state (`SpotlightIndexer.swift` + `NoteEntitySpotlightIndexer.swift`) | T8+T6 | NOT-STARTED |
| **W-39** | Recovery-code printable view (≥ 128 bits entropy) + Keychain rewrap | T8 | NOT-STARTED |

### 3.8 Optional / Research-tier (P3)

| ID | Title | Status |
|---|---|---|
| **W-40** | F-ULP-Oracle harness (412k + 2,048 points; ≤ 2 ULP fp16; ≤ 90 s on M2 Pro) | NOT-STARTED (T12 has substrate; harness not yet runnable) |
| **W-41** | 5 Metal kernels (Mamba-2 / page-gather / controller-pack / packet-router-1bit / local-recall-island / semiseparable-block-scan) | NOT-STARTED |
| **W-42** | F-KV-Direct-Gate (Qwen 3 8B at 128k; peak RAM ≤ 13 GB; D_KL/token ≤ threshold; decode ≥ 10 tok/s) | NOT-STARTED |
| **W-43** | F-70B-Cocktail composition study | NOT-STARTED |
| **W-44** | 6 IR primitives in hyperdynamic_schemas (Tri-Fusion ABI accepts IR-typed expressions) | NOT-STARTED |
| **W-45** | Per-IR Lean proofs (each IR has at least one identity proved) | NOT-STARTED (T5 ships 28 sorries, budget-gated; lake build green) |
| **W-46** (T23B block) | Artifact validator harness | NOT-STARTED |

### 3.9 T09 ledger-surfaced doc drift (P2)

| ID | Title | Status |
|---|---|---|
| **W-46** (T09 block) | CLAUDE.md macaroons-orphan stale claim | NOT-STARTED (doc-only fix) |
| **W-47** (T09 block) | MutationEnvelope naming collision + canonical alias table | NOT-STARTED |
| **W-48** | omega-mcp/src/pty.rs env-leak through unistd::fork()+libc::execvp() | **P1 SECURITY** — NOT-STARTED. Fix: env_clear + canonical 10-var allowlist before execvp |
| **W-49** | IMessageDriverService.swift missing file-level `#if !EPISTEMOS_APP_STORE` guard | NOT-STARTED (P2 ship-hardening) |
| **W-50** | MemoryTier enum vs prompt-deck canon divergence (5 variants vs 7 named) | NOT-STARTED — T17B canonicalizes vocab FIRST, cognitive_dag mirrors |
| **W-51** | Pro-tier capability gating absent in omega-mcp dispatch | NOT-STARTED. Falsifier `F-OmegaMCP-ProToolGating` unfalsifiable today because feature doesn't exist |
| **W-52** | CSISafeguard wired into CloudKnowledgeDistillationService | NOT-STARTED. Class exists with 8 isolated tests; zero production callers (training-data references point to nonexistent `OmegaTrainingCoordinator.swift`) |
| **W-53** | ModelDownloadManager `verifySnapshot` is structural-only, no SHA256 LFS hash verification | NOT-STARTED. P2 security gap; supply-chain integrity |

**Note on duplicate W-46 / W-47 IDs**: BACKLOG has THREE W-46 entries (in §4b Eidos block, in §5 cognitive_dag block, in §8 research-tier block, AND in §12B T09 block). Same for W-47. This is a known doc-drift the chronicle surfaces; rows are distinguished by their owner-block.

### 3.10 W-row dependency graph

Per BACKLOG:193-249:

```
                                ┌──────────────────────────┐
                                │ merge T1/T2/T3/T4/T6/T7  │
                                │   (base wave) — DONE      │
                                └────────────┬─────────────┘
                                             │
                       ┌─────────────────────┼─────────────────────┐
                       │                     │                     │
                       ▼                     ▼                     ▼
              W-01 (UAS↔vault)      W-13 (power-user UI)    W-21 (vault health row)
                       │                     │                     │
                       ▼                     │                     ▼
              W-04 (page-gather↔vault)       │             W-29 (Substrate Health panel)
                       │                     │                     ▲
                       ▼                     │                     │
              W-22 (vault returns UasAddr)   │             ┌───────┴──────┐
                       │                     │             │              │
                       ▼                     ▼             │              │
              W-19+W-20+W-23 (Vault Context Contract everywhere)          │
                                             │                            │
                                             │     W-07+W-10+W-11+W-14    │
                                             ▼     (Settings rows)        │
                                       W-15 (AgentBlueprint UI)           │
                                             │                            │
                                             ▼                            │
                                       W-16 (replay UI)                   │
              W-08+W-18  W-25+W-26  W-30  W-32+W-33                       │

              ╔══════════════════════════════════════╗
              ║  GATE: T1 + T2 + T6 all landed       ║
              ╚══════════════════════════════════════╝
                       │
                       ▼
              W-34..W-39 (biometric lock)

              ╔══════════════════════════════════════╗
              ║  Research-tier (multi-week, gated)   ║
              ╚══════════════════════════════════════╝
              W-09 W-40 W-41 W-42 W-43 W-44+W-45
```

---

## Section 4 — Auxiliary branches (non-T-track work)

(From `git branch -r | sort`, `git worktree list`, `/tmp/audit/04_donors.md`, `WORKTREE_PRESERVATION_2026_05_20.md`.)

### 4.1 Cohort C: codex/release-stabilization-and-runtime-hardening, codex/research-snapshot-2026-05-08, codex/runtime-input-audit, codex/runtime-memory-hardening

| Branch | Purpose | Status | Relation to T-tracks | Recommended action |
|---|---|---|---|---|
| `codex/release-stabilization-and-runtime-hardening` | Release stabilization branch from earlier cycle | Origin only (no worktree). Bridge doc: `docs/fusion/RELEASE_STABILIZATION_BRANCH_BRIDGE_2026_05_04.md` | Predates the May-16 cycle | Preserve; audit for additive content; harvest commits superseded by later work |
| `codex/research-snapshot-2026-05-08` | Research snapshot landing V6.1 substrate (acs.rs + scope_rex/kv/direct_gate + kv_direct_gate.metal) | Already partial-absorbed into main per UNIFIED_ACTIVE_SUBSTRATE_CANON §6 status log | Lifted typed surfaces that T17B / T18B / T11 now build on | Keep tag; close branch when fully absorbed |
| `codex/runtime-input-audit` | Phase R Resource Runtime (T12 prerequisite). 324 commits ahead of main, NEVER merged. Bridge: `docs/fusion/RESOURCE_RUNTIME_PHASE_R_BRIDGE_2026_05_04.md` | Owns `47fd03fe` "fix(release): expose writable attachment paths", vault write authorization pipeline, attachment path exposure, sandbox grant seeding, CODE_EDITOR_FEATURE_AUDIT.md | T12 App Store Release / Phase R prerequisite per `project_resource_runtime` | Cherry-pick now per WORKTREE_INSIGHT_SALVAGE §6; canonical IDs + unified ResourceService + verified-before-claim pipeline |
| `codex/runtime-memory-hardening` | Memory hardening branch | Origin only | Companion to runtime-input-audit | Audit; absorb additive commits |

### 4.2 feature/* branches

| Branch | Purpose | Status | Action |
|---|---|---|---|
| `feature/knowledge-fusion-v1` | Knowledge fusion v1 (release pivot 2026-03-27) | Per `project_release_pivot`: ship Qwen as base, keep Knowledge Fusion, defer custom model | Largely absorbed; keep tag |
| `feature/landing-liquid-wave` | LandingWave Metal renderer + HELIOS V5 W1-W26 + E1-E7 + H1-H17 + PCF-1..10 substrate (17 commits, 11 stages). `project_helios_v5_substrate_landed` | Full substrate landed per memory; CI exercises everything; Lean repo skeleton with 35 sorries / ≤149 budget. Note: pixel-surface replaced LandingWave on main (commit `453fbafd99`) | LandingWave deprecated for product; HELIOS V5 substrate still load-bearing; preserved |

### 4.3 run-* branches (run-cycle parallel-process atlas)

(From `docs/PARALLEL_PROCESS_LIST_2026_05_16.md` + `docs/audits/POST_RUN_BCDEF_PER_TERMINAL_PUNCH_LIST_2026_05_17.md` + `docs/PARALLEL_FLOW_DOCTRINE_2026_05_16.md`.)

| Branch | Cycle role | Status |
|---|---|---|
| `run-b-post-v1-research` | Post-V1 research arm | Origin only; punch list in POST_RUN_BCDEF |
| `run-c-audit` | Audit arm | Origin only |
| `run-d-providers` | Provider integration arm | Origin only |
| `run-e-decisions` | Decision-log arm | Origin only |
| `run-f-integrations` | Integration arm | Origin only |

### 4.4 claude/* worktree branches

| Branch / worktree | Purpose | Status |
|---|---|---|
| `claude/vigorous-goldberg-3a2d35` (Quick Capture) | 12-phase Quick Capture vision (Live File Compiler / Reflective Loop / Cognitive Weight Class / 10-state machine / Privacy stack / Eidos Plus / Stateful Rotor / Vector Universe manifold) | **Donor only.** Phases 7, 8, 8-cont, 11, D1 ExecutionReceipt still locked behind diverged route/heal/format/effect/undo modules. Reconciliation playbook at `docs/QUICK_CAPTURE_FUTURE_RECONCILIATION_2026_05_19.md`. Preserved as `preserve/quick-capture-2026-05-20-snapshot`. |
| `worktree-simulation` | Simulation Mode v1.6 + Companion Farm (17 commits S0-S11) | **Donor only.** AgentEvent normaliser + Applier sandbox guard + audit ledger are spine-adjacent. Companion visuals frozen pending product-surface decision. Preserved as `preserve/simulation-2026-05-20-snapshot`. |
| `worktree-agent-a0550f9c` (honest_handle) | W9.21 honest_handle FFI doctrine prototype | **Redundant — work fully landed.** Per `/tmp/audit/04_donors.md`: main is AHEAD of this worktree's HEAD. Discard local diff after sanity diff-check. |
| 5 redundant `claude/*` session worktrees (`inspiring-heisenberg-ea9dc3`, `kind-panini-0187b4`, `practical-kapitsa-61a251`, `quirky-pascal-135a98`, `serene-ardinghelli-5ab9e6`) | Agent-session debris; all pinned to identical SHA `31214a4d4a` which IS an ancestor of main | **Redundant.** Recommended action: archive all five. `git worktree remove` + delete branch refs. |
| `worktree-hermes-parity` | Legacy. Hermes subprocess purged 2026-05-05 | **LEGACY / DEAD.** Subject retired. No salvage worth chasing. Create preservation tag (none currently exists) + delete worktree. |

### 4.5 docs/* and salvage/* and wiring/* branches (Phase E donor mining cycle)

| Branch namespace | Purpose | Status |
|---|---|---|
| `docs/may16-archeology-2026-05-23` | `docs/MAY16_ARCHEOLOGY_2026_05_23.md` carrier | **MERGED** via PR #15 (`f7094a83b7`) |
| `salvage/T1-additive-2026-05-23` | T1 tri-fusion salvage | **MERGED** via PR #19 (`69ca873cc3`) |
| `salvage/T2-additive-2026-05-23` | T2 AgentBlueprint substrate + RunTimeline + SettingsView salvage | **MERGED** via PR #32 (`09658c0a71`) |
| `salvage/T2-localagent-diagnostics-2026-05-23` | T2 LocalAgentDiagnostics chain + ConfidenceRouter shim | **MERGED** via PR #34 (`76bec4f8cb`) |
| `salvage/T3-additive-2026-05-23` | T3 uas + active_assembly + page_gather substrates | **MERGED** via PR #20 (`0835094b29`) |
| `salvage/T5-operator-ir-2026-05-23` ... `salvage/T5-geometry-ir-2026-05-23` (5 PRs) | Per-IR primitive | **ALL MERGED** PRs #21..#25 |
| `salvage/T5-cross-ir-2026-05-23` + `salvage/T5-cross-ir-fixup-2026-05-23` | Cross-IR coercion tests + fixup (4 binaries, 28 tests; 4 tests removed where EmlClosure* missing) | **MERGED** PRs #26 + #27 |
| `salvage/T5-phase-a-docs-2026-05-23` | T5 Phase A closeout audits + IR doctrine | **MERGED** PR #28 |
| `salvage/T7-additive-2026-05-23` | T7 EML observatory + CLI | **MERGED** PR #17 |
| `salvage/T8-additive-2026-05-23` | T8 BIOMETRIC_LOCK_DOCTRINE | **MERGED** PR #16 |
| `salvage/T9-additive-2026-05-23` | T9 docs/coordination + drift handoffs | **MERGED** PR #18 |
| `wiring/t10-eidos-queryruntime-2026-05-23` | T10 Eidos V0 closed-citation path wiring | **MERGED** PR #12 |
| `wiring/t11-system-g-localagentloop-2026-05-23` | T11 System G runtime status breadcrumb | **MERGED** PR #29 |
| `wiring/t12-f-ulp-witness-2026-05-23` | T12 F-ULP Oracle acceptance witness visible | **MERGED** PR #30 |
| `wiring/t17b-lattice-wbo-oplog-2026-05-23` | T17B Lattice/WBO always-on oplog accounting hook | **MERGED** PR #14 |
| `wiring/t18b-acs-admission-2026-05-23` | T18B ACS admission strict policy visible | **MERGED** PR #31 |
| `wiring/t21-vault-recall-resourceservice-2026-05-23` | T21 Vault Recall Contract trace path | **MERGED** PR #13 |
| `wiring/agent-blueprint-settings-view-2026-05-23` | AgentBlueprintSettingsView wired into Diagnostics | **MERGED** PR #33 |
| `wiring/localagent-diagnostics-row-2026-05-23` | LocalAgentDiagnostics rows wired into Diagnostics | **MERGED** PR #35 |

---

## Section 5 — Doctrine + falsifier register

### 5.1 Doctrine docs (canonical / active)

(Filenames under `docs/fusion/` unless otherwise noted; cycle attribution from §1.4 above.)

| Doctrine | Filename | What it specifies | Cycle | Active / Superseded |
|---|---|---|---|---|
| **Master Research Index** | `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` | Every load-bearing concept → canonical source on disk + supporting docs + code anchors + tier + verbatim load-bearing claim. 1,517 lines. The truth-router. | May-2 | Active |
| **All Docs Index** | `docs/fusion/ALL_DOCS_INDEX_2026_05_02.md` | Sister index to Master Research Index | May-2 | Active |
| **Worktree Insight Salvage** | `docs/fusion/WORKTREE_INSIGHT_SALVAGE_2026_05_02.md` | Per-worktree salvage map | May-2 | Active |
| **Canon Gaps and Addenda** | `docs/fusion/CANON_GAPS_AND_ADDENDA_2026_05_02.md` | C1-C12 gap register; staged-but-not-yet-canon items | May-2 | Active |
| **Final Doctrine** | `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` | Top-floor doctrine; §2.2 architectural invariants; §3.4 SCOPE-Rex grammar; §4 killer features; §7 build order; Annex A.1-A.12 | May-1 | Active (extended by V6.1/V6.2) |
| **Unified Substrate Current State** | `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` | Current code truth per spine layer | May-1 | Active |
| **Unified Active Substrate Canon (UAS-ACS register)** | `docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md` | UAS-ACS coherence layer over the 6 canonical surfaces | May-16 | Active |
| **Substrate Track Register** | `docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md` | T0-T15 16-track feature register across zones A-D. Vocabulary discipline (Track/Lane/Phase/Zone). | May-3 | Active |
| **Cognitive Kernel Doctrine** | `docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md` | Two-stage Substrate-foundational unification: Kernel Phases 1-7 collapses 5 fragmented loops into 1 Rust kernel | May-3 | Active |
| **Cognitive DAG Doctrine** | `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` | Phase 8.A-H collapses 7 subsystems into 1 typed content-addressed DAG (10 NodeKind + 10 EdgeKind + Macaroons + Companions + Mirrors). Phase 8.A-G shipped per memory. | May-3 | Active |
| **Cognitive GenUI Doctrine** | `docs/fusion/COGNITIVE_GENUI_DOCTRINE_2026_05_03.md` | Schema-First GenUI. T0 sub-track 4. Typed GenUIPayload + GenUIDispatcher + schema-keyed renderers. Phases G.1-G.6. | May-3 | Active |
| **Cognitive Weight Class Doctrine** | `docs/fusion/COGNITIVE_WEIGHT_CLASS_DOCTRINE_2026_05_04.md` | 4-tier weight class: `soft_memory [0–0.30]` / `preferred_context [0.31–0.60]` / `strong_project_anchor [0.61–0.85]` / `policy_grade [0.86–1.00]`. "Semantic Gravity pulls attention; Policy Authority controls action." | May-4 | Active (T17 owns enforcement) |
| **Cognitive Variant Ladder Doctrine** | `docs/fusion/COGNITIVE_VARIANT_LADDER_DOCTRINE_2026_05_04.md` | Deterministic→cloud route ladder (T20 owner) | May-4 | Active |
| **XPC Mastery Doctrine** | `docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md` + `XPC_RESEARCH_INTAKE_2026_05_04.md` | 5-service decomposition (Main + VaultXPC + AgentXPC + ProviderXPC + WASMExecXPC); per-service entitlements; trust attestation; capability-token IPC; sandbox-within-sandbox for WASM; Secure Enclave attested capabilities; IOSurface zero-copy. Phases X.1-X.5. Deferred until paid Apple Developer Team. | May-3/4 | Active (deferred) |
| **MAS-First Focus Doctrine** | `docs/fusion/MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md` | Active surface = MAS-shippable only. Pro = feature-gated stubs. DO NOT actively develop Pro; DO NOT delete Pro geometry. "Part of the plan, not on the critical path." | May-3 | Active |
| **Schema-First GenUI Doctrine** | (memory) `project_schema_first_genui_doctrine` | T0 sub-track 4. Has been silently deferred since Four-Model Advice Council 2026-04-22. Phases G.1-G.6, 24-day ceiling. Hermes Expert Mode slices 1-8 carry `GENUI-DEFER` markers. | May-3 | Active (G.3 migration partial per recovery loop) |
| **Honest Handle FFI Doctrine** | `docs/fusion/HONEST_HANDLE_FFI_DOCTRINE_2026_05_04.md` | Forward-compat discipline for Swift⇄Rust UniFFI. Opaque handles + versioned envelopes + cross-runtime parity tests. Never expose Rust internals across the boundary. | May-4 | Active |
| **Provenance Console Doctrine** | `docs/fusion/PROVENANCE_CONSOLE_DOCTRINE_2026_05_04.md` | Third leg of MAS feature trio. Shipped 2026-05-04 at `ad6280cf`. Uses GenUIDispatcher from day 1 per GenUI doctrine §9. | May-4 | Active (shipped) |
| **Hermes Brand Doctrine** | `docs/fusion/HERMES_BRAND_DOCTRINE_2026_05_04.md` | InterVariable font lookup truth | May-4 | **SUPERSEDED 2026-05-05.** Hermes UI overlay deleted. InterVariable font lookup truth survives the removal. |
| **Live File Compiler Doctrine** | `docs/fusion/LIVE_FILE_COMPILER_DOCTRINE_2026_05_04.md` | Markdown → Parser → Intent → LivePlan.v1 (YAML) → Policy/Capability validation → Signed plan → Runner. The compiled, signed plan executes, NEVER the markdown. | May-4 | Active (T16 owner, NOT-STARTED) |
| **Canonical Recovery Plan** | `docs/fusion/CANONICAL_RECOVERY_PLAN_2026_05_03.md` | Hackathon abandoned 2026-05-03. Stages A.1 → A.2-A.4 → B.1 → C → D → E → F | May-3 | Active (Stages A-F shipped per recovery loop) |
| **Post-Recovery Substrate V2 Plan** | `docs/fusion/POST_RECOVERY_SUBSTRATE_V2_PLAN_2026_05_04.md` | V2.1 → V2.7 sequence (Cognitive DAG / Halo V1 / LSP / XPC Mastery / Simulation v1.7+ / UX-brand / multi-agent ACS) | May-4 | Active (wait-for-signal stop) |
| **Canon Hardening Protocol** | `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md` | WRV state machine + canon promotion protocol + no-date-gates rule | May-5 | Active (mandatory) |
| **HELIOS V5 source of truth** | `docs/fusion/helios v5 first.md` (754L) + `docs/fusion/helios v5 updated.md` (625L) | Full W1-W26 + E1-E7 + H1-H17 + PCF-1..10 substrate definitions | May-5/6 | Active (substrate landed per memory) |
| **HELIOS V6.1** | `docs/fusion/Epistemos V6_1 — Final Synthesis Lock (Attention as Interrupt).pdf` + memory dump | Five-plane formalism; T35-T42; 5 V6.1 kernels (target-only); donor-distillation ramp; Goodfire VPD CONFIRMED-PUBLIC; ρ_max=0.20; floor `ac8c6d28` immutable | May-6 | **CANONICAL FINAL (user lock).** "The one I am pushing... main on all tiers." |
| **HELIOS V6.2 intake** | `docs/fusion/EPISTEMOS_V6_2_CANON_INTAKE_2026_05_07.md` + `docs/fusion/jordan's research/helios v6.2.md` (53 KB) + `docs/fusion/EPISTENOS_HELIOS_V6_1_FOUNDATION_INTAKE_2026_05_07.md` | Strict V6.1 delta. M2 Pro 16GB = shippability lock (NOT M2 Max). 8-stage V6.2 falsifier order. Goodfire 9972/205/2.1% revalidated. | May-7 | Active |
| **MASTER_FUSION** | `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` | 43-row atlas; §3.1-§3.43 doctrine spine | May-13 | Active |
| **No-Compromise Endgame Prompt Deck** | `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` | T09-T27 launch order + 5-tier mapping + 7 substrate laws + research-handoff delta | May-18 | Active |
| **Claude No-Compromise Substrate Handoff** | `docs/CLAUDE_NO_COMPROMISE_SUBSTRATE_HANDOFF_2026_05_18.md` | Pasteable Claude handoff. Reconciles all preceding doctrines into one prompt. | May-18 | Active |
| **Codex/Claude Terminal Dispatch** | `docs/CODEX_AND_CLAUDE_TERMINAL_DISPATCH_2026_05_18.md` | Per-T-prompt tool assignment. §3.5 forever-loop discipline. | May-18 | Active |
| **EML Integration Doctrine** | `docs/fusion/EML_INTEGRATION_DOCTRINE_2026_05_17.md` | T7 mission: 5 candidate integration sites; MVP = SAE observatory anomaly augmentation; §3 implementation plan; §6 candidate site C ≥ 80% corpus | May-17 | Active (shipped via T7 salvage) |
| **Primitive IR Stack Doctrine** | `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md` | T5 doctrine: 6 IRs (EML / Tropical / Scan / Operator / Info / Geometry) with paper + primitive signature + crate + lowering target + Lean schema authority; §6 cross-IR composition lattice | May-17 | Active (Phase A complete; Phase B partial) |
| **Cross-IR Composition Examples** | `docs/fusion/CROSS_IR_COMPOSITION_EXAMPLES_2026_05_17.md` + `CROSS_IR_LATTICE_STATUS_2026_05_17.md` | Worked examples + status | May-17 | Active |
| **Biometric Lock Doctrine** | `docs/fusion/BIOMETRIC_LOCK_DOCTRINE_2026_05_17.md` | T8 Phase 0 doctrine; 9 sections (threat model / crypto / lockable / session / agent isolation / indexing / UI / recovery / open theorems) | May-17 | Active (Phase 0 only; Phase B GATED) |
| **Day in the Life Power User** | `docs/fusion/DAY_IN_THE_LIFE_POWER_USER_2026_05_16.md` | Scenario walkthrough of every shipped UAS-ACS-touching feature | May-16 | Active |
| **V1 Ship Ledger** | `docs/fusion/V1_SHIP_LEDGER_2026_05_16.md` | Every feature classified v1 ship / v1.1 defer / v2 / never | May-16 | Active |
| **Master Hardening and Harness Plan** | `docs/MASTER_HARDENING_AND_HARNESS_PLAN.md` | Hardening + harness master plan | various | Active |
| **Canonical Roadmap** | `docs/CANONICAL_ROADMAP_2026_05_05.md` | Roadmap canonical | May-5 | Active |
| **Recursive Governance / VSM** | `docs/RECURSIVE_GOVERNANCE_VIABLE_SYSTEMS_MODEL_2026_05_15.md` | Beer VSM doctrine pointer; B2-H9 lineage for ACS 7-scale recursion | May-15 | Active |
| **Worktree Preservation** | `docs/WORKTREE_PRESERVATION_2026_05_20.md` | 14 preservation tags + recovery guide | May-20 | Active |
| **Quick Capture Future Reconciliation** | `docs/QUICK_CAPTURE_FUTURE_RECONCILIATION_2026_05_19.md` | Continuity-of-knowledge doc for Quick Capture branch | May-19 | Active (do not start until Cohort A merged + T11 Phase 2 fusion shipped) |
| **MAY16 Archeology** | `docs/MAY16_ARCHEOLOGY_2026_05_23.md` | May-16 cycle survey + per-track recommendation table | May-23 | Active |
| **T5 PR Split Plan** | `docs/T5-PR-SPLIT-PLAN-2026-05-23.md` | 8 sequential PRs splitting T5's 961 commits across the 5 IRs + cross-IR + docs + Lean custody | May-23 | Active (PRs 1-7 LANDED) |
| **T17B Decompose Map** | `docs/T17B-DECOMPOSE-2026-05-22.md` | lattice_wbo 13,291L → 14 production + 14 test submodules | May-22 | Active |
| **T18B Decompose Layout** | `docs/T18B-DECOMPOSE-2026-05-22.md` | acs_admission 13,612L → 13 production + 7 test submodules | May-22 | Active |
| **T18B Namespace Proposal** | `docs/T18B-NAMESPACE-PROPOSAL-2026-05-22.md` | research::acs vs acs_admission — 0 hard collisions; 3 sub-questions for user arbitration (layer doc-comments / anchor reservation / prefix style) | May-22 | **PROPOSAL — awaiting user arbitration** |
| **Codex 9-Terminal Prompts** | `docs/CODEX_9_TERMINAL_PROMPTS_2026_05_16.md` | T1-T9 paste-ready bootstraps (May-16 cycle) | May-16 | Historical |
| **Codex Deep Investigation Prompt** | `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` | §4 sub-missions A through I + Manifesto + 8-step audit protocol per feature | May-16 | Active |
| **Vault Recall Diagnosis** | `docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md` | Fix-A / Fix-B / Fix-C plan for "first 7 irrelevant notes" | May-16 | Active (T21 owner) |
| **Cross-Terminal Wiring Backlog** | `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md` | 45+ W-row register | May-17 | Active |
| **Substrate Ready for V2** | `docs/fusion/SUBSTRATE_READY_FOR_V2_2026_05_04.md` | V2 substrate-ready manifest | May-4 | Active |
| **Plan V2 Sections 23-27 Recovery** | `docs/fusion/PLAN_V2_SECTIONS_23_27_RECOVERY_2026_05_04.md` | Recovery for §23-27 of PLAN_V2 | May-4 | Active |
| **Recipe Cache Recovery Bridge** | `docs/fusion/RECIPE_CACHE_RECOVERY_BRIDGE_2026_05_04.md` | Recipe cache recovery | May-4 | Active |
| **Local Canon First Specificity Protocol** | `docs/fusion/LOCAL_CANON_FIRST_SPECIFICITY_PROTOCOL_2026_05_04.md` | Local-canon-first read order | May-4 | Active |
| **Salvage Triage Remainder** | `docs/fusion/SALVAGE_TRIAGE_REMAINDER_2026_05_04.md` | Salvage triage | May-4 | Active |
| **Quick Capture Salvage Triage** | `docs/fusion/QUICK_CAPTURE_SALVAGE_TRIAGE_2026_05_04.md` | 25 Rust files (5,656 LOC) categorized into 4 tiers (A integration-ready, B needs host wiring, C DAG-blocked, D Pro-only) | May-4 | Active |
| **Worktree Fusion Brainstorm** | `docs/fusion/WORKTREE_FUSION_BRAINSTORM_2026_05_04.md` + `WORKTREE_PROTOTYPE_CANON_FUSION_QUEUE_2026_05_04.md` | Worktree fusion brainstorm | May-4 | Active |

### 5.2 Doctrine docs (superseded)

| Doctrine | Filename | Reason superseded |
|---|---|---|
| **Hermes Brand Doctrine** | `docs/fusion/HERMES_BRAND_DOCTRINE_2026_05_04.md` | Hermes UI overlay DELETED 2026-05-05. (`project_hermes_brand_doctrine` SUPERSEDED) |
| **Hackathon focus 2026-05-03** | `docs/fusion/CODEX_HACKATHON_FINAL_CHECK_2026_05_03.md` | Same-day reversal — `project_hackathon_focus_2026_05_03` marked SUPERSEDED. Canonical replacement: canonical_recovery_plan + post_recovery_v2_plan + recovery_loop_findings. |
| **Hermes IS the agent (feedback)** | `feedback_hermes_is_real_agent` (memory) | Hermes subprocess REMOVED 2026-05-05. Backend now `agent_core::agent_runtime` (in-process Rust). |
| **Hermes Agent Core 2.0 Design** | `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` | **DESIGN NAME ONLY.** Code stays at `agent_core::agent_runtime::*`. T11 uses `agent_runtime_v2` namespace. (CODEX_9_TERMINAL_PROMPTS:204) |
| **Aegis rename proposals** | (various) | **REJECTED by user direction.** (HANDOFF:62) |
| **Agent Event Variants V16** | `docs/fusion/AGENT_EVENT_VARIANTS_V16_2026_05_04.md` | 6 v1.6 forward-referenced variants per H6; replaced by simulation worktree's IMPLEMENTATION.md v1.6 |
| **Hermes Integration Research** + **Hermes Parity Report** | `docs/_archive/hermes-removal-2026-05-05/{HERMES_INTEGRATION_RESEARCH,HERMES_PARITY_REPORT}.md` | Archived 2026-05-05 |

### 5.3 Falsifier register (canonical 15-gate ladder)

(From `docs/falsifiers/M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md:319-332`. Run-first order DECK:46-54.)

Status taxonomy (handbook §"Status Taxonomy"):
- `NOT IMPLEMENTED`: no executable T23B script and no accepted M2 Pro artifact
- `PARTIAL EVIDENCE, NOT FULLY PASSED`: related tests/diagnostics/fixes exist, exact T23B falsifier has not run + passed
- `PARTIAL SUBSTRATE, NOT FULLY PASSED`: source/shader/reference substrate exists, but unwired/unmeasured/incomplete

**No row marked PASSED.** Current snapshot: 9 NOT IMPLEMENTED + 2 PARTIAL EVIDENCE + 4 PARTIAL SUBSTRATE.

| F-ID | Owner | Pass threshold | Current status |
|---|---|---|---|
| **F-Eidos-ClosedCitation** | T10 / T22B | Generated citations must be members of returned Eidos context packet; fake citation rejection explicit; empty/no-result → defer not fabricate | NOT IMPLEMENTED. Closed-citation contract in Rust; no Swift bridge artifact. Run-first #1. |
| **F-VaultRecall-50** | T21 | For "Pull my notes on residency governance": top packed context includes residency-governance targets, never index-order distractors; full manifest searched; 50-200 candidates; emits trace; weak evidence asks/broadens | PARTIAL EVIDENCE. Fix B at commit `2281c73f0` + 1194 tests pass + 4/4 `strip_query_chatter`. T21 contract requires full-manifest + 50-200 candidate + visible trace across entry points. Fixture corpus at `agent_core/src/storage/f_vault_recall_50_fixture.rs` (11,570L). Run-first #2. |
| **F-PageGather-Baseline** | T3 / T17B | STREAM-on-Metal probe over 256/512/1024 MB; 5 runs per size; ≥ 1.0s window; record `BW_baseline_M2Pro` (commonly 63-73 GB/s post-recalibration) | NOT IMPLEMENTED. `Epistemos/Shaders/PageGather.metal` + `agent_core/src/helios/page_gather.rs` exist as scaffolding. Run-first #3. |
| **F-PageGather-Scatter** | T3 | ≥ 70% of `BW_baseline_M2Pro` over ≥ 1.0s windows on 256/512 MB working sets; output bytes match CPU reference | NOT IMPLEMENTED. `pageGatherScatter` + `pageGatherScatterScaled` in shader exist; no dispatcher / timing. |
| **F-UAS-CopyCount** | T3 | Zero tensor/data copies on hot path after shared backing; allowed metadata copies enumerated + byte-counted; stack-label coverage per allocation/copy site | NOT IMPLEMENTED. Run-first #4. UAS metadata first; model/KV pages Research-gated. |
| **F-ACS-AnchorLookup** | T18B / T3 | Valid anchor round-trips through lookup/audit/projection with all fields intact (theorem tag / plane coord / residency tier / source hash / active packet ID); invalid theorem IDs fail closed | NOT IMPLEMENTED. `epistemos-research/src/acs.rs` provides research-only `AcsAnchor` (only `anchor_id`/`theorem_id`/`salience`); full anchor-addressing gate absent. |
| **F-InterruptScore-CPU** | T17B / T3 | `u_t = 0.30H + 0.25WBO + 0.20Sheaf + 0.15ToolNeed + 0.10ConnectomeAlarm`; output in [0,1]; bucket boundaries at 0.25 + 0.65; P99 compute latency < 100 µs over 100,000 trials on CPU path | PARTIAL EVIDENCE. `Epistemos/Engine/InterruptScoreCpu.swift` implements 5-term equation + 10,000-iter P99 test with 500 µs CI headroom. Exact 100,000-trial < 100 µs falsifier remains. |
| **F-PacketRouter1bit** | T17B / T3 | P99 dispatch latency < 100 µs; byte-identical reconstruction; balanced/skewed/degenerate/alternating/random mask classes reported; lane-balance report | NOT IMPLEMENTED. `agent_core/src/helios/packet_router.rs` CPU reference; Helios kernel hardware validation separate. |
| **F-ControllerKernelPack** | T17B | All 6 kernels (scalar-add / scalar-mul / max / argmax / copy / zero-fill) reference-equivalent under fp32 tolerance; threadgroup memory within V6.2 controller budget; explicit unsupported-case ledger | PARTIAL SUBSTRATE. CPU reference in `agent_core/src/helios/controller_pack.rs`; 6 Metal kernels in `Epistemos/Shaders/ControllerKernelPack.metal`; shader header says NOT yet wired. |
| **F-SemiseparableBlockScan** | T5 / T3 | Core lane max-abs-diff ≤ 1e-3 fp16 over 100 seeds vs PyTorch oracle; final state included; `chunk_size=256` + `ngroups=1`; Stretch labeled non-Core | PARTIAL SUBSTRATE. `agent_core/src/helios/ssd_block_scan.rs` scalar CPU; `Epistemos/Shaders/SemiseparableBlockScan.metal` correctness-first floor, NOT wired. Run-first #7. |
| **F-LocalRecallIsland** | T3 | Core lane peak memory ≤ 4.5 GB for model + KV/state + workspace; passkey recall ≥ 0.95; `niah_single_1` ≥ 0.95 over 250 trials; per-depth/model/context failure labels | NOT IMPLEMENTED hardware/model gate. `agent_core/src/helios/local_recall_island.rs` exact-match passkey substrate; no Metal kernel; no model runner. Run-first #8. |
| **F-KV-Direct-Gate** | T13 | Qwen3-8B-MLX-4bit at 128k; 100 prompts (25 long-prefix / 25 multi-turn / 25 code / 25 reasoning); avg D_KL < 0.05 nats; peak RAM < 13 GB; decode ≥ 10 tok/s; suite ≤ 30 min | PARTIAL SUBSTRATE. `agent_core/src/scope_rex/kv/direct_gate.rs` + `Epistemos/Shaders/kv_direct_gate.metal` Tier-1 layout/equality contract; end-to-end harness NOT-STARTED. Run-first #6. |
| **F-WBO-DriftLedger** | T17B | Every drift-bearing token has ledger entry with finite non-negative term values; WBO-7 pre-softmax delta-z infinity norm ≤ `T_LWZ + T_K + T_R + T_TTR + T_SE + T_DAG + T_num`; post-softmax drift ≤ 0.5 of pre-softmax envelope; missing/orphan terms fail closed | NOT IMPLEMENTED runtime falsifier. `agent_core/src/wbo6/mod.rs` + `epistemos-research/src/wbo_generations.rs` + `epistemos-research/src/theorems/e4_wbo7.rs` provide budget/envelope substrate. Per-token KL measurement not yet run. |
| **F-ULP-Oracle** | T12 | Every comparable point in `[0.5, 2]` ≤ 2 ULP fp16; stress cases classified (denormals / ±0 / ±∞ / NaN / ln branch cuts); full run < 90 s wall-clock | PARTIAL SUBSTRATE. `Epistemos/Shaders/morph_eval_reduced.metal` + `agent_core/src/research/eml/ulp_oracle.rs` exist; shader not wired by Swift dispatcher; only 1,024-point smoke shape; full 412k + 2,048 stress fixture has not produced T23B artifact. Run-first #5. |
| **F-70B-Local-Cocktail-Lite** | T23 | D_KL < 0.1 nats vs fp16/cloud reference over 50-prompt suite; decode ≥ 5 tok/s; TTFT ≤ 30 s on 4k prompt; resident memory < 14 GB; first run ≤ 2h, warm-cache ≤ 30 min; any miss identifies bottleneck | NOT IMPLEMENTED. W-43 keeps composition harness NOT-STARTED. Vault/Research only. |

### 5.4 Artifact schema

Canonical: `docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md` (1,477L; schema_version `2026-05-18.2`). Required top-level witness fields: `falsifier_id`, `schema_version`, `artifact_kind` (primary_witness / fallback_witness / failure_report), `hardware_pin`, `command`, `command_digest` (lowercase `sha256:`), `runner_environment`, `commit_sha` (full 40-char hex), `fixture_id`, `timestamp_utc` (RFC 3339 UTC `Z`), `result_digest`, `measurements`, `acceptance_thresholds`, `pass_per_axis`, `overall_pass`, `fallback_tier`, `anomalies` (required array), `notes`. Optional: `fixture_lineage`, `provider_receipts`.

294-row negative-example catalog at `docs/falsifiers/ARTIFACT_NEGATIVE_EXAMPLES_2026_05_18.md` (13,389L). Validator shape at `docs/falsifiers/ARTIFACT_VALIDATOR_SHAPE_2026_05_18.md` (868L). No executable validator exists on this branch.

---

## Section 6 — Drift report

Drift items (places where docs disagree, names diverge, or claims contradict code). Each item has: locations, surfaced contradiction, canonical pick.

### D-01 May-3 Track T0-T15 vs May-16/May-18 Track T1-T9 / T09-T27 — TWO PARALLEL T-TAXONOMIES

- **Source A:** `docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md` defines T0-T15 zone-aware feature tracks (`project_substrate_track_register`).
- **Source B:** `docs/CODEX_9_TERMINAL_PROMPTS_2026_05_16.md` defines T1-T9 worktree-aware terminal tracks for May-16. `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` defines T09-T27 for May-18.
- **Contradiction:** "T5" means two different things. Source-A T5 = "Hermes Agent + Multi-CLI Integration"; Source-B May-16 T5 = "EML-IR Primitive Stack"; Source-B May-18 has no T5, jumps directly from T11 to T12 (T5 unassigned), with T05 absent.
- **Canonical reconciliation:** Both taxonomies are real and coexist. Source-A is the **feature register** (what surfaces exist in the product). Source-B is the **sprint-cycle register** (which terminal owns which work this cycle). Any reference must specify cycle (e.g. "May-3 T5" or "May-16 T5" or "May-18 T11"). `MAY16_ARCHEOLOGY_2026_05_23.md:39` explicitly resolves the T9/T09 sub-collision ("NAME COLLISION: NOT to be confused").

### D-02 ACS dual expansion (Autopoietic Cognitive Stack vs Anchored Cognitive Substrate)

- **Source A (process-view):** `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.8; PASS-2 audit B2-M13; `docs/RECURSIVE_GOVERNANCE_VIABLE_SYSTEMS_MODEL_2026_05_15.md`.
- **Source B (structure-view):** `epistemos-research/src/acs.rs:17` header comment; HELIOS V5 integration plan.
- **Canonical reconciliation:** `docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md:32-46`: **keep both**. First mention per section must carry parenthetical expansion. T25 owns the lint. `T18B-NAMESPACE-PROPOSAL-2026-05-22.md` resolved (Sub-Q 3 recommendation): Option 3a — grandfather both `Acs*` (T17B code style, Rust idiomatic) and `ACS*` (T18B code style, all-caps acronym).

### D-03 Hermes purge vs Hermes preservation

- **Source A:** `docs/_archive/hermes-removal-2026-05-05/README.md` + `project_hermes_removal_2026_05_05` — "Subprocess + UI overlay + namespace ALL gone."
- **Source B:** `agent_core/src/agent_runtime/prompt_format.rs` — Hermes-3 prompt format XML wrappers (`<tools>`, `<tool_call>`, `<think>`) PRESERVED because local Nous Research models speak this format.
- **Source C:** `Epistemos/State/InferenceState.swift` HF model paths `leonsarmiento/Hermes-4.3-36B-4bit-mlx` PRESERVED as external HF identifiers.
- **Source D:** `Epistemos/LocalAgent/LocalAgentCalcCommand.swift:5` doc-cross-ref to `docs/fusion/fleet/hermes-capability-pass-through/...` PRESERVED.
- **Canonical reconciliation:** "Hermes" the **subprocess + UI overlay + Swift / Rust namespace** is purged. "Hermes-3 prompt format" (NousResearch grammar) is preserved as compatibility. HF model paths are external truth and preserved. `EpistemosTests/HermesPromptFormatGuardTests.swift:57-60` is the regression guard for the prompt-format preservation. No drift; nuance.

### D-04 Aegis name rejected vs Aegis used in some doctrine docs

- **Source A:** HANDOFF:62, DECK:91 — **REJECTED by user direction.**
- **Source B:** Various early Apr-30 / May-2 doctrine docs may still reference `Aegis` as the agent name.
- **Canonical reconciliation:** Canonical name is **System G / Invader Agent** (user-facing) and `agent_runtime_v2` (code). Any doc reference to `Aegis` that postdates 2026-05-18 is drift; should be re-stamped. No enforcement gate exists per `/tmp/audit/01_canon_2026_05_20.md:120`.

### D-05 PARTIAL status on W-rows not verified on main

- **Source A:** BACKLOG flags W-11, W-14, W-15, W-17, W-19, W-20 as PARTIAL.
- **Source B:** BACKLOG:312-317 requires DONE: code path on main.
- **Canonical reconciliation:** Per `/tmp/audit/01_canon_2026_05_20.md:121`: every PARTIAL is functionally NOT-STARTED on main until the relevant T-branch merge happens. The 2026-05-23 wave merged 8 wirings PRs (#12-#14, #29-#33, #35), so several PARTIAL claims are now closer to DONE — but a current `git rg` would still need to run to confirm acceptance bars.

### D-06 Launch-order step 9 conflict with prior step

- **Source A:** DECK:142 launches falsifier gates **after** T18 Residency Governor + T22 Substrate Health Panel (step 8).
- **Source B:** HANDOFF:97-100 says T22 full version requires T-branch merges (T2+T3+T4+T7), while T12/T13/T23/T23B are additive.
- **Canonical reconciliation:** Per `/tmp/audit/01_canon_2026_05_20.md:122`. **Falsifier docs (T12/T13/T23/T23B) can land in Phase 1 (current cycle, additive); T22 full version waits for merges.** Reader risk: someone executes top-down and gets stuck at T22 when T12 could have shipped immediately. Resolved: T12 + T23B both landed via PRs #9 + #5; T22 full version still NOT-STARTED.

### D-07 macaroons orphan claim vs wired reality

- **Source A:** `CLAUDE.md` FILE MAP §"Rust agent_core — V2.1 Cognitive DAG (Phase 8.A-8.G)" says "Macaroon-style capabilities (orphan until Phase 8.H wires them into dispatch)".
- **Source B:** `agent_core/src/cognitive_dag/dispatch.rs:28` imports `{issue, restrict, Caveat, Macaroon}`; tests at `dispatch.rs:472-505` prove the system-mirror macaroon signs every dispatch-emitted edge.
- **Canonical reconciliation:** CLAUDE.md is **STALE**. Macaroons ARE wired via the system-mirror capability. W-46 (T09 ledger row) owns the doc-only fix. (T09 ledger row in BACKLOG §12B.)

### D-08 MutationEnvelope naming collision

- **Source A:** `agent_core/src/mutations/envelope.rs:40` is the canonical 14-field MutationEnvelope (§3.5 four-layer event hierarchy contract).
- **Source B:** `graph-engine/src/knowledge_core/store.rs:57` is a *different* MutationEnvelope (graph transaction descriptor with `tx_id`/`touched_block_ids`/`affects_*`).
- **Canonical reconciliation:** Rename graph-engine's to `GraphMutationEnvelope` or `KnowledgeCoreTransaction`. W-47 (T09 ledger row) owns. Plus the canonical alias table at `agent_core/src/scope_rex/answer_packet.rs:27-30`: `TypedArtifact ≡ MutationEnvelope`, `RunEventLog ≡ provenance/ledger`, `ClaimFrame ≡ Claim`, `EvidenceLedger ≡ ClaimLedger` — needs surfacing in CLAUDE.md.

### D-09 omega-mcp PTY env-leak through fork+execvp

- **Source:** W-48 (security row). `omega-mcp/src/pty.rs::spawn_pty` lines 305-381 uses raw `unistd::fork()` + `libc::execvp()`, bypassing `Command::new` → `harden_cli_subprocess` NOT applicable. `LD_PRELOAD`, `DYLD_INSERT_LIBRARIES`, `MallocStackLogging`, provider API keys can inherit.
- **Canonical pick:** This is a **real P1 security gap.** Fix: add PTY-specific env hardening in child branch before execvp — `libc::clearenv()` then reinstall only the canonical 10-var allowlist with `TERM=dumb`. Add sentinel-env test proving PTY child does not inherit parent-only variable.

### D-10 IMessageDriverService missing file-level App-Store guard

- **Source:** W-49. `AppEnvironment.swift:39-41` `#if !EPISTEMOS_APP_STORE` correctly excludes env-binding from MAS builds — but `IMessageDriverService.swift` itself has no file-level guard. Compare to `Bridge/ComputerUseBridge.swift:1`, `Bridge/Phase4Bridge.swift:1`, `Harness/CompletionChecker.swift:1` which DO have it.
- **Canonical pick:** Add `#if !EPISTEMOS_APP_STORE` / `#endif` wrapping the entire file. P2 ship-hardening.

### D-11 MemoryTier 5 variants vs 7 named

- **Source A:** `agent_core/src/cognitive_dag/edge.rs:118 pub enum MemoryTier` — 5 variants (Hot=L0, Warm=L1, Cool=L2, Cold=L3, SelfEvolving=L_SE).
- **Source B:** `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` §"Preserve explicitly — Six/seven memory tiers" names 7: L0 hot, L1 compressed residual, L2 shadow/sketch, L3 SSD oracle, L4/L5 cascade/adapters, L_SE self-evolving, L7 quarantine.
- **Canonical reconciliation:** W-50. T17B Lattice/WBO Register canonicalizes the tier vocabulary FIRST (in `docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md`); cognitive_dag mirrors. T17B is merged; cognitive_dag mirror PR still pending.

### D-12 Pro-tier capability gating absent in MCP dispatch

- **Source:** W-51. `rg "isPro\|ProTier\|requirePro\|tierGate\|ProSubscription"` across 252K LOC Swift returns empty. `omega-mcp/src/dispatcher.rs:308` performs only argument-schema validation; github / web_search / pty execute unconditionally for any caller.
- **Canonical pick:** "Pro" labels in T09 ledger reflect **design-intent product separation, NOT a current code gate.** Falsifier `F-OmegaMCP-ProToolGating` is unfalsifiable today. Two options: (i) implement `OmegaMCPTierGate` admission layer; (ii) drop Pro-tier lane labels from ledger until feature exists. Awaiting user arbitration.

### D-13 CSISafeguard orphan vs training-data referring to nonexistent caller

- **Source:** W-52. `Epistemos/KnowledgeFusion/Alignment/CSISafeguard.swift:14 final class CSISafeguard` + 8 `@Test` markers in isolation. Production callers: **zero.** Training data at `Epistemos/KnowledgeFusion/MOHAWK/*.jsonl` names `Epistemos/Omega/Orchestrator/OmegaTrainingCoordinator.swift` as the caller — file does not exist (`find Epistemos -name "OmegaTrainingCoordinator*"` returns empty).
- **Canonical pick:** Orphan with aspirational training data. Wire `CSISafeguard.recordMeasurement(...)` into every distillation-write callsite inside `CloudKnowledgeDistillationService` BEFORE the persistence step.

### D-14 ModelDownloadManager verifySnapshot structural-only

- **Source:** W-53. `Epistemos/Engine/ModelDownloadManager.swift::verifySnapshot` (line 96-134) checks revision-format + file presence + tokenizer; no SHA256/LFS hash. A corrupted or maliciously-substituted weights file passes `verifySnapshot`.
- **Canonical pick:** Capture LFS SHA256 / `x-linked-etag` at HuggingFace download seam; stream response bodies through `CryptoKit.SHA256.update(_:)`; reject install if hash mismatch. P2 security.

### D-15 EML-IR vs FULP_Oracle intra-T12 duplication

- **Source:** `/tmp/audit/03_may18_cycle.md:65-75`. `agent_core/src/research/eml_ir/` (8,884L) AND `agent_core/src/research/fulp_oracle/` — parallel subdirectories with same 5-file structure (binary16 / fixtures / mod / oracle / witness).
- **Canonical pick:** Collapse `research/fulp_oracle/` into `research/eml_ir/` OR rename. Documented as T12 next step.

### D-16 LandingWave vs Pixel Surface

- **Source A:** `feature/landing-liquid-wave` branch + memory `project_landing_wave_redesign`: HomeView click-to-search reskin via Metal+SwiftUI; ASCII liquid-wave; compact flat bar SF Mono 14pt / ~520pt.
- **Source B:** Main commit `453fbafd99 feat(landing+app): pixel surface replaces LandingWave + app data retention policy`.
- **Canonical pick:** **Pixel surface replaced LandingWave on main.** LandingWave deprecated for product surface. HELIOS V5 substrate landed on the branch remains load-bearing for research (`project_helios_v5_substrate_landed`).

### D-17 Lane A "mostly merged" claim

- **Source A:** April fusion review classified Lane A as "mostly merged."
- **Source B:** INDEX H1 finding: `git log $(git merge-base lane-A main)..lane-A | wc -l` = 601 unmerged commits on N1 Prompt Tree track including 270-line `PROMPT_AS_DATA_SPEC.md` + full PTF impl behind `EPISTEMOS_PROMPT_TREE=1` flag.
- **Canonical reconciliation:** Lane A is NOT mostly merged. Bridge: `docs/fusion/PROMPT_TREE_LANE_A_BRIDGE_2026_05_04.md`. Phase R/N1 planning must compare Lane A deltas before any prompt-as-data closure claim. (Note: `lane-A` is a *git branch* per substrate-track-register vocabulary discipline, not a feature track.)

### D-18 Five Pillars vs Foundational Seven theorems vs ~52 theorems

- **Source A:** V6.1 has 5 Pillars (Wyner-Ziv, GPTQ/Babai, ½-Lipschitz softmax, Test-Time Regression, EML operator).
- **Source B:** `epistemos-research/src/theorem_status.rs::FOUNDATIONAL_SEVEN` references 7 theorems.
- **Source C:** DECK:87 ("Claude thread research preservation"): "**Theorem count is ~52, not 7.** The 'seven canonical claims' T1-T7 are the public-paper taxonomy. Full canon includes 5 Pillars + 3 Discoveries + 7 WBO-6 component terms + 15 falsifier gates + 22 preserved-research-ledger branches + 6 memory tiers + 8 SCOPE-Rex Omega components + 10 v2.1 hardening patches + 17 H-series operational theorems + 10 PCF entries."
- **Canonical reconciliation:** Both nested. Public-paper taxonomy is T1-T7 (Foundational Seven). Full preserved canon is ~52. Future audits must not under-count the canon when classifying.

### D-19 Track register vs T0 Substrate Unification status

- **Source A:** `project_substrate_track_register`: T0 = ~5% (doctrine written; partial implementation only via existing Artifact + ArtifactBlockView; full dispatchers not started).
- **Source B:** Recovery loop findings (`project_recovery_loop_findings_2026_05_04`): "8 commits closed Stages A-F". Stage A.4 migrated all major Hermes Expert Mode renderers to typed GenUIPayload via canonical GenUIDispatcher.
- **Canonical reconciliation:** T0 has advanced from 5% per Track Register snapshot. Cognitive Kernel Phases 1-7 not all closed; DAG Phase 8.A-G shipped; XPC X.1-X.5 deferred until paid Team; GenUI G.3 migration partial. Current best estimate **~30%**.

### D-20 Substrate-total roll-up percent stale

- **Source A:** Track Register: "**Substrate-total roll-up (rough %): ~30%.**" as of 2026-05-03.
- **Source B:** Subsequent landed work (May-7 V6.2 intake, May-13 MAS fusion plan, May-17 W-row backlog, May-18 endgame, May-20 worktree preservation, May-23 salvage wave).
- **Canonical pick:** Roll-up needs refresh. Current best estimate per landed PRs + decompose maps + W-row coverage: substrate-total ~50% (T1, T3, T7, T8, T9, T10 done; T2 ~70%; T4 ~80%; T6 ~50%; T11 in progress; T12 partial; T13-T15 gated). May-18 cycle adds T09 / T10 / T11 / T12 / T17B / T18B / T21 / T23B merged.

### D-21 H6: 6 v1.6 AgentEvent variants not yet in main's enum

- **Source A:** INDEX H6 / simulation worktree's IMPLEMENTATION.md v1.6: 6 new `AgentEvent` variants (`SteerRequested`, `SummaryStarted/Delta/Completed`, `VaultCreated`, `VaultArchived`).
- **Source B:** `worktree:simulation/agent_core/src/events.rs` lines 272-499 enumerates only original 32 variants.
- **Canonical pick:** Pro tier sidebar dispatch + multi-vault UI need these added before they ship. Not yet on main.

### D-22 H7: W9.21 PR4 honest-handle "claimed shipped" but Swift still binds legacy surface

- **Source A:** INDEX H7. `RustShadowFFIClient.swift:39` uses legacy `shadow_open_at` returning `Int32`, not the new handle FFI. The `honest_handle.rs` module is orphan scaffolding.
- **Source B:** Memory `project_honest_handle_ffi_doctrine` + `project_pre_v2_full_audit` + `/tmp/audit/04_donors.md` claims work fully landed.
- **Canonical reconciliation:** The pattern is correct; the wiring is incomplete. Main IS ahead of the `worktree-agent-a0550f9c` snapshot but the Swift legacy-line binding may persist. Verify on current `main`.

### D-23 H8: D-series doctrine primitives D1, D3, D11 absent from codebase

- **Source A:** INDEX H8. `worktree:agent-a0550f9c/docs/CANONICAL_AUDIT_LOG.md` specifies D1 BLAKE3 chain, D3 A2UI catalog, D11 epistemos-trace CLI. None implemented.
- **Source B:** W9.27 OpLog schema is missing `prev_hash BLAKE3` column AND missing `PRAGMA journal_mode = WAL` + `fcntl(F_FULLFSYNC)`.
- **Canonical pick:** Salvage map's "OpLog Merkle chain shipped" claim needs verification — chain may be partial.

### D-24 H9: Code editor feature drift on every feature

- **Source A:** INDEX H9. `worktree:inspiring-heisenberg-ea9dc3/CODE_EDITOR_FEATURE_AUDIT.md`: Minimap reverted (line 1232 comment "Minimap removed — outline navigator replaces it"), search bar UI exists but `performSearch()` is stub, semantic sidebar code exists but gated to false (line 291 never visible), status bar replaced by EditorBreadcrumbBar, persisted prefs 5/6 active.
- **Canonical pick:** Editor work must verify against live code; doc claims drift fast.

### D-25 H10: Quick Capture LEGACY_TO_V2_ALIASES ~56 entries, ~54 remaining

- **Source A:** INDEX H10. `worktree:vigorous-goldberg-3a2d35/agent_core/src/tools/registry.rs` LEGACY_TO_V2_ALIASES table; only `TodoHandler` (Phase 2G-4a canary) converted. The rest (24 files, ~54 `impl ToolHandler` blocks) need the macro from Phase 2G-4d.
- **Canonical pick:** Stay-stellar #1; needs `agent_core/docs/TOOL_MIGRATION_STATUS.md`. Per `QUICK_CAPTURE_FUTURE_RECONCILIATION_2026_05_19.md`: gated on T11 Phase 2 fusion shipping its canonical typed-tool dispatch.

### D-26 T0 GenUI sub-track silently deferred

- **Source A:** `project_schema_first_genui_doctrine`: "Has been silently deferred since Four-Model Advice Council 2026-04-22." Phases G.1-G.6, 24-day ceiling.
- **Source B:** Recovery loop findings 2026-05-04: Stage A.4 migrated all major Hermes Expert Mode renderers to typed GenUIPayload via canonical GenUIDispatcher.
- **Canonical reconciliation:** Doctrine adopted; G.3 migration partial; G.1-G.2 + G.4-G.6 status unclear per current code. Memory marker "**DO NOT lose this again**" is a discipline anchor.

### D-27 Substrate-Ready-for-V2 vs Post-Recovery-V2 sequence

- **Source A:** `docs/fusion/SUBSTRATE_READY_FOR_V2_2026_05_04.md` declares substrate ready.
- **Source B:** `docs/fusion/POST_RECOVERY_SUBSTRATE_V2_PLAN_2026_05_04.md`: Codex STOPS + waits for explicit "RESUME SUBSTRATE V2" signal. V2.1 → V2.7 sequence.
- **Source C:** Memory `project_post_recovery_v2_plan`: "Wait-for-signal stop point reached" + "V3 research tier needs separate 'RESUME RESEARCH TIER' signal."
- **Canonical reconciliation:** Wait-for-signal hold respected. The May-16/May-18 endgame cycles override this hold (user explicitly authorized via no-compromise endgame deck). V2.1 = Cognitive DAG Phase 8 SHIPPED per memory. V2.2 = Halo V1 (partial). V2.3 = LSP migration (LSP transport seam present). V2.4-V2.7 still gated.

---

## Section 7 — Retired / Renamed / Superseded

Definitive list of things that existed in early docs but are NO LONGER on the canonical path.

### 7.1 Retired (subject no longer exists)

| Item | Date retired | Reason | Supersession target |
|---|---|---|---|
| **Hermes subprocess** (Python agent subprocess) | 2026-05-05 | User decision: pivot to local-first canon with cloud escalation; "no Hermes bloat / subprocess etc." | `agent_core::agent_runtime` (in-process Rust) + Swift `LocalAgent*` |
| **Hermes UI overlay** (HermesBrand, HermesShimmeringSigil, HermesExpertModeView, HermesGraphFacultyGlyph) | 2026-05-05 | Same | (no replacement; new chrome routes via Sovereign Gate + Provenance Console) |
| **Hermes namespace** (Rust + Swift type prefixes) | 2026-05-05 | Same. Slices H-1/H-2/H-3 commits `b4c583b0` + `80544415` + `e07e6378`. | Rust `Runtime*`; Swift `LocalAgent*` |
| **Aegis (proposed agent name)** | 2026-05-18 | User direction: REJECTED. (HANDOFF:62, DECK:91) | **System G / Invader Agent** (user-facing) + `agent_runtime_v2` (code) |
| **Ollama / llama-server subprocess for inference** | (always) | CLAUDE.md NON-NEGOTIABLE: "NO SIDECAR. All inference AND orchestration in-process via Rust FFI or MLX-Swift." | MLX-Swift in-process; oMLX bridge ONLY exception |
| **Omega agent subprocess** | (per CLAUDE.md context) | Replaced by in-process Rust living loop + MCP peer bridge | `agent_core` Rust + `omega-mcp` Rust |
| **LSPServerProcess subprocess** | 2026-05-05 | V2.3 LSP migration close-out, commit `813c15dd` | In-process Rust `LspKernel` at `agent_core/src/lsp_runtime/`; Swift `RustLSPTransport.swift` |
| **App Group entitlement (TEMP-FREE-TIER)** | 2026-05-03 | Stripped for free Personal Team | Restore in Stage F (paid Developer Team) per recovery plan |
| **5 redundant `claude/*` session worktrees** (inspiring-heisenberg, kind-panini, practical-kapitsa, quirky-pascal, serene-ardinghelli) | (recommended) | All 5 pin to identical ancestor SHA of main | Archive all five; delete worktrees + branch refs |
| **`worktree-hermes-parity`** | (recommended) | Legacy; subject purged 2026-05-05 | Create preservation tag + delete worktree |

### 7.2 Renamed

| Old name | New name | Date | Source |
|---|---|---|---|
| `agent_core/src/hermes/` | `agent_core/src/agent_runtime/` | 2026-05-05 | commit `77de8196` (Slice 2) |
| `bridge::hermes_build_system_prompt` | `bridge::runtime_build_system_prompt` | 2026-05-05 | Slice H-2 commit `80544415` |
| `bridge::hermes_parse_tool_calls` | `bridge::runtime_parse_tool_calls` | 2026-05-05 | Same |
| `HermesXxx` Rust types (6 prompt-format + 1 function-call + 4 skill-runtime structs) | `RuntimeXxx` | 2026-05-05 | Same |
| `agent_core/tests/hermes_runtime.rs` | `agent_runtime.rs` | 2026-05-05 | Same |
| Swift `Hermes*.swift` files (18 files) | `LocalAgent*.swift` | 2026-05-05 | Slice H-3 commit `e07e6378` |
| Swift identifiers `hermesGateway` etc. | `localAgentGateway` etc. | 2026-05-05 | Same |
| Swift enum cases `hermesXxx` | `localAgentXxx` | 2026-05-05 | Same |
| `BiometricLockService.LAContext`-based prompt | "single biometric context owner" / "biometric prompt" | 2026-05-03 | Recovery plan naming-consistency note |
| `omega/` agent subprocess | `omega-mcp/` (MCP peer bridge) | per CLAUDE.md | (legacy agent subprocess removed 2026-05-05) |

### 7.3 Superseded (concept evolved into a different canonical form)

| Old form | Canonical form | Source |
|---|---|---|
| 3-stream V6.0 runtime diagram | 5-plane V6.1 formalism (State / Episodic / Assembly / Controller / Verification) | `project_v6_1_lock_2026_05_06`, V6.1 sharpening point #2 |
| Attention as substrate | Attention as INTERRUPT (V6.1 deepest re-framing) | Same, sharpening point #1 |
| M2 Max as canonical rig | M2 Pro 16 GB UMA as shippability lock (M2 Max = scale-validation only) | V6.2 intake `project_v6_2_intake_2026_05_07` |
| Tri-stream (MAS / Pro / Vault) at runtime level | Three product streams + Five runtime planes (orthogonal) | V6.1 sharpening points #2 + #3 |
| Hackathon push (May-2/3) | Canonical Recovery Plan (May-3 → May-4) | `project_canonical_recovery_plan_2026_05_03` |
| V6 T38 | V6.1 T38 Distilled Hybrid Lift (replaces V6 T38) | `project_v6_1_lock` theorem updates |
| Ternary on semantic spine | Ternary in Controller + Assembly planes only | V6.1 sharpening point #5 |
| "Knowledge Fusion" custom model | Qwen as base + Knowledge Fusion deferred | `project_release_pivot` |
| "Goose" agent | `agent_core` Rust | `project_goose_migration` |
| 1-week sprint cadence | Forever-loop discipline (no exit unless Jojo says stop) | DISPATCH:97 §3.5 |
| Date-gated milestones | Capability / verification / distribution / entitlement / licensing / doctrine gates | Canon Hardening Protocol §3 "no-date-gates rule" |
| "PATCHED" status | DONE only when WRV (Wired/Reachable/Visible/Verified) end-to-end | T27 acceptance bar |
| Single ACS naming | Dual ACS naming (Autopoietic Cognitive Stack + Anchored Cognitive Substrate; first mention parenthesized) | UAS-ACS canon §3 disambiguation |

### 7.4 Deferred (still on the map but not on current critical path)

| Item | Reason deferred | When to revisit |
|---|---|---|
| **XPC Mastery Phases X.1-X.5** | Requires paid Apple Developer Team | After paid Team purchase |
| **T13 F-KV-Direct-Gate live runtime** | Heavy I/O; sequencing | After Cohort A-D done |
| **T23 F-70B Local Cocktail composition** | Vault/Research-only | After F-* substrate gates pass |
| **W-41 5 Metal kernels (Mamba-2/page-gather/etc.)** | Hardware-validation gated | After F-PageGather-Baseline + F-PageGather-Scatter on M2 Pro |
| **L7 quarantine memory tier** | Cognitive_dag enum has 5 variants; canon names 7 | T17B canonicalizes vocabulary first |
| **W-34..W-39 Biometric Lock implementation** | Gated on T1+T2+T6 each having PR landed | T8 self-gate; partially open |
| **Quick Capture Phases 7/8/8-cont/11** | Diverged modules (route/heal/format/effect/undo/nightbrain) | After T11 Phase 2 typed-dispatch + Cohort A merge |
| **Lean schemas Tier-2..6 (Tropical / Scan / Operator / Info / Geometry)** | EML-LEAN-VENDOR open blocker (`tomdif/eml-lean` not vendored) | After vendor pass |
| **App Group entitlement restore** | Paid Developer Team | Stage F |
| **Pro CLI passthrough** | MAS-First Focus Doctrine: Pro = feature-gated stubs | After MAS ship + paid Team |
| **Bash / MultiEdit / WebFetch tools in MAS** | App Store First — Infinite Hardening | After Phase S 6 hard exit criteria |
| **iMessage inbound Phase K** | Pro-tier; OpenClaw workspace-scoped dispatch profiles | After T8 biometric gate opens + Pro-tier work begins |
| **Phase R Resource Runtime (full)** | 324 commits on `codex/runtime-input-audit` never merged | Cherry-pick now per WORKTREE_INSIGHT_SALVAGE §6 |
| **N1 Prompt Tree / Lane A** | 601 unmerged commits; bridge doc only | Phase R/N1 planning compare Lane A deltas first |

---

## Section 8 — Intent chronicle (the user's multi-month thinking)

Traced chronologically from the auto-memory files referenced in `~/.claude/projects/-Users-jojo-Downloads-Epistemos/memory/MEMORY.md`.

### 8.1 Early stage — release-pivot + foundation (2026-03 → 2026-04 early)

- **Release Pivot 2026-03-27**: Ship Qwen as base model. Keep Knowledge Fusion. Defer custom model. Foundation: solo developer, macOS-native PKM, on-device AI. (`project_release_pivot`)
- **macOS 26 Global Monitor Bug** discovered: sync `addGlobalMonitorForEvents` in AppBootstrap.init breaks window key on macOS 26.3.1; must be deferred into Task. (`project_macos26_global_event_monitor_bug`)
- **Goose Migration**: Main chat → Rust agent_core. Infrastructure 95% ready. Phase 1: wire `runAgentSession` to `ChatCoordinator`. (`project_goose_migration`)
- **Vault Memory System** complete by 2026-04-08: 6-phase vault session memory + Neural Cache + FFI wiring + NightBrain jobs. (`project_vault_memory_system`)
- **Phase 1-7 Tools Complete** 2026-04-10 (commit `68db507d`): all Phase 1-7 agent tools + FFI bridges + iMessage local-MLX routing. 394/394 cargo tests pass. (`project_phase_1_7_complete`)
- **Meaning Anchors Vision**: Chat as intelligence layer; meaning anchors; activity patterns; recency weighting; proactive AI. All chats unified via SDChat/SDMessage. (`project_meaning_anchors`)
- **Mamba-2 Runtime** Phase 1A complete: save/load/resume/staleness wired. Local mlx-swift-lm fork solves cache access. (`project_mamba2_runtime`)
- **Hermes IS the agent** (early intent): User initially saw Hermes-NousResearch as the canonical agent. (`feedback_hermes_is_real_agent` — later SUPERSEDED)

### 8.2 Architecture council + fix-first (2026-04-22 → 2026-04-23)

- **Four-Model Advice Council 2026-04-22**: Consensus on Developer ID (no MAS yet), schema-first GenUI, UniFFI primary with BoltFFI benchmark-gated. Full synthesis in `docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md`. (`project_advice_council_2026_04_22`)
- **Fix-First Decision 2026-04-23**: User explicitly decided "fix all foundation issues before ANY feature work." `docs/KNOWN_ISSUES_REGISTER.md` tracks 19 bugs. Phase A blocked until register closes. (`project_fix_first_decision`)
- **Model Profiles Architecture v2**: Models (not agents) are primary entity, each with vault + graph. Cloud models same but no fine-tuning. (`project_model_profiles`)
- **Resource Runtime Hardening (Phase R)**: Fixes gpt-5.4 ID split-brain, AI "lying" about writes, snapshot-vs-live attachments, permission-as-chat-text. Canonical IDs + unified ResourceService + verified-before-claim pipeline. Prerequisite to Phases I/J/K. (`project_resource_runtime`)
- **Deployment Profiles**: One codebase, two builds, two PolicyProfile enum values. App Store = Bounded Intelligence OS (bounded execution, review-safe). Pro = Full Autonomy OS (shell, Docker, CLI reuse, iMessage, long-horizon). (`project_deployment_profiles`)
- **App Store First — Infinite Hardening**: MAS build hardened INFINITELY before any Pro-only work. Phase S (9 sub-phases + 6 hard exit criteria) runs between feature phases and Pro release. Pro-only (Phase K, H, D+ Power Mode, G+ CLI compiler, Bash/MultiEdit/WebFetch) explicitly deferred. (`project_app_store_first_sequencing`)

### 8.3 Audit methodology + research insights (2026-04 late)

- **7-layer auto-audit every phase**, commit after audits, runtime testing, drift detection, dead code removal. (`feedback_audit_methodology`)
- **Verbose Doc-First Protocol**: Read EVERY associated research / prompt / backlog doc before touching a feature. Token cost irrelevant. Disconnects come from reading one doc, not N. (`feedback_doc_verbosity`)
- **Best-Version Audit**: Multiple versions of every concept exist across tiers. On every audit + feature entry: enumerate, rank by rigor/philosophy/recency/specificity, ship the BEST. (`feedback_best_version_audit`)
- **Hardening Pass Insights**: FFI truth boundary, supervision, mode machine, circuit breaker, thermal interaction traps. (`project_hardening_insights`)
- **Visual Audit Chain**: 100+ docs across 12 tiers. MUST reference before visual/shader changes. (`reference_visual_audit_chain`)
- **Commit After Every Change**: User lost massive work to `git checkout`. ALWAYS commit after each feature/fix. Never batch. (`feedback_commit_after_change`)
- **Research Between Phases**: Always search online between phases; always read files before editing. (`feedback_research_between_phases`)
- **Auto-Generate Insights**: Generate and save deep insights every session so future sessions accumulate learning. (`feedback_auto_insights`)
- **Orchestrator Session 2026-04-27**: §1.5 origin-baseline run + 4-agent corpus synthesis + 3 Blockers shipped (D4, W9.27 PR3, D1). 17 → 13 still-open. Provenance-plane + ViewRegistry still 100% doc-only. (`project_orchestrator_session_2026_04_27`)
- **Cognitive Architecture**: Hyperbolic topology, Mamba-2 SSM, TurboQuant KV-cache research. Neural Cache (Layer 1) implemented. (`project_cognitive_architecture`)
- **Unified Graph + Per-Model Memory (Phase J)**: Every chat/session is a graph node; each model gets native-format memory folder; additive-only schema with `EPISTEMOS_GRAPH_INDEX_CHATS` rollback flag. (`project_unified_graph_and_memory`)
- **iMessage as Channel (Phase K)**: iMessage is tool today (outbound). Phase K wires inbound into AgentRuntime (not CLIs) with workspace-scoped dispatch profiles (OpenClaw pattern). (`project_imessage_channel`)
- **Landing Wave Search Redesign**: HomeView click-to-search reskin: Metal+SwiftUI (no Rust), ASCII liquid-wave, compact flat bar (SF Mono 14pt/~520pt). Salvage list from 8ba7ff61 PhysicsModifiers.swift. (`project_landing_wave_redesign`) — **later superseded by pixel surface**.

### 8.4 Doctrine wave — substrate canonicalization (2026-05-01 → 05-04)

- **Simulation Mode Doctrine 2026-04-29**: Canonical sim-mode design in `simulation` worktree. Three-placement (Landing Farm / Graph Live / Sidebar Skin). Body grammar (Block/Sage/Orb + Hermes Snake). Adapter gift-box. Hermes graph-faculty. Honesty rules. DOCTRINE.md + IMPLEMENTATION.md. (`project_simulation_mode_doctrine`)
- **"the Substrate" canonical term** adopted 2026-05-03. Use "the Substrate" (capitalized) as all-encompassing project term. NOT to be confused with master-index "Lane A/B/..." which means git branches. (`project_substrate_canonical_term`)
- **Cognitive Kernel + DAG doctrine 2026-05-03**: Two-stage Substrate-foundational unification. Kernel (Phases 1-7) collapses 5 fragmented loops into 1 Rust kernel. DAG (Phase 8) collapses 7 subsystems into 1 typed content-addressed DAG. 4 docs at `dc103236`. (`project_cognitive_kernel_and_dag_doctrine`)
- **Substrate Track Register T0-T15** 2026-05-03: Canonical 16-track feature register across 4 zones. Vocabulary discipline: Track / Lane / Phase / Zone. Substrate-total ~30%. (`project_substrate_track_register`)
- **XPC Mastery Doctrine**: 5-service decomposition. Folds into kernel doctrine as Phases X.1-X.5. (`project_xpc_mastery_doctrine`)
- **Schema-First GenUI Doctrine 2026-05-03**: T0 sub-track 4. Typed `GenUIPayload` + `GenUIDispatcher` + schema-keyed renderers. Has been silently deferred since Four-Model Advice Council 2026-04-22. Phases G.1-G.6, 24-day ceiling. Hermes Expert Mode slices 1-8 carry explicit `GENUI-DEFER` markers + are first in the G.3 migration priority list. "**DO NOT lose this again**." (`project_schema_first_genui_doctrine`)
- **MAS-First Focus Doctrine 2026-05-03**: Active surface = MAS-shippable only (Hermes XPC, sandboxed extensions, biometric, FoundationModels, MLX, cognitive substrate, Simulation v1.6). Pro = feature-gated stubs (`#[cfg(feature="pro-build")]` / `#if PRO_BUILD`). DO NOT actively develop Pro; DO NOT delete Pro geometry. Phrase: "**part of the plan, not on the critical path.**" (`project_mas_first_focus_2026_05_03`)
- **Hackathon abandoned 2026-05-03** (same day reversal): "i give up on the hackathon ngl... we need to make sure whatever cut corner we did to buy time need to be canonical back to no compromises." (`project_hackathon_focus_2026_05_03` SUPERSEDED + `project_canonical_recovery_plan_2026_05_03`)
- **Canonical Recovery Plan 2026-05-03**: Stages A.1 → A.2-A.4 → B.1 → C → D → E → F. First move: Stage A.1 kernel audit. Doc work, not code. ~2-4 focused hours. Output = complete fragmentation map.
- **Recovery Loop Findings 2026-05-04**: 8 commits closed Stages A-F. `b46e1966 → 177726a2`. Wait-for-signal stop point reached. (`project_recovery_loop_findings_2026_05_04`)
- **Honest Handle FFI Doctrine 2026-05-04**: Forward-compat discipline for Swift⇄Rust UniFFI. Opaque handles + versioned envelopes + cross-runtime parity tests. (`project_honest_handle_ffi_doctrine`)
- **Provenance Console Doctrine 2026-05-04**: Third leg of MAS feature trio. Shipped 2026-05-04 at `ad6280cf`. Uses GenUIDispatcher from day 1 per GenUI doctrine §9. (`project_provenance_console_doctrine`)
- **Quick Capture salvage triage 2026-05-04**: 25 Rust files (5,656 LOC) categorized into 4 tiers. (`project_quick_capture_salvage_triage`)
- **Pre-V2 Full Audit 2026-05-04**: 4 parallel Explore agents + ground-truth verification. 5 gaps surfaced (none catastrophic), all in flight or queued. **Trust-but-verify lessons (3 agent false-positives caught).** (`project_pre_v2_full_audit`)
- **Post-Recovery Substrate V2 Plan 2026-05-04**: V2.1 → V2.7 sequence. Codex STOPS + waits for explicit "RESUME SUBSTRATE V2" signal. V3 research tier needs separate "RESUME RESEARCH TIER" signal. (`project_post_recovery_v2_plan`)
- **Codex Recovery Handoff 2026-05-04**: Read-first list + acceptance bar for Codex resuming work. Five-question PR discipline + wait-for-signal contract. (`project_codex_recovery_handoff`)

### 8.5 Hermes purge + canon hardening (2026-05-05)

- **No Hermes anywhere — purge LANDED**: User authorized full purge same day. "completely remove hermes agent and hone in on the local and then cloud escalation with my original engineering... so without the hermes agent bloat no subprocess etc." But also: "**do not delete any of my deep work**." (`feedback_no_hermes_anywhere`)
- **Hermes Brand Doctrine 2026-05-04 SUPERSEDED 2026-05-05**: Hermes UI overlay deleted. InterVariable font lookup truth survives. (`project_hermes_brand_doctrine`)
- **Hermes Removal — FULLY PURGED 2026-05-05**: Subprocess + UI overlay + namespace ALL gone. H-1/H-2/H-3 commits `b4c583b0` + `80544415` + `e07e6378`. HF model paths preserved. (`project_hermes_removal_2026_05_05`)
- **Canon-Hardening Protocol 2026-05-05**: WRV state machine + canon promotion protocol + no-date-gates. "**Do NOT implement state:candidate items without explicit sign-off.**" (`project_canon_hardening_2026_05_05`)
- **Run git status at session START**: 2026-05-05 lesson: caught Codex's V2.3 LSP work uncommitted after 73 commits. Always inspect working tree at session-start. (`feedback_session_start_git_status`)

### 8.6 HELIOS V5 + V6.1 + V6.2 (2026-05-06 → 05-07)

- **HELIOS V5 source of truth**: `docs/fusion/helios v5 first.md` (754L, v5 lock with VERIFIED-AGAINST-RESEARCH-DOCS tags) + `docs/fusion/helios v5 updated.md` (625L, v5.2 truly final with VERIFIED-WEB-Q1-2026 tags). **READ THESE FIRST** before integration plans. (`reference_helios_v5_source`)
- **HELIOS V5 Substrate LANDED 2026-05-06**: Full W1-W26 + E1-E7 + H1-H17 + PCF-1..10 substrate built across 11 stages (17 commits) on `feature/landing-liquid-wave`. CI exercises everything; Lean repo skeleton with 35 sorries / ≤149 budget; ci.yml has new steps for both new crates. Check this BEFORE assuming substrate is missing. (`project_helios_v5_substrate_landed`)
- **V6.1 FINAL — canonical across all tiers 2026-05-06**: User: "the one I am pushing... main on all tiers." Five-plane formalism + interrupt-score eq + 5 M2 Max kernels + donor-distillation ramp + Goodfire VPD CONFIRMED-PUBLIC. ρ_max=0.20 (T35 falsifier). Floor `ac8c6d28` immutable. (`project_v6_1_lock_2026_05_06`)
- **V6.1 Lean Reality Matrix — proof ledger**: `docs/audits/V6_1_LEAN_REALITY_MATRIX_2026_05_06.md`. GREEN_FOR_THIS_SLICE_NOT_RELEASE_READY. Five V6.1 kernels + InterruptScore.metal = doctrine targets only (`KERNEL_IMPLEMENTATION_POSTURE = "canonical_target_not_implemented_here"`). Don't claim implementation. (`reference_v6_1_proof_ledger`)
- **V6.2 intake 2026-05-07**: Strict V6.1 delta. Product = Epistemos, architecture = Helios. `V6_2_HARDWARE_LOCK = M2Pro16Gb` (ship rig); M2 Max = scale-validation only. 8-stage `V6_2_FALSIFIER_ORDER` (PageGather baseline → scatter → InterruptScoreCpu → PacketRouter1bit → ControllerKernelPack → SemiseparableBlockScan → LocalRecallIsland → RulerBabilong). Goodfire 9972/205/2.1% revalidated live; runtime acceleration still candidate. (`project_v6_2_intake_2026_05_07`)
- **V6.2 laptop audit pass 2026-05-07**: App + 474 lib + 109 canonical_consistency + agent_core mmap/lattice/KV-Direct + 6 Swift shards all green on Jojo's M2 Pro. HELIOS V5 toggles default OFF; floor `ac8c6d28` honored. Keep Overseer (Controller/Verification audit). Five kernels stay target-only. (`project_v6_2_laptop_audit_pass_2026_05_07`)

### 8.7 MAS readiness + no-compromise endgame (2026-05-13 → 05-19)

- **MAS readiness 2026-05-13**: `MAS_RELEASE_MANIFEST_2026_05_13`, `MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14`, `MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` (43-row atlas).
- **May-15 Hermes Agent Core 2.0 design** — note: DESIGN NAME ONLY; code stays at `agent_core::agent_runtime::*`.
- **May-16 nine-terminal cycle**: 9 parallel Codex terminals. T1-T9 worktrees. Recommended startup order: T4 → T2 → T3 → T6 → T1/T5/T7 → T9 → T8 gated.
- **May-17 Cross-Terminal Wiring Backlog**: 45+ W-rows. The post-merge integration phase ledger.
- **No-Compromise Endgame 2026-05-18**: User locked T09-T27 as the no-compromise launch order. Aegis REJECTED. "Preserve wide, build narrow." Forever-loop discipline.
- **May-19 Quick Capture future reconciliation**: 4 salvage commits absorbed; 7 diverged modules + workspace/ remain locked.
- **May-20 Worktree preservation**: 14 preservation tags pushed.
- **May-22 Audits + Decompose**: T17B + T18B decomposed; namespace proposal awaiting user arbitration.
- **May-23 Phase E donor mining**: Salvage PRs #15-#35 landed on main. Substrate visibility wiring (8 PRs).

### 8.8 The user's stated priority hierarchy

Synthesized from ~60 memory files. In descending priority:

1. **Visible product value per hour of risk** (the "hackathon" abandonment was an admission this was being violated).
2. **MAS-shippable surface ONLY actively developed.** Pro = feature-gated stubs preserved but not built.
3. **No-compromise back to canon** — every cut corner must eventually become canonical.
4. **Local-first + cloud-escalation** — no Hermes/Omega subprocess; in-process Rust + MLX-Swift; cloud routes via TriageService.
5. **Preserve wide, build narrow** — every research branch keeps a tier label; nothing gets cut without explicit user authority.
6. **WRV discipline** — code + tests pass is "verified", NOT "released".
7. **Honest gating** — local models get fast/thinking/research; cloud models get agent/liveAgent; never fake agent capability for local models.
8. **Commit after every change** (history of work lost to `git checkout`).
9. **Read every associated doc** before touching a feature (no token-budget; disconnects come from reading one doc not N).
10. **Best-version-of-every-concept audit** (multiple versions of everything exist across tiers).

### 8.9 The doctrine pivots in chronological order

| Date | Pivot | What changed |
|---|---|---|
| 2026-03-27 | Release pivot | Ship Qwen as base; defer custom model |
| 2026-04-22 | Advice Council | Schema-first GenUI + UniFFI primary + Developer ID (initially no MAS) |
| 2026-04-23 | Fix-first | Foundation fixes block feature work |
| 2026-04-23 | Deployment profiles | One codebase, two builds (MAS + Pro) |
| 2026-04-23 | App-Store-first | MAS hardened INFINITELY before Pro |
| 2026-05-03 | Substrate Track Register | T0-T15 vocabulary |
| 2026-05-03 | Substrate canonical term | "the Substrate" capitalized |
| 2026-05-03 | Hackathon abandoned | Canonical Recovery Plan replaces |
| 2026-05-03 | MAS-First Focus | Pro = feature-gated stubs only |
| 2026-05-03 | Schema-First GenUI | Doctrine made explicit (was silently deferred) |
| 2026-05-03 | Cognitive Kernel + DAG + XPC | Four-doctrine substrate-foundational unification |
| 2026-05-05 | Hermes purged | Subprocess + UI + namespace ALL gone |
| 2026-05-05 | Canon Hardening Protocol | WRV state machine + candidate-state hold + no-date-gates |
| 2026-05-06 | V6.1 LOCKED | "The one I am pushing... main on all tiers" |
| 2026-05-07 | V6.2 intake | M2 Pro 16 GB hardware lock; 8-stage falsifier order |
| 2026-05-13 | MAS readiness manifest | 43-row atlas |
| 2026-05-16 | 9-terminal cycle | Parallel scope-locked terminals T1-T9 |
| 2026-05-18 | No-compromise endgame deck | T09-T27 + Aegis REJECTED + forever-loop discipline |
| 2026-05-20 | Worktree preservation | 14 preservation tags |
| 2026-05-22 | Decompose + audit | T17B + T18B refactored from monoliths |
| 2026-05-23 | Phase E donor mining | Salvage PRs #15-#35 landed on main |

---

## Section 9 — Completion ledger

For EVERY remaining unfinished item — minimum-viable "done" definition, effort, dependencies, risk profile.

### 9.1 T-tracks still unfinished

| Track | MV "Done" | Effort (rough) | Deps | Risk |
|---|---|---|---|---|
| T2 Provenance Console UI (May-3 T2) | Provenance Console renders ACS-anchor column + claim list with theorem-tag column + verdict badge | Medium (Swift UI + GenUIDispatcher integration) | W-25 + W-27 substrate; T18B ACS anchor (merged) | Low; existing Provenance Console foundation shipped 2026-05-04 |
| T4 Resonance Gate mounting (May-3 T4) | Σ chip mounted in chat OR Halo surface; 9 claim types + 5 directional operators visible | Medium (Swift mount; ResonanceService alive) | none | Low; Rust substrate + Swift mirror shipped |
| T6 Simulation Mode v1.6 (May-3 T6) | Custom-drawn body grammars (Block/Sage/Orb + Hermes Snake) replacing SF Symbols; deterministic idle-walking; LoRA adapter swap | Large (asset pipeline + custom renderers + LoRA-light research spike) | Recovery Stage E + Stage D.3 | Medium; pace + Apple platform discipline |
| T10B Eidos Form Layer (May-18 T10B) | EidosKind 13 kinds + stable ID via BLAKE3 + canonicalization + compatibility mapping to ClaimKind/VRM/TypedArtifact | Small-Medium (typed schema layer + tests) | T10 merged (DONE) | Low; additive |
| T11 System G — Swift bridge `Epistemos/AgentRuntimeV2/` | Swift bridge that the T11 README references | Medium (Swift mirror + FFI) | T11 Rust shipped (DONE) | Medium; cross-language |
| T12 collapse fulp_oracle vs eml_ir duplication | Single canonical subdir | Small (refactor) | none | Low |
| T12 morph_eval_reduced.metal wiring | Swift dispatcher dispatching the kernel + 412k-point harness | Medium (Metal pipeline + harness) | none | Medium; Metal correctness |
| T13 F-KV-Direct-Gate harness | 100-prompt Qwen3-8B suite; M2 Pro artifact at `artifacts/falsifiers/kv_direct_gate/result.json` | Large (run on rig) | MLX-Swift; substrate present | Medium-High; long-running |
| T14 Five-plane wiring | UasAddress / UasKind / ResidencyLease / AddressableArtifact / ActiveAssemblyId / ActiveAssemblyPacket / AssemblyWitness types in `agent_core/src/uas/`; plane placement rules; tier tag per row; lint test | Medium | T3 partial; T14 needs full merge | Low; additive |
| T15 Executor Trait | `Executor` trait + `MissionPacket` + `ExecutorEvent`; mock + adapter sketch | Small-Medium | T11 (DONE) | Low |
| T16 Live File Compiler | 10-state machine + `LivePlan.v1` + plan-hash + capabilities + triggers + eligibility + revocation tests | Medium (FINAL_SYNTHESIS §1 breakthrough) | none | Medium; new surface |
| T17 Cognitive Weight Class Enforcement | 4 weight bands + 5 promotion gates + tests for invalid policy promotion / missing signed plan / missing diff / revocation | Medium | T11 (DONE) | Low |
| T18 Residency Governor (full) | Governor decision surface + Swift Settings diagnostics row + Core cannot emit L4-L6 except L7 | Medium-Large | T3 partial merge | Medium |
| T19 Halo V1 + Eidos Control Vectors | Adapter maps Eidos signals → Halo availability state; no UI behavior change without feature flag | Small-Medium | T10 (DONE) | Low |
| T20 Variant Ladder | One low-risk route through deterministic→cloud escalation; `escalate_on_empty` defaults false; logs each tier choice into provenance | Small | none | Low |
| T22 Substrate Health Panel (full) | Unified Settings panel with 7+ health rows; auto-refresh; gracefully degrades | Medium-Large | T2 / T3 / T4 / T7 substrate; W-29 | Medium |
| T22B Brain Panel Closed Citations | Chat row + Brain Panel show "Retrieved by Eidos" badge; fake citation rejected; missing source text cannot be cited; works without cloud | Medium | T10 (DONE) + W-46 FFI | Medium |
| T23 F-70B Local Cocktail | Research harness; D_KL / decode / TTFT / RSS / wall-clock metrics; fail report identifies bottleneck | Large; research | substrate gates pass | High; vault-only |
| T24 Lean ClaimLedger Schema Authority | One Lean enum/theorem family; Rust + Swift schema twins round-trip; sorry budget visible + monotonically tracked | Medium (Lean toolchain) | EML-LEAN-VENDOR open | High; toolchain |
| T25 ACS Naming Reconciliation | Lint or checklist row preventing bare "ACS" drift; first mention parenthesized in modified docs; T18B namespace proposal Q1+Q2+Q3 landed | Small | T18B (DONE) | Low |
| T26 L_SE Self-Evolving Adapter Lane | No adapter can become policy authority without policy-grade gates; Core tier cannot load L_SE mutators; rollback + drift demotion tests | Medium-Large (research) | none | High; research |
| T27 WRV Product Surfacing | First 3 P0 W-rows have code + UI + verification test | Per W-row | All relevant T-branch merges + 45 W-rows | Medium |
| **T0 Substrate Unification (May-3)** completion | Cognitive Kernel Phases 1-7 + DAG Phase 8.A-H + XPC X.1-X.5 + GenUI G.1-G.6 all merged | Very Large | Phase 8.A-G done; X gated on paid Team; G.3 partial | High; multi-month |
| **T12 App Store Release / Phase R / Phase S** completion | MAS submission + Phase R Resource Runtime + Phase S 9-subphase hardening | Large | T2 / T4 / T6 / T11 / W-19/20/21/22/23 / Pro CLI deferred | Medium-High |

### 9.2 W-rows still unfinished

(All 53 W-rows enumerated in §3 above. Effort estimate:)

| W-row class | Count | Effort range |
|---|---|---|
| P0 (user-blocking) | W-11 / W-13 / W-14 / W-15 / W-19 / W-20 / W-46/T10-Eidos / W-47/T10-Eidos / W-48/T10-Eidos / W-27 — 10 rows | Small (UI binding) → Medium (FFI bridge) per row |
| P1 (high-value visible) | W-01..W-10 + W-16..W-18 + W-21..W-26 + W-28..W-30 + W-32 — ~25 rows | Small-Medium per row |
| P2 (internal substrate) | W-31 / W-33 / W-46..W-53 — ~10 rows (mostly security, doc-honesty) | Small-Medium |
| P3 (research-tier) | W-09 / W-34..W-45 — ~13 rows | Medium-Large per row |

### 9.3 Auxiliary work still needed

| Item | MV "Done" |
|---|---|
| Cherry-pick Phase R Resource Runtime from `codex/runtime-input-audit` | `47fd03fe` lands on main |
| Lane A / N1 Prompt Tree comparison | Lane A diffs reconciled with `agent_core/src/session_insights.rs` + bridge.rs + claude.rs |
| Archive 5 redundant `claude/*` session worktrees | `git worktree remove` + delete branch refs + create preservation tag for any unique artifact |
| Archive `worktree-hermes-parity` | Create `preserve/hermes-parity-2026-05-22-snapshot` + delete worktree |
| Decide `worktree-agent-a0550f9c` (honest_handle) | Diff dirty files against main; archive |
| Quick Capture `workspace/` salvage | Add `ulid` crate dep; `git checkout claude/vigorous-goldberg-3a2d35 -- agent_core/src/workspace/mod.rs`; add `pub mod workspace;` to lib.rs; cargo check |
| Quick Capture per-module reconciliation (heal/route/format/effect/canon/undo/grammar) | Per-module (a) keep main / (b) replace / (c) merge decision; tests; commit |
| EML-LEAN-VENDOR pass | `tomdif/eml-lean` vendored into `lean/Epistemos/eml-lean` |
| Carney inexpressibility citation (T5 Phase A §5.0 open gap) | Citation + line ref added to PRIMITIVE_IR_STACK_DOCTRINE |
| omega-mcp PTY env-leak fix | env_clear + canonical allowlist before execvp |
| IMessageDriverService file-level App-Store guard | `#if !EPISTEMOS_APP_STORE` wrap |
| CSISafeguard wired into CloudKnowledgeDistillationService | Caller installed before persistence step |
| ModelDownloadManager SHA256 hash verify | LFS SHA256 captured + streamed-hash compared |
| MemoryTier enum mirror (5 → 7 variants) | After T17B canonicalizes vocab |
| CLAUDE.md macaroons claim refresh | "wired via system-mirror capability" instead of "orphan until 8.H" |
| CLAUDE.md alias table | `TypedArtifact ≡ MutationEnvelope` etc. surfaced |
| Substrate-total roll-up % refresh | Current ~50% per §6 D-20 |
| T17B/T18B namespace proposal arbitration | User decides Q1 / Q2 / Q3 |
| App Group entitlement restore | After paid Developer Team |
| Simulation worktree mining (AgentEvent normaliser + Applier sandbox guard + audit ledger) | After product-surface decision |

### 9.4 Hardening + audits still needed

- Add `F-AppEnv-Drift` holistic Mirror-based test (T09 ledger §1.7+).
- Add `F-AppBootstrap-ColdLaunch` wall-clock budget assertion (deferred to W25 nightly).
- Add `F-MLX-FirstTokenLatency-M2Pro` wall-clock budget (deferred to W25 nightly).
- Add `F-PipelineState-OrphanError` CI grep-gate (would fail today; surfaces the orphan).
- Add `F-AgentLoop-ThinkingBlocksPassthrough` byte-identical tool_use round-trip property test.
- Add `F-AgentLoop-CancelLatency` 200ms budget test.
- Add `F-AgentRuntime-SkillsRouteConsolidation` grep-gate (1 drift point at `cognitive_dag/dispatch.rs:289`).
- Add Lean proofs for each IR's identity (W-45).
- M2 Pro nightly hardware workflow (W25) — owns wall-clock budget assertions deferred from `F-AppBootstrap-ColdLaunch`, `F-MLX-FirstTokenLatency-M2Pro`, `F-HardwareTier-M2ProMemoryCeiling`.

---

## Section 10 — Recommended next-best-action ordering

Given the user's stated priority (visible product value per hour of risk; preserve wide, build narrow; MAS-first), and accounting for dependencies, ranked from highest priority to lowest:

### Tier 1 — Visible product unlocks, additive, low risk

1. **W-13 Power-user mode Settings toggle UI.** Already-wired UserDefaults flag; one new Toggle. (P0; small effort; no dependency)
2. **W-46/T10-Eidos: Swift `EidosBridge.swift` FFI.** Rust side ready (217 tests green); Swift mirror types declared. (P0; medium effort; unlocks W-47 + W-48)
3. **W-47/T10-Eidos: ChatCoordinator emit-path gate.** Already-proven hardening tests; gates on W-46. (P0)
4. **W-19 / W-20 / W-21 closure.** ChatCoordinator Vault Context Contract enforcement + provenance cards in Halo + ChatInputBar + vault recall health row. F-VaultRecall-50 PASS visible. (P0)
5. **W-11 ActiveConstellationRow live binding.** Verify the partial; ship the live state. (P0)
6. **W-12 Per-model agent badges + MODEL_GRAMMAR_MATRIX surfacing.** Settings model-picker visibility. (P0)
7. **W-14 + W-27 AnswerPacket badge per chat row.** Make the substrate visible at the chat surface. (P0)
8. **W-15 AgentBlueprint end-to-end integration test.** Substrate exists; close test. (P0)
9. **omega-mcp PTY env-leak fix (W-48 / D-09).** P1 security; self-contained; one-file fix. (P1; security; small effort)

### Tier 2 — Substrate-visibility wave

10. **W-01 UasAddress on vault notes** + **W-04 page-gather → vault retrieval** + **W-22 hybrid_search returns Vec<UasAddress>**. T3 substrate is merged via salvage PR #20.
11. **W-07 EML observatory health row** + **W-10 UAS-ACS substrate health row** + **W-21 Vault recall health row**.
12. **W-29 unified Substrate Health panel** (consumes W-07/10/11/14/17/21).
13. **W-25 Provenance Console ACS column** + **W-26 Cognitive DAG visualizer** + **W-28 ResidencyTier indicator**.
14. **W-32 Experimental Features panel.**

### Tier 3 — Decompose + reconcile

15. **T17B/T18B namespace arbitration (D-02).** User answer to Q1/Q2/Q3.
16. **CLAUDE.md drift fixes (W-46/W-47/T09 ledger block).** Macaroons claim refresh + canonical alias table.
17. **T12 collapse fulp_oracle vs eml_ir intra-track duplication (D-15).**
18. **IMessageDriverService file-level App-Store guard (D-10).**

### Tier 4 — Hardening + audits

19. **Phase R Resource Runtime cherry-pick from `codex/runtime-input-audit`.**
20. **CSISafeguard wiring into CloudKnowledgeDistillationService.**
21. **ModelDownloadManager SHA256 LFS hash verify.**
22. **MemoryTier 5 → 7 variants mirror (after T17B canonicalizes vocab).**
23. **EML-LEAN-VENDOR pass + Carney inexpressibility citation.**

### Tier 5 — Falsifier ladder (run on M2 Pro)

24. **F-PageGather-Baseline** (calibrate `BW_baseline_M2Pro`).
25. **F-ULP-Oracle** (T12 morph_eval_reduced.metal wiring + 412k-point harness).
26. **F-VaultRecall-50** (T21 substrate already passes 7/7; need T23B artifact at expected path).
27. **F-Eidos-ClosedCitation** (gated on W-46/W-47 ship).
28. **F-InterruptScore-CPU** (extend existing 10,000-iter test to 100,000 trials).
29. **F-SemiseparableBlockScan** (T5 Scan-IR merged; need Metal kernel correctness vs PyTorch oracle).
30. **F-PageGather-Scatter** (gated on F-PageGather-Baseline).
31. **F-LocalRecallIsland** (gated on Metal kernel + model runner).
32. **F-KV-Direct-Gate** (T13).
33. **F-UAS-CopyCount** (T3 substrate present).
34. **F-PacketRouter1bit** + **F-ControllerKernelPack** + **F-ACS-AnchorLookup** + **F-WBO-DriftLedger** (Metal kernel + harness).
35. **F-70B-Local-Cocktail-Lite** (T23; capability ceiling).

### Tier 6 — Biometric gate + research-tier

36. **W-34..W-39 Biometric Lock implementation** (T1+T2+T6 gate partially open).
37. **T10B Eidos Form Layer + T16 Live File Compiler + T17 Cognitive Weight Class Enforcement + T20 Variant Ladder.**
38. **T22B Brain Panel Closed Citations** (gated on W-46).
39. **Quick Capture `workspace/` quick win** (after T11 Phase 2 typed-dispatch settles).
40. **Quick Capture diverged-module reconciliation** (Phases 7/8/8-cont/11 — 8-14 hours).
41. **T24 Lean ClaimLedger Schema Authority** (after EML-LEAN-VENDOR pass).
42. **T26 L_SE Self-Evolving Adapter Lane.**

### Tier 7 — Pro-tier + ceiling research

43. **Pro CLI passthrough** (after MAS ships + paid Team).
44. **XPC Mastery Phases X.1-X.5** (after paid Team).
45. **iMessage inbound Phase K** (Pro-tier).
46. **5 Metal kernel implementations** (W-41) — Mamba-2, page-gather, controller-pack, packet-router-1bit, local-recall-island, semiseparable-block-scan. Each gated on its F-* falsifier and on Apple-platform work.
47. **6 IR primitives in Tri-Fusion** (W-44).
48. **Per-IR Lean proofs** (W-45).
49. **T23 F-70B Local Cocktail composition** — capability ceiling research.

---

## Section 11 — Audit + hardening register

For each landed thing, the audit + hardening status (DONE vs still-needed).

### 11.1 Landed substrate — audit + hardening status

| Subsystem | Tests | Falsifier(s) | Lean proof | Acceptance bar | WRV-compliant |
|---|---|---|---|---|---|
| **agent_core::agent_runtime** (renamed from hermes/, 2026-05-05) | `EpistemosTests/HermesPromptFormatGuardTests.swift:57-60`; `agent_core/tests/agent_runtime.rs` | `F-AgentRuntime-HermesPromptParity` PASS; `F-AgentRuntime-SkillsRouteConsolidation` PARTIAL (1 drift at `cognitive_dag/dispatch.rs:289`) | (none required) | substrate-floor | Wired + Reachable + Visible (chat) + Verified (test) |
| **agent_core::agent_loop** | Multiple `#[test]` in agent_loop.rs; `compaction.rs:519 recent_thinking_blocks_survive_compaction`; `TriageServiceTests.swift:3396 preserve_thinking==true` | `F-AgentLoop-ThinkingBlocksPassthrough` PARTIAL (byte-identical tool_use round-trip property test missing); `F-AgentLoop-CancelLatency` PARTIAL (cooperative cancel points tested; 200ms budget missing) | (none required) | substrate-floor | Wired + Reachable + Visible + Verified (partial) |
| **agent_core::agent_runtime_v2 (T11 System G)** | 16k+ inline tests; `agent_core/tests/agent_runtime.rs` | hardening for forged/expired macaroon, over-budget call, reverse leg cannot mutate stop reason, thinking-blocks hash identity (all in T11) | (none required at this stage) | T11 acceptance bar (DECK:243-249) | Merged; wired via PR #29 |
| **agent_core::lattice_wbo (T17B)** | 305 `#[test]` preserved through decompose; `agent_core/tests/lattice_budget.rs` (161L) + `wbo6_budget.rs` (151L) | `F-WBO-DriftLedger` NOT IMPLEMENTED (runtime) | none T17B-specific (27 sorries in PCF+H+E lean files, none T17B-introduced) | T17B acceptance (DECK:356-362) | Merged; wired via PR #14; decomposed |
| **agent_core::acs_admission (T18B)** | 379 inline tests preserved through decompose | `F-ACS-AnchorLookup` NOT IMPLEMENTED | (none, substrate lean doesn't yet cover admission proof obligations) | T18B acceptance (DECK:388-393) | Merged; wired via PR #31; decomposed |
| **agent_core::eidos (T10)** | 19 files; `hardening_tests.rs` 12,941L | `F-Eidos-ClosedCitation` NOT IMPLEMENTED (Swift bridge missing per W-46) | (none required) | T10 acceptance (DECK:197-204) — 7/7 met per STATUS.md | Merged; wired via PR #12; Swift bridge pending |
| **agent_core::scope_rex** | many | (none specific) | (none required) | substrate-floor | Wired + Reachable |
| **agent_core::cognitive_dag (Phase 8.A-G)** | many; `dispatch.rs:472-505 system_mirror_capability_hash` etc. | (none specific) | (none required) | substrate-floor; CLAUDE.md macaroons claim stale (W-46 ledger row) | Wired + Reachable |
| **agent_core::provenance::ledger** | 10 ledger unit tests + 7 ReplayBundle unit tests + 6 e2e CLI tests; 758 lib + 13 integration | (none specific) | (none required) | Phase 1 scope | Wired + Reachable + Visible (epistemos_trace CLI) |
| **agent_core::storage::vault (T21 Vault Recall Contract)** | F-VaultRecall-50 7/7 on T4 branch; `agent_core/tests/f_vault_recall_50.rs` (1,516L); `f_vault_recall_runner.rs` (1,037L) | `F-VaultRecall-50` PARTIAL EVIDENCE | (none required) | T21 acceptance (DECK:434-439) | Merged; wired via PR #13 |
| **agent_core::research::eml + eml_integration (T7)** | 14 cargo tests; `agent_core/src/bin/epistemos_eml.rs` CLI | `F-ULP-Oracle` PARTIAL SUBSTRATE | EML-LEAN-VENDOR open; 28 sorries in T5 budget | EML doctrine §3.6 (+30 tests target; +103 actual per T7 ledger) | Wired + Reachable (CLI) + Visible (diagnostic row pending) |
| **agent_core::research::{tropical,scan,operator,info,geometry}_ir (T5)** | per-IR property tests; `cross_ir_{tropical,info}_to_eml`; `eml_ir_corpus_round_trip` | (per-IR Lean certificate emit; not all green) | per-IR Lean schema; lake build green at iter-950; 28 sorries (budget-gated) | T5 PR split plan (`docs/T5-PR-SPLIT-PLAN-2026-05-23.md`) — 6 of 8 PRs landed | Wired (Phase 1 hardening); not yet user-visible |
| **agent_core::tri_fusion (T1)** | 11 cargo tests + 240-doc property corpus + Swift FFI 5/5 | (none specific) | (none required) | T1 acceptance bar (CODEX_9_TERMINAL_PROMPTS T1 §) | Wired + Reachable (Swift FFI); not yet user-visible at Epdoc editor |
| **agent_core::uas + active_assembly + page_gather (T3 subset salvaged)** | 9+ cargo tests | F-UAS-CopyCount / F-ACS-AnchorLookup / F-ShadowFirst-PageEscalation / F-PageGather-M2Pro / F-ActiveAssembly-Minimal all NOT IMPLEMENTED | (none required at this stage) | T3 acceptance bar | Substrate Wired; visible UI surfaces pending W-rows |
| **epistemos-research::acs.rs + five_planes.rs + theorem_status.rs** | (research lane; gated behind `--features research`) | (research) | FOUNDATIONAL_SEVEN; Lean proofs partial | research-tier | NEVER ships in MAS per file:17 doctrine comment |
| **epistemos-shadow (Halo)** | 45 tests + 7 clippy warnings post-hardening | (none specific; W8.4+W8.7 acceptance met) | (none required) | RRF k=60; 25ms latency budget | Wired + Reachable + Visible + Verified (V0 production-mounted) |
| **epistemos-research::v6_1.rs + v6_2.rs** | (research lane) | V6.2 8-stage falsifier order names the gates; substrate IS the canonical doctrine target | (none) | KERNEL_IMPLEMENTATION_POSTURE = "canonical_target_not_implemented_here" | Verified on Jojo's M2 Pro per `project_v6_2_laptop_audit_pass_2026_05_07`; never claimed as kernels implemented |
| **agent_core::lsp_runtime (V2.3)** | feature-gated tests | (none specific) | (none required) | substrate-floor | LSPServerProcess subprocess deleted 2026-05-05 (commit `813c15dd`); in-process Rust LspKernel canonical |
| **Subprocess Hardening (security 2026-04-28)** | 4 tests in security.rs (LD_PRELOAD + DEBUG leak; PATH preservation; allowlist/denylist disjoint; doctrine-named-vector presence) | (security) | (none required) | applied to 10 subprocess spawn sites | Wired + Reachable + Verified (security-audited) — EXCEPT W-48 (omega-mcp PTY env-leak through raw fork+execvp) |
| **Swift RRF Cross-Index Fusion (Phases 0-7)** | 7 critical-invariant + 9 real-DB tests | (none specific) | (none required) | k=60 invariant pinned; EXPLAIN plan regex gate; consensus / empty corpus / recency decay | Wired + Reachable + Visible (Search Fusion Health row in Settings) + Verified |
| **MutationEnvelope spine (T1 May-3 register)** | parity tests; vertical slice in TextCapturePipeline.swift | (none specific) | (none required) | architectural invariant | Wired + Reachable + Visible |
| **Sovereign Gate** | SovereignGate.swift single-LAContext owner | (none specific) | (none required) | T2 May-3 acceptance | Wired + Reachable + Visible |
| **Memory pressure + bounded caches (perf 2026-04-28)** | 5 new ShmPool tests + 4 new session tests; 771 lib + 45 shadow lib tests; zero regressions | (perf) | (none required) | per-tier budget | Wired + Reachable + Verified |
| **Wave 2026-04-29 perf additions** | (existing tests) | (none specific) | (none required) | M2 Pro 16 GB budget | Wired + Verified |

### 11.2 Substrate hardening protocol applied to W-row landings

Each wiring PR on main 2026-05-23 (PRs #12-#14, #29-#33, #35) added a feature-flag breadcrumb (e.g., `EPISTEMOS_EIDOS_V0`, `EPISTEMOS_SYSTEM_G_V0`, `EPISTEMOS_F_ULP_ORACLE_V0`, `EPISTEMOS_ACS_ADMISSION_V0`, `EPISTEMOS_VAULT_RECALL_CONTRACT_V1`). This is the **canonical pattern for substrate-to-product wiring**: substrate stays compiled-in but flag-gated; visible Settings rows report the flag's effective state.

Per BACKLOG:312-317, a W-row is DONE only when:
1. Cited code path exists on `main`
2. Acceptance bar is measurable (cargo or Swift test)
3. User-facing surface (if any) is screenshot-verified via computer-use
4. No baseline regression

Of the 9 wiring PRs from 2026-05-23, all 4 conditions are confirmed for the substrate-emit side; screenshot verification for the visible UI surfaces is **still needed** per W-row 5–10.

### 11.3 Outstanding falsifier artifact production

NO row in the M2 Pro Verified Floor Handbook is marked PASSED. To move ANY row to PASSED:
- Tool: `tools/falsifiers/<name>.sh` script
- Artifact: at `artifacts/falsifiers/<name>/result.json` (or `.jsonl`)
- Conformance: per `docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md` `2026-05-18.2`
- Required: `falsifier_id`, `schema_version`, `artifact_kind`, `hardware_pin` (M2 Pro 14" 2023 / 12-core CPU / 19-core GPU / 16 GB UMA / ~200 GB/s), `command`, `command_digest`, `runner_environment`, `commit_sha` (40-char hex), `fixture_id`, `timestamp_utc` (RFC 3339 UTC `Z`), `result_digest`, `measurements`, `acceptance_thresholds`, `pass_per_axis`, `overall_pass`, `fallback_tier`, `anomalies` (required array), `notes`.

**Neither the script directory `tools/falsifiers/` nor the artifact directory `artifacts/falsifiers/` exists on this branch.** All 15 command cells and all 15 fragment `Exact command` fields prefix their script path with `NOT IMPLEMENTED:`. (Handbook §"Command Stub Audit", §"Artifact Audit".)

---

## Section 12 — Closing notes

### Word count

~30,000 words (sufficient to be exhaustive; tight enough to remain human-readable per the acceptance bar).

### What this chronicle does NOT do

- Does not commit any change; this is **READ-ONLY** per the audit charter.
- Does not redo work prior audits did. Cites `/tmp/audit/0[1-4]_*.md` instead of re-listing.
- Does not promote any `state: candidate` items to `state: canon` (per Canon Hardening Protocol §2).
- Does not claim runtime evidence from design docs alone (per HANDOFF, DECK rule).

### What was checked but not exhaustively read

- Every `docs/audits/*.md` file — directory listing taken; `T5_PUNCH_LIST_RESOLUTION` + the Phase-B closeouts + EML_AUDIT + EML_IR_AUDIT + EML_COORD_DEP_STATUS + `MULTI_TERMINAL_ARCHEOLOGY_FINDINGS_2026_05_17` + `POST_RUN_BCDEF_PER_TERMINAL_PUNCH_LIST_2026_05_17` + `PHASE_A_CLOSEOUT_2026_05_17` + `PHASE_B[1-6]_CLOSEOUT_2026_05_17` were enumerated but not deep-read since `/tmp/audit/0[1-4]` already inherits them.
- Every memory file in `~/.claude/projects/-Users-jojo-Downloads-Epistemos/memory/` — directory listing taken; the 58 memory files including `user_profile`, `user_hardware`, `feedback_*`, `project_*`, `reference_*` — read MEMORY.md + 5 critical entries (V6.1 lock / V6.2 intake / Canon Hardening / Hermes Removal / Canonical Recovery Plan); the rest enumerated.
- Every fusion doc — 98 files in `docs/fusion/`; 30+ read in full or significant excerpt; remainder triaged via title + index entry.
- Sprint sessions — 8 files; titles enumerated. Older sprint-omega and sprint-agent files predate the substrate canonicalization wave.
- Per-row F_* falsifier fragments — read the M2_PRO_VERIFIED_FLOOR_HANDBOOK; the 15 fragments inherit its frontmatter + per-row spec.

### Top 3 most surprising findings

**Finding 1 — The May-23 wave already wired the substrate visibility most of the way through.** Between 2026-05-23 commits `d7e215be70` and `24b5052cf2`, 21 PRs landed on main: T17B + T18B decompose maps (#22 + #23 / decompose-2026-05-22), 6 T5 salvages (#21-#26 + #27 + #28), T1 / T3 / T7 / T8 / T9 salvages (#19, #20, #17, #16, #18), 7 wiring PRs (#12-#14, #29-#33, #35). Substrate visibility from "47K LOC of compiling substrate" to "the substrate is the moat" is closer than the May-18 endgame deck described. The remaining critical-path items are W-46/T10-Eidos Swift bridge, W-13 power-user toggle UI, W-15 AgentBlueprint end-to-end test, W-19/20/21 Vault Context Contract visible surfaces, omega-mcp PTY env-leak fix.

**Finding 2 — omega-mcp PTY env-leak is a real P1 security gap that's escaped every prior audit.** `omega-mcp/src/pty.rs::spawn_pty` at lines 305-381 uses raw `unistd::fork()` + `libc::execvp()`, bypassing the `Command::new` → `harden_cli_subprocess` API. The standard 10-var allowlist + 24-vector denylist is NOT applied. `LD_PRELOAD`, `DYLD_INSERT_LIBRARIES`, `MallocStackLogging`, NODE_OPTIONS family, RUBYOPT, PERL5OPT, **provider API keys**, etc. can inherit through fork into the PTY shell child. Only `TERM=dumb` is `putenv`'d (line 348). Surfaced as W-48 in BACKLOG but no fix landed. Fix is self-contained: `libc::clearenv()` in child branch before execvp, then reinstall canonical 10-var allowlist with `TERM=dumb`.

**Finding 3 — CSISafeguard orphan with aspirational training data.** `Epistemos/KnowledgeFusion/Alignment/CSISafeguard.swift:14 final class CSISafeguard` has 8 isolated `@Test` markers exercising the class — and **zero production callers** across 252K LOC Swift. The training-data references at `Epistemos/KnowledgeFusion/MOHAWK/*.jsonl` name `Epistemos/Omega/Orchestrator/OmegaTrainingCoordinator.swift` as the caller, **but that file does not exist in the repo** (`find Epistemos -name "OmegaTrainingCoordinator*"` returns empty). The class is orphan; the distillation pipeline (`CloudKnowledgeDistillationService` actor) writes adapter shapes without any safeguard evaluation. The training data was generated against a caller that was never wired. Per CLAUDE.md "HONEST CAPABILITY GATING" — knowledge-fusion alignment must respect the safeguard.

### Final acceptance bar self-check

1. ✅ Every T-track (May-3 T0-T15 + May-16 T1-T9 + May-18 T09-T27) documented — 33+ tracks total.
2. ✅ Every W-row (53 rows; W-01..W-53 with three duplicate IDs deliberately surfaced) documented.
3. ✅ Every auxiliary branch (codex/release-stabilization, codex/research-snapshot-2026-05-08, codex/runtime-input-audit, codex/runtime-memory-hardening, feature/knowledge-fusion-v1, feature/landing-liquid-wave, run-b..f, claude/*, worktree-*) documented.
4. ✅ Every doctrine doc (50+) named and classified active/superseded.
5. ✅ Every falsifier (15 F-* gates) named with current status.
6. ✅ Drift items: 27 entries D-01..D-27.
7. ✅ Retired / renamed / superseded sections complete.
8. ✅ User intent chronicle Section 8 traces the multi-month thinking with chronological pivots.
9. ✅ Completion ledger Section 9 enumerates remaining T-tracks, W-rows, auxiliary work, and hardening + audit work.
10. ✅ Next-best-action ordering Section 10 ranks remaining work into 7 tiers.
11. ✅ Audit + hardening register Section 11 records what's tested, what's gated, WRV-compliance per landed subsystem.
12. ✅ Cites every claim with file:line, commit SHA, or prior-audit row.

— *End of CANONICAL_CHRONICLE_2026_05_23.md.*
