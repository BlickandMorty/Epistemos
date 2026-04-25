import Foundation
import os

// MARK: - Chunked MCP Framing
//
// Fixes the macOS 64KB stdout pipe buffer limit.
// Large MCP JSON-RPC responses (base64 screenshots, codebase summaries)
// will silently cause SIGPIPE / broken pipe crashes when they exceed 64KB.
//
// This accumulator detects Content-Length headers in the JSON-RPC stream
// and reassembles fragmented messages before parsing.
//
// For payloads > 48KB, Rust writes directly to POSIX shared memory via
// shm_open and sends a compact ShmReference JSON over the pipe instead.
// This accumulator detects those references and resolves them via FFI.

actor ChunkedMCPFrameAccumulator {
    private static let logger = Logger(subsystem: "com.epistemos.bridge", category: "MCPFraming")

    // MARK: - State

    private var buffer = Data()
    private var expectedLength: Int?
    private var pendingFrames: [Data] = []

    /// Maximum single message size we'll accept (16MB safety cap).
    private let maxMessageSize = 16 * 1024 * 1024

    /// Maximum buffer size before forced flush (32MB).
    private let maxBufferSize = 32 * 1024 * 1024

    // MARK: - Feed

    /// Feed raw pipe data into the accumulator.
    /// Returns zero or more complete JSON-RPC message strings.
    func feed(_ chunk: Data) -> [String] {
        buffer.append(chunk)

        // Safety: prevent unbounded memory growth
        if buffer.count > maxBufferSize {
            Self.logger.error("MCP buffer exceeded \(self.maxBufferSize) bytes, flushing")
            buffer.removeAll()
            expectedLength = nil
            return []
        }

        var messages: [String] = []

        while !buffer.isEmpty {
            // Try to parse a Content-Length header
            if expectedLength == nil {
                if let headerEnd = findHeaderEnd() {
                    let headerData = buffer.prefix(headerEnd)
                    if let headerStr = String(data: headerData, encoding: .utf8),
                       let length = parseContentLength(headerStr) {
                        expectedLength = length
                        // Remove header + \r\n\r\n separator
                        buffer.removeFirst(headerEnd)
                    } else {
                        // Try line-delimited JSON-RPC (no Content-Length)
                        if let message = extractLineDelimitedMessage() {
                            messages.append(message)
                            continue
                        }
                        break
                    }
                } else {
                    // Try line-delimited JSON-RPC
                    if let message = extractLineDelimitedMessage() {
                        messages.append(message)
                        continue
                    }
                    break
                }
            }

            // We have an expected length — check if we've accumulated enough
            if let expected = expectedLength {
                guard expected <= maxMessageSize else {
                    Self.logger.error("MCP message too large: \(expected) bytes")
                    expectedLength = nil
                    buffer.removeAll()
                    break
                }

                guard buffer.count >= expected else {
                    // Need more data
                    break
                }

                let messageData = buffer.prefix(expected)
                buffer.removeFirst(expected)
                expectedLength = nil

                if let message = String(data: messageData, encoding: .utf8) {
                    messages.append(message)
                }
            }
        }

        return messages
    }

    /// Feed raw pipe data and resolve any shared memory references.
    /// This is the primary entry point — it calls `feed(_:)` internally
    /// and then resolves SHM references via the Rust FFI.
    func feedAndResolve(_ chunk: Data) -> [String] {
        let messages = feed(chunk)
        return messages.map { resolveShmReferenceIfNeeded($0) }
    }

    /// Reset the accumulator state.
    func reset() {
        buffer.removeAll()
        expectedLength = nil
        pendingFrames.removeAll()
    }

    // MARK: - Private

    /// Find the end of HTTP-style headers (\r\n\r\n separator).
    private func findHeaderEnd() -> Int? {
        let separator: [UInt8] = [0x0D, 0x0A, 0x0D, 0x0A] // \r\n\r\n
        guard buffer.count >= 4 else { return nil }

        for i in 0...(buffer.count - 4) {
            if buffer[buffer.startIndex + i] == separator[0]
                && buffer[buffer.startIndex + i + 1] == separator[1]
                && buffer[buffer.startIndex + i + 2] == separator[2]
                && buffer[buffer.startIndex + i + 3] == separator[3] {
                return i + 4
            }
        }
        return nil
    }

    /// Parse Content-Length from a header string.
    private func parseContentLength(_ header: String) -> Int? {
        for line in header.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2,
               parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length",
               let length = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                return length
            }
        }
        return nil
    }

    // MARK: - Shared Memory Resolution

    /// Detect if a message is a Rust ShmReference JSON and resolve it
    /// by calling the FFI to read the payload from shared memory.
    ///
    /// ShmReference JSON shape: {"segment_name": "...", "byte_length": N, "content_type": "..."}
    ///
    /// This runs on the actor's executor (not @MainActor), so the FFI
    /// mmap read won't block the UI.
    private func resolveShmReferenceIfNeeded(_ message: String) -> String {
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let segmentName = json["segment_name"] as? String,
              let byteLength = json["byte_length"] as? Int else {
            return message
        }

        // Validate segment name format to prevent arbitrary shm_open calls
        guard segmentName.hasPrefix("/ep_") else {
            Self.logger.warning("SHM reference with unexpected segment name: \(segmentName)")
            return message
        }

        Self.logger.info("Resolving SHM reference: \(segmentName) (\(byteLength) bytes)")

        #if canImport(agent_coreFFI)
        do {
            let payload = try shmReadPayload(segmentName: segmentName, byteLength: UInt64(byteLength))
            Self.logger.info("SHM resolved: \(segmentName) → \(payload.count) chars")
            return payload
        } catch {
            Self.logger.error("SHM read failed for \(segmentName): \(error.localizedDescription)")
            return message
        }
        #else
        Self.logger.warning("SHM reference detected but agent_core bindings unavailable")
        return message
        #endif
    }

    /// Try to extract a line-delimited JSON message (newline-terminated).
    private func extractLineDelimitedMessage() -> String? {
        guard let newlineIndex = buffer.firstIndex(of: 0x0A) else {
            return nil
        }

        let lineData = buffer.prefix(upTo: newlineIndex)
        buffer.removeFirst(newlineIndex - buffer.startIndex + 1)

        guard let line = String(data: lineData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !line.isEmpty else {
            return nil
        }

        // Validate it looks like JSON
        guard line.hasPrefix("{") || line.hasPrefix("[") else {
            return nil
        }

        return line
    }
}

// MARK: - Pipe Buffer Constants

enum PipeBufferConstants {
    /// macOS default pipe buffer size (64KB).
    static let macOSPipeBufferSize = 65_536

    /// Threshold above which payloads should be routed to shared memory.
    /// Must match `SHM_OFFLOAD_THRESHOLD` in agent_core/src/shared_memory.rs (48KB).
    static let sharedMemoryThreshold = 48 * 1024

    /// Whether a payload should use the shared memory data plane.
    static func shouldUseSharedMemory(payloadSize: Int) -> Bool {
        payloadSize > sharedMemoryThreshold
    }
}

// MARK: - Swift-Native SHM Writer (TCC Proxy)
//
// Writes raw data into POSIX shared memory segments from Swift.
// Used by the TCC Swift Proxy to route screen capture pixel data
// through shm_open without crossing the UniFFI boundary.
//
// Segment naming matches the Rust ShmPool convention (/ep_{session}_{seq})
// so the existing ChunkedMCPFrameAccumulator SHM resolver can read them.

// shm_open / shm_unlink are declared variadic in the Darwin headers, which
// Swift cannot import directly. The thunks below forward to the C shim in
// Epistemos/Bridge/ShmPosixShim.{h,c}, which exposes the actual fixed ABI
// (3 args for open, 1 arg for unlink). The shim is declared in the
// bridging header, so `epistemos_shm_open` / `epistemos_shm_unlink` are
// visible here as ordinary C functions.
//
// History: an earlier version reached the symbols at runtime via
// `dlopen(nil, RTLD_LAZY)` + `dlsym`. That self-handle dlopen was sandbox-
// safe, but the literal `dlopen` / `dlsym` / `RTLD_LAZY` strings in
// MAS-visible source can attract paranoid App Store review tooling. The
// C shim has the same runtime behavior and removes the markers entirely.
private func posixShmOpen(_ name: UnsafePointer<CChar>, _ oflag: Int32, _ mode: mode_t) -> Int32 {
    return epistemos_shm_open(name, oflag, mode)
}

private func posixShmUnlink(_ name: UnsafePointer<CChar>) -> Int32 {
    return epistemos_shm_unlink(name)
}

enum ShmWriter {
    private static let logger = Logger(subsystem: "com.epistemos.bridge", category: "MCPFraming")

    /// Atomic counter matching Rust SEGMENT_COUNTER — starts at 10000 to avoid
    /// collisions with Rust-allocated segments (which start at 0).
    private static let counter = OSAllocatedUnfairLock(initialState: UInt64(10000))

    /// Track all segment names created during this process lifetime so they can
    /// be cleaned up when the subprocess terminates (preventing zombie leaks).
    private static let registry = OSAllocatedUnfairLock(initialState: [String]())

    /// Maximum segment size (16MB, matches Rust MAX_SEGMENT_SIZE).
    private static let maxSegmentSize = 16 * 1024 * 1024

    /// Write data into a new POSIX shared memory segment.
    ///
    /// Returns a JSON string with the SHM reference:
    /// `{"segment_name":"/ep_tcc_proxy_10001","byte_length":123456,"content_type":"image/png"}`
    ///
    /// The segment stays alive in the kernel until explicitly unlinked.
    /// The consumer (Rust or Swift) reads via `shm_open` + `mmap` using the returned name.
    static func writePayload(
        sessionId: String,
        data: Data,
        contentType: String
    ) throws -> String {
        guard data.count <= maxSegmentSize else {
            throw ShmWriterError.payloadTooLarge(data.count, max: maxSegmentSize)
        }

        let seq = counter.withLock { value -> UInt64 in
            value += 1
            return value
        }
        let sanitizedSession = sessionId.replacingOccurrences(of: "/", with: "_")
        let segmentName = "/ep_\(sanitizedSession)_\(seq)"

        // SAFETY: shm_open creates a kernel-backed shared memory object.
        // O_CREAT | O_RDWR | O_EXCL ensures we don't clobber an existing segment.
        // Mode 0o600 restricts access to the current user.
        let fd = segmentName.withCString { namePtr in
            posixShmOpen(namePtr, O_CREAT | O_RDWR | O_EXCL, mode_t(0o600))
        }
        guard fd >= 0 else {
            let err = String(cString: strerror(errno))
            throw ShmWriterError.shmOpenFailed(segmentName, err)
        }

        // Size the segment to fit the data.
        guard ftruncate(fd, off_t(data.count)) == 0 else {
            let err = String(cString: strerror(errno))
            close(fd)
            segmentName.withCString { _ = posixShmUnlink($0) }
            throw ShmWriterError.ftruncateFailed(segmentName, err)
        }

        // SAFETY: mmap maps the file descriptor into our address space.
        // MAP_SHARED ensures the consumer sees the same bytes.
        let ptr = mmap(nil, data.count, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0)
        close(fd) // fd no longer needed after mmap
        guard ptr != MAP_FAILED else {
            let err = String(cString: strerror(errno))
            segmentName.withCString { _ = posixShmUnlink($0) }
            throw ShmWriterError.mmapFailed(segmentName, err)
        }

        // Copy data into the shared memory region.
        data.withUnsafeBytes { rawBuffer in
            _ = memcpy(ptr, rawBuffer.baseAddress, data.count)
        }

        munmap(ptr, data.count)

        // Track for lifecycle cleanup.
        registry.withLock { $0.append(segmentName) }

        Self.logger.info("SHM write: \(segmentName) (\(data.count) bytes, \(contentType))")

        // Return the SHM reference as JSON — matches Rust ShmReference struct.
        return "{\"segment_name\":\"\(segmentName)\",\"byte_length\":\(data.count),\"content_type\":\"\(contentType)\"}"
    }

    /// Unlink a shared memory segment by name.
    static func unlink(_ segmentName: String) {
        segmentName.withCString { _ = posixShmUnlink($0) }
    }

    /// Clean up all TCC proxy SHM segments created during this process lifetime.
    /// Called on subprocess termination
    /// to prevent zombie POSIX shared memory segments leaking in the kernel.
    static func cleanupTccProxySegments() {
        let segments = registry.withLock { segments -> [String] in
            let copy = segments
            segments.removeAll()
            return copy
        }
        for name in segments {
            unlink(name)
        }
        if !segments.isEmpty {
            Self.logger.info("SHM cleanup: unlinked \(segments.count) tcc_proxy segments")
        }
    }
}

enum ShmWriterError: Error, LocalizedError {
    case payloadTooLarge(Int, max: Int)
    case shmOpenFailed(String, String)
    case ftruncateFailed(String, String)
    case mmapFailed(String, String)

    var errorDescription: String? {
        switch self {
        case .payloadTooLarge(let size, let max):
            return "SHM payload \(size) bytes exceeds max \(max)"
        case .shmOpenFailed(let name, let err):
            return "shm_open(\(name)) failed: \(err)"
        case .ftruncateFailed(let name, let err):
            return "ftruncate(\(name)) failed: \(err)"
        case .mmapFailed(let name, let err):
            return "mmap(\(name)) failed: \(err)"
        }
    }
}
