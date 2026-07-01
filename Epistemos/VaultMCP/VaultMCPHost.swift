import Foundation

private final class VaultMCPRustResourceDispatcher: VaultMCPResourceDispatcher, @unchecked Sendable {
    private let dispatcher: McpDispatcher

    init(vaultPath: String) {
        dispatcher = McpDispatcher(logDbPath: ":memory:")
        dispatcher.setVaultRoot(root: vaultPath)
    }

    nonisolated func dispatch(requestJson: String) -> String {
        dispatcher.dispatch(requestJson: requestJson)
    }
}

@MainActor
final class VaultMCPHost {
    static let shared = VaultMCPHost()

    private var server: VaultMCPServer?
    private var serverVaultPath: String?
    private var tokenStore: VaultMCPTokenStore

    init(tokenStore: VaultMCPTokenStore = VaultMCPTokenStore()) {
        self.tokenStore = tokenStore
    }

    func start(vaultRoot: URL, timeout: Duration = .seconds(5)) async -> WorkNativeMCPRegistration? {
        var server = ensureServer(vaultRoot: vaultRoot)
        if case .running(let registration) = server.status { return registration }
        if case .failed = server.status {
            stop()
            server = ensureServer(vaultRoot: vaultRoot)
        }
        do {
            try server.start()
        } catch {
            stop()
            return nil
        }

        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            switch server.status {
            case .running(let registration):
                return registration
            case .failed:
                return nil
            default:
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        return nil
    }

    var currentRegistration: WorkNativeMCPRegistration? {
        guard let server, case .running(let registration) = server.status else { return nil }
        return registration
    }

    func currentRegistration(for vaultRoot: URL?) -> WorkNativeMCPRegistration? {
        guard let vaultRoot,
              serverVaultPath == Self.canonicalVaultPath(vaultRoot) else { return nil }
        return currentRegistration
    }

    var currentStatus: VaultMCPServer.Status {
        server?.status ?? .idle
    }

    func stop() {
        server?.stop()
        server = nil
        serverVaultPath = nil
    }

    func stopIfCurrentVaultDiffers(from vaultRoot: URL?) {
        guard server != nil else { return }
        guard let vaultRoot,
              serverVaultPath == Self.canonicalVaultPath(vaultRoot) else {
            stop()
            return
        }
    }

    func rotateTokenAndRestart(vaultRoot: URL, timeout: Duration = .seconds(5)) async -> WorkNativeMCPRegistration? {
        _ = tokenStore.rotateToken()
        stop()
        return await start(vaultRoot: vaultRoot, timeout: timeout)
    }

    private func ensureServer(vaultRoot: URL) -> VaultMCPServer {
        let canonicalVaultURL = Self.canonicalVaultURL(vaultRoot)
        let vaultPath = canonicalVaultURL.path
        if let server, serverVaultPath == vaultPath {
            return server
        }

        server?.stop()
        let readOnlyExecutor = ToolTierBridge(
            vaultPath: vaultPath,
            tier: .readOnly,
            allowedToolNames: Set(VaultMCPCore.readToolNames)
        ).toolExecutor()
        let newServer = VaultMCPServer(
            vaultRoot: canonicalVaultURL,
            executor: readOnlyExecutor,
            token: tokenStore.currentToken(),
            resourceDispatcher: VaultMCPRustResourceDispatcher(vaultPath: vaultPath))
        server = newServer
        serverVaultPath = vaultPath
        return newServer
    }

    nonisolated static func canonicalVaultPath(_ url: URL) -> String {
        canonicalVaultURL(url).path
    }

    private nonisolated static func canonicalVaultURL(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }
}
