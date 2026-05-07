//! HELIOS V5 Lane 3 (RESEARCH_FRONTIER) workspace member.
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §1 + §3
//! W17/W18/W19 + DOC 0 §0.4:
//!
//! > "Lane 3 RESEARCH_FRONTIER — VPD extraction + Dual Connectome
//! >  Trace + ParamAnchor + QK Edge Anchor + ParamAttributionGraph +
//! >  ComponentRoute. JIT permitted."
//!
//! ## Sub-modules
//!
//! - [`vpd`] — Goodfire-style Variational Parameter Decomposition
//!   substrate (PCF-1..PCF-3, PCF-7, PCF-8). Extracted parameter
//!   anchors + attention-edge anchors + parameter-component graphs +
//!   component routes + dual SPD/SAE traces + sheaf consistency.
//! - [`theorems`] — E1-E7 Epistemos Core Theorem substrate types
//!   (the foundational seven). Includes Chart6 (E1 12-plane bundle),
//!   CellularSheaf (E2), MorphField (E3), WBO7Inequality (E4),
//!   DuplexFusion (E5), Epi_eps (E6), AutogenousKernel (E7).
//! - [`acs`] — Anchored Cognitive Substrate + CMS-X v3 constitutive
//!   field lifts from HELIOS v4 source_docs. Research-tier
//!   architectural anchor.
//! - [`shadow_memory`] — Helios Shadow Memory escalation policy +
//!   Theorem 2.4 (Shadowed Associative State, Conditional) KL
//!   bound substrate (classical analogue of Huang-Kueng-Preskill
//!   2020 / Zhao-Zlokapa-Neven-Babbush-Preskill-McClean-Huang
//!   arXiv:2604.07639). NEVER inherits the quantum advantage.
//! - [`cms_v2`] — Constitutive Moral Substrate v2 (April 2026).
//!   Six defense-in-depth layers, three-tier moral structure
//!   (hard / soft / meta), six unresolvable problems. Cites Brophy
//!   arXiv:2506.00415 (Wide Reflective Equilibrium), Curry et al.
//!   2019 (seven-culture universals), Arditi et al. NeurIPS 2024
//!   (refusal direction).
//! - [`ternary_kernel`] — Ternary Core with Residual Islands typed
//!   substrate: Trit alphabet, 16-trits-per-u32 packing convention,
//!   three-backend triad (Dense/MLX/BitnetReference/TernaryMetal),
//!   9 fragile-dense layers + 4 ternary hot-path layers, residual-
//!   island layer formula. Architectural envelope around the W12/
//!   W13/W14 MSL kernels.
//! - [`theorem_status`] — 5-arm status legend (P/EV/EB/C/DROP) +
//!   7-arm paper-safe label taxonomy + FOUNDATIONAL_SEVEN const
//!   table mapping E1..E7 → status + label per the hardened canon
//!   `EPISTEMOS_FINAL_SEVEN_THEOREMS_v2_HARDENED.md`.
//! - [`v6_1`] — V6.1 Final Synthesis Lock canon: AttentionMode
//!   reframed as Interrupt (not Substrate) per the V5→V6→V6.1 arc;
//!   four-arm CanonLock chain; six-axis V6_1Axis slogan;
//!   `VERIFIED_FLOOR_ANCHOR = "ac8c6d28"` (immutable, carry-forward).
//! - [`sherry`] — Sherry 1.25-bit packing substrate per Hong Huang
//!   et al. (Jan 2026; Tencent/AngelSlim). 3:4 sparsity blocks of 4
//!   weights packed into 5 bits saturating C(4,3)·2³ = 32-config
//!   space. Pack/unpack round-trip + 3:4 contract enforcement.
//! - [`mas_capability_lattice`] — DeploymentTier (MAS / Pro /
//!   Research) × Capability (12-arm) availability lattice per the
//!   `mac_store_edition.md` MAS-First Focus Doctrine. CAPABILITY_LATTICE
//!   const table with 12 canonical rows; doctrine invariants (MAS
//!   baseline must ship; risky surfaces never in MAS; Pro widens MAS).
//! - [`engram`] — Engram hash-table substrate per
//!   `epistemos_resonance_gate.md` §2.2 (DeepSeek V4 inspired).
//!   Static-knowledge O(1) lookup separated from dynamic-reasoning
//!   compute. Sparsity Allocation Law heuristic at ~22% (NOT
//!   theorem) split via `sparsity_allocation_split()`.
//! - [`mathematical_pillars`] — Five mathematical pillars taxonomy
//!   per `epistemos_definitive_master.md` §"PART I". Wyner-Ziv +
//!   Babai/GPTQ + Softmax-½-Lipschitz + Test-Time Regression +
//!   eml-universal. Each pillar has anchor citation + Master
//!   Inequality role. All five are Status::P.
//! - [`self_evolving_l_se`] — L_SE Self-Evolving Extension
//!   substrate per `epistemos_definitive_master.md` §"PART IV".
//!   Hybrid Titans-MAC online + SEAL-DoRA nightly. Surprise
//!   gradient as unified confidence signal across L0..L4 + L_SE
//!   itself. T_SE drift bound parameters for the Master Inequality.
//! - [`validation_thresholds`] — 7 canonical validation thresholds
//!   per `epistemos_definitive_master.md` §"PART VI" §1. KL <
//!   0.05; compression ≥ 10×; top-k recall ≥ 0.95; L4 escalation
//!   < 5%; RAM ≤ 12 GB; decode ≥ 20 tok/s; SSM-Tx gap ≤ 5pp.
//!   `check_all()` returns failing thresholds.
//! - [`falsifier_actions`] — Per-term falsifier actions for the
//!   Master Inequality (WBO-6) per `epistemos_definitive_master.md`
//!   §"PART VI" §2. 6-term `InequalityTerm` × 9-arm
//!   `FalsifierAction` mapping with primary + optional secondary
//!   fallback per term.
//! - [`cross_domain_lens`] — "5 names, one substance" koan from
//!   `helios_v3.md` Part VII: residual stream = prediction error =
//!   surprise gradient = Koopman mode = free cumulant. Plus
//!   `TSafetyBound` parallel safety inequality (CMS-X v3 lives ON
//!   TOP of Helios, not inside the substrate).
//! - [`wbo_generations`] — Master Inequality WBO-5 → WBO-6 → WBO-7
//!   evolution. WBO-5 (compass artifact) ⊂ WBO-6 (definitive
//!   master) ⊂ WBO-7 (V5 canon, current). Per-generation
//!   `term_names()` + `term_count()` + `lock_date()` + `anchor_source()`.
//! - [`kv_direct_gate`] — KV-Direct Week-1 acceptance gate per
//!   `helios_v3.md` Part V "Sharpest Next Move". Binary decision
//!   rule: D_KL == 0 AND peak_ram_reduction ≥ 8×. Per Qasim
//!   Theorem 1 (arXiv:2603.19664).
//! - [`ulp_compare`] — Sign-correct ULP distance utilities per
//!   `epistemos_helios_v3_master_canon_v2_1.md` Patch 8. Naive
//!   `f.to_bits()` subtraction breaks across the sign boundary;
//!   `ordered_f32_bits()` / `ordered_f16_bits()` map to a monotonic
//!   integer first.
//! - [`stack_roles`] — Mac-native stack roles (Rust spine / MLX
//!   hand / Metal nerves) per `helios_v2.md` + canonical reference
//!   checkpoint pins (Qwen3-8B-MLX-4bit transformer track +
//!   cartesia-ai/mamba2-2.7b-4bit-mlx SSM track) for cross-
//!   architecture validation.
//! - [`scientific_calculator_basis`] — Scientific Calculator Basis
//!   per Odrzywołek arXiv:2603.21852 §1.1. 6 canonical categories
//!   (constants / arithmetic / exponentiation / transcendental /
//!   inverse-trig / hyperbolic) totaling 23 members. EML grammar
//!   `S → 1 | eml(S, S)` with 2 productions. Plus 3 explicit
//!   non-analytic functions outside the closure (bump / Weierstrass
//!   / |x| at 0).
//! - [`gate_action`] — ResonanceGate decision actions (6 arms) +
//!   hard-invariant thresholds. Per `epistenos_build_prompt.md`
//!   §2.4 — Pass / Hold / Quarantine / TriggerEvidenceSupremacy /
//!   EngramAnchor / MigrateResidency. Engram-anchor predicate at
//!   prime + ρ > 0.7 + κ > 0.382. Self-monitoring d_max = 3.
//! - [`learning_modes`] — `LearningMode` (4 arms: Freeze /
//!   FastWeight / LoRA / Sketch) + `Direction` (6 arms: Upward /
//!   Downward / Sideways / Inward / OnItself / None) per
//!   `epistenos_build_prompt.md` §2.1 helios-core canonical types.
//! - [`agent_swarm`] — VaultGatedSwarm + Hermes Gateway substrate
//!   per `epistenos_build_prompt.md` §2.4 + §3.4. 5-axis
//!   `TaskBudgetAxis` (MaxTokens/MaxCost/MaxTime/MinResonance/
//!   Deadline) + `AgentMessageContract` (Ed25519-signed, capability-
//!   granted, resonance-classified) + `HermesVerificationOutcome`
//!   (VerifiedPromote / EdgeTriggerEsp / ContradictedQuarantine).
//!   Hermes shared-mmap arena pinned at 200 KiB.
//! - [`cargo_features`] — canonical 9-feature Cargo flag taxonomy
//!   per `epistenos_build_prompt.md` §4.3. Metal + Mlx (default) /
//!   Ane (experimental) / Ssm / Ttt / SelfTuning / Vault / Hermes
//!   (Pro-only) / Bench. is_default / is_experimental / is_pro_only
//!   classifiers are pairwise-disjoint.
//! - [`lane4_falsifier`] — Physical-experiment verdict format per
//!   `helios v5 first.md` DOC 4 §4.5. PhysicalExperiment (Bz /
//!   Sandpile / Other) × Verdict (Confirms / Falsifies /
//!   Inconclusive) → LanePromotion (L4→L5Vault / L5→L3Research /
//!   Stay). Lane-asymmetric promotion rules.
//! - [`vault_categories`] — Lane 5 Speculative Vault category
//!   taxonomy per `helios v5 first.md` DOC 5. Six sections (§5.1
//!   DemotedEmlBranches / §5.2 ArchitecturalOverclaims / §5.3
//!   DoNotBuildInCoreOrMas / §5.4 T18-T35V42Catalog / §5.5
//!   ProRdLater / §5.6 SpeculativeButPreserved). re_promotion_allowed
//!   gate requires both explicit falsifier + satisfaction.
//! - [`five_planes`] — V6.1 Five-Plane runtime formalism per
//!   `Epistemos V6.1 Final Synthesis Lock` PART 3. State /
//!   Episodic / Assembly / Controller / Verification — orthogonal
//!   to the MAS/Pro/Vault product streams. Ternary path lives in
//!   Assembly + Controller planes only.
//! - [`interrupt_score`] — V6.1 Interrupt-score equation per
//!   PART 2.2: `u_t = α·H + β·WBO + γ·Sheaf + δ·Tool + ε·ConnAlarm`.
//!   Three escalation levels (PureRecurrent / RecallEpisode /
//!   FullEscalation). T35-v6.1 falsifier ρ_max = 0.20.
//! - [`v6_1_execution_policy`] — per-stream lean execution policy:
//!   MAS static-9:1 fallback only when `u_t` is unavailable; Pro
//!   full interrupt scoring + LocalRecallIsland; Vault adds
//!   PacketRouter1bit + experimental ConnectomeAlarm.
//! - [`v6_2`] — V6.2 Lean verification canon intake: Jojo's M2 Pro
//!   16GB becomes the shippability rig, hardware falsifiers are
//!   budget-revised to that envelope, and InterruptScore is CPU
//!   canonical with Metal only as a batch shadow path.
//! - [`v6_1_foundation`] — May 7 foundation update: EML-IR is a
//!   bounded computational primitive, `F-ULP-Oracle` gates
//!   `morph_eval_reduced.metal`, and AnswerPacket schema freeze sits
//!   behind the arithmetic floor.
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 is **research-only**. NEVER ships in MAS. The crate has no
//! `mas-build` feature; building it requires `--features research`.

#[cfg(feature = "research")]
pub mod acs;

#[cfg(feature = "research")]
pub mod agent_swarm;

#[cfg(feature = "research")]
pub mod cargo_features;

#[cfg(feature = "research")]
pub mod cms_v2;

#[cfg(feature = "research")]
pub mod cross_domain_lens;

#[cfg(feature = "research")]
pub mod donor_distillation;

#[cfg(feature = "research")]
pub mod engram;

#[cfg(feature = "research")]
pub mod falsifier_actions;

#[cfg(feature = "research")]
pub mod five_planes;

#[cfg(feature = "research")]
pub mod gate_action;

#[cfg(feature = "research")]
pub mod hardware_profile;

#[cfg(feature = "research")]
pub mod goodfire_vpd_specs;

#[cfg(feature = "research")]
pub mod interrupt_score;

#[cfg(feature = "research")]
pub mod kv_direct_gate;

#[cfg(feature = "research")]
pub mod lane4_falsifier;

#[cfg(feature = "research")]
pub mod learning_modes;

#[cfg(feature = "research")]
pub mod m2_max_kernels;

#[cfg(feature = "research")]
pub mod mas_capability_lattice;

#[cfg(feature = "research")]
pub mod mathematical_pillars;

#[cfg(feature = "research")]
pub mod scientific_calculator_basis;

#[cfg(feature = "research")]
pub mod self_evolving_l_se;

#[cfg(feature = "research")]
pub mod validation_thresholds;

#[cfg(feature = "research")]
pub mod wbo_generations;

#[cfg(feature = "research")]
pub mod shadow_memory;

#[cfg(feature = "research")]
pub mod sherry;

#[cfg(feature = "research")]
pub mod stack_roles;

#[cfg(feature = "research")]
pub mod ternary_kernel;

#[cfg(feature = "research")]
pub mod theorem_status;

#[cfg(feature = "research")]
pub mod ulp_compare;

#[cfg(feature = "research")]
pub mod vault_categories;

#[cfg(feature = "research")]
pub mod theorems;

#[cfg(feature = "research")]
pub mod v6_1;

#[cfg(feature = "research")]
pub mod v6_1_foundation;

#[cfg(feature = "research")]
pub mod v6_1_execution_policy;

#[cfg(feature = "research")]
pub mod v6_1_stream_surface;

#[cfg(feature = "research")]
pub mod v6_1_theorems;

#[cfg(feature = "research")]
pub mod v6_2;

#[cfg(feature = "research")]
pub mod vpd;
