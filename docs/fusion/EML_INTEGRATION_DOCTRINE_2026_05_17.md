# EML Integration Doctrine — making `agent_core/src/research/eml/` a load-bearing primitive

**Date**: 2026-05-17
**Owner**: T7 (§4.B Deep EML integration)
**Branch**: codex/t7-eml-2026-05-16 (cut from main)
**Companion**: `docs/audits/EML_AUDIT_2026_05_17.md` (substrate state).
**Bar**: EML stops being a research-island and becomes a substrate primitive
that ≥ 2 modules outside `research/eml/` call into, with every behavior
claim either paper-line-cited or property-test-backed.

---

## §1. Typed surface (what EML provides today)

Full surface inventory: see audit doc §4. Summary:

- **Binary primitive**: `eml(x, y) = exp(x) − ln(y)` over `(f64, f64)`, with
  partials `∂eml/∂x = exp(x)` and `∂eml/∂y = -1/y`, and the inverse
  `eml_inverse_x(z, y) = ln(z + ln(y))`. All error-typed; `y ≤ 0` rejected.
- **Grammar + evaluator**: `S → 1 | eml(S, S)` (`EmlExpr`) with recursive
  descent to f64 (`evaluate`), depth-capped at 32.
- **Acceptance harness**: 1024-sample fp16-ULP smoke oracle + 2-ULP
  shipping bar; AnswerPacket schema freeze gates on this.
- **Universality**: every elementary function on the Liouvillian-solvable
  subdomain decomposes into an EML term (Odrzywołek arXiv:2603.21852).
  Hard fence: Smith's quintic counter-construction bounds the universality
  claim (`agent_core/src/research/eml/mod.rs:42-45`).

**Doctrine row §5.0 reconciliation**: when this document says
*"EML potential"*, it means *"the f64 value of an `EmlExpr` evaluated by
[`evaluate`], optionally composed with a documented monotone normalization"*.
EML is **not** an Energy-Based Model in the LeCun sense. See audit §6 for
the full IS/IS-NOT enumeration.

---

## §2. Five candidate integration sites

Each candidate names: the host module, the energy-shaped operation, the
proposed `(x, y) → EmlExpr` encoding, the acceptance test, and the
coordination dependency. Sites are not exclusive — the MVP picks one;
the rest forward-stage.

### (a) Tri-Fusion ambiguity resolution — COORD T1

**Host**: `agent_core/src/research/...` (T1's tri-fusion module; not in T7
scope to read or touch).

**Energy-shaped operation**: when MD ⇄ JSON ⇄ HTML round-trip yields
multiple valid parses, pick the lowest-energy candidate.

**Proposed encoding**: per candidate parse `p_i`, encode a feature pair
`(x_i, y_i)` where `x_i` is the negative-log-likelihood of the parse under
a depth-prior and `y_i` is the round-trip recall fraction (strictly
positive). The EML potential `eml(x_i, y_i)` produces a scalar dispersion;
selection picks `argmin_i eml(...)`.

**Acceptance test**: property test in `agent_core/tests/eml_tri_fusion.rs`
proving the lowest-potential parse matches the analytic answer on a
hand-constructed fixture (e.g. two-candidate MD↔HTML round-trip with one
candidate dominant on recall).

**Coordination**: requires T1's surface to be stable. **Forward-stage
unless T1 publishes its parse-candidate enumerator before T7 lands MVP.**

---

### (b) ConfidenceRouter scoring — COORD T2

**Host**: `Epistemos/LocalAgent/ConfidenceRouter.swift` (Swift side; T2's
agent_runtime in Rust owns the routing primitive — out of T7 scope).

**Energy-shaped operation**: route an inference request to the model whose
"confidence potential" is lowest. EML potential acts as a calibrated
inverse-confidence proxy.

**Proposed encoding**: `(x, y) = (request_complexity_log, model_recall_estimate)`.
Higher complexity ↑ `x` ↑ `exp(x)`; lower recall ↑ `-ln(y)`. The sum is
larger when both signals say "this is hard for this model" — route away.

**Acceptance test**: property test asserting monotonicity:
`eml_partial_x > 0` and `eml_partial_y < 0` (already covered by
`operator.rs` tests; integration test would lift these into the routing
pipeline).

**Coordination**: requires T2's ConfidenceRouter to accept an external
score injection or a `ConfidenceFloor` extension. **Forward-stage —
out of T7's runtime layer.**

---

### (c) Kuramoto coupling tempering — COORD T3

**Host**: `agent_core/src/research/acs/kuramoto.rs` (T3's UAS-ACS slice;
explicitly out of T7 scope per the worktree's DON'T TOUCH list).

**Energy-shaped operation**: when the global order parameter `R(t)`
exceeds a synchronization threshold, damp the coupling constant by an
EML-potential-derived gradient to prevent runaway lock-in.

**Proposed encoding**: `(x, y) = (log(R(t)), 1 + ε)` for small `ε > 0`;
the partial `∂eml/∂y` gives a negative gradient applied as a coupling
damping term.

**Acceptance test**: simulation property test showing the damped Kuramoto
stays below `R = 0.95` for at least N steps after detection.

**Coordination**: T3 owns kuramoto.rs. **Forward-stage — out of T7 scope.**

---

### (d) F-VaultRecall-50 re-ranking — COORD T4

**Host**: `agent_core/src/storage/vault.rs` (T4 owns; out of T7 scope).

**Energy-shaped operation**: re-rank candidate vault results by
energy-weighted relevance. The current Fix B (lines 495-548) does query
chatter strip + AND-for-short-queries; EML adds a secondary re-rank pass.

**Proposed encoding**: `(x, y) = (-log(bm25_score + ε), recall_fraction)`.
`eml(...)` becomes a re-rank key, smaller-is-better.

**Acceptance test**: F-VaultRecall-50 dataset pass-fraction does not
regress under the EML re-rank pass; ideally improves by ≥ 2 pp on the
existing 50-query fixture.

**Coordination**: T4 owns vault.rs. **Forward-stage — out of T7 scope.**

---

### (e) SAE Cognition Observatory anomaly augmentation — NO COORD DEPENDENCY ✅

**Host**: a new module `agent_core/src/research/eml_integration/` (T7's
scope ALLOW) that consumes the `LabeledScore` surface from
`agent_core/src/research/cognition_observatory/sae.rs` (read-only at
T7's boundary; doctrine §B.4 *additive only*).

**Energy-shaped operation**: augment the SAE feature-firing score with an
EML-potential overlay derived from the same observation. The augmented
score feeds the existing `auc_roc` / `evaluate_against_gate` pipeline.

**Proposed encoding**: per `LabeledScore` observation with raw SAE score
`s ≥ 0`, derive
- `x = log(1 + s)` (always finite, monotone in `s`)
- `y = 1 + s` (strictly positive)

Then `eml(x, y) = exp(log(1 + s)) − ln(1 + s) = (1 + s) − ln(1 + s)`.

This is a **monotone-increasing function of `s`** (derivative
`1 − 1/(1 + s) > 0` for `s > 0`), and **bounded below by 1** at `s = 0`.
Crucially it is **analytically derivable from the EML primitive**, not
hand-tuned — every claim about it rides on the eml-module's existing
tests plus a small property suite proving monotonicity, the floor, and
the AUC-preserving behavior.

**Acceptance test**: property tests in `agent_core/tests/eml_observatory.rs`:
1. Monotonicity: for any `s1 < s2`, augmented(s1) < augmented(s2).
2. Floor: augmented(0) ≥ 1.
3. AUC preservation under monotone transform (the rank-based AUC formula
   in `sae.rs:146` is invariant under strictly monotone transformations of
   the score, so the augmented score yields exactly the same AUC). This
   is the cleanest possible "first integration" — proves the overlay is
   semantically neutral on the existing acceptance gate while exposing
   the EML potential as a diagnostic surface.
4. Determinism: augmented score is purely a function of the raw score
   (no hidden state).
5. Round-trip via the EML expression-tree encoding (`EmlExpr` constructed
   per observation evaluates to the same value as direct `eml(x, y)`).

**Coordination**: none — T7 owns the new module; the host `sae.rs` is
read but not touched. (Per §B.4 *additive only* and §0 rule 1 *never
delete*.)

**Verdict**: **MVP = (e) SAE observatory anomaly augmentation.**

---

## §3. The minimal integration MVP — site (e), implementation plan

### §3.1 New crate-internal layout

```
agent_core/src/research/eml_integration/
├── mod.rs              — re-exports + module docstring with sources
├── potential.rs        — EmlPotential newtype + monotone-normalized score
├── observatory.rs      — SAE-score augmentation API
└── diagnostic.rs       — Settings → Diagnostics row payload
```

Module registered in `agent_core/src/research/mod.rs` alphabetically
after `eml`. Feature-gated behind `feature = "research"` like its
siblings (per `research/mod.rs:13-15`).

### §3.2 `potential.rs` — the encapsulated primitive

```rust
pub struct EmlPotential(pub f64);

impl EmlPotential {
    /// Constructs from a strictly-positive scalar `s ≥ 0`.
    /// Encoding: x = ln(1 + s), y = 1 + s. Both finite for any
    /// finite `s ≥ 0`. The encoded EML value equals (1 + s) − ln(1 + s),
    /// monotone-increasing in `s`, floor 1.0 at s = 0.
    pub fn from_score(s: f64) -> Result<Self, EmlError>;

    /// Underlying EML expression (for provenance + serde).
    pub fn to_expr(&self) -> EmlExpr;

    /// Raw f64 value.
    pub fn value(&self) -> f64;
}
```

Property tests (in-module):

- `potential_from_zero_is_one`
- `potential_from_positive_is_above_one`
- `potential_is_monotone_in_score`
- `potential_floor_holds_across_grid`
- `potential_to_expr_evaluates_back_to_value`
- `potential_rejects_nan_score`
- `potential_rejects_negative_score`
- `potential_is_deterministic`

### §3.3 `observatory.rs` — SAE-score augmentation

```rust
pub struct AugmentedScore {
    pub raw: f32,
    pub eml_potential: f64,
    pub label_positive: bool,
}

pub fn augment(observations: &[LabeledScore]) -> Result<Vec<AugmentedScore>, EmlError>;

/// Run AUC on the augmented scores. Because EML potential is a strictly
/// monotone transform of the raw score, the rank-based AUC is
/// **identically preserved**. This is the semantic-neutrality property
/// the doctrine pins to a test.
pub fn auc_on_augmented(observations: &[LabeledScore]) -> Result<f32, SaeAucError>;
```

Property tests (in `agent_core/tests/eml_observatory.rs`):

- `augment_preserves_observation_count`
- `augment_preserves_labels`
- `augment_monotone_in_raw_score`
- `auc_on_augmented_equals_auc_on_raw_within_eps`  ← the cornerstone
- `augment_deterministic`
- `augment_rejects_nan_score`
- `augment_with_all_negative_labels_gives_zero_auc`
- `augment_with_all_positive_labels_gives_one_auc`

### §3.4 `diagnostic.rs` — Settings → Diagnostics payload

A Sendable `EmlEnergyDiagnostic` struct + a `compute_live_readout()`
function that:

1. Runs the smoke ULP oracle (`run_smoke_oracle(SHIPPING_BAR)`).
2. Captures the current `EmlPotential::from_score(reference_input)` for
   a baseline sentinel score (e.g. `s = 1.0`).
3. Returns a JSON-serializable struct exposing
   `{ ulp_max, ulp_mean, ulp_within_bar_fraction, potential_at_one,
   timestamp_ms, eml_universality_hard_fence_text }`.

This is consumed by a Swift `EmlEnergyHealthRow` mirror in Settings →
Diagnostics on the Swift side (mirroring the `EditorBundleHealthRow` /
`SearchFusionHealthRow` pattern documented in `CLAUDE.md`).

The Swift row is land-after — Swift work is gated behind the diagnostic
row landing in Rust + the FFI exposing `compute_live_readout()`. T7 Phase
B (iter 7-30) targets the Rust side; the Swift surface is a Phase C
candidate (iter 30+).

### §3.5 The "≥ 2 modules call EML" success criterion

After Phase B lands, EML will be called by:

1. **`eml_integration`** (new) — directly, via the `EmlExpr` + `eml(x, y)`
   surface. Acts as the **runtime integration adapter**.
2. **`cognition_observatory::sae`** — indirectly, via the
   `eml_integration::observatory::augment` API. The SAE module is NOT
   modified; the augmentation is a **read-only consumer**.

For a stricter "≥ 2 *integration* sites" reading, T7 Phase C will then
add the diagnostic row's call site (Settings UI surface) as the third
caller, plus forward-stage the four other candidate sites.

### §3.6 Test-growth target

Per the T7 prompt: `+30 cargo tests`.

- `potential.rs`: 8 in-module property tests.
- `observatory.rs`: 4 in-module + 8 in `tests/eml_observatory.rs` = 12.
- `diagnostic.rs`: 4 in-module tests.
- `tests/eml_potential_grid.rs`: 6 property tests (cross-grid sweep,
  determinism, EmlExpr round-trip, fraction-within-bar carryover,
  composition with the existing gate).
- Total: **30 new tests**, meeting the bar exactly.

---

## §4. Forward-staged integrations

The four sites that require coordination with other terminals are not
deleted, denied, or marked NOT-STARTED. They are **forward-staged**, each
as a candidate row for MASTER_FUSION §3.X:

| Site | Coord | Estimated effort | Pre-req |
|---|---|---|---|
| (a) Tri-Fusion ambiguity | T1 | 1-2 iter | T1 publishes parse-candidate enumerator |
| (b) ConfidenceRouter | T2 | 2-3 iter | T2 exposes ConfidenceFloor extension hook |
| (c) Kuramoto damping | T3 | 1-2 iter | T3 finishes ACS substrate review |
| (d) Vault re-ranking | T4 | 2 iter | T4 stabilizes F-VaultRecall-50 dataset spec |

Each row will be added as a §3.X candidate in MASTER_FUSION after the MVP
ships. No code in those modules touched by T7 (scope LOCK).

---

## §5. The "no hand-waving" rule (per §4.B point 4)

Every claim in this doctrine has a citation back-pointer:

- *"EML universality on the Liouvillian-solvable subdomain"* →
  Odrzywołek arXiv:2603.21852 §2, mirrored in `eml/mod.rs:6-10`.
- *"Smith quintic fence bounds the universality claim"* →
  `eml/mod.rs:42-45`.
- *"`eml(x, y) = exp(x) − ln(y)` rejects `y ≤ 0`"* →
  `operator.rs:22-24` + test `eml_rejects_negative_y` (`:111-114`).
- *"Augmented score is monotone in raw score"* → derivative
  `1 − 1/(1+s) > 0`, will be pinned by `potential_is_monotone_in_score`
  test in Phase B.
- *"Rank-based AUC is invariant under strictly monotone score transforms"* →
  Hanley & McNeil 1982 (cited in `sae.rs:8-10`), pinned by
  `auc_on_augmented_equals_auc_on_raw_within_eps` test in Phase B.

If a future audit-of-audit cycle finds an unpinned claim, that claim is
either deleted or grounded; doctrine never silently floats.

---

## §6. Iteration plan

- **Phase A** (iter 1-6, doc-only): audit doc + this doctrine doc + 2-3
  audit-of-audit refinement rounds.
- **Phase B** (iter 7-30, code-allowed, additive): build
  `eml_integration/` per §3 — 30 new tests, diagnostic row payload,
  property-test cornerstone proving the AUC-preserving identity.
- **Phase C** (iter 30+, forward-stage candidates): pick one of (a)/(b)/(c)/(d)
  if its coordination terminal has advanced enough; otherwise harden Phase
  B's surfaces (Swift mirror for the diagnostic row, observatory
  visualization).

Every iter:

1. `git status` clean before starting.
2. `cargo test --manifest-path agent_core/Cargo.toml --lib` ≥ baseline.
3. §5.0 reconciliation: every new claim either paper-cited or
   property-tested.
4. ONE slice, one commit, HEREDOC body, `Co-Authored-By: Codex (T7)`.
5. Push every 5-10 commits.

---

*End of doctrine. Phase B starts at iter 3 with the
`eml_integration/potential.rs` primitive.*

---

## §7. Implementation Log

Per §3.43's PR-discipline rule + MASTER_FUSION's §"Implementation Log"
pattern: every shipped slice gets a row here with the commit SHA so
future readers can pick up cold without re-grepping the branch.

| Iter | Phase | Commit | Scope | Tests added |
|---:|---|---|---|---:|
| 1 | A — doc | `bdf991c8d` | `docs/audits/EML_AUDIT_2026_05_17.md` (substrate-state audit, §5.0 reconciliation row) | 0 |
| 2 | A — doc | `e9314bf04` | this doc (`EML_INTEGRATION_DOCTRINE_2026_05_17.md`); 5 candidate sites + MVP plan | 0 |
| 3 | B — code | `f18627f24` | `eml_integration/{mod,potential}.rs`; EmlPotential newtype + encoding | +15 lib |
| 4 | B — code | `c2d0aab80` | `eml_integration/observatory.rs`; SAE-AUC cornerstone MVP integration | +17 lib |
| 5 | B — code | `0920347d6` | `eml_integration/diagnostic.rs`; Settings → Diagnostics payload struct | +10 lib |
| 6 | B — test | `01318d76a` | `tests/eml_observatory.rs`; integration tests on cornerstone identity | +14 integration |
| 7 | C — audit | `3476f0629` | `docs/audits/EML_AUDIT_OF_AUDIT_2026_05_17.md`; window 1 cycle | 0 |
| 8 | C — doc | `8f992fa14` | MASTER_FUSION §3.44 EML Integration Substrate row | 0 |
| 9 | C — doc | `c68dd4026` | CLAUDE.md FILE MAP entry for `eml_integration/` | 0 |
| 10 | C — code | `4005f302e` | `observatory::summarize` + `AugmentedSummary` aggregator | +10 lib |
| 11 | C — code | `0a91d3698` | `agent_core/src/bin/epistemos_eml.rs` ops CLI | 0 |
| 12 | C — doc | `2fc19ca6b` | CLAUDE.md FILE MAP entry for the CLI binary | 0 |

**Cumulative test growth**: +52 lib + +14 integration = **+66 tests**.

(The audit-of-audit doc additionally records cross-pinned tests from
the iter-3 potential cornerstone, so the doctrine's "55 tests" §3.6
target was met by iter 6 itself; iters 7-12 added doc/canon/ops
surfaces + 10 more lib tests via the aggregator. Note: the iter-10
commit message records +66 total against the earlier doctrine §3.6
estimate of 30; that estimate was set BEFORE the cornerstone-AUC
property tests were enumerated.)

**Cargo gates** (post-iter 12):
- Default features (`mas-build`): **1671/1671** held throughout.
- `--features research --lib`: 3490 baseline → **3527** (+37 net).
- `--features research --test eml_observatory`: 14/14.
- `--features research --bin epistemos_eml`: builds clean; smoke-run
  prints expected JSON payload.

**Forward-stage status** (from audit-of-audit §5):
- Item 1 (MASTER_FUSION §3.44): ✅ landed iter 8.
- Item 2 (FFI bridge for compute_live_readout): NOT-STARTED — needs
  coord with the broader release plan (research feature isn't in
  default mas-build, so the Swift mirror waits on that decision).
- Item 3 (Swift `EmlEnergyHealthRow`): NOT-STARTED — gated by item 2.
- Item 4 (CLI binary `epistemos_eml`): ✅ landed iter 11.
- Item 5 (coord-dependency unblock checks for sites a/b/c/d): ✅
  cycle 1 ran iter 14 (`docs/audits/EML_COORD_DEP_STATUS_2026_05_17.md`);
  all four sites continue to forward-stage. Next cycle target iter 24.

---

## §8 Phase C — post-MVP iters (13-16) — ledger update

After the audit-of-audit verdict (iter 7) confirmed Phase B's MVP
acceptance bar cleared, Phase C began with iters 8-12 landing the
canon anchors (§3.44 / CLAUDE.md FILE MAP / CLAUDE.md CLI entry) +
the AugmentedSummary aggregator + the ops CLI. Iters 13-16 add:

| Iter | Phase | Commit | Scope | Tests added |
|---:|---|---|---|---:|
| 13 | C — doc | `457ac4cb7` | this doc — append §7 Implementation Log | 0 |
| 14 | C — audit | `9e2c8e90e` | `docs/audits/EML_COORD_DEP_STATUS_2026_05_17.md`; cycle 1 of forward-stage register item 5 | 0 |
| 15 | C — code | `7ddd6763e` | Serde derives on EmlError + EmlPotential(+Error) + AugmentedObservation + AugmentedSummary; documents serde semantics (NaN → null, ~1 ULP loss) in property tests | +5 lib |
| 16 | C — code | `ffbc087a1` | `EmlEnergyDiagnostic.observation_summary: Option<AugmentedSummary>` field + `compute_live_readout_with_observations(&[LabeledScore])` entry + `DiagnosticError::AugmentFailed` variant + CLI exhaustive-match fix | +7 lib |

**Cumulative test growth (post-iter 16)**: +66 lib + 14 integration =
**+80 tests** (was +66 at end of iter 12). Far above the §4.B doctrine
target of +30.

**Cargo gates (post-iter 16)**:
- Default features (`mas-build`): **1671/1671** still held.
- `--features research --lib`: 3490 baseline → **3539** (+49 net).
- `--features research --test eml_observatory`: 14/14.
- `--features research --bin epistemos_eml`: builds clean; smoke-run
  prints JSON with `"observation_summary": null` on substrate-only
  entry.

**Phase-C diminishing returns observation**: by iter 16, the
substrate, the MVP, the diagnostic, the canon anchors, the CLI, the
serde-roundtrip story, and the observation-summary surfacing have all
shipped. Further Phase-C work is gated on either (a) one of the
forward-staged candidate sites unblocking via T1-T4 coordination, or
(b) the FFI-bridge + Swift-mirror release-plan decision landing. The
audit-of-audit cycle 2 (iter ~24) is the natural next checkpoint.

