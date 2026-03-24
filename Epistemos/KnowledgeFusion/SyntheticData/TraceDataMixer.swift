import Foundation

// MARK: - Trace Data Mixer

/// Mixes ODIA agent traces with existing training data at configurable ratios.
/// Implements the 40/20/20/20 composition from the Google Deep Research paper:
/// - 40% synthetic tool-call examples (ODIA traces)
/// - 20% general language & code
/// - 20% multi-step reasoning traces
/// - 20% macOS-specific automation
@MainActor
final class TraceDataMixer {

    struct MixConfig {
        var toolCallRatio: Double = 0.40
        var generalRatio: Double = 0.20
        var reasoningRatio: Double = 0.20
        var automationRatio: Double = 0.20
    }

    /// Mix ODIA traces with existing training data categories.
    /// Returns a combined JSONL string with the target ratio.
    func mix(
        odiaTraces: [ODIATrace],
        generalData: [String],
        reasoningData: [String],
        automationData: [String],
        config: MixConfig = MixConfig(),
        targetCount: Int = 1000
    ) -> String {
        let toolCount = Int(Double(targetCount) * config.toolCallRatio)
        let generalCount = Int(Double(targetCount) * config.generalRatio)
        let reasoningCount = Int(Double(targetCount) * config.reasoningRatio)
        let automationCount = Int(Double(targetCount) * config.automationRatio)

        var lines: [String] = []

        // Sample ODIA traces (with replacement if needed)
        let odiaLines = odiaTraces.compactMap { trace -> String? in
            guard let data = try? JSONEncoder().encode(trace),
                  let line = String(data: data, encoding: .utf8) else { return nil }
            return line
        }
        lines.append(contentsOf: sample(from: odiaLines, count: toolCount))

        // Sample from other categories
        lines.append(contentsOf: sample(from: generalData, count: generalCount))
        lines.append(contentsOf: sample(from: reasoningData, count: reasoningCount))
        lines.append(contentsOf: sample(from: automationData, count: automationCount))

        // Shuffle for training diversity
        lines.shuffle()

        return lines.joined(separator: "\n")
    }

    /// Sample `count` items from an array, with replacement if array is smaller.
    private func sample(from items: [String], count: Int) -> [String] {
        guard !items.isEmpty else { return [] }
        if items.count >= count {
            return Array(items.shuffled().prefix(count))
        }
        // Sample with replacement
        return (0..<count).map { _ in items.randomElement()! }
    }
}
