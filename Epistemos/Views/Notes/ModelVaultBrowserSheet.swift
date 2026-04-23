import Foundation
import SwiftData

struct ModelVaultDocumentEntry: Identifiable, Hashable {
    enum Kind: Hashable {
        case file
        case directory
    }

    let kind: Kind
    let url: URL
    let relativePath: String
    let isHidden: Bool

    var id: String { relativePath }

    var isDirectory: Bool {
        kind == .directory
    }

    var displayName: String {
        URL(fileURLWithPath: relativePath).lastPathComponent
    }

    var systemImage: String {
        if isDirectory {
            return "folder"
        }
        switch relativePath.lowercased() {
        case "instructions.md":
            return "slider.horizontal.3"
        case "knowledge_profile.md":
            return "brain.head.profile"
        case "concept_index.md":
            return "list.number"
        case "active_context.md":
            return "sparkles.rectangle.stack"
        case "meta.json":
            return "curlybraces"
        default:
            let ext = url.pathExtension.lowercased()
            switch ext {
            case "md", "markdown", "txt", "mdx":
                return "doc.text"
            case "json", "yaml", "yml", "toml":
                return "curlybraces"
            default:
                return "doc"
            }
        }
    }

    var sortRank: Int {
        ModelVaultBrowserStore.sortRank(for: self)
    }
}

enum ModelVaultBrowserStore {
    private static let preferredFiles = [
        "instructions.md",
        "knowledge_profile.md",
        "concept_index.md",
        "active_context.md",
        "meta.json",
    ]

    static func loadEntries(rootURL: URL, includeHidden: Bool = false) -> [ModelVaultDocumentEntry] {
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsPackageDescendants]
        ) else {
            return []
        }

        var entries: [ModelVaultDocumentEntry] = []
        let normalizedRootPath = rootURL.standardizedFileURL.path
        let rootPrefix = normalizedRootPath.hasSuffix("/") ? normalizedRootPath : normalizedRootPath + "/"

        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
            let relativePath = relativePath(for: url, rootPrefix: rootPrefix)
            let isHidden = isInternalPath(relativePath)
            if values?.isDirectory == true {
                if isHidden && !includeHidden {
                    enumerator.skipDescendants()
                    continue
                }
                entries.append(
                    ModelVaultDocumentEntry(
                        kind: .directory,
                        url: url,
                        relativePath: relativePath,
                        isHidden: isHidden
                    )
                )
                continue
            }
            guard values?.isRegularFile == true else { continue }
            if isHidden && !includeHidden { continue }

            entries.append(
                ModelVaultDocumentEntry(
                    kind: .file,
                    url: url,
                    relativePath: relativePath,
                    isHidden: isHidden
                )
            )
        }

        return entries.sorted { lhs, rhs in
            let lhsRank = sortRank(for: lhs)
            let rhsRank = sortRank(for: rhs)
            if lhsRank == rhsRank {
                return lhs.relativePath.localizedCaseInsensitiveCompare(rhs.relativePath) == .orderedAscending
            }
            return lhsRank < rhsRank
        }
    }

    static func isEditableTextFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if ["md", "markdown", "mdx", "txt", "json", "yaml", "yml", "toml", "xml", "html", "css", "js", "ts", "swift", "py", "rs", "sh"].contains(ext) {
            return true
        }
        return url.lastPathComponent.hasPrefix(".")
    }

    nonisolated static func isModelVaultPath(
        _ filePath: String,
        rootURL: URL = ModelVaultsSidebarSection.modelVaultsRootURL()
    ) -> Bool {
        let trimmed = filePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let normalizedRoot = rootURL.standardizedFileURL.path
        let normalizedPath = URL(fileURLWithPath: trimmed).standardizedFileURL.path
        let prefix = normalizedRoot.hasSuffix("/") ? normalizedRoot : normalizedRoot + "/"
        return normalizedPath.hasPrefix(prefix)
    }

    @MainActor
    static func ensureWorkspacePage(
        for document: ModelVaultDocumentEntry,
        modelContext: ModelContext
    ) -> String? {
        guard !document.isDirectory else { return nil }

        let normalizedPath = document.url.standardizedFileURL.path
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.filePath == normalizedPath }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            refreshWorkspacePageFromDiskIfSafe(existing, sourceURL: document.url, modelContext: modelContext)
            return existing.id
        }

        let page = SDPage(title: document.displayName)
        page.filePath = normalizedPath
        syncWorkspacePageFromDisk(page, sourceURL: document.url)
        modelContext.insert(page)

        do {
            try modelContext.save()
            return page.id
        } catch {
            NoteFileStorage.deleteBody(pageId: page.id)
            modelContext.delete(page)
            return nil
        }
    }

    @MainActor
    static func removeWorkspacePages(
        backingDeletedItemAt deletedURL: URL,
        modelContext: ModelContext
    ) -> [String] {
        let normalizedDeletedPath = deletedURL.standardizedFileURL.path
        let descendantPrefix = normalizedDeletedPath.hasSuffix("/")
            ? normalizedDeletedPath
            : normalizedDeletedPath + "/"

        let allPages = (try? modelContext.fetch(FetchDescriptor<SDPage>())) ?? []
        let matchingPages = allPages.filter { page in
            guard let filePath = page.filePath?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !filePath.isEmpty else {
                return false
            }
            let normalizedPagePath = URL(fileURLWithPath: filePath).standardizedFileURL.path
            return normalizedPagePath == normalizedDeletedPath
                || normalizedPagePath.hasPrefix(descendantPrefix)
        }

        guard !matchingPages.isEmpty else { return [] }

        struct RemovedWorkspacePage {
            let page: SDPage
            let insight: SDNoteInsight?
        }

        var removedPages: [RemovedWorkspacePage] = []
        removedPages.reserveCapacity(matchingPages.count)

        for page in matchingPages {
            let pageId = page.id
            let insightDescriptor = FetchDescriptor<SDNoteInsight>(
                predicate: #Predicate { $0.pageId == pageId }
            )
            let insight = try? modelContext.fetch(insightDescriptor).first
            if let insight {
                modelContext.delete(insight)
            }
            modelContext.delete(page)
            removedPages.append(RemovedWorkspacePage(page: page, insight: insight))
        }

        do {
            try modelContext.save()
        } catch {
            for removed in removedPages {
                if let insight = removed.insight {
                    modelContext.insert(insight)
                }
                modelContext.insert(removed.page)
            }
            return []
        }

        let removedPageIDs = removedPages.map(\.page.id)
        for pageId in removedPageIDs {
            SpotlightIndexer.deindex(pageId)
            Task { @MainActor in
                AppBootstrap.shared?.instantRecallService.removeNote(noteId: pageId)
            }
            NoteFileStorage.deleteBody(pageId: pageId)
        }
        return removedPageIDs
    }

    static func readText(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        for encoding in [String.Encoding.utf8, .utf16, .unicode, .ascii] {
            if let text = String(data: data, encoding: encoding) {
                return text
            }
        }
        throw CocoaError(.fileReadInapplicableStringEncoding)
    }

    static func writeText(_ content: String, to url: URL) -> Bool {
        NoteFileStorage.writeTextAtomically(content, to: url, itemLabel: url.lastPathComponent)
    }

    static func createTextFile(
        named rawName: String,
        rootURL: URL,
        relativeDirectory: String? = nil
    ) -> ModelVaultDocumentEntry? {
        let directoryURL = resolvedDirectoryURL(rootURL: rootURL, relativeDirectory: relativeDirectory)
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            return nil
        }

        let preferredName = preferredFileName(from: rawName)
        let fileURL = uniqueChildURL(in: directoryURL, preferredName: preferredName)
        guard writeText("", to: fileURL) else { return nil }

        let rootPrefix = normalizedRootPrefix(for: rootURL)
        return ModelVaultDocumentEntry(
            kind: .file,
            url: fileURL,
            relativePath: relativePath(for: fileURL, rootPrefix: rootPrefix),
            isHidden: isInternalPath(relativePath(for: fileURL, rootPrefix: rootPrefix))
        )
    }

    static func createDirectory(
        named rawName: String,
        rootURL: URL,
        relativeParentDirectory: String? = nil
    ) -> URL? {
        let parentURL = resolvedDirectoryURL(rootURL: rootURL, relativeDirectory: relativeParentDirectory)
        let preferredName = preferredDirectoryName(from: rawName)
        let directoryURL = uniqueChildURL(in: parentURL, preferredName: preferredName)
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            return directoryURL
        } catch {
            return nil
        }
    }

    static func deleteItem(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            return false
        }
    }

    private static func relativePath(for url: URL, rootPrefix: String) -> String {
        let path = url.standardizedFileURL.path
        if path.hasPrefix(rootPrefix) {
            return String(path.dropFirst(rootPrefix.count))
        }
        return url.lastPathComponent
    }

    private static func isInternalPath(_ relativePath: String) -> Bool {
        relativePath.split(separator: "/").contains { $0.hasPrefix(".") }
    }

    private static func normalizedRootPrefix(for rootURL: URL) -> String {
        let normalizedRootPath = rootURL.standardizedFileURL.path
        return normalizedRootPath.hasSuffix("/") ? normalizedRootPath : normalizedRootPath + "/"
    }

    private static func resolvedDirectoryURL(rootURL: URL, relativeDirectory: String?) -> URL {
        guard let relativeDirectory,
              !relativeDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return rootURL
        }
        return rootURL.appendingPathComponent(relativeDirectory, isDirectory: true)
    }

    private static func preferredFileName(from rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "untitled.md" : trimmed
        let normalized = fallback
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return normalized.contains(".") ? normalized : normalized + ".md"
    }

    private static func preferredDirectoryName(from rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "untitled-folder" : trimmed
        return fallback
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
    }

    private static func uniqueChildURL(in directoryURL: URL, preferredName: String) -> URL {
        let preferredURL = directoryURL.appendingPathComponent(preferredName)
        guard !FileManager.default.fileExists(atPath: preferredURL.path) else {
            let ext = preferredURL.pathExtension
            let stem = preferredURL.deletingPathExtension().lastPathComponent
            var counter = 2
            while true {
                let candidateName: String
                if ext.isEmpty {
                    candidateName = "\(stem)-\(counter)"
                } else {
                    candidateName = "\(stem)-\(counter).\(ext)"
                }
                let candidateURL = directoryURL.appendingPathComponent(candidateName)
                if !FileManager.default.fileExists(atPath: candidateURL.path) {
                    return candidateURL
                }
                counter += 1
            }
        }
        return preferredURL
    }

    fileprivate static func sortRank(for entry: ModelVaultDocumentEntry) -> Int {
        if entry.isDirectory {
            return preferredFiles.count
        }
        let lowercasedPath = entry.relativePath.lowercased()
        if let index = preferredFiles.firstIndex(of: lowercasedPath) {
            return index
        }
        return entry.isHidden ? preferredFiles.count + 1 : preferredFiles.count
    }

    @MainActor
    private static func refreshWorkspacePageFromDiskIfSafe(
        _ page: SDPage,
        sourceURL: URL,
        modelContext: ModelContext
    ) {
        guard !page.needsVaultSync else { return }
        guard let diskBody = synchronizedBody(for: sourceURL) else { return }

        let diskHash = SDPage.bodyHash(diskBody)
        guard page.lastSyncedBodyHash != diskHash || !NoteFileStorage.bodyExists(pageId: page.id) else {
            return
        }

        syncWorkspacePageFromDisk(page, sourceURL: sourceURL, bodyOverride: diskBody, bodyHashOverride: diskHash)
        try? modelContext.save()
    }

    @MainActor
    private static func syncWorkspacePageFromDisk(
        _ page: SDPage,
        sourceURL: URL,
        bodyOverride: String? = nil,
        bodyHashOverride: String? = nil
    ) {
        guard let body = bodyOverride ?? synchronizedBody(for: sourceURL) else { return }
        page.saveBody(body)
        page.lastSyncedBodyHash = bodyHashOverride ?? SDPage.bodyHash(body)
        page.lastSyncedAt = contentModificationDate(at: sourceURL) ?? .now
        page.needsVaultSync = false
    }

    private static func synchronizedBody(for sourceURL: URL) -> String? {
        if let decoded = VaultIndexActor.decodedBodyFromReadableVaultFile(at: sourceURL) {
            return decoded
        }
        return try? readText(at: sourceURL)
    }

    private static func contentModificationDate(at sourceURL: URL) -> Date? {
        do {
            return try sourceURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        } catch {
            return nil
        }
    }
}
