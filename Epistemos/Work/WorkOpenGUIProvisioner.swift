import Darwin
import Foundation

// #7 (MCP/tools): provision the OpenGUI Work workspace so the runtime-spawned opencode exposes Epistemos's FULL native
// tool surface. opencode reads `<workspace>/opencode.json` (verified: @opengui/runtime opencode-config.ts walks the
// directory up to it). We start the app-hosted native-tools MCP (WorkNativeMCPHost — W-R3, already built + verified)
// and MERGE an `mcp.epistemos-native` block into that file BEFORE the supervisor spawns opencode → opencode auto-loads
// it → the full native Epistemos tool surface (incl. computer-use) reaches the OpenGUI Work agent. Same block shape as
// the OpenWork-path nativeMCP registration. Best-effort: if the host can't start, opencode just keeps its default tools.
enum WorkOpenGUIProvisioner {
    private static let maxExistingConfigBytes = 1024 * 1024

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
        let existing = readExistingConfigTextNoFollow(at: configURL)
        guard let json = mergedNativeMCPConfigJSON(existingJSON: existing, registration: registration),
              let out = json.data(using: .utf8) else {
            return false
        }
        do {
            try writeOwnerOnlyConfigData(out, to: configURL)
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
