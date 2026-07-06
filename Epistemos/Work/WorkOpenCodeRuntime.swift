import Darwin
import Foundation

// WORK = OpenCode shell — the bundled-runtime resolver + lazy lifecycle (owner
// 2026-06-21). OpenCode ships as a BUNDLED in-app runtime (Bun/Node) — owner-
// authorized for the WORK path (addendum §110-111, "set in stone": MAS non-
// restrictive, notarized direct-distribution; this sidecar is EXPLICIT, Pro-gated,
// and VISIBLE via the health row — never a hidden/default sidecar on the chat/act
// path). Option A: the native terminal view spawns the bundled `opencode` TUI in a
// PTY; the TUI self-manages its loopback Bun server (`opencode serve`, 127.0.0.1),
// so the "lazy Bun engine / kill-on-idle" lifecycle = the PTY process lifecycle
// (SwiftTerm kills it on terminal-view teardown).
//
// HONEST: the bundled runtime is ABSENT until OpenCode is vendored into Resources.
// Until then `bundledRuntimeURL()` is nil, the shell stays inert, and nothing
// launches — no fake terminal, no spawn against a missing binary. The moment the
// vendored bundle is dropped in, the resolver goes LIVE with zero further wiring.

/// W-R2/W-R3 (2026-06-24): registration for the app-hosted native-tools MCP — the in-process loopback HTTP
/// server (`WorkToolMCPCore` behind an NWListener) that exposes the FULL Epistemos tool set (vault/graph +
/// Swift-side computer-use) to OpenCode. nil until that server is live → the OpenCode config omits it
/// (honest; OpenCode then only sees the `epistemos-vault` stdio server).
// `nonisolated` so the nonisolated `WorkNativeMCPServer.Status` (which has `case running(WorkNativeMCPRegistration)`
// and is itself Equatable) can use this Equatable conformance off the main actor. Both fields are Sendable value
// types, so escaping the module's default MainActor isolation is safe.
nonisolated struct WorkNativeMCPRegistration: Equatable, Sendable {
    private static let safeBearerTokenCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~+/="
    )

    let url: String
    let token: String

    var isTrustedLoopbackMCP: Bool {
        Self.isTrustedLoopbackMCP(url: url, token: token)
    }

    static func isTrustedLoopbackMCP(url: String, token: String) -> Bool {
        guard isSafeBearerToken(token),
              let components = URLComponents(string: url),
              components.scheme?.lowercased() == "http",
              components.path == WorkNativeMCPServer.mcpPath,
              let host = components.host,
              let port = components.port,
              (1024...65535).contains(port),
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil else { return false }
        return host == "127.0.0.1" || host == "localhost" || host == "::1"
    }

    static func isSafeBearerToken(_ token: String) -> Bool {
        token == token.trimmingCharacters(in: .whitespacesAndNewlines)
            && !token.isEmpty
            && token.unicodeScalars.allSatisfy { scalar in
                safeBearerTokenCharacters.contains(scalar)
            }
    }
}

nonisolated enum WorkOpenCodeRuntime {
    /// Loopback only — the OpenCode server is NEVER exposed off-host.
    static let loopbackHost = "127.0.0.1"
    /// `opencode serve` default port (the TUI self-serves here).
    static let defaultPort = 4096
    /// Kill-on-idle window for the work runtime (owner: lazy-launch, kill-on-idle).
    static let idleTimeout: TimeInterval = 300
    private static let maxExistingConfigBytes = 1024 * 1024

    /// Where the bundled OpenCode runtime launcher lives once vendored + bundled into
    /// the signed .app. Honest nil until then (no fake "present").
    static func bundledRuntimeURL(bundle: Bundle = .main) -> URL? {
        resolveRuntimeURL(inResources: bundle.resourceURL)
    }

    /// Pure resolver (testable without a real Bundle): the `opencode-runtime/bin/opencode` launcher under a
    /// Resources dir, IFF it exists + is executable. nil when the resources dir is nil or the binary is absent
    /// (honest — the build-time `build-opencode-runtime.sh` vendor lands it; until then the shell stays inert).
    static func resolveRuntimeURL(inResources resources: URL?) -> URL? {
        guard let resources else { return nil }
        let structured = resources
            .appendingPathComponent("opencode-runtime", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("opencode")
        if FileManager.default.isExecutableFile(atPath: structured.path) { return structured }
        // FLATTENED FALLBACK (owner 2026-06-23): the synchronized resource-group copy flattens
        // `opencode-runtime/bin/*` to the Resources ROOT in the built .app (verified iter31:
        // `opencode`, `bun`, `omega_mcp_stdio` all land directly under Contents/Resources/). The
        // three binaries stay CO-LOCATED there, so `shellEnvironment` prepends this same dir to PATH
        // and `opencode serve` still finds its sibling `bun`. Prefer the structured layout; fall back
        // to the flattened one so the vendored runtime is honestly LIVE either way (never a fake term).
        let flattened = resources.appendingPathComponent("opencode")
        return FileManager.default.isExecutableFile(atPath: flattened.path) ? flattened : nil
    }

    /// The PTY environment for the OpenCode TUI: inherit the process env (PATH/HOME a
    /// PTY needs) and pin the server to loopback. Pure + testable. When the runtime is
    /// vendored, the bundled Bun's bin dir is prepended to PATH here.
    static func shellEnvironment(
        base: [String: String] = ProcessInfo.processInfo.environment,
        runtimeURL: URL?
    ) -> [String: String] {
        var env = base
        // Pin OpenCode's server to loopback (defense-in-depth even though it defaults
        // to 127.0.0.1) — the work server is host-private.
        env["OPENCODE_HOST"] = loopbackHost
        env["OPENCODE_PORT"] = String(defaultPort)
        if let runtimeURL {
            // Prepend the bundled runtime's bin dir so the TUI finds its own Bun/node
            // toolchain ahead of any system install.
            let binDir = runtimeURL.deletingLastPathComponent().path
            let existing = env["PATH"] ?? ""
            env["PATH"] = existing.isEmpty ? binDir : "\(binDir):\(existing)"
        }
        return env
    }

    /// The bundled `omega_mcp_stdio` MCP server (next to `bin/opencode`) — the FUSION transport that gives
    /// OpenCode's work agent the app's vault tools. nil until vendored (built+staged by the build script).
    static func bundledMcpServerURL(bundle: Bundle = .main) -> URL? {
        guard let resources = bundle.resourceURL else { return nil }
        let structured = resources
            .appendingPathComponent("opencode-runtime", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("omega_mcp_stdio")
        if FileManager.default.isExecutableFile(atPath: structured.path) { return structured }
        // Flattened fallback — same reason as resolveRuntimeURL (built bundle flattens to Resources root).
        let flattened = resources.appendingPathComponent("omega_mcp_stdio")
        return FileManager.default.isExecutableFile(atPath: flattened.path) ? flattened : nil
    }

    /// The OpenCode config (opencode.json) that FUSES the app's vault tools into the work TUI: registers the
    /// bundled `omega_mcp_stdio` as a local MCP server with the vault root in its environment. OpenCode reads
    /// it via `OPENCODE_CONFIG`. Pure + testable; donor tools fuse beneath OpenCode via MCP.
    static func openCodeConfigJSON(stdioServerPath: String, vaultRoot: String) -> String {
        let config: [String: Any] = [
            "$schema": "https://opencode.ai/config.json",
            "mcp": [
                "epistemos-vault": [
                    "type": "local",
                    "command": [stdioServerPath],
                    "environment": ["EPISTEMOS_VAULT_ROOT": vaultRoot],
                    "enabled": true,
                ],
            ],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: config, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else { return "{}" }
        return json
    }

    /// Write the fusion config to an app-managed path (Application Support), returning its path for
    /// `OPENCODE_CONFIG`. nil on failure (the caller then launches the TUI without fusion — honest, not fatal).
    /// NOTE: this is the CLOBBERING writer (kept for the legacy seam + tests); the LIVE launch path uses the
    /// merge-preserving `writeMergedFusionConfig` so user-installed MCPs survive a relaunch (0.49).
    static func writeFusionConfig(_ json: String) -> String? {
        guard let file = fusionConfigURL() else { return nil }
        let directory = file.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            try writeOwnerOnlyConfigData(Data(json.utf8), to: file)
            return file.path
        } catch {
            return nil
        }
    }

    /// The DURABLE, app-managed OpenCode config path (Application Support/Epistemos/opencode/opencode.json).
    /// Stable across launches — this is the persistent HOME for the work TUI's config, so any MCP/dependency the
    /// user installs into it (via the TUI's MCP-add, which writes back to OPENCODE_CONFIG) survives quit+reopen.
    static func fusionConfigURL() -> URL? {
        let fm = FileManager.default
        guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return support
            .appendingPathComponent("Epistemos/opencode", isDirectory: true)
            .appendingPathComponent("opencode.json")
    }

    /// Owner 2026-06-24: OpenCode's TUI was white/black, not the Epistemos theme. OpenCode reads its UI theme
    /// from `~/.config/opencode/tui.json` (theme in opencode.json is deprecated). The built-in `system` theme
    /// adapts to the TERMINAL's color scheme — and our SwiftTerm PTY colors are set from the live Epistemos
    /// palette (WorkTerminalPalette.from(theme:)), so `system` makes OpenCode follow the Epistemos theme.
    /// Merge-preserving: only set `theme` when the user hasn't chosen one (never clobber a user pick). Best-effort.
    @discardableResult
    static func writeTuiThemeConfig(theme: String = "system") -> String? {
        let fm = FileManager.default
        let dir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/opencode", isDirectory: true)
        let file = dir.appendingPathComponent("tui.json")
        var root: [String: Any] = {
            guard let data = try? Data(contentsOf: file),
                  let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            else { return [:] }
            return obj
        }()
        root["$schema"] = "https://opencode.ai/tui.json"
        if root["theme"] == nil {
            root["theme"] = theme
        }
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8)
        else { return nil }
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
            try writeOwnerOnlyConfigData(Data(json.utf8), to: file)
            return file.path
        } catch {
            return nil
        }
    }

    /// MERGE-PRESERVING config generation (0.49 — owner: "MCP never saved after I quit my app"). Deep-merges our
    /// `epistemos-vault` fusion server into an EXISTING opencode.json, preserving EVERY other key and every other
    /// MCP server the user installed. `existingJSON` nil/empty/garbage → a fresh fusion-only config (honest). Pure
    /// + testable. This is why launch-time rewrites no longer clobber user installs: we only ever (re)assert OUR
    /// one server, never the whole file.
    static func mergedOpenCodeConfigJSON(
        existingJSON: String?, stdioServerPath: String, vaultRoot: String,
        nativeMCP: WorkNativeMCPRegistration? = nil
    ) -> String {
        var root: [String: Any] = {
            guard let existingJSON,
                  let data = existingJSON.data(using: .utf8),
                  let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            else { return [:] }
            return obj
        }()
        root["$schema"] = "https://opencode.ai/config.json"
        // Preserve every user-added MCP server; only (re)assert our fusion vault entry.
        var mcp = (root["mcp"] as? [String: Any]) ?? [:]
        mcp["epistemos-vault"] = [
            "type": "local",
            "command": [stdioServerPath],
            "environment": ["EPISTEMOS_VAULT_ROOT": vaultRoot],
            "enabled": true,
        ]
        // W-R2/W-R3 (2026-06-24): when the app-hosted native-tools MCP is live, register it so OpenCode can
        // call the FULL Epistemos tool set (vault/graph + Swift-side computer-use) over loopback. nil →
        // omitted (honest). Merge-preserving: only (re)asserts OUR entry, never drops user-added servers.
        if let nativeMCP, nativeMCP.isTrustedLoopbackMCP {
            mcp["epistemos-native"] = [
                "type": "remote",
                "url": nativeMCP.url,
                "headers": ["Authorization": "Bearer \(nativeMCP.token)"],
                "enabled": true,
            ]
        }
        root["mcp"] = mcp
        // Owner 2026-06-24: OpenCode showed "LSPs are disabled". `"lsp": true` enables LSP globally (OpenCode
        // auto-detects installed language servers); omitting it keeps LSP off. Only set the default when the user
        // hasn't configured `lsp` themselves (preserve a user object/false).
        if root["lsp"] == nil {
            root["lsp"] = true
        }
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8)
        else {
            // Fall back to the fresh (non-merged) config rather than dropping the fusion server entirely.
            return openCodeConfigJSON(stdioServerPath: stdioServerPath, vaultRoot: vaultRoot)
        }
        return json
    }

    /// Read the durable opencode.json (if any), MERGE our fusion server in (preserving user installs), write it
    /// back, return its path for `OPENCODE_CONFIG`. nil on failure (caller launches without fusion — honest). This
    /// is the LIVE launch path: it makes the Application-Support config the persistent home AND guarantees launch
    /// never clobbers a user-installed MCP (0.49).
    static func writeMergedFusionConfig(
        stdioServerPath: String, vaultRoot: String, nativeMCP: WorkNativeMCPRegistration? = nil
    ) -> String? {
        guard let file = fusionConfigURL() else { return nil }
        let directory = file.deletingLastPathComponent()
        let existing = readExistingConfigTextNoFollow(at: file)
        let json = mergedOpenCodeConfigJSON(
            existingJSON: existing, stdioServerPath: stdioServerPath, vaultRoot: vaultRoot,
            nativeMCP: nativeMCP)
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            try writeOwnerOnlyConfigData(Data(json.utf8), to: file)
            return file.path
        } catch {
            return nil
        }
    }

    private static func readExistingConfigTextNoFollow(at file: URL) -> String? {
        let fd = file.path.withCString { path in
            open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard fd >= 0 else { return nil }

        var fileStatus = stat()
        guard fstat(fd, &fileStatus) == 0 else {
            close(fd)
            return nil
        }
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG,
              fileStatus.st_size >= 0,
              UInt64(fileStatus.st_size) <= UInt64(maxExistingConfigBytes) else {
            close(fd)
            return nil
        }

        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        guard let data = try? handle.readToEnd(),
              data.count <= maxExistingConfigBytes else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func writeOwnerOnlyConfigData(_ data: Data, to file: URL) throws {
        let directory = file.deletingLastPathComponent()
        let temporary = directory.appendingPathComponent(".\(file.lastPathComponent).\(UUID().uuidString).tmp")
        do {
            try writeExclusiveOwnerOnlyData(data, to: temporary)
            let destinationExists = FileManager.default.fileExists(atPath: file.path)
                || (try? FileManager.default.destinationOfSymbolicLink(atPath: file.path)) != nil
            if destinationExists {
                try FileManager.default.removeItem(at: file)
            }
            try FileManager.default.moveItem(at: temporary, to: file)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
    }

    private static func writeExclusiveOwnerOnlyData(_ data: Data, to file: URL) throws {
        let fd = file.path.withCString { path in
            open(path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, mode_t(0o600))
        }
        guard fd >= 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }

        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        do {
            try handle.write(contentsOf: data)
            try handle.synchronize()
            try handle.close()
        } catch {
            try? handle.close()
            throw error
        }
    }
}

/// The LIVE OpenCode work shell — resolves a real launch spec pointing at the bundled
/// `opencode` TUI rooted at the workspace. Only ever constructed when the runtime is
/// actually bundled (the factory checks), so `isReady` is honestly true here.
struct BundledWorkOpenCodeShell: WorkOpenCodeShell {
    let runtimeURL: URL

    var isReady: Bool { true }

    func launchSpec(
        workspace: URL, epistemosVaultRoot: URL?, nativeMCP: WorkNativeMCPRegistration?
    ) throws -> WorkShellLaunchSpec {
        var environment = WorkOpenCodeRuntime.shellEnvironment(runtimeURL: runtimeURL)
        // Owner 2026-06-24: make OpenCode's TUI follow the Epistemos theme (it was white/black). Best-effort —
        // writes `theme: system` into ~/.config/opencode/tui.json so OpenCode adapts to the PTY's Epistemos
        // palette. Never blocks the shell.
        WorkOpenCodeRuntime.writeTuiThemeConfig()
        // FUSION (owner §720 + 0.49b): when the bundled omega_mcp_stdio server is present AND a real app vault
        // is active, write an OpenCode config registering it rooted at the APP VAULT (NOT the shell cwd) so the
        // work agent sees the app's vault notes + `skills/` as first-class MCP context, then point OpenCode at it
        // via OPENCODE_CONFIG. The shell cwd stays `workspace` for shell/file ops; the fusion vault root is
        // decoupled. Best-effort: a write failure just omits the fusion (the TUI still launches honestly).
        //
        // HONEST NO-VAULT (owner 2026-06-24 — authority "make the no-vault state honest"): when NO vault is
        // active (`epistemosVaultRoot == nil`), do NOT silently root the fusion server at the empty default
        // (~/Documents/Epistemos). That produced a 0-resources MCP that masqueraded as an MCP failure
        // (diag 8af17c841). Instead OMIT fusion entirely: OpenCode launches with no OPENCODE_CONFIG /
        // EPISTEMOS_VAULT_ROOT, so omega_mcp_stdio honestly reports no vault (empty resources/list = "no vault
        // connected", NOT "MCP broken"). The user connects a vault to enable fusion. NEVER the empty default.
        if let vaultURL = epistemosVaultRoot,
           let serverURL = WorkOpenCodeRuntime.bundledMcpServerURL() {
            // Root the fusion MCP server at the live app vault (skills/vault/context bridge), NEVER the cwd/home
            // (home would bury the app vault under a 5000-file noisy resource list and miss `skills/`).
            let fusionVaultRoot = vaultURL.path
            // MERGE-PRESERVING (0.49): read the durable opencode.json, fold our fusion server in WITHOUT
            // dropping any MCP/dependency the user installed via the TUI, write back. Launch no longer
            // clobbers user installs — they survive quit+reopen because OPENCODE_CONFIG is this same
            // persistent Application-Support file every launch.
            if let configPath = WorkOpenCodeRuntime.writeMergedFusionConfig(
                stdioServerPath: serverURL.path, vaultRoot: fusionVaultRoot, nativeMCP: nativeMCP) {
                environment["OPENCODE_CONFIG"] = configPath
                environment["EPISTEMOS_VAULT_ROOT"] = fusionVaultRoot
            }
        }
        return WorkShellLaunchSpec(
            executableURL: runtimeURL,
            arguments: [],   // bare `opencode` launches the TUI in the cwd
            workingDirectory: workspace,
            environment: environment
        )
    }
}
