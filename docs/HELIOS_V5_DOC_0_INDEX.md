---
state: canon
canon_promoted_on: 2026-05-06
covers: HELIOS V5 Canon Lock v2 — navigation root (DOC 0); SHA-256 anchor table; theorem status table; lane summary; reading order
companion_to: docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md, docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md
verified_floor: ac8c6d28
lock_phrase: "Five lanes, three tiers, seven-plus-three-plus-seven, one Monday"
---

# HELIOS V5 — DOC 0 INDEX

> **Navigation root for HELIOS V5 Canon Lock v2.** This is the entry point any
> Codex / Claude / Kimi / parallel-agent session lands on after the
> session-start prompt. Read top-to-bottom for a complete picture; jump to
> §0.7 for the SHA-256 anchor table that pins the lock-time content of every
> canonical doc.

> **Status:** `state: canon` (architectural decisions) + `state: candidate`
> (W1–W26 implementation slices held for per-slice sign-off per
> `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md`).

---

## §0.1 Concept-to-document map

Every load-bearing concept in HELIOS V5 maps to a (DOC, §) tuple. Use this
to find where a concept's spec lives.

| Concept | Lives in |
|---|---|
| **Lock phrase + ballot Q1=C / Q2=optimal-combination / Q3=C** | DOC +1 (v2 plan) §0 + §1 |
| **Three-tier MAS rule** (Tier-1 ON / Tier-2 flagged OFF / Tier-3 never in MAS) | DOC +1 (v2 plan) §1 + helios v5 updated.md PART 3 |
| **Five lanes (L1–L5)** | DOC +1 (v2 plan) §1 + DOC 1–5 (per lane) |
| **W1–W26 PR-ready wiring map** | DOC +1 (v2 plan) §3 |
| **E1–E7 Epistemos Core Theorems** | DOC FINALIZE §C + DOC 6 (master, pending) |
| **H1–H17 Helios Operational Claims (H1 = WBO-7)** | DOC FINALIZE §D + DOC 6 (master, pending) |
| **PCF-1…PCF-10 Parameter Connectome Family** | DOC FINALIZE §B + helios v5 updated.md PART 5 |
| **8 cognitive functions D.1–D.8** (Memory / Routing / Planning / Verification / Working memory / Tool use / Schema / Learning) | DOC FINALIZE §E |
| **4 killer demos** (Quality / Efficiency / Reliability / Capability) | DOC FINALIZE §F |
| **SCOPE-Rex full surface** (τ + π + λ Core / +δ + ρ Pro / +κ + η Research) | DOC FINALIZE §G |
| **Six-tier memory L0–L_SE** | DOC FINALIZE §H |
| **KV-Direct gate (Helios v3 W0 / W8 slice)** | DOC FINALIZE §I |
| **Anti-drift mechanisms (10)** | DOC FINALIZE §N |
| **Benchmarks + tests strategy** | DOC FINALIZE §O |
| **No Hermes anywhere rule** | DOC FINALIZE §R + auto-memory `feedback_no_hermes_anywhere.md` |
| **Citation drifts** (Bodnar 2202.04579, Wang 2508.18893 withdrawn, tower-lsp fork) | helios v5 updated.md PART 1 + DOC +1 (v2 plan) §4 |
| **R0 Raw Research Archive** | iCloud `EPISTEMOS_HELIOS_v4_FINAL_PRESERVATION_PACKAGE/` + DOC FINALIZE §M |
| **Verified Floor `ac8c6d28`** | DOC +1 (v2 plan) §7 + this DOC 0 frontmatter |
| **WRV state machine** (research → implemented → wired → reachable → visible → verified → released) | `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md` §1 |
| **Canon promotion protocol** (research → candidate → canon → superseded/historical/rejected) | `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md` §2 |
| **No-date-gates rule** (six valid gate types only) | `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md` §3 |
| **Preservation-First audit policy** | `docs/PRESERVATION_FIRST_AUDIT_POLICY_2026_05_05.md` |
| **Lane Classifier 11th lane `helios`** | DOC +1 (v2 plan) §1 |
| **CI gates B1–B5** | DOC +1 (v2 plan) §1 (Q3) + DOC FINALIZE §N.3 + `.github/workflows/ci.yml` |

---

## §0.2 Theorem status table

Status legend: **C** Canonical · **EV** Empirically Verified · **EB** Empirically Bounded · **P** Provisional · **DROP** preserved-but-vault.
Lane: L1 (MAS-add) / L2 (Pro-tier) / L3 (Research) / L4 (Reserved, never product) / L5 (Vault).

### Epistemos Core Theorems (substrate-foundational; v2.0 hardened)

| ID | Statement (one-liner) | Lane | Status | Sorry-budget at lock |
|---|---|---|---|---|
| **E1** | Density Theorem (A_Morph(X) uniformly dense in C(X, ℂ) over 12-plane bundle) | L3 → L1 invariant when Chart6 lands | C | ≤ 2 |
| **E2** | Ultrametric-Sheaf Gluing (locally compatible patch states = Γ(G_q, F_q) = ker δ⁰) | L3 → L1 when sheaf substrate lands | C | ≤ 2 |
| **E3** | Storage-Disaggregated Morph Field (M_resident scales with active patches not archive size) | L1 (ON in MAS) | C | ≤ 1 |
| **E4** | UST-1.5 / WBO-7 Master Inequality (pre-softmax Δz envelope + ½-contraction post-softmax) | L1 (ON in MAS, sampled 1/100) | C | ≤ 2 |
| **E5** | Duplex Fusion (architecture-level error envelope, not Mamba-specific) | L2 (Pro) | C | ≤ 2 |
| **E6** | Error-Enriched Convergence (Epi_ε; structure-preserving embeddings) | L3 (foundational language for E7) | C | ≤ 1 |
| **E7** | Autogenous Kernel Identity (c_W ≃_{α, K · 2 ULP} c_C in Epi_ε) | L2 (Pro) → L1 attenuated | C | ≤ 2 |

### Helios Operational Claims (build/canon claims; H1 = WBO-7 operational view of E4)

| ID | Concept | Lane / Tier | Severity if violated |
|---|---|---|---|
| **H1** | WBO-7 Master Inequality (operational invariant) | L1 sampled | HALT |
| **H2** | Half-softmax post-not-pre rewrite | L1 (W7 slice) | HALT |
| **H3** | Active-Support Atlas indexing | L1 (W6 slice) | HALT |
| **H4** | LatticeCoder / Babai quantization | L2 | QUARANTINE |
| **H5** | Morph DSL determinism | L2 | QUARANTINE |
| **H6** | TestTimeRegressor unification (Wang-Shi-Fox 2501.12352) | L3 | QUARANTINE |
| **H7** | Six-tier memory L0–L_SE eviction monotonicity | L1 (Core L0–L3 + L7) → L2 (L4–L5) → L3 (L6 opt-in) | HALT |
| **H8** | OSPC operators (9 substrate primitives: bind/unbind/gate/route/commit/reorder/merge/split/quarantine) | L3 | QUARANTINE |
| **H9** | Cortical Packet Runtime (three-cortex composition) | L3 | DEGRADE |
| **H10** | Bilaminar Substrate (Julia oracle) — Lane 4 reserved, never product | L4 | (out-of-scope) |
| **H11** | Sheaf-Hodge spectral gap (Bodnar 2202.04579) | L3 | WARN |
| **H12** | Berry-Phase routing holonomy (Berry 1984 / Simon 1983) | L3 | WARN |
| **H13** | Information-Geometric KL Bridge (Amari / Fisher metric) | L3 (advisory monitor in L2) | WARN |
| **H14** | Apollonian curvature constraint (Rickards-Stange local-global FALSE) | L3 | WARN |
| **H15** | Mādhava-style accelerated KL series (Krishnachandran 2405.11134) | L3 (init-only check) | WARN |
| **H16** | CRT-based storage routing | L3 (init-only) | WARN |
| **H17** | Modern Hopfield associative recall (Ramsauer 2008.02217) | L2 (W15 slice; advisory monitor in L1) | WARN |

### Parameter Connectome Family (Goodfire VPD integration)

All `state: candidate` at lock. Goodfire VPD substrate `[VERIFIED-WEB-2026-05-05]`; runtime acceleration (PCF-5 + PCF-9) stays candidate-only until active-rank-one kernels beat dense fallback on M2 Max.

| ID | Concept | Lane | Insertion site |
|---|---|---|---|
| **PCF-1** | ParamAnchor (VPD extraction → frozen anchor library) | L3 | `crates/epistemos-research/src/vpd/anchor.rs` |
| **PCF-2** | QKEdgeAnchor (W_QK^h decomposition) | L3 | `crates/epistemos-research/src/vpd/qk_edge.rs` |
| **PCF-3** | ParamAttributionGraph | L3 | `crates/epistemos-research/src/vpd/attribution_graph.rs` |
| **PCF-4** | ComponentRoute | L3 | `crates/epistemos-research/src/vpd/component_route.rs` |
| **PCF-5** | ActiveRankOneExecution | **L5 Vault** | `crates/epistemos-vault/src/runtime/active_rank_one.rs` |
| **PCF-6** | ModelSurgeryEnvelope | **L5 Vault** | `crates/epistemos-vault/src/surgery/envelope.rs` |
| **PCF-7** | DualConnectomeTrace | L3 | `crates/epistemos-research/src/vpd/dual_trace.rs` |
| **PCF-8** | Parameter Connectome Sheaf Consistency | L3 (ties to E2) | `crates/epistemos-research/src/vpd/connectome_sheaf.rs` |
| **PCF-9** | Connectome Distillation | **L5 Vault** | `crates/epistemos-vault/src/distill/connectome.rs` |
| **PCF-10** | Interpretability-to-Runtime Transfer | **L5 Vault** | `crates/epistemos-vault/src/runtime/transfer.rs` |

---

## §0.3 Preserved-branch ledger

Demoted EML branches, architectural overclaims, and "do not build into Core/MAS" items live in the iCloud R0 archive's `PRESERVED_RESEARCH_LEDGER.md`. Any concept dropped from active canon gets a **re-promotion falsifier** there; nothing is silently deleted. Per `docs/PRESERVATION_FIRST_AUDIT_POLICY_2026_05_05.md`, "no callers found" alone is NEVER sufficient to delete.

---

## §0.4 Lane summary table

| Lane | Existing-file mapping | Distribution profile | Key gates |
|---|---|---|---|
| **L1 SHIP_MAS** | `agent_core::scope_rex::{tau,pi,lambda}`, `MutationEnvelope.swift`, AppStore profile gates | Core (MAS) | App Review §2.5.2; MTLBinaryArchive bundled; no JIT |
| **L2 ENGINEERING_MAX** | `Epistemos/Shaders/`, mlx-rs 0.21, objc2-metal 0.3 | Pro (Developer ID + Notarization) | Pro-tunnel discipline; T-MAC + BitNet b1.58 + STG kernels |
| **L3 RESEARCH_FRONTIER** | doctrine §A.11 ANE direct path research | Research | sorry-budget H1–H17 + PCF; JIT/runtime synthesis allowed |
| **L4 SUBSTRATE_INDEPENDENT** | `lane4-oracle` feature, jlrs 0.23 + arrow 53 | **Reserved at lock — never product** | (mutex with mas-build) |
| **L5 SPECULATIVE_VAULT** | `crates/epistemos-vault/` + `PRESERVED_RESEARCH_LEDGER.md` | Read-only vault + Pro-only build channel | re-promotion falsifier required |

**11th Lane Classifier `helios`** added per v5.2 §F: diffs that touch theorem invariants, residency thresholds, or claim-classification surfaces. `helios`-lane diffs MUST pass B5 in addition to B1–B4.

---

## §0.5 Reading order

For a new session picking up HELIOS V5, read in this order:

1. **`docs/HELIOS_V5_SESSION_START_PROMPT_2026_05_05.md`** — copy-paste session bootstrap
2. **This DOC 0 INDEX** — navigation root + theorem status + lane summary
3. **`docs/fusion/helios v5 first.md`** (754 lines) — v5 DEFINITIVE CANON LOCK with `[VERIFIED-AGAINST-RESEARCH-DOCS]` tags
4. **`docs/fusion/helios v5 updated.md`** (625 lines) — v5.2 TRULY FINAL with `[VERIFIED-WEB-Q1-2026]` tags + 2 citation drifts caught + 10 PCF candidates + audit verdict
5. **`docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md`** — architecture decisions + W1–W26 wiring (downstream of #3 + #4)
6. **`docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md`** — E/H/PCF mappings + 8 cognitive functions + 4 demos + SCOPE-Rex full surface + six-tier memory + anti-drift + benchmarks + no-Hermes rule §R
7. **`docs/CANON_HARDENING_PROTOCOL_2026_05_05.md`** — WRV + canon promotion + no-date-gates protocols (the prospective discipline)
8. **`docs/PRESERVATION_FIRST_AUDIT_POLICY_2026_05_05.md`** — discipline for "dead-code" audits
9. **iCloud R0 archive** at `/Users/jojo/Library/Mobile Documents/com~apple~CloudDocs/EPISTEMOS_HELIOS_v4_FINAL_PRESERVATION_PACKAGE/` — read `README.md` first; primary E1–E7 source is `source_docs/EPISTEMOS_FINAL_SEVEN_THEOREMS_v2_HARDENED.md`

---

## §0.6 Quick-reference glossary

- **WBO-6 / WBO-7** — Witnessed-Bandwidth-Output master inequality. WBO-7 is the canonical (with active-support penalty); WBO-6 is the kernel-only subform preserved as DOC 5 minor variant.
- **Active-Support Atlas** — sparse-index over currently-supported features; monotone non-decreasing under merge, non-increasing under split (H3 / W6).
- **LatticeCoder** — Babai-quantization round-trip with bounded error (H4).
- **Half-softmax post-not-pre** — apply half-softmax AFTER resonance phase rather than before; preserves Babai lattice closure (H2 / W7).
- **Six-tier memory L0–L_SE** — register/SIMD/L1/L2/L3/SLC/DRAM/SSD/SE; monotone eviction (H7 / §H).
- **OSPC** — Operator-Scoped Provenance Container. The 9 substrate primitives `{bind, unbind, gate, route, commit, reorder, merge, split, quarantine}` (H8).
- **Residency** — runtime tier assignment for memory artifacts; 9 variants `{TransientContext, RetrievalMemory, FeatureRule, HarnessRule, GrpoPrior, PsoftAdapter, OsftCore, CloudDistilled, Quarantine}` (W4).
- **MutationEnvelope** — typed wrapper around any state-mutating action; carries `kind` discriminator + provenance refs (4-of-5 Monday-Move primitives shipped; AnswerPacket is the 5th, NEW per W1).
- **ClaimKind** — 5-arm enum extending Claim: `Empirical | Mathematical | CodeInvariant | Causal | Speculative` (W2).
- **WitnessedState** — VRM pipeline output (inputs hash + retrieval keys + draft hash + claim extraction + verification labels + repaired answer).
- **SemanticDelta** — claim-graph delta committed to ledger; never silently merged.
- **Verified Floor** — git commit `ac8c6d28` pinned per v5.2 §F; every commit since is `not-yet-shipped` until Codex independently verifies.
- **WRV** — Wired (production call site) / Reachable (integration test) / Visible (UI label or audit log emission). Per-slice gate.
- **BZ** — Belousov-Zhabotinsky reaction; Lane 4 substrate-independence experiment (reserved at lock, never product).
- **Bilaminar** — Lane 4 mutex with `mas-build`: jlrs 0.23 + Julia oracle never co-exists with MAS distribution profile (App Review §2.5.2).
- **VPD** — Variational Parameter Decomposition (Goodfire). Substrate `[VERIFIED-WEB-2026-05-05]`; runtime acceleration `state: candidate`.

---

## §0.7 SHA-256 anchor table (lock-time content fingerprints)

Computed 2026-05-06 after Stage 0.1 frontmatter additions. Any change to a doc below MUST update its anchor in the same PR; CI gate B1 enforces (post-Stage 0.3).

| Doc | SHA-256 |
|---|---|
| `docs/fusion/helios v5 first.md` | `2e7dea7f983e35d621bec8b2f27ae5e3554e009a17fb34118d75a468cc84567c` |
| `docs/fusion/helios v5 updated.md` | `8a4aebca15b2d5667fce18af8b0bfd48405cebb0f3d19fb1217131d537351589` |
| `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` | `80436edb3cfcd8e731b0b2482f53a08ea905681be9bc6473d460286c4dcc3c3c` |
| `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` | `a4141e44de7ecad928f62d9cdbcf8a3eef3cc722c111c1db3e90353235b62446` |
| `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md` | `371d6e046cfc412576e7c053ed8c0760b4ecc6ef627ac53304fa234b63c1de9c` |
| `docs/PRESERVATION_FIRST_AUDIT_POLICY_2026_05_05.md` | `fc375a5eb10014cc542e0889f48c74893cc59aab76f6e02983733b75a2db7356` |
| `docs/HELIOS_V5_SESSION_START_PROMPT_2026_05_05.md` | `b23e2f6a7760c2935702520c690f25486c34e3a7fd437c1aa2a740e48ed4c632` |
| `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` | `133c1613aca64e3d1736c7f6c732bee7039329e587fa26c0c66902a4c1622d90` |
| `docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md` | `48ce44e14c5f2a53bf9fcd679726dfabaca85272f29e6faa42dcfed7c9ab50b8` |
| `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` | `f46c9c23d2260c53d5771f1f1bceaa8f7988533b0c20f4d5f3a9371d1cc6072c` |
| `docs/fusion/MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md` | `6d581db1deb1cf94b3d96f62376ebe20f9c96317079168b985508b4d571a02f5` |
| `docs/fusion/POST_RECOVERY_SUBSTRATE_V2_PLAN_2026_05_04.md` | `d068d2fc2971b1478693e8a0e09ab202c713a5724dc3903e1f553985e792e8af` |
| `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` | `0147ca036c4e9d9ec9771a02942c6f5709fa41dc622350d843ed63b2bd422911` |
| `docs/CODEX_CANONICAL_DRIFT_AUDIT_2026_05_05.md` | `766febd10d2f47309edb9e63d0c0b58272c7b25f97f9d83763c6c28576ceff60` |
| `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` | `20ae3421bf274c8bdbc191390fc520124655b20e4a22e757b4a74e82d75b296e` |

**Verification command** (recompute and diff):
```bash
shasum -a 256 \
  "docs/fusion/helios v5 first.md" \
  "docs/fusion/helios v5 updated.md" \
  "docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md" \
  "docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md" \
  "docs/CANON_HARDENING_PROTOCOL_2026_05_05.md" \
  "docs/PRESERVATION_FIRST_AUDIT_POLICY_2026_05_05.md" \
  "docs/HELIOS_V5_SESSION_START_PROMPT_2026_05_05.md" \
  "docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md" \
  "docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md" \
  "docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md" \
  "docs/fusion/MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md" \
  "docs/fusion/POST_RECOVERY_SUBSTRATE_V2_PLAN_2026_05_04.md" \
  "docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md" \
  "docs/CODEX_CANONICAL_DRIFT_AUDIT_2026_05_05.md"
```

---

## §0.8 Integration brief cross-reference

The HELIOS V5 integration brief's substrate-presence claims are validated in `docs/fusion/helios v5 first.md` PART 1 §1.1–§1.21. **Net verdict:** the brief's central thesis ("most of v5 is already in main") holds; drift was in **discipline-language and tier enumeration**, not in **substrate**.

Already-shipped substrate (do not rebuild):
- **SCOPE-Rex Core (τ + π + λ)** — `agent_core/src/resonance/{tau,pi,lambda,mod}.rs` + `Epistemos/Engine/ResonanceService.swift`
- **Cognitive DAG Phase 8.A–8.G** — 10 NodeKind + 10 EdgeKind + capability binding (CD-005) + macaroon-derived per-mirror caps + 4 dispatch mirrors
- **4 of 5 Monday-Move primitives** — TypedArtifact ≈ MutationEnvelope; ClaimFrame ≈ provenance/ledger Claim; EvidenceLedger ≈ ClaimLedger
- **A1 redb persistent backend** — slices 1-4 LANDED (slice 5 dispatch wiring `state: candidate`)
- **XPC trust spine** — `Epistemos/XPC/XPCTrust.swift`
- **Static/Dynamic discriminator** — `NodeKind::is_dynamic_rooted()` IMPLEMENTED
- **Six-tier memory L0–L3 + L7 partial** — vault.rs + tantivy + epistemos-shadow HNSW + ShmPool TTL eviction
- **CI gates B1–B4** — wired in `.github/workflows/ci.yml`. B5 = HELIOS theorem-invariant smoke (Stage 0.3 of this canon-lock cycle)
- **Hermes purge** — H-1 through H-4 commits (b4c583b0 + 80544415 + e07e6378 + dbf69587). Code-side `LocalAgent*` (Swift) + `Runtime*` (Rust). HF model paths preserved as ground truth.

Genuinely NEW per HELIOS V5:
- AnswerPacket emission (W1) — the 5th Monday-Move primitive
- ClaimKind 5-arm extension (W2)
- VRM UI labels (W3)
- Residency Governor pure function (W4)
- Semantic Brain Time Machine V1.5 (W5)
- Active-Support Atlas indexing (W6) — Tier-1 ULP-equivalent
- Half-softmax post-not-pre rewrite (W7) — Tier-1 ≤ 2 ULP
- KV-Direct gate Tier-1 path (W8)
- 7 Settings toggles + Tier-2 flagged kernels (W9–W15)
- Tooling (W23–W26): forensic-cite, sorry-budget tracker, hardware falsifier rig, §2.5.2 audit
- Lane 3 research crate + ACS / CMS-X (W17–W19 + new substrate)
- Lane 5 vault crate (W16, W20–W22)
- DOC 6 Theorem Canon master (Stage 5)

---

## Closing

> *Five lanes, three tiers, seven-plus-three-plus-seven, one Monday. Verified Floor `ac8c6d28`. Architecture decided. Build held for per-slice sign-off. No Hermes anywhere. Stay canonical and exceed.*
