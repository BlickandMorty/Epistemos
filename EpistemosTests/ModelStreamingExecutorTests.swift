import Foundation
import Testing

@Suite("Model Streaming Executor Audit")
struct ModelStreamingExecutorTests {
    @Test("model stream relays do not inherit the main actor")
    func modelStreamRelaysDoNotInheritMainActor() throws {
        let localBackend = try loadMirroredSourceTextFile("Epistemos/Engine/LocalBackendLLMClient.swift")
        let cloud = try loadMirroredSourceTextFile("Epistemos/Engine/LLMService.swift")
        let mlx = try loadMirroredSourceTextFile("Epistemos/Engine/MLXInferenceService.swift")
        let gguf = try loadMirroredSourceTextFile("Epistemos/Engine/LocalGGUFClient.swift")
        let mlxClient = try sourceSection(
            in: mlx,
            startingAt: "@MainActor\nfinal class LocalMLXClient",
            endingBefore: "\nactor MLXInferenceService"
        )
        let ggufClient = try sourceSection(
            in: gguf,
            startingAt: "@MainActor\nfinal class LocalGGUFClient",
            endingBefore: "\nnonisolated enum LocalGenerationMetrics"
        )

        #expect(!localBackend.contains("let task = Task { @MainActor in"))
        #expect(!cloud.contains("let task = Task { @MainActor [weak self] in"))
        #expect(!mlxClient.contains("let task = Task {"))
        #expect(!ggufClient.contains("let task = Task {"))
        #expect(localBackend.contains("Task.detached(priority: .userInitiated)"))
        #expect(cloud.contains("Task.detached(priority: .userInitiated)"))
        #expect(mlxClient.contains("Task.detached(priority: .userInitiated)"))
        #expect(ggufClient.contains("Task.detached(priority: .userInitiated)"))
    }

    private func sourceSection(
        in source: String,
        startingAt startMarker: String,
        endingBefore endMarker: String
    ) throws -> String {
        guard let start = source.range(of: startMarker)?.lowerBound,
              let end = source.range(of: endMarker, range: start..<source.endIndex)?.lowerBound else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return String(source[start..<end])
    }
}
