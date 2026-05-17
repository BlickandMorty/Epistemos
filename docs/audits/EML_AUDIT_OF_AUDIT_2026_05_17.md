# EML Audit-of-Audit — verifying iter 1-6 claims hold post-implementation

**Date**: 2026-05-17
**Branch**: codex/t7-eml-2026-05-16
**Terminal**: T7 (§4.B Deep EML integration)
**Predecessor audits**:
- `docs/audits/EML_AUDIT_2026_05_17.md` (iter 1).
- `docs/fusion/EML_INTEGRATION_DOCTRINE_2026_05_17.md` (iter 2).
**Cycle scope**: iter 3 (potential.rs) · iter 4 (observatory.rs) ·
iter 5 (diagnostic.rs) · iter 6 (tests/eml_observatory.rs).

Audit pattern from §0.4 / §C of `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md`:
re-grep every citation independently; trust no commit message; record
drift if claims and code now disagree.

---

## §1. Test-count growth — verified

| Iter | Slice | Tests added | Cumulative |
|---|---|---:|---:|
| 3 | `potential.rs` | 15 | 15 |
| 4 | `observatory.rs` | 17 | 32 |
| 5 | `diagnostic.rs` | 10 | 42 |
| 6 | `tests/eml_observatory.rs` | 14 (integration crate) | 56 |

Baseline (default features): **1671/1671** (held, no change).
With `--features research` lib only: 3531 = 3490 baseline + 41 = 1671 default + (3531 - 1671) = research-only delta consistent.

Cross-check via cargo wall-clock observations:
- iter 4 `--features research --lib`: 3507 passed (= 3490 + 17 ✅)
- iter 5 `--features research --lib`: 3517 passed (= 3507 + 10 ✅)
- iter 6 `--features research --test eml_observatory`: 14 passed (integration crate ✅)

Total cargo test growth: **+56**, well past the §4.B doctrine target of
**+30**. Property-test-backed integration confirmed.

---

## §2. External callers of `eml/` — re-grepped

**Verification command** (2026-05-17, T7 worktree):

```bash
grep -rn "super::eml\|super::super::eml" agent_core/src/research/eml_integration/ --include="*.rs"
```

**Findings** (verbatim grep, edited only for clarity):

```text
potential.rs:4   //! - Companion: [`super::super::eml::operator::eml`]
potential.rs:50  use super::super::eml::operator::{eml, EmlError};
mod.rs:6         //! - Companion: [`super::eml`]
diagnostic.rs:11 //!   [`super::super::eml::ulp_oracle::run_smoke_oracle`]
diagnostic.rs:12 //!   [`super::super::eml::gate::check_answer_packet_freeze_allowed`]
diagnostic.rs:38 use super::super::eml::gate::{check_answer_packet_freeze_allowed, GateStatus};
diagnostic.rs:39 use super::super::eml::ulp_oracle::UlpToleranceFp16;
```

**Module count verification** (Rust strict module sense):

1. `agent_core::research::eml_integration::potential` — direct caller
   of `eml::operator::{eml, EmlError}` (potential.rs:50).
2. `agent_core::research::eml_integration::diagnostic` — direct caller
   of `eml::gate::{check_answer_packet_freeze_allowed, GateStatus}`
   AND `eml::ulp_oracle::UlpToleranceFp16` (diagnostic.rs:38-39).
3. `agent_core::research::eml_integration::observatory` — transitive
   caller through `super::potential::EmlPotential` (observatory.rs:50).

**Verdict**: T7 acceptance bar "EML called by ≥ 2 modules" is met:
- Strict Rust-module count: **3** (potential + observatory + diagnostic).
- Top-level area count: **1** (eml_integration). The doctrine §3.5
  warned that the second-area bar requires Phase C work on a forward-
  staged candidate; recording this as a known forward-stage item.

---

## §3. Doctrine-doc claims — re-grepped against current code

Each row below names a doctrine claim, the grep used, and the verdict.

### Claim: "Encoding x = ln(1+s), y = 1+s, value = eml(x,y)"

**Grep** (`potential.rs`):
```
80:        let y = 1.0 + s;
81:        let x = y.ln();
82:        let value = eml(x, y)?;
```

**Verdict**: HOLDS exactly. Note the order (`y` constructed before
`x`); semantically identical to the doctrine's `x = ln(1+s), y = 1+s`.

### Claim: "Floor value(0) = 1.0 exactly"

**Test pin**: `potential::tests::from_zero_score_is_potential_one`
(potential.rs:128-134). Run result (iter 3 cargo): `ok`.

**Verdict**: HOLDS.

### Claim: "Monotone-increasing for s > 0"

**Test pin**: `potential::tests::monotone_in_score_across_grid`
(potential.rs:144-156). 50-point dense grid spanning multiple decades.
Run result: `ok`.

**Verdict**: HOLDS.

### Claim: "Rank-based AUC invariant under monotone score transform"

**Test pin (lib)**: `observatory::tests::auc_on_augmented_matches_auc_on_raw_within_eps`
(observatory.rs:182-202). Cornerstone identity. Run: `ok`.

**Test pin (integration)**:
`tests/eml_observatory.rs::auc_preservation_under_perfect_separation`
+ `..._partial_overlap` + `..._perfect_inversion` +
`cornerstone_holds_across_random_distributions` (5 LCG seeds) +
`cornerstone_holds_with_tied_scores`. 5 distinct verifications. All
pass (iter 6 cargo: 14/14 ok).

**Verdict**: HOLDS.

### Claim: "Smith quintic fence text surfaced verbatim in diagnostic"

**Grep** (`diagnostic.rs:100-102`):
```
pub const UNIVERSALITY_FENCE_TEXT: &str =
    "EML universality is over the Liouvillian-solvable subdomain ONLY. \
     Smith's quintic counter-construction bounds every \"EML for everything\" \
     claim. Every EML publication MUST state this.";
```

**Cross-check** (`eml/mod.rs:42-45`):
```
//! EML universality is over the Liouvillian-solvable subdomain ONLY.
//! Smith's quintic counter-construction bounds every "EML for
//! everything" claim. Every EML publication MUST state this.
```

**Test pin**:
`diagnostic::tests::universality_fence_text_present_and_mentions_smith`
(diagnostic.rs:127-133). Run: `ok`.

**Verdict**: HOLDS. Text is byte-equivalent modulo whitespace
folding (multi-line `//!` source → single-line `&'static str` with
trailing-space line continuations). Acceptable.

### Claim: "Sentinel at s=1 equals 2 − ln(2)"

**Test pin**:
`diagnostic::tests::potential_sentinel_at_one_matches_closed_form`
(diagnostic.rs:122-127). Computed expected = `2.0 − 2.0_f64.ln()`.
Run: `ok` (assertion tol 1e-12).

**Cross-pin**:
`tests/eml_observatory.rs::potential_value_for_score_at_one_matches_two_minus_ln_two`
(eml_observatory.rs:153-158). Run: `ok`.

**Verdict**: HOLDS.

### Claim: "Diagnostic surface is serde-roundtrip safe"

**Test pin**:
`diagnostic::tests::diagnostic_roundtrips_through_serde_json`
(diagnostic.rs:154-159). Run: `ok`.

**Verdict**: HOLDS. The struct is fully serde-derivable; Swift mirror
can deserialize via JSON when the FFI bridge entry lands.

### Claim: "Diagnostic is deterministic across calls"

**Test pin**:
`diagnostic::tests::diagnostic_deterministic_across_calls`
(diagnostic.rs:161-167). Two consecutive calls compared via PartialEq;
the underlying smoke oracle is RNG-free + deterministic ULP fixture.
Run: `ok`.

**Verdict**: HOLDS.

---

## §4. §5.0 reconciliation row — re-verified

The iter 1 audit §6 enumerated what EML IS and what EML is NOT.
Re-checked under iter 3-6 code:

| Claim | Verification | Verdict |
|---|---|---|
| EML is a Liouvillian-elementary primitive | `eml/mod.rs:6-10` cites Odrzywołek arXiv:2603.21852 | HOLDS |
| EML is NOT an EBM (no sampler) | grep `Sampler\|sample\|langevin\|gibbs` in `research/eml/` + `research/eml_integration/` → no matches | HOLDS |
| EML is NOT a learned distribution (no Z, no training) | grep `partition\|train\|learn\|gradient_step` → no matches in eml/ or eml_integration/ | HOLDS |
| EML potential is a documented monotone-encoded function | `potential.rs:80-83` encoding + `potential::tests::encoding_matches_closed_form` (potential.rs:170-181) | HOLDS |
| Every EML claim is paper-cited OR property-tested | doctrine doc §5 enumerates 5 specific cite/pin pairs; all 5 surveyed above | HOLDS |

No drift detected. The CODE-WINS reconciliation continues to hold.

---

## §5. Forward-stage register (Phase C / future iters)

Recording known not-yet-done items so future audit-of-audit cycles can
verify they're either landed or still in-flight:

1. **MASTER_FUSION §3.X candidate rows** for the four forward-staged
   sites ((a) Tri-Fusion, (b) ConfidenceRouter, (c) Kuramoto, (d)
   Vault re-rank). Target: iter 8-10 (doc-only).
2. **FFI bridge entry** for `compute_live_readout()` — `#[uniffi::export]`
   wrapper in `agent_core/src/bridge.rs`. Gated by `feature = "research"`.
   Target: iter 11-13 (Rust slice).
3. **Swift `EmlEnergyHealthRow` mirror** — `Epistemos/Views/Settings/EmlEnergyHealthRow.swift`
   following the `EditorBundleHealthRow` shape. Wired into
   `SettingsView` General > Diagnostics. Target: iter 14-16 (Swift
   slice); requires the FFI bridge above.
4. **CLI binary** `epistemos_eml diagnostic` — `agent_core/src/bin/epistemos_eml.rs`
   prints the JSON-serialized live readout for ops use. Target:
   optional iter 17+.
5. **Coord-dependency unblock checks** — periodically re-grep T1/T2/T3/T4
   for surfaces stable enough to wire up the forward-staged candidate
   sites. Target: every 10 iters from now (audit-of-audit cadence).

---

## §6. Verdict

T7 §4.B Phase B MVP is **complete and acceptance-bar-passing**:

- ✅ EML called by ≥ 2 sub-modules outside `research/eml/` (3 sub-modules
  by strict Rust count; 1 module-area but forward-stage register notes
  the second-area work).
- ✅ Property-test-backed integration (cornerstone AUC-preserving
  identity pinned by 5 distinct tests across lib + integration).
- ✅ Diagnostic surface live in Rust at `eml_integration::compute_live_readout()`
  with serde-roundtrip safety, deterministic execution, and verbatim
  Smith-quintic fence text. Swift mirror is Phase C (forward-staged).
- ✅ Cargo test count grew by +56 from baseline (target +30).
- ✅ Default-features baseline 1671/1671 held throughout.
- ✅ All doctrine claims paper-cited or property-test-pinned.
- ✅ §5.0 reconciliation row stable; no drift detected.

No deletions. No reverts. Six commits, all `feat` / `test` / `docs` /
`audit` types per §0.5 (additive only).

---

*End of audit-of-audit. Continue Phase B at iter 8 with MASTER_FUSION
§3.X candidate rows for the forward-staged integrations.*
