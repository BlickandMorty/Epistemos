import Foundation
import Observation
import Dispatch

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

struct KnowledgeCoreProjectionSnapshot: Sendable, Equatable {
    let summaries: [KnowledgeCorePayloadSummary]
    let projectedRowCount: Int
    let stringCacheHits: UInt64
    let stringCacheMisses: UInt64
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
    private let projectionCache = KnowledgeCoreProjectionCache()
    private var lastError: KnowledgeCoreBridgeError?

    init?(
        slotCount: UInt32 = 0,
        slotPayloadBytes: UInt32 = 0,
        peerId: UInt64 = 1
    ) {
        guard let core = graph_engine_kc_create(slotCount, slotPayloadBytes, peerId) else {
            Log.ffiBoundary.fault("KnowledgeCoreBridge creation returned a null core")
            RuntimeDiagnostics.record(
                .fault,
                category: "FFIBoundary",
                message: "KnowledgeCoreBridge creation returned a null core",
                metadata: ["peerId": "\(peerId)"]
            )
            return nil
        }

        let region = graph_engine_kc_ring_region(core)
        let layout = graph_engine_kc_ring_layout(core)
        guard let base = region.ptr,
              region.len > 0,
              layout.slot_count > 0,
              layout.slot_payload_bytes > 0 else {
            Log.ffiBoundary.fault("KnowledgeCoreBridge exposed an invalid ring layout")
            RuntimeDiagnostics.record(
                .fault,
                category: "FFIBoundary",
                message: "KnowledgeCoreBridge exposed an invalid ring layout",
                metadata: [
                    "peerId": "\(peerId)",
                    "regionLength": "\(region.len)",
                    "slotCount": "\(layout.slot_count)",
                    "slotPayloadBytes": "\(layout.slot_payload_bytes)",
                ]
            )
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

    func drainProjectedSummaries(limit: Int = .max) -> KnowledgeCoreProjectionSnapshot {
        let drained = drain(limit: limit, decodeRows: false, projectRows: true)
        let stats = projectionCache.stats()
        return KnowledgeCoreProjectionSnapshot(
            summaries: drained.summaries,
            projectedRowCount: stats.rowCount,
            stringCacheHits: stats.stringStats.hits,
            stringCacheMisses: stats.stringStats.misses
        )
    }

    private func drain(
        limit: Int,
        decodeRows: Bool,
        projectRows: Bool = false
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
            if projectRows {
                projectionCache.apply(slot: slot, summary: summary)
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
            added: decodeRows(section: 0, rowCount: summary.addedCount, slot: slot),
            updated: decodeRows(section: 1, rowCount: summary.updatedCount, slot: slot),
            removed: decodeRows(section: 2, rowCount: summary.removedCount, slot: slot)
        )
    }

    private func decodeRows(
        section: UInt8,
        rowCount: Int,
        slot: (payload: UnsafePointer<UInt8>, len: UInt64)
    ) -> [KnowledgeCoreRowSnapshot] {
        guard rowCount > 0 else { return [] }
        let ffiRowCount = UInt32(rowCount)

        return withUnsafeTemporaryAllocation(
            of: KnowledgeQueryRowFFI.self,
            capacity: rowCount
        ) { buffer in
            guard let base = buffer.baseAddress else {
                return decodeRowsScalar(section: section, slot: slot, rowCount: ffiRowCount)
            }
            let written = graph_engine_kc_payload_rows(
                slot.payload,
                slot.len,
                section,
                0,
                base,
                ffiRowCount
            )
            guard written == ffiRowCount else {
                return decodeRowsScalar(section: section, slot: slot, rowCount: ffiRowCount)
            }

            var rows: [KnowledgeCoreRowSnapshot] = []
            rows.reserveCapacity(rowCount)
            for index in 0..<rowCount {
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
        switch rowKind {
        case .block:
            return KnowledgeCoreRowSnapshot(
                rowKind: rowKind,
                pageId: decode(row.page_id),
                blockId: decode(row.block_id),
                parentId: decode(row.parent_id),
                targetId: "",
                content: decode(row.content),
                propertyKey: "",
                propertyValue: "",
                taskMarker: "",
                orderKey: decode(row.order_key),
                depth: row.depth,
                refType: 0,
                taskDone: false
            )
        case .task:
            return KnowledgeCoreRowSnapshot(
                rowKind: rowKind,
                pageId: decode(row.page_id),
                blockId: decode(row.block_id),
                parentId: "",
                targetId: "",
                content: "",
                propertyKey: "",
                propertyValue: "",
                taskMarker: decode(row.task_marker),
                orderKey: "",
                depth: 0,
                refType: 0,
                taskDone: row.task_done != 0
            )
        case .property:
            return KnowledgeCoreRowSnapshot(
                rowKind: rowKind,
                pageId: decode(row.page_id),
                blockId: decode(row.block_id),
                parentId: "",
                targetId: "",
                content: "",
                propertyKey: decode(row.property_key),
                propertyValue: decode(row.property_value),
                taskMarker: "",
                orderKey: "",
                depth: 0,
                refType: 0,
                taskDone: false
            )
        case .link:
            return KnowledgeCoreRowSnapshot(
                rowKind: rowKind,
                pageId: decode(row.page_id),
                blockId: decode(row.block_id),
                parentId: "",
                targetId: decode(row.target_id),
                content: "",
                propertyKey: "",
                propertyValue: "",
                taskMarker: "",
                orderKey: "",
                depth: 0,
                refType: row.ref_type,
                taskDone: false
            )
        }
    }

    private func decode(_ slice: GraphEngineStringSlice) -> String {
        guard let ptr = slice.ptr, slice.len > 0 else { return "" }
        let buffer = UnsafeBufferPointer(start: ptr, count: Int(slice.len))
        if let decoded = String(bytes: buffer, encoding: .utf8) {
            return decoded
        }
        Log.ffiBoundary.warning(
            "KnowledgeCoreBridge received invalid UTF-8 payload (\(slice.len) bytes); coercing with replacement characters"
        )
        RuntimeDiagnostics.record(
            .warning,
            category: "FFIBoundary",
            message: "KnowledgeCoreBridge received invalid UTF-8 payload",
            metadata: ["bytes": "\(slice.len)"]
        )
        return String(decoding: buffer, as: UTF8.self)
    }

    private func finish(_ success: Bool) -> Bool {
        if success {
            lastError = nil
            return true
        }
        let error = fetchLastError()
        lastError = error
        recordFFIFailure(error)
        return false
    }

    private func finish(_ value: UInt64) -> UInt64? {
        guard value != 0 else {
            let error = fetchLastError()
            lastError = error
            recordFFIFailure(error)
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

    private func recordFFIFailure(_ error: KnowledgeCoreBridgeError) {
        Log.ffiBoundary.error(
            "KnowledgeCoreBridge call failed with \(String(describing: error.code), privacy: .public): \(error.message, privacy: .public)"
        )
        RuntimeDiagnostics.record(
            .error,
            category: "FFIBoundary",
            message: "KnowledgeCoreBridge call failed",
            metadata: [
                "code": "\(error.code.rawValue)",
                "message": error.message,
            ]
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
    private(set) var lastDrainDurationNs: UInt64 = 0
    private(set) var maxDrainDurationNs: UInt64 = 0
    private(set) var totalDrainDurationNs: UInt64 = 0
    private(set) var lastApplyDurationNs: UInt64 = 0
    private(set) var maxApplyDurationNs: UInt64 = 0
    private(set) var totalApplyDurationNs: UInt64 = 0
    private(set) var projectedRowCount: Int = 0
    private(set) var stringCacheHits: UInt64 = 0
    private(set) var stringCacheMisses: UInt64 = 0
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

    @discardableResult
    func moveBlock(
        pageId: String,
        blockId: String,
        parentId: String? = nil,
        index: UInt32
    ) async -> Bool {
        let success = await bridge.moveBlock(
            pageId: pageId,
            blockId: blockId,
            parentId: parentId,
            index: index
        )
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
                let drainStart = DispatchTime.now().uptimeNanoseconds
                let projection = await bridge.drainProjectedSummaries(limit: maxFramesPerBatch)
                let drainDurationNs = DispatchTime.now().uptimeNanoseconds &- drainStart
                if !projection.summaries.isEmpty {
                    await MainActor.run {
                        self?.applyBatch(projection, drainDurationNs: drainDurationNs)
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

    private func applyBatch(_ projection: KnowledgeCoreProjectionSnapshot, drainDurationNs: UInt64) {
        let applyStart = DispatchTime.now().uptimeNanoseconds
        totalBatches += 1
        totalFrames += UInt64(projection.summaries.count)
        lastBatch = projection.summaries
        lastDrainDurationNs = drainDurationNs
        maxDrainDurationNs = max(maxDrainDurationNs, drainDurationNs)
        totalDrainDurationNs &+= drainDurationNs
        projectedRowCount = projection.projectedRowCount
        stringCacheHits = projection.stringCacheHits
        stringCacheMisses = projection.stringCacheMisses
        let applyDurationNs = DispatchTime.now().uptimeNanoseconds &- applyStart
        lastApplyDurationNs = applyDurationNs
        maxApplyDurationNs = max(maxApplyDurationNs, applyDurationNs)
        totalApplyDurationNs &+= applyDurationNs
    }
}

private final class PollTaskBox {
    var task: Task<Void, Never>?

    deinit {
        task?.cancel()
    }
}

nonisolated private struct KnowledgeCoreProjectionCacheStats {
    let rowCount: Int
    let stringStats: BorrowedUTF8StringCacheStats
}

nonisolated private struct KnowledgeCoreRowKey: Hashable, Sendable {
    let rowKind: KnowledgeCoreRowKind
    let pageId: String
    let blockId: String
    let parentId: String
    let targetId: String
    let propertyKey: String
    let refType: UInt8
}

nonisolated private struct KnowledgeCoreProjectedRow: Sendable, Equatable {
    let key: KnowledgeCoreRowKey
    var content: String
    var propertyValue: String
    var taskMarker: String
    var orderKey: String
    var depth: UInt16
    var taskDone: Bool
}

nonisolated private final class KnowledgeCoreProjectionCache {
    private let stringCache = BorrowedUTF8StringCache()
    private var rows: [KnowledgeCoreRowKey: KnowledgeCoreProjectedRow] = [:]

    init() {}

    func apply(
        slot: (payload: UnsafePointer<UInt8>, len: UInt64),
        summary: KnowledgeCorePayloadSummary
    ) {
        applySection(section: 0, rowCount: summary.addedCount, slot: slot, removal: false)
        applySection(section: 1, rowCount: summary.updatedCount, slot: slot, removal: false)
        applySection(section: 2, rowCount: summary.removedCount, slot: slot, removal: true)
    }

    func stats() -> KnowledgeCoreProjectionCacheStats {
        KnowledgeCoreProjectionCacheStats(rowCount: rows.count, stringStats: stringCache.stats())
    }

    private func applySection(
        section: UInt8,
        rowCount: Int,
        slot: (payload: UnsafePointer<UInt8>, len: UInt64),
        removal: Bool
    ) {
        guard rowCount > 0 else { return }
        let ffiRowCount = UInt32(rowCount)
        withUnsafeTemporaryAllocation(of: KnowledgeQueryRowFFI.self, capacity: rowCount) { buffer in
            guard let base = buffer.baseAddress else { return }
            let written = graph_engine_kc_payload_rows(
                slot.payload,
                slot.len,
                section,
                0,
                base,
                ffiRowCount
            )
            guard written == ffiRowCount else { return }
            for index in 0..<rowCount {
                apply(buffer[index], removal: removal)
            }
        }
    }

    private func apply(_ row: KnowledgeQueryRowFFI, removal: Bool) {
        guard let rowKind = KnowledgeCoreRowKind(rawValue: row.row_kind) else { return }
        let key = makeKey(row, rowKind: rowKind)
        if removal {
            rows.removeValue(forKey: key)
            return
        }

        rows[key] = makeProjection(row, rowKind: rowKind, key: key)
    }

    private func makeKey(
        _ row: KnowledgeQueryRowFFI,
        rowKind: KnowledgeCoreRowKind
    ) -> KnowledgeCoreRowKey {
        switch rowKind {
        case .block:
            return KnowledgeCoreRowKey(
                rowKind: rowKind,
                pageId: stringCache.string(for: row.page_id),
                blockId: stringCache.string(for: row.block_id),
                parentId: stringCache.string(for: row.parent_id),
                targetId: "",
                propertyKey: "",
                refType: 0
            )
        case .task:
            return KnowledgeCoreRowKey(
                rowKind: rowKind,
                pageId: stringCache.string(for: row.page_id),
                blockId: stringCache.string(for: row.block_id),
                parentId: "",
                targetId: "",
                propertyKey: "",
                refType: 0
            )
        case .property:
            return KnowledgeCoreRowKey(
                rowKind: rowKind,
                pageId: stringCache.string(for: row.page_id),
                blockId: stringCache.string(for: row.block_id),
                parentId: "",
                targetId: "",
                propertyKey: stringCache.string(for: row.property_key),
                refType: 0
            )
        case .link:
            return KnowledgeCoreRowKey(
                rowKind: rowKind,
                pageId: stringCache.string(for: row.page_id),
                blockId: stringCache.string(for: row.block_id),
                parentId: "",
                targetId: stringCache.string(for: row.target_id),
                propertyKey: "",
                refType: row.ref_type
            )
        }
    }

    private func makeProjection(
        _ row: KnowledgeQueryRowFFI,
        rowKind: KnowledgeCoreRowKind,
        key: KnowledgeCoreRowKey
    ) -> KnowledgeCoreProjectedRow {
        switch rowKind {
        case .block:
            return KnowledgeCoreProjectedRow(
                key: key,
                content: stringCache.string(for: row.content),
                propertyValue: "",
                taskMarker: "",
                orderKey: stringCache.string(for: row.order_key),
                depth: row.depth,
                taskDone: false
            )
        case .task:
            return KnowledgeCoreProjectedRow(
                key: key,
                content: "",
                propertyValue: "",
                taskMarker: stringCache.string(for: row.task_marker),
                orderKey: "",
                depth: 0,
                taskDone: row.task_done != 0
            )
        case .property:
            return KnowledgeCoreProjectedRow(
                key: key,
                content: "",
                propertyValue: stringCache.string(for: row.property_value),
                taskMarker: "",
                orderKey: "",
                depth: 0,
                taskDone: false
            )
        case .link:
            return KnowledgeCoreProjectedRow(
                key: key,
                content: "",
                propertyValue: "",
                taskMarker: "",
                orderKey: "",
                depth: 0,
                taskDone: false
            )
        }
    }
}
