import Foundation
import Testing
@testable import Epistemos

@Suite("Local Model Release Sweep")
struct LocalModelReleaseSweepTests {
    @MainActor
    @Test("live release sweep validates supported local models end to end")
    func liveReleaseSweep() async {
        guard FileManager.default.fileExists(atPath: "/tmp/epi-live-local-model-release-sweep") else {
            return
        }

        let selectedModels = LocalRuntimeSmokeSupport.selectedReleaseSweepModelIDs()
        #expect(!selectedModels.isEmpty)

        print(
            "LOCAL_MODEL_RELEASE_SWEEP selected=\(selectedModels.map(\.rawValue).joined(separator: ","))"
        )

        for model in selectedModels {
            var bootstrap: AppBootstrap?

            do {
                print("LOCAL_MODEL_RELEASE_SWEEP start model=\(model.rawValue)")
                let prepared = try await LocalRuntimeSmokeSupport.preparedBootstrap(for: model.rawValue)
                bootstrap = prepared

                try LocalRuntimeSmokeSupport.verifyPickerVisibilityAndSelection(
                    modelID: model.rawValue,
                    bootstrap: prepared
                )
                try await LocalRuntimeSmokeSupport.verifyChatQuality(
                    modelID: model.rawValue,
                    bootstrap: prepared
                )
                try await LocalRuntimeSmokeSupport.verifyThinkingMode(
                    modelID: model.rawValue,
                    bootstrap: prepared
                )
                try await LocalRuntimeSmokeSupport.verifyLongContextSanity(
                    modelID: model.rawValue,
                    bootstrap: prepared
                )
                try await LocalRuntimeSmokeSupport.verifyContextContract(
                    modelID: model.rawValue,
                    bootstrap: prepared
                )
                try await LocalRuntimeSmokeSupport.verifyVision(
                    modelID: model.rawValue,
                    bootstrap: prepared
                )
                try await LocalRuntimeSmokeSupport.verifyAgentMode(
                    modelID: model.rawValue,
                    bootstrap: prepared
                )

                if model.isSSM {
                    try await LocalRuntimeSmokeSupport.verifyLiveSSMStateRoundTrip(
                        modelID: model.rawValue,
                        bootstrap: prepared
                    )
                }

                print("LOCAL_MODEL_RELEASE_SWEEP ok model=\(model.rawValue)")
            } catch {
                Issue.record("Live local model sweep failed for \(model.rawValue): \(error.localizedDescription)")
            }

            if let bootstrap {
                await bootstrap.localInferenceService.unload()
            }
        }
    }
}
