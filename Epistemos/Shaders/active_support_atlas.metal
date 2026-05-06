// active_support_atlas.metal
//
// HELIOS V5 W6 — Active-Support Atlas indexing (Tier-1 ULP-equivalent).
//
// HELIOS-W6-METAL guard
//
// Per docs/HELIOS_V5_DOC_6_THEOREM_CANON.md §1+§2 H3 +
// `agent_core/src/scope_rex/metal/asa_index.rs` (the Rust pure-Rust
// reference that locks BIT-IDENTICAL output under conservative-mask).
//
// **Tier 1 contract:** for any conservative AsaIndex (every non-zero-
// contributing row included), the masked output is BIT-IDENTICAL to
// the dense reference matmul on M2 Max.
//
// Loaded by `Epistemos/Engine/MetalRuntimeManager.swift` once W6.b
// dispatch wiring lands. Until then this kernel ships in the .app
// bundle (compiled to default.metallib at app-build time) but no
// production caller dispatches it.
//
// Build flags applied by Xcode (release config):
//   -O3 -ffast-math

#include <metal_stdlib>
using namespace metal;

/// GPU-accelerated Active-Support Atlas masked matmul.
///
/// Inputs:
///   - input[cols] — dense input vector
///   - weights[rows * cols] — full weight matrix (row-major)
///   - active_rows[active_count] — sorted ascending active row indices
///     (BIT-IDENTICAL contract requires sorted order matching the
///      Rust BTreeSet iteration)
///   - rows, cols, active_count — shape constants
/// Output:
///   - out[rows] — masked matmul output. Inactive rows = 0.0 exactly.
///
/// One thread per active row. Each thread computes
///   out[active_rows[gid]] = Σ_c input[c] * weights[active_rows[gid] * cols + c]
/// in the SAME order as the Rust reference (c ascending) so the
/// floating-point sum is bit-identical.
kernel void asaMaskedMatmul(
    device const float* input        [[buffer(0)]],
    device const float* weights      [[buffer(1)]],
    device const uint*  active_rows  [[buffer(2)]],
    device       float* out          [[buffer(3)]],
    constant     uint&  rows         [[buffer(4)]],
    constant     uint&  cols         [[buffer(5)]],
    constant     uint&  active_count [[buffer(6)]],
    uint                gid          [[thread_position_in_grid]]
) {
    if (gid >= active_count) return;

    uint r = active_rows[gid];
    if (r >= rows) return;       // defensive bounds-check

    float acc = 0.0f;
    uint base = r * cols;
    for (uint c = 0; c < cols; ++c) {
        acc += input[c] * weights[base + c];
    }
    out[r] = acc;
}

/// Companion kernel that zeroes the output buffer before
/// asaMaskedMatmul writes per-active-row results. Inactive rows
/// stay at 0.0 exactly — preserving the Rust reference's
/// "out = vec![0.0; rows]" initialization.
kernel void zeroOutputBuffer(
    device float* out [[buffer(0)]],
    constant uint& rows [[buffer(1)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= rows) return;
    out[gid] = 0.0f;
}
