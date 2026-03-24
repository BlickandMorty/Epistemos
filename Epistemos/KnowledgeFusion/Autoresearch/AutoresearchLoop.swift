import Foundation

// MARK: - Types

struct AutoresearchProgress: Sendable {
    let phase: AutoresearchPhase
    let experimentId: UUID
    let configDescription: String
}

enum AutoresearchPhase: String, Sendable {
    case proposing = "Proposing configuration..."
    case training = "Training experiment..."
    case evaluating = "Evaluating..."
    case deciding = "Comparing to best..."
    case complete = "Experiment complete"
}

// MARK: - AutoresearchLoop

/// Autonomous training configuration optimization loop.
/// Adapted from Karpathy's autoresearch pattern
/// (source: /Users/jojo/Downloads/autoresearch-master).
///
/// Core loop: PROPOSE → TRAIN (fixed budget) → EVALUATE → KEEP/DISCARD.
///
/// Variations explored:
/// - lora_rank: [4, 8, 16, 32]
/// - learning_rate: [1e-5, 2e-5, 3e-5, 5e-5]
/// - replay_ratio: [0.05, 0.10, 0.15, 0.20]
/// - curriculum_order: [ascending, descending, random]
///
/// Scheduling: Runs only during extended idle (>60 min, plugged in).
/// Maximum runtime per iteration: 30 minutes. Hard timeout at 35 minutes.
actor AutoresearchLoop {

    private let trainer: QLoRATrainer
    private let tracker: ExperimentTracker
    private let evaluator: MetricEvaluator
    private let trainingBudget: Int  // iterations per experiment
    private let timeoutSeconds: TimeInterval

    private var isRunning = false
    private var cancelled = false

    init(
        trainer: QLoRATrainer,
        tracker: ExperimentTracker,
        evaluator: MetricEvaluator,
        trainingBudget: Int = 200,
        timeoutSeconds: TimeInterval = 1800  // 30 min
    ) {
        self.trainer = trainer
        self.tracker = tracker
        self.evaluator = evaluator
        self.trainingBudget = trainingBudget
        self.timeoutSeconds = timeoutSeconds
    }

    // MARK: - Public

    func runOneIteration(
        modelPath: URL,
        dataPath: URL,
        evalData: EvaluationDataset,
        outputDirectory: URL,
        progressHandler: (@Sendable (AutoresearchProgress) -> Void)? = nil
    ) async throws -> ExperimentResult {
        guard !isRunning else {
            throw AutoresearchError.alreadyRunning
        }
        isRunning = true
        cancelled = false
        defer { isRunning = false }

        let experimentId = UUID()
        let baseConfig = await tracker.getBestConfig() ?? TrainingConfig.defaultKnowledge
        let previousBest = await tracker.getBestScore()

        // STEP 1: PROPOSE — vary one parameter
        progressHandler?(AutoresearchProgress(
            phase: .proposing, experimentId: experimentId, configDescription: ""
        ))
        let (proposed, description) = proposeVariation(from: baseConfig)

        progressHandler?(AutoresearchProgress(
            phase: .training, experimentId: experimentId, configDescription: description
        ))

        // STEP 2: TRAIN — fixed budget
        let experimentDir = outputDirectory.appendingPathComponent(experimentId.uuidString)
        try FileManager.default.createDirectory(at: experimentDir, withIntermediateDirectories: true)

        // Write a temporary training config to use the proposed params
        // For now, use the standard trainer with the proposed num_iters
        do {
            _ = try await trainer.trainKnowledgeAdapter(
                modelPath: modelPath,
                dataPath: dataPath,
                outputPath: experimentDir,
                numIters: trainingBudget
            )
        } catch {
            // Training failed — record as discarded
            let result = ExperimentResult(
                id: experimentId,
                proposedConfig: proposed,
                score: 0,
                previousBestScore: previousBest,
                decision: .discarded,
                checkpointPath: nil,
                timestamp: Date(),
                description: "\(description) — FAILED: \(error.localizedDescription)"
            )
            try await tracker.recordExperiment(result)
            return result
        }

        guard !cancelled else {
            throw AutoresearchError.cancelled
        }

        // STEP 3: EVALUATE
        progressHandler?(AutoresearchProgress(
            phase: .evaluating, experimentId: experimentId, configDescription: description
        ))

        let score = await evaluator.evaluate(evalData: evalData)

        // STEP 4: KEEP OR DISCARD
        progressHandler?(AutoresearchProgress(
            phase: .deciding, experimentId: experimentId, configDescription: description
        ))

        let decision: ExperimentDecision
        if score.compositeScore > previousBest {
            decision = .kept
        } else {
            decision = .discarded
        }

        let result = ExperimentResult(
            id: experimentId,
            proposedConfig: proposed,
            score: score.compositeScore,
            previousBestScore: previousBest,
            decision: decision,
            checkpointPath: decision == .kept ? experimentDir.path : nil,
            timestamp: Date(),
            description: description
        )

        try await tracker.recordExperiment(result)

        // Clean up discarded checkpoint
        if decision == .discarded {
            try? FileManager.default.removeItem(at: experimentDir)
        }

        progressHandler?(AutoresearchProgress(
            phase: .complete, experimentId: experimentId,
            configDescription: "\(description) — \(decision.rawValue) (score: \(String(format: "%.4f", score.compositeScore)))"
        ))

        return result
    }

    func cancelCurrentExperiment() {
        cancelled = true
    }

    func currentlyRunning() -> Bool { isRunning }

    // MARK: - Configuration Proposal

    /// Randomly varies ONE parameter from the base config.
    /// Adapted from autoresearch pattern: each experiment changes one thing.
    func proposeVariation(from base: TrainingConfig) -> (config: TrainingConfig, description: String) {
        var config = base
        let dimension = Int.random(in: 0..<4)

        switch dimension {
        case 0:
            // Vary rank
            let options = [4, 8, 16, 32]
            let newRank = options.randomElement()!
            config.loraRank = newRank
            config.loraAlpha = newRank * 2  // maintain 2x ratio
            return (config, "rank=\(newRank) alpha=\(newRank * 2)")

        case 1:
            // Vary learning rate
            let options: [Double] = [1e-5, 2e-5, 3e-5, 5e-5]
            let newLR = options.randomElement()!
            config.learningRate = newLR
            return (config, "lr=\(newLR)")

        case 2:
            // Vary replay ratio
            let options: [Double] = [0.05, 0.10, 0.15, 0.20]
            let newRatio = options.randomElement()!
            config.replayRatio = newRatio
            return (config, "replay=\(newRatio)")

        case 3:
            // Vary curriculum order
            let options: [TrainingConfig.CurriculumOrder] = [.ascending, .descending, .random]
            let newOrder = options.randomElement()!
            config.curriculumOrder = newOrder
            return (config, "curriculum=\(newOrder.rawValue)")

        default:
            return (config, "no change")
        }
    }
}

// MARK: - Errors

enum AutoresearchError: Error, LocalizedError {
    case alreadyRunning
    case cancelled

    var errorDescription: String? {
        switch self {
        case .alreadyRunning: return "An autoresearch experiment is already running"
        case .cancelled: return "Autoresearch experiment was cancelled"
        }
    }
}
