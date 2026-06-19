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
}
#endif
