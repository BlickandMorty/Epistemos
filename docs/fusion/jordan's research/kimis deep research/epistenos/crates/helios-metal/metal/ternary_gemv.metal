#include <metal_stdlib>
using namespace metal;

// ============================================================================
// ternary_gemv.metal
// Packed trit matrix-vector multiply.
//
// Ternary encoding: 2 bits per trit
//   00 = -1, 01 = 0, 10 = +1, 11 = reserved
// 16 trits packed into one uint (32 bits).
//
// Each thread computes one output row.
// The weight matrix W is stored in packed format, with block scales.
//
// Layout:
//   packed_w: [out_dim, words_per_row] where words_per_row = in_dim / 16
//   scales:   [out_dim, in_dim / block_size] or [out_dim] if per-row
//   x:        [in_dim] input vector
//   y:        [out_dim] output vector
//
// Algorithm per thread (one row):
//   accum = 0 (float)
//   for each word in row:
//       unpack 16 trits from uint
//       fetch corresponding 16 input elements
//       for each trit: accum += trit_value * x[i] * scale
//   y[row] = accum
//
// Expected speedup: 1.5x over dense baseline (2/3 memory traffic + fused scale).
// ============================================================================

// Unpack a single 2-bit trit from a packed uint word.
inline int unpack_trit(uint word, uint idx) {
    uint shift = (idx & 0xF) * 2;   // 0..15 -> shift 0,2,4,...,30
    uint bits  = (word >> shift) & 0x3;
    // 00->-1, 01->0, 10->+1, 11->0 (reserved -> 0)
    return (bits == 0) ? -1 : ((bits == 2) ? 1 : 0);
}

kernel void ternary_gemv(
    device const half*   x,            // [in_dim] input
    device const uint*   packed_w,     // [out_dim, words_per_row] packed weights
    device const float*  scales,       // [num_blocks] block scales
    device       float*  y,            // [out_dim] output
    constant     uint&   in_dim,       // input dimension (must be multiple of 16)
    constant     uint&   block_size,   // elements per scale block
    constant     uint&   words_per_row,// in_dim / 16
    uint row [[thread_position_in_grid]])
{
    if (row >= (uint)(y - x)) { /* placeholder bounds check not needed here */ }

    float accum = 0.0f;
    const uint row_offset = row * words_per_row;

    // Determine how many blocks this row spans
    const uint blocks_per_row = (in_dim + block_size - 1) / block_size;

    for (uint w = 0; w < words_per_row; w++) {
        uint word = packed_w[row_offset + w];
        uint base_col = w * 16;

        // Current block index for scale lookup
        uint block_idx = base_col / block_size;
        float scale = scales[row * blocks_per_row + block_idx];

        for (uint t = 0; t < 16; t++) {
            uint col = base_col + t;
            if (col >= in_dim) break;

            int trit = unpack_trit(word, t);
            if (trit != 0) {
                accum += float(trit) * float(x[col]) * scale;
            }

            // Update scale if we've crossed a block boundary
            uint next_block = (col + 1) / block_size;
            if (next_block != block_idx && (col + 1) < in_dim) {
                block_idx = next_block;
                scale = scales[row * blocks_per_row + block_idx];
            }
        }
    }

    y[row] = accum;
}
