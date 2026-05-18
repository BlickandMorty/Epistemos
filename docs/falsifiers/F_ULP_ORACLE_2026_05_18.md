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
| Harness | `agent_core/src/research/eml_ir/` |
| Shader | `Epistemos/Shaders/morph_eval_reduced.metal` |
| Narrow test | From `agent_core/`: `cargo test --features research research::eml_ir` |

## Evidence

The Rust witness is emitted by `acceptance_witness_json()` and replayed by
`replay_witness_json()`. The witness records hardware metadata without serial
or UUID fields, the full fixture fingerprint, per-operation max/mean ULP, and
visible worst-case input.

The current Rust gate exercises the same float arithmetic shape used by
`morphOracleFp16` and does not claim Apple MSL §6.5.4 as a spec guarantee.
Live GPU capture remains the next hardening step before downstream schema
freezes treat Metal output itself as proven.

## Falsifier Row

| Falsifier | Lane | Tier | Status | Evidence | Missing proof | Next action |
|---|---|---|---|---|---|---|
| F-ULP-Oracle | Research | M2 Pro numeric falsifier | implemented-not-wired | `agent_core/src/research/eml_ir/`, `Epistemos/Shaders/morph_eval_reduced.metal`, `cargo test --features research research::eml_ir` | live Metal dispatch capture from `morphOracleFp16`; calibrated <=90s wall-clock run log on Jojo's M2 Pro | harden with GPU capture, subnormal/signed-zero diagnostics, WBO numerics cross-link, and Helios v3 §3.5/F7a reference |
