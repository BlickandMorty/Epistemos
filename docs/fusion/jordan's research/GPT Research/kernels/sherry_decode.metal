#include <metal_stdlib>
using namespace metal;

kernel void unpack_sherry_block(
    device const uchar* codes [[buffer(0)]],
    device const float* scales [[buffer(1)]],
    device float* out [[buffer(2)]],
    constant uint& n_blocks [[buffer(3)]],
    uint block_id [[thread_position_in_grid]]) {
    if (block_id >= n_blocks) { return; }
    uchar code = codes[block_id];
    uint zero_index = uint(code >> 3);
    uint sign_pos = 0;
    for (uint i = 0; i < 4; ++i) {
        float value = 0.0f;
        if (i != zero_index) {
            bool neg = ((code >> sign_pos) & 1) == 1;
            value = neg ? -scales[block_id] : scales[block_id];
            sign_pos += 1;
        }
        out[block_id * 4 + i] = value;
    }
}

kernel void apply_arenas_bias(
    device float* residual [[buffer(0)]],
    device const float* bias [[buffer(1)]],
    constant uint& n [[buffer(2)]],
    constant float& alpha [[buffer(3)]],
    uint tid [[thread_position_in_grid]]) {
    if (tid < n) { residual[tid] += alpha * bias[tid]; }
}
