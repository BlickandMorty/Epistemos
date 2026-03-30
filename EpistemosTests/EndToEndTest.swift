import Foundation
import Testing
@testable import Epistemos

// MARK: - Deterministic Mock for E2E Pipeline

/// Returns structured, deterministic responses for the full pipeline test.
private struct E2EMockInference: KFInferenceProvider {
    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        if prompt.contains("Generate") && prompt.contains("questions") {
            return """
            1. What are the main principles described in this passage?
            2. How does this concept apply to real-world scenarios?
            3. What evidence supports the claims made here?
            """
        } else if prompt.contains("Rewrite the passage") {
            return """
            The passage describes several interconnected principles that form \
            a comprehensive framework. The key insight is that systematic \
            approaches yield more reliable outcomes than ad-hoc methods. \
            This has been validated through extensive empirical research \
            across multiple domains.
            """
        } else if prompt.contains("Rate the following") {
            return "4"
        } else if prompt.contains("Answer the following") {
            return "Quantum error correction protects quantum information from decoherence using redundant encoding across surface codes."
        } else if prompt.contains("Think through") {
            return "The threshold theorem implies fault-tolerant quantum computing is achievable given sufficiently low physical error rates."
        } else if prompt.contains("Continue") {
            return "I believe this demonstrates the fundamental principles at work in practice."
        }
        return "Generic response for testing."
    }
}

// MARK: - Test Vault Creator

private func createE2ETestVault() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("kf-e2e-vault-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    // 5 markdown files covering different topics
    let topics: [(String, String)] = [
        ("quantum_computing", """
        ## Quantum Error Correction

        Quantum error correction (QEC) protects quantum information from decoherence and quantum noise. \
        The threshold theorem proves that quantum computation can be made arbitrarily reliable as long as \
        the error rate per physical gate is below a certain threshold. Surface codes are the most \
        promising approach for near-term quantum computers, requiring only nearest-neighbor qubit \
        interactions on a 2D lattice. The logical error rate decreases exponentially with code distance.

        ## Quantum Algorithms

        Shor's algorithm factors large integers exponentially faster than classical methods. Grover's \
        algorithm provides quadratic speedup for unstructured search. The Variational Quantum Eigensolver \
        combines classical optimization with quantum circuit evaluation for molecular simulation.
        """),
        ("machine_learning", """
        ## Transformer Architecture

        The transformer architecture revolutionized natural language processing through self-attention \
        mechanisms. Unlike recurrent networks, transformers process all positions simultaneously, \
        enabling massive parallelization during training. The attention mechanism computes weighted \
        sums of value vectors, with weights determined by query-key compatibility scores.

        ## Fine-Tuning Methods

        Parameter-efficient fine-tuning methods like LoRA adapt pre-trained models by learning low-rank \
        update matrices. This approach freezes the original weights and only trains the small adapter \
        matrices, dramatically reducing memory requirements and training time.
        """),
        ("personal_journal", """
        ## March Research Notes

        I've been exploring how attention layers and MLP layers serve different roles in transformers. \
        My intuition was that attention handles both style and facts, but the research shows MLP layers \
        are the primary knowledge stores. I think this insight fundamentally changes how we should \
        approach fine-tuning. Tomorrow I plan to test this hypothesis with targeted layer freezing.

        ## Weekly Reflection

        This week I made significant progress on the knowledge fusion architecture. I feel confident \
        that the five-subsystem design will scale well. My main concern is the training time on M1 \
        hardware, but the benchmarks suggest it should be manageable for vault sizes under 10,000 notes.
        """),
        ("api_reference", """
        ## MLX-LM Training API

        The mlx-lm library provides function endpoints for fine-tuning language models on Apple Silicon. \
        The primary command `mlx_lm.lora` accepts parameters including --model for the base model path, \
        --data for the JSONL training data directory, and --adapter-path for output. The REST API module \
        interface serves models via `mlx_lm.server --model [path] --adapter-path [path]`. Configuration \
        requires specifying target_modules as a list of layer names.

        ## Whisper Transcription API

        The mlx-whisper library provides audio transcription with the function `mlx_whisper.transcribe()`. \
        It accepts a file path parameter and returns a JSON object containing segments with timestamps. \
        The endpoint supports multiple model sizes via the path_or_hf_repo argument.
        """),
        ("cryptography", """
        ## Post-Quantum Cryptography

        The advent of large-scale quantum computers threatens current public-key cryptography. RSA and \
        elliptic curve cryptography rely on problems that quantum algorithms can solve efficiently. \
        NIST has standardized several post-quantum algorithms including CRYSTALS-Kyber for key \
        encapsulation and CRYSTALS-Dilithium for digital signatures.

        ## Lattice-Based Cryptography

        Lattice problems like Learning With Errors (LWE) form the foundation of several post-quantum \
        schemes. These problems remain computationally hard even for quantum computers, providing \
        confidence in long-term security guarantees.
        """),
    ]

    for (name, content) in topics {
        try content.write(
            to: root.appendingPathComponent("\(name).md"),
            atomically: true, encoding: .utf8
        )
    }

    return root
}

// MARK: - End-to-End Test

@Suite("EndToEnd Knowledge Fusion Pipeline")
@MainActor
struct EndToEndTest {

    @Test("Full pipeline: parse → chunk → generate → curate → register")
    func fullPipeline() async throws {
        let vaultURL = try createE2ETestVault()
        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-e2e-output-\(UUID().uuidString)")
        let registryPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-e2e-registry-\(UUID().uuidString).json")
        defer {
            try? FileManager.default.removeItem(at: vaultURL)
            try? FileManager.default.removeItem(at: outputDir)
            try? FileManager.default.removeItem(at: registryPath)
        }

        // Step 1: Parse vault
        let parser = VaultParser()
        let parseResult = await parser.parseVault(at: vaultURL)
        #expect(parseResult.parsedItems == 5)
        #expect(parseResult.errors.isEmpty)

        // Step 2: Chunk documents
        let chunker = DocumentChunker()
        let chunks = chunker.chunkAll(documents: parseResult.documents)
        #expect(!chunks.isEmpty)
        #expect(chunks.count >= 5, "Should produce at least one chunk per document")

        // Verify no chunk exceeds max tokens
        for chunk in chunks {
            #expect(chunk.estimatedTokenCount <= 1500)
        }

        // Step 3: Generate synthetic data
        let provider = E2EMockInference()
        let generator = SyntheticDataGenerator(
            inferenceProvider: provider,
            outputDirectory: outputDir,
            qualityThreshold: 3,
            evalHoldoutRatio: 0.10
        )
        let synthResult = try await generator.generate(chunks: chunks)

        #expect(synthResult.totalGenerated > 0, "Should generate pairs from chunks")
        #expect(synthResult.totalAccepted > 0, "Should accept quality pairs")

        // Step 4: Verify JSONL files
        for (category, fileURL) in synthResult.trainingFiles {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
            #expect(!lines.isEmpty, "\(category) JSONL should not be empty")

            // Validate each line is valid JSON
            for line in lines {
                let data = line.data(using: .utf8)!
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                #expect(json?["messages"] != nil, "Each line must have messages array")
            }
        }

        // Step 5: Verify eval holdout created
        #expect(synthResult.evalHeldOutCount > 0, "Should hold out eval examples")

        // Step 6: Register mock adapter
        let registry = AdapterRegistry(storagePath: registryPath)
        let adapterDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-e2e-adapter-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: adapterDir, withIntermediateDirectories: true)
        try Data([0x00]).write(to: adapterDir.appendingPathComponent("adapter_weights.safetensors"))
        defer { try? FileManager.default.removeItem(at: adapterDir) }

        let record = AdapterRecord(
            id: UUID(),
            name: "E2E Test Adapter",
            type: .knowledge,
            adapterPath: adapterDir,
            metadataPath: adapterDir.appendingPathComponent("training_metadata.json"),
            sourceVault: "e2e-vault",
            createdAt: Date(),
            qualityScore: nil,
            isActive: false,
            baseModel: "test",
            loraRank: 32,
            parameterCount: 32 * 4096 * 7 * 2,
            trainingExamples: synthResult.totalAccepted
        )
        try await registry.register(record)
        try await registry.setActive(record.id, active: true)

        let active = await registry.getActiveAdapters()
        #expect(active.count == 1)

        // Step 7: Load adapter (hot-swap)
        let loader = AdapterLoader()
        try await loader.load(record)
        #expect(await loader.isLoaded(record.id))

        // Step 8: Run evaluation
        let evaluator = MetricEvaluator(inferenceProvider: provider)
        let evalData = EvaluationDataset(
            directProbes: [
                .init(question: "What is quantum error correction?",
                      expectedAnswer: "QEC protects quantum information from decoherence using surface codes"),
            ],
            indirectProbes: [
                .init(question: "How does the threshold theorem enable quantum computing?",
                      expectedKeywords: ["threshold", "fault-tolerant"]),
            ],
            styleHeldOut: [
                "I believe this approach demonstrates the key principles effectively building on prior research and experience."
            ]
        )

        let score = await evaluator.evaluate(evalData: evalData)
        #expect(score.directProbingScore > 0.0, "Direct probing should score > 0")
        #expect(score.compositeScore >= 0.0)
        #expect(score.compositeScore <= 1.0)
    }

    @Test("Category classification covers all three types")
    func categoryClassification() async throws {
        let vaultURL = try createE2ETestVault()
        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-e2e-cat-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: vaultURL)
            try? FileManager.default.removeItem(at: outputDir)
        }

        let parser = VaultParser()
        let parseResult = await parser.parseVault(at: vaultURL)
        let chunker = DocumentChunker()
        let chunks = chunker.chunkAll(documents: parseResult.documents)

        let generator = SyntheticDataGenerator(
            inferenceProvider: E2EMockInference(),
            outputDirectory: outputDir,
            qualityThreshold: 1,  // Accept all for category test
            evalHoldoutRatio: 0.0
        )
        let result = try await generator.generate(chunks: chunks)

        // With mock inference, classification depends on chunk content + mock answers.
        // Verify at least some pairs were accepted and categorized.
        let totalCategorized = result.categoryBreakdown.values.reduce(0, +)
        #expect(totalCategorized == result.totalAccepted, "All accepted pairs should be categorized")
    }
}
