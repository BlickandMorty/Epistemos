// elementwise_ssm_helpers.metal — Elementwise utilities for Mamba-2 SSD
//
// Lightweight kernels for decay computation, output merging,
// and state buffer operations. These complement the MPS matmul
// operations used for the heavy lifting (Steps 1, 2, 4).

#include <metal_stdlib>
using namespace metal;

// ---------------------------------------------------------------------------
// Chunk State Decay — Compute decay factors for SSD Steps 2 & 4
// ---------------------------------------------------------------------------

/// Compute per-token decay factor: exp(cumsum(A_log)) for each position in chunk.
/// Used to weight the input projection (B * X) by how much each token's
/// contribution has decayed by the end of the chunk.
///
/// Input: cum_decay — cumulative log-decay from intra_chunk_scan
/// Output: decay — exp(cum_decay) elementwise, clamped
kernel void chunk_state_decay(
    device const half *cum_decay  [[buffer(0)]],  // (B, L, H) cumulative log-decay
    device half       *decay      [[buffer(1)]],  // (B, L, H) exp(cum_decay)
    constant uint     &n_elements [[buffer(2)]],  // total elements
    uint gid [[thread_position_in_grid]]
)
{
    if (gid >= n_elements) return;

    float val = float(cum_decay[gid]);
    val = clamp(val, -88.0f, 0.0f);
    decay[gid] = half(exp(val));
}

// ---------------------------------------------------------------------------
// SSD Output Merge — Y = Y_diag + Y_off (Step 1 + Step 4)
// ---------------------------------------------------------------------------

/// Combine intra-chunk output (Y_diag) with inter-chunk state contribution (Y_off).
/// Final SSD output: Y[t] = Y_diag[t] + C[t] · h_{chunk-1}
/// Both inputs and output are (B, L, D).
kernel void ssd_output_merge(
    device const half *y_diag    [[buffer(0)]],  // (B, L, D) from Step 1
    device const half *y_off     [[buffer(1)]],  // (B, L, D) from Step 4
    device half       *y_out     [[buffer(2)]],  // (B, L, D) final output
    constant uint     &n_elements [[buffer(3)]],
    uint gid [[thread_position_in_grid]]
)
{
    if (gid >= n_elements) return;
    y_out[gid] = y_diag[gid] + y_off[gid];
}

// ---------------------------------------------------------------------------
// Gated Output — SiLU gating (Mamba-2 output gate)
// ---------------------------------------------------------------------------

/// Apply SiLU gating: output = y * silu(z)
/// where silu(x) = x * sigmoid(x) = x / (1 + exp(-x))
///
/// This is the final step in the Mamba-2 block: the SSM output is
/// multiplied by the gated residual path.
kernel void silu_gate(
    device const half *y       [[buffer(0)]],  // (B, L, D) SSM output
    device const half *z       [[buffer(1)]],  // (B, L, D) gate values
    device half       *output  [[buffer(2)]],  // (B, L, D)
    constant uint     &n_elements [[buffer(3)]],
    uint gid [[thread_position_in_grid]]
)
{
    if (gid >= n_elements) return;

    float y_val = float(y[gid]);
    float z_val = float(z[gid]);

    // SiLU(z) = z * sigmoid(z)
    float sigmoid_z = 1.0f / (1.0f + exp(-z_val));
    float silu_z = z_val * sigmoid_z;

    output[gid] = half(y_val * silu_z);
}

// ---------------------------------------------------------------------------
// RMSNorm — Root Mean Square Layer Normalization
// ---------------------------------------------------------------------------

/// RMSNorm: y = x * rsqrt(mean(x^2) + eps) * weight
/// Used between Mamba-2 layers.
/// One threadgroup per (batch, token) — reduces over D dimension.
kernel void rms_norm(
    device const half *input    [[buffer(0)]],  // (B, L, D)
    device const half *weight   [[buffer(1)]],  // (D,)
    device half       *output   [[buffer(2)]],  // (B, L, D)
    constant uint     &d_model  [[buffer(3)]],
    constant float    &eps      [[buffer(4)]],
    uint2 tgid [[threadgroup_position_in_grid]],  // (token_idx, batch)
    uint  tid  [[thread_index_in_threadgroup]],
    uint  simd_lane [[thread_index_in_simdgroup]],
    uint  simd_id   [[simdgroup_index_in_threadgroup]]
)
{
    uint offset = tgid.y * d_model + tgid.x * d_model;  // flat offset to this token

    // Parallel reduction of sum(x^2) over D
    float sum_sq = 0.0f;
    for (uint d = tid; d < d_model; d += 256) {  // stride by threadgroup size
        float val = float(input[offset + d]);
        sum_sq += val * val;
    }

    // SIMD reduction
    sum_sq = simd_sum(sum_sq);

    // Cross-SIMD reduction via threadgroup memory
    threadgroup float simd_sums[8];
    if (simd_lane == 0) {
        simd_sums[simd_id] = sum_sq;
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    if (simd_id == 0 && simd_lane < 8) {
        sum_sq = simd_sums[simd_lane];
        sum_sq = simd_sum(sum_sq);
        if (simd_lane == 0) {
            simd_sums[0] = sum_sq;
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    float mean_sq = simd_sums[0] / float(d_model);
    float scale = rsqrt(mean_sq + eps);

    // Apply normalization and weight
    for (uint d = tid; d < d_model; d += 256) {
        float val = float(input[offset + d]) * scale * float(weight[d]);
        output[offset + d] = half(val);
    }
}

// ---------------------------------------------------------------------------
// State Buffer Copy — For ping-pong buffer swap
// ---------------------------------------------------------------------------

/// Copy state from one buffer to another. Used when saving snapshots
/// without disrupting the active inference state.
kernel void state_buffer_copy(
    device const half *src   [[buffer(0)]],
    device half       *dst   [[buffer(1)]],
    constant uint     &n_elements [[buffer(2)]],
    uint gid [[thread_position_in_grid]]
)
{
    if (gid >= n_elements) return;
    dst[gid] = src[gid];
}
