# Metal Witness Gates Preflight - 2026-05-27

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

Status: preflight evidence landed; `F-ULP-Oracle` full Metal primary artifact landed; `F-ControllerKernelPack` full Metal primary artifact landed; PageGather has a real 256 MB failure witness plus locality, scheduler, dense-restore, and packetized mitigation witnesses, and remains the open dense throughput gate.

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
| `F-PageGather-M2Pro` | Metal dispatch/equivalence preflight exists; `artifacts/falsifiers/page_gather/metal_failure_result.json` records a 256 MB sustained dense failure; `artifacts/falsifiers/page_gather/locality_probe_result.json` now records 256/512 MB packetized scheduled mitigation evidence (`0.729x` / `0.752x` STREAM, `0` sampled violations); `block_sorted_schedule` is the product-candidate schedule contract; `pageGatherScatterScheduled` verifies the dense destination-position contract; `pageGatherPacketizeScheduled` verifies the lean witness-coordinate packet path | The primary dense 256/512/1024 MB pass artifact is still not produced; dense scheduled restore is correct but too slow (`0.092x` / `0.058x` STREAM at 256/512 MB), so either caller paths must consume packetized output or dense restore must be optimized before green. |
| `F-ControllerKernelPack` | `artifacts/falsifiers/controller_kernel_pack/result.json` is now a full Metal primary witness: 7-size x 100-seed correctness, empty-input contracts, p50/p99 latency budget, and 100-cycle sequence budget all pass | No caveat remains for this gate's Metal/controller axis. |
| `F-ULP-Oracle` | `artifacts/falsifiers/ulp_oracle/result.json` is now a full Metal `morphOracleFp16` primary witness over 414,048 points / 1,242,144 evaluations | No caveat remains for this gate's Metal/oracle axis; PageGather remains orange/pending. |

The preflight itself did not rewrite artifacts. The follow-up Metal artifact
slice rewrote `artifacts/falsifiers/ulp_oracle/result.json` after the full
Metal/oracle run passed and `artifacts/falsifiers/controller_kernel_pack/result.json`
after the full ControllerKernelPack Metal run passed. The PageGather follow-up
wrote a separate failure report, not `result.json`, because the measured ratio
failed. A later PageGather locality probe wrote a second side report proving
block-sorted read-locality is promising, the scheduler contract exists on the
Rust/trace side, the Metal destination-position kernel now preserves logical
output order, and the packetized scheduled path crosses the `0.70x` floor at
the 256/512 MB M2 Pro envelope. Existing fallback/CPU artifacts remain the
authority for dense PageGather until its real hardware measurement run replaces
them or a caller-path packetized consumption witness is added.
ControllerKernelPack is now promoted by its primary Metal witness.

## No-Orphan Check

- Motion: Project/Verify. Shader source is projected into a runtime Metal witness.
- UAS: no new UAS address shape; consumes existing falsifier names and shader paths.
- Plane: PageGather is retrieval/page plane; ControllerKernelPack is controller plane; F-ULP is verification plane.
- Residency: Apple Silicon UMA via `.storageModeShared` buffers in the test harness.
- WBO/error: failures throw test errors or write explicit failure reports; no fallback is hidden as a pass.
- Witness: Swift Testing runtime dispatch plus this audit doc.
- Falsifier: `F-ULP-Oracle` and `F-ControllerKernelPack` have primary Metal
  artifacts; `F-PageGather-M2Pro` has a packetized mitigation witness but is not
  fully promoted for dense output.
- Tier: `F-ULP-Oracle` and `F-ControllerKernelPack` are verified-floor hardware
  evidence; PageGather remains research / verified-floor mitigation evidence,
  not live product green.
- Rollback: remove the test file and restore the compile script guard if the preflight proves unstable.

## Remaining Primary Work

The next slice must generate the remaining primary hardware artifact:

1. PageGather caller-path witness for packetized `(logical_position, value)`
   consumption, or Metal optimization for dense destination-position restore,
   then rerun STREAM-on-Metal plus scatter/gather ratios for the documented
   working-set ladder.

Until that exists, Settings and docs must keep the PageGather throughput gate
orange/pending, not promoted to green.
