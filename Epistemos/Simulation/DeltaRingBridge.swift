//
//  DeltaRingBridge.swift
//  Simulation Mode S4 — zero-copy SPSC ring → MTLBuffer drain.
//
//  Per DOCTRINE I-8 / IMPLEMENTATION §2.2 the per-frame delta path
//  crosses raw C ABI (`epistemos_delta_ring_drain`), NOT UniFFI.
//  This file:
//
//   - Mirrors `agent_core::ffi::PerInstanceData` byte-for-byte so
//     the MTLBuffer pointer can be bound directly to the Swift
//     struct without a copy.
//   - Declares the C-ABI drain symbol via `@_silgen_name` (matches
//     the existing `RustShadowFFIClient` pattern in this repo —
//     UniFFI doesn't bind raw `extern "C"` symbols, and we
//     deliberately bypass it on the hot path).
//   - Wraps the drain in `signpostInterval(SimSignpost.ffi,
//     "delta_drain")` so the FFI boundary timing shows up in
//     Instruments, satisfying the "<5µs p95" budget in
//     DOCTRINE §12.

import Foundation
import Metal
import OSLog

// MARK: - PerInstanceData (Rust mirror)

/// 64-byte cache-line-aligned per-companion render delta.
/// Layout MUST match `agent_core::ffi::PerInstanceData` exactly.
/// We use tuple-based `(Float, Float)` and `(Float, Float, Float,
/// Float)` rather than `SIMD2<Float>` / `SIMD4<Float>` because
/// SIMD4<Float>'s 16-byte alignment would push `tint` from offset
/// 44 (Rust [f32; 4]) to offset 48, breaking layout parity.
public struct PerInstanceData {
    public var agent_id_lo: UInt64
    public var agent_id_hi: UInt64
    public var position: (Float, Float)
    public var scale: (Float, Float)
    public var atlas_index: UInt32
    public var frame_index: UInt32
    public var palette_id: UInt32
    public var tint: (Float, Float, Float, Float)
    public var state_flags: UInt32

    public init() {
        agent_id_lo = 0
        agent_id_hi = 0
        position = (0, 0)
        scale = (0, 0)
        atlas_index = 0
        frame_index = 0
        palette_id = 0
        tint = (0, 0, 0, 0)
        state_flags = 0
    }
}

/// Runtime layout assertion. If the Rust side adds / reorders /
/// removes a field and forgets to update this Swift mirror, the
/// app fails-fast at first DeltaRingBridge construction.
@inline(__always)
private func assertPerInstanceDataLayout() {
    precondition(
        MemoryLayout<PerInstanceData>.size == 64,
        "PerInstanceData drifted from Rust layout (size != 64)"
    )
    precondition(
        MemoryLayout<PerInstanceData>.stride == 64,
        "PerInstanceData drifted from Rust layout (stride != 64)"
    )
}

// MARK: - Raw C-ABI bindings

@_silgen_name("epistemos_delta_ring_drain")
private func _epistemos_delta_ring_drain(
    _ ring: OpaquePointer,
    _ outBuffer: UnsafeMutablePointer<PerInstanceData>,
    _ capacity: UInt
) -> UInt

// MARK: - DeltaRingBridge

/// Bridges between the Rust SPSC `DeltaRing` and a persistent
/// `MTLBuffer` on the Swift side. Per DOCTRINE I-8 / I-15:
///
/// - No allocation in the per-frame `drain()` path — the MTLBuffer
///   is allocated once at init.
/// - No string-keyed dispatch — drain is a single C function call.
/// - No UniFFI on this path — UniFFI's per-call serialization tax
///   compounds at 120Hz.
public final class DeltaRingBridge {
    /// Raw `*const DeltaRing` u64 obtained via UniFFI from
    /// `epistemos_simulation_delta_ring_handle`. Valid only while
    /// the owning Simulation is alive.
    private let ringHandle: UInt64

    /// Persistent MTLBuffer backing the per-frame instance data.
    /// `.storageModeShared` so CPU writes are visible to the GPU
    /// without an explicit blit.
    public let instanceBuffer: MTLBuffer
    public let capacity: Int

    /// Last drain count — used by the renderer to skip the
    /// drawIndexedPrimitives call when the ring was empty (idle
    /// branch in DOCTRINE §12: zero draws when no events).
    public private(set) var lastDrainCount: Int = 0

    public init?(ringHandle: UInt64, device: MTLDevice, capacity: Int = 256) {
        assertPerInstanceDataLayout()
        guard ringHandle != 0 else { return nil }
        let bufferLength = capacity * MemoryLayout<PerInstanceData>.stride
        guard let buffer = device.makeBuffer(
            length: bufferLength,
            options: [.storageModeShared]
        ) else {
            return nil
        }
        buffer.label = "Simulation.PerInstanceBuffer"
        self.ringHandle = ringHandle
        self.instanceBuffer = buffer
        self.capacity = capacity
    }

    /// Drain pending deltas from the Rust ring into
    /// `instanceBuffer`. Returns the number of entries written.
    /// Wrapped in a signpost interval so Instruments observes
    /// the FFI boundary timing per DOCTRINE §12 (<5µs p95).
    @discardableResult
    public func drain() -> Int {
        signpostInterval(SimSignpost.ffi, "delta_drain") {
            guard let opaque = OpaquePointer(bitPattern: UInt(self.ringHandle)) else {
                self.lastDrainCount = 0
                return 0
            }
            let pointer = self.instanceBuffer.contents()
                .bindMemory(to: PerInstanceData.self, capacity: self.capacity)
            let n = _epistemos_delta_ring_drain(opaque, pointer, UInt(self.capacity))
            self.lastDrainCount = Int(n)
            return Int(n)
        }
    }
}
