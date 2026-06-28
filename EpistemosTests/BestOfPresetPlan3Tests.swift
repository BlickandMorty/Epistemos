import Foundation
import Testing

@testable import Epistemos

@Suite("Plan 3 best-of preset")
struct BestOfPresetPlan3Tests {
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
