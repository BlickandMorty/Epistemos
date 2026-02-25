import Foundation
import SwiftData

// MARK: - SDFolder
// Folder (notebook) in the vault hierarchy. Maps to physical subdirectories on disk.
// Supports nesting via parent-child relationship (Obsidian-style folder trees).
//
// CloudKit-compatible: all properties optional or defaulted, no @Attribute(.unique),
// .cascade on children (deleting folder removes subfolders), .nullify on pages
// (deleting folder orphans pages to root, doesn't delete them).

@Model
final class SDFolder {
    #Index<SDFolder>([\.id])

    // MARK: - Identity
    var id: String = UUID().uuidString

    // MARK: - Content
    var name: String = ""
    var emoji: String = ""
    var sortOrder: Int = 0

    /// Collection folders appear in a dedicated "Collections" section at the top of the sidebar.
    /// Users create these to organize notes by type (Essays, Research, Projects, etc.).
    var isCollection: Bool = false

    // MARK: - Timestamps
    var createdAt: Date = Date.now

    // MARK: - Relationships
    @Relationship(deleteRule: .nullify, inverse: \SDPage.folder)
    var pages: [SDPage]? = []

    @Relationship(deleteRule: .cascade, inverse: \SDFolder.parent)
    var children: [SDFolder]? = []

    var parent: SDFolder?

    // MARK: - Computed

    /// Relative path from vault root, walking the parent chain.
    /// e.g. "Projects/2026" for a "2026" folder inside "Projects".
    /// Depth-capped at 20 to guard against circular reference corruption.
    var relativePath: String {
        var parts: [String] = [name]
        var current = parent
        var visited = Set<String>()
        while let p = current, !visited.contains(p.id), parts.count < 20 {
            visited.insert(p.id)
            parts.insert(p.name, at: 0)
            current = p.parent
        }
        return parts.joined(separator: "/")
    }

    // MARK: - Init

    init(name: String, emoji: String = "") {
        self.id = UUID().uuidString
        self.name = name
        self.emoji = emoji
        self.createdAt = .now
    }
}
