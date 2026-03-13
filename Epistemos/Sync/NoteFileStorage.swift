import AppKit
import Foundation
import os

final class NoteFileMutationQueue: @unchecked Sendable {
    private let queue: DispatchQueue

    nonisolated init(label: String = "com.epistemos.NoteFileStorage.mutation") {
        self.queue = DispatchQueue(label: label, qos: .utility)
    }

    nonisolated func performSync(_ operation: () -> Void) {
        queue.sync(execute: operation)
    }

    nonisolated func performAsync(_ operation: @escaping @Sendable () -> Void) async {
        await withCheckedContinuation { continuation in
            queue.async {
                operation()
                continuation.resume()
            }
        }
    }
}

/// File-based storage for note bodies. Bodies are stored as .md files in Application Support,
/// keyed by page ID. This keeps SQLite rows small — FetchDescriptor only loads metadata.
///
/// All methods are `nonisolated` — pure filesystem I/O with no UI dependency.
/// This allows calling from any actor: MainActor, VaultIndexActor, SDPage (nonisolated), etc.
enum NoteFileStorage {
    private nonisolated static let logger = Logger(subsystem: "com.epistemos", category: "NoteFileStorage")
    private nonisolated static let mutationQueue = NoteFileMutationQueue()
    private nonisolated(unsafe) static var storageDirectoryOverride: URL?

    private nonisolated static func bodyURL(pageId: String) -> URL {
        storageDirectory().appendingPathComponent("\(pageId).md")
    }

    private nonisolated static func legacyRichTextURL(pageId: String) -> URL {
        storageDirectory().appendingPathComponent("\(pageId).rtfd")
    }

    private nonisolated static func managedBodyPageId(for url: URL) -> String? {
        let ext = url.pathExtension.lowercased()
        guard ext == "md" || ext == "rtfd" else { return nil }
        let pageId = url.deletingPathExtension().lastPathComponent
        return isValidPageId(pageId) ? pageId : nil
    }

    @discardableResult
    private nonisolated static func persistBody(_ content: String, to url: URL, pageId: String) -> Bool {
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            logger.error("Failed to write body for \(pageId): \(error.localizedDescription)")
            return false
        }
    }

    private nonisolated static func migrateLegacyRichTextBody(pageId: String) -> String {
        let url = legacyRichTextURL(pageId: pageId)
        guard FileManager.default.fileExists(atPath: url.path),
              let content = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) else {
            return ""
        }

        let body = content.string
        guard persistBody(body, to: bodyURL(pageId: pageId), pageId: pageId) else {
            return ""
        }

        try? FileManager.default.removeItem(at: url)
        logger.notice("Migrated legacy RTFD note to markdown storage for \(pageId, privacy: .private)")
        return body
    }

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
    /// Cached after first access — the directory is created once and never changes.
    private nonisolated static let _storageDirectory: URL = {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            let fallback = fm.temporaryDirectory.appendingPathComponent("Epistemos/note-bodies", isDirectory: true)
            try? fm.createDirectory(at: fallback, withIntermediateDirectories: true)
            return fallback
        }
        let dir = appSupport.appendingPathComponent("Epistemos/note-bodies", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    nonisolated static func setStorageDirectoryOverrideForTesting(_ url: URL?) {
        storageDirectoryOverride = url
        if let url {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    nonisolated static func storageDirectory() -> URL {
        let dir = storageDirectoryOverride ?? _storageDirectory
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
        let url = bodyURL(pageId: pageId)
        let options: Data.ReadingOptions = mapped ? .mappedIfSafe : []
        guard let data = try? Data(contentsOf: url, options: options),
              let text = String(data: data, encoding: .utf8) else {
            return migrateLegacyRichTextBody(pageId: pageId)
        }
        return text
    }

    /// Read raw file data for a note body. Returns nil if file doesn't exist or pageId is invalid.
    /// Uses mmap by default — ideal for hashing and search indexing where
    /// you only need bytes, not a decoded String.
    nonisolated static func readBodyData(pageId: String) -> Data? {
        guard isValidPageId(pageId) else { return nil }
        let url = bodyURL(pageId: pageId)
        return try? Data(contentsOf: url, options: .mappedIfSafe)
    }

    /// Write a note body to disk.
    nonisolated static func writeBody(pageId: String, content: String) {
        guard isValidPageId(pageId) else {
            logger.error("Invalid pageId rejected in writeBody: \(pageId.prefix(20))")
            return
        }
        let url = bodyURL(pageId: pageId)

        // Empty writes are legitimate (user cleared the note). The original zero-byte
        // bug is fixed by textDidChange restructure + NSNotFound bounds checks + direct
        // file save bypassing the SwiftUI binding chain. No need to block empty writes here.
        mutationQueue.performSync {
            _ = persistBody(content, to: url, pageId: pageId)
        }
    }

    /// Write a note body off the caller actor while preserving global file mutation order.
    nonisolated static func writeBodyAsync(pageId: String, content: String) async {
        guard isValidPageId(pageId) else {
            logger.error("Invalid pageId rejected in writeBodyAsync: \(pageId.prefix(20))")
            return
        }
        let url = bodyURL(pageId: pageId)
        await mutationQueue.performAsync {
            _ = persistBody(content, to: url, pageId: pageId)
        }
    }

    /// Delete a note body file.
    nonisolated static func deleteBody(pageId: String) {
        guard isValidPageId(pageId) else { return }
        let url = bodyURL(pageId: pageId)
        mutationQueue.performSync {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Check if a body file exists on disk.
    nonisolated static func bodyExists(pageId: String) -> Bool {
        guard isValidPageId(pageId) else { return false }
        let url = bodyURL(pageId: pageId)
        return FileManager.default.fileExists(atPath: url.path)
    }

    @discardableResult
    nonisolated static func cleanupOrphanBodies<S: Sequence>(
        in directory: URL? = nil,
        validPageIds: S
    ) -> [String]
    where S.Element == String {
        let validIds = Set(validPageIds.filter { isValidPageId($0) })
        let storageURL = directory ?? storageDirectory()
        var removed: [String] = []

        mutationQueue.performSync {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: storageURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                return
            }

            for fileURL in contents {
                guard let pageId = managedBodyPageId(for: fileURL) else { continue }
                guard !validIds.contains(pageId) else { continue }
                do {
                    try FileManager.default.removeItem(at: fileURL)
                    removed.append(pageId)
                } catch {
                    logger.error(
                        "Failed to remove orphan body for \(pageId, privacy: .private): \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        }

        return removed.sorted()
    }

    nonisolated static func managedBodyPageIds(in directory: URL? = nil) -> [String] {
        let storageURL = directory ?? storageDirectory()
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: storageURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.compactMap(managedBodyPageId(for:)).sorted()
    }

    nonisolated static func managedBodyCount(in directory: URL? = nil) -> Int {
        managedBodyPageIds(in: directory).count
    }

    @discardableResult
    nonisolated static func removeAllManagedBodies(in directory: URL? = nil) -> [String] {
        let storageURL = directory ?? storageDirectory()
        var removed: [String] = []

        mutationQueue.performSync {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: storageURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                return
            }

            for fileURL in contents {
                guard let pageId = managedBodyPageId(for: fileURL) else { continue }
                do {
                    try FileManager.default.removeItem(at: fileURL)
                    removed.append(pageId)
                } catch {
                    logger.error(
                        "Failed to remove managed body for \(pageId, privacy: .private): \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        }

        return removed.sorted()
    }

    // MARK: - External Body Change Notification

    /// Posted when note body is changed outside the editor (restore-to-version, vault sync, etc.).
    /// `userInfo["pageId"]` contains the affected page ID as `String`.
    /// ProseEditorView listens for this to reload from disk without relying on `page.body` (which
    /// is always "" for migrated notes and therefore useless as a change signal).
    nonisolated static let pageBodyDidChange = Notification.Name("EpistemosPageBodyDidChange")

    /// Asks any open editor for the given page to flush its in-memory edits to disk NOW.
    /// Synchronous on main thread — when this returns, disk is up to date.
    nonisolated static let pageBodyWillRead = Notification.Name("EpistemosPageBodyWillRead")

    /// Post the body-changed notification on the main thread.
    /// Call after `saveBody()` completes in any external mutation path (restore, sync, etc.).
    @MainActor static func notifyBodyChanged(pageId: String) {
        NotificationCenter.default.post(name: pageBodyDidChange, object: nil, userInfo: ["pageId": pageId])
    }

    /// Ask any open editor for this page to flush pending edits to disk.
    /// Synchronous — disk is current when this returns.
    @MainActor static func requestFlush(pageId: String) {
        NotificationCenter.default.post(name: pageBodyWillRead, object: nil, userInfo: ["pageId": pageId])
    }
}
