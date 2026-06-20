import Foundation

// Data + finetune substrate (owner 2026-06-18), kill-Python slice 3: native
// in-process LoRA adapter apply — the replacement for the molora_inference.py
// subprocess. Loads a TRAINED adapter from disk and attaches it to a loaded MLX
// model for inference, entirely in-process (no python3). Single-adapter apply
// first (covers the knowledge/style vault adapters); MoLoRA decide-once ROUTING
// over multiple adapters is a later native step.
//
// Pro-only (#if !EPISTEMOS_APP_STORE): MLX inference + adapters are heavy /
// Apple-Silicon-only, but NATIVE, not a subprocess.

#if !EPISTEMOS_APP_STORE
import MLXLMCommon

enum NativeAdapterApplyError: Error, LocalizedError {
    case invalidDirectory(String)
    var errorDescription: String? {
        switch self {
        case .invalidDirectory(let reason): return "Can't apply adapter — \(reason)"
        }
    }
}

enum NativeAdapterApply {
    /// Load the trained adapter at `adapterDirectory` (adapter_config.json +
    /// adapters.safetensors) into `model` for inference, via MLXLMCommon
    /// `LoRAContainer`. The model gains the LoRA layers + their trained weights;
    /// the base weights are untouched. Validated BEFORE the MLX hop so a missing
    /// file yields an honest error rather than a raw decode failure. (A usable
    /// generation needs an on-device run — not claimed here; this is the native
    /// apply path that replaces the Python subprocess.)
    nonisolated static func apply(adapterDirectory: URL, into model: any LanguageModel) throws {
        if let reason = NativeAdapterDirectory.invalidReason(adapterDirectory) {
            throw NativeAdapterApplyError.invalidDirectory(reason)
        }
        let container = try LoRAContainer.from(directory: adapterDirectory)
        try container.load(into: model)
    }
}
#endif
