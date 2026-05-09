import Foundation
import Testing
@testable import Epistemos

@MainActor
private func makeInferenceState(keychainValues: [String: String] = [:]) -> InferenceState {
    let store = TestKeychainStore(values: keychainValues)
    return InferenceState(
        keychainLoad: store.load(_:),
        keychainSave: store.save(_:_:),
        keychainDelete: store.delete(_:)
    )
}

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

        let inference = makeInferenceState(keychainValues: [
            CloudModelProvider.openAI.oauthKeychainKey: encodedString
        ])

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

        let didPersistCredential = LockedFlag()
        let service = CloudProviderAuthService(
            keychainLoad: { _ in nil },
            keychainSave: { _, _ in
                didPersistCredential.setTrue()
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

        #expect(!didPersistCredential.isSet)
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

        let inference = makeInferenceState(keychainValues: [
            CloudModelProvider.openAI.oauthKeychainKey: encodedString
        ])
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
              "models": [
                { "slug": "gpt-5.4-mini" },
                { "slug": "gpt-5.4" },
                { "slug": "gpt-5.2" }
              ]
            }
            """.data(using: .utf8) ?? Data()
            return (response, data)
        }

        let client = CloudLLMClient(inference: inference, urlSession: session)
        let result = await client.testConnection(provider: .openAI)

        #expect(result.success)
    }

    @Test("agent core environment overrides carry OpenAI Codex access through to Rust")
    func agentCoreEnvironmentOverridesCarryOpenAICodexAccessThroughToRust() throws {
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

        let overrides = AppBootstrap.agentCoreEnvironmentOverrides { key in
            if key == CloudModelProvider.openAI.oauthKeychainKey {
                return encodedString
            }
            return nil
        }

        #expect(overrides["OPENAI_ACCESS_TOKEN"] == credential.accessToken)
        #expect(overrides["OPENAI_AUTH_MODE"] == "codex")
        #expect(overrides["OPENAI_CLIENT_VERSION"] == OpenAICodexRuntimeMetadata.clientVersion)
    }

    @MainActor
    @Test("OpenAI account generate falls back to Codex streaming requests and a supported model")
    func openAIAccountGenerateFallsBackToCodexStreamingRequests() async throws {
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

        let inference = makeInferenceState(keychainValues: [
            CloudModelProvider.openAI.oauthKeychainKey: encodedString
        ])
        let session = makeURLSession { request in
            let url = try #require(request.url)
            #expect(url.path == "/backend-api/codex/responses")
            let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
            let clientVersion = components.queryItems?
                .first(where: { $0.name == "client_version" })?
                .value
            #expect(clientVersion == OpenAICodexRuntimeMetadata.clientVersion)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(credential.accessToken)")
            #expect(request.httpBody != nil || request.httpBodyStream != nil)

            let response = try #require(
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            )
            let data = """
            event: response.output_text.delta
            data: {"type":"response.output_text.delta","delta":"Hello"}

            event: response.output_text.delta
            data: {"type":"response.output_text.delta","delta":" there"}

            event: response.completed
            data: {"type":"response.completed"}

            """.data(using: .utf8) ?? Data()
            return (response, data)
        }

        let client = CloudLLMClient(inference: inference, urlSession: session)
        let result = try await client.generate(
            prompt: "Say hello in exactly two words.",
            systemPrompt: nil,
            maxTokens: 16,
            model: .openAIGPT41Mini
        )

        #expect(result == "Hello there")
    }

    @MainActor
    @Test("OpenAI API requests carry native GPT-5.4 controls for pro work")
    func openAIAPIRequestsCarryNativeGPT54ControlsForProWork() async throws {
        let inference = makeInferenceState(keychainValues: [
            CloudModelProvider.openAI.apiKeyKeychainKey: "sk-openai-test"
        ])
        inference.setChatReasoningTier(.off)
        let session = makeURLSession { request in
            let url = try #require(request.url)
            #expect(url.path == "/v1/responses")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-openai-test")

            let bodyData = try self.requestBodyData(from: request)
            let json = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
            #expect(json["model"] as? String == CloudTextModelID.openAIGPT54.vendorModelID)

            let reasoning = try #require(json["reasoning"] as? [String: Any])
            #expect(reasoning["effort"] as? String == "high")

            let text = try #require(json["text"] as? [String: Any])
            #expect(text["verbosity"] as? String == "medium")

            let response = try #require(
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            )
            let data = """
            {
              "output_text": "done"
            }
            """.data(using: .utf8) ?? Data()
            return (response, data)
        }

        let client = CloudLLMClient(inference: inference, urlSession: session)
        _ = try await client.generate(
            prompt: "Explain the architecture tradeoffs.",
            systemPrompt: nil,
            maxTokens: 256,
            model: .openAIGPT54,
            operatingMode: .pro
        )
    }

    @MainActor
    @Test("OpenAI API pro mode ignores a saved off tier and still requests the higher reasoning route")
    func openAIAPIProModeStillRequestsHighReasoningWhenSavedTierIsOff() async throws {
        let inference = makeInferenceState(keychainValues: [
            CloudModelProvider.openAI.apiKeyKeychainKey: "sk-openai-test"
        ])
        inference.setChatReasoningTier(.off)
        let session = makeURLSession { request in
            let bodyData = try self.requestBodyData(from: request)
            let json = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
            let reasoning = try #require(json["reasoning"] as? [String: Any])
            #expect(reasoning["effort"] as? String == "high")
            #expect(reasoning["summary"] as? String == "auto")

            let text = try #require(json["text"] as? [String: Any])
            #expect(text["verbosity"] as? String == "medium")

            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            )
            let data = """
            {
              "output_text": "done"
            }
            """.data(using: .utf8) ?? Data()
            return (response, data)
        }

        let client = CloudLLMClient(inference: inference, urlSession: session)
        _ = try await client.generate(
            prompt: "Give me the rigorous version.",
            systemPrompt: nil,
            maxTokens: 256,
            model: .openAIGPT54,
            operatingMode: .pro
        )
    }

    @MainActor
    @Test("OpenAI API thinking route keeps GPT-5.4 instead of silently swapping to o3")
    func openAIAPIThinkingRouteKeepsGPT54() async throws {
        let inference = makeInferenceState(keychainValues: [
            CloudModelProvider.openAI.apiKeyKeychainKey: "sk-openai-test"
        ])
        let session = makeURLSession { request in
            let url = try #require(request.url)
            let bodyData = try self.requestBodyData(from: request)
            let json = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
            #expect(json["model"] as? String == CloudTextModelID.openAIGPT54.vendorModelID)

            let reasoning = try #require(json["reasoning"] as? [String: Any])
            #expect(reasoning["effort"] as? String == "medium")

            let text = try #require(json["text"] as? [String: Any])
            #expect(text["verbosity"] as? String == "medium")

            let response = try #require(
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            )
            let data = """
            {
              "output_text": "thoughtful"
            }
            """.data(using: .utf8) ?? Data()
            return (response, data)
        }

        let client = CloudLLMClient(inference: inference, urlSession: session)
        _ = try await client.generate(
            prompt: "Reason through the migration plan.",
            systemPrompt: nil,
            maxTokens: 256,
            model: .openAIGPT54,
            operatingMode: .thinking
        )
    }

    @MainActor
    @Test("OpenAI API requests omit json_object mode when web search is enabled")
    func openAIAPIRequestsOmitJSONModeWhenWebSearchIsEnabled() async throws {
        let inference = makeInferenceState(keychainValues: [
            CloudModelProvider.openAI.apiKeyKeychainKey: "sk-openai-test"
        ])
        inference.setChatReasoningTier(.off)
        inference.setStructuredJSONOutputEnabled(true)
        inference.setOpenAIWebSearchEnabled(true)

        let session = makeURLSession { request in
            let url = try #require(request.url)
            #expect(url.path == "/v1/responses")

            let bodyData = try self.requestBodyData(from: request)
            let json = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])

            let tools = try #require(json["tools"] as? [[String: Any]])
            #expect(tools.count == 1)
            #expect(tools[0]["type"] as? String == "web_search")

            let text = try #require(json["text"] as? [String: Any])
            #expect(text["verbosity"] as? String == "low")
            #expect(text["format"] == nil)

            let response = try #require(
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            )
            let data = """
            {
              "output_text": "search-ready"
            }
            """.data(using: .utf8) ?? Data()
            return (response, data)
        }

        let client = CloudLLMClient(inference: inference, urlSession: session)
        let result = try await client.generate(
            prompt: "Find the latest release notes.",
            systemPrompt: nil,
            maxTokens: 128,
            model: .openAIGPT54,
            operatingMode: .fast
        )

        #expect(result == "search-ready")
    }

    @MainActor
    @Test("OpenAI structured generation drops web search when JSON schema is required")
    func openAIStructuredGenerationDropsWebSearchWhenJSONSchemaIsRequired() async throws {
        let inference = makeInferenceState(keychainValues: [
            CloudModelProvider.openAI.apiKeyKeychainKey: "sk-openai-test"
        ])
        inference.setOpenAIWebSearchEnabled(true)

        let session = makeURLSession { request in
            let url = try #require(request.url)
            #expect(url.path == "/v1/responses")

            let bodyData = try self.requestBodyData(from: request)
            let json = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
            #expect(json["tools"] == nil)

            let text = try #require(json["text"] as? [String: Any])
            let format = try #require(text["format"] as? [String: Any])
            #expect(format["type"] as? String == "json_schema")
            #expect(format["name"] as? String == "search_payload")

            let response = try #require(
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            )
            let data = """
            {
              "output_text": "{\\"answer\\":\\"ok\\"}"
            }
            """.data(using: .utf8) ?? Data()
            return (response, data)
        }

        let client = CloudLLMClient(inference: inference, urlSession: session)
        let result = try await client.generateStructured(
            prompt: "Return JSON only.",
            systemPrompt: nil,
            maxTokens: 32,
            model: .openAIGPT54Mini,
            schema: CloudJSONSchema(
                name: "search_payload",
                description: nil,
                schema: [
                    "type": "object",
                    "properties": [
                        "answer": ["type": "string"]
                    ],
                    "required": ["answer"],
                    "additionalProperties": false,
                ],
                strict: true
            ),
            type: [String: String].self
        )

        #expect(result.value == ["answer": "ok"])
    }

    @MainActor
    @Test("OpenAI Codex account requests carry native GPT-5 controls for thinking and pro work")
    func openAICodexRequestsCarryNativeGPT54Controls() async throws {
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

        let inference = makeInferenceState(keychainValues: [
            CloudModelProvider.openAI.oauthKeychainKey: encodedString
        ])
        let session = makeURLSession { request in
            let url = try #require(request.url)
            #expect(url.path == "/backend-api/codex/responses")

            let bodyData = try self.requestBodyData(from: request)
            let json = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
            #expect(json["model"] as? String == CloudTextModelID.openAIGPT54.vendorModelID)
            let reasoning = try #require(json["reasoning"] as? [String: Any])
            #expect(reasoning["effort"] as? String == "high")
            #expect(reasoning["summary"] as? String == "auto")

            let text = try #require(json["text"] as? [String: Any])
            #expect(text["verbosity"] as? String == "medium")

            let response = try #require(
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            )
            let data = """
            event: response.output_text.delta
            data: {"type":"response.output_text.delta","delta":"clean"}

            event: response.completed
            data: {"type":"response.completed"}

            """.data(using: .utf8) ?? Data()
            return (response, data)
        }

        let client = CloudLLMClient(inference: inference, urlSession: session)
        _ = try await client.generate(
            prompt: "Write a polished answer.",
            systemPrompt: nil,
            maxTokens: 256,
            model: .openAIGPT54,
            operatingMode: .pro
        )
    }

    @MainActor
    @Test("OpenAI Codex agent mode preserves low-effort selections instead of collapsing them to standard")
    func openAICodexAgentModePreservesLowEffortSelection() async throws {
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

        let inference = makeInferenceState(keychainValues: [
            CloudModelProvider.openAI.oauthKeychainKey: encodedString
        ])
        inference.setActiveAIProvider(.openAI)
        inference.setPreferredChatModelSelection(.cloud(.openAIGPT54))
        inference.setChatReasoningTier(.low, for: .agent)

        let session = makeURLSession { request in
            let url = try #require(request.url)
            #expect(url.path == "/backend-api/codex/responses")

            let bodyData = try self.requestBodyData(from: request)
            let json = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
            #expect(json["model"] as? String == CloudTextModelID.openAIGPT54.vendorModelID)
            let reasoning = try #require(json["reasoning"] as? [String: Any])
            #expect(reasoning["effort"] as? String == "low")
            #expect(reasoning["summary"] as? String == "auto")

            let text = try #require(json["text"] as? [String: Any])
            #expect(text["verbosity"] as? String == "low")

            let response = try #require(
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            )
            let data = """
            event: response.output_text.delta
            data: {"type":"response.output_text.delta","delta":"clean"}

            event: response.completed
            data: {"type":"response.completed"}

            """.data(using: .utf8) ?? Data()
            return (response, data)
        }

        let client = CloudLLMClient(inference: inference, urlSession: session)
        _ = try await client.generate(
            prompt: "Handle this as an agent task.",
            systemPrompt: nil,
            maxTokens: 256,
            model: .openAIGPT54,
            operatingMode: .agent
        )
    }

    @MainActor
    @Test("OpenAI account structured generation streams Codex JSON schema output")
    func openAIAccountStructuredGenerationStreamsCodexJSONSchemaOutput() async throws {
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

        let inference = makeInferenceState(keychainValues: [
            CloudModelProvider.openAI.oauthKeychainKey: encodedString
        ])
        let session = makeURLSession { request in
            let url = try #require(request.url)
            #expect(url.path == "/backend-api/codex/responses")
            #expect(request.httpBody != nil || request.httpBodyStream != nil)

            let response = try #require(
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            )
            let data = """
            event: response.output_text.delta
            data: {"type":"response.output_text.delta","delta":"{\\"answer\\":\\"ok\\"}"}

            event: response.completed
            data: {"type":"response.completed"}

            """.data(using: .utf8) ?? Data()
            return (response, data)
        }

        let client = CloudLLMClient(inference: inference, urlSession: session)
        let result = try await client.generateStructured(
            prompt: "Return JSON only.",
            systemPrompt: nil,
            maxTokens: 32,
            model: .openAIGPT54Mini,
            schema: CloudJSONSchema(
                name: "codex_payload",
                description: nil,
                schema: [
                    "type": "object",
                    "properties": [
                        "answer": ["type": "string"]
                    ],
                    "required": ["answer"],
                    "additionalProperties": false,
                ],
                strict: true
            ),
            type: [String: String].self
        )

        #expect(result.value == ["answer": "ok"])
        #expect(result.rawJSON == #"{"answer":"ok"}"#)
    }

    @MainActor
    @Test("OpenAI Codex account hides unsupported OpenAI models from the active picker")
    func openAICodexAccountHidesUnsupportedOpenAIModelsFromActivePicker() async throws {
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

        let inference = InferenceState(
            keychainLoad: { key in
                key == CloudModelProvider.openAI.oauthKeychainKey ? encodedString : nil
            },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )

        inference.setActiveAIProvider(.openAI)

        #expect(inference.activeCloudModels == [.openAIGPT54, .openAIGPT54Mini])
    }

    @MainActor
    @Test("OpenAI Codex account maps fallback chains onto supported GPT-5 models")
    func openAICodexAccountMapsFallbackChainsOntoSupportedGPT5Models() async throws {
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

        let inference = InferenceState(
            keychainLoad: { key in
                key == CloudModelProvider.openAI.oauthKeychainKey ? encodedString : nil
            },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )
        inference.setActiveAIProvider(.openAI)
        inference.setPreferredChatModelSelection(.cloud(.openAIGPT54))

        let fastChain = inference.cloudFallbackChain(for: .fast)
        let thinkingChain = inference.cloudFallbackChain(for: .thinking)
        let agentChain = inference.cloudFallbackChain(for: .agent)

        #expect(fastChain.first == .openAIGPT54)
        #expect(thinkingChain.first == .openAIGPT54)
        #expect(agentChain.first == .openAIGPT54)
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

    private nonisolated func requestBodyData(from request: URLRequest) throws -> Data {
        if let data = request.httpBody {
            return data
        }
        guard let stream = request.httpBodyStream else {
            throw URLError(.badServerResponse)
        }
        stream.open()
        defer { stream.close() }

        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var data = Data()
        while stream.hasBytesAvailable {
            let readCount = stream.read(buffer, maxLength: bufferSize)
            if readCount < 0 {
                throw stream.streamError ?? URLError(.cannotDecodeRawData)
            }
            if readCount == 0 {
                break
            }
            data.append(buffer, count: readCount)
        }
        return data
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

@MainActor
@Suite("Cloud Provider Agent Environment", .serialized)
struct CloudProviderAgentEnvironmentTests {
    private let managedEnvVars = [
        "OPENAI_ACCESS_TOKEN",
        "OPENAI_AUTH_MODE",
        "OPENAI_CLIENT_VERSION",
        "ANTHROPIC_ACCESS_TOKEN",
        "ANTHROPIC_AUTH_MODE",
        "GOOGLE_ACCESS_TOKEN",
        "GOOGLE_AUTH_MODE",
        "GOOGLE_PROJECT_ID",
    ]

    @Test("agent core environment overrides carry Anthropic and Google OAuth through to Rust")
    func agentCoreEnvironmentOverridesCarryAnthropicAndGoogleOAuthThroughToRust() throws {
        let expiration = Date(timeIntervalSinceNow: 3_600)
        let anthropicCredential = try encodedCredential(
            CloudProviderOAuthCredential(
                provider: .anthropic,
                accessToken: "anthropic-oauth-token",
                refreshToken: "anthropic-refresh-token",
                expiresAt: expiration,
                clientID: nil,
                clientSecret: nil,
                projectID: nil,
                authMode: .anthropicClaudeCode,
                accountLabel: "claude-user@example.com"
            )
        )
        let googleCredential = try encodedCredential(
            CloudProviderOAuthCredential(
                provider: .google,
                accessToken: "google-oauth-token",
                refreshToken: "google-refresh-token",
                expiresAt: expiration,
                clientID: "desktop-client-id.apps.googleusercontent.com",
                clientSecret: "desktop-client-secret",
                projectID: "epistemos-auth-project",
                authMode: .googleGemini,
                accountLabel: "google-user@example.com"
            )
        )

        let overrides = AppBootstrap.agentCoreEnvironmentOverrides { key in
            if key == CloudModelProvider.anthropic.oauthKeychainKey {
                return anthropicCredential
            }
            if key == CloudModelProvider.google.oauthKeychainKey {
                return googleCredential
            }
            return nil
        }

        #expect(overrides["ANTHROPIC_ACCESS_TOKEN"] == "anthropic-oauth-token")
        #expect(overrides["ANTHROPIC_AUTH_MODE"] == "oauth")
        #expect(overrides["GOOGLE_ACCESS_TOKEN"] == "google-oauth-token")
        #expect(overrides["GOOGLE_AUTH_MODE"] == "oauth")
        #expect(overrides["GOOGLE_PROJECT_ID"] == "epistemos-auth-project")
    }

    @Test("agent core environment overrides carry API-key cloud providers through to Rust")
    func agentCoreEnvironmentOverridesCarryAPIKeyCloudProvidersThroughToRust() {
        let overrides = AppBootstrap.agentCoreEnvironmentOverrides { key in
            switch key {
            case CloudModelProvider.deepseek.apiKeyKeychainKey:
                return "deepseek-api-key"
            case CloudModelProvider.zai.apiKeyKeychainKey:
                return "glm-api-key"
            case CloudModelProvider.kimi.apiKeyKeychainKey:
                return "kimi-api-key"
            case CloudModelProvider.minimax.apiKeyKeychainKey:
                return "minimax-api-key"
            default:
                return nil
            }
        }

        #expect(overrides["DEEPSEEK_API_KEY"] == "deepseek-api-key")
        #expect(overrides["GLM_API_KEY"] == "glm-api-key")
        #expect(overrides["KIMI_API_KEY"] == "kimi-api-key")
        #expect(overrides["MINIMAX_API_KEY"] == "minimax-api-key")
    }

    @Test("refreshing cached cloud credentials does not mirror secrets into the parent environment")
    func refreshingCachedCloudCredentialsDoesNotMirrorSecretsIntoParentEnvironment() throws {
        let savedEnvironment = Dictionary(uniqueKeysWithValues: managedEnvVars.map {
            ($0, processEnvironmentValue(for: $0))
        })
        defer {
            for (name, value) in savedEnvironment {
                setProcessEnvironmentValue(value, for: name)
            }
        }

        for envVar in managedEnvVars {
            setProcessEnvironmentValue(nil, for: envVar)
        }

        let expiration = Date(timeIntervalSinceNow: 3_600)
        let openAICredential = try encodedCredential(
            CloudProviderOAuthCredential(
                provider: .openAI,
                accessToken: makeJWT(expiration: expiration),
                refreshToken: "openai-refresh-token",
                expiresAt: expiration,
                clientID: OpenAICodexRuntimeMetadata.clientID,
                clientSecret: nil,
                projectID: nil,
                authMode: .openAICodex,
                accountLabel: "chatgpt@example.com"
            )
        )
        let anthropicCredential = try encodedCredential(
            CloudProviderOAuthCredential(
                provider: .anthropic,
                accessToken: "anthropic-oauth-token",
                refreshToken: "anthropic-refresh-token",
                expiresAt: expiration,
                clientID: nil,
                clientSecret: nil,
                projectID: nil,
                authMode: .anthropicClaudeCode,
                accountLabel: "claude-user@example.com"
            )
        )
        let googleCredential = try encodedCredential(
            CloudProviderOAuthCredential(
                provider: .google,
                accessToken: "google-oauth-token",
                refreshToken: "google-refresh-token",
                expiresAt: expiration,
                clientID: "desktop-client-id.apps.googleusercontent.com",
                clientSecret: "desktop-client-secret",
                projectID: "epistemos-auth-project",
                authMode: .googleGemini,
                accountLabel: "google-user@example.com"
            )
        )

        _ = InferenceState(
            keychainLoad: { key in
                if key == CloudModelProvider.openAI.oauthKeychainKey {
                    return openAICredential
                }
                if key == CloudModelProvider.anthropic.oauthKeychainKey {
                    return anthropicCredential
                }
                if key == CloudModelProvider.google.oauthKeychainKey {
                    return googleCredential
                }
                return nil
            },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )

        #expect(processEnvironmentValue(for: "OPENAI_ACCESS_TOKEN") == nil)
        #expect(processEnvironmentValue(for: "OPENAI_AUTH_MODE") == nil)
        #expect(processEnvironmentValue(for: "OPENAI_CLIENT_VERSION") == nil)
        #expect(processEnvironmentValue(for: "ANTHROPIC_ACCESS_TOKEN") == nil)
        #expect(processEnvironmentValue(for: "ANTHROPIC_AUTH_MODE") == nil)
        #expect(processEnvironmentValue(for: "GOOGLE_ACCESS_TOKEN") == nil)
        #expect(processEnvironmentValue(for: "GOOGLE_AUTH_MODE") == nil)
        #expect(processEnvironmentValue(for: "GOOGLE_PROJECT_ID") == nil)
    }

    @Test("refreshing cached API-key cloud credentials does not mirror secrets into the parent environment")
    func refreshingCachedAPIKeyCloudCredentialsDoesNotMirrorSecretsIntoParentEnvironment() {
        let managedEnvVars = [
            "DEEPSEEK_API_KEY",
            "GLM_API_KEY",
            "KIMI_API_KEY",
            "MINIMAX_API_KEY",
        ]
        let savedEnvironment = Dictionary(uniqueKeysWithValues: managedEnvVars.map {
            ($0, processEnvironmentValue(for: $0))
        })
        defer {
            for (name, value) in savedEnvironment {
                setProcessEnvironmentValue(value, for: name)
            }
        }

        for envVar in managedEnvVars {
            setProcessEnvironmentValue(nil, for: envVar)
        }

        _ = InferenceState(
            keychainLoad: { key in
                switch key {
                case CloudModelProvider.deepseek.apiKeyKeychainKey:
                    return "deepseek-api-key"
                case CloudModelProvider.zai.apiKeyKeychainKey:
                    return "glm-api-key"
                case CloudModelProvider.kimi.apiKeyKeychainKey:
                    return "kimi-api-key"
                case CloudModelProvider.minimax.apiKeyKeychainKey:
                    return "minimax-api-key"
                default:
                    return nil
                }
            },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )

        #expect(processEnvironmentValue(for: "DEEPSEEK_API_KEY") == nil)
        #expect(processEnvironmentValue(for: "GLM_API_KEY") == nil)
        #expect(processEnvironmentValue(for: "KIMI_API_KEY") == nil)
        #expect(processEnvironmentValue(for: "MINIMAX_API_KEY") == nil)
    }

    @Test("agent core credential environment is scoped and restored")
    func agentCoreCredentialEnvironmentIsScopedAndRestored() async throws {
        let envVar = "DEEPSEEK_API_KEY"
        let savedValue = processEnvironmentValue(for: envVar)
        defer {
            setProcessEnvironmentValue(savedValue, for: envVar)
        }
        setProcessEnvironmentValue(nil, for: envVar)

        let observed: String? = try await AppBootstrap.withScopedAgentCoreEnvironment(
            keychainLoad: { key in
                key == CloudModelProvider.deepseek.apiKeyKeychainKey ? "deepseek-api-key" : nil
            }
        ) {
            guard let rawValue = getenv(envVar) else { return nil }
            return String(cString: rawValue)
        }

        #expect(observed == "deepseek-api-key")
        #expect(processEnvironmentValue(for: envVar) == nil)
    }

    @MainActor
    @Test("launch defers cloud credential bootstrap off the boot-critical path")
    func launchDefersCloudCredentialBootstrapOffTheBootCriticalPath() async throws {
        let savedValue = processEnvironmentValue(for: "DEEPSEEK_API_KEY")
        defer {
            setProcessEnvironmentValue(savedValue, for: "DEEPSEEK_API_KEY")
        }
        setProcessEnvironmentValue(nil, for: "DEEPSEEK_API_KEY")

        let probe = DeferredKeychainProbe(
            values: [CloudModelProvider.deepseek.apiKeyKeychainKey: "deepseek-api-key"],
            initialDelay: 0.35
        )
        let clock = ContinuousClock()
        let start = clock.now
        let inference = InferenceState(
            keychainLoad: probe.load(_:),
            keychainSave: { _, _ in true },
            keychainDelete: { _ in },
            deferCloudCredentialBootstrapOnLaunch: true
        )
        let elapsed = start.duration(to: clock.now)

        #expect(elapsed < .milliseconds(150))
        #expect(processEnvironmentValue(for: "DEEPSEEK_API_KEY") == nil)

        try await Task.sleep(for: .milliseconds(500))
        #expect(processEnvironmentValue(for: "DEEPSEEK_API_KEY") == nil)
        withExtendedLifetime(inference) {}
    }

    private func encodedCredential(_ credential: CloudProviderOAuthCredential) throws -> String {
        let data = try JSONEncoder().encode(credential)
        return try #require(String(data: data, encoding: .utf8))
    }

    private func processEnvironmentValue(for name: String) -> String? {
        guard let rawValue = getenv(name) else { return nil }
        return String(cString: rawValue)
    }

    private func setProcessEnvironmentValue(_ value: String?, for name: String) {
        if let value {
            setenv(name, value, 1)
        } else {
            unsetenv(name)
        }
    }

    private final class DeferredKeychainProbe: @unchecked Sendable {
        private let lock = NSLock()
        private let values: [String: String]
        private let initialDelay: TimeInterval
        nonisolated(unsafe) private var didSleep = false

        init(values: [String: String], initialDelay: TimeInterval) {
            self.values = values
            self.initialDelay = initialDelay
        }

        nonisolated func load(_ key: String) -> String? {
            let shouldSleep: Bool
            lock.lock()
            shouldSleep = !didSleep
            didSleep = true
            lock.unlock()

            if shouldSleep {
                Thread.sleep(forTimeInterval: initialDelay)
            }
            return values[key]
        }
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
}
