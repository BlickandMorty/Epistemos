---
state: candidate
candidate_promoted_on: 2026-05-05
covers: HELIOS v5 (17-theorem hierarchical canon + 5-lane discipline + Monday Move) integration with current Epistemos Cognitive DAG substrate
authority: held for explicit user/Codex sign-off + parallel-Claude engineering review per the user's 2026-05-05 instruction
companion-to: docs/CANONICAL_SWEEP_CLOSEOUT_2026_05_05.md, docs/CODEX_FULL_HANDOFF_2026_05_05.md
---

# HELIOS V5 ↔ Epistemos Cognitive DAG — Integration Plan

> **State: candidate.** Per the canon-hardening protocol installed
> 2026-05-05 (`docs/CANON_HARDENING_PROTOCOL_2026_05_05.md`),
> doctrine-shaping work goes through `state: candidate` (a brief
> that surveys the substrate, recommends a path, queues sign-off)
> BEFORE landing as `state: canon`. **Do not implement from this
> brief without explicit sign-off.**
>
> **Reviewable.** The user's stated workflow is to have a separate
> Claude session research engineering best methods + have Codex
> verify before any implementation. This brief is structured for
> independent review:
>   - §1 anchors HELIOS v5 to current code (verifiable per-file)
>   - §2 maps each of 17 theorems to a runtime invariant insertion site
>   - §3 maps the 5-lane discipline to existing distribution profiles
>   - §4 dissolves "the Monday Move" against existing 80%-present primitives
>   - §5 lists concrete sign-off questions
>   - §6 flags 8 engineering risks the parallel review should pressure-test
>   - §7 sequences the 12-week roadmap against the existing CI gates + canon promotion protocol

---

## §1 — What HELIOS v5 actually asks for, anchored to current code

Per the v5 canon doc the user shared (the HELIOS v5 Final Canon, "Five lanes, three tiers, seven-plus-three-plus-seven, one Monday"), the asks are:

| HELIOS v5 ask | Status in current main (verified 2026-05-05) |
|---|---|
| **SCOPE-Rex Core** (τ Kleene K3 + π 9-claim classification + λ L0-L7 residency) | **PARTIALLY SHIPPED.** `agent_core/src/resonance/{tau,pi,lambda,mod}.rs` + `Epistemos/Engine/ResonanceService.swift` exist, mirror Doctrine §4.1, doctrine-anchored. δ + ρ (Pro) + κ + η (Research) are NOT yet wired. |
| **The 5 Monday-Move primitives** (TypedArtifact / MutationEnvelope / ClaimFrame / AnswerPacket / EvidenceLedger) | **4 of 5 PRESENT.** `Epistemos/Models/MutationEnvelope.swift` (TypedArtifact + MutationEnvelope) + `agent_core/src/mutations/envelope.rs` (Rust mirror) + `agent_core/src/provenance/ledger.rs` (Claim ≈ ClaimFrame; ClaimLedger ≈ EvidenceLedger). **AnswerPacket is the only genuinely new primitive.** |
| **Cognitive DAG substrate** (typed nodes + edges + capability binding + replay) | **PHASE 8.A-8.G COMPLETE.** `agent_core/src/cognitive_dag/{node,edge,storage,merkle,companions,macaroons,migration,dispatch,resonance}.rs`. 10 NodeKind variants + 10 EdgeKind variants + capability-bound `put_edge` + macaroon-derived per-mirror caps + 4 dispatch mirrors. 879/879 lib tests + 891/891 with lsp-runtime green. |
| **17 theorems compiled to runtime invariants** | **NOT YET STARTED as theorems.** Some implicit substrate-level checks exist (e.g. mmap discipline, BLAKE3 chains, capability binding) but none are formally tagged "T1" through "T17." |
| **Lean 4 formalization (`epikernel-theorems` repo, mathlib4 pinned, sorry-budget tracked in CI)** | **NOT IN MAIN.** No Lean code exists in the repo. No `lakefile.lean`. No mathlib4 dep. |
| **20+ precompiled Metal kernels (MTLBinaryArchive, no JIT)** | **PARTIALLY IN MAIN.** `Epistemos/Shaders/Mamba2/*.metal` (4 shaders) + `Epistemos/Shaders/LandingWave.metal` exist; MTLBinaryArchive build pipeline is partial; the v5 list of 20+ specific kernels (sheaf_laplacian_apply, hopfield_modern_update, etc.) is NOT yet implemented. |
| **DOMINO grammar-constrained decoding** | **NOT IN MAIN.** `Epistemos/LocalAgent/LocalToolGrammar.swift` provides grammar-bound dispatch but is NOT the DOMINO-ICML-2024 reference implementation. |
| **GBNF answer-packet grammar** | **NOT IN MAIN.** No `grammars/answer_packet.gbnf`. |
| **Six-tier memory L0-L_SE active** | **PARTIALLY IN MAIN.** L0-L3 (working memory) + L7 (quarantine) per doctrine §A.3; L4-L5 (Pro) and L6 (Research opt-in) NOT yet wired. The HELIOS v3 KV-Direct gate is NOT in main. |
| **5-lane discipline** | **3-TIER PARTIAL.** Existing Core/Pro/Research distribution profiles per doctrine §3 cover Lanes 1/2/3. Lane 4 (substrate-independent physical experiments) is NOT in main as a discipline. Lane 5 (speculative vault) ≈ existing `PRESERVED_RESEARCH_LEDGER.md` pattern. |
| **The 7-doc set + INDEX (DOC 0-7)** | **NOT IN MAIN.** No `LANE_1_SHIP_MAS.md` / `LANE_2_ENGINEERING_MAX.md` / etc. files exist in `docs/`. |

**Net delta:** the substrate is much further along than the v5 canon implies. The actual delta to v5 is:
1. **Add AnswerPacket + GBNF + DOMINO** to the existing primitive set (the 1 of 5 genuinely new Monday Move type).
2. **Tag existing substrate-level checks** as T1-T7 invariants with formal Lean statements (most of T1-T7 substrate already exists but isn't theorem-labeled).
3. **Build out T8-T17** as new runtime invariants on top of the Cognitive DAG.
4. **Write the Lean repo** (`epikernel-theorems` or rename to fit existing crate naming).
5. **Build out the 20+ Metal kernels** as the precompiled MTLBinaryArchive set (most don't exist yet).
6. **Promote SCOPE-Rex from Core-tier (τ+π+λ) to Pro-tier (+δ+ρ) and Research-tier (+κ+η).**
7. **Adopt the 5-lane discipline + 7-doc set** as a new doctrine layer (per canon promotion protocol, this is itself a candidate brief).

---

## §2 — 17 theorems → runtime invariant insertion sites

The v5 canon's "Hierarchical (Option C)" structure is preserved verbatim: 7 Foundational + 3 Architectural + 7 Cross-Tradition. For each, this section identifies (a) the existing code site that ALREADY implements the substrate the theorem asserts, OR (b) the new code site that needs to be added. This maps the v5 invariant suite (Part H of v5 canon) to concrete file paths.

### Foundational Seven (T1-T7) — sacred v3/v4 inheritance

| T | Substrate already in main? | Insertion site for runtime invariant |
|---|---|---|
| **T1 — Density (Stone-Weierstrass on 12-plane bundle)** | Conceptual; no `Chart6` type exists. | NEW: `agent_core/src/scope_rex/invariants/t1_density.rs` (creates `Chart6` + `assert_t1_separates`). Hook into `cognitive_dag::dispatch::on_chart_promotion` (NEW dispatch fn). Budget: 80 µs. |
| **T2 — Ultrametric Sheaf Gluing** | NO sheaf substrate in main. The doctrine §4.1 + §A.13 (Knowledge Sieve) reference sheaves but no `CellularSheaf` type exists. | NEW: `agent_core/src/scope_rex/invariants/t2_sheaf.rs` (defines minimal `CellularSheaf` + `assert_t2_consistency`). Hook: every cross-tier read (existing `agent_core/src/storage/vault.rs`). Budget: 200 µs. **Engineering risk: a full cellular-sheaf type is a non-trivial dep; consider lifting to a separate `epistemos-sheaf` crate.** |
| **T3 — Storage-Disaggregated Morph Field (RSS bound)** | YES. `Epistemos/App/EpistemosApp.swift` `RuntimeDiagnosticsMonitor` already tracks RSS via `mach_task_basic_info`. `agent_core/src/shared_memory.rs` ShmPool TTL eviction enforces the bound. | EXISTING: add `agent_core/src/scope_rex/invariants/t3_rss.rs` thin wrapper that calls into the existing RSS path + emits `InvariantBreach::T3_ResidentOverflow`. Budget: 5 µs. |
| **T4 — UST-1.5 / WBO-6 Master Inequality (KL-divergence envelope)** | Partial. `agent_core/src/prompt_caching.rs` tracks token quantization; no formal KL envelope check. | NEW: `agent_core/src/scope_rex/invariants/t4_wbo6.rs` + telemetry hook into existing inference path. Budget: 1 ms (sampled, not every token). **Engineering risk: requires baseline-KL telemetry which doesn't exist today.** |
| **T5 — Duplex Fusion (hard ternary + soft attention)** | Partial. `Epistemos/LocalAgent/LocalAgentLoop.swift` + `ConfidenceRouter.swift` route between local + cloud paths but not under a formal η·Δ bound. | NEW: `agent_core/src/scope_rex/invariants/t5_duplex.rs` + ConfidenceRouter calibration. Budget: 100 µs/router-emit. |
| **T6 — Error-Enriched Convergence (Epi_ε)** | NO categorical substrate. Doctrine §A.6 references the four memory layers but no `Epi_ε` formalism. | NEW: `agent_core/src/scope_rex/invariants/t6_epi_eps.rs` — but per v5, T6 is "ship-with-caveat" and the Lean elaboration is sorry-5. **Recommend: skip runtime invariant; keep T6 as doctrine-only foundational language for T7's equality claims.** |
| **T7 — Autogenous Kernel Identity (ULP-bounded compilation)** | Partial. `Epistemos/Engine/MetalRuntimeManager.swift` ships precompiled Metal kernels but no ULP-oracle test harness. v5 says "ship `crates/morph-kernel/tests/ulp_oracle.rs` Monday." HELIOS v4 README explicitly names this as "the single sharpest move." | NEW: `agent_core/src/scope_rex/invariants/t7_kernel.rs` + `agent_core/tests/ulp_oracle.rs`. Hook: every Metal kernel promotion. Budget: 5 ms (spot-check ≥1024 random inputs). **Engineering risk: requires fp64 oracle (HELIOS proposes `oxieml::EmlTree::eval_real`). The user's v5 explicitly demoted EML-alone density from canon — recheck whether the oracle dep is still wanted.** |

### Architectural Three (T8-T10) — load-bearing engineering theorems

| T | Substrate? | Insertion site |
|---|---|---|
| **T8 — Active Assembly (CAFTI/PARN)** | NO. Cell-assembly substrate doesn't exist; doctrine §A.4 ACS recursion sketches it but no `assembly_compiler.rs`. | NEW: `agent_core/src/scope_rex/invariants/t8_assembly.rs`. Hook: routing dispatch. Budget: 50 µs. |
| **T9' — Renderer-Separation (verdict-monotone decoder)** | Partial. `Epistemos/LocalAgent/IncrementalToolCallDetector.swift` enforces grammar-bound tool emission; no verdict-monotonicity check. | NEW: `agent_core/src/scope_rex/invariants/t9_renderer.rs`. Hook: every render emit. Budget: 200 µs/claim. **Pairs naturally with the AnswerPacket + GBNF Monday Move work.** |
| **T10 — Cognitive Externalization** | YES. The Cognitive DAG IS the externalization substrate (`agent_core/src/cognitive_dag/*`). Existing 4 mirrors (`migration.rs`) externalize Skills, Procedural, Provenance, Companion. | EXISTING: T10 invariant is "prove K∘M_s outperforms M_l on bounded personal-domain tasks." Hook: `Epistemos/Harness/TraceCollector.swift` rolling A/B telemetry. Budget: async (no inference-path cost). **Engineering risk: requires a 7-theorem corpus + 200-question eval set the user mentions but doesn't exist in repo today.** |

### Cross-Tradition Seven (T11-T17) — admitted with falsifiers

| T | Substrate? | Insertion site |
|---|---|---|
| **T11 — Sheaf-Hodge spectral gap** | NO. Sub-theorem of T2. | NEW (after T2). Budget: 50 ms (spectral gap on M2 Max is the gating cost). |
| **T12 — Berry-Phase routing holonomy** | NO. | NEW: `agent_core/src/scope_rex/invariants/t12_berry.rs`. Budget: 1 ms. |
| **T13 — Information-Geometric KL Bridge (Fisher metric)** | NO. | NEW: `agent_core/src/scope_rex/invariants/t13_info_geo.rs`. Budget: 500 µs. |
| **T14 — Apollonian curvature (Descartes residual)** | NO. | NEW. Budget: 100 µs. **Critical caveat (per v5 §A.2 + Caveat #4): T14 must encode Rickards-Stange 2023's local-global FAILURE as the obstruction set, not assume completeness.** |
| **T15 — Madhava-Style accelerated KL series** | NO. Init-only check; bounds error on accelerated KL series. | NEW: init-time check in agent_core boot. Budget: init-only. |
| **T16 — CRT-based storage routing** | NO formal CRT in storage; mathlib4 has the theorem (CRT in `Mathlib.Data.ZMod.Basic`). | NEW: `agent_core/src/scope_rex/invariants/t16_crt.rs`. Budget: init-only (boot check). |
| **T17 — Modern Hopfield associative recall** | NO. Working-memory substrate exists (`agent_core/src/agent_runtime/`) but no Hopfield primitive. | NEW: `agent_core/src/scope_rex/invariants/t17_hopfield.rs` + new Metal kernel `hopfield_modern_update.metal`. Budget: 2 ms. |

### Aggregate runtime budget verification

The v5 canon claims "≤5 ms cumulative per inference; mostly sampled, so amortized <0.5 ms." Verify against existing inference path:

- **Existing per-inference budget (current main, no v5 invariants):** ~150 ms p95 medium prompt on M2 Max per the existing `benchmarks/results/*.json` baselines.
- **Proposed v5 add:** sum of per-theorem budgets = 80 µs (T1) + 200 µs (T2) + 5 µs (T3) + 1 ms (T4 sampled) + 100 µs (T5) + 0 (T6 docs-only) + 5 ms (T7 spot-check) + 50 µs (T8) + 200 µs (T9') + 0 (T10 async) + 50 ms (T11) + 1 ms (T12) + 500 µs (T13) + 100 µs (T14) + 0 (T15 init) + 0 (T16 init) + 2 ms (T17) = **~59 ms cumulative if every check fires every inference.**
- **Sampling discipline brings it down:** if T4 + T7 + T11 + T17 sample at 10% (the 4 expensive ones), amortized ≈ 8 ms additional per inference. **Acceptable but not ≤5 ms — the v5 claim is optimistic.**

**Engineering risk #1:** the v5 ≤5 ms aggregate is achievable only with aggressive sampling. The plan needs explicit per-invariant sampling rates locked at design time, not left to runtime.

---

## §3 — 5-lane discipline mapped to existing distribution profiles

The v5 canon's 5-lane structure already maps cleanly onto current Epistemos:

| HELIOS v5 lane | Existing Epistemos analog | Delta |
|---|---|---|
| **Lane 1 — SHIP / MAS** | Existing **Core / MAS distribution profile** per doctrine §3 + §1.7 ("App Store First — Infinite Hardening"). MAS_PRO_SOURCE_GUARD audit landed today. | NO new lane needed. v5's Lane 1 spec (no JIT, MTLBinaryArchive only, public CoreML, attenuated invariants) is already the canonical Core profile. ADD: AnswerPacket + GBNF + DOMINO as Core-shippable substrate. |
| **Lane 2 — ENGINEERING-MAX / EpiKernel Cortex** | Existing **Pro distribution profile** per doctrine §3 (Developer ID + Notarization). | RENAME ONLY. The 20+ precompiled Metal kernels v5 enumerates (sheaf_laplacian_apply, hopfield_modern_update, hdc_vsa_*, etc.) become Pro-tier additions to existing `Epistemos/Shaders/`. |
| **Lane 3 — RESEARCH-FRONTIER** | Existing **Research distribution profile** per doctrine §3 (Developer ID + private framework loading). The `_ANEClient` work in doctrine §A.11 IS Lane 3. | RENAME ONLY. v5's Lane 3 = existing Research tier + the JIT/`mx.fast.metal_kernel` permission. ADD: Lean 4 repo (`epikernel-theorems`). |
| **Lane 4 — SUBSTRATE-INDEPENDENT (BZ + sandpile + Julia oracle)** | **NOT IN MAIN.** Genuinely new lane. | NEW lane. Per v5 §B.4, this is research-only, never product. The Julia oracle target (`helios-oracle/`) needs feature-flag isolation from `mas-build`. |
| **Lane 5 — SPECULATIVE-PRESERVATION VAULT** | Existing `PRESERVED_RESEARCH_LEDGER.md` pattern in HELIOS v4 preservation package + `docs/_archive/` directory. | RENAME + EXTEND. Existing pattern has 4 demoted EML branches + 4 architectural overclaims; v5 adds T18-T35 + ANE/M5 Ultra/PEER preservation entries. |

**Net:** Lanes 1-3 are RENAMES (low cost; align v5 vocabulary with existing distribution-profiles doctrine). Lane 4 is GENUINELY NEW (and explicitly never-product per v5 §B.4 — physical experiments only). Lane 5 EXTENDS an existing preservation pattern.

**Recommendation:** adopt the 5-lane vocabulary in the doctrine (§3 addendum), but DO NOT create new code paths for Lanes 1-3 — they're the existing distribution profiles. Only Lane 4 (Julia oracle + physical experiment logging) and Lane 5 (preservation vault directory) are new file artifacts.

---

## §4 — The Monday Move dissolved against existing primitives

V5 §G prescribes 5 types in build order. Each maps to existing code:

| V5 type | Existing in main? | Recommendation |
|---|---|---|
| **TypedArtifact<T>** (SHA-256 + schema_version + payload + witness) | ✅ `Epistemos/Models/MutationEnvelope.swift:88,293` (Sensitivity enum + sensitivity field) + `agent_core/src/mutations/envelope.rs` (Rust mirror with wire-format byte parity per `EpistemosTests/MutationEnvelopeParityTests.swift`) | **REUSE EXISTING.** No new type; tag the existing `MutationEnvelope` as the v5 TypedArtifact. |
| **MutationEnvelope** (prev_hash + new_hash + mutator_id + timestamp + signature) | ✅ Same files. The existing wire format already has all 5 fields. | **REUSE EXISTING.** |
| **ClaimFrame** (subject + predicate + object + evidence_handle + confidence + sheaf_position) | ✅ partial: `agent_core/src/provenance/ledger.rs` has `Claim` (id + text + derived_from + supported_by + created_at_ms). Missing: explicit subject/predicate/object decomposition + sheaf_position field. | **EXTEND.** Add `subject + predicate + object + sheaf_position` fields to existing `Claim`. ~30 LOC. |
| **AnswerPacket** (vec<ClaimFrame> + summary + GBNF schema version + DOMINO mask digest) | ❌ NEW. | **NEW.** This is the only genuinely-new Monday-Move primitive. ~150 LOC Rust + ~50 GBNF grammar + ~50 LOC Swift binding. |
| **EvidenceLedger** (append-only ClaimFrame store with mmap'd cold tier + HNSW hot index) | ✅ `agent_core/src/provenance/ledger.rs` `ClaimLedger` (append-only) + `agent_core/src/storage/vault.rs` (tantivy + bge-small embeddings) + `epistemos-shadow` crate (HNSW). | **REUSE EXISTING + INTEGRATE.** ClaimLedger already exists; integrate with shadow's HNSW for the AnswerPacket retrieval path. |

**Revised Monday Move (much smaller than v5 implies):**

```
Day 1: Tag existing MutationEnvelope as v5 TypedArtifact in doctrine §9 anchors.
Day 2: Extend Claim with subject/predicate/object/sheaf_position fields. Update ledger tests.
Day 3: Define AnswerPacket struct + GBNF grammar at agent_core/grammars/answer_packet.gbnf.
Day 4: Wire DOMINO-mask decoder over existing IncrementalToolCallDetector path.
Day 5: AnswerPacket emission demo via Qwen3-8B-MLX-4bit + grammar-conformance test (target ≥99% on dev set).
```

**Total estimated LOC:** ~250 Rust + ~50 GBNF + ~80 Swift + ~150 LOC tests. **Comparable to A1 redb scoping (5-9 hours) — NOT the 12-week build the v5 canon implies for the full HELIOS substrate.** The v5 12-week roadmap is the FULL theorem suite + Lane 4 physical experiments, not the Monday Move alone.

---

## §5 — Concrete sign-off questions for the user

Per the canon promotion protocol, this brief MUST queue explicit sign-off questions. The user's standing instruction is to have them reviewed before implementation lands.

**Strategic (5):**

1. **Adopt the 5-lane vocabulary in doctrine?** YES = §3 addendum + future docs use Lane 1/2/3 instead of Core/Pro/Research; NO = keep existing 3-tier vocabulary, treat v5's 5-lane structure as alternative naming only.

2. **Promote the 7-doc set + INDEX (DOC 0-7) into `docs/`?** Each is a substantial new doc; per the user's "feedback_doc_verbosity" memory ("Read EVERY associated research doc before touching a feature; token cost irrelevant"), the verbose 7-doc structure is doctrine-aligned. But it duplicates content already in existing docs (e.g. doctrine §3 already covers Lane 1/2/3). YES = create the 8 files; NO = keep existing doctrine + reference v5 inline.

3. **Implement T1-T17 invariants in this branch (`feature/landing-liquid-wave`) or a new branch?** The clippy debt + state:candidate items already queued (Static/Dynamic, A1 redb, B1-B3 phases) suggest a separate `feature/helios-v5-integration` branch is cleaner.

4. **Lean 4 commitment.** Adding mathlib4 to the workspace is a substantial new dependency (~3-5 GB Lean toolchain + mathlib4 build cache). Worth it for sorry-budget-tracked formal verification, but not free. YES = create `epikernel-theorems/` Lean repo per v5 §V12; NO = ship Rust runtime invariants only with theorem-doc cross-refs.

5. **Promote SCOPE-Rex from Core (τ+π+λ shipped today) to Pro (+δ+ρ) to Research (+κ+η)?** The Pro tier's δ (5 directional operators) and ρ (resonance) are doctrine §4.1 material that hasn't been implemented. Lock the implementation order: SCOPE-Rex Pro tier BEFORE T11-T17 cross-tradition theorems, since T11/T12/T13 rely on the resonance + directional substrate.

**Tactical (5):**

6. **AnswerPacket placement.** Add to existing `agent_core/src/provenance/` module OR create new `agent_core/src/scope_rex/answer_packet/`? Recommendation: new `scope_rex` module for cohesion.

7. **DOMINO library.** Use upstream `microsoft/aici` or roll our own (per the v5 doc's preference for "hand-written GBNF grammar")?

8. **GBNF grammar location.** `agent_core/grammars/answer_packet.gbnf` (binary-adjacent) or `docs/grammars/answer_packet.gbnf` (doc-adjacent)? Recommend the former.

9. **The HELIOS v4 oxieml dep.** v5 §G keeps `oxieml::EmlTree::eval_real fp64` as the T7 ULP oracle. But v5 §A.2 demoted EML-alone density from canon. Is the oracle still wanted? If yes, vendor at locked SHA per HELIOS v4 README pattern. If no, T7's ULP oracle needs a different fp64 path (MPFR? rug?).

10. **The 7-theorem corpus + 200-question eval set** referenced in T10 acceptance criteria + v5 §E.1 D.1 quality demo — does this corpus exist anywhere, or does it need authoring? Recommendation: author as `tests/corpora/seven_theorem_eval.jsonl` as a separate slice before T10 invariant lands.

**Engineering best-practice (5 — for the parallel-Claude review):**

11. **Sampling discipline.** §2 above shows the v5 ≤5 ms claim requires aggressive sampling. Lock per-invariant sampling rates at design time: T4 + T7 + T11 + T17 at ≤10% sample rate; T1-T3 + T5 + T8 + T9' + T12-T14 + T17 at every-invocation.

12. **MTLBinaryArchive enumeration.** v5 names 20+ specific kernels (`sheaf_laplacian_apply.metal`, etc.). Most don't exist. Build order: T-numbered theorem invariants → kernels they need → MTLBinaryArchive build script.

13. **CI gate extension.** The existing 4 CI gates (B1 doctrine lint, B2 verify-replay, B3 Pro feature, B4 lsp-runtime) need a 5th: B5 = HELIOS theorem invariant smoke (run Lean elaborations + Rust runtime invariant tests).

14. **Workspace structure.** v5 prescribes `epikernel-core` Rust crate parallel to agent_core. The existing pattern is monorepo-style (`agent_core` + `omega-mcp` + `omega-ax` + `epistemos-shadow` + `graph-engine` + `epistemos-core`). Recommendation: add `agent_core/src/scope_rex/` as a module, not a new crate, until the surface justifies a split.

15. **Backward-compatibility with the 86 commits already on this branch.** The session-end state is clean (working tree green except CD-009 benchmark JSONs); a HELIOS v5 integration must land on top without regressing the existing canon-hardening work.

---

## §6 — 8 engineering risks the parallel review should pressure-test

For the user's separately-tasked Claude session researching engineering best methods, here are the risks I want pressure-tested:

1. **Aggregate runtime budget.** §2 shows v5's ≤5 ms claim is optimistic; locked sampling rates needed.

2. **Lean toolchain cost.** mathlib4 adds ~3-5 GB to dev environment + 30-60 min CI build. Worth it for formal verification, but evaluate alternatives (Coq, Agda, F*, or Rust-only with `kani`/`prusti` for symbolic verification).

3. **EML / oxieml dep evolution.** v5 demotes EML-alone density but keeps oxieml as T7 oracle. Resolve before T7 ulp_oracle.rs lands.

4. **DOMINO subword alignment** on Qwen3 tokenizer. v5 references DOMINO ICML 2024 (arXiv 2403.06988) but the user's local agent uses Hermes-3 ChatML format (`HermesPromptBuilder.swift`). Verify DOMINO's subword-prefix-tree alignment works on Qwen3's BPE tokenizer.

5. **Sheaf-Laplacian on M2 Max ≤50 ms** (v5 T11 hardware falsifier). Sparse linear algebra on Apple Silicon is uneven (no cuSPARSE-equivalent). Verify with a benchmark before committing the budget.

6. **ANE direct-access (Lane 3, T7+T17 ANE-accelerated paths).** maderix's 19 TFLOPS FP16 measurement is research-quality. Apple may close `_ANEClient` discovery path with any macOS update. Plan for graceful degradation.

7. **App Review 2.5.2 risk surface.** v5 Lane 1 ships precompiled-only (no JIT). Verify NO transitive dep brings in JIT (e.g. tantivy's regex-syntax has historically caused this). MAS_PRO_SOURCE_GUARD audit covers subprocess; a parallel "JIT/codegen surface" audit is new work.

8. **The 12-week roadmap calendar.** v5 §F + §"Recommendations Stage 1-5" assume one full-time person. Realistic? Existing session pattern has been ~80 commits in one day with autonomous loop; the 12-week formalization + 5 lanes + 7 docs + 17 theorems is on the order of months, not weeks.

---

## §7 — 12-week roadmap aligned to existing CI gates + canon promotion protocol

The v5 §F roadmap is solid but needs to land WITHIN the existing canon promotion protocol. Each week's deliverables become `state: candidate` briefs that get sign-off cycles.

**Pre-week 1 (now):** this brief lands as `state: candidate`. User + Codex + parallel-Claude engineering review answer the 15 sign-off questions in §5. Adjustments folded in. Brief promoted to `state: canon` only after sign-off.

**W0 (gate): canon-promotion sign-off.** Without sign-off, no implementation. With sign-off, the brief promotes to `state: canon` and W1 begins.

**W1-W2 (Monday Move + SCOPE-Rex Pro promotion):** AnswerPacket + GBNF + DOMINO + ClaimFrame extension. SCOPE-Rex δ + ρ Pro-tier added (`agent_core/src/resonance/{delta,rho}.rs`). One CI gate added: B5 = HELIOS smoke. **Deliverable:** AnswerPacket emission demo + grammar conformance ≥99%.

**W3-W4 (T1-T3 Foundational invariants):** T1 density + T2 sheaf + T3 RSS as `agent_core/src/scope_rex/invariants/t{1,2,3}.rs` with hooks into existing dispatch sites. Lean repo skeleton (`epikernel-theorems/`). **Deliverable:** T1+T2+T3 sorry-budget per v5 §F locked.

**W5-W6 (T4-T7 + Lean):** T4 WBO-6 + T5 Duplex + T6 Epi_ε (docs-only) + T7 ULP oracle (with resolved oxieml decision). T7 is the single sharpest move per HELIOS v4 README. **Deliverable:** F1/F7a oracle test passes ≤2 ULP fp16 vs fp64 oracle.

**W7-W8 (T8-T10 Architectural):** T8 active assembly (requires PARN/CAFTI substrate that doesn't exist; this is the biggest unknown), T9' renderer separation (pairs with W1 AnswerPacket), T10 cognitive externalization (requires 7-theorem corpus). **Deliverable:** all 3 architectural invariants live + 7-theorem corpus authored.

**W9-W10 (T11-T17 Cross-Tradition):** Ship the 7 cross-tradition theorems. Each gets a hardware falsifier on M2 Max. **Deliverable:** at least 4 of T11-T17 falsifiers pass.

**W11 (Lane 4 + Lane 5):** Lane 4 BZ rig + sandpile experiments ($250 + $20 budget per v5 §B.4). Lane 5 vault directory populated with all v4.2 + v5 demoted entries. Julia oracle target gated behind `lane4-oracle` feature flag mutually exclusive with `mas-build`. **Deliverable:** Lane 4 falsifier verdicts logged; Lane 5 vault SHA-256 hash table in INDEX.md.

**W12 (Lane 1 MAS pre-flight):** TestFlight pre-flight build to surface App Review 2.5.2 questions early. Reproducibility manifest. v5 lock SHA-256 sealed in INDEX.md. **Deliverable:** TestFlight build accepted, no 2.5.2 flag.

**Post-W12 (Months 4-6):** Lane 1 MAS submission per v5 §"Recommendations Stage 5".

**Slip protocol:** per the canon promotion protocol's no-date-gates rule, calendar weeks are advisory. Hold the deliverable thresholds as ground truth, not the calendar. Each week's deliverable promotes to `state: canon` independently.

---

## §8 — What this brief explicitly does NOT do

- Does NOT add doctrine sections — proposes them; no merges until sign-off.
- Does NOT add code — every implementation slice in §7 lands as its own commit AFTER sign-off + after the per-deliverable acceptance threshold.
- Does NOT consume the existing `state: candidate` queue (A1 redb, Static/Dynamic discriminator, B1-B3 phase work) — HELIOS v5 integration is a NEW candidate brief that joins the queue.
- Does NOT touch the current branch's clippy debt (~126 issues) or the still-required CD-008 manual runtime smoke — those remain in the Codex Full Handoff queue.
- Does NOT promote the v5 vocabulary (Lane 1/2/3/4/5) over the existing doctrine vocabulary (Core/Pro/Research) without explicit sign-off (sign-off question #1).
- Does NOT pre-author Lean 4 statements — that's W3+ work after sign-off.

---

## §9 — Bottom line

HELIOS v5 is well-organized and the v5 canon is genuinely smaller than it appears — most of the substrate (SCOPE-Rex Core, the 4-of-5 Monday Move primitives, the Cognitive DAG, the 3-tier distribution model) is **already in main**. The integration delta is:

- **Small:** AnswerPacket + GBNF + DOMINO (~250 LOC).
- **Medium:** SCOPE-Rex Pro tier (δ + ρ); 7-theorem corpus + eval set; T1-T3 + T9' invariants tagged onto existing substrate.
- **Large:** T4-T7 + T8 + T11-T17 invariants (new substrate); Lean 4 repo; 20+ Metal kernels in MTLBinaryArchive; Lane 4 physical experiments.

The 12-week v5 roadmap is realistic only with the canon promotion protocol's sign-off gates honored at each stage. Without sign-off discipline, HELIOS v5 risks becoming a parallel research substrate that never integrates with the canon-hardened Cognitive DAG you just landed.

**Recommendation:** sign off on §5's 15 questions, then promote this brief to `state: canon`, then begin W0→W12 in disciplined slices with per-deliverable acceptance thresholds.

**This brief held for sign-off.** No code lands without explicit user/Codex authorization. Parallel Claude engineering review can pressure-test §6's 8 risks independently.

---

## Cross-references

- Source v5 canon: user-pasted message 2026-05-05 ("HELIOS V5 — The Final Canon")
- Source v4.2 canon: user-pasted message 2026-05-05 ("EPISTEMOS / HELIOS THEOREM CANON v4.2")
- HELIOS v4 preservation package: `/Users/jojo/Library/Mobile Documents/com~apple~CloudDocs/EPISTEMOS_HELIOS_v4_FINAL_PRESERVATION_PACKAGE/`
  - `README.md`, `EPISTEMOS_HELIOS_v4_MASTER_CANON.md`, `EPISTEMOS_HELIOS_v4_MASTER_CANON_COMPACT.md`, `PRESERVED_RESEARCH_LEDGER.md`, `RAW_PROMPTS_FULL.md`, `helios v4 updated.md`
- Existing SCOPE-Rex Core: `agent_core/src/resonance/{tau,pi,lambda,mod}.rs` + `Epistemos/Engine/ResonanceService.swift`
- Existing Cognitive DAG: `agent_core/src/cognitive_dag/{node,edge,storage,merkle,companions,macaroons,migration,dispatch,resonance}.rs`
- Existing Monday-Move primitives: `Epistemos/Models/MutationEnvelope.swift` + `agent_core/src/mutations/envelope.rs` + `agent_core/src/provenance/ledger.rs`
- Doctrine: `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` (especially §3 distribution profiles, §4.1 Resonance Gate, §A.6 four memory layers)
- Canon promotion protocol: `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md`
- Existing state:candidate queue: `docs/A1_REDB_PERSISTENT_BACKEND_SCOPING_2026_05_05.md`, `docs/STATIC_NOTE_VS_DYNAMIC_WEIGHT_DELIBERATION_2026_05_05.md`, `docs/B1_BIOMETRIC_TAMAGOTCHI_BRAINEXPORT_LIFT_TARGETS_2026_05_05.md`, `docs/B2_LIVE_FILES_AND_SUBSTRATE_LIFT_TARGETS_2026_05_05.md`, `docs/B3_OBSCURA_BROWSER_LIFT_TARGETS_2026_05_05.md`
- Codex Full Handoff: `docs/CODEX_FULL_HANDOFF_2026_05_05.md`
- Pre-merge blocker: `docs/APP_ISSUES_AUTO_FIX.md` ISSUE-2026-05-05-001 (~126 clippy issues across 5 crates)

---

*Held for sign-off. Five lanes, three tiers, seven-plus-three-plus-seven, one Monday — but only after the canon-hardening discipline you installed today says go.*
