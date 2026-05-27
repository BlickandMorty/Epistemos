# Metal Witness Gates Preflight - 2026-05-27

Status: preflight evidence landed; primary throughput artifacts remain pending.

Branch: `codex/resume-metal-witness-gates-2026-05-27`

## Scope

This slice advances `RESUME METAL WITNESS GATES` without overstating the hardware floor.
It adds direct Metal dispatch/equivalence tests for the source kernels that were already
present in `Epistemos/Shaders/`:

- `PageGather.metal`
- `ControllerKernelPack.metal`
- `morph_eval_reduced.metal`

The goal is to prove the kernels compile into `default.metallib`, can be dispatched on
the live Metal device, and match deterministic CPU/oracle fixtures on small inputs.

## What Changed

- `EpistemosTests/MetalWitnessGatesTests.swift`
  - Dispatches `pageGatherScatter` and `pageGatherScatterScaled`.
  - Dispatches the six `ControllerKernelPack.metal` micro-kernels.
  - Dispatches `morphOracleFp16` and checks a small fp16 ULP smoke budget.
- `Tools/metal-shader-compile/metal-shader-compile.sh`
  - Keeps the Helios deferred-kernel rail, but no longer fails merely because a
    deferred shader file exists.
  - Emits `DEFERRED ... compile smoke is not a primary M2 Pro falsifier pass`.
- `EpistemosTests/HELIOSInvariantSourceGuardTests.swift`
  - Replaces the stale "kernel must be absent" guard with a stronger anti-drift
    check: deferred kernels may be present only with witness tests and an audit note.

## Honest Status

| Gate | Current status after this slice | Not promoted to green because |
|---|---|---|
| `F-PageGather-M2Pro` | Metal dispatch/equivalence preflight exists | The 70%-of-measured-STREAM sustained bandwidth artifact is still not produced. |
| `F-ControllerKernelPack` | Metal dispatch/equivalence preflight exists | p99 dispatch latency, sequence wall time, and full 7-size x 100-seed artifact are still not produced. |
| `F-ULP-Oracle` | CPU primary witness remains; Metal `morphOracleFp16` smoke test exists | The full 414,048-point Metal-vs-oracle run and <=90s M2 Pro wall-clock artifact are still not produced. |

No falsifier artifact was rewritten by this preflight. Existing fallback/CPU artifacts remain the authority
until a real hardware measurement run replaces them.

## No-Orphan Check

- Motion: Project/Verify. Shader source is projected into a runtime Metal witness.
- UAS: no new UAS address shape; consumes existing falsifier names and shader paths.
- Plane: PageGather is retrieval/page plane; ControllerKernelPack is controller plane; F-ULP is verification plane.
- Residency: Apple Silicon UMA via `.storageModeShared` buffers in the test harness.
- WBO/error: failures throw test errors; no fallback is hidden as a pass.
- Witness: Swift Testing runtime dispatch plus this audit doc.
- Falsifier: `F-PageGather-M2Pro`, `F-ControllerKernelPack`, and `F-ULP-Oracle` are referenced but not fully promoted.
- Tier: research / verified-floor preflight, not live product green.
- Rollback: remove the test file and restore the compile script guard if the preflight proves unstable.

## Remaining Primary Work

The next slice must generate primary hardware artifacts:

1. PageGather STREAM-on-Metal baseline plus scatter/gather ratios for the documented working-set ladder.
2. ControllerKernelPack p50/p99 latency and 100-cycle sequence wall time with full fixture matrix.
3. F-ULP full Metal-vs-oracle fixture over 412,000 log-sampled points plus 2,048 stress points.

Until those exist, Settings and docs must keep these gates orange/pending, not promoted to green.
