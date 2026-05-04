import Foundation

// MARK: - ArenaOp

/// Operation codes sent across the mmap arena to the Rust XPC service.
///
/// These values are contractually bound to the `op` field of the
/// `RequestSlot` struct on the Rust side.  Adding new variants requires
/// a version bump on both sides.
public enum ArenaOp: UInt16 {
    /// Retrieve a document or artefact from the vault.
    case retrieve = 1
    /// Plan a task (decomposition, routing, budget estimation).
    case plan = 2
    /// Execute a planned task inside the bounded XPC service.
    case execute = 3
    /// Escalate a task to the cloud gateway (Hermes sidecar).
    case escalate = 4
}

// MARK: - ArenaResponse

/// A response read from the arena by the Swift consumer.
///
/// The bridge copies the inline payload into a Swift `Data` value.  If the
/// response carries artefact references, they are resolved into signed URLs
/// by the blob store manager.
public struct ArenaResponse {
    /// Sequence number matching the original request.
    public let seq: UInt64
    /// Status code (0 = success, non-zero = domain-specific error).
    public let status: UInt16
    /// Inline payload (clamped to `INLINE_RSP_BYTES` on the Rust side).
    public let payload: Data
    /// References to out-of-line blobs that may accompany the response.
    public let refs: [ArenaArtefactRef]
}

// MARK: - ArenaArtefactRef

/// Swift mirror of the Rust `ArtefactRef` struct.
public struct ArenaArtefactRef {
    /// 16-byte content hash (first 16 bytes of BLAKE3).
    public let blobId: Data
    /// Byte offset inside the blob file.
    public let offset: UInt64
    /// Byte length of the span.
    public let length: UInt64
    /// Reserved flags.
    public let flags: UInt32
}

// MARK: - ArenaBridge

/// Swift actor that wraps the Rust `MappedArena` via UniFFI.
///
/// All public methods are `async` so that callers can await responses
/// without blocking the main thread.  The actor serialises access, which
/// matches the single-producer invariant of the request ring.
///
/// ## Usage
///
/// ```swift
/// let bridge = try ArenaBridge()
/// let seq = try await bridge.submitRequest(op: .retrieve, payload: requestData)
/// if let response = await bridge.pollResponse(seq: seq) {
///     print("Response: \(response.payload)")
/// }
/// ```
public actor ArenaBridge {

    /// The mmap arena handle exposed through the UniFFI-generated bindings.
    ///
    /// In a production build this is a `RustMappedArena` from the UniFFI
    /// scaffolding.  For the skeleton we store the file path and simulate the
    /// ring-buffer protocol in-process so that unit tests can exercise the
    /// full flow without a separate XPC service.
    private var arenaPath: URL
    private var requestSequence: UInt64 = 0
    private var pendingResponses: [UInt64: ArenaResponse] = [:]

    // MARK: - Init

    /// Open (or create) the arena file and return a bridge handle.
    ///
    /// - Throws: `ArenaPathError` if the arena file cannot be resolved.
    public init() throws {
        self.arenaPath = try ArenaPathResolver.resolve()
    }

    /// Open the arena at an explicit path (for testing or diagnostics).
    public init(path: URL) {
        self.arenaPath = path
    }

    // MARK: - Request Submission

    /// Submit a request into the arena request ring.
    ///
    /// - Parameters:
    ///   - op: The operation code.
    ///   - payload: Inline payload (clamped to 2048 bytes by the Rust side).
    /// - Returns: The sequence number assigned to the request.
    /// - Throws: `ArenaBridgeError` if the ring is full or the arena is inaccessible.
    public func submitRequest(op: ArenaOp, payload: Data) async throws -> UInt64 {
        let clamped = payload.prefix(2048)
        requestSequence += 1
        let seq = requestSequence

        // TODO: UniFFI call to Rust `MappedArena::submit_request`.
        // For the skeleton we simulate acceptance and enqueue a synthetic
        // response after a short delay so that tests can poll.
        #if DEBUG
        print("[ArenaBridge] submit seq=\(seq) op=\(op.rawValue) payload=\(clamped.count) bytes")
        #endif

        // Simulate async XPC processing in DEBUG builds.
        #if DEBUG
        Task {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10 ms
            let response = ArenaResponse(
                seq: seq,
                status: 0,
                payload: Data("OK\(seq)".utf8),
                refs: []
            )
            await self.ingestResponse(response)
        }
        #endif

        return seq
    }

    // MARK: - Response Polling

    /// Poll for a response matching the given sequence number.
    ///
    /// Returns immediately if the response is already available, otherwise
    /// returns `nil`.  Callers should retry periodically or use a Combine
    /// publisher for reactive observation.
    ///
    /// - Parameter seq: The sequence number from `submitRequest`.
    /// - Returns: The response if available, or `nil`.
    public func pollResponse(seq: UInt64) async -> ArenaResponse? {
        if let cached = pendingResponses.removeValue(forKey: seq) {
            return cached
        }

        // TODO: UniFFI call to Rust `MappedArena::try_take_response`.
        return nil
    }

    /// Blocking-await a response with a timeout.
    ///
    /// - Parameters:
    ///   - seq: The sequence number to wait for.
    ///   - timeout: Maximum wait duration (default 30 s).
    /// - Returns: The response.
    /// - Throws: `ArenaBridgeError.timeout` if the response does not arrive.
    public func awaitResponse(seq: UInt64, timeout: Duration = .seconds(30)) async throws -> ArenaResponse {
        let deadline = ContinuousClock().now + timeout

        while ContinuousClock().now < deadline {
            if let rsp = await pollResponse(seq: seq) {
                return rsp
            }
            try? await Task.sleep(nanoseconds: 5_000_000) // 5 ms poll interval
        }

        throw ArenaBridgeError.timeout(seq: seq)
    }

    // MARK: - Epoch Signalling

    /// Read the current signal epoch from the arena header.
    ///
    /// A change in this value indicates that the XPC service has reloaded its
    /// configuration or that a new companion has joined the simulation.
    public func readSignalEpoch() async -> UInt64 {
        // TODO: UniFFI call to Rust `MappedArena::signal_epoch`.
        0
    }

    // MARK: - Internal

    /// Inject a response into the local cache (used by the simulated XPC path
    /// in DEBUG builds and by unit tests).
    internal func ingestResponse(_ response: ArenaResponse) {
        pendingResponses[response.seq] = response
    }
}

// MARK: - ArenaBridgeError

public enum ArenaBridgeError: Error, LocalizedError {
    case ringFull
    case arenaNotOpen
    case timeout(seq: UInt64)
    case submitFailed(String)

    public var errorDescription: String? {
        switch self {
        case .ringFull:
            return "Arena request ring is full."
        case .arenaNotOpen:
            return "Arena is not open."
        case .timeout(let seq):
            return "Timeout waiting for response to seq=\(seq)."
        case .submitFailed(let msg):
            return "Submit failed: \(msg)"
        }
    }
}
