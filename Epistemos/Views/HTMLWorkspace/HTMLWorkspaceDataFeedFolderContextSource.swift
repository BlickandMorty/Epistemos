import Foundation
import SwiftData

extension HTMLWorkspaceDataFeedContextSources {
    static func folderNoteResults(
        query: String?,
        modelContainer: ModelContainer?,
        limit: Int
    ) -> [HTMLWorkspaceDataFeedResult] {
        guard let modelContainer else { return [] }

        let context = ModelContext(modelContainer)
        let terms = folderSearchTerms(from: query)
        guard !terms.isEmpty else { return [] }

        let folders = matchedFolders(terms: terms, context: context)
        guard !folders.isEmpty else { return [] }

        let pages = activePages(context: context)
        let effectiveLimit = HTMLWorkspaceDataFeed.clampedLimit(limit)
        var seenPageIDs = Set<String>()
        var results: [HTMLWorkspaceDataFeedResult] = []
        results.reserveCapacity(effectiveLimit)

        for folder in folders {
            let folderPath = normalizedFolderText(folder.relativePath)
            for page in pages where pageIsInFolder(page, folder: folder, folderPath: folderPath) {
                guard seenPageIDs.insert(page.id).inserted else { continue }
                results.append(folderNoteResult(page: page, folderPath: folderPath, order: results.count))
                if results.count >= effectiveLimit {
                    return results
                }
            }
        }

        return results
    }

    static func shouldUseFolderNoteResults(for query: String?) -> Bool {
        let normalizedQuery = normalizedFolderQuery(query)
        guard !normalizedQuery.isEmpty else { return false }
        if normalizedQuery.hasPrefix("folder:") || normalizedQuery.hasPrefix("folders:") {
            return true
        }
        return normalizedQuery.hasPrefix("folder ") || normalizedQuery.hasPrefix("folders ")
    }

    private static func matchedFolders(terms: [String], context: ModelContext) -> [SDFolder] {
        var descriptor = FetchDescriptor<SDFolder>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
        )
        descriptor.fetchLimit = 500
        return ((try? context.fetch(descriptor)) ?? []).filter { folder in
            let haystack = [
                normalizedFolderText(folder.name),
                normalizedFolderText(folder.relativePath),
            ].joined(separator: " ").lowercased()
            return terms.allSatisfy { haystack.contains($0) }
        }
    }

    private static func activePages(context: ModelContext) -> [SDPage] {
        ((try? context.fetch(SDPage.activePagesDescriptor)) ?? [])
            .filter { !$0.isArchived && $0.templateId == nil }
    }

    private static func pageIsInFolder(_ page: SDPage, folder: SDFolder, folderPath: String) -> Bool {
        if page.folder?.id == folder.id {
            return true
        }
        let subfolder = normalizedFolderText(page.subfolder)
        guard !subfolder.isEmpty, !folderPath.isEmpty else { return false }
        return subfolder == folderPath || subfolder.hasPrefix("\(folderPath)/")
    }

    private static func folderNoteResult(page: SDPage, folderPath: String, order: Int) -> HTMLWorkspaceDataFeedResult {
        let title = normalizedFolderText(page.title).isEmpty ? "Untitled folder note" : page.title
        let summary = normalizedFolderText(page.summary)
        let bodySnippet = page.normalizedBodySnippet(limit: 360)
        let snippet = summary.isEmpty ? bodySnippet : summary
        return HTMLWorkspaceDataFeedResult(
            pageID: page.id,
            title: title,
            snippet: normalizedFolderText(snippet).isEmpty ? "No folder-note excerpt available." : snippet,
            rank: max(0.01, 1.0 - Double(order) * 0.01),
            contextKind: "folder_note",
            sourceLabel: "Folder: \(folderPath)",
            provenance: "SDFolder/SDPage / folder:\(folderPath)"
        )
    }

    private static func folderSearchTerms(from query: String?) -> [String] {
        var value = normalizedFolderQuery(query)
        for prefix in ["folder:", "folders:"] where value.hasPrefix(prefix) {
            value.removeFirst(prefix.count)
            break
        }
        let stopWords: Set<String> = ["folder", "folders"]
        return value
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { !stopWords.contains($0) }
    }

    private static func normalizedFolderQuery(_ value: String?) -> String {
        normalizedFolderText(value).lowercased()
    }

    private static func normalizedFolderText(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func normalizedFolderText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
