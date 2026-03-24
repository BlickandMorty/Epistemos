import Foundation

// MARK: - Types

nonisolated struct TrainingConfig: Sendable, Codable {
    var loraRank: Int
    var loraAlpha: Int
    var learningRate: Double
    var replayRatio: Double
    var curriculumOrder: CurriculumOrder
    var targetModules: [String]

    enum CurriculumOrder: String, Codable, Sendable {
        case ascending   // simple → complex (default)
        case descending  // complex → simple
        case random      // no curriculum
    }

    /// Default knowledge config from ANCHOR 2.
    static let defaultKnowledge = TrainingConfig(
        loraRank: 32,
        loraAlpha: 64,
        learningRate: 2e-5,
        replayRatio: 0.10,
        curriculumOrder: .ascending,
        targetModules: ["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"]
    )

    /// Default style config from ANCHOR 2.
    static let defaultStyle = TrainingConfig(
        loraRank: 8,
        loraAlpha: 16,
        learningRate: 1e-5,
        replayRatio: 0.10,
        curriculumOrder: .ascending,
        targetModules: ["q_proj", "k_proj", "v_proj", "o_proj"]
    )
}

enum ExperimentDecision: String, Codable, Sendable {
    case kept
    case discarded
}

nonisolated struct ExperimentResult: Sendable, Codable, Identifiable {
    let id: UUID
    let proposedConfig: TrainingConfig
    let score: Double
    let previousBestScore: Double
    let decision: ExperimentDecision
    let checkpointPath: String?
    let timestamp: Date
    let description: String
}

// MARK: - ExperimentTracker

/// Tracks experiment history and best known configuration.
/// Adapted from Karpathy's autoresearch pattern
/// (source: /Users/jojo/Downloads/autoresearch-master).
///
/// Persistent files:
/// - experiments/experiment_log.jsonl (append-only)
/// - experiments/best_config.json (current champion)
actor ExperimentTracker {

    private let experimentsDirectory: URL
    private var bestConfig: TrainingConfig?
    private var bestScore: Double = 0

    init(experimentsDirectory: URL) {
        self.experimentsDirectory = experimentsDirectory
    }

    // MARK: - Lifecycle

    func load() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: experimentsDirectory, withIntermediateDirectories: true)

        // Load best config
        let bestPath = experimentsDirectory.appendingPathComponent("best_config.json")
        if fm.fileExists(atPath: bestPath.path) {
            let data = try Data(contentsOf: bestPath)
            let stored = try JSONDecoder().decode(StoredBest.self, from: data)
            bestConfig = stored.config
            bestScore = stored.score
        }
    }

    // MARK: - Recording

    func recordExperiment(_ result: ExperimentResult) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: experimentsDirectory, withIntermediateDirectories: true)

        // Append to log (append-only JSONL)
        let logPath = experimentsDirectory.appendingPathComponent("experiment_log.jsonl")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        let lineData = try encoder.encode(result)
        let line = String(data: lineData, encoding: .utf8)! + "\n"

        if fm.fileExists(atPath: logPath.path) {
            let handle = try FileHandle(forWritingTo: logPath)
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try line.write(to: logPath, atomically: true, encoding: .utf8)
        }

        // Update best if kept
        if result.decision == .kept {
            bestConfig = result.proposedConfig
            bestScore = result.score
            try saveBestConfig()
        }
    }

    // MARK: - Queries

    func getBestConfig() -> TrainingConfig? { bestConfig }
    func getBestScore() -> Double { bestScore }

    func getExperimentHistory(limit: Int = 50) throws -> [ExperimentResult] {
        let logPath = experimentsDirectory.appendingPathComponent("experiment_log.jsonl")
        guard FileManager.default.fileExists(atPath: logPath.path) else { return [] }

        let content = try String(contentsOf: logPath, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let results: [ExperimentResult] = lines.suffix(limit).compactMap { line in
            guard let data = line.data(using: .utf8) else { return nil }
            return try? decoder.decode(ExperimentResult.self, from: data)
        }

        return results
    }

    /// Remove checkpoints from discarded experiments to free disk space.
    func pruneDiscardedCheckpoints() throws {
        let history = try getExperimentHistory(limit: 1000)
        let fm = FileManager.default

        for experiment in history where experiment.decision == .discarded {
            if let path = experiment.checkpointPath {
                let url = URL(fileURLWithPath: path)
                if fm.fileExists(atPath: url.path) {
                    try fm.removeItem(at: url)
                }
            }
        }
    }

    // MARK: - Helpers

    private func saveBestConfig() throws {
        guard let config = bestConfig else { return }
        let stored = StoredBest(config: config, score: bestScore)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(stored)

        let path = experimentsDirectory.appendingPathComponent("best_config.json")
        try data.write(to: path, options: .atomic)
    }
}

// MARK: - Storage Types

private nonisolated struct StoredBest: Codable, Sendable {
    let config: TrainingConfig
    let score: Double
}
