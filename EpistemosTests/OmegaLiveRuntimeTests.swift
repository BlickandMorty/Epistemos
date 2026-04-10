import Foundation
import Testing
@testable import Epistemos

// Legacy live runtime transcript tests are kept for reference while the old
// Omega live runtime surface stays retired from the current app.
#if false

@Suite("Omega Live Runtime")
@MainActor
struct OmegaLiveRuntimeTests {
    private func makeTempDirectory(prefix: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("live runtime scaffold persists transcript and event phases")
    func liveRuntimeScaffoldPersistsTranscriptAndEventPhases() throws {
        let root = try makeTempDirectory(prefix: "omega-live-runtime")
        defer {
            OmegaLiveRuntimeState.setTranscriptRootURLOverrideForTesting(nil)
            try? FileManager.default.removeItem(at: root)
        }

        OmegaLiveRuntimeState.setTranscriptRootURLOverrideForTesting(root)

        let runtime = OmegaLiveRuntimeState()
        runtime.runScaffoldTurn(taskDescription: "Bridge Omega to the living Rust loop")

        #expect(runtime.lastTurn != nil)
        #expect(runtime.lastTurn?.stopReason == "end_turn")
        #expect(runtime.lastTurn?.assistantText.contains("Local runtime") == true)
        #expect(runtime.lastTurn?.assistantText.contains("perplexity") == false)
        #expect(runtime.events.map(\.phase) == ["thinking_delta", "text_delta", "complete"])
        #expect(runtime.phaseHistory.map(\.kind) == [.thinking, .responding, .complete])
        #expect(runtime.currentPhase?.kind == .complete)
        #expect(runtime.transcriptJSONL.contains("Bridge Omega to the living Rust loop"))
        #expect(runtime.transcriptJSONL.contains("perplexity") == false)
        #expect(runtime.transcriptJSONL.contains("sonar-pro") == false)
        #expect(FileManager.default.fileExists(atPath: runtime.transcriptPath))
    }

    @Test("orchestrator submitTask seeds live runtime transcript before plan execution")
    func orchestratorSubmitTaskSeedsLiveRuntimeTranscript() async throws {
        let root = try makeTempDirectory(prefix: "omega-live-runtime-orchestrator")
        defer {
            OmegaLiveRuntimeState.setTranscriptRootURLOverrideForTesting(nil)
            try? FileManager.default.removeItem(at: root)
        }

        OmegaLiveRuntimeState.setTranscriptRootURLOverrideForTesting(root)

        let orchestrator = OrchestratorState()
        await orchestrator.submitTask("list files in my vault")

        #expect(orchestrator.liveRuntime.lastTurn != nil)
        #expect(orchestrator.liveRuntime.lastTurn?.stopReason == "end_turn")
        #expect(orchestrator.liveRuntime.transcriptJSONL.contains("list files in my vault"))
        #expect(orchestrator.liveRuntime.transcriptJSONL.contains("perplexity") == false)
        #expect(orchestrator.liveRuntime.transcriptJSONL.contains("sonar-pro") == false)
        #expect(orchestrator.liveRuntime.events.last?.phase == "complete")
        #expect(orchestrator.liveRuntime.phaseHistory.contains { $0.kind == .planning })
        #expect(orchestrator.liveRuntime.phaseHistory.contains { $0.kind == .failed })
        #expect(orchestrator.liveRuntime.lastError == "Agent 'file' not found")
        #expect(orchestrator.liveRuntime.currentPhase?.kind == .failed)
    }
}
#endif
