// morph_eval_reduced.metal
//
// HELIOS V6.1 PHASE B.0 — F-ULP-Oracle (Monday priority).
//
// V6.1-B0-METAL guard (substrate floor v0.1; not yet wired by any
// Swift dispatcher).
//
// Per `docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md` §1.1 +
// `agent_core/src/research/eml/operator.rs` (Rust fp64 reference,
// 9 tests) + `ulp_oracle.rs` (smoke harness, 9 tests).
//
// **THE Monday deliverable.** AnswerPacket schema does NOT ship until
// the F-ULP-Oracle fixture (B.0.4) passes against this shader.
//
// **v0.1 scope:** only the three primitives needed for the universal
// EML grammar `S → 1 | eml(S, S)`:
//   * fp16 exp
//   * fp16 ln (positive args only; branch-cut for y ≤ 0 surfaces in
//     the Rust caller, not in the shader)
//   * fused intrinsic eml(x, y) = exp(x) − ln(y)
//
// **Acceptance bar:** ≤ 2 ULP fp16 across 412k log-sampled points in
// the closed `[0.5, 2]` interval + 2,048 stress points. The Rust
// harness owns the fp64-then-binary16 reference and the replayable
// witness; this shader owns the candidate arithmetic path.
//
// **HARDWARE-BUDGET:** Wall-clock < 90s on M2 Pro 16 GB per V6.1
// integration. Metal `exp` / `ln` intrinsics are 1-cycle latency on
// Apple GPU; the fused kernel is 2 ops + 1 sub.
//
// **Gated behind:** NOT YET WIRED.
//
// Build flags: -O3 -ffast-math (but -ffast-math compromises strict
// ULP semantics — production may need -fhonor-nans / -fhonor-infinities
// once the falsifier harness measures the discrepancy).

#include <metal_stdlib>
using namespace metal;

/// Element-wise fp16 exp.
kernel void morphExpFp16(
    device const half* x        [[buffer(0)]],
    device       half* out      [[buffer(1)]],
    constant     uint& count    [[buffer(2)]],
    uint               gid      [[thread_position_in_grid]]
) {
    if (gid >= count) return;
    out[gid] = exp(x[gid]);
}

/// Element-wise fp16 ln (caller-positive-args, validated upstream).
kernel void morphLnFp16(
    device const half* y        [[buffer(0)]],
    device       half* out      [[buffer(1)]],
    constant     uint& count    [[buffer(2)]],
    uint               gid      [[thread_position_in_grid]]
) {
    if (gid >= count) return;
    out[gid] = log(y[gid]);
}

/// Fused fp16 EML intrinsic: out[i] = exp(x[i]) − ln(y[i]).
/// The grammar primitive. F-ULP-Oracle measures this kernel's
/// output against the Rust fp64 reference; ≤ 2 ULP fp16 acceptance.
kernel void morphEmlFp16(
    device const half* x        [[buffer(0)]],
    device const half* y        [[buffer(1)]],
    device       half* out      [[buffer(2)]],
    constant     uint& count    [[buffer(3)]],
    uint               gid      [[thread_position_in_grid]]
) {
    if (gid >= count) return;
    out[gid] = exp(x[gid]) - log(y[gid]);
}

/// Combined oracle kernel for T12: one dispatch produces the three
/// fp16 candidates measured by the Rust F-ULP harness.
kernel void morphOracleFp16(
    device const half* x        [[buffer(0)]],
    device const half* y        [[buffer(1)]],
    device       half* expOut   [[buffer(2)]],
    device       half* lnOut    [[buffer(3)]],
    device       half* emlOut   [[buffer(4)]],
    constant     uint& count    [[buffer(5)]],
    uint               gid      [[thread_position_in_grid]]
) {
    if (gid >= count) return;
    float xf = float(x[gid]);
    float yf = float(y[gid]);
    float expValue = exp(xf);
    float lnValue = log(yf);
    expOut[gid] = half(expValue);
    lnOut[gid] = half(lnValue);
    emlOut[gid] = half(expValue - lnValue);
}
