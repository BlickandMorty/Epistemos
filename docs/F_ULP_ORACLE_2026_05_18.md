# F-ULP Oracle - 2026-05-18

## Acceptance Bar

F-ULP-Oracle proves the fp16 arithmetic floor for `exp`, `ln`, and
`eml(x, y) = exp(x) - ln(y)` over the closed `[0.5, 2]` interval.

| Field | Value |
|---|---|
| Lane | Research |
| Tier | M2 Pro falsifier gate |
| Status | hidden-working research harness; implemented-not-wired product surface |
| Hardware pin | MacBook Pro 14-inch 2023, Mac14,9, Apple M2 Pro, 12 CPU cores, 19 GPU cores, 16 GB UMA, about 200 GB/s |
| Fixture | 412,000 log-stratified points + 2,048 adversarial points |
| Operations | `exp`, `ln`, `eml(x,y)` |
| Pass threshold | <= 2 ULP fp16 |
| Harness | `agent_core/src/research/fulp_oracle/` |
| Metal kernels | `Epistemos/Shaders/fulp_oracle.metal` |
| Narrow test | `cargo test -p agent_core fulp_oracle --features research` from `agent_core/` |
| Metal syntax check | `xcrun -sdk macosx metal -c Epistemos/Shaders/fulp_oracle.metal -o /tmp/fulp_oracle.air` |

## Witness Contract

The witness is replayable JSON from `FulpWitness`:

- `hardware` records the M2 Pro 16 GB UMA pin and omits serial/UUID fields.
- `budget_target_seconds` records the 90s M2 Pro floor from the acceptance bar.
- `config` freezes `412000 + 2048` points and `2` ULP tolerance.
- `grid_fingerprint` hashes every generated point index, fixture kind, axis,
  `x`, and `y`.
- `stats` records per-operation evaluated count, max ULP, mean ULP, and visible
  worst-case input.
- `acceptance_witness_json` emits the replayable JSON witness directly from the
  harness.
- `replay_witness_json` reruns the same deterministic oracle and rejects
  fingerprint, stats, or pass drift.

## Falsifier Row

| Falsifier | Purpose | Current status | Input fixture | Pass threshold | Failure meaning | Fallback route | Product lane | Evidence | Missing proof | Next action |
|---|---|---|---|---|---|---|---|---|---|---|
| F-ULP-Oracle | Arithmetic floor for fp16 `exp`, `ln`, and `eml` before AnswerPacket schema freeze | hidden-working research harness; implemented-not-wired product surface | 412k closed-interval log-stratified points + 2,048 adversarial axis fixtures | max <= 2 ULP fp16 for each operation | Metal/fp16 arithmetic cannot be used as a verified floor for downstream EML claims | keep AnswerPacket schema freeze blocked; route EML claims to CPU/reference path | Research | `agent_core/src/research/fulp_oracle/`, `Epistemos/Shaders/fulp_oracle.metal` | live Metal dispatch is not wired into the Rust witness yet | run the narrow F-ULP test, then wire a Metal capture path if this gate must measure GPU output directly |

`docs/falsifiers/` does not exist in this worktree at this iteration, so the
row is staged here in the T12 document instead of inventing a parallel handbook
owned by T23B.

## Verification Log

Current local results:

- `system_profiler SPHardwareDataType` confirmed Mac14,9, Apple M2 Pro, 12 CPU
  cores, 16 GB memory. Serial, UUID, and UDID are intentionally not copied into
  the witness.
- `cargo test -p agent_core fulp_oracle --features research` passed 19 F-ULP
  tests. The full acceptance-grid test evaluated 414,048 points for each of
  `exp`, `ln`, and `eml`; the runtime-budget assertion completed the
  acceptance oracle under the 90s target.
- `xcrun -sdk macosx metal -c Epistemos/Shaders/fulp_oracle.metal -o
  /tmp/fulp_oracle.air` passed.

Proof boundary:

- The replayable witness currently measures `cpu_reference_rounded_fp16_v1`.
- The Metal kernels are present and compile, but live GPU output capture is not
  yet part of the Rust witness. Do not promote this to a GPU-empirical pass
  until that capture path exists.
