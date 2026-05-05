import Foundation

// MARK: - V2.4 MockProviderServiceStreaming
//
// In-process mock that satisfies `ProviderServiceStreamingProtocol`
// without launching an actual XPC service. Used by tests + by the
// V2.4 "buildable today" workflow — exercises the protocol shape,
// the wire-format encoding/decoding, and the session lifecycle
// without requiring code signing or an XPC service deployment.
//
// **Doctrine alignment:** the design doc
// `docs/V2_4_AND_V3_2_DESIGN_2026_05_05.md` calls for "mock-XPC tests
// that exercise the protocol in-process without launching the
// service." This is that mock.
//
// The mock generates a deterministic chunk sequence per session
// (sessionId determines the seed; same input produces same chunks)
// so tests can assert exact wire-format outcomes without flake.

/// In-process mock of `ProviderServiceStreamingProtocol`. Records every
/// call in `callLog` for test assertions; serves a deterministic chunk
/// sequence from a session-keyed generator.
///
/// Marked `@unchecked Sendable` because the internal state is locked;
/// the mock is consumed from XPCTest contexts that need cross-thread
/// access without forcing the actor isolation that a real XPC service
/// would impose.
public final class MockProviderServiceStreaming: NSObject, ProviderServiceStreamingProtocol, @unchecked Sendable {

    // MARK: - Recorded state for test assertions

    public enum Call: Equatable, Sendable {
        case openSession(requestJson: String)
        case fetchNextChunk(sessionId: String)
        case closeSession(sessionId: String)
    }

    private let stateLock = NSLock()
    private var sessions: [String: SessionState] = [:]
    private var callLogValue: [Call] = []

    private struct SessionState {
        let request: ProviderXPCStreamingRequest
        var chunksRemaining: [LLMTokenChunk]
    }

    public override init() {
        super.init()
    }

    /// Snapshot the recorded call log. Thread-safe.
    public var callLog: [Call] {
        stateLock.lock()
        defer { stateLock.unlock() }
        return callLogValue
    }

    /// Reset the mock to a clean state. Useful between test cases.
    public func reset() {
        stateLock.lock()
        defer { stateLock.unlock() }
        sessions.removeAll()
        callLogValue.removeAll()
    }

    // MARK: - Protocol surface

    public func openSession(
        _ requestJson: String,
        withReply reply: @escaping (NSDictionary) -> Void
    ) {
        stateLock.lock()
        callLogValue.append(.openSession(requestJson: requestJson))
        stateLock.unlock()

        guard let request = decodeRequest(requestJson) else {
            reply(errorReply(
                kind: "decode_failed",
                message: "Could not decode ProviderXPCStreamingRequest"
            ))
            return
        }

        // Mock validation: the credential handle must start with
        // `kc:` (mirrors a Keychain reference shape) and the
        // capability token must be non-empty. These mirror the kinds
        // of checks a real ProviderXPC service would do before
        // opening a session.
        if !request.credentialKeychainHandle.hasPrefix("kc:") {
            reply(errorReply(
                kind: "credential_not_found",
                message: "Mock requires `kc:` prefix on credential handle"
            ))
            return
        }
        if request.capabilityToken.isEmpty {
            reply(errorReply(
                kind: "capability_rejected",
                message: "Mock requires non-empty capability token"
            ))
            return
        }

        // Generate a deterministic chunk sequence keyed by the
        // request body so tests are reproducible.
        let sessionId = "mock-session-\(UUID().uuidString)"
        let chunks = Self.deterministicChunks(for: request)

        stateLock.lock()
        sessions[sessionId] = SessionState(request: request, chunksRemaining: chunks)
        stateLock.unlock()

        let session = ProviderXPCStreamingSession(
            sessionId: sessionId,
            provider: request.provider,
            modelId: request.modelId,
            ringBytes: 65536,
            // Mock returns 0 for the mach port — the IOSurface ring
            // is Phase 2 work; in Phase 1 the mock streams chunks via
            // fetchNextChunk replies.
            ringMachPort: 0
        )

        reply(successReply(sessionKey: ProviderXPCStreamingKeys.session, payload: session))
    }

    public func fetchNextChunk(
        sessionId: String,
        withReply reply: @escaping (NSDictionary) -> Void
    ) {
        stateLock.lock()
        callLogValue.append(.fetchNextChunk(sessionId: sessionId))
        guard var state = sessions[sessionId] else {
            stateLock.unlock()
            reply(errorReply(
                kind: "session_not_found",
                message: "Mock has no session with id \(sessionId)"
            ))
            return
        }
        if state.chunksRemaining.isEmpty {
            sessions.removeValue(forKey: sessionId)
            stateLock.unlock()
            reply([ProviderXPCStreamingKeys.status: ProviderXPCStreamingKeys.statusDone])
            return
        }
        let chunk = state.chunksRemaining.removeFirst()
        sessions[sessionId] = state
        stateLock.unlock()

        reply(successReply(sessionKey: ProviderXPCStreamingKeys.chunk, payload: chunk))
    }

    public func closeSession(
        sessionId: String,
        withReply reply: @escaping (NSDictionary) -> Void
    ) {
        stateLock.lock()
        callLogValue.append(.closeSession(sessionId: sessionId))
        sessions.removeValue(forKey: sessionId)
        stateLock.unlock()
        reply([ProviderXPCStreamingKeys.status: ProviderXPCStreamingKeys.statusOk])
    }

    // MARK: - Deterministic chunk generator

    /// Produces a deterministic chunk sequence for a given request.
    /// Same input always produces the same output so tests can
    /// assert exact wire-format outcomes. The sequence is small (3
    /// chunks) so tests stay fast.
    private static func deterministicChunks(
        for request: ProviderXPCStreamingRequest
    ) -> [LLMTokenChunk] {
        let prefix = "[mock:\(request.provider.rawValue):\(request.modelId)]"
        return [
            LLMTokenChunk(sequence: 1, text: "\(prefix) "),
            LLMTokenChunk(sequence: 2, text: "deterministic mock response"),
            LLMTokenChunk(
                sequence: 3,
                text: "",
                tokenId: nil,
                isFinal: true,
                metadataJson: #"{"finish_reason":"end_turn"}"#
            ),
        ]
    }

    // MARK: - Reply envelopes

    private func errorReply(kind: String, message: String) -> NSDictionary {
        [
            ProviderXPCStreamingKeys.status: ProviderXPCStreamingKeys.statusError,
            ProviderXPCStreamingKeys.errorKind: kind,
            ProviderXPCStreamingKeys.errorMessage: message,
        ]
    }

    private func successReply<T: Codable>(
        sessionKey: String,
        payload: T
    ) -> NSDictionary {
        guard
            let data = try? JSONEncoder().encode(payload),
            let json = String(data: data, encoding: .utf8)
        else {
            return errorReply(kind: "encode_failed", message: "Could not encode \(T.self)")
        }
        return [
            ProviderXPCStreamingKeys.status: ProviderXPCStreamingKeys.statusOk,
            sessionKey: json,
        ]
    }

    private func decodeRequest(_ json: String) -> ProviderXPCStreamingRequest? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ProviderXPCStreamingRequest.self, from: data)
    }
}
