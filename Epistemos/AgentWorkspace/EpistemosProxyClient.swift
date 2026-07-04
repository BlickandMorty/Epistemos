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

        struct TokenResponse: Decodable {
            let token: String
            let expiresAt: Date
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
}
