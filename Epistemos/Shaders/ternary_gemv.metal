// ternary_gemv.metal
//
// WAVE J1 KERNEL #2 — Block-scaled ternary GEMV (decode-path).
//
// HELIOS-J1-K2-METAL guard (doctrinal stub; not yet wired by any
// Swift dispatcher).
//
// Per `docs/fusion/jordan's research/ternary kernel.md`
// §"Block-scaled ternary GEMV" + `agent_core/src/research/ternary/gemv.rs`
// (CPU reference) + Ma et al. arXiv:2402.17764 (BitNet b1.58 ternary
// alphabet + absmean per-group scale) + Wei et al. arXiv:2407.00088
// (T-MAC LUT-centric GEMM — the prefill-path sibling kernel; this
// shader is its decode-path counterpart).
//
// **Wave J1 contract:** decode tok/s ≥ MLX dense fp16 baseline at
// equal model size on M2 Pro 16 GB. Per-token output bit-exact within
// fp16 tolerance vs. the Rust CPU reference (`gemv_block_scaled` —
// 12 unit tests gating the reference).
//
// **HARDWARE-BUDGET:** designed for M2 Pro 16 GB (canonical Wave J
// target was M2 Max 64 GB; this kernel adapts the block size and
// threadgroup memory footprint to the Pro's tighter envelope).
// 16-trit blocks (one u32 per block) keep threadgroup memory pressure
// modest. Bandwidth-bound on M2 Pro (≈ 200 GB/s); compute will be
// the bottleneck only on the largest projections.
//
// **Block layout (matches Rust `GemvBlock`):**
//   * `packed`      : 16 trits in one u32 (00=-1, 01=0, 10=+1, 11=reserved)
//   * `scale`       : fp32 per-block scale (BitNet b1.58 group mean)
//   * `nonzero_count`: u8 sparsity hint (currently unused by this kernel;
//                      reserved for future skip-zero specialization)
//
// **Gated behind:** NOT YET WIRED — this shader ships in the .app
// bundle (compiled to default.metallib at app-build time) but no
// production caller dispatches it until the Wave J1 dispatch path
// lands. Wire-in plan: `Epistemos/Engine/MetalRuntimeManager.swift`
// gains a `ternaryGemv(...)` entry point that mirrors the Rust
// `gemv_block_scaled` signature, gated behind a Settings →
// Experimental Metal Kernels → "Wave J1 Ternary GEMV" toggle
// (defaults OFF) per the W12/W13/W14 sibling-kernel convention.
//
// Build flags applied by Xcode (release config):
//   -O3 -ffast-math

#include <metal_stdlib>
using namespace metal;

/// Block-scaled ternary GEMV block layout. Byte-for-byte mirror of
/// the Rust `GemvBlock` struct in `agent_core/src/research/ternary/gemv.rs`.
struct TernaryGemvBlock {
    uint  packed;          // 16 trits, 2 bits each
    float scale;           // per-block fp32 scale
    uchar nonzero_count;   // sparsity hint (unused in v0)
    uchar _pad0;
    uchar _pad1;
    uchar _pad2;
};

/// Decode a single trit out of a packed u32. Reserved `0b11` slot
/// returns 0 (CPU reference surfaces an error; the shader is the hot
/// path and skips the branch — callers MUST validate packed data
/// before dispatch).
static inline float trit_value(uint packed, uint slot) {
    uint bits = (packed >> (slot * 2u)) & 0x3u;
    // 00 → -1, 01 → 0, 10 → +1, 11 → reserved (treated as 0)
    if (bits == 0u) return -1.0f;
    if (bits == 2u) return  1.0f;
    return 0.0f;
}

/// Block-scaled ternary GEMV. One thread per output row.
///
/// `output[r] = Σ_b ( blocks[r * blocks_per_row + b].scale ·
///                    Σ_{t=0..16} ( trit_value(block.packed, t) ·
///                                  input[b*16 + t] ) )`
///
/// NOT YET DISPATCHED. Reference for the Wave J1 wire-in pass.
kernel void ternaryGemv(
    device const float*              input            [[buffer(0)]],
    device const TernaryGemvBlock*   blocks           [[buffer(1)]],
    device       float*              output           [[buffer(2)]],
    constant     uint&               blocks_per_row   [[buffer(3)]],
    uint                             row              [[thread_position_in_grid]]
) {
    float accum = 0.0f;
    const uint row_base = row * blocks_per_row;
    for (uint b = 0u; b < blocks_per_row; ++b) {
        TernaryGemvBlock block = blocks[row_base + b];
        const uint col_base = b * 16u;
        float block_dot = 0.0f;
        for (uint t = 0u; t < 16u; ++t) {
            block_dot += trit_value(block.packed, t) * input[col_base + t];
        }
        accum += block.scale * block_dot;
    }
    output[row] = accum;
}
