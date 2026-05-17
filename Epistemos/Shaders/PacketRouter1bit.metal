// PacketRouter1bit.metal
//
// HELIOS V6.2 stage 4 — PacketRouter1bit dispatch.
//
// HELIOS-V62-S4-METAL guard (substrate floor; not yet wired by any
// Swift dispatcher).
//
// Per `docs/fusion/helios v6.2.md` 8-stage falsifier §4 +
// `agent_core/src/helios/packet_router.rs` (Rust CPU reference, 10 tests).
//
// **Acceptance bar:** P99 dispatch latency < 100µs on M2 Pro 16 GB
// across a 100k-element batch. The Swift falsifier harness owns the
// measurement; this Metal kernel + its Rust CPU reference own the
// correctness contract.
//
// **Dispatch semantics:** 1 bit per input. Bit clear → `lane_0`, bit
// set → `lane_1`. Each lane is packed contiguously by atomic-counter
// allocation; original input index recorded per output slot so a
// downstream `unroute` pass can merge expert results back into the
// original batch order.
//
// **HARDWARE-BUDGET:** designed for M2 Pro 16 GB. Atomic counter
// pressure is the limiting factor at 100k-batch scale — two
// `atomic_uint` slots (one per lane) need to keep up with the
// thread-issue rate. M2 Pro 6 P-cores + 4 E-cores wired via GPU
// dispatch should hit the P99 bar with room to spare; M2 Max
// validation deferred.
//
// **Gated behind:** NOT YET WIRED — ships in the bundle but no
// Swift caller dispatches it until the Helios V6.2 stage 4 acceptance
// harness lands.
//
// Build flags: -O3 -ffast-math

#include <metal_stdlib>
using namespace metal;

/// 1-bit packet router. One thread per input element. Each thread
/// atomically reserves its slot in the destination lane via fetch_add
/// on the lane's write-counter, then writes its input value and
/// records the original index.
///
/// Output layout matches the Rust `RoutingOutputs` struct:
///   * `lane_0_values[k]` + `lane_0_orig_idx[k]` are paired.
///   * `lane_1_values[k]` + `lane_1_orig_idx[k]` are paired.
///
/// NOT YET DISPATCHED. Acceptance harness will measure P99 of one
/// kernel launch at 100k-element batch size.
kernel void packetRouter1Bit(
    device const float*    inputs            [[buffer(0)]],
    device const uchar*    bits              [[buffer(1)]],  // 0/1 per input
    device       float*    lane_0_values     [[buffer(2)]],
    device       float*    lane_1_values     [[buffer(3)]],
    device       uint*     lane_0_orig_idx   [[buffer(4)]],
    device       uint*     lane_1_orig_idx   [[buffer(5)]],
    device       atomic_uint* lane_0_count   [[buffer(6)]],
    device       atomic_uint* lane_1_count   [[buffer(7)]],
    constant     uint&     total             [[buffer(8)]],
    uint                   gid               [[thread_position_in_grid]]
) {
    if (gid >= total) {
        return;
    }
    float v = inputs[gid];
    uchar b = bits[gid];
    if (b != 0) {
        uint slot = atomic_fetch_add_explicit(lane_1_count, 1u, memory_order_relaxed);
        lane_1_values[slot] = v;
        lane_1_orig_idx[slot] = gid;
    } else {
        uint slot = atomic_fetch_add_explicit(lane_0_count, 1u, memory_order_relaxed);
        lane_0_values[slot] = v;
        lane_0_orig_idx[slot] = gid;
    }
}
