#include <metal_stdlib>
using namespace metal;

// ============================================================================
// dora_apply.metal
// DoRA (Weight-Decomposed Low-Rank Adaptation) apply kernel.
//
// Computes: output = base + (magnitude * (W_lora_B @ W_lora_A @ input))
//
// Where:
//   input:    [in_dim]         activation vector
//   lora_a:   [rank, in_dim]   down-projection
//   lora_b:   [out_dim, rank]  up-projection
//   magnitude:[out_dim]        learned magnitude per output
//   base:     [out_dim]        base output (precomputed, passed in)
//   output:   [out_dim]        final result
//
// Fused into single kernel:
//   1. Each thread computes one output element.
//   2. Thread first computes the low-rank inner product:
//        z = sum_k lora_b[row, k] * (sum_j lora_a[k, j] * input[j])
//   3. To avoid allocating an intermediate [rank] buffer, we expand:
//        z = sum_j input[j] * sum_k lora_b[row, k] * lora_a[k, j]
//      This is mathematically equivalent but more flops.
//   4. Alternative: compute lora_a @ input first into threadgroup memory,
//      then lora_b @ temp. We use the two-phase approach with TG scratch.
//
// Two-phase approach (chosen for better locality):
//   Phase 1 (TG): Compute h = W_A @ input into threadgroup memory [rank]
//   Phase 2:      Compute output_i = base_i + m_i * sum_k W_B[i,k] * h[k]
//
// ============================================================================

kernel void dora_apply(
    device const half* input,      // [in_dim]
    device const half* lora_a,   // [rank, in_dim]
    device const half* lora_b,   // [out_dim, rank]
    device const half* magnitude,// [out_dim]
    device const half* base,     // [out_dim] base output
    device       half* output,   // [out_dim] result
    constant     uint& in_dim,
    constant     uint& out_dim,
    constant     uint& rank,
    uint2 tid [[thread_position_in_threadgroup]],
    uint2 gid [[thread_position_in_grid]],
    uint2 tgp_size [[threads_per_threadgroup]])
{
    const uint row   = gid.x;
    const uint local = tid.x;
    const uint tpg   = tgp_size.x;

    if (row >= out_dim) return;

    // Threadgroup buffer for intermediate h = W_A @ input (shared across threadgroup)
    // Each threadgroup computes the same h, so we use a single shared array.
    // Max rank assumed <= 256 for threadgroup allocation.
    threadgroup half tg_h[256];

    // ------------------------------------------------------------------------
    // Phase 1: Compute h[k] = sum_j lora_a[k, j] * input[j]
    // All threads in threadgroup collaborate to fill tg_h[rank].
    // Each thread handles a slice of the dot product.
    // ------------------------------------------------------------------------
    for (uint k = local; k < rank; k += tpg) {
        float sum = 0.0f;
        for (uint j = 0; j < in_dim; j++) {
            sum += float(lora_a[k * in_dim + j]) * float(input[j]);
        }
        tg_h[k] = half(sum);
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // ------------------------------------------------------------------------
    // Phase 2: Compute output[row] = base[row] + magnitude[row] * sum_k lora_b[row,k] * h[k]
    // Only one thread per row writes the output; others idle.
    // We use thread 0 of each row's threadgroup to compute and write.
    // ------------------------------------------------------------------------
    if (local == 0) {
        float sum = 0.0f;
        for (uint k = 0; k < rank; k++) {
            sum += float(lora_b[row * rank + k]) * float(tg_h[k]);
        }
        float mag = float(magnitude[row]);
        float base_val = float(base[row]);
        float result = base_val + mag * sum;
        output[row] = half(result);
    }
}
