import Foundation

// Owner 2026-06-18 (per-model vaults): the Model Vaults settings used to render
// GENERIC hardcoded file rows ("Present in compiled vaults") with no real data.
// This inspector reads the ACTUAL on-disk status of each model's compiled vault
// files (existence, byte size, last-modified) so the UI can show honest
// per-model status instead of a fixed claim. Pure w.r.t. its (directory,
// fileManager) inputs → unit-testable with a temp-dir fixture.

/// Real on-disk status of one compiled-vault file.
struct ModelVaultFileStatus: Sendable, Equatable, Identifiable {
    let name: String
    let description: String
    let exists: Bool
    let sizeBytes: Int
    let modifiedAt: Date?
    var id: String { name }
}

enum ModelVaultFileInspector {
    /// The canonical KnowledgeFusion compiled-vault files, in display order.
    /// (meta.json is intentionally excluded — it's bookkeeping, not content.)
    static let canonicalFiles: [(name: String, description: String)] = [
        ("knowledge_profile.md", "Domain map, entity graph, and writing-style fingerprint"),
        ("concept_index.md", "Ranked concepts distilled from your notes"),
        ("active_context.md", "Rolling active-context window plus recent chats"),
        ("instructions.md", "User-editable preferences and conventions for this model"),
    ]

    /// Probe a model's vault directory for the canonical files. Never throws —
    /// a missing directory or file yields `exists: false` with zeroed stats, so
    /// the UI shows an honest "not compiled" row instead of an error.
    static func probe(
        directory: URL,
        fileManager: FileManager = .default
    ) -> [ModelVaultFileStatus] {
        canonicalFiles.map { file in
            let url = directory.appendingPathComponent(file.name)
            let exists = fileManager.fileExists(atPath: url.path)
            let attrs = exists ? try? fileManager.attributesOfItem(atPath: url.path) : nil
            return ModelVaultFileStatus(
                name: file.name,
                description: file.description,
                exists: exists,
                sizeBytes: (attrs?[.size] as? NSNumber)?.intValue ?? 0,
                modifiedAt: attrs?[.modificationDate] as? Date
            )
        }
    }

    /// A short single-line content preview of a vault file (owner 2026-06-18:
    /// "content preview"). Reads at most a bounded prefix (never loads a large
    /// file), collapses runs of whitespace/newlines to single spaces, and
    /// truncates to `maxChars` with an ellipsis. Returns nil for a missing or
    /// blank file. Pure w.r.t. the URL → unit-testable.
    static func preview(of url: URL, maxChars: Int = 180) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: 8192)) ?? Data()
        guard let raw = String(data: data, encoding: .utf8) else { return nil }
        let collapsed = raw
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return nil }
        if collapsed.count <= maxChars { return collapsed }
        return String(collapsed.prefix(maxChars)) + "…"
    }

    /// Human-friendly, locale-independent byte size for the status rows.
    static func formatBytes(_ bytes: Int) -> String {
        if bytes <= 0 { return "0 B" }
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024
        if kb < 1024 { return "\(Int(kb.rounded())) KB" }
        let mb = kb / 1024
        return String(format: "%.1f MB", mb)
    }

    /// True when at least one canonical content file exists on disk.
    static func anyCompiled(_ files: [ModelVaultFileStatus]) -> Bool {
        files.contains { $0.exists }
    }

    /// Total bytes across the existing canonical files.
    static func totalBytes(_ files: [ModelVaultFileStatus]) -> Int {
        files.reduce(0) { $0 + ($1.exists ? $1.sizeBytes : 0) }
    }
}
