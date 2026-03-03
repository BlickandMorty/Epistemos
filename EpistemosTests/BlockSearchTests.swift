import Foundation
import Testing
@testable import Epistemos

@Suite("BlockSearch")
struct BlockSearchTests {
    private func uniqueId(_ prefix: String = "block-test") -> String {
        "\(prefix)-\(UUID().uuidString)"
    }

    private func uniqueToken(_ prefix: String = "btok") -> String {
        "\(prefix)\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
    }

    private func cleanupBlocks(_ service: SearchIndexService, ids: [String]) {
        for id in ids {
            try? service.deleteBlock(blockId: id)
        }
    }

    private func isDatabaseLocked(_ error: Error) -> Bool {
        String(describing: error).localizedCaseInsensitiveContains("database is locked")
    }

    private func withRetry<T>(
        attempts: Int = 20,
        delay: TimeInterval = 0.05,
        _ operation: () throws -> T
    ) throws -> T {
        var lastError: Error?
        for attempt in 1...attempts {
            do {
                return try operation()
            } catch {
                lastError = error
                guard isDatabaseLocked(error), attempt < attempts else { throw error }
                Thread.sleep(forTimeInterval: delay)
            }
        }
        throw lastError ?? SearchIndexError.noAppSupportDirectory
    }

    @Test("block upsert and search returns matching block")
    func upsertAndSearch() throws {
        let service = try SearchIndexService()
        let blockId = uniqueId()
        let pageId = uniqueId("page")
        let token = uniqueToken()
        defer { cleanupBlocks(service, ids: [blockId]) }

        try withRetry {
            try service.upsertBlock(blockId: blockId, pageId: pageId, content: "Block with \(token) content")
        }

        let results = try withRetry { try service.searchBlocks(query: token, limit: 20) }
        #expect(results.contains { $0.blockId == blockId })
        #expect(results.first { $0.blockId == blockId }?.pageId == pageId)
    }

    @Test("block delete removes from search index")
    func deleteRemovesBlock() throws {
        let service = try SearchIndexService()
        let blockId = uniqueId()
        let pageId = uniqueId("page")
        let token = uniqueToken("del")
        defer { cleanupBlocks(service, ids: [blockId]) }

        try withRetry {
            try service.upsertBlock(blockId: blockId, pageId: pageId, content: "Content \(token)")
        }
        let beforeDelete = try withRetry { try service.searchBlocks(query: token) }
        #expect(beforeDelete.contains { $0.blockId == blockId })

        try withRetry { try service.deleteBlock(blockId: blockId) }
        let afterDelete = try withRetry { try service.searchBlocks(query: token) }
        #expect(!afterDelete.contains { $0.blockId == blockId })
    }

    @Test("block search respects limit")
    func searchRespectsLimit() throws {
        let service = try SearchIndexService()
        let token = uniqueToken("lim")
        let blockIds = (0..<3).map { _ in uniqueId("lim-block") }
        let pageId = uniqueId("page")
        defer { cleanupBlocks(service, ids: blockIds) }

        for (idx, id) in blockIds.enumerated() {
            try withRetry {
                try service.upsertBlock(blockId: id, pageId: pageId, content: "\(token) block \(idx)")
            }
        }

        let results = try withRetry { try service.searchBlocks(query: token, limit: 2) }
        #expect(results.count <= 2)
        #expect(results.allSatisfy { blockIds.contains($0.blockId) })
    }

    @Test("block update changes indexed content")
    func updateChangesContent() throws {
        let service = try SearchIndexService()
        let blockId = uniqueId()
        let pageId = uniqueId("page")
        let oldToken = uniqueToken("old")
        let newToken = uniqueToken("new")
        defer { cleanupBlocks(service, ids: [blockId]) }

        try withRetry {
            try service.upsertBlock(blockId: blockId, pageId: pageId, content: "Content \(oldToken)")
        }
        try withRetry {
            try service.upsertBlock(blockId: blockId, pageId: pageId, content: "Content \(newToken)")
        }

        let newResults = try withRetry { try service.searchBlocks(query: newToken) }
        let oldResults = try withRetry { try service.searchBlocks(query: oldToken) }

        #expect(newResults.contains { $0.blockId == blockId })
        #expect(!oldResults.contains { $0.blockId == blockId })
    }
}
