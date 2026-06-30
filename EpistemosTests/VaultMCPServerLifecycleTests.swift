import Foundation
import Testing
@testable import Epistemos

@Suite("Vault MCP Server Lifecycle")
struct VaultMCPServerLifecycleTests {
    private let token = "secret-token-abc123"
    private let storedToken = "ABCDEFGHIJKLMNOPQRSTUVWXYZ123456"
    private let mintedToken = "abcdefghijklmnopqrstuvwxyz123456"
    private let rotatedToken = "0123456789abcdefghijklmnopqrstuv"

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
        let keychain = MemoryKeychain(values: [VaultMCPTokenStore.keychainKey: " \(storedToken) "])
        let firstFactory = TokenFactory([mintedToken])
        let existingStore = VaultMCPTokenStore(
            load: keychain.load,
            save: keychain.save,
            makeToken: firstFactory.next)
        #expect(existingStore.currentToken() == storedToken)

        let emptyKeychain = MemoryKeychain()
        let factory = TokenFactory([mintedToken, rotatedToken])
        let store = VaultMCPTokenStore(
            load: emptyKeychain.load,
            save: emptyKeychain.save,
            makeToken: factory.next)
        #expect(store.currentToken() == mintedToken)
        #expect(emptyKeychain.load(VaultMCPTokenStore.keychainKey) == mintedToken)
        #expect(store.rotateToken() == rotatedToken)
        #expect(emptyKeychain.load(VaultMCPTokenStore.keychainKey) == rotatedToken)
        #expect(VaultMCPTokenStore.masked("abcd1234wxyz") == "abcd...wxyz")
        #expect(VaultMCPTokenStore.masked("short") == "****")
    }

    @Test("token store rejects weak stored and generated token values")
    func tokenStoreRejectsWeakTokenValues() {
        let replacementToken = mintedToken
        let weakStoredKeychain = MemoryKeychain(values: [VaultMCPTokenStore.keychainKey: "short"])
        let replacementStore = VaultMCPTokenStore(
            load: weakStoredKeychain.load,
            save: weakStoredKeychain.save,
            makeToken: { replacementToken })
        #expect(replacementStore.currentToken() == replacementToken)
        #expect(weakStoredKeychain.load(VaultMCPTokenStore.keychainKey) == replacementToken)

        let generatedKeychain = MemoryKeychain()
        let invalidGeneratedStore = VaultMCPTokenStore(
            load: generatedKeychain.load,
            save: generatedKeychain.save,
            makeToken: { "bad\nbearer" })
        let fallback = invalidGeneratedStore.currentToken()
        #expect(fallback != "bad\nbearer")
        #expect(fallback.count >= 24)
        #expect(generatedKeychain.load(VaultMCPTokenStore.keychainKey) == fallback)
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

    @Test("server failure diagnostics do not expose raw localized paths")
    func serverFailureDiagnosticsDoNotExposeRawLocalizedPaths() {
        let privatePath = "/Users/example/private-vault/mcp.sock"
        let error = NSError(
            domain: "VaultMCPPathLeak",
            code: 91,
            userInfo: [NSLocalizedDescriptionKey: "listener failed at \(privatePath)"]
        )
        let status = VaultMCPServerDiagnostics.statusMessage(for: error)
        let pathDomainStatus = VaultMCPServerDiagnostics.statusMessage(
            for: NSError(
                domain: privatePath,
                code: 92,
                userInfo: [NSLocalizedDescriptionKey: "listener failed at \(privatePath)"]
            )
        )
        let oversized = VaultMCPServerDiagnostics.statusMessage(
            String(repeating: "e", count: VaultMCPServerDiagnostics.maxStatusMessageCharacters + 32)
        )

        #expect(status.contains("domain=VaultMCPPathLeak"))
        #expect(status.contains("code=91"))
        #expect(status.contains(privatePath) == false)
        #expect(pathDomainStatus.contains("domain=Network"))
        #expect(pathDomainStatus.contains("code=92"))
        #expect(pathDomainStatus.contains(privatePath) == false)
        #expect(status.count <= VaultMCPServerDiagnostics.maxStatusMessageCharacters)
        #expect(oversized.count == VaultMCPServerDiagnostics.maxStatusMessageCharacters + 3)
    }

    @Test("host scopes running registration to the active vault")
    @MainActor
    func hostScopesRunningRegistrationToActiveVault() async throws {
        let firstRoot = try Self.makeVaultRoot()
        let secondRoot = try Self.makeVaultRoot()
        defer {
            try? FileManager.default.removeItem(at: firstRoot)
            try? FileManager.default.removeItem(at: secondRoot)
        }

        let keychain = MemoryKeychain()
        let factory = TokenFactory(["scoped-token"])
        let host = VaultMCPHost(tokenStore: VaultMCPTokenStore(
            load: keychain.load,
            save: keychain.save,
            makeToken: factory.next))
        defer { host.stop() }

        let registration = try #require(await host.start(vaultRoot: firstRoot, timeout: .seconds(2)))
        #expect(host.currentRegistration(for: firstRoot)?.url == registration.url)
        #expect(host.currentRegistration(for: secondRoot) == nil)

        host.stopIfCurrentVaultDiffers(from: secondRoot)
        #expect(host.currentRegistration == nil)
        #expect(host.currentStatus == .stopped)
    }

    @Test("host scopes registrations by canonical vault root")
    @MainActor
    func hostScopesRegistrationsByCanonicalVaultRoot() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-vault-mcp-canonical-\(UUID().uuidString)", isDirectory: true)
        let realVault = root.appendingPathComponent("Real Vault", isDirectory: true)
        let linkedVault = root.appendingPathComponent("Linked Vault", isDirectory: true)
        try FileManager.default.createDirectory(at: realVault, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: linkedVault, withDestinationURL: realVault)
        defer { try? FileManager.default.removeItem(at: root) }

        let keychain = MemoryKeychain()
        let factory = TokenFactory(["canonical-token-abcdefghijklmnopqrstuvwxyz"])
        let host = VaultMCPHost(tokenStore: VaultMCPTokenStore(
            load: keychain.load,
            save: keychain.save,
            makeToken: factory.next))
        defer { host.stop() }

        let registration = try #require(await host.start(vaultRoot: realVault, timeout: .seconds(2)))
        #expect(VaultMCPHost.canonicalVaultPath(realVault) == VaultMCPHost.canonicalVaultPath(linkedVault))
        #expect(host.currentRegistration(for: realVault)?.url == registration.url)
        #expect(host.currentRegistration(for: linkedVault)?.url == registration.url)

        host.stopIfCurrentVaultDiffers(from: linkedVault)
        #expect(host.currentRegistration?.url == registration.url)
        #expect(host.currentStatus == .running(registration))
    }

    @Test("source guards keep server/host on the audited Plan 3 seams")
    func sourceGuardsKeepPlan3Seams() throws {
        let server = try loadMirroredSourceTextFile("Epistemos/VaultMCP/VaultMCPServer.swift")
        #expect(server.contains("WorkNativeMCPServer.routeOutcome"))
        #expect(server.contains("WorkNativeMCPServer.httpResponse"))
        #expect(server.contains("WorkNativeMCPServer.acceptedResponse"))
        #expect(server.contains("WorkMCPHTTPRequest.parse"))
        #expect(server.contains("requiredInterfaceType = .loopback"))
        #expect(server.contains("VaultMCPServerDiagnostics.statusMessage(for: error)"))
        #expect(server.contains("fallback: \"receive failed\""))
        #expect(server.contains("maxStatusMessageCharacters"))
        #expect(!server.contains("error.localizedDescription"))

        let tokenStore = try loadMirroredSourceTextFile("Epistemos/VaultMCP/VaultMCPTokenStore.swift")
        #expect(tokenStore.contains("Keychain.load"))
        #expect(tokenStore.contains("Keychain.save"))
        #expect(tokenStore.contains("vault_mcp_bearer"))
        #expect(tokenStore.contains("minimumTokenLength"))
        #expect(tokenStore.contains("usableToken"))
        #expect(tokenStore.contains("uuidFallbackToken"))
        #expect(!tokenStore.contains("UserDefaults"))

        let host = try loadMirroredSourceTextFile("Epistemos/VaultMCP/VaultMCPHost.swift")
        #expect(host.contains("VaultMCPRustResourceDispatcher"))
        #expect(host.contains("dispatcher.setVaultRoot(root: vaultPath)"))
        #expect(host.contains("tier: .readOnly"))
        #expect(host.contains("allowedToolNames: Set(VaultMCPCore.readToolNames)"))
        #expect(host.contains("canonicalVaultURL"))
        #expect(host.contains("canonicalVaultPath"))
        #expect(host.contains("standardizedFileURL.resolvingSymlinksInPath()"))
        #expect(host.contains("currentRegistration(for vaultRoot: URL?)"))
        #expect(host.contains("stopIfCurrentVaultDiffers"))
        #expect(host.contains("rotateTokenAndRestart"))
        #expect(!host.contains("AppBootstrap"))
        #expect(!host.contains("applicationDidFinishLaunching"))

        let row = try loadMirroredSourceTextFile("Epistemos/Views/Settings/VaultMCPServerSettingsRow.swift")
        #expect(row.contains("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)"))
        #expect(row.contains("VaultMCPHost.shared.start"))
        #expect(row.contains("VaultMCPHost.shared.stop"))
        #expect(row.contains("VaultMCPHost.shared.stopIfCurrentVaultDiffers"))
        #expect(row.contains("VaultMCPHost.shared.currentRegistration(for: vaultRoot)"))
        #expect(row.contains("pendingVaultPath"))
        #expect(row.contains("isPendingOperationCurrent(for: vaultPath)"))
        #expect(row.contains("completePendingOperation(for: vaultPath)"))
        #expect(row.contains(".task(id: vaultRoot.map(Self.canonicalVaultPath))"))
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
