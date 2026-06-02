// PageGather.metal
//
// HELIOS V6.2 stage 1-2 — PageGather baseline + scatter.
//
// HELIOS-V62-S1-METAL guard (substrate floor; not yet wired by any
// Swift dispatcher).
//
// Per `docs/fusion/helios v6.2.md` 8-stage falsifier §1-§2 +
// `agent_core/src/helios/page_gather.rs` (Rust CPU reference, 12 tests).
//
// **Acceptance bar:**
//   * Stage 1 baseline: ≥ 63-73 GB/s on M2 Pro 16 GB (STREAM-on-Metal
//     reference for 256 MB working set).
//   * Stage 2 locality-aware scatter: ≥ 70% of the measured baseline
//     on the same working set at {256 MB, 512 MB} on M2 Pro 16 GB.
//     The 2026-05-27 full Fisher-Yates permutation witness is a
//     failure stressor (~6% of STREAM), not a product-green layout.
//
// **HARDWARE-BUDGET:** canonical Wave J target was M2 Max 64 GB with
// {512 MB, 1024 MB} working-set pairs. Terminal B adapts to M2 Pro
// 16 GB envelope: {256 MB, 512 MB}. Larger working sets deferred to
// the M2 Max validation path.
//
// **Block layout:** the scatter target buffer is one `device float*`
// chunk indexed by `device const uint*` index list. Substrate floor
// uses byte-for-byte equivalent layout to the Rust CPU reference so
// future falsifier harnesses can swap CPU ↔ Metal output without
// re-shaping.
//
// **Gated behind:** NOT YET WIRED — this shader ships in the .app
// bundle (compiled to default.metallib) but no Swift caller dispatches
// it until the Helios V6.2 dispatch wire-in pass. Wire-in plan
// mirrors the W12/W13/W14 sibling-kernel toggle convention in
// `Epistemos/Engine/MetalRuntimeManager.swift`.
//
// Build flags: -O3 -ffast-math

#include <metal_stdlib>
using namespace metal;

/// PageGather scatter: `out[i] = source[indices[i]]`.
///
/// One thread per output element. Maximum throughput when indices are
/// sequential (degenerates to memcpy). Full-coverage random indices are
/// correctness stressors; they require a future locality-aware schedule
/// before this shader can clear the ≥70% STREAM promotion gate.
///
/// NOT YET DISPATCHED. Falsifier harness will run STREAM-on-Metal
/// baseline first, then this kernel with sequential indices (stage 1)
/// and classified scatter indices (stage 2). Full random permutation
/// failures stay orange/pending until mitigated.
kernel void pageGatherScatter(
    device const float* source        [[buffer(0)]],
    device const uint*  indices       [[buffer(1)]],
    device       float* out           [[buffer(2)]],
    constant     uint&  count         [[buffer(3)]],
    uint                gid           [[thread_position_in_grid]]
) {
    if (gid >= count) {
        return;
    }
    out[gid] = source[indices[gid]];
}

/// Scheduled PageGather: `out[logicalPositions[i]] = source[indices[i]]`.
///
/// This is the product-candidate contract for locality-aware schedules:
/// callers may execute reads in source-local order while preserving the
/// caller-visible logical output positions. This kernel is deliberately
/// separate from `pageGatherScatter` so the falsifier can distinguish a
/// read-local probe from the real destination-position restore cost.
kernel void pageGatherScatterScheduled(
    device const float* source           [[buffer(0)]],
    device const uint*  indices          [[buffer(1)]],
    device const uint*  logicalPositions [[buffer(2)]],
    device       float* out              [[buffer(3)]],
    constant     uint&  count            [[buffer(4)]],
    uint                gid              [[thread_position_in_grid]]
) {
    if (gid >= count) {
        return;
    }
    out[logicalPositions[gid]] = source[indices[gid]];
}

/// Packetized scheduled PageGather:
/// `packetValues[i] = source[indices[i]]`;
/// `packetLogicalPositions[i] = logicalPositions[i]`.
///
/// This is the lean witness-coordinate variant for page recall. It keeps
/// block-sorted source locality and emits a compact packet stream instead of
/// paying random destination writes immediately. Dense restore remains a
/// separate, auditable projection step.
kernel void pageGatherPacketizeScheduled(
    device const float* source                 [[buffer(0)]],
    device const uint*  indices                [[buffer(1)]],
    device const uint*  logicalPositions       [[buffer(2)]],
    device       float* packetValues           [[buffer(3)]],
    device       uint*  packetLogicalPositions [[buffer(4)]],
    constant     uint&  count                  [[buffer(5)]],
    uint                gid                    [[thread_position_in_grid]]
) {
    if (gid >= count) {
        return;
    }
    packetValues[gid] = source[indices[gid]];
    packetLogicalPositions[gid] = logicalPositions[gid];
}

/// PageGather with per-element scale: `out[i] = source[indices[i]] * scales[i]`.
///
/// Two-input variant for the BitNet b1.58 absmean codec where each
/// gathered weight tile carries its own scale. Byte-identical to the
/// Rust `gather_with_scale` reference.
kernel void pageGatherScatterScaled(
    device const float* source        [[buffer(0)]],
    device const uint*  indices       [[buffer(1)]],
    device const float* scales        [[buffer(2)]],
    device       float* out           [[buffer(3)]],
    constant     uint&  count         [[buffer(4)]],
    uint                gid           [[thread_position_in_grid]]
) {
    if (gid >= count) {
        return;
    }
    out[gid] = source[indices[gid]] * scales[gid];
}
