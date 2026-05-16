import Testing
import SwiftData
@testable import Epistemos

@Suite("AppBootstrap MRU BlockMirror prewarm (ISSUE-2026-05-12-008)")
nonisolated struct AppBootstrapPrewarmTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: SDPage.self, SDBlock.self, SDFolder.self, SDChat.self,
                 SDMessage.self, SDPageVersion.self, SDGraphNode.self,
                 SDGraphEdge.self,
            configurations: config
        )
    }

    @Test("prewarmRecentBlockMirrors syncs inline-body pages and skips disk-only ones")
    @MainActor
    func prewarmsInlineBodyPagesAndSkipsDiskOnly() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let p1 = SDPage(title: "first")
        p1.body = "Hello world\n\nSecond line."
        ctx.insert(p1)

        let p2 = SDPage(title: "second")
        p2.body = "Just one line of body content."
        ctx.insert(p2)

        let p3 = SDPage(title: "third no body")
        // Leave body as default empty string — simulates a disk-only page
        // (in production, `body` is cleared after saveBody()).
        ctx.insert(p3)

        try ctx.save()

        let synced = AppBootstrap.prewarmRecentBlockMirrors(
            modelContext: ctx,
            limit: 10
        )
        #expect(synced == 2)

        let blocks = try ctx.fetch(FetchDescriptor<SDBlock>())
        let pageIdsWithBlocks = Set(blocks.map { $0.pageId })
        #expect(pageIdsWithBlocks.contains(p1.id))
        #expect(pageIdsWithBlocks.contains(p2.id))
        #expect(!pageIdsWithBlocks.contains(p3.id))
    }

    @Test("prewarmRecentBlockMirrors on empty store returns 0")
    @MainActor
    func emptyStoreReturnsZero() throws {
        let container = try makeContainer()
        let synced = AppBootstrap.prewarmRecentBlockMirrors(
            modelContext: container.mainContext,
            limit: 5
        )
        #expect(synced == 0)
    }

    @Test("prewarmRecentBlockMirrors limit caps the fetch")
    @MainActor
    func limitCapsFetch() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        for i in 0..<7 {
            let page = SDPage(title: "page-\(i)")
            page.body = "Body for page \(i)."
            ctx.insert(page)
        }
        try ctx.save()

        let synced = AppBootstrap.prewarmRecentBlockMirrors(
            modelContext: ctx,
            limit: 3
        )
        #expect(synced == 3)
    }
}
