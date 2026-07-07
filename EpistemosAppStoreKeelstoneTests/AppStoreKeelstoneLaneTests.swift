import Foundation
import SwiftData
import Testing
@testable import Epistemos

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX
#error("KEELSTONE App Store lane tests must compile with EPISTEMOS_APP_STORE and MAS_SANDBOX.")
#endif

@Suite("KEELSTONE App Store Lane", .serialized)
@MainActor
struct AppStoreKeelstoneLaneTests {
    private let vaultBookmarkKey = "epistemos.vaultBookmark"
    private let lastVaultPathKey = "epistemos.lastVaultPath"

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(EpistemosSchema.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeTempDirectory(prefix: String = "keelstone-appstore") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeUncreatedTempDirectory(prefix: String = "keelstone-appstore-first-run") -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "AppStoreKeelstoneLaneTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test("App Store lane compiles the App Store surface")
    func appStoreLaneCompilesAppStoreSurface() {
        #expect(AppSurface.current == .appStore)
        #expect(AppSurface.current.isSandboxed)
        #expect(!AppSurface.current.allowsSubprocessCapabilities)
    }

    @Test("App Store lane first-run and upgrade bootstrap matrix")
    func appStoreLaneFirstRunAndUpgradeBootstrapMatrix() throws {
        let freshVault = makeUncreatedTempDirectory()
        defer { try? FileManager.default.removeItem(at: freshVault) }

        #expect(FirstRunBootstrap.isFresh(at: freshVault))
        let freshReceipt = try FirstRunBootstrap.bootstrap(at: freshVault)
        #expect(freshReceipt.wasFresh)
        for relative in FirstRunBootstrap.scaffoldFolders {
            let folder = freshVault.appendingPathComponent(relative, isDirectory: true)
            var isDirectory: ObjCBool = false
            #expect(FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory))
            #expect(isDirectory.boolValue)
        }
        let secondReceipt = try FirstRunBootstrap.bootstrap(at: freshVault)
        #expect(!secondReceipt.wasFresh)
        #expect(secondReceipt.metadata.createdAt == freshReceipt.metadata.createdAt)

        let partialVault = makeUncreatedTempDirectory(prefix: "keelstone-appstore-partial")
        defer { try? FileManager.default.removeItem(at: partialVault) }
        try FileManager.default.createDirectory(
            at: partialVault.appendingPathComponent("notes", isDirectory: true),
            withIntermediateDirectories: true
        )
        #expect(FirstRunBootstrap.isFresh(at: partialVault))
        let partialReceipt = try FirstRunBootstrap.bootstrap(at: partialVault)
        #expect(partialReceipt.wasFresh)
        #expect(partialReceipt.createdFolders.count == FirstRunBootstrap.scaffoldFolders.count - 1)
    }

    @Test("App Store lane rejects stale and non-security-scoped startup bookmarks")
    func appStoreLaneRejectsInvalidStartupBookmarks() {
        let stale = VaultSyncService.startupBookmarkValidationForTesting(
            bookmarkExists: true,
            resolvedURL: URL(fileURLWithPath: "/tmp/vault", isDirectory: true),
            isStale: true,
            usedSecurityScope: true,
            accessGranted: true,
            isReadable: true,
            requiresSecurityScopedVaultAccess: true
        )
        #expect(!stale.isReadyForAutomaticRestore)
        #expect(stale.failureReason == "Saved vault bookmark is stale and must be re-selected.")

        let plain = VaultSyncService.startupBookmarkValidationForTesting(
            bookmarkExists: true,
            resolvedURL: URL(fileURLWithPath: "/tmp/vault", isDirectory: true),
            isStale: false,
            usedSecurityScope: false,
            accessGranted: true,
            isReadable: true,
            requiresSecurityScopedVaultAccess: true
        )
        #expect(!plain.isReadyForAutomaticRestore)
        #expect(plain.failureReason == "Saved vault bookmark is not security-scoped and must be re-selected.")
    }

    @Test("App Store lane refuses plain bookmark fallback when persisting vault selection")
    func appStoreLaneRefusesPlainBookmarkFallback() throws {
        let container = try makeContainer()
        let defaults = makeIsolatedDefaults()
        let service = VaultSyncService(modelContainer: container, userDefaults: defaults)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-appstore-bookmark")
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        service.setRequiresSecurityScopedVaultAccessForTesting(true)
        service.setBookmarkDataWriterForTesting { _, options in
            if options.contains(.withSecurityScope) {
                throw CocoaError(.fileReadUnknown)
            }
            return Data("plain-bookmark".utf8)
        }

        service.persistVaultSelection(vaultURL)

        #expect(defaults.data(forKey: vaultBookmarkKey) == nil)
        #expect(defaults.string(forKey: lastVaultPathKey) == vaultURL.path)
    }

    @Test("App Store lane freezes writes when the mounted vault root disappears")
    func appStoreLaneRootUnavailabilityFreezesWrites() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let defaults = makeIsolatedDefaults()
        let service = VaultSyncService(modelContainer: container, userDefaults: defaults)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-appstore-unavailable")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        defaults.set(Data("bookmark".utf8), forKey: vaultBookmarkKey)
        let page = SDPage(title: "Unavailable Root")
        context.insert(page)
        try context.save()

        service.setVaultURLForTesting(vaultURL)
        service.setInitialImportCompletedForTesting(true)
        try FileManager.default.removeItem(at: vaultURL)

        service.handleVaultVolumeUnavailableForTesting(
            vaultURL: vaultURL,
            reason: "appstore lane root unavailable"
        )

        #expect(service.vaultURL == nil)
        #expect(!service.isWatching)
        #expect(service.recoveryIssue?.reason == "appstore lane root unavailable")
        #expect(defaults.data(forKey: vaultBookmarkKey) == Data("bookmark".utf8))
        #expect(try context.fetch(FetchDescriptor<SDPage>()).count == 1)
        #expect(await service.savePageBodyFileFirst(pageId: page.id, body: "edited") == false)
    }
}
