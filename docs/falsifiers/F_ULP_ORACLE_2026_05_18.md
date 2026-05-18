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
