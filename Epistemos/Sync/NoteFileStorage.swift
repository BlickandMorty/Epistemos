import Foundation
import os

/// File-based storage for note bodies. Bodies are stored as .md files in Application Support,
/// keyed by page ID. This keeps SQLite rows small — FetchDescriptor only loads metadata.
///
/// All methods are `nonisolated` — pure filesystem I/O with no UI dependency.
/// This allows calling from any actor: MainActor, VaultIndexActor, SDPage (nonisolated), etc.
enum NoteFileStorage {
    private nonisolated static let logger = Logger(subsystem: "com.epistemos", category: "NoteFileStorage")

    /// Validates that a pageId is safe for use as a filename component.
    /// Rejects empty strings, path separators, traversal sequences, and null bytes.
    nonisolated static func isValidPageId(_ pageId: String) -> Bool {
        !pageId.isEmpty
            && !pageId.contains("/")
            && !pageId.contains("\\")
            && !pageId.contains("..")
            && !pageId.contains("\0")
            && pageId.count <= 256
    }

    /// Base directory: ~/Library/Application Support/Epistemos/note-bodies/
    nonisolated static func storageDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Epistemos/note-bodies", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Read a note body from disk. Returns empty string if file doesn't exist or pageId is invalid.
    ///
    /// - Parameter mapped: When `true`, uses `mmap` via `Data(contentsOf:options:.mappedIfSafe)`.
    ///   The file bytes stay on disk and are paged in lazily by the kernel — zero heap allocation.
    ///   Use for bulk operations (indexing, hashing, search) where many files are read in a loop.
    ///   Falls back to normal read for small files or network filesystems.
    nonisolated static func readBody(pageId: String, mapped: Bool = false) -> String {
        guard isValidPageId(pageId) else { return "" }
        let url = storageDirectory().appendingPathComponent("\(pageId).md")
        let options: Data.ReadingOptions = mapped ? .mappedIfSafe : []
        guard let data = try? Data(contentsOf: url, options: options),
              let text = String(data: data, encoding: .utf8) else {
            return ""
        }
        return text
    }

    /// Read raw file data for a note body. Returns nil if file doesn't exist or pageId is invalid.
    /// Uses mmap by default — ideal for hashing and search indexing where
    /// you only need bytes, not a decoded String.
    nonisolated static func readBodyData(pageId: String) -> Data? {
        guard isValidPageId(pageId) else { return nil }
        let url = storageDirectory().appendingPathComponent("\(pageId).md")
        return try? Data(contentsOf: url, options: .mappedIfSafe)
    }

    /// Write a note body to disk.
    nonisolated static func writeBody(pageId: String, content: String) {
        guard isValidPageId(pageId) else {
            logger.error("Invalid pageId rejected in writeBody: \(pageId.prefix(20))")
            return
        }
        let url = storageDirectory().appendingPathComponent("\(pageId).md")
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            logger.error("Failed to write body for \(pageId): \(error.localizedDescription)")
        }
    }

    /// Delete a note body file.
    nonisolated static func deleteBody(pageId: String) {
        guard isValidPageId(pageId) else { return }
        let url = storageDirectory().appendingPathComponent("\(pageId).md")
        try? FileManager.default.removeItem(at: url)
    }

    /// Check if a body file exists on disk.
    nonisolated static func bodyExists(pageId: String) -> Bool {
        guard isValidPageId(pageId) else { return false }
        let url = storageDirectory().appendingPathComponent("\(pageId).md")
        return FileManager.default.fileExists(atPath: url.path)
    }
}
