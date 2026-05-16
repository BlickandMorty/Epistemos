// SemiseparableBlockScan.metal
//
// HELIOS V6.2 stage 6 — SemiseparableBlockScan (Mamba-2 SSD).
//
// HELIOS-V62-S6-METAL guard (substrate floor; not yet wired by any
// Swift dispatcher).
//
// Per `docs/fusion/helios v6.2.md` 8-stage falsifier §6 +
// `agent_core/src/helios/ssd_block_scan.rs` (Rust CPU reference, 10 tests).
//
// **Acceptance bar:** max |y_ref - y_kernel| ≤ 1e-3 in fp16 across
// 100 random seeds vs PyTorch `ssd_minimal.py` Listing 1 (Dao & Gu
// arXiv:2405.21060 supplement). Substrate floor lands the kernel +
// Rust reference; the Swift falsifier harness runs the 100-seed
// comparison (outside Terminal B scope for the Swift side).
//
// **Math (scalar variant, per channel):**
//   state[t] = a[t] * state[t-1] + b[t] * x[t]
//   y[t]     = c[t] * state[t]
//
// "Semiseparable" naming: the lower-triangular cumulative matrix is
// rank-1 semiseparable, which is what makes the parallel-scan trick
// in the Mamba-2 paper work. "Block" = processing multiple tokens
// per kernel launch (block_size threads per channel).
//
// **HARDWARE-BUDGET:** designed for M2 Pro 16 GB. Per-channel
// recurrence is inherently sequential along the time axis, so the
// parallelism is across channels (one thread per channel) — M2 Pro
// has 10-12 P+E cores * GPU thread issue rate, comfortable headroom
// for the typical 128-256 channel widths of Mamba-2 blocks.
//
// **Gated behind:** NOT YET WIRED. Single-threaded fallback for
// correctness-first substrate floor; the productionalized
// parallel-scan version lands in a subsequent iter once correctness
// is locked.
//
// Build flags: -O3 -ffast-math

#include <metal_stdlib>
using namespace metal;

/// Scalar SSD scan. One thread per channel; each thread walks the
/// time axis sequentially. The Rust reference is the correctness
/// oracle; this kernel must match it within fp16 tolerance.
kernel void ssdScanScalar(
    device const float* a              [[buffer(0)]],   // [T]
    device const float* b              [[buffer(1)]],   // [T]
    device const float* c              [[buffer(2)]],   // [T]
    device const float* x              [[buffer(3)]],   // [T]
    device       float* y              [[buffer(4)]],   // [T]
    device       float* final_state    [[buffer(5)]],   // scalar
    constant     float& initial_state  [[buffer(6)]],
    constant     uint&  t              [[buffer(7)]],
    uint                gid            [[thread_position_in_grid]]
) {
    // Single-channel substrate floor: gid must be 0; future per-channel
    // variant strides the buffers by channel.
    if (gid != 0) return;
    float state = initial_state;
    for (uint i = 0u; i < t; ++i) {
        state = a[i] * state + b[i] * x[i];
        y[i] = c[i] * state;
    }
    final_state[0] = state;
}
