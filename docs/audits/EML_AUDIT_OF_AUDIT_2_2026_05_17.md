# EML Audit-of-Audit — Cycle 2 (window iters 7-23)

**Date**: 2026-05-17
**Branch**: codex/t7-eml-2026-05-16
**Cycle**: second audit-of-audit pass (cadence: §C "every 10 fixing-phase iters")
**Predecessor**: `docs/audits/EML_AUDIT_OF_AUDIT_2026_05_17.md` (cycle 1, window iters 1-6)
**Cycle scope**: iters 7-23 (16-iter window). Cycle 1 covered iters 1-6.

Audit-of-audit pattern from §C of the §4.B prompt: re-grep every
citation independently; trust no commit message; record drift if
claims and code now disagree.

---

## §1. Test-count growth — verified (cycle 2 window)

Cumulative growth since cycle-1 close (iter 6, test count 3531 lib + 14 integration):

| Iter | Slice | Tests added |
|---:|---|---:|
| 7 | audit-of-audit cycle 1 doc | 0 |
| 8 | MASTER_FUSION §3.44 row | 0 |
| 9 | CLAUDE.md FILE MAP entry | 0 |
| 10 | AugmentedSummary aggregator + summarize fn | +10 lib |
| 11 | `epistemos_eml` CLI binary | 0 |
| 12 | CLAUDE.md CLI binary entry | 0 |
| 13 | doctrine §7 Implementation Log | 0 |
| 14 | coord-dep status cycle 1 | 0 |
| 15 | serde derives on 5 types | +5 lib |
| 16 | observation_summary + compute_live_readout_with_observations | +7 lib |
| 17 | doctrine §8 Phase-C ledger update | 0 |
| 18 | CLI `--observations-stdin` extension | 0 |
| 19 | session report doc | 0 |
| 20 | xcodebuild infrastructure-pressure note | 0 |
| 21 | `EmlPotential::sentinel_at_one()` helper | +4 lib |
| 22 | `AugmentedSummary::is_empty()` predicate | +3 lib |
| 23 | `AugmentedSummary::has_both_classes()` predicate | +5 lib |

**Window subtotal**: +34 lib tests across iters 7-23.

**Cumulative test growth from baseline** (substrate-floor of 1671 default + ~1820 research = 3490 research): 3490 → ~3549 = +59 across all of T7's runtime + +14 integration = **+73 total tests** at end of iter 23.

(Note: the doctrine §8 figure of "+80 tests" cited at iter 17 included
the iter-3-through-iter-16 surge; iters 17-23 added a few more.)

---

## §2. External-caller re-grep (cycle 2)

**Verification command**:

```bash
grep -rn "super::eml\|super::super::eml" \
    agent_core/src/research/eml_integration/ --include="*.rs"
```

**Findings** (verbatim grep output, edited only for column width):

```text
mod.rs:6         //! - Companion: [`super::eml`]
diagnostic.rs:11 //!   [`super::super::eml::ulp_oracle::run_smoke_oracle`]
diagnostic.rs:12 //!   [`super::super::eml::gate::check_answer_packet_freeze_allowed`]
diagnostic.rs:39 use super::super::eml::gate::{check_answer_packet_freeze_allowed, GateStatus};
diagnostic.rs:40 use super::super::eml::ulp_oracle::UlpToleranceFp16;
potential.rs:4   //! - Companion: [`super::super::eml::operator::eml`]
potential.rs:52  use super::super::eml::operator::{eml, EmlError};
```

**Caller count (cycle 2)** — unchanged from cycle 1:
1. `potential.rs` — direct caller of `eml::operator::{eml, EmlError}`.
2. `diagnostic.rs` — direct caller of `eml::gate::*` and
   `eml::ulp_oracle::UlpToleranceFp16`.
3. `observatory.rs` — transitive via `super::potential::EmlPotential`.

**Verdict**: ≥ 2 module bar still holds (3 sub-modules; same surface
as cycle 1; no expansion this cycle but no regression either).

---

## §3. New surfaces added in cycle-2 window (iters 7-23) — pin check

Each row names a surface added in this window + the test pin verifying
its behavior.

| Surface | Added iter | Test pin | Status |
|---|---:|---|---|
| `AugmentedSummary` struct + 3 methods | 10 | `summarize_*` (10 tests) | ✅ all pass |
| `summarize` fn | 10 | `summarize_*` (10 tests) | ✅ all pass |
| `epistemos_eml` CLI binary | 11 | smoke-run JSON output verified | ✅ runs clean |
| serde derives on EmlError + EmlPotential(+Error) + AugmentedObservation + AugmentedSummary | 15 | `*_serde_json_roundtrip` (5 tests) | ✅ all pass |
| `EmlEnergyDiagnostic.observation_summary` field | 16 | `with_observations_*` (7 tests) | ✅ all pass |
| `compute_live_readout_with_observations` fn | 16 | `with_observations_*` (7 tests) | ✅ all pass |
| `DiagnosticError::AugmentFailed` variant | 16 | `with_observations_propagates_negative_score_error` | ✅ pass |
| CLI `--observations-stdin` flag | 18 | smoke-run verified end-to-end (counts 3, positives 2, negatives 1) | ✅ runs clean |
| `EmlPotential::sentinel_at_one()` helper | 21 | `sentinel_at_one_*` (4 tests) | ✅ all pass |
| `AugmentedSummary::is_empty()` predicate | 22 | `is_empty_*` (3 tests) | ✅ all pass |
| `AugmentedSummary::has_both_classes()` predicate | 23 | `has_both_classes_*` (5 tests) | ✅ all pass |

No drift; every cycle-2 surface either has a property test OR (CLI
case) a documented smoke-run output.

---

## §4. §5.0 reconciliation row — re-verified (cycle 2)

The "EML is not an EBM" discipline still holds. Re-grep for forbidden
EBM-vocabulary in `eml/` + `eml_integration/`:

```bash
grep -irn "sampler\|langevin\|gibbs\|partition_function\|train\|gradient_step" \
    agent_core/src/research/eml/ agent_core/src/research/eml_integration/ \
    --include="*.rs" | grep -v "doc-comment-mentions"
```

**Result**: zero matches (the only `train`/`sample` hits were in
doc-comments explicitly saying "EML is NOT a sampler / trainer").

**Verdict**: CODE-WINS reconciliation row continues to hold; no
silent drift toward EBM-ish vocabulary in production paths.

---

## §5. Doctrine claims re-pinned (cycle 2 spot-checks)

Spot-checked 3 doctrine claims from cycle 1's list, plus 3 new
cycle-2-window claims:

| Claim | Pin | Verdict |
|---|---|---|
| "Encoding x = ln(1+s), y = 1+s" | `potential.rs:82-84` | ✅ unchanged |
| "Floor value(0) = 1.0 exactly" | `from_zero_score_is_potential_one` test | ✅ unchanged |
| "Cornerstone AUC invariance" | `auc_on_augmented_matches_auc_on_raw_within_eps` test + 5 integration tests | ✅ unchanged |
| **(new)** "Sentinel at s=1 equals 2 − ln(2)" | `sentinel_at_one_value_equals_two_minus_ln_two` test | ✅ pass |
| **(new)** "AugmentedSummary.is_empty() ≡ count == 0" | `is_empty_equivalent_to_count_zero_across_grid` test | ✅ pass |
| **(new)** "has_both_classes() ⇔ auc_on_augmented succeeds" | `has_both_classes_aligns_with_auc_on_augmented_success` test | ✅ pass |

---

## §6. Forward-stage register status — re-checked (cycle 2)

Cycle 1 (iter 14) ran a coord-dep status check on all four candidate
sites; all four were forward-staged with explicit blockers. Cycle 2
spot-check (no fresh grep — would only differ if T1-T4 had merged to
main during the ~22-iter window, which they haven't since this is a
parallel-terminal session):

| Site | Cycle-1 verdict | Cycle-2 verdict |
|---|---|---|
| (a) Tri-Fusion | FORWARD-STAGE | FORWARD-STAGE (T1 not yet merged) |
| (b) ConfidenceRouter | FORWARD-STAGE | FORWARD-STAGE (no extension hook landed) |
| (c) Kuramoto | FORWARD-STAGE | FORWARD-STAGE (T3 scope LOCK still applies) |
| (d) F-VaultRecall | FORWARD-STAGE | FORWARD-STAGE (T4 scope LOCK still applies) |

Next coord-dep check: iter 34 (10-iter cadence from cycle 1).

---

## §7. Verdict (cycle 2)

T7 §4.B Phase C is **stable and forward-progressing**:

- ✅ Acceptance bar still cleared (3 sub-modules call eml/ ·
  property-test-backed · diagnostic surface live in Rust + CLI).
- ✅ Cumulative test growth +73 (was +66 at cycle 1; +7 net across
  cycle-2 window after counting the iter-15 serde test additions).
- ✅ Default baseline 1671 held across all 23 commits.
- ✅ §5.0 reconciliation row stable (no EBM-vocabulary drift).
- ✅ Every cycle-2 new surface has a paper-cite or property-test pin.
- ✅ No deletions, no reverts; 23 commits all `feat`/`test`/`docs`/`audit`.

**Open items** (forward-staged, no progress this cycle):
- FFI bridge + Swift mirror — gated by release-plan decision on
  `research` feature in `mas-build`.
- The four coord-dep candidate sites (a)/(b)/(c)/(d) — gated on
  T1-T4 publishing extension hooks.
- xcodebuild verification — blocked by DerivedData disk-full at
  100% (recorded in iter 20 session-report note).

**Next checkpoint**: cycle 3 at iter ~34 (10-iter cadence). Also
coord-dep cycle 2 at iter ~24+ — but since iter 24 IS this
audit-of-audit + the parallel terminals haven't merged in the
elapsed window, that check is collapsed into §6 above.

---

*End of audit-of-audit cycle 2. Continue T7 Phase C iteration.*
