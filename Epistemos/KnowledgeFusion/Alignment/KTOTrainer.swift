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

    private let minimumBatch: Int

    init(minimumBatch: Int = 20) {
        self.minimumBatch = minimumBatch
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

        #if !EPISTEMOS_APP_STORE
        // SS-LS 1b: native in-process KTO — no Python, no subprocess at all. Parse
        // the feedback JSONL → KTO examples and fine-tune a LoRA adapter natively
        // (NativeKTOTrainer = NativeKTODataPrep + NativeKTOLoss + a native LoRATrain
        // loop), writing the adapter to outputPath. Convergence is owner-verified
        // on-device; the train→apply round-trip is fully native (no Python anywhere).
        let examples = NativeKTODataPrep.loadFeedbackExamples(at: feedbackPath)
        guard !examples.isEmpty else {
            return KTOTrainingResult(
                success: true, skipped: true, signalsUsed: 0, finalLoss: nil, newAdapterPath: nil
            )
        }
        try FileManager.default.createDirectory(at: outputPath, withIntermediateDirectories: true)
        let plan = NativeLoRAPlan(
            batchSize: 1, iterations: max(1, numIters), stepsPerReport: 10, stepsPerEval: 100,
            validationBatches: 10, saveEvery: max(1, min(100, numIters)),
            rank: 8, scale: 2.0, numLayers: 16, fineTuneType: "lora"
        )
        let result = try await NativeKTOTrainer.train(
            modelDirectory: modelPath,
            examples: examples,
            adapterURL: NativeAdapterDirectory.weightsURL(in: outputPath),
            loraConfiguration: NativeLoRATrainer.loraConfiguration(for: plan),
            kto: NativeKTOLoss(beta: ktoBeta),
            iterations: max(1, numIters)
        )
        return KTOTrainingResult(
            success: true, skipped: false, signalsUsed: examples.count,
            finalLoss: result.finalLoss.map(Double.init), newAdapterPath: outputPath
        )
        #else
        // The App Store sandbox cannot run local training; the KnowledgeFusion entry
        // points are already gated out of MAS — this body gate is defense-in-depth.
        _ = (modelPath, adapterPath, numIters, ktoBeta)
        throw QLoRATrainerError.trainingFailed(
            "KTO training is not available in the App Store sandbox build."
        )
        #endif
    }
}
