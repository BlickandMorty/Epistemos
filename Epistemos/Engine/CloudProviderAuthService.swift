import AppKit
import CryptoKit
import Foundation
import Network
import os
import Security

nonisolated enum CloudProviderOAuthMode: String, Codable, Sendable, Equatable {
    case openAICodex
    case googleGemini
    case anthropicClaudeCode
}

nonisolated struct CloudProviderOAuthCredential: Codable, Sendable, Equatable {
    private static let log = Logger(subsystem: "com.epistemos.auth", category: "CloudProviderOAuthCredential")

    let provider: CloudModelProvider
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date?
    var clientID: String?
    var clientSecret: String?
    var projectID: String?
    var authMode: CloudProviderOAuthMode
    var accountLabel: String?

    init(
        provider: CloudModelProvider,
        accessToken: String,
        refreshToken: String?,
        expiresAt: Date?,
        clientID: String?,
        clientSecret: String?,
        projectID: String?,
        authMode: CloudProviderOAuthMode,
        accountLabel: String?
    ) {
        self.provider = provider
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.projectID = projectID
        self.authMode = authMode
        self.accountLabel = accountLabel
    }

    var effectiveExpiration: Date? {
        expiresAt ?? OAuthTokenMetadata.expirationDate(fromJWT: accessToken)
    }

    var isExpiredOrExpiringSoon: Bool {
        guard let effectiveExpiration else { return false }
        return effectiveExpiration.timeIntervalSinceNow <= 300
    }

    static func decode(from rawValue: String) -> CloudProviderOAuthCredential? {
        guard let data = rawValue.data(using: .utf8) else {
            Self.log.error("Failed to decode OAuth credential blob: stored value was not valid UTF-8")
            return nil
        }
        do {
            return try JSONDecoder().decode(Self.self, from: data)
        } catch {
            Self.log.error("Failed to decode OAuth credential blob: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    var displayAccountLabel: String? {
        let trimmed = accountLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

nonisolated struct GoogleOAuthClientConfiguration: Codable, Sendable, Equatable {
    let clientID: String
    let clientSecret: String
    let projectID: String

    static func parse(from data: Data) throws -> GoogleOAuthClientConfiguration {
        let payload = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = payload as? [String: Any] else {
            throw CloudProviderAuthError.invalidGoogleClientConfiguration
        }

        let installed = dictionary["installed"] as? [String: Any]
        let desktop = dictionary["web"] as? [String: Any]
        guard let container = installed ?? desktop else {
            throw CloudProviderAuthError.invalidGoogleClientConfiguration
        }

        guard let clientID = container["client_id"] as? String,
              !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let clientSecret = container["client_secret"] as? String,
              !clientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CloudProviderAuthError.invalidGoogleClientConfiguration
        }

        let projectID = (container["project_id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? (dictionary["project_id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""

        return GoogleOAuthClientConfiguration(
            clientID: clientID,
            clientSecret: clientSecret,
            projectID: projectID
        )
    }
}

extension GoogleOAuthClientConfiguration {
    /// Embedded development credentials loaded from a bundled `google_oauth_client.json`.
    /// Users can override by loading their own OAuth client JSON in Settings.
    static let embeddedDefault: GoogleOAuthClientConfiguration? = {
        guard let url = Bundle.main.url(forResource: "google_oauth_client", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? GoogleOAuthClientConfiguration.parse(from: data)
    }()
}

nonisolated enum OAuthTokenMetadata {
    static func expirationDate(fromJWT token: String) -> Date? {
        guard let payload = payload(fromJWT: token) else { return nil }
        guard let exp = payload["exp"] as? TimeInterval else {
            return nil
        }
        return Date(timeIntervalSince1970: exp)
    }

    static func payload(fromJWT token: String) -> [String: Any]? {
        let segments = token.split(separator: ".")
        guard segments.count >= 2,
              let payloadData = base64URLDecoded(String(segments[1])),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            return nil
        }
        return payload
    }

    private static func base64URLDecoded(_ value: String) -> Data? {
        var normalized = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let padding = normalized.count % 4
        if padding > 0 {
            normalized.append(String(repeating: "=", count: 4 - padding))
        }
        return Data(base64Encoded: normalized)
    }
}

nonisolated enum OpenAICodexRuntimeMetadata {
    static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    static let clientVersion = loadClientVersion()

    private nonisolated static let clientVersionFallback = "0.118.0"

    static func url(appendingClientVersionTo urlString: String) -> URL? {
        guard var components = URLComponents(string: urlString) else {
            return nil
        }
        var queryItems = components.queryItems ?? []
        if !queryItems.contains(where: { $0.name == "client_version" }) {
            queryItems.append(URLQueryItem(name: "client_version", value: clientVersion))
        }
        components.queryItems = queryItems
        return components.url
    }

    private static func loadClientVersion() -> String {
        let modelsCacheURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/models_cache.json")
        guard let data = try? Data(contentsOf: modelsCacheURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawValue = json["client_version"] as? String else {
            return clientVersionFallback
        }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? clientVersionFallback : trimmed
    }
}

nonisolated enum CloudProviderResolvedCredential: Sendable, Equatable {
    case apiKey(String)
    case openAICodex(accessToken: String)
    case googleOAuth(accessToken: String, projectID: String)
    case anthropicOAuth(accessToken: String)
}

nonisolated enum AnthropicClaudeCodeImportResult: Sendable, Equatable {
    case imported(CloudProviderOAuthCredential)
    case failure(String)
}

nonisolated enum CloudProviderAuthError: LocalizedError {
    case invalidGoogleClientConfiguration
    case googleProjectIDRequired
    case missingOAuthSession(CloudModelProvider)
    case missingOAuthRefreshToken(CloudModelProvider)
    case unsupportedOAuthProvider(CloudModelProvider)
    case openAIDeviceCodeRequestFailed
    case openAIDeviceCodeTimedOut
    case openAIDeviceCodeCancelled
    case openAITokenExchangeFailed(Int)
    case googleAuthorizationDenied(String)
    case googleAuthorizationTimedOut
    case googleTokenExchangeFailed(Int)
    case anthropicRefreshFailed
    case callbackServerFailed
    case callbackServerReceivedInvalidRequest
    case callbackServerDenied(String)

    var errorDescription: String? {
        switch self {
        case .invalidGoogleClientConfiguration:
            "The Google OAuth client file is missing the required Desktop App fields (`installed.client_id` and `installed.client_secret`, or the same values under `web`)."
        case .googleProjectIDRequired:
            "Google OAuth needs a Cloud project ID for Gemini API requests."
        case .missingOAuthSession(let provider):
            "\(provider.displayName) account access is not connected yet."
        case .missingOAuthRefreshToken(let provider):
            "\(provider.displayName) account access cannot refresh because no refresh token was stored."
        case .unsupportedOAuthProvider(let provider):
            "\(provider.displayName) does not support this OAuth flow."
        case .openAIDeviceCodeRequestFailed:
            "OpenAI account sign-in could not start the device authorization flow."
        case .openAIDeviceCodeTimedOut:
            "OpenAI account sign-in did not finish within 90 seconds. If OpenAI asked you to enable access first, finish that in the browser and then tap Retry OpenAI Sign In."
        case .openAIDeviceCodeCancelled:
            "OpenAI account sign-in was cancelled."
        case .openAITokenExchangeFailed(let status):
            "OpenAI account sign-in failed during token exchange (\(status))."
        case .googleAuthorizationDenied(let message):
            "Google account sign-in was denied: \(message)"
        case .googleAuthorizationTimedOut:
            "Google account sign-in timed out after 90 seconds before the browser callback returned. Finish the browser step and then tap Retry Google OAuth."
        case .googleTokenExchangeFailed(let status):
            "Google account sign-in failed during token exchange (\(status))."
        case .anthropicRefreshFailed:
            "Anthropic account access could not be refreshed."
        case .callbackServerFailed:
            "The local OAuth callback server could not start."
        case .callbackServerReceivedInvalidRequest:
            "The OAuth callback was missing the required authorization code."
        case .callbackServerDenied(let message):
            "The OAuth callback returned an error: \(message)"
        }
    }
}

@MainActor
final class CloudProviderAuthService {
    static let shared = CloudProviderAuthService()

    private static let log = Logger(subsystem: "com.epistemos.auth", category: "CloudProviderAuth")

    private let keychainLoad: @Sendable (String) -> String?
    private let keychainSave: @Sendable (String, String) -> Bool
    private let keychainDelete: @Sendable (String) -> Void
    private let urlSession: URLSession
    private let openAISignInTimeout: Duration
    private let googleSignInTimeout: Duration
    private let agentProvenanceRecorder: AgentToolProvenanceRecorder?

    init(
        keychainLoad: @escaping @Sendable (String) -> String? = { Keychain.load(for: $0) },
        keychainSave: @escaping @Sendable (String, String) -> Bool = { value, key in
            Keychain.save(value, for: key)
        },
        keychainDelete: @escaping @Sendable (String) -> Void = { Keychain.delete(for: $0) },
        urlSession: URLSession = .shared,
        openAISignInTimeout: Duration = .seconds(90),
        googleSignInTimeout: Duration = .seconds(90),
        agentProvenanceRecorder: AgentToolProvenanceRecorder? = AgentToolProvenanceRecorder()
    ) {
        self.keychainLoad = keychainLoad
        self.keychainSave = keychainSave
        self.keychainDelete = keychainDelete
        self.urlSession = urlSession
        self.openAISignInTimeout = openAISignInTimeout
        self.googleSignInTimeout = googleSignInTimeout
        self.agentProvenanceRecorder = agentProvenanceRecorder
    }

    func storedOAuthCredential(for provider: CloudModelProvider) -> CloudProviderOAuthCredential? {
        guard let rawValue = keychainLoad(provider.oauthKeychainKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty else {
            return nil
        }
        return CloudProviderOAuthCredential.decode(from: rawValue)
    }

    func storeOAuthCredential(_ credential: CloudProviderOAuthCredential) -> Bool {
        do {
            let data = try JSONEncoder().encode(credential)
            guard let encoded = String(data: data, encoding: .utf8) else { return false }
            return keychainSave(encoded, credential.provider.oauthKeychainKey)
        } catch {
            Self.log.error("Failed to encode OAuth credential for \(credential.provider.displayName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func clearOAuthCredential(for provider: CloudModelProvider) {
        keychainDelete(provider.oauthKeychainKey)
    }

    func hasStoredOAuthCredential(for provider: CloudModelProvider) -> Bool {
        storedOAuthCredential(for: provider) != nil
    }

    func resolvedCredential(
        for provider: CloudModelProvider,
        apiKey: String?
    ) async throws -> CloudProviderResolvedCredential {
        if let credential = storedOAuthCredential(for: provider) {
            let refreshed = try await refreshedCredentialIfNeeded(credential)
            switch refreshed.authMode {
            case .openAICodex:
                return .openAICodex(accessToken: refreshed.accessToken)
            case .googleGemini:
                guard let projectID = refreshed.projectID, !projectID.isEmpty else {
                    throw CloudProviderAuthError.googleProjectIDRequired
                }
                return .googleOAuth(accessToken: refreshed.accessToken, projectID: projectID)
            case .anthropicClaudeCode:
                return .anthropicOAuth(accessToken: refreshed.accessToken)
            }
        }

        guard let trimmedAPIKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmedAPIKey.isEmpty else {
            throw CloudProviderAuthError.missingOAuthSession(provider)
        }
        return .apiKey(trimmedAPIKey)
    }

    func importOpenAICodexCLIIfPresent() -> Bool {
        let authPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/auth.json")
        guard let data = try? Data(contentsOf: authPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = json["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String,
              !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        let refreshToken = (tokens["refresh_token"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let credential = CloudProviderOAuthCredential(
            provider: .openAI,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: OAuthTokenMetadata.expirationDate(fromJWT: accessToken),
            clientID: OpenAICodexRuntimeMetadata.clientID,
            clientSecret: nil,
            projectID: nil,
            authMode: .openAICodex,
            accountLabel: openAIAccountLabel(fromAccessToken: accessToken)
        )
        return storeOAuthCredential(credential)
    }

    func importAnthropicClaudeCodeCredentials() -> AnthropicClaudeCodeImportResult {
        let credentialsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")
        guard let data = try? Data(contentsOf: credentialsURL) else {
            return .failure(
                "No Claude Code account session was found in ~/.claude/.credentials.json. Open Claude Code, sign in, then retry import."
            )
        }

        guard let credential = anthropicClaudeCodeCredential(from: data) else {
            return .failure(
                "Claude Code credentials were found, but they did not contain a usable Anthropic account session. Reconnect in Claude Code, then retry import."
            )
        }
        guard storeOAuthCredential(credential) else {
            return .failure(
                "Epistemos couldn't store the imported Claude Code account session in the Apple Keychain."
            )
        }
        return .imported(credential)
    }

    nonisolated func anthropicClaudeCodeCredential(from data: Data) -> CloudProviderOAuthCredential? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let rawAccessToken = oauth["accessToken"] as? String else {
            return nil
        }

        let accessToken = rawAccessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accessToken.isEmpty else { return nil }

        let refreshToken = (oauth["refreshToken"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let expiresAtMilliseconds = oauth["expiresAt"] as? TimeInterval
        let expiresAt = expiresAtMilliseconds.map { Date(timeIntervalSince1970: $0 / 1_000) }

        return CloudProviderOAuthCredential(
            provider: .anthropic,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            clientID: Self.anthropicClaudeCodeClientID,
            clientSecret: nil,
            projectID: nil,
            authMode: .anthropicClaudeCode,
            accountLabel: Self.inferredAnthropicAccountLabel(from: json)
        )
    }

    func signInToOpenAI(
        openURL: @escaping @Sendable (URL) -> Void = { NSWorkspace.shared.open($0) },
        onDeviceCodeReady: @escaping @MainActor @Sendable (OpenAIDeviceAuthorization) -> Void = { _ in }
    ) async throws {
        try await withOpenAITimeout {
            let deviceCodeRequest = try await self.requestOpenAIDeviceCode()
            onDeviceCodeReady(deviceCodeRequest)
            openURL(deviceCodeRequest.verificationURL)
            let authorizationData = try await self.pollOpenAIDeviceCode(deviceCodeRequest)
            let credential = try await self.exchangeOpenAIDeviceCode(authorizationData)
            guard self.storeOAuthCredential(credential) else {
                throw CloudProviderAuthError.openAITokenExchangeFailed(0)
            }
        }
    }

    func signInToGoogle(
        configuration: GoogleOAuthClientConfiguration,
        openURL: @escaping @Sendable (URL) -> Void = { NSWorkspace.shared.open($0) }
    ) async throws {
        let scopes = [
            "https://www.googleapis.com/auth/cloud-platform",
            "https://www.googleapis.com/auth/userinfo.email",
            "https://www.googleapis.com/auth/userinfo.profile",
        ]
        let callback = try await LocalOAuthCallbackServer.start(path: "/oauth2callback")
        defer {
            Task {
                await callback.stop()
            }
        }

        let verifier = Self.randomURLSafeString(byteCount: 32)
        let challenge = Self.base64URL(Self.sha256(data: Data(verifier.utf8)))
        let redirectURI = "http://127.0.0.1:\(await callback.currentPort())/oauth2callback"

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        components?.queryItems = [
            .init(name: "client_id", value: configuration.clientID),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: scopes.joined(separator: " ")),
            .init(name: "access_type", value: "offline"),
            .init(name: "prompt", value: "consent"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
        ]

        guard let url = components?.url else {
            throw CloudProviderAuthError.invalidGoogleClientConfiguration
        }
        openURL(url)

        let callbackResult = try await callback.waitForAuthorizationResult(timeout: googleSignInTimeout)
        switch callbackResult {
        case .success(let code):
            var credential = try await exchangeGoogleAuthorizationCode(
                code: code,
                verifier: verifier,
                redirectURI: redirectURI,
                configuration: configuration
            )
            credential.accountLabel = await fetchGoogleAccountLabel(accessToken: credential.accessToken)
            guard storeOAuthCredential(credential) else {
                throw CloudProviderAuthError.googleTokenExchangeFailed(0)
            }
        case .failure(let message):
            throw CloudProviderAuthError.googleAuthorizationDenied(message)
        }
    }

    private func refreshedCredentialIfNeeded(
        _ credential: CloudProviderOAuthCredential
    ) async throws -> CloudProviderOAuthCredential {
        guard credential.isExpiredOrExpiringSoon else { return credential }

        let toolCallID = Self.oauthRefreshToolCallID(for: credential.provider)
        let startedAt = Date()
        recordOAuthRefreshEvent(
            toolCallID: toolCallID,
            kind: .toolCallRequested,
            status: .requested,
            credential: credential
        )

        do {
            let refreshed: CloudProviderOAuthCredential
            switch credential.authMode {
            case .openAICodex:
                refreshed = try await refreshOpenAICredential(credential)
            case .googleGemini:
                refreshed = try await refreshGoogleCredential(credential)
            case .anthropicClaudeCode:
                refreshed = try await refreshAnthropicCredential(credential)
            }
            recordOAuthRefreshEvent(
                toolCallID: toolCallID,
                kind: .toolCallCompleted,
                status: .completed,
                credential: credential,
                refreshedCredential: refreshed,
                durationMs: Self.durationMilliseconds(since: startedAt)
            )
            return refreshed
        } catch {
            recordOAuthRefreshEvent(
                toolCallID: toolCallID,
                kind: .toolCallFailed,
                status: .failed,
                credential: credential,
                durationMs: Self.durationMilliseconds(since: startedAt),
                failureClass: Self.oauthRefreshFailureClass(error),
                errorMessage: "OAuth token refresh failed."
            )
            throw error
        }
    }

    private func recordOAuthRefreshEvent(
        toolCallID: String,
        kind: AgentProvenanceEventKind,
        status: AgentToolEventStatus,
        credential: CloudProviderOAuthCredential,
        refreshedCredential: CloudProviderOAuthCredential? = nil,
        durationMs: UInt64? = nil,
        failureClass: String? = nil,
        errorMessage: String? = nil
    ) {
        guard let agentProvenanceRecorder else { return }

        var metadata = [
            "source": "cloud_provider_auth_service",
            "surface": "oauth_token_refresh",
            "provider": credential.provider.rawValue,
            "auth_mode": credential.authMode.rawValue,
        ]
        if let failureClass {
            metadata["failure_class"] = failureClass
        }

        _ = agentProvenanceRecorder.recordToolEvent(
            runID: Self.oauthRefreshRunID(for: credential.provider),
            traceID: nil,
            kind: kind,
            actor: .agent(id: "cloud-provider-auth-service", modelID: nil),
            toolCallID: toolCallID,
            toolName: "auth.token.refreshed",
            argumentsJSON: Self.oauthRefreshArgumentsJSON(for: credential),
            resultJSON: refreshedCredential.map { Self.oauthRefreshResultJSON(before: credential, after: $0) },
            durationMs: durationMs,
            status: status,
            errorMessage: errorMessage,
            metadata: metadata
        )
    }

    private nonisolated static func oauthRefreshRunID(for provider: CloudModelProvider) -> String {
        "auth-token-refresh-\(provider.rawValue)"
    }

    private nonisolated static func oauthRefreshToolCallID(for provider: CloudModelProvider) -> String {
        "auth-token-refresh:\(provider.rawValue)"
    }

    private nonisolated static func oauthRefreshArgumentsJSON(
        for credential: CloudProviderOAuthCredential
    ) -> String {
        var payload: [String: Any] = [
            "provider": credential.provider.rawValue,
            "auth_mode": credential.authMode.rawValue,
            "previous_token_fingerprint": tokenFingerprint(credential.accessToken),
        ]
        if let previousExpiresAt = iso8601String(credential.effectiveExpiration) {
            payload["previous_expires_at"] = previousExpiresAt
        }
        return sortedJSONString(payload)
    }

    private nonisolated static func oauthRefreshResultJSON(
        before credential: CloudProviderOAuthCredential,
        after refreshedCredential: CloudProviderOAuthCredential
    ) -> String {
        var payload: [String: Any] = [
            "provider": refreshedCredential.provider.rawValue,
            "auth_mode": refreshedCredential.authMode.rawValue,
            "refresh_token_rotated": credential.refreshToken != refreshedCredential.refreshToken,
        ]
        if let newExpiresAt = iso8601String(refreshedCredential.effectiveExpiration) {
            payload["new_expires_at"] = newExpiresAt
        }
        return sortedJSONString(payload)
    }

    private nonisolated static func tokenFingerprint(_ token: String) -> String {
        let digest = SHA256.hash(data: Data(token.utf8))
        return digest.prefix(4).map { String(format: "%02x", $0) }.joined()
    }

    private nonisolated static func sortedJSONString(_ payload: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private nonisolated static func iso8601String(_ date: Date?) -> String? {
        guard let date else { return nil }
        return ISO8601DateFormatter().string(from: date)
    }

    private nonisolated static func durationMilliseconds(since startedAt: Date) -> UInt64 {
        let milliseconds = Date().timeIntervalSince(startedAt) * 1_000
        guard milliseconds.isFinite, milliseconds >= 0 else { return 0 }
        return UInt64(milliseconds.rounded())
    }

    private nonisolated static func oauthRefreshFailureClass(_ error: Error) -> String {
        if error is CloudProviderAuthError {
            return "CloudProviderAuthError"
        }
        if error is URLError {
            return "URLError"
        }
        return String(describing: type(of: error))
    }

    private func refreshOpenAICredential(
        _ credential: CloudProviderOAuthCredential
    ) async throws -> CloudProviderOAuthCredential {
        guard let refreshToken = credential.refreshToken,
              !refreshToken.isEmpty else {
            throw CloudProviderAuthError.missingOAuthRefreshToken(.openAI)
        }

        guard let url = OpenAICodexRuntimeMetadata.url(
            appendingClientVersionTo: "https://auth.openai.com/oauth/token"
        ) else {
            throw CloudProviderAuthError.openAIDeviceCodeRequestFailed
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncodedData([
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": OpenAICodexRuntimeMetadata.clientID,
        ])

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = payload["access_token"] as? String,
              !accessToken.isEmpty else {
            throw CloudProviderAuthError.openAITokenExchangeFailed((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        var updated = credential
        updated.accessToken = accessToken
        let rotatedRefreshToken = (payload["refresh_token"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let rotatedRefreshToken, !rotatedRefreshToken.isEmpty {
            updated.refreshToken = rotatedRefreshToken
        }
        updated.expiresAt = OAuthTokenMetadata.expirationDate(fromJWT: accessToken)
        if updated.accountLabel == nil {
            updated.accountLabel = openAIAccountLabel(fromAccessToken: accessToken)
        }
        _ = storeOAuthCredential(updated)
        return updated
    }

    private func refreshGoogleCredential(
        _ credential: CloudProviderOAuthCredential
    ) async throws -> CloudProviderOAuthCredential {
        guard let refreshToken = credential.refreshToken,
              !refreshToken.isEmpty else {
            throw CloudProviderAuthError.missingOAuthRefreshToken(.google)
        }
        guard let clientID = credential.clientID,
              let clientSecret = credential.clientSecret,
              !clientID.isEmpty,
              !clientSecret.isEmpty else {
            throw CloudProviderAuthError.invalidGoogleClientConfiguration
        }

        guard let tokenURL = URL(string: "https://oauth2.googleapis.com/token") else {
            throw CloudProviderAuthError.invalidGoogleClientConfiguration
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncodedData([
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID,
            "client_secret": clientSecret,
        ])

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = payload["access_token"] as? String,
              !accessToken.isEmpty else {
            throw CloudProviderAuthError.googleTokenExchangeFailed((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        var updated = credential
        updated.accessToken = accessToken
        if let expiresIn = payload["expires_in"] as? TimeInterval {
            updated.expiresAt = Date().addingTimeInterval(expiresIn)
        } else {
            updated.expiresAt = OAuthTokenMetadata.expirationDate(fromJWT: accessToken)
        }
        _ = storeOAuthCredential(updated)
        return updated
    }

    private func refreshAnthropicCredential(
        _ credential: CloudProviderOAuthCredential
    ) async throws -> CloudProviderOAuthCredential {
        guard let refreshToken = credential.refreshToken,
              !refreshToken.isEmpty else {
            throw CloudProviderAuthError.missingOAuthRefreshToken(.anthropic)
        }

        let tokenEndpoints = [
            URL(string: "https://platform.claude.com/v1/oauth/token"),
            URL(string: "https://console.anthropic.com/v1/oauth/token"),
        ].compactMap { $0 }

        for tokenEndpoint in tokenEndpoints {
            var request = URLRequest(url: tokenEndpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(
                "claude-cli/\(Self.anthropicClaudeCodeVersionFallback) (external, cli)",
                forHTTPHeaderField: "User-Agent"
            )
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "grant_type": "refresh_token",
                "refresh_token": refreshToken,
                "client_id": Self.anthropicClaudeCodeClientID,
            ])

            do {
                let (data, response) = try await urlSession.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let accessToken = payload["access_token"] as? String,
                      !accessToken.isEmpty else {
                    continue
                }

                var updated = credential
                updated.accessToken = accessToken
                let rotatedRefreshToken = (payload["refresh_token"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let rotatedRefreshToken, !rotatedRefreshToken.isEmpty {
                    updated.refreshToken = rotatedRefreshToken
                }
                if let expiresIn = payload["expires_in"] as? TimeInterval {
                    updated.expiresAt = Date().addingTimeInterval(expiresIn)
                }
                _ = storeOAuthCredential(updated)
                return updated
            } catch {
                continue
            }
        }

        throw CloudProviderAuthError.anthropicRefreshFailed
    }

    private func requestOpenAIDeviceCode() async throws -> OpenAIDeviceAuthorization {
        guard let url = OpenAICodexRuntimeMetadata.url(
            appendingClientVersionTo: "https://auth.openai.com/api/accounts/deviceauth/usercode"
        ) else {
            throw CloudProviderAuthError.openAIDeviceCodeRequestFailed
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "client_id": OpenAICodexRuntimeMetadata.clientID
        ])

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let userCode = json["user_code"] as? String,
              let deviceAuthID = json["device_auth_id"] as? String else {
            throw CloudProviderAuthError.openAIDeviceCodeRequestFailed
        }

        let interval = max(3, json["interval"] as? Int ?? 5)
        guard let verificationURL = URL(string: "https://auth.openai.com/codex/device") else {
            throw CloudProviderAuthError.openAIDeviceCodeRequestFailed
        }
        return OpenAIDeviceAuthorization(
            userCode: userCode,
            deviceAuthID: deviceAuthID,
            intervalSeconds: interval,
            verificationURL: verificationURL
        )
    }

    private func pollOpenAIDeviceCode(
        _ authorization: OpenAIDeviceAuthorization
    ) async throws -> OpenAIDeviceCodeExchange {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: openAISignInTimeout)
        guard let url = OpenAICodexRuntimeMetadata.url(
            appendingClientVersionTo: "https://auth.openai.com/api/accounts/deviceauth/token"
        ) else {
            throw CloudProviderAuthError.openAIDeviceCodeRequestFailed
        }

        while clock.now < deadline {
            try Task.checkCancellation()
            try await Task.sleep(for: .seconds(authorization.intervalSeconds))

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "device_auth_id": authorization.deviceAuthID,
                "user_code": authorization.userCode,
            ])

            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                continue
            }
            if httpResponse.statusCode == 200,
               let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let authorizationCode = json["authorization_code"] as? String,
               let codeVerifier = json["code_verifier"] as? String {
                return OpenAIDeviceCodeExchange(
                    authorizationCode: authorizationCode,
                    codeVerifier: codeVerifier
                )
            }
            if httpResponse.statusCode == 403 || httpResponse.statusCode == 404 {
                continue
            }
            throw CloudProviderAuthError.openAITokenExchangeFailed(httpResponse.statusCode)
        }

        throw CloudProviderAuthError.openAIDeviceCodeTimedOut
    }

    private func withOpenAITimeout<T: Sendable>(
        _ operation: @escaping @MainActor @Sendable () async throws -> T
    ) async throws -> T {
        let timeout = openAISignInTimeout
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw CloudProviderAuthError.openAIDeviceCodeTimedOut
            }

            do {
                guard let result = try await group.next() else {
                    group.cancelAll()
                    throw CloudProviderAuthError.openAIDeviceCodeTimedOut
                }
                group.cancelAll()
                return result
            } catch {
                group.cancelAll()
                throw error
            }
        }
    }

    private func exchangeOpenAIDeviceCode(
        _ exchange: OpenAIDeviceCodeExchange
    ) async throws -> CloudProviderOAuthCredential {
        guard let url = OpenAICodexRuntimeMetadata.url(
            appendingClientVersionTo: "https://auth.openai.com/oauth/token"
        ) else {
            throw CloudProviderAuthError.openAIDeviceCodeRequestFailed
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncodedData([
            "grant_type": "authorization_code",
            "code": exchange.authorizationCode,
            "redirect_uri": "https://auth.openai.com/deviceauth/callback",
            "client_id": OpenAICodexRuntimeMetadata.clientID,
            "code_verifier": exchange.codeVerifier,
        ])

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            throw CloudProviderAuthError.openAITokenExchangeFailed((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let refreshToken = (json["refresh_token"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return CloudProviderOAuthCredential(
            provider: .openAI,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: OAuthTokenMetadata.expirationDate(fromJWT: accessToken),
            clientID: OpenAICodexRuntimeMetadata.clientID,
            clientSecret: nil,
            projectID: nil,
            authMode: .openAICodex,
            accountLabel: openAIAccountLabel(fromAccessToken: accessToken)
        )
    }

    private func exchangeGoogleAuthorizationCode(
        code: String,
        verifier: String,
        redirectURI: String,
        configuration: GoogleOAuthClientConfiguration
    ) async throws -> CloudProviderOAuthCredential {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            throw CloudProviderAuthError.googleTokenExchangeFailed(0)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncodedData([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": configuration.clientID,
            "client_secret": configuration.clientSecret,
            "code_verifier": verifier,
        ])

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            throw CloudProviderAuthError.googleTokenExchangeFailed((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let refreshToken = (json["refresh_token"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let expiresIn = json["expires_in"] as? TimeInterval

        return CloudProviderOAuthCredential(
            provider: .google,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresIn.map { Date().addingTimeInterval($0) },
            clientID: configuration.clientID,
            clientSecret: configuration.clientSecret,
            projectID: configuration.projectID,
            authMode: .googleGemini,
            accountLabel: nil
        )
    }

    private func fetchGoogleAccountLabel(accessToken: String) async -> String? {
        guard let url = URL(string: "https://www.googleapis.com/oauth2/v2/userinfo") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            return googleAccountLabel(fromUserInfoData: data)
        } catch {
            return nil
        }
    }

    nonisolated func googleAccountLabel(fromUserInfoData data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let candidates = [
            json["email"] as? String,
            json["name"] as? String,
            json["given_name"] as? String,
        ]
        return candidates.compactMap(Self.sanitizedGoogleAccountLabel(_:)).first
    }

    nonisolated func openAIAccountLabel(fromAccessToken token: String) -> String? {
        guard let payload = OAuthTokenMetadata.payload(fromJWT: token) else {
            return nil
        }

        let candidates = [
            payload["email"] as? String,
            payload["preferred_username"] as? String,
            payload["name"] as? String,
        ]
        return candidates.compactMap(Self.sanitizedGoogleAccountLabel(_:)).first
    }

    private nonisolated static func formEncodedData(_ values: [String: String]) -> Data? {
        var components = URLComponents()
        components.queryItems = values.map { key, value in
            URLQueryItem(name: key, value: value)
        }
        return components.percentEncodedQuery?.data(using: .utf8)
    }

    private nonisolated static func inferredAnthropicAccountLabel(from json: Any) -> String? {
        var candidates: [([String], String)] = []
        collectStringCandidates(in: json, path: [], into: &candidates)

        var bestMatch: (score: Int, label: String)?
        for candidate in candidates {
            let path = candidate.0
            let value = candidate.1
            guard let sanitized = sanitizedAnthropicAccountLabel(value) else {
                continue
            }
            let score = anthropicAccountLabelScore(path: path, value: sanitized)
            guard score > 0 else { continue }

            if let currentBest = bestMatch {
                if score > currentBest.score ||
                    (score == currentBest.score && sanitized.count > currentBest.label.count) {
                    bestMatch = (score, sanitized)
                }
            } else {
                bestMatch = (score, sanitized)
            }
        }

        return bestMatch?.label
    }

    private nonisolated static func collectStringCandidates(
        in json: Any,
        path: [String],
        into candidates: inout [([String], String)]
    ) {
        if let dictionary = json as? [String: Any] {
            for (key, value) in dictionary {
                collectStringCandidates(
                    in: value,
                    path: path + [key],
                    into: &candidates
                )
            }
            return
        }

        if let array = json as? [Any] {
            for (index, value) in array.enumerated() {
                collectStringCandidates(
                    in: value,
                    path: path + ["[\(index)]"],
                    into: &candidates
                )
            }
            return
        }

        if let string = json as? String {
            candidates.append((path, string))
        }
    }

    private nonisolated static func anthropicAccountLabelScore(
        path: [String],
        value: String
    ) -> Int {
        let normalizedPath = path.map(normalizedAccountPathComponent(_:))
        let joinedPath = normalizedPath.joined(separator: ".")
        let blockedKeys = [
            "token",
            "secret",
            "client",
            "scope",
            "expires",
            "expiry",
            "verifier",
            "authorization",
            "sessionid",
            "sessionkey",
        ]
        guard blockedKeys.allSatisfy({ !joinedPath.contains($0) }) else {
            return 0
        }

        var score = 0
        if value.contains("@") {
            score += 120
        }
        if joinedPath.contains("email") || joinedPath.contains("mail") {
            score += 90
        }
        if joinedPath.contains("displayname") || joinedPath.contains("fullname") {
            score += 60
        }
        if joinedPath.contains("username") || joinedPath.contains("login") {
            score += 45
        }
        if joinedPath.contains("user") || joinedPath.contains("account") || joinedPath.contains("profile") {
            score += 25
        }
        if joinedPath.contains("claudeaioauth") {
            score -= 40
        }
        if value.contains(" ") {
            score += 4
        }
        return score
    }

    private nonisolated static func normalizedAccountPathComponent(_ component: String) -> String {
        component
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private nonisolated static func sanitizedAnthropicAccountLabel(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 120 else {
            return nil
        }

        let lowered = trimmed.lowercased()
        let blockedPrefixes = ["sk-", "eyj", "bearer "]
        guard blockedPrefixes.allSatisfy({ !lowered.hasPrefix($0) }) else {
            return nil
        }
        guard !trimmed.contains("://"),
              !trimmed.contains("\n"),
              !trimmed.contains("\r") else {
            return nil
        }
        return trimmed
    }

    private nonisolated static func sanitizedGoogleAccountLabel(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= 120,
              !trimmed.contains("\n"),
              !trimmed.contains("\r"),
              !trimmed.contains("://") else {
            return nil
        }
        return trimmed
    }

    private nonisolated static func sha256(data: Data) -> Data {
        return Data(SHA256.hash(data: data))
    }

    private nonisolated static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private nonisolated static func randomURLSafeString(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        if status == errSecSuccess {
            return base64URL(Data(bytes))
        }
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }

    private nonisolated static let anthropicClaudeCodeClientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    private nonisolated static let anthropicClaudeCodeVersionFallback = "2.1.74"
}

struct OpenAIDeviceAuthorization: Sendable, Equatable, Identifiable {
    var id: String { deviceAuthID }
    let userCode: String
    let deviceAuthID: String
    let intervalSeconds: Int
    let verificationURL: URL
}

private struct OpenAIDeviceCodeExchange: Sendable {
    let authorizationCode: String
    let codeVerifier: String
}

private actor LocalOAuthCallbackServer {
    enum AuthorizationResult: Sendable, Equatable {
        case success(String)
        case failure(String)
    }

    private let listener: NWListener
    private(set) var port: UInt16 = 0
    private let path: String
    private var authorizationContinuation: CheckedContinuation<AuthorizationResult, Error>?
    private var didResolve = false
    private var timeoutTask: Task<Void, Never>?

    static func start(path: String) async throws -> LocalOAuthCallbackServer {
        let parameters = NWParameters.tcp
        let listener = try NWListener(using: parameters, on: .any)
        let server = try await LocalOAuthCallbackServer(listener: listener, path: path)
        return server
    }

    private init(listener: NWListener, path: String) async throws {
        self.listener = listener
        self.path = path

        let resumeGate = ContinuationResumeGate()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    resumeGate.resume(continuation: continuation, result: .success(()))
                case .failed(let error):
                    resumeGate.resume(continuation: continuation, result: .failure(error))
                default:
                    break
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                guard let self else { return }
                Task {
                    await self.handle(connection: connection)
                }
            }
            listener.start(queue: DispatchQueue(label: "com.epistemos.auth.callback"))
        }

        guard let listenerPort = listener.port else {
            throw CloudProviderAuthError.callbackServerFailed
        }
        self.port = listenerPort.rawValue
    }

    func currentPort() -> UInt16 {
        port
    }

    func waitForAuthorizationResult(timeout: Duration) async throws -> AuthorizationResult {
        try await withCheckedThrowingContinuation { continuation in
            authorizationContinuation = continuation
            timeoutTask?.cancel()
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: timeout)
                await self?.resolveTimeoutIfNeeded()
            }
        }
    }

    func stop() {
        timeoutTask?.cancel()
        timeoutTask = nil
        listener.cancel()
        resolveFailureIfNeeded(CloudProviderAuthError.googleAuthorizationTimedOut)
    }

    private func handle(connection: NWConnection) async {
        connection.start(queue: DispatchQueue(label: "com.epistemos.auth.callback.connection"))
        do {
            let requestData = try await receiveRequestData(on: connection)
            let authorizationResult = try parseAuthorizationResult(from: requestData)
            try await sendResponse(
                on: connection,
                html: "<html><body><h2>Epistemos connected.</h2><p>You can close this window.</p></body></html>"
            )
            resolve(authorizationResult)
        } catch let error as CloudProviderAuthError {
            try? await sendResponse(
                on: connection,
                html: "<html><body><h2>Epistemos sign-in failed.</h2><p>\(error.localizedDescription)</p></body></html>"
            )
            resolve(.failure(error.localizedDescription))
        } catch {
            try? await sendResponse(
                on: connection,
                html: "<html><body><h2>Epistemos sign-in failed.</h2><p>\(error.localizedDescription)</p></body></html>"
            )
            resolve(.failure(error.localizedDescription))
        }
        connection.cancel()
    }

    private func resolve(_ result: AuthorizationResult) {
        guard !didResolve, let continuation = authorizationContinuation else { return }
        didResolve = true
        authorizationContinuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation.resume(returning: result)
    }

    private func resolveTimeoutIfNeeded() {
        resolveFailureIfNeeded(CloudProviderAuthError.googleAuthorizationTimedOut)
        listener.cancel()
    }

    private func resolveFailureIfNeeded(_ error: Error) {
        guard !didResolve, let continuation = authorizationContinuation else { return }
        didResolve = true
        authorizationContinuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation.resume(throwing: error)
    }

    private func parseAuthorizationResult(from data: Data) throws -> AuthorizationResult {
        guard let requestText = String(data: data, encoding: .utf8),
              let requestLine = requestText.split(separator: "\r\n").first else {
            throw CloudProviderAuthError.callbackServerReceivedInvalidRequest
        }

        let components = requestLine.split(separator: " ")
        guard components.count >= 2 else {
            throw CloudProviderAuthError.callbackServerReceivedInvalidRequest
        }

        let target = String(components[1])
        guard let urlComponents = URLComponents(string: "http://127.0.0.1\(target)"),
              urlComponents.path == path else {
            throw CloudProviderAuthError.callbackServerReceivedInvalidRequest
        }

        if let error = urlComponents.queryItems?.first(where: { $0.name == "error" })?.value {
            let description = urlComponents.queryItems?.first(where: { $0.name == "error_description" })?.value ?? error
            return .failure(description)
        }

        guard let code = urlComponents.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.isEmpty else {
            throw CloudProviderAuthError.callbackServerReceivedInvalidRequest
        }
        return .success(code)
    }

    private func receiveRequestData(on connection: NWConnection) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let buffer = DataBufferAccumulator()

            @Sendable func receiveNextChunk() {
                connection.receive(minimumIncompleteLength: 1, maximumLength: 8_192) { data, _, isComplete, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    if let data {
                        buffer.append(data)
                    }
                    let accumulated = buffer.snapshot()
                    if accumulated.range(of: Data("\r\n\r\n".utf8)) != nil || isComplete {
                        continuation.resume(returning: accumulated)
                        return
                    }
                    receiveNextChunk()
                }
            }

            receiveNextChunk()
        }
    }

    private func sendResponse(on connection: NWConnection, html: String) async throws {
        let bodyData = Data(html.utf8)
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(bodyData.count)\r
        Connection: close\r
        \r
        \(html)
        """

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: Data(response.utf8), completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }
}

private final class ContinuationResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var didResume = false

    nonisolated func resume(
        continuation: CheckedContinuation<Void, Error>,
        result: Result<Void, Error>
    ) {
        lock.lock()
        guard !didResume else {
            lock.unlock()
            return
        }
        didResume = true
        lock.unlock()

        switch result {
        case .success:
            continuation.resume(returning: ())
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}

private final class DataBufferAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var buffer = Data()

    nonisolated func append(_ data: Data) {
        lock.lock()
        buffer.append(data)
        lock.unlock()
    }

    nonisolated func snapshot() -> Data {
        lock.lock()
        let value = buffer
        lock.unlock()
        return value
    }
}
