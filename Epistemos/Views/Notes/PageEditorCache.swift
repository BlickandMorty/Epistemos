import AppKit
import CryptoKit
import os

// MARK: - DiskStyleCache
// Persists scroll position and selection per page to disk so they survive app restarts.
// Lightweight metadata only — live editor state stays in the active TextKit 2 stack.
//
// Lifecycle:
//   dismantleNSView → save scroll/selection + body hash
//   makeNSView      → on pool miss, check disk → restore scroll position
//   AppBootstrap    → evictIfNeeded (cap at 200 files)

@MainActor
final class DiskStyleCache {
    static let shared = DiskStyleCache()
    private static let log = Logger(subsystem: "com.epistemos", category: "DiskStyleCache")

    nonisolated struct CacheEntry: Codable, Sendable {
        let bodyHash: String
        let scrollY: CGFloat
        let selectionLocation: Int
        let selectionLength: Int
        let lastOpenedAt: TimeInterval

        var selection: NSRange { NSRange(location: selectionLocation, length: selectionLength) }
    }

    private let cacheDir: URL
    private let maxFiles = 200

    private init() {
        let appSupport = FoundationSafety.userApplicationSupportDirectory()
            .appendingPathComponent("Epistemos", isDirectory: true)
        cacheDir = appSupport.appendingPathComponent("style-cache", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        } catch {
            Self.log.error(
                "DiskStyleCache: failed to create cache directory: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    // MARK: - Save

    func save(pageId: String, bodyText: String, scrollY: CGFloat, selection: NSRange) {
        let entry = CacheEntry(
            bodyHash: Self.bodyHash(bodyText),
            scrollY: scrollY,
            selectionLocation: selection.location,
            selectionLength: selection.length,
            lastOpenedAt: Date.now.timeIntervalSinceReferenceDate
        )
        let url = cacheDir.appendingPathComponent("\(pageId).json")
        do {
            let data = try JSONEncoder().encode(entry)
            try data.write(to: url, options: .atomic)
        } catch {
            Self.log.error(
                "DiskStyleCache: failed to write cache entry for \(pageId, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    // MARK: - Restore

    func restore(pageId: String, currentBodyText: String) -> CacheEntry? {
        let url = cacheDir.appendingPathComponent("\(pageId).json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            Self.log.error(
                "DiskStyleCache: failed to read cache entry for \(pageId, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }

        let entry: CacheEntry
        do {
            entry = try JSONDecoder().decode(CacheEntry.self, from: data)
        } catch {
            Self.log.error(
                "DiskStyleCache: failed to decode cache entry for \(pageId, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            removeCacheFile(at: url, reason: "corrupt cache entry for \(pageId)")
            return nil
        }

        guard entry.bodyHash == Self.bodyHash(currentBodyText) else {
            removeCacheFile(at: url, reason: "stale cache entry for \(pageId)")
            return nil
        }
        return entry
    }

    // MARK: - Eviction

    func evictIfNeeded() {
        let fm = FileManager.default
        let files: [URL]
        do {
            files = try fm.contentsOfDirectory(
                at: cacheDir,
                includingPropertiesForKeys: [.contentModificationDateKey]
            )
        } catch {
            Self.log.error(
                "DiskStyleCache: failed to enumerate cache directory: \(error.localizedDescription, privacy: .public)"
            )
            return
        }
        guard files.count > maxFiles else { return }

        let sorted = files.sorted { a, b in
            let dateA = modificationDate(for: a)
            let dateB = modificationDate(for: b)
            return dateA < dateB
        }
        for file in sorted.prefix(files.count - maxFiles) {
            removeCacheFile(at: file, reason: "cache eviction")
        }
    }

    func clearAll() {
        let fm = FileManager.default
        let files: [URL]
        do {
            files = try fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)
        } catch {
            Self.log.error(
                "DiskStyleCache: failed to enumerate cache directory for clearAll: \(error.localizedDescription, privacy: .public)"
            )
            return
        }
        for file in files {
            removeCacheFile(at: file, reason: "clearAll")
        }
    }

    // MARK: - Hashing

    private nonisolated static func bodyHash(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    private func modificationDate(for url: URL) -> Date {
        do {
            return try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
        } catch {
            Self.log.error(
                "DiskStyleCache: failed to read modification date for \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return .distantPast
        }
    }

    private func removeCacheFile(at url: URL, reason: String) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            Self.log.error(
                "DiskStyleCache: failed to remove \(reason, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
