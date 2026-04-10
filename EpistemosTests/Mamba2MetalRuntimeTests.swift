import Testing
@testable import Epistemos

@Suite("Mamba2 Metal Runtime")
struct Mamba2MetalRuntimeTests {
    @Test("empty state snapshots do not crash the Metal runtime loader")
    func emptyStateSnapshotsDoNotCrashTheLoader() throws {
        guard let runtime = MetalRuntimeManager() else { return }

        runtime.allocateStateBuffers(layers: 1, stateDim: 1, headDim: 1, heads: 1)

        #expect(runtime.loadState(Data()))
    }

    @Test("diagnostic forward pass compiles kernels and produces finite outputs")
    func diagnosticForwardPassProducesFiniteOutputs() throws {
        guard CustomSSMRuntimeSupport.isAvailable else { return }
        guard let runtime = MetalRuntimeManager() else { return }

        let forwardPass = Mamba2ForwardPass(runtime: runtime)
        let result = try forwardPass.runDiagnosticPass()

        #expect(result.elapsedMS > 0)
        #expect(!result.output.isEmpty)
        #expect(result.output.allSatisfy { $0.isFinite })
        #expect(!result.chunkStates.isEmpty)
        #expect(result.chunkStates.allSatisfy { $0.isFinite })
        #expect(!result.lMatrixPreview.isEmpty)
        #expect(result.lMatrixPreview.allSatisfy { $0.isFinite && $0 >= 0 })
    }
}
