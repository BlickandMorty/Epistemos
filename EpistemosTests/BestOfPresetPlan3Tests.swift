import Foundation
import Testing

@testable import Epistemos

@Suite("Plan 3 best-of preset")
struct BestOfPresetPlan3Tests {
    @Test("Plan 3 extensibility docs track shipped MCP, preset, and vault server surfaces")
    func docsTrackShippedExtensibilitySurface() throws {
        let capability = try loadMirroredSourceTextFile("docs/research/PLAN_3_CAPABILITIES_2026_06_28.md")
        let extensibility = try loadMirroredSourceTextFile("docs/research/PLAN_3_EXTENSIBILITY_CODEPACK_2026_06_28.md")
        let vault = try loadMirroredSourceTextFile("docs/research/PLAN_3_VAULT_MCP_CODEPACK_2026_06_28.md")
        let registry = try loadMirroredSourceTextFile("Epistemos/Omega/MCPRegistryClient.swift")
        let directory = try loadMirroredSourceTextFile("Epistemos/Omega/MCPUrlServerDirectory.swift")
        let extensionsView = try loadMirroredSourceTextFile("Epistemos/Views/Settings/ExtensionsDetailView.swift")

        for required in [
            "Shipped Plan 3 surface",
            "`MCPRegistryClient`",
            "`MCPUrlServerDirectory.write/install/uninstall`",
            "`ExtensionsDetailView`",
            "`BestOfPreset.swift`",
            "`VaultMCPCore`",
            "`VaultMCPServerSettingsRow`",
            "allowedToolNames: Set(VaultMCPCore.readToolNames)",
            "cap request bodies at 8 MiB",
            "registry display fields raw-capped and control-stripped",
            "raw failure/domain strings and success-message display names\nbounded and control/whitespace-normalized",
            "raw listener/domain strings and protocol diagnostic strings bounded and control/whitespace-normalized before trim/validation",
        ] {
            #expect(capability.contains(required), "Capability doc missing shipped extensibility state: \(required)")
        }

        for required in [
            "MCPRegistryClient.swift` [DELIVERED]",
            "MCPUrlServerDirectory.write/install/uninstall` [DELIVERED]",
            "ExtensionsDetailView.swift` [DELIVERED]",
            "BestOfPreset.swift` + `Epistemos/Resources/best_of_preset.json` [DELIVERED]",
            "SkillsDetailView()",
            "MCPServersDetailView",
            "BrowserUseSettingsView",
            "off the SwiftUI path",
            "Registry fields are raw-capped, control-stripped",
            "raw failure/domain strings and success-message display names bounded and control/whitespace-normalized",
            "raw-bounded MCP URL diagnostic helper",
        ] {
            #expect(extensibility.contains(required), "Extensibility codepack missing shipped marker: \(required)")
        }

        for required in [
            "Task.detached(priority: .utility)",
            "MCPServerSettingsOperationOutcome",
            "MCPUrlServerDirectory.discover()",
            "BestOfPreset.manifest().items",
            "rows = loadedRows",
            "BestOfPreset.apply(vaultPath: selectedVaultPath)",
            "BestOfPreset.revertRemoteMCP()",
            "ToolbarCapsuleButton(",
            "chromePolicy: .alwaysSurface",
            "@Environment(UIState.self)",
            "private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }",
            "ui.theme.resolved.accent.color",
            "ui.theme.resolved.headingAccent.color",
            "ui.theme.resolved.mutedForeground.color",
            "settingsFlatInputChrome(theme: theme",
            "tint(theme: ui.theme)",
            "extensionSettingsRowGap()",
        ] {
            #expect(extensionsView.contains(required), "ExtensionsDetailView missing off-main operation marker: \(required)")
        }
        #expect(!extensionsView.contains(".buttonStyle(.plain)"))
        #expect(!extensionsView.contains(".foregroundStyle(.secondary)"))
        #expect(!extensionsView.contains(".textFieldStyle(.roundedBorder)"))
        #expect(!extensionsView.contains("Divider()"))
        #expect(!extensionsView.contains("tint: .green"))
        #expect(!extensionsView.contains("tint: .orange"))
        #expect(!extensionsView.contains("tint: .red"))
        #expect(!extensionsView.contains("return .green"))
        #expect(!extensionsView.contains("return .orange"))
        #expect(!extensionsView.contains("return .red"))

        for required in [
            "maxRegistryFieldLength",
            "maxRegistryLookupDepth",
            "boundedRegistryString",
            "unicodeScalars.prefix(maxRegistryFieldLength + 128)",
            "CharacterSet.controlCharacters",
            "normalizedLimit",
            "isAllowedRegistryResponseURL",
            "response.host?.lowercased() == request.host?.lowercased()",
            "response.percentEncodedPath == request.percentEncodedPath",
            "response.percentEncodedQuery == request.percentEncodedQuery",
            "String(trimmed.prefix(maxRegistryFieldLength))",
            "homepageURL",
            "components.host?.lowercased() == \"github.com\"",
            "components.percentEncodedQuery == nil",
            "components.percentEncodedFragment == nil",
        ] {
            #expect(registry.contains(required), "MCPRegistryClient missing bounded registry guard: \(required)")
        }

        for required in [
            "maxConfigBytes",
            "loadConfigData",
            "String(message.prefix(maxFailureReasonCharacters + 32))",
            "String(domain.prefix(maxDomainCharacters + 32))",
            "maxFailureReasonCharacters - 3",
            "destinationOfSymbolicLink",
            "attributes[.type] as? FileAttributeType == .typeRegular",
            "open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)",
            "writeConfigDataNoFollow",
            "open(path, O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW | O_CLOEXEC",
            "fstat(fd",
            "readToEnd()",
            "data.count <= maxConfigBytes",
        ] {
            #expect(directory.contains(required), "MCPUrlServerDirectory missing bounded config-file guard: \(required)")
        }

        for required in [
            "VaultMCPCore.swift` [DELIVERED]",
            "VaultMCPServer.swift` [DELIVERED]",
            "VaultMCPTokenStore.swift` [DELIVERED]",
            "VaultMCPHost.swift` [DELIVERED]",
            "VaultMCPServerSettingsRow.swift` [DELIVERED]",
            "AgentToolNameAliases.canonical",
            "ChatToolTier.readOnly",
            "Direct core dispatch rejects JSON-RPC request strings over the 8 MiB cap",
            "requires a JSON-RPC 2.0 object envelope",
            "Swift method/tool protocol diagnostics bound and control/whitespace-normalize raw strings before trimming",
            "bounds and control/whitespace-normalizes raw listener/domain strings before",
        ] {
            #expect(vault.contains(required), "Vault MCP codepack missing shipped marker: \(required)")
        }

        for stale in [
            "read-only — no",
            "no writer",
            "NEW `Epistemos/Omega/MCPRegistryClient.swift`",
            "NEW writer `MCPUrlServerDirectory.write/install/uninstall`",
            "NEW `Epistemos/Views/Settings/ExtensionsDetailView.swift`",
            "Genuinely new (no preset concept exists). **Build:**",
            "~80% built",
            "**Build:** a read-only `VaultMCPCore`",
            "We deliberately do NOT expose an add/enable/disable mutation here",
        ] {
            #expect(!capability.contains(stale), "Capability doc kept stale extensibility claim: \(stale)")
            #expect(!extensibility.contains(stale), "Extensibility codepack kept stale claim: \(stale)")
            #expect(!vault.contains(stale), "Vault MCP codepack kept stale claim: \(stale)")
            #expect(!directory.contains(stale), "MCPUrlServerDirectory kept stale source comment: \(stale)")
        }
    }

    @Test("registry entries strip controls before display and ids")
    func registryEntriesStripControlsBeforeDisplayAndIDs() async throws {
        let payload = """
        {
          "servers": [
            {
              "name": " Context\\u0000\\n7 ",
              "description": "Docs\\rserver",
              "remoteUrl": "https://mcp.context7.com/mcp"
            }
          ]
        }
        """
        let client = MCPRegistryClient { request in
            let response = HTTPURLResponse(
                url: try #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
            return (Data(payload.utf8), try #require(response))
        }

        let entries = await client.searchSmithery(query: "docs")
        let entry = try #require(entries.first)

        #expect(entry.name == "Context7")
        #expect(entry.description == "Docsserver")
        #expect(entry.id == "smithery:remote:context7")
        #expect(entry.name.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) })
        #expect(entry.description.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) })
    }

    @Test("apply reports built-ins and installs only missing remote MCP rows")
    func applyInstallsRemoteMCP() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("best-of-apply-\(UUID().uuidString)")
        let home = root.appendingPathComponent("home")
        defer { try? FileManager.default.removeItem(at: root) }

        let results = await BestOfPreset.apply(
            vaultPath: nil,
            distribution: .coreAppStore,
            home: home
        )

        let vaultSearch = try #require(results.first { $0.item.id == "vault.search" })
        #expect(vaultSearch.status == .alreadyEnabled)

        let context7 = try #require(results.first { $0.item.id == "context7" })
        #expect(context7.status == .installed)

        let servers = MCPUrlServerDirectory.discover(
            cwd: root.appendingPathComponent("project"),
            home: home
        )
        #expect(servers.map(\.name).contains("context7"))

        let receipt = BestOfPresetReceiptStore.load(home: home)
        #expect(receipt.remoteMCPServerNames == ["context7"])
    }

    @Test("revert removes only receipt-owned remote MCP servers")
    func revertLeavesUserServersAlone() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("best-of-revert-\(UUID().uuidString)")
        let home = root.appendingPathComponent("home")
        let config = MCPUrlServerDirectory.globalConfigURL(home: home)
        defer { try? FileManager.default.removeItem(at: root) }

        _ = await BestOfPreset.apply(
            vaultPath: nil,
            distribution: .coreAppStore,
            home: home
        )
        _ = try MCPUrlServerDirectory.install(
            MCPUrlServerDirectory.WritableEntry(name: "user-owned", url: "https://user.example.com/mcp"),
            to: config
        )

        let results = BestOfPreset.revertRemoteMCP(home: home)
        #expect(results.map(\.item.id) == ["context7"])
        #expect(results.first?.status == .removed)

        let servers = MCPUrlServerDirectory.discover(
            cwd: root.appendingPathComponent("project"),
            home: home
        )
        #expect(servers.map(\.name) == ["user-owned"])
        #expect(BestOfPresetReceiptStore.load(home: home).remoteMCPServerNames.isEmpty)
    }

    @Test("apply does not replace a user server with the preset name")
    func applyDoesNotOverwriteConflictingRemoteMCP() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("best-of-conflict-\(UUID().uuidString)")
        let home = root.appendingPathComponent("home")
        let config = MCPUrlServerDirectory.globalConfigURL(home: home)
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try MCPUrlServerDirectory.install(
            MCPUrlServerDirectory.WritableEntry(name: "context7", url: "https://custom.example.com/mcp"),
            to: config
        )

        let results = await BestOfPreset.apply(
            vaultPath: nil,
            distribution: .coreAppStore,
            home: home
        )
        let context7 = try #require(results.first { $0.item.id == "context7" })
        if case .conflict = context7.status {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected conflict for user-owned context7 server")
        }

        let servers = MCPUrlServerDirectory.discover(
            cwd: root.appendingPathComponent("project"),
            home: home
        )
        #expect(servers.first { $0.name == "context7" }?.url == "https://custom.example.com/mcp")
        #expect(BestOfPresetReceiptStore.load(home: home).remoteMCPServerNames.isEmpty)
    }

    @Test("preset diagnostics redact external error details and cap messages")
    func presetDiagnosticsRedactExternalErrorDetailsAndCapMessages() {
        let privatePath = "/Users/example/Private Vault/best-of.json"
        let error = NSError(
            domain: privatePath,
            code: 17,
            userInfo: [NSLocalizedDescriptionKey: "failed at \(privatePath)"]
        )
        let redacted = BestOfPresetDiagnostics.externalErrorDescription(
            error,
            fallback: "Preset install failed."
        )

        #expect(redacted.contains("Preset install failed."))
        #expect(redacted.contains("domain=Error"))
        #expect(redacted.contains("code=17"))
        #expect(redacted.count <= BestOfPresetDiagnostics.maxStatusMessageCharacters)
        #expect(!redacted.contains(privatePath))
        #expect(!redacted.contains("failed at"))

        let longMessage = String(repeating: "x", count: BestOfPresetDiagnostics.maxStatusMessageCharacters + 50)
        let capped = BestOfPresetDiagnostics.message(longMessage, fallback: "Skill install failed.")
        #expect(capped.count == BestOfPresetDiagnostics.maxStatusMessageCharacters)
        #expect(capped.hasSuffix("..."))
    }

    @Test("manifest loader accepts bounded regular bundled manifests")
    func manifestLoaderAcceptsBoundedBundleManifest() throws {
        let json = """
        {
          "items": [
            {
              "kind": "builtinTool",
              "id": "custom.builtin",
              "displayName": "Custom",
              "why": "Fixture row",
              "minDistribution": "coreAppStore",
              "installTarget": null
            }
          ]
        }
        """
        let fixture = try Self.makeBestOfPresetBundle(data: Data(json.utf8))
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let manifest = BestOfPreset.manifest(bundle: fixture.bundle)

        #expect(manifest.items.map(\.id) == ["custom.builtin"])
    }

    @Test("manifest loader falls back for oversized bundled manifests")
    func manifestLoaderRejectsOversizedBundleManifest() throws {
        let oversizedWhy = String(repeating: "A", count: BestOfPreset.maxManifestBytes)
        let json = """
        {
          "items": [
            {
              "kind": "remoteMCP",
              "id": "malicious",
              "displayName": "Malicious",
              "why": "\(oversizedWhy)",
              "minDistribution": "coreAppStore",
              "installTarget": "https://malicious.example.com/mcp"
            }
          ]
        }
        """
        let data = Data(json.utf8)
        let fixture = try Self.makeBestOfPresetBundle(data: data)
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        #expect(data.count > BestOfPreset.maxManifestBytes)
        let manifest = BestOfPreset.manifest(bundle: fixture.bundle)

        #expect(!manifest.items.map(\.id).contains("malicious"))
        #expect(manifest.items.map(\.id).contains("context7"))
    }

    @Test("manifest loader does not follow symlinked bundled manifests")
    func manifestLoaderRejectsSymlinkedBundleManifest() throws {
        let outsideRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("best-of-manifest-outside-\(UUID().uuidString)")
        let outsideURL = outsideRoot.appendingPathComponent("outside.json")
        defer { try? FileManager.default.removeItem(at: outsideRoot) }
        try FileManager.default.createDirectory(at: outsideRoot, withIntermediateDirectories: true)
        try """
        {
          "items": [
            {
              "kind": "remoteMCP",
              "id": "malicious",
              "displayName": "Malicious",
              "why": "Symlinked fixture",
              "minDistribution": "coreAppStore",
              "installTarget": "https://malicious.example.com/mcp"
            }
          ]
        }
        """.write(to: outsideURL, atomically: true, encoding: .utf8)

        let fixture = try Self.makeBestOfPresetBundle(symlinkTarget: outsideURL)
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let manifest = BestOfPreset.manifest(bundle: fixture.bundle)

        #expect(!manifest.items.map(\.id).contains("malicious"))
        #expect(manifest.items.map(\.id).contains("context7"))
    }

    @Test("receipt store ignores oversized receipt files")
    func receiptStoreIgnoresOversizedFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("best-of-oversized-receipt-\(UUID().uuidString)")
        let home = root.appendingPathComponent("home")
        let receiptURL = BestOfPresetReceiptStore.receiptURL(home: home)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(
            at: receiptURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(repeating: UInt8(ascii: "{"), count: 70 * 1024).write(to: receiptURL)

        #expect(BestOfPresetReceiptStore.load(home: home).remoteMCPServerNames.isEmpty)
    }

    @Test("receipt store does not read or overwrite a symlinked receipt")
    func receiptStoreRejectsSymlinkedReceiptPath() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("best-of-symlink-receipt-\(UUID().uuidString)")
        let home = root.appendingPathComponent("home")
        let receiptURL = BestOfPresetReceiptStore.receiptURL(home: home)
        let outsideURL = root.appendingPathComponent("outside.json")
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(
            at: receiptURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try #"{"remoteMCPServerNames":["context7"]}"#.write(to: outsideURL, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: receiptURL, withDestinationURL: outsideURL)

        #expect(BestOfPresetReceiptStore.load(home: home).remoteMCPServerNames.isEmpty)

        BestOfPresetReceiptStore.save(
            BestOfPresetReceipt(remoteMCPServerNames: ["context7"]),
            home: home
        )

        let outside = try String(contentsOf: outsideURL, encoding: .utf8)
        #expect(outside == #"{"remoteMCPServerNames":["context7"]}"#)
        #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: receiptURL.path)) != nil)
    }

    @Test("receipt store does not write through a symlinked receipt directory")
    func receiptStoreRejectsSymlinkedReceiptDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("best-of-symlink-receipt-dir-\(UUID().uuidString)")
        let home = root.appendingPathComponent("home")
        let realMCPDirectory = root.appendingPathComponent("outside-mcp", isDirectory: true)
        let mcpDirectory = home
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("mcp", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(
            at: mcpDirectory.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(at: realMCPDirectory, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: mcpDirectory, withDestinationURL: realMCPDirectory)

        BestOfPresetReceiptStore.save(
            BestOfPresetReceipt(remoteMCPServerNames: ["context7"]),
            home: home
        )

        #expect(BestOfPresetReceiptStore.load(home: home).remoteMCPServerNames.isEmpty)
        #expect(!FileManager.default.fileExists(
            atPath: realMCPDirectory
                .appendingPathComponent("epistemos_best_of_preset_receipt.json", isDirectory: false)
                .path
        ))
    }

    @Test("skill repo preset rows reject non-GitHub install targets before invoking tools")
    func skillRepoRowsRejectNonGitHubTargets() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("best-of-skill-target-\(UUID().uuidString)")
        let home = root.appendingPathComponent("home")
        let json = """
        {
          "items": [
            {
              "kind": "skillRepo",
              "id": "bad-skill",
              "displayName": "Bad Skill",
              "why": "Should not invoke skill_manage",
              "minDistribution": "proResearch",
              "installTarget": "https://github.com/owner/repo?token=abc123"
            }
          ]
        }
        """
        let fixture = try Self.makeBestOfPresetBundle(data: Data(json.utf8))
        defer {
            try? FileManager.default.removeItem(at: fixture.root)
            try? FileManager.default.removeItem(at: root)
        }

        let results = await BestOfPreset.apply(
            vaultPath: root.appendingPathComponent("vault").path,
            distribution: .proResearch,
            home: home,
            bundle: fixture.bundle
        )

        let result = try #require(results.first)
        #expect(result.item.id == "bad-skill")
        #expect(result.status == .unavailable)
        #expect(result.detail == "Skill repository target must be a clean GitHub HTTPS repository URL.")
    }

    @Test("receipt store source keeps bounded non-symlink file contract")
    func receiptStoreSourceGuard() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Omega/BestOfPreset.swift")
        for required in [
            "maxManifestBytes",
            "loadManifestData",
            "maxReceiptBytes",
            "readBoundedRegularFileNoFollow",
            "destinationOfSymbolicLink",
            "open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)",
            "fstat(fd",
            "readToEnd()",
            "readBoundedRegularFileNoFollow(at: url, maxBytes: maxManifestBytes)",
            "readBoundedRegularFileNoFollow(at: url, maxBytes: maxReceiptBytes)",
            "data.count <= maxBytes",
            "data.count <= maxReceiptBytes",
            "writeReceiptDataNoFollow",
            "open(path, O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW | O_CLOEXEC",
            "rejectReceiptPathSymlinkComponents",
            "firstExistingSymlinkComponent",
            "BestOfPresetDiagnostics.externalErrorDescription",
            "BestOfPresetDiagnostics.message",
            "skillRepoGitHubTarget",
            "components.host?.lowercased() == \"github.com\"",
            "components.percentEncodedQuery == nil",
            "components.percentEncodedFragment == nil",
        ] {
            #expect(source.contains(required), "BestOfPreset receipt store missing hardening marker: \(required)")
        }
        #expect(!source.contains("Data(contentsOf: url)"))
        #expect(!source.contains("error.localizedDescription"))
    }

    private static func makeBestOfPresetBundle(
        data: Data? = nil,
        symlinkTarget: URL? = nil
    ) throws -> (bundle: Bundle, root: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BestOfPresetFixture-\(UUID().uuidString).bundle", isDirectory: true)
        let contents = root.appendingPathComponent("Contents", isDirectory: true)
        let resources = contents.appendingPathComponent("Resources", isDirectory: true)
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>CFBundleIdentifier</key>
          <string>com.epistemos.best-of-fixture.\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))</string>
          <key>CFBundlePackageType</key>
          <string>BNDL</string>
          <key>CFBundleVersion</key>
          <string>1</string>
        </dict>
        </plist>
        """.write(to: contents.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)

        let manifestURL = resources.appendingPathComponent("best_of_preset.json")
        if let symlinkTarget {
            try FileManager.default.createSymbolicLink(at: manifestURL, withDestinationURL: symlinkTarget)
        } else {
            try (data ?? Data()).write(to: manifestURL)
        }

        return (try #require(Bundle(url: root)), root)
    }
}
