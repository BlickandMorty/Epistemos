import Foundation

// MARK: - Types

struct TrainingProgress: Sendable {
    let iteration: Int
    let totalIterations: Int
    let loss: Double
    let learningRate: Double
    let estimatedTimeRemaining: TimeInterval
}

nonisolated struct AdapterMetadata: Sendable, Codable {
    let adapterType: String
    let sourceVault: String
    let loraRank: Int
    let loraAlpha: Int
    let targetModules: [String]
    let learningRate: Double
    let numExamples: Int
    let numIters: Int
    let trainingDurationSeconds: Double
    let createdAt: String
    let baseModel: String
    let qualityScore: Double?

    enum CodingKeys: String, CodingKey {
        case adapterType = "adapter_type"
        case sourceVault = "source_vault"
        case loraRank = "lora_rank"
        case loraAlpha = "lora_alpha"
        case targetModules = "target_modules"
        case learningRate = "learning_rate"
        case numExamples = "num_examples"
        case numIters = "num_iters"
        case trainingDurationSeconds = "training_duration_seconds"
        case createdAt = "created_at"
        case baseModel = "base_model"
        case qualityScore = "quality_score"
    }
}

// MARK: - QLoRATrainer

/// Swift wrapper that invokes Python training scripts through a subprocess.
/// This is the first Swift→Python process bridge in the Epistemos codebase.
///
/// CRITICAL (ANCHOR 3, GAP 1): Training scripts produce SEPARATE adapter
/// .safetensors files. They NEVER fuse adapters into base model weights.
actor QLoRATrainer {

    private let scriptsDirectory: URL

    init(scriptsDirectory: URL? = nil) {
        if let dir = scriptsDirectory {
            self.scriptsDirectory = dir
        } else {
            self.scriptsDirectory = Bundle.main.bundleURL
                .appendingPathComponent("Contents/Resources/KnowledgeFusion/Training/scripts")
        }
    }

    // MARK: - Public API

    struct TrainingConfig: Sendable {
        var numIters: Int = 200
        var loraRank: Int = 16
        var loraAlpha: Int = 32
        var batchSize: Int = 1
        var maxSeqLen: Int = 1024
        var learningRate: Double = 2e-5
        var seed: Int = 42

        static let defaultKnowledge = TrainingConfig(
            numIters: 200,
            loraRank: 16,
            loraAlpha: 32,
            batchSize: 1,
            maxSeqLen: 1024,
            learningRate: 2e-5,
            seed: 42
        )

        static let defaultStyle = TrainingConfig(
            numIters: 200,
            loraRank: 8,
            loraAlpha: 16,
            batchSize: 1,
            maxSeqLen: 1024,
            learningRate: 1e-5,
            seed: 42
        )
    }

    func trainKnowledgeAdapter(
        modelPath: URL,
        dataPath: URL,
        outputPath: URL,
        replayPath: URL? = nil,
        config: TrainingConfig = .defaultKnowledge,
        progressHandler: (@Sendable (TrainingProgress) -> Void)? = nil
    ) async throws -> AdapterMetadata {
        let script = scriptsDirectory.appendingPathComponent("train_knowledge.py")
        return try await runTraining(
            script: script,
            modelPath: modelPath,
            dataPath: dataPath,
            outputPath: outputPath,
            replayPath: replayPath,
            config: config,
            progressHandler: progressHandler
        )
    }

    func trainStyleAdapter(
        modelPath: URL,
        dataPath: URL,
        outputPath: URL,
        replayPath: URL? = nil,
        config: TrainingConfig = .defaultStyle,
        progressHandler: (@Sendable (TrainingProgress) -> Void)? = nil
    ) async throws -> AdapterMetadata {
        let script = scriptsDirectory.appendingPathComponent("train_style.py")
        return try await runTraining(
            script: script,
            modelPath: modelPath,
            dataPath: dataPath,
            outputPath: outputPath,
            replayPath: replayPath,
            config: config,
            progressHandler: progressHandler
        )
    }

    func cancelTraining() async {
        // Native MLX LoRA training (NativeLoRATrainer) replaced the python3
        // subprocess, so there's no Process to terminate. Cooperative
        // cancellation is a follow-on via the LoRATrain progress
        // ProgressDisposition.stop path.
    }

    // MARK: - Process Execution

    private func runTraining(
        script: URL,
        modelPath: URL,
        dataPath: URL,
        outputPath: URL,
        replayPath: URL?,
        config: TrainingConfig,
        progressHandler: (@Sendable (TrainingProgress) -> Void)?
    ) async throws -> AdapterMetadata {
        // NATIVE in-process MLX LoRA training (owner 2026-06-18): the python3
        // `Process()` subprocess is GONE — this now calls NativeLoRATrainer, which
        // loads the base model + runs MLXLLM.LoRATrain.train in-process. The
        // `script` URL only selects the adapter TYPE now (train_knowledge →
        // "knowledge", train_style → "style").
        let adapterType = script.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "train_", with: "")

        #if !EPISTEMOS_APP_STORE
        // (replay-buffer mixing is a follow-on native step; not yet threaded)
        _ = replayPath
        return try await NativeLoRATrainer.train(
            modelDirectory: modelPath,
            dataURL: dataPath,
            outputDirectory: outputPath,
            config: config,
            adapterType: adapterType.isEmpty ? "knowledge" : adapterType,
            baseModel: modelPath.lastPathComponent,
            sourceVault: dataPath.deletingLastPathComponent().lastPathComponent,
            progress: progressHandler
        )
        #else
        // The App Store sandbox can't run heavy on-device training; the
        // KnowledgeFusion entry points are already gated out of MAS (defense in
        // depth), and NativeLoRATrainer itself is `#if !EPISTEMOS_APP_STORE`.
        _ = (modelPath, dataPath, outputPath, replayPath, config, progressHandler, adapterType)
        throw QLoRATrainerError.trainingFailed(
            "LoRA training is not available in the App Store sandbox build."
        )
        #endif
    }
}

// MARK: - Errors

enum QLoRATrainerError: Error, LocalizedError {
    case trainingFailed(String)
    case metadataNotFound(URL)
    case scriptNotFound(URL)

    var errorDescription: String? {
        switch self {
        case .trainingFailed(let msg): return "Training failed: \(msg)"
        case .metadataNotFound(let url): return "Training metadata not found at: \(url.path)"
        case .scriptNotFound(let url): return "Training script not found at: \(url.path)"
        }
    }
}
