import Foundation
import Observation

enum KnowledgeCoreDocumentFormat: UInt8, Sendable {
    case markdown = 0
    case org = 1
}

enum KnowledgeCoreSubscriptionKind: UInt8, Sendable {
    case outline = 0
    case tasks = 1
    case properties = 2
    case links = 3
}

enum KnowledgeCoreRowKind: UInt8, Sendable {
    case block = 0
    case task = 1
    case property = 2
    case link = 3
}

enum KnowledgeCoreErrorCode: UInt8, Sendable {
    case none = 0
    case invalidArgument = 1
    case ringFull = 2
    case payloadTooLarge = 3
    case ring = 4
    case missingBlock = 5
    case missingNode = 6
    case store = 7
    case outline = 8
    case serialization = 9
}

enum KnowledgeCoreBackpressurePolicy: UInt8, Sendable {
    case failFast = 0
}

struct KnowledgeCoreBridgeError: Error, Sendable, Equatable {
    let code: KnowledgeCoreErrorCode
    let message: String
}

struct KnowledgeCorePayloadSummary: Sendable, Equatable {
    let txId: UInt64
    let subscriptionId: UInt64
    let kind: KnowledgeCoreSubscriptionKind
    let addedCount: Int
    let updatedCount: Int
    let removedCount: Int
}

struct KnowledgeCoreTransportStatsSnapshot: Sendable, Equatable {
    let publishedFrames: UInt64
    let droppedFrames: UInt64
    let coalescedFrames: UInt64
    let ringFullFailures: UInt64
}

struct KnowledgeCoreRowSnapshot: Sendable, Equatable {
    let rowKind: KnowledgeCoreRowKind
    let pageId: String
    let blockId: String
    let parentId: String
    let targetId: String
    let content: String
    let propertyKey: String
    let propertyValue: String
    let taskMarker: String
    let orderKey: String
    let depth: UInt16
    let refType: UInt8
    let taskDone: Bool
}

struct KnowledgeCorePayloadSnapshot: Sendable, Equatable {
    let txId: UInt64
    let subscriptionId: UInt64
    let kind: KnowledgeCoreSubscriptionKind
    let added: [KnowledgeCoreRowSnapshot]
    let updated: [KnowledgeCoreRowSnapshot]
    let removed: [KnowledgeCoreRowSnapshot]

    var summary: KnowledgeCorePayloadSummary {
        KnowledgeCorePayloadSummary(
            txId: txId,
            subscriptionId: subscriptionId,
            kind: kind,
            addedCount: added.count,
            updatedCount: updated.count,
            removedCount: removed.count
        )
    }
}

private struct KnowledgeCoreSlotHeader {
    var len: UInt32
    var kind: UInt16
    var flags: UInt16
    var version: UInt64
}

actor KnowledgeCoreBridge {
    private nonisolated(unsafe) let core: OpaquePointer
    private let region: UnsafeMutableRawPointer
    private let regionLength: Int
    private let layout: GraphEngineRingLayout
    private var lastError: KnowledgeCoreBridgeError?

    init?(
        slotCount: UInt32 = 0,
        slotPayloadBytes: UInt32 = 0,
        peerId: UInt64 = 1
    ) {
        guard let core = graph_engine_kc_create(slotCount, slotPayloadBytes, peerId) else {
            return nil
        }

        let region = graph_engine_kc_ring_region(core)
        let layout = graph_engine_kc_ring_layout(core)
        guard let base = region.ptr,
              region.len > 0,
              layout.slot_count > 0,
              layout.slot_payload_bytes > 0 else {
            graph_engine_kc_destroy(core)
            return nil
        }

        self.core = core
        self.region = UnsafeMutableRawPointer(base)
        self.regionLength = Int(region.len)
        self.layout = layout
        self.lastError = nil
        precondition(
            layout.slot_count > 0
                && layout.slot_payload_bytes > 0
                && layout.slot_stride > 0
                && layout.slot_payload_offset >= UInt64(MemoryLayout<KnowledgeCoreSlotHeader>.size)
                && layout.tail_offset > layout.head_offset,
            "Knowledge-core ring layout is invalid"
        )
    }

    deinit {
        graph_engine_kc_destroy(core)
    }

    func subscribeOutline(pageId: String) -> UInt64? {
        let id = pageId.withCString { graph_engine_kc_subscribe_outline(core, $0) }
        return finish(id)
    }

    func subscribeTasks(pageId: String? = nil) -> UInt64? {
        let id: UInt64
        if let pageId {
            id = pageId.withCString { graph_engine_kc_subscribe_tasks(core, $0) }
        } else {
            id = graph_engine_kc_subscribe_tasks(core, nil)
        }
        return finish(id)
    }

    func subscribeProperties(pageId: String? = nil, key: String? = nil) -> UInt64? {
        let id: UInt64
        switch (pageId, key) {
        case let (.some(pageId), .some(key)):
            id = pageId.withCString { pagePtr in
                key.withCString { keyPtr in
                    graph_engine_kc_subscribe_properties(core, pagePtr, keyPtr)
                }
            }
        case let (.some(pageId), .none):
            id = pageId.withCString { graph_engine_kc_subscribe_properties(core, $0, nil) }
        case let (.none, .some(key)):
            id = key.withCString { graph_engine_kc_subscribe_properties(core, nil, $0) }
        case (.none, .none):
            id = graph_engine_kc_subscribe_properties(core, nil, nil)
        }
        return finish(id)
    }

    @discardableResult
    func unsubscribe(_ subscriptionId: UInt64) -> Bool {
        finish(graph_engine_kc_unsubscribe(core, subscriptionId) != 0)
    }

    @discardableResult
    func ingestDocument(pageId: String, format: KnowledgeCoreDocumentFormat, text: String) -> Bool {
        pageId.withCString { pagePtr in
            text.withCString { textPtr in
                finish(graph_engine_kc_ingest_document(core, pagePtr, format.rawValue, textPtr) != 0)
            }
        }
    }

    @discardableResult
    func insertBlock(
        pageId: String,
        blockId: String,
        parentId: String? = nil,
        index: UInt32,
        content: String
    ) -> Bool {
        pageId.withCString { pagePtr in
            blockId.withCString { blockPtr in
                content.withCString { contentPtr in
                    if let parentId {
                        return parentId.withCString { parentPtr in
                            finish(graph_engine_kc_insert_block(
                                core,
                                pagePtr,
                                blockPtr,
                                parentPtr,
                                index,
                                contentPtr
                            ) != 0)
                        }
                    } else {
                        return finish(graph_engine_kc_insert_block(
                            core,
                            pagePtr,
                            blockPtr,
                            nil,
                            index,
                            contentPtr
                        ) != 0)
                    }
                }
            }
        }
    }

    @discardableResult
    func moveBlock(
        pageId: String,
        blockId: String,
        parentId: String? = nil,
        index: UInt32
    ) -> Bool {
        pageId.withCString { pagePtr in
            blockId.withCString { blockPtr in
                if let parentId {
                    return parentId.withCString { parentPtr in
                        finish(graph_engine_kc_move_block(
                            core,
                            pagePtr,
                            blockPtr,
                            parentPtr,
                            index
                        ) != 0)
                    }
                } else {
                    return finish(graph_engine_kc_move_block(core, pagePtr, blockPtr, nil, index) != 0)
                }
            }
        }
    }

    @discardableResult
    func deleteBlock(pageId: String, blockId: String) -> Bool {
        pageId.withCString { pagePtr in
            blockId.withCString { blockPtr in
                finish(graph_engine_kc_delete_block(core, pagePtr, blockPtr) != 0)
            }
        }
    }

    func lastErrorSnapshot() -> KnowledgeCoreBridgeError? {
        lastError
    }

    func backpressurePolicy() -> KnowledgeCoreBackpressurePolicy {
        KnowledgeCoreBackpressurePolicy(rawValue: graph_engine_kc_backpressure_policy(core)) ?? .failFast
    }

    func transportStats() -> KnowledgeCoreTransportStatsSnapshot {
        let stats = graph_engine_kc_transport_stats(core)
        return KnowledgeCoreTransportStatsSnapshot(
            publishedFrames: stats.published_frames,
            droppedFrames: stats.dropped_frames,
            coalescedFrames: stats.coalesced_frames,
            ringFullFailures: stats.ring_full_failures
        )
    }

    func drainSummaries(limit: Int = .max) -> [KnowledgeCorePayloadSummary] {
        drain(limit: limit, decodeRows: false).summaries
    }

    func drainPayloads(limit: Int = .max) -> [KnowledgeCorePayloadSnapshot] {
        drain(limit: limit, decodeRows: true).payloads
    }

    private func drain(
        limit: Int,
        decodeRows: Bool
    ) -> (summaries: [KnowledgeCorePayloadSummary], payloads: [KnowledgeCorePayloadSnapshot]) {
        let head = graph_engine_kc_ring_head(core)
        var tail = graph_engine_kc_ring_tail(core)
        guard head > tail else { return ([], []) }

        let maxFrames = max(0, limit)
        let available = Int(min(head - tail, UInt64(maxFrames == .max ? Int.max : maxFrames)))
        guard available > 0 else { return ([], []) }

        var summaries: [KnowledgeCorePayloadSummary] = []
        var payloads: [KnowledgeCorePayloadSnapshot] = []
        summaries.reserveCapacity(available)
        if decodeRows {
            payloads.reserveCapacity(available)
        }

        while tail < head && summaries.count < maxFrames {
            guard let slot = slot(at: tail) else {
                break
            }
            guard let summary = decodeSummary(slot) else {
                break
            }
            summaries.append(summary)
            if decodeRows, let payload = decodePayload(slot, summary: summary) {
                payloads.append(payload)
            }
            tail += 1
        }

        graph_engine_kc_ring_set_tail(core, tail)
        return (summaries, payloads)
    }

    private func slot(at sequence: UInt64) -> (payload: UnsafePointer<UInt8>, len: UInt64)? {
        let slotIndex = Int(sequence % UInt64(layout.slot_count))
        let slotOffset = Int(layout.slots_offset + (UInt64(slotIndex) * layout.slot_stride))
        let payloadOffset = Int(layout.slot_payload_offset)
        guard slotOffset >= 0,
              payloadOffset >= 0,
              slotOffset + MemoryLayout<KnowledgeCoreSlotHeader>.size <= regionLength,
              slotOffset + payloadOffset <= regionLength else {
            return nil
        }

        let base = region.advanced(by: slotOffset)
        let header = base.load(as: KnowledgeCoreSlotHeader.self)
        let length = Int(header.len)
        guard length >= 0,
              length <= Int(layout.slot_payload_bytes),
              slotOffset + payloadOffset + length <= regionLength else {
            return nil
        }

        let payload = base.advanced(by: payloadOffset).assumingMemoryBound(to: UInt8.self)
        return (payload: UnsafePointer(payload), len: UInt64(length))
    }

    private func decodeSummary(
        _ slot: (payload: UnsafePointer<UInt8>, len: UInt64)
    ) -> KnowledgeCorePayloadSummary? {
        var summary = KnowledgePayloadSummaryFFI()
        guard graph_engine_kc_payload_summary(slot.payload, slot.len, &summary) != 0,
              let kind = KnowledgeCoreSubscriptionKind(rawValue: summary.kind) else {
            return nil
        }
        return KnowledgeCorePayloadSummary(
            txId: summary.tx_id,
            subscriptionId: summary.subscription_id,
            kind: kind,
            addedCount: Int(summary.added_count),
            updatedCount: Int(summary.updated_count),
            removedCount: Int(summary.removed_count)
        )
    }

    private func decodePayload(
        _ slot: (payload: UnsafePointer<UInt8>, len: UInt64),
        summary: KnowledgeCorePayloadSummary
    ) -> KnowledgeCorePayloadSnapshot? {
        KnowledgeCorePayloadSnapshot(
            txId: summary.txId,
            subscriptionId: summary.subscriptionId,
            kind: summary.kind,
            added: decodeRows(section: 0, slot: slot),
            updated: decodeRows(section: 1, slot: slot),
            removed: decodeRows(section: 2, slot: slot)
        )
    }

    private func decodeRows(
        section: UInt8,
        slot: (payload: UnsafePointer<UInt8>, len: UInt64)
    ) -> [KnowledgeCoreRowSnapshot] {
        let rowCount = graph_engine_kc_payload_row_count(slot.payload, slot.len, section)
        guard rowCount > 0 else { return [] }

        return withUnsafeTemporaryAllocation(
            of: KnowledgeQueryRowFFI.self,
            capacity: Int(rowCount)
        ) { buffer in
            guard let base = buffer.baseAddress else {
                return decodeRowsScalar(section: section, slot: slot, rowCount: rowCount)
            }
            let written = graph_engine_kc_payload_rows(
                slot.payload,
                slot.len,
                section,
                0,
                base,
                rowCount
            )
            guard written == rowCount else {
                return decodeRowsScalar(section: section, slot: slot, rowCount: rowCount)
            }

            var rows: [KnowledgeCoreRowSnapshot] = []
            rows.reserveCapacity(Int(written))
            for index in 0..<Int(written) {
                if let row = decodeRowSnapshot(buffer[index]) {
                    rows.append(row)
                }
            }
            return rows
        }
    }

    private func decodeRowsScalar(
        section: UInt8,
        slot: (payload: UnsafePointer<UInt8>, len: UInt64),
        rowCount: UInt32
    ) -> [KnowledgeCoreRowSnapshot] {
        var rows: [KnowledgeCoreRowSnapshot] = []
        rows.reserveCapacity(Int(rowCount))
        for index in 0..<rowCount {
            var row = KnowledgeQueryRowFFI()
            guard graph_engine_kc_payload_row(slot.payload, slot.len, section, index, &row) != 0,
                  let snapshot = decodeRowSnapshot(row) else {
                continue
            }
            rows.append(snapshot)
        }
        return rows
    }

    private func decodeRowSnapshot(_ row: KnowledgeQueryRowFFI) -> KnowledgeCoreRowSnapshot? {
        guard let rowKind = KnowledgeCoreRowKind(rawValue: row.row_kind) else {
            return nil
        }
        return KnowledgeCoreRowSnapshot(
            rowKind: rowKind,
            pageId: decode(row.page_id),
            blockId: decode(row.block_id),
            parentId: decode(row.parent_id),
            targetId: decode(row.target_id),
            content: decode(row.content),
            propertyKey: decode(row.property_key),
            propertyValue: decode(row.property_value),
            taskMarker: decode(row.task_marker),
            orderKey: decode(row.order_key),
            depth: row.depth,
            refType: row.ref_type,
            taskDone: row.task_done != 0
        )
    }

    private func decode(_ slice: GraphEngineStringSlice) -> String {
        guard let ptr = slice.ptr, slice.len > 0 else { return "" }
        let buffer = UnsafeBufferPointer(start: ptr, count: Int(slice.len))
        return String(decoding: buffer, as: UTF8.self)
    }

    private func finish(_ success: Bool) -> Bool {
        if success {
            lastError = nil
            return true
        }
        lastError = fetchLastError()
        return false
    }

    private func finish(_ value: UInt64) -> UInt64? {
        guard value != 0 else {
            lastError = fetchLastError()
            return nil
        }
        lastError = nil
        return value
    }

    private func fetchLastError() -> KnowledgeCoreBridgeError {
        let rawCode = graph_engine_kc_last_error_code(core)
        let code = KnowledgeCoreErrorCode(rawValue: rawCode) ?? .invalidArgument
        let message = decode(graph_engine_kc_last_error_message(core))
        return KnowledgeCoreBridgeError(
            code: code,
            message: message.isEmpty ? "staged knowledge-core call failed" : message
        )
    }
}

@MainActor
@Observable
final class KnowledgeCoreShadowRuntime {
    @ObservationIgnored
    private let bridge: KnowledgeCoreBridge
    @ObservationIgnored
    private let pollTaskBox = PollTaskBox()

    private(set) var totalBatches: UInt64 = 0
    private(set) var totalFrames: UInt64 = 0
    private(set) var lastBatch: [KnowledgeCorePayloadSummary] = []
    private(set) var lastError: KnowledgeCoreBridgeError?

    init?(peerId: UInt64 = 1) {
        guard let bridge = KnowledgeCoreBridge(peerId: peerId) else {
            return nil
        }
        self.bridge = bridge
    }

    func subscribeOutline(pageId: String) async -> UInt64? {
        startIfNeeded()
        let id = await bridge.subscribeOutline(pageId: pageId)
        lastError = id == nil ? await bridge.lastErrorSnapshot() : nil
        return id
    }

    func subscribeTasks(pageId: String? = nil) async -> UInt64? {
        startIfNeeded()
        let id = await bridge.subscribeTasks(pageId: pageId)
        lastError = id == nil ? await bridge.lastErrorSnapshot() : nil
        return id
    }

    func subscribeProperties(pageId: String? = nil, key: String? = nil) async -> UInt64? {
        startIfNeeded()
        let id = await bridge.subscribeProperties(pageId: pageId, key: key)
        lastError = id == nil ? await bridge.lastErrorSnapshot() : nil
        return id
    }

    @discardableResult
    func unsubscribe(_ subscriptionId: UInt64) async -> Bool {
        let success = await bridge.unsubscribe(subscriptionId)
        lastError = success ? nil : await bridge.lastErrorSnapshot()
        return success
    }

    @discardableResult
    func ingestDocument(
        pageId: String,
        format: KnowledgeCoreDocumentFormat,
        text: String
    ) async -> Bool {
        let success = await bridge.ingestDocument(pageId: pageId, format: format, text: text)
        lastError = success ? nil : await bridge.lastErrorSnapshot()
        return success
    }

    func drainPayloads(limit: Int = .max) async -> [KnowledgeCorePayloadSnapshot] {
        await bridge.drainPayloads(limit: limit)
    }

    func startIfNeeded(
        frameInterval: Duration = .milliseconds(16),
        maxFramesPerBatch: Int = 128
    ) {
        guard pollTaskBox.task == nil else { return }
        pollTaskBox.task = Task(priority: .utility) { [weak self, bridge] in
            while !Task.isCancelled {
                let summaries = await bridge.drainSummaries(limit: maxFramesPerBatch)
                if !summaries.isEmpty {
                    await MainActor.run {
                        self?.applyBatch(summaries)
                    }
                }
                try? await Task.sleep(for: frameInterval)
            }
        }
    }

    func stop() {
        pollTaskBox.task?.cancel()
        pollTaskBox.task = nil
    }

    private func applyBatch(_ summaries: [KnowledgeCorePayloadSummary]) {
        totalBatches += 1
        totalFrames += UInt64(summaries.count)
        lastBatch = summaries
    }
}

private final class PollTaskBox {
    var task: Task<Void, Never>?

    deinit {
        task?.cancel()
    }
}
