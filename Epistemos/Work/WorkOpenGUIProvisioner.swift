import Foundation

// #7 (MCP/tools): provision the OpenGUI Work workspace so the runtime-spawned opencode exposes Epistemos's FULL native
// tool surface. opencode reads `<workspace>/opencode.json` (verified: @opengui/runtime opencode-config.ts walks the
// directory up to it). We start the app-hosted native-tools MCP (WorkNativeMCPHost — W-R3, already built + verified)
// and MERGE an `mcp.epistemos-native` block into that file BEFORE the supervisor spawns opencode → opencode auto-loads
// it → the full native Epistemos tool surface (incl. computer-use) reaches the OpenGUI Work agent. Same block shape as
// the OpenWork-path nativeMCP registration. Best-effort: if the host can't start, opencode just keeps its default tools.
enum WorkOpenGUIProvisioner {
    /// Work/OpenGUI's cwd may be an Epistemos-managed scratch workspace, but app tools must prefer the live vault.
    nonisolated static func nativeToolRoot(workspace: URL, epistemosVaultRoot: URL?) -> URL {
        epistemosVaultRoot ?? workspace
    }

    /// Start the native-tools MCP + merge `mcp.epistemos-native` into `<workspace>/opencode.json`. Returns true on
    /// success (false → host unavailable / write failed; the runtime stays valid, agent keeps default tools).
    @MainActor
    @discardableResult
    static func provisionNativeMCP(
        workspace: URL,
        epistemosVaultRoot: URL?,
        context: WorkAppContextSnapshot? = nil
    ) async -> Bool {
        let toolRoot = nativeToolRoot(workspace: workspace, epistemosVaultRoot: epistemosVaultRoot)
        guard let registration = await WorkNativeMCPHost.shared.startAndAwaitRegistration(
            vaultRoot: toolRoot,
            context: context)
        else {
            return false
        }
        do {
            try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        } catch {
            return false
        }
        let configURL = workspace.appendingPathComponent("opencode.json")
        // Merge with any existing opencode.json so we never clobber user/other config.
        let existing = try? String(contentsOf: configURL, encoding: .utf8)
        guard let json = mergedNativeMCPConfigJSON(existingJSON: existing, registration: registration),
              let out = json.data(using: .utf8) else {
            return false
        }
        do {
            try out.write(to: configURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    nonisolated static func mergedNativeMCPConfigJSON(
        existingJSON: String?,
        registration: WorkNativeMCPRegistration
    ) -> String? {
        guard isValidNativeMCPRegistration(registration) else { return nil }
        var root: [String: Any] = {
            guard let existingJSON,
                  let data = existingJSON.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return [:]
            }
            return object
        }()
        var mcp = (root["mcp"] as? [String: Any]) ?? [:]
        mcp["epistemos-native"] = nativeMCPConfigBlock(registration)
        root["mcp"] = mcp
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return json
    }

    nonisolated static func nativeMCPConfigBlock(_ registration: WorkNativeMCPRegistration) -> [String: Any] {
        [
            "type": "remote",
            "url": registration.url,
            "headers": ["Authorization": "Bearer \(registration.token)"],
            "enabled": true,
        ]
    }

    nonisolated static func isValidNativeMCPRegistration(_ registration: WorkNativeMCPRegistration) -> Bool {
        registration.isTrustedLoopbackMCP
    }
}
