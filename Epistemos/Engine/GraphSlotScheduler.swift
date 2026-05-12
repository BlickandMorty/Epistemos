import Foundation
import Metal

// MARK: - GraphSlotScheduler (Phase A Week 2)
//
// Canonical 3-slot ring buffer for the shared `MTLBuffer`-backed
// `GraphNodeState` array.
//
// Per `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md` §"Locked
// architectural decisions" #2 (3-slot ring with epoch-aware recycling)
// and the explicit slot states in research drop 6:
//
//   ┌──────────┐   reserveWriteSlot()   ┌────────────┐
//   │ writable │ ─────────────────────▶ │ cpuWriting │
//   └──────────┘                        └──────┬─────┘
//        ▲                                     │ markReadyForGPU(slot)
//        │                                     ▼
//   completion handler              ┌────────────┐
//   fires after GPU finishes        │ gpuReading │
//   reading this slot               └──────┬─────┘
//        │                                 │ commandBuffer.addCompletedHandler
//        └─────────────────────────────────┘
//
// Invariants enforced by this scheduler:
//   1. One writer per slot at a time (CPU writes only when state == .writable)
//   2. CPU can never re-use a slot the GPU is still reading
//   3. Recycle happens automatically via addCompletedHandler — no manual
//      bookkeeping in the frame loop
//   4. Versions are monotonically increasing per-slot so consumers can
//      detect skipped frames
//
// Per the canonical plan: this is the safety pattern that prevents
// the most common race in the architecture (CPU mutates shared buffer
// while GPU is still reading it, producing torn positions / NaNs /
// flickers). The state machine makes the invariant violation impossible
// to express — `reserveWriteSlot()` simply returns nil if no slot is
// `.writable`, forcing the caller to skip the frame instead of writing
// into a slot the GPU is using.

@MainActor
public final class GraphSlotScheduler {

    public enum SlotState: String, Sendable {
        case writable
        case cpuWriting
        case gpuReading
    }

    public struct SlotReservation: Sendable {
        public let index: Int
        public let version: UInt64
    }

    private struct SlotMeta {
        var version: UInt64
        var state: SlotState
    }

    nonisolated public static let canonicalSlotCount: Int = 3

    private let slotCount: Int
    private var meta: [SlotMeta]
    private var nextWriteSearchIndex: Int

    public init(slotCount: Int = GraphSlotScheduler.canonicalSlotCount) {
        precondition(slotCount >= 2, "GraphSlotScheduler requires at least 2 slots; ring with N=1 cannot pipeline")
        precondition(slotCount <= 4, "GraphSlotScheduler caps at 4 slots; matches graph-engine Rust ring capacity")
        self.slotCount = slotCount
        self.meta = (0..<slotCount).map { _ in SlotMeta(version: 0, state: .writable) }
        self.nextWriteSearchIndex = 0
    }

    // MARK: - Slot Lifecycle

    /// Reserve a slot for CPU writing. Returns nil if every slot is
    /// either currently being CPU-written or held by the GPU — in that
    /// case the caller MUST skip the frame; writing anyway would race.
    ///
    /// Round-robins through slots starting at `nextWriteSearchIndex`
    /// so consecutive reservations don't all funnel into slot 0 and
    /// thrash the GPU's read cache.
    public func reserveWriteSlot() -> SlotReservation? {
        for offset in 0..<slotCount {
            let idx = (nextWriteSearchIndex + offset) % slotCount
            if meta[idx].state == .writable {
                meta[idx].state = .cpuWriting
                meta[idx].version &+= 1
                nextWriteSearchIndex = (idx + 1) % slotCount
                return SlotReservation(index: idx, version: meta[idx].version)
            }
        }
        return nil
    }

    /// Mark a CPU-written slot as ready for GPU consumption. The GPU
    /// will read this slot until the command buffer completes; the
    /// recycler then flips it back to `.writable`.
    public func markReadyForGPU(_ reservation: SlotReservation) {
        let idx = reservation.index
        precondition(idx >= 0 && idx < slotCount, "slot index out of range")
        precondition(
            meta[idx].state == .cpuWriting,
            "markReadyForGPU called on slot \(idx) in unexpected state \(meta[idx].state)"
        )
        precondition(
            meta[idx].version == reservation.version,
            "markReadyForGPU version mismatch on slot \(idx): got \(reservation.version), have \(meta[idx].version)"
        )
        meta[idx].state = .gpuReading
    }

    /// Wire the recycler to fire when a command buffer finishes.
    /// Once the GPU is done with the slot, this flips its state back
    /// to `.writable` so the next frame can reuse it.
    ///
    /// Call this AFTER `markReadyForGPU` and BEFORE `commandBuffer.commit()`.
    /// Per canonical decision #30: keep compute + render on a single
    /// queue initially; this means one `addCompletedHandler` covers
    /// both passes for this slot.
    public func attachCompletion(
        _ reservation: SlotReservation,
        to commandBuffer: MTLCommandBuffer
    ) {
        let idx = reservation.index
        let version = reservation.version
        commandBuffer.addCompletedHandler { [weak self] cb in
            // The Metal completion handler fires on a background queue.
            // Capture only Sendable values (status enum) before hopping
            // back to MainActor — `cb` itself is not Sendable so we
            // can't carry it across the actor boundary in Swift 6.
            let status = cb.status
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.recycleSlot(index: idx, version: version, status: status)
            }
        }
    }

    private func recycleSlot(index: Int, version: UInt64, status: MTLCommandBufferStatus) {
        precondition(index >= 0 && index < slotCount, "recycleSlot index out of range")
        // If the slot has been bumped past `version` (shouldn't happen
        // under the ring invariants, but defensive), skip the recycle —
        // someone else has already taken control.
        guard meta[index].version == version else { return }
        // If the GPU command buffer failed, still recycle — the slot
        // is technically free; the CPU just got bad render output for
        // that frame. The render layer surfaces the GPU error separately.
        if status == .error {
            // Intentional: we still want to free the slot. A persistent
            // error is the render layer's problem, not ours.
        }
        meta[index].state = .writable
    }

    // MARK: - Observability

    /// Read the current state of a slot. Diagnostic-only; do not gate
    /// any control flow on this — use `reserveWriteSlot()` instead.
    public func state(of index: Int) -> SlotState {
        precondition(index >= 0 && index < slotCount)
        return meta[index].state
    }

    /// Read the current version of a slot. Diagnostic-only.
    public func version(of index: Int) -> UInt64 {
        precondition(index >= 0 && index < slotCount)
        return meta[index].version
    }

    /// Count of slots currently in the `.writable` state. If this hits
    /// 0, the CPU cannot reserve a new slot and must skip the frame.
    /// Useful for telemetry to detect GPU back-pressure.
    public var writableCount: Int {
        meta.lazy.filter { $0.state == .writable }.count
    }

    /// Total slot count this scheduler manages.
    public var totalSlots: Int { slotCount }
}
