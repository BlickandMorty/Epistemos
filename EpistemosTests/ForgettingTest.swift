import Foundation
import Testing
@testable import Epistemos

// MARK: - Forgetting Test

/// Tests that experience replay and curriculum learning mitigate catastrophic forgetting.
/// Per ANCHOR 4: all four mitigations must be present and functional.
///
/// Since we cannot run actual model training in unit tests, this suite verifies:
/// 1. Experience replay buffer correctly mixes data
/// 2. Curriculum sorter produces correct ordering
/// 3. The combined pipeline preserves data integrity
/// 4. Training config defaults include all mitigations
@Suite("Catastrophic Forgetting Mitigations")
struct ForgettingTest {

    // MARK: - Mitigation 1: Experience Replay

    @Test("Replay buffer interleaves general examples at correct ratio")
    func replayRatio() throws {
        let buffer = ExperienceReplayBuffer(bufferCapacity: 500, defaultReplayRatio: 0.10)

        // Create 1000-line vault data
        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-forget-vault-\(UUID().uuidString).jsonl")
        let replayURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-forget-replay-\(UUID().uuidString).jsonl")
        defer {
            try? FileManager.default.removeItem(at: vaultURL)
            try? FileManager.default.removeItem(at: replayURL)
        }

        let vaultLines = (0..<1000).map { i in
            "{\"messages\":[{\"role\":\"user\",\"content\":\"VaultQ\(i)\"},{\"role\":\"assistant\",\"content\":\"VaultA\(i)\"}]}"
        }
        try vaultLines.joined(separator: "\n").write(to: vaultURL, atomically: true, encoding: .utf8)

        let replayLines = (0..<500).map { i in
            "{\"messages\":[{\"role\":\"user\",\"content\":\"GeneralQ\(i)\"},{\"role\":\"assistant\",\"content\":\"GeneralA\(i)\"}]}"
        }
        try replayLines.joined(separator: "\n").write(to: replayURL, atomically: true, encoding: .utf8)

        let mixedURL = try buffer.generateMixedDataset(vaultData: vaultURL, replayBuffer: replayURL, ratio: 0.10)
        defer { try? FileManager.default.removeItem(at: mixedURL) }

        let mixedContent = try String(contentsOf: mixedURL, encoding: .utf8)
        let mixedLines = mixedContent.components(separatedBy: .newlines).filter { !$0.isEmpty }

        let replayCount = mixedLines.filter { $0.contains("GeneralQ") }.count
        let vaultCount = mixedLines.filter { $0.contains("VaultQ") }.count

        // Replay should be ~10% of total
        let ratio = Double(replayCount) / Double(mixedLines.count)
        #expect(ratio > 0.05, "Replay ratio too low: \(ratio)")
        #expect(ratio < 0.20, "Replay ratio too high: \(ratio)")

        // Vault data should be preserved
        #expect(vaultCount == 1000, "All vault examples should be present")
    }

    @Test("Replay examples distributed throughout, not clustered")
    func replayDistribution() throws {
        let buffer = ExperienceReplayBuffer()

        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-forget-dist-vault-\(UUID().uuidString).jsonl")
        let replayURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-forget-dist-replay-\(UUID().uuidString).jsonl")
        defer {
            try? FileManager.default.removeItem(at: vaultURL)
            try? FileManager.default.removeItem(at: replayURL)
        }

        let vaultLines = (0..<100).map { "{\"messages\":[{\"role\":\"user\",\"content\":\"V\($0)\"}]}" }
        try vaultLines.joined(separator: "\n").write(to: vaultURL, atomically: true, encoding: .utf8)

        let replayLines = (0..<50).map { "{\"messages\":[{\"role\":\"user\",\"content\":\"R\($0)\"}]}" }
        try replayLines.joined(separator: "\n").write(to: replayURL, atomically: true, encoding: .utf8)

        let mixedURL = try buffer.generateMixedDataset(vaultData: vaultURL, replayBuffer: replayURL)
        defer { try? FileManager.default.removeItem(at: mixedURL) }

        let lines = try String(contentsOf: mixedURL, encoding: .utf8)
            .components(separatedBy: .newlines).filter { !$0.isEmpty }

        // Find positions of replay examples
        let replayPositions = lines.enumerated()
            .filter { $0.element.contains("\"R") }
            .map(\.offset)

        guard replayPositions.count >= 2 else { return }

        // Check that replay examples appear in both first and second half
        let midpoint = lines.count / 2
        let firstHalf = replayPositions.filter { $0 < midpoint }.count
        let secondHalf = replayPositions.filter { $0 >= midpoint }.count

        #expect(firstHalf > 0, "Should have replay examples in first half")
        #expect(secondHalf > 0, "Should have replay examples in second half")
    }

    // MARK: - Mitigation 2: Curriculum Learning

    @Test("Curriculum sorts simple content before complex")
    func curriculumOrder() throws {
        let sorter = CurriculumSorter()

        let scores = [
            ("Water is H2O.", sorter.computeComplexity("Water is H2O.")),
            ("The process involves multiple steps because each phase depends on the previous one.", sorter.computeComplexity("The process involves multiple steps because each phase depends on the previous one.")),
            ("Quantum error correction is critically important because quantum states are inherently fragile. Therefore, without correction, computations accumulate errors exponentially. Furthermore, the threshold theorem proves reliability. Consequently, this implies fault-tolerance is achievable. However, practical implementation requires enormous overhead.", sorter.computeComplexity("Quantum error correction is critically important because quantum states are inherently fragile. Therefore, without correction, computations accumulate errors exponentially. Furthermore, the threshold theorem proves reliability. Consequently, this implies fault-tolerance is achievable. However, practical implementation requires enormous overhead.")),
        ]

        // Verify ascending order
        for i in 0..<scores.count - 1 {
            #expect(scores[i].1 <= scores[i + 1].1,
                   "\"\(scores[i].0.prefix(30))...\" (score: \(scores[i].1)) should be simpler than \"\(scores[i+1].0.prefix(30))...\" (score: \(scores[i+1].1))")
        }
    }

    @Test("Sorted JSONL maintains valid format")
    func sortedJSONLValid() throws {
        let inputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-forget-sort-in-\(UUID().uuidString).jsonl")
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-forget-sort-out-\(UUID().uuidString).jsonl")
        defer {
            try? FileManager.default.removeItem(at: inputURL)
            try? FileManager.default.removeItem(at: outputURL)
        }

        let lines = [
            "{\"messages\":[{\"role\":\"assistant\",\"content\":\"Complex multi-hop reasoning because therefore consequently furthermore.\"}]}",
            "{\"messages\":[{\"role\":\"assistant\",\"content\":\"Simple fact.\"}]}",
            "{\"messages\":[{\"role\":\"assistant\",\"content\":\"Medium explanation of a concept with some detail.\"}]}",
        ]
        try lines.joined(separator: "\n").write(to: inputURL, atomically: true, encoding: .utf8)

        let sorter = CurriculumSorter()
        try sorter.sortByComplexity(inputPath: inputURL, outputPath: outputURL)

        let outputLines = try String(contentsOf: outputURL, encoding: .utf8)
            .components(separatedBy: .newlines).filter { !$0.isEmpty }

        #expect(outputLines.count == 3)

        // All lines should be valid JSON
        for line in outputLines {
            let data = line.data(using: .utf8)!
            #expect(try JSONSerialization.jsonObject(with: data) is [String: Any])
        }

        // First line should be simplest
        #expect(outputLines[0].contains("Simple fact"))
    }

    // MARK: - Mitigation 3 & 4: Config Verification

    @Test("Default training config includes all forgetting mitigations")
    func configMitigations() {
        let config = TrainingConfig.defaultKnowledge

        // Mitigation 1: Experience replay ratio is set
        #expect(config.replayRatio == 0.10, "Replay ratio should be 10%")

        // Mitigation 2: Curriculum order is ascending
        #expect(config.curriculumOrder == .ascending, "Curriculum should default to ascending (simple→complex)")

        // Mitigation 4: L2 regularization is in the Python scripts (verified in HyperparameterComplianceTests)
        // Just verify the config struct carries the information
        #expect(config.loraRank == 32)
        #expect(config.loraAlpha == 64)
    }

    @Test("Style config also includes forgetting mitigations")
    func styleConfigMitigations() {
        let config = TrainingConfig.defaultStyle

        #expect(config.replayRatio == 0.10)
        #expect(config.curriculumOrder == .ascending)
        #expect(config.loraRank == 8)
        #expect(config.loraAlpha == 16)
    }
}
