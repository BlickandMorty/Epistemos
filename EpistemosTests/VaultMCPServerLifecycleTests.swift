import Foundation
import Testing
@testable import Epistemos

@Suite("Vault MCP Server Lifecycle")
struct VaultMCPServerLifecycleTests {
    private let token = "secret-token-abc123"

    private enum TestError: Error {
        case didNotStart
    }

    private nonisolated final class MemoryKeychain: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [String: String]

        init(values: [String: String] = [:]) {
            self.values = values
        }

        func load(_ key: String) -> String? {
            lock.withLock { values[key] }
        }

        func save(_ value: String, _ key: String) -> Bool {
            lock.withLock { values[key] = value }
            return true
        }
    }

    private nonisolated final class TokenFactory: @unchecked Sendable {
        private let lock = NSLock()
        private var tokens: [String]

        init(_ tokens: [String]) {
            self.tokens = tokens
        }

        func next() -> String {
            lock.withLock {
                tokens.isEmpty ? "fallback-token" : tokens.removeFirst()
            }
        }
    }

    private static let echoExecutor: LocalAgentToolExecutor = { name, argumentsJSON in
        LocalToolResult(
            toolName: name,
            resultJson: #"{"echoed":"\#(name)","args":\#(argumentsJSON)}"#,
            isError: false)
    }

    @Test("token store loads existing token, mints missing token, and rotates through Keychain closures")
    func tokenStorePersistenceAndRotation() {
        let keychain = MemoryKeychain(values: [VaultMCPTokenStore.keychainKey: " existing-token "])
        let firstFactory = TokenFactory(["unused-token"])
        let existingStore = VaultMCPTokenStore(
            load: keychain.load,
            save: keychain.save,
            makeToken: firstFactory.next)
        #expect(existingStore.currentToken() == "existing-token")

        let emptyKeychain = MemoryKeychain()
        let factory = TokenFactory(["minted-token", "rotated-token"])
        let store = VaultMCPTokenStore(
            load: emptyKeychain.load,
            save: emptyKeychain.save,
            makeToken: factory.next)
        #expect(store.currentToken() == "minted-token")
        #expect(emptyKeychain.load(VaultMCPTokenStore.keychainKey) == "minted-token")
        #expect(store.rotateToken() == "rotated-token")
        #expect(emptyKeychain.load(VaultMCPTokenStore.keychainKey) == "rotated-token")
        #expect(VaultMCPTokenStore.masked("abcd1234wxyz") == "abcd...wxyz")
        #expect(VaultMCPTokenStore.masked("short") == "****")
    }

    @Test("authorized POST dispatches to the read-only vault core over loopback HTTP")
    func authorizedPostDispatchesToVaultCore() async throws {
        let root = try Self.makeVaultRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try "A note".write(to: root.appendingPathComponent("Note.md"), atomically: true, encoding: .utf8)

        let server = VaultMCPServer(vaultRoot: root, executor: Self.echoExecutor, token: token)
        defer { server.stop() }
        let registration = try await startAndAwait(server)

        let (data, response) = try await post(
            #"{"jsonrpc":"2.0","id":1,"method":"tools/list"}"#,
            to: registration)
        #expect(response.statusCode == 200)
        let object = try Self.jsonObject(data)
        let result = try #require(object["result"] as? [String: Any])
        let tools = try #require(result["tools"] as? [[String: Any]])
        let names = Set(tools.compactMap { $0["name"] as? String })
        #expect(names == Set(VaultMCPCore.readToolNames))
        #expect(!names.contains("vault.write"))
    }

    @Test("server rejects wrong bearer and non-loopback Origin before dispatch")
    func serverRejectsBadAuthAndOrigin() async throws {
        let root = try Self.makeVaultRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let server = VaultMCPServer(vaultRoot: root, executor: Self.echoExecutor, token: token)
        defer { server.stop() }
        let registration = try await startAndAwait(server)

        let (_, wrongToken) = try await post(
            #"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#,
            to: registration,
            bearer: "wrong-token")
        #expect(wrongToken.statusCode == 401)

        let (_, wrongOrigin) = try await post(
            #"{"jsonrpc":"2.0","id":3,"method":"tools/list"}"#,
            to: registration,
            origin: "https://evil.example.com")
        #expect(wrongOrigin.statusCode == 401)
    }

    @Test("JSON-RPC notifications receive 202 Accepted with no response body")
    func notificationsReceiveAccepted() async throws {
        let root = try Self.makeVaultRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let server = VaultMCPServer(vaultRoot: root, executor: Self.echoExecutor, token: token)
        defer { server.stop() }
        let registration = try await startAndAwait(server)

        let (data, response) = try await post(
            #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#,
            to: registration)
        #expect(response.statusCode == 202)
        #expect(data.isEmpty)
    }

    @Test("source guards keep server/host on the audited Plan 3 seams")
    func sourceGuardsKeepPlan3Seams() throws {
        let server = try loadMirroredSourceTextFile("Epistemos/VaultMCP/VaultMCPServer.swift")
        #expect(server.contains("WorkNativeMCPServer.routeOutcome"))
        #expect(server.contains("WorkNativeMCPServer.httpResponse"))
        #expect(server.contains("WorkNativeMCPServer.acceptedResponse"))
        #expect(server.contains("WorkMCPHTTPRequest.parse"))
        #expect(server.contains("requiredInterfaceType = .loopback"))

        let tokenStore = try loadMirroredSourceTextFile("Epistemos/VaultMCP/VaultMCPTokenStore.swift")
        #expect(tokenStore.contains("Keychain.load"))
        #expect(tokenStore.contains("Keychain.save"))
        #expect(tokenStore.contains("vault_mcp_bearer"))
        #expect(!tokenStore.contains("UserDefaults"))

        let host = try loadMirroredSourceTextFile("Epistemos/VaultMCP/VaultMCPHost.swift")
        #expect(host.contains("allowedToolNames: Set(VaultMCPCore.readToolNames)"))
        #expect(host.contains("rotateTokenAndRestart"))
        #expect(!host.contains("AppBootstrap"))
        #expect(!host.contains("applicationDidFinishLaunching"))

        let row = try loadMirroredSourceTextFile("Epistemos/Views/Settings/VaultMCPServerSettingsRow.swift")
        #expect(row.contains("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)"))
        #expect(row.contains("VaultMCPHost.shared.start"))
        #expect(row.contains("VaultMCPHost.shared.stop"))
        #expect(row.contains("VaultMCPTokenStore.masked"))
        #expect(row.contains("Copy MCP client config"))
        #expect(row.contains(#""type": "http""#))
        #expect(row.contains("Authorization"))
        #expect(!row.contains("@AppStorage"))

        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        #expect(settings.contains("VaultMCPServerSettingsRow(vaultRoot: vaultSync.vaultURL)"))
        #expect(settings.contains("Section(\"Read-Only MCP Server\")"))
    }

    private func startAndAwait(_ server: VaultMCPServer) async throws -> WorkNativeMCPRegistration {
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
        bearer: String? = nil,
        origin: String? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        let url = try #require(URL(string: registration.url))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearer ?? registration.token)", forHTTPHeaderField: "Authorization")
        if let origin {
            request.setValue(origin, forHTTPHeaderField: "Origin")
        }
        request.httpBody = Data(json.utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, try #require(response as? HTTPURLResponse))
    }

    private static func makeVaultRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-vault-mcp-server-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static func jsonObject(_ data: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
