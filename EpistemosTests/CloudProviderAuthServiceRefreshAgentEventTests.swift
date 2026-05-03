import Foundation
import Testing
@testable import Epistemos

@MainActor
private final class CloudProviderAuthRefreshEventSink {
    private(set) var events: [AgentProvenanceEvent] = []

    func append(_ event: AgentProvenanceEvent) -> Bool {
        events.append(event)
        return true
    }
}

@MainActor
@Suite("Cloud Provider Auth Refresh AgentEvent Provenance")
struct CloudProviderAuthServiceRefreshAgentEventTests {
    @Test("expired Google OAuth credential refresh records sanitized requested and completed events")
    func expiredGoogleRefreshRecordsSanitizedRequestedAndCompletedEvents() async throws {
        let expiredCredential = CloudProviderOAuthCredential(
            provider: .google,
            accessToken: "old-google-access-token-secret",
            refreshToken: "google-refresh-token-secret",
            expiresAt: Date(timeIntervalSince1970: 1_000),
            clientID: "google-client-id",
            clientSecret: "google-client-secret",
            projectID: "epistemos-project",
            authMode: .googleGemini,
            accountLabel: "google-user@example.com"
        )
        let store = TestKeychainStore(values: [
            CloudModelProvider.google.oauthKeychainKey: try encodedCredential(expiredCredential)
        ])
        let session = makeCloudProviderAuthRefreshURLSession { request in
            let url = try #require(request.url)
            #expect(url.host == "oauth2.googleapis.com")
            #expect(url.path == "/token")
            let body = String(data: try requestBodyData(from: request), encoding: .utf8) ?? ""
            #expect(body.contains("refresh_token=google-refresh-token-secret"))
            #expect(body.contains("client_secret=google-client-secret"))

            let response = try #require(
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            )
            let data = """
            {
              "access_token": "new-google-access-token-secret",
              "expires_in": 3600
            }
            """.data(using: .utf8) ?? Data()
            return (response, data)
        }
        let sink = CloudProviderAuthRefreshEventSink()
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 42 },
            persist: { event in sink.append(event) }
        )
        let service = CloudProviderAuthService(
            keychainLoad: store.load(_:),
            keychainSave: store.save(_:_:),
            keychainDelete: store.delete(_:),
            urlSession: session,
            agentProvenanceRecorder: recorder
        )

        let credential = try await service.resolvedCredential(for: .google, apiKey: nil)

        if case .googleOAuth(let accessToken, let projectID) = credential {
            #expect(accessToken == "new-google-access-token-secret")
            #expect(projectID == "epistemos-project")
        } else {
            Issue.record("Expected Google OAuth credential after refresh.")
        }
        #expect(sink.events.map(\.kind) == [.toolCallRequested, .toolCallCompleted])
        #expect(sink.events.map { $0.tool?.status } == [.requested, .completed])
        #expect(sink.events.allSatisfy { $0.tool?.toolName == "auth.token.refreshed" })
        #expect(sink.events.allSatisfy { $0.metadata["source"] == "cloud_provider_auth_service" })
        #expect(sink.events.allSatisfy { $0.metadata["surface"] == "oauth_token_refresh" })
        #expect(sink.events.allSatisfy { $0.metadata["provider"] == CloudModelProvider.google.rawValue })
        #expect(sink.events.last?.tool?.resultJSON?.contains("new_expires_at") == true)
        #expect(sink.events.last?.tool?.durationMs != nil)

        let encodedEvents = try String(data: JSONEncoder().encode(sink.events), encoding: .utf8) ?? ""
        #expect(encodedEvents.contains("previous_token_fingerprint"))
        #expect(!encodedEvents.contains("old-google-access-token-secret"))
        #expect(!encodedEvents.contains("google-refresh-token-secret"))
        #expect(!encodedEvents.contains("new-google-access-token-secret"))
        #expect(!encodedEvents.contains("google-client-secret"))
    }

    @Test("failed refresh records sanitized failure event without leaking OAuth secrets")
    func failedRefreshRecordsSanitizedFailureEventWithoutLeakingOAuthSecrets() async throws {
        let expiredCredential = CloudProviderOAuthCredential(
            provider: .google,
            accessToken: "old-google-access-token-secret",
            refreshToken: "google-refresh-token-secret",
            expiresAt: Date(timeIntervalSince1970: 1_000),
            clientID: "google-client-id",
            clientSecret: "google-client-secret",
            projectID: "epistemos-project",
            authMode: .googleGemini,
            accountLabel: nil
        )
        let store = TestKeychainStore(values: [
            CloudModelProvider.google.oauthKeychainKey: try encodedCredential(expiredCredential)
        ])
        let session = makeCloudProviderAuthRefreshURLSession { request in
            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)
            )
            let data = """
            {
              "error": "refresh token google-refresh-token-secret rejected"
            }
            """.data(using: .utf8) ?? Data()
            return (response, data)
        }
        let sink = CloudProviderAuthRefreshEventSink()
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 84 },
            persist: { event in sink.append(event) }
        )
        let service = CloudProviderAuthService(
            keychainLoad: store.load(_:),
            keychainSave: store.save(_:_:),
            keychainDelete: store.delete(_:),
            urlSession: session,
            agentProvenanceRecorder: recorder
        )

        do {
            _ = try await service.resolvedCredential(for: .google, apiKey: nil)
            Issue.record("Expected Google refresh to fail.")
        } catch let error as CloudProviderAuthError {
            switch error {
            case .googleTokenExchangeFailed(500):
                break
            default:
                Issue.record("Expected googleTokenExchangeFailed(500), got \(error).")
            }
        } catch {
            Issue.record("Expected CloudProviderAuthError.googleTokenExchangeFailed, got \(error).")
        }

        #expect(sink.events.map(\.kind) == [.toolCallRequested, .toolCallFailed])
        #expect(sink.events.map { $0.tool?.status } == [.requested, .failed])
        #expect(sink.events.last?.tool?.errorMessage == "OAuth token refresh failed.")
        #expect(sink.events.last?.metadata["failure_class"] == "CloudProviderAuthError")

        let encodedEvents = try String(data: JSONEncoder().encode(sink.events), encoding: .utf8) ?? ""
        #expect(encodedEvents.contains("previous_token_fingerprint"))
        #expect(!encodedEvents.contains("old-google-access-token-secret"))
        #expect(!encodedEvents.contains("google-refresh-token-secret"))
        #expect(!encodedEvents.contains("google-client-secret"))
    }

    @Test("fresh OAuth credential does not emit refresh events")
    func freshCredentialDoesNotEmitRefreshEvents() async throws {
        let freshCredential = CloudProviderOAuthCredential(
            provider: .google,
            accessToken: "fresh-google-access-token-secret",
            refreshToken: "google-refresh-token-secret",
            expiresAt: Date(timeIntervalSinceNow: 3_600),
            clientID: "google-client-id",
            clientSecret: "google-client-secret",
            projectID: "epistemos-project",
            authMode: .googleGemini,
            accountLabel: nil
        )
        let store = TestKeychainStore(values: [
            CloudModelProvider.google.oauthKeychainKey: try encodedCredential(freshCredential)
        ])
        let sink = CloudProviderAuthRefreshEventSink()
        let recorder = AgentToolProvenanceRecorder(
            persist: { event in sink.append(event) }
        )
        let service = CloudProviderAuthService(
            keychainLoad: store.load(_:),
            keychainSave: store.save(_:_:),
            keychainDelete: store.delete(_:),
            agentProvenanceRecorder: recorder
        )

        _ = try await service.resolvedCredential(for: .google, apiKey: nil)

        #expect(sink.events.isEmpty)
    }

    private func encodedCredential(_ credential: CloudProviderOAuthCredential) throws -> String {
        let data = try JSONEncoder().encode(credential)
        return try #require(String(data: data, encoding: .utf8))
    }
}

private func makeCloudProviderAuthRefreshURLSession(
    handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
) -> URLSession {
    CloudProviderAuthRefreshURLProtocol.handler = handler
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [CloudProviderAuthRefreshURLProtocol.self]
    return URLSession(configuration: configuration)
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

private nonisolated final class CloudProviderAuthRefreshURLProtocol: URLProtocol {
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
