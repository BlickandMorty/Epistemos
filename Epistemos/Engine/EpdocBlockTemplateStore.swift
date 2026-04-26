import Foundation

// MARK: - EpdocBlockTemplateStore
//
// Wave 7.17.b block templates. Per-vault library of reusable block
// snippets the slash menu surfaces under `/template`. Each template
// is a tiny `.epdoc`-shaped JSON file at:
//
//   <vault>/.epcache/templates/<template_id>.json
//
// Storing them as `.epcache/` files keeps the templates out of the
// gitignored content tree + travels with the vault. Templates carry
// a name, optional description, and a ProseMirror JSON node tree
// the slash menu inserts at the cursor.
//
// V1 surface: load all + filter by prefix. V2 surface: edit + save
// from the editor itself.

nonisolated public struct EpdocBlockTemplate: Codable, Sendable, Hashable {
    /// Stable id (ULID). Embedded in the filename + payload so a
    /// rename can detect drift.
    public let id: String
    /// Human-readable name shown in the slash-menu picker.
    public let name: String
    /// Optional one-line description shown as a slash-menu subtitle.
    public let description: String?
    /// SF Symbol name shown in the slash-menu row.
    public let icon: String
    /// ProseMirror JSON node tree the slash menu inserts at the
    /// cursor. The receiver runs `editor.commands.insertContent(node)`.
    public let nodeJSON: String

    public init(
        id: String,
        name: String,
        description: String? = nil,
        icon: String = "doc.on.doc",
        nodeJSON: String
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.nodeJSON = nodeJSON
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case icon
        case nodeJSON = "node_json"
    }
}

/// Process-wide store, scoped to a single vault root. Multiple vaults
/// → multiple actor instances; the main app holds one tied to the
/// active workspace.
public actor EpdocBlockTemplateStore {

    public static let templatesSubdir: String = ".epcache/templates"

    public let vaultRoot: URL
    private(set) public var templates: [EpdocBlockTemplate] = []

    public init(vaultRoot: URL) {
        self.vaultRoot = vaultRoot
    }

    // MARK: - I/O

    /// Reload templates from disk. Idempotent. First-launch (no
    /// directory) → empty templates list.
    public func reload() throws {
        templates.removeAll()
        let dir = vaultRoot.appendingPathComponent(Self.templatesSubdir, isDirectory: true)
        guard FileManager.default.fileExists(atPath: dir.path) else {
            return
        }
        let files = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        )
        for fileURL in files where fileURL.pathExtension.lowercased() == "json" {
            let data = try Data(contentsOf: fileURL)
            if let decoded = try? JSONDecoder().decode(EpdocBlockTemplate.self, from: data) {
                templates.append(decoded)
            }
        }
        // Stable lexicographic name sort so the slash-menu order is
        // predictable across reloads.
        templates.sort { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// Persist a single template to disk. Overwrites any existing
    /// file with the same id.
    public func save(_ template: EpdocBlockTemplate) throws {
        let dir = vaultRoot.appendingPathComponent(Self.templatesSubdir, isDirectory: true)
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        let fileURL = dir.appendingPathComponent("\(template.id).json", isDirectory: false)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(template)
        try data.write(to: fileURL, options: [.atomic])
        // Refresh in-memory copy.
        if let idx = templates.firstIndex(where: { $0.id == template.id }) {
            templates[idx] = template
        } else {
            templates.append(template)
            templates.sort { $0.name.lowercased() < $1.name.lowercased() }
        }
    }

    /// Remove a template by id.
    public func remove(id: String) throws {
        templates.removeAll { $0.id == id }
        let fileURL = vaultRoot
            .appendingPathComponent(Self.templatesSubdir, isDirectory: true)
            .appendingPathComponent("\(id).json", isDirectory: false)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    // MARK: - Queries

    /// Filter by case-insensitive substring on the name (drives the
    /// slash menu's autocomplete).
    public func matching(prefix: String) -> [EpdocBlockTemplate] {
        if prefix.isEmpty { return templates }
        let needle = prefix.lowercased()
        return templates.filter {
            $0.name.lowercased().contains(needle) || $0.id == needle
        }
    }
}
