import Foundation
import Testing

/// Source guards for the post-PR44 AgentEvent decision: `GhostComputerAgent`
/// must stay explicitly unrouted unless a future slice instruments it with
/// ComputerUseBridge-grade provenance first.
@Suite("GhostComputerAgent Reachability Guards")
struct GhostComputerAgentReachabilityGuardTests {

    @Test("production Swift does not instantiate GhostComputerAgent")
    func productionSwiftDoesNotInstantiateGhostComputerAgent() throws {
        let productionFiles = try mirroredSourceFileURLs(
            under: "Epistemos",
            includingExtensions: ["swift"]
        )

        for fileURL in productionFiles where fileURL.lastPathComponent != "GhostComputerAgent.swift" {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            let relativePath = try relativeSourcePath(fileURL)

            #expect(!source.contains("GhostComputerAgent("),
                    "\(relativePath) must not instantiate GhostComputerAgent without adding AgentEvent provenance")
        }
    }

    @Test("production Swift does not call GhostComputerAgent MCP adapters")
    func productionSwiftDoesNotCallGhostComputerAgentMCPAdapters() throws {
        let adapterCalls = [
            "GhostComputerAgent.mcpSee",
            "GhostComputerAgent.mcpClick",
            "GhostComputerAgent.mcpType",
            "GhostComputerAgent.mcpKeys",
            "GhostComputerAgent.mcpScroll",
            "GhostComputerAgent.mcpScreenshot",
        ]
        let productionFiles = try mirroredSourceFileURLs(
            under: "Epistemos",
            includingExtensions: ["swift"]
        )

        for fileURL in productionFiles where fileURL.lastPathComponent != "GhostComputerAgent.swift" {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            let relativePath = try relativeSourcePath(fileURL)

            for adapterCall in adapterCalls {
                #expect(!source.contains(adapterCall),
                        "\(relativePath) must not call \(adapterCall) without adding AgentEvent provenance")
            }
        }
    }

    @Test("shipping computer-use path stays on ComputerUseBridge")
    func shippingComputerUsePathStaysOnComputerUseBridge() throws {
        let phase4Bridge = try loadMirroredSourceTextFile("Epistemos/Bridge/Phase4Bridge.swift")
        let streamingDelegate = try loadMirroredSourceTextFile("Epistemos/Bridge/StreamingDelegate.swift")
        let agentLoop = try loadMirroredSourceTextFile("agent_core/src/agent_loop.rs")

        #expect(phase4Bridge.contains("ComputerUseBridge.shared.execute(actionJSON: actionJson)"),
                "Phase4Bridge computer-use dispatch must stay on the instrumented ComputerUseBridge path")
        #expect(streamingDelegate.contains("ComputerUseBridge.shared.execute(actionJSON: actionJson)"),
                "StreamingDelegate computer tool dispatch must stay on the instrumented ComputerUseBridge path")
        #expect(agentLoop.contains("if name == \"computer\""),
                "Rust agent loop must keep delegating computer-use as the canonical native tool marker")
    }

    @Test("GhostComputerAgent still exposes high-risk actions that require provenance if routed")
    func ghostComputerAgentHighRiskActionsRemainVisible() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Omega/Agents/GhostComputerAgent.swift")

        for marker in [
            "func execute(step: AgentStep)",
            "private func executeSee",
            "private func executeClick",
            "private func executeType",
            "private func executeScroll",
            "private func executeKeys",
            "private func executeScreenshot",
            "static func mcpSee",
            "static func mcpClick",
            "static func mcpType",
            "static func mcpKeys",
            "static func mcpScroll",
            "static func mcpScreenshot",
        ] {
            #expect(source.contains(marker),
                    "GhostComputerAgent source marker disappeared: \(marker). Re-audit reachability and provenance.")
        }

        #expect(source.contains("#if !EPISTEMOS_APP_STORE"),
                "GhostComputerAgent must remain outside the Core/App Store build")
        #expect(!source.contains("AgentToolProvenanceRecorder("),
                "If GhostComputerAgent becomes routed, add a dedicated provenance slice instead of silently half-instrumenting it")
    }

    private func relativeSourcePath(_ fileURL: URL) throws -> String {
        let root = try sourceMirrorRootURL().standardizedFileURL.path
        let path = fileURL.standardizedFileURL.path
        guard path.hasPrefix(root + "/") else {
            return fileURL.lastPathComponent
        }
        return String(path.dropFirst(root.count + 1))
    }
}
