// tmac_lut.metal
//
// HELIOS V5 W12 — T-MAC LUT-centric ternary GEMM (Tier-2 bundled, default OFF).
//
// HELIOS-W12-METAL guard
//
// Per docs/HELIOS_V5_DOC_6_THEOREM_CANON.md §3 W12 cross-ref +
// `agent_core/src/scope_rex/kernels/t_mac.rs` (Tier-2 reference) +
// Wei et al. arXiv:2407.00088 (T-MAC, June 2024).
//
// **Tier 2 contract:** GPU output matches the dense ternary GEMM
// reference to FP16 tolerance on 100 representative prompts.
// Speed target: 30 tok/s 1-core, 71 tok/s 8-core M2 Ultra for
// BitNet-b1.58-3B per Wei et al.; M2 Max bound is ≥ 40 tok/s on
// BitNet-b1.58-2B4T per W12 acceptance.
//
// **Gated behind:** Settings → Experimental Metal Kernels →
// T-MAC ternary path (`epistemos.helios.v5.kernel.tMac`).
// Defaults OFF per §2.5.2 — requires bundled BitNet-trained or
// ternary-quantized model file in Resources/Models/.
//
// Loaded by `Epistemos/Engine/MetalRuntimeManager.swift` once
// W12.b dispatch wiring lands. Until then this kernel ships in
// the .app bundle (compiled to default.metallib at app-build
// time) but no production caller dispatches it.
//
// Build flags applied by Xcode (release config):
//   -O3 -ffast-math

#include <metal_stdlib>
using namespace metal;

/// Pure ternary GEMM reference (no LUT trick yet).
///
/// Inputs:
///   - input[cols] — fp16 input vector
///   - weights[rows * cols] — packed ternary weights as i8 in
///     {-1, 0, +1} (caller's responsibility to maintain the
///     ternary discipline; validation lives in the Rust caller)
///   - rows, cols — shape constants
/// Output:
///   - out[rows] — per-row dot product
///
/// One thread per output row. Mirrors Rust `t_mac_reference`
/// arithmetic order (c ascending) so output is BIT-IDENTICAL.
///
/// **TODO (W12.b):** replace this dense ternary GEMM with the
/// LUT-centric trick (per Wei et al.) — precompute per-input-
/// chunk dot products against {-1, 0, +1} once, then GEMM
/// becomes a series of table lookups + ±sums. The current
/// kernel locks correctness; LUT optimization is a perf-only
/// follow-up that must preserve the BIT-IDENTICAL contract.
kernel void tmacTernaryGemm(
    device const half* input    [[buffer(0)]],
    device const char* weights  [[buffer(1)]],   // i8 ternary {-1, 0, +1}
    device       half* out      [[buffer(2)]],
    constant     uint& rows     [[buffer(3)]],
    constant     uint& cols     [[buffer(4)]],
    uint               gid      [[thread_position_in_grid]]
) {
    if (gid >= rows) return;

    uint base = gid * cols;
    float acc = 0.0f;
    for (uint c = 0; c < cols; ++c) {
        char w = weights[base + c];
        // Branch by ternary sign — 0 contributes nothing.
        if (w == 1) {
            acc += float(input[c]);
        } else if (w == -1) {
            acc -= float(input[c]);
        }
        // w == 0 falls through; contributes 0.
    }
    out[gid] = half(acc);
}

/// Companion validator: count out-of-range entries in the ternary
/// weight buffer. Mirror of Rust `validate_ternary_weights`.
/// Returns count of invalid entries via accumulator.
kernel void validateTernaryWeights(
    device const char* weights      [[buffer(0)]],
    device       atomic_uint* invalid_count [[buffer(1)]],
    constant     uint& length       [[buffer(2)]],
    uint               gid          [[thread_position_in_grid]]
) {
    if (gid >= length) return;
    char w = weights[gid];
    if (w != -1 && w != 0 && w != 1) {
        atomic_fetch_add_explicit(invalid_count, 1, memory_order_relaxed);
    }
}
