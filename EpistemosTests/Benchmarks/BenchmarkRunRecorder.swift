import Foundation

nonisolated enum BenchmarkRunRecorderError: Error, Equatable {
    case emptySamples
    case nonFiniteSample(Double)
}

nonisolated struct BenchmarkRunReport: Codable {
    let schema_version: Int
    let generated_at: String
    let suite: String
    let measurement: String
    let unit: String
    let sample_count: Int
    let min: Double
    let max: Double
    let p50: Double
    let p95: Double
    let p99: Double
    let samples: [Double]
    let metadata: [String: String]
}

nonisolated enum BenchmarkRunRecorder {
    static func record(
        suite: String,
        measurement: String,
        unit: String,
        samples rawSamples: [Double],
        metadata: [String: String] = [:],
        generatedAt: Date = Date(),
        resultsDirectory overrideResultsDirectory: URL? = nil
    ) throws -> URL {
        guard !rawSamples.isEmpty else {
            throw BenchmarkRunRecorderError.emptySamples
        }

        for sample in rawSamples where !sample.isFinite {
            throw BenchmarkRunRecorderError.nonFiniteSample(sample)
        }

        let samples = rawSamples.sorted()
        let generatedAtString = makeISO8601Formatter().string(from: generatedAt)
        let report = BenchmarkRunReport(
            schema_version: 1,
            generated_at: generatedAtString,
            suite: suite,
            measurement: measurement,
            unit: unit,
            sample_count: samples.count,
            min: samples[0],
            max: samples[samples.count - 1],
            p50: percentile(samples, 50),
            p95: percentile(samples, 95),
            p99: percentile(samples, 99),
            samples: samples,
            metadata: metadata
        )

        let resultsDirectory = overrideResultsDirectory ?? repoRoot()
            .appendingPathComponent("benchmarks", isDirectory: true)
            .appendingPathComponent("results", isDirectory: true)
        try FileManager.default.createDirectory(at: resultsDirectory, withIntermediateDirectories: true)

        let filename = [
            sanitizeForFilename(generatedAtString),
            sanitizeForFilename(suite),
            sanitizeForFilename(measurement),
        ].joined(separator: "-") + ".json"

        let outputURL = resultsDirectory.appendingPathComponent(filename, isDirectory: false)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(report)
        try data.write(to: outputURL, options: [.atomic])
        return outputURL
    }

    private static func makeISO8601Formatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static func percentile(_ sortedSamples: [Double], _ percentile: Double) -> Double {
        guard sortedSamples.count > 1 else {
            return sortedSamples[0]
        }

        let rank = (percentile / 100) * Double(sortedSamples.count - 1)
        let lowerIndex = Int(rank.rounded(.down))
        let upperIndex = Int(rank.rounded(.up))
        if lowerIndex == upperIndex {
            return sortedSamples[lowerIndex]
        }

        let weight = rank - Double(lowerIndex)
        return sortedSamples[lowerIndex] * (1 - weight) + sortedSamples[upperIndex] * weight
    }

    private static func sanitizeForFilename(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let collapsed = String(scalars)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return collapsed.isEmpty ? "benchmark" : collapsed.lowercased()
    }
}
