import Foundation

// MARK: - EventDrain
//
// Wave 5 follow-up of the Extended Program Plan
// (cross-ref dpp §5.3-5.6 — Swift EventDrain actor draining at frame
//  boundaries; the substrate-rt SPSC ring + FFI surface shipped in
//  W5 base [c0e09d25]).
//
// Per dpp §5.3: "Swift module map (Sources/EpistemosRT/include/) +
// EventDrain actor draining at frame boundaries."
//
// This file is the Swift side — an actor-bound consumer that calls
// `ering_drain` once per CADisplayLink tick into a stack buffer (no
// per-event boundary cost). The Rust side (substrate-rt) already
// ships the producer + ring + repr(C) GraphEvent payload.
//
// Three FFI symbols pulled in via @_silgen_name to avoid an SPM
// module-map step:
//   ering_new(capacity: usize) -> *mut EventRing
//   ering_try_push(*mut EventRing, *const GraphEvent) -> bool
//   ering_drain(*mut EventRing, *mut GraphEvent, max: usize) -> usize
//   ering_pending(*mut EventRing) -> usize
//   ering_destroy(*mut EventRing)
//
// The W5 follow-up's per-event migration (cursor moves first per
// dpp §5.4) lands the actual producer call sites; this commit
// ships the Swift consumer surface so the migration is a one-line
// drop-in at each event source.

// MARK: - GraphEventKind (mirror of substrate-rt's enum)

/// Stable u8 discriminant matching `substrate_rt::GraphEventKind`.
/// Numeric values are CONTRACTS — they cross the FFI and may end up
/// in mmap'd raw-thoughts logs (dpp §5.6).
nonisolated public enum GraphEventKind: UInt8, Sendable, Hashable {
    case sentinel = 0
    case cursorMove = 1
    case editDelta = 2
    case layoutUpdate = 3
    case mcpTokenChunk = 4
    case agentFrameTick = 5

    /// Round-trip a raw byte → typed kind. Returns `nil` for unknown
    /// values so the consumer tolerates forward-compat events from a
    /// future Rust producer.
    public static func from(rawByte: UInt8) -> GraphEventKind? {
        GraphEventKind(rawValue: rawByte)
    }
}

/// Mirror of `substrate_rt::GraphEvent`. 64 bytes total, repr(C),
/// passed across the FFI as raw bytes.
@frozen
nonisolated public struct GraphEvent: Sendable, Hashable {
    public var kind: UInt8
    public var reserved0: UInt8
    public var reserved1: UInt8
    public var reserved2: UInt8
    public var reserved3: UInt8
    public var reserved4: UInt8
    public var reserved5: UInt8
    public var reserved6: UInt8
    /// 56-byte opaque payload. Each `kind` interprets these bytes
    /// per its own schema (documented in substrate-rt's GraphEventKind).
    public var data: (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    )

    public static var sentinel: GraphEvent {
        GraphEvent(
            kind: 0,
            reserved0: 0, reserved1: 0, reserved2: 0, reserved3: 0,
            reserved4: 0, reserved5: 0, reserved6: 0,
            data: (
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0
            )
        )
    }

    public init(
        kind: UInt8,
        reserved0: UInt8 = 0,
        reserved1: UInt8 = 0,
        reserved2: UInt8 = 0,
        reserved3: UInt8 = 0,
        reserved4: UInt8 = 0,
        reserved5: UInt8 = 0,
        reserved6: UInt8 = 0,
        data: (
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
        )
    ) {
        self.kind = kind
        self.reserved0 = reserved0
        self.reserved1 = reserved1
        self.reserved2 = reserved2
        self.reserved3 = reserved3
        self.reserved4 = reserved4
        self.reserved5 = reserved5
        self.reserved6 = reserved6
        self.data = data
    }

    /// Hashable + Equatable need explicit impls because Swift can't
    /// auto-derive them for a 56-tuple-payload struct.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(kind)
        withUnsafeBytes(of: data) { bytes in
            hasher.combine(bytes: UnsafeRawBufferPointer(rebasing: bytes[0..<bytes.count]))
        }
    }

    public static func == (lhs: GraphEvent, rhs: GraphEvent) -> Bool {
        if lhs.kind != rhs.kind { return false }
        return withUnsafeBytes(of: lhs.data) { l in
            withUnsafeBytes(of: rhs.data) { r in
                l.count == r.count && memcmp(l.baseAddress, r.baseAddress, l.count) == 0
            }
        }
    }

    public var typedKind: GraphEventKind? {
        GraphEventKind.from(rawByte: kind)
    }
}

// `GraphEvent` MUST be exactly 64 bytes — the substrate-rt Rust side
// asserts this at compile time via `const _: () = assert!(size_of...)`.
// We mirror the assertion here so a future @frozen edit on the Swift
// side that drifts the layout fails immediately.
nonisolated public let graphEventSize: Int = MemoryLayout<GraphEvent>.size

// MARK: - EventRingClient protocol (testability)

/// Abstract over the FFI so tests use an in-memory implementation.
nonisolated public protocol EventRingClient: Sendable {
    func tryPush(_ event: GraphEvent) -> Bool
    func drain(into buffer: inout [GraphEvent]) -> Int
    func pendingApprox() -> Int
}

// The real `RustEventRingClient` implementation that calls into the
// substrate-rt FFI lives in `RustEventRingClient.swift`, gated behind
// the `EPISTEMOS_LINK_SUBSTRATE_RT` compile flag. Until the project
// wiring links the substrate-rt cdylib, tests and pre-link paths use
// `InMemoryEventRingClient` below.

// MARK: - In-memory fallback/test client

/// Thread-safe in-memory `EventRingClient` for tests and pre-link fallback
/// paths. Mirrors the
/// substrate-rt SPSC semantics (FIFO order; full ring rejects push;
/// drain returns at most the buffer size).
nonisolated public final class InMemoryEventRingClient: EventRingClient, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.epistemos.eventring.in-memory")
    private var buffer: [GraphEvent] = []
    private let capacity: Int

    public init(capacity: Int = 1024) {
        self.capacity = capacity
    }

    public func tryPush(_ event: GraphEvent) -> Bool {
        queue.sync {
            if buffer.count >= capacity { return false }
            buffer.append(event)
            return true
        }
    }

    public func drain(into out: inout [GraphEvent]) -> Int {
        let snapshot: [GraphEvent] = queue.sync {
            let take = Swift.min(out.count, buffer.count)
            let drained = Array(buffer.prefix(take))
            buffer.removeFirst(take)
            return drained
        }
        for (i, e) in snapshot.enumerated() {
            out[i] = e
        }
        return snapshot.count
    }

    public func pendingApprox() -> Int {
        queue.sync { buffer.count }
    }
}

// MARK: - EventDrain actor

/// Actor that owns the consumer side of the ring + a stack-allocated
/// drain buffer. SwiftUI / AppKit views call `tick(handler:)` once
/// per frame; the actor drains everything available + invokes the
/// handler once per drained event.
public actor EventDrain {

    private let client: any EventRingClient
    private var buffer: [GraphEvent]

    public init(client: any EventRingClient, batchSize: Int = 256) {
        self.client = client
        self.buffer = Array(repeating: GraphEvent.sentinel, count: batchSize)
    }

    /// Drain everything pending in one batch + invoke the handler
    /// for each drained event. Returns the count drained.
    @discardableResult
    public func tick(handler: @Sendable (GraphEvent) -> Void) -> Int {
        let count = client.drain(into: &buffer)
        for i in 0..<count {
            handler(buffer[i])
        }
        return count
    }

    /// Snapshot of the producer's pending count (approximate; the
    /// real value drifts under concurrent push).
    public func pendingApprox() -> Int {
        client.pendingApprox()
    }
}

// FFI declarations live in RustEventRingClient.swift behind the
// EPISTEMOS_LINK_SUBSTRATE_RT compile flag — kept separate so this
// file compiles cleanly even when the substrate-rt cdylib isn't
// linked into the app target.
