import Foundation
import Testing
@testable import Epistemos

@Suite("SearchIndexService Integration")
struct SearchIndexServiceIntegrationTests {
    private func makeDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("search-index-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("search.sqlite")
    }

    private func makeService() throws -> (service: SearchIndexService, databaseURL: URL) {
        let databaseURL = makeDatabaseURL()
        return (try SearchIndexService(databaseURL: databaseURL), databaseURL)
    }

    private func uniqueId(_ prefix: String = "search-test") -> String {
        "\(prefix)-\(UUID().uuidString)"
    }

    private func uniqueToken(_ prefix: String = "tok") -> String {
        "\(prefix)\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
    }

    private func cleanup(_ service: SearchIndexService, ids: [String]) {
        for id in ids {
            try? service.delete(pageId: id)
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

    @Test("upsert + search returns inserted page")
    func upsertAndSearchRoundTrip() throws {
        let setup = try makeService()
        let service = setup.service
        let pageId = uniqueId()
        let token = uniqueToken()
        defer { cleanup(service, ids: [pageId]) }

        try withRetry {
            try service.upsert(
            id: pageId,
            title: "Title \(token)",
            body: "Body with \(token) detail",
            tags: "tag1 tag2",
            updatedAt: .now
        )
        }

        let results = try withRetry { try service.search(query: token, limit: 20) }
        #expect(results.contains { $0.pageId == pageId })
    }

    @Test("delete removes page from FTS results")
    func deleteRemovesPage() throws {
        let setup = try makeService()
        let service = setup.service
        let pageId = uniqueId()
        let token = uniqueToken("delete")
        defer { cleanup(service, ids: [pageId]) }

        try withRetry {
            try service.upsert(
            id: pageId,
            title: token,
            body: "Body",
            tags: "",
            updatedAt: .now
        )
        }
        let beforeDelete = try withRetry { try service.search(query: token) }
        #expect(beforeDelete.contains { $0.pageId == pageId })

        try withRetry { try service.delete(pageId: pageId) }
        let afterDelete = try withRetry { try service.search(query: token) }
        #expect(!afterDelete.contains { $0.pageId == pageId })
    }

    @Test("upsert conflict updates indexed content")
    func upsertConflictUpdatesContent() throws {
        let setup = try makeService()
        let service = setup.service
        let pageId = uniqueId()
        let oldToken = uniqueToken("old")
        let newToken = uniqueToken("new")
        defer { cleanup(service, ids: [pageId]) }

        try withRetry {
            try service.upsert(
            id: pageId,
            title: oldToken,
            body: "Old body",
            tags: "",
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        }
        try withRetry {
            try service.upsert(
            id: pageId,
            title: newToken,
            body: "New body \(newToken)",
            tags: "updated",
            updatedAt: Date(timeIntervalSince1970: 2)
        )
        }

        let newResults = try withRetry { try service.search(query: newToken) }
        let oldResults = try withRetry { try service.search(query: oldToken) }

        #expect(newResults.contains { $0.pageId == pageId })
        #expect(!oldResults.contains { $0.pageId == pageId })
    }

    @Test("search returns empty for blank query")
    func blankQueryReturnsEmpty() throws {
        let setup = try makeService()
        let service = setup.service
        #expect(try withRetry { try service.search(query: "   ") }.isEmpty)
        #expect(try withRetry { try service.search(query: "\n\t") }.isEmpty)
    }

    @Test("search respects result limit")
    func searchRespectsLimit() throws {
        let setup = try makeService()
        let service = setup.service
        let token = uniqueToken("limit")
        let ids = (0..<3).map { _ in uniqueId("limit-id") }
        defer { cleanup(service, ids: ids) }

        for (idx, id) in ids.enumerated() {
            try withRetry {
                try service.upsert(
                id: id,
                title: "\(token) \(idx)",
                body: "\(token) body",
                tags: "",
                updatedAt: .now
            )
            }
        }

        let results = try withRetry { try service.search(query: token, limit: 2) }
        #expect(results.count <= 2)
        #expect(results.allSatisfy { ids.contains($0.pageId) })
    }

    @Test("diffSync updates changed pages and deletes stale entries")
    func diffSyncUpdatesAndDeletes() async throws {
        let setup = try makeService()
        let service = setup.service
        let updatedId = uniqueId("diff-updated")
        let newId = uniqueId("diff-new")
        let staleId = uniqueId("diff-stale")
        let oldToken = uniqueToken("old")
        let newToken = uniqueToken("new")
        defer { cleanup(service, ids: [updatedId, newId, staleId]) }

        try withRetry {
            try service.upsert(
                id: updatedId,
                title: "Old \(oldToken)",
                body: "Old body \(oldToken)",
                tags: "",
                updatedAt: Date(timeIntervalSince1970: 1)
            )
        }
        try withRetry {
            try service.upsert(
                id: staleId,
                title: "Stale \(oldToken)",
                body: "Stale body \(oldToken)",
                tags: "",
                updatedAt: Date(timeIntervalSince1970: 1)
            )
        }

        try await service.diffSync(
            swiftDataPages: [
                (id: updatedId, updatedAt: Date(timeIntervalSince1970: 2)),
                (id: newId, updatedAt: Date(timeIntervalSince1970: 2)),
            ],
            fullPageProvider: { id in
                switch id {
                case updatedId:
                    return (
                        title: "Updated \(newToken)",
                        body: "Updated body \(newToken)",
                        tags: "fresh",
                        updatedAt: Date(timeIntervalSince1970: 2)
                    )
                case newId:
                    return (
                        title: "Inserted \(newToken)",
                        body: "Inserted body \(newToken)",
                        tags: "fresh",
                        updatedAt: Date(timeIntervalSince1970: 2)
                    )
                default:
                    return nil
                }
            }
        )

        let newResults = try withRetry { try service.search(query: newToken, limit: 10) }
        let oldResults = try withRetry { try service.search(query: oldToken, limit: 10) }

        #expect(newResults.contains { $0.pageId == updatedId })
        #expect(newResults.contains { $0.pageId == newId })
        #expect(!oldResults.contains { $0.pageId == staleId })
        #expect(!oldResults.contains { $0.pageId == updatedId })
    }

    @Test("async rebuild indexes full page snapshots")
    func asyncRebuildIndexesFullPageSnapshots() async throws {
        let setup = try makeService()
        let service = setup.service
        let pageId = uniqueId("rebuild")
        let token = uniqueToken("rebuild")
        defer { cleanup(service, ids: [pageId]) }

        try await service.rebuildFromSwiftDataAsync([
            (
                id: pageId,
                title: "Rebuild \(token)",
                body: "Body \(token)",
                tags: "fresh",
                updatedAt: .now
            ),
        ])

        let results = try withRetry { try service.search(query: token, limit: 20) }
        #expect(results.contains { $0.pageId == pageId })
    }
}
