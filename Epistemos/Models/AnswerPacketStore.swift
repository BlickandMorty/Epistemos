import Foundation

// SUBSTRATE Phase 2 (owner 2026-06-20, SUBSTRATE_BUILD_SEQUENCE): durable AnswerPacket persistence.
// Today AnswerPackets live only in `AnswerPacketEmitter.shared`'s in-memory ring, so a per-answer
// provenance receipt is lost on relaunch. This is the pure persistence PRIMITIVE — an append-only
// JSONL log (one packet per line) over the frozen AnswerPacket Codable schema (Phase 0). It is
// `nonisolated` so file IO runs OFF the MainActor (CLAUDE.md "never block @MainActor"), bounded
// (compact keeps the last N), and corruption-tolerant (a bad line is skipped, never crashes).
//
// The live `emit()` → `append` wiring is the deliberate follow-up slice; this primitive is unit-
// tested in isolation first (post-crash discipline: safe machinery now, production wiring later).
nonisolated public struct AnswerPacketStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Append one packet as a single JSON line. Creates the parent directory + file on first use.
    public func append(_ packet: AnswerPacket) throws {
        var line = try JSONEncoder().encode(packet)
        line.append(0x0A)  // '\n' — one packet per line
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
        } else {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try line.write(to: fileURL, options: .atomic)
        }
    }

    /// Load up to `limit` of the most recently persisted packets, MOST-RECENT-FIRST. A corrupt or
    /// partially-written line is skipped honestly (never throws on a single bad entry).
    public func loadRecent(limit: Int) throws -> [AnswerPacket] {
        guard limit > 0, let raw = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        let decoder = JSONDecoder()
        let tail = raw.split(separator: "\n", omittingEmptySubsequences: true).suffix(limit)
        let chronological = tail.compactMap { line in
            try? decoder.decode(AnswerPacket.self, from: Data(line.utf8))
        }
        return chronological.reversed()
    }

    /// Bound the log: rewrite the file to keep only the last `maxEntries` valid lines. The wiring
    /// calls this periodically so the append-only log never grows without limit.
    public func compact(maxEntries: Int) throws {
        guard maxEntries > 0, let raw = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: true)
        guard lines.count > maxEntries else { return }
        let kept = lines.suffix(maxEntries).joined(separator: "\n") + "\n"
        try kept.data(using: .utf8)?.write(to: fileURL, options: .atomic)
    }
}
