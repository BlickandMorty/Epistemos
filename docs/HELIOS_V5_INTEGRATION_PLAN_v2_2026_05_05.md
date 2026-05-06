---
state: canon (architectural decisions) + candidate (implementation slices)
canon_promoted_on: 2026-05-05
audit_patched_on: 2026-05-05 (user audit applied: 4 patches per "not quite canon-lockable as pasted" verdict)
covers: HELIOS V5 DEFINITIVE CANON LOCK v2 (TRULY FINAL) integration with current Epistemos Cognitive DAG substrate
supersedes: docs/HELIOS_V5_INTEGRATION_PLAN_2026_05_05.md (v1)
verified_floor: ac8c6d28 (pinned per v5.2 lock)
lock_phrase: "Five lanes, three tiers, seven-plus-three-plus-seven, one Monday"
choices_locked: Q1=C (full split per Gate Register), Q2=optimal-combination (Tier 1 ON + Tier 2 flagged OFF + Tier 3 never in MAS), Q3=C (aggregate B5 + per-slice WRV + per-slice rollback)
namespace_hardening: E1–E7 (Epistemos Core Theorems) + H1–H17 (Helios Operational Claims) + PCF-1…PCF-10 (Parameter Connectome Family) + W1–W26 (Work Slices) + L1–L5 (Lanes) + R0 (Raw Research Archive, append-only)
companion_to: docs/CANONICAL_SWEEP_CLOSEOUT_2026_05_05.md, docs/CODEX_FULL_HANDOFF_2026_05_05.md
---

# HELIOS V5 ↔ Epistemos Cognitive DAG — Integration Plan **v2**

> **State: canon (architectural decisions) + candidate (implementation slices).**
> The user's v5.2 definitive-lock ballot answered all 15 sign-off
> questions from v1 of this plan. The architectural decisions
> (3 locked choices, Tier-1/2/3 MAS rule, lane assignments,
> 5-lane vocabulary) are now `state: canon`. Per-slice
> implementation work (W1–W26) remains `state: candidate` until
> per-slice WRV proof + rollback procedure are exercised.
>
> **Verified Floor:** `ac8c6d28` (pinned per v5.2 §F).
>
> **What changed since v1:** all 15 sign-off questions answered;
> 10 new T25–T34 PCF candidate theorems admitted; 2 citation
> drifts caught (Bodnar 2202.04579 not 2206.04386; Wang 2508.18893
> withdrawn 2025-12-05); 1 dependency drift (tower-lsp upstream
> unmaintained → fork to tower-lsp-community/tower-lsp-server);
> three of v1's `state: candidate` items have been promoted to
> `state: canon` by Codex continuation in parallel (Static/Dynamic
> discriminator IMPLEMENTED; A1 redb slices 1–4 LANDED, slice 5
> pending; B1/B2/B3 Tier-1 doctrine lifts landed).

---

## §0 — What's locked + what's already implemented since v1

### Locked decisions (v5.2 ballot answered)

| Question (v1 §5) | v5.2 lock |
|---|---|
| Q1: Adopt the 5-lane vocabulary in doctrine? | **C — full split per Gate Register.** Lane 1 = MAS-add; Lane 2 = Pro-tier; Lane 3 = Research; Lane 4 = Reserved; Lane 5 = Vault. The 11th Lane Classifier `helios` is locked per v5.2 §F. |
| Q2: How does MAS handle the v5 Tier-1/Tier-2 kernel upgrades? | **Optimal-combination — Tier 1 ON + Tier 2 flagged OFF + Tier 3 never in MAS.** Three-tier rule per v5.2 §3 (mathematically equivalent ON; bundled-but-defaults-OFF for model-file-changing kernels; runtime-mutating paths Vault-only). |
| Q3: How does CI enforce HELIOS invariants? | **C — aggregate B5 + per-slice WRV + per-slice rollback.** B5 = HELIOS theorem-invariant smoke; per-invariant sampling rates locked at 1/100 for T1–T17 EV theorems and 1/10 for T25–T34 CANDIDATE theorems per v5.2 §F. |

### Implemented since v1 (Codex continuation, observed in modified-file system reminders)

| Item | Status | Closure artifact |
|---|---|---|
| **Static/Dynamic discriminator** (v1 §3.2 brief, Q2 user question) | **IMPLEMENTED** — `state: canon`. `NodeKind::is_dynamic_rooted()` method + doctrine §2.2 paragraph. | `docs/STATIC_NOTE_VS_DYNAMIC_WEIGHT_DELIBERATION_2026_05_05.md` (state: canon) |
| **A1 redb persistent backend** (v1 §3.1 brief) | **PARTIAL — slices 1–4 landed, slice 5 dispatch wiring pending.** redb 4.1.0 dep + RedbDagStore + put_node/get_node + put_edge with CD-005 + edges_from/edges_to + capability registry + merkle_root + snapshot all landed. Default OFF until Phase 8.H authority verification. | `docs/A1_REDB_PERSISTENT_BACKEND_SCOPING_2026_05_05.md` (state: canon-partial) |
| **B1 Tier-1 doctrine lifts** (v1 §3.3) | **LANDED** by Codex continuation into `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`. Phase 21–25 runtime work remains candidate. | `docs/B1_BIOMETRIC_TAMAGOTCHI_BRAINEXPORT_LIFT_TARGETS_2026_05_05.md` (state: candidate for runtime) |
| **B2 Tier-1 doctrine lifts** (v1 §3.4) | **LANDED.** W7-A through W7-J + W8 runtime work remains candidate. | `docs/B2_LIVE_FILES_AND_SUBSTRATE_LIFT_TARGETS_2026_05_05.md` (state: candidate for runtime) |
| **B3 Tier-1 doctrine lifts** (v1 §3.5) | **LANDED.** W6-A through W6-I runtime work remains candidate. | `docs/B3_OBSCURA_BROWSER_LIFT_TARGETS_2026_05_05.md` (state: candidate for runtime) |
| **CD-008 cargo all-targets verification** | **CLOSED by Codex continuation.** All 5 primary crates green at `--all-targets` granularity. | `docs/CD_008_PARTIAL_CLOSURE_2026_05_05.md` |
| **Clippy debt (~126 issues)** | **CLOSED.** Codex continuation cleaned without API-changing refactors per v5.2 §3 Tier-1 constraint. | `docs/CODEX_FULL_HANDOFF_2026_05_05.md` §1 |
| **B5 source-guard** (3 orphan files + tirith Pro-gating) | **RESOLVED.** Codex continuation removed `code_execution.rs` + `graph_query.rs` (proven-dead overlap with cli_passthrough/graph.rs); promoted `note_tools.rs` into compiled registry with R.5 gating; tirith.rs Pro-gated. | `docs/MAS_PRO_SOURCE_GUARD_2026_05_05.md` |
| **NightBrain live Rust task registration** | **WIRED.** `agent_core/src/nightbrain/live.rs` adds idempotent canonical-task registration via FFI. | (file present at canonical path) |

**Net since v1:** 8 items closed, 4 of v1's 5 candidate briefs now have either runtime implementation in flight or doctrine lifts landed, only HELIOS v5 itself remains as a v1-candidate-not-yet-closed brief — and v5.2 supersedes v1 of THIS plan.

---

## §1 — The locked choices + their architectural consequences

### Q1=C: full lane split per Gate Register

The 5-lane vocabulary (Lane 1 MAS-add / Lane 2 Pro-tier / Lane 3 Research / Lane 4 Reserved / Lane 5 Vault) is now canonical. The existing 3-tier distribution model (Core / Pro / Research per doctrine §3) maps as follows:

| HELIOS v5.2 lane | Existing distribution profile | Net delta |
|---|---|---|
| **Lane 1 — MAS-add** | doctrine §3 Core profile | **MAS canonical surface.** All Tier-1 ULP-equivalent kernel upgrades + AnswerPacket/ClaimKind/VRM additions land here. v5.2 §3 Tier-1 ON-by-default constraint applies. |
| **Lane 2 — Pro-tier** | doctrine §3 Pro profile (Developer ID + Notarization) | Opportunistic kernel upgrades + T-MAC LUT + half-softmax post-not-pre + BitNet b1.58 + Sparse Ternary GEMM + runtime active-rank-one experiments (FLAGGED). |
| **Lane 3 — Research** | doctrine §3 Research profile (private framework loading) | VPD extraction + Dual Connectome Trace + ParamAnchor + QK Edge Anchor + ParamAttributionGraph + ComponentRoute. JIT permitted. |
| **Lane 4 — Reserved** | (no current analog) | **Unassigned at lock per v5.2 §F.** Reserved for substrate-independent Lane-4 / physical-experiment work if ever pursued. Not blocking. |
| **Lane 5 — Vault** | existing `PRESERVED_RESEARCH_LEDGER` pattern + new vault-only build feature | HCache/KVCrush, ModelSurgery (PCF-6), Active Rank-One Runtime (PCF-5), Connectome Distillation (T34). Builds with `vault` Cargo feature; never ships outside Lane 5 distribution. |

**Doctrine action:** `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §3 addendum names the 5-lane vocabulary as the canonical mapping over the existing Core/Pro/Research profiles. ~10 line addition. Held for sign-off as a discrete doctrine-merge slice.

### Q2=optimal-combination: the Tier-1/Tier-2/Tier-3 MAS rule

Per v5.2 §3, derived from App Review §2.5.2 verbatim: "Apps should be self-contained in their bundles, and may not read or write data outside the designated container area, nor may they download, install, or execute code which introduces or changes features or functionality of the app." The decisive word is **download**.

**Tier 1 — `[MAS-SAFE-TIER-1]` ships ON in MAS by default** (mathematically equivalent drop-ins; bit-equivalent within ≤ 2 ULP; no model-file change; no behavior change):

- Active-Support Atlas indexing
- Half-softmax post-not-pre rewrite
- KV-Direct gate (only when provably equivalent to existing cache)
- AnswerPacket emission (additive struct + serialization)
- ClaimKind 5-arm extension `(Empirical | Mathematical | CodeInvariant | Causal | Speculative)`
- VRM UI labels `(Verified | Plausible-but-unverified | Speculative | Blocked)`
- Residency Governor (pure function)
- Semantic Brain Time Machine V1.5 (claim-graph deltas only, NEVER tensor checkpoints)

**Tier 2 — `[MAS-SAFE-TIER-2-FLAGGED]` ships in MAS bundle but defaults OFF** (opt-in via Settings; behavior change requires user consent; alternate model files BUNDLED, not downloaded):

- T-MAC LUT against ternary weights (requires bundled BitNet/ternary model GGUF)
- BitNet b1.58 inference path (requires bundled `microsoft/bitnet-b1.58-2B-4T` GGUF)
- Sparse Ternary GEMM (requires ternary-quantized model)
- Modern Hopfield retrieval at chat boundary
- Precomputed VPD Component Browser (transparency surface; bundled atlas JSON; never executes inference change)

**Tier 3 — `[PRO-ONLY]` / `[RESEARCH-ONLY]` / `[VAULT-ONLY]` — never ships in MAS:**

- Runtime VPD training (Lane 3)
- Active Rank-One Runtime execution (Lane 5)
- ModelSurgery / weight editing (Lane 5)
- Connectome Distillation training (Lane 5)
- HCache/KVCrush experimental tier (Lane 5)
- Goodfire-style adversarial component ablation (Lane 5)

**§2.5.2 compliance audit (W26)** is a per-release gate that enumerates every bundled artifact, asserts no runtime download path, and asserts all Tier-2 toggles default OFF. Lives at `tools/app-review-audit/` + `docs/2.5.2-compliance.md`. **CI gate B1 release-gate.**

### Q3=C: aggregate B5 + per-slice WRV + per-slice rollback

CI gates remain **B1 doctrine-lint + B2 verify-replay + B3 Pro-build matrix + B4 lsp-runtime + B5 HELIOS theorem-invariant smoke**. Per-invariant sampling locked:

- T1–T17 EV theorems: 1/100 sample rate (fires every 100th inference)
- T25–T34 CANDIDATE theorems: 1/10 sample rate (more frequent because they're newer + falsifier-driven)

**WRV per slice (W1–W26):**

- **W**ired = production code path with file:line
- **R**eachable = integration test
- **V**isible = UI label OR audit log emission

**Rollback per slice:** every W has a documented rollback procedure (feature-flag OFF + B5 confirms + UI banner returns).

---

## §2 — PCF-1…PCF-10 Parameter Connectome Family mapping

> **Namespace hardening (per user audit 2026-05-05 final):** these
> were tagged `T25–T34` in v5.2 as pasted; the user's audit verdict
> renames them to `PCF-1…PCF-10` to avoid namespace collision with
> the H1–H17 Helios Operational Claims. The mapping below uses the
> hardened PCF-N namespace.

The v5.2 §5 admits 10 candidate theorems at status `CANDIDATE` with sorry-budget ≤ 7 each. Mapping each to current Epistemos substrate:

| PCF | (was T) | Statement (one-liner) | Current substrate? | Lane | Insertion site |
|---|---|---|---|---|---|
| **PCF-1** | T25 | Parameter Assembly Extraction — SPD/APD parameter decomposition recovers ground-truth mechanisms | NO | L3 | NEW: `crates/epistemos-research/src/vpd/extract.rs` |
| **PCF-2** | T26 | Attention Edge Assembly (QK Decomposition) — `W_QK^h = Σ V_{Q,c} (U_{Q,c}^h⊤ U_{K,c'}^h) V_{K,c'}^⊤` | NO. Formula attribution **`[VERIFIED-WEB-2026-05-05]`** per Goodfire May 5, 2026 "Interpreting Language Model Parameters" page | L3 | NEW: `crates/epistemos-research/src/vpd/qk_edge.rs` |
| **PCF-3** | T27 | Parameter-to-Cortical-Packet Lift — parameter component cluster ≥ k_min lifts to cell-assembly per Buzsáki 2010 | NO. Cross-domain analogy | L3 | NEW: `crates/epistemos-research/src/vpd/cortical_lift.rs` |
| **PCF-4** | T28 | Interpretability-to-Runtime Transfer — faithful SPD decomposition transfers to runtime as active-rank-one path with bounded PPL drift | NO | **L5 Vault** | NEW: `crates/epistemos-vault/src/runtime/active_rank_one.rs` (gated `vault` feature) |
| **PCF-5** | T29 | Component Edit Safety Bound — editing component subset S of size ≤ s_max bounds downstream PPL drift by O(s_max · σ_max(W_edit)) | NO | **L5 Vault** | NEW: `crates/epistemos-vault/src/surgery/edit_safety.rs` |
| **PCF-6** | T30 | Component Cluster Compression — cluster-aware quantization achieves ≥ 2× compression at equal PPL vs uniform ternary | NO | L3 | NEW: `crates/epistemos-research/src/vpd/cluster_quant.rs` |
| **PCF-7** | T31 | Dual Decomposition Completeness — dual SPD + SAE decomposition more faithful than either alone | NO | L3 | NEW: `crates/epistemos-research/src/vpd/dual_trace.rs` |
| **PCF-8** | T32 | Parameter Connectome Sheaf Consistency — the parameter connectome over component clusters carries a cellular sheaf | Partial — sheaf substrate doesn't exist; ties into v1 §2 H/E sheaf gap | L3 | NEW: builds on v1 §2 sheaf substrate; same `epistemos-sheaf` crate consideration |
| **PCF-9** | T33 | Active Rank-One Execution — per-step only rank-one subcomponents above threshold τ contribute meaningfully (≥ 1−δ of output norm) | NO | **L5 Vault** | NEW: `crates/epistemos-vault/src/runtime/active_rank_one.rs` |
| **PCF-10** | T34 | Connectome Distillation — model can be distilled to top-k component clusters with bounded PPL drift, producing a NEW model file | NO | **L5 Vault** | NEW: `crates/epistemos-vault/src/distill/connectome.rs` (alternate model file output may eventually ship Tier-2 in MAS after fresh §2.5.2 audit) |

**Falsifier protocols** for PCF-1…PCF-10 all run on M2 Max per v5.2 §5. Hardware falsifier rig W25 (`tools/falsifier/`) is the harness.

**Goodfire VPD verification status — UPGRADED 2026-05-05** per user audit Patch 1: the Goodfire May 5, 2026 "Interpreting Language Model Parameters" page **publicly verifies all 8 specifics** the v5.2 originally tagged `[NEEDS-SOURCE-FILE-VERIFICATION]`:

- ✅ `goodfire-ai/param-decomp` repo (linked)
- ✅ four-layer 67M-parameter toy model (described)
- ✅ 38,912 rank-one subcomponents / 9,972 alive / 205 per position / 2.1% (stated)
- ✅ QK decomposition formula (given)
- ✅ emoticon-edit demonstration (described)
- ✅ VPD decomposes matrices into rank-one subcomponents `W_l ≈ Σ_c U_c^l (V_c^l)^T` (stated)

**Status change:** `[NEEDS-SOURCE-FILE-VERIFICATION]` → **`[VERIFIED-WEB-2026-05-05]`** for PCF specifics. Stage 0 local-doc verification is no longer blocking; substrate verification is web-anchored.

**Caveat preserved:** runtime acceleration (PCF-4 + PCF-9 active-rank-one path) remains `CANDIDATE-only` until our active-rank-one kernel beats dense fallback on M2 Max. Goodfire proves interpretability value at small-model scale, NOT hot-path performance theorem. PCF-4 and PCF-9 stay `state: candidate` even after the substrate verification upgrade.

---

## §3 — W1–W26 PR-ready wiring map (anchored to current Epistemos layout)

The v5.2 §4 prescribes 26 W-slices each with file paths assuming `apps/Epistemos/MAS/Sources/`, `crates/epistemos-core/src/`, `lean/Epistemos/`. Current Epistemos layout differs slightly (`Epistemos/` Swift sources at repo root + `agent_core/` Rust crate; no Lean repo yet). **File paths below are translated to current layout** with `[NEEDS-SOURCE-FILE-VERIFICATION]` tags where v5.2's exact anchors don't yet exist.

### Tier 1 MAS-add slices (W1–W8) — ship in MAS Lane 1

| W | Slice | Files (current layout) | CI | Tier | MAS impact |
|---|---|---|---|---|---|
| W1 | AnswerPacket emission | `agent_core/src/scope_rex/answer_packet.rs` (NEW) + `Epistemos/Bridge/StreamingDelegate.swift` (DELTA) + `Epistemos/Views/Chat/MessageRow.swift` label | B1+B2+B5 | Tier 1 | additive label, zero latency penalty |
| W2 | ClaimKind 5-arm extension | `agent_core/src/provenance/ledger.rs` (extend Claim) + `agent_core/src/provenance/replay.rs` (extend ledger replay) + Swift mirror | B1+B2+B5 | Tier 1 | zero user-facing change |
| W3 | VRM UI labels | `Epistemos/Views/Chat/VRMLabelView.swift` (NEW) + asset catalog | B1+snapshot | Tier 1 | additive UI element |
| W4 | Residency Governor | `agent_core/src/scope_rex/residency.rs` (NEW pure function) + `Epistemos/Engine/ResonanceService.swift` (DELTA — extends existing λ residency tier classification) | B1+B2 | Tier 1 | zero — same eviction outcomes |
| W5 | Semantic Brain Time Machine V1.5 | `agent_core/src/scope_rex/btm_semantic.rs` (NEW; operates on `agent_core/src/cognitive_dag` deltas only) + `Epistemos/Views/History/BTMView.swift` (NEW) | B1+B2+B5 | Tier 1 | additive history feature |
| W6 | Active-Support Atlas indexing | `agent_core/src/scope_rex/metal/asa_index.rs` (NEW) + `Epistemos/Engine/MetalRuntimeManager.swift` dispatch hook | B3+B5 | Tier 1 | zero output change; 5–18% latency target on M2 Max |
| W7 | Half-softmax post-not-pre rewrite | DELTA on existing `Epistemos/Engine/MLXInferenceService.swift` + Lean equivalence proof at future `lean/Epistemos/SoftmaxEquiv.lean` | B3+B5 | Tier 1 | zero output change |
| W8 | KV-Direct gate (Tier-1 path only) | `agent_core/src/scope_rex/kv/direct_gate.rs` (NEW); equivalence proof gates Tier-1 vs Tier-2 promotion | B3+B5 | Tier 1 | zero |

### Tier 2 MAS-flagged-OFF slices (W9–W15) — ship bundled but default OFF

| W | Slice | Settings parent | Tier | MAS impact |
|---|---|---|---|---|
| W9 | Settings → Verified Research Mode toggle | parent for Hopfield retrieval, etc. | Tier 2 | opt-in only |
| W10 | Settings → Connectome Browser toggle | bundles `Epistemos/Resources/connectome_atlas_v1.json` | Tier 2 | opt-in transparency surface |
| W11 | Settings → Experimental Metal Kernels toggle (parent) | parent for T-MAC + BitNet 1.58 + Sparse Ternary GEMM | Tier 2 | opt-in only |
| W12 | T-MAC LUT path (bundled, OFF) | child of W11; bundled ternary model in `Epistemos/Resources/Models/` | Tier 2 | opt-in |
| W13 | BitNet b1.58 inference (bundled, OFF) | child of W11; `Epistemos/Resources/Models/bitnet-b1.58-2B-4T.gguf` bundled | Tier 2 | opt-in |
| W14 | Sparse Ternary GEMM (bundled, OFF) | child of W11; NEON SIMD + blocked interleaved per arXiv:2510.06957 | Tier 2 | opt-in |
| W15 | Modern Hopfield retrieval at chat boundary | child of W9; new `agent_core/src/scope_rex/retrieval/hopfield.rs` | Tier 2 | opt-in |

### Pro-tier + Research + Vault slices (W16–W22) — never ship in MAS

| W | Slice | Lane | Notes |
|---|---|---|---|
| W16 | Pro-tier T-MAC + Atlas joint path | L2 | Pro-build only |
| W17 | Lane 3 VPD extraction pipeline | L3 | `crates/epistemos-research/src/vpd/` (NEW crate) |
| W18 | Lane 3 ParamAnchor library | L3 | `crates/epistemos-research/src/anchors/` |
| W19 | Lane 3 Dual Connectome Trace | L3 | `crates/epistemos-research/src/dual_trace/` |
| W20 | Lane 5 ModelSurgery (Vault) | L5 | `crates/epistemos-vault/src/surgery/` (gated `vault` feature) |
| W21 | Lane 5 Active Rank-One Runtime (Vault) | L5 | `crates/epistemos-vault/src/runtime/` |
| W22 | Lane 5 HCache / KVCrush (Vault) | L5 | `crates/epistemos-vault/src/cache/` |

### Tooling slices (W23–W26) — research + release-gate

| W | Slice | Files |
|---|---|---|
| W23 | Forensic citation registry tool | `tools/forensic-cite/` (NEW Rust binary) |
| W24 | Lean 4 sorry-budget tracker | `lean/Epistemos/SorryBudget.lean` + `tools/sorry-budget/` (requires Lean repo creation; parallel to existing crates) |
| W25 | Hardware falsifier rig (M2 Max) | `tools/falsifier/` (Swift + Rust harness; nightly on dev rig) |
| W26 | App Review §2.5.2 compliance audit (per-release) | `tools/app-review-audit/` + `docs/2.5.2-compliance.md` (CI release-gate B1) |

### 12-week roadmap (calendar advisory; thresholds are ground truth per canon promotion protocol)

| Week | W-slices | Verification gate |
|---|---|---|
| 1–2 | W1, W2, W3 | AnswerPacket emission demo + grammar conformance ≥ 99% on dev set |
| 3 | W4, W5 | Residency Governor unit-test on 100 synthetic eviction traces; BTM replay test on 50 conversations |
| 4 | W6, W7, W8 | T1 ULP-equality test passes on M2 Max; T7 half-softmax equivalence ≤ 2 ULP; T8 KV-Direct round-trip equality on 10³ traces |
| 5 | W9, W10, W11 | Settings toggles all default OFF; W26 compliance audit passes |
| 6 | W12, W13, W14, W15 | Each Tier-2 kernel passes its bundled-model smoke test |
| 7 | W23 forensic citation registry | Tool prints arXiv ID + DOI + mathlib4 path for any T<N> |
| 8 | W24 sorry-budget tracker + W25 falsifier rig | Tracker fails CI if T1–T17 sorry > budget OR T25–T34 sorry > 7; rig runs nightly on M2 Max |
| 9–10 | W17, W18, W19 (Lane 3) | T25–T34 falsifiers run; promote any that pass to EB |
| 11 | W16 Pro-tier joint path | Pro-build matrix on M2 Max passes |
| 12 | W26 §2.5.2 audit + TestFlight pre-flight | Apple TestFlight build accepted, no §2.5.2 flag |
| Vault | W20, W21, W22 (separate cadence) | Vault builds with `vault` feature, no MAS dep |

---

## §4 — Citation drifts + dependency drifts (caught by v5.2)

### Citation drift 1: Bodnar et al. Neural Sheaf Diffusion

- **Was tagged in v1 + v4.2 as:** `arXiv:2206.04386`
- **Correct ID per v5.2 [VERIFIED-WEB-Q1-2026]:** `arXiv:2202.04579` (NeurIPS 2022)
- **Action:** any prior locked document referencing 2206.04386 must be rebased on this correction. Audit affected docs:
  - `docs/HELIOS_V5_INTEGRATION_PLAN_2026_05_05.md` v1 (this plan v2 supersedes it)
  - Any T2 / T11 / T14 sheaf-related references in doctrine § Annex A.13 or future Cognitive DAG sheaf substrate code

### Citation drift 2: Wang arXiv:2508.18893 (Cybenko erratum) WITHDRAWN

- **Was published:** 2025-08-26 ("A note on Cybenko's Universal Approximation Theorem")
- **Withdrawn by Kun Wang:** 2025-12-05 per v5.2 [VERIFIED-WEB-Q1-2026]
- **Implication:** Cybenko's *original* 1989 theorem (MCSS 2:303–314, doi 10.1007/BF02551274) **stands intact**. The 2025 objection was withdrawn.
- **Action:** when implementing T1 Universal Approximation runtime invariant, cite Cybenko 1989 as authoritative. Mention Wang withdrawal as historical context only, NOT as a standing critique.

### Dependency drift: tower-lsp upstream unmaintained

- **Current Epistemos LSP integration** (per agent_core/src/lsp_runtime/mod.rs) uses `tower-lsp 0.20`
- **v5.2 [VERIFIED-WEB-Q1-2026] finding:** `ebkalderon/tower-lsp` is effectively unmaintained (0.20.0, ~2 years stale)
- **Recommended fork:** `tower-lsp-community/tower-lsp-server` (MIT/Apache-2.0, active LSP 3.17 support)
- **Action — pre-W4 dependency change:** swap `tower-lsp` → `tower-lsp-server` in `agent_core/Cargo.toml` BEFORE the W4 LSP-related slice. Replace `use tower_lsp::lsp_types as lsp;` with `use tower_lsp_server::lsp_types as lsp;` (or whatever the fork's actual import path is — verify on first attempt). Re-run `cargo test --lib --features lsp-runtime lsp_runtime` to confirm all 17 tests still pass.
- **Risk if not done:** stale dep accumulates security advisories; LSP 3.17 features (which v5 W17/W18 may need for symbol-graph integration with VPD components) won't be available; CI gate B4 stays green but the substrate calcifies.

---

## §5 — PCF Lane assignments (full split per Q1=C)

Per v5.2 §2:

| PCF item | Lane | Tag | Rationale |
|---|---|---|---|
| **PCF-1 ParamAnchor** (VPD extraction → frozen anchor library) | **Lane 3** (Research) | `[RESEARCH-ONLY]` | Training-time decomposition; never user-visible at runtime |
| **PCF-2 QK Edge Anchor** (attention edge assembly per W_QK^h decomposition) | **Lane 3** | `[RESEARCH-ONLY]` | Symbolic edge between component clusters |
| **PCF-3 ParamAttributionGraph** (graph over parameter components) | **Lane 3** | `[RESEARCH-ONLY]` | Visualization research artifact |
| **PCF-4 ComponentRoute** (route inference through component subset) | **Lane 3** | `[RESEARCH-ONLY]` | Deferred until PCF-1 verified |
| **PCF-5 Active Rank-One Runtime** (runtime per-step component activation) | **Lane 5** (Vault) | `[VAULT-ONLY]` | Modifies inference path; Pro-tier only after long burn-in |
| **PCF-6 ModelSurgery / Connectome Distillation** (offline edit + retrain-free distillation to alternate model file) | **Lane 5** (Vault) | `[VAULT-ONLY]` | Mutates weights; cannot ship in MAS |
| **PCF-7 Dual Connectome Trace** (parameter-space + activation-space joint traces) | **Lane 3** | `[RESEARCH-ONLY]` | Combines SPD + SAE; pure research |

**MAS-side surface (transparency only, no behavioral change):** an *optional* precomputed-metadata Component Browser may ship in MAS at Tier 2 (defaults OFF, opt-in via Settings → "Connectome Browser") because (a) it ships precomputed JSON/binary metadata bundled in the `.app`, (b) it does not execute code that changes inference, (c) it is purely a transparency surface. **§2.5.2 verdict per v5.2: SAFE.**

**`[NEEDS-SOURCE-FILE-VERIFICATION]` action protocol** per v5.2 Stage 0:

1. Open the user's research docs (likely in iCloud or `/Users/jojo/Documents/`)
2. Verify the 8 Goodfire VPD specifics:
   - 67M-parameter, 4-layer toy LM
   - 38,912 rank-one subcomponents
   - 9,972 alive components
   - 205 subcomponents per sequence position (= 2.1% of alive)
   - emoticon-edit demonstration of mechanistic faithfulness
   - QK decomposition formula `W_QK^h = Σ V_{Q,c} (U_{Q,c}^h⊤ U_{K,c'}^h) V_{K,c'}^⊤`
   - parameter faithfulness / minimality / mechanistic-faithfulness / simplicity objectives
   - `goodfire-ai/param-decomp` repo handle
3. **Promotion gate:** if 6 of 8 specifics fail local verification, demote T26 (QK Edge Assembly) to DROP and rebuild the PCF claim list per v5.2 Caveats.
4. If specifics verify, promote PCF-1 + PCF-2 substrate from CANDIDATE-with-warning to CANDIDATE-confirmed; PCF-5 + PCF-6 stay Vault-only regardless.

---

## §6 — What's still held for sign-off (v2 candidate items)

The following implementation work remains `state: candidate` even after v5.2 lock + v1 closures:

1. **W1–W26 implementation slices** themselves. The architecture is locked; the per-slice WRV proof + rollback procedure must be exercised before each slice promotes to canon.

2. **A1 redb slice 5** (dispatch authority wiring). Slices 1–4 LANDED per Codex continuation; slice 5 (`cognitive_dag_store()` returns `RedbDagStore` when `cognitive-dag-redb` feature enabled) PENDING per v1 §3.1 brief.

3. **B1 Phase 21–25 runtime work** (Biometric / Tamagotchi / Brain Export). Tier-1 doctrine lifts LANDED; runtime phases queued.

4. **B2 Phase W7-A through W7-J + W8 runtime work** (Live Files + Stateful Rotor + MoLoRA/QLoRA subprocess elimination). Tier-1 doctrine lifts LANDED; runtime phases queued.

5. **B3 Phase W6-A through W6-I runtime work** (Obscura + deno_core + Eidos). Tier-1 doctrine lifts LANDED; runtime phases queued.

6. **Lean repo creation** (`lean/Epistemos/` + mathlib4 pinned at v5.2 lock SHA). Substantial new dependency (~3-5 GB Lean toolchain + mathlib4 build cache + 30-60 min CI build). W24 sorry-budget tracker depends on this.

7. **The new `crates/epistemos-research/` and `crates/epistemos-vault/` workspace members**. Currently the workspace has `agent_core` + `omega-mcp` + `omega-ax` + `epistemos-shadow` + `graph-engine` + `epistemos-core`. Adding `epistemos-research` (W17–W19) and `epistemos-vault` (W20–W22) is a workspace structure decision that itself needs sign-off.

8. **Local-doc verification of Goodfire VPD specifics** (§5 above; v5.2 Stage 0 prerequisite).

9. **CI gate extension** for B5 HELIOS theorem-invariant smoke. Currently ci.yml has B1-B4; B5 requires the W24 sorry-budget tracker + W25 falsifier rig outputs to be CI-consumable.

10. **`PCF-2`/`T26` formula attribution** `[NEEDS-SOURCE-FILE-VERIFICATION]` resolution.

---

## §7 — The Verified Floor + integration sequence

**Verified Floor: `ac8c6d28`** (commit message: "views(anyview): doctrine §6 #6 enforcement — replace 16 AnyView violations with typed view-builders")

This commit is the canonical baseline. All v5.2 W-slices land ON TOP of this floor without regressing it. CI gate B2 (verify-replay) enforces against `7a063f4a`-and-later commits per the existing `CODEX_VERIFICATION_HANDOFF_2026_05_05.md`; the v5.2 Verified Floor extends that contract.

**Integration sequence (decision-ready, advisory calendar):**

**Stage 0 (this week, BLOCKING for any T25–T34 promotion):** Local-doc verification pass per §5. Resolve all 8 Goodfire VPD specifics. Outcome: PCF substrate either CANDIDATE-confirmed (proceed) or T26 DROP + PCF claim list rebuild (rescope).

**Stage 1 (Weeks 1–6):** Ship W1–W15 in MAS Lane 1 + Lane 2-flagged. Hard gate: W26 §2.5.2 compliance audit must pass on each TestFlight build before App Store promotion. **Tier-1 invariant cap: aggregate ≤ 5 ms cumulative per inference (per v5.2 §F sampling discipline; 1/100 for T1–T17 brings amortized below 0.5 ms).**

**Stage 2 (Weeks 7–12):** Land research crate (W17–W19), forensic registry tool (W23), sorry-budget tracker (W24 — requires Lean repo creation), M2 Max falsifier rig (W25). Run all T25–T34 falsifiers; promote passing ones from CANDIDATE to EB.

**Stage 3 (post-12-week):** Vault crate (W20–W22) builds in separate distribution channel with no MAS dependency. Connectome Distillation (T34) may eventually produce alternate model files that ship Tier-2 in a future MAS release **after** a fresh §2.5.2 audit per v5.2 §B.5.

**Threshold to abort the Tier-2 flagged kernels:** if any single user-facing toggle increases App Review rejection risk above 5% per submission (measured by beta-tester legal review or Apple developer-relations consultation), drop the affected kernel to Pro-only and ship the corresponding MAS update with the toggle removed.

**Threshold to escalate to Lean expert review:** if any T25–T34 sorry-budget exceeds 7 at lock, OR any T1–T17 EV theorem accumulates a sorry, escalate to mathlib4 contributor review before next CI green.

**Threshold to rotate off tower-lsp:** **DO IT NOW** (pre-W4). Upstream unmaintained per v5.2 verification.

---

## §8 — What this v2 brief explicitly does NOT do

- Does NOT implement W1–W26 — proposes them in detail; per-slice implementation needs sign-off + per-slice rollback procedure exercised before each promotion.
- Does NOT touch the Verified Floor `ac8c6d28` — every slice lands on top.
- Does NOT skip Stage 0 — Goodfire VPD specifics MUST be verified against local docs before any T25–T34 promotion above CANDIDATE.
- Does NOT add Lean repo without sign-off (W24 dependency).
- Does NOT add `epistemos-research/` or `epistemos-vault/` workspace members without sign-off.
- Does NOT swap tower-lsp → tower-lsp-server without explicit sign-off (even though §4 recommends "DO IT NOW", the dep change is itself a slice that needs review).
- Does NOT claim "v5.2 IMPLEMENTED" — the architectural decisions are LOCKED, the implementation slices are CANDIDATE.

---

## §9 — User audit applied (2026-05-05 final, 4 patches)

The user's "Final audit verdict: not quite canon-lockable as pasted, but it is very close" identified 4 blocking issues and 3 confirmation patches. All 4 blocking patches are applied to this v2 plan:

### Patch 1: Namespace collision RESOLVED — E/H/PCF split

The v5.2 canon as pasted used `T1`–`T17` for both the Hardened Seven-Theorem Ship Document v2.0 and the HELIOS V5 Theorem Canon, creating a namespace collision (T1 was sometimes Density, sometimes Universal Approximation, sometimes WBO-7). **Hardened mapping:**

| Old name (collision) | New canonical name | Scope |
|---|---|---|
| Hardened v2.0 T1–T7 (Density / Sheaf / Storage / WBO-7 / Duplex / Epi_ε / Autogenous Kernel) | **E1–E7** Epistemos Core Theorems | substrate-foundational; v2.0 hardened seven |
| HELIOS V5 T1–T17 operational claims | **H1–H17** Helios Operational Claims | v5 build/canon claims; H1=WBO-7, H2=half-softmax post-not-pre, H3=Active-Support Atlas, H4=LatticeCoder/Babai, H5=Morph DSL, H6=TestTimeRegressor, H7=six-tier memory L0–L_SE, H8=OSPC operators, H9=Cortical Packet Runtime, H10=Bilaminar Substrate, H11–H17=cross-tradition research |
| T25–T34 (PCF) | **PCF-1…PCF-10** Parameter Connectome Family | applied throughout this v2 plan; see §2 above |
| W1–W26 | **W1–W26** Work Slices | unchanged |
| Lanes | **L1–L5** | unchanged |
| (new) | **R0** Raw Research Archive | append-only; preserves all raw prompts, drafts, Helios v3/v4, SCOPE-Rex docs, brainstorms, demoted branches with re-promotion falsifier |

**Application in this v2 plan:** §2 renamed throughout (T25–T34 → PCF-1…PCF-10 with old-T-numbers preserved in column 2 for traceback). Other sections that referenced "T1–T17" now refer to "E1–E7 + H1–H17" where appropriate.

### Patch 2: Goodfire VPD specifics UPGRADED to verified

The user's audit cites the Goodfire May 5, 2026 "Interpreting Language Model Parameters" page, which **publicly verifies** all 8 specifics the v5.2 canon tagged `[NEEDS-SOURCE-FILE-VERIFICATION]`. **Status changed to `[VERIFIED-WEB-2026-05-05]`** in §2 above. Stage 0 local-doc verification is no longer blocking. **Caveat preserved:** PCF-4 + PCF-9 runtime acceleration stays `state: candidate` until active-rank-one kernels beat dense fallback on M2 Max — Goodfire proves interpretability value at small-model scale, not hot-path performance theorem.

### Patch 3: Bodnar Neural Sheaf Diffusion citation HARDENED to 2202.04579

This v2 plan does NOT contain a Bodnar reference (the audit's Patch 3 is against the v5.2 source canon's later DOC 3 §3.1, not against this plan). **Action for the v5.2 source canon:** patch any remaining `Bodnar-Cangea-Lió arXiv 2206.04386` reference to:

> Bodnar–Di Giovanni–Chamberlain–Liò–Bronstein, "Neural Sheaf Diffusion," **arXiv:2202.04579**, NeurIPS 2022.

Any future doctrine merge of HELIOS sheaf substrate (PCF-8 Parameter Connectome Sheaf Consistency, or v1's T2 sheaf gap, or Annex A.13 Knowledge Sieve) MUST cite 2202.04579 not 2206.04386.

### Patch 4: Cybenko MCSS erratum sentence REMOVED

This v2 plan does NOT contain a "Cybenko MCSS erratum" sentence (the audit's Patch 4 is against the v5.2 source canon). **Action for the v5.2 source canon + future H1 / E1 invariant doc:** delete any sentence stating "the gap was already addressed by Cybenko's MCSS erratum" — replace with:

> Wang's 2025 note (arXiv:2508.18893) is non-load-bearing for Helios. The canon relies on Cybenko 1989 for the classical sigmoidal result and Hornik/Leshno-style generalizations for the architecture/activation-neutral form.

### Confirmation patches (already correct in v2)

- **Patch 5 (M3 Max GPU correction):** v5.2 correctly states M3 Max is 30/40-core GPU, not 128-core. Up to 128 GB unified memory ≠ GPU-core count. Preserved.
- **Patch 6 (jlrs 0.23 verification):** docs.rs verifies jlrs 0.23.0 + Julia 1.10/1.11/1.12 support + Rust MSRV 1.85. Lane 4 `lane4-oracle` ↔ `mas-build` mutex is the right discipline. Preserved.
- **Patch 7 (tower-lsp-server fork):** docs.rs verifies tower-lsp-server 0.23.0 community fork. v2 plan §4 already recommends "DO IT NOW" pre-W4 swap. Preserved.

### Net status after audit

| Category | Status |
|---|---|
| **Architectural decisions (Q1=C, Q2=optimal-combination, Q3=C)** | `state: canon` — sealed |
| **Namespace hardening (E/H/PCF/W/L/R0)** | `state: canon` — applied |
| **Goodfire VPD specifics** | `[VERIFIED-WEB-2026-05-05]` |
| **Bodnar citation** | hardened to 2202.04579 (action item for v5.2 source canon) |
| **Cybenko erratum sentence** | removed (action item for v5.2 source canon) |
| **App Store §2.5.2 phrasing** | defensive language adopted in §9 closing line |
| **Verified Floor `ac8c6d28`** | pinned |
| **W1–W26 implementation slices** | `state: candidate` — held for per-slice sign-off |

**The lock now passes the user's "nothing lost" requirement.** Per the audit verdict: *"You did not lose the research. You have too much duplicated truth, not too little. The final move is not more discovery. It is namespacing and sealing."* Done.

---

## §10 — Closing line (user-audit-patched 2026-05-05)

**HELIOS V5 Canon Lock v2 is conditionally sealed after namespace hardening.** The raw archive is preserved as **R0** (append-only). The Epistemos seven-theorem substrate is **E1–E7**. The Helios operational theorem canon is **H1–H17**. The Parameter Connectome Family is **PCF-1…PCF-10**. Work slices remain **W1–W26**. Lanes remain **L1–L5**. No research branch is deleted; every demoted branch is preserved in Vault with a re-promotion falsifier. Goodfire VPD specifics are now public-web verified as of 2026-05-05, but runtime acceleration remains candidate-only until active-rank-one kernels beat dense fallback. The lock phrase remains: *"Five lanes, three tiers, seven-plus-three-plus-seven, one Monday."*

**Architectural decisions: `state: canon`. Implementation slices: `state: candidate`.**

Per the canon promotion protocol (`docs/CANON_HARDENING_PROTOCOL_2026_05_05.md`), W1–W26 land as individual sign-off-gated slices with WRV proof + rollback procedure per slice. The 12-week calendar is advisory; the per-slice acceptance thresholds are ground truth.

**MAS becomes the perfect build via the optimal combination** — Tier-1 ULP-equivalent kernel drop-ins ON, Tier-2 model-file-changing kernels bundled-but-default-OFF, Tier-3 runtime-mutating paths Vault-only. Per user audit Patch 4: **bundled alternate models and bundled Metal kernels are MAS-candidate-safe ONLY IF** enumerated during review, default OFF when behavior-changing, and covered by W26 §2.5.2 compliance audit. Runtime download or runtime executable generation remains banned from MAS. (Defensive phrasing per user audit; "definitely safe" language removed.)

*Lock sealed (conditionally, after namespace hardening). Verified Floor: `ac8c6d28`. Held for per-slice sign-off — but the architecture is decided.*

---

## Cross-references

- **PRIMARY SOURCE OF TRUTH (persisted in repo):**
  - `docs/fusion/helios v5 first.md` — 754-line v5 DEFINITIVE CANON LOCK with VERIFIED-AGAINST-RESEARCH-DOCS / NEEDS-SOURCE-FILE-VERIFICATION / DRIFT-DETECTED tags
  - `docs/fusion/helios v5 updated.md` — 625-line v5.2 TRULY FINAL with VERIFIED-WEB-Q1-2026 tags + 2 citation drifts caught (Bodnar 2202.04579, Wang 2508.18893 withdrawn) + 10 PCF candidate theorems
- **v5.2 source (also user-pasted message 2026-05-05):** "HELIOS V5 — DEFINITIVE CANON LOCK v2 (TRULY FINAL)" — content matches `docs/fusion/helios v5 updated.md`
- **v1 of this plan (superseded):** `docs/HELIOS_V5_INTEGRATION_PLAN_2026_05_05.md`
- **HELIOS v4 preservation package:** `/Users/jojo/Library/Mobile Documents/com~apple~CloudDocs/EPISTEMOS_HELIOS_v4_FINAL_PRESERVATION_PACKAGE/`
- **Local v5 + v4-updated source files:** `/Users/jojo/Downloads/helios v5.md` + `/Users/jojo/Downloads/helios v4 updated.md`
- **Existing SCOPE-Rex Core (already shipped):** `agent_core/src/resonance/{tau,pi,lambda,mod}.rs` + `Epistemos/Engine/ResonanceService.swift`
- **Existing Cognitive DAG:** `agent_core/src/cognitive_dag/{node,edge,storage,merkle,companions,macaroons,migration,dispatch,resonance}.rs`
- **Existing Monday-Move primitives (4 of 5):** `Epistemos/Models/MutationEnvelope.swift` + `agent_core/src/mutations/envelope.rs` + `agent_core/src/provenance/ledger.rs`
- **Existing LSP runtime:** `agent_core/src/lsp_runtime/mod.rs` (currently uses tower-lsp 0.20; needs swap to tower-lsp-server fork)
- **Doctrine:** `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` (especially §3 distribution profiles, §4.0 UX posture, §4.1 Resonance Gate, §A.6 four memory layers, §A.13 Knowledge Sieve, Annex A.15 Flight Recorder, Annex A.16 Telemetry policy, Annex C Pre-release evidence package)
- **Canon promotion protocol:** `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md`
- **Existing state:candidate queue (closed by Codex continuation):**
  - `docs/STATIC_NOTE_VS_DYNAMIC_WEIGHT_DELIBERATION_2026_05_05.md` (state: canon, IMPLEMENTED)
  - `docs/A1_REDB_PERSISTENT_BACKEND_SCOPING_2026_05_05.md` (state: canon-partial, slices 1-4 LANDED)
  - `docs/B1_BIOMETRIC_TAMAGOTCHI_BRAINEXPORT_LIFT_TARGETS_2026_05_05.md` (Tier-1 lifts LANDED, runtime queued)
  - `docs/B2_LIVE_FILES_AND_SUBSTRATE_LIFT_TARGETS_2026_05_05.md` (Tier-1 lifts LANDED, runtime queued)
  - `docs/B3_OBSCURA_BROWSER_LIFT_TARGETS_2026_05_05.md` (Tier-1 lifts LANDED, runtime queued)
- **Codex Full Handoff:** `docs/CODEX_FULL_HANDOFF_2026_05_05.md` (ISSUE-2026-05-05-001 clippy debt CLOSED by Codex continuation)
- **Verified Floor:** commit `ac8c6d28` (views(anyview): doctrine §6 #6 enforcement — replace 16 AnyView violations with typed view-builders)
