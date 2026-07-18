import Foundation
import Testing

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("Free V1 agent-environment closure tests must compile in the App Store Free V1 target.")
#endif

@Suite("Free V1 agent-core environment closure")
struct FreeV1AgentCoreEnvironmentClosureTests {
    @Test("Free V1 does not compile agent credential discovery or environment mutation")
    func freeV1ExcludesAgentEnvironmentChoreography() throws {
        let bootstrap = try sourceText("Epistemos/App/AppBootstrap.swift")
        let runtimeState = try sourceText("Epistemos/State/ProductRuntimeState.swift")
        let globalAgentTypes = try #require(
            sourceSection(
                in: bootstrap,
                startingAt: "#if !EPISTEMOS_FREE_V1\nnonisolated struct StartupAutoDiscoveryKeyMapping",
                endingBefore: "@MainActor\nfinal class AppBootstrap"
            )
        )

        #expect(
            bootstrap.contains(
                "#if !EPISTEMOS_FREE_V1\nnonisolated struct StartupAutoDiscoveryKeyMapping"
            )
        )
        #expect(globalAgentTypes.contains("private actor AgentCoreEnvironmentScopeGate"))
        #expect(
            bootstrap.contains(
                "#if !EPISTEMOS_FREE_V1\n    private nonisolated static var agentCoreManagedOAuthEnvironmentVars"
            )
        )
        #expect(
            bootstrap.contains(
                "#if !EPISTEMOS_FREE_V1\n    nonisolated static func startupAutoDiscoveryReportForTesting("
            )
        )
        #expect(
            bootstrap.contains(
                "#if !EPISTEMOS_FREE_V1\n        if ProductCapabilityPolicy.isAvailable(.models)"
            )
        )
        #expect(!runtimeState.contains("FreeV1RuntimeState"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        let testDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let repositoryRoot = testDirectory.deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    private func sourceSection(in text: String, startingAt start: String, endingBefore end: String) -> String? {
        guard let startRange = text.range(of: start),
              let endRange = text[startRange.upperBound...].range(of: end) else {
            return nil
        }
        return String(text[startRange.lowerBound..<endRange.lowerBound])
    }
}
