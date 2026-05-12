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

        #expect(!localBackend.contains("let task = Task { @MainActor in"))
        #expect(!cloud.contains("let task = Task { @MainActor [weak self] in"))
        #expect(localBackend.contains("Task.detached(priority: .userInitiated)"))
        #expect(cloud.contains("Task.detached(priority: .userInitiated)"))
        #expect(!mlx.contains("Task { @MainActor"))
        #expect(!gguf.contains("Task { @MainActor"))
    }
}
