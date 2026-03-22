import AppKit
import CryptoKit

// MARK: - DiskStyleCache
// Persists scroll position and selection per page to disk so they survive app restarts.
// Lightweight metadata only — the in-memory styled storages live in PageStoragePool.
//
// Lifecycle:
//   dismantleNSView → save scroll/selection + body hash
//   makeNSView      → on pool miss, check disk → restore scroll position
//   AppBootstrap    → evictIfNeeded (cap at 200 files)

@MainActor
final class DiskStyleCache {
    static let shared = DiskStyleCache()

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
        guard let appSupportBase = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else {
            // Fallback to temp directory if Application Support is unavailable
            cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("epistemos-style-cache", isDirectory: true)
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            return
        }
        let appSupport = appSupportBase.appendingPathComponent("Epistemos", isDirectory: true)
        cacheDir = appSupport.appendingPathComponent("style-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
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
        if let data = try? JSONEncoder().encode(entry) {
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: - Restore

    func restore(pageId: String, currentBodyText: String) -> CacheEntry? {
        let url = cacheDir.appendingPathComponent("\(pageId).json")
        guard let data = try? Data(contentsOf: url),
              let entry = try? JSONDecoder().decode(CacheEntry.self, from: data)
        else { return nil }
        guard entry.bodyHash == Self.bodyHash(currentBodyText) else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return entry
    }

    // MARK: - Eviction

    func evictIfNeeded() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: cacheDir, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        guard files.count > maxFiles else { return }

        let sorted = files.sorted { a, b in
            let dateA = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let dateB = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return dateA < dateB
        }
        for file in sorted.prefix(files.count - maxFiles) {
            try? fm.removeItem(at: file)
        }
    }

    func clearAll() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)
        else { return }
        for file in files {
            try? fm.removeItem(at: file)
        }
    }

    // MARK: - Hashing

    private nonisolated static func bodyHash(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}
