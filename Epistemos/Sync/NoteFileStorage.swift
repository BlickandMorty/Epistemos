import AppKit
import CryptoKit
import Foundation
import os
#if canImport(epistemos_coreFFI)
import epistemos_coreFFI
#endif

/// Serializes all note file mutations through a single dispatch queue.
/// Sendable: all fields are immutable (`let`). The queue itself is thread-safe.
final class NoteFileMutationQueue: Sendable {
    private let queue: DispatchQueue
    private let queueKey = DispatchSpecificKey<UInt8>()
    private let queueToken: UInt8 = 1

    nonisolated init(label: String = "com.epistemos.NoteFileStorage.mutation") {
        let queue = DispatchQueue(label: label, qos: .utility)
        queue.setSpecific(key: queueKey, value: queueToken)
        self.queue = queue
    }

    nonisolated func performSync<T>(_ operation: () -> T) -> T {
        if DispatchQueue.getSpecific(key: queueKey) == queueToken {
            return operation()
        } else {
            return queue.sync(execute: operation)
        }
    }

    nonisolated func performAsync<T: Sendable>(_ operation: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: operation())
            }
        }
    }
}

private enum EpistemosCoreIntegrityBridge {
    private nonisolated static let log = Logger(subsystem: "com.epistemos", category: "NoteFileStorageBridge")
    private enum BridgeError: Error {
        case unavailable(String)
        case rustError(String)
        case rustPanic(String)
        case unexpectedCallStatus(Int8)
    }

    private nonisolated static let callSuccess: Int8 = 0
    private nonisolated static let callError: Int8 = 1
    private nonisolated static let callUnexpectedError: Int8 = 2
    private nonisolated static let bindingsContractVersion: UInt32 = 26

    private nonisolated static let initializationFailure: String? = {
#if canImport(epistemos_coreFFI)
        guard ffi_epistemos_core_uniffi_contract_version() == bindingsContractVersion else {
            return "UniFFI contract version mismatch"
        }
        guard uniffi_epistemos_core_checksum_func_content_hash_bytes() == 21588,
              uniffi_epistemos_core_checksum_func_full_sync_fd() == 54082,
              uniffi_epistemos_core_checksum_func_verify_content_hash() == 64084 else {
            return "UniFFI API checksum mismatch"
        }
        return nil
#else
        return "epistemos_coreFFI module unavailable"
#endif
    }()

    private nonisolated static func makeCallStatus() -> RustCallStatus {
        RustCallStatus(
            code: callSuccess,
            errorBuf: RustBuffer(capacity: 0, len: 0, data: nil)
        )
    }

    private nonisolated static func ensureInitialized() throws {
        if let initializationFailure {
            throw BridgeError.unavailable(initializationFailure)
        }
    }

    private nonisolated static func withRustCall<T>(
        _ callback: (UnsafeMutablePointer<RustCallStatus>) -> T
    ) throws -> T {
        try ensureInitialized()
        var callStatus = makeCallStatus()
        let result = callback(&callStatus)
        try checkCallStatus(callStatus)
        return result
    }

    private nonisolated static func checkCallStatus(_ callStatus: RustCallStatus) throws {
        switch callStatus.code {
        case callSuccess:
            return
        case callError:
            let message = takeRustString(callStatus.errorBuf)
            throw BridgeError.rustError(message.isEmpty ? "Rust error" : message)
        case callUnexpectedError:
            let message = takeRustString(callStatus.errorBuf)
            throw BridgeError.rustPanic(message.isEmpty ? "Rust panic" : message)
        default:
            freeRustBuffer(callStatus.errorBuf)
            throw BridgeError.unexpectedCallStatus(callStatus.code)
        }
    }

    private nonisolated static func takeRustString(_ rustBuffer: RustBuffer) -> String {
        defer { freeRustBuffer(rustBuffer) }
        guard let data = rustBuffer.data, rustBuffer.len > 0 else {
            return ""
        }
        let bytes = UnsafeBufferPointer(start: data, count: Int(rustBuffer.len))
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }

    private nonisolated static func freeRustBuffer(_ rustBuffer: RustBuffer) {
#if canImport(epistemos_coreFFI)
        var status = makeCallStatus()
        ffi_epistemos_core_rustbuffer_free(rustBuffer, &status)
#endif
    }

    private nonisolated static func rustBuffer(fromRawBytes data: Data) throws -> RustBuffer {
        try data.withUnsafeBytes { rawBytes in
            let bytes = rawBytes.bindMemory(to: UInt8.self)
            let foreignBytes = ForeignBytes(
                len: Int32(bytes.count),
                data: bytes.baseAddress
            )
            return try withRustCall { status in
                ffi_epistemos_core_rustbuffer_from_bytes(foreignBytes, status)
            }
        }
    }

    private nonisolated static func rustBuffer(fromByteSequence data: Data) throws -> RustBuffer {
        var serialized = [UInt8]()
        serialized.reserveCapacity(MemoryLayout<Int32>.size + data.count)
        var count = Int32(data.count).bigEndian
        withUnsafeBytes(of: &count) { serialized.append(contentsOf: $0) }
        serialized.append(contentsOf: data)
        return try rustBuffer(fromRawBytes: Data(serialized))
    }

    private nonisolated static func rustBuffer(from string: String) throws -> RustBuffer {
        try rustBuffer(fromRawBytes: Data(string.utf8))
    }

    nonisolated static func computeContentHashBytes(_ data: Data) -> String? {
        do {
            let content = try rustBuffer(fromByteSequence: data)
            let hashBuffer = try withRustCall { status in
                uniffi_epistemos_core_fn_func_content_hash_bytes(content, status)
            }
            return takeRustString(hashBuffer)
        } catch {
            log.error("content_hash_bytes bridge failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    nonisolated static func verifyContentHashBytes(_ data: Data, expectedHash: String) -> Bool {
        do {
            let content = try rustBuffer(fromByteSequence: data)
            let expected = try rustBuffer(from: expectedHash)
            let result = try withRustCall { status in
                uniffi_epistemos_core_fn_func_verify_content_hash(content, expected, status)
            }
            return result != 0
        } catch {
            log.error("verify_content_hash bridge failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    nonisolated static func sanitizeAndNormalizeText(_ value: String) -> String? {
        do {
#if canImport(epistemos_coreFFI)
            try ensureInitialized()
            return try sanitizeAndNormalize(input: value)
#else
            throw BridgeError.unavailable("epistemos_coreFFI module unavailable")
#endif
        } catch {
            log.error("sanitize_and_normalize bridge failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    nonisolated static func performFullSync(fd: Int32) -> Bool {
        do {
            let result = try withRustCall { status in
                uniffi_epistemos_core_fn_func_full_sync_fd(fd, status)
            }
            return result == 0
        } catch {
            log.error("full_sync_fd bridge failed: \(String(describing: error), privacy: .public)")
            return false
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
    private nonisolated static let pendingBodyQueue = DispatchQueue(label: "com.epistemos.NoteFileStorage.pending")
    private nonisolated static let storageOverrideQueue = DispatchQueue(label: "com.epistemos.NoteFileStorage.override")
    private nonisolated static let storageOverrideScope = DispatchSemaphore(value: 1)
    private nonisolated(unsafe) static var storageDirectoryOverride: URL?
    private nonisolated(unsafe) static var pendingBodies: [String: String] = [:]
    private nonisolated static let blake3HashPrefix = "blake3:"
    private nonisolated static let contentHashXAttrName = "com.epistemos.content_hash"

    private nonisolated static func bodyURL(pageId: String) -> URL {
        bodyURL(pageId: pageId, in: storageDirectory())
    }

    private nonisolated static func bodyURL(pageId: String, in directory: URL) -> URL {
        directory.appendingPathComponent("\(pageId).md")
    }

    private nonisolated static func hashURL(pageId: String) -> URL {
        integrityURL(pageId: pageId, in: storageDirectory())
    }

    private nonisolated static func integrityURL(pageId: String, in directory: URL) -> URL {
        directory.appendingPathComponent("\(pageId).integrity")
    }

    private nonisolated static func legacyIntegrityURL(pageId: String, in directory: URL) -> URL {
        directory.appendingPathComponent("\(pageId).blake3")
    }

    private nonisolated static func legacyRichTextURL(pageId: String) -> URL {
        storageDirectory().appendingPathComponent("\(pageId).rtfd")
    }

    private nonisolated static func pendingBodyKey(pageId: String, directory: URL) -> String {
        "\(directory.standardizedFileURL.path)\u{1F}\(pageId)"
    }

    private nonisolated static func quarantineDirectory(in directory: URL) -> URL {
        directory.appendingPathComponent(".quarantine", isDirectory: true)
    }

    private nonisolated static func managedBodyPageId(for url: URL) -> String? {
        let ext = url.pathExtension.lowercased()
        guard ext == "md" || ext == "rtfd" else { return nil }
        let pageId = url.deletingPathExtension().lastPathComponent
        return isValidPageId(pageId) ? pageId : nil
    }

    private nonisolated static func isMissingFileError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain,
           nsError.code == CocoaError.fileNoSuchFile.rawValue
            || nsError.code == CocoaError.fileReadNoSuchFile.rawValue {
            return true
        }
        if nsError.domain == NSPOSIXErrorDomain, nsError.code == ENOENT {
            return true
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isMissingFileError(underlying)
        }
        return false
    }

    private nonisolated static func createDirectoryIfNeeded(_ url: URL, label: String) {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create \(label, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private nonisolated static func readTextIfPresent(from url: URL, label: String) -> String? {
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            guard !isMissingFileError(error) else { return nil }
            logger.error("Failed to read \(label, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private nonisolated static func readDataIfPresent(
        from url: URL,
        options: Data.ReadingOptions = [],
        label: String
    ) -> Data? {
        do {
            return try Data(contentsOf: url, options: options)
        } catch {
            guard !isMissingFileError(error) else { return nil }
            logger.error("Failed to read \(label, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private nonisolated static func directoryContentsIfPresent(
        at url: URL,
        options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles],
        label: String
    ) -> [URL] {
        do {
            return try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: options
            )
        } catch {
            guard !isMissingFileError(error) else { return [] }
            logger.error("Failed to enumerate \(label, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private nonisolated static func removeItemIfPresent(at url: URL, label: String) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            guard !isMissingFileError(error) else { return }
            logger.error("Failed to remove \(label, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private nonisolated static func closeFileHandle(_ handle: FileHandle, label: String) {
        do {
            try handle.close()
        } catch {
            logger.error("Failed to close \(label, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private nonisolated static func integrityArtifactURLs(pageId: String, in directory: URL) -> [URL] {
        [
            integrityURL(pageId: pageId, in: directory),
            legacyIntegrityURL(pageId: pageId, in: directory),
        ]
    }

    private nonisolated static func legacyIntegrityHash(for content: String) -> String {
        let digest = SHA256.hash(data: Data(content.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private nonisolated static func normalizedStorageContent(_ content: String, pageId: String) -> String? {
        guard !content.isEmpty else { return "" }
        guard let normalized = EpistemosCoreIntegrityBridge.sanitizeAndNormalizeText(content),
              !normalized.isEmpty else {
            logger.error("Rejected unsafe note body content for \(pageId, privacy: .private)")
            return nil
        }
        return normalized
    }

    private nonisolated static func integrityToken(for data: Data) -> String {
        let hash = EpistemosCoreIntegrityBridge.computeContentHashBytes(data) ?? ""
        return "\(blake3HashPrefix)\(hash)"
    }

    private nonisolated static func storedIntegrityReference(from url: URL) -> String? {
        guard let raw = readTextIfPresent(from: url, label: url.lastPathComponent) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private nonisolated static func storedIntegrityXAttr(at bodyURL: URL) -> String? {
        let path = bodyURL.path
        return path.withCString { rawPath in
            let size = getxattr(rawPath, contentHashXAttrName, nil, 0, 0, 0)
            guard size > 0 else { return nil }
            var buffer = [UInt8](repeating: 0, count: Int(size))
            let read = getxattr(rawPath, contentHashXAttrName, &buffer, buffer.count, 0, 0)
            guard read >= 0 else { return nil }
            let value = String(bytes: buffer.prefix(Int(read)), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let value, !value.isEmpty else { return nil }
            return value
        }
    }

    private nonisolated static func integrityReferenceMatches(
        _ reference: String,
        data: Data,
        decodedText: String
    ) -> Bool {
        if reference.hasPrefix(blake3HashPrefix),
           let expectedHash = reference.split(separator: ":", maxSplits: 1).last {
            return EpistemosCoreIntegrityBridge.verifyContentHashBytes(data, expectedHash: String(expectedHash))
        }
        return reference == legacyIntegrityHash(for: decodedText)
    }

    @discardableResult
    private nonisolated static func quarantineManagedFiles(
        pageId: String,
        reason: String,
        in directory: URL
    ) -> Bool {
        let quarantineRoot = quarantineDirectory(in: directory)
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let quarantineURL = quarantineRoot.appendingPathComponent(
            "\(pageId)-\(timestamp)-\(UUID().uuidString)",
            isDirectory: true
        )

        do {
            try FileManager.default.createDirectory(at: quarantineURL, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create quarantine directory for \(pageId, privacy: .private): \(error.localizedDescription, privacy: .public)")
            return false
        }

        let managedFiles = [
            bodyURL(pageId: pageId, in: directory),
            integrityURL(pageId: pageId, in: directory),
            legacyIntegrityURL(pageId: pageId, in: directory),
        ]

        var movedAnyFile = false
        for sourceURL in managedFiles where FileManager.default.fileExists(atPath: sourceURL.path) {
            let destinationURL = quarantineURL.appendingPathComponent(sourceURL.lastPathComponent, isDirectory: false)
            do {
                try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
                movedAnyFile = true
            } catch {
                logger.error(
                    "Failed to quarantine \(sourceURL.lastPathComponent, privacy: .public) for \(pageId, privacy: .private): \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        let reasonURL = quarantineURL.appendingPathComponent("reason.txt", isDirectory: false)
        do {
            try reason.write(to: reasonURL, atomically: true, encoding: .utf8)
        } catch {
            logger.error(
                "Failed to persist quarantine reason for \(pageId, privacy: .private): \(error.localizedDescription, privacy: .public)"
            )
        }

        if movedAnyFile {
            logger.error(
                "Quarantined note body for \(pageId, privacy: .private) at \(quarantineURL.path, privacy: .public) because \(reason, privacy: .public)"
            )
        }
        return movedAnyFile
    }

    private nonisolated static func verifyOrBackfillIntegrityHash(
        for data: Data,
        decodedText: String,
        pageId: String,
        hashFileURL: URL,
        directory: URL
    ) -> Bool {
        let bodyFileURL = bodyURL(pageId: pageId, in: directory)
        let normalizedToken = integrityToken(for: data)
        let storedSidecar = storedIntegrityReference(from: hashFileURL)
        let storedXAttr = storedIntegrityXAttr(at: bodyFileURL)
        let sidecarValid = storedSidecar.map { integrityReferenceMatches($0, data: data, decodedText: decodedText) }
        let xattrValid = storedXAttr.map { integrityReferenceMatches($0, data: data, decodedText: decodedText) }

        let needsRepair: Bool = {
            switch (sidecarValid, xattrValid) {
            case (.some(false), .some(false)),
                 (.some(false), nil),
                 (nil, .some(false)):
                return false
            default:
                return storedSidecar != normalizedToken || storedXAttr != normalizedToken
            }
        }()

        switch (sidecarValid, xattrValid) {
        case (.some(false), .some(false)),
             (.some(false), nil),
             (nil, .some(false)):
            mutationQueue.performSync {
                _ = quarantineManagedFiles(
                    pageId: pageId,
                    reason: "Neither integrity reference matches the on-disk note body",
                    in: directory
                )
            }
            return false
        case (.some(true), .some(true)),
             (.some(true), .some(false)),
             (.some(false), .some(true)),
             (.some(true), nil),
             (nil, .some(true)),
             (nil, nil):
            if needsRepair {
                var repaired = false
                mutationQueue.performSync {
                    repaired = persistHash(normalizedToken, pageId: pageId, directory: directory)
                }
                if !repaired {
                    logger.error("Failed to repair integrity references for \(pageId, privacy: .private)")
                    return false
                }
            }
            return true
        }
    }

    @discardableResult
    private nonisolated static func persistBody(_ content: String, to url: URL, pageId: String) -> Bool {
        atomicWriteUTF8(content, to: url, itemLabel: pageId)
    }

    @discardableResult
    private nonisolated static func persistStagedBody(
        _ stagedContent: String,
        pageId: String,
        url: URL,
        directory: URL
    ) -> Bool {
        guard let normalizedContent = normalizedStorageContent(stagedContent, pageId: pageId) else {
            return false
        }
        let data = Data(normalizedContent.utf8)
        let hash = integrityToken(for: data)
        guard persistBody(normalizedContent, to: url, pageId: pageId) else {
            return false
        }
        guard persistHash(hash, pageId: pageId, directory: directory) else {
            logger.error("Failed to persist integrity hash for \(pageId, privacy: .private)")
            for url in integrityArtifactURLs(pageId: pageId, in: directory) {
                removeItemIfPresent(at: url, label: url.lastPathComponent)
            }
            return false
        }
        return true
    }

    @discardableResult
    private nonisolated static func persistHash(_ hash: String, pageId: String, directory: URL) -> Bool {
        let primaryURL = integrityURL(pageId: pageId, in: directory)
        guard atomicWriteUTF8(hash, to: primaryURL, itemLabel: "\(pageId).integrity") else {
            return false
        }
        persistHashXAttr(hash, bodyURL: bodyURL(pageId: pageId, in: directory))
        let legacyURL = legacyIntegrityURL(pageId: pageId, in: directory)
        if FileManager.default.fileExists(atPath: legacyURL.path) {
            removeItemIfPresent(at: legacyURL, label: legacyURL.lastPathComponent)
        }
        return true
    }

    private nonisolated static func persistHashXAttr(_ hash: String, bodyURL: URL) {
        let bodyPath = bodyURL.path
        let data = Data(hash.utf8)
        let result = bodyPath.withCString { rawPath in
            data.withUnsafeBytes { bytes in
                Darwin.setxattr(rawPath, contentHashXAttrName, bytes.baseAddress, bytes.count, 0, 0)
            }
        }
        if result != 0 {
            logger.error("Failed to persist integrity xattr for \(bodyURL.lastPathComponent, privacy: .public)")
        }
    }

    private nonisolated static func removeHashXAttr(pageId: String, in directory: URL) {
        let bodyPath = directory.appendingPathComponent("\(pageId).md").path
        let result = bodyPath.withCString { rawPath in
            Darwin.removexattr(rawPath, contentHashXAttrName, 0)
        }
        if result != 0 && errno != ENOATTR && errno != ENOENT {
            logger.error("Failed to remove integrity xattr for \(pageId, privacy: .private)")
        }
    }

    @discardableResult
    nonisolated static func writeTextAtomically(_ content: String, to url: URL, itemLabel: String) -> Bool {
        atomicWriteUTF8(content, to: url, itemLabel: itemLabel)
    }

    @discardableResult
    private nonisolated static func atomicWriteUTF8(_ content: String, to url: URL, itemLabel: String) -> Bool {
        guard let data = content.data(using: .utf8) else {
            logger.error("Failed to encode UTF-8 data for \(itemLabel)")
            return false
        }

        let dir = url.deletingLastPathComponent()
        let tmpName = ".\(url.lastPathComponent).tmp.\(ProcessInfo.processInfo.processIdentifier)"
        let tmpURL = dir.appendingPathComponent(tmpName)

        do {
            // Step 1: Write to temp file in the SAME directory (same APFS volume).
            try data.write(to: tmpURL, options: [])
        } catch {
            logger.error("Failed to create temp file for \(itemLabel): \(error.localizedDescription)")
            return false
        }

        // Step 2: F_FULLFSYNC the temp file — data is now on stable storage.
        // Fail-closed: if we cannot durably persist, abort the write.
        do {
            let fh = try FileHandle(forWritingTo: tmpURL)
            guard Self.performFullSync(fh.fileDescriptor) else {
                closeFileHandle(fh, label: tmpURL.lastPathComponent)
                removeItemIfPresent(at: tmpURL, label: tmpURL.lastPathComponent)
                logger.error("F_FULLFSYNC failed for temp file — aborting write for \(itemLabel)")
                return false
            }
            closeFileHandle(fh, label: tmpURL.lastPathComponent)
        } catch {
            removeItemIfPresent(at: tmpURL, label: tmpURL.lastPathComponent)
            logger.error("Failed to sync temp file for \(itemLabel): \(error.localizedDescription)")
            return false
        }

        // Step 3 (file handle closed above) + Step 4: Atomic rename.
        // POSIX rename() overwrites the destination atomically — no delete-then-move.
        let result = tmpURL.path.withCString { src in
            url.path.withCString { dst in
                Darwin.rename(src, dst)
            }
        }
        if result != 0 {
            let err = String(cString: strerror(errno))
            logger.error("Atomic rename failed for \(itemLabel): \(err)")
            removeItemIfPresent(at: tmpURL, label: tmpURL.lastPathComponent)
            return false
        }

        // Step 5: F_FULLFSYNC the parent directory — persists the directory entry.
        // Without this, a crash after rename can leave the entry unflushed.
        let dirFD = open(dir.path, O_RDONLY)
        if dirFD >= 0 {
            let didSyncDirectory = Self.performFullSync(dirFD)
            close(dirFD)
            guard didSyncDirectory else {
                logger.error("F_FULLFSYNC failed for parent directory of \(itemLabel)")
                return false
            }
        } else {
            logger.error("Failed to open parent directory for \(itemLabel)")
            return false
        }

        return true
    }

    /// F_FULLFSYNC on a file descriptor — the ONLY durable flush on macOS.
    /// fsync() only flushes the kernel page cache, NOT the drive's write cache.
    /// F_FULLFSYNC (fcntl 51) commands the drive to flush to stable storage.
    /// No fallback to fsync — if F_FULLFSYNC fails, the caller must handle it.
    /// Zero-corruption spec §1.1.
    @discardableResult
    nonisolated static func performFullSync(_ fd: Int32) -> Bool {
        EpistemosCoreIntegrityBridge.performFullSync(fd: fd)
    }

    nonisolated static func integrityTokenForTesting(_ data: Data) -> String {
        integrityToken(for: data)
    }

    private nonisolated static func migrateLegacyRichTextBody(pageId: String) -> String {
        let url = legacyRichTextURL(pageId: pageId)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return ""
        }
        let content: NSAttributedString
        do {
            content = try NSAttributedString(url: url, options: [:], documentAttributes: nil)
        } catch {
            logger.error("Failed to load legacy rich text for \(pageId, privacy: .private): \(error.localizedDescription, privacy: .public)")
            return ""
        }

        let body = content.string
        guard let normalizedBody = normalizedStorageContent(body, pageId: pageId) else {
            return ""
        }
        let directory = storageDirectory()
        var didPersist = false
        mutationQueue.performSync {
            guard persistBody(normalizedBody, to: bodyURL(pageId: pageId, in: directory), pageId: pageId) else {
                return
            }
            guard persistHash(
                integrityToken(for: Data(normalizedBody.utf8)),
                pageId: pageId,
                directory: directory
            ) else {
                removeManagedFiles(pageId: pageId, in: directory)
                return
            }
            didPersist = true
        }
        guard didPersist else { return "" }

        removeItemIfPresent(at: url, label: url.lastPathComponent)
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
        let appSupport = FoundationSafety.userApplicationSupportDirectory(fileManager: fm)
        let dir = appSupport.appendingPathComponent("Epistemos/note-bodies", isDirectory: true)
        createDirectoryIfNeeded(dir, label: dir.path)
        return dir
    }()

    nonisolated static func setStorageDirectoryOverrideForTesting(_ url: URL?) {
        storageOverrideQueue.sync {
            storageDirectoryOverride = url
        }
        if let url {
            createDirectoryIfNeeded(url, label: url.path)
        }
    }

    private nonisolated static func currentStorageDirectoryOverride() -> URL? {
        storageOverrideQueue.sync { storageDirectoryOverride }
    }

    nonisolated static func withStorageDirectoryOverrideForTesting<T>(
        _ url: URL?,
        operation: () throws -> T
    ) rethrows -> T {
        if let url {
            createDirectoryIfNeeded(url, label: url.path)
        }
        storageOverrideScope.wait()
        let previousOverride = currentStorageDirectoryOverride()
        storageOverrideQueue.sync {
            storageDirectoryOverride = url
        }
        defer {
            storageOverrideQueue.sync {
                storageDirectoryOverride = previousOverride
            }
            storageOverrideScope.signal()
        }
        return try operation()
    }

    private nonisolated static func waitForStorageOverrideScope() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                storageOverrideScope.wait()
                continuation.resume()
            }
        }
    }

    @MainActor
    static func withStorageDirectoryOverrideForTesting<T>(
        _ url: URL?,
        operation: @MainActor @Sendable @escaping () async throws -> T
    ) async rethrows -> T {
        if let url {
            createDirectoryIfNeeded(url, label: url.path)
        }
        await waitForStorageOverrideScope()
        let previousOverride = currentStorageDirectoryOverride()
        storageOverrideQueue.sync {
            storageDirectoryOverride = url
        }
        defer {
            storageOverrideQueue.sync {
                storageDirectoryOverride = previousOverride
            }
            storageOverrideScope.signal()
        }
        return try await operation()
    }

    nonisolated static func storageDirectory() -> URL {
        let dir = currentStorageDirectoryOverride() ?? _storageDirectory
        createDirectoryIfNeeded(dir, label: dir.path)
        return dir
    }

    /// Read a note body from disk. Returns empty string if file doesn't exist or pageId is invalid.
    ///
    /// - Parameter mapped: When `true`, uses `mmap` via `Data(contentsOf:options:.mappedIfSafe)`.
    ///   The file bytes stay on disk and are paged in lazily by the kernel until the UTF-8 decode.
    ///   Use for bulk operations (indexing, hashing, search) where many files are read in a loop.
    ///   Falls back to normal read for small files or network filesystems.
    /// Read a note body from disk.
    /// - Parameter fast: When `true`, skips Rust FFI normalization and BLAKE3 hash
    ///   verification. Safe because all writes already normalize via `persistStagedBody`.
    ///   Use `fast: true` for UI-driven reads (editor, sidebar snippets) to avoid
    ///   blocking the main thread with 2-3s of FFI work.
    ///   Use `fast: false` for integrity-critical paths (sync, export, indexing).
    nonisolated static func readBody(pageId: String, mapped: Bool = false, fast: Bool = false) -> String {
        guard isValidPageId(pageId) else { return "" }
        let directory = storageDirectory()
        if let pending = pendingBody(for: pageId, directory: directory) {
            return pending
        }
        let url = bodyURL(pageId: pageId, in: directory)
        let options: Data.ReadingOptions = mapped ? .mappedIfSafe : []
        guard let data = readDataIfPresent(from: url, options: options, label: url.lastPathComponent),
              let text = FoundationSafety.decodedText(from: data) else {
            return migrateLegacyRichTextBody(pageId: pageId)
        }

        // Trust-on-Read: skip expensive Rust FFI (normalization + hash) for UI reads.
        // All writes go through persistStagedBody which normalizes before disk write.
        if fast {
            return text
        }

        guard let normalizedText = normalizedStorageContent(text, pageId: pageId) else {
            return ""
        }

        let hashFileURL = existingHashURL(pageId: pageId, in: directory)
        guard verifyOrBackfillIntegrityHash(
            for: data,
            decodedText: text,
            pageId: pageId,
            hashFileURL: hashFileURL,
            directory: directory
        ) else {
            return ""
        }

        return normalizedText
    }

    /// Read raw on-disk bytes for a note body without attempting UTF-8 decode.
    /// Used by legacy/corruption recovery tooling.
    nonisolated static func readRawBodyData(pageId: String, mapped: Bool = true) -> Data? {
        guard isValidPageId(pageId) else { return nil }
        let url = bodyURL(pageId: pageId, in: storageDirectory())
        let options: Data.ReadingOptions = mapped ? .mappedIfSafe : []
        return readDataIfPresent(from: url, options: options, label: url.lastPathComponent)
    }

    nonisolated static func bodyFileURL(pageId: String) -> URL? {
        guard isValidPageId(pageId) else { return nil }
        let url = bodyURL(pageId: pageId, in: storageDirectory())
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Read raw file data for a note body. Returns nil if file doesn't exist or pageId is invalid.
    /// Uses mmap by default — ideal for hashing and search indexing where
    /// you only need bytes, not a decoded String.
    /// - Parameter fast: When `true`, skips normalization and hash verification.
    nonisolated static func readBodyData(pageId: String, fast: Bool = false) -> Data? {
        guard isValidPageId(pageId) else { return nil }
        let directory = storageDirectory()
        let url = bodyURL(pageId: pageId, in: directory)
        guard let data = readDataIfPresent(from: url, options: .mappedIfSafe, label: url.lastPathComponent) else {
            return nil
        }

        // Trust-on-Read: skip FFI for UI-driven reads.
        if fast {
            return data
        }

        guard let text = FoundationSafety.decodedText(from: data) else {
            return nil
        }
        guard normalizedStorageContent(text, pageId: pageId) != nil else {
            return nil
        }
        let hashFileURL = existingHashURL(pageId: pageId, in: directory)
        guard verifyOrBackfillIntegrityHash(
            for: data,
            decodedText: text,
            pageId: pageId,
            hashFileURL: hashFileURL,
            directory: directory
        ) else {
            return nil
        }
        return data
    }

    /// Write a note body to disk with an integrity hash sidecar.
    /// Zero-corruption spec §2.3: every byte written is checksummed.
    nonisolated static func writeBody(pageId: String, content: String) {
        let directory = storageDirectory()
        guard let stagedContent = stageBodyForImmediateRead(pageId: pageId, content: content, directory: directory) else {
            return
        }
        let url = bodyURL(pageId: pageId, in: directory)
        let didPersist = mutationQueue.performSync {
            persistStagedBody(stagedContent, pageId: pageId, url: url, directory: directory)
        }
        if didPersist {
            clearPendingBody(pageId: pageId, directory: directory, matching: stagedContent)
        }
    }

    /// Write a note body off the caller actor while preserving global file mutation order.
    nonisolated static func writeBodyAsync(pageId: String, content: String) async {
        let directory = storageDirectory()
        guard let stagedContent = stageBodyForImmediateRead(pageId: pageId, content: content, directory: directory) else {
            return
        }
        await persistStagedBodyAsync(stagedContent, pageId: pageId, directory: directory)
    }

    /// Stage a note body for immediate reads and durably persist it in the background.
    /// Use this from non-async UI flush paths instead of wrapping `writeBodyAsync` in a new Task,
    /// which can delay the staging step long enough for the next reader to observe stale content.
    @discardableResult
    nonisolated static func scheduleWriteBody(pageId: String, content: String) -> Task<Bool, Never>? {
        let directory = storageDirectory()
        guard let stagedContent = stageBodyForImmediateRead(pageId: pageId, content: content, directory: directory) else {
            return nil
        }
        return Task.detached(priority: .utility) {
            await persistStagedBodyAsync(stagedContent, pageId: pageId, directory: directory)
        }
    }

    /// Persist a staged in-memory body to disk when a background save/export task needs
    /// the normalized durable version before continuing.
    @discardableResult
    nonisolated static func flushPendingBodyToDisk(pageId: String) async -> Bool {
        let directory = storageDirectory()
        guard isValidPageId(pageId),
              let stagedContent = pendingBody(for: pageId, directory: directory) else {
            return false
        }
        return await persistStagedBodyAsync(stagedContent, pageId: pageId, directory: directory)
    }

    /// Delete a note body file.
    nonisolated static func deleteBody(pageId: String) {
        guard isValidPageId(pageId) else { return }
        let directory = storageDirectory()
        clearPendingBody(pageId: pageId, directory: directory)
        mutationQueue.performSync {
            removeManagedFiles(pageId: pageId, in: directory)
        }
    }

    /// Check if a body file exists on disk.
    nonisolated static func bodyExists(pageId: String) -> Bool {
        guard isValidPageId(pageId) else { return false }
        let url = bodyURL(pageId: pageId, in: storageDirectory())
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
            let contents = directoryContentsIfPresent(
                at: storageURL,
                label: storageURL.path
            )
            guard !contents.isEmpty else {
                return
            }

            for fileURL in contents {
                guard let pageId = managedBodyPageId(for: fileURL) else { continue }
                guard !validIds.contains(pageId) else { continue }
                do {
                    try FileManager.default.removeItem(at: fileURL)
                    for sidecarURL in integrityArtifactURLs(pageId: pageId, in: storageURL) {
                        removeItemIfPresent(at: sidecarURL, label: sidecarURL.lastPathComponent)
                    }
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
        let contents = directoryContentsIfPresent(at: storageURL, label: storageURL.path)

        return contents.compactMap(managedBodyPageId(for:)).sorted()
    }

    nonisolated static func managedBodyCount(in directory: URL? = nil) -> Int {
        managedBodyPageIds(in: directory).count
    }

    nonisolated static func quarantineDirectoryURLForTesting(in directory: URL? = nil) -> URL {
        quarantineDirectory(in: directory ?? storageDirectory())
    }

    @discardableResult
    nonisolated static func removeAllManagedBodies(in directory: URL? = nil) -> [String] {
        let storageURL = directory ?? storageDirectory()
        var removed: [String] = []

        mutationQueue.performSync {
            let contents = directoryContentsIfPresent(
                at: storageURL,
                label: storageURL.path
            )
            guard !contents.isEmpty else {
                return
            }

            for fileURL in contents {
                guard let pageId = managedBodyPageId(for: fileURL) else { continue }
                do {
                    try FileManager.default.removeItem(at: fileURL)
                    for sidecarURL in integrityArtifactURLs(pageId: pageId, in: storageURL) {
                        removeItemIfPresent(at: sidecarURL, label: sidecarURL.lastPathComponent)
                    }
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

    private nonisolated static func removeManagedFiles(pageId: String, in directory: URL) {
        removeHashXAttr(pageId: pageId, in: directory)
        let bodyFileURL = directory.appendingPathComponent("\(pageId).md")
        removeItemIfPresent(at: bodyFileURL, label: bodyFileURL.lastPathComponent)
        for url in integrityArtifactURLs(pageId: pageId, in: directory) {
            removeItemIfPresent(at: url, label: url.lastPathComponent)
        }
    }

    private nonisolated static func existingHashURL(pageId: String, in directory: URL) -> URL {
        let primaryURL = integrityURL(pageId: pageId, in: directory)
        if FileManager.default.fileExists(atPath: primaryURL.path) {
            return primaryURL
        }
        let legacyURL = legacyIntegrityURL(pageId: pageId, in: directory)
        if FileManager.default.fileExists(atPath: legacyURL.path) {
            return legacyURL
        }
        return primaryURL
    }

    // MARK: - External Body Change Notification

    /// Posted when note body is changed outside the editor (restore-to-version, vault sync, etc.).
    /// `userInfo["pageId"]` contains the affected page ID as `String`.
    /// ProseEditorView listens for this to reload from disk without relying on `page.body` (which
    /// is always "" for migrated notes and therefore useless as a change signal).
    nonisolated static let pageBodyDidChange = Notification.Name("EpistemosPageBodyDidChange")

    /// Asks any open editor for the given page to stage its in-memory edits immediately
    /// before a downstream reader (save/export/transclusion) continues.
    nonisolated static let pageBodyWillRead = Notification.Name("EpistemosPageBodyWillRead")

    /// Post the body-changed notification on the main thread.
    /// Call after `saveBody()` completes in any external mutation path (restore, sync, etc.).
    @MainActor static func notifyBodyChanged(pageId: String) {
        NotificationCenter.default.post(name: pageBodyDidChange, object: nil, userInfo: ["pageId": pageId])
    }

    /// Ask any open editor for this page to flush pending edits.
    /// Live editor text becomes readable immediately via the pending-body cache while the
    /// background save/export task decides when to durably persist it.
    @MainActor static func requestFlush(pageId: String) {
        if let liveBody = NoteWindowManager.shared.editorBody(for: pageId),
           stageBodyForImmediateRead(pageId: pageId, content: liveBody) != nil {
        }
        NotificationCenter.default.post(name: pageBodyWillRead, object: nil, userInfo: ["pageId": pageId])
    }

    @discardableResult
    nonisolated static func stageBodyForImmediateRead(
        pageId: String,
        content: String,
        directory: URL? = nil
    ) -> String? {
        guard isValidPageId(pageId) else {
            logger.error("Invalid pageId rejected in writeBody: \(pageId.prefix(20))")
            return nil
        }
        setPendingBody(content, for: pageId, directory: directory ?? storageDirectory())
        return content
    }

    private nonisolated static func pendingBody(for pageId: String, directory: URL) -> String? {
        let key = pendingBodyKey(pageId: pageId, directory: directory)
        return pendingBodyQueue.sync { pendingBodies[key] }
    }

    private nonisolated static func setPendingBody(_ body: String, for pageId: String, directory: URL) {
        let key = pendingBodyKey(pageId: pageId, directory: directory)
        pendingBodyQueue.sync {
            pendingBodies[key] = body
        }
    }

    private nonisolated static func clearPendingBody(
        pageId: String,
        directory: URL,
        matching expectedBody: String? = nil
    ) {
        let key = pendingBodyKey(pageId: pageId, directory: directory)
        pendingBodyQueue.sync {
            guard let expectedBody else {
                pendingBodies.removeValue(forKey: key)
                return
            }
            guard pendingBodies[key] == expectedBody else { return }
            pendingBodies.removeValue(forKey: key)
        }
    }

    @discardableResult
    private nonisolated static func persistStagedBodyAsync(
        _ stagedContent: String,
        pageId: String,
        directory: URL
    ) async -> Bool {
        let url = bodyURL(pageId: pageId, in: directory)
        let didPersist = await mutationQueue.performAsync {
            persistStagedBody(stagedContent, pageId: pageId, url: url, directory: directory)
        }
        if didPersist {
            clearPendingBody(pageId: pageId, directory: directory, matching: stagedContent)
        }
        return didPersist
    }
}
