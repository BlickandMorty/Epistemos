import Foundation

// MARK: - ExperienceReplayBuffer

/// Manages a fixed-capacity buffer of general-purpose conversation examples
/// for experience replay during fine-tuning.
///
/// Per ANCHOR 4, Mitigation 1 (MSSR algorithm):
/// - Buffer capacity: 500 examples
/// - During every training run, interleave 10% of buffer examples into the
///   personal vault training data
/// - Buffer must be general (not domain-specific)
nonisolated struct ExperienceReplayBuffer: Sendable {

    let bufferCapacity: Int
    let defaultReplayRatio: Double

    init(bufferCapacity: Int = 500, defaultReplayRatio: Double = 0.10) {
        self.bufferCapacity = bufferCapacity
        self.defaultReplayRatio = defaultReplayRatio
    }

    // MARK: - Public

    /// Generates a mixed dataset by interleaving replay examples throughout
    /// the vault training data. Returns path to the mixed JSONL file.
    ///
    /// - Parameters:
    ///   - vaultData: Path to the vault training JSONL
    ///   - replayBuffer: Path to the experience replay JSONL
    ///   - ratio: Fraction of final dataset that should be replay (default 0.10)
    /// - Returns: URL to temporary mixed JSONL file
    func generateMixedDataset(
        vaultData: URL,
        replayBuffer: URL,
        ratio: Double? = nil
    ) throws -> URL {
        let mixRatio = ratio ?? defaultReplayRatio

        // Read vault data
        let vaultLines = try readJSONLLines(from: vaultData)
        guard !vaultLines.isEmpty else {
            throw ReplayBufferError.emptyVaultData
        }

        // Read replay buffer
        let replayLines = try readJSONLLines(from: replayBuffer)
        guard !replayLines.isEmpty else {
            throw ReplayBufferError.emptyReplayBuffer
        }

        // Calculate how many replay examples to include
        // If vault has N examples and ratio is R, we need R/(1-R)*N replay examples
        let replayCount = Int(ceil(Double(vaultLines.count) * mixRatio / (1.0 - mixRatio)))
        let sampledReplay = sampleWithReplacement(from: replayLines, count: replayCount)

        // Interleave replay examples throughout vault data (not appended at end)
        let mixed = interleave(primary: vaultLines, secondary: sampledReplay)

        // Write to temp file
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf_mixed_\(UUID().uuidString).jsonl")
        let content = mixed.joined(separator: "\n")
        try content.write(to: outputURL, atomically: true, encoding: .utf8)

        return outputURL
    }

    /// Creates a minimal replay buffer JSONL from a set of general-purpose
    /// conversation examples. Used for initial setup.
    func createReplayBuffer(from examples: [ReplayExample], outputPath: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let capped = Array(examples.prefix(bufferCapacity))
        let lines = try capped.map { example -> String in
            let line = ReplayJSONL(messages: [
                .init(role: "system", content: "You are a helpful assistant."),
                .init(role: "user", content: example.prompt),
                .init(role: "assistant", content: example.response),
            ])
            let data = try encoder.encode(line)
            return try FoundationSafety.utf8String(from: data)
        }

        try FileManager.default.createDirectory(
            at: outputPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try lines.joined(separator: "\n").write(to: outputPath, atomically: true, encoding: .utf8)
    }

    // MARK: - Helpers

    private func readJSONLLines(from url: URL) throws -> [String] {
        let content = try String(contentsOf: url, encoding: .utf8)
        return content.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    private func sampleWithReplacement(from lines: [String], count: Int) -> [String] {
        guard !lines.isEmpty else { return [] }
        var sampled: [String] = []
        sampled.reserveCapacity(count)
        for _ in 0..<count {
            let index = Int.random(in: 0..<lines.count)
            sampled.append(lines[index])
        }
        return sampled
    }

    /// Interleaves secondary lines evenly throughout primary lines.
    /// Distributes secondary examples at regular intervals, not appended at end.
    private func interleave(primary: [String], secondary: [String]) -> [String] {
        guard !secondary.isEmpty else { return primary }
        guard !primary.isEmpty else { return secondary }

        var result: [String] = []
        result.reserveCapacity(primary.count + secondary.count)

        let interval = max(1, primary.count / secondary.count)
        var secondaryIdx = 0

        for (i, line) in primary.enumerated() {
            result.append(line)
            if (i + 1) % interval == 0 && secondaryIdx < secondary.count {
                result.append(secondary[secondaryIdx])
                secondaryIdx += 1
            }
        }

        // Append any remaining secondary examples
        while secondaryIdx < secondary.count {
            result.append(secondary[secondaryIdx])
            secondaryIdx += 1
        }

        return result
    }
}

// MARK: - Types

struct ReplayExample: Sendable {
    let prompt: String
    let response: String
}

private nonisolated struct ReplayJSONL: Codable, Sendable {
    let messages: [Message]
    nonisolated struct Message: Codable, Sendable {
        let role: String
        let content: String
    }
}

enum ReplayBufferError: Error, LocalizedError {
    case emptyVaultData
    case emptyReplayBuffer

    var errorDescription: String? {
        switch self {
        case .emptyVaultData: return "Vault training data is empty"
        case .emptyReplayBuffer: return "Experience replay buffer is empty"
        }
    }
}
