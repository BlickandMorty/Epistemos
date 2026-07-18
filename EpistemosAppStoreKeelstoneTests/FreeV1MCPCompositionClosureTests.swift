import Foundation
import Testing

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("Free V1 MCP composition-closure tests must compile in the App Store target.")
#endif

@Suite("Free V1 MCP composition closure")
struct FreeV1MCPCompositionClosureTests {
    @Test("Free V1 does not inject a removed MCP bridge into the environment")
    func freeV1EnvironmentDoesNotReferenceMCPBridge() throws {
        let bootstrap = try sourceText("Epistemos/App/AppBootstrap.swift")
        let environment = try sourceText("Epistemos/App/AppEnvironment.swift")

        #expect(!bootstrap.contains("let mcpBridge = MCPBridge()"))
        #expect(!environment.contains(".environment(bootstrap.mcpBridge)"))
    }

    @Test("Free V1 removes unreachable remote MCP Settings and preset sources")
    func freeV1DoesNotShipRemoteMCPSettingsOrPresetSources() {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let retiredPaths = [
            "Epistemos/Views/Settings/ExtensionsDetailView.swift",
            "Epistemos/Omega/BestOfPreset.swift",
            "Epistemos/Omega/MCPRegistryClient.swift",
            "Epistemos/Omega/MCPUrlServerDirectory.swift",
            "Epistemos/Engine/CoworkConnectorDirectory.swift",
            "Epistemos/Resources/best_of_preset.json",
        ]

        for path in retiredPaths {
            #expect(
                !FileManager.default.fileExists(atPath: repositoryRoot.appendingPathComponent(path).path),
                "Free V1 must not ship retired remote-MCP source: \(path)"
            )
        }
    }

    private func sourceText(_ relativePath: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
