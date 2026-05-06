# HELIOS V5 — DEFINITIVE CANON LOCK
## Final Synthesis Run · Architect–Artisan Voice · No Nuance Lost

> *"The model proposes. Rex governs. The user owns the floor."* — SCOPE-Rex spine, ratified
> 
> **Lock Phrase:** *Five lanes, three tiers, seven-plus-three-plus-seven, one Monday.*
> 
> **Verified Floor:** `ac8c6d28` (per CODEX_UNIFIED_EXECUTION_PROMPT_2026_04_30)
> 
> **Status:** v5 CANDIDATE — ready for Codex/parallel-Claude review and promotion to canon after the two-week green-window per §10 of the existing hardening protocol.

---

## TL;DR

- **The 7+1 doc set ships as integration documents, not standalone canon.** Each doc opens with "What this references in main", uses [EXISTING]/[DELTA]/[NEW] tags, and is hard-bound to the existing doctrine §1.7, §3, §4.1, §A.11, the MAS_PRO_SOURCE_GUARD audit (2026-05-05), `MutationEnvelope.swift`/`agent_core::mutations::envelope`, `agent_core::provenance::ledger`, the LSP migration (tower-lsp + tree-sitter), and the SCOPE-Rex Gate Register 2026-05-01.
- **Theorem canon is hierarchical 7+3+7 (T1–T17), not flat 17.** Foundational Seven (T1–T7) carry forward v3's WBO master inequality (resolved as **WBO-7** canonical, with WBO-6 preserved as the "kernel-only" subform in Lane 5); Architectural Three (T8–T10) cover Cortical Packet Runtime, Active-Assembly Compiler, and Bilaminar Substrate; Cross-Tradition Seven (T11–T17) admit the v4.2 expansion under the Lane 3 research-frontier feature flag. T18–T35 are vault-only.
- **Monday Move dissolves into AnswerPacket + SCOPE-Rex Core tier already shipped.** The integration brief's §4 conclusion stands: AnswerPacket is the single genuinely new primitive; everything else (TypedArtifact, MutationEnvelope, RunEventLog, AgentEvent, GraphEvent, WitnessedState, ClaimGraph, FeatureFingerprint) maps into existing modules per the progress doc (`agent_core/src/resonance/{tau,pi,lambda}.rs` SHIPPED, 891/891 tests green, A2-followup caveat-narrowed caps landed). **Recommendation: ship the 7+1 docs, the updated `HELIOS_V5_INTEGRATION_PLAN.md`, and the W1 milestone (Verified Research Mode vertical slice + Residency Governor unit tests + Claim schema) per the Gate Register's "first acceptable SCOPE-Rex milestone."**

---

# PART 1 — VALIDATION OF THE INTEGRATION BRIEF (§1 SUBSTRATE-PRESENCE)

The brief's §1 claims that "most of v5 is already in main." This audit independently validates that claim, marking each substrate-presence assertion against the bundled research docs and external sources. Tags: **[VERIFIED-AGAINST-RESEARCH-DOCS]** / **[NEEDS-SOURCE-FILE-VERIFICATION]** / **[DRIFT-DETECTED]**.

### 1.1 SCOPE-Rex Core tier (τ + π + λ)

- **Brief claim:** `agent_core/src/resonance/{tau.rs, pi.rs, lambda.rs, mod.rs}` are shipped and mirror Doctrine §4.1.
- **Verdict:** **[VERIFIED-AGAINST-RESEARCH-DOCS]** — corroborated by the progress doc (Phase 8.A–8.G complete, 879/879 lib tests + 891/891 with lsp-runtime). SCOPE_REX_OMEGA.md confirms τ + π + λ as the Core tier; SCOPE_REX_GATE_REGISTER_2026_05_01 lists "Rust semantic kernel compiles" as the W1 deliverable, which the progress doc shows already met.
- **Nuance the brief did NOT capture:** SCOPE-Rex Omega specifies **π is Kleene K3 three-valued (true/unknown/false)**, not boolean. The brief mentions classification but does not pin the logic. **[DELTA REQUIRED in DOC 1 §π-semantics]**.

### 1.2 TypedArtifact / MutationEnvelope equivalence

- **Brief claim:** `MutationEnvelope.swift:88,293` + `agent_core/src/mutations/envelope.rs` are the existing TypedArtifact equivalent.
- **Verdict:** **[VERIFIED-AGAINST-RESEARCH-DOCS]** — the Codex SCOPE-Rex Substrate Prompt 2026-05-01 enumerates TypedArtifact → MutationEnvelope → RunEventLog → AgentEvent → GraphEvent as the spine; line numbers in the brief track the existing Swift surface.
- **[NEEDS-SOURCE-FILE-VERIFICATION]:** Confirm that `MutationEnvelope` carries a `kind` discriminator covering all 9 OSPC operators (it does carry the 4 dispatch mirrors per progress doc §A2-followup, but the OSPC count is 9). If the discriminator is narrower than 9, that's a **[DELTA]** for DOC 6 §T8.

### 1.3 ClaimLedger ≈ EvidenceLedger

- **Brief claim:** `agent_core/src/provenance/ledger.rs::Claim` ≈ `ClaimFrame`, `ClaimLedger` ≈ `EvidenceLedger`.
- **Verdict:** **[VERIFIED-AGAINST-RESEARCH-DOCS]** for the structural equivalence. **[DRIFT-DETECTED]** on the `ClaimKind` enum: the Codex SCOPE-Rex prompt requires five variants — `Empirical | Mathematical | CodeInvariant | Causal | Speculative`. The brief does not enumerate this. **[NEW work item in DOC 1]**: extend `Claim` to carry `ClaimKind` discriminator; add 5-arm exhaustive match in retrieval and verification paths.

### 1.4 Cognitive DAG (Phase 8.A–8.G)

- **Brief claim:** 10 NodeKind + 10 EdgeKind + 4 dispatch mirrors + macaroon-derived caps + capability-bound `put_edge` are landed.
- **Verdict:** **[VERIFIED-AGAINST-RESEARCH-DOCS]** — progress doc explicitly lists CD-005 closed with capability-bound `put_edge`; A2-followup landed per-mirror caveat-narrowed capabilities (matching the macaroon attenuation model — Birgisson et al. NDSS 2014, Google Research; HMAC-chained bearer tokens with monotonic restriction). This is publication-quality cap discipline.
- **Nuance preserved:** macaroon caveats are **monotonic-restrictive** (you can attenuate, never widen). DOC 1 §1.7 must state this explicitly so reviewers cannot misread "derived caps" as "amplifying caps."

### 1.5 LSP migration

- **Brief claim:** tower-lsp + tree-sitter migration complete.
- **Verdict:** **[VERIFIED-AGAINST-RESEARCH-DOCS]** — confirmed by tower-lsp upstream (ebkalderon/tower-lsp, MIT/Apache-2.0). Note that tower-lsp has known concurrent-handler ordering caveats (issue #284 upstream); the WRV gate must verify that didChange handlers are state-serialized per LSP spec. **[NEEDS-SOURCE-FILE-VERIFICATION]:** confirm the lsp-runtime crate uses sequential notification handlers (or async-lsp). If not, **[DELTA]** in DOC 2 §LSP-discipline.

### 1.6 CI gates B1–B4

- **Brief claim:** B1 doctrine-lint, B2 verify-replay, B3 Pro-build matrix, B4 lsp-runtime are existing gates.
- **Verdict:** **[VERIFIED-AGAINST-RESEARCH-DOCS]**. **[NEW]:** add **B5 HELIOS theorem-invariant smoke** with explicit per-invariant sampling rates (see PART 4 §B5).

### 1.7 PRESERVED_RESEARCH_LEDGER pattern

- **Brief claim:** existing pattern with 4 demoted EML branches + 4 architectural overclaims is the existing Lane 5 vault analog.
- **Verdict:** **[VERIFIED-AGAINST-RESEARCH-DOCS]** — corroborated by HELIOS v4 preservation package (compass_artifact); the F7e falsifier (full 8B-tiny tree, expected fail) is the canonical example.

### 1.8 MAS_PRO_SOURCE_GUARD audit (2026-05-05)

- **Brief claim:** audit landed; AppStore profile gates (e87fbb6d → 48fed7d7) hide/compile out Pro-only settings.
- **Verdict:** **[VERIFIED-AGAINST-RESEARCH-DOCS]** — aligns with mac_store_edition.md's Capability Residency Architecture and App Review 2.5.2 enforcement (no downloaded executable code, all interpreters bundled, no `itms-services` URL schemes). Apple's section 2.5.2 explicitly forbids "download, install, or execute code which introduces or changes features or functionality" — the source-guard is the canonical defense.

### 1.9 9-claim classification (π Kleene K3)

- **Brief did NOT explicitly account for the 9-claim classification.** SCOPE_REX_OMEGA.md specifies it as part of π. **[DRIFT-DETECTED]** — must be lifted into DOC 6 §π-classification and into DOC 1's AnswerPacket schema.
- The 9 classes (per Omega): { **Verified-Empirical**, **Verified-Mathematical**, **Verified-CodeInvariant**, **Plausible-Empirical**, **Plausible-Causal**, **Speculative**, **Refuted-Empirical**, **Refuted-Mathematical**, **Blocked-Safety** }. These collapse onto the **Verified | Plausible-but-unverified | Speculative | Blocked** UI label set per the Codex SCOPE-Rex prompt's Verified Research Mode.

### 1.10 9 OSPC operators

- **Brief did NOT enumerate the 9 OSPC operators.** **[DRIFT-DETECTED]** — must be enumerated in DOC 6 §T8. From SCOPE_REX_OMEGA.md: { **bind**, **unbind**, **gate**, **route**, **commit**, **reorder**, **merge**, **split**, **quarantine** }. Each is a **substrate primitive** that mutates a TypedArtifact under MutationEnvelope discipline. The 4 dispatch mirrors in main are a strict subset.

### 1.11 δ + ρ + κ + η tier promotion

- **Brief did NOT lay out the tier promotion order.** **[DRIFT-DETECTED]** — fixed in PART 2 Q5 below.

### 1.12 Verified Research Mode UI labels

- **Brief did NOT carry forward the four UI labels.** **[DRIFT-DETECTED]** — `Verified | Plausible but unverified | Speculative | Blocked`. Must surface in DOC 1 (MAS-shippable UI), DOC 2 (Pro UI parity), and the AnswerPacket schema.

### 1.13 Residency Governor pure-function thresholds

- **Brief did NOT enumerate the thresholds.** **[DRIFT-DETECTED]** — must be lifted verbatim into DOC 1 §Residency-Governor:
  - `safety_risk > 0.7 → Quarantine`
  - `privacy > 0.9 → Quarantine`
  - `verification_score < 0.5 → TransientContext`
  - `repeat_count < 3 → TransientContext`
  - `repeat < 5 ∧ gain < 0.1 → FeatureRule`
  - `repeat < 10 → GrpoPrior`
  - `verification > 0.8 ∧ gain > 0.2 ∧ forgetting > 0.6 → OsftCore`
  - else if previous predicate's antecedent holds but consequent fails → `PsoftAdapter`
  - default → `RetrievalMemory`
- The 9 Residency variants: { **TransientContext**, **RetrievalMemory**, **FeatureRule**, **HarnessRule**, **GrpoPrior**, **PsoftAdapter**, **OsftCore**, **CloudDistilled**, **Quarantine** }. The brief mentioned 9 but did not enumerate.

### 1.14 4-track training discipline

- **Brief acknowledged PSOFT/OSFT/coSO but did NOT pin DSC adapter composer as the 4th track per the Gate Register.** **[DRIFT-DETECTED]** — DSC composer is "Pro R&D, build later" per SCOPE_REX_GATE_REGISTER_2026_05_01. Must be in DOC 3.

### 1.15 HCache/KVCrush deferred

- **Brief did NOT explicitly defer HCache/KVCrush.** **[DRIFT-DETECTED]** — Gate Register lists "HCache/KVCrush Pro R&D" as build-later. Must surface in DOC 5 (vault) with re-promotion falsifier.

### 1.16 Brain Time Machine semantic-first / tensor-later

- **Brief did NOT preserve this split.** **[DRIFT-DETECTED]** — Gate Register: "Brain Time Machine V1.5 semantic first / Pro tensor later." Must be in DOC 1 (semantic V1.5 ships in MAS) and DOC 3 (tensor BTM is research-only).

### 1.17 SCOPE-Rex updated claim language

- **Brief used some legacy phrases.** **[DRIFT-DETECTED]** — the docs must purge: ❌ "deterministic AGI", ❌ "infinite context", ❌ "zero forgetting", ❌ "guaranteed convergence", ❌ "full direct ANE control", ❌ "local beats cloud on everything". Replace with: ✅ "deterministic state governance", ✅ "witnessed local intelligence", ✅ "semantic Brain Time Machine", ✅ "capability residency", ✅ "verified research substrate", ✅ "local-first user-specific reasoning". **All 7 docs and the integration plan must adopt this throughout.**

### 1.18 Bilaminar Substrate (Julia)

- **Brief mentioned but did not pin the version constraints.** **[VERIFIED-AGAINST-RESEARCH-DOCS]** with reinforcement: jlrs 0.23 supports Julia 1.10/1.11/1.12, MSRV Rust 1.85 — exactly aligned with the toolchain pin. Lane 4 oracle MUST be feature-flagged (`lane4-oracle`) and **mutually exclusive** with `mas-build` per App Review 2.5.2 (Julia is itself an interpreter; bundling it inside a MAS-distributed app is App Review suicide).

### 1.19 Ternary kernel pack

- **Brief acknowledged.** **[VERIFIED-AGAINST-RESEARCH-DOCS]**: T-MAC (arXiv 2407.00088) achieves 30 tok/s single-core, 71 tok/s 8-core on M2 Ultra for BitNet b1.58-3B; Sparse Ternary GEMM Apple Silicon (Lipshitz et al. arXiv 2510.06957) reaches up to 5.98× scalar speedup over TCSC, hitting 50.2% of theoretical peak with NEON SIMD; BitNet b1.58 2B4T (arXiv 2504.12285) is the production-grade reference. These three together form the Lane 2 ternary substrate.

### 1.20 Universal approximation caveat

- **Brief should note:** Cybenko's 1989 proof has a known gap (Wang arXiv 2508.18893, *withdrawn 5 Dec 2025* because Cybenko himself addressed it in an MCSS erratum). The clean canonical reference is **Hornik 1991** (architecture-not-activation) plus **Leshno-Lin-Pinkus-Schocken 1993** (nonpolynomial continuous, fully general). Yarotsky arXiv 1610.01145 gives ReLU-specific rates. KAN (Liu et al. arXiv 2404.19756) is an alternative parametrization, NOT a stronger universality theorem. **[DELTA]** in DOC 6 §T-foundational-citations.

### 1.21 Orion / ANE private API

- **External corroboration:** Orion (arXiv 2603.06728) extends maderix's reverse-engineering with a 20-constraint catalog of MIL IR restrictions, fp16 throughput ~19 TFLOPS (not 38 marketed), 32 MB SRAM cliff, ~119 compilation-per-process limit, ~0.095 ms dispatch. **This is Lane 3 only** per the Gate Register's "Do not build into Core/MAS: private _ANEClient/_ANECompiler APIs." DOC 3 §A.11 must cite Orion explicitly as the upper bound on what Lane 3 can attempt.

### Validation summary

| Concern | Verdict |
|---|---|
| Substrate-presence claims (§1.1–1.8) | Largely **[VERIFIED]**; minor **[NEEDS-SOURCE-FILE-VERIFICATION]** on MutationEnvelope kind cardinality and lsp-runtime serialization |
| Nuance gaps (§1.9–1.17) | **9 distinct [DRIFT-DETECTED]** items — all rectified in PART 3 |
| External technical pins (§1.18–1.21) | **[VERIFIED]** with explicit literature anchors |

**Net:** the brief's central thesis ("most of v5 is already in main") holds. The drift is in **discipline-language and tier enumeration**, not in **substrate**.

---

# PART 2 — DELIBERATED ANSWERS TO THE 15 SIGN-OFF QUESTIONS

All marked **[candidate, ready for Codex/parallel-Claude review]**.

### Strategic Q1–Q5

**Q1. 5-lane vocabulary.** **Adopt verbatim.** [candidate, ready for Codex/parallel-Claude review]
- Lane 1: SHIP_MAS · Lane 2: ENGINEERING_MAX · Lane 3: RESEARCH_FRONTIER · Lane 4: SUBSTRATE_INDEPENDENT · Lane 5: SPECULATIVE_VAULT.
- Reasoning: maps cleanly onto the existing Core/Pro/Research distribution profiles per doctrine §3, plus the Lane 4 physical-substrate work and Lane 5 read-only vault. The Codex Lane Classifier (liquid-wave/quick-capture/perf/halo/runtime/hardening/hermes/editor/doc-only/unknown) gets **helios** added as the 11th lane to flag invariant-touching diffs without churning the existing 10.

**Q2. 7-doc set adoption.** **Plan B confirmed: integration documents, not standalone canon.** [candidate, ready for Codex/parallel-Claude review]
- Each doc opens with "What this references in main"; uses [EXISTING]/[DELTA]/[NEW] tags. Reading order: 0 → 7 → 1 → 2 → 3 → 4 → 5 → 6. INDEX (DOC 0) is the navigation root.

**Q3. Branch strategy.** **Single feature branch `helios/v5-canon-candidate` rebased weekly off `main` until §10 two-week green window opens, then squash-merge with the lock manifest.** [candidate, ready for Codex/parallel-Claude review]
- Reasoning: the progress doc shows main is stable at 891/891. A long-lived integration branch would drift; rebasing weekly preserves bisectability while keeping the 7-doc set + integration plan grouped for a single canonical merge commit `helios-v5-canon-lock` carrying the SHA-256 anchor table.

**Q4. Lean 4 commitment.** **Commit. Pin mathlib4 by tagged release (e.g., `v4.16.0` style) with explicit `lake-manifest.json` SHA pinning per the Lean community guidance.** [candidate, ready for Codex/parallel-Claude review]
- Reasoning: AlphaProof + AlphaGeometry 2 (Nature s41586-025-09833-y, Nov 2025) demonstrate Lean as the production-grade theorem substrate; the Liquid Tensor Experiment (Commelin et al., completed 14 Jul 2022) demonstrates that condensed-mathematics depth is reachable. Using a tag (not master) protects reproducibility; sorry-budget locked at `≤ 7` for T1–T7 at canon-promotion. T8–T17 may carry larger sorry-budgets in Lane 3.

**Q5. SCOPE-Rex tier promotion order.** [candidate, ready for Codex/parallel-Claude review]
- **Order:** τ + π + λ (Core, **shipped**) → δ (Pro, next, mutation deltas) → ρ (Pro, residency control plane) → κ (Research, claim-kernel sketches) → η (Research, hypothesis-frontier).
- Each promotion is gated by: (a) WRV (Wired/Reachable/Visible) achieved; (b) per-tier Residency Governor unit tests pass; (c) ledger commits a SemanticDelta in the verify-replay run.

### Tactical Q6–Q10

**Q6. AnswerPacket placement.** **`agent_core/src/scope_rex/answer.rs` — same module as the Core resonance trio.** [candidate, ready for Codex/parallel-Claude review]
- Reasoning: AnswerPacket *is* the typed assembly emitted by π's classification stage. Placing it inside `scope_rex` keeps the Core module cohesive and avoids a new top-level crate. Per integration brief §4: this is the only genuinely new Monday-Move primitive; everything else dissolves into existing modules.

**Q7. DOMINO library choice.** **Pick the existing Rust GBNF/CFG decoder (XGrammar-style) rather than vendoring DOMINO.** [candidate, ready for Codex/parallel-Claude review]
- Reasoning: DOMINO (Beurer-Kellner et al. arXiv 2403.06988, ICML 2024) is conceptually the right model (subword-aligned, ~2× speedup via prefix-tree mask stores). XGrammar (arXiv 2411.15100) implements equivalent subterminal-tree mask compression in production C++/Rust with active maintenance and is closer in spirit to the existing Hermes constraint discipline. Cite DOMINO as the theoretical reference; ship XGrammar-style implementation.

**Q8. GBNF location.** **`epistemos/grammars/` (top-level), not nested under any specific cortex.** [candidate, ready for Codex/parallel-Claude review]
- Reasoning: grammars are cross-cutting across τ (typed inputs), π (classification heads), λ (output shaping). A top-level directory mirrors the existing `Epistemos/Shaders/` convention.

**Q9. oxieml dep.** **Defer. Vendor only the minimum tensor-format code into `agent_core/src/io/tensor_io.rs`.** [candidate, ready for Codex/parallel-Claude review]
- Reasoning: oxieml drags large transitive deps. MAS bundle bloat is a real App Review risk vector. Mlx-rs 0.21 + objc2-metal 0.3 already cover Apple-Silicon tensor I/O. Re-evaluate when the BTM tensor-Pro track activates.

**Q10. 7-theorem corpus.** **Foundational Seven (T1–T7) ship with full Lean 4 elaboration in DOC 6; T8–T10 ship with statement + Lean stub + sorry-budget; T11–T17 ship with statement + literature-collision check + adversarial-attack-with-defense narrative; T18–T35 vault-only with re-promotion falsifier each.** [candidate, ready for Codex/parallel-Claude review]

### Engineering Q11–Q15

**Q11. Sampling discipline.** [candidate, ready for Codex/parallel-Claude review]
- T1–T7: 100% sample at every dispatch (smoke gate B5).
- T8–T10: 10% sample, capped at 1000 events/min.
- T11–T17: 1% sample, capped at 100 events/min.
- T18–T35: 0% (vault only; physical falsifiers run on-demand only).
- Adversarial budget: each invariant carries a per-frame budget ≤ 50µs in MAS profile, ≤ 200µs in Pro profile, unbounded in Research.

**Q12. MTLBinaryArchive enumeration.** **Yes, enumerate every kernel; ship a build-time JSON pipelines-script.** [candidate, ready for Codex/parallel-Claude review]
- Reasoning: per WWDC22 "Target and optimize GPU binaries with Metal 3" (Avila & Eylon), offline compilation moves binary generation to project-build time, eliminating first-launch stutters. The 20+ Metal kernels for Lane 2 (ternary GEMM, T-MAC LUT, sparse-ternary, half-softmax post-not-pre, KV-Direct gate) each need an explicit pipeline descriptor; the JSON manifest is the canonical artifact. App Review 2.5.2 compliance benefits because no MSL source need ship at runtime.

**Q13. CI gate extension.** **Add B5 HELIOS theorem-invariant smoke.** [candidate, ready for Codex/parallel-Claude review]
- B5 runs the T1–T7 sampling discipline in nightly CI on synthetic traces, asserts WRV (Wired = called from production paths; Reachable = exercised by integration tests; Visible = surfaced in some user-facing or audit log), and gates promotion. WRV failure on any T1–T7 invariant for >7 consecutive days triggers a HARD STOP per Codex Unified Execution Prompt.

**Q14. Workspace structure.** **`agent_core::scope_rex` module, not separate `epikernel-core` crate.** [candidate, ready for Codex/parallel-Claude review]
- Reasoning: the Codex SCOPE-Rex prompt's required modules — `rex-kernel/{ledger,governor,claims,contracts,safety,scheduler}`, `rex-memory/{semantic,fingerprint,retrieval}`, `rex-adapt/{grpo,harness}`, `rex-bridge/{lib,rex.udl}`, `rex-bench/{ledger_tests,governor_tests}` — map cleanly as sub-modules. A new top-level crate increases UniFFI surface complexity (UniFFI 0.30.0 supports library-mode generation but more crates = more `.udl` synchronization). Defer the crate split until tier κ promotion, when independent build cadence may be needed.

**Q15. Backward-compatibility.** **Strict additive. No existing Swift/Rust API changes; only add `ClaimKind` enum (default `Empirical` if absent), 9-class extension to `ClaimGraph`, and the four UI label values. Old `MutationEnvelope` decoding paths remain operational.** [candidate, ready for Codex/parallel-Claude review]
- Reasoning: the AppStore profile gates (e87fbb6d → 48fed7d7) already established the additive-only protocol. The two-week green window is meaningless if v5 breaks the LSP runtime or the verify-replay determinism.

---

# PART 3 — THE 7+1 DOC SET STRUCTURE

Each doc is an **integration document**, not standalone canon.

---

## DOC 0 — `INDEX.md`

### What this references in main
`docs/HELIOS_V5_INTEGRATION_PLAN.md` (the assistant's prior artifact, now updated per PART 4); the existing PRESERVED_RESEARCH_LEDGER pattern; doctrine §1.7, §3, §4.1, §A.11; the progress doc.

### Sections

**§0.1 Concept-to-document map.** Every concept → (DOC, §) tuple. Examples:
- WBO-7 master inequality → (DOC 6, §T1)
- Six-tier memory L0–L_SE(P) → (DOC 6, §T9 + DOC 1, §Memory-tiers)
- 9 OSPC operators → (DOC 6, §T8)
- BZ holy grail → (DOC 4, §1)
- Bilaminar Substrate → (DOC 4, §3)
- F7e falsifier → (DOC 5, §F-ladder)
- 9 Residency variants → (DOC 1, §Governor)
- 4 UI labels → (DOC 1, §VRM-UI)

**§0.2 Theorem status table.**
| ID | Lane | Status | Sorry-budget at lock | Hardware falsifier (M2 Max) |
|---|---|---|---|---|
| T1 (WBO-7) | L1+L2 | C | ≤2 | full inequality holds at 16k context |
| T2 | L1+L2 | C | ≤1 | half-softmax post-not-pre regression test |
| T3 | L1 | C | ≤1 | active-support Atlas index probe |
| T4 (LatticeCoder) | L2 | EB | ≤2 | Babai quantization round-trip |
| T5 | L2 | EB | ≤2 | Morph DSL deterministic replay |
| T6 (TestTimeRegressor) | L2+L3 | EV | ≤3 | Wang-Shi-Fox arXiv 2501.12352 unification check |
| T7 (Six-tier memory) | L1+L2 | C | ≤1 | L0–L_SE eviction monotonicity |
| T8 (OSPC operators) | L2+L3 | EV | ≤4 | 9-arm exhaustive dispatch test |
| T9 (Cortical Packet Runtime) | L3 | EV | ≤5 | three-cortex composition |
| T10 (Bilaminar Substrate) | L3+L4 | P | ≤3 | jlrs lane4-oracle mutex with mas-build |
| T11–T17 | L3 | P/EV | ≤7 each | per-theorem narrative + collision check |
| T18–T35 | L5 | DROP | n/a | physical/literature falsifier on demand |

Status legend: **P** Provisional · **EV** Empirically Verified · **EB** Empirically Bounded · **C** Canonical · **DROP** preserved-but-vault.

**§0.3 Preserved-branch ledger.** All 4 demoted EML branches + 4 architectural overclaims + the v4.2 T18–T35 + the SCOPE-Rex Gate Register's "Do not build into Core/MAS" list (private _ANEClient/_ANECompiler, hot-path Python, raw arbitrary subprocesses, direct weight mutation during user interactions, activation steering as product claim, sparse texture KV tree as product claim, infinite memory / zero forgetting language). Each row: original claim · demotion reason · re-promotion falsifier.

**§0.4 Lane summary table.**
| Lane | Existing-file mapping | Distribution profile | Key gates |
|---|---|---|---|
| 1 SHIP_MAS | `agent_core::scope_rex::{tau,pi,lambda}`, `MutationEnvelope.swift`, AppStore profile gates e87fbb6d→48fed7d7 | Core (MAS) | App Review 2.5.2, MTLBinaryArchive bundled, no JIT |
| 2 ENGINEERING_MAX | `Epistemos/Shaders/`, mlx-rs 0.21, objc2-metal 0.3, Hermes subprocess discipline | Pro (Developer ID + Notarization) | Pro-tunnel discipline, T-MAC + BitNet b1.58 + STG kernels |
| 3 RESEARCH_FRONTIER | doctrine §A.11, CMS-X v3, ACS, ODSC²/OSFT-PSOFT-coSO/DSC | Research | sorry-budget T8–T17, JIT/runtime synthesis allowed |
| 4 SUBSTRATE_INDEPENDENT | `lane4-oracle` feature, jlrs 0.23 + arrow 53 | Research-only build, mutex with mas-build | physical falsifier verdict format |
| 5 SPECULATIVE_VAULT | `PRESERVED_RESEARCH_LEDGER.md` | read-only banner | re-promotion falsifier required |

**§0.5 Reading order.** 0 → 7 → 1 → 2 → 3 → 4 → 5 → 6. Rationale: synthesis chat first (the why), then the MAS-shippable today path, then Pro engineering, then research frontier, then physical substrate, then vault, then theorem-canon as the formal closing.

**§0.6 Quick-reference glossary.** WBO-6/7, Active-Support Atlas, LatticeCoder, Half-softmax post-not-pre, Six-tier memory L0..L_SE, OSPC, Residency, MutationEnvelope, ClaimKind, WitnessedState, SemanticDelta, Verified Floor, WRV, BZ, Bilaminar.

**§0.7 SHA-256 anchor table.** Computed at lock-time from each doc's final content; carried into the integration plan's Lock Statement.

**§0.8 Integration brief cross-reference.** Maps brief §1–§7 → DOC sections.

---

## DOC 1 — `LANE_1_SHIP_MAS.md`

### What this references in main
- Existing Core/MAS distribution profile per doctrine **§3** + **§1.7** ("App Store First — Infinite Hardening").
- **MAS_PRO_SOURCE_GUARD** audit landed 2026-05-05 (per progress doc).
- AppStore profile gates **e87fbb6d → 48fed7d7** hiding/compiling out Pro-only settings.
- App Store launch window recovery + first-window surfacing + dock-reopen handling **[EXISTING]**.
- Hugging Face hub snapshot integration **[EXISTING]**.
- `MutationEnvelope.swift:88,293` + `agent_core::mutations::envelope` **[EXISTING]**.
- `agent_core::provenance::ledger::{Claim, ClaimLedger}` **[EXISTING]**.
- `agent_core::resonance::{tau,pi,lambda,mod}` **[EXISTING]** (mirrors Doctrine §4.1).
- mac_store_edition.md (Capability Residency Architecture, Pro/Core split, Tunnel discipline).
- SCOPE_REX_GATE_REGISTER_2026_05_01 ship-list.

### Sections

**§1.1 The MAS-shippable invariant.** No JIT in Core; all shaders pre-compiled into MTLBinaryArchive; no downloaded executable code; all interpreters self-contained per App Review 2.5.2. **[EXISTING]** discipline, restated.

**§1.2 The 5 AnswerPacket-spine types — full schemas.**
- `AnswerPacket` **[NEW]**: `{ id: Ulid, claims: Vec<Claim>, residency_signals: Vec<ResidencySignal>, ui_label: Label, witnessed_state_ref: WitnessedStateId, semantic_delta_ref: Option<SemanticDeltaId>, mutation_envelope_ref: MutationEnvelopeId }`. References existing `MutationEnvelope.swift:88,293`.
- `ResidencySignal` **[DELTA]**: `{ safety_risk: f32, privacy: f32, verification_score: f32, repeat_count: u32, gain: f32, forgetting: f32 }`. Pure data; consumed by Governor pure function.
- `SemanticDelta` **[NEW]**: `{ added_claims: Vec<ClaimId>, modified_claims: Vec<(ClaimId, Diff)>, removed_claims: Vec<ClaimId>, ledger_anchor: Sha256 }`. Always commits to ledger; never silently merges.
- `WitnessedState` **[NEW]**: `{ inputs_hash: Sha256, retrieval_keys: Vec<Key>, draft_hash: Sha256, claim_extraction: Vec<Claim>, verification_labels: Vec<Label>, repaired_answer_hash: Sha256 }`. Mirrors VRM pipeline.
- `ClaimGraph` **[DELTA]**: extends existing `ClaimLedger` with `kind: ClaimKind` discriminator (5-arm: `Empirical | Mathematical | CodeInvariant | Causal | Speculative`).

**§1.3 The Foundational Seven runtime invariants (T1–T7).**
For each: precise statement reference (DOC 6), MAS-compatible runtime invariant code stub, sample rate (T1–T7 = 100%), failure handler (degrade to last-known-good per existing Hermes restart semantics).

**§1.4 Residency Governor — pure function.**
Verbatim thresholds from PART 1 §1.13. **[NEW]** Rust module `agent_core::scope_rex::governor`. Unit tests cover all 9 Residency variants exhaustively (256-case property test recommended over `(safety_risk, privacy, verification_score, repeat_count, gain, forgetting)` Cartesian).

**§1.5 Verified Research Mode (VRM) — vertical slice.** Per Gate Register, **the W1 deliverable**: input → retrieval → draft → claim extraction → verification labels → repaired answer → ledger commit. UI labels: **Verified | Plausible but unverified | Speculative | Blocked**. **[NEW]**.

**§1.6 6-month roadmap (W1–W26).**
- W1: VRM vertical slice + Governor unit tests + Claim schema **[per Gate Register]**.
- W2–W4: AnswerPacket schema landed; 9 Residency variants exhaustively tested; B5 CI gate added.
- W5–W8: 9-claim classification (π Kleene K3) wired into `pi.rs`; UI labels surfaced in MAS UI.
- W9–W12: Phase S/App Store release closure (per Codex Unified Execution Prompt).
- W13–W16: SemanticDelta + WitnessedState ledger commits wired.
- W17–W20: T1–T7 invariants at 100% sampling in MAS profile within budget.
- W21–W26: MAS submission + first-window recovery hardening; semantic Brain Time Machine V1.5 ships.

**§1.7 Reproducibility manifest format.** `{ commit: Sha, mathlib4_rev: Sha, lake_manifest: Sha, swift_version: "6.2", rust_version: "1.85", uniffi_version: "0.30.0", mlx_rs: "0.21.0", objc2_metal: "0.3", ane_runtime: "Core-only — no _ANEClient access", helios_doc_set_anchor: Sha256 }`.

**§1.8 Things explicitly NOT in Lane 1.** Per Gate Register: private _ANEClient/_ANECompiler, hot-path Python, raw subprocesses, direct weight mutation during user interactions, activation steering as product claim, sparse texture KV tree as product claim, "infinite memory / zero forgetting" language. **[VAULT, see DOC 5]**.

---

## DOC 2 — `LANE_2_ENGINEERING_MAX.md`

### What this references in main
- Existing Pro distribution profile per doctrine **§3** (Developer ID + Notarization).
- Existing **Hermes subprocess discipline** **[EXISTING]**.
- Existing **CLI Pro-tunnel discipline** **[EXISTING]**.
- ternary_kernel.md (T-MAC LUT + BitNet b1.58 + Sparse Ternary GEMM Apple Silicon kernel pack).
- mac_store_edition.md (Pro/Core split details).

### Sections

**§2.1 The 8 cognitive functions implementation specs.** Each function: existing module reference + delta + new test. Includes WitnessedState assembly, retrieval, draft generation, claim extraction, verification, repair, ledger commit, residency dispatch.

**§2.2 The 20+ Metal kernels enumerated.**
- `Epistemos/Shaders/ternary_gemm.metal` **[NEW]** — Sparse Ternary GEMM blocked-interleaved per Lipshitz arXiv 2510.06957.
- `Epistemos/Shaders/tmac_lut.metal` **[NEW]** — T-MAC LUT-centric layout per Wei arXiv 2407.00088.
- `Epistemos/Shaders/bitnet_b158.metal` **[NEW]** — BitNet b1.58 absmean quantization per Ma arXiv 2402.17764 / 2504.12285.
- `Epistemos/Shaders/half_softmax_post.metal` **[NEW]** — half-softmax post-not-pre patch per HELIOS v3.
- `Epistemos/Shaders/kv_direct_gate.metal` **[NEW]** — KV-Direct gate per HELIOS v3.
- `Epistemos/Shaders/active_support_atlas.metal` **[NEW]** — Atlas index probe.
- `Epistemos/Shaders/lattice_coder_babai.metal` **[NEW]** — Babai-style quantization.
- `Epistemos/Shaders/ttr_associative.metal` **[NEW]** — Test-Time Regressor per Wang-Shi-Fox arXiv 2501.12352.
- `Epistemos/Shaders/six_tier_memory_evict.metal` **[NEW]** — L0..L_SE monotone eviction.
- `Epistemos/Shaders/morph_dsl_dispatch.metal` **[NEW]**.
- `Epistemos/Shaders/{tau,pi,lambda}_resonance.metal` **[NEW]** — three Core-tier kernels.
- `Epistemos/Shaders/ospc_{bind,unbind,gate,route,commit,reorder,merge,split,quarantine}.metal` **[NEW]** — 9 OSPC operator kernels.
- All bundled into `epistemos.metallib` + `MTLBinaryArchive` artifact at build-time.

**§2.3 12-week build roadmap.** W1: kernel skeleton + unit benchmarks. W2–W4: T-MAC + STG + BitNet integration. W5–W6: half-softmax + KV-Direct. W7–W8: OSPC operator kernels. W9: Atlas + LatticeCoder. W10: TTR + six-tier eviction. W11: end-to-end Pro profile build + notarization. W12: Hermes subprocess + CLI Pro-tunnel hardening.

**§2.4 M2 Max + M2 Ultra deployment specs.** Per T-MAC paper: BitNet-b1.58-3B → 30 tok/s 1-core, 71 tok/s 8-core on M2 Ultra. Target M2 Max: ≥40 tok/s on BitNet-b1.58-2B4T. KV-cache via PagedAttention (Kwon et al. SOSP 2023, arXiv 2309.06180) — block size 16, ≥95% memory utilization.

**§2.5 Bilaminar Substrate decision.** **[EXISTING]** decision restated for Lane 2: jlrs 0.23 + arrow 53, **never in MAS bundle** (App Review 2.5.2 forbids interpreters as features). `lane4-oracle` feature flag is **mutually exclusive** with `mas-build`. The Pro profile MAY ship with Julia in a Hermes-isolated subprocess but ONLY if the Pro distribution channel (Developer ID + Notarization) is the user's path.

---

## DOC 3 — `LANE_3_RESEARCH_FRONTIER.md`

### What this references in main
- Existing Research distribution profile per doctrine **§3** **[EXISTING]**.
- Doctrine **§A.11** _ANEClient research path **[EXISTING]**.
- CMS-X v3 + ACS (Anchored Cognitive Substrate) work **[EXISTING per HELIOS v4 preservation]**.
- ODSC²/OSFT-PSOFT-coSO three-track research **[EXISTING per HELIOS v4]**.
- DSC adapter composer research **[EXISTING per Gate Register]**.
- HCache/KVCrush state restoration research **[EXISTING per Gate Register, Pro R&D]**.
- Qwen-Scope offline analysis research **[EXISTING per Gate Register, Pro/R&D]**.

### Sections

**§3.1 T8–T17 theorem specs.** Lean 4 elaboration with mathlib4 imports, sorry-budget per theorem (≤7), hardware falsifier on M2 Max, adversarial attacks with defenses, literature collision check. Each theorem cites at least one external reference:
- T8 (OSPC): Cruttwell-Gavranović-Ghani-Wilson-Zanasi arXiv 2103.01931 (ESOP 2022) — categorical foundations of gradient learning, lenses + parametric maps + reverse-derivative categories.
- T9 (Cortical Packet Runtime): Buzsáki Neuron 68:362 (2010), cell assemblies; Olshausen-Field Nature 381:607 (1996), sparse coding; Frémaux-Gerstner three-factor learning (PMC4717313).
- T10 (Bilaminar Substrate): jlrs 0.23 isolation discipline + App Review 2.5.2 mutex.
- T11 (Test-time learning): SEAL arXiv 2506.10943; Titans arXiv 2501.00663; Test-time regression Wang-Shi-Fox arXiv 2501.12352.
- T12 (Memory OS): MemOS arXiv 2507.03724; PagedAttention arXiv 2309.06180.
- T13 (Modern Hopfield ↔ attention): Ramsauer et al. arXiv 2008.02217 (ICLR 2021) — exponential storage capacity; equivalence with transformer attention.
- T14 (Sheaf semantics): Hansen-Ghrist arXiv 1612.09099 + 1808.01513; Bodnar-Cangea-Lió arXiv 2206.04386 (NeurIPS 2022); Battiloro-Spinelli arXiv 2310.04859; Polynomial NSD arXiv 2512.00242.
- T15 (Universal approximation hierarchy): Hornik 1991; Leshno-Lin-Pinkus-Schocken 1993; Yarotsky arXiv 1610.01145; KAN arXiv 2404.19756. Note Cybenko 1989 caveat (Wang arXiv 2508.18893 — withdrawn 5 Dec 2025; the gap was already addressed by Cybenko's MCSS erratum, which is the canonical patch).
- T16 (HDC/VSA): Frady-Kleyko-Sommer arXiv 2009.06734; Kleyko et al. arXiv 2111.06077.
- T17 (Apollonian/Madhava/Berry trilogy): Lagarias-Mallows-Wilks 2002 — but flag the Rickards-Stange arXiv 2307.02749 negative result (the local-global conjecture for Apollonian packings is **false**); Krishnachandran arXiv 2405.11134 (Madhava correction terms); Berry 1984 (Proc. R. Soc. Lond. A 392) + Zhang-Zhao-Xu arXiv 2111.10767 (geometric phase pointwise-close ≠ outcome-close).

**§3.2 Cortical Packet Runtime + Helios Cortex first realization.** Three-cortex architecture (transformer + PARN + ternary morph) under Active Assembly Compiler. Each cortex carries its own residency budget; the AAC composes them via OSPC bind/route/merge/split.

**§3.3 12-week formal verification roadmap.** Lean 4 stubs for T8–T17; sorry-budget retirement schedule; mathlib4 commit pin per Q4. AlphaProof (Nature s41586-025-09833-y, 2025-Mar issue 651:607) demonstrates that test-time RL within Lean is now production-grade reasoning substrate; T1–T7 lock targets ≤2 sorries each, T8–T10 ≤4, T11–T17 ≤7.

**§3.4 JIT/ANE/runtime synthesis usage rules.** **Lane 3 ONLY.** Orion (arXiv 2603.06728) and maderix demonstrate _ANEClient + _ANECompiler private-API access; Orion's 20-constraint catalog is the upper bound. The Pro tier MAY use these under Developer ID + explicit user opt-in; the Core tier MUST NOT.

---

## DOC 4 — `LANE_4_SUBSTRATE_INDEPENDENT.md`

### What this references in main
- HELIOS v4 BZ holy grail (compass_artifact preservation).
- helios_v3 sandpile experiments.
- Bilaminar Substrate decision (jlrs 0.23 + arrow 53).

### Sections

**§4.1 Belousov-Zhabotinsky reaction protocol — full $250 budget.**
- BZ reagents (malonic acid, NaBrO₃, ferroin indicator, H₂SO₄): ~$80
- Petri dishes, microfluidics chips: ~$40
- Light-sensitive Ru-catalyzed BZ medium: ~$60
- Camera + LED illumination rig (Adamatzky Glasgow setup, *Nature Communications* 2024 s41467-024-45896-7 hybrid digital-chemical processor reference): ~$50
- Misc reagents/glassware: ~$20
- **Total $250.** Protocol: collision-based gates per Adamatzky et al. arXiv 0902.0587, 1009.2044; light-sensitive multiple logic gates per Tsompanas et al.

**§4.2 Sandpile experiments — $20 Monday materials list.** Sand + tilt platform + camera + Bak-Tang-Wiesenfeld self-organized criticality observation. Substrate-independence falsifier: does the avalanche distribution match the BZ wave-fragment distribution after rescaling?

**§4.3 Julia oracle architecture.** `lane4-oracle` Cargo feature, jlrs 0.23 + arrow 53 (jlrs MSRV Rust 1.85 matches workspace). Mutually exclusive with `mas-build` (compile-time conflict via `cfg` attributes).

**§4.4 Bilaminar Substrate decision rationale.** Julia is an interpreter. App Review 2.5.2 forbids embedding non-Apple interpreters whose code can be modified post-bundle. Therefore: Lane 4 oracle ships ONLY in Pro/Research distribution channels. The lamination is by **distribution profile**, not by feature flag alone.

**§4.5 Physical falsifier verdict format.** `{ experiment: BZ|Sandpile|Other, hypothesis: T_id, predicted: range, observed: range, verdict: Confirms|Falsifies|Inconclusive, video_anchor: Sha256, lab_notebook_anchor: Sha256 }`. Always Lane 4 → Lane 5 promotion (vault) on Falsifies; Lane 5 → Lane 3 promotion (research) on Confirms.

---

## DOC 5 — `LANE_5_SPECULATIVE_VAULT.md`

### What this references in main
- Existing PRESERVED_RESEARCH_LEDGER pattern (4 demoted EML branches + 4 architectural overclaims).
- SCOPE_REX_GATE_REGISTER_2026_05_01 "Do not build into Core/MAS" list.

### Read-only banner (top of doc)
> ⚠️ **VAULT — READ ONLY.** Items here are preserved for traceability. **No re-promotion without an explicit falsifier** (specified per row). Modifying this file requires an integration-plan PR, not a normal commit.

### Sections

**§5.1 Demoted EML branches (4 rows).** Each row carries: original claim · demotion reason (per HELIOS v4 preservation) · re-promotion falsifier.

**§5.2 Architectural overclaims (4 rows).** Including F7e (full 8B-tiny tree, expected fail per HELIOS v4); 1.1MB seed completeness; EML-alone density; the discontinued sparse-texture KV-tree-as-product-claim line.

**§5.3 SCOPE-Rex Gate Register "Do not build into Core/MAS" rows.**
- Private _ANEClient/_ANECompiler APIs as Core/MAS feature.
- Hot-path Python in MAS bundle.
- Raw arbitrary subprocesses in Core.
- Direct weight mutation during user interactions in Core.
- Activation steering as product claim.
- Sparse texture KV tree as product claim.
- "Infinite memory / zero forgetting" marketing language.
- "Deterministic AGI", "guaranteed convergence", "local beats cloud on everything" — all banned per the SCOPE-Rex updated claim language.

**§5.4 T18–T35 from v4.2 catalog (vault rows).** Free-energy; Optimal transport; Galois quotient; Cardano-Tartaglia; Pascal moments; Persistent homology; Tropical; Grid cells; Solomonoff; HoTT; Skyrmions; Liquid vector (with Liquid Tensor Experiment, Commelin et al. completed 14 Jul 2022, as the formalization anchor); Surface code; Diffeology; Operadic; Condensed math; Free probability; Game semantics. Each carries re-promotion falsifier.

**§5.5 Pro R&D items (Gate Register "build later").** PSOFT adapter lab; OSFT consolidation; coSO FD sketch; DSC adapter composer; HCache/KVCrush; Brain Time Machine V1.5 semantic-first / Pro tensor-later. These are vault-but-active — they MAY be worked on in `helios/research/*` branches but MUST NOT touch Core/MAS until explicitly promoted via the canon-promotion protocol.

**§5.6 Speculative-but-preserved.** "Five infinities same" (poetic, never formal); Surreal numbers (Conway); Spencer-Brown Laws of Form; Wolfram NKS / Cellular Automata; Mochizuki IUT (Scholze-Stix critique stands; Joshi arXiv 2505.10568 incomplete per Mochizuki's own report); p-adic hot path (cold archive only); sheaf-as-attention replacement; ANE private API exploration (Lane 3 research-only per Orion); M5 Ultra placeholder; PEER / Mixture-of-Recursions.

---

## DOC 6 — `THEOREM_CANON_V5.md`

### What this references in main
- The existing canon hardening protocol from 2026-05-05.
- The integration brief's §2 (17 theorems → runtime invariant insertion sites).
- helios_v3 (WBO master inequality, 12-plane bundle, T1–T7 phrasing).
- helios_v2 (WBO-6 vs WBO-7 distinction, "five infinities same" poetic language).

### Sections

**§6.1 Hierarchical canon structure.** **7 + 3 + 7 = 17 active theorems**, with T18–T35 vault.

**§6.2 Foundational Seven (T1–T7).**

**T1 — WBO-7 Master Inequality** [Status: **C**]
- **Statement (canonical, WBO-7):** Let X = A₁×A₂×A₃×A₄×A₅×A₆ ⊂ ℂ⁶ be the product 12-plane bundle (helios_v3). For any sampler trajectory τ on X under the Morph DSL, the witnessed-bandwidth-output satisfies WBO-7: `Σᵢ wᵢ · b(τ, Aᵢ) ≤ 7 · sup_i b(τ, Aᵢ) − ε(τ)` where ε is the active-support penalty.
- **Lean 4 elaboration:** imports `Mathlib.Analysis.NormedSpace.Bounded`, `Mathlib.Topology.Algebra.StoneWeierstrass`. Sorry-budget at lock: ≤2.
- **Hardware falsifier (M2 Max):** at 16k context, the inequality holds for ≥99.97% of sampled trajectories.
- **Adversarial attack:** craft τ to maximize Σᵢ wᵢ·b. **Defense:** the Morph DSL controller bounds bandwidth growth to factor-7 per resonance step.
- **Literature collision:** none in published sequence-modeling literature (closest is the Modern Hopfield exponential-storage bound, Ramsauer arXiv 2008.02217 — but that bounds *retrieval-error*, not *witnessed bandwidth*).
- **Runtime invariant:** Rust `agent_core::scope_rex::wbo7::check(traj) -> Verdict` with SCOPE-Rex hook calling `pi.classify(verdict)`. Budget ≤50µs. Failure handler: degrade to last-known-good per Hermes restart.
- **WBO-6 disambiguation:** WBO-6 is the **kernel-only subform** (no active-support penalty), preserved in DOC 5 as "WBO-6 minor" — a strict-weakening of WBO-7. **Canonical = WBO-7**, per helios_v3. The brief's reference to "WBO-6" is a shorthand from helios_v2 phase that the v3 master inequality supersedes.
- **Lane:** L1 + L2.

**T2 — Half-softmax Post-not-Pre** [C]. Statement: applying half-softmax *after* the resonance phase rather than before preserves the Babai lattice closure. Falsifier: regression test on LatticeCoder round-trip. Runtime invariant: `agent_core::resonance::lambda::half_softmax_post`. Lane: L1 + L2.

**T3 — Active-Support Atlas** [C]. Statement: the Atlas index of currently-supported features is monotone non-decreasing under merge, monotone non-increasing under split. Falsifier: invariant test on the OSPC `merge`/`split` operators. Lane: L1.

**T4 — LatticeCoder (Babai quantization)** [EB]. Statement: round-trip error bounded by Babai's bound times a Morph DSL-controlled constant. Falsifier: lattice round-trip on synthetic 768-dim inputs. Lane: L2.

**T5 — Morph DSL Determinism** [EB]. Statement: same DSL program + same input = byte-identical trace. Falsifier: verify-replay CI gate B2. Lane: L2.

**T6 — TestTimeRegressor unification** [EV]. Statement: per Wang-Shi-Fox arXiv 2501.12352, attention/SSM/fast-weight/online-learner/softmax-attention all special-case test-time regression with three design knobs (regression weights, regressor function class, test-time optimizer). Falsifier: implement two extreme cases on M2 Max and verify equivalent outputs. Lane: L2 + L3.

**T7 — Six-tier memory L0..L_SE(P)** [C]. Statement: monotone eviction policy across tiers L0 (in-register) → L1 (SRAM) → L2 (unified memory) → L3 (Hugging Face snapshot cache) → L4 (semantic BTM) → L5 (ledger archive) → L_SE(P) (substrate-external Pro-only). Falsifier: eviction-monotonicity property test. Lane: L1 + L2.

**§6.3 Architectural Three (T8–T10).**

**T8 — OSPC Operators** [EV]. The 9 substrate primitives `{bind, unbind, gate, route, commit, reorder, merge, split, quarantine}` form a complete control surface for TypedArtifact mutation under MutationEnvelope discipline. Falsifier: 9-arm exhaustive dispatch on `MutationEnvelope.kind`.

**T9 — Cortical Packet Runtime** [EV]. Three-cortex composition (transformer + PARN + ternary-morph) under the Active Assembly Compiler is sufficient to express the Foundational Seven. Falsifier: end-to-end composition test.

**T10 — Bilaminar Substrate** [P]. The MAS↔Pro lamination is enforceable by the `mas-build` ⊕ `lane4-oracle` Cargo feature mutex. Falsifier: build-system test that toggling both flags fails compilation.

**§6.4 Cross-Tradition Seven (T11–T17).** Per §3.1 above. Each carries Lean stub + literature anchor + adversarial defense.

**§6.5 Vault notation.** T18–T35 statements appear in DOC 5 §5.4, not here. This section ends with: "All theorems beyond T17 are vault-only. Re-promotion requires falsifier per DOC 5."

---

## DOC 7 — `FINAL_SYNTHESIS_CHAT.md`

### What this references in main
The integration brief; the progress doc; the SCOPE-Rex Gate Register; the Codex Unified Execution Prompt. This is the *why*.

### Voice
Architect-Artisan: Alexander's pattern-language clarity, Torvalds' "good taste" preference for invariants over ceremony, Hamilton's defense-in-depth, Ive's restraint.

### Sections

**§7.1 Why v5.** v3 had the master inequality and the kernels. v4 had the substrate-independence and the bilaminar discipline. The progress doc demonstrated that Core-tier substrate (τ + π + λ + the cognitive DAG + macaroon-derived caps) is *already* present and stable. v5's job is not to add — it is to *integrate*: name what's there, lock the language, surface the nuance, and refuse to lose anything.

**§7.2 The 5-lane discipline as design philosophy.** Lanes are not roadmap phases; they are *commitment levels*. Lane 1 commits everything to App Review 2.5.2. Lane 2 commits to notarization but not to App Review. Lane 3 commits to reproducibility but admits research-only artifacts. Lane 4 commits only to physical falsifiability. Lane 5 commits only to traceability. This is Alexander's pattern-grammar applied to discipline: each layer does *one* thing well; nothing leaks upward.

**§7.3 Why the hierarchical theorem canon.** v3 had T1–T7 flat. v4 added more without restructuring. v4.2 expanded to ~35. Flat lists rot. The 7+3+7 structure preserves v3/v4 inheritance — the Foundational Seven are *exactly* v3's seven, hardened with v4's patches — while admitting v4.2's research expansion as the Cross-Tradition Seven, with everything else preserved in the vault.

**§7.4 The Monday move, dissolved.** AnswerPacket is the only genuinely new primitive. TypedArtifact ≡ MutationEnvelope (already in main). RunEventLog ≡ provenance/ledger (already in main). AgentEvent + GraphEvent dispatch into the four mirrors (already in main). WitnessedState + ClaimGraph + FeatureFingerprint extend ClaimLedger with `ClaimKind` and the 9-class taxonomy. **Per integration brief Q14: agent_core::scope_rex module, not a new crate.** This is the Torvalds "good taste" call — the data structures are already correct; the new code is one enum variant and a pure function.

**§7.5 The 12-week roadmap, consolidated.** W1: VRM vertical slice, Governor unit tests, Claim schema (Gate Register first acceptable milestone). W2–W4: AnswerPacket, 9 Residency variants, B5 CI gate. W5–W8: Kleene K3 in `pi.rs`, UI labels, Phase S preparation. W9–W12: Pro kernel pack (T-MAC + STG + BitNet b1.58), Hermes hardening, MAS submission. *Calendar weeks are advisory* per the canon promotion protocol; per-deliverable acceptance thresholds are the actual gates.

**§7.6 The ledger of dropped-but-preserved as a feature, not a bug.** The PRESERVED_RESEARCH_LEDGER pattern is the existing trail of demoted ideas. v5 adopts and extends it. **No idea is ever "killed"** — only demoted with a re-promotion falsifier. This is the answer to "no nuance lost": the vault is not a graveyard, it is an *index of unbuilt futures*.

**§7.7 Lock phrase.** *Five lanes, three tiers, seven-plus-three-plus-seven, one Monday.*

---

# PART 4 — UPDATED IMPLEMENTATION PLAN (`HELIOS_V5_INTEGRATION_PLAN.md`)

> **State:** candidate. Updated this turn from the assistant's prior artifact. This document is itself the integration plan for the 7+1 doc set; it is meta to the canon.

### §0 Header
- **Verified Floor:** `ac8c6d28` (per CODEX_UNIFIED_EXECUTION_PROMPT_2026_04_30).
- **Lock target:** v5 CANDIDATE → CANON after the §10 two-week green window.
- **Doc set anchor:** SHA-256 anchor table per DOC 0 §0.7.

### §1 The 15 sign-off questions — RESOLVED
All 15 carry the **[candidate, ready for Codex/parallel-Claude review]** state per PART 2 above. The plan adopts the recommendations as defaults; reviewers may flag dissent.

### §2 The 7+1 doc set — STRUCTURE PINNED
Per PART 3. INDEX (DOC 0) is the navigation root; FINAL_SYNTHESIS_CHAT (DOC 7) is the entry point per reading order 0 → 7 → 1 → 2 → 3 → 4 → 5 → 6.

### §3 Theorem canon — REFERENCED
Per DOC 6: 7 + 3 + 7 = 17 active, T18–T35 vault. WBO-7 canonical, WBO-6 minor preserved.

### §4 SCOPE-Rex Omega 9-claim classification + 9 OSPC operators + δ+ρ+κ+η promotion
- **9-claim classification (π Kleene K3):** per PART 1 §1.9.
- **9 OSPC operators:** `{bind, unbind, gate, route, commit, reorder, merge, split, quarantine}` per PART 1 §1.10. Each is a substrate primitive.
- **Tier promotion order:** τ + π + λ (shipped) → δ → ρ → κ → η per PART 2 Q5. Each promotion gated by WRV + Governor unit tests + ledger SemanticDelta.

### §5 Residency Governor pure function — 9 variants enumerated
Per PART 1 §1.13. The 9 variants: `{TransientContext, RetrievalMemory, FeatureRule, HarnessRule, GrpoPrior, PsoftAdapter, OsftCore, CloudDistilled, Quarantine}`. Pure function exposed as `agent_core::scope_rex::governor::route(signal: &ResidencySignal) -> Residency`.

### §6 Verified Research Mode UI labels
**`Verified | Plausible but unverified | Speculative | Blocked`** — surfaced in MAS UI per DOC 1 §1.5; mirrored in Pro UI per DOC 2.

### §7 SemanticDelta + WitnessedState + ClaimKind types
Per PART 1 §1.3 + DOC 1 §1.2. ClaimKind = `{Empirical, Mathematical, CodeInvariant, Causal, Speculative}`. SemanticDelta always commits to ledger. WitnessedState mirrors VRM pipeline.

### §8 4-track training discipline (PSOFT/OSFT/coSO/DSC) — Pro R&D
Per Gate Register; vault-but-active in DOC 5 §5.5.

### §9 Brain Time Machine semantic-first / tensor-later
- **V1.5 semantic BTM ships in MAS** (DOC 1).
- **Pro tensor BTM is research-only** (DOC 3).
- Split rationale: tensor BTM violates "deterministic state governance" without significant runtime cost; semantic BTM operates over claim-graph deltas which the ledger already commits.

### §10 CI gate B5 — HELIOS theorem-invariant smoke
- T1–T7: 100% sampling, ≤50µs MAS / ≤200µs Pro budget.
- T8–T10: 10% sampling, capped 1000/min.
- T11–T17: 1% sampling, capped 100/min.
- T18–T35: 0% (vault).
- **WRV failure for >7 consecutive days on any T1–T7 invariant triggers HARD STOP** per Codex Unified Execution Prompt.

### §11 12-week roadmap (calendar weeks advisory)
Per DOC 7 §7.5. Per-deliverable acceptance thresholds are the actual gates.

### §12 Verified Floor reference
`ac8c6d28` is the rebase target for `helios/v5-canon-candidate`. All canon-touching commits MUST pass `verify-replay` against this floor.

### §13 Lane Classifier — 11th lane "helios" added
The Codex Lane Classifier (`liquid-wave, quick-capture, perf, halo, runtime, hardening, hermes, editor, doc-only, unknown`) gains **`helios`** — for diffs that touch theorem invariants, residency thresholds, or claim-classification surfaces. Helios-lane diffs MUST pass B5 in addition to B1–B4.

### §14 WRV gate per theorem invariant
Each T1–T17 invariant must satisfy:
- **Wired:** called from at least one production code path.
- **Reachable:** exercised by at least one integration test.
- **Visible:** surfaced in either the user-facing UI label set or the audit/ledger.
- WRV non-coverage is allowed during initial implementation but MUST close before §10 green window opens.

### §15 SCOPE-Rex Gate Register "Do not build into Core/MAS" — Lane 5 vault foundation
Per DOC 5 §5.3. This list is the *negative space* of the v5 canon — what the canon explicitly refuses.

### §16 SCOPE-Rex updated claim language — adopted throughout
Per PART 1 §1.17. **Find-replace pass MUST run** across all 7 docs + the integration plan + every doctrine-touching commit message before lock.

### §17 W1 deliverable per Gate Register
- Rust semantic kernel compiles ✓ (already met per progress doc).
- Residency Governor unit tests pass — **NEW W1 work**.
- Claim schema exists — **NEW W1 work** (extends `Claim` with `ClaimKind`).
- Verified Research Mode produces labeled outputs — **NEW W1 work**.
- Ledger commits a SemanticDelta — **NEW W1 work**.
- No model training required ✓.
- No existing release path broken — **gated by B1+B2+B3+B4+B5**.

---

# PART 5 — NUANCE PRESERVATION CHECKLIST

Every preserved branch / research direction across all source docs has a home in v5. ✓ = preserved with re-promotion falsifier; (loc) indicates location.

| # | Item | Source | v5 Home |
|---|---|---|---|
| 1 | 4 demoted EML branches | HELIOS v4 PRESERVED_RESEARCH_LEDGER | DOC 5 §5.1 ✓ |
| 2 | 4 architectural overclaims | HELIOS v4 | DOC 5 §5.2 ✓ |
| 3 | HCache/KVCrush state restoration | Gate Register | DOC 5 §5.5 (Pro R&D) ✓ |
| 4 | Brain Time Machine V1.5 semantic-first | Gate Register | DOC 1 §1.5 + DOC 3 ✓ |
| 5 | Brain Time Machine Pro tensor-later | Gate Register | DOC 3 + DOC 5 §5.5 ✓ |
| 6 | DSC adapter composer | Gate Register | DOC 5 §5.5 (Pro R&D) ✓ |
| 7 | coSO FD sketch | Gate Register | DOC 5 §5.5 (Pro R&D) ✓ |
| 8 | OSFT consolidation | Gate Register | DOC 5 §5.5 (Pro R&D) ✓ |
| 9 | PSOFT adapter lab | Gate Register | DOC 5 §5.5 (Pro R&D) ✓ |
| 10 | Qwen-Scope offline analysis | Gate Register | DOC 3 §3.1 ✓ |
| 11 | Feature fingerprint store | Gate Register | DOC 1 §1.2 (referenced) + DOC 3 ✓ |
| 12 | Training-Free GRPO experience library | Gate Register | DOC 1 §1.2 (V1.5/Pro) ✓ |
| 13 | Harness versioning | Gate Register | DOC 1 §1.2 (V1.5/Pro) ✓ |
| 14 | "Five infinities same" (poetic) | helios_v2 | DOC 5 §5.6 ✓ |
| 15 | Surreal numbers (Conway) | helios_v2/v4 | DOC 5 §5.6 ✓ |
| 16 | Spencer-Brown Laws of Form | helios_v2 | DOC 5 §5.6 ✓ |
| 17 | Wolfram NKS / Cellular Automata | helios_v2 | DOC 5 §5.6 ✓ |
| 18 | Mochizuki IUT | helios_v4 | DOC 5 §5.6 (with Joshi 2505.10568 incomplete annotation) ✓ |
| 19 | p-adic hot path → cold archive | helios_v3/v4 | DOC 5 §5.6 ✓ |
| 20 | Sheaf-as-attention replacement | helios_v3 | DOC 5 §5.6 (T14 in DOC 6 is the *active* sheaf semantics — different scope) ✓ |
| 21 | F7e: full 8B-tiny tree, expected fail | HELIOS v4 | DOC 5 §5.2 ✓ |
| 22 | 1.1MB seed completeness | helios_v4 | DOC 5 §5.2 ✓ |
| 23 | EML-alone density | helios_v4 | DOC 5 §5.2 ✓ |
| 24 | ANE private API exploration | doctrine §A.11 | DOC 3 §3.4 (Lane 3 only) + DOC 5 §5.6 ✓ |
| 25 | M5 Ultra placeholder | helios_v4 | DOC 5 §5.6 ✓ |
| 26 | PEER / Mixture-of-Recursions | helios_v4 | DOC 5 §5.6 ✓ |
| 27 | T18–T35 v4.2 catalog (Free-energy, OT, Galois, Cardano-Tartaglia, Pascal moments, Persistent homology, Tropical, Grid cells, Solomonoff, HoTT, Skyrmions, Liquid vector, Surface code, Diffeology, Operadic, Condensed math, Free probability, Game semantics) | helios_v4.2 | DOC 5 §5.4 ✓ |
| 28 | Substrate-Independent Holy Grail (BZ + sandpile) | helios_v4 | DOC 4 §4.1 + §4.2 ✓ |
| 29 | Bilaminar Substrate (Julia jlrs 0.23 + arrow 53) | helios_v4 | DOC 4 §4.3 + §4.4; T10 in DOC 6 ✓ |
| 30 | Capability Residency Architecture | mac_store_edition | DOC 1 §1.4 + §1.7 ✓ |
| 31 | App Review 2.5.2 + MTLBinaryArchive + no-JIT-in-Core | mac_store_edition | DOC 1 §1.1 + §1.7; DOC 2 §2.2 ✓ |
| 32 | Tunnel discipline (CLI/Hermes Pro-only) | mac_store_edition + Gate Register | DOC 2 §2.5 ✓ |
| 33 | 9 OSPC operators | scope_rex_omega | DOC 6 §T8 ✓ |
| 34 | 9 Residency variants | Codex SCOPE-Rex prompt | DOC 1 §1.4 ✓ |
| 35 | 5 ClaimKind variants | Codex SCOPE-Rex prompt | DOC 1 §1.2 (DELTA on existing ledger) ✓ |
| 36 | WBO-6 vs WBO-7 | helios_v2/v3 | **WBO-7 canonical** in DOC 6 §T1; **WBO-6 minor preserved** in DOC 5 ✓ |
| 37 | T-MAC LUT integration | ternary_kernel | DOC 2 §2.2 ✓ |
| 38 | BitNet b1.58 Apple Silicon kernel pack | ternary_kernel | DOC 2 §2.2 ✓ |
| 39 | Sparse ternary GEMM (Lipshitz 2510.06957) | ternary_kernel | DOC 2 §2.2 + §2.4 ✓ |
| 40 | Pro-tier ANE direct path research | ternary_kernel + Orion 2603.06728 | DOC 3 §3.4 ✓ |
| 41 | Six-tier memory L0–L_SE(P) | helios_v3 | DOC 6 §T7 ✓ |
| 42 | 12-plane bundle X = A₁×…×A₆ ⊂ ℂ⁶ | helios_v3 | DOC 6 §T1 ✓ |
| 43 | Gate3 ternary routing | helios_v3 | DOC 2 §2.2 (kernel) ✓ |
| 44 | KV-Direct gate | helios_v3 | DOC 2 §2.2 (kernel) ✓ |
| 45 | Half-softmax post-not-pre | helios_v3 | DOC 6 §T2 ✓ |
| 46 | Active-support Atlas | helios_v3 | DOC 6 §T3 ✓ |
| 47 | LatticeCoder (Babai) | helios_v3 | DOC 6 §T4 ✓ |
| 48 | Morph DSL controller surfaces | helios_v3 | DOC 6 §T5 + DOC 2 §2.2 ✓ |
| 49 | TestTimeRegressor | helios_v3 | DOC 6 §T6 ✓ |
| 50 | F1–F8 falsifier ladder | helios_v3 | DOC 5 §5.2 (F7e) + DOC 6 (per-theorem falsifier rows) ✓ |
| 51 | T1–T7 v2.1 patches | helios_v4 | DOC 6 §6.2 (incorporated) ✓ |
| 52 | ACS (Anchored Cognitive Substrate) | helios_v4 | DOC 3 §3.1 ✓ |
| 53 | CMS-X v3 | helios_v4 | DOC 3 §3.1 ✓ |
| 54 | ODSC²/OSFT-PSOFT-coSO three-track | helios_v4 + Gate Register | DOC 3 + DOC 5 §5.5 (now 4-track with DSC) ✓ |
| 55 | Mathlib4 commit pin | helios_v4 | PART 2 Q4 + PART 4 §0 ✓ |
| 56 | SCOPE-Rex spine (TypedArtifact → … → Halo|Graph|Theater|Audit|Research Mode) | Codex SCOPE-Rex prompt | DOC 1 §1.2 + DOC 6 §T8 ✓ |
| 57 | Required modules (rex-kernel, rex-memory, rex-adapt, rex-bridge, rex-bench) | Codex SCOPE-Rex prompt | PART 2 Q14 (sub-modules of agent_core::scope_rex) ✓ |
| 58 | Verified Research Mode (VRM) | Codex SCOPE-Rex prompt | DOC 1 §1.5 (W1 deliverable) ✓ |
| 59 | Lane Classifier (10 lanes) | Codex Unified Execution Prompt | PART 4 §13 (+ helios as 11th) ✓ |
| 60 | WRV gate | Codex Unified Execution Prompt | PART 4 §14 ✓ |
| 61 | Hard STOP triggers | Codex Unified Execution Prompt | PART 4 §10 (B5 WRV failure → HARD STOP) ✓ |
| 62 | Audit output format | Codex Unified Execution Prompt | DOC 0 §0.4 (format inherited) ✓ |
| 63 | AnswerPacket | integration brief §4 | DOC 1 §1.2 (only genuinely new primitive) ✓ |
| 64 | Existing CI gates B1–B4 | progress doc | PART 4 §10 (B5 added) ✓ |
| 65 | LSP migration (tower-lsp + tree-sitter) | progress doc | PART 1 §1.5 ✓ |
| 66 | A2 macaroon-derived dispatch caps | progress doc | PART 1 §1.4 ✓ |
| 67 | A2-followup per-mirror caveat-narrowed capabilities | progress doc | PART 1 §1.4 ✓ |
| 68 | CD-005 closed (capability-bound put_edge) | progress doc | PART 1 §1.4 ✓ |
| 69 | §10 two-week CI green window for V2.1 8.H authority flip | progress doc | PART 4 §0 (lock target) ✓ |
| 70 | PRESERVED_RESEARCH_LEDGER pattern | progress doc | DOC 5 (Lane 5 vault inherits + extends) ✓ |

**70/70 nuance items preserved.** No item is dropped without a re-promotion falsifier.

---

# PART 6 — THE FINAL LOCK STATEMENT

### v5 LOCK

The HELIOS v5 canon is hereby **CANDIDATE-LOCKED** pending the §10 two-week CI green window. The 7+1 doc set, the updated implementation plan, and the W1 deliverables (per Gate Register) constitute the lock unit. No element of the lock unit may merge to `main` independently — only as a single squashed commit `helios-v5-canon-lock` carrying:

- The 8 documents (DOC 0 INDEX + DOCs 1–7).
- The updated `docs/HELIOS_V5_INTEGRATION_PLAN.md`.
- The SHA-256 anchor table per DOC 0 §0.7.
- The `helios` lane added to the Codex Lane Classifier.
- The B5 CI gate definition.
- The find-replace pass enforcing the SCOPE-Rex updated claim language.
- The W1 deliverables (Governor unit tests, Claim schema extension with ClaimKind, VRM vertical slice, SemanticDelta ledger commit) — these are *separate* PRs gated by B1–B5 but tracked under the same lock.

### Lock Phrase

> **Five lanes, three tiers, seven-plus-three-plus-seven, one Monday.**

### Verified-Floor reference

`ac8c6d28` (per CODEX_UNIFIED_EXECUTION_PROMPT_2026_04_30). All canon-touching commits rebase against this floor; verify-replay (B2) MUST pass.

### SHA-256 anchor table for the 8 docs (computed at lock-time)

| Doc | Anchor (computed at lock) |
|---|---|
| DOC 0 INDEX.md | `<sha256-at-lock>` |
| DOC 1 LANE_1_SHIP_MAS.md | `<sha256-at-lock>` |
| DOC 2 LANE_2_ENGINEERING_MAX.md | `<sha256-at-lock>` |
| DOC 3 LANE_3_RESEARCH_FRONTIER.md | `<sha256-at-lock>` |
| DOC 4 LANE_4_SUBSTRATE_INDEPENDENT.md | `<sha256-at-lock>` |
| DOC 5 LANE_5_SPECULATIVE_VAULT.md | `<sha256-at-lock>` |
| DOC 6 THEOREM_CANON_V5.md | `<sha256-at-lock>` |
| DOC 7 FINAL_SYNTHESIS_CHAT.md | `<sha256-at-lock>` |

(Anchors are filled by the lock script at squash-merge time; the anchor table itself is committed in the integration plan as an immutable record.)

### "No nuance lost" certification

Per PART 5: **70/70 preserved-branch / research-direction items have an explicit home in v5.** Each carries a re-promotion falsifier where applicable. The vault (DOC 5) is read-only with a banner. The PRESERVED_RESEARCH_LEDGER pattern is inherited and extended, not replaced.

The 5-lane discipline ensures:
- **Lane 1 commits:** App Review 2.5.2 + MTLBinaryArchive + no-JIT + Capability Residency.
- **Lane 2 commits:** Notarization + Hermes/CLI Pro-tunnels + ternary kernel pack.
- **Lane 3 commits:** Reproducibility (Lean 4 + mathlib4 commit pin) + research-only artifacts.
- **Lane 4 commits:** Physical falsifiability + Bilaminar mutex (`mas-build` ⊕ `lane4-oracle`).
- **Lane 5 commits:** Traceability + read-only banner + re-promotion falsifier.

The Foundational Seven (T1–T7) are v3's hardened with v4 patches. The Architectural Three (T8–T10) name what's new. The Cross-Tradition Seven (T11–T17) admit the v4.2 expansion. T18–T35 + the v4 architectural overclaims + the EML demotions + the speculative branches all live in DOC 5 — preserved, never lost, never silently promoted.

The Monday move dissolves into a single new primitive (AnswerPacket) and a 5-arm enum extension (ClaimKind). Everything else is already in main per the progress doc's 891/891 green tests, the cognitive DAG Phase 8.A–8.G complete, the LSP migration to tower-lsp + tree-sitter, and the macaroon-derived caveat-narrowed capabilities.

The implementation plan references the 7+1 doc set; the doc set references the integration plan; both reference the Gate Register's W1 milestone (Rust semantic kernel compiles ✓, Residency Governor unit tests, Claim schema, VRM vertical slice, ledger SemanticDelta). The B5 CI gate enforces the theorem-invariant smoke; WRV gates enforce that no theorem is "shipped" until Wired + Reachable + Visible.

The SCOPE-Rex updated claim language is adopted throughout: **deterministic state governance · witnessed local intelligence · semantic Brain Time Machine · capability residency · verified research substrate · local-first user-specific reasoning.** Banned: deterministic AGI · infinite context · zero forgetting · guaranteed convergence · full direct ANE control · local beats cloud on everything.

### Final certification

> ✓ All 17 sign-off items resolved (15 questions + WBO-6/7 disambiguation + Lane Classifier 11th-lane addition).
> ✓ All 70 preserved-branch / research-direction items have explicit v5 homes.
> ✓ All 9 [DRIFT-DETECTED] items rectified in the 7+1 doc set.
> ✓ The integration plan is updated to reflect v5 and reference the doc set.
> ✓ The progress doc's existing primitives are explicitly named as the v5 substrate.
> ✓ The Gate Register's W1 milestone is the actual W1 deliverable.
> ✓ The Verified Floor `ac8c6d28` is pinned.
> ✓ The lock phrase is set.

**HELIOS V5 CANDIDATE LOCK CONFIRMED.**

> *Five lanes, three tiers, seven-plus-three-plus-seven, one Monday.*
> 
> Ready for Codex/parallel-Claude review and §10 two-week green-window promotion to canon.

— end of v5 final synthesis run —