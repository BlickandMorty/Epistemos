import Foundation

// MARK: - Vault Manifest
// Lightweight in-memory representation of the full vault.
// Built once on Notes Mode entry, reused for all queries in the session.
// ~50-80 tokens per entry — a 200-note vault ≈ 12K tokens.

struct VaultManifest: Sendable {
    let entries: [ManifestEntry]
    let recentBodies: [NoteBody]
    let generatedAt: Date

    struct ManifestEntry: Sendable, Identifiable {
        let pageId: String
        let title: String
        let tags: [String]
        let folderName: String?
        let wordCount: Int
        let snippet: String
        let updatedAt: Date
        let createdAt: Date

        var id: String { pageId }
    }

    struct NoteBody: Sendable {
        let pageId: String
        let title: String
        let body: String
    }

    /// Format the manifest as an LLM-readable context string.
    /// Includes the bird's-eye manifest + full bodies of recent notes.
    func asContext() -> String {
        var parts: [String] = []

        parts.append("## Vault Overview (\(entries.count) notes)")
        for entry in entries {
            let tags = entry.tags.isEmpty ? "" : " [tags: \(entry.tags.joined(separator: ", "))]"
            let folder = entry.folderName.map { " in \($0)" } ?? ""
            let date = entry.updatedAt.formatted(date: .abbreviated, time: .omitted)
            parts.append("- **\(entry.title)**\(folder)\(tags) — \(entry.wordCount) words, updated \(date)\n  \(entry.snippet)")
        }

        if !recentBodies.isEmpty {
            parts.append("\n## Recent Notes (full content)")
            for note in recentBodies {
                parts.append("### \(note.title)\n\(note.body)")
            }
        }

        return parts.joined(separator: "\n")
    }
}
