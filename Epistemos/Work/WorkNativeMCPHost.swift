import Foundation

// W-R3/W-R2 increment (c2) (2026-06-24): the app-level OWNER of the in-process native-tools MCP server.
// It constructs `WorkNativeMCPServer` with the PRODUCTION composed executor (computer-use → ComputerUseBridge;
// everything else → ToolTierBridge Rust FFI), starts it on the Work/OpenCode launch path BEFORE config
// generation, and hands its loopback `WorkNativeMCPRegistration` to `writeMergedFusionConfig` so the generated
// OpenCode config asserts `epistemos-native` (the FULL native tool surface, incl. Swift-side computer-use) —
// closing the W-R3 "every native tool expressed to OpenCode" gap.
//
// HONEST: if the server can't bind or isn't ready in time, `startAndAwaitRegistration` returns nil → the OpenCode
// config OMITS `epistemos-native` (it stays valid; OpenCode just sees the `epistemos-vault` stdio server). The
// server is rebuilt when the active vault changes so the native tools root at the live vault.
@MainActor
final class WorkNativeMCPHost {
    static let shared = WorkNativeMCPHost()

    private var server: WorkNativeMCPServer?
    private var serverVaultPath: String?
    private let contextStore = WorkAppContextStore()

    private init() {}

    /// Start the native-tools MCP (idempotent per vault root) and return its registration once the loopback
    /// listener is `.ready`, or nil if it can't start / isn't ready within `timeout`.
    func startAndAwaitRegistration(
        vaultRoot: URL?,
        context: WorkAppContextSnapshot? = nil,
        timeout: Duration = .seconds(5)
    ) async -> WorkNativeMCPRegistration? {
        contextStore.snapshot = context
        let server = ensureServer(vaultRoot: vaultRoot)
        if case .running(let registration) = server.status { return registration }
        do {
            try server.start()
        } catch {
            return nil
        }
        // NWListener `.ready` is async — poll the lock-protected status until running/failed/timeout.
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

    /// The current registration if the server is already live (sync, no start) — nil otherwise.
    var currentRegistration: WorkNativeMCPRegistration? {
        guard let server, case .running(let registration) = server.status else { return nil }
        return registration
    }

    func updateContext(_ context: WorkAppContextSnapshot?) {
        contextStore.snapshot = context
    }

    private func ensureServer(vaultRoot: URL?) -> WorkNativeMCPServer {
        let vaultPath = vaultRoot?.path ?? ""
        if let server, serverVaultPath == vaultPath {
            return server
        }
        server?.stop()
        let base = ToolTierBridge(vaultPath: vaultPath, tier: .full).toolExecutor()
        let composedExecutor = WorkNativeToolExecutor.composed(base: base)
        let newServer = WorkNativeMCPServer(
            executor: composedExecutor,
            nativeToolVaultPath: vaultPath,
            appContextStore: contextStore
        )
        server = newServer
        serverVaultPath = vaultPath
        return newServer
    }
}
