import AppKit
import CryptoKit
import Foundation
import Observation
import SwiftData
import os

// MARK: - VaultSyncService
// Apple Notes Hybrid: SwiftData is the sole source of truth during editing.
// Vault .md files are an import/export target — NOT a live sync partner.
//
// Save triggers: per-note Save (Cmd+S), Save All (Shift+Cmd+S), auto-save interval.
// Import: initial vault import on attach, manual "Sync from Vault" button.
// No live file watching — VaultFilePresenter has been removed.

/// A conflict detected during "Sync from Vault" — both the in-app and on-disk versions changed.
struct VaultSyncConflict: Identifiable {
    let id: String  // page ID
    let title: String
    let appBody: String
    let diskBody: String
}

struct VaultHealthSnapshot: Sendable {
    let vaultURL: URL?
    let isVaultReadable: Bool
    let vaultMarkdownCount: Int
    let indexedPageCount: Int
    let indexedPagesWithFilePath: Int
    let localBodyFileCount: Int
    let bookmarkExists: Bool
    let restoreFailed: Bool
    let initialImportCompleted: Bool
    let hadPriorLocalState: Bool

    var displayPath: String {
        vaultURL?.path ?? "No readable vault path detected"
    }

    var hasSevereIndexMismatch: Bool {
        guard isVaultReadable, vaultMarkdownCount > 0 else { return false }
        guard indexedPagesWithFilePath > 0 else { return true }
        if vaultMarkdownCount >= 50 {
            return indexedPageCount < max(10, vaultMarkdownCount / 10)
        }
        return indexedPageCount < max(1, vaultMarkdownCount / 2)
    }

    var hasCollapsedBodyCache: Bool {
        guard localBodyFileCount > 0, indexedPageCount > 0 else { return false }
        return localBodyFileCount < min(indexedPageCount, 3) && indexedPagesWithFilePath == 0
    }

    var requiresRecovery: Bool {
        if restoreFailed && hadPriorLocalState {
            return true
        }
        guard initialImportCompleted else { return false }
        return hasSevereIndexMismatch || hasCollapsedBodyCache
    }
}

struct VaultRecoveryIssue: Identifiable, Sendable {
    let id: String
    let snapshot: VaultHealthSnapshot
    let reason: String

    init(snapshot: VaultHealthSnapshot, reason: String) {
        self.id = UUID().uuidString
        self.snapshot = snapshot
        self.reason = reason
    }

    var detailText: String {
        """
        \(reason)

        Vault path: \(snapshot.displayPath)
        Vault notes on disk: \(snapshot.vaultMarkdownCount)
        Indexed notes in app: \(snapshot.indexedPageCount)
        Indexed notes with file paths: \(snapshot.indexedPagesWithFilePath)
        Local note-body files: \(snapshot.localBodyFileCount)
        """
    }
}

private let log = Logger(subsystem: "com.epistemos", category: "VaultSync")

@MainActor @Observable
final class VaultSyncService {
    typealias ExportPageOperation = @Sendable (String, URL) async throws -> String?
    fileprivate nonisolated static let bookmarkKey = "epistemos.vaultBookmark"
    fileprivate nonisolated static let lastVaultPathKey = "epistemos.lastVaultPath"
    fileprivate nonisolated static let autoSaveIntervalKey = "epistemos.autoSaveInterval"
    fileprivate nonisolated static let testDefaultsSuitePrefix = "com.epistemos.tests.VaultSyncService."
    private nonisolated static let defaultRecoveryVaultURL = URL(
        fileURLWithPath: "/Users/jojo/My mind",
        isDirectory: true
    )

    nonisolated static func shouldRestoreVaultFromBookmark(
        processInfoEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        processInfoEnvironment["XCTestConfigurationFilePath"] == nil
    }

    nonisolated private static func makeDefaultUserDefaults(
        processInfoEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UserDefaults {
        guard shouldRestoreVaultFromBookmark(processInfoEnvironment: processInfoEnvironment) else {
            let suiteName = "\(testDefaultsSuitePrefix)\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName) ?? .standard
            defaults.removePersistentDomain(forName: suiteName)
            return defaults
        }
        return .standard
    }

    private struct DirtySaveBatch {
        let context: ModelContext
        let vaultURL: URL
        let dirtyIds: [String]
        let expectedBodyHashes: [String: String]
    }

    private var indexActor: VaultIndexActor?
    private let modelContainer: ModelContainer
    var exportPageOverride: ExportPageOperation?
    private var searchDatabaseURLOverride: URL?
    private var appSupportDirectoryURLOverride: URL?
    private var preferencesFileURLOverride: URL?
    private var recoverySnapshotRootURLOverride: URL?
    private var defaults = UserDefaults.standard

    private(set) var vaultURL: URL?
    private(set) var isWatching = false

    /// Whether the vault is being imported/indexed. Starts true if a vault
    /// bookmark exists so the landing page shows a vault sync message on the
    /// very first frame, before the import Task even begins.
    var isIndexing = false
    var recoveryIssue: VaultRecoveryIssue?
    var isRecoveringLocalState = false

    /// FTS5 search index (GRDB). Created in startWatching, nil'd in stopWatching.
    private(set) var searchService: SearchIndexService?

    /// EventBus for emitting vaultChanged events on mutations.
    private weak var eventBus: EventBus?

    /// Set the EventBus reference for vault change notifications.
    func setEventBus(_ bus: EventBus) { eventBus = bus }

    /// Whether we hold a security-scoped resource on the vault URL.
    private var isSecurityScoped = false

    private var importTask: Task<Void, Never>?
    private var autoSaveTask: Task<Void, Never>?
    private var versionCaptureTask: Task<Void, Never>?
    private var manifestRefreshTask: Task<Void, Never>?
    private var inFlightDirtySaveTask: Task<Void, Never>?
    private var pendingDirtySaveRequest = false
    private var initialImportCompleted = false

    // MARK: - File Watching
    private var fileWatcherSource: DispatchSourceFileSystemObject?
    private var fileWatcherFD: Int32 = -1
    private var fileWatchDebounceTask: Task<Void, Never>?
    private let fileWatcherClock = ContinuousClock()
    private var fileWatcherIgnoreUntil: ContinuousClock.Instant?

    init(modelContainer: ModelContainer, userDefaults: UserDefaults? = nil) {
        let resolvedDefaults = userDefaults ?? Self.makeDefaultUserDefaults()
        self.modelContainer = modelContainer
        self.defaults = resolvedDefaults
        self.isIndexing = resolvedDefaults.data(forKey: Self.bookmarkKey) != nil
        self.autoSaveInterval = resolvedDefaults.double(forKey: Self.autoSaveIntervalKey)
    }

    func setVaultURLForTesting(_ vaultURL: URL?) {
        self.vaultURL = vaultURL
    }

    func importVaultForTesting(from vaultURL: URL) async throws {
        self.vaultURL = vaultURL
        let actor = VaultIndexActor(modelContainer: modelContainer)
        indexActor = actor
        try await actor.importVault(from: vaultURL)
    }

    func setExportPageOverrideForTesting(_ exportPageOverride: ExportPageOperation?) {
        self.exportPageOverride = exportPageOverride
    }

    func setSearchDatabaseURLForTesting(_ databaseURL: URL?) {
        searchDatabaseURLOverride = databaseURL
    }

    func setAppSupportDirectoryURLForTesting(_ url: URL?) {
        appSupportDirectoryURLOverride = url
    }

    func setPreferencesFileURLForTesting(_ url: URL?) {
        preferencesFileURLOverride = url
    }

    func setRecoverySnapshotRootURLForTesting(_ url: URL?) {
        recoverySnapshotRootURLOverride = url
    }

    func setUserDefaultsForTesting(_ userDefaults: UserDefaults) {
        defaults = userDefaults
        isIndexing = userDefaults.data(forKey: Self.bookmarkKey) != nil
        autoSaveInterval = userDefaults.double(forKey: Self.autoSaveIntervalKey)
    }

    func setInitialImportCompletedForTesting(_ value: Bool) {
        initialImportCompleted = value
    }

    private func exportPage(pageId: String, to vaultURL: URL) async throws -> String? {
        if let exportPageOverride {
            return try await exportPageOverride(pageId, vaultURL)
        }
        return try await indexActor?.exportPage(pageId: pageId, to: vaultURL)
    }

    func dismissRecoveryIssue() {
        recoveryIssue = nil
    }

    func persistVaultSelection(_ url: URL) {
        if let bookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            defaults.set(bookmark, forKey: Self.bookmarkKey)
        }
        defaults.set(url.path, forKey: Self.lastVaultPathKey)
        recoveryIssue = nil
    }

    func clearPersistedVaultSelection() {
        defaults.removeObject(forKey: Self.bookmarkKey)
        defaults.removeObject(forKey: Self.lastVaultPathKey)
    }

    func shouldRunBodyCleanup(candidateVaultURL: URL?) async -> Bool {
        let snapshot = await buildVaultHealthSnapshot(
            candidateVaultURL: candidateVaultURL,
            bookmarkExists: defaults.data(forKey: Self.bookmarkKey) != nil,
            restoreFailed: false
        )
        guard snapshot.initialImportCompleted else { return false }
        guard snapshot.isVaultReadable, snapshot.vaultMarkdownCount > 0 else { return false }
        guard snapshot.indexedPagesWithFilePath > 0 else { return false }
        return !snapshot.requiresRecovery
    }

    func detectRecoveryIssue(
        candidateVaultURL: URL?,
        bookmarkExists: Bool,
        restoreFailed: Bool
    ) async -> VaultRecoveryIssue? {
        let snapshot = await buildVaultHealthSnapshot(
            candidateVaultURL: candidateVaultURL,
            bookmarkExists: bookmarkExists,
            restoreFailed: restoreFailed
        )
        guard snapshot.requiresRecovery else { return nil }
        return VaultRecoveryIssue(snapshot: snapshot, reason: recoveryReason(for: snapshot))
    }

    @discardableResult
    func recoverFromVault(at vaultURL: URL) async -> Bool {
        guard !isRecoveringLocalState else { return false }
        isRecoveringLocalState = true
        recoveryIssue = nil
        isIndexing = true
        initialImportCompleted = false

        do {
            try snapshotLocalState()
            stopWatching(preserveData: true)
            clearDerivedLocalStateForRecovery()
            persistVaultSelection(vaultURL)
            startWatching(vaultURL: vaultURL)
            await importTask?.value
            let issue = await detectRecoveryIssue(
                candidateVaultURL: vaultURL,
                bookmarkExists: true,
                restoreFailed: false
            )
            recoveryIssue = issue
            isRecoveringLocalState = false
            return issue == nil
        } catch {
            isRecoveringLocalState = false
            isIndexing = false
            let snapshot = await buildVaultHealthSnapshot(
                candidateVaultURL: vaultURL,
                bookmarkExists: true,
                restoreFailed: true
            )
            recoveryIssue = VaultRecoveryIssue(
                snapshot: snapshot,
                reason: "Epistemos could not rebuild its local vault state: \(error.localizedDescription)"
            )
            return false
        }
    }

    private func buildVaultHealthSnapshot(
        candidateVaultURL: URL?,
        bookmarkExists: Bool,
        restoreFailed: Bool
    ) async -> VaultHealthSnapshot {
        let resolvedVaultURL = resolvedRecoveryVaultURL(from: candidateVaultURL)
        let isVaultReadable = resolvedVaultURL.map(isReadableVaultURL(_:)) ?? false
        let vaultMarkdownCount: Int
        if let resolvedVaultURL, isVaultReadable {
            vaultMarkdownCount = await Task.detached(priority: .utility) {
                VaultIndexActor.countImportableNoteFiles(in: resolvedVaultURL)
            }.value
        } else {
            vaultMarkdownCount = 0
        }

        let context = modelContainer.mainContext
        let pages = (try? context.fetch(FetchDescriptor<SDPage>())) ?? []
        let indexedPagesWithFilePath = pages.reduce(into: 0) { partial, page in
            if let filePath = page.filePath, !filePath.isEmpty {
                partial += 1
            }
        }

        return VaultHealthSnapshot(
            vaultURL: resolvedVaultURL,
            isVaultReadable: isVaultReadable,
            vaultMarkdownCount: vaultMarkdownCount,
            indexedPageCount: pages.count,
            indexedPagesWithFilePath: indexedPagesWithFilePath,
            localBodyFileCount: NoteFileStorage.managedBodyCount(),
            bookmarkExists: bookmarkExists,
            restoreFailed: restoreFailed,
            initialImportCompleted: initialImportCompleted,
            hadPriorLocalState: !pages.isEmpty
                || NoteFileStorage.managedBodyCount() > 0
                || defaults.string(forKey: Self.lastVaultPathKey) != nil
        )
    }

    private func resolvedRecoveryVaultURL(from candidateVaultURL: URL?) -> URL? {
        if let candidateVaultURL {
            return candidateVaultURL
        }
        if let vaultURL {
            return vaultURL
        }
        if let hintedPath = defaults.string(forKey: Self.lastVaultPathKey),
           !hintedPath.isEmpty {
            return URL(fileURLWithPath: hintedPath, isDirectory: true)
        }
        return Self.defaultRecoveryVaultURL
    }

    private func isReadableVaultURL(_ url: URL) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: url.path) && fm.isReadableFile(atPath: url.path)
    }

    private func recoveryReason(for snapshot: VaultHealthSnapshot) -> String {
        if snapshot.restoreFailed {
            return "Epistemos could not reconnect to the vault and the local index is no longer trustworthy."
        }
        if snapshot.indexedPagesWithFilePath == 0 && snapshot.vaultMarkdownCount > 0 {
            return "Epistemos can read the vault on disk, but the local index lost every file-path mapping."
        }
        if snapshot.hasSevereIndexMismatch {
            return "Epistemos indexed only a small fraction of the readable vault."
        }
        if snapshot.hasCollapsedBodyCache {
            return "Epistemos kept only a collapsed local note-body cache after the vault stayed readable."
        }
        return "Epistemos detected a vault mismatch and needs to rebuild its local state."
    }

    private func appSupportDirectoryURL() -> URL? {
        if let appSupportDirectoryURLOverride {
            return appSupportDirectoryURLOverride
        }
        guard let appSupportBase = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        return appSupportBase.appendingPathComponent("Epistemos", isDirectory: true)
    }

    private func preferencesFileURL() -> URL? {
        if let preferencesFileURLOverride {
            return preferencesFileURLOverride
        }
        guard let library = FileManager.default.urls(
            for: .libraryDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        return library
            .appendingPathComponent("Preferences", isDirectory: true)
            .appendingPathComponent("com.epistemos.app.plist")
    }

    private func recoverySnapshotRootURL() -> URL? {
        if let recoverySnapshotRootURLOverride {
            return recoverySnapshotRootURLOverride
        }
        guard let appSupportBase = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        return appSupportBase.appendingPathComponent("Epistemos-Recovery", isDirectory: true)
    }

    private func defaultSearchDatabaseURL() -> URL? {
        searchDatabaseURLOverride ?? appSupportDirectoryURL()?.appendingPathComponent("search.sqlite")
    }

    private func snapshotLocalState() throws {
        let fm = FileManager.default
        guard let snapshotRoot = recoverySnapshotRootURL() else { return }
        try fm.createDirectory(at: snapshotRoot, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let snapshotURL = snapshotRoot.appendingPathComponent(
            "snapshot-\(formatter.string(from: .now))-\(UUID().uuidString.prefix(8))",
            isDirectory: true
        )
        try fm.createDirectory(at: snapshotURL, withIntermediateDirectories: true)

        if let appSupportURL = appSupportDirectoryURL(), fm.fileExists(atPath: appSupportURL.path) {
            try fm.copyItem(
                at: appSupportURL,
                to: snapshotURL.appendingPathComponent(appSupportURL.lastPathComponent, isDirectory: true)
            )
        }

        if let preferencesURL = preferencesFileURL(), fm.fileExists(atPath: preferencesURL.path) {
            try fm.copyItem(
                at: preferencesURL,
                to: snapshotURL.appendingPathComponent(preferencesURL.lastPathComponent)
            )
        }
    }

    private func clearDerivedLocalStateForRecovery() {
        clearVaultData()
        _ = NoteFileStorage.removeAllManagedBodies()
        clearSearchIndexFiles()
        clearDerivedFilesystemCaches()
        sanitizeTransientSelectionsForVaultRebuild()
        AppBootstrap.shared?.ambientManifest = nil
    }

    private func clearSearchIndexFiles() {
        guard let databaseURL = defaultSearchDatabaseURL() else { return }
        let fm = FileManager.default
        let urls = [
            databaseURL,
            URL(fileURLWithPath: databaseURL.path + "-shm"),
            URL(fileURLWithPath: databaseURL.path + "-wal"),
        ]
        for url in urls where fm.fileExists(atPath: url.path) {
            try? fm.removeItem(at: url)
        }
    }

    private func clearDerivedFilesystemCaches() {
        let fm = FileManager.default
        if let styleCacheURL = appSupportDirectoryURL()?.appendingPathComponent("style-cache", isDirectory: true),
           fm.fileExists(atPath: styleCacheURL.path) {
            try? fm.removeItem(at: styleCacheURL)
            try? fm.createDirectory(at: styleCacheURL, withIntermediateDirectories: true)
        }
    }

    private func sanitizeTransientSelectionsForVaultRebuild() {
        AppBootstrap.shared?.notesUI.resetForVaultSwitch()
        NoteWindowManager.shared.resetForVaultRebuild()
        if let graphState = AppBootstrap.shared?.graphState {
            graphState.selectNode(nil)
            graphState.selectedNodeScreenPoint = nil
        }
    }

    private func schedulePostImportMaintenance(vaultURL: URL, bookmarkExists: Bool, restoreFailed: Bool) async {
        initialImportCompleted = true
        let issue = await detectRecoveryIssue(
            candidateVaultURL: vaultURL,
            bookmarkExists: bookmarkExists,
            restoreFailed: restoreFailed
        )
        recoveryIssue = issue
        guard issue == nil else { return }

        AppBootstrap.shared?.refreshAmbientManifest()
        AppBootstrap.shared?.scheduleHealthyVaultBodyCleanup()
        if let bootstrap = AppBootstrap.shared {
            Task(priority: .utility) {
                let refreshed = await bootstrap.graphState.refreshStructuralDataAsync(
                    container: bootstrap.modelContainer
                )
                if !refreshed {
                    await MainActor.run {
                        bootstrap.graphState.requestRecommit()
                    }
                }
            }
        }
    }

    private func handleRestoreFailure(
        reason: String,
        bookmarkExists: Bool
    ) {
        isIndexing = false
        initialImportCompleted = false
        Task { @MainActor [weak self] in
            guard let self else { return }
            let issue = await self.detectRecoveryIssue(
                candidateVaultURL: nil,
                bookmarkExists: bookmarkExists,
                restoreFailed: true
            )
            if let issue {
                self.recoveryIssue = issue
            } else {
                self.recoveryIssue = nil
                self.clearVaultData()
            }
            log.warning("\(reason, privacy: .public)")
        }
    }

    // MARK: - Lifecycle

    /// Restore vault from saved bookmark on app launch.
    /// Call from RootView.onAppear (after NSApp is alive).
    func restoreVaultFromBookmark() {
        guard Self.shouldRestoreVaultFromBookmark() else {
            isIndexing = false
            log.info("Skipping vault bookmark restore under tests")
            return
        }

        let interval = Log.vaultPerf.beginInterval("restoreVaultFromBookmark")
        defer { Log.vaultPerf.endInterval("restoreVaultFromBookmark", interval) }

        // Migration: check old domains for vault bookmark data.
        // 1. Brainiac.epistemos (rename session stored "epistemos.vaultBookmark" there)
        // 2. com.lucid.app (v2 stored "epistemos.vaultBookmark" there)
        // After bundle ID reverted to Brainiac.lucid-v3, those domains are orphaned.
        var data = defaults.data(forKey: Self.bookmarkKey)
        if let data {
            log.info("📦 Vault bookmark found in current domain (\(data.count) bytes)")
        } else {
            log.info("📦 No vault bookmark in current domain — checking migration sources")
            let migrations: [(suite: String, key: String)] = [
                ("Brainiac.epistemos", "epistemos.vaultBookmark"),
                ("com.lucid.app", "epistemos.vaultBookmark"),
            ]
            for (suite, key) in migrations {
                if let oldSuite = UserDefaults(suiteName: suite) {
                    let oldData = oldSuite.data(forKey: key)
                    log.info(
                        "📦 Checking \(suite, privacy: .public)/\(key, privacy: .public): \(oldData.map { "\($0.count) bytes" } ?? "nil", privacy: .public)"
                    )
                    if let oldData {
                        data = oldData
                        defaults.set(oldData, forKey: Self.bookmarkKey)
                        oldSuite.removeObject(forKey: key)
                        log.info(
                            "📦 Migrated vault bookmark from \(suite, privacy: .public) (\(oldData.count) bytes)"
                        )
                        break
                    }
                } else {
                    log.info("📦 Could not open suite \(suite, privacy: .public)")
                }
            }
        }
        guard let data else {
            log.info("📦 No bookmark data found anywhere")
            handleRestoreFailure(
                reason: "Vault bookmark missing on launch",
                bookmarkExists: false
            )
            return
        }
        log.info("📦 Resolving bookmark (\(data.count) bytes)")
        var isStale = false
        // Try resolving with security scope first, then without (the app is not sandboxed,
        // so migrated bookmarks from a different bundle ID may lack valid security scope
        // but the path itself is still accessible).
        var url: URL?
        var usedSecurityScope = false
        do {
            let resolved = try URL(
                resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil,
                bookmarkDataIsStale: &isStale)
            url = resolved
            usedSecurityScope = true
            log.info(
                "📦 Resolved with security scope → \(resolved.path, privacy: .private) (stale=\(isStale))"
            )
        } catch {
            log.info(
                "📦 Security-scoped resolution failed: \(error.localizedDescription, privacy: .public)"
            )
            // Fallback: try without security scope (non-sandboxed app can still access by path)
            do {
                let resolved = try URL(
                    resolvingBookmarkData: data, options: [], relativeTo: nil,
                    bookmarkDataIsStale: &isStale)
                url = resolved
                log.info(
                    "📦 Resolved WITHOUT security scope → \(resolved.path, privacy: .private) (stale=\(isStale))"
                )
            } catch {
                log.info(
                    "📦 Non-scoped resolution also failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
        guard let url else {
            defaults.removeObject(forKey: Self.bookmarkKey)
            handleRestoreFailure(
                reason: "📦 Failed to resolve vault bookmark",
                bookmarkExists: true
            )
            return
        }

        // Start security-scoped access and keep it — do NOT release before startWatching.
        // Security-scoped access is reference-counted; releasing then re-acquiring creates
        // a window where the scope is lost and background actors can't read files.
        let gained: Bool
        if usedSecurityScope {
            gained = url.startAccessingSecurityScopedResource()
        } else {
            // No security scope needed — bookmark resolved without it (non-sandboxed).
            // Create a fresh security-scoped bookmark so future launches work cleanly.
            gained = FileManager.default.isReadableFile(atPath: url.path)
            if gained,
                let fresh = try? url.bookmarkData(
                    options: .withSecurityScope, includingResourceValuesForKeys: nil,
                    relativeTo: nil)
            {
                defaults.set(fresh, forKey: Self.bookmarkKey)
                log.info("Created fresh security-scoped bookmark for vault")
            }
        }
        if !gained {
            defaults.removeObject(forKey: Self.bookmarkKey)
            handleRestoreFailure(
                reason: "Security scope not granted for vault bookmark",
                bookmarkExists: true
            )
            return
        }

        let exists = FileManager.default.fileExists(atPath: url.path)
        if !exists {
            url.stopAccessingSecurityScopedResource()
            defaults.removeObject(forKey: Self.bookmarkKey)
            handleRestoreFailure(
                reason: "Vault directory not found at \(url.path)",
                bookmarkExists: true
            )
            return
        }

        if isStale {
            if let fresh = try? url.bookmarkData(
                options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            {
                defaults.set(fresh, forKey: Self.bookmarkKey)
            }
        }

        // Pass scopeAlreadyAcquired=true so startWatching doesn't double-acquire
        startWatching(vaultURL: url, scopeAlreadyAcquired: true)
    }

    /// Start watching a vault directory. Performs initial import, then watches for changes.
    /// - Parameter scopeAlreadyAcquired: If true, the caller has already called
    ///   `startAccessingSecurityScopedResource()` — we track it but don't call again.
    func startWatching(vaultURL: URL, scopeAlreadyAcquired: Bool = false) {
        let interval = Log.vaultPerf.beginInterval("startWatching")
        defer { Log.vaultPerf.endInterval("startWatching", interval) }

        // If already watching, stop first (allows re-selection of vault folder)
        if isWatching {
            stopWatching()
        }
        // No clearVaultData() here — incremental import handles stale data.
        // clearVaultData() is only called in stopWatching() (vault switch)
        // and restoreVaultFromBookmark() failure paths.

        if scopeAlreadyAcquired {
            isSecurityScoped = true
        } else {
            // Start security-scoped access (required for sandboxed apps)
            let gained = vaultURL.startAccessingSecurityScopedResource()
            if gained {
                isSecurityScoped = true
            }
            log.info("Security scope acquired: \(gained)")
        }

        self.vaultURL = vaultURL
        self.isWatching = true
        self.initialImportCompleted = false
        self.recoveryIssue = nil
        defaults.set(vaultURL.path, forKey: Self.lastVaultPathKey)

        // Create background indexer
        indexActor = VaultIndexActor(modelContainer: modelContainer)

        // Create FTS5 search index
        do {
            let svc = try SearchIndexService(databaseURL: searchDatabaseURLOverride)
            self.searchService = svc
        } catch {
            log.error("Failed to create SearchIndexService: \(error.localizedDescription, privacy: .public)")
        }

        // Initial vault import
        let actor = indexActor
        let url = vaultURL
        let svc = searchService
        isIndexing = true
        importTask = Task {
            let importInterval = Log.vaultPerf.beginInterval("initialVaultImport")

            // Inject search service into actor before import
            if let svc { await actor?.setSearchService(svc) }
            do {
                try await actor?.importVault(from: url)
                log.info("Initial vault import complete")

                // Signal the graph to rebuild with newly imported data
                await MainActor.run {
                    AppBootstrap.shared?.graphState.needsRefresh = true
                }

                // Bulk-index all imported pages into Spotlight.
                await actor?.spotlightReindexAll()
            } catch {
                log.error(
                    "Initial vault import failed: \(error.localizedDescription, privacy: .public)")
            }
            Log.vaultPerf.endInterval("initialVaultImport", importInterval)

            // Diff-sync FTS5 index with SwiftData (catches stale/missing search.sqlite)
            if let svc, let actor {
                let diffSyncInterval = Log.vaultPerf.beginInterval("initialVaultDiffSync")
                let timestamps = await actor.allPageTimestamps()
                do {
                    try await svc.diffSync(
                        swiftDataPages: timestamps,
                        fullPageProvider: { id in await actor.fullPageData(for: id) }
                    )
                } catch {
                    log.error("FTS5 diff-sync failed: \(error.localizedDescription, privacy: .public)")
                }
                Log.vaultPerf.endInterval("initialVaultDiffSync", diffSyncInterval)
            }
            await MainActor.run {
                self.isIndexing = false
            }
            await self.schedulePostImportMaintenance(
                vaultURL: url,
                bookmarkExists: true,
                restoreFailed: false
            )
        }


        if let actor = indexActor {
            Task(priority: .utility) {
                await actor.migrateToHybridSync()
                await actor.migrateFromExternalStorage()
            }
        }
        restartAutoSaveTimer()
        startVersionCaptureTimer()
        startManifestRefreshTimer()
        startFileWatcher()

        // Build ambient manifest optimistically; a second refresh runs after import settles.
        AppBootstrap.shared?.refreshAmbientManifest()

        log.info("VaultSyncService started for: \(vaultURL.lastPathComponent, privacy: .public)")
    }

    /// Stop watching and release resources.
    /// - Parameter preserveData: When `true`, keeps SwiftData models intact so the
    ///   next launch can do an incremental import (~instant) instead of a full reimport (~13s).
    ///   Pass `false` (default) for vault switches/disconnects to clear stale data.
    func stopWatching(preserveData: Bool = false) {
        importTask?.cancel()
        importTask = nil
        autoSaveTask?.cancel()
        autoSaveTask = nil
        versionCaptureTask?.cancel()
        versionCaptureTask = nil
        manifestRefreshTask?.cancel()
        manifestRefreshTask = nil
        stopFileWatcher()
        indexActor = nil
        searchService = nil

        if !preserveData {
            clearVaultData()
            SpotlightIndexer.removeAll()
        }

        if isSecurityScoped, let url = vaultURL {
            url.stopAccessingSecurityScopedResource()
            isSecurityScoped = false
        }

        vaultURL = nil
        isWatching = false
        isIndexing = false
        initialImportCompleted = false
        log.info("VaultSyncService stopped (preserveData=\(preserveData))")
    }

    /// Delete all vault pages/folders AND graph data from SwiftData.
    /// Called on every vault transition and startup failure to prevent stale ghost data.
    private func clearVaultData() {
        let context = modelContainer.mainContext
        do {
            try context.delete(model: SDBlock.self)
            try context.delete(model: SDPageVersion.self)
            try context.delete(model: SDNoteInsight.self)
            try context.delete(model: SDPage.self)
            try context.delete(model: SDFolder.self)
            try context.delete(model: SDGraphNode.self)
            try context.delete(model: SDGraphEdge.self)
            try context.save()
            Log.vault.info("Cleared all vault + graph data from SwiftData")
        } catch {
            Log.vault.error("Failed to clear vault data: \(error.localizedDescription, privacy: .public)")
        }

        // Clear the in-memory graph store and reset graph state.
        Task { @MainActor in
            if let graphState = AppBootstrap.shared?.graphState {
                graphState.store.clear()
                graphState.hasPlayedEntrance = false
                graphState.isLoaded = false
                graphState.needsRefresh = false
                graphState.requestRecommit()
                if let engine = graphState.engineHandle {
                    graph_engine_clear(engine)
                }
            }
        }
    }

    // MARK: - Vault Context (Background)

    /// Search the vault for notes relevant to a chat query and format as context.
    /// Delegates to VaultIndexActor so all disk-heavy body reads run off the main thread.
    func buildVaultContext(for query: String) async -> String? {
        await indexActor?.buildVaultContext(for: query)
    }

    /// Build lightweight ambient manifest (entries only, no bodies).
    func buildAmbientManifest() async -> VaultManifest? {
        await indexActor?.buildAmbientManifest()
    }

    /// Build complete vault manifest with recent bodies (for vault briefing).
    func buildVaultManifest() async -> VaultManifest? {
        await indexActor?.buildVaultManifest()
    }

    /// Fetch full note bodies by ID for @-mention resolution.
    func fetchNoteBodies(ids: [String]) async -> [VaultManifest.NoteBody] {
        await indexActor?.fetchNoteBodies(ids: ids) ?? []
    }

    /// Find notes matching a title query.
    func findNotesByTitle(_ query: String) async -> [VaultManifest.ManifestEntry] {
        await indexActor?.findNotesByTitle(query) ?? []
    }

    /// Search note bodies via FTS5 full-text index. Returns matching page IDs.
    func searchIndex(query: String) async -> [String] {
        guard let svc = searchService else { return [] }
        do {
            return try await svc.searchAsync(query: query).map(\.pageId)
        } catch {
            log.error("FTS5 search failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// Full-text search with ranked results + snippets. For command palette deep search.
    func searchFull(query: String, limit: Int = 20) -> [SearchResult] {
        guard let svc = searchService else { return [] }
        do {
            return try svc.search(query: query, limit: limit)
        } catch {
            return []
        }
    }

    func searchFullAsync(query: String, limit: Int = 20) async -> [SearchResult] {
        guard let svc = searchService else { return [] }
        do {
            return try await svc.searchAsync(query: query, limit: limit)
        } catch {
            return []
        }
    }

    func searchBlocksAsync(query: String, limit: Int = 20) async -> [BlockSearchResult] {
        guard let svc = searchService else { return [] }
        do {
            return try await svc.searchBlocksAsync(query: query, limit: limit)
        } catch {
            return []
        }
    }

    /// Manually trigger a full FTS5 index rebuild.
    /// Called from Settings > Vault > "Rebuild Index" button.
    func rebuildIndex() {
        guard let actor = indexActor, let svc = searchService else { return }
        isIndexing = true
        Task {
            let interval = Log.vaultPerf.beginInterval("rebuildIndex")
            defer { Log.vaultPerf.endInterval("rebuildIndex", interval) }
            let pages = await actor.allPagesForRebuild()
            do {
                try await svc.rebuildFromSwiftDataAsync(pages)
            } catch {
                log.error("FTS5 index rebuild failed: \(error.localizedDescription, privacy: .public)")
            }
            isIndexing = false
        }
    }

    // MARK: - Migration


    // MARK: - Sync from Vault

    /// Pull external .md changes from the vault folder.
    /// Returns conflicts (both sides changed) for the UI to resolve.
    func syncFromVault() async -> [VaultSyncConflict] {
        guard let vaultURL, let actor = indexActor else { return [] }
        let interval = Log.vaultPerf.beginInterval("syncFromVault")
        defer { Log.vaultPerf.endInterval("syncFromVault", interval) }

        let context = modelContainer.mainContext
        do {
            try context.save()  // Persist latest state
        } catch {
            Log.vault.error("Failed to save before sync-from-vault: \(error.localizedDescription, privacy: .public)")
        }

        // Re-import vault (handles new files + updates)
        do {
            try await actor.importVault(from: vaultURL)
        } catch {
            log.error("Sync import failed: \(error.localizedDescription, privacy: .public)")
            return []
        }

        // Signal the graph to rebuild with synced data
        AppBootstrap.shared?.graphState.needsRefresh = true

        let pageCount = await actor.allPageTimestamps().count
        log.info("Sync from vault complete: \(pageCount) pages")
        eventBus?.emit(.vaultChanged)
        return []
    }

    // MARK: - Write Operations

    // MARK: - Explicit Save (Apple Notes Hybrid)

    /// Save a single page to its vault .md file and update sync tracking fields.
    @discardableResult
    func savePage(pageId: String) -> Task<Void, Never>? {
        captureVersionIfNeeded(pageId: pageId)

        guard let vaultURL else {
            log.warning("Cannot save page: no vault URL")
            return nil
        }

        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
        guard (try? context.fetch(descriptor).first) != nil else { return nil }

        do {
            try context.save()
        } catch {
            Log.vault.error("Failed to save before page export (\(pageId.prefix(8), privacy: .public)): \(error.localizedDescription, privacy: .public)")
        }

        let expectedBodyHash = if let page = try? context.fetch(descriptor).first {
            SDPage.bodyHash(page.loadBody(mapped: true))
        } else {
            ""
        }

        suppressFileWatcherForSelfOriginatedChange()

        let task = Task {
            do {
                let exportedPath = try await self.exportPage(pageId: pageId, to: vaultURL)

                await MainActor.run {
                    let desc = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
                    if let page = try? context.fetch(desc).first {
                        let currentHash = SDPage.bodyHash(page.loadBody(mapped: true))
                        if currentHash == expectedBodyHash {
                            page.lastSyncedBodyHash = currentHash
                            page.lastSyncedAt = .now
                            page.needsVaultSync = false
                            SpotlightIndexer.index(page)
                        } else {
                            page.needsVaultSync = true
                        }
                        do {
                            try context.save()
                        } catch {
                            Log.vault.error("Failed to save sync tracking for page (\(pageId.prefix(8), privacy: .public)): \(error.localizedDescription, privacy: .public)")
                        }
                    }
                }

                if let path = exportedPath {
                    log.info("Saved page to vault: \(path, privacy: .private)")
                }

                await MainActor.run { [weak self] in
                    self?.eventBus?.emit(.vaultPageChanged(pageId: pageId))
                }
            } catch {
                log.error("Failed to save page \(pageId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        return task
    }

    /// Save all dirty pages to their vault .md files.
    @discardableResult
    func saveAllDirtyPages() -> Task<Void, Never>? {
        if let task = inFlightDirtySaveTask, !task.isCancelled {
            pendingDirtySaveRequest = true
            return task
        }

        guard let initialBatch = nextDirtySaveBatch() else { return nil }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.runDirtySaveLoop(startingWith: initialBatch)
        }
        inFlightDirtySaveTask = task
        return task
    }

    private func nextDirtySaveBatch() -> DirtySaveBatch? {
        guard let vaultURL else { return nil }

        let context = modelContainer.mainContext
        let dirtyDescriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.needsVaultSync == true || $0.lastSyncedBodyHash == nil }
        )
        guard let dirtyPages = try? context.fetch(dirtyDescriptor),
              !dirtyPages.isEmpty else {
            log.info("No dirty pages to save")
            return nil
        }

        var expectedBodyHashes: [String: String] = [:]
        expectedBodyHashes.reserveCapacity(dirtyPages.count)

        for page in dirtyPages {
            captureVersionIfNeeded(pageId: page.id)
            expectedBodyHashes[page.id] = SDPage.bodyHash(page.loadBody(mapped: true))
        }

        do {
            try context.save()
        } catch {
            Log.vault.error("Failed to save before dirty pages export: \(error.localizedDescription, privacy: .public)")
        }

        return DirtySaveBatch(
            context: context,
            vaultURL: vaultURL,
            dirtyIds: dirtyPages.map(\.id),
            expectedBodyHashes: expectedBodyHashes
        )
    }

    private func runDirtySaveLoop(startingWith initialBatch: DirtySaveBatch) async {
        let interval = Log.vaultPerf.beginInterval("saveAllDirtyPages")
        defer {
            Log.vaultPerf.endInterval("saveAllDirtyPages", interval)
            inFlightDirtySaveTask = nil
            pendingDirtySaveRequest = false
        }

        var currentBatch: DirtySaveBatch? = initialBatch
        while !Task.isCancelled {
            pendingDirtySaveRequest = false
            guard let batch = currentBatch ?? nextDirtySaveBatch() else { return }
            currentBatch = nil

            var successfulIds: [String] = []
            successfulIds.reserveCapacity(batch.dirtyIds.count)

            for pageId in batch.dirtyIds {
                do {
                    suppressFileWatcherForSelfOriginatedChange()
                    _ = try await exportPage(pageId: pageId, to: batch.vaultURL)
                    successfulIds.append(pageId)
                } catch {
                    log.error("Failed to save page \(pageId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }

            for pageId in successfulIds {
                let desc = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
                guard let page = try? batch.context.fetch(desc).first else { continue }

                let currentHash = SDPage.bodyHash(page.loadBody(mapped: true))
                if currentHash == batch.expectedBodyHashes[pageId] {
                    page.lastSyncedBodyHash = currentHash
                    page.lastSyncedAt = .now
                    page.needsVaultSync = false
                    SpotlightIndexer.index(page)
                } else {
                    pendingDirtySaveRequest = true
                }
            }

            do {
                try batch.context.save()
            } catch {
                Log.vault.error("Failed to save sync tracking after dirty pages export: \(error.localizedDescription, privacy: .public)")
            }

            log.info("Saved \(successfulIds.count) of \(batch.dirtyIds.count) dirty pages to vault")

            guard pendingDirtySaveRequest else { return }
        }
    }

    /// Auto-save interval in seconds. 0 = disabled.
    /// Stored property so @Observable tracks it and SwiftUI re-renders on change.
    var autoSaveInterval: TimeInterval = 0 {
        didSet {
            defaults.set(autoSaveInterval, forKey: Self.autoSaveIntervalKey)
            restartAutoSaveTimer()
        }
    }

    /// Start or restart the auto-save timer.
    func restartAutoSaveTimer() {
        autoSaveTask?.cancel()
        autoSaveTask = nil

        let interval = autoSaveInterval
        guard interval > 0, isWatching else { return }

        autoSaveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                self?.saveAllDirtyPages()
            }
        }
    }

    /// Periodic manifest refresh (5-minute interval) as safety net for external edits.
    private func startManifestRefreshTimer() {
        manifestRefreshTask?.cancel()
        manifestRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                guard !Task.isCancelled else { return }
                guard self != nil else { return }
                AppBootstrap.shared?.refreshAmbientManifest()
            }
        }
    }

    // MARK: - File System Watcher

    /// Monitor the vault directory for external changes (creates, modifies, deletes, renames).
    /// Uses GCD DispatchSource for efficient kernel-level notifications.
    /// Debounces rapid changes (e.g. editor auto-save) with a 2-second delay.
    private func startFileWatcher() {
        guard let url = vaultURL else { return }
        stopFileWatcher()

        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            log.warning("File watcher: failed to open vault directory for monitoring")
            return
        }
        fileWatcherFD = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .rename, .delete, .link, .attrib],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.handleFileSystemChange()
        }

        source.setCancelHandler { [fd] in
            close(fd)
        }

        source.resume()
        fileWatcherSource = source
        log.info("File watcher started for: \(url.lastPathComponent, privacy: .public)")
    }

    private func stopFileWatcher() {
        fileWatchDebounceTask?.cancel()
        fileWatchDebounceTask = nil
        fileWatcherIgnoreUntil = nil
        if let source = fileWatcherSource {
            source.cancel()
            fileWatcherSource = nil
            fileWatcherFD = -1
        }
    }

    private func suppressFileWatcherForSelfOriginatedChange(window: Duration = .seconds(3)) {
        guard isWatching else { return }
        let deadline = fileWatcherClock.now + window
        if let existingDeadline = fileWatcherIgnoreUntil, existingDeadline > deadline {
            return
        }
        fileWatcherIgnoreUntil = deadline
    }

    private func shouldIgnoreFileWatcherChange() -> Bool {
        guard let deadline = fileWatcherIgnoreUntil else { return false }
        let now = fileWatcherClock.now
        if now < deadline {
            return true
        }
        fileWatcherIgnoreUntil = nil
        return false
    }

    /// Debounced handler for file system change events.
    /// Waits 2 seconds after the last change before re-importing, so rapid
    /// saves (e.g. typing in an external editor) don't trigger 50 reimports.
    private func handleFileSystemChange() {
        fileWatchDebounceTask?.cancel()
        fileWatchDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self, let vaultURL, let actor = indexActor else { return }
            guard !shouldIgnoreFileWatcherChange() else {
                log.info("File watcher: skipping self-originated vault change")
                return
            }

            log.info("File watcher: vault changed externally — re-importing")
            do {
                try await actor.importVault(from: vaultURL, deleteMissingFiles: false)
                log.info("File watcher: re-import complete")

                // Rebuild graph with new/changed data
                AppBootstrap.shared?.graphState.needsRefresh = true

                // Refresh ambient manifest
                AppBootstrap.shared?.refreshAmbientManifest()

                // Diff-sync FTS5 search index
                if let svc = searchService {
                    let timestamps = await actor.allPageTimestamps()
                    try await svc.diffSync(
                        swiftDataPages: timestamps,
                        fullPageProvider: { id in await actor.fullPageData(for: id) }
                    )
                }
            } catch {
                log.error("File watcher: re-import failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Version Capture

    private static let maxVersionsPerPage = 50
    static let maxTotalVersions = 10_000

    /// Capture a snapshot of the current page body as a version, if it changed.
    func captureVersionIfNeeded(pageId: String) {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
        guard let page = try? context.fetch(descriptor).first else { return }
        let currentBody = page.loadBody()
        guard !currentBody.isEmpty else { return }

        // Check if body actually changed since last version
        let pid = page.id
        var versionDesc = FetchDescriptor<SDPageVersion>(
            predicate: #Predicate<SDPageVersion> { $0.pageId == pid },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        versionDesc.fetchLimit = 1
        if let latest = try? context.fetch(versionDesc).first, latest.body == currentBody { return }

        let version = SDPageVersion(pageId: pageId, title: page.title, body: currentBody, wordCount: page.wordCount)
        context.insert(version)
        do {
            try context.save()
        } catch {
            Log.vault.error("Failed to save captured version for page \(pageId.prefix(8), privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
        log.info("Captured version for page \(pageId.prefix(8))")
        pruneVersions(pageId: pageId)
        pruneVersionsGlobal()
    }

    /// Keep only the most recent N versions per page.
    private func pruneVersions(pageId: String) {
        let context = modelContainer.mainContext
        var desc = FetchDescriptor<SDPageVersion>(
            predicate: #Predicate<SDPageVersion> { $0.pageId == pageId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        desc.fetchOffset = Self.maxVersionsPerPage
        guard let old = try? context.fetch(desc), !old.isEmpty else { return }
        for version in old { context.delete(version) }
        do {
            try context.save()
        } catch {
            Log.vault.error("Failed to save after pruning versions for page \(pageId.prefix(8), privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
        log.info("Pruned \(old.count) old versions for page \(pageId.prefix(8))")
    }

    /// Delete the oldest versions across all pages when total exceeds the global limit.
    /// Called after every per-page prune to keep storage bounded.
    func pruneVersionsGlobal() {
        let context = modelContainer.mainContext
        let countDesc = FetchDescriptor<SDPageVersion>()
        guard let totalCount = try? context.fetchCount(countDesc),
              totalCount > Self.maxTotalVersions else { return }

        let excess = totalCount - Self.maxTotalVersions
        var oldestDesc = FetchDescriptor<SDPageVersion>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        oldestDesc.fetchLimit = excess
        guard let oldest = try? context.fetch(oldestDesc), !oldest.isEmpty else { return }
        for version in oldest { context.delete(version) }
        do {
            try context.save()
        } catch {
            Log.vault.error("Failed to save after global version prune: \(error.localizedDescription, privacy: .public)")
        }
        log.info("Global version prune: removed \(oldest.count) oldest versions (total was \(totalCount))")
    }

    /// Start a 10-minute timer that captures versions for all dirty pages.
    private func startVersionCaptureTimer() {
        versionCaptureTask?.cancel()
        versionCaptureTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(600))
                guard !Task.isCancelled, let self else { return }
                self.autoCaptureVersions()
            }
        }
    }

    /// Capture versions for all dirty pages (called by timer).
    private func autoCaptureVersions() {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<SDPage>()
        guard let allPages = try? context.fetch(descriptor) else { return }
        let dirty = allPages.filter(\.isDirtyVault)
        for page in dirty {
            let pid = page.id
            captureVersionIfNeeded(pageId: pid)
        }
        if !dirty.isEmpty {
            log.info("Auto-captured versions for \(dirty.count) dirty pages")
        }
    }

    /// Create a new page in SwiftData and write its .md file.
    /// Returns the page ID for immediate navigation.
    func createPage(title: String, body: String = "", emoji: String = "", subfolder: String? = nil)
        async -> String?
    {
        guard let vaultURL else {
            log.warning("Cannot create page: no vault URL")
            return nil
        }

        let page = SDPage(title: title, emoji: emoji)
        page.saveBody(body)
        page.subfolder = subfolder
        page.wordCount = body.split(separator: " ").count

        // Insert into main context (we're on MainActor)
        let context = modelContainer.mainContext
        context.insert(page)
        BlockMirror.sync(pageId: page.id, body: body, modelContext: context)
        do {
            try context.save()  // Explicit save ensures the page is persisted before background export
        } catch {
            Log.vault.error("Failed to save new page '\(title, privacy: .public)': \(error.localizedDescription, privacy: .public)")
        }

        // Index in Spotlight
        SpotlightIndexer.index(page)
        page.lastSyncedBodyHash = SDPage.bodyHash(page.loadBody())
        page.lastSyncedAt = .now
        page.needsVaultSync = false

        // Export to disk in background
        let pageId = page.id
        suppressFileWatcherForSelfOriginatedChange()
        Task { [weak self] in
            do {
                _ = try await self?.exportPage(pageId: pageId, to: vaultURL)
            } catch {
                log.error(
                    "Failed to export new page to disk: \(error.localizedDescription, privacy: .public)"
                )
            }
            await MainActor.run {
                self?.eventBus?.emit(.vaultChanged)
            }
        }

        return pageId
    }

    // MARK: - Directory Operations

    private func removeVaultItem(at url: URL, label: String) {
        suppressFileWatcherForSelfOriginatedChange()
        do {
            var trashedURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &trashedURL)
            log.info("Moved \(label, privacy: .public) to Trash: \(url.path, privacy: .private)")
            eventBus?.emit(.vaultChanged)
        } catch {
            do {
                try FileManager.default.removeItem(at: url)
                log.info("Deleted \(label, privacy: .public): \(url.path, privacy: .private)")
                eventBus?.emit(.vaultChanged)
            } catch {
                log.error(
                    "Failed to remove \(label, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    /// Delete the .md file for a page from the vault.
    /// Called when user deletes a page from the sidebar — prevents orphan resurrection on reimport.
    func deletePageFromDisk(filePath: String?) {
        guard let filePath, FileManager.default.fileExists(atPath: filePath) else { return }
        removeVaultItem(at: URL(fileURLWithPath: filePath), label: "page file")
    }

    /// Delete a physical directory from the vault.
    /// Called when user deletes a folder — prevents folder resurrection on reimport.
    func deleteDirectory(relativePath: String) {
        guard let vaultURL else { return }
        let dirURL = vaultURL.appendingPathComponent(relativePath, isDirectory: true)
        guard FileManager.default.fileExists(atPath: dirURL.path) else { return }
        removeVaultItem(at: dirURL, label: "directory")
    }

    /// Create a physical directory in the vault for an SDFolder.
    /// `relativePath` is the folder's path relative to vault root (e.g. "Projects/2026").
    func createDirectory(relativePath: String) {
        guard let vaultURL else {
            log.warning("Cannot create directory: no vault URL")
            return
        }
        let dirURL = vaultURL.appendingPathComponent(relativePath, isDirectory: true)
        do {
            suppressFileWatcherForSelfOriginatedChange()
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            log.info("Created directory: \(relativePath, privacy: .public)")
        } catch {
            log.error(
                "Failed to create directory \(relativePath, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// Rename a page's vault .md file to match a new title.
    /// Call this after updating page.title so the Finder filename stays in sync.
    func renamePageFile(pageId: String, newTitle: String) {
        guard let vaultURL else {
            log.warning("Cannot rename page file: no vault URL")
            return
        }
        let actor = indexActor
        suppressFileWatcherForSelfOriginatedChange()
        Task {
            do {
                try await actor?.renamePageFile(pageId: pageId, newTitle: newTitle, vaultURL: vaultURL)
            } catch {
                log.error("Failed to rename page file: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Rename a directory in the vault. Both paths are relative to vault root.
    func renameDirectory(from oldRelativePath: String, to newRelativePath: String) {
        guard let vaultURL else {
            log.warning("Cannot rename directory: no vault URL")
            return
        }
        let oldURL = vaultURL.appendingPathComponent(oldRelativePath, isDirectory: true)
        let newURL = vaultURL.appendingPathComponent(newRelativePath, isDirectory: true)

        guard FileManager.default.fileExists(atPath: oldURL.path) else {
            // Directory doesn't exist on disk yet — create the new one instead
            createDirectory(relativePath: newRelativePath)
            return
        }

        do {
            // Ensure parent of new path exists
            let parentURL = newURL.deletingLastPathComponent()
            suppressFileWatcherForSelfOriginatedChange()
            try FileManager.default.createDirectory(
                at: parentURL, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: oldURL, to: newURL)
            log.info(
                "Renamed directory: \(oldRelativePath, privacy: .public) → \(newRelativePath, privacy: .public)"
            )
        } catch {
            log.error("Failed to rename directory: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Move a page's markdown file into a different vault subfolder and keep SwiftData in sync.
    func movePage(pageId: String, toSubfolder subfolder: String?) {
        guard let vaultURL else {
            log.warning("Cannot move page: no vault URL")
            return
        }

        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
        guard let page = try? context.fetch(descriptor).first else { return }

        let normalizedSubfolder: String? = {
            guard let subfolder else { return nil }
            let trimmed = subfolder.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }()

        let targetParentURL =
            normalizedSubfolder.map { vaultURL.appendingPathComponent($0, isDirectory: true) }
            ?? vaultURL

        do {
            suppressFileWatcherForSelfOriginatedChange()
            try FileManager.default.createDirectory(
                at: targetParentURL,
                withIntermediateDirectories: true
            )

            if let existingPath = page.filePath,
                FileManager.default.fileExists(atPath: existingPath)
            {
                let oldURL = URL(fileURLWithPath: existingPath)
                var newURL = targetParentURL.appendingPathComponent(oldURL.lastPathComponent)

                if newURL.path != oldURL.path {
                    let baseName = oldURL.deletingPathExtension().lastPathComponent
                    let ext = oldURL.pathExtension
                    var suffix = 1
                    while FileManager.default.fileExists(atPath: newURL.path) {
                        let candidateName =
                            suffix > 100
                            ? "\(baseName)-\(UUID().uuidString.prefix(8))"
                            : "\(baseName)-\(suffix)"
                        newURL = targetParentURL.appendingPathComponent(candidateName)
                            .appendingPathExtension(ext)
                        suffix += 1
                    }

                    try FileManager.default.moveItem(at: oldURL, to: newURL)
                }

                page.filePath = newURL.path
            } else {
                page.filePath = nil
            }

            page.subfolder = normalizedSubfolder
            page.updatedAt = .now
            try context.save()

            if page.filePath == nil {
                savePage(pageId: pageId)
            }
            eventBus?.emit(.vaultChanged)
        } catch {
            log.error("Failed to move page: \(error.localizedDescription, privacy: .public)")
        }
    }

}

@MainActor
enum VaultConnectionActions {
    static func selectVaultFolder(notesUI: NotesUIState, vaultSync: VaultSyncService) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder for your Epistemos vault"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        notesUI.resetForVaultSwitch()
        vaultSync.persistVaultSelection(url)
        vaultSync.startWatching(vaultURL: url)
    }

    static func disconnect(notesUI: NotesUIState, vaultSync: VaultSyncService) {
        notesUI.resetForVaultSwitch()
        vaultSync.stopWatching()
        vaultSync.dismissRecoveryIssue()
        vaultSync.clearPersistedVaultSelection()
        AppBootstrap.shared?.ambientManifest = nil
    }
}
