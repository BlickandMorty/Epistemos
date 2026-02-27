import Foundation
import SwiftData

// MARK: - Vault Context & Vault Actions
// Builds ambient vault context for queries and executes [ACTION:...] markers.

extension AppBootstrap {

    // MARK: - Vault Context

    /// Build vault context for queries when a vault is attached.
    /// Injects ambient manifest (titles/metadata only) + resolves @[Note Title] references.
    /// Returns (notesContext, cleanedQuery) where cleanedQuery has @-references stripped.
    func buildNotesContext(query: String, chatState: ChatState) async -> (String?, String) {
        guard ambientManifest != nil else { return (nil, query) }

        var contextParts: [String] = []
        var cleanedQuery = query

        // 1. Include ambient manifest (titles + metadata, no bodies)
        if let manifest = ambientManifest {
            contextParts.append(manifest.asManifestOnly())
        }

        // 2. Parse and resolve @[Note Title] references
        let mentionPattern = #"@\[([^\]]+)\]"#
        if let regex = try? NSRegularExpression(pattern: mentionPattern) {
            let nsQuery = query as NSString
            let matches = regex.matches(in: query, range: NSRange(location: 0, length: nsQuery.length))

            var titlesToResolve: [String] = []
            for match in matches.reversed() {
                guard let titleRange = Range(match.range(at: 1), in: query) else { continue }
                let title = String(query[titleRange])
                titlesToResolve.append(title)
                if let fullRange = Range(match.range, in: cleanedQuery) {
                    cleanedQuery.replaceSubrange(fullRange, with: title)
                }
            }

            // Fetch full bodies for mentioned notes
            if !titlesToResolve.isEmpty {
                for title in titlesToResolve {
                    let found = await vaultSync.findNotesByTitle(title)
                    let ids = found.map(\.pageId).filter { !chatState.loadedNoteIds.contains($0) }
                    if !ids.isEmpty {
                        let bodies = await vaultSync.fetchNoteBodies(ids: ids)
                        for body in bodies {
                            contextParts.append("### Referenced Note: \(body.title)\n\(body.body)")
                            chatState.loadedNoteIds.insert(body.pageId)
                            chatState.loadedNoteTitles.append(body.title)
                        }
                    }
                }
            }
        }

        // 3. Include previously loaded note bodies (persistent across turns)
        if !chatState.loadedNoteIds.isEmpty {
            let alreadyLoaded = await vaultSync.fetchNoteBodies(ids: Array(chatState.loadedNoteIds))
            for body in alreadyLoaded {
                if !contextParts.contains(where: { $0.contains("### Referenced Note: \(body.title)") }) {
                    contextParts.append("### Previously Referenced: \(body.title)\n\(body.body)")
                }
            }
        }

        let context = contextParts.isEmpty ? nil : contextParts.joined(separator: "\n\n")
        return (context, cleanedQuery.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: - Vault Action Execution

    /// Parse [ACTION:...] markers from pipeline response and execute vault mutations.
    /// Returns the response text with markers replaced by confirmation messages.
    func executeVaultActions(in response: String) -> String {
        var cleaned = response
        var executed: [String] = []
        let context = modelContainer.mainContext

        // TAG action
        if let range = response.range(of: #"\[ACTION:TAG\s+(.+?)\]"#, options: .regularExpression) {
            let marker = String(response[range])
            let raw = marker
                .replacingOccurrences(of: "[ACTION:TAG ", with: "")
                .replacingOccurrences(of: "]", with: "")
            let tags = raw.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty && $0.count < 30 }

            if !tags.isEmpty {
                let targetId = notesUI.activePageId
                let page: SDPage?
                if let targetId {
                    let desc = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == targetId })
                    page = try? context.fetch(desc).first
                } else {
                    var desc = FetchDescriptor<SDPage>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
                    desc.fetchLimit = 1
                    page = try? context.fetch(desc).first
                }
                if let page {
                    let newTags = tags.filter { !page.tags.contains($0) }
                    if !newTags.isEmpty {
                        page.tags.append(contentsOf: newTags)
                        page.updatedAt = .now
                        executed.append("✅ Added tags [\(newTags.joined(separator: ", "))] to \(page.title)")
                    }
                }
            }
            cleaned = cleaned.replacingOccurrences(of: marker, with: "")
        }

        // MOVE action
        if let range = response.range(of: #"\[ACTION:MOVE\s+(.+?)\]"#, options: .regularExpression) {
            let marker = String(response[range])
            let folderName = marker
                .replacingOccurrences(of: "[ACTION:MOVE ", with: "")
                .replacingOccurrences(of: "]", with: "")
                .trimmingCharacters(in: .whitespaces)
            let folderDesc = FetchDescriptor<SDFolder>()
            if let folders = try? context.fetch(folderDesc),
               let folder = folders.first(where: { $0.name.lowercased() == folderName.lowercased() }) {
                var pageDesc = FetchDescriptor<SDPage>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
                pageDesc.fetchLimit = 1
                if let page = try? context.fetch(pageDesc).first {
                    page.folder = folder
                    page.updatedAt = .now
                    executed.append("✅ Moved \(page.title) to \(folder.name)")
                }
            }
            cleaned = cleaned.replacingOccurrences(of: marker, with: "")
        }

        // CREATE action
        if let range = response.range(of: #"\[ACTION:CREATE\s+(.+?)\]"#, options: .regularExpression) {
            let marker = String(response[range])
            let title = marker
                .replacingOccurrences(of: "[ACTION:CREATE ", with: "")
                .replacingOccurrences(of: "]", with: "")
                .trimmingCharacters(in: .whitespaces)
            if !title.isEmpty {
                Task {
                    if await vaultSync.createPage(title: title) != nil {
                        // Note created — user can navigate to it from sidebar
                    }
                }
                executed.append("✅ Created note: \(title)")
            }
            cleaned = cleaned.replacingOccurrences(of: marker, with: "")
        }

        if !executed.isEmpty {
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            cleaned += "\n\n---\n" + executed.joined(separator: "\n")
        }

        return cleaned
    }
}
