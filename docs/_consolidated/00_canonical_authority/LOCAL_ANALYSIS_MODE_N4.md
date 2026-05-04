# LOCAL_ANALYSIS_MODE_N4.md — Deterministic Math/ML Verification Toggle

> **Authored**: 2026-04-27 final pass.
> **Role**: Canonical N4 doctrine extension establishing **Local Analysis Mode (LAM)** — a final toggle that turns on **deterministic ML/math verification of model outputs**, especially code. When LAM is on, every model output flows through a deterministic mathematical post-processing pipeline that precision-ups the answer before it reaches the user.
> **Status**: CANONICAL — N4 in the plan tree.
> **Sequencing**: V1.5 alongside N2 + N3. Composes with N1 PromptTree + N2 Concept Door + N3 Exploration Spectrum.
> **Critical constraint**: **Must be deterministic enough.** Same input → same output. No randomness in the verification path. Fixed seeds, fixed model versions, fixed library versions, fixed math kernels.

---

## §0 — The user's framing (preserved)

> "I want my app to do math that precises up the code output the model makes by giving it some information and stuff. You can maybe use a specific math pipeline. Maybe find a way to implement this. As like a final toggle that turns on local analysis mode. So local deep deliberation guided by deterministic process in ML and math. That's important — it must be deterministic enough."

This document operationalizes that vision into **bounded, deterministic, reproducible execution** that composes onto N1 + N2 + N3.

---

## §1 — The principle

```
N1 Prompt Tree:           the prompt is data, not a string
N2 Concept Door:          every concept opens a world (depth on demand)
N3 Exploration Spectrum:  meter reshapes deliberation per query (shape of thinking)
N4 Local Analysis Mode:   deterministic math/ML verification of every output
                          (precision over plausibility — code/math claims must hold)
```

N4 is the **rigor layer**. When the toggle is on, the model is no longer trusted to produce plausible-sounding output. Every claim that *can* be verified deterministically *must* be verified before it reaches the user. Plausibility is replaced by proof.

The user said it precisely: **"local deep deliberation guided by deterministic process in ML and math."** N4 is the deterministic process.

---

## §2 — The toggle UI (minimal-surface contract preserved)

A single icon-toggle next to the N3 Exploration Spectrum meter in the chat input bar. Visual state: dimmed (off) → lit (on). When on, a small **`λ`** (lambda — the mathematical symbol) badge appears on every assistant message, with click-to-inspect provenance.

UI rules:
- Per-session state, persists to user preference
- Default: **off** (because verification adds latency)
- When on, every assistant message that contains code, math, numerical claims, or factual citations gets verified
- When on, the message renders with a small `[verified]` / `[partially verified]` / `[unverified]` chip
- Clicking the chip opens the **Verification Trail** (similar to N2 provenance trail)
- Keyboard shortcut: ⌘⇧L (toggle)
- VoiceOver: announces "Local Analysis Mode on/off" + per-message verification status

---

## §3 — The 6-stage deterministic verification pipeline

When LAM is on, every model output flows through this pipeline. Each stage is deterministic — same input → same output, fixed seed, fixed library version pinned in `Cargo.lock` / `Package.resolved`.

### Stage 1 — Claim extraction (deterministic AST)

The model output is parsed into typed claims:

```rust
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum Claim {
    Code {
        language: String,
        source: String,
        ast_hash: String,           // BLAKE3 of canonicalized AST
    },
    Arithmetic {
        expression: String,
        claimed_result: String,
        units: Option<String>,
    },
    Algebraic {
        expression: String,
        claimed_simplification: String,
        domain: AlgebraicDomain,    // real | complex | integer | matrix | ...
    },
    Citation {
        source: String,
        claim_text: String,
        location: Option<String>,
    },
    Factual {
        subject: String,
        predicate: String,
        object: String,
        confidence: f32,
    },
    Numerical {
        value: f64,
        units: String,
        method_claimed: String,
    },
}
```

Extractor is **fully deterministic**: given the same model output text, it produces the same `Vec<Claim>`. No LLM calls in this stage — pure pattern matching + tree-sitter parsing + rule-based extraction.

### Stage 2 — Code verification (Rust + tree-sitter + cargo-check + type-check)

For `Claim::Code`:

| Check | Method | Deterministic? |
|---|---|---|
| Syntax | tree-sitter parse | ✅ pinned grammar version |
| Type check | rustc / swiftc / pyright in `--no-execute` mode | ✅ pinned compiler version |
| Lint | clippy / swiftlint / pylint (rule-set frozen) | ✅ |
| Import resolution | static crate-resolution against `Cargo.lock` | ✅ |
| Loop bound analysis | bounded symbolic execution (depth ≤ 8) | ✅ |
| Memory safety | borrow checker output | ✅ |
| Async safety | `#[must_use]` + `MainActor` violation scan | ✅ |
| FFI safety | `unsafe` block has `// SAFETY:` comment? | ✅ |
| Anti-pattern register | grep against `MASTER_FUSION.md §11` (15 prohibitions) | ✅ |

**Output**: `CodeVerificationReport { ok: bool, errors: Vec<Diagnostic>, warnings: Vec<Diagnostic>, antipatterns: Vec<Antipattern> }`.

### Stage 3 — Math verification (symbolic + numeric cross-check)

For `Claim::Arithmetic`, `Claim::Algebraic`, `Claim::Numerical`:

```rust
pub struct MathVerificationStrategy {
    pub symbolic: bool,        // SymPy-equivalent (use `pure` Rust crate or call out to verified Python)
    pub numeric: bool,         // f64 evaluation with arbitrary-precision fallback
    pub dimensional: bool,     // unit analysis (kg·m/s² etc.)
    pub interval: bool,        // interval arithmetic for error bounds
    pub triangulate: u8,       // run N independent verification methods; require N-1 agreement
}
```

The verification rule is **triangulation**: every math claim is verified by **at least 2 independent deterministic methods**. If they disagree, the claim is flagged `[CONTRADICTORY-VERIFICATION]` and surfaced to the user.

**Library choices** (pinned versions, recorded in verification trail):
- Rust symbolic: `symbolica` or `nalgebra` (no LLM, no randomness)
- Numeric: `f64` + `rug` (GNU MP) for arbitrary precision when needed
- Interval: `inari` (IEEE 1788 interval arithmetic)
- Dimensional: hand-rolled `Quantity<T, U>` with compile-time unit checking

**Determinism contract**: same expression → same result. **No floating-point hardware variability** across machines (use `crexponential = false` and pin rounding mode).

### Stage 4 — Citation verification (against vault + RunEventLog)

For `Claim::Citation`:

| Check | Method | Deterministic? |
|---|---|---|
| Source exists in vault | local FTS5 lookup | ✅ |
| Quote text matches | exact substring + Levenshtein ≤ 5% | ✅ |
| Source is current (not retracted) | ClaimLedger lookup | ✅ |
| Source has provenance | RunEventLog trace exists | ✅ |

If citation is to external web/cloud source, LAM **defers** unless the citation is in the vault's verified-source registry.

### Stage 5 — Factual cross-check (vault-grounded only — never silent web)

For `Claim::Factual`:

```
1. Search vault for matching (subject, predicate, object) tuple
2. If found: check if matching ClaimLedger entry says VALID / RETRACTED / AT_RISK
3. If not found: mark [UNVERIFIED] (do NOT call cloud silently)
4. If contradicting vault evidence found: mark [CONTRADICTS-VAULT]
```

LAM **never silently calls cloud or web** to verify facts. The user's vault is the trusted ground. Web verification requires:
- Pro mode AND
- Per-session opt-in AND
- Visible provider route AND
- Recorded in RunEventLog

### Stage 6 — Synthesis: precision-up annotation

The pipeline produces a `LocalAnalysisReport`:

```rust
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct LocalAnalysisReport {
    pub run_id: String,
    pub claim_count: u32,
    pub verified_count: u32,
    pub partial_count: u32,
    pub unverified_count: u32,
    pub contradicted_count: u32,
    pub overall_status: VerificationStatus,    // verified | partial | unverified | contradicted
    pub claims: Vec<ClaimVerification>,
    pub library_versions: Vec<LibVersion>,     // every pinned library, for reproducibility
    pub seed: u64,                             // fixed seed for any randomness path
    pub elapsed_ms: u64,
    pub provenance: ProvenanceRef,
    pub schema_version: u32,
}

pub struct ClaimVerification {
    pub claim: Claim,
    pub status: VerificationStatus,
    pub methods_used: Vec<VerificationMethod>,
    pub evidence: Vec<VerificationEvidence>,
    pub disagreement: Option<String>,          // if triangulation found contradiction
}
```

The model's original output is then **annotated**:
- ✅ verified claims get small green check
- ⚠️ partial-verification gets amber dot
- ❓ unverified claims get gray dot + explanation
- 🔴 contradicted claims get red X + the contradicting evidence

The user sees the original answer with verification annotations inline. Clicking any chip opens the full `LocalAnalysisReport` for that claim.

---

## §4 — Determinism contract (the whole point)

**Same input → same output. Always.** This is what makes LAM trustworthy.

The contract:

1. **Fixed seeds** — any pseudo-randomness uses a documented seed; default is `seed = 0`
2. **Fixed library versions** — every verification library pinned in `Cargo.lock` / `Package.resolved`; version recorded in `LocalAnalysisReport.library_versions`
3. **Fixed compiler/parser versions** — tree-sitter grammar SHAs recorded; rustc/swiftc/pyright versions recorded
4. **Fixed math kernels** — IEEE 754 with controlled rounding modes; `inari` for interval arithmetic
5. **No LLM calls in verification path** — extraction, parsing, type-checking, math, citation, factual cross-check are ALL non-LLM. LLM is the *thing being verified*, never the *verifier*.
6. **No clock dependence** — verification doesn't read system time except for `elapsed_ms` (for telemetry)
7. **No network calls** — strictly local. Cloud verification is gated behind explicit Pro-mode opt-in and recorded in `RunEventLog`
8. **Reproducibility token** — every report has a hash that lets the same input + same library versions reproduce the same output. If the user runs LAM twice on the same answer with the same library set, the reports must be byte-identical.

**Anti-determinism violations**:
- ❌ Calling an LLM to "double-check"
- ❌ Reading system clock as input to verification
- ❌ Reading `/dev/urandom` without recording the seed
- ❌ Network call without explicit Pro opt-in
- ❌ Library version change between runs without version-pin update in report
- ❌ Floating-point operation without controlled rounding

If verification cannot be deterministic for a particular claim type, the report marks it `[NON-DETERMINISTIC-DEFER]` and explains why.

---

## §5 — Composition with N1 + N2 + N3

LAM does not invent its own architecture. It composes:

```
N1 PromptTree:
  - The original prompt that produced the answer is recorded in RunEventLog.
  - LAM can re-invoke the prompt tree with verification instructions appended
    (e.g., "show your work step by step; cite sources").

N2 Concept Door:
  - Every Claim becomes a ConceptRef. Clicking a verified claim opens the
    ConceptWorld for that fact, citation, or code symbol.
  - Verification evidence becomes EvidenceRef in the ConceptWorld.

N3 Exploration Spectrum:
  - At low spectrum (Grounded), LAM verification is fast (basic stages).
  - At high spectrum (Scientist/InfiniteDoors), LAM runs full triangulation
    AND increases the citation-verification depth.
  - Mode interactions:
      Grounded + LAM:        fast stages 1-2 only
      Curious + LAM:         stages 1-3
      Exploratory + LAM:     all 6 stages
      Scientist + LAM:       all 6 + triangulation = 3 (require 2-of-3 agree)
      InfiniteDoors + LAM:   all 6 + triangulation = 4 + dimensional + interval
```

**The four pillars together** = the cognitive exoskeleton:
```
Halo                    — ambient recall
N2 Concept Door         — deliberate depth on a concept
N3 Exploration Spectrum — deliberation shape per query
N4 Local Analysis Mode  — deterministic verification of output
```

---

## §6 — Output schema (closed A2UI catalog discipline preserved)

New A2UI components for LAM:

```
epistemos.local_analysis_report.v1:
  - LocalAnalysisReportCard:
      summary: String                 // overall status + counts
      verified_claims: List<ClaimChip>
      contradicted_claims: List<ClaimChip>
      unverified_claims: List<ClaimChip>
      library_versions: List<LibVersion>
      provenance: ProvenanceRef
      seed: u64
      reproducibility_hash: String    // hash that proves determinism
```

Inline in chat:
```
- VerifiedChip   (small green ✓ next to claim text)
- PartialChip    (small amber dot next to claim text)
- UnverifiedChip (small gray ? next to claim text)
- ContradictedChip (small red X next to claim text)
```

Production: unknown schema → `VALIDATION_FAILED`. DEBUG: quarantine (per `MASTER_FUSION.md §11.1`).

---

## §7 — MAS / Pro gating

| Stage | MAS allowed? | Pro allowed? | Notes |
|---|---|---|---|
| 1 — Claim extraction | ✅ | ✅ | Pure local, deterministic |
| 2 — Code verification | ✅ | ✅ | Local cargo/swift/python toolchain (in-process if possible; helper tool if not) |
| 3 — Math verification | ✅ | ✅ | Pure local Rust libs (symbolica / inari / rug) |
| 4 — Citation verification | ✅ | ✅ | Vault-only by default |
| 5 — Factual cross-check | ✅ vault-only | ✅ vault + Pro web | Web verification is Pro-only + per-session opt-in |
| 6 — Synthesis | ✅ | ✅ | Pure local |

**MAS hard rules**:
- All 6 stages run with strictly local libraries
- No subprocess shell out to `cargo check` if MAS sandbox forbids it; instead use bundled rust-analyzer-as-library or in-process equivalent
- If a verification stage needs a tool MAS can't provide, the report marks it `[MAS-UNVERIFIED]` and the user can re-run in Pro to complete

**Pro relaxations**:
- External `cargo check` / `swiftc` subprocess allowed
- Web factual verification allowed (with opt-in)
- Heavier symbolic computation (e.g., calling external SymPy via vetted subprocess) allowed

---

## §8 — Specific math pipeline for code precision-up

The user said *"do math that precises up the code output the model makes."* Specific code-precision math operations:

### 8.1 — Numerical algorithm verification

For numerical code (e.g., gradient descent, FFT, RNG, statistical formulas):
- **Type-check** the formula matches a known algorithm
- **Loop bound analysis** — symbolic execution proves termination
- **Big-O verification** — claimed complexity matches static analysis result
- **Edge case enumeration** — `0`, `±∞`, `NaN`, empty input, single-element input
- **Precision contract** — claimed precision (e.g., "ε = 1e-12") verified by interval arithmetic

### 8.2 — Linear algebra verification

For matrix code (e.g., transformations, decompositions):
- **Dimensional consistency** — matrix shapes line up
- **Conservation laws** — det/trace/rank invariants verified for unitary/orthogonal claims
- **Symmetry/Hermitian properties** — verified by sample evaluation + symbolic

### 8.3 — Algorithm correctness via specification

For algorithm claims:
- **Pre/post-condition extraction** from comments
- **Invariant checking** against known algorithm spec (when available)
- **Reference implementation comparison** — diff against a vetted reference (e.g., `core::cmp::Ord` for sort algorithms)

### 8.4 — Probabilistic algorithm determinism

For ML/probabilistic code:
- **Seed verification** — RNG seed is set
- **Convergence claim verification** — claimed loss/accuracy matches static analysis bounds
- **Numerical stability** — operations are stable (no `softmax` of huge numbers without subtracting max)

---

## §9 — Definition of done (N4 acceptance criteria — VERY EXPLICIT so it ships)

N4 is shippable when **all 20** are true:

### UI surface (4)
1. ⚪ LAM toggle visible in chat input bar
2. ⚪ Per-message verification chip (✓ / amber / ? / red)
3. ⚪ ⌘⇧L keyboard shortcut works
4. ⚪ VoiceOver labels for toggle + per-message status

### Schemas (3)
5. ⚪ `Claim` enum (6 variants: Code/Arithmetic/Algebraic/Citation/Factual/Numerical)
6. ⚪ `LocalAnalysisReport` validates against StructureRegistry
7. ⚪ `epistemos.local_analysis_report.v1` registered in A2UI catalog

### Pipeline (6)
8. ⚪ Stage 1 (claim extraction) — pure deterministic, no LLM
9. ⚪ Stage 2 (code verification) — tree-sitter + type-check + lint + AntipatternRegister grep
10. ⚪ Stage 3 (math verification) — symbolic + numeric + interval + dimensional, triangulation ≥ 2 methods
11. ⚪ Stage 4 (citation verification) — vault FTS5 + ClaimLedger
12. ⚪ Stage 5 (factual cross-check) — vault-only by default; Pro web is opt-in
13. ⚪ Stage 6 (synthesis) — produces LocalAnalysisReport with reproducibility_hash

### Determinism (3)
14. ⚪ All library versions pinned + recorded in report
15. ⚪ Reproducibility test: same input run 2× produces byte-identical reports
16. ⚪ No LLM calls in verification path (verified by grep against pipeline source)

### Composition (2)
17. ⚪ Each verified claim is a N2 Concept Door target
18. ⚪ N3 Exploration Spectrum modulates triangulation depth correctly

### Provenance + verification (2)
19. ⚪ LAM run writes to RunEventLog as `RunEvent::LocalAnalysisCompleted { report_id }`
20. ⚪ WRV proof: toggle is **Wired**, **Reachable** (real keystroke gesture), **Visible** (chip renders distinctly)

---

## §10 — Anti-overbuild stops (binding)

If an agent working on N4 finds itself adding any of these, **stop and surface**:

- LLM-based "double-checker" that calls another model (violates determinism)
- Silent web verification (must be Pro + opt-in)
- Non-pinned library versions (breaks reproducibility)
- Non-deterministic floating-point operations
- Background batch verification on prior messages without user gesture
- Mutating user message content based on verification (annotation only — never rewriting)
- Claims that LAM "guarantees correctness" — it guarantees **deterministic verification** of *some* claims; many claims remain unverifiable
- Generic JSON fallback for `epistemos.local_analysis_report.v1`
- MAS builds with web verification on by default

---

## §11 — Sequencing in the plan tree

| Phase | Status | Items |
|---|---|---|
| **V1** (MAS App Store) | ⚪ pending | Halo + Contextual Shadows ONLY |
| **V1.5** | ⚪ post-V1 | **N2 + N3 + N4** + Raw Thoughts + typed artifact spine |
| **Pro / direct** | ⚪ post-V1.5 | Full Pro web verification + InfiniteDoors mode + agents + Hermes |

**N4 does NOT block V1 ship.** Lands in V1.5 as the third leg of the cognitive exoskeleton (alongside N2 Concept Door + N3 Exploration Spectrum). V1 = Halo (the magical first impression). V1.5 = N2 + N3 + N4 (the cognitive exoskeleton). Pro = full autonomy + web verification.

---

## §12 — Cross-references

- `MASTER_FUSION.md §16` — N2 Concept Door (depth on demand)
- `MASTER_FUSION.md §18` — N3 Exploration Spectrum (deliberation shape)
- `MASTER_FUSION.md §19` — Summary entry pointing here (LAM)
- `MASTER_FUSION.md §3.5` — Four-layer event hierarchy (RunEventLog records LAM runs)
- `MASTER_FUSION.md §11.1` — Closed A2UI catalog (LAM components in catalog)
- `MASTER_FUSION.md §17` — Minimal Surface, Infinite Depth (LAM's chip-then-trail UX)
- `CONCEPT_DOOR_N2.md` — sister N2 doctrine
- `EXPLORATION_SPECTRUM_N3.md` — sister N3 doctrine
- `docs/PROMPT_AS_DATA_SPEC.md` — N1 spec
- `docs/plan/01_DOCTRINE.md` — provenance + retraction primitives
- `docs/plan/03_EXECUTION_MAP.md` — N4 entry (to be added)

---

## §13 — Why this is the rigor pillar

```
N1: prompt becomes data
N2: every concept becomes a door
N3: every query has a deliberation-shape meter
N4: every output is deterministically verified
```

Without N4, the model's output is plausible. With N4, every code/math claim is **either verified, partially verified, or honestly flagged as unverified**. The user trusts the answer because they can see the verification trail.

A normal AI app gives a plausible answer. **Epistemos gives an answer with the math/code claims verified by a deterministic pipeline whose output is byte-reproducible.**

---

## §14 — Provenance log

| Date | Author | Action |
|---|---|---|
| 2026-04-27 | consolidation pass (Cowork) | Initial authoring of N4 Local Analysis Mode. 6-stage deterministic pipeline (claim extraction / code verification / math verification / citation verification / factual cross-check / synthesis). Triangulation ≥ 2 methods for math claims. Determinism contract (8 rules + 6 anti-violations). Composition with N1 PromptTree + N2 Concept Door + N3 Exploration Spectrum. MAS/Pro gating per stage. 20 acceptance criteria locked. Anti-overbuild stops binding. Cross-linked from MASTER_FUSION.md §19. **Authored to be VERY EXPLICIT so it actually ships.** |

---

**END OF LOCAL_ANALYSIS_MODE_N4.md**

> *"Local deep deliberation guided by deterministic process in ML and math. That's important — it must be deterministic enough."* — User, 2026-04-27
>
> Implementation: 6-stage deterministic pipeline. Same input → same output. No LLM in the verification path. Triangulation for math. Vault-grounded for facts. Pro-only for web. Every claim either verified, partially verified, or honestly flagged. Plausibility is not enough. Proof, where proof is possible.
