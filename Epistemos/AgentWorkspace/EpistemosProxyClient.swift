import Foundation
import OSLog

// Plan 1-MAS §5 + §11 R4 — the receipt-gated proxy CLIENT.
// Contract (server side is deployed separately):
//   POST {base}/v1/auth/verify-receipt {"storekit_jws": ...}
//     → {"token": ..., "expiresAt": ISO8601}
//   POST {base}/v1/chat/completions  (OpenAI-compatible, Bearer token) → SSE
// The short-lived session token lives in the KEYCHAIN (never UserDefaults,
// never the binary); refresh triggers below ~20% of remaining TTL. Provider
// API keys exist only server-side (§0.5).

nonisolated struct EpistemosProxySession: Sendable, Equatable {
    let token: String
    let expiresAt: Date

    var remainingTTL: TimeInterval { expiresAt.timeIntervalSinceNow }

    /// Refresh below ~20% of a nominal 1-hour TTL (or any time under 3 min).
    var needsRefresh: Bool {
        remainingTTL < max(180, 3_600 * 0.2)
    }
}

nonisolated enum EpistemosProxyError: Error, Sendable {
    case notConfigured
    case receiptRejected(status: Int, body: String)
    case malformedResponse
}

nonisolated final class EpistemosProxyClient: @unchecked Sendable {
    static let shared = EpistemosProxyClient()

    private static let log = Logger(subsystem: "com.epistemos", category: "AgentProxy")
    private static let tokenKeychainKey = "epistemos.proxy.sessionToken"
    private static let expiryKeychainKey = "epistemos.proxy.sessionTokenExpiry"

    /// Owner-configurable during rollout; the shipped default is the
    /// production proxy host.
    static var baseURL: URL? {
        if let override = ProcessInfo.processInfo.environment["EPISTEMOS_PROXY_BASE_URL"],
           let url = URL(string: override) {
            return url
        }
        return URL(string: "https://proxy.epistemos.app")
    }

    /// The base URL handed to agent_core's provider config when the
    /// "epistemos-cloud" lane is active.
    static var chatCompletionsBaseURL: URL? {
        baseURL?.appendingPathComponent("v1")
    }

    private let lock = NSLock()
    private var cached: EpistemosProxySession?

    private init() {}

    private struct TokenResponse: Decodable {
        let token: String
        let expiresAt: Date
    }

    // MARK: - Session token lifecycle

    /// Current session, from memory or Keychain. nil = never exchanged.
    func currentSession() -> EpistemosProxySession? {
        lock.lock()
        defer { lock.unlock() }
        if let cached { return cached }
        guard let token = Keychain.load(for: Self.tokenKeychainKey),
              let expiryRaw = Keychain.load(for: Self.expiryKeychainKey),
              let expiry = ISO8601DateFormatter().date(from: expiryRaw) else {
            return nil
        }
        let session = EpistemosProxySession(token: token, expiresAt: expiry)
        cached = session
        return session
    }

    /// Session lookup for real cloud traffic. Production returns only a
    /// StoreKit-minted proxy session. DEBUG additionally supports owner testing
    /// with either:
    /// - `EPISTEMOS_PROXY_DEV_TOKEN`: POSTs to `/v1/auth/dev-session` and stores
    ///   the returned short-lived proxy session.
    /// - `EPISTEMOS_PROXY_DEV_SESSION_TOKEN`: uses an already minted proxy
    ///   bearer for local debug runs.
    ///
    /// Neither path fakes completions; JuneCloudEngine still calls the real
    /// `/v1/chat/completions` SSE endpoint.
    func sessionForCloudRequest() async throws -> EpistemosProxySession? {
        if let session = currentSession(), session.remainingTTL > 0 {
            return session
        }

        #if DEBUG
        if let session = debugSessionFromEnvironment() {
            store(session)
            return session
        }
        return try await mintDebugSessionIfConfigured()
        #else
        return nil
        #endif
    }

    /// Exchange a StoreKit JWS for a proxy session token (§5: the proxy
    /// verifies via the App Store Server API; verifyReceipt is deprecated
    /// and never used).
    func exchangeReceipt(jws: String, appAccountToken: UUID?) async throws -> EpistemosProxySession {
        guard let base = Self.baseURL else { throw EpistemosProxyError.notConfigured }
        var request = URLRequest(url: base.appendingPathComponent("v1/auth/verify-receipt"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload: [String: Any] = ["storekit_jws": jws]
        if let appAccountToken {
            payload["app_account_token"] = appAccountToken.uuidString
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw EpistemosProxyError.malformedResponse
        }
        guard http.statusCode == 200 else {
            throw EpistemosProxyError.receiptRejected(
                status: http.statusCode,
                body: String(decoding: data.prefix(300), as: UTF8.self)
            )
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode(TokenResponse.self, from: data) else {
            throw EpistemosProxyError.malformedResponse
        }

        let session = EpistemosProxySession(token: decoded.token, expiresAt: decoded.expiresAt)
        store(session)
        Self.log.info("Proxy session refreshed; expires \(decoded.expiresAt, privacy: .public)")
        return session
    }

    func clearSession() {
        lock.lock()
        cached = nil
        lock.unlock()
        Keychain.delete(for: Self.tokenKeychainKey)
        Keychain.delete(for: Self.expiryKeychainKey)
    }

    private func store(_ session: EpistemosProxySession) {
        lock.lock()
        cached = session
        lock.unlock()
        _ = Keychain.save(session.token, for: Self.tokenKeychainKey)
        _ = Keychain.save(
            ISO8601DateFormatter().string(from: session.expiresAt),
            for: Self.expiryKeychainKey
        )
    }

    #if DEBUG
    private func debugSessionFromEnvironment() -> EpistemosProxySession? {
        let env = ProcessInfo.processInfo.environment
        guard let token = env["EPISTEMOS_PROXY_DEV_SESSION_TOKEN"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            return nil
        }

        let expiresAt: Date
        if let raw = env["EPISTEMOS_PROXY_DEV_SESSION_EXPIRES_AT"],
           let parsed = ISO8601DateFormatter().date(from: raw) {
            expiresAt = parsed
        } else {
            expiresAt = Date().addingTimeInterval(3_600)
        }
        return EpistemosProxySession(token: token, expiresAt: expiresAt)
    }

    private func mintDebugSessionIfConfigured() async throws -> EpistemosProxySession? {
        let env = ProcessInfo.processInfo.environment
        guard let devToken = env["EPISTEMOS_PROXY_DEV_TOKEN"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !devToken.isEmpty else {
            return nil
        }
        guard let base = Self.baseURL else { throw EpistemosProxyError.notConfigured }

        var request = URLRequest(url: base.appendingPathComponent("v1/auth/dev-session"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(devToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["scope": "chat.completions"])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw EpistemosProxyError.malformedResponse
        }
        guard http.statusCode == 200 else {
            throw EpistemosProxyError.receiptRejected(
                status: http.statusCode,
                body: String(decoding: data.prefix(300), as: UTF8.self)
            )
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode(TokenResponse.self, from: data) else {
            throw EpistemosProxyError.malformedResponse
        }

        let session = EpistemosProxySession(token: decoded.token, expiresAt: decoded.expiresAt)
        store(session)
        Self.log.info("DEBUG proxy dev session minted; expires \(decoded.expiresAt, privacy: .public)")
        return session
    }
    #endif
}
