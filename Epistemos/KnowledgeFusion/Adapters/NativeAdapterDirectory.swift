import Foundation

// Data + finetune substrate (owner 2026-06-18), kill-Python slice 3: the native
// adapter directory layout — the contract between NativeLoRATrainer (writes a
// trained adapter) and NativeAdapterApply (loads it at inference time via
// MLXLMCommon LoRAContainer), replacing the molora_inference.py subprocess.
//
// mlx-swift-lm's `LoRAContainer.from(directory:)` reads exactly two files:
// `adapter_config.json` (the LoRAConfiguration) + `adapters.safetensors` (the
// weights). This pure, MLX-independent helper names + validates that layout so
// the train→apply round-trip is native end to end. Unit-tested.

enum NativeAdapterDirectory {
    /// The LoRAConfiguration JSON `LoRAContainer.from(directory:)` decodes.
    nonisolated static let configFileName = "adapter_config.json"
    /// The trained LoRA weights `LoRAContainer.from(directory:)` loads.
    nonisolated static let weightsFileName = "adapters.safetensors"

    nonisolated static func configURL(in directory: URL) -> URL {
        directory.appendingPathComponent(configFileName)
    }

    nonisolated static func weightsURL(in directory: URL) -> URL {
        directory.appendingPathComponent(weightsFileName)
    }

    /// True only when BOTH the config + weights files exist — i.e. the directory
    /// is a complete, loadable native adapter. A directory with just the weights
    /// (the raw LoRATrain output before the config is written) is NOT valid.
    nonisolated static func isValid(_ directory: URL, fileManager: FileManager = .default) -> Bool {
        fileManager.fileExists(atPath: configURL(in: directory).path)
            && fileManager.fileExists(atPath: weightsURL(in: directory).path)
    }

    /// Honest one-line reason a directory isn't a loadable adapter, or nil if it
    /// is valid — for surfacing a clear error instead of a raw decode failure.
    nonisolated static func invalidReason(_ directory: URL, fileManager: FileManager = .default) -> String? {
        if !fileManager.fileExists(atPath: directory.path) {
            return "Adapter directory does not exist."
        }
        let hasConfig = fileManager.fileExists(atPath: configURL(in: directory).path)
        let hasWeights = fileManager.fileExists(atPath: weightsURL(in: directory).path)
        switch (hasConfig, hasWeights) {
        case (true, true): return nil
        case (false, true): return "Missing \(configFileName) (adapter config)."
        case (true, false): return "Missing \(weightsFileName) (adapter weights)."
        case (false, false): return "Not a native adapter (no \(configFileName) or \(weightsFileName))."
        }
    }
}
