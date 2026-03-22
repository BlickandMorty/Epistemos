import Testing
import SwiftData
@testable import Epistemos

// MARK: - Audit W7.1: Unbounded Version Storage

@Suite("Audit W7.1 — Global Version Pruning")
@MainActor
struct VersionPruningTests {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: SDPage.self, SDFolder.self, SDBlock.self, SDPageVersion.self,
            SDChat.self, SDMessage.self, SDGraphNode.self, SDGraphEdge.self,
            configurations: config
        )
    }

    private func seedVersions(count: Int, pageId: String = "page-1", context: ModelContext) {
        for i in 0..<count {
            let version = SDPageVersion(
                pageId: pageId,
                title: "v\(i)",
                body: "Body \(i)",
                wordCount: i
            )
            // Stagger creation dates so oldest-first ordering works
            version.createdAt = Date(timeIntervalSinceNow: Double(-count + i))
            context.insert(version)
        }
        try? context.save()
    }

    // MARK: - Global Prune Tests

    @Test("pruneVersionsGlobal does nothing under limit")
    func underLimitNoOp() throws {
        let container = try makeContainer()
        let context = container.mainContext

        seedVersions(count: 100, context: context)
        let svc = VaultSyncService(modelContainer: container)
        svc.pruneVersionsGlobal()

        let count = try context.fetchCount(FetchDescriptor<SDPageVersion>())
        #expect(count == 100)
    }

    @Test("pruneVersionsGlobal removes excess versions")
    func overLimitPrunes() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Seed more than the global limit
        let total = VaultSyncService.maxTotalVersions + 500
        // Use multiple pages to simulate real usage
        for pageIdx in 0..<10 {
            seedVersions(count: total / 10, pageId: "page-\(pageIdx)", context: context)
        }

        let beforeCount = try context.fetchCount(FetchDescriptor<SDPageVersion>())
        #expect(beforeCount == total)

        let svc = VaultSyncService(modelContainer: container)
        svc.pruneVersionsGlobal()

        let afterCount = try context.fetchCount(FetchDescriptor<SDPageVersion>())
        #expect(afterCount == VaultSyncService.maxTotalVersions)
    }

    @Test("pruneVersionsGlobal removes oldest versions first")
    func removesOldestFirst() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Create a small set to verify ordering
        let limit = VaultSyncService.maxTotalVersions
        let total = limit + 5
        for i in 0..<total {
            let version = SDPageVersion(
                pageId: "page-1",
                title: "v\(i)",
                body: "Body \(i)",
                wordCount: i
            )
            // Oldest first: v0 is the oldest, v(total-1) is the newest
            version.createdAt = Date(timeIntervalSinceNow: Double(-total + i) * 60)
            context.insert(version)
        }
        try context.save()

        let svc = VaultSyncService(modelContainer: container)
        svc.pruneVersionsGlobal()

        // The oldest 5 should be removed (v0..v4), newest should remain
        let remaining = try context.fetch(
            FetchDescriptor<SDPageVersion>(
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
        )
        #expect(remaining.count == limit)
        // The oldest remaining should be v5 (wordCount was used as index)
        #expect(remaining.first?.wordCount == 5)
    }

    @Test("maxTotalVersions constant is 10_000")
    func constantValue() {
        #expect(VaultSyncService.maxTotalVersions == 10_000)
    }

    // MARK: - Edge Cases (Gate 4)

    @Test("pruneVersionsGlobal with exactly maxTotalVersions does nothing")
    func exactlyAtLimit() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let limit = VaultSyncService.maxTotalVersions
        seedVersions(count: limit, context: context)

        let svc = VaultSyncService(modelContainer: container)
        svc.pruneVersionsGlobal()

        let count = try context.fetchCount(FetchDescriptor<SDPageVersion>())
        #expect(count == limit)
    }

    @Test("pruneVersionsGlobal with zero versions does nothing")
    func emptyDatabase() throws {
        let container = try makeContainer()
        let svc = VaultSyncService(modelContainer: container)
        svc.pruneVersionsGlobal()

        let count = try container.mainContext.fetchCount(FetchDescriptor<SDPageVersion>())
        #expect(count == 0)
    }

    @Test("pruneVersionsGlobal with one over limit removes exactly one")
    func oneOverLimit() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let limit = VaultSyncService.maxTotalVersions
        seedVersions(count: limit + 1, context: context)

        let svc = VaultSyncService(modelContainer: container)
        svc.pruneVersionsGlobal()

        let count = try context.fetchCount(FetchDescriptor<SDPageVersion>())
        #expect(count == limit)
    }
}
