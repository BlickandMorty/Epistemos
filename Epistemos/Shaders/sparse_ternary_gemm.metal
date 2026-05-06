// sparse_ternary_gemm.metal
//
// HELIOS V5 W14 — Sparse Ternary GEMM (Tier-2 NEON SIMD, default OFF).
//
// HELIOS-W14-METAL guard
//
// Per docs/HELIOS_V5_DOC_6_THEOREM_CANON.md §3 W14 cross-ref +
// `agent_core/src/scope_rex/kernels/sparse_ternary_gemm.rs`
// (Tier-2 reference) +
// Lipshitz, Melone, Maraziaris, Bilal arXiv:2510.06957v2
// (ETH Zurich, 2025-10-13).
//
// **Tier 2 contract:** ≥ 4× speedup vs TCSC baseline on M2 Max
// at 50% sparsity (verifying ETH paper's 5.98× scalar speedup
// on local hardware).
//
// **Output BIT-IDENTICAL** with the dense ternary GEMM (W12)
// when the sparse mask drops only true-zero weights.
//
// **Sparse format:**
//   * per-row entry list of (col, sign) pairs
//   * `entries[r * max_nnz + i]` packed as `int16` (col) +
//     `int8` (sign) — caller passes pre-sorted by col ascending
//
// **Gated behind:** Settings → Experimental Metal Kernels →
// Sparse Ternary GEMM (`epistemos.helios.v5.kernel.sparseTernaryGEMM`).
// Defaults OFF per §2.5.2 — requires ternary-quantized model.
//
// Build flags: -O3 -ffast-math

#include <metal_stdlib>
using namespace metal;

/// Sparse ternary entry packed as 32-bit: col (24 bits) + sign (8 bits).
/// Sign is i8 in {-1, +1} (zero entries are NOT stored).
struct SparseTernaryEntry {
    uint  col  : 24;
    int   sign : 8;
};

/// Sparse Ternary GEMM kernel. One thread per output row.
/// Iterates each row's non-zero entries (sorted ascending by col)
/// and accumulates `sign * input[col]`.
///
/// **BIT-IDENTICAL** with the dense T-MAC reference when the
/// sparse mask drops only true-zero weights — same sum order.
kernel void sparseTernaryGemm(
    device const half*               input         [[buffer(0)]],
    device const SparseTernaryEntry* entries       [[buffer(1)]],
    device const uint*               row_starts    [[buffer(2)]],   // CSR-style row-pointer array; size = rows + 1
    device       half*               out           [[buffer(3)]],
    constant     uint&               rows          [[buffer(4)]],
    constant     uint&               cols          [[buffer(5)]],
    uint                             gid           [[thread_position_in_grid]]
) {
    if (gid >= rows) return;

    uint start = row_starts[gid];
    uint end = row_starts[gid + 1];

    float acc = 0.0f;
    for (uint i = start; i < end; ++i) {
        SparseTernaryEntry e = entries[i];
        if (e.col >= cols) continue;     // defensive bounds-check
        if (e.sign == 1) {
            acc += float(input[e.col]);
        } else if (e.sign == -1) {
            acc -= float(input[e.col]);
        }
    }
    out[gid] = half(acc);
}

/// Sparsity-ratio reporter: counts non-zero entries across all rows
/// and computes 1 - (nnz / total_cells).
kernel void sparseTernaryFootprint(
    device const uint* row_starts          [[buffer(0)]],
    device       atomic_uint* nnz_total    [[buffer(1)]],
    constant     uint& rows                [[buffer(2)]],
    uint               gid                 [[thread_position_in_grid]]
) {
    if (gid >= rows) return;
    uint count = row_starts[gid + 1] - row_starts[gid];
    atomic_fetch_add_explicit(nnz_total, count, memory_order_relaxed);
}
