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

    private let pythonPath: String
    private let scriptsDirectory: URL
    private var activeProcess: Process?

    init(pythonPath: String = "/usr/bin/python3", scriptsDirectory: URL? = nil) {
        self.pythonPath = pythonPath
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
        if let process = activeProcess, process.isRunning {
            process.terminate()
        }
        activeProcess = nil
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
        var arguments = [
            script.path,
            "--model_path", modelPath.path,
            "--data_path", dataPath.path,
            "--output_path", outputPath.path,
            "--num_iters", String(config.numIters),
            "--seed", String(config.seed),
            "--lora_rank", String(config.loraRank),
            "--lora_alpha", String(config.loraAlpha),
            "--batch_size", String(config.batchSize),
            "--max_seq_len", String(config.maxSeqLen),
            "--learning_rate", String(config.learningRate),
        ]
        if let replayPath {
            arguments.append(contentsOf: ["--replay_path", replayPath.path])
        }

        let process = Process.init()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        activeProcess = process
        defer { activeProcess = nil }

        // Parse stdout in real-time for progress updates
        let progressParser = TrainingProgressParser(
            totalIterations: config.numIters,
            handler: progressHandler
        )

        let stdoutHandle = stdoutPipe.fileHandleForReading
        stdoutHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let line = String(data: data, encoding: .utf8) {
                progressParser.parse(line)
            }
        }

        let timeoutSeconds = 3600.0
        let state = ThrowingProcessContinuationState<Void>()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                guard state.store(process: process, continuation: continuation) else {
                    stdoutHandle.readabilityHandler = nil
                    continuation.resume(throwing: CancellationError())
                    return
                }

                let timeoutTask = Task.detached(priority: .utility) {
                    try? await Task.sleep(for: .seconds(timeoutSeconds))
                    state.terminate()
                    state.resume(throwing: TimeoutError(seconds: timeoutSeconds))
                }

                process.terminationHandler = { proc in
                    timeoutTask.cancel()
                    stdoutHandle.readabilityHandler = nil
                    if proc.terminationStatus == 0 {
                        state.resume(returning: ())
                    } else {
                        let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        state.resume(throwing: QLoRATrainerError.trainingFailed(errorMsg))
                    }
                }

                do {
                    try process.run()
                } catch {
                    timeoutTask.cancel()
                    stdoutHandle.readabilityHandler = nil
                    state.resume(throwing: error)
                }
            }
        } onCancel: {
            state.terminate()
            state.resume(throwing: CancellationError())
        }

        // Read and return metadata
        let metadataPath = outputPath.appendingPathComponent("training_metadata.json")
        guard FileManager.default.fileExists(atPath: metadataPath.path) else {
            throw QLoRATrainerError.metadataNotFound(metadataPath)
        }
        let metadataData = try Data(contentsOf: metadataPath)
        return try JSONDecoder().decode(AdapterMetadata.self, from: metadataData)
    }
}

// MARK: - Progress Parser

/// Parses mlx-lm training log output format:
/// "Iter N: train loss X.XXX, learning_rate X.Xe-XX, ..."
private nonisolated final class TrainingProgressParser: Sendable {
    private let totalIterations: Int
    private let handler: (@Sendable (TrainingProgress) -> Void)?
    private let startTime = Date()

    nonisolated init(totalIterations: Int, handler: (@Sendable (TrainingProgress) -> Void)?) {
        self.totalIterations = totalIterations
        self.handler = handler
    }

    func parse(_ output: String) {
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            guard let progress = parseIterLine(line) else { continue }
            handler?(progress)
        }
    }

    private func parseIterLine(_ line: String) -> TrainingProgress? {
        // Match: "Iter N: train loss X.XXX, learning_rate X.Xe-XX"
        // or: "Iter N (val): ..."
        guard line.contains("Iter") && line.contains("train loss") else { return nil }

        let components = line.components(separatedBy: " ")
        guard let iterIdx = components.firstIndex(of: "Iter"),
              iterIdx + 1 < components.count else { return nil }

        let iterStr = components[iterIdx + 1].trimmingCharacters(in: CharacterSet(charactersIn: ":,"))
        guard let iter = Int(iterStr) else { return nil }

        // Parse loss
        var loss: Double = 0
        if let lossIdx = components.firstIndex(of: "loss"),
           lossIdx + 1 < components.count {
            let lossStr = components[lossIdx + 1].trimmingCharacters(in: CharacterSet(charactersIn: ","))
            loss = Double(lossStr) ?? 0
        }

        // Parse learning rate
        var lr: Double = 0
        if let lrIdx = components.firstIndex(of: "learning_rate"),
           lrIdx + 1 < components.count {
            let lrStr = components[lrIdx + 1].trimmingCharacters(in: CharacterSet(charactersIn: ","))
            lr = Double(lrStr) ?? 0
        }

        // Estimate time remaining
        let elapsed = Date().timeIntervalSince(startTime)
        let itersRemaining = totalIterations - iter
        let timePerIter = iter > 0 ? elapsed / Double(iter) : 0
        let estimatedRemaining = timePerIter * Double(itersRemaining)

        return TrainingProgress(
            iteration: iter,
            totalIterations: totalIterations,
            loss: loss,
            learningRate: lr,
            estimatedTimeRemaining: estimatedRemaining
        )
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
