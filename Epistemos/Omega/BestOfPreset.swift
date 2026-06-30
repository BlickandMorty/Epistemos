import Darwin
import Foundation
#if canImport(agent_coreFFI)
import agent_coreFFI
#endif

private func readBoundedRegularFileNoFollow(at url: URL, maxBytes: Int) -> Data? {
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
        let remoteItemsByName = Dictionary(
            uniqueKeysWithValues: manifest(bundle: bundle).items
                .filter { $0.kind == .remoteMCP }
                .map { ($0.id, $0) }
        )

        var results: [BestOfPresetResult] = []
        var stillInstalled: Set<String> = []
        for name in receipt.remoteMCPServerNames.sorted() {
            guard let item = remoteItemsByName[name] else { continue }
            do {
                _ = try MCPUrlServerDirectory.uninstall(
                    name: name,
                    from: configURL,
                    fileManager: fileManager
                )
                results.append(result(item, .removed, "Removed preset-managed URL MCP server."))
            } catch {
                stillInstalled.insert(name)
                results.append(result(item, .failed(error.localizedDescription), error.localizedDescription))
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
            return result(item, .failed(error.localizedDescription), error.localizedDescription)
        }
    }

    private static func installSkillRepo(
        _ item: BestOfPresetItem,
        vaultPath: String?
    ) async -> BestOfPresetResult {
        guard let target = installTarget(for: item) else {
            return result(item, .unavailable, "No install target is bundled for this preset row.")
        }
        guard let vaultPath, !vaultPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return result(item, .unavailable, "Attach a vault before installing skill repositories.")
        }

        #if canImport(agent_coreFFI)
        do {
            let payload: [String: Any] = [
                "action": "install_from_github",
                "git_url": target,
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
                return result(item, .failed(error), error)
            }
            if !toolResult.success {
                return result(item, .failed("Skill install failed."), "Skill install failed.")
            }
            return result(item, .installed, "Installed skill repository through skill_manage.")
        } catch {
            return result(item, .failed(error.localizedDescription), error.localizedDescription)
        }
        #else
        return result(item, .unavailable, "agent_coreFFI bindings are unavailable.")
        #endif
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
            minDistribution: .coreAppStore,
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
            guard !isSymbolicLink(url) else { return }
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder.bestOfPresetEncoder.encode(receipt)
            guard data.count <= maxReceiptBytes else { return }
            try data.write(to: url, options: [.atomic])
        } catch {
            // Receipt persistence should not make the install path fail; a
            // missing receipt only makes later revert conservative.
        }
    }

    private static func isSymbolicLink(_ url: URL) -> Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil
    }
}

private extension JSONEncoder {
    nonisolated static var bestOfPresetEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
