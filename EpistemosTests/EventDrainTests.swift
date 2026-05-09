import Foundation
import Testing

@testable import Epistemos

/// Wave 5 follow-up source-guard for the Swift EventDrain actor +
/// in-memory ring client.
@Suite("EventDrain (Wave 5 follow-up)")
nonisolated struct EventDrainTests {

    private static func cursorMoveEvent(line: UInt32, column: UInt32) -> GraphEvent {
        var ev = GraphEvent.sentinel
        ev.kind = GraphEventKind.cursorMove.rawValue
        // Write line (u32) + column (u32) into the data tuple's first 8 bytes.
        withUnsafeMutableBytes(of: &ev.data) { ptr in
            ptr.storeBytes(of: line, toByteOffset: 0, as: UInt32.self)
            ptr.storeBytes(of: column, toByteOffset: 4, as: UInt32.self)
        }
        return ev
    }

    // MARK: - GraphEvent layout

    @Test("GraphEvent is exactly 64 bytes (matches the substrate-rt repr(C) contract)")
    func graphEventSizeMatches() {
        #expect(graphEventSize == 64,
                "GraphEvent MUST be 64 bytes total — the substrate-rt Rust side asserts size_of::<GraphEvent>() == 64 at compile time; any drift breaks the FFI bytes-equal contract")
    }

    @Test("GraphEventKind round-trips raw bytes via from(rawByte:)")
    func graphEventKindRoundTrip() {
        for kind in [
            GraphEventKind.sentinel,
            .cursorMove,
            .editDelta,
            .layoutUpdate,
            .mcpTokenChunk,
            .agentFrameTick,
        ] {
            #expect(GraphEventKind.from(rawByte: kind.rawValue) == kind)
        }
        #expect(GraphEventKind.from(rawByte: 99) == nil,
                "unknown kind bytes must return nil — forward-compat with future Rust producers")
    }

    @Test("GraphEvent typedKind decodes the discriminant byte")
    func graphEventTypedKind() {
        var ev = GraphEvent.sentinel
        ev.kind = GraphEventKind.cursorMove.rawValue
        #expect(ev.typedKind == .cursorMove)
        ev.kind = 99
        #expect(ev.typedKind == nil)
    }

    // MARK: - InMemoryEventRingClient

    @Test("In-memory client accepts pushes up to capacity then rejects")
    func inMemoryRespectsCapacity() {
        let client = InMemoryEventRingClient(capacity: 4)
        for i in 0..<4 {
            #expect(client.tryPush(Self.cursorMoveEvent(line: UInt32(i), column: 0)),
                    "push \(i) within capacity must succeed")
        }
        #expect(!client.tryPush(Self.cursorMoveEvent(line: 99, column: 0)),
                "push past capacity must fail (back-pressure)")
    }

    @Test("In-memory client preserves FIFO order on drain")
    func inMemoryFIFOOrder() {
        let client = InMemoryEventRingClient(capacity: 16)
        for i in 0..<6 {
            _ = client.tryPush(Self.cursorMoveEvent(line: UInt32(i), column: 0))
        }
        var out = Array(repeating: GraphEvent.sentinel, count: 16)
        let drained = client.drain(into: &out)
        #expect(drained == 6)
        for i in 0..<6 {
            withUnsafeBytes(of: out[i].data) { bytes in
                let line = bytes.load(fromByteOffset: 0, as: UInt32.self)
                #expect(line == UInt32(i),
                        "drained event \(i) must carry line=\(i) — FIFO order")
            }
        }
    }

    @Test("In-memory client drain returns 0 when empty + buffer is unmodified")
    func inMemoryDrainEmpty() {
        let client = InMemoryEventRingClient(capacity: 8)
        var out: [GraphEvent] = Array(repeating: GraphEvent.sentinel, count: 4)
        #expect(client.drain(into: &out) == 0)
    }

    @Test("In-memory client drain caps at the buffer size (back-pressure for the consumer)")
    func inMemoryDrainCapsAtBufferSize() {
        let client = InMemoryEventRingClient(capacity: 16)
        for i in 0..<10 {
            _ = client.tryPush(Self.cursorMoveEvent(line: UInt32(i), column: 0))
        }
        var out: [GraphEvent] = Array(repeating: GraphEvent.sentinel, count: 3)
        let drained = client.drain(into: &out)
        #expect(drained == 3,
                "drain into a smaller buffer must cap at the buffer's size")
        #expect(client.pendingApprox() == 7)
    }

    @Test("pendingApprox reflects pushes minus drains")
    func inMemoryPendingTracking() {
        let client = InMemoryEventRingClient(capacity: 16)
        for i in 0..<5 {
            _ = client.tryPush(Self.cursorMoveEvent(line: UInt32(i), column: 0))
        }
        #expect(client.pendingApprox() == 5)
        var out: [GraphEvent] = Array(repeating: GraphEvent.sentinel, count: 3)
        _ = client.drain(into: &out)
        #expect(client.pendingApprox() == 2)
    }

    @Test("In-memory event ring labels are honest fallback/test labels")
    func inMemoryClientSourceLabelsAreHonestFallbackLabels() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Engine/EventDrain.swift")

        #expect(source.contains("In-memory fallback/test client"))
        #expect(source.contains("com.epistemos.eventring.in-memory"))
        #expect(source.contains("pre-link fallback"))
        #expect(!source.contains("In-memory stub client"))
        #expect(!source.contains("eventring.stub"))
    }

    // MARK: - EventDrain actor

    @Test("EventDrain.tick drains pending events + invokes the handler per event")
    func actorTickInvokesHandler() async {
        let client = InMemoryEventRingClient(capacity: 16)
        for i in 0..<4 {
            _ = client.tryPush(Self.cursorMoveEvent(line: UInt32(i), column: 0))
        }
        let drain = EventDrain(client: client, batchSize: 16)
        let counter = TestCounter()
        let count = await drain.tick { event in
            counter.bump(line: event)
        }
        #expect(count == 4)
        #expect(counter.invocations == 4)
        let pending = await drain.pendingApprox()
        #expect(pending == 0,
                "after a full drain, pendingApprox should report zero")
    }

    @Test("EventDrain.tick returns 0 + skips the handler when no events pending")
    func actorTickEmpty() async {
        let drain = EventDrain(client: InMemoryEventRingClient(capacity: 4))
        let counter = TestCounter()
        let count = await drain.tick { _ in counter.bump() }
        #expect(count == 0)
        #expect(counter.invocations == 0)
    }

    @Test("EventDrain batchSize caps the per-tick drain count")
    func actorTickRespectsBatchSize() async {
        let client = InMemoryEventRingClient(capacity: 32)
        for i in 0..<10 {
            _ = client.tryPush(Self.cursorMoveEvent(line: UInt32(i), column: 0))
        }
        let drain = EventDrain(client: client, batchSize: 4)
        let firstCount = await drain.tick { _ in }
        #expect(firstCount == 4,
                "first tick must drain exactly batchSize=4")
        let secondCount = await drain.tick { _ in }
        #expect(secondCount == 4,
                "second tick must drain another 4")
        let thirdCount = await drain.tick { _ in }
        #expect(thirdCount == 2,
                "third tick must drain the remaining 2")
        let fourthCount = await drain.tick { _ in }
        #expect(fourthCount == 0,
                "fourth tick must return 0 — ring is empty")
    }
}

nonisolated private final class TestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _invocations: Int = 0
    var invocations: Int {
        lock.lock(); defer { lock.unlock() }
        return _invocations
    }
    func bump(line _: GraphEvent? = nil) {
        lock.lock(); defer { lock.unlock() }
        _invocations += 1
    }
}
