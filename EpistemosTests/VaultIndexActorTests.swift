import Foundation
import SwiftData
import Testing
@testable import Epistemos

@Suite("VaultIndexActor")
@MainActor
struct VaultIndexActorTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([SDPage.self, SDFolder.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeSearchIndex() throws -> SearchIndexService {
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vault-index-search-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("search.sqlite")
        return try SearchIndexService(databaseURL: dbURL)
    }

    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("vault-index-actor-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @discardableResult
    private func insertPage(
        in context: ModelContext,
        title: String,
        body: String,
        tags: [String] = [],
        updatedAt: Date = .now,
        createdAt: Date = .now,
        wordCount: Int = 0,
        summary: String = "",
        isArchived: Bool = false,
        templateId: String? = nil,
        folder: SDFolder? = nil
    ) -> SDPage {
        let page = SDPage(title: title)
        page.body = body
        page.tags = tags
        page.updatedAt = updatedAt
        page.createdAt = createdAt
        page.wordCount = wordCount
        page.summary = summary
        page.isArchived = isArchived
        page.templateId = templateId
        page.folder = folder
        context.insert(page)
        return page
    }

    @Test("buildVaultContext returns nil for conversational follow-ups")
    func buildVaultContextNilForVagueQuery() async throws {
        let container = try makeContainer()
        let actor = VaultIndexActor(modelContainer: container)
        let context = container.mainContext

        _ = insertPage(
            in: context,
            title: "Quantum Field Theory",
            body: "Renormalization and lagrangians.",
            tags: ["physics"]
        )
        try context.save()

        let result = await actor.buildVaultContext(for: "go deeper")
        #expect(result == nil)
    }

    @Test("buildVaultContext includes relevant notes and action instructions")
    func buildVaultContextIncludesRelevantNotes() async throws {
        let container = try makeContainer()
        let actor = VaultIndexActor(modelContainer: container)
        let context = container.mainContext

        let folder = SDFolder(name: "Research")
        context.insert(folder)

        _ = insertPage(
            in: context,
            title: "Quantum Field Theory",
            body: "Field operators, derivation, and perturbation.",
            tags: ["physics", "quantum"],
            wordCount: 320,
            summary: "QFT derivation summary",
            folder: folder
        )
        _ = insertPage(
            in: context,
            title: "Cooking Notes",
            body: "Sourdough starter and hydration ratios.",
            tags: ["food"],
            wordCount: 120
        )

        try context.save()

        let result = await actor.buildVaultContext(for: "quantum field derivation")
        #expect(result != nil)
        #expect(result?.contains("### Quantum Field Theory") == true)
        #expect(result?.contains("Cooking Notes") == false)
        #expect(result?.contains("## Vault Actions") == true)
        #expect(result?.contains("[ACTION:TAG") == true)
        #expect(result?.contains("Available folders: [Research]") == true)
    }

    @Test("buildAmbientManifest returns entries without recent bodies")
    func buildAmbientManifestStructure() async throws {
        let container = try makeContainer()
        let actor = VaultIndexActor(modelContainer: container)
        let context = container.mainContext

        _ = insertPage(
            in: context,
            title: "Note A",
            body: "Body A",
            tags: ["a"],
            updatedAt: Date(timeIntervalSince1970: 10),
            wordCount: 50,
            summary: "Summary A"
        )
        _ = insertPage(
            in: context,
            title: "Note B",
            body: "Body B",
            tags: [],
            updatedAt: Date(timeIntervalSince1970: 20),
            wordCount: 30,
            summary: ""
        )
        try context.save()

        guard let manifest = await actor.buildAmbientManifest(vaultTitle: "my mind") else {
            Issue.record("Expected non-nil ambient manifest")
            return
        }
        #expect(manifest.entries.count == 2)
        #expect(manifest.recentBodies.isEmpty)
        #expect(manifest.vaultTitle == "my mind")
        #expect(manifest.totalNoteCount == 2)
        #expect(manifest.isInventoryComplete)

        let noteB = manifest.entries.first { $0.title == "Note B" }
        #expect(noteB?.snippet == "Note B")
    }

    @Test("buildVaultManifest includes all entries and only 20 recent bodies")
    func buildVaultManifestRecentBodyLimit() async throws {
        let container = try makeContainer()
        let actor = VaultIndexActor(modelContainer: container)
        let context = container.mainContext

        for i in 0..<25 {
            _ = insertPage(
                in: context,
                title: "P\(i)",
                body: "Body \(i) " + String(repeating: "x", count: 30),
                updatedAt: Date(timeIntervalSince1970: Double(i)),
                createdAt: Date(timeIntervalSince1970: Double(i - 100)),
                wordCount: 100 + i
            )
        }
        try context.save()

        guard let manifest = await actor.buildVaultManifest(vaultTitle: "my mind") else {
            Issue.record("Expected non-nil vault manifest")
            return
        }
        #expect(manifest.entries.count == 25)
        #expect(manifest.recentBodies.count == 20)
        #expect(manifest.recentBodies.first?.title == "P24")
        #expect(manifest.recentBodies.last?.title == "P5")
        #expect(manifest.vaultTitle == "my mind")
        #expect(manifest.totalNoteCount == 25)
    }

    @Test("fetchNoteBodies returns only existing IDs in request order")
    func fetchNoteBodiesFiltersMissing() async throws {
        let container = try makeContainer()
        let actor = VaultIndexActor(modelContainer: container)
        let context = container.mainContext

        let a = insertPage(in: context, title: "A", body: "Body A")
        let b = insertPage(in: context, title: "B", body: "Body B")
        _ = insertPage(in: context, title: "C", body: "Body C")
        try context.save()

        let bodies = await actor.fetchNoteBodies(ids: [b.id, "missing-id", a.id])
        #expect(bodies.count == 2)
        #expect(bodies.map(\.pageId) == [b.id, a.id])
    }

    @Test("findNotesByTitle is case-insensitive and capped at 8")
    func findNotesByTitleBehavior() async throws {
        let container = try makeContainer()
        let actor = VaultIndexActor(modelContainer: container)
        let context = container.mainContext

        for i in 0..<10 {
            _ = insertPage(
                in: context,
                title: "Quantum \(i)",
                body: "Body \(i)",
                updatedAt: Date(timeIntervalSince1970: Double(i))
            )
        }
        _ = insertPage(in: context, title: "Classical Mechanics", body: "Body C")
        try context.save()

        let result = await actor.findNotesByTitle("QuAnTuM")
        #expect(result.count == 8)
        #expect(result.first?.title == "Quantum 9")
        #expect(result.allSatisfy { $0.title.lowercased().contains("quantum") })
    }

    @Test("allPagesForRebuild excludes archived and template pages")
    func allPagesForRebuildFilters() async throws {
        let container = try makeContainer()
        let actor = VaultIndexActor(modelContainer: container)
        let context = container.mainContext

        let active = insertPage(in: context, title: "Active", body: "A")
        _ = insertPage(in: context, title: "Archived", body: "B", isArchived: true)
        _ = insertPage(in: context, title: "Template", body: "C", templateId: "tpl-1")
        try context.save()

        let rows = await actor.allPagesForRebuild()
        #expect(rows.count == 1)
        #expect(rows.first?.id == active.id)
    }

    @Test("spotlight reindex snapshot skips unchanged pages when persisted timestamp is newer")
    func spotlightReindexSnapshotSkipsUnchangedPages() async throws {
        let container = try makeContainer()
        let actor = VaultIndexActor(modelContainer: container)
        let context = container.mainContext
        defer {
            UserDefaults.standard.removeObject(forKey: VaultIndexActor.spotlightIndexDateKey)
        }

        _ = insertPage(
            in: context,
            title: "Stable Note",
            body: "Body",
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        try context.save()

        UserDefaults.standard.set(
            Date(timeIntervalSince1970: 200),
            forKey: VaultIndexActor.spotlightIndexDateKey
        )

        let snapshot = await actor.spotlightReindexSnapshotForTesting()

        #expect(snapshot.lastIndexDate == Date(timeIntervalSince1970: 200))
        #expect(snapshot.changedPageCount == 0)
        #expect(snapshot.willIndex == false)
    }

    @Test("spotlight reindex snapshot includes pages newer than persisted timestamp")
    func spotlightReindexSnapshotIncludesChangedPages() async throws {
        let container = try makeContainer()
        let actor = VaultIndexActor(modelContainer: container)
        let context = container.mainContext
        defer {
            UserDefaults.standard.removeObject(forKey: VaultIndexActor.spotlightIndexDateKey)
        }

        _ = insertPage(
            in: context,
            title: "Old Note",
            body: "Old",
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        _ = insertPage(
            in: context,
            title: "Fresh Note",
            body: "Fresh",
            updatedAt: Date(timeIntervalSince1970: 300)
        )
        try context.save()

        UserDefaults.standard.set(
            Date(timeIntervalSince1970: 200),
            forKey: VaultIndexActor.spotlightIndexDateKey
        )

        let snapshot = await actor.spotlightReindexSnapshotForTesting()

        #expect(snapshot.lastIndexDate == Date(timeIntervalSince1970: 200))
        #expect(snapshot.changedPageCount == 1)
        #expect(snapshot.willIndex == true)
    }

    @Test("fullPageData returns joined tags and nil for missing page")
    func fullPageDataBehavior() async throws {
        let container = try makeContainer()
        let actor = VaultIndexActor(modelContainer: container)
        let context = container.mainContext

        let page = insertPage(
            in: context,
            title: "Tagged",
            body: "Tagged body",
            tags: ["alpha", "beta"],
            updatedAt: Date(timeIntervalSince1970: 1234)
        )
        try context.save()

        let found = await actor.fullPageData(for: page.id)
        #expect(found != nil)
        #expect(found?.title == "Tagged")
        #expect(found?.body == "Tagged body")
        #expect(found?.tags == "alpha beta")
        #expect(found?.updatedAt == Date(timeIntervalSince1970: 1234))

        let missing = await actor.fullPageData(for: "missing-id")
        #expect(missing == nil)
    }

    @Test("allPageTimestamps returns every inserted page")
    func allPageTimestampsReturnsAll() async throws {
        let container = try makeContainer()
        let actor = VaultIndexActor(modelContainer: container)
        let context = container.mainContext

        let p1 = insertPage(in: context, title: "One", body: "1")
        let p2 = insertPage(in: context, title: "Two", body: "2")
        try context.save()

        let timestamps = await actor.allPageTimestamps()
        let ids = Set(timestamps.map(\.id))
        #expect(ids == Set([p1.id, p2.id]))
    }

    @Test("sanitizeTitle removes control characters, trims, and defaults to Untitled")
    func sanitizeTitle() {
        #expect(VaultIndexActor.sanitizeTitle("  Good Title  ") == "Good Title")
        #expect(VaultIndexActor.sanitizeTitle("Bad\u{0000}Title") == "BadTitle")
        #expect(VaultIndexActor.sanitizeTitle(" \n\t ") == "Untitled")
    }

    @Test("persistRestoredBody marks page dirty for vault export")
    func persistRestoredBodyMarksPageDirty() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let page = insertPage(in: context, title: "Restore", body: "")
        try context.save()

        try DiffSheetView.persistRestoredBody("Restored body text", to: page, modelContext: context)

        #expect(page.loadBody() == "Restored body text")
        #expect(page.wordCount == 3)
        #expect(page.needsVaultSync)
    }

    @Test("renamePageFile renames file and updates filePath")
    func renamePageFileUpdatesStoredPath() async throws {
        let container = try makeContainer()
        let actor = VaultIndexActor(modelContainer: container)
        let context = container.mainContext
        let vaultURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        let oldURL = vaultURL.appendingPathComponent("Old Title.md")
        try "body".write(to: oldURL, atomically: true, encoding: .utf8)

        let page = insertPage(in: context, title: "Old Title", body: "")
        page.filePath = oldURL.path
        try context.save()

        try await actor.renamePageFile(pageId: page.id, newTitle: "New Title", vaultURL: vaultURL)

        let newURL = vaultURL.appendingPathComponent("New Title.md")
        #expect(!FileManager.default.fileExists(atPath: oldURL.path))
        #expect(FileManager.default.fileExists(atPath: newURL.path))

        let verifyContext = ModelContext(container)
        let pageId = page.id
        let updated = try verifyContext.fetch(FetchDescriptor<SDPage>())
            .first(where: { $0.id == pageId })
        #expect(updated?.filePath == newURL.path)
    }

    @Test("renamePageFile dedupes when target filename already exists")
    func renamePageFileDedupesExistingTarget() async throws {
        let container = try makeContainer()
        let actor = VaultIndexActor(modelContainer: container)
        let context = container.mainContext
        let vaultURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        let oldURL = vaultURL.appendingPathComponent("Original.md")
        let occupiedURL = vaultURL.appendingPathComponent("Renamed.md")
        try "old".write(to: oldURL, atomically: true, encoding: .utf8)
        try "existing".write(to: occupiedURL, atomically: true, encoding: .utf8)

        let page = insertPage(in: context, title: "Original", body: "")
        page.filePath = oldURL.path
        try context.save()

        try await actor.renamePageFile(pageId: page.id, newTitle: "Renamed", vaultURL: vaultURL)

        let dedupedURL = vaultURL.appendingPathComponent("Renamed-1.md")
        #expect(FileManager.default.fileExists(atPath: occupiedURL.path))
        #expect(FileManager.default.fileExists(atPath: dedupedURL.path))

        let verifyContext = ModelContext(container)
        let pageId = page.id
        let updated = try verifyContext.fetch(FetchDescriptor<SDPage>())
            .first(where: { $0.id == pageId })
        #expect(updated?.filePath == dedupedURL.path)
    }

    @Test("importVault marks imported pages clean and synced")
    func importVaultMarksImportedPagesSynced() async throws {
        let container = try makeContainer()
        let actor = VaultIndexActor(modelContainer: container)
        let vaultURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        let fileURL = vaultURL.appendingPathComponent("Imported.md")
        try """
        ---
        title: Imported Title
        tags: [alpha, beta]
        ---

        Imported body
        """.write(to: fileURL, atomically: true, encoding: .utf8)

        try await actor.importVault(from: vaultURL)

        let verifyContext = ModelContext(container)
        guard let page = try verifyContext.fetch(FetchDescriptor<SDPage>()).first else {
            Issue.record("Expected imported page")
            return
        }

        #expect(page.title == "Imported Title")
        #expect(page.loadBody() == "Imported body")
        #expect(page.needsVaultSync == false)
        #expect(page.lastSyncedBodyHash == SDPage.bodyHash("Imported body"))
        #expect(page.lastSyncedAt != nil)
    }

    @Test("cancelled import does not delete tracked pages from a partial scan")
    func cancelledImportSkipsDeletionPass() async throws {
        let container = try makeContainer()
        let actor = VaultIndexActor(modelContainer: container)
        let context = container.mainContext
        let vaultURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        let fileURL = vaultURL.appendingPathComponent("Tracked.md")
        try "Tracked body".write(to: fileURL, atomically: true, encoding: .utf8)

        let page = insertPage(in: context, title: "Tracked", body: "Tracked body")
        page.filePath = fileURL.path
        try context.save()

        let importTask = Task {
            withUnsafeCurrentTask { task in
                task?.cancel()
            }
            try await actor.importVault(from: vaultURL)
        }
        try await importTask.value

        let verifyContext = ModelContext(container)
        let trackedPages = try verifyContext.fetch(FetchDescriptor<SDPage>())
        #expect(trackedPages.contains { $0.id == page.id })
        #expect(trackedPages.first(where: { $0.id == page.id })?.filePath == fileURL.path)
    }

    @Test("exportPage refreshes search index so graph queries see saved body text")
    func exportPageRefreshesSearchIndexForGraphQueries() async throws {
        let container = try makeContainer()
        let actor = VaultIndexActor(modelContainer: container)
        let context = container.mainContext
        let vaultURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        let searchIndex = try makeSearchIndex()
        await actor.setSearchService(searchIndex)

        let token = "bodytoken\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        let page = insertPage(in: context, title: "Indexed Note", body: "Body with \(token)")
        try context.save()

        #expect(try searchIndex.search(query: token).isEmpty)

        let store = GraphStore()
        let graphNode = GraphNodeRecord(
            id: "graph-\(page.id)",
            type: .note,
            label: page.title,
            sourceId: page.id,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: page.createdAt,
            updatedAt: page.updatedAt
        )
        store.addNode(graphNode)

        let exportedPath = try await actor.exportPage(pageId: page.id, to: vaultURL)
        #expect(exportedPath != nil)

        let noteHits = try searchIndex.search(query: token)
        #expect(noteHits.contains { $0.pageId == page.id })

        let runtime = QueryRuntime(
            graphStore: store,
            graphState: GraphState(),
            searchIndex: searchIndex
        )
        let queryResult = runtime.query(token)

        #expect(queryResult.nodes.map(\.id) == [graphNode.id])
        #expect(queryResult.nodes.first?.snippet?.isEmpty == false)
    }
}
