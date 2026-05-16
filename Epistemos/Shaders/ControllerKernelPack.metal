// ControllerKernelPack.metal
//
// HELIOS V6.2 stage 5 — ControllerKernelPack 6 fused micro-kernels.
//
// HELIOS-V62-S5-METAL guard (substrate floor; not yet wired by any
// Swift dispatcher).
//
// Per `docs/fusion/helios v6.2.md` 8-stage falsifier §5 +
// `agent_core/src/helios/controller_pack.rs` (Rust CPU reference, 17 tests).
//
// **Acceptance bar:** all 6 kernels reference-equivalent vs the Rust
// CPU reference under fp32 tolerance. Dispatch overhead amortization
// is the second-order win: packing 6 small kernels into one .metal
// file lets the controller path dispatch them via a single pipeline
// load.
//
// **The 6 micro-kernels:**
//   1. scalarAddInPlace      — a[i] += scalar
//   2. scalarMulInPlace      — a[i] *= scalar
//   3. maxReduce             — out[0] = max(a)
//   4. argmaxReduce          — out[0] = argmax(a) (first-index tie-break)
//   5. copyRange             — dst[i] = src[i]
//   6. zeroFill              — a[i] = 0
//
// Reductions (max / argmax) are intentionally NOT thread-grid optimized
// here — the substrate floor matches the Rust reference's
// single-threaded semantics. The Helios V6.2 stage 5 acceptance harness
// validates correctness first; the productionalized parallel reduction
// variant lands in a subsequent iter once correctness is locked.
//
// **Gated behind:** NOT YET WIRED.
//
// Build flags: -O3 -ffast-math

#include <metal_stdlib>
using namespace metal;

kernel void scalarAddInPlace(
    device       float* a            [[buffer(0)]],
    constant     float& scalar       [[buffer(1)]],
    constant     uint&  count        [[buffer(2)]],
    uint                gid          [[thread_position_in_grid]]
) {
    if (gid >= count) return;
    a[gid] += scalar;
}

kernel void scalarMulInPlace(
    device       float* a            [[buffer(0)]],
    constant     float& scalar       [[buffer(1)]],
    constant     uint&  count        [[buffer(2)]],
    uint                gid          [[thread_position_in_grid]]
) {
    if (gid >= count) return;
    a[gid] *= scalar;
}

/// Single-threaded reduction. Dispatched as a 1-thread grid; the
/// productionalized threadgroup-shared-memory variant lands later.
kernel void maxReduce(
    device const float* a            [[buffer(0)]],
    device       float* out          [[buffer(1)]],
    constant     uint&  count        [[buffer(2)]],
    uint                gid          [[thread_position_in_grid]]
) {
    if (gid != 0 || count == 0) return;
    float best = a[0];
    for (uint i = 1u; i < count; ++i) {
        if (a[i] > best) best = a[i];
    }
    out[0] = best;
}

kernel void argmaxReduce(
    device const float* a            [[buffer(0)]],
    device       uint*  out          [[buffer(1)]],
    constant     uint&  count        [[buffer(2)]],
    uint                gid          [[thread_position_in_grid]]
) {
    if (gid != 0 || count == 0) return;
    uint best_idx = 0u;
    float best_val = a[0];
    for (uint i = 1u; i < count; ++i) {
        if (a[i] > best_val) {
            best_val = a[i];
            best_idx = i;
        }
    }
    out[0] = best_idx;
}

kernel void copyRange(
    device const float* src          [[buffer(0)]],
    device       float* dst          [[buffer(1)]],
    constant     uint&  count        [[buffer(2)]],
    uint                gid          [[thread_position_in_grid]]
) {
    if (gid >= count) return;
    dst[gid] = src[gid];
}

kernel void zeroFill(
    device       float* a            [[buffer(0)]],
    constant     uint&  count        [[buffer(1)]],
    uint                gid          [[thread_position_in_grid]]
) {
    if (gid >= count) return;
    a[gid] = 0.0f;
}
