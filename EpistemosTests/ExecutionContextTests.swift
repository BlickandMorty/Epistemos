import Testing
@testable import Epistemos

#if false
// Retained for reference while the legacy ExecutionContext type is absent
// from the live app. These tests should come back only if that type returns.
@Suite("ExecutionContext")
@MainActor
struct ExecutionContextTests {

    // MARK: - Working Directory Tracking

    @Test("Updates working directory from PTY output")
    func workingDirTracking() {
        let context = ExecutionContext()
        let step = makeStep(tool: "run_persistent")
        let result = AgentStepResult.ok(
            "{\"success\":true,\"stdout\":\"files...\",\"working_dir\":\"/tmp/project\",\"duration_ms\":50}",
            stepId: step.id, durationMs: 50, confidence: 0.95
        )
        context.update(from: result, step: step)
        #expect(context.workingDir == "/tmp/project")
    }

    @Test("Ignores empty working directory")
    func ignoresEmptyWorkingDir() {
        let context = ExecutionContext()
        let originalDir = context.workingDir
        let step = makeStep(tool: "run_command")
        let result = AgentStepResult.ok(
            "{\"success\":true,\"stdout\":\"ok\",\"working_dir\":\"\"}",
            stepId: step.id, durationMs: 10, confidence: 0.95
        )
        context.update(from: result, step: step)
        #expect(context.workingDir == originalDir)
    }

    // MARK: - File Path Tracking

    @Test("Tracks file paths from file operations")
    func filePathTracking() {
        let context = ExecutionContext()
        let step = makeStep(tool: "write_file")
        let result = AgentStepResult.ok(
            "{\"success\":true,\"path\":\"notes/test.md\"}",
            stepId: step.id, durationMs: 20, confidence: 1.0
        )
        context.update(from: result, step: step)
        #expect(context.producedFilePaths.contains("notes/test.md"))
    }

    @Test("Tracks file_path key variant")
    func filePathKeyVariant() {
        let context = ExecutionContext()
        let step = makeStep(tool: "write_file")
        let result = AgentStepResult.ok(
            "{\"success\":true,\"file_path\":\"/Users/test/doc.md\"}",
            stepId: step.id, durationMs: 15, confidence: 1.0
        )
        context.update(from: result, step: step)
        #expect(context.producedFilePaths.contains("/Users/test/doc.md"))
    }

    // MARK: - Environment Override Tracking

    @Test("Tracks environment overrides")
    func envOverrideTracking() {
        let context = ExecutionContext()
        let step = makeStep(tool: "run_persistent")
        let result = AgentStepResult.ok(
            "{\"success\":true,\"stdout\":\"ok\",\"env\":{\"NODE_ENV\":\"production\"}}",
            stepId: step.id, durationMs: 30, confidence: 0.95
        )
        context.update(from: result, step: step)
        #expect(context.envOverrides["NODE_ENV"] == "production")
    }

    // MARK: - Serialization

    @Test("toJson contains all tracked state")
    func toJsonSerialization() {
        let context = ExecutionContext()
        context.workingDir = "/tmp"
        context.envOverrides["KEY"] = "value"
        context.producedFilePaths.append("test.md")

        let json = context.toJson()
        #expect(json["working_dir"] as? String == "/tmp")
        #expect((json["env_overrides"] as? [String: String])?["KEY"] == "value")
        #expect((json["produced_files"] as? [String])?.contains("test.md") == true)
    }

    // MARK: - Reset

    @Test("Reset clears all state")
    func resetClearsState() {
        let context = ExecutionContext()
        context.workingDir = "/tmp/modified"
        context.envOverrides["FOO"] = "bar"
        context.producedFilePaths.append("file.txt")

        context.reset()

        #expect(context.workingDir == FileManager.default.homeDirectoryForCurrentUser.path)
        #expect(context.envOverrides.isEmpty)
        #expect(context.producedFilePaths.isEmpty)
    }

    // MARK: - Failed Results Ignored

    @Test("Failed results are not tracked")
    func failedResultsIgnored() {
        let context = ExecutionContext()
        let originalDir = context.workingDir
        let step = makeStep(tool: "run_persistent")
        let result = AgentStepResult.fail("Timeout", stepId: step.id, durationMs: 30000)
        context.update(from: result, step: step)
        #expect(context.workingDir == originalDir)
        #expect(context.producedFilePaths.isEmpty)
    }

    // MARK: - Helpers

    private func makeStep(tool: String) -> AgentStep {
        AgentStep(
            id: UUID(),
            description: "test",
            assignedAgent: "terminal",
            toolName: tool,
            argumentsJson: "{}",
            riskLevel: .low,
            dependsOn: []
        )
    }
}
#endif
