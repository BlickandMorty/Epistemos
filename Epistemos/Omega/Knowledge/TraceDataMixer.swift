import Foundation

// MARK: - Trace Data Mixer

/// Mixes ODIA execution traces with general/reasoning/automation data
/// at the 40/20/20/20 ratio specified in TRAINING_GUIDE.md.
///
/// Output: Combined JSONL string ready for mlx-lm training.
@MainActor
final class TraceDataMixer {

    /// Mix training data at the 40/20/20/20 ratio.
    /// - Parameters:
    ///   - odiaTraces: Agent execution traces (40%)
    ///   - generalData: General language data lines (20%)
    ///   - reasoningData: Reasoning/chain-of-thought lines (20%)
    ///   - automationData: Tool calling / automation lines (20%)
    ///   - targetCount: Total number of training examples to produce
    /// - Returns: Shuffled JSONL string
    func mix(
        odiaTraces: [ODIATrace],
        generalData: [String],
        reasoningData: [String],
        automationData: [String],
        targetCount: Int
    ) -> String {
        let odiaCount = Int(Double(targetCount) * 0.40)
        let generalCount = Int(Double(targetCount) * 0.20)
        let reasoningCount = Int(Double(targetCount) * 0.20)
        let automationCount = targetCount - odiaCount - generalCount - reasoningCount

        var mixed: [String] = []

        // ODIA traces → JSONL lines
        let generator = ODIATraceGenerator()
        let odiaLines = generator.toJSONL(Array(odiaTraces.prefix(odiaCount)))
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
        mixed.append(contentsOf: sample(odiaLines, count: odiaCount))

        // Other data sources (already JSONL lines)
        mixed.append(contentsOf: sample(generalData, count: generalCount))
        mixed.append(contentsOf: sample(reasoningData, count: reasoningCount))
        mixed.append(contentsOf: sample(automationData, count: automationCount))

        // Shuffle deterministically
        var rng = SeededRNG(seed: 42)
        mixed.shuffle(using: &rng)

        return mixed.joined(separator: "\n")
    }

    /// Sample `count` items from `source`, repeating if necessary.
    private func sample(_ source: [String], count: Int) -> [String] {
        guard !source.isEmpty, count > 0 else { return [] }
        var result: [String] = []
        for i in 0..<count {
            result.append(source[i % source.count])
        }
        return result
    }
}

// MARK: - Seeded RNG for deterministic shuffling

private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
