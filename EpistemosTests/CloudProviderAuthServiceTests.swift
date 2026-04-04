import Foundation
import Testing
@testable import Epistemos

@Suite("Cloud Provider Auth Service")
struct CloudProviderAuthServiceTests {
    @Test("Google desktop client secret JSON parses installed credentials")
    func googleDesktopClientSecretParsesInstalledCredentials() throws {
        let json = """
        {
          "installed": {
            "client_id": "desktop-client-id.apps.googleusercontent.com",
            "project_id": "epistemos-auth-project",
            "client_secret": "desktop-client-secret",
            "redirect_uris": [
              "http://127.0.0.1"
            ]
          }
        }
        """

        let data = try #require(json.data(using: .utf8))
        let configuration = try GoogleOAuthClientConfiguration.parse(from: data)

        #expect(configuration.clientID == "desktop-client-id.apps.googleusercontent.com")
        #expect(configuration.clientSecret == "desktop-client-secret")
        #expect(configuration.projectID == "epistemos-auth-project")
    }

    @Test("Google desktop client secret JSON can omit project ID until the user enters it separately")
    func googleDesktopClientSecretAllowsMissingProjectID() throws {
        let json = """
        {
          "installed": {
            "client_id": "desktop-client-id.apps.googleusercontent.com",
            "client_secret": "desktop-client-secret",
            "redirect_uris": [
              "http://127.0.0.1"
            ]
          }
        }
        """

        let data = try #require(json.data(using: .utf8))
        let configuration = try GoogleOAuthClientConfiguration.parse(from: data)

        #expect(configuration.clientID == "desktop-client-id.apps.googleusercontent.com")
        #expect(configuration.clientSecret == "desktop-client-secret")
        #expect(configuration.projectID.isEmpty)
    }

    @Test("JWT expiration decoder reads exp claim from OAuth access token")
    func jwtExpirationDecoderReadsExpClaim() throws {
        let expiration = Date(timeIntervalSince1970: 1_777_777_777)
        let token = makeJWT(expiration: expiration)

        let decoded = OAuthTokenMetadata.expirationDate(fromJWT: token)

        #expect(decoded == expiration)
    }

    @MainActor
    @Test("oauth-backed cloud providers count as configured access")
    func oauthBackedCloudProvidersCountAsConfiguredAccess() throws {
        let expiration = Date(timeIntervalSince1970: 1_888_888_888)
        let credential = CloudProviderOAuthCredential(
            provider: .openAI,
            accessToken: makeJWT(expiration: expiration),
            refreshToken: "refresh-token",
            expiresAt: expiration,
            clientID: "codex-client-id",
            clientSecret: nil,
            projectID: nil,
            authMode: .openAICodex,
            accountLabel: "chatgpt@example.com"
        )
        let encoded = try JSONEncoder().encode(credential)
        let encodedString = try #require(String(data: encoded, encoding: .utf8))

        var keychainValues: [String: String] = [
            CloudModelProvider.openAI.oauthKeychainKey: encodedString
        ]

        let inference = InferenceState(
            keychainLoad: { keychainValues[$0] },
            keychainSave: { value, key in
                keychainValues[key] = value
                return true
            },
            keychainDelete: { keychainValues.removeValue(forKey: $0) }
        )

        #expect(inference.configuredCloudProviders.contains(.openAI))
        #expect(inference.hasConfiguredCloudModels)
        #expect(!inference.shouldShowCloudSetupHint)
    }

    @MainActor
    @Test("OpenAI sign-in times out instead of checking forever")
    func openAISignInTimesOutInsteadOfCheckingForever() async throws {
        let session = makeURLSession { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }
            let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
            let clientVersion = components.queryItems?
                .first(where: { $0.name == "client_version" })?
                .value

            let response: HTTPURLResponse
            let data: Data
            switch url.path {
            case "/api/accounts/deviceauth/usercode":
                #expect(clientVersion == OpenAICodexRuntimeMetadata.clientVersion)
                response = try #require(
                    HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
                )
                data = """
                {
                  "user_code": "ABCD-EFGH",
                  "device_auth_id": "device-auth-id",
                  "interval": 5
                }
                """.data(using: .utf8) ?? Data()
            default:
                throw URLError(.unsupportedURL)
            }

            return (response, data)
        }

        var didPersistCredential = false
        let service = CloudProviderAuthService(
            keychainLoad: { _ in nil },
            keychainSave: { _, _ in
                didPersistCredential = true
                return true
            },
            keychainDelete: { _ in },
            urlSession: session,
            openAISignInTimeout: .milliseconds(50)
        )

        do {
            try await service.signInToOpenAI(openURL: { _ in })
            Issue.record("Expected OpenAI sign-in to time out instead of remaining in checking.")
        } catch let error as CloudProviderAuthError {
            switch error {
            case .openAIDeviceCodeTimedOut:
                break
            default:
                Issue.record("Expected OpenAI device-code timeout, got \(error.localizedDescription).")
            }
        } catch {
            Issue.record("Expected CloudProviderAuthError.openAIDeviceCodeTimedOut, got \(error).")
        }

        #expect(!didPersistCredential)
    }

    @MainActor
    @Test("OpenAI account validation requests include the Codex client version")
    func openAIAccountValidationRequestsIncludeCodexClientVersion() async throws {
        let expiration = Date(timeIntervalSinceNow: 3_600)
        let credential = CloudProviderOAuthCredential(
            provider: .openAI,
            accessToken: makeJWT(expiration: expiration),
            refreshToken: "refresh-token",
            expiresAt: expiration,
            clientID: OpenAICodexRuntimeMetadata.clientID,
            clientSecret: nil,
            projectID: nil,
            authMode: .openAICodex,
            accountLabel: "chatgpt@example.com"
        )
        let encoded = try JSONEncoder().encode(credential)
        let encodedString = try #require(String(data: encoded, encoding: .utf8))

        var keychainValues: [String: String] = [
            CloudModelProvider.openAI.oauthKeychainKey: encodedString
        ]

        let inference = InferenceState(
            keychainLoad: { keychainValues[$0] },
            keychainSave: { value, key in
                keychainValues[key] = value
                return true
            },
            keychainDelete: { keychainValues.removeValue(forKey: $0) }
        )
        let session = makeURLSession { request in
            let url = try #require(request.url)
            #expect(url.path == "/backend-api/codex/models")
            let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
            let clientVersion = components.queryItems?
                .first(where: { $0.name == "client_version" })?
                .value
            #expect(clientVersion == OpenAICodexRuntimeMetadata.clientVersion)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(credential.accessToken)")

            let response = try #require(
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            )
            let data = """
            {
              "data": [
                { "id": "gpt-4.1-mini" }
              ]
            }
            """.data(using: .utf8) ?? Data()
            return (response, data)
        }

        let client = CloudLLMClient(inference: inference, urlSession: session)
        let result = await client.testConnection(provider: .openAI)

        #expect(result.success)
    }

    @MainActor
    @Test("OpenAI account response requests include the Codex client version")
    func openAIAccountResponseRequestsIncludeCodexClientVersion() async throws {
        let expiration = Date(timeIntervalSinceNow: 3_600)
        let credential = CloudProviderOAuthCredential(
            provider: .openAI,
            accessToken: makeJWT(expiration: expiration),
            refreshToken: "refresh-token",
            expiresAt: expiration,
            clientID: OpenAICodexRuntimeMetadata.clientID,
            clientSecret: nil,
            projectID: nil,
            authMode: .openAICodex,
            accountLabel: "chatgpt@example.com"
        )
        let encoded = try JSONEncoder().encode(credential)
        let encodedString = try #require(String(data: encoded, encoding: .utf8))

        var keychainValues: [String: String] = [
            CloudModelProvider.openAI.oauthKeychainKey: encodedString
        ]

        let inference = InferenceState(
            keychainLoad: { keychainValues[$0] },
            keychainSave: { value, key in
                keychainValues[key] = value
                return true
            },
            keychainDelete: { keychainValues.removeValue(forKey: $0) }
        )
        let session = makeURLSession { request in
            let url = try #require(request.url)
            #expect(url.path == "/backend-api/codex/responses")
            let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
            let clientVersion = components.queryItems?
                .first(where: { $0.name == "client_version" })?
                .value
            #expect(clientVersion == OpenAICodexRuntimeMetadata.clientVersion)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(credential.accessToken)")

            let response = try #require(
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            )
            let data = """
            {
              "output_text": "OK"
            }
            """.data(using: .utf8) ?? Data()
            return (response, data)
        }

        let client = CloudLLMClient(inference: inference, urlSession: session)
        let result = await client.testConnection(provider: .openAI, model: .openAIGPT41Mini)

        #expect(result.success)
    }

    @Test("OpenAI access token parser captures the connected account email")
    func openAIAccessTokenParserCapturesConnectedAccountEmail() throws {
        let expiration = Date(timeIntervalSince1970: 1_888_888_888)
        let token = makeJWT(
            expiration: expiration,
            additionalClaims: [
                "email": "chatgpt-user@example.com",
                "name": "ChatGPT User",
            ]
        )
        let service = CloudProviderAuthService(
            keychainLoad: { _ in nil },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )

        let accountLabel = service.openAIAccountLabel(fromAccessToken: token)

        #expect(accountLabel == "chatgpt-user@example.com")
    }

    @Test("OpenAI client version errors surface readable recovery guidance")
    func openAIClientVersionErrorsSurfaceReadableRecoveryGuidance() {
        let body = """
        {
          "error": {
            "message": "[{'type': 'missing', 'loc': ('query', 'client_version'), 'msg': 'Field required', 'input': None}]",
            "type": "invalid_request_error",
            "param": null,
            "code": null
          }
        }
        """

        let error = LLMError.apiError(statusCode: 400, body: body)

        #expect(
            error.errorDescription
                == "OpenAI account setup is missing a required client version marker. Retry OpenAI sign-in and then run the live check again."
        )
    }

    @Test("Anthropic Claude Code import captures the connected account label when present")
    func anthropicClaudeCodeImportCapturesConnectedAccountLabelWhenPresent() throws {
        let json = """
        {
          "claudeAiOauth": {
            "accessToken": "anthropic-access-token",
            "refreshToken": "anthropic-refresh-token",
            "expiresAt": 1777777777000
          },
          "user": {
            "email": "claude-user@example.com",
            "displayName": "Claude User"
          }
        }
        """

        let data = try #require(json.data(using: .utf8))
        let service = CloudProviderAuthService(
            keychainLoad: { _ in nil },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )

        let credential = service.anthropicClaudeCodeCredential(from: data)

        #expect(credential?.provider == .anthropic)
        #expect(credential?.refreshToken == "anthropic-refresh-token")
        #expect(credential?.accountLabel == "claude-user@example.com")
    }

    @Test("Google sign-in times out instead of checking forever")
    func googleSignInTimesOutInsteadOfCheckingForever() async throws {
        let service = CloudProviderAuthService(
            keychainLoad: { _ in nil },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in },
            googleSignInTimeout: .milliseconds(50)
        )
        let configuration = GoogleOAuthClientConfiguration(
            clientID: "desktop-client-id.apps.googleusercontent.com",
            clientSecret: "desktop-client-secret",
            projectID: "epistemos-auth-project"
        )

        do {
            try await service.signInToGoogle(configuration: configuration, openURL: { _ in })
            Issue.record("Expected Google OAuth sign-in to time out instead of remaining in checking.")
        } catch let error as CloudProviderAuthError {
            switch error {
            case .googleAuthorizationTimedOut:
                break
            default:
                Issue.record("Expected Google OAuth timeout, got \(error.localizedDescription).")
            }
        } catch {
            Issue.record("Expected CloudProviderAuthError.googleAuthorizationTimedOut, got \(error).")
        }
    }

    @Test("Google user info parser captures the connected account email")
    func googleUserInfoParserCapturesConnectedAccountEmail() throws {
        let json = """
        {
          "sub": "1234567890",
          "email": "google-user@example.com",
          "email_verified": true,
          "name": "Google User"
        }
        """

        let data = try #require(json.data(using: .utf8))
        let service = CloudProviderAuthService(
            keychainLoad: { _ in nil },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )

        let accountLabel = service.googleAccountLabel(fromUserInfoData: data)

        #expect(accountLabel == "google-user@example.com")
    }

    private func makeJWT(
        expiration: Date,
        additionalClaims: [String: String] = [:]
    ) -> String {
        let header: [String: Any] = ["alg": "none", "typ": "JWT"]
        var payload: [String: Any] = ["exp": Int(expiration.timeIntervalSince1970)]
        for (key, value) in additionalClaims {
            payload[key] = value
        }

        let headerData = (try? JSONSerialization.data(withJSONObject: header)) ?? Data()
        let payloadData = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()

        return [
            base64URL(headerData),
            base64URL(payloadData),
            ""
        ].joined(separator: ".")
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func makeURLSession(
        handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> URLSession {
        CloudProviderAuthServiceTestURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CloudProviderAuthServiceTestURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private nonisolated final class CloudProviderAuthServiceTestURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
