#include <metal_stdlib>
using namespace metal;

// Research seed: packed ternary projection plus sparse COO residual island.

inline int epst_unpack_residual_trit(uint word, uint index) {
    uint bits = (word >> ((index & 0xfu) * 2u)) & 0x3u;
    return (bits == 0u) ? -1 : ((bits == 2u) ? 1 : 0);
}

kernel void ternary_proj_residual(
    device const half* x,
    device const uint* packed_weights,
    device const float* scales,
    device float* y,
    device const uint* residual_rows,
    device const uint* residual_cols,
    device const half* residual_values,
    constant uint& residual_count,
    constant uint& input_dim,
    constant uint& output_dim,
    constant uint& block_size,
    constant uint& words_per_row,
    uint row [[thread_position_in_grid]])
{
    if (row >= output_dim || block_size == 0) {
        return;
    }

    float accum = 0.0f;
    uint blocks_per_row = (input_dim + block_size - 1u) / block_size;
    uint row_offset = row * words_per_row;

    for (uint word_index = 0; word_index < words_per_row; word_index++) {
        uint word = packed_weights[row_offset + word_index];
        uint base_col = word_index * 16u;
        for (uint lane = 0; lane < 16u; lane++) {
            uint col = base_col + lane;
            if (col >= input_dim) {
                break;
            }
            int trit = epst_unpack_residual_trit(word, lane);
            if (trit != 0) {
                uint scale_index = row * blocks_per_row + col / block_size;
                accum += float(trit) * float(x[col]) * scales[scale_index];
            }
        }
    }

    for (uint idx = 0; idx < residual_count; idx++) {
        if (residual_rows[idx] == row && residual_cols[idx] < input_dim) {
            accum += float(residual_values[idx]) * float(x[residual_cols[idx]]);
        }
    }

    y[row] = accum;
}
