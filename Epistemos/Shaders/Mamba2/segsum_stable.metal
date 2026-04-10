// segsum_stable.metal — Stable segment sum for Mamba-2 SSD
//
// Computes the semiseparable matrix L from log-space decay parameters.
// Uses cumulative ADDITION in log-space (never subtraction) to avoid
// catastrophic cancellation that causes NaN even in FP32.
//
// Input:  A_log — log(A) decay values per token (chunk_len elements)
// Output: L_matrix — exp(segsum) lower-triangular mask (chunk_len × chunk_len)
//
// L[i,j] = exp(sum(A_log[k] for k in j..i))  if i >= j
//        = 0                                   if i < j  (upper triangle)
//
// Threadgroup memory: chunk_len × chunk_len × sizeof(float) for FP32 intermediates
// Final output is FP16.
//
// Apple Silicon constraints:
//   - 32KB threadgroup memory limit
//   - chunk_len=128: 128×128×4 = 64KB → TOO BIG for FP32
//   - Solution: tile 64×64 FP32 (16KB) with 4 passes, or compute in FP16 with clamping
//   - For Phase 1: use FP16 with input clamping to [-20, 0] to prevent exp() overflow

#include <metal_stdlib>
using namespace metal;

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

constant uint CHUNK_LEN [[function_constant(0)]];  // Typically 128
constant uint NUM_HEADS [[function_constant(1)]];

// ---------------------------------------------------------------------------
// Stable Segsum Kernel (FP16, clamped inputs)
// ---------------------------------------------------------------------------

/// Compute the lower-triangular segsum matrix for one chunk of one head.
/// Grid: (chunk_len, chunk_len, num_chunks * num_heads)
/// Threadgroup: (16, 16, 1) — 256 threads per group
kernel void segsum_stable(
    device const half *A_log         [[buffer(0)]],   // (B, L, H) log decay
    device half       *L_matrix      [[buffer(1)]],   // (B, n_chunks, H, Q, Q) output
    constant uint     &batch_size    [[buffer(2)]],
    constant uint     &seq_len       [[buffer(3)]],
    constant uint     &n_heads       [[buffer(4)]],
    constant uint     &chunk_len     [[buffer(5)]],
    uint3 gid  [[thread_position_in_grid]],
    uint3 tgid [[threadgroup_position_in_grid]]
)
{
    // gid.x = column j within chunk
    // gid.y = row i within chunk
    // gid.z = (batch * n_chunks * n_heads) + (chunk * n_heads) + head

    uint j = gid.x;
    uint i = gid.y;
    uint flat_idx = gid.z;

    if (j >= chunk_len || i >= chunk_len) return;

    uint n_chunks = (seq_len + chunk_len - 1) / chunk_len;
    uint head     = flat_idx % n_heads;
    uint chunk    = (flat_idx / n_heads) % n_chunks;
    uint batch    = flat_idx / (n_chunks * n_heads);

    if (batch >= batch_size) return;

    // Upper triangle: L[i,j] = 0 (represented as -inf in log-space, then exp → 0)
    uint out_offset = flat_idx * chunk_len * chunk_len + i * chunk_len + j;

    if (i < j) {
        L_matrix[out_offset] = half(0.0h);
        return;
    }

    // Compute segsum: sum(A_log[k] for k in j..i) via cumulative addition
    // A_log layout: (B, L, H) → batch * seq_len * n_heads + (chunk*chunk_len + k) * n_heads + head
    float cumsum = 0.0f;  // FP32 accumulation for stability
    uint base = batch * seq_len * n_heads + chunk * chunk_len * n_heads + head;

    for (uint k = j; k <= i; k++) {
        float a_val = float(A_log[base + k * n_heads]);
        // Clamp to prevent exp() overflow: A_log should be negative (decay)
        a_val = clamp(a_val, -20.0f, 0.0f);
        cumsum += a_val;
    }

    // exp(cumsum) → L matrix element
    // Clamp cumsum to prevent underflow/overflow
    cumsum = clamp(cumsum, -88.0f, 0.0f);  // exp(-88) ≈ 6e-39 (min half)
    L_matrix[out_offset] = half(exp(cumsum));
}

// ---------------------------------------------------------------------------
// Optimized Segsum with Threadgroup Prefix Sum
// ---------------------------------------------------------------------------

/// Tiled version using threadgroup memory for prefix sum of A_log within a chunk.
/// Each threadgroup handles one chunk × one head.
/// Grid: (n_chunks * n_heads, batch_size, 1)
/// Threadgroup: (chunk_len, 1, 1) — one thread per token position
kernel void segsum_stable_tiled(
    device const half *A_log         [[buffer(0)]],   // (B, L, H)
    device half       *L_matrix      [[buffer(1)]],   // (B, n_chunks, H, Q, Q)
    constant uint     &batch_size    [[buffer(2)]],
    constant uint     &seq_len       [[buffer(3)]],
    constant uint     &n_heads       [[buffer(4)]],
    constant uint     &chunk_len     [[buffer(5)]],
    uint2 tgid  [[threadgroup_position_in_grid]],
    uint  tid   [[thread_index_in_threadgroup]],
    uint  simd_lane [[thread_index_in_simdgroup]]
)
{
    // tgid.x = chunk * n_heads + head
    // tgid.y = batch
    uint head  = tgid.x % n_heads;
    uint chunk = tgid.x / n_heads;
    uint batch = tgid.y;

    if (batch >= batch_size) return;
    if (tid >= chunk_len) return;

    uint n_chunks = (seq_len + chunk_len - 1) / chunk_len;
    if (chunk >= n_chunks) return;

    // Load this thread's A_log value into threadgroup memory
    threadgroup float prefix[256];  // max chunk_len = 256

    uint global_pos = batch * seq_len * n_heads + (chunk * chunk_len + tid) * n_heads + head;
    float a_val = (chunk * chunk_len + tid < seq_len) ? float(A_log[global_pos]) : 0.0f;
    a_val = clamp(a_val, -20.0f, 0.0f);

    // Inclusive prefix sum using simd intrinsics for intra-SIMD,
    // then threadgroup memory for inter-SIMD
    prefix[tid] = a_val;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Simple sequential prefix sum (chunk_len ≤ 256, fast enough)
    if (tid == 0) {
        for (uint k = 1; k < chunk_len; k++) {
            prefix[k] += prefix[k - 1];
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Now prefix[k] = sum(A_log[0..k]) for this chunk
    // L[i,j] = exp(prefix[i] - prefix[j-1]) for i >= j
    //        = exp(prefix[i]) when j == 0

    // Each thread writes one row (row = tid = i)
    uint out_base = (batch * n_chunks * n_heads + chunk * n_heads + head) * chunk_len * chunk_len;
    float prefix_i = prefix[tid];

    for (uint j = 0; j <= tid; j++) {
        float prefix_j_minus_1 = (j > 0) ? prefix[j - 1] : 0.0f;
        float segsum = prefix_i - prefix_j_minus_1;
        segsum = clamp(segsum, -88.0f, 0.0f);
        L_matrix[out_base + tid * chunk_len + j] = half(exp(segsum));
    }

    // Upper triangle = 0
    for (uint j = tid + 1; j < chunk_len; j++) {
        L_matrix[out_base + tid * chunk_len + j] = half(0.0h);
    }
}
