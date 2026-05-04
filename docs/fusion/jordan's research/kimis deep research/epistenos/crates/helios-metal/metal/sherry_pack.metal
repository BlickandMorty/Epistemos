#include <metal_stdlib>
using namespace metal;

// ============================================================================
// sherry_pack.metal
// Parallel Sherry 1.25-bit weight packing.
//
// Sherry quantization uses 4 levels (2 bits), packing 16 weights into u64.
// Each threadgroup handles one block of weights.
//
// Algorithm per block:
//   1. Find block min/max via threadgroup reduction.
//   2. Compute scale = (max - min) / 3.0 (4 levels: 0,1,2,3).
//   3. Each thread quantizes its assigned weights to 2 bits.
//   4. Pack 16 consecutive 2-bit weights into one uint64_t.
//
// Packing layout: 16 weights x 2 bits = 32 bits -> two uint64 per 32 weights
//                 Actually 16 weights x 2 bits = 32 bits? No.
//                 16 weights * 2 bits = 32 bits = one uint32.
//                 We pack 32 weights into one uint64 (32*2=64 bits).
//                 So 32 weights -> 1 ulong.
//
// Performance: Coalesced reads, shared reductions, ~1/16 memory write traffic.
// ============================================================================

kernel void sherry_pack_block(
    device const half* weights,    // [N] input weights
    device       ulong* packed,    // [N/32] packed output
    constant     uint& block_size,  // weights per block (must be multiple of 32)
    uint2 tid [[thread_position_in_threadgroup]],
    uint2 gid [[thread_position_in_grid]],
    uint2 tgp_size [[threads_per_threadgroup]])
{
    const uint block_id   = gid.y;          // each row of grid = one block
    const uint local_id   = tid.x;
    const uint tpg        = tgp_size.x;
    const uint block_off  = block_id * block_size;

    // Threadgroup scratch for reduction
    threadgroup half tg_min[1];
    threadgroup half tg_max[1];
    threadgroup half tg_scale[1];

    // ------------------------------------------------------------------------
    // Step 1: Find block min / max via parallel reduction
    // ------------------------------------------------------------------------
    threadgroup half s_min[1024];
    threadgroup half s_max[1024];

    half local_min = HALF_MAX;
    half local_max = -HALF_MAX;

    for (uint i = local_id; i < block_size; i += tpg) {
        half w = weights[block_off + i];
        local_min = min(local_min, w);
        local_max = max(local_max, w);
    }

    s_min[local_id] = local_min;
    s_max[local_id] = local_max;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint stride = tpg >> 1; stride > 0; stride >>= 1) {
        if (local_id < stride) {
            s_min[local_id] = min(s_min[local_id], s_min[local_id + stride]);
            s_max[local_id] = max(s_max[local_id], s_max[local_id + stride]);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (local_id == 0) {
        tg_min[0]   = s_min[0];
        tg_max[0]   = s_max[0];
        half range  = tg_max[0] - tg_min[0];
        // Guard against zero-range blocks
        tg_scale[0] = (range > 1.0e-4h) ? range / 3.0h : 1.0h;
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    const half b_min   = tg_min[0];
    const half b_scale = tg_scale[0];

    // ------------------------------------------------------------------------
    // Step 2: Quantize and pack
    // Each thread processes groups of 32 weights -> 1 ulong.
    // ------------------------------------------------------------------------
    const uint words_per_block = block_size / 32;
    for (uint widx = local_id; widx < words_per_block; widx += tpg) {
        ulong word = 0;
        uint base  = block_off + widx * 32;

        for (uint j = 0; j < 32; j++) {
            half val = weights[base + j];
            // Quantize to 4 levels [0,1,2,3]
            half norm = (val - b_min) / b_scale;
            int level = int(clamp(norm + 0.5h, 0.0h, 3.0h));
            // Pack 2-bit level into ulong
            word |= (ulong(level & 0x3) << (j * 2));
        }

        packed[block_id * words_per_block + widx] = word;
    }
}
