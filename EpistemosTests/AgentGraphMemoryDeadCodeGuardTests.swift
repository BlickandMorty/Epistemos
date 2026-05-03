import Testing

/// Source guard for the Omega memory cleanup slice. `AgentGraphMemory` is still
/// the read/distill facade, but its old execution-writer path was unreachable
/// and must not drift back in without a new deliberation.
@Suite("AgentGraphMemory Dead Code Guard")
struct AgentGraphMemoryDeadCodeGuardTests {

    @Test("AgentGraphMemory no longer exposes the unreachable recordExecution writer")
    func recordExecutionWritePathStaysDeleted() throws {
        let source = try loadAgentGraphMemorySource()

        for forbidden in [
            "func recordExecution(",
            "steps: [AgentStepResult]",
            "nodesCreatedThisSession",
            "edgesCreatedThisSession",
            "extractSourceNode",
            "extractTags",
            "linkOrCreateTag",
            "truncateLabel",
        ] {
            #expect(!source.contains(forbidden),
                    "AgentGraphMemory should not retain dead execution-writer symbol: \(forbidden)")
        }
    }

    @Test("AgentGraphMemory keeps the live recall, source, context, and distillation APIs")
    func liveReadAndDistillSurfacesRemain() throws {
        let source = try loadAgentGraphMemorySource()

        for required in [
            "final class AgentGraphMemory",
            "func recall(query: String, limit: Int = 10) -> [GraphNodeRecord]",
            "func sourcesFor(executionNodeId: String) -> [GraphNodeRecord]",
            "func contextFor(topic: String, maxDepth: Int = 2) -> [GraphNodeRecord]",
            "func distillMemory(",
            "graphState?.requestIncrementalRemove(nodeId: id)",
        ] {
            #expect(source.contains(required),
                    "AgentGraphMemory must keep live read/distill surface: \(required)")
        }
    }

    private func loadAgentGraphMemorySource() throws -> String {
        try loadMirroredSourceTextFile("Epistemos/Omega/Knowledge/AgentGraphMemory.swift")
    }
}
