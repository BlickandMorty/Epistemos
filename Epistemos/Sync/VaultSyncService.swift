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
    private var indexActor: VaultIndexActor?
    private let modelContainer: ModelContainer

    private(set) var vaultURL: URL?
    private(set) var isWatching = false

    /// Whether the search index is currently being rebuilt.
    var isIndexing = false

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
                "📦 Resolved with security scope → \(resolved.path, privacy: .public) (stale=\(isStale))"
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
                    "📦 Resolved WITHOUT security scope → \(resolved.path, privacy: .public) (stale=\(isStale))"
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
            clearVaultData()
            return
        }

        let exists = FileManager.default.fileExists(atPath: url.path)
        if !exists {
            log.warning(
                "Vault directory not found at \(url.path, privacy: .public) — clearing bookmark")
            url.stopAccessingSecurityScopedResource()
            UserDefaults.standard.removeObject(forKey: "epistemos.vaultBookmark")
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
        }


        migrateToHybridSync()
        migrateFromExternalStorage()
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

    /// Delete all vault pages/folders from SwiftData.
    /// Called on every vault transition and startup failure to prevent stale ghost data.
    private func clearVaultData() {
        let context = modelContainer.mainContext
        do {
            try context.delete(model: SDPage.self)
            try context.delete(model: SDFolder.self)
            try context.save()
            Log.vault.info("Cleared all vault data from SwiftData")
        } catch {
            Log.vault.error("Failed to clear vault data: \(error.localizedDescription, privacy: .public)")
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

    /// One-time migration: compute body hashes for existing pages so they start "clean."
    /// Called once on first launch after the Apple Notes hybrid update.
    private func migrateToHybridSync() {
        let migrationKey = "epistemos.hybridSyncMigrated"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<SDPage>()
        guard let pages = try? context.fetch(descriptor) else { return }

        var migrated = 0
        for page in pages where page.lastSyncedBodyHash == nil {
            page.lastSyncedBodyHash = SDPage.bodyHash(page.loadBody(mapped: true))
            page.lastSyncedAt = .now
            page.needsVaultSync = false
            migrated += 1
        }

        if migrated > 0 {
            do {
                try context.save()
            } catch {
                Log.vault.error("Failed to save after hybrid sync migration: \(error.localizedDescription, privacy: .public)")
            }
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
        log.info("Hybrid sync migration: set hashes for \(migrated) existing pages")
    }

    /// One-time migration: body moved from @Attribute(.externalStorage) to inline SQLite.
    /// External storage data may be lost during schema migration, so force importVault
    /// to re-read every .md file by resetting all page timestamps to .distantPast.
    private func migrateFromExternalStorage() {
        let migrationKey = "epistemos.inlineBodyMigrated"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<SDPage>()
        guard let pages = try? context.fetch(descriptor) else { return }

        for page in pages {
            page.updatedAt = .distantPast
        }
        do {
            try context.save()
        } catch {
            Log.vault.error("Failed to save after external storage migration: \(error.localizedDescription, privacy: .public)")
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
        log.info("Inline body migration: reset \(pages.count) page timestamps for re-import")
    }

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

        let actor = indexActor
        Task {
            do {
                let exportedPath = try await actor?.exportPage(pageId: pageId, to: vaultURL)

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
                    log.info("Saved page to vault: \(path, privacy: .public)")
                }
                await MainActor.run { [weak self] in
                    self?.eventBus?.emit(.vaultChanged)
                }
            } catch {
                log.error("Failed to save page \(pageId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Save all dirty pages to their vault .md files.
    func saveAllDirtyPages() {
        guard let vaultURL else { return }

        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<SDPage>()
        guard let allPages = try? context.fetch(descriptor) else { return }

        let dirtyPages = allPages.filter(\.isDirtyVault)
        guard !dirtyPages.isEmpty else {
            log.info("No dirty pages to save")
            return
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

        let actor = indexActor
        Task {
            for pageId in dirtyIds {
                do {
                    _ = try await actor?.exportPage(pageId: pageId, to: vaultURL)
                } catch {
                    log.error("Failed to save page \(pageId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }

            await MainActor.run {
                for pageId in dirtyIds {
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

            log.info("Saved \(dirtyIds.count) dirty pages to vault")
        }
    }

    /// Auto-save interval in seconds. 0 = disabled.
    var autoSaveInterval: TimeInterval {
        get { UserDefaults.standard.double(forKey: "epistemos.autoSaveInterval") }
        set {
            UserDefaults.standard.set(newValue, forKey: "epistemos.autoSaveInterval")
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
                _ = try await self?.indexActor?.exportPage(pageId: pageId, to: vaultURL)
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
            log.info("Deleted page file: \(filePath, privacy: .public)")
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
