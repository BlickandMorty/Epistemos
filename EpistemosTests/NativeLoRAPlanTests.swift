import Testing
import Foundation
@testable import Epistemos

/// Data + finetune substrate (owner 2026-06-18) — locks the pure mapping from the
/// existing TrainingConfig onto the native mlx-swift-lm trainer's hyperparameters
/// (the substrate that replaces the Python QLoRA arg-passing). MLX-independent,
/// so the scaling + clamp math is tested directly.
@Suite("Native LoRA plan")
struct NativeLoRAPlanTests {

    @Test("knowledge config maps to standard LoRA alpha/rank scaling")
    func mapsKnowledgeConfig() {
        let plan = NativeLoRAPlan.from(.defaultKnowledge)
        #expect(plan.rank == 16)
        #expect(plan.scale == 2.0)             // alpha 32 / rank 16
        #expect(plan.iterations == 200)
        #expect(plan.batchSize == 1)
        #expect(plan.numLayers == 16)
        #expect(plan.fineTuneType == "lora")
        #expect(plan.saveEvery == 100)         // min(100, 200)
    }

    @Test("style config maps with its smaller rank")
    func mapsStyleConfig() {
        let plan = NativeLoRAPlan.from(.defaultStyle)
        #expect(plan.rank == 8)
        #expect(plan.scale == 2.0)             // alpha 16 / rank 8
        #expect(plan.iterations == 200)
    }

    @Test("save cadence never exceeds the iteration count")
    func saveEveryClampsToIterations() {
        var short = QLoRATrainer.TrainingConfig.defaultKnowledge
        short.numIters = 40
        #expect(NativeLoRAPlan.from(short).saveEvery == 40)   // min(100, 40)

        var long = QLoRATrainer.TrainingConfig.defaultKnowledge
        long.numIters = 500
        #expect(NativeLoRAPlan.from(long).saveEvery == 100)   // capped at 100
    }

    @Test("degenerate config is clamped — no zero rank / zero iterations / div-by-zero")
    func clampsDegenerateConfig() {
        var bad = QLoRATrainer.TrainingConfig.defaultKnowledge
        bad.loraRank = 0
        bad.loraAlpha = 0
        bad.numIters = 0
        bad.batchSize = 0
        let plan = NativeLoRAPlan.from(bad)
        #expect(plan.rank == 1)            // clamped, never 0
        #expect(plan.iterations == 1)
        #expect(plan.batchSize == 1)
        #expect(plan.saveEvery == 1)
        #expect(plan.scale == 1.0)         // alpha(1)/rank(1), never NaN/inf
        #expect(plan.numLayers == 16)
    }

    @Test("numLayers override is honored and clamped")
    func numLayersOverride() {
        #expect(NativeLoRAPlan.from(.defaultKnowledge, numLayers: 8).numLayers == 8)
        #expect(NativeLoRAPlan.from(.defaultKnowledge, numLayers: 0).numLayers == 1)  // clamped
    }
}
