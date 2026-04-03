import Foundation

// MARK: - Types

struct KTOTrainingResult: Sendable {
    let success: Bool
    let skipped: Bool  // true if < MIN_FEEDBACK_BATCH
    let signalsUsed: Int
    let finalLoss: Double?
    let newAdapterPath: URL?
}

// MARK: - KTOTrainer

/// Manages the KTO (Kahneman-Tversky Optimization) training lifecycle.
///
/// ANCHOR 1 Subsystem 4: KTO NOT DPO. Binary unpaired feedback.
/// DPO requires paired responses + reference model in memory — too expensive.
actor KTOTrainer {

    private let pythonPath: String
    private let scriptsDirectory: URL
    private let minimumBatch: Int

    init(
        pythonPath: String = "/usr/bin/python3",
        scriptsDirectory: URL? = nil,
        minimumBatch: Int = 20
    ) {
        self.pythonPath = pythonPath
        self.minimumBatch = minimumBatch
        if let dir = scriptsDirectory {
            self.scriptsDirectory = dir
        } else {
            self.scriptsDirectory = Bundle.main.bundleURL
                .appendingPathComponent("Contents/Resources/KnowledgeFusion/Alignment/scripts")
        }
    }

    /// Export feedback signals from FeedbackLogger to KTO JSONL format.
    func exportFeedback(
        logger: FeedbackLogger,
        since: Date,
        outputPath: URL
    ) async throws -> Int {
        try await logger.exportToJSONL(since: since, outputPath: outputPath)
    }

    /// Run a KTO update using exported feedback data.
    func runKTOUpdate(
        modelPath: URL,
        adapterPath: URL?,
        feedbackPath: URL,
        outputPath: URL,
        numIters: Int = 200,
        ktoBeta: Double = 0.1
    ) async throws -> KTOTrainingResult {
        // Count signals
        let content = try String(contentsOf: feedbackPath, encoding: .utf8)
        let signalCount = content.components(separatedBy: .newlines).filter { !$0.isEmpty }.count

        if signalCount < minimumBatch {
            return KTOTrainingResult(
                success: true,
                skipped: true,
                signalsUsed: signalCount,
                finalLoss: nil,
                newAdapterPath: nil
            )
        }

        let script = scriptsDirectory.appendingPathComponent("train_kto.py")

        var arguments = [
            script.path,
            "--model_path", modelPath.path,
            "--data_path", feedbackPath.path,
            "--output_path", outputPath.path,
            "--num_iters", String(numIters),
            "--kto_beta", String(ktoBeta),
        ]
        if let adapterPath {
            arguments.append(contentsOf: ["--adapter_path", adapterPath.path])
        }

        let process = Process.init()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let timeoutSeconds = 1800.0
        let state = ThrowingProcessContinuationState<Void>()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                guard state.store(process: process, continuation: continuation) else {
                    continuation.resume(throwing: CancellationError())
                    return
                }

                let timeoutTask = Task.detached(priority: .utility) {
                    do {
                        try await Task.sleep(for: .seconds(timeoutSeconds))
                    } catch is CancellationError {
                        return
                    } catch {
                        return
                    }
                    state.terminate()
                    state.resume(throwing: TimeoutError(seconds: timeoutSeconds))
                }

                process.terminationHandler = { proc in
                    timeoutTask.cancel()
                    if proc.terminationStatus == 0 {
                        state.resume(returning: ())
                    } else {
                        let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown"
                        state.resume(throwing: QLoRATrainerError.trainingFailed(errorMsg))
                    }
                }
                do {
                    try process.run()
                } catch {
                    timeoutTask.cancel()
                    state.resume(throwing: error)
                }
            }
        } onCancel: {
            state.terminate()
            state.resume(throwing: CancellationError())
        }

        // Check for "SKIPPED" in output
        let outputData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        if output.contains("SKIPPED") {
            return KTOTrainingResult(
                success: true,
                skipped: true,
                signalsUsed: signalCount,
                finalLoss: nil,
                newAdapterPath: nil
            )
        }

        return KTOTrainingResult(
            success: true,
            skipped: false,
            signalsUsed: signalCount,
            finalLoss: nil,
            newAdapterPath: outputPath
        )
    }
}
