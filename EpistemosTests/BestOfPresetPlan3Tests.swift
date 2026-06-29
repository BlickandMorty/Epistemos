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
        let directory = try loadMirroredSourceTextFile("Epistemos/Omega/MCPUrlServerDirectory.swift")

        for required in [
            "Shipped Plan 3 surface",
            "`MCPRegistryClient`",
            "`MCPUrlServerDirectory.write/install/uninstall`",
            "`ExtensionsDetailView`",
            "`BestOfPreset.swift`",
            "`VaultMCPCore`",
            "`VaultMCPServerSettingsRow`",
            "allowedToolNames: Set(VaultMCPCore.readToolNames)",
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
        ] {
            #expect(extensibility.contains(required), "Extensibility codepack missing shipped marker: \(required)")
        }

        for required in [
            "VaultMCPCore.swift` [DELIVERED]",
            "VaultMCPServer.swift` [DELIVERED]",
            "VaultMCPTokenStore.swift` [DELIVERED]",
            "VaultMCPHost.swift` [DELIVERED]",
            "VaultMCPServerSettingsRow.swift` [DELIVERED]",
            "AgentToolNameAliases.canonical",
            "ChatToolTier.readOnly",
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
}
