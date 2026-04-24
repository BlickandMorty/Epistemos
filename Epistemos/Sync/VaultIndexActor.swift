import CoreSpotlight
import Foundation
import SwiftData
import os

/// Posted when vault folder relationships are repaired, so sidebar can rebuild its cache.
nonisolated let vaultFoldersRepairedNotification = Notification.Name("VaultFoldersRepaired")

// MARK: - VaultIndexActor
// Background actor for all SwiftData write operations that shouldn't block the main thread.
// Handles vault imports, bulk operations, and re-indexing.
//
// @ModelActor auto-generates the modelContainer and modelExecutor properties,
// and gives this actor its own ModelContext isolated from the main thread.

@ModelActor
actor VaultIndexActor {
    struct SpotlightReindexSnapshot: Sendable {
        let lastIndexDate: Date
        let changedPageCount: Int
        let willIndex: Bool
    }

    struct VaultImportComparableCounts: Sendable, Equatable {
        let trackedVaultPageCount: Int
        let uniqueTrackedVaultPathCount: Int
        let duplicateTrackedPathCount: Int
        let nonVaultPageCount: Int
    }

    struct VaultFolderSelectionAssessment: Sendable, Equatable {
        let importableNoteFileCount: Int
        let otherRegularFileCount: Int
        let scannedRegularFileCount: Int
        let reachedScanLimit: Bool

        var shouldConfirmSelection: Bool {
            if importableNoteFileCount == 0 {
                return otherRegularFileCount >= 32
            }
            return otherRegularFileCount >= max(64, importableNoteFileCount * 8)
        }

        var confirmationMessage: String {
            let scanScope =
                reachedScanLimit
                ? "in the first \(scannedRegularFileCount) files Epistemos checked"
                : "in this folder"

            if importableNoteFileCount == 0 {
                return """
                Epistemos did not find any Markdown or plain-text note files \(scanScope). \
                This folder may not actually be a notes vault.
                """
            }

            return """
            Epistemos found only \(importableNoteFileCount) note file\(importableNoteFileCount == 1 ? "" : "s") \
            but \(otherRegularFileCount) other file\(otherRegularFileCount == 1 ? "" : "s") \(scanScope). \
            If this is not really your notes workspace, switching to it can make the app look empty or noisy.
            """
        }
    }

    private let log = Logger(subsystem: "com.epistemos", category: "VaultIndex")
    nonisolated private static let staticLog = Logger(subsystem: "com.epistemos", category: "VaultIndex")
    nonisolated static let spotlightIndexDateKey = "epistemos.lastSpotlightIndexDate"
    nonisolated private static let excludedDirs: Set<String> = [
        "node_modules", ".git", ".build", "Pods", "DerivedData", ".svn", ".venv", "venv",
        "__pycache__", ".pytest_cache", ".mypy_cache",
    ]
    nonisolated private static let excludedSuffixes: Set<String> = [
        ".photoslibrary", ".app", ".framework", ".xcodeproj", ".xcworkspace",
    ]

    nonisolated private static func canonicalFilePath(_ path: String) -> String {
        URL(fileURLWithPath: path)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }

    // MARK: - FTS5 Search Index (GRDB)
    typealias SaveContextOperation = @Sendable (String) throws -> Bool

    private var searchService: SearchIndexService?
    private var saveContextOverride: SaveContextOperation?

    func setSearchService(_ service: SearchIndexService) {
        self.searchService = service
    }

    func setSaveContextOverrideForTesting(_ saveContextOverride: SaveContextOperation?) {
        self.saveContextOverride = saveContextOverride
    }

    private func fetchAll<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        label: String
    ) -> [T]? {
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            log.error(
                "VaultIndex: failed to fetch \(label, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private func fetchFirst<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        label: String
    ) -> T? {
        fetchAll(descriptor, label: label)?.first
    }

    private func fetchCount<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        label: String
    ) -> Int? {
        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            log.error(
                "VaultIndex: failed to fetch count for \(label, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private func saveContext(_ label: String) throws {
        if let saveContextOverride {
            let handled = try saveContextOverride(label)
            if handled {
                return
            }
        }
        do {
            try modelContext.save()
        } catch {
            log.error(
                "VaultIndex: failed to save \(label, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    private nonisolated static func isRegularFile(_ fileURL: URL, label: String) -> Bool {
        do {
            return try fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true
        } catch {
            staticLog.error(
                "VaultIndex: failed to inspect \(label, privacy: .public) at \(fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }

    private nonisolated static func contentModificationDate(
        for fileURL: URL,
        label: String,
        logWhenMissing: Bool = true
    ) -> Date? {
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            if logWhenMissing {
                staticLog.error(
                    "VaultIndex: missing \(label, privacy: .public) at \(fileURL.path, privacy: .public) while reading modification date"
                )
            }
            return nil
        }

        do {
            return try fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        } catch {
            staticLog.error(
                "VaultIndex: failed to read modification date for \(label, privacy: .public) at \(fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private nonisolated static func mappedFileData(
        at fileURL: URL,
        label: String
    ) -> Data? {
        do {
            return try Data(contentsOf: fileURL, options: .mappedIfSafe)
        } catch {
            staticLog.error(
                "VaultIndex: failed to read \(label, privacy: .public) at \(fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    nonisolated static func shouldSkipDescendants(for name: String) -> Bool {
        excludedDirs.contains(name) || excludedSuffixes.contains(where: { name.hasSuffix($0) })
    }

    /// Iterate a `FileManager.DirectoryEnumerator` synchronously and
    /// return the list of importable note-file URLs. Exposed as a
    /// sync nonisolated helper because
    /// `DirectoryEnumerator.makeIterator()` is unavailable from async
    /// contexts in Swift 6 — the async `importVault` now drains this
    /// into an array up-front, then iterates the array with `await`.
    /// Filter logic matches the former inline iteration:
    /// `shouldSkipDescendants` → `skipDescendants()`,
    /// `isImportableNoteFile` gate.
    nonisolated static func drainEnumerator(
        _ enumerator: FileManager.DirectoryEnumerator
    ) -> [URL] {
        var drained: [URL] = []
        for case let fileURL as URL in enumerator {
            let name = fileURL.lastPathComponent
            if shouldSkipDescendants(for: name) {
                enumerator.skipDescendants()
                continue
            }
            guard isImportableNoteFile(fileURL) else { continue }
            drained.append(fileURL)
        }
        return drained
    }

    private static let importableExtensions: Set<String> = [
        // Notes
        "md", "markdown", "txt",
        // Code files
        "swift", "rs", "py", "pyw", "js", "mjs", "cjs", "jsx", "ts", "mts", "tsx",
        "json", "jsonl", "html", "htm", "css", "scss", "less",
        "sh", "bash", "zsh", "fish",
        "go", "c", "h", "cpp", "cc", "cxx", "hpp", "hxx", "mm",
        "yaml", "yml", "toml", "xml", "plist", "svg",
        "gd", "lua", "rb", "java", "kt", "kts", "sql",
        "r", "zig", "wgsl", "glsl", "metal", "hlsl",
    ]

    nonisolated static func isImportableNoteFile(_ fileURL: URL) -> Bool {
        let ext = fileURL.pathExtension.lowercased()
        return importableExtensions.contains(ext)
    }

    nonisolated static func countImportableNoteFiles(in url: URL) -> Int {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path), fm.isReadableFile(atPath: url.path) else { return 0 }
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return 0
        }

        var count = 0
        for case let fileURL as URL in enumerator {
            let name = fileURL.lastPathComponent
            if shouldSkipDescendants(for: name) {
                enumerator.skipDescendants()
                continue
            }
            guard isImportableNoteFile(fileURL) else { continue }
            count += 1
        }
        return count
    }

    nonisolated static func vaultFolderSelectionAssessment(
        for url: URL,
        scanLimit: Int = 256
    ) -> VaultFolderSelectionAssessment {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path), fm.isReadableFile(atPath: url.path) else {
            return VaultFolderSelectionAssessment(
                importableNoteFileCount: 0,
                otherRegularFileCount: 0,
                scannedRegularFileCount: 0,
                reachedScanLimit: false
            )
        }

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return VaultFolderSelectionAssessment(
                importableNoteFileCount: 0,
                otherRegularFileCount: 0,
                scannedRegularFileCount: 0,
                reachedScanLimit: false
            )
        }

        var importableNoteFileCount = 0
        var otherRegularFileCount = 0
        var scannedRegularFileCount = 0
        var reachedScanLimit = false

        for case let fileURL as URL in enumerator {
            let name = fileURL.lastPathComponent
            if shouldSkipDescendants(for: name) {
                enumerator.skipDescendants()
                continue
            }

            guard Self.isRegularFile(fileURL, label: "vault selection candidate") else {
                continue
            }

            scannedRegularFileCount += 1
            if isImportableNoteFile(fileURL) {
                importableNoteFileCount += 1
            } else {
                otherRegularFileCount += 1
            }

            if scannedRegularFileCount >= scanLimit {
                reachedScanLimit = true
                break
            }
        }

        return VaultFolderSelectionAssessment(
            importableNoteFileCount: importableNoteFileCount,
            otherRegularFileCount: otherRegularFileCount,
            scannedRegularFileCount: scannedRegularFileCount,
            reachedScanLimit: reachedScanLimit
        )
    }

    nonisolated static func isModificationDate(_ lhs: Date?, newerThan rhs: Date?) -> Bool {
        guard let lhs, let rhs else { return false }
        return lhs > rhs
    }

    nonisolated static func comparableVaultPageCounts(
        pages: [SDPage],
        in vaultURL: URL
    ) -> VaultImportComparableCounts {
        let vaultRoot = vaultURL.standardizedFileURL.path
        let trackedPrefix = vaultRoot.hasSuffix("/") ? vaultRoot : vaultRoot + "/"
        var uniqueTrackedPaths = Set<String>()
        var trackedVaultPageCount = 0
        var duplicateTrackedPathCount = 0
        var nonVaultPageCount = 0

        for page in pages {
            guard let filePath = page.filePath else {
                nonVaultPageCount += 1
                continue
            }

            let standardizedPath = URL(fileURLWithPath: filePath).standardizedFileURL.path
            guard standardizedPath.hasPrefix(trackedPrefix),
                  isImportableNoteFile(URL(fileURLWithPath: standardizedPath))
            else {
                nonVaultPageCount += 1
                continue
            }

            trackedVaultPageCount += 1
            if !uniqueTrackedPaths.insert(standardizedPath).inserted {
                duplicateTrackedPathCount += 1
            }
        }

        return VaultImportComparableCounts(
            trackedVaultPageCount: trackedVaultPageCount,
            uniqueTrackedVaultPathCount: uniqueTrackedPaths.count,
            duplicateTrackedPathCount: duplicateTrackedPathCount,
            nonVaultPageCount: nonVaultPageCount
        )
    }

    // MARK: - Full Vault Import

    private struct UpdatedPageSnapshot {
        let pageId: String
        let body: String
        let filePath: String?
        let wordCount: Int
        let emoji: String
        let lastSyncedBodyHash: String?
        let lastSyncedAt: Date?
        let needsVaultSync: Bool
        let updatedAt: Date
        let title: String
        let tags: [String]
        let frontMatter: [String: String]
        let parentPageId: String?
        let templateId: String?
        let subfolder: String?
        let isJournal: Bool
        let journalDate: String?
    }

    private enum PageUpsertResult {
        case unchanged
        case updated(UpdatedPageSnapshot)
        case inserted(SDPage)
    }

    private func discardPendingImportedPages(
        _ pendingInsertedPageIDs: [String],
        failedSaveLabel: String
    ) {
        guard !pendingInsertedPageIDs.isEmpty else { return }

        let seenPageIDs = Set(pendingInsertedPageIDs)
        for pageID in seenPageIDs {
            NoteFileStorage.deleteBody(pageId: pageID)

            do {
                try searchService?.delete(pageId: pageID)
            } catch {
                log.error(
                    "VaultIndex: failed to remove search row for discarded imported page \(pageID, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        log.error(
            "VaultIndex: discarded \(seenPageIDs.count, privacy: .public) pending imported pages after failed \(failedSaveLabel, privacy: .public)"
        )
    }

    private func restorePendingUpdatedPages(
        _ pendingUpdatedPages: [UpdatedPageSnapshot],
        failedSaveLabel: String
    ) {
        guard !pendingUpdatedPages.isEmpty else { return }

        var restoredPageIDs = Set<String>()
        var restoredCount = 0

        for snapshot in pendingUpdatedPages where restoredPageIDs.insert(snapshot.pageId).inserted {
            let pageId = snapshot.pageId
            if let page = fetchFirst(
                FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId }),
                label: "updated page rollback \(pageId)"
            ) {
                page.filePath = snapshot.filePath
                page.wordCount = snapshot.wordCount
                page.emoji = snapshot.emoji
                page.lastSyncedBodyHash = snapshot.lastSyncedBodyHash
                page.lastSyncedAt = snapshot.lastSyncedAt
                page.needsVaultSync = snapshot.needsVaultSync
                page.updatedAt = snapshot.updatedAt
                page.title = snapshot.title
                page.tags = snapshot.tags
                page.frontMatter = snapshot.frontMatter
                page.parentPageId = snapshot.parentPageId
                page.templateId = snapshot.templateId
                page.subfolder = snapshot.subfolder
                page.isJournal = snapshot.isJournal
                page.journalDate = snapshot.journalDate
                page.saveBody(snapshot.body)
                BlockMirror.sync(pageId: snapshot.pageId, body: snapshot.body, modelContext: modelContext)
            } else {
                NoteFileStorage.writeBody(pageId: snapshot.pageId, content: snapshot.body)
            }
            upsertSearchIndex(
                pageId: snapshot.pageId,
                title: snapshot.title,
                body: snapshot.body,
                tags: snapshot.tags,
                updatedAt: snapshot.updatedAt
            )

            let restoredPageId = snapshot.pageId
            Task { @MainActor in
                NoteFileStorage.notifyBodyChanged(pageId: restoredPageId)
            }

            restoredCount += 1
        }

        do {
            try saveContext("updated page rollback state")
        } catch {
            log.error(
                "VaultIndex: failed to persist restored updated pages after failed \(failedSaveLabel, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }

        log.error(
            "VaultIndex: restored \(restoredCount, privacy: .public) pending updated pages after failed \(failedSaveLabel, privacy: .public)"
        )
    }

    /// Import vault incrementally: only process new, modified, or deleted files.
    /// Compares file modification dates against stored SDPage.updatedAt to skip unchanged files.
    func importVault(from url: URL, deleteMissingFiles: Bool = true) async throws {
        let fm = FileManager.default

        guard fm.fileExists(atPath: url.path) else {
            log.warning("Vault directory does not exist: \(url.path, privacy: .private)")
            return
        }

        guard fm.isReadableFile(atPath: url.path) else {
            log.error(
                "Vault directory exists but is not readable (security scope may be missing): \(url.path, privacy: .private)"
            )
            return
        }

        // ── 1. Build lookup of existing pages by filePath ──
        let existingDescriptor = FetchDescriptor<SDPage>()
        let existingPages = try modelContext.fetch(existingDescriptor)
        var existingByPath: [String: SDPage] = [:]
        var allExistingPaths = Set<String>()
        for page in existingPages {
            if let fp = page.filePath {
                allExistingPaths.insert(fp)
                existingByPath[fp] = page
                existingByPath[Self.canonicalFilePath(fp)] = page
            }
        }

        // ── 2. Enumerate vault files on disk ──
        let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        guard let enumerator else {
            log.error("Failed to create directory enumerator for: \(url.path, privacy: .private)")
            return
        }

        var diskPaths = Set<String>()
        var diskPathAliases = Set<String>()
        var insertCount = 0
        var updateCount = 0
        var skipCount = 0
        var changeCount = 0
        var unreadableCount = 0
        var pendingInsertedPages = [SDPage]()
        var pendingUpdatedPages = [UpdatedPageSnapshot]()
        let batchSize = 200
        var completedScan = !Task.isCancelled

        func saveImportProgress(_ label: String) throws {
            do {
                try saveContext(label)
                pendingInsertedPages.removeAll(keepingCapacity: true)
                pendingUpdatedPages.removeAll(keepingCapacity: true)
            } catch {
                let pendingInsertedPageIDs = pendingInsertedPages.map(\.id)
                modelContext.rollback()
                modelContext.processPendingChanges()
                discardPendingImportedPages(pendingInsertedPageIDs, failedSaveLabel: label)
                restorePendingUpdatedPages(pendingUpdatedPages, failedSaveLabel: label)
                throw error
            }
        }

        if !completedScan {
            log.info("Vault import cancelled before enumeration started — skipping deletion pass")
        }

        if completedScan {
            // FileManager.DirectoryEnumerator.makeIterator() isn't
            // available from async contexts (Swift 6). Drain the
            // enumerator inside a synchronous helper first, then
            // iterate the resulting array asynchronously.
            // `skipDescendants` is still called during the sync pass
            // so the filter is identical to the pre-migration
            // iteration behaviour.
            let drained = Self.drainEnumerator(enumerator)

            for fileURL in drained {
                // Allow cooperative cancellation during large vault imports
                guard !Task.isCancelled else {
                    completedScan = false
                    log.info("Vault import cancelled — indexed \(insertCount + updateCount) files before cancellation")
                    break
                }

                let filePath = fileURL.path
                diskPaths.insert(filePath)
                diskPathAliases.insert(filePath)
                diskPathAliases.insert(Self.canonicalFilePath(filePath))

                // Get file modification date
                let fileModDate =
                    Self.contentModificationDate(for: fileURL, label: "vault import file")
                    ?? .distantFuture

                // Pre-check readability to count unreadable files separately.
                guard fm.isReadableFile(atPath: filePath) else {
                    log.warning("Skipping unreadable file: \(fileURL.lastPathComponent, privacy: .public)")
                    unreadableCount += 1
                    continue
                }

                let existingPage = existingByPath[filePath] ?? existingByPath[Self.canonicalFilePath(filePath)]
                if let existingPage {
                    let needsLocalBodyRebuild =
                        !NoteFileStorage.bodyExists(pageId: existingPage.id)
                        && NoteFileStorage.readBody(
                            pageId: existingPage.id,
                            mapped: false,
                            fast: true
                        ).isEmpty
                    // File exists in DB — check if it changed
                    if fileModDate > existingPage.updatedAt || needsLocalBodyRebuild {
                        // File was modified externally — re-read and update.
                        // Phase R.3: `upsertPage` is now async (body read
                        // preserves managed sidecars before gateway fallback).
                        // Dropping the
                        // `autoreleasepool` wrapper is safe here — the
                        // outer sync import loop still has its own
                        // scratch context that releases between pages.
                        do {
                            let result = try await upsertPage(from: fileURL, vaultURL: url)
                            switch result {
                            case .updated(let snapshot):
                                pendingUpdatedPages.append(snapshot)
                                updateCount += 1
                                changeCount += 1
                            case .inserted(let page):
                                pendingInsertedPages.append(page)
                                insertCount += 1
                                changeCount += 1
                            case .unchanged:
                                skipCount += 1
                            }
                        } catch {
                            log.error(
                                "Failed to update \(fileURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
                            )
                        }
                    } else {
                        // Unchanged — skip entirely (no disk read, no body load)
                        skipCount += 1
                    }
                } else {
                    // New file — insert. Same Phase R.3 note as above.
                    do {
                        let result = try await upsertPage(from: fileURL, vaultURL: url)
                        switch result {
                        case .inserted(let page):
                            pendingInsertedPages.append(page)
                            insertCount += 1
                            changeCount += 1
                        case .updated(let snapshot):
                            pendingUpdatedPages.append(snapshot)
                            updateCount += 1
                            changeCount += 1
                        case .unchanged:
                            skipCount += 1
                        }
                    } catch {
                        log.error(
                            "Failed to index \(fileURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
                        )
                    }
                }

                if changeCount > 0 && changeCount.isMultiple(of: batchSize) {
                    try saveImportProgress("vault import batch progress")
                    log.info("Vault import progress: \(changeCount, privacy: .public) changes")
                }
            }
        }

        let existingComparableCounts = Self.comparableVaultPageCounts(
            pages: existingPages,
            in: url
        )
        if completedScan &&
            diskPaths.isEmpty &&
            existingComparableCounts.trackedVaultPageCount > 0
        {
            log.warning(
                "Vault import returned 0 disk files while \(existingComparableCounts.uniqueTrackedVaultPathCount) tracked vault pages already exist — treating the scan as transient and skipping destructive reconciliation"
            )
            return
        }

        // ── 3. Delete pages whose files no longer exist on disk ──
        var deleteCount = 0
        if completedScan && deleteMissingFiles {
            let deletedPaths = allExistingPaths.filter { path in
                !diskPathAliases.contains(path)
                    && !diskPathAliases.contains(Self.canonicalFilePath(path))
            }
            for path in deletedPaths {
                if let page = existingByPath[path] {
                    SpotlightIndexer.deindex(page.id)
                    modelContext.delete(page)
                    deleteCount += 1
                }
            }
        } else if !completedScan {
            log.info("Vault import incomplete — skipping deletion pass for tracked pages")
        } else {
            log.info("Vault import ran in non-destructive mode — skipping deletion pass for tracked pages")
        }

        if changeCount > 0 || deleteCount > 0 {
            try saveImportProgress("vault import final changes")
        }

        // Synthesize folders from subfolder paths.
        // Always run when there are inserts/deletes, OR when orphaned pages exist
        // (pages with subfolder set but no folder relationship — can happen after
        // DB migration, schema reset, or if synthesis failed on a prior run).
        if insertCount > 0 || deleteCount > 0 {
            try synthesizeFoldersFromSubfolders()
        } else {
            try repairOrphanedFolderRelationships(vaultURL: url)
        }

        // Diagnostic: compare disk file count only against vault-backed note pages.
        if let currentPages = fetchAll(
            FetchDescriptor<SDPage>(),
            label: "current vault pages for import diagnostics"
        ) {
            let comparableCounts = Self.comparableVaultPageCounts(pages: currentPages, in: url)
            log.info(
                "Vault import complete: \(diskPaths.count) files on disk, \(comparableCounts.uniqueTrackedVaultPathCount) tracked vault pages in DB → \(insertCount) new, \(updateCount) updated, \(skipCount) unchanged, \(deleteCount) deleted, \(unreadableCount) unreadable, \(comparableCounts.nonVaultPageCount) non-vault pages, \(comparableCounts.duplicateTrackedPathCount) duplicate tracked paths"
            )
            if completedScan &&
                deleteMissingFiles &&
                diskPaths.count != comparableCounts.uniqueTrackedVaultPathCount
            {
                log.warning(
                    "Vault import mismatch: \(diskPaths.count) disk files vs \(comparableCounts.uniqueTrackedVaultPathCount) tracked DB paths (delta: \(comparableCounts.uniqueTrackedVaultPathCount - diskPaths.count), tracked pages: \(comparableCounts.trackedVaultPageCount), non-vault pages: \(comparableCounts.nonVaultPageCount), duplicate tracked paths: \(comparableCounts.duplicateTrackedPathCount))"
                )
            }
        } else {
            log.warning("Vault import complete, but tracked page diagnostics were unavailable")
        }
    }

    /// Post-import pass: create SDFolder objects from unique `subfolder` directory paths
    /// found in imported pages. Handles nested paths ("A/B/C") by creating the full chain.
    /// Wires `page.folder` to the leaf folder matching its `subfolder` path.
    private func synthesizeFoldersFromSubfolders() throws {
        // Fetch all imported pages that live in a subdirectory
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate { $0.subfolder != nil }
        )
        let pagesWithSubfolder = try modelContext.fetch(descriptor)
        guard !pagesWithSubfolder.isEmpty else { return }

        // Collect unique subfolder paths
        var uniquePaths = Set<String>()
        for page in pagesWithSubfolder {
            if let sub = page.subfolder, !sub.isEmpty {
                uniquePaths.insert(sub)
            }
        }
        guard !uniquePaths.isEmpty else { return }

        // Pre-load existing folders so we don't create duplicates on incremental import
        var foldersByPath: [String: SDFolder] = [:]
        let existingFolderDescriptor = FetchDescriptor<SDFolder>()
        let existingFolders = try modelContext.fetch(existingFolderDescriptor)
        for folder in existingFolders {
            let path = folder.relativePath
            if !path.isEmpty {
                foldersByPath[path] = folder
            }
        }

        for path in uniquePaths.sorted() {
            let segments = path.components(separatedBy: "/").filter { !$0.isEmpty }
            var currentPath = ""
            var parentFolder: SDFolder? = nil

            for segment in segments {
                currentPath = currentPath.isEmpty ? segment : currentPath + "/" + segment

                if let existing = foldersByPath[currentPath] {
                    parentFolder = existing
                    continue
                }

                let folder = SDFolder(name: segment)
                folder.parent = parentFolder
                modelContext.insert(folder)
                foldersByPath[currentPath] = folder
                parentFolder = folder
            }
        }

        // Wire page.folder to the leaf folder matching each page's subfolder path
        for page in pagesWithSubfolder {
            if let sub = page.subfolder, let folder = foldersByPath[sub] {
                page.folder = folder
            }
        }

        // Restore isCollection for any folder names the user previously marked as collections.
        // CollectionRegistry persists folder names in UserDefaults so they survive across launches.
        let registry = CollectionRegistry.shared
        for folder in foldersByPath.values where registry.isCollection(folder.name) {
            folder.isCollection = true
        }

        try saveContext("synthesized folders from subfolders")
        log.info(
            "Synthesized \(foldersByPath.count) folders from \(uniquePaths.count) unique directory paths"
        )
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: vaultFoldersRepairedNotification, object: nil)
        }
    }

    /// Lightweight repair: only runs when no files were inserted/deleted.
    /// Two-phase fix:
    /// 1. Derive missing `subfolder` from `filePath` for pages that have a file but no subfolder.
    /// 2. Wire pages that have `subfolder` but no `folder` relationship to existing SDFolders.
    /// If no orphans exist, this is a no-op.
    private func repairOrphanedFolderRelationships(vaultURL: URL) throws {
        let allPagesDescriptor = FetchDescriptor<SDPage>()
        let allPages = try modelContext.fetch(allPagesDescriptor)

        // Phase 1: Fix pages with filePath inside a subfolder but subfolder field is nil.
        // This can happen if pages were imported by an older version or migrated from v3.
        let vaultPath = vaultURL.path
        var subfolderFixed = 0
        for page in allPages where page.subfolder == nil && page.folder == nil {
            guard let fp = page.filePath, fp.hasPrefix(vaultPath) else { continue }
            let relativePath = URL(fileURLWithPath: fp).deletingLastPathComponent().path
                .replacingOccurrences(of: vaultPath, with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !relativePath.isEmpty {
                page.subfolder = relativePath
                subfolderFixed += 1
            }
        }

        // Phase 2: Wire pages that have subfolder but no folder relationship.
        let orphans = allPages.filter { $0.subfolder != nil && $0.folder == nil }
        guard !orphans.isEmpty else {
            if subfolderFixed > 0 {
                try saveContext("repair orphaned folder subfolder updates")
                log.info("Repair: set subfolder on \(subfolderFixed) pages (no folder wiring needed)")
            }
            return
        }

        // Check if folders exist. If not, do full synthesis.
        let folderDescriptor = FetchDescriptor<SDFolder>()
        let existingFolders = try modelContext.fetch(folderDescriptor)

        if existingFolders.isEmpty {
            log.info("Repair: no folders exist, running full synthesis for \(orphans.count) orphaned pages")
            try synthesizeFoldersFromSubfolders()
            return
        }

        // Build folder lookup by relativePath
        var foldersByPath: [String: SDFolder] = [:]
        for folder in existingFolders {
            let path = folder.relativePath
            if !path.isEmpty {
                foldersByPath[path] = folder
            }
        }

        // Wire orphans to matching folders
        var repaired = 0
        for page in orphans {
            if let sub = page.subfolder, let folder = foldersByPath[sub] {
                page.folder = folder
                repaired += 1
            }
        }

        if repaired > 0 || subfolderFixed > 0 {
            try saveContext("repair orphaned folder relationships")
            log.info("Repair: fixed \(subfolderFixed) missing subfolders, wired \(repaired) orphaned pages to folders")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: vaultFoldersRepairedNotification, object: nil)
            }
        }
    }

    // MARK: - Single File Re-index

    /// Re-index a single file that changed externally.
    @discardableResult
    func reindexFile(at url: URL, vaultURL: URL) async throws -> Bool {
        let result = try await upsertPage(from: url, vaultURL: vaultURL)
        let changed: Bool
        switch result {
        case .unchanged:
            changed = false
        case .updated, .inserted(_):
            changed = true
        }
        if changed {
            try saveContext("single file reindex")
            log.debug("Re-indexed: \(url.lastPathComponent, privacy: .public)")
        }
        return changed
    }

    // MARK: - Export to Disk

    /// Write a page's body back to its .md file (Source of Truth write-back).
    func exportPage(pageId: String, to vaultURL: URL) async throws -> (path: String, bodyHash: String)? {
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate { $0.id == pageId }
        )
        guard let page = try modelContext.fetch(descriptor).first else {
            log.warning("Export failed: page \(pageId, privacy: .public) not found")
            return nil
        }

        let fileURL: URL
        if let existingPath = page.filePath {
            fileURL = URL(filePath: existingPath)
        } else {
            // New page — create file in vault root (or subfolder if set)
            let baseName = sanitizeFileName(page.title)
            let parentURL: URL
            if let subfolder = page.subfolder {
                parentURL = vaultURL.appendingPathComponent(subfolder, isDirectory: true)
                try FileManager.default.createDirectory(
                    at: parentURL, withIntermediateDirectories: true)
            } else {
                parentURL = vaultURL
            }
            // Dedup: append -1, -2, etc. if filename already taken.
            // Falls back to UUID suffix after 100 attempts to guarantee uniqueness.
            var candidate = parentURL.appendingPathComponent("\(baseName).md")
            var suffix = 1
            while FileManager.default.fileExists(atPath: candidate.path) {
                if suffix > 100 {
                    let uuid8 = UUID().uuidString.prefix(8)
                    candidate = parentURL.appendingPathComponent("\(baseName)-\(uuid8).md")
                    break
                }
                candidate = parentURL.appendingPathComponent("\(baseName)-\(suffix).md")
                suffix += 1
            }
            fileURL = candidate
            page.filePath = fileURL.path
        }

        // Build content — markdown front-matter only for markdown note files.
        // Tracked source files (.swift, .rs, .py, etc.) must round-trip as raw text.
        //
        // Phase R.3: body read routed through the Sendable-primitive
        // helper so managed sidecars stay authoritative. Parity
        // preserved via `PhaseR3BodyReadParityTests`.
        let body = await SDPage.loadBodyAsyncFromPrimitives(
            pageId: page.id,
            filePath: page.filePath,
            inlineBody: page.body,
            mapped: true
        )
        let bodyHash = SDPage.bodyHash(body)
        let output = Self.shouldWriteMarkdownFrontMatter(to: fileURL)
            ? buildMarkdown(for: page, body: body)
            : body
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: Data())
        }
        try coordinatedWrite(output, to: fileURL)

        // Persist filePath back to the store so subsequent exports use the same path.
        // Without this save, the filePath only exists in the background actor's memory
        // and the mainContext never sees it — causing duplicate file creation.
        try saveContext("exported page file path")
        upsertSearchIndex(page: page, body: body)

        log.debug("Exported: \(fileURL.lastPathComponent, privacy: .public)")
        return (fileURL.path, bodyHash)
    }

    // MARK: - Rename Page File

    /// Rename a page's vault .md file to match a new title.
    /// Moves the file on disk and updates page.filePath.
    func renamePageFile(pageId: String, newTitle: String, vaultURL: URL) throws {
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate { $0.id == pageId }
        )
        guard let page = try modelContext.fetch(descriptor).first else { return }
        guard let oldPath = page.filePath else { return }

        let oldURL = URL(filePath: oldPath)
        let parentURL = oldURL.deletingLastPathComponent()
        let newBaseName = sanitizeFileName(newTitle)
        var newURL = parentURL.appendingPathComponent("\(newBaseName).md")

        // Skip if the filename is already correct
        guard newURL.path != oldURL.path else { return }

        // Dedup if target already exists (and isn't the same file)
        var suffix = 1
        while FileManager.default.fileExists(atPath: newURL.path) {
            if suffix > 100 {
                let uuid8 = UUID().uuidString.prefix(8)
                newURL = parentURL.appendingPathComponent("\(newBaseName)-\(uuid8).md")
                break
            }
            newURL = parentURL.appendingPathComponent("\(newBaseName)-\(suffix).md")
            suffix += 1
        }

        // Move the file
        guard FileManager.default.fileExists(atPath: oldURL.path) else { return }
        try FileManager.default.moveItem(at: oldURL, to: newURL)
        page.filePath = newURL.path
        try saveContext("renamed page file")
        log.info("Renamed page file: \(oldURL.lastPathComponent, privacy: .public) → \(newURL.lastPathComponent, privacy: .public)")
    }

    // MARK: - Handle Deletion

    /// Remove a page from SwiftData when its .md file is deleted externally.
    func handleFileDeletion(at url: URL) throws {
        let filePath = url.path
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate { $0.filePath == filePath }
        )
        let existing = try modelContext.fetch(descriptor)
        for page in existing {
            do {
                try searchService?.delete(pageId: page.id)
            } catch {
                log.error("FTS5 delete failed for page \(page.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
            // Clean up orphaned SDNoteInsight
            let pageId = page.id
            SpotlightIndexer.deindex(pageId)
            Task { @MainActor in
                AppBootstrap.shared?.instantRecallService.removeNote(noteId: pageId)
            }
            let insightDesc = FetchDescriptor<SDNoteInsight>(predicate: #Predicate { $0.pageId == pageId })
            if let insight = fetchFirst(insightDesc, label: "note insight for deleted file \(pageId)") {
                modelContext.delete(insight)
            }
            modelContext.delete(page)
        }
        try saveContext("deleted file removal")
        log.debug("Removed deleted file from index: \(url.lastPathComponent, privacy: .public)")
    }

    // MARK: - Private Helpers

    /// Upsert a page from a .md file URL. Updates if exists (by filePath), creates if new.
    private func upsertPage(from fileURL: URL, vaultURL: URL) async throws -> PageUpsertResult {
        // Pre-flight check: verify the file is actually readable before attempting I/O.
        // Security-scoped access is process-wide (granted by VaultSyncService), but individual
        // files may be locked, in Trash, symlinked, or otherwise inaccessible.
        let fm = FileManager.default
        guard fm.isReadableFile(atPath: fileURL.path) else {
            log.warning(
                "Skipping unreadable file: \(fileURL.lastPathComponent, privacy: .public)"
            )
            return .unchanged  // Caller should increment unreadableCount
        }

        let filePath = fileURL.path

        let content: String
        do {
            guard let data = Self.mappedFileData(
                at: fileURL,
                label: "vault note file"
            ) else {
                return .unchanged
            }
            if let decoded = FoundationSafety.decodedText(from: data) {
                content = decoded
            } else if let latin1 = String(data: data, encoding: .isoLatin1) {
                log.info(
                    "Read \(fileURL.lastPathComponent, privacy: .public) with Latin-1 fallback (Unicode decode failed)"
                )
                content = latin1
            } else {
                throw CocoaError(.fileReadInapplicableStringEncoding)
            }
        } catch {
            log.error(
                "Failed to read \(fileURL.lastPathComponent, privacy: .public): \(error, privacy: .public)"
            )
            return .unchanged  // Skip this file instead of crashing the entire import
        }

        let (frontMatter, body) = Self.shouldWriteMarkdownFrontMatter(to: fileURL)
            ? Self.parseFrontMatter(content)
            : ([:], content)

        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate { $0.filePath == filePath }
        )
        let existing = try modelContext.fetch(descriptor)

        let parsedTitle = frontMatter["title"] ?? fileURL.deletingPathExtension().lastPathComponent
        let parsedTags =
            frontMatter["tags"]?.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
            } ?? []
        let parsedEmoji = frontMatter["icon"] ?? ""
        let parsedWordCount = countWords(body)

        if let page = existing.first {
            let missingManagedBodyNeedsRestore =
                !NoteFileStorage.bodyExists(pageId: page.id)
                && NoteFileStorage.readBody(
                    pageId: page.id,
                    mapped: false,
                    fast: true
                ).isEmpty
            // Guard: if the note-body file on disk is newer than the vault .md file,
            // the user edited in-app after the last auto-save export. Preserve their
            // edits by skipping the body overwrite — only update metadata from vault.
            let noteBodyURL = NoteFileStorage.storageDirectory().appendingPathComponent("\(page.id).md")
            let noteBodyModDate = Self.contentModificationDate(
                for: noteBodyURL,
                label: "managed note body",
                logWhenMissing: false
            )
            let vaultModDate = Self.contentModificationDate(
                for: fileURL,
                label: "vault note file"
            )
            let noteBodyIsNewer = Self.isModificationDate(noteBodyModDate, newerThan: vaultModDate)

            // Only preserve in-app body if it's non-empty. A zero-byte note-body
            // (from historical DB reset or write failure) should never win over vault content.
            // Import rollback needs the managed note snapshot, not the
            // incoming vault file from `filePath`.
            let currentBody = page.loadBody(mapped: true)
            let preserveBody = noteBodyIsNewer && !currentBody.isEmpty

            // Skip no-op writes (common for self-originated saves) to avoid UI churn.
            if missingManagedBodyNeedsRestore
                || currentBody != body
                || page.title != parsedTitle
                || page.tags != parsedTags
                || page.emoji != parsedEmoji
                || page.frontMatter != frontMatter
                || page.wordCount != parsedWordCount
            {
                let snapshot = UpdatedPageSnapshot(
                    pageId: page.id,
                    body: currentBody,
                    filePath: page.filePath,
                    wordCount: page.wordCount,
                    emoji: page.emoji,
                    lastSyncedBodyHash: page.lastSyncedBodyHash,
                    lastSyncedAt: page.lastSyncedAt,
                    needsVaultSync: page.needsVaultSync,
                    updatedAt: page.updatedAt,
                    title: page.title,
                    tags: page.tags,
                    frontMatter: page.frontMatter,
                    parentPageId: page.parentPageId,
                    templateId: page.templateId,
                    subfolder: page.subfolder,
                    isJournal: page.isJournal,
                    journalDate: page.journalDate
                )
                if preserveBody {
                    log.info("Preserving in-app edits for '\(parsedTitle, privacy: .public)' — note-body newer than vault .md")
                    page.needsVaultSync = true
                } else {
                    page.saveBody(body)
                    BlockMirror.sync(pageId: page.id, body: body, modelContext: modelContext)
                    page.lastSyncedBodyHash = SDPage.bodyHash(body)
                    page.lastSyncedAt = .now
                    page.needsVaultSync = false
                    // Notify editor to reload — vault replaced the body externally.
                    let changedId = page.id
                    Task { @MainActor in
                        NoteFileStorage.notifyBodyChanged(pageId: changedId)
                    }
                }
                page.updatedAt = .now
                if !preserveBody {
                    page.wordCount = parsedWordCount
                }
                page.title = Self.sanitizeTitle(parsedTitle)
                page.tags = parsedTags
                page.emoji = parsedEmoji
                page.frontMatter = frontMatter

                // Keep parentPageId from front-matter for backward compat
                let newParentId = frontMatter["parent"]
                if page.parentPageId != newParentId {
                    page.parentPageId = newParentId
                }
                page.templateId = frontMatter["template"]

                // Update subfolder if file moved to a different directory
                let relativePath = fileURL.deletingLastPathComponent().path
                    .replacingOccurrences(of: vaultURL.path, with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                let newSubfolder = relativePath.isEmpty ? nil : relativePath
                if page.subfolder != newSubfolder {
                    page.subfolder = newSubfolder
                    // folder relationship will be re-wired by synthesis/repair
                }

                let indexBody = preserveBody ? currentBody : body
                upsertSearchIndex(page: page, body: indexBody)
                return .updated(snapshot)
            }
            return .unchanged
        } else {
            // Create new page
            let page = SDPage(title: parsedTitle)

            // Restore persisted ID so parent-child references survive reimport.
            // Without this, every reimport generates new UUIDs and breaks `parent: <id>` links.
            // Guard: if another SDPage already owns this ID (at a different filePath),
            // this is a Finder-duplicated file — keep the fresh UUID to avoid collisions.
            if let savedId = frontMatter["id"], !savedId.isEmpty {
                let idDescriptor = FetchDescriptor<SDPage>(
                    predicate: #Predicate { $0.id == savedId }
                )
                if let existingWithId = fetchAll(
                    idDescriptor,
                    label: "existing page by restored ID \(savedId)"
                ) {
                    let isOwnedByAnotherFile = existingWithId.contains { $0.filePath != filePath }
                    if isOwnedByAnotherFile {
                        log.info("Duplicate file detected for page \(savedId, privacy: .public) — assigning new ID")
                    } else {
                        page.id = savedId
                    }
                } else {
                    log.warning(
                        "Restored ID collision check failed for \(savedId, privacy: .public); keeping generated page ID for \(fileURL.lastPathComponent, privacy: .public)"
                    )
                }
            }

            page.saveBody(body)
            BlockMirror.sync(pageId: page.id, body: body, modelContext: modelContext)
            page.filePath = filePath
            page.wordCount = parsedWordCount
            page.emoji = parsedEmoji
            page.lastSyncedBodyHash = SDPage.bodyHash(body)
            page.lastSyncedAt = .now
            page.needsVaultSync = false

            // Compute subfolder relative to vault root
            let relativePath = fileURL.deletingLastPathComponent().path
                .replacingOccurrences(of: vaultURL.path, with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !relativePath.isEmpty {
                page.subfolder = relativePath
            }

            page.tags = parsedTags
            page.frontMatter = frontMatter
            page.isJournal = frontMatter["journal"] == "true"
            page.journalDate = frontMatter["date"]

            // Keep parentPageId from front-matter for backward compat
            if let parentId = frontMatter["parent"] {
                page.parentPageId = parentId
            }
            page.templateId = frontMatter["template"]

            modelContext.insert(page)
            upsertSearchIndex(page: page, body: body)
            return .inserted(page)
        }
    }

    nonisolated static func decodedBodyFromReadableVaultFile(at fileURL: URL) -> String? {
        guard FileManager.default.isReadableFile(atPath: fileURL.path),
              let data = Self.mappedFileData(at: fileURL, label: "readable vault body preview") else {
            return nil
        }

        let decode: (String) -> String = { decoded in
            Self.shouldWriteMarkdownFrontMatter(to: fileURL)
                ? Self.parseFrontMatter(decoded).1
                : decoded
        }

        if let decoded = FoundationSafety.decodedText(from: data) {
            return decode(decoded)
        }
        if let latin1 = String(data: data, encoding: .isoLatin1) {
            return decode(latin1)
        }
        return nil
    }

    /// Parse YAML front-matter from markdown content.
    /// Returns (frontMatter dict, body without front-matter).
    nonisolated static func parseFrontMatter(_ content: String) -> ([String: String], String) {
        // Strip Unicode BOM (U+FEFF) that Windows editors may prepend
        let cleaned = content.hasPrefix("\u{FEFF}") ? String(content.dropFirst()) : content
        guard cleaned.hasPrefix("---") else { return ([:], cleaned) }

        let lines = cleaned.components(separatedBy: "\n")
        guard lines.count > 1 else { return ([:], cleaned) }

        var frontMatter: [String: String] = [:]
        var endIndex = -1

        for i in 1..<lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed == "---" {
                endIndex = i
                break
            }
            // Skip YAML comment lines
            if trimmed.hasPrefix("#") { continue }
            let parts = lines[i].split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                var value = parts[1].trimmingCharacters(in: .whitespaces)
                // Strip YAML double-quote wrapping (written by yamlEscapeTitle)
                if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
                    value = String(value.dropFirst().dropLast())
                    value = value.replacingOccurrences(of: "\\\"", with: "\"")
                }
                // Strip surrounding brackets for array values like [swift, ios]
                if value.hasPrefix("[") && value.hasSuffix("]") {
                    value = String(value.dropFirst().dropLast())
                }
                frontMatter[key] = value
            }
        }

        if endIndex > 0 {
            let bodyLines = Array(lines[(endIndex + 1)...])
            let body = bodyLines.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (frontMatter, body)
        }

        return ([:], cleaned)
    }

    /// Build markdown with front-matter from an SDPage.
    private func buildMarkdown(for page: SDPage, body: String) -> String {
        var lines: [String] = ["---"]
        lines.append("id: \(page.id)")
        lines.append("title: \(yamlEscapeTitle(page.title))")
        if !page.tags.isEmpty {
            lines.append("tags: [\(page.tags.joined(separator: ", "))]")
        }
        if !page.emoji.isEmpty {
            lines.append("icon: \(page.emoji)")
        }
        if page.isJournal {
            lines.append("journal: true")
        }
        if let date = page.journalDate {
            lines.append("date: \(date)")
        }
        if let parentId = page.parentPageId {
            lines.append("parent: \(parentId)")
        }
        if let templateId = page.templateId {
            lines.append("template: \(templateId)")
        }
        // Include any extra front-matter keys
        let knownKeys: Set<String> = [
            "id", "title", "tags", "icon", "journal", "date", "parent", "template",
        ]
        for (key, value) in page.frontMatter where !knownKeys.contains(key) {
            lines.append("\(key): \(value)")
        }
        lines.append("---")
        lines.append("")
        lines.append(body)
        return lines.joined(separator: "\n")
    }

    private nonisolated static func shouldWriteMarkdownFrontMatter(to fileURL: URL) -> Bool {
        switch fileURL.pathExtension.lowercased() {
        case "", "md", "markdown":
            return true
        default:
            return false
        }
    }

    /// YAML-escape a title for front-matter: wrap in double quotes if it contains special chars.
    private func yamlEscapeTitle(_ title: String) -> String {
        let needsQuoting = title.contains(":") || title.contains("\"") ||
                            title.contains("#") || title.hasPrefix(" ") ||
                            title.hasSuffix(" ") || title.contains("'") ||
                            title.contains("[") || title.contains("]")
        if needsQuoting {
            let escaped = title.replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\""
        }
        return title
    }

    /// Count words in text content (NL tokenizer — accurate for non-English).
    private func countWords(_ text: String) -> Int {
        NLAnalysisService.wordCount(text)
    }

    /// Sanitize a title for use as a filename (Obsidian-compatible superset).
    private func sanitizeFileName(_ title: String) -> String {
        var s = title
        // Normalize smart quotes
        s = s.replacingOccurrences(of: "\u{2018}", with: "'")
        s = s.replacingOccurrences(of: "\u{2019}", with: "'")
        s = s.replacingOccurrences(of: "\u{201C}", with: "\"")
        s = s.replacingOccurrences(of: "\u{201D}", with: "\"")
        // Strip forbidden characters: :/\?*"<>|#^[]{}
        let forbidden = CharacterSet(charactersIn: ":/\\?*\"<>|#^[]{}")
            .union(.controlCharacters)
        s = String(s.unicodeScalars.filter { !forbidden.contains($0) })
        // Collapse multiple spaces/dashes
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        while s.contains("--") { s = s.replacingOccurrences(of: "--", with: "-") }
        // Strip leading/trailing whitespace and periods
        s = s.trimmingCharacters(in: .whitespaces)
        while s.hasPrefix(".") { s = String(s.dropFirst()) }
        while s.hasSuffix(".") { s = String(s.dropLast()) }
        s = s.trimmingCharacters(in: .whitespaces)
        // Truncate to 200 characters
        if s.count > 200 { s = String(s.prefix(200)) }
        return s.isEmpty ? "Untitled" : s
    }

    // MARK: - Title Sanitization

    /// Strip control characters from a title. Safe to call from any isolation context.
    nonisolated static func sanitizeTitle(_ raw: String) -> String {
        let cleaned = raw.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
        let result = String(String.UnicodeScalarView(cleaned))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? "Untitled" : result
    }

    // MARK: - Search Index Helpers

    private func upsertSearchIndex(page: SDPage, body: String) {
        upsertSearchIndex(
            pageId: page.id,
            title: page.title,
            body: body,
            tags: page.tags,
            updatedAt: page.updatedAt
        )
    }

    private func upsertSearchIndex(
        pageId: String,
        title: String,
        body: String,
        tags: [String],
        updatedAt: Date
    ) {
        do {
            try searchService?.upsert(
                id: pageId,
                title: title,
                body: body,
                tags: tags.joined(separator: " "),
                updatedAt: updatedAt
            )
        } catch {
            log.error("FTS5 upsert failed for page \(pageId, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// All page (id, updatedAt) pairs for diff sync.
    func allPageTimestamps() -> [(id: String, updatedAt: Date)] {
        let descriptor = FetchDescriptor<SDPage>()
        guard let pages = fetchAll(descriptor, label: "all page timestamps") else { return [] }
        return pages.map { ($0.id, $0.updatedAt) }
    }

    /// Full page data for a single page (used by diff sync provider).
    ///
    /// Phase R.3: body read via the Sendable-primitive helper. The
    /// method is async because the gateway read is async — callers
    /// already `await` on actor hops.
    func fullPageData(for pageId: String) async -> (title: String, body: String, tags: String, updatedAt: Date)? {
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
        guard let page = fetchFirst(descriptor, label: "full page data for \(pageId)") else { return nil }
        let body = await SDPage.loadBodyAsyncFromPrimitives(
            pageId: page.id,
            filePath: page.filePath,
            inlineBody: page.body,
            mapped: true
        )
        return (page.title, body, page.tags.joined(separator: " "), page.updatedAt)
    }

    /// All pages formatted for a full FTS5 rebuild.
    ///
    /// Phase R.3: same managed-sidecar-first body read via the
    /// primitives helper, inside an async for-loop (sync `.map` can't await).
    func allPagesForRebuild() async -> [(id: String, title: String, body: String, tags: String, updatedAt: Date)] {
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { !$0.isArchived && $0.templateId == nil }
        )
        guard let pages = fetchAll(descriptor, label: "pages for search index rebuild") else { return [] }
        var out: [(id: String, title: String, body: String, tags: String, updatedAt: Date)] = []
        out.reserveCapacity(pages.count)
        for page in pages {
            let body = await SDPage.loadBodyAsyncFromPrimitives(
                pageId: page.id,
                filePath: page.filePath,
                inlineBody: page.body,
                mapped: true
            )
            out.append((page.id, page.title, body, page.tags.joined(separator: " "), page.updatedAt))
        }
        return out
    }

    // MARK: - Vault Context for Chat Pipeline

    /// Conversational words that appear frequently in chat but carry no
    /// topic signal. Filtered out before vault search to prevent generic
    /// follow-ups like "go deeper" from matching unrelated notes.
    private static let vaultStopWords: Set<String> = QueryAnalyzer.stopWords.union([
        "deeper", "explain", "elaborate", "expand", "answer", "question",
        "tell", "give", "show", "help", "find", "look", "want", "need",
        "mean", "means", "work", "works", "think", "thought", "point",
        "talk", "discuss", "describe", "detail", "details", "further",
        "better", "good", "great", "okay", "sure", "yeah", "right",
        "well", "maybe", "example", "examples", "info", "information",
        "know", "idea", "ideas", "reason", "reasons", "part", "parts",
        "start", "begin", "first", "next", "last", "different", "specific",
        "something", "anything", "everything", "nothing", "someone",
        "make", "made", "take", "took", "keep", "come", "came", "done",
        "back", "down", "long", "real", "true", "false", "stuff", "kind",
    ])

    /// Search the vault for notes relevant to the query and format as context.
    /// Runs on this background actor so disk-backed note body reads
    /// happen off the main thread instead of inside interactive UI paths.
    ///
    /// Relevance filtering:
    /// 1. Stop words + conversational filler stripped from search terms
    /// 2. Queries with < 2 meaningful terms return nil (catches vague follow-ups)
    /// 3. Notes scored by term-match count × term specificity (length)
    /// 4. Minimum score threshold gates injection — no low-relevance leaks
    func buildVaultContext(for query: String) async -> String? {
        // ── 1. Extract meaningful search terms ──────────────────────────
        let terms = query.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count > 3 && !Self.vaultStopWords.contains($0) }

        // ── 2. Skip vault context for vague/follow-up queries ───────────
        // "go deeper", "tell me more", "explain further" → 0-1 terms after filtering
        guard terms.count >= 2 else { return nil }

        // ── 3. Fetch candidate pages ────────────────────────────────────
        var descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { !$0.isArchived },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 200
        guard let pages = fetchAll(descriptor, label: "vault context pages"), !pages.isEmpty else {
            return nil
        }

        // ── 4. Score each page by relevance ─────────────────────────────
        struct ScoredPage {
            let page: SDPage
            let score: Double
        }

        var scored: [ScoredPage] = []
        let titleScanPages = pages  // all pages get title scanned (cheap)
        let bodyScanPages = pages.prefix(30)  // only recent pages get body scanned (disk I/O)
        let bodyScanIds = Set(bodyScanPages.map(\.id))
        var cachedBodies: [String: String] = [:]
        cachedBodies.reserveCapacity(bodyScanIds.count)

        for page in titleScanPages {
            var score: Double = 0
            let titleLower = page.title.lowercased()
            var matchedTerms = 0

            // Title matches: +3 base + length bonus (longer terms are more specific)
            for term in terms where titleLower.contains(term) {
                matchedTerms += 1
                score += 3.0 + Double(term.count - 4) * 0.5
            }

            // Body matches: only for recent pages, and only if title gave partial signal
            // or this is in the body-scan window. Each body match: +1 base + length bonus.
            // Phase R.3: managed-sidecar-first read via the primitives helper.
            if bodyScanIds.contains(page.id), score < 8 {
                let body: String
                if let cached = cachedBodies[page.id] {
                    body = cached
                } else {
                    body = await SDPage.loadBodyAsyncFromPrimitives(
                        pageId: page.id,
                        filePath: page.filePath,
                        inlineBody: page.body,
                        mapped: true
                    )
                    cachedBodies[page.id] = body
                }
                let bodyLower = String(body.prefix(1500)).lowercased()
                for term in terms where bodyLower.contains(term) {
                    if !titleLower.contains(term) { matchedTerms += 1 }
                    score += 1.0 + Double(term.count - 4) * 0.3
                }
            }

            // Require at least 2 distinct term matches to count as relevant
            if matchedTerms >= 2 && score > 0 {
                scored.append(ScoredPage(page: page, score: score))
            }
        }

        // ── 5. Apply minimum relevance threshold ────────────────────────
        // Score of 4.0 ≈ two 5-letter terms matching in title, or one title + two body
        let threshold: Double = 4.0
        let relevant =
            scored
            .filter { $0.score >= threshold }
            .sorted { $0.score > $1.score }
            .prefix(5)

        guard !relevant.isEmpty else { return nil }

        // ── 6. Format matched notes as context ──────────────────────────
        // Phase R.3: sequential for loop to accommodate the async
        // body read. Prior body reads may already be in `cachedBodies`
        // from the score loop; only uncached pages incur a fresh read.
        var notesParts: [String] = []
        notesParts.reserveCapacity(relevant.count)
        for entry in relevant {
            let body: String
            if let cached = cachedBodies[entry.page.id] {
                body = cached
            } else {
                body = await SDPage.loadBodyAsyncFromPrimitives(
                    pageId: entry.page.id,
                    filePath: entry.page.filePath,
                    inlineBody: entry.page.body,
                    mapped: true
                )
            }
            notesParts.append(
                "### \(entry.page.title)\nTags: [\(entry.page.tags.joined(separator: ", "))]\n\(String(body.prefix(500)))"
            )
        }
        let notesSection = notesParts.joined(separator: "\n\n")

        // Build folder list for action instructions
        let folderDescriptor = FetchDescriptor<SDFolder>(sortBy: [SortDescriptor(\.sortOrder)])
        let folderNames = fetchAll(folderDescriptor, label: "folder names for vault context")?.map(\.name) ?? []

        let actionInstructions = """

            ## Vault Actions
            When the user asks to modify notes (tag, move, organize, etc.), include action markers at the END:
            - Add tags: `[ACTION:TAG tag1, tag2, tag3]`
            - Move to folder: `[ACTION:MOVE FolderName]`
            - Create note: `[ACTION:CREATE Title of New Note]`
            Available folders: [\(folderNames.joined(separator: ", "))]
            Only use markers when the user explicitly asks to modify something.
            """

        return notesSection + actionInstructions
    }

    // MARK: - Vault Manifest for Notes Mode

    /// Build a lightweight manifest for ambient vault awareness.
    /// Entries only — no recent bodies (those are loaded on-demand via @-mentions).
    func buildAmbientManifest(vaultTitle: String) -> VaultManifest? {
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { !$0.isArchived },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        guard let pages = fetchAll(descriptor, label: "ambient manifest pages"), !pages.isEmpty else {
            return nil
        }

        let entries: [VaultManifest.ManifestEntry] = pages.map { page in
            VaultManifest.ManifestEntry(
                pageId: page.id,
                title: page.title,
                relativePath: page.vaultRelativeNotePath,
                tags: page.tags,
                folderName: page.folder?.name,
                wordCount: page.wordCount,
                snippet: page.summary.isEmpty ? page.title : page.summary,
                updatedAt: page.updatedAt,
                createdAt: page.createdAt
            )
        }

        return VaultManifest(
            vaultTitle: vaultTitle,
            totalNoteCount: pages.count,
            isInventoryComplete: true,
            entries: entries,
            recentBodies: [],
            generatedAt: .now
        )
    }

    /// Build a complete vault manifest for vault briefing.
    /// Includes metadata for ALL non-archived notes + full bodies of the 20 most recent.
    ///
    /// Phase R.3: deep-read body pass uses the Sendable-primitive
    /// helper so managed sidecars stay authoritative. The metadata
    /// `entries` map stays synchronous — no body reads there.
    func buildVaultManifest(vaultTitle: String) async -> VaultManifest? {
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { !$0.isArchived },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        guard let pages = fetchAll(descriptor, label: "vault manifest pages"), !pages.isEmpty else {
            return nil
        }

        let entries: [VaultManifest.ManifestEntry] = pages.map { page in
            VaultManifest.ManifestEntry(
                pageId: page.id,
                title: page.title,
                relativePath: page.vaultRelativeNotePath,
                tags: page.tags,
                folderName: page.folder?.name,
                wordCount: page.wordCount,  // Use cached field — no body read
                snippet: page.summary.isEmpty
                    ? page.title  // Fallback to title instead of reading body
                    : page.summary,
                updatedAt: page.updatedAt,
                createdAt: page.createdAt
            )
        }

        // Deep-read: full bodies of the 20 most recently edited.
        var recentBodies: [VaultManifest.NoteBody] = []
        recentBodies.reserveCapacity(20)
        for page in pages.prefix(20) {
            let body = await SDPage.loadBodyAsyncFromPrimitives(
                pageId: page.id,
                filePath: page.filePath,
                inlineBody: page.body,
                mapped: true
            )
            recentBodies.append(VaultManifest.NoteBody(
                pageId: page.id,
                title: page.title,
                relativePath: page.vaultRelativeNotePath,
                body: String(body.prefix(2000))
            ))
        }

        return VaultManifest(
            vaultTitle: vaultTitle,
            totalNoteCount: pages.count,
            isInventoryComplete: true,
            entries: entries,
            recentBodies: recentBodies,
            generatedAt: .now
        )
    }

    /// Fetch full bodies for specific notes by page ID (for @-mention resolution & preWarm).
    ///
    /// Phase R.3: each body read goes through the Sendable-primitive
    /// helper so managed sidecars stay authoritative before gateway
    /// fallback.
    func fetchNoteBodies(ids: [String]) async -> [VaultManifest.NoteBody] {
        guard !ids.isEmpty else { return [] }
        // Individual fetches — SwiftData #Predicate can't reliably translate
        // local array .contains() to SQL, causing runtime crashes.
        // Batch sizes are small (3-6 IDs) so N fetches are fine.
        var results: [VaultManifest.NoteBody] = []
        for id in ids {
            let descriptor = FetchDescriptor<SDPage>(
                predicate: #Predicate<SDPage> { $0.id == id }
            )
            if let page = fetchFirst(descriptor, label: "note body for \(id)") {
                let body = await SDPage.loadBodyAsyncFromPrimitives(
                    pageId: page.id,
                    filePath: page.filePath,
                    inlineBody: page.body,
                    mapped: true
                )
                results.append(VaultManifest.NoteBody(
                    pageId: page.id,
                    title: page.title,
                    relativePath: page.vaultRelativeNotePath,
                    body: body
                ))
            }
        }
        return results
    }

    /// Find notes matching a title query (for @-mention resolution by title).
    func findNotesByTitle(_ query: String) -> [VaultManifest.ManifestEntry] {
        let q = query.lowercased()
        var descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { !$0.isArchived },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 200
        guard let pages = fetchAll(descriptor, label: "notes by title query") else { return [] }
        return pages.filter { $0.title.lowercased().contains(q) }.prefix(8).map { page in
            VaultManifest.ManifestEntry(
                pageId: page.id,
                title: page.title,
                relativePath: page.vaultRelativeNotePath,
                tags: page.tags,
                folderName: page.folder?.name,
                wordCount: page.wordCount,  // Use cached field — no body read
                snippet: page.summary.isEmpty ? page.title : page.summary,
                updatedAt: page.updatedAt,
                createdAt: page.createdAt
            )
        }
    }

    // MARK: - Spotlight Indexing (Background)

    private func spotlightReindexSnapshot() -> SpotlightReindexSnapshot {
        let lastIndexDate =
            UserDefaults.standard.object(forKey: Self.spotlightIndexDateKey) as? Date
            ?? .distantPast

        var descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.updatedAt > lastIndexDate },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1000

        let changedPageCount = fetchCount(
            descriptor,
            label: "spotlight changed page count"
        ) ?? 0
        return SpotlightReindexSnapshot(
            lastIndexDate: lastIndexDate,
            changedPageCount: changedPageCount,
            willIndex: changedPageCount > 0
        )
    }

    func spotlightReindexSnapshotForTesting() -> SpotlightReindexSnapshot {
        spotlightReindexSnapshot()
    }

    /// Re-index pages into Core Spotlight, skipping pages unchanged since last index.
    /// Only reads .body for pages that actually need reindexing.
    ///
    /// Phase R.3: body reads go through the Sendable-primitive
    /// helper. Sync `.map` replaced by a sequential async for-loop.
    func spotlightReindexAll() async {
        let snapshot = spotlightReindexSnapshot()
        let lastIndexDate = snapshot.lastIndexDate

        var descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.updatedAt > lastIndexDate },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        // Safety cap: don't try to index more than 1000 at once
        descriptor.fetchLimit = 1000

        guard let pages = fetchAll(descriptor, label: "spotlight reindex pages") else {
            return
        }
        guard !pages.isEmpty else {
            log.info("Spotlight: no pages changed since last index")
            return
        }

        let batchSize = 50
        let total = pages.count

        for batchStart in stride(from: 0, to: total, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, total)
            let batch = Array(pages[batchStart..<batchEnd])

            var items: [CSSearchableItem] = []
            items.reserveCapacity(batch.count)
            for page in batch {
                let pageBody = await SDPage.loadBodyAsyncFromPrimitives(
                    pageId: page.id,
                    filePath: page.filePath,
                    inlineBody: page.body,
                    mapped: true
                )
                items.append(SpotlightIndexer.makeItem(for: page, body: pageBody))
            }

            CSSearchableIndex.default().indexSearchableItems(items) { error in
                if let error {
                    self.log.error(
                        "Spotlight batch reindex failed: \(error.localizedDescription, privacy: .private)"
                    )
                }
            }
        }

        // Update last index timestamp
        UserDefaults.standard.set(Date.now, forKey: Self.spotlightIndexDateKey)
        log.info("Spotlight indexed \(total) changed notes (skipped unchanged)")
    }

    // MARK: - Coordinated File Access

    /// Write a file using NSFileCoordinator. Ensures the write is coordinated
    /// with the active NSFilePresenter so it doesn't trigger a spurious re-index.
    private func coordinatedWrite(_ content: String, to url: URL) throws {
        var coordinatorError: NSError?
        var writeError: Error?

        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError)
        { newURL in
            if !NoteFileStorage.writeTextAtomically(content, to: newURL, itemLabel: newURL.lastPathComponent) {
                writeError = NSError(domain: "Epistemos", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Atomic write failed for \(newURL.lastPathComponent)"
                ])
            }
        }

        if let coordinatorError {
            throw coordinatorError
        }
        if let writeError {
            throw writeError
        }
    }

    // MARK: - One-Time Migrations

    /// Compute body hashes for existing pages so they start "clean."
    /// One-time migration on first launch after hybrid sync update.
    func migrateToHybridSync() {
        let migrationKey = "epistemos.hybridSyncMigrated"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let descriptor = FetchDescriptor<SDPage>()
        guard let pages = fetchAll(descriptor, label: "hybrid sync migration pages") else { return }

        var migrated = 0
        for page in pages where page.lastSyncedBodyHash == nil {
            page.lastSyncedBodyHash = SDPage.bodyHash(NoteFileStorage.readBody(pageId: page.id, mapped: true, fast: false))
            page.lastSyncedAt = .now
            page.needsVaultSync = false
            migrated += 1
        }

        if migrated > 0 {
            do {
                try saveContext("hybrid sync migration")
            } catch {
                return
            }
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
        log.info("Hybrid sync migration: set hashes for \(migrated) existing pages")
    }

    /// Reset all page timestamps so importVault re-reads every .md file.
    /// One-time migration after body moved from external storage to inline SQLite.
    func migrateFromExternalStorage() {
        let migrationKey = "epistemos.inlineBodyMigrated"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let descriptor = FetchDescriptor<SDPage>()
        guard let pages = fetchAll(descriptor, label: "inline body migration pages") else { return }

        for page in pages {
            page.updatedAt = .distantPast
        }
        do {
            try saveContext("inline body migration")
        } catch {
            return
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
        log.info("Inline body migration: reset \(pages.count) page timestamps for re-import")
    }
}
