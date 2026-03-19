import Foundation
import Testing

@Suite("Local Runtime Memory Profile")
struct LocalRuntimeMemoryProfileTests {
    @Test("live qwen memory profile prints exact baseline peak completed and unloaded memory")
    @MainActor
    func liveQwen35MemoryProfile() async throws {
        guard FileManager.default.fileExists(atPath: "/tmp/epi-live-local-qwen35-memory-profile") else {
            return
        }

        let smokeMarker = "/tmp/epi-live-local-qwen35-smoke"
        let fileManager = FileManager.default
        let alreadyEnabled = fileManager.fileExists(atPath: smokeMarker)
        if !alreadyEnabled {
            fileManager.createFile(atPath: smokeMarker, contents: Data())
        }
        defer {
            if !alreadyEnabled {
                try? fileManager.removeItem(atPath: smokeMarker)
            }
        }

        try await LocalRuntimeSmokeSupport.runLiveQwen35MemoryProfile()
    }
}
