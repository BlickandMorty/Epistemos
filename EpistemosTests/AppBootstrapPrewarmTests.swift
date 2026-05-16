import Testing
import SwiftData
import Foundation
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

    @Test("prewarmRecentBlockMirrors syncs inline-body pages and skips disk-only ones without filePath")
    @MainActor
    func prewarmsInlineBodyPagesAndSkipsEmpty() async throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let p1 = SDPage(title: "first")
        p1.body = "Hello world\n\nSecond line."
        ctx.insert(p1)

        let p2 = SDPage(title: "second")
        p2.body = "Just one line of body content."
        ctx.insert(p2)

        let p3 = SDPage(title: "third no body, no filePath")
        // No body, no filePath — should fall through all 4 steps and skip.
        ctx.insert(p3)

        try ctx.save()

        let synced = await AppBootstrap.prewarmRecentBlockMirrors(
            modelContainer: container,
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
    func emptyStoreReturnsZero() async throws {
        let container = try makeContainer()
        let synced = await AppBootstrap.prewarmRecentBlockMirrors(
            modelContainer: container,
            limit: 5
        )
        #expect(synced == 0)
    }

    @Test("prewarmRecentBlockMirrors limit caps the fetch")
    @MainActor
    func limitCapsFetch() async throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        for i in 0..<7 {
            let page = SDPage(title: "page-\(i)")
            page.body = "Body for page \(i)."
            ctx.insert(page)
        }
        try ctx.save()

        let synced = await AppBootstrap.prewarmRecentBlockMirrors(
            modelContainer: container,
            limit: 3
        )
        #expect(synced == 3)
    }

    @Test("prewarmRecentBlockMirrors loads body from disk when inline body is empty")
    @MainActor
    func diskOnlyPageIsPrewarmedViaFilePath() async throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("prewarm-disk-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("disk-body.md")
        try "Body from disk\n\nSecond paragraph from a real file."
            .write(to: fileURL, atomically: true, encoding: .utf8)

        let page = SDPage(title: "disk-only page")
        page.body = ""  // body lives on disk only
        page.filePath = fileURL.path
        ctx.insert(page)
        try ctx.save()

        let synced = await AppBootstrap.prewarmRecentBlockMirrors(
            modelContainer: container,
            limit: 5
        )
        #expect(synced == 1)

        let blocks = try ctx.fetch(FetchDescriptor<SDBlock>())
        let pageIdsWithBlocks = Set(blocks.map { $0.pageId })
        #expect(pageIdsWithBlocks.contains(page.id))
    }

    @Test("prewarmRecentBlockMirrors gracefully skips pages whose filePath does not exist")
    @MainActor
    func missingFilePathIsSkippedGracefully() async throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let page = SDPage(title: "missing file page")
        page.body = ""
        page.filePath = "/tmp/this-file-definitely-does-not-exist-\(UUID().uuidString).md"
        ctx.insert(page)
        try ctx.save()

        let synced = await AppBootstrap.prewarmRecentBlockMirrors(
            modelContainer: container,
            limit: 5
        )
        #expect(synced == 0)

        let blocks = try ctx.fetch(FetchDescriptor<SDBlock>())
        #expect(blocks.isEmpty)
    }
}
