# Metal Witness Gates Preflight - 2026-05-27

Status: preflight evidence landed; `F-ULP-Oracle` full Metal primary artifact now landed; PageGather has a real 256 MB failure witness plus a locality probe; primary throughput artifacts remain pending for PageGather and ControllerKernelPack.

Branch: `codex/resume-metal-witness-gates-2026-05-27`

Follow-up branch: `codex/canonical-metal-artifact-gates-2026-05-27`

PageGather failure branch: `codex/pagegather-metal-primary-witness-2026-05-27`

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
| `F-PageGather-M2Pro` | Metal dispatch/equivalence preflight exists; `artifacts/falsifiers/page_gather/metal_failure_result.json` records a 256 MB sustained failure; `artifacts/falsifiers/page_gather/locality_probe_result.json` records a 256 MB block-sorted mitigation lead | The primary 256/512/1024 MB pass artifact is still not produced; current random-scatter layout is correct but too slow, and the locality probe is not yet wired as a product scheduler path. |
| `F-ControllerKernelPack` | Metal dispatch/equivalence preflight exists | p99 dispatch latency, sequence wall time, and full 7-size x 100-seed artifact are still not produced. |
| `F-ULP-Oracle` | `artifacts/falsifiers/ulp_oracle/result.json` is now a full Metal `morphOracleFp16` primary witness over 414,048 points / 1,242,144 evaluations | No caveat remains for this gate's Metal/oracle axis; PageGather and ControllerKernelPack remain orange/pending. |

The preflight itself did not rewrite artifacts. The follow-up Metal artifact
slice rewrote only `artifacts/falsifiers/ulp_oracle/result.json` after the full
Metal/oracle run passed. The PageGather follow-up wrote a separate failure
report, not `result.json`, because the measured ratio failed. A later
PageGather locality probe wrote a second side report proving block-sorted
locality is promising at 256 MB, but existing fallback/CPU artifacts remain the
authority for PageGather and ControllerKernelPack until their real hardware
measurement runs replace them.

## No-Orphan Check

- Motion: Project/Verify. Shader source is projected into a runtime Metal witness.
- UAS: no new UAS address shape; consumes existing falsifier names and shader paths.
- Plane: PageGather is retrieval/page plane; ControllerKernelPack is controller plane; F-ULP is verification plane.
- Residency: Apple Silicon UMA via `.storageModeShared` buffers in the test harness.
- WBO/error: failures throw test errors or write explicit failure reports; no fallback is hidden as a pass.
- Witness: Swift Testing runtime dispatch plus this audit doc.
- Falsifier: `F-ULP-Oracle` has a primary Metal artifact; `F-PageGather-M2Pro`
  and `F-ControllerKernelPack` are referenced but not fully promoted.
- Tier: `F-ULP-Oracle` is verified-floor hardware evidence; PageGather and
  ControllerKernelPack remain research / verified-floor preflight, not live product green.
- Rollback: remove the test file and restore the compile script guard if the preflight proves unstable.

## Remaining Primary Work

The next slice must generate the remaining primary hardware artifacts:

1. PageGather scheduler/kernel mitigation that turns the block-sorted locality
   probe into a product path, then reruns STREAM-on-Metal plus scatter/gather
   ratios for the documented working-set ladder.
2. ControllerKernelPack p50/p99 latency and 100-cycle sequence wall time with full fixture matrix.

Until those exist, Settings and docs must keep those throughput gates
orange/pending, not promoted to green.
