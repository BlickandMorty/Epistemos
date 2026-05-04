#include <metal_stdlib>
using namespace metal;

// Pro seed: DoRA apply kernel. Runtime dispatch remains gated by Pro envelopes.

kernel void dora_apply(
    device const half* input,
    device const half* lora_a,
    device const half* lora_b,
    device const half* magnitude,
    device const half* base,
    device half* output,
    constant uint& input_dim,
    constant uint& output_dim,
    constant uint& rank,
    uint row [[thread_position_in_grid]])
{
    if (row >= output_dim) {
        return;
    }

    float low_rank_sum = 0.0f;
    for (uint k = 0; k < rank; k++) {
        float hidden = 0.0f;
        for (uint col = 0; col < input_dim; col++) {
            hidden += float(lora_a[k * input_dim + col]) * float(input[col]);
        }
        low_rank_sum += float(lora_b[row * rank + k]) * hidden;
    }

    output[row] = half(float(base[row]) + float(magnitude[row]) * low_rank_sum);
}
