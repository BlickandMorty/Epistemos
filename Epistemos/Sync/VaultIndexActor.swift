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
    private let log = Logger(subsystem: "com.epistemos", category: "VaultIndex")

    // MARK: - FTS5 Search Index (GRDB)
    private var searchService: SearchIndexService?

    func setSearchService(_ service: SearchIndexService) {
        self.searchService = service
    }

    // MARK: - Full Vault Import

    /// Import vault incrementally: only process new, modified, or deleted files.
    /// Compares file modification dates against stored SDPage.updatedAt to skip unchanged files.
    func importVault(from url: URL) throws {
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
        for page in existingPages {
            if let fp = page.filePath {
                existingByPath[fp] = page
            }
        }
        let allExistingPaths = Set(existingByPath.keys)

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

        // Directories that should never be indexed (developer artifacts, system data, not user notes)
        let excludedDirs: Set<String> = [
            "node_modules", ".git", ".build", "Pods", "DerivedData", ".svn", ".venv", "venv",
            "__pycache__", ".pytest_cache", ".mypy_cache",
        ]
        // Package/system directories that contain thousands of non-note files
        let excludedSuffixes: Set<String> = [".photoslibrary", ".app", ".framework", ".xcodeproj", ".xcworkspace"]

        var diskPaths = Set<String>()
        var insertCount = 0
        var updateCount = 0
        var skipCount = 0
        var changeCount = 0
        let batchSize = 200

        for case let fileURL as URL in enumerator {
            // Allow cooperative cancellation during large vault imports
            guard !Task.isCancelled else {
                log.info("Vault import cancelled — indexed \(insertCount + updateCount) files before cancellation")
                break
            }
            // Skip developer artifact and system directory subtrees entirely
            let name = fileURL.lastPathComponent
            if excludedDirs.contains(name)
                || excludedSuffixes.contains(where: { name.hasSuffix($0) }) {
                enumerator.skipDescendants()
                continue
            }

            let ext = fileURL.pathExtension.lowercased()
            guard ext == "md" || ext == "markdown" || ext == "txt" else { continue }

            let filePath = fileURL.path
            diskPaths.insert(filePath)

            // Get file modification date
            let fileModDate: Date
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
               let modDate = resourceValues.contentModificationDate {
                fileModDate = modDate
            } else {
                // Can't read mod date — treat as changed to be safe
                fileModDate = .distantFuture
            }

            if let existingPage = existingByPath[filePath] {
                // File exists in DB — check if it changed
                if fileModDate > existingPage.updatedAt {
                    // File was modified externally — re-read and update
                    autoreleasepool {
                        do {
                            let changed = try upsertPage(from: fileURL, vaultURL: url)
                            if changed {
                                updateCount += 1
                                changeCount += 1
                            } else {
                                skipCount += 1
                            }
                        } catch {
                            log.error(
                                "Failed to update \(fileURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
                            )
                        }
                    }
                } else {
                    // Unchanged — skip entirely (no disk read, no body load)
                    skipCount += 1
                }
            } else {
                // New file — insert
                autoreleasepool {
                    do {
                        _ = try upsertPage(from: fileURL, vaultURL: url)
                        insertCount += 1
                        changeCount += 1
                    } catch {
                        log.error(
                            "Failed to index \(fileURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
                        )
                    }
                }
            }

            if changeCount > 0 && changeCount.isMultiple(of: batchSize) {
                try modelContext.save()
                log.info("Vault import progress: \(changeCount, privacy: .public) changes")
            }
        }

        // ── 3. Delete pages whose files no longer exist on disk ──
        let deletedPaths = allExistingPaths.subtracting(diskPaths)
        var deleteCount = 0
        for path in deletedPaths {
            if let page = existingByPath[path] {
                modelContext.delete(page)
                deleteCount += 1
            }
        }

        if changeCount > 0 || deleteCount > 0 {
            try modelContext.save()
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

        log.info(
            "Vault import complete: \(diskPaths.count) note files on disk → \(insertCount) new, \(updateCount) updated, \(skipCount) unchanged, \(deleteCount) deleted"
        )
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
        if let existingFolders = try? modelContext.fetch(existingFolderDescriptor) {
            for folder in existingFolders {
                let path = folder.relativePath
                if !path.isEmpty {
                    foldersByPath[path] = folder
                }
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

        try modelContext.save()
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
                try modelContext.save()
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
            try modelContext.save()
            log.info("Repair: fixed \(subfolderFixed) missing subfolders, wired \(repaired) orphaned pages to folders")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: vaultFoldersRepairedNotification, object: nil)
            }
        }
    }

    // MARK: - Single File Re-index

    /// Re-index a single file that changed externally.
    @discardableResult
    func reindexFile(at url: URL, vaultURL: URL) throws -> Bool {
        let changed = try upsertPage(from: url, vaultURL: vaultURL)
        if changed {
            try modelContext.save()
            log.debug("Re-indexed: \(url.lastPathComponent, privacy: .public)")
        }
        return changed
    }

    // MARK: - Export to Disk

    /// Write a page's body back to its .md file (Source of Truth write-back).
    func exportPage(pageId: String, to vaultURL: URL) throws -> String? {
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

        // Build content — markdown with front-matter for .md files, plain text for .txt
        let ext = fileURL.pathExtension.lowercased()
        let output = (ext == "txt") ? page.loadBody() : buildMarkdown(for: page)
        try coordinatedWrite(output, to: fileURL)

        // Persist filePath back to the store so subsequent exports use the same path.
        // Without this save, the filePath only exists in the background actor's memory
        // and the mainContext never sees it — causing duplicate file creation.
        try modelContext.save()

        log.debug("Exported: \(fileURL.lastPathComponent, privacy: .public)")
        return fileURL.path
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
            modelContext.delete(page)
        }
        try modelContext.save()
        log.debug("Removed deleted file from index: \(url.lastPathComponent, privacy: .public)")
    }

    // MARK: - Private Helpers

    /// Upsert a page from a .md file URL. Updates if exists (by filePath), creates if new.
    private func upsertPage(from fileURL: URL, vaultURL: URL) throws -> Bool {
        // Pre-flight check: verify the file is actually readable before attempting I/O.
        // Security-scoped access is process-wide (granted by VaultSyncService), but individual
        // files may be locked, in Trash, symlinked, or otherwise inaccessible.
        let fm = FileManager.default
        guard fm.isReadableFile(atPath: fileURL.path) else {
            log.warning(
                "Skipping unreadable file: \(fileURL.lastPathComponent, privacy: .public) at \(fileURL.path, privacy: .private)"
            )
            return false
        }

        let filePath = fileURL.path

        let content: String
        do {
            content = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            log.error(
                "Failed to read \(fileURL.lastPathComponent, privacy: .public): \(error, privacy: .public)"
            )
            return false  // Skip this file instead of crashing the entire import
        }

        let (frontMatter, body) = parseFrontMatter(content)

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
            // Skip no-op writes (common for self-originated saves) to avoid UI churn.
            if page.loadBody(mapped: true) != body || page.title != parsedTitle || page.tags != parsedTags
                || page.emoji != parsedEmoji || page.frontMatter != frontMatter
                || page.wordCount != parsedWordCount
            {
                page.saveBody(body)
                page.updatedAt = .now
                page.wordCount = parsedWordCount
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

                do {
                    try searchService?.upsert(
                        id: page.id, title: page.title, body: body,
                        tags: page.tags.joined(separator: " "), updatedAt: page.updatedAt
                    )
                } catch {
                    log.error("FTS5 upsert failed for page \(page.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
                return true
            }
            return false
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
                let existingWithId = (try? modelContext.fetch(idDescriptor)) ?? []
                let isOwnedByAnotherFile = existingWithId.contains { $0.filePath != filePath }
                if isOwnedByAnotherFile {
                    log.info("Duplicate file detected for page \(savedId, privacy: .public) — assigning new ID")
                } else {
                    page.id = savedId
                }
            }

            page.saveBody(body)
            page.filePath = filePath
            page.wordCount = parsedWordCount
            page.emoji = parsedEmoji

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
            do {
                try searchService?.upsert(
                    id: page.id, title: page.title, body: body,
                    tags: page.tags.joined(separator: " "), updatedAt: page.updatedAt
                )
            } catch {
                log.error("FTS5 insert failed for page \(page.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
            return true
        }
    }

    /// Parse YAML front-matter from markdown content.
    /// Returns (frontMatter dict, body without front-matter).
    private func parseFrontMatter(_ content: String) -> ([String: String], String) {
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
    private func buildMarkdown(for page: SDPage) -> String {
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
        lines.append(page.loadBody())
        return lines.joined(separator: "\n")
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

    /// Count words in text content.
    private func countWords(_ text: String) -> Int {
        var count = 0
        text.enumerateSubstrings(
            in: text.startIndex..., options: [.byWords, .substringNotRequired]
        ) { _, _, _, _ in
            count += 1
        }
        return count
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

    /// All page (id, updatedAt) pairs for diff sync.
    func allPageTimestamps() -> [(id: String, updatedAt: Date)] {
        let descriptor = FetchDescriptor<SDPage>()
        guard let pages = try? modelContext.fetch(descriptor) else { return [] }
        return pages.map { ($0.id, $0.updatedAt) }
    }

    /// Full page data for a single page (used by diff sync provider).
    func fullPageData(for pageId: String) -> (title: String, body: String, tags: String, updatedAt: Date)? {
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
        guard let page = try? modelContext.fetch(descriptor).first else { return nil }
        return (page.title, page.loadBody(mapped: true), page.tags.joined(separator: " "), page.updatedAt)
    }

    /// All pages formatted for a full FTS5 rebuild.
    func allPagesForRebuild() -> [(id: String, title: String, body: String, tags: String, updatedAt: Date)] {
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { !$0.isArchived && $0.templateId == nil }
        )
        guard let pages = try? modelContext.fetch(descriptor) else { return [] }
        return pages.map { ($0.id, $0.title, $0.loadBody(mapped: true), $0.tags.joined(separator: " "), $0.updatedAt) }
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
    /// Runs on this background actor so all `@Attribute(.externalStorage)` body reads
    /// happen off the main thread (each .body access triggers a lazy disk read).
    ///
    /// Relevance filtering:
    /// 1. Stop words + conversational filler stripped from search terms
    /// 2. Queries with < 2 meaningful terms return nil (catches vague follow-ups)
    /// 3. Notes scored by term-match count × term specificity (length)
    /// 4. Minimum score threshold gates injection — no low-relevance leaks
    func buildVaultContext(for query: String) -> String? {
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
        guard let pages = try? modelContext.fetch(descriptor) else { return nil }

        // ── 4. Score each page by relevance ─────────────────────────────
        struct ScoredPage {
            let page: SDPage
            let score: Double
        }

        var scored: [ScoredPage] = []
        let titleScanPages = pages  // all pages get title scanned (cheap)
        let bodyScanPages = pages.prefix(30)  // only recent pages get body scanned (disk I/O)
        let bodyScanIds = Set(bodyScanPages.map(\.id))

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
            // or this is in the body-scan window. Each body match: +1 base + length bonus
            if bodyScanIds.contains(page.id), score < 8 {
                let bodyLower = String(page.loadBody(mapped: true).lowercased().prefix(1500))
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
        let notesSection = relevant.map { scored in
            "### \(scored.page.title)\nTags: [\(scored.page.tags.joined(separator: ", "))]\n\(String(scored.page.loadBody(mapped: true).prefix(500)))"
        }.joined(separator: "\n\n")

        // Build folder list for action instructions
        let folderDescriptor = FetchDescriptor<SDFolder>(sortBy: [SortDescriptor(\.sortOrder)])
        let folderNames = (try? modelContext.fetch(folderDescriptor))?.map(\.name) ?? []

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
    func buildAmbientManifest() -> VaultManifest? {
        var descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { !$0.isArchived },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 500

        guard let pages = try? modelContext.fetch(descriptor), !pages.isEmpty else { return nil }

        let entries: [VaultManifest.ManifestEntry] = pages.map { page in
            VaultManifest.ManifestEntry(
                pageId: page.id,
                title: page.title,
                tags: page.tags,
                folderName: page.folder?.name,
                wordCount: page.wordCount,
                snippet: page.summary.isEmpty ? page.title : page.summary,
                updatedAt: page.updatedAt,
                createdAt: page.createdAt
            )
        }

        return VaultManifest(
            entries: entries,
            recentBodies: [],
            generatedAt: .now
        )
    }

    /// Build a complete vault manifest for vault briefing.
    /// Includes metadata for ALL non-archived notes + full bodies of the 20 most recent.
    func buildVaultManifest() -> VaultManifest? {
        var descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { !$0.isArchived },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 500

        guard let pages = try? modelContext.fetch(descriptor), !pages.isEmpty else { return nil }

        let entries: [VaultManifest.ManifestEntry] = pages.map { page in
            VaultManifest.ManifestEntry(
                pageId: page.id,
                title: page.title,
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

        // Deep-read: full bodies of the 20 most recently edited
        let recentBodies: [VaultManifest.NoteBody] = pages.prefix(20).map { page in
            VaultManifest.NoteBody(
                pageId: page.id,
                title: page.title,
                body: String(page.loadBody(mapped: true).prefix(2000))
            )
        }

        return VaultManifest(
            entries: entries,
            recentBodies: recentBodies,
            generatedAt: .now
        )
    }

    /// Fetch full bodies for specific notes by page ID (for @-mention resolution & preWarm).
    func fetchNoteBodies(ids: [String]) -> [VaultManifest.NoteBody] {
        guard !ids.isEmpty else { return [] }
        // Individual fetches — SwiftData #Predicate can't reliably translate
        // local array .contains() to SQL, causing runtime crashes.
        // Batch sizes are small (3-6 IDs) so N fetches are fine.
        var results: [VaultManifest.NoteBody] = []
        for id in ids {
            let descriptor = FetchDescriptor<SDPage>(
                predicate: #Predicate<SDPage> { $0.id == id }
            )
            if let page = try? modelContext.fetch(descriptor).first {
                results.append(VaultManifest.NoteBody(
                    pageId: page.id, title: page.title, body: page.loadBody(mapped: true)
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
        guard let pages = try? modelContext.fetch(descriptor) else { return [] }
        return pages.filter { $0.title.lowercased().contains(q) }.prefix(8).map { page in
            VaultManifest.ManifestEntry(
                pageId: page.id,
                title: page.title,
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

    /// Re-index pages into Core Spotlight, skipping pages unchanged since last index.
    /// Only reads .body for pages that actually need reindexing.
    func spotlightReindexAll() {
        let lastIndexDate = UserDefaults.standard.object(forKey: "epistemos.lastSpotlightIndexDate") as? Date
            ?? .distantPast

        var descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.updatedAt > lastIndexDate },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        // Safety cap: don't try to index more than 1000 at once
        descriptor.fetchLimit = 1000

        guard let pages = try? modelContext.fetch(descriptor), !pages.isEmpty else {
            log.info("Spotlight: no pages changed since last index")
            return
        }

        let batchSize = 50
        let total = pages.count

        for batchStart in stride(from: 0, to: total, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, total)
            let batch = pages[batchStart..<batchEnd]

            let items = batch.map { page -> CSSearchableItem in
                let pageBody = page.loadBody(mapped: true)
                return SpotlightIndexer.makeItem(for: page, body: pageBody)
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
        UserDefaults.standard.set(Date.now, forKey: "epistemos.lastSpotlightIndexDate")
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
            do {
                try content.write(to: newURL, atomically: true, encoding: .utf8)
            } catch {
                writeError = error
            }
        }

        if let coordinatorError {
            throw coordinatorError
        }
        if let writeError {
            throw writeError
        }
    }
}
