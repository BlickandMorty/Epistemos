import Foundation
import Testing
@testable import Epistemos

// MARK: - Thread-Safe Progress Counter

private actor ProgressCounter {
    private var _count = 0
    private var _lastPhaseRaw: String?

    nonisolated func record(_ progress: SyntheticDataProgress) {
        let raw = progress.phase.rawValue
        Task { await _record(raw) }
    }

    private func _record(_ phaseRaw: String) {
        _count += 1
        _lastPhaseRaw = phaseRaw
    }

    var count: Int { _count }
    var lastPhaseRaw: String? { _lastPhaseRaw }
}

// MARK: - Mock Inference Provider

/// Deterministic mock that returns canned responses for the 3-step backtranslation.
/// Simulates the on-device model without requiring actual MLX inference.
private struct MockInferenceProvider: KFInferenceProvider {
    let scorePattern: [Int]  // rotating scores for quality step

    init(scorePattern: [Int] = [4, 3, 2]) {
        self.scorePattern = scorePattern
    }

    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        // Detect which step based on prompt content
        if prompt.contains("Generate") && prompt.contains("questions") {
            // Step A: Query generation
            return """
            1. What is the main concept described in this passage?
            2. How does this topic relate to practical applications?
            3. What are the key components or elements mentioned?
            """
        } else if prompt.contains("Rewrite the passage") {
            // Step B: Response rewriting
            return """
            The passage describes a fundamental concept in this domain. \
            The key insight is that the approach combines theoretical foundations \
            with practical implementation details. The methodology involves \
            several distinct phases, each building upon the previous one to \
            create a comprehensive solution.
            """
        } else if prompt.contains("Rate the following") || prompt.contains("Rate this QA pair") {
            // Step C: Quality scoring — rotate through scorePattern
            // Use a simple deterministic approach based on prompt hash
            let hash = abs(prompt.hashValue)
            let index = hash % scorePattern.count
            return "\(scorePattern[index])"
        }

        return "Mock response"
    }
}

// MARK: - Sample Chunks

private func makeSampleChunks() -> [TextChunk] {
    [
        // Knowledge chunk
        TextChunk(
            id: UUID(),
            documentId: UUID(),
            sourcePageId: nil,
            chunkIndex: 0,
            text: """
            ## Quantum Error Correction

            Quantum error correction (QEC) protects quantum information from decoherence and quantum noise. \
            The threshold theorem proves that quantum computation can be made arbitrarily reliable as long as \
            the error rate per physical gate is below a certain threshold. Surface codes are the most \
            promising approach for near-term quantum computers, requiring only nearest-neighbor qubit \
            interactions on a 2D lattice. The logical error rate decreases exponentially with code distance.
            """,
            heading: "## Quantum Error Correction",
            hierarchy: "## Quantum Error Correction",
            estimatedTokenCount: 100,
            chunkType: .markdown
        ),
        // Style chunk (personal writing)
        TextChunk(
            id: UUID(),
            documentId: UUID(),
            sourcePageId: nil,
            chunkIndex: 1,
            text: """
            ## My Research Journal

            I've been thinking about how transformers process information differently than I expected. \
            My intuition was that attention layers would be the primary site of factual knowledge storage, \
            but the research suggests MLP layers are actually the key-value memory networks. I feel like \
            this changes my entire mental model of how fine-tuning works. Tomorrow I'm going to run \
            experiments to test whether targeting MLP layers versus attention layers makes a measurable \
            difference in knowledge absorption.
            """,
            heading: "## My Research Journal",
            hierarchy: "## My Research Journal",
            estimatedTokenCount: 120,
            chunkType: .markdown
        ),
        // Tool chunk
        TextChunk(
            id: UUID(),
            documentId: UUID(),
            sourcePageId: nil,
            chunkIndex: 2,
            text: """
            ## MLX-LM API Reference

            The mlx-lm library provides a Python API for fine-tuning language models on Apple Silicon. \
            The primary function `mlx_lm.lora` accepts parameters including --model for the base model path, \
            --data for the training JSONL, and --adapter-path for the output adapter weights. The endpoint \
            configuration requires specifying target_modules as a list of module names like q_proj, k_proj. \
            The REST API interface serves the model via `mlx_lm.server --model [path] --adapter-path [path]`.
            """,
            heading: "## MLX-LM API Reference",
            hierarchy: "## MLX-LM API Reference",
            estimatedTokenCount: 130,
            chunkType: .markdown
        ),
    ]
}

private func makeCuratablePair(
    index: Int,
    qualityScore: Int,
    sourceChunkId: UUID = UUID()
) -> GeneratedPair {
    GeneratedPair(
        question: "What does example \(index) reveal about building a resilient knowledge system?",
        answer: """
        Example \(index) shows that a resilient knowledge system preserves evidence, validates retrieval quality, \
        and keeps answers grounded in structured context even after repeated edits, sync passes, and evaluation cycles.
        """,
        qualityScore: qualityScore,
        sourceChunkId: sourceChunkId,
        sourceChunkText: """
        Example \(index) discusses resilient knowledge systems, grounded retrieval, and stable evaluation behavior.
        """
    )
}

// MARK: - InstructionBacktranslator Tests

@Suite("InstructionBacktranslator")
struct InstructionBacktranslatorTests {

    @Test("Generates pairs from a knowledge chunk")
    func generatesPairsFromChunk() async throws {
        let provider = MockInferenceProvider(scorePattern: [4, 3, 5])
        let bt = InstructionBacktranslator(inferenceProvider: provider)
        let chunk = makeSampleChunks()[0]

        let pairs = try await bt.backtranslate(chunk: chunk)

        #expect(!pairs.isEmpty)
        #expect(pairs.count <= 3)

        for pair in pairs {
            #expect(!pair.question.isEmpty)
            #expect(!pair.answer.isEmpty)
            #expect(pair.qualityScore >= 1 && pair.qualityScore <= 5)
            #expect(pair.sourceChunkId == chunk.id)
        }
    }

    @Test("Quality scores are parsed correctly")
    func qualityScoresParsed() async throws {
        let provider = MockInferenceProvider(scorePattern: [5, 1, 3])
        let bt = InstructionBacktranslator(inferenceProvider: provider)
        let chunk = makeSampleChunks()[0]

        let pairs = try await bt.backtranslate(chunk: chunk)
        // All pairs should have valid scores between 1-5
        for pair in pairs {
            #expect(pair.qualityScore >= 1)
            #expect(pair.qualityScore <= 5)
        }
    }
}

// MARK: - QualityCurator Tests

@Suite("QualityCurator")
struct QualityCuratorTests {

    @Test("Quality filter discards pairs below threshold")
    func qualityFilterDiscards() {
        let curator = QualityCurator(qualityThreshold: 3)

        let pairs: [GeneratedPair] = [
            makeCuratablePair(index: 1, qualityScore: 5),
            makeCuratablePair(index: 2, qualityScore: 2),
            makeCuratablePair(index: 3, qualityScore: 1),
            makeCuratablePair(index: 4, qualityScore: 3),
            makeCuratablePair(index: 5, qualityScore: 4),
        ]

        let result = curator.curate(pairs: pairs)

        // Pairs with score 2 and 1 should be discarded
        #expect(result.discardedCount == 2)
        #expect(result.accepted.count + result.evalHeldOut.count == 3)
    }

    @Test("Duplicate pairs are deduplicated via SHA-256")
    func deduplication() {
        let curator = QualityCurator(qualityThreshold: 1)
        let chunkId = UUID()
        let duplicate = makeCuratablePair(index: 1, qualityScore: 4, sourceChunkId: chunkId)

        let pairs: [GeneratedPair] = [
            duplicate,
            GeneratedPair(
                question: duplicate.question,
                answer: duplicate.answer,
                qualityScore: 5,
                sourceChunkId: chunkId,
                sourceChunkText: duplicate.sourceChunkText
            ),
            makeCuratablePair(index: 2, qualityScore: 3, sourceChunkId: chunkId),
        ]

        let result = curator.curate(pairs: pairs)
        #expect(result.duplicateCount == 1)
        #expect(result.accepted.count + result.evalHeldOut.count == 2)
    }

    @Test("Classification: personal writing → style")
    func classifiesStyle() {
        let curator = QualityCurator()
        let category = curator.classifyPair(
            question: "What did you work on today?",
            answer: "I worked on my knowledge fusion system. I've been thinking about transformer architectures."
        )
        #expect(category == .style)
    }

    @Test("Classification: API/tool content → tool")
    func classifiesTool() {
        let curator = QualityCurator()
        let category = curator.classifyPair(
            question: "How do you use the mlx-lm API?",
            answer: "The function accepts a model parameter and an endpoint configuration. Import the library and call the REST API method."
        )
        #expect(category == .tool)
    }

    @Test("Classification: factual content → knowledge")
    func classifiesKnowledge() {
        let curator = QualityCurator()
        let category = curator.classifyPair(
            question: "What is quantum error correction?",
            answer: "Quantum error correction protects quantum information from decoherence using redundant encoding across multiple physical qubits."
        )
        #expect(category == .knowledge)
    }

    @Test("Eval holdout is approximately 10%")
    func evalHoldout() {
        let curator = QualityCurator(qualityThreshold: 1, evalHoldoutRatio: 0.10)

        // Generate 50 unique pairs
        let pairs = (0..<50).map { i in
            makeCuratablePair(index: i, qualityScore: 4)
        }

        let result = curator.curate(pairs: pairs)
        let curatedCount = result.accepted.count + result.evalHeldOut.count
        // Holdout is computed from the post-filter curated set, not the raw input count.
        #expect(result.evalHeldOut.count >= 3)
        #expect(result.evalHeldOut.count <= 8)
        #expect(curatedCount + result.discardedCount + result.duplicateCount == 50)
    }

    @Test("JSONL output is valid JSON per line")
    func jsonlValid() throws {
        let curator = QualityCurator(qualityThreshold: 1, evalHoldoutRatio: 0.0)
        let pairs: [GeneratedPair] = [
            makeCuratablePair(index: 1, qualityScore: 4),
            makeCuratablePair(index: 2, qualityScore: 5),
        ]

        let result = curator.curate(pairs: pairs)
        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-jsonl-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: outputDir) }

        let files = try curator.writeJSONL(
            pairs: result.accepted,
            outputDirectory: outputDir,
            timestamp: "test"
        )

        for (_, fileURL) in files {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }

            for line in lines {
                let data = line.data(using: .utf8)!
                let parsed = try JSONSerialization.jsonObject(with: data)
                let dict = parsed as? [String: Any]
                #expect(dict != nil, "Each JSONL line must be valid JSON")

                let messages = dict?["messages"] as? [[String: Any]]
                #expect(messages != nil, "Each line must have 'messages' array")
                #expect(messages?.count == 3, "Each line must have system/user/assistant messages")
            }
        }
    }

    @Test("Category breakdown counts are correct")
    func categoryBreakdown() {
        let curator = QualityCurator(qualityThreshold: 1, evalHoldoutRatio: 0.0)

        let pairs: [GeneratedPair] = [
            // Knowledge
            GeneratedPair(question: "What is photosynthesis?", answer: "Photosynthesis converts light energy into chemical energy in plants.", qualityScore: 4, sourceChunkId: UUID(), sourceChunkText: ""),
            // Style
            GeneratedPair(question: "What happened today?", answer: "I spent my morning reviewing notes. I think the approach is working.", qualityScore: 4, sourceChunkId: UUID(), sourceChunkText: ""),
            // Tool
            GeneratedPair(question: "How to call the API?", answer: "The function endpoint accepts a parameter and returns the REST interface module.", qualityScore: 4, sourceChunkId: UUID(), sourceChunkText: ""),
        ]

        let result = curator.curate(pairs: pairs)
        let total = result.categoryBreakdown.values.reduce(0, +)
        #expect(total == result.accepted.count)
    }
}

// MARK: - SyntheticDataGenerator Integration Tests

@Suite("SyntheticDataGenerator")
struct SyntheticDataGeneratorTests {

    @Test("Full pipeline produces JSONL output from sample chunks")
    func fullPipeline() async throws {
        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-synth-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: outputDir) }

        let provider = MockInferenceProvider(scorePattern: [4, 3, 5])
        let generator = SyntheticDataGenerator(
            inferenceProvider: provider,
            outputDirectory: outputDir,
            qualityThreshold: 3,
            evalHoldoutRatio: 0.10
        )

        let chunks = makeSampleChunks()
        let progressCounter = ProgressCounter()

        let result = try await generator.generate(chunks: chunks) { progress in
            progressCounter.record(progress)
        }

        // Verify at least some pairs were generated
        #expect(result.totalGenerated > 0, "Should generate pairs from 3 chunks")
        #expect(result.totalAccepted > 0, "Should accept at least some pairs")
        #expect(!result.trainingFiles.isEmpty, "Should produce at least one JSONL file")

        // Allow async progress tasks to complete
        try await Task.sleep(for: .milliseconds(100))

        // Verify progress was reported
        let pCount = await progressCounter.count
        let pLast = await progressCounter.lastPhaseRaw
        #expect(pCount > 0, "Should report progress")
        #expect(pLast == SyntheticDataPhase.complete.rawValue)

        // Verify JSONL files exist and are valid
        for (_, fileURL) in result.trainingFiles {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
            #expect(!lines.isEmpty)

            for line in lines {
                let data = line.data(using: .utf8)!
                let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                #expect(parsed?["messages"] != nil)
            }
        }
    }

    @Test("Empty chunks produces empty result")
    func emptyChunks() async throws {
        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-empty-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: outputDir) }

        let provider = MockInferenceProvider()
        let generator = SyntheticDataGenerator(
            inferenceProvider: provider,
            outputDirectory: outputDir
        )

        let result = try await generator.generate(chunks: [])
        #expect(result.totalGenerated == 0)
        #expect(result.trainingFiles.isEmpty)
    }

    @Test("Quality filter reduces output count")
    func qualityFilterReduces() async throws {
        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-filter-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: outputDir) }

        // Score pattern where most pairs get low scores → high discard rate
        let provider = MockInferenceProvider(scorePattern: [1, 2, 1])
        let generator = SyntheticDataGenerator(
            inferenceProvider: provider,
            outputDirectory: outputDir,
            qualityThreshold: 3
        )

        let chunks = [makeSampleChunks()[0]]
        let result = try await generator.generate(chunks: chunks)

        // With scores [1, 2, 1], all pairs should be discarded (threshold 3)
        #expect(result.totalDiscarded == result.totalGenerated)
        #expect(result.totalAccepted == 0)
    }
}
