import Foundation

// MARK: - Vault Manifest
// Lightweight in-memory representation of the full vault.
// Built eagerly on vault attach, shared across all AI surfaces.
// ~30-40 tokens per entry (manifest-only) or ~50-80 (with snippets).

struct VaultManifest: Sendable {
    let vaultTitle: String
    let totalNoteCount: Int
    let isInventoryComplete: Bool
    let entries: [ManifestEntry]
    let recentBodies: [NoteBody]
    let generatedAt: Date

    struct ManifestEntry: Sendable, Identifiable {
        nonisolated let pageId: String
        nonisolated let title: String
        nonisolated let relativePath: String?
        nonisolated let tags: [String]
        nonisolated let folderName: String?
        nonisolated let wordCount: Int
        nonisolated let snippet: String
        nonisolated let updatedAt: Date
        nonisolated let createdAt: Date

        nonisolated var id: String { pageId }

        nonisolated init(
            pageId: String,
            title: String,
            relativePath: String? = nil,
            tags: [String],
            folderName: String?,
            wordCount: Int,
            snippet: String,
            updatedAt: Date,
            createdAt: Date
        ) {
            self.pageId = pageId
            self.title = title
            self.relativePath = relativePath
            self.tags = tags
            self.folderName = folderName
            self.wordCount = wordCount
            self.snippet = snippet
            self.updatedAt = updatedAt
            self.createdAt = createdAt
        }
    }

    struct NoteBody: Sendable {
        nonisolated let pageId: String
        nonisolated let title: String
        nonisolated let relativePath: String?
        nonisolated let body: String

        nonisolated init(
            pageId: String,
            title: String,
            relativePath: String? = nil,
            body: String
        ) {
            self.pageId = pageId
            self.title = title
            self.relativePath = relativePath
            self.body = body
        }
    }

    /// Format the manifest as an LLM-readable context string.
    /// Includes the bird's-eye manifest + full bodies of recent notes.
    func asContext() -> String {
        var parts: [String] = []

        parts.append("## Vault")
        parts.append("- title: \(vaultTitle)")
        parts.append("- notes: \(totalNoteCount)")
        parts.append("- inventory: \(isInventoryComplete ? "complete" : "partial")")
        parts.append("")
        parts.append("## Vault Overview (\(entries.count) listed notes)")
        for entry in entries {
            let tags = entry.tags.isEmpty ? "" : " [tags: \(entry.tags.joined(separator: ", "))]"
            let folder = entry.folderName.map { " in \($0)" } ?? ""
            let date = entry.updatedAt.formatted(date: .abbreviated, time: .omitted)
            parts.append("- **\(entry.title)**\(folder)\(tags) — \(entry.wordCount) words, updated \(date)\n  \(entry.snippet)")
        }

        if !recentBodies.isEmpty {
            parts.append("\n## Recent Notes (full content)")
            for note in recentBodies {
                let pathLine = note.vaultReadReferenceLine.map { "\($0)\n" } ?? ""
                parts.append("### \(note.title)\n\(pathLine)\(note.body)")
            }
        }

        return parts.joined(separator: "\n")
    }

    /// Compact manifest for ambient context injection — titles, tags, and metadata only.
    /// Omits snippets and recent note bodies to minimize token overhead (~30-40 tokens/entry).
    func asManifestOnly() -> String {
        var parts: [String] = []
        parts.append("## Vault")
        parts.append("- title: \(vaultTitle)")
        parts.append("- notes: \(totalNoteCount)")
        parts.append("- inventory: \(isInventoryComplete ? "complete" : "partial")")
        parts.append("")
        parts.append("## Vault Overview (\(entries.count) listed notes)")
        for entry in entries {
            let tags = entry.tags.isEmpty ? "" : " [tags: \(entry.tags.joined(separator: ", "))]"
            let folder = entry.folderName.map { " in \($0)" } ?? ""
            let date = entry.updatedAt.formatted(date: .abbreviated, time: .omitted)
            parts.append("- **\(entry.title)**\(folder)\(tags) — \(entry.wordCount) words, updated \(date)")
        }
        return parts.joined(separator: "\n")
    }
}

struct VaultContextPack: Sendable {
    let manifest: VaultManifest?
    let includeManifest: Bool
    let referencedNotes: [VaultManifest.NoteBody]
    let matchedVaultNotes: [VaultManifest.NoteBody]
    let cleanedQuery: String

    func renderedContext() -> String? {
        var parts: [String] = []
        if includeManifest, let manifest {
            parts.append(manifest.asManifestOnly())
        }

        var seenNoteIDs = Set<String>()
        for note in referencedNotes {
            guard seenNoteIDs.insert(note.pageId).inserted else { continue }
            let pathLine = note.vaultReadReferenceLine.map { "\($0)\n" } ?? ""
            parts.append("### Referenced Note: \(note.title)\n\(pathLine)\(note.body)")
        }

        if !matchedVaultNotes.isEmpty {
            parts.append("## Matched Vault Notes")
            for note in matchedVaultNotes {
                guard seenNoteIDs.insert(note.pageId).inserted else { continue }
                let pathLine = note.vaultReadReferenceLine.map { "\($0)\n" } ?? ""
                parts.append("### Vault Match: \(note.title)\n\(pathLine)\(note.body)")
            }
        }

        return parts.isEmpty ? nil : parts.joined(separator: "\n\n")
    }
}

extension VaultManifest.NoteBody {
    nonisolated var vaultReadReferenceLine: String? {
        guard let relativePath else { return nil }
        let trimmedPath = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return nil }
        return "Canonical vault-relative path (use this with `vault.read`): \(trimmedPath)"
    }
}
