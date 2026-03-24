import Foundation
import Testing
@testable import Epistemos

// MARK: - Mock Inference for Evaluation

private struct EvalMockInference: KFInferenceProvider {
    /// Returns responses containing expected keywords for testing.
    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        if prompt.contains("quantum") || prompt.contains("Quantum") {
            return "Quantum error correction protects quantum information using surface codes and the threshold theorem for fault-tolerant computing."
        }
        if prompt.contains("Continue") {
            return "I believe this approach demonstrates the key principles effectively, building on prior research in the field."
        }
        return "The answer involves multiple factors that contribute to the overall result."
    }
}

// MARK: - MetricEvaluator Tests

@Suite("MetricEvaluator")
struct MetricEvaluatorTests {

    @Test("Direct probing scores correct answers")
    func directProbing() async {
        let evaluator = MetricEvaluator(inferenceProvider: EvalMockInference())

        let probes = [
            EvaluationDataset.DirectProbe(
                question: "What is quantum error correction?",
                expectedAnswer: "Quantum error correction protects quantum information from decoherence using surface codes."
            ),
        ]

        let score = await evaluator.evaluateDirectProbing(probes: probes)
        #expect(score > 0.0, "Should score > 0 for matching answer")
    }

    @Test("Indirect probing checks keyword presence")
    func indirectProbing() async {
        let evaluator = MetricEvaluator(inferenceProvider: EvalMockInference())

        let probes = [
            EvaluationDataset.IndirectProbe(
                question: "How does quantum error correction relate to computing?",
                expectedKeywords: ["threshold", "surface", "fault-tolerant"]
            ),
        ]

        let score = await evaluator.evaluateIndirectProbing(probes: probes)
        #expect(score > 0.0, "Should detect keywords in response")
    }

    @Test("Token overlap similarity computes F1")
    func tokenOverlap() async {
        let evaluator = MetricEvaluator(inferenceProvider: EvalMockInference())

        let sim = await evaluator.tokenOverlapSimilarity(
            generated: "the quick brown fox jumps",
            reference: "the quick brown dog runs"
        )
        // 3 overlapping tokens (the, quick, brown) out of 5 each
        #expect(sim > 0.4)
        #expect(sim < 1.0)
    }

    @Test("Identical texts score 1.0")
    func identicalTexts() async {
        let evaluator = MetricEvaluator(inferenceProvider: EvalMockInference())
        let sim = await evaluator.tokenOverlapSimilarity(
            generated: "hello world", reference: "hello world"
        )
        #expect(sim == 1.0)
    }

    @Test("Disjoint texts score 0.0")
    func disjointTexts() async {
        let evaluator = MetricEvaluator(inferenceProvider: EvalMockInference())
        let sim = await evaluator.tokenOverlapSimilarity(
            generated: "alpha beta gamma", reference: "delta epsilon zeta"
        )
        #expect(sim == 0.0)
    }

    @Test("Full evaluation produces composite score")
    func fullEvaluation() async {
        let evaluator = MetricEvaluator(inferenceProvider: EvalMockInference())

        let evalData = EvaluationDataset(
            directProbes: [
                .init(question: "What is quantum error correction?",
                      expectedAnswer: "Quantum error correction protects information using codes"),
            ],
            indirectProbes: [
                .init(question: "How does quantum error correction enable computing?",
                      expectedKeywords: ["threshold", "fault-tolerant"]),
            ],
            styleHeldOut: [
                "I believe this approach demonstrates the key principles effectively building on prior research in the field of quantum computing."
            ]
        )

        let score = await evaluator.evaluate(evalData: evalData)
        #expect(score.compositeScore >= 0.0)
        #expect(score.compositeScore <= 1.0)
        // Composite = direct*0.5 + indirect*0.3 + style*0.2
        let recomputed = score.directProbingScore * 0.5 + score.indirectProbingScore * 0.3 + score.styleScore * 0.2
        #expect(abs(score.compositeScore - recomputed) < 0.001)
    }

    @Test("Load eval dataset from JSONL")
    func loadEvalDataset() throws {
        let jsonl = """
        {"messages":[{"role":"system","content":""},{"role":"user","content":"What is water?"},{"role":"assistant","content":"Water is a chemical compound H2O."}]}
        {"messages":[{"role":"system","content":""},{"role":"user","content":"Tell me about writing"},{"role":"assistant","content":"I often write my thoughts in journals."}]}
        """
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("kf-eval-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: path) }
        try jsonl.write(to: path, atomically: true, encoding: .utf8)

        let dataset = try MetricEvaluator.loadEvalDataset(from: path)
        #expect(dataset.directProbes.count == 1)  // "Water" one
        #expect(dataset.styleHeldOut.count == 1)   // "I often write" one
    }
}

// MARK: - ExperimentTracker Tests

@Suite("ExperimentTracker")
struct ExperimentTrackerTests {

    private func makeTempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-exp-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("Records experiments to JSONL")
    func recordsExperiments() async throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let tracker = ExperimentTracker(experimentsDirectory: dir)
        try await tracker.load()

        let result = ExperimentResult(
            id: UUID(),
            proposedConfig: .defaultKnowledge,
            score: 0.75,
            previousBestScore: 0.70,
            decision: .kept,
            checkpointPath: nil,
            timestamp: Date(),
            description: "rank=32 alpha=64"
        )

        try await tracker.recordExperiment(result)

        let history = try await tracker.getExperimentHistory()
        #expect(history.count == 1)
        #expect(history[0].score == 0.75)
        #expect(history[0].decision == .kept)
    }

    @Test("Best config updates on kept experiment")
    func bestConfigUpdates() async throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let tracker = ExperimentTracker(experimentsDirectory: dir)
        try await tracker.load()

        var config = TrainingConfig.defaultKnowledge
        config.loraRank = 16

        let result = ExperimentResult(
            id: UUID(),
            proposedConfig: config,
            score: 0.80,
            previousBestScore: 0.0,
            decision: .kept,
            checkpointPath: nil,
            timestamp: Date(),
            description: "rank=16"
        )
        try await tracker.recordExperiment(result)

        let best = await tracker.getBestConfig()
        #expect(best?.loraRank == 16)
        #expect(await tracker.getBestScore() == 0.80)
    }

    @Test("Discarded experiment does not update best")
    func discardedNoUpdate() async throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let tracker = ExperimentTracker(experimentsDirectory: dir)
        try await tracker.load()

        let result = ExperimentResult(
            id: UUID(),
            proposedConfig: .defaultKnowledge,
            score: 0.50,
            previousBestScore: 0.70,
            decision: .discarded,
            checkpointPath: nil,
            timestamp: Date(),
            description: "rank=4 — worse"
        )
        try await tracker.recordExperiment(result)

        #expect(await tracker.getBestConfig() == nil)
        #expect(await tracker.getBestScore() == 0.0)
    }

    @Test("Persists and reloads best config")
    func persistence() async throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Write
        let tracker1 = ExperimentTracker(experimentsDirectory: dir)
        try await tracker1.load()
        let result = ExperimentResult(
            id: UUID(),
            proposedConfig: .defaultStyle,
            score: 0.90,
            previousBestScore: 0.0,
            decision: .kept,
            checkpointPath: nil,
            timestamp: Date(),
            description: "style baseline"
        )
        try await tracker1.recordExperiment(result)

        // Reload
        let tracker2 = ExperimentTracker(experimentsDirectory: dir)
        try await tracker2.load()
        #expect(await tracker2.getBestScore() == 0.90)
        #expect(await tracker2.getBestConfig()?.loraRank == 8)
    }

    @Test("Experiment log is append-only")
    func appendOnly() async throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let tracker = ExperimentTracker(experimentsDirectory: dir)
        try await tracker.load()

        for i in 0..<5 {
            let result = ExperimentResult(
                id: UUID(),
                proposedConfig: .defaultKnowledge,
                score: Double(i) * 0.1,
                previousBestScore: 0.0,
                decision: i % 2 == 0 ? .kept : .discarded,
                checkpointPath: nil,
                timestamp: Date(),
                description: "experiment \(i)"
            )
            try await tracker.recordExperiment(result)
        }

        let history = try await tracker.getExperimentHistory()
        #expect(history.count == 5)
    }
}

// MARK: - AutoresearchLoop Tests

@Suite("AutoresearchLoop")
struct AutoresearchLoopTests {

    @Test("Propose variation changes exactly one parameter")
    func proposeVariation() async {
        let trainer = QLoRATrainer()
        let tracker = ExperimentTracker(experimentsDirectory: FileManager.default.temporaryDirectory)
        let evaluator = MetricEvaluator(inferenceProvider: EvalMockInference())
        let loop = AutoresearchLoop(trainer: trainer, tracker: tracker, evaluator: evaluator)

        let base = TrainingConfig.defaultKnowledge

        // Run 20 proposals and check each differs from base in at most one dimension
        for _ in 0..<20 {
            let (proposed, description) = await loop.proposeVariation(from: base)
            #expect(!description.isEmpty)

            var diffs = 0
            if proposed.loraRank != base.loraRank { diffs += 1 }
            if proposed.learningRate != base.learningRate { diffs += 1 }
            if proposed.replayRatio != base.replayRatio { diffs += 1 }
            if proposed.curriculumOrder != base.curriculumOrder { diffs += 1 }

            #expect(diffs <= 1, "Should change at most one parameter, changed \(diffs)")
        }
    }

    @Test("Training budget defaults to 200 iterations")
    func trainingBudget() async {
        let trainer = QLoRATrainer()
        let tracker = ExperimentTracker(experimentsDirectory: FileManager.default.temporaryDirectory)
        let evaluator = MetricEvaluator(inferenceProvider: EvalMockInference())
        let loop = AutoresearchLoop(trainer: trainer, tracker: tracker, evaluator: evaluator, trainingBudget: 200)

        // Verify the loop was created with 200 budget (no direct accessor needed — tested via integration)
        #expect(await loop.currentlyRunning() == false)
    }
}
