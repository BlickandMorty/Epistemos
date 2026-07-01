import Darwin
import Foundation

// SUBSTRATE Phase 2 (owner 2026-06-20, SUBSTRATE_BUILD_SEQUENCE): durable AnswerPacket persistence.
// Today AnswerPackets live only in `AnswerPacketEmitter.shared`'s in-memory ring, so a per-answer
// provenance receipt is lost on relaunch. This is the pure persistence PRIMITIVE — an append-only
// JSONL log (one packet per line) over the frozen AnswerPacket Codable schema (Phase 0). It is
// `nonisolated` so file IO runs OFF the MainActor (CLAUDE.md "never block @MainActor"), bounded
// (compact keeps the last N; reads are capped), regular-file/no-follow, and corruption-tolerant
// (a bad line is skipped, never crashes).
//
// The live `emit()` → `append` wiring is the deliberate follow-up slice; this primitive is unit-
// tested in isolation first (post-crash discipline: safe machinery now, production wiring later).
nonisolated public struct AnswerPacketStore: Sendable {
    public static let maxLogBytes = 8 * 1024 * 1024

    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Default durable log location shared by the emitter and read-only consumers.
    public static func defaultEpistemosStore() -> AnswerPacketStore? {
        guard let url = defaultEpistemosLogURL() else { return nil }
        return AnswerPacketStore(fileURL: url)
    }

    public static func defaultEpistemosLogURL() -> URL? {
        guard let dir = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        return dir
            .appendingPathComponent("Epistemos", isDirectory: true)
            .appendingPathComponent("answer_packets.jsonl")
    }

    /// Append one packet as a single JSON line. Creates the parent directory + file on first use.
    public func append(_ packet: AnswerPacket) throws {
        var line = try JSONEncoder().encode(packetWithHonestStoredLabel(packet))
        line.append(0x0A)  // '\n' — one packet per line
        guard line.count <= Self.maxLogBytes else {
            throw storeError("answer packet log exceeds the 8 MiB cap", errnoCode: EFBIG)
        }
        let handle = try openStoreFileForWriting(truncate: false, appendingBytes: line.count)
        defer { try? handle.close() }
        try handle.write(contentsOf: line)
    }

    /// Load up to `limit` of the most recently persisted packets, MOST-RECENT-FIRST. A corrupt or
    /// partially-written line is skipped honestly (never throws on a single bad entry).
    public func loadRecent(limit: Int) throws -> [AnswerPacket] {
        guard limit > 0,
              let raw = try readStoreFileText() else { return [] }
        let decoder = JSONDecoder()
        let chronological = raw.split(separator: "\n", omittingEmptySubsequences: true).compactMap { line -> AnswerPacket? in
            guard let packet = try? decoder.decode(AnswerPacket.self, from: Data(line.utf8)) else {
                return nil
            }
            return packetWithHonestStoredLabel(packet)
        }
        return chronological.suffix(limit).reversed()
    }

    /// Bound the log: rewrite the file to keep only the last `maxEntries` valid lines. The wiring
    /// calls this periodically so the append-only log never grows without limit.
    public func compact(maxEntries: Int) throws {
        guard maxEntries > 0,
              let raw = try readStoreFileText() else { return }
        let decoder = JSONDecoder()
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: true)
        let packets = lines.compactMap { line in
            try? decoder.decode(AnswerPacket.self, from: Data(line.utf8))
        }
        let keptPackets = packets.suffix(maxEntries)
        let normalizedPackets = keptPackets.map { packetWithHonestStoredLabel($0) }
        guard lines.count > maxEntries
            || lines.count != packets.count
            || Array(keptPackets) != normalizedPackets else { return }
        var kept = Data()
        let encoder = JSONEncoder()
        for packet in normalizedPackets {
            var line = try encoder.encode(packet)
            line.append(0x0A)
            guard kept.count <= Self.maxLogBytes - line.count else {
                throw storeError("answer packet log exceeds the 8 MiB cap", errnoCode: EFBIG)
            }
            kept.append(line)
        }
        let handle = try openStoreFileForWriting(truncate: true)
        defer { try? handle.close() }
        try handle.write(contentsOf: kept)
    }

    private func packetWithHonestStoredLabel(_ packet: AnswerPacket) -> AnswerPacket {
        var normalized = packet
        normalized.uiLabel = VRMLabel.honestLabel(for: normalized) ?? .default
        return normalized
    }

    private func readStoreFileText() throws -> String? {
        try validateStoreDirectoryPath()
        if (try? FileManager.default.destinationOfSymbolicLink(atPath: fileURL.path)) != nil {
            throw storeError("answer packet log is a symbolic link", errnoCode: ELOOP)
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        let fd = fileURL.path.withCString { path in
            open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard fd >= 0 else {
            let capturedErrno = errno
            if capturedErrno == ENOENT { return nil }
            throw storeError("could not open answer packet log", errnoCode: capturedErrno)
        }

        var fileStatus = stat()
        guard fstat(fd, &fileStatus) == 0 else {
            let capturedErrno = errno
            close(fd)
            throw storeError("could not inspect answer packet log", errnoCode: capturedErrno)
        }
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG else {
            close(fd)
            throw storeError("answer packet log is not a regular file", errnoCode: EFTYPE)
        }
        guard fileStatus.st_nlink == 1 else {
            close(fd)
            throw storeError("answer packet log is linked from another path", errnoCode: EMLINK)
        }
        guard fileStatus.st_size >= 0 else {
            close(fd)
            throw storeError("answer packet log exceeds the 8 MiB cap", errnoCode: EFBIG)
        }
        guard UInt64(fileStatus.st_size) <= UInt64(Self.maxLogBytes) else {
            close(fd)
            return nil
        }

        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        let data = try handle.readToEnd() ?? Data()
        guard data.count <= Self.maxLogBytes else {
            return nil
        }
        guard let raw = String(data: data, encoding: .utf8) else {
            throw storeError("answer packet log is not valid UTF-8", errnoCode: EILSEQ)
        }
        return raw
    }

    private func openStoreFileForWriting(
        truncate: Bool,
        appendingBytes: Int? = nil
    ) throws -> FileHandle {
        try validateStoreDirectoryPath()
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try validateStoreDirectoryPath()
        let flags = O_WRONLY | O_CREAT | O_NOFOLLOW | O_CLOEXEC | (truncate ? O_TRUNC : O_APPEND)
        let fd = fileURL.path.withCString { path in
            open(path, flags, mode_t(0o600))
        }
        guard fd >= 0 else {
            throw storeError("could not open answer packet log", errnoCode: errno)
        }

        var fileStatus = stat()
        guard fstat(fd, &fileStatus) == 0 else {
            let capturedErrno = errno
            close(fd)
            throw storeError("could not inspect answer packet log", errnoCode: capturedErrno)
        }
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG else {
            close(fd)
            throw storeError("answer packet log is not a regular file", errnoCode: EFTYPE)
        }
        guard fileStatus.st_nlink == 1 else {
            close(fd)
            throw storeError("answer packet log is linked from another path", errnoCode: EMLINK)
        }
        if !truncate, let appendingBytes {
            guard fileStatus.st_size >= 0 else {
                close(fd)
                throw storeError("answer packet log exceeds the 8 MiB cap", errnoCode: EFBIG)
            }
            let byteCount = UInt64(fileStatus.st_size)
            guard byteCount <= UInt64(Self.maxLogBytes),
                  UInt64(appendingBytes) <= UInt64(Self.maxLogBytes) - byteCount else {
                close(fd)
                throw storeError("answer packet log exceeds the 8 MiB cap", errnoCode: EFBIG)
            }
        }
        return FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    }

    private func validateStoreDirectoryPath() throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        if (try? FileManager.default.destinationOfSymbolicLink(atPath: directoryURL.path)) != nil {
            throw storeError("answer packet log directory is a symbolic link", errnoCode: ELOOP)
        }
    }

    private func storeError(_ prefix: String, errnoCode: Int32) -> NSError {
        let message = String(cString: strerror(errnoCode))
        return NSError(
            domain: "AnswerPacketStore",
            code: Int(errnoCode),
            userInfo: [NSLocalizedDescriptionKey: "\(prefix): \(message)"]
        )
    }
}
