import Foundation

// Data + finetune substrate (owner 2026-06-18), kill-Python slice 2: the NATIVE
// in-process LoRA trainer seam. Wraps the vendored mlx-swift-lm trainer
// (MLXLLM.LoRATrain) so finetune runs on Apple Silicon WITHOUT spawning
// /usr/bin/python3 — replacing QLoRATrainer's `Process()` body. Pro-only
// (#if !EPISTEMOS_APP_STORE): training is heavy + cost-gated, but NATIVE, not a
// subprocess.
//
// This slice lands the typed bridge: a NativeLoRAPlan → real `LoRATrain.Parameters`
// + `LoRAConfiguration`, plus the chat-data → [String] dataset prep
// (LoRAChatDataConverter — no Python). The model-load + `LoRATrain.train` call is
// the next slice (it reuses MLXInferenceService's load path + needs an on-device
// run to verify token-gen — never claimed here).

#if !EPISTEMOS_APP_STORE
import MLXLLM
import MLXLMCommon
import MLXOptimizers

enum NativeLoRATrainerError: Error, LocalizedError {
    case emptyDataset
    var errorDescription: String? {
        switch self {
        case .emptyDataset:
            return "No training examples after converting the chat data."
        }
    }
}

enum NativeLoRATrainer {

    /// A NativeLoRAPlan → the mlx-swift-lm trainer cadence parameters, pointed at
    /// where the adapter `.safetensors` should be saved.
    static func trainParameters(for plan: NativeLoRAPlan, adapterURL: URL) -> LoRATrain.Parameters {
        LoRATrain.Parameters(
            batchSize: plan.batchSize,
            iterations: plan.iterations,
            stepsPerReport: plan.stepsPerReport,
            stepsPerEval: plan.stepsPerEval,
            validationBatches: plan.validationBatches,
            saveEvery: plan.saveEvery,
            adapterURL: adapterURL
        )
    }

    /// A NativeLoRAPlan → the native LoRA adapter configuration (rank/scale/layers).
    static func loraConfiguration(for plan: NativeLoRAPlan) -> LoRAConfiguration {
        LoRAConfiguration(
            numLayers: plan.numLayers,
            fineTuneType: plan.fineTuneType == "dora" ? .dora : .lora,
            loraParameters: .init(rank: plan.rank, scale: plan.scale, keys: nil)
        )
    }

    /// Build both native config objects from the existing Epistemos TrainingConfig.
    static func nativeConfig(
        from config: QLoRATrainer.TrainingConfig,
        adapterURL: URL
    ) -> (parameters: LoRATrain.Parameters, configuration: LoRAConfiguration) {
        let plan = NativeLoRAPlan.from(config)
        return (trainParameters(for: plan, adapterURL: adapterURL), loraConfiguration(for: plan))
    }

    /// Prepare the training texts from Epistemos chat JSONL natively (the chat
    /// `{"messages":[…]}` → flat training strings the native trainer consumes).
    /// No Python: this is the in-process replacement for the script's data step.
    static func prepareDataset(chatJSONLAt url: URL) throws -> [String] {
        let content = try String(contentsOf: url, encoding: .utf8)
        return LoRAChatDataConverter.texts(fromChatJSONL: content)
    }

    /// Run a native, in-process LoRA finetune — the direct replacement for
    /// QLoRATrainer's `Process()` python3 path. Loads the base model + tokenizer
    /// (the same MLX load path the inference lane uses), freezes the base +
    /// attaches trainable LoRA layers (`LoRAContainer.from`), trains with
    /// `MLXLLM.LoRATrain.train` (which writes the adapter `.safetensors` to
    /// `adapterURL` via the parameters), then writes `training_metadata.json`.
    /// NO subprocess, NO Python. Heavy + Apple-Silicon-only — run off the main
    /// actor. (Token-gen / a usable adapter is only PROVEN by an on-device run;
    /// this is the native code path.)
    @discardableResult
    static func train(
        modelDirectory: URL,
        dataURL: URL,
        outputDirectory: URL,
        config: QLoRATrainer.TrainingConfig,
        adapterType: String,
        baseModel: String,
        sourceVault: String,
        progress: (@Sendable (TrainingProgress) -> Void)? = nil
    ) async throws -> AdapterMetadata {
        let trainData = try prepareDataset(chatJSONLAt: dataURL)
        guard !trainData.isEmpty else { throw NativeLoRATrainerError.emptyDataset }

        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let adapterURL = outputDirectory.appendingPathComponent("adapters.safetensors")
        let plan = NativeLoRAPlan.from(config)
        let parameters = trainParameters(for: plan, adapterURL: adapterURL)
        let loraConfig = loraConfiguration(for: plan)
        // Small held-out slice for the validation loss (the data is one set).
        let validation = Array(trainData.prefix(max(1, trainData.count / 10)))
        let learningRate = Float(config.learningRate)
        let totalIters = plan.iterations
        let started = Date()

        let configuration = ModelConfiguration(directory: modelDirectory)
        let container = try await LLMModelFactory.shared.loadContainer(configuration: configuration)

        try await container.perform { (context: ModelContext) in
            let model = context.model
            // Freeze base weights + attach fresh trainable LoRA layers in place.
            _ = try LoRAContainer.from(model: model, configuration: loraConfig)
            let optimizer = Adam(learningRate: learningRate)
            try LoRATrain.train(
                model: model,
                train: trainData,
                validate: validation,
                optimizer: optimizer,
                tokenizer: context.tokenizer,
                parameters: parameters
            ) { report in
                if case let .train(iteration, trainingLoss, _, _) = report {
                    let elapsed = Date().timeIntervalSince(started)
                    let perIter = iteration > 0 ? elapsed / Double(iteration) : 0
                    progress?(
                        TrainingProgress(
                            iteration: iteration,
                            totalIterations: totalIters,
                            loss: Double(trainingLoss),
                            learningRate: Double(learningRate),
                            estimatedTimeRemaining: perIter * Double(max(0, totalIters - iteration))
                        )
                    )
                }
                return .more
            }
        }

        let metadata = AdapterMetadata(
            adapterType: adapterType,
            sourceVault: sourceVault,
            loraRank: plan.rank,
            loraAlpha: config.loraAlpha,
            targetModules: loraConfig.loraParameters.keys ?? [],
            learningRate: config.learningRate,
            numExamples: trainData.count,
            numIters: plan.iterations,
            trainingDurationSeconds: Date().timeIntervalSince(started),
            createdAt: ISO8601DateFormatter().string(from: started),
            baseModel: baseModel,
            qualityScore: nil
        )
        let metadataURL = outputDirectory.appendingPathComponent("training_metadata.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(metadata).write(to: metadataURL)
        return metadata
    }
}
#endif
