import Testing
@testable import Epistemos

@Suite("Adaptation Executor")
struct AdaptationExecutorTests {

    @Test("begin session rejects non-helper models")
    @MainActor
    func beginSessionRejectsNonHelperModels() {
        let executor = AdaptationExecutor()

        #expect(throws: AdaptationExecutorError.helperModelRequired) {
            try executor.beginSession(
                adapterID: "adapter",
                modelID: "helper-model",
                runtimeKind: .mlx,
                isHelperModel: false
            )
        }
    }

    @Test("begin session rejects the main gguf runtime")
    @MainActor
    func beginSessionRejectsMainRuntime() {
        let executor = AdaptationExecutor()

        #expect(throws: AdaptationExecutorError.mainRuntimeAdaptationDenied) {
            try executor.beginSession(
                adapterID: "adapter",
                modelID: "main-model",
                runtimeKind: .gguf,
                isHelperModel: true
            )
        }
    }

    @Test("begin session accepts mlx helper models")
    @MainActor
    func beginSessionAcceptsMLXHelperModels() throws {
        let executor = AdaptationExecutor()

        let sessionID = try executor.beginSession(
            adapterID: "adapter",
            modelID: "helper-model",
            runtimeKind: .mlx,
            isHelperModel: true
        )

        #expect(!sessionID.isEmpty)
        #expect(executor.hasActiveSession)
        let snapshot = executor.endSession()
        #expect(snapshot?.state == "accumulating")
    }
}
