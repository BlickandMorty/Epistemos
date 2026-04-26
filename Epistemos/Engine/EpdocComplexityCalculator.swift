import Foundation

// MARK: - EpdocComplexityCalculator
//
// Wave 7.12 of the Extended Program Plan
// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 7.12).
//
// Compute a single 0.0–1.0 *complexity scalar* per `.epdoc` package
// from its ProseMirror tree. The number gets cached in
// `manifest.metadata["complexity"]` (W7.6 substrate) on every save
// and drives:
//   - W7.14 EpdocGraphProjector — node weight in the graph engine
//   - W7.16 Metal renderer — node radius + edge thickness scale
//   - V2 sort orders — "complex docs first" / "simple notes only"
//   - V2 search ranking — bias toward simpler results when query is
//     ambiguous
//
// ## Counting heuristic
//
// Seven sub-metrics, each saturating at a per-metric ceiling. The
// final score is a *weighted sum* clamped to `[0, 1]`. Weights are
// tunable via `ComplexityWeights`.
//
//   words           log10(N+1) / log10(5001)         saturates at 5000 words
//   headings        max_heading_depth / 6            1.0 at H6
//   code_blocks     log10(N+1) / log10(11)           saturates at 10 fences
//   links           log10(N+1) / log10(21)           saturates at 20 links
//   math            log10(N+1) / log10(11)           saturates at 10 math nodes
//   mermaid         log10(N+1) / log10(6)            saturates at 5 diagrams
//   embeds          log10(N+1) / log10(11)           saturates at 10 transclusions
//
// Saturation is intentionally log-scale: the difference between 1
// and 100 words is much larger than between 10000 and 100000 words.
// A simple note (200 words, 1 heading, no code) lands around 0.15.
// A long technical doc with 50 code blocks + 20 math equations + 5
// diagrams lands at the ceiling.

nonisolated public struct ComplexityWeights: Sendable, Hashable {
    /// Weight on the `words` sub-metric. Default 0.30 — text length
    /// is the strongest single signal of "this doc is non-trivial".
    public let words: Double
    /// Weight on `headings` (max depth seen). Default 0.10.
    public let headings: Double
    /// Weight on `code_blocks` count. Default 0.15.
    public let codeBlocks: Double
    /// Weight on `links` (link marks). Default 0.10.
    public let links: Double
    /// Weight on `math` (math_inline + math_display). Default 0.15.
    public let math: Double
    /// Weight on `mermaid` diagrams. Default 0.15.
    public let mermaid: Double
    /// Weight on `embeds` (transclusion / iframe / etc.). Default 0.05.
    public let embeds: Double

    public init(
        words: Double = 0.30,
        headings: Double = 0.10,
        codeBlocks: Double = 0.15,
        links: Double = 0.10,
        math: Double = 0.15,
        mermaid: Double = 0.15,
        embeds: Double = 0.05
    ) {
        self.words = words
        self.headings = headings
        self.codeBlocks = codeBlocks
        self.links = links
        self.math = math
        self.mermaid = mermaid
        self.embeds = embeds
    }

    /// Default weights. Sum = 1.0 so a doc that saturates every
    /// sub-metric scores exactly 1.0.
    public static let `default` = ComplexityWeights()

    /// Total of every weight — useful for a sanity assertion in
    /// tests + custom weight constructors.
    public var total: Double {
        words + headings + codeBlocks + links + math + mermaid + embeds
    }
}

/// Per-metric breakdown that powers the calculator's final score.
/// Surfaced separately so the doc inspector can show a debug
/// "what makes this complex" panel.
nonisolated public struct DocComplexityBreakdown: Sendable, Hashable {
    public let wordCount: Int
    public let maxHeadingDepth: Int
    public let codeBlockCount: Int
    public let linkCount: Int
    public let mathCount: Int
    public let mermaidCount: Int
    public let embedCount: Int

    /// The final scalar in [0, 1] computed from the counts above
    /// using the active `ComplexityWeights`.
    public let complexity: Double

    /// The breakdown of each sub-metric AFTER its saturation curve is
    /// applied. Each value is in [0, 1]. Matches the 7 weight fields
    /// of `ComplexityWeights` 1:1.
    public let saturated: SaturatedSubScores

    nonisolated public struct SaturatedSubScores: Sendable, Hashable {
        public let words: Double
        public let headings: Double
        public let codeBlocks: Double
        public let links: Double
        public let math: Double
        public let mermaid: Double
        public let embeds: Double
    }
}

nonisolated public enum EpdocComplexityCalculator {

    /// Compute the complexity scalar + full breakdown for a parsed
    /// ProseMirror tree.
    public static func breakdown(
        for doc: ProseMirrorNode,
        weights: ComplexityWeights = .default
    ) -> DocComplexityBreakdown {
        var counts = Counts()
        countNodes(in: doc, into: &counts)

        let saturated = DocComplexityBreakdown.SaturatedSubScores(
            words: saturateLog(Double(counts.words), ceiling: 5000),
            headings: clampUnit(Double(counts.maxHeadingDepth) / 6.0),
            codeBlocks: saturateLog(Double(counts.codeBlocks), ceiling: 10),
            links: saturateLog(Double(counts.links), ceiling: 20),
            math: saturateLog(Double(counts.math), ceiling: 10),
            mermaid: saturateLog(Double(counts.mermaid), ceiling: 5),
            embeds: saturateLog(Double(counts.embeds), ceiling: 10)
        )
        let raw =
            saturated.words      * weights.words +
            saturated.headings   * weights.headings +
            saturated.codeBlocks * weights.codeBlocks +
            saturated.links      * weights.links +
            saturated.math       * weights.math +
            saturated.mermaid    * weights.mermaid +
            saturated.embeds     * weights.embeds
        // Clamp defensively in case a custom ComplexityWeights sums >1.
        let complexity = clampUnit(raw)
        return DocComplexityBreakdown(
            wordCount: counts.words,
            maxHeadingDepth: counts.maxHeadingDepth,
            codeBlockCount: counts.codeBlocks,
            linkCount: counts.links,
            mathCount: counts.math,
            mermaidCount: counts.mermaid,
            embedCount: counts.embeds,
            complexity: complexity,
            saturated: saturated
        )
    }

    /// Convenience: just the scalar, for callers that don't need the
    /// breakdown (e.g. the manifest.metadata writer).
    public static func complexity(
        for doc: ProseMirrorNode,
        weights: ComplexityWeights = .default
    ) -> Double {
        breakdown(for: doc, weights: weights).complexity
    }

    /// Convenience: parse JSON bytes and compute. Returns nil on
    /// JSON decode failure.
    public static func complexity(jsonData: Data, weights: ComplexityWeights = .default) -> Double? {
        let decoder = JSONDecoder()
        guard let doc = try? decoder.decode(ProseMirrorNode.self, from: jsonData) else {
            return nil
        }
        return complexity(for: doc, weights: weights)
    }

    // MARK: - Counting walker

    fileprivate struct Counts {
        var words: Int = 0
        var maxHeadingDepth: Int = 0
        var codeBlocks: Int = 0
        var links: Int = 0
        var math: Int = 0
        var mermaid: Int = 0
        var embeds: Int = 0
    }

    private static func countNodes(in node: ProseMirrorNode, into counts: inout Counts) {
        switch node.type {
        case "text":
            if let text = node.text {
                counts.words += text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
            }
            for mark in node.marks ?? [] {
                if mark.type == "link" { counts.links += 1 }
            }

        case "heading":
            if let level = node.attrs?.level {
                counts.maxHeadingDepth = max(counts.maxHeadingDepth, max(0, min(6, level)))
            }
            for child in node.content ?? [] { countNodes(in: child, into: &counts) }

        case "code_block":
            counts.codeBlocks += 1
            for child in node.content ?? [] { countNodes(in: child, into: &counts) }

        case "math_inline", "math_display":
            counts.math += 1
            for child in node.content ?? [] { countNodes(in: child, into: &counts) }

        case "mermaid":
            counts.mermaid += 1
            for child in node.content ?? [] { countNodes(in: child, into: &counts) }

        case "embed", "transclusion", "iframe":
            counts.embeds += 1
            for child in node.content ?? [] { countNodes(in: child, into: &counts) }

        default:
            for child in node.content ?? [] { countNodes(in: child, into: &counts) }
        }
    }

    // MARK: - Saturation curves

    /// `log10(value + 1) / log10(ceiling + 1)`, clamped to [0, 1].
    /// Hits 1.0 exactly when value == ceiling. Stays below 1.0 forever
    /// for value < ceiling.
    private static func saturateLog(_ value: Double, ceiling: Double) -> Double {
        guard ceiling > 0 else { return 0 }
        let v = max(0, value)
        let raw = log10(v + 1) / log10(ceiling + 1)
        return clampUnit(raw)
    }

    private static func clampUnit(_ value: Double) -> Double {
        max(0.0, min(1.0, value))
    }
}
