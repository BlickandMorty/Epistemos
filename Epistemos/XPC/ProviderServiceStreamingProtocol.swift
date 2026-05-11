import Foundation

// MARK: - V2.4 ProviderServiceStreamingProtocol
//
// XPC protocol surface for cloud-model dispatch via the canonical
// two-stage handshake described in
// `docs/V2_4_AND_V3_2_DESIGN_2026_05_05.md`:
//
//   Stage 1 — negotiation, over NSXPCConnection. Main app asks
//   ProviderXPC to set up a streaming session: provider, model,
//   credential handle (Keychain reference, NOT the secret), capability
//   token. ProviderXPC validates + opens an `IOSurface`-backed shared
//   memory ring + returns a session handle.
//
//   Stage 2 — streaming, over the shared memory ring. ProviderXPC
//   writes typed `LLMTokenChunk` records into the ring; main app reads
//   without IPC overhead. Per-token cost: one atomic store + one
//   atomic load. Sub-microsecond per token. (Phase 2 follow-up; stage
//   1 lands first.)
//
// **Build status — SCAFFOLD ONLY (RCA13 P1-018).** This file ships the
// Swift protocol declarations + the typed wire structs + a Mock client
// implementation for in-process tests. There is NO production caller
// of this streaming surface yet. The actual XPC service launch +
// entitlement provisioning is V2.4 production work that requires
// paid Apple Developer Program signing.
//
// **What this means for audits / UI:**
// - No Settings row, no chat-tier descriptor, no provider picker
//   claims XPC streaming is available. If you find one, that surface
//   is wrong and should be hidden or labeled "preview".
// - The Mock at `MockProviderServiceStreaming` is exercised only by
//   `EpistemosTests/ProviderServiceStreamingTests.swift`, never by
//   production code paths.
// - `ProviderServiceClient.classifySurfaceInProcess(_:)` is a real
//   in-process call — that one is wired. The streaming half is not.
//
// The protocol exists now so the V2.4 production slice has a
// concrete target to land against. Audit-honesty marker per the
// RCA13 P1-018 acceptance criterion: "production streaming is
// complete, or the feature is hidden/gated/labeled as scaffold."

// MARK: - Wire types (Codable so they cross XPC + IOSurface cleanly)

/// Cloud provider tier the streaming session targets. Mirrors the
/// existing LocalAgentGatewaySurface cloud-provider variants but kept as
/// a separate enum so the streaming protocol's wire format can evolve
/// independently of the gateway-policy surface.
nonisolated public enum ProviderXPCProvider: String, Codable, Sendable, Hashable, CaseIterable {
    case anthropic
    case openAI = "openai"
    case google
    case perplexity
    case openAICompatible = "openai_compatible"
}

/// Per-session request shape. Sent by main app over NSXPCConnection
/// in stage-1 negotiation. ProviderXPC validates + returns either a
/// `ProviderXPCStreamingSession` (success) or a structured
/// `ProviderXPCError` (failure).
nonisolated public struct ProviderXPCStreamingRequest: Codable, Sendable, Hashable {
    public let provider: ProviderXPCProvider
    /// Provider-specific model identifier (e.g. "claude-opus-4-7",
    /// "gpt-5", "gemini-2.5-pro", "sonar-pro").
    public let modelId: String
    /// Reference to the Keychain entry holding the API key. The
    /// streaming protocol NEVER carries the raw secret across XPC —
    /// ProviderXPC fetches it via SecItemCopyMatching using this
    /// handle. This is the security-critical part of the V2.4
    /// pattern.
    public let credentialKeychainHandle: String
    /// Capability token issued by the Sovereign Gate macaroon system.
    /// ProviderXPC verifies the token before opening the session;
    /// invalid tokens return ProviderXPCError.capabilityRejected.
    public let capabilityToken: String
    /// Maximum tokens to generate. Bounded server-side at provider
    /// limits.
    public let maxTokens: UInt32
    /// JSON-encoded provider-specific request body (prompt, system,
    /// tools, etc.). ProviderXPC forwards this verbatim to the
    /// provider HTTP endpoint after credential injection.
    public let requestBodyJson: String

    public init(
        provider: ProviderXPCProvider,
        modelId: String,
        credentialKeychainHandle: String,
        capabilityToken: String,
        maxTokens: UInt32,
        requestBodyJson: String
    ) {
        self.provider = provider
        self.modelId = modelId
        self.credentialKeychainHandle = credentialKeychainHandle
        self.capabilityToken = capabilityToken
        self.maxTokens = maxTokens
        self.requestBodyJson = requestBodyJson
    }
}

/// Stage-1 negotiation response. Carries the session id (for stage-2
/// streaming reads) + the IOSurface mach port (the shared memory ring
/// for sub-µs token streaming) + the negotiated session metadata.
nonisolated public struct ProviderXPCStreamingSession: Codable, Sendable, Hashable {
    public let sessionId: String
    public let provider: ProviderXPCProvider
    public let modelId: String
    /// Shared-memory ring size in bytes. Default 64 KiB — fits ~30s
    /// of typical token streaming.
    public let ringBytes: UInt32
    /// IOSurface mach_port ID. Main app reconstructs the IOSurface
    /// via `IOSurfaceLookupFromMachPort(...)` and reads token chunks
    /// without further IPC. Stage-1 returns this; stage-2 streaming
    /// is a pure shared-memory read on the main app side.
    ///
    /// **Phase note:** stage-2 IOSurface streaming is a follow-up
    /// slice; the protocol declares the field today so the wire shape
    /// is stable. In Phase 1 (this slice) the shared-memory ring is
    /// not yet wired and ProviderXPC sends chunks via NSXPCConnection
    /// `withReply` calls.
    public let ringMachPort: UInt32

    public init(
        sessionId: String,
        provider: ProviderXPCProvider,
        modelId: String,
        ringBytes: UInt32,
        ringMachPort: UInt32
    ) {
        self.sessionId = sessionId
        self.provider = provider
        self.modelId = modelId
        self.ringBytes = ringBytes
        self.ringMachPort = ringMachPort
    }
}

/// Per-token chunk written into the shared-memory ring (or, in Phase 1,
/// returned via NSXPCConnection withReply). Layout is fixed so the
/// reader can tell where one chunk ends and the next begins without a
/// length prefix.
nonisolated public struct LLMTokenChunk: Codable, Sendable, Hashable {
    /// Monotonic per-session sequence number. The reader asserts
    /// `seq == previous_seq + 1` to detect drops.
    public let sequence: UInt64
    /// UTF-8 token text (may be empty for tool-use start markers).
    public let text: String
    /// Provider-side token-id when known (some providers expose this,
    /// some don't). Useful for the V3.1 logit-trajectory hashing.
    public let tokenId: Int32?
    /// True iff this is the last chunk for the session.
    public let isFinal: Bool
    /// Optional structured metadata (tool-use start, thinking-block
    /// boundaries, finish-reason, etc.) — JSON-encoded so the schema
    /// can evolve.
    public let metadataJson: String?

    public init(
        sequence: UInt64,
        text: String,
        tokenId: Int32? = nil,
        isFinal: Bool = false,
        metadataJson: String? = nil
    ) {
        self.sequence = sequence
        self.text = text
        self.tokenId = tokenId
        self.isFinal = isFinal
        self.metadataJson = metadataJson
    }
}

/// Structured error for stage-1 negotiation failures. Stage-2
/// streaming errors land on the chunk stream as a final chunk with
/// `metadataJson` carrying a `finish_reason: error` field.
nonisolated public enum ProviderXPCError: Error, Codable, Sendable, Equatable {
    case credentialNotFound(handle: String)
    case capabilityRejected(reason: String)
    case providerUnsupported(provider: String)
    case modelUnsupported(provider: String, model: String)
    case ringAllocationFailed(reason: String)
    case providerHttpError(status: Int, message: String)
    case shutdown
}

// MARK: - Protocol surface

/// XPC protocol the main app calls to open + drive a streaming
/// cloud-model session. Stage 1 (negotiation) is `openSession` /
/// `closeSession`. Stage 2 (streaming) is the IOSurface ring (Phase 2
/// follow-up).
///
/// All `withReply` callbacks are `@escaping` per the NSXPCConnection
/// contract. Replies use NSDictionary for ObjC bridging compatibility;
/// helpers below decode them back into typed `Result<T, ProviderXPCError>`.
@objc(EpistemosProviderServiceStreamingProtocol)
public protocol ProviderServiceStreamingProtocol {
    /// Stage-1 negotiation. Validates the request + opens a streaming
    /// session. Reply NSDictionary keys:
    ///   `status`: "ok" | "error"
    ///   On success: `session` carrying ProviderXPCStreamingSession JSON
    ///   On error: `error_kind` + `error_message`
    func openSession(
        _ requestJson: String,
        withReply reply: @escaping (NSDictionary) -> Void
    )

    /// Phase-1 chunk fetch — temporary path until IOSurface streaming
    /// lands. Main app polls for the next chunk via XPC reply. Reply
    /// NSDictionary keys:
    ///   `status`: "ok" | "done" | "error"
    ///   On ok: `chunk` carrying LLMTokenChunk JSON
    ///   On done: nothing (session has emitted its final chunk)
    ///   On error: `error_kind` + `error_message`
    ///
    /// **Phase 2 will replace this with shared-memory ring reads.**
    func fetchNextChunk(
        sessionId: String,
        withReply reply: @escaping (NSDictionary) -> Void
    )

    /// Stage-1 teardown. Closes the session, releases the ring, sends
    /// a final chunk if streaming is mid-flight. Reply NSDictionary keys:
    ///   `status`: "ok" | "error"
    func closeSession(
        sessionId: String,
        withReply reply: @escaping (NSDictionary) -> Void
    )
}

// MARK: - Wire envelope helpers

/// JSON envelope keys for the NSDictionary replies. Kept stable so
/// the wire format can evolve without breaking the cross-process
/// serialization.
nonisolated public enum ProviderXPCStreamingKeys {
    public static let status = "status"
    public static let statusOk = "ok"
    public static let statusError = "error"
    public static let statusDone = "done"
    public static let session = "session"
    public static let chunk = "chunk"
    public static let errorKind = "error_kind"
    public static let errorMessage = "error_message"
}
