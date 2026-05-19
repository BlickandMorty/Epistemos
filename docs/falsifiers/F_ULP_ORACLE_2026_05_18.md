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
`adversarial_fixture_count = 20`;
`adversarial_fixture_fingerprint =
207fffdef0c46b4d25e2568c2b8681b757c458f4de7cfcf9f3ea9e0b41afad19`;
`adversarial_reference_stats = { finite_count = 12, rejected_count = 8 }`;
`adversarial_reference_fingerprint =
6a008162a85703828be3de70fd1268defeeb3ed44f389dc2bff034f0bf27d8c7`;
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

The 20 adversarial fixtures live outside the closed-interval acceptance grid
and witness the kernel's signed-zero, NaN, infinity, and subnormal behavior so
that the bulk ULP statistic on `[0.5, 2]` does not hide a discontinuity.

- `exp_positive_zero` / `exp_negative_zero`: probes `exp(±0) = 1` so the
  candidate cannot encode an unsigned-zero fast path that swallows the sign
  bit and rounds inconsistently against `f64::exp` rounded to binary16.
- `ln_positive_zero` / `ln_negative_zero`: probes `ln(+0)` and `ln(-0)`, the
  IEEE-defined negative-infinity branch, so the candidate is rejected if it
  silently substitutes an `fp16` MAX or clamps to a finite value.
- `ln_f64_min_positive_subnormal`: anchors the smallest positive `f64`
  subnormal `f64::from_bits(1)` to catch a candidate that flushes the input
  before computing `ln`.
- `ln_fp16_min_positive_subnormal` / `ln_fp16_max_positive_subnormal` /
  `ln_fp16_min_positive_normal`: span the fp16 subnormal / normal boundary
  for the `ln` operand so a kernel that flushes-to-zero on fp16 inputs is
  caught at the boundary.
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
