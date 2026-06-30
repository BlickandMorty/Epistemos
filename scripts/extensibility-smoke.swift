import Foundation

@main
enum ExtensibilitySmoke {
    static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("extensibility smoke failed: \(message)\n".utf8))
        exit(1)
    }

    static func main() async {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-extensibility-smoke-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        } catch {
            fail("could not create temp home: \(error)")
        }

        let configURL = MCPUrlServerDirectory.globalConfigURL(home: root)
        do {
            let installed = try MCPUrlServerDirectory.install(
                MCPUrlServerDirectory.WritableEntry(
                    name: "docs",
                    url: "https://docs.example.com/mcp",
                    authorizationTokenEnv: "DOCS_TOKEN"
                ),
                to: configURL
            )
            guard installed.count == 1,
                  installed[0].name == "docs",
                  installed[0].host == "docs.example.com",
                  installed[0].declaresAuth else {
                fail("direct URL MCP install did not round-trip")
            }

            let stored = try String(contentsOf: configURL, encoding: .utf8)
            guard stored.contains("DOCS_TOKEN"),
                  !stored.contains("secret-token") else {
                fail("URL MCP config leaked token value or missed env key")
            }

            do {
                _ = try MCPUrlServerDirectory.install(
                    MCPUrlServerDirectory.WritableEntry(
                        name: "bad",
                        url: "https://example.com/mcp?token=secret"
                    ),
                    to: configURL
                )
                fail("secret-bearing MCP URL was accepted")
            } catch MCPUrlServerDirectory.WriteError.secretBearingURLComponentPresent {
                // expected
            } catch {
                fail("secret-bearing MCP URL failed with unexpected error: \(error)")
            }

            _ = try MCPUrlServerDirectory.uninstall(name: "docs", from: configURL)
        } catch {
            fail("URL MCP config proof failed: \(error)")
        }

        let resourceURL = URL(fileURLWithPath: "Epistemos/Resources/best_of_preset.json")
        guard let resourceData = try? Data(contentsOf: resourceURL),
              let resourceManifest = try? JSONDecoder().decode(BestOfPresetManifest.self, from: resourceData),
              resourceManifest.items.contains(where: { $0.id == "context7" && $0.kind == .remoteMCP }),
              resourceManifest.items.contains(where: { $0.id == "anthropic-skills" && $0.minDistribution == .proResearch }) else {
            fail("bundled best_of_preset.json did not decode with expected rows")
        }

        let results = await BestOfPreset.apply(
            vaultPath: nil,
            distribution: .coreAppStore,
            home: root
        )
        let statuses = Dictionary(uniqueKeysWithValues: results.map { ($0.item.id, $0.status) })
        guard statuses["vault.search"] == .alreadyEnabled,
              statuses["context7"] == .installed,
              statuses["anthropic-skills"] == .proLocked else {
            fail("best-of apply produced unexpected statuses: \(statuses)")
        }

        let servers = MCPUrlServerDirectory.discover(
            cwd: root.appendingPathComponent("empty-project", isDirectory: true),
            home: root
        )
        guard servers.contains(where: { $0.name == "context7" && $0.url == "https://mcp.context7.com/mcp" }) else {
            fail("best-of apply did not install context7 URL MCP server")
        }

        let reverted = BestOfPreset.revertRemoteMCP(home: root)
        guard reverted.contains(where: { $0.item.id == "context7" && $0.status == .removed }) else {
            fail("best-of revert did not remove context7")
        }

        let afterRevert = MCPUrlServerDirectory.discover(
            cwd: root.appendingPathComponent("empty-project", isDirectory: true),
            home: root
        )
        guard !afterRevert.contains(where: { $0.name == "context7" }) else {
            fail("context7 remained after best-of revert")
        }

        print("extensibility smoke OK: url_mcp_write=true secret_url_rejected=true best_of_context7_installed=true pro_skill_locked=true revert=true")
    }
}
