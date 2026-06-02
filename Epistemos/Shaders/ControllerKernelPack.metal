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
// Reductions (max / argmax) use one 256-thread threadgroup and preserve
// the Rust reference's empty-input and first-index tie-break semantics.
// The Helios V6.2 stage 5 acceptance harness validates both the contract
// and the measured p50/p99 controller timings.
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

/// Threadgroup-local reduction with Rust-reference empty semantics:
/// `max([]) = NaN`.
kernel void maxReduce(
    device const float* a            [[buffer(0)]],
    device       float* out          [[buffer(1)]],
    constant     uint&  count        [[buffer(2)]],
    uint                gid          [[thread_position_in_grid]],
    uint                lid          [[thread_index_in_threadgroup]],
    uint                groupWidth   [[threads_per_threadgroup]]
) {
    if (count == 0) {
        if (gid == 0) {
            out[0] = NAN;
        }
        return;
    }

    threadgroup float localMax[256];
    float best = -INFINITY;
    for (uint i = gid; i < count; i += groupWidth) {
        best = max(best, a[i]);
    }
    localMax[lid] = best;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint stride = groupWidth >> 1; stride > 0; stride >>= 1) {
        if (lid < stride) {
            localMax[lid] = max(localMax[lid], localMax[lid + stride]);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (lid == 0) {
        out[0] = localMax[0];
    }
}

kernel void argmaxReduce(
    device const float* a            [[buffer(0)]],
    device       uint*  out          [[buffer(1)]],
    constant     uint&  count        [[buffer(2)]],
    uint                gid          [[thread_position_in_grid]],
    uint                lid          [[thread_index_in_threadgroup]],
    uint                groupWidth   [[threads_per_threadgroup]]
) {
    if (count == 0) {
        if (gid == 0) {
            out[0] = uint(-1);
        }
        return;
    }

    threadgroup float localValue[256];
    threadgroup uint localIndex[256];
    float bestValue = -INFINITY;
    uint bestIndex = uint(-1);
    for (uint i = gid; i < count; i += groupWidth) {
        float candidate = a[i];
        if (candidate > bestValue || (candidate == bestValue && i < bestIndex)) {
            bestValue = candidate;
            bestIndex = i;
        }
    }
    localValue[lid] = bestValue;
    localIndex[lid] = bestIndex;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint stride = groupWidth >> 1; stride > 0; stride >>= 1) {
        if (lid < stride) {
            float rhsValue = localValue[lid + stride];
            uint rhsIndex = localIndex[lid + stride];
            if (rhsValue > localValue[lid] || (rhsValue == localValue[lid] && rhsIndex < localIndex[lid])) {
                localValue[lid] = rhsValue;
                localIndex[lid] = rhsIndex;
            }
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (lid == 0) {
        out[0] = localIndex[0];
    }
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
