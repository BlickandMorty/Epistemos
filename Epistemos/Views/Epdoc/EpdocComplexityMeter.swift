import Foundation
import SwiftUI

public struct EpdocAgentTokenEstimate: Sendable, Equatable {
    public enum Source: Sendable, Equatable {
        case markdown
        case documentStats
    }

    public let tokens: Int
    public let source: Source

    public static func estimate(
        markdown: String?,
        fallbackWordCount: Int,
        fallbackCharacterCount: Int
    ) -> EpdocAgentTokenEstimate {
        let trimmedMarkdown = markdown?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedMarkdown.isEmpty {
            return EpdocAgentTokenEstimate(
                tokens: estimatedTokens(forCharacterCount: trimmedMarkdown.count),
                source: .markdown
            )
        }

        let fallbackCharacters = max(0, fallbackCharacterCount, fallbackWordCount * 5)
        return EpdocAgentTokenEstimate(
            tokens: estimatedTokens(forCharacterCount: fallbackCharacters),
            source: .documentStats
        )
    }

    public var compactCountText: String {
        if tokens >= 1_000_000 {
            return Self.compactDecimal(Double(tokens) / 1_000_000.0, suffix: "m")
        }
        if tokens >= 1_000 {
            return Self.compactDecimal(Double(tokens) / 1_000.0, suffix: "k")
        }
        return "\(tokens)"
    }

    public var sourceDescription: String {
        switch source {
        case .markdown: return "live Markdown"
        case .documentStats: return "document stats"
        }
    }

    private static func estimatedTokens(forCharacterCount characterCount: Int) -> Int {
        guard characterCount > 0 else { return 0 }
        return max(1, Int(ceil(Double(characterCount) / 4.0)))
    }

    private static func compactDecimal(_ value: Double, suffix: String) -> String {
        let tenths = (value * 10).rounded() / 10
        if tenths.rounded(.down) == tenths {
            return "\(Int(tenths))\(suffix)"
        }
        return String(format: "%.1f%@", tenths, suffix)
    }
}

@MainActor
public struct EpdocAgentTokenCounter: View {
    public let estimate: EpdocAgentTokenEstimate
    public let label: String

    public init(
        estimate: EpdocAgentTokenEstimate,
        label: String = "Document"
    ) {
        self.estimate = estimate
        self.label = label
    }

    public var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "number.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 15, weight: .semibold))

            VStack(alignment: .leading, spacing: 0) {
                Text(estimate.compactCountText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("agent tokens")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.separator.opacity(0.45), lineWidth: 0.5))
        .help(tooltipText)
        .accessibilityLabel("\(label): about \(estimate.tokens) agent tokens")
        .accessibilityValue("Estimated from \(estimate.sourceDescription)")
    }

    private var tooltipText: String {
        "\(label): about \(estimate.tokens) agent tokens\nEstimated from \(estimate.sourceDescription)."
    }
}

#if DEBUG
#Preview("EpdocAgentTokenCounter") {
    VStack(alignment: .leading, spacing: 12) {
        EpdocAgentTokenCounter(
            estimate: .estimate(markdown: "Short document", fallbackWordCount: 0, fallbackCharacterCount: 0),
            label: "Quick note"
        )
        EpdocAgentTokenCounter(
            estimate: .estimate(markdown: nil, fallbackWordCount: 1200, fallbackCharacterCount: 0),
            label: "Research doc"
        )
    }
    .padding()
}
#endif
