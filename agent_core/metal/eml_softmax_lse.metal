#include <metal_stdlib>
using namespace metal;

// Core / Pro seed: stable row softmax with log-sum-exp.
// One threadgroup owns one row. Runtime integration must supply CPU golden tests.

kernel void eml_softmax_lse(
    device const half* logits,
    device half* output,
    constant uint& columns,
    uint local_id [[thread_index_in_threadgroup]],
    uint row [[threadgroup_position_in_grid]],
    uint threads_per_group [[threads_per_threadgroup]])
{
    threadgroup float scratch[1024];
    threadgroup float row_lse;

    float local_max = -INFINITY;
    for (uint col = local_id; col < columns; col += threads_per_group) {
        local_max = max(local_max, float(logits[row * columns + col]));
    }
    scratch[local_id] = local_max;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint stride = threads_per_group >> 1; stride > 0; stride >>= 1) {
        if (local_id < stride) {
            scratch[local_id] = max(scratch[local_id], scratch[local_id + stride]);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    float row_max = scratch[0];

    float local_sum = 0.0f;
    for (uint col = local_id; col < columns; col += threads_per_group) {
        local_sum += exp(float(logits[row * columns + col]) - row_max);
    }
    scratch[local_id] = local_sum;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint stride = threads_per_group >> 1; stride > 0; stride >>= 1) {
        if (local_id < stride) {
            scratch[local_id] += scratch[local_id + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (local_id == 0) {
        row_lse = log(max(scratch[0], 1.0e-20f)) + row_max;
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint col = local_id; col < columns; col += threads_per_group) {
        float probability = exp(float(logits[row * columns + col]) - row_lse);
        output[row * columns + col] = half(probability);
    }
}
