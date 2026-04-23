import Foundation

struct ModelVaultDocumentEntry: Identifiable, Hashable {
    let url: URL
    let relativePath: String
    let isHidden: Bool

    var id: String { relativePath }

    var displayName: String {
        URL(fileURLWithPath: relativePath).lastPathComponent
    }

    var systemImage: String {
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
            if values?.isDirectory == true, !includeHidden, isInternalPath(relativePath(for: url, rootPrefix: rootPrefix)) {
                enumerator.skipDescendants()
                continue
            }
            guard values?.isRegularFile == true else { continue }

            let relativePath = relativePath(for: url, rootPrefix: rootPrefix)
            let isHidden = isInternalPath(relativePath)
            if isHidden && !includeHidden {
                continue
            }

            entries.append(
                ModelVaultDocumentEntry(
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

    private static func sortRank(for entry: ModelVaultDocumentEntry) -> Int {
        let lowercasedPath = entry.relativePath.lowercased()
        if let index = preferredFiles.firstIndex(of: lowercasedPath) {
            return index
        }
        return entry.isHidden ? preferredFiles.count + 1 : preferredFiles.count
    }
}
