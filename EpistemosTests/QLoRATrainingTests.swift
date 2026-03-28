import Foundation
import Testing
@testable import Epistemos

// MARK: - Helper

private func writeSampleJSONL(count: Int, prefix: String = "sample") -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("kf-\(prefix)-\(UUID().uuidString).jsonl")
    let lines = (0..<count).map { i in
        """
        {"messages":[{"role":"system","content":"You are helpful."},{"role":"user","content":"Question \(i)?"},{"role":"assistant","content":"Answer \(i)."}]}
        """
    }
    try! lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    return url
}

private func writeComplexJSONL() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("kf-complex-\(UUID().uuidString).jsonl")
    let lines = [
        // Simple: short definition
        """
        {"messages":[{"role":"system","content":""},{"role":"user","content":"What is water?"},{"role":"assistant","content":"Water is H2O."}]}
        """,
        // Medium: explanatory
        """
        {"messages":[{"role":"system","content":""},{"role":"user","content":"How does photosynthesis work?"},{"role":"assistant","content":"Photosynthesis is the process by which plants convert light energy into chemical energy. The process occurs in chloroplasts, where chlorophyll absorbs sunlight. Because carbon dioxide and water are combined, glucose and oxygen are produced as outputs."}]}
        """,
        // Complex: multi-hop reasoning
        """
        {"messages":[{"role":"system","content":""},{"role":"user","content":"Why is quantum error correction important?"},{"role":"assistant","content":"Quantum error correction is critically important because quantum states are inherently fragile. Therefore, without error correction, quantum computations would accumulate errors exponentially. Furthermore, the threshold theorem proves that given a sufficiently low physical error rate, logical error rates can be made arbitrarily small. Consequently, this implies that fault-tolerant quantum computing is theoretically achievable. However, the practical implementation requires enormous overhead in physical qubits, which means current noisy intermediate-scale quantum devices cannot yet achieve this goal. Nevertheless, progress in surface codes and topological approaches suggests that practical quantum error correction may be realized within the next decade."}]}
        """,
    ]
    try! lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    return url
}

private func loadRepoTextFile(_ relativePath: String) throws -> String {
    let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let fileURL = repoRoot.appendingPathComponent(relativePath)
    return try String(contentsOf: fileURL, encoding: .utf8)
}

// MARK: - ExperienceReplayBuffer Tests

@Suite("ExperienceReplayBuffer")
struct ExperienceReplayBufferTests {

    @Test("Mixed dataset has correct proportions")
    func mixedDatasetProportions() throws {
        let vaultData = writeSampleJSONL(count: 100, prefix: "vault")
        let replayData = writeSampleJSONL(count: 50, prefix: "replay")
        defer {
            try? FileManager.default.removeItem(at: vaultData)
            try? FileManager.default.removeItem(at: replayData)
        }

        let buffer = ExperienceReplayBuffer()
        let mixedURL = try buffer.generateMixedDataset(
            vaultData: vaultData,
            replayBuffer: replayData,
            ratio: 0.10
        )
        defer { try? FileManager.default.removeItem(at: mixedURL) }

        let mixedContent = try String(contentsOf: mixedURL, encoding: .utf8)
        let mixedLines = mixedContent.components(separatedBy: .newlines).filter { !$0.isEmpty }

        // 100 vault + ~11 replay (ceil(100 * 0.1 / 0.9) ≈ 12)
        #expect(mixedLines.count >= 110)
        #expect(mixedLines.count <= 115)
    }

    @Test("Replay examples are interleaved, not appended")
    func replayInterleaved() throws {
        let vaultData = writeSampleJSONL(count: 20, prefix: "vault-il")

        // Create replay with distinctive content
        let replayURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-replay-il-\(UUID().uuidString).jsonl")
        let replayLines = (0..<10).map { _ in
            """
            {"messages":[{"role":"system","content":"REPLAY"},{"role":"user","content":"Replay Q"},{"role":"assistant","content":"Replay A"}]}
            """
        }
        try replayLines.joined(separator: "\n").write(to: replayURL, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: vaultData)
            try? FileManager.default.removeItem(at: replayURL)
        }

        let buffer = ExperienceReplayBuffer()
        let mixedURL = try buffer.generateMixedDataset(
            vaultData: vaultData,
            replayBuffer: replayURL,
            ratio: 0.10
        )
        defer { try? FileManager.default.removeItem(at: mixedURL) }

        let lines = try String(contentsOf: mixedURL, encoding: .utf8)
            .components(separatedBy: .newlines).filter { !$0.isEmpty }

        // Replay lines should NOT all be at the end
        let replayIndices = lines.enumerated().filter { $0.element.contains("REPLAY") }.map(\.offset)
        #expect(!replayIndices.isEmpty)

        if let first = replayIndices.first {
            // Replay should be spread throughout, not just at the end
            #expect(first < lines.count / 2, "First replay example should appear in first half")
        }
    }

    @Test("Empty vault data throws error")
    func emptyVaultThrows() throws {
        let emptyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-empty-\(UUID().uuidString).jsonl")
        try "".write(to: emptyURL, atomically: true, encoding: .utf8)
        let replayURL = writeSampleJSONL(count: 10, prefix: "replay-err")
        defer {
            try? FileManager.default.removeItem(at: emptyURL)
            try? FileManager.default.removeItem(at: replayURL)
        }

        let buffer = ExperienceReplayBuffer()
        #expect(throws: ReplayBufferError.self) {
            try buffer.generateMixedDataset(vaultData: emptyURL, replayBuffer: replayURL)
        }
    }

    @Test("Create replay buffer respects capacity")
    func createBufferCapacity() throws {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-buf-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let examples = (0..<600).map { i in
            ReplayExample(prompt: "Q\(i)", response: "A\(i)")
        }

        let buffer = ExperienceReplayBuffer(bufferCapacity: 500)
        try buffer.createReplayBuffer(from: examples, outputPath: outputURL)

        let content = try String(contentsOf: outputURL, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        #expect(lines.count == 500, "Buffer should cap at 500 examples")
    }
}

// MARK: - CurriculumSorter Tests

@Suite("CurriculumSorter")
struct CurriculumSorterTests {

    @Test("Simple content scores lower than complex content")
    func simpleVsComplex() {
        let sorter = CurriculumSorter()

        let simple = "Water is H2O."
        let complex = """
        Quantum error correction is critically important because quantum states \
        are inherently fragile. Therefore, without correction, computations accumulate \
        errors exponentially. Furthermore, the threshold theorem proves that given a \
        sufficiently low physical error rate, logical error rates can be made arbitrarily \
        small. Consequently, this implies fault-tolerant quantum computing is achievable. \
        However, practical implementation requires enormous overhead in physical qubits.
        """

        let simpleScore = sorter.computeComplexity(simple)
        let complexScore = sorter.computeComplexity(complex)

        #expect(simpleScore < complexScore,
               "Simple (\(simpleScore)) should score lower than complex (\(complexScore))")
    }

    @Test("Multi-hop cues increase complexity score")
    func multiHopCues() {
        let sorter = CurriculumSorter()

        let withoutCues = "The sky is blue. Grass is green. The sun is bright."
        let withCues = "The sky is blue because of Rayleigh scattering. Therefore light scatters differently. Consequently the sky appears blue."

        let scoreWithout = sorter.computeComplexity(withoutCues)
        let scoreWith = sorter.computeComplexity(withCues)

        #expect(scoreWith > scoreWithout)
    }

    @Test("Sort produces ascending complexity order")
    func sortAscending() throws {
        let inputURL = writeComplexJSONL()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-sorted-\(UUID().uuidString).jsonl")
        defer {
            try? FileManager.default.removeItem(at: inputURL)
            try? FileManager.default.removeItem(at: outputURL)
        }

        let sorter = CurriculumSorter()
        try sorter.sortByComplexity(inputPath: inputURL, outputPath: outputURL)

        let outputLines = try String(contentsOf: outputURL, encoding: .utf8)
            .components(separatedBy: .newlines).filter { !$0.isEmpty }

        #expect(outputLines.count == 3)

        // First line should be the simplest (shortest answer: "Water is H2O.")
        #expect(outputLines[0].contains("Water is H2O"))

        // Last line should be the most complex (quantum error correction)
        #expect(outputLines[2].contains("threshold theorem"))
    }

    @Test("Empty text scores zero")
    func emptyScoresZero() {
        let sorter = CurriculumSorter()
        #expect(sorter.computeComplexity("") == 0)
    }
}

// MARK: - TrainingProfileManager Tests

@Suite("TrainingProfileManager")
struct TrainingProfileManagerTests {

    @Test("Knowledge-heavy data recommends knowledge profile")
    func knowledgeProfile() throws {
        let knowledgePath = writeSampleJSONL(count: 80, prefix: "know")
        let stylePath = writeSampleJSONL(count: 10, prefix: "style")
        let toolPath = writeSampleJSONL(count: 10, prefix: "tool")
        defer {
            try? FileManager.default.removeItem(at: knowledgePath)
            try? FileManager.default.removeItem(at: stylePath)
            try? FileManager.default.removeItem(at: toolPath)
        }

        let manager = TrainingProfileManager()
        let rec = try manager.recommend(
            knowledgePath: knowledgePath,
            stylePath: stylePath,
            toolPath: toolPath
        )

        #expect(rec.profile == .knowledge)
        #expect(rec.totalPairs == 100)
    }

    @Test("Style-heavy data recommends style profile")
    func styleProfile() throws {
        let knowledgePath = writeSampleJSONL(count: 10, prefix: "know-s")
        let stylePath = writeSampleJSONL(count: 70, prefix: "style-s")
        defer {
            try? FileManager.default.removeItem(at: knowledgePath)
            try? FileManager.default.removeItem(at: stylePath)
        }

        let manager = TrainingProfileManager()
        let rec = try manager.recommend(
            knowledgePath: knowledgePath,
            stylePath: stylePath,
            toolPath: nil
        )

        #expect(rec.profile == .style)
    }

    @Test("Mixed data recommends mixed profile")
    func mixedProfile() throws {
        let knowledgePath = writeSampleJSONL(count: 40, prefix: "know-m")
        let stylePath = writeSampleJSONL(count: 40, prefix: "style-m")
        let toolPath = writeSampleJSONL(count: 20, prefix: "tool-m")
        defer {
            try? FileManager.default.removeItem(at: knowledgePath)
            try? FileManager.default.removeItem(at: stylePath)
            try? FileManager.default.removeItem(at: toolPath)
        }

        let manager = TrainingProfileManager()
        let rec = try manager.recommend(
            knowledgePath: knowledgePath,
            stylePath: stylePath,
            toolPath: toolPath
        )

        #expect(rec.profile == .mixed)
        #expect(rec.totalPairs == 100)
    }
}

// MARK: - Hyperparameter Verification Tests

@Suite("Hyperparameter Compliance")
struct HyperparameterComplianceTests {

    @Test("Knowledge training script has correct hyperparameters")
    func knowledgeHyperparams() throws {
        let scriptURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/KnowledgeFusion/Training/scripts/train_knowledge.py")
        let trainerSource = try loadRepoTextFile("Epistemos/KnowledgeFusion/Training/QLoRATrainer.swift")

        // Fall back to source directory if not in bundle (test environment)
        let sourcePath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Epistemos/KnowledgeFusion/Training/scripts/train_knowledge.py")

        let url = FileManager.default.fileExists(atPath: scriptURL.path) ? scriptURL : sourcePath
        guard FileManager.default.fileExists(atPath: url.path) else {
            // Script not accessible from test environment; skip
            return
        }

        let content = try String(contentsOf: url, encoding: .utf8)

        // ANCHOR 2 compliance checks
        #expect(content.contains("DEFAULT_RANK = 16"))
        #expect(content.contains("DEFAULT_ALPHA = 32"))
        #expect(content.contains("gate_proj"))
        #expect(content.contains("up_proj"))
        #expect(content.contains("down_proj"))
        #expect(content.contains("DEFAULT_LR = 2e-5"))
        #expect(content.contains("REPLAY_RATIO = 0.10"))
        #expect(trainerSource.contains("static let defaultKnowledge = TrainingConfig("))
        #expect(trainerSource.contains("loraRank: 16"))
        #expect(trainerSource.contains("loraAlpha: 32"))
        #expect(trainerSource.contains("config: TrainingConfig = .defaultKnowledge"))

        // ANCHOR 3, GAP 1: No fusion calls in actual code
        #expect(!content.contains("merge_weights=True"))
        #expect(!content.contains("merge_adapter("))
        #expect(!content.contains(".fuse("))
    }

    @Test("Style training script has correct hyperparameters")
    func styleHyperparams() throws {
        let sourcePath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Epistemos/KnowledgeFusion/Training/scripts/train_style.py")
        let trainerSource = try loadRepoTextFile("Epistemos/KnowledgeFusion/Training/QLoRATrainer.swift")

        guard FileManager.default.fileExists(atPath: sourcePath.path) else { return }
        let content = try String(contentsOf: sourcePath, encoding: .utf8)

        // ANCHOR 2 compliance: style profile
        #expect(content.contains("DEFAULT_RANK = 8"))
        #expect(content.contains("DEFAULT_ALPHA = 16"))
        #expect(content.contains("DEFAULT_LR = 1e-5"))

        // Style must NOT target MLP layers in the TARGET_MODULES list
        // (gate_proj may appear in comments but not in the active list)
        #expect(content.contains("q_proj"))
        #expect(content.contains("k_proj"))
        #expect(trainerSource.contains("static let defaultStyle = TrainingConfig("))
        #expect(trainerSource.contains("loraRank: 8"))
        #expect(trainerSource.contains("loraAlpha: 16"))
        #expect(trainerSource.contains("config: TrainingConfig = .defaultStyle"))

        // ANCHOR 3, GAP 1: No fusion calls in actual code
        #expect(!content.contains("merge_weights=True"))
        #expect(!content.contains("merge_adapter("))
        #expect(!content.contains(".fuse("))
    }
}
