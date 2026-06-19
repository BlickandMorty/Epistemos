import Foundation

// Data + finetune substrate (owner 2026-06-18), kill-Python slice 2: the PURE
// config substrate that maps Epistemos's existing `QLoRATrainer.TrainingConfig`
// onto the native mlx-swift-lm trainer's hyperparameters — WITHOUT importing MLX,
// so the mapping math (LoRA alpha/rank scaling, clamps, save cadence) is
// unit-tested directly. `NativeLoRATrainer` (Pro-gated) turns a plan into the
// real `LoRATrain.Parameters` + `LoRAConfiguration`. No Python anywhere.

/// A resolved, MLX-independent LoRA training plan derived from a TrainingConfig.
struct NativeLoRAPlan: Sendable, Equatable {
    // Trainer cadence (→ LoRATrain.Parameters)
    let batchSize: Int
    let iterations: Int
    let stepsPerReport: Int
    let stepsPerEval: Int
    let validationBatches: Int
    let saveEvery: Int

    // Adapter shape (→ LoRAConfiguration)
    let rank: Int
    let scale: Float
    let numLayers: Int
    /// "lora" or "dora" (matches LoRAConfiguration.FineTuneType.rawValue).
    let fineTuneType: String

    /// Map the existing Epistemos TrainingConfig onto a native plan. `scale` uses
    /// the standard LoRA alpha/rank scaling so the user's `loraAlpha` intent
    /// carries over (rather than the library's flat default). `numLayers` is how
    /// many trailing transformer layers to adapt (mlx-lm's common default is 16).
    /// All fields are clamped to safe minimums so a degenerate config can't make
    /// the native trainer divide-by-zero or loop forever.
    static func from(
        _ config: QLoRATrainer.TrainingConfig,
        numLayers: Int = 16
    ) -> NativeLoRAPlan {
        let rank = max(1, config.loraRank)
        let iterations = max(1, config.numIters)
        return NativeLoRAPlan(
            batchSize: max(1, config.batchSize),
            iterations: iterations,
            stepsPerReport: 10,
            stepsPerEval: 100,
            validationBatches: 10,
            // Never save more often than every step, nor less than once.
            saveEvery: max(1, min(100, iterations)),
            rank: rank,
            scale: Float(max(1, config.loraAlpha)) / Float(rank),
            numLayers: max(1, numLayers),
            fineTuneType: "lora"
        )
    }
}
