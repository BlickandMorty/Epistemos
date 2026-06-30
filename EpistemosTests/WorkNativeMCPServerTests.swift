import Foundation
import Testing
@testable import Epistemos

@Suite("Work Native MCP Server — pure transport helpers")
struct WorkNativeMCPServerTests {
    private let token = "secret-token-abc123"
    enum TestError: Error { case didNotStart }

    private static let echoExecutor: LocalAgentToolExecutor = { name, argumentsJson in
        LocalToolResult(
            toolName: name,
            resultJson: #"{"echoed":"\#(name)","args":\#(argumentsJson)}"#,
            isError: false)
    }

    private func authHeaders(_ bearer: String?, origin: String? = nil) -> [String: String] {
        var headers: [String: String] = [:]
        if let bearer { headers["authorization"] = "Bearer \(bearer)" }
        if let origin { headers["origin"] = origin }
        return headers
    }

    private func startAndAwait(_ server: WorkNativeMCPServer) async throws -> WorkNativeMCPRegistration {
        try server.start()
        for _ in 0..<100 {
            if case .running(let registration) = server.status { return registration }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw TestError.didNotStart
    }

    private func post(
        _ json: String,
        to registration: WorkNativeMCPRegistration,
        bearer: String? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        let url = try #require(URL(string: registration.url))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearer ?? registration.token)", forHTTPHeaderField: "Authorization")
        request.httpBody = Data(json.utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, try #require(response as? HTTPURLResponse))
    }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test("Work server diagnostics redact external errors")
    func workServerDiagnosticsRedactExternalErrors() {
        let message = WorkServerDiagnostics.statusMessage(
            for: NSError(
                domain: "/Users/jojo/PrivateVault/network.swift",
                code: -12,
                userInfo: [
                    NSLocalizedDescriptionKey: "listener failed at /Users/jojo/PrivateVault/socket"
                ]
            ),
            fallback: "listener failed"
        )

        #expect(message.contains("listener failed"))
        #expect(message.contains("code=-12"))
        #expect(message.count <= WorkServerDiagnostics.maxStatusMessageCharacters)
        for forbidden in [
            "/Users/jojo",
            "PrivateVault",
            "network.swift",
            "socket",
        ] {
            #expect(!message.contains(forbidden))
        }
    }

    @Test("Work native MCP server source routes failures through diagnostics")
    func workNativeMCPServerSourceRoutesFailuresThroughDiagnostics() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Work/WorkNativeMCPServer.swift")

        #expect(source.contains("WorkServerDiagnostics.statusMessage(for: error"))
        #expect(!source.contains("error.localizedDescription"))
        #expect(!source.contains("String(describing: error)"))
    }

    // MARK: routeOutcome — the security + routing gate

    @Test("POST /mcp with the correct bearer dispatches to the core")
    func dispatchesAuthorizedPost() {
        let outcome = WorkNativeMCPServer.routeOutcome(
            method: "POST", path: "/mcp", headers: authHeaders(token), token: token)
        #expect(outcome == .dispatch)
    }

    @Test("query string on the path is stripped before matching")
    func dispatchesWithQueryString() {
        let outcome = WorkNativeMCPServer.routeOutcome(
            method: "POST", path: "/mcp?session=1", headers: authHeaders(token), token: token)
        #expect(outcome == .dispatch)
    }

    @Test("wrong / missing bearer → unauthorized")
    func rejectsBadToken() {
        #expect(WorkNativeMCPServer.routeOutcome(
            method: "POST", path: "/mcp", headers: authHeaders("nope"), token: token) == .unauthorized)
        #expect(WorkNativeMCPServer.routeOutcome(
            method: "POST", path: "/mcp", headers: authHeaders(nil), token: token) == .unauthorized)
    }

    @Test("GET on the MCP path → method not allowed (POST-only JSON-RPC)")
    func rejectsNonPost() {
        let outcome = WorkNativeMCPServer.routeOutcome(
            method: "GET", path: "/mcp", headers: authHeaders(token), token: token)
        #expect(outcome == .methodNotAllowed)
    }

    @Test("unknown path → not found (even with a valid bearer)")
    func rejectsUnknownPath() {
        let outcome = WorkNativeMCPServer.routeOutcome(
            method: "POST", path: "/v1/chat", headers: authHeaders(token), token: token)
        #expect(outcome == .notFound)
    }

    @Test("a non-loopback Origin header is refused; absent/loopback Origin is allowed")
    func enforcesOriginAllowlist() {
        #expect(WorkNativeMCPServer.routeOutcome(
            method: "POST", path: "/mcp",
            headers: authHeaders(token, origin: "https://evil.example.com"), token: token) == .unauthorized)
        #expect(WorkNativeMCPServer.routeOutcome(
            method: "POST", path: "/mcp",
            headers: authHeaders(token, origin: "http://127.0.0.1:5173"), token: token) == .dispatch)
    }

    // MARK: bearerToken / origin / constant-time compare

    @Test("bearerToken parses case-insensitive scheme, rejects other schemes")
    func parsesBearer() {
        #expect(WorkNativeMCPServer.bearerToken(from: ["authorization": "Bearer abc"]) == "abc")
        #expect(WorkNativeMCPServer.bearerToken(from: ["authorization": "bearer abc"]) == "abc")
        #expect(WorkNativeMCPServer.bearerToken(from: ["authorization": "Basic abc"]) == nil)
        #expect(WorkNativeMCPServer.bearerToken(from: [:]) == nil)
        #expect(WorkNativeMCPServer.bearerToken(from: ["authorization": "Bearer "]) == nil)
    }

    @Test("isAllowedOrigin: absent/loopback allowed, opaque/routable refused")
    func originRules() {
        #expect(WorkNativeMCPServer.isAllowedOrigin(headers: [:]))
        #expect(!WorkNativeMCPServer.isAllowedOrigin(headers: ["origin": "null"]))
        #expect(WorkNativeMCPServer.isAllowedOrigin(headers: ["origin": "http://localhost:3000"]))
        #expect(WorkNativeMCPServer.isAllowedOrigin(headers: ["origin": "http://127.0.0.1:9"]))
        #expect(WorkNativeMCPServer.isAllowedOrigin(headers: ["origin": "http://[::1]:3000"]))
        #expect(!WorkNativeMCPServer.isAllowedOrigin(headers: ["origin": "file://localhost/private.html"]))
        #expect(!WorkNativeMCPServer.isAllowedOrigin(headers: ["origin": "https://app.evil.com"]))
    }

    @Test("isAllowedOrigin: HOST-exact match — substring-spoof loopback origins are REFUSED")
    func originRejectsSubstringSpoof() {
        // A substring check would wrongly allow these; host-exact matching must REFUSE them.
        #expect(!WorkNativeMCPServer.isAllowedOrigin(headers: ["origin": "http://127.0.0.1.evil.com"]))
        #expect(!WorkNativeMCPServer.isAllowedOrigin(headers: ["origin": "http://localhost.evil.com"]))
        #expect(!WorkNativeMCPServer.isAllowedOrigin(headers: ["origin": "http://evil-127.0.0.1.com"]))
        #expect(!WorkNativeMCPServer.isAllowedOrigin(headers: ["origin": "http://localhostx:3000"]))
        #expect(!WorkNativeMCPServer.isAllowedOrigin(headers: ["origin": "garbage"]))   // unparseable → fail closed
    }

    @Test("constantTimeEquals is true only for identical strings")
    func constantTime() {
        #expect(WorkNativeMCPServer.constantTimeEquals("abcdef", "abcdef"))
        #expect(!WorkNativeMCPServer.constantTimeEquals("abcdef", "abcdeg"))
        #expect(!WorkNativeMCPServer.constantTimeEquals("abc", "abcdef")) // length mismatch
        #expect(!WorkNativeMCPServer.constantTimeEquals("", "x"))
    }

    @Test("randomToken is non-empty and unique per call")
    func randomTokensDiffer() {
        let a = WorkNativeMCPServer.randomToken()
        let b = WorkNativeMCPServer.randomToken()
        #expect(!a.isEmpty)
        #expect(a != b)
    }

    // MARK: httpResponse framing

    @Test("httpResponse frames status line + Content-Length + body")
    func framesResponse() throws {
        let data = WorkNativeMCPServer.httpResponse(status: 200, json: #"{"ok":true}"#)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.hasPrefix("HTTP/1.1 200 OK\r\n"))
        #expect(text.contains("Content-Type: application/json\r\n"))
        #expect(text.contains("Cache-Control: no-store\r\n"))
        #expect(text.contains("Content-Length: 11\r\n")) // {"ok":true} == 11 bytes
        #expect(text.contains("Connection: close\r\n"))
        #expect(text.hasSuffix(#"{"ok":true}"#))
    }

    @Test("httpResponse maps known status reasons")
    func statusReasons() {
        #expect(WorkNativeMCPServer.reason(401) == "Unauthorized")
        #expect(WorkNativeMCPServer.reason(405) == "Method Not Allowed")
        #expect(WorkNativeMCPServer.reason(404) == "Not Found")
    }

    @Test("405 responses advertise POST as the only MCP method")
    func methodNotAllowedAdvertisesAllow() {
        let text = String(decoding: WorkNativeMCPServer.httpResponse(status: 405, json: #"{"error":"method"}"#),
                          as: UTF8.self)
        #expect(text.hasPrefix("HTTP/1.1 405 Method Not Allowed"))
        #expect(text.contains("Allow: POST\r\n"))
    }

    // MARK: HTTP request parser

    @Test("parse returns a complete request with method, path, lowercased headers, body")
    func parsesCompleteRequest() throws {
        let body = #"{"jsonrpc":"2.0","method":"tools/list"}"#
        let raw = "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:9\r\nAuthorization: Bearer xyz\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
        guard case .complete(let request) = WorkMCPHTTPRequest.parse(Data(raw.utf8)) else {
            Issue.record("expected .complete")
            return
        }
        #expect(request.method == "POST")
        #expect(request.path == "/mcp")
        #expect(request.headers["authorization"] == "Bearer xyz")
        #expect(String(data: request.body, encoding: .utf8) == body)
    }

    @Test("parse reports needMore when headers are not yet terminated")
    func parseNeedsMoreHeaders() {
        #expect(WorkMCPHTTPRequest.parse(Data("POST /mcp HTTP/1.1\r\nHost: x".utf8)) == .needMore)
    }

    @Test("parse reports needMore when the body is shorter than Content-Length")
    func parseNeedsMoreBody() {
        let raw = "POST /mcp HTTP/1.1\r\nContent-Length: 50\r\n\r\n{\"partial\":true}"
        #expect(WorkMCPHTTPRequest.parse(Data(raw.utf8)) == .needMore)
    }

    @Test("parse rejects malformed or negative Content-Length")
    func parseRejectsBadContentLength() {
        let negative = "POST /mcp HTTP/1.1\r\nContent-Length: -1\r\n\r\n"
        #expect(WorkMCPHTTPRequest.parse(Data(negative.utf8)) == .invalid)

        let malformed = "POST /mcp HTTP/1.1\r\nContent-Length: nope\r\n\r\n{}"
        #expect(WorkMCPHTTPRequest.parse(Data(malformed.utf8)) == .invalid)

        let duplicate = "POST /mcp HTTP/1.1\r\nContent-Length: 2\r\nContent-Length: 2\r\n\r\n{}"
        #expect(WorkMCPHTTPRequest.parse(Data(duplicate.utf8)) == .invalid)
    }

    @Test("parse returns tooLarge for declared Content-Length over the caller cap before waiting for a body")
    func parseRejectsOversizedDeclaredContentLength() {
        let raw = "POST /mcp HTTP/1.1\r\nContent-Length: 9000000\r\n\r\n"
        #expect(WorkMCPHTTPRequest.parse(Data(raw.utf8), maxContentLength: 8 * 1024 * 1024) == .tooLarge)
        let response = String(decoding: WorkNativeMCPServer.httpResponse(
            status: 413, json: #"{"error":"request too large"}"#), as: UTF8.self)
        #expect(response.hasPrefix("HTTP/1.1 413 Payload Too Large"))
    }

    // MARK: MCP Streamable HTTP transport (notifications + session id)

    @Test("isNotification: method-without-id is a notification; request-with-id / result / junk is not")
    func notificationDetection() {
        #expect(WorkNativeMCPServer.isNotification(requestJSON: #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#))
        #expect(!WorkNativeMCPServer.isNotification(requestJSON: #"{"jsonrpc":"2.0","id":1,"method":"tools/list"}"#))
        #expect(!WorkNativeMCPServer.isNotification(requestJSON: #"{"jsonrpc":"2.0","id":2,"result":{}}"#))
        #expect(!WorkNativeMCPServer.isNotification(requestJSON: "not json"))
    }

    @Test("httpResponse emits Mcp-Session-Id when provided; acceptedResponse is a bodyless 202")
    func sessionIdAndAccepted() {
        let resp = String(decoding: WorkNativeMCPServer.httpResponse(status: 200, json: "{}", sessionID: "sess-1"),
                          as: UTF8.self)
        #expect(resp.contains("Mcp-Session-Id: sess-1"))
        #expect(resp.contains("Content-Type: application/json"))
        let accepted = String(decoding: WorkNativeMCPServer.acceptedResponse(sessionID: "sess-1"), as: UTF8.self)
        #expect(accepted.hasPrefix("HTTP/1.1 202 Accepted"))
        #expect(accepted.contains("Cache-Control: no-store"))
        #expect(accepted.contains("Content-Length: 0"))
        #expect(accepted.contains("Mcp-Session-Id: sess-1"))
    }

    // MARK: End-to-end loopback transport

    @Test("loopback POST initialize reaches the MCP core and returns a session id")
    func loopbackInitialize() async throws {
        let server = WorkNativeMCPServer(executor: Self.echoExecutor, token: token)
        defer { server.stop() }
        let registration = try await startAndAwait(server)

        let (data, response) = try await post(
            #"{"jsonrpc":"2.0","id":1,"method":"initialize"}"#,
            to: registration)
        #expect(response.statusCode == 200)
        #expect(response.value(forHTTPHeaderField: "Mcp-Session-Id")?.isEmpty == false)
        let obj = try jsonObject(data)
        let result = try #require(obj["result"] as? [String: Any])
        let serverInfo = try #require(result["serverInfo"] as? [String: Any])
        #expect(serverInfo["name"] as? String == "epistemos-native-tools")
    }

    @Test("loopback POST tools/call reaches the in-app executor")
    func loopbackToolsCallRunsExecutor() async throws {
        let server = WorkNativeMCPServer(executor: Self.echoExecutor, token: token)
        defer { server.stop() }
        let registration = try await startAndAwait(server)

        let (data, response) = try await post(
            #"{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"note.create","arguments":{"title":"Work proof"}}}"#,
            to: registration)
        #expect(response.statusCode == 200)
        let obj = try jsonObject(data)
        let result = try #require(obj["result"] as? [String: Any])
        let content = try #require(result["content"] as? [[String: Any]])
        let text = try #require(content.first?["text"] as? String)
        #expect(result["isError"] as? Bool == false)
        #expect(text.contains(#""echoed":"note.create""#))
        #expect(text.contains(#""title":"Work proof""#))
    }

    @Test("loopback context snapshot tool returns the Work-owned app context")
    func loopbackContextSnapshotTool() async throws {
        let contextStore = WorkAppContextStore()
        contextStore.snapshot = WorkAppContextSnapshot(
            workspacePath: "/work",
            vaultPath: "/vault",
            managedSkillsCount: 2,
            nativeToolsAvailable: true,
            selectedEngine: "opencode",
            activeWorkSessionID: "opencode:ses_1")
        let server = WorkNativeMCPServer(
            executor: Self.echoExecutor,
            appContextStore: contextStore,
            token: token)
        defer { server.stop() }
        let registration = try await startAndAwait(server)

        let (listData, listResponse) = try await post(
            #"{"jsonrpc":"2.0","id":31,"method":"tools/list"}"#,
            to: registration)
        #expect(listResponse.statusCode == 200)
        #expect(String(data: listData, encoding: .utf8)?.contains(WorkToolMCPCore.contextSnapshotToolName) == true)

        let (callData, callResponse) = try await post(
            #"{"jsonrpc":"2.0","id":32,"method":"tools/call","params":{"name":"epistemos.context.snapshot","arguments":{}}}"#,
            to: registration)
        #expect(callResponse.statusCode == 200)
        let obj = try jsonObject(callData)
        let result = try #require(obj["result"] as? [String: Any])
        let content = try #require(result["content"] as? [[String: Any]])
        let text = try #require(content.first?["text"] as? String)
        #expect(text.contains(#""workspacePath":"\/work""#) || text.contains(#""workspacePath":"/work""#))
        #expect(text.contains(#""selectedEngine":"opencode""#))
        #expect(text.contains(#""activeWorkSessionID":"opencode:ses_1""#))
    }

    @Test("loopback JSON-RPC notification returns bodyless 202 accepted")
    func loopbackNotificationIsAccepted() async throws {
        let server = WorkNativeMCPServer(executor: Self.echoExecutor, token: token)
        defer { server.stop() }
        let registration = try await startAndAwait(server)

        let (data, response) = try await post(
            #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#,
            to: registration)
        #expect(response.statusCode == 202)
        #expect(response.value(forHTTPHeaderField: "Content-Length") == "0")
        #expect(response.value(forHTTPHeaderField: "Mcp-Session-Id")?.isEmpty == false)
        #expect(data.isEmpty)
    }

    @Test("loopback refuses a wrong bearer before dispatching to native tools")
    func loopbackRejectsWrongBearer() async throws {
        let server = WorkNativeMCPServer(executor: Self.echoExecutor, token: token)
        defer { server.stop() }
        let registration = try await startAndAwait(server)

        let (data, response) = try await post(
            #"{"jsonrpc":"2.0","id":3,"method":"tools/list"}"#,
            to: registration,
            bearer: "wrong-token")
        #expect(response.statusCode == 401)
        #expect(String(data: data, encoding: .utf8)?.contains("unauthorized") == true)
    }
}
