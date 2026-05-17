# Unified Active Substrate Canon (UAS-ACS Register) — 2026-05-16

**Purpose:** single no-loss register pulling together every UAS (Unified Address Space) and ACS (Anchored / Autopoietic Cognitive Substrate) surface across the corpus. Produced per the 4-advisor synthesis directive: **the canon has coverage but not coherence; this register is the coherence layer.**

**Audience:** anyone (Codex, Claude, the user, a future maintainer) needing to reason about UAS-ACS as ONE concept rather than 8+ scattered surfaces.

**Discipline:** this doc is APPEND-ONLY for net-new surfaces; if an existing surface changes status (NOT-STARTED → PARTIAL → SHIPPED), update its row in place + log the transition in §6.

---

## 1. One-paragraph definition

**UAS-ACS is the substrate-level claim that Epistemos's memory + compute + governance fabric is a SINGLE addressable, autopoietic, recursively-governed system, not a collection of separate subsystems.** UAS (Unified Address Space) is the zero-copy memory side — Swift / Rust / Metal / MLX / KV / HNSW share one address space with no tensor copies on the hot path. ACS (Anchored Cognitive Substrate per HELIOS V5 code-canonical naming · or Autopoietic Cognitive Stack per the original Beer/VSM-lineage doctrine) is the governance side — 7-scale recursion, 4 homeostatic loops, Kuramoto-coupled multi-agent sync, MAPE-K control loops, autopoietic regeneration. They are **two sides of one substrate**: UAS is the structural / address-space view, ACS is the dynamical / regulation view. Same fabric.

The 4-advisor synthesis from earlier this session named UAS-ACS as the **umbrella concept** that ties together: the 5 V6.1 Metal kernels (target-only) · the Cognitive DAG (Phase 8.A-G shipped) · SCOPE-Rex (MutationEnvelope + WitnessedState + ClaimGraph + RunEventLog) · the 5-plane formalism (state · episodic · assembly · controller · verification) · the Foundational Seven theorems · the Goodfire VPD/SPD parameter decomposition.

---

## 2. The 6 canonical surfaces

| # | Surface | Path | Status | What it carries |
|---|---|---|---|---|
| 1 | **Rust ACS substrate** (Lane 3 research-only, NEVER ships in MAS) | `epistemos-research/src/acs.rs` | SHIPPED at 190 LOC (research-tier) | `AcsAnchor` + `CmsXField` + `ACS_CANONICAL_PLANE = RuntimePlane::Episodic` + serde Codable + cross-link to `crate::five_planes::RuntimePlane` + `crate::theorem_status::FOUNDATIONAL_SEVEN`. Header per file:1-19: "ACS = Anchored Cognitive Substrate — the constitutive field that ties the Foundational Seven (E1-E7) into a coherent computational fabric. Lifted as research-tier substrate types; NEVER ships in MAS." |
| 2 | **5-plane runtime formalism** (the addressable plane register) | `epistemos-research/src/five_planes.rs` | SHIPPED at 308 LOC (research-tier) | `RuntimePlane::State | Episodic | Assembly | Controller | Verification` enum + per-plane semantics. ACS anchors live in `Episodic`; verification of theorem-labels happens in `Verification` plane. This IS the addressable-plane half of UAS. |
| 3 | **KV-Direct gate** (memory floor: the Qasim et al. arXiv:2603.19664 implementation) | `agent_core/src/scope_rex/kv/direct_gate.rs` (290 LOC Rust) + `Epistemos/Shaders/kv_direct_gate.metal` (65 LOC Metal) | SHIPPED at Tier-1 | F-KV-Direct-Gate from Phase B.0-KV. The memory-architecture floor for UAS — guarantees zero-copy KV access between Swift+Rust+Metal+MLX. Verifies SSD-mmap-direct doesn't trigger spurious page faults under MLX hot path. |
| 4 | **MASTER_FUSION §3.8 ACS doctrine row** (the doctrine spine) | `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` lines 175-189 | doctrine + PARTIAL substrate | 11-facet table covering 7-scale recursion · VSM S1-S5 · 4 homeostatic loops · Kuramoto coupling · Markov blanket / ViableSystem · HealingAction · MAPE-K + Lyapunov · Three-factor plasticity · `acs.rs` substrate anchor (PARTIAL) · naming-drift disambiguation (Autopoietic vs Anchored) · cross-link to RECURSIVE_GOVERNANCE_VIABLE_SYSTEMS_MODEL B2-H9 |
| 5 | **HELIOS V6.1 substrate** (the V1.x target tier) | `docs/fusion/helios v5 first.md` (754L, v5 lock) + `docs/fusion/helios v5 updated.md` (625L, v5.2 truly final) | doctrine + PARTIAL substrate per `project_helios_v5_substrate_landed` | Full W1-W26 + E1-E7 + H1-H17 + PCF-1..10 substrate built across 11 stages (17 commits) on `feature/landing-liquid-wave`. CI exercises everything; Lean repo skeleton with 35 sorries / ≤149 budget. Five V6.1 Metal kernels (PageGather · SemiseparableBlockScan · LocalRecallIsland · ControllerKernelPack · PacketRouter1bit) are KERNEL_IMPLEMENTATION_POSTURE = "canonical_target_not_implemented_here" — doctrine targets only |
| 6 | **HELIOS V6.1/V6.2 lock + V6.2 falsifier order** (the ship cadence) | `docs/CANONICAL_DOC_INDEX_2026_05_16.md` + `docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md` | doctrine | V6_2_FALSIFIER_ORDER (PageGather baseline → scatter → InterruptScoreCpu → PacketRouter1bit → ControllerKernelPack → SemiseparableBlockScan → LocalRecallIsland → RulerBabilong). Each stage is a falsifiable gate; UAS-ACS as system is "shipped" only when all 8 falsifiers pass on M2 Pro 16 GB hardware |

---

## 3. Naming-drift disambiguation (CRITICAL)

The acronym **ACS** has TWO expansions in the corpus. Both describe the same substrate but from different framings:

| Framing | Expansion | Lineage | Where dominant |
|---|---|---|---|
| Process-view | **Autopoietic Cognitive Stack** | Beer VSM · acs_meta_layer.md · meta_homeostasis.md | Doctrine docs (MASTER_FUSION §3.8 first 8 rows · PASS-2 audit B2-M13 framing · audit-of-audit register) |
| Structure-view | **Anchored Cognitive Substrate** | HELIOS V5 preservation package · CMS_v2_Final_Definitive.md · the Rust code | Code (`epistemos-research/src/acs.rs:17` header) + HELIOS V5 integration plan |

**Disambiguation rule (PR-discipline):** any new surface that uses "ACS" without parenthetical expansion is drift. Always write either:
- `ACS (Autopoietic Cognitive Stack)` when discussing the process / regulation view
- `ACS (Anchored Cognitive Substrate)` when discussing the code / structure view

Both expansions reference the same primitive: recursion + autopoiesis + anchoring. The MASTER_FUSION §3.8 "Naming-drift disambiguation (B2-M13)" row is the authoritative source.

---

## 4. UAS-ACS cross-link map (no-loss inventory)

Every doc that references UAS-ACS, with what it carries. Update this list when net-new references land.

### Doctrine docs

- `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md`
  - §3.2 Six-tier memory hierarchy (UAS = addressable-side of L1-L6)
  - §3.4 SCOPE-Rex (UAS as substrate underlying SCOPE-Rex's address grammar)
  - §3.8 ACS doctrine row (the canonical 11-facet table)
  - §3.16 Helios kernels (the V6.1 / V6.2 target-only kernels named via UAS-ACS contract)
  - §3.18 Provenance ledger (Phase 1 — the verification-plane consumer of UAS)
  - §3.40 Run Ledger per-token cryptographic attestation (B2-M14 sibling; NOT-STARTED)
- `docs/fusion/helios v5 first.md` + `helios v5 updated.md` (V5 lock + V5.2 final)
- `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` (Foundational Seven theorems referenced from `acs.rs`)
- `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` (top-floor doctrine)
- `docs/fusion/SUBSTRATE_READY_FOR_V2_2026_05_04.md` (V2 substrate-ready manifest)
- `docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md` (V6.1 floor research + KV-Direct gate + 70B Cocktail integration)

### Code surfaces

- `epistemos-research/src/acs.rs` (190 LOC · Lane 3 research-only · NEVER ships in MAS)
- `epistemos-research/src/five_planes.rs` (308 LOC · the 5-plane formalism enum)
- `epistemos-research/src/theorem_status.rs` (FOUNDATIONAL_SEVEN constant — referenced from acs.rs:25)
- `agent_core/src/scope_rex/kv/direct_gate.rs` (290 LOC · F-KV-Direct-Gate Rust)
- `Epistemos/Shaders/kv_direct_gate.metal` (65 LOC · F-KV-Direct-Gate Metal)
- `agent_core/src/scope_rex/` (SCOPE-Rex crate: MutationEnvelope + WitnessedState + ClaimGraph + RunEventLog)
- `agent_core/src/cognitive_dag/` (Phase 8.A-G shipped: 10 NodeKind + 10 EdgeKind + Macaroons + Companions + Mirrors)

### Audit / drift docs

- `docs/RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md` B2-M13 row (ACS doctrine anchor)
- `docs/RECURSIVE_GOVERNANCE_VIABLE_SYSTEMS_MODEL_2026_05_15.md` (Beer VSM doctrine pointer · B2-H9 lineage)
- `docs/audits/V6_2_PER_BUBBLE_BINDING_RESEARCH_2026_05_12.md` (UAS verification surface — AnswerPacket race condition)

### Terminal prompts that reference UAS-ACS

- Terminal B prompt (`docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`) Phase B.0-LARGE (F-70B-Local-Cocktail — explicitly cites UAS + ACS + sparse-active-assembly + L3 SSD Oracle as 4-axis verified-floor stack)
- Terminal D prompt (`docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_D_2026_05_16.md`) Phase D.0 (MissionPacket consumes AnswerPacket schema gated by F-ULP-Oracle, which is the UAS-arithmetic-floor)

---

## 5. V1 / V1.x / V2 / Never-ships sort

Per the MAS-first focus doctrine (`project_mas_first_focus_2026_05_03`): **active surface = MAS-shippable only; Pro = feature-gated stubs**.

| UAS-ACS facet | V1 (MAS ship) | V1.x (post-V1 MAS) | V2.x (Pro) | Never-ships (research-only) |
|---|---|---|---|---|
| Rust `acs.rs` substrate types | — | — | — | ✅ NEVER (per file:17 doctrine comment, research-tier only) |
| 5-plane runtime enum | — | — | ✅ V2 (feature-gated) | — |
| KV-Direct gate Rust + Metal | ✅ V1 (Tier-1 SHIPPED) | — | — | — |
| MASTER_FUSION §3.8 ACS doctrine | — | — | — | ✅ doctrine-only (not shippable) |
| V6.1 Metal kernels (5) | — | — | ✅ V2 falsifier-gated | — |
| Cognitive DAG (Phase 8.A-G) | ✅ V1 SHIPPED (in agent_core) | — | — | — |
| SCOPE-Rex | ✅ V1 SHIPPED (in agent_core) | — | — | — |
| Provenance ledger Phase 1 | ✅ V1 SHIPPED (in agent_core) | — | — | — |
| Run Ledger (B2-M14) | — | — | ✅ V2 (paid-team-gated) | — |
| Kuramoto coupling | — | — | — | ✅ research-tier (red-team prefers discrete-time + gossip) |
| HealingAction struct | — | — | ✅ V2 | — |
| MAPE-K + Lyapunov + CBF | — | ✅ V1.x (some maps to OverseerProtocol — partial) | — | — |
| Three-factor plasticity | — | — | — | ✅ research-tier |
| Foundational Seven theorems | — | — | — | ✅ doctrine + Lean proof tier |

---

## 6. Status-transition log

Append-only. Each row = one UAS-ACS-related status change.

| Date | Surface | From | To | Commit | Notes |
|---|---|---|---|---|---|
| 2026-05-08 | `epistemos-research/src/acs.rs` | absent | SHIPPED at 190 LOC | (codex/research-snapshot-2026-05-08 work) | Lifted from HELIOS V5 preservation package per integration plan §M |
| 2026-05-08 | `agent_core/src/scope_rex/kv/direct_gate.rs` | absent | SHIPPED at 290 LOC | (KV-Direct gate landing) | F-KV-Direct-Gate Tier-1 — UAS memory-architecture floor |
| 2026-05-08 | `Epistemos/Shaders/kv_direct_gate.metal` | absent | SHIPPED at 65 LOC | (KV-Direct gate landing) | Metal shader for UAS zero-copy verification |
| 2026-05-13 | MASTER_FUSION §3.8 ACS row | doctrine-only | doctrine + B2-M13 substrate anchor + naming-drift disambiguation | PASS-2 §B2-M13 close | Surfaces 11-facet table + Autopoietic vs Anchored disambiguation |
| 2026-05-15 | `docs/RECURSIVE_GOVERNANCE_VIABLE_SYSTEMS_MODEL_2026_05_15.md` | absent | doctrine pointer | PASS-2 §B2-H9 close (iter 21) | Beer VSM cross-link to ACS 7-scale recursion |
| 2026-05-16 | `docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md` | absent | comprehensive integration doc with §1.12 (KV-Direct) + §1.13 (70B Cocktail) | iter-66 + iter-72 + iter-73 commits | UAS-ACS integrated into V6.1 floor research |
| 2026-05-16 | THIS DOC (`UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md`) | absent | initial register at ~250 LOC | (this commit) | Integration artifact 1 of 3 per 4-advisor synthesis |

---

## 7. PR-discipline rules (UAS-ACS specific)

In addition to the standard MASTER_FUSION §7 acceptance bar:

1. **Naming discipline (mandatory):** every new mention of "ACS" carries its parenthetical expansion in first occurrence per section.
2. **Lockstep §3.8 + `acs.rs`:** any change to ACS code in `epistemos-research/src/acs.rs` MUST update MASTER_FUSION §3.8 ACS table + the §3.8 naming-drift disambiguation row in the same commit (established as PR-discipline rule per B2-M13).
3. **Plane discipline:** any new UAS-ACS surface that doesn't fit cleanly into one of the 5 RuntimePlane values (State / Episodic / Assembly / Controller / Verification) MUST surface as a "plane-placement question" row in this doc §6 before landing code.
4. **5.0 reconciliation:** any PR claiming to add a new UAS-ACS facet MUST first grep this doc §4 cross-link map + verify the facet isn't already present under a different name.
5. **MAS-first gate:** any new UAS-ACS code MUST be tagged with one of: V1 / V1.x / V2 / never-ships per §5 sort. Untagged code is rejected at review.

---

## 8. Open questions (user-decision-gated, not auto-resolvable)

These are surfaced for explicit user direction. They cannot be auto-implemented.

1. **ACS naming convention going forward.** Two expansions coexist (Autopoietic Cognitive Stack process-view · Anchored Cognitive Substrate structure-view). Three options:
   - (a) Keep both (current state; disambiguation row in MASTER_FUSION §3.8 is the authoritative source).
   - (b) Pick "Anchored Cognitive Substrate" as primary (matches code; HELIOS V5 canonical naming) and update doctrine.
   - (c) Pick "Autopoietic Cognitive Stack" as primary (matches doctrine lineage Beer/VSM) and update code header comment.
   - **Recommendation: (a) keep both.** Current state is honest about lineage + structure. Renaming code header risks Lane 3 drift; renaming doctrine risks losing Beer/VSM lineage.

2. **Kuramoto coupling — discrete-time vs continuous-time.** MASTER_FUSION §3.8 notes red-team prefers discrete-time + gossip. NOT-STARTED. Question: does V2.x ship Kuramoto at all, or stays research-tier?

3. **V1.x scope for MAPE-K + Lyapunov.** §3.8 says "some maps to OverseerProtocol". Question: which specific subset of MAPE-K is V1.x vs V2.x?

4. **UAS-ACS shipped surface naming in MAS build.** When V1.x lands MAPE-K subset, what does the user-facing UI call it? "Self-governance"? "Resonance"? "Homeostasis"? Branding question.

---

## 9. Cross-references to the other 2 integration artifacts

This canon is artifact 1 of 3 per the 4-advisor synthesis. The other 2:

- **Artifact 2: V1 Ship Ledger** (`docs/fusion/V1_SHIP_LEDGER_2026_05_16.md`) — enumeration of every feature: v1 ship · v1.1 defer · v2 · never. This UAS-ACS canon's §5 sort table feeds into the Ship Ledger.
- **Artifact 3: Day-in-the-Life Power User** (`docs/fusion/DAY_IN_THE_LIFE_POWER_USER_2026_05_16.md`) — concrete user scenario walking through every shipped UAS-ACS-touching feature. This canon's §2 + §5 are inputs.

Both artifacts will be produced as subsequent iters of this loop run unless user redirects.

---

## 10. What this canon ISN'T

To prevent scope creep:

- **NOT a replacement** for `MASTER_FUSION §3.8` ACS doctrine row. §3.8 is the canonical doctrine surface; this canon is the integration / coherence layer.
- **NOT a research extension.** Does not introduce net-new UAS-ACS facets. It registers existing surfaces.
- **NOT a Pro-tier roadmap.** §5 sort merely classifies existing facets by ship tier; doesn't add new Pro-tier facets.
- **NOT a vault retrieval fix.** F-VaultRecall-50 (the highest-priority product bug per 4-advisor synthesis) is orthogonal product work, not a UAS-ACS register concern.

---

*— End of Unified Active Substrate Canon. Initial register at iter 76 of the codex/research-snapshot-2026-05-08 loop run. Append-only for new surfaces; in-place for status transitions. Cross-refs to §2 (canonical surfaces) + §4 (no-loss map) + §6 (status log).*

---

## 11. T9 Iter 20 Synthesis Delta - 2026-05-17

This pass reconciles the active 9-terminal branch state after T9 iterations 1-20.

| Surface | Branch State | Canon Impact |
|---|---|---|
| Tri-Fusion structured mutation substrate | T1 has branch commits through `fc9efe18d`: Swift Epdoc receiver gate plus 64 deterministic JSON corpus cases; generated artifacts and footer debt remain. | UAS-ACS content-fabric surface is now a real branch implementation, not only doctrine, but acceptance remains short of the 200-doc corpus and PR merge gate. |
| AgentBlueprint mission runner | T2 `79cb183ee` adds typed AgentBlueprint / MissionPacket contracts and Settings dispatch; live refinements continue. | Local Agent Excellence now has a concrete per-model mission-runner surface on branch. It remains Investigating because 36B-on-16GB runtime proof and capability badges are not verified. |
| Vault Context Contract | T4 has local branch commits through `93ad1953a`: trace contract, MMR, recency/user/graph signals, UI provenance, weak fallback rejection, and prompt evidence threshold recorded. | F-VaultRecall-50 moves from "load-bearing open bug" to branch-patched / merge-pending. It is not canonically shipped until T4 pushes PR and main verifies. |
| UI/UX audit coverage | T6 pushed through `e19b8118c`, declaring pass-1 coverage over all 209 `Epistemos/Views/**` files. | UI/UX recursive audit loop has branch-complete pass-1 coverage. The dominant canon risk is accessibility consistency, especially Metal-rendered and generated UI surfaces. |

Open synthesis gates:
- Artifact hygiene remains the recurring cross-terminal blocker (`syntax-core/target/**` dirty in T1/T2/T4/T6).
- T2 must document the Swift-test scope rationale and prove runtime model-gating claims before APP_ISSUES can move beyond `Investigating`.
- T4 must push/PR and document the narrow `agent_core/src/lib.rs` module-registration exception before F-VaultRecall-50 can be treated as shipped.
- T6 pass-2 should prioritize the accessibility representation gaps it found, especially MetalGraphView, onboarding, Epdoc chrome, and AgentBlueprint UI.
