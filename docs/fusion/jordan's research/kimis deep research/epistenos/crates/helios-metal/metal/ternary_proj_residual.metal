#include <metal_stdlib>
using namespace metal;

// ============================================================================
// ternary_proj_residual.metal
// Fused ternary projection + sparse residual island.
//
// Computes: y = ternary_gemv(x, W_packed) + sparse_residual(x)
// where the sparse residual is in COO format: (r_rows, r_cols, r_vals).
//
// Fusing into a single kernel avoids:
//   1. Allocating an intermediate buffer for ternary GEMV output
//   2. A separate sparse-add kernel dispatch
//   3. Extra memory round-trips
//
// Algorithm per thread (one output row):
//   1. Compute ternary GEMV accumulation (same as ternary_gemv).
//   2. Iterate COO entries matching this row, add residual values.
//   3. Write final result.
//
// Performance: Fused kernel saves ~1 buffer write + 1 buffer read vs. separate.
// ============================================================================

inline int unpack_trit(uint word, uint idx) {
    uint shift = (idx & 0xF) * 2;
    uint bits  = (word >> shift) & 0x3;
    return (bits == 0) ? -1 : ((bits == 2) ? 1 : 0);
}

kernel void ternary_proj_residual(
    device const half*   x,             // [in_dim] input vector
    device const uint*   packed_w,      // [out_dim, words_per_row] packed weights
    device const float*  scales,        // block scales
    device       float*  y,             // [out_dim] output
    device const uint*   r_rows,        // [r_nnz] COO row indices
    device const uint*   r_cols,        // [r_nnz] COO col indices
    device const half*   r_vals,        // [r_nnz] COO values
    device const uint&   r_nnz,         // number of non-zeros in residual
    constant     uint&   in_dim,
    constant     uint&   block_size,
    constant     uint&   words_per_row,
    constant     uint&   out_dim,
    uint row [[thread_position_in_grid]])
{
    if (row >= out_dim) {
        return;
    }

    // ------------------------------------------------------------------------
    // Phase 1: Ternary GEMV accumulation
    // ------------------------------------------------------------------------
    float accum = 0.0f;
    const uint row_offset = row * words_per_row;
    const uint blocks_per_row = (in_dim + block_size - 1) / block_size;

    for (uint w = 0; w < words_per_row; w++) {
        uint word = packed_w[row_offset + w];
        uint base_col = w * 16;
        uint block_idx = base_col / block_size;
        float scale = scales[row * blocks_per_row + block_idx];

        for (uint t = 0; t < 16; t++) {
            uint col = base_col + t;
            if (col >= in_dim) break;

            int trit = unpack_trit(word, t);
            if (trit != 0) {
                accum += float(trit) * float(x[col]) * scale;
            }

            uint next_block = (col + 1) / block_size;
            if (next_block != block_idx && (col + 1) < in_dim) {
                block_idx = next_block;
                scale = scales[row * blocks_per_row + block_idx];
            }
        }
    }

    // ------------------------------------------------------------------------
    // Phase 2: Sparse residual island (COO scatter-add)
    // Each thread scans the COO list for entries matching its row.
    // For small residual islands this is efficient; for large ones,
    // a binary-search or CSR layout would be better (TODO).
    // ------------------------------------------------------------------------
    for (uint i = 0; i < r_nnz; i++) {
        if (r_rows[i] == row) {
            accum += float(r_vals[i]) * float(x[r_cols[i]]);
        }
    }

    // ------------------------------------------------------------------------
    // Phase 3: Write result
    // ------------------------------------------------------------------------
    y[row] = accum;
}
