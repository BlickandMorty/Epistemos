import Foundation
import SwiftData
import Testing
@testable import Epistemos

@Suite("VaultSyncService Audit")
@MainActor
struct VaultSyncServiceAuditTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([SDPage.self, SDFolder.self, SDPageVersion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("vault-sync-audit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @discardableResult
    private func insertDirtyPage(
        in context: ModelContext,
        title: String,
        body: String,
        lastSyncedHash: String,
        lastSyncedAt: Date
    ) -> SDPage {
        let page = SDPage(title: title)
        page.body = body
        page.needsVaultSync = true
        page.lastSyncedBodyHash = lastSyncedHash
        page.lastSyncedAt = lastSyncedAt
        context.insert(page)
        return page
    }

    @Test("saveAllDirtyPages keeps failed exports dirty")
    func saveAllDirtyPagesKeepsFailedExportsDirty() async throws {
        enum StubError: Error { case exportFailed }

        let container = try makeContainer()
        let context = container.mainContext
        let service = VaultSyncService(modelContainer: container)
        let vaultURL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        service.setVaultURLForTesting(vaultURL)

        let oldDate = Date(timeIntervalSince1970: 1_000)
        let successPage = insertDirtyPage(
            in: context,
            title: "Success",
            body: "success body",
            lastSyncedHash: "old-success-hash",
            lastSyncedAt: oldDate
        )
        let failedPage = insertDirtyPage(
            in: context,
            title: "Failure",
            body: "failed body",
            lastSyncedHash: "old-failed-hash",
            lastSyncedAt: oldDate
        )
        try context.save()

        service.setExportPageOverrideForTesting { pageId, _ in
            if pageId == failedPage.id {
                throw StubError.exportFailed
            }
            return "/tmp/\(pageId).md"
        }

        let task = service.saveAllDirtyPages()
        await task?.value

        let pages = try context.fetch(FetchDescriptor<SDPage>())
        guard let savedSuccess = pages.first(where: { $0.id == successPage.id }) else {
            Issue.record("Missing successful page after save")
            return
        }
        guard let savedFailure = pages.first(where: { $0.id == failedPage.id }) else {
            Issue.record("Missing failed page after save")
            return
        }

        #expect(savedSuccess.needsVaultSync == false)
        #expect(savedSuccess.lastSyncedAt != oldDate)
        #expect(savedSuccess.lastSyncedBodyHash == SDPage.bodyHash(savedSuccess.loadBody(mapped: true)))

        #expect(savedFailure.needsVaultSync)
        #expect(savedFailure.lastSyncedAt == oldDate)
        #expect(savedFailure.lastSyncedBodyHash == "old-failed-hash")
    }
}
