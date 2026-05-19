# F-ULP Oracle - 2026-05-18

## Acceptance Bar

F-ULP-Oracle verifies the fp16 arithmetic floor for `exp`, `ln`, and
`eml(x, y) = exp(x) - ln(y)` over the closed `[0.5, 2]` interval.

| Field | Value |
|---|---|
| Lane | Research |
| Tier | M2 Pro falsifier gate |
| Hardware pin | MacBook Pro 14-inch 2023, Mac14,9, Apple M2 Pro, 12 CPU cores, 19 GPU cores, 16 GB UMA, about 200 GB/s |
| Fixture | 412,000 log-sampled points + 2,048 stress points |
| Reference | `f64::exp(x) - f64::ln(y)`, rounded to binary16 |
| Candidate | CPU float-intrinsic surrogate for `morphOracleFp16`, rounded to binary16 |
| Pass threshold | max <= 2 ULP fp16 per operation |
| Adversarial probes | Separate zero, NaN, infinity, and subnormal fixtures outside the acceptance grid |
| Harness | `agent_core/src/research/eml_ir/` |
| Shader | `Epistemos/Shaders/morph_eval_reduced.metal` |
| Narrow test | From `agent_core/`: `cargo test --features research research::eml_ir` |

## Evidence

The Rust witness is emitted by `acceptance_witness_json()` and replayed by
`replay_witness_json()`. The witness records hardware metadata without serial
or UUID fields, the full fixture fingerprint, per-operation max/mean ULP,
per-axis max/mean ULP, `budget_target_seconds = 90`,
`budget_target_millis = 90,000`,
`observed_wall_clock_millis <= budget_target_millis`, and visible worst-case
input. Current replay witness schema is `schema_version = 12`; the accepted
evaluator variant is `cpu_float_intrinsic_morph_oracle_fp16_v1`. Replay rejects
unknown JSON fields, fp64 self-reference witnesses as candidate evidence,
per-axis max-ULP jumps, operation catalog drift, axis catalog drift,
adversarial fixture drift, budget target millisecond drift, and over-budget
wall-clock claims. It pins the
`morphOracleFp16` shader entrypoint and `shader_fingerprint` alongside the
operation catalog fingerprint, per-axis catalog fingerprint, fixture
fingerprint, adversarial fixture count, adversarial fixture fingerprint,
adversarial reference finite/reject counts, and adversarial reference
fingerprint.
Current pinned fingerprints:
`operation_catalog_fingerprint =
ad8e99b40e8c673bb255cdc4dfa10905479e6d8b8a5c6f1ac47809e247b0bc37`;
`axis_catalog_fingerprint =
f0c1ec3142aafa93170de35d02e561368206e745aad481f7e32d865c5ee71537`;
`grid_fingerprint =
4a83ee96a1dffd0251307ebca42c33eb8982992a641dd641c540fd560a42bdb3`;
`adversarial_fixture_count = 23`;
`adversarial_fixture_fingerprint =
78c5d0adee288b449acebb9e16324e64e6c648ecc036a82df3bc3b5b06539339`;
`adversarial_reference_stats = { finite_count = 12, rejected_count = 11 }`;
`adversarial_reference_fingerprint =
5624f053ca313b514e32d2965434fe1a77cd1fcfaa13a0c58ebe18003c220db4`;
`shader_fingerprint =
17f0b3f9de6cf7398e54c242397b833e88a8d39b5c1b07a99085cae5717ac871`.

The current Rust gate exercises the same float arithmetic shape used by
`morphOracleFp16` and does not claim Apple MSL §6.5.4 as a spec guarantee.
Live GPU capture remains the next hardening step before downstream schema
freezes treat Metal output itself as proven.

## Falsifier Row

| Falsifier | Lane | Tier | Status | Evidence | Missing proof | Next action |
|---|---|---|---|---|---|---|
| F-ULP-Oracle | Research | M2 Pro numeric falsifier | implemented-not-wired | `agent_core/src/research/eml_ir/`, `Epistemos/Shaders/morph_eval_reduced.metal`, `cargo test --features research research::eml_ir` | live Metal dispatch capture from `morphOracleFp16` | harden with GPU capture, subnormal/signed-zero diagnostics, WBO numerics cross-link, and Helios v3 §3.5/F7a reference |

## Apple MSL Spec Posture

This terminal does not claim Apple Metal Shading Language §6.5.4 as a
verified guarantee. The MSL spec describes general intrinsic behavior for
`exp`, `log`, and related transcendental functions; this terminal treats
that as unverified until repo-local evidence (a captured `morphOracleFp16`
dispatch result over the canonical fixture grid) exists. The CPU
float-intrinsic surrogate is therefore the floor of what the kernel can
achieve, not the ceiling, and the witness explicitly distinguishes the
candidate evaluator variant from any spec-derived claim that has not been
verified by the harness in this terminal.

## Fp16 Bit Pattern Pin

The candidate output and reference output are compared at the fp16 bit
level. The local `Fp16Bits` helper carries an explicit `u16` binary16
representation, with explicit conversions to and from `f64` via the
IEEE round-to-nearest-even rule, and explicit fp16 classification
(`Zero`, `Subnormal`, `Normal`, `Infinity`, `Nan`). A candidate that ships
fp32 outputs and only casts to fp16 inside its replay path is rejected
because the witness comparison happens on the explicit `u16` pattern,
not on a floating-point compare; that closes the rounding loophole where
two fp32 values that round to the same fp16 bit pattern could appear
non-bit-equal under `==` if the witness compared at fp32 width.

## Closed Interval Semantics

The acceptance interval `[0.5, 2]` is closed at both endpoints. The
log-sampled grid pins the first input to `0.5` and the last input to `2`
exactly, so a candidate that opens the interval on either side
(`(0.5, 2)`, `[0.5, 2)`, or `(0.5, 2]`) is rejected by the
`closed_interval_edge` axis. The `0.5` endpoint is the binary representation
`0x3800` in fp16, and `2.0` is `0x4000`; the `closed_interval_edge` anchor
list explicitly includes both endpoints alongside their `± 1 ULP`
neighbors so a candidate cannot drop either endpoint without lighting up a
worst-case row pinned to that side of the interval.

## Mission Identity Pin

The witness `mission` field is the exact string `F-ULP-Oracle T12`,
pinned at the schema source.
Replay rejects a witness whose mission string drifts from that constant,
so a candidate cannot reuse the F-ULP-Oracle witness shape for a different
gate (such as F-KV-Direct or F-70B-Cocktail). The mission pin makes the
witness self-identifying without trusting an out-of-band file name or
container metadata.

## Pass Field Invariants

The witness `pass` field is `true` only when every per-operation
max-ULP maps to the `Primary` gate tier (`<= 2` fp16 ULP) and the observed
wall clock is inside the millisecond budget. Replay rejects any witness
whose `pass` field disagrees with the recomputed verdict from the per-axis
and per-operation ULP statistics, so a candidate cannot publish `pass:
true` while shipping a per-operation max that the gate tier ladder maps to
`Fallback` or `Fail`, and a candidate cannot publish `pass: false` while
hiding a passing measurement. The verdict is therefore reproducible from
the grid, the catalog, the candidate evaluator, and the recorded wall
clock; nothing else.

## Evaluator Variant Allowlist

Replay rejects any witness whose `evaluator_variant` is not
`cpu_float_intrinsic_morph_oracle_fp16_v1`. The reference evaluator
(`ReferenceRoundedEvaluator`, which is `f64::exp(x) - f64::ln(y)` rounded
to binary16) is therefore explicitly disallowed as a candidate, since a
candidate that calls itself the reference is a self-referential loop and
produces a trivially zero ULP distance against itself. Adding a future
candidate variant requires extending the allowlist in lockstep with the
schema version, so a candidate cannot smuggle a new fingerprint through by
renaming its evaluator after the fact.

## Worst-Case Witness Surface

`OperationStats` carries a `WorstCase` row for each of `exp`, `ln`, and
`eml` that pins the input `(x, y)` that produced the per-operation
worst-case ULP, the candidate fp16 output, the reference fp16 output, the
recorded ULP distance, the stress axis the worst case landed in, and the
gate tier the worst case mapped to. Replay rejects a witness whose
`WorstCase` row disagrees with the recomputed value for the same fixture
grid, so a candidate cannot publish a worst-case that does not match the
inputs it claims to have run. The witness therefore stays replayable from
the grid alone, with no hidden state, even when the worst-case input lives
inside the dense interior of the log-sampled grid.

## Adversarial Reference Stats

`adversarial_reference_stats` records `finite_count = 12` and
`rejected_count = 11` over the 23-fixture adversarial set, so a candidate
cannot collapse the rejected-by-IEEE branch (NaN inputs, signed-infinity
inputs, exact `ln(0)` branches, and so on) into a finite ULP measurement.
Replay rejects a witness whose `adversarial_reference_stats` disagree with
the recomputed deterministic reference, which guarantees that the
`finite_count` and `rejected_count` partition is itself part of the
fingerprint chain rather than an opaque pre-computed claim.

## Scope Lock and Frozen Terminals

The T12 F-ULP-Oracle lane only writes to
`agent_core/src/research/eml_ir/`,
`Epistemos/Shaders/morph_eval_reduced.metal`, and
`docs/falsifiers/F_ULP_ORACLE_2026_05_18.md`. The following neighbor
terminals are explicitly frozen for this lane and must not be edited by
F-ULP-Oracle iterations:

- `agent_core/src/research/operator_ir/` (T5 operator IR).
- `agent_core/src/research/scan_ir/` (T5 scan IR).
- `agent_core/src/research/tropical_ir/` (T5 tropical IR).
- `agent_core/src/lattice_wbo/` (T17B WBO lattice).
- `agent_core/src/acs_admission/` (T18B ACS admission).

A scope drift into any of these directories must be reverted before the
witness is re-emitted, so the F-ULP-Oracle witness can never depend on
behavior from a frozen neighbor terminal.

## Fixture Fingerprint Chain

The witness chains six SHA-256 fingerprints that the replay path
recomputes from canonical sources before any ULP comparison:

1. `operation_catalog_fingerprint` over the catalog of `(Exp, Ln, Eml)`
   plus their stable indices.
2. `axis_catalog_fingerprint` over the catalog of the five `StressAxis`
   labels plus their stable indices.
3. `grid_fingerprint` over the 412,000-log-sampled-plus-2,048-stress grid
   captured as serialized `FixtureInput` rows.
4. `adversarial_fixture_fingerprint` over the 23-element adversarial fixture
   list including each fixture's label, operation, x, and y.
5. `adversarial_reference_fingerprint` over the deterministic
   `f64`-then-rounded fp16 reference values for the adversarial set,
   including a structured rejection marker for points outside the IEEE
   finite range.
6. `shader_fingerprint` over the `Epistemos/Shaders/morph_eval_reduced.metal`
   source bytes pinned to `morphOracleFp16`.

Any fingerprint that disagrees with its canonical recomputation aborts replay
before per-axis or worst-case checks run, so a candidate cannot replay a
trusted witness payload while quietly shipping a different fixture grid,
catalog, adversarial set, reference, or shader source.

## Witness Schema Version

The witness records `schema_version = 12` and replay rejects any witness
whose `schema_version` field does not match the canonical constant
`FULP_WITNESS_SCHEMA_VERSION`. The schema-version drift surfaces before any
fingerprint check so a candidate cannot replay an old witness against a new
fixture grid by pretending the schema has not advanced; conversely, a
candidate cannot fast-forward the schema to dodge a missing field check
because every schema bump must add or remove an explicit `FulpWitness`
field that the strongly typed parse path enforces.

## Live Metal Dispatch Capture (Deferred)

The current Rust gate exercises the same float arithmetic shape that the
`morphOracleFp16` Metal kernel uses (fp32 intrinsics then `half(...)`
rounding for `exp`, `ln`, and `eml`), but it does not execute the Metal
kernel itself. Live `morphOracleFp16` dispatch capture on the M2 Pro is
deferred until the GPU evidence harness exists in this terminal; downstream
schema freezes must not treat Metal output itself as proven by the CPU
surrogate alone. The shader entrypoint and fingerprint are pinned in the
witness so that a future GPU capture lands against the exact source pinned
here; the surrogate is the floor, not the ceiling.

## Per-Axis Regression Detection

`OperationStats` records per-axis (`log_sampled`, `closed_interval_edge`,
`exp_output_midpoint`, `ln_output_midpoint`, `eml_cross_midpoint`) ULP
statistics alongside the per-operation rollup, so a regression that ships
inside a single stress axis can be flagged even when the per-operation max
stays under the threshold. Replay rejects a witness whose per-axis max-ULP
or per-axis mean-ULP drifts from the recomputed value for the same fixture
grid; a candidate that hides a regression by collapsing axis statistics is
caught before the gate tier is read.

## Replay Corruption Rejection

`replay_witness_json` parses the witness twice: once as a strongly typed
`FulpWitness` for value-level checks, once as a raw `serde_json` payload for
structural drift. A witness with a duplicate top-level key, a duplicate
nested key, an unknown top-level field, an unknown nested field,
a type mismatch (boolean where a number is expected, string where an object
is expected, and so on), an out-of-range unsigned integer for any numeric
path, a missing required field, or a stats array whose length is not the
expected three per-operation rows is rejected with a typed `FulpReplayError`
so a corruption-after-emit attack cannot pass replay even when the
high-level numbers superficially match.

## Wall-Clock Budget

The witness records `budget_target_seconds = 90` and the matching
`budget_target_millis = 90,000` so that an over-budget result is rejected by
replay even when the second-resolution and millisecond-resolution fields
disagree. `observed_wall_clock_millis` is captured per run and replay
rejects any witness whose observed wall clock exceeds the millisecond budget.
A drift in either the target seconds, the target milliseconds, or the
observed wall clock surfaces as a `budget_mismatch_kind` so a candidate that
shortens the budget to claim a pass is rejected before any ULP comparison.

## Hardware Identifier Exclusion

The witness JSON records the M2 Pro hardware pin (`MacBook Pro 14-inch 2023`,
`Mac14,9`, `Apple M2 Pro`, 12 CPU cores, 19 GPU cores, 16 GB UMA,
about 200 GB/s memory bandwidth) without serial number, software UUID,
hardware UUID, ECID, hardware UUID `hwid`, board id, `ioplatform` token,
IMEI, MEID, UDID, IDFA, IDFV, host id, Apple chip id, Apple boot nonce,
or provisioning enrollment id, and without any ethernet MAC-shaped
colon-separated hex pattern. Replay rejects a witness whose hardware pin
diverges from the M2 Pro canon, so a candidate cannot pass by claiming
different silicon while still publishing a hardware-identifying string the
canon never emits.

## Reference Methodology

Per-point ULP distance is measured against `f64::exp(x) - f64::ln(y)` rounded
to binary16. The reference is never recomputed in fp32 because the rounding
boundary moves: an fp32 reference that drifts by even one ULP relative to
fp64-then-rounded would silently widen the acceptance band and let a
non-compliant kernel through. The candidate is the CPU float-intrinsic
surrogate `cpu_float_intrinsic_morph_oracle_fp16_v1`, which exercises the
same float arithmetic shape the `morphOracleFp16` Metal kernel uses
(fp32 intrinsics then `half(...)` rounding for each of `exp`, `ln`, and
`eml`). Replay rejects a witness whose `evaluator_variant` is the fp64
reference itself, so the reference cannot be smuggled in as its own
candidate.

## ULP Gate Tier Ladder

`classify_ulp_gate` partitions per-operation max-ULP into the three gate tiers
that surface in the witness alongside the raw float. Replay rejects a witness
whose gate-tier label drifts from the recomputed tier for the same max-ULP,
so a candidate that fudges the label without moving the float cannot pass.

- `Primary`: max-ULP `<= 2`. This is the acceptance tier and the only one
  that satisfies the F-ULP-Oracle pass-threshold for the closed `[0.5, 2]`
  interval over the 414,048-point fixture grid.
- `Fallback`: max-ULP in `[3, 4]`. The candidate stays inside a degraded
  band but is no longer ship-grade; the witness still records the worst-case
  input so downstream tooling can drive an investigation without rerunning.
- `Fail`: max-ULP `>= 5`. The candidate is rejected outright; the witness is
  emitted for post-mortem but `pass` is `false` and the gate stops the lane.

## Adversarial Fixture Purposes

The 23 adversarial fixtures live outside the closed-interval acceptance grid
and witness the kernel's signed-zero, NaN, infinity, and subnormal behavior so
that the bulk ULP statistic on `[0.5, 2]` does not hide a discontinuity.

- `exp_positive_zero` / `exp_negative_zero`: probes `exp(±0) = 1` so the
  candidate cannot encode an unsigned-zero fast path that swallows the sign
  bit and rounds inconsistently against `f64::exp` rounded to binary16.
- `ln_positive_zero` / `ln_negative_zero`: probes `ln(+0)` and `ln(-0)`, the
  IEEE-defined negative-infinity branch, so the candidate is rejected if it
  silently substitutes an `fp16` MAX or clamps to a finite value.
- `ln_negative_one` / `eml_ln_negative_one`: probes an ordinary finite
  negative branch-cut input so the candidate cannot special-case only zero,
  infinity, NaN, or subnormal invalid operands.
- `ln_f64_min_positive_subnormal`: anchors the smallest positive `f64`
  subnormal `f64::from_bits(1)` to catch a candidate that flushes the input
  before computing `ln`.
- `ln_fp16_min_positive_subnormal` / `ln_fp16_max_positive_subnormal` /
  `ln_fp16_min_positive_normal`: span the fp16 subnormal / normal boundary
  for the `ln` operand so a kernel that flushes-to-zero on fp16 inputs is
  caught at the boundary.
- `ln_fp16_min_negative_subnormal`: anchors the negative fp16 subnormal
  branch for `ln` so a candidate cannot abs, clamp, or flush the invalid
  input into a finite ULP measurement.
- `nan_x` / `nan_y` / `nan_payload_x` / `nan_payload_y`: probes both quiet
  NaN inputs and explicit IEEE NaN payload bits so a candidate cannot
  silently canonicalize the NaN payload during fp16 rounding.
- `positive_infinity_y` / `negative_infinity_x`: probes the well-defined
  infinity branches of `ln` and `exp` so a candidate cannot replace either
  with a finite saturating value.
- `eml_fp16_max_positive_subnormal` / `eml_fp16_min_positive_normal`: same
  fp16 subnormal / normal boundary applied to `eml(x, y) = exp(x) - ln(y)`
  so the subtraction does not paper over a `ln` subnormal handling drift.
- `eml_ln_negative_zero` / `eml_exp_positive_zero` / `eml_exp_negative_zero`:
  combine signed-zero exact branches with `eml` so a kernel that loses the
  sign bit inside the subtraction is rejected.
- `ln_one_exact_zero`: anchors the exact `ln(1) = +0` branch so a
  candidate cannot return `-0` and pass the bulk grid.

## Stress Fixture Axes

The 2,048-point stress block is split into four axes of 512 points each, plus
the 412,000 log-sampled grid that anchors the dense interior. Each axis targets
a specific failure mode that the dense log-sampled grid cannot exercise.

- `log_sampled`: dense log-uniform sweep of 412,000 points across `[0.5, 2]`
  paired against a permuted partner; anchors the interior of the closed
  interval and bounds the bulk-case ULP statistic.
- `closed_interval_edge`: 512 stress points at the closed-interval anchors
  `0.5`, `0.5 + 1 ULP`, `2 - 1 ULP`, `2`, and the immediate neighbors;
  probes the boundary where the candidate kernel must respect the closed-set
  semantics of `[0.5, 2]`.
- `exp_output_midpoint`: 512 stress points placed at fp16 midpoints of the
  candidate `exp` output so that a single fp16 ULP slip flips the rounding
  direction.
- `ln_output_midpoint`: 512 stress points placed at fp16 midpoints of the
  candidate `ln` output for the same reason on the logarithm side.
- `eml_cross_midpoint`: 512 stress points where `exp(x)` and `ln(y)` are
  each held near fp16 midpoints so that the `eml(x, y) = exp(x) - ln(y)`
  subtraction lands inside a half-ULP catastrophic-cancellation band.

## Numerics Linkage

- WBO: `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` E4 carries the
  pre-softmax drift term `T_num`; F-ULP is the local fp16 arithmetic
  witness for that numerical-error budget, not a product feature claim.
- F-ladder: `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md`
  names F1/F7a as the expensive Metal-kernel verification work after
  KV-Direct preflight.
- Helios v3 §3.5: `docs/fusion/jordan's research/helios v3.md`
  anchors `surprise_grad_step.metal` telemetry; F-ULP remains narrower
  and only covers `exp`, `ln`, and `eml` fp16 arithmetic.
