import Foundation
import Testing

/// Source guards for the post-PR45 AgentEvent decision: the obsolete
/// `GhostComputerAgent` path stays deleted while shipping computer-use remains
/// on the instrumented `ComputerUseBridge` route.
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

    // Cloud-only / Omega-removal migration: "shipping computer-use path stays on
    // ComputerUseBridge" removed — ComputerUseBridge + Phase4Bridge (the native
    // computer-use dispatch stack) were deleted, so there is no bridge path to lock.

    @Test("GhostComputerAgent source stays deleted")
    func ghostComputerAgentSourceStaysDeleted() throws {
        let deletedURL = try sourceMirrorURL(for: "Epistemos/Omega/Agents/GhostComputerAgent.swift")

        #expect(!FileManager.default.fileExists(atPath: deletedURL.path),
                "GhostComputerAgent was deleted because ComputerUseBridge is the canonical path; reintroducing it requires a fresh provenance deliberation")
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
