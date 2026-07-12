import Darwin
import Foundation
#if canImport(agent_coreFFI)
import agent_coreFFI
#endif

private nonisolated func readBoundedRegularFileNoFollow(at url: URL, maxBytes: Int) -> Data? {
    if (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil {
        return nil
    }
    guard FileManager.default.fileExists(atPath: url.path) else {
        return nil
    }

    let fd = url.path.withCString { path in
        open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
    }
    guard fd >= 0 else {
        return nil
    }

    var fileStatus = stat()
    guard fstat(fd, &fileStatus) == 0 else {
        close(fd)
        return nil
    }
    guard (fileStatus.st_mode & S_IFMT) == S_IFREG else {
        close(fd)
        return nil
    }
    guard fileStatus.st_nlink == 1 else {
        close(fd)
        return nil
    }
    guard fileStatus.st_size >= 0,
          UInt64(fileStatus.st_size) <= UInt64(maxBytes) else {
        close(fd)
        return nil
    }

    let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    defer { try? handle.close() }
    do {
        let data = try handle.readToEnd() ?? Data()
        guard data.count <= maxBytes else {
            return nil
        }
        return data
    } catch {
        return nil
    }
}

nonisolated enum BestOfPresetItemKind: String, Codable, Sendable {
    case builtinTool
    case skillRepo
    case remoteMCP
}

nonisolated enum BestOfPresetMinimumDistribution: String, Codable, Sendable {
    case coreAppStore
    case proResearch

    func isUnlocked(in distribution: ToolSurfacePolicy.Distribution) -> Bool {
        let resolved = ToolSurfacePolicy.resolvedDistribution(distribution)
        switch self {
        case .coreAppStore:
            return true
        case .proResearch:
            return resolved == .proResearch
        }
    }
}

nonisolated struct BestOfPresetManifest: Codable, Sendable {
    let items: [BestOfPresetItem]
}

nonisolated struct BestOfPresetItem: Codable, Equatable, Hashable, Identifiable, Sendable {
    let kind: BestOfPresetItemKind
    let id: String
    let displayName: String
    let why: String
    let minDistribution: BestOfPresetMinimumDistribution
    let installTarget: String?
}

nonisolated enum BestOfPresetStatus: Equatable, Sendable {
    case alreadyEnabled
    case installed
    case removed
    case proLocked
    case unavailable
    case conflict(String)
    case failed(String)

    var title: String {
        switch self {
        case .alreadyEnabled: "Already enabled"
        case .installed: "Installed"
        case .removed: "Removed"
        case .proLocked: "Pro only"
        case .unavailable: "Unavailable"
        case .conflict: "Conflict"
        case .failed: "Failed"
        }
    }
}

nonisolated struct BestOfPresetResult: Equatable, Sendable, Identifiable {
    let item: BestOfPresetItem
    let status: BestOfPresetStatus
    let detail: String

    var id: String { item.id }
}

nonisolated enum BestOfPresetDiagnostics {
    static let maxStatusMessageCharacters = MCPUrlServerDirectory.Diagnostics.maxFailureReasonCharacters

    static func message(_ value: String, fallback: String) -> String {
        MCPUrlServerDirectory.Diagnostics.failureReason(value, fallback: fallback)
    }

    static func externalErrorDescription(_ error: Error, fallback: String) -> String {
        if let writeError = error as? MCPUrlServerDirectory.WriteError {
            return message(writeError.errorDescription ?? fallback, fallback: fallback)
        }
        return MCPUrlServerDirectory.Diagnostics.externalErrorDescription(error, fallback: fallback)
    }
}

nonisolated enum BestOfPreset {
    static let maxManifestBytes = 64 * 1024

    static func manifest(bundle: Bundle = .main) -> BestOfPresetManifest {
        if let data = loadManifestData(bundle: bundle),
           let manifest = try? JSONDecoder().decode(BestOfPresetManifest.self, from: data) {
            return manifest
        }
        return fallbackManifest
    }

    static func installTarget(for item: BestOfPresetItem) -> String? {
        item.installTarget ?? fallbackTargets[item.id]
    }

    private static func loadManifestData(bundle: Bundle) -> Data? {
        guard let url = bundle.url(forResource: "best_of_preset", withExtension: "json") else {
            return nil
        }
        return readBoundedRegularFileNoFollow(at: url, maxBytes: maxManifestBytes)
    }

    static func apply(
        vaultPath: String?,
        distribution: ToolSurfacePolicy.Distribution = .currentBuild,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default,
        bundle: Bundle = .main
    ) async -> [BestOfPresetResult] {
        let items = manifest(bundle: bundle).items
        let configURL = MCPUrlServerDirectory.globalConfigURL(home: home)
        var receipt = BestOfPresetReceiptStore.load(home: home)
        var results: [BestOfPresetResult] = []

        for item in items {
            guard item.minDistribution.isUnlocked(in: distribution) else {
                results.append(result(item, .proLocked, "Unlocks in Pro."))
                continue
            }

            switch item.kind {
            case .builtinTool:
                let enabled = ToolSurfacePolicy.isSurfacedToolName(item.id, distribution: distribution)
                results.append(result(
                    item,
                    enabled ? .alreadyEnabled : .unavailable,
                    enabled ? "Built into this build profile." : "Not surfaced by this build profile."
                ))

            case .remoteMCP:
                let outcome = installRemoteMCP(
                    item,
                    configURL: configURL,
                    fileManager: fileManager,
                    receipt: &receipt
                )
                results.append(outcome)

            case .skillRepo:
                results.append(await installSkillRepo(item, vaultPath: vaultPath))
            }
        }

        BestOfPresetReceiptStore.save(receipt, home: home)
        return results
    }

    static func revertRemoteMCP(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default,
        bundle: Bundle = .main
    ) -> [BestOfPresetResult] {
        let receipt = BestOfPresetReceiptStore.load(home: home)
        guard !receipt.remoteMCPServerNames.isEmpty else { return [] }

        let configURL = MCPUrlServerDirectory.globalConfigURL(home: home)
        let currentEntries = MCPUrlServerDirectory.loadWritableEntries(
            from: configURL,
            fileManager: fileManager
        )
        let remoteItemsByName = Dictionary(
            uniqueKeysWithValues: manifest(bundle: bundle).items
                .filter { $0.kind == .remoteMCP }
                .map { ($0.id, $0) }
        )

        var results: [BestOfPresetResult] = []
        var stillInstalled: Set<String> = []
        for name in receipt.remoteMCPServerNames.sorted() {
            guard let item = remoteItemsByName[name] else { continue }
            let currentEntry = currentEntries.first { $0.name == name }
            if let currentEntry,
               let expectedTarget = installTarget(for: item),
               currentEntry.url != expectedTarget {
                let message = "Preset-managed URL MCP server now points somewhere else; not removed."
                stillInstalled.insert(name)
                results.append(result(item, .conflict(message), message))
                continue
            }
            do {
                _ = try MCPUrlServerDirectory.uninstall(
                    name: name,
                    from: configURL,
                    fileManager: fileManager
                )
                results.append(result(item, .removed, "Removed preset-managed URL MCP server."))
            } catch {
                stillInstalled.insert(name)
                let message = BestOfPresetDiagnostics.externalErrorDescription(
                    error,
                    fallback: "Preset revert failed."
                )
                results.append(result(item, .failed(message), message))
            }
        }

        BestOfPresetReceiptStore.save(
            BestOfPresetReceipt(remoteMCPServerNames: stillInstalled),
            home: home
        )
        return results
    }

    private static func installRemoteMCP(
        _ item: BestOfPresetItem,
        configURL: URL,
        fileManager: FileManager,
        receipt: inout BestOfPresetReceipt
    ) -> BestOfPresetResult {
        guard let target = installTarget(for: item) else {
            return result(item, .unavailable, "No install target is bundled for this preset row.")
        }

        let existing = MCPUrlServerDirectory.loadWritableEntries(
            from: configURL,
            fileManager: fileManager
        )
        if let current = existing.first(where: { $0.name == item.id }) {
            guard current.url == target else {
                return result(
                    item,
                    .conflict("A server named \(item.id) already points somewhere else."),
                    "A server named \(item.id) already points somewhere else."
                )
            }
            return result(item, .alreadyEnabled, "URL MCP server is already configured.")
        }

        do {
            _ = try MCPUrlServerDirectory.install(
                MCPUrlServerDirectory.WritableEntry(name: item.id, url: target),
                to: configURL,
                fileManager: fileManager
            )
            receipt.remoteMCPServerNames.insert(item.id)
            return result(item, .installed, "Installed URL MCP server config.")
        } catch {
            let message = BestOfPresetDiagnostics.externalErrorDescription(
                error,
                fallback: "Preset install failed."
            )
            return result(item, .failed(message), message)
        }
    }

    private static func installSkillRepo(
        _ item: BestOfPresetItem,
        vaultPath: String?
    ) async -> BestOfPresetResult {
        guard let target = installTarget(for: item) else {
            return result(item, .unavailable, "No install target is bundled for this preset row.")
        }
        guard let gitHubTarget = skillRepoGitHubTarget(target) else {
            return result(item, .unavailable, "Skill repository target must be a clean GitHub HTTPS repository URL.")
        }
        guard let vaultPath, !vaultPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return result(item, .unavailable, "Attach a vault before installing skill repositories.")
        }

        #if canImport(agent_coreFFI)
        do {
            let payload: [String: Any] = [
                "action": "install_from_github",
                "git_url": gitHubTarget,
            ]
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
            let inputJSON = String(data: data, encoding: .utf8) ?? "{}"
            let toolResult = try await executeToolCall(
                vaultPath: vaultPath,
                tier: "agent",
                toolName: "skill_manage",
                inputJson: inputJSON
            )
            if let error = toolResult.error, !error.isEmpty {
                let message = BestOfPresetDiagnostics.message(error, fallback: "Skill install failed.")
                return result(item, .failed(message), message)
            }
            if !toolResult.success {
                return result(item, .failed("Skill install failed."), "Skill install failed.")
            }
            return result(item, .installed, "Installed skill repository through skill_manage.")
        } catch {
            let message = BestOfPresetDiagnostics.externalErrorDescription(
                error,
                fallback: "Skill install failed."
            )
            return result(item, .failed(message), message)
        }
        #else
        return result(item, .unavailable, "agent_coreFFI bindings are unavailable.")
        #endif
    }

    private static func skillRepoGitHubTarget(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "https",
              components.host?.lowercased() == "github.com",
              components.user == nil,
              components.password == nil,
              components.percentEncodedQuery == nil,
              components.percentEncodedFragment == nil else {
            return nil
        }
        let pathSegments = components.percentEncodedPath
            .split(separator: "/", omittingEmptySubsequences: true)
        guard pathSegments.count == 2,
              pathSegments.allSatisfy({ segment in
                  let lowered = segment.lowercased()
                  return !segment.isEmpty && !lowered.contains("%2f") && !lowered.contains("%5c")
              }) else {
            return nil
        }
        return trimmed
    }

    private static func result(
        _ item: BestOfPresetItem,
        _ status: BestOfPresetStatus,
        _ detail: String
    ) -> BestOfPresetResult {
        BestOfPresetResult(item: item, status: status, detail: detail)
    }

    private static let fallbackTargets: [String: String] = [
        "context7": "https://mcp.context7.com/mcp",
        "anthropic-skills": "https://github.com/anthropics/skills",
    ]

    private static let fallbackManifest = BestOfPresetManifest(items: [
        BestOfPresetItem(
            kind: .builtinTool,
            id: "vault.search",
            displayName: "Vault Search",
            why: "Ground answers in the local vault.",
            minDistribution: .coreAppStore,
            installTarget: nil
        ),
        BestOfPresetItem(
            kind: .builtinTool,
            id: "vault.read",
            displayName: "Vault Read",
            why: "Open exact markdown evidence when search finds a note.",
            minDistribution: .coreAppStore,
            installTarget: nil
        ),
        BestOfPresetItem(
            kind: .builtinTool,
            id: "eidos.query",
            displayName: "Eidos Query",
            why: "Select stronger evidence before answering.",
            minDistribution: .coreAppStore,
            installTarget: nil
        ),
        BestOfPresetItem(
            kind: .builtinTool,
            id: "web.search",
            displayName: "Web Search",
            why: "Find current public sources without subprocess automation.",
            minDistribution: .coreAppStore,
            installTarget: nil
        ),
        BestOfPresetItem(
            kind: .builtinTool,
            id: "web.fetch",
            displayName: "Web Fetch",
            why: "Fetch source pages directly over HTTPS.",
            minDistribution: .coreAppStore,
            installTarget: nil
        ),
        BestOfPresetItem(
            kind: .builtinTool,
            id: "graph.query",
            displayName: "Graph Query",
            why: "Use the vault graph as a live retrieval surface.",
            minDistribution: .coreAppStore,
            installTarget: nil
        ),
        BestOfPresetItem(
            kind: .builtinTool,
            id: "graph.neighbors",
            displayName: "Graph Neighbors",
            why: "Expand from a known note into related local context.",
            minDistribution: .coreAppStore,
            installTarget: nil
        ),
        BestOfPresetItem(
            kind: .remoteMCP,
            id: "context7",
            displayName: "Context7",
            why: "Add a hosted MCP server for current library documentation.",
            minDistribution: .proResearch,
            installTarget: "https://mcp.context7.com/mcp"
        ),
        BestOfPresetItem(
            kind: .skillRepo,
            id: "anthropic-skills",
            displayName: "Anthropic Skills",
            why: "Install the public Agent Skills examples in Pro builds.",
            minDistribution: .proResearch,
            installTarget: "https://github.com/anthropics/skills"
        ),
    ])
}

nonisolated struct BestOfPresetReceipt: Codable, Equatable, Sendable {
    var remoteMCPServerNames: Set<String>
}

nonisolated enum BestOfPresetReceiptStore {
    private static let maxReceiptBytes = 64 * 1024

    static func receiptURL(home: URL) -> URL {
        home.appendingPathComponent(".config")
            .appendingPathComponent("mcp")
            .appendingPathComponent("epistemos_best_of_preset_receipt.json")
    }

    static func load(home: URL) -> BestOfPresetReceipt {
        let url = receiptURL(home: home)
        guard let data = readBoundedRegularFileNoFollow(at: url, maxBytes: maxReceiptBytes),
              let receipt = try? JSONDecoder().decode(BestOfPresetReceipt.self, from: data) else {
            return BestOfPresetReceipt(remoteMCPServerNames: [])
        }
        return receipt
    }

    static func save(_ receipt: BestOfPresetReceipt, home: URL) {
        let url = receiptURL(home: home)
        do {
            try rejectReceiptPathSymlinkComponents(url.deletingLastPathComponent())
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try rejectReceiptPathSymlinkComponents(url.deletingLastPathComponent())
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: url.deletingLastPathComponent().path
            )
            let data = try JSONEncoder.bestOfPresetEncoder.encode(receipt)
            guard data.count <= maxReceiptBytes else { return }
            try writeReceiptDataNoFollow(data, to: url)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            // Receipt persistence should not make the install path fail; a
            // missing receipt only makes later revert conservative.
        }
    }

    private static func writeReceiptDataNoFollow(_ data: Data, to url: URL) throws {
        if let existingStatus = fileStatusNoFollow(url) {
            guard (existingStatus.st_mode & S_IFMT) == S_IFREG,
                  existingStatus.st_nlink == 1 else {
                throw NSError(domain: "BestOfPresetReceiptStore", code: Int(EFTYPE))
            }
        }

        let tempURL = url
            .deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp", isDirectory: false)
        var didRename = false
        defer {
            if !didRename {
                try? FileManager.default.removeItem(at: tempURL)
            }
        }

        let fd = tempURL.path.withCString { path in
            open(path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, mode_t(0o600))
        }
        guard fd >= 0 else {
            throw NSError(domain: "BestOfPresetReceiptStore", code: Int(errno))
        }

        var fileStatus = stat()
        guard fstat(fd, &fileStatus) == 0 else {
            let capturedErrno = errno
            close(fd)
            throw NSError(domain: "BestOfPresetReceiptStore", code: Int(capturedErrno))
        }
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG else {
            close(fd)
            throw NSError(domain: "BestOfPresetReceiptStore", code: Int(EFTYPE))
        }
        guard fileStatus.st_nlink == 1 else {
            close(fd)
            throw NSError(domain: "BestOfPresetReceiptStore", code: Int(EFTYPE))
        }

        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        do {
            try handle.write(contentsOf: data)
            try handle.synchronize()
            try handle.close()
            guard rename(tempURL.path, url.path) == 0 else {
                throw NSError(domain: "BestOfPresetReceiptStore", code: Int(errno))
            }
            didRename = true
        } catch {
            try? handle.close()
            throw error
        }
    }

    private static func fileStatusNoFollow(_ url: URL) -> stat? {
        var fileStatus = stat()
        let result = url.path.withCString { path in
            lstat(path, &fileStatus)
        }
        return result == 0 ? fileStatus : nil
    }

    private static func rejectReceiptPathSymlinkComponents(_ url: URL) throws {
        if try firstExistingSymlinkComponent(in: url) != nil {
            throw NSError(domain: "BestOfPresetReceiptStore", code: Int(ELOOP))
        }
    }

    private static func firstExistingSymlinkComponent(in url: URL) throws -> URL? {
        let standardized = url.standardizedFileURL
        let path = standardized.path
        let components = path.split(separator: "/", omittingEmptySubsequences: true)
        var current = path.hasPrefix("/")
            ? URL(fileURLWithPath: "/", isDirectory: true)
            : URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)

        for component in components {
            current = current.appendingPathComponent(String(component), isDirectory: false)
            var fileStatus = stat()
            guard lstat(current.path, &fileStatus) == 0 else {
                if errno == ENOENT || errno == ENOTDIR {
                    return nil
                }
                throw NSError(domain: "BestOfPresetReceiptStore", code: Int(errno))
            }
            if (fileStatus.st_mode & S_IFMT) == S_IFLNK,
               !isAllowedSystemSymlinkComponent(current, fileStatus: fileStatus) {
                return current
            }
        }
        return nil
    }

    private static func isAllowedSystemSymlinkComponent(_ url: URL, fileStatus: stat) -> Bool {
        url.deletingLastPathComponent().path == "/" && fileStatus.st_uid == 0
    }
}

private extension JSONEncoder {
    nonisolated static var bestOfPresetEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
