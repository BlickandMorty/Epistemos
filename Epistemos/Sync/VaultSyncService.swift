import Foundation
import CryptoKit
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

private let log = Logger(subsystem: "com.epistemos", category: "VaultSync")

@MainActor @Observable
final class VaultSyncService {
    typealias ExportPageOperation = @Sendable (String, URL) async throws -> String?

    private var indexActor: VaultIndexActor?
    private let modelContainer: ModelContainer
    var exportPageOverride: ExportPageOperation?

    private(set) var vaultURL: URL?
    private(set) var isWatching = false

    /// Whether the vault is being imported/indexed. Starts true if a vault
    /// bookmark exists so the landing page shows "wait...indexing" on the
    /// very first frame, before the import Task even begins.
    var isIndexing: Bool = UserDefaults.standard.data(forKey: "epistemos.vaultBookmark") != nil

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

    // MARK: - File Watching
    private var fileWatcherSource: DispatchSourceFileSystemObject?
    private var fileWatcherFD: Int32 = -1
    private var fileWatchDebounceTask: Task<Void, Never>?

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func setVaultURLForTesting(_ vaultURL: URL?) {
        self.vaultURL = vaultURL
    }

    func setExportPageOverrideForTesting(_ exportPageOverride: ExportPageOperation?) {
        self.exportPageOverride = exportPageOverride
    }

    private func exportPage(pageId: String, to vaultURL: URL) async throws -> String? {
        if let exportPageOverride {
            return try await exportPageOverride(pageId, vaultURL)
        }
        return try await indexActor?.exportPage(pageId: pageId, to: vaultURL)
    }

    // MARK: - Lifecycle

    /// Restore vault from saved bookmark on app launch.
    /// Call from RootView.onAppear (after NSApp is alive).
    func restoreVaultFromBookmark() {
        // Migration: check old domains for vault bookmark data.
        // 1. Brainiac.epistemos (rename session stored "epistemos.vaultBookmark" there)
        // 2. com.lucid.app (v2 stored "epistemos.vaultBookmark" there)
        // After bundle ID reverted to Brainiac.lucid-v3, those domains are orphaned.
        var data = UserDefaults.standard.data(forKey: "epistemos.vaultBookmark")
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
                        UserDefaults.standard.set(oldData, forKey: "epistemos.vaultBookmark")
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
            log.info("📦 No bookmark data found anywhere — clearing vault data")
            isIndexing = false
            clearVaultData()
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
            log.warning("📦 Failed to resolve vault bookmark — clearing stale data")
            UserDefaults.standard.removeObject(forKey: "epistemos.vaultBookmark")
            isIndexing = false
            clearVaultData()
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
                UserDefaults.standard.set(fresh, forKey: "epistemos.vaultBookmark")
                log.info("Created fresh security-scoped bookmark for vault")
            }
        }
        if !gained {
            log.warning("Security scope not granted for vault bookmark — clearing")
            UserDefaults.standard.removeObject(forKey: "epistemos.vaultBookmark")
            isIndexing = false
            clearVaultData()
            return
        }

        let exists = FileManager.default.fileExists(atPath: url.path)
        if !exists {
            log.warning(
                "Vault directory not found at \(url.path, privacy: .private) — clearing bookmark")
            url.stopAccessingSecurityScopedResource()
            UserDefaults.standard.removeObject(forKey: "epistemos.vaultBookmark")
            isIndexing = false
            clearVaultData()
            return
        }

        if isStale {
            if let fresh = try? url.bookmarkData(
                options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            {
                UserDefaults.standard.set(fresh, forKey: "epistemos.vaultBookmark")
            }
        }

        // Pass scopeAlreadyAcquired=true so startWatching doesn't double-acquire
        startWatching(vaultURL: url, scopeAlreadyAcquired: true)
    }

    /// Start watching a vault directory. Performs initial import, then watches for changes.
    /// - Parameter scopeAlreadyAcquired: If true, the caller has already called
    ///   `startAccessingSecurityScopedResource()` — we track it but don't call again.
    func startWatching(vaultURL: URL, scopeAlreadyAcquired: Bool = false) {
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

        // Create background indexer
        indexActor = VaultIndexActor(modelContainer: modelContainer)

        // Create FTS5 search index
        do {
            let svc = try SearchIndexService()
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

            // Diff-sync FTS5 index with SwiftData (catches stale/missing search.sqlite)
            if let svc, let actor {
                let timestamps = await actor.allPageTimestamps()
                do {
                    try await svc.diffSync(
                        swiftDataPages: timestamps,
                        fullPageProvider: { id in await actor.fullPageData(for: id) }
                    )
                } catch {
                    log.error("FTS5 diff-sync failed: \(error.localizedDescription, privacy: .public)")
                }
            }
            await MainActor.run { self.isIndexing = false }
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

        // Build ambient manifest eagerly after import completes
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
            return try svc.search(query: query).map(\.pageId)
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
            let pages = await actor.allPagesForRebuild()
            do {
                try svc.rebuildFromSwiftData(pages)
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

        // After import, re-fetch pages and update hashes
        let descriptor = FetchDescriptor<SDPage>()
        guard let updatedPages = try? context.fetch(descriptor) else { return [] }

        // Update hashes for all pages (single pass — avoids reading each body from disk twice)
        for page in updatedPages {
            page.lastSyncedBodyHash = SDPage.bodyHash(page.loadBody(mapped: true))
            page.lastSyncedAt = .now
            page.needsVaultSync = false
        }
        do {
            try context.save()
        } catch {
            Log.vault.error("Failed to save after sync-from-vault hash update: \(error.localizedDescription, privacy: .public)")
        }

        log.info("Sync from vault complete: \(updatedPages.count) pages")
        eventBus?.emit(.vaultChanged)
        return []
    }

    // MARK: - Write Operations

    // MARK: - Explicit Save (Apple Notes Hybrid)

    /// Save a single page to its vault .md file and update sync tracking fields.
    func savePage(pageId: String) {
        captureVersionIfNeeded(pageId: pageId)

        guard let vaultURL else {
            log.warning("Cannot save page: no vault URL")
            return
        }

        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
        guard (try? context.fetch(descriptor).first) != nil else { return }

        do {
            try context.save()
        } catch {
            Log.vault.error("Failed to save before page export (\(pageId.prefix(8), privacy: .public)): \(error.localizedDescription, privacy: .public)")
        }

        Task {
            do {
                let exportedPath = try await self.exportPage(pageId: pageId, to: vaultURL)

                await MainActor.run {
                    let desc = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
                    if let page = try? context.fetch(desc).first {
                        page.lastSyncedBodyHash = SDPage.bodyHash(page.loadBody())
                        page.lastSyncedAt = .now
                        page.needsVaultSync = false
                        do {
                            try context.save()
                        } catch {
                            Log.vault.error("Failed to save sync tracking for page (\(pageId.prefix(8), privacy: .public)): \(error.localizedDescription, privacy: .public)")
                        }
                        SpotlightIndexer.index(page)
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
    }

    /// Save all dirty pages to their vault .md files.
    @discardableResult
    func saveAllDirtyPages() -> Task<Void, Never>? {
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

        let dirtyIds = dirtyPages.map(\.id)

        // Capture versions before saving
        for pageId in dirtyIds {
            captureVersionIfNeeded(pageId: pageId)
        }

        do {
            try context.save()
        } catch {
            Log.vault.error("Failed to save before dirty pages export: \(error.localizedDescription, privacy: .public)")
        }
        let task = Task { [weak self] in
            guard let self else { return }
            var successfulIds: [String] = []
            successfulIds.reserveCapacity(dirtyIds.count)

            for pageId in dirtyIds {
                do {
                    _ = try await self.exportPage(pageId: pageId, to: vaultURL)
                    successfulIds.append(pageId)
                } catch {
                    log.error("Failed to save page \(pageId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }

            await MainActor.run {
                for pageId in successfulIds {
                    let desc = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
                    if let page = try? context.fetch(desc).first {
                        page.lastSyncedBodyHash = SDPage.bodyHash(page.loadBody(mapped: true))
                        page.lastSyncedAt = .now
                        page.needsVaultSync = false
                        SpotlightIndexer.index(page)
                    }
                }
                do {
                    try context.save()
                } catch {
                    Log.vault.error("Failed to save sync tracking after dirty pages export: \(error.localizedDescription, privacy: .public)")
                }
            }

            log.info("Saved \(successfulIds.count) of \(dirtyIds.count) dirty pages to vault")
        }
        return task
    }

    /// Auto-save interval in seconds. 0 = disabled.
    /// Stored property so @Observable tracks it and SwiftUI re-renders on change.
    var autoSaveInterval: TimeInterval = UserDefaults.standard.double(forKey: "epistemos.autoSaveInterval") {
        didSet {
            UserDefaults.standard.set(autoSaveInterval, forKey: "epistemos.autoSaveInterval")
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
                guard !Task.isCancelled, let self else { return }
                self.saveAllDirtyPages()
            }
        }
    }

    /// Periodic manifest refresh (5-minute interval) as safety net for external edits.
    private func startManifestRefreshTimer() {
        manifestRefreshTask?.cancel()
        manifestRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                guard !Task.isCancelled, let self else { return }
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
        if let source = fileWatcherSource {
            source.cancel()
            fileWatcherSource = nil
            fileWatcherFD = -1
        }
    }

    /// Debounced handler for file system change events.
    /// Waits 2 seconds after the last change before re-importing, so rapid
    /// saves (e.g. typing in an external editor) don't trigger 50 reimports.
    private func handleFileSystemChange() {
        fileWatchDebounceTask?.cancel()
        fileWatchDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self, let vaultURL, let actor = indexActor else { return }

            log.info("File watcher: vault changed externally — re-importing")
            do {
                try await actor.importVault(from: vaultURL)
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

    /// Delete the .md file for a page from the vault.
    /// Called when user deletes a page from the sidebar — prevents orphan resurrection on reimport.
    func deletePageFromDisk(filePath: String?) {
        guard let filePath, FileManager.default.fileExists(atPath: filePath) else { return }

        do {
            try FileManager.default.removeItem(atPath: filePath)
            log.info("Deleted page file: \(filePath, privacy: .private)")
            eventBus?.emit(.vaultChanged)
        } catch {
            log.error("Failed to delete page file: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Delete a physical directory from the vault.
    /// Called when user deletes a folder — prevents folder resurrection on reimport.
    func deleteDirectory(relativePath: String) {
        guard let vaultURL else { return }
        let dirURL = vaultURL.appendingPathComponent(relativePath, isDirectory: true)
        guard FileManager.default.fileExists(atPath: dirURL.path) else { return }

        do {
            try FileManager.default.removeItem(at: dirURL)
            log.info("Deleted directory: \(relativePath, privacy: .public)")
        } catch {
            log.error(
                "Failed to delete directory \(relativePath, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
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

}
