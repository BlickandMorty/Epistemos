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
// Eleven sub-metrics, each saturating at a per-metric ceiling. The
// final score is a *weighted sum* clamped to `[0, 1]`. Weights are
// tunable via `ComplexityWeights`.
//
//   words           log10(N+1) / log10(5001)         saturates at 5000 words
//   headings        count + depth composite          saturates at 20 headings / H6
//   code_blocks     log10(N+1) / log10(11)           saturates at 10 fences
//   links           log10(N+1) / log10(21)           saturates at 20 links
//   math            log10(N+1) / log10(11)           saturates at 10 math nodes
//   mermaid/charts  log10(N+1) / log10(6)            saturates at 5 diagrams/charts
//   embeds          log10(N+1) / log10(11)           saturates at 10 transclusions
//   tables          log10(N+1) / log10(6)            saturates at 5 tables
//   list_items      log10(N+1) / log10(41)           saturates at 40 list/task items
//   callouts        log10(N+1) / log10(11)           saturates at 10 callouts
//   citations       log10(N+1) / log10(21)           saturates at 20 footnotes/citations
//
// Saturation is intentionally log-scale: the difference between 1
// and 100 words is much larger than between 10000 and 100000 words.
// A simple note (200 words, 1 heading, no code) lands around 0.15.
// A long technical doc with code, equations, charts, tables, citations,
// and dense structure lands near the ceiling.

nonisolated public struct ComplexityWeights: Sendable, Hashable {
    /// Weight on the `words` sub-metric. Default 0.34 — text length
    /// is the strongest single signal of "this doc is non-trivial".
    public let words: Double
    /// Weight on `headings` (count + max depth). Default 0.06.
    public let headings: Double
    /// Weight on `code_blocks` count. Default 0.10.
    public let codeBlocks: Double
    /// Weight on `links` (link marks). Default 0.06.
    public let links: Double
    /// Weight on `math` (math_inline + math_display). Default 0.09.
    public let math: Double
    /// Weight on Mermaid diagrams and first-party research charts. Default 0.11.
    public let mermaid: Double
    /// Weight on `embeds` (transclusion / iframe / etc.). Default 0.04.
    public let embeds: Double
    /// Weight on table blocks. Default 0.06.
    public let tables: Double
    /// Weight on list and task-item structure. Default 0.04.
    public let listItems: Double
    /// Weight on callout/admonition blocks. Default 0.04.
    public let callouts: Double
    /// Weight on footnotes/citations. Default 0.06.
    public let citations: Double

    public init(
        words: Double = 0.34,
        headings: Double = 0.06,
        codeBlocks: Double = 0.10,
        links: Double = 0.06,
        math: Double = 0.09,
        mermaid: Double = 0.11,
        embeds: Double = 0.04,
        tables: Double = 0.06,
        listItems: Double = 0.04,
        callouts: Double = 0.04,
        citations: Double = 0.06
    ) {
        self.words = words
        self.headings = headings
        self.codeBlocks = codeBlocks
        self.links = links
        self.math = math
        self.mermaid = mermaid
        self.embeds = embeds
        self.tables = tables
        self.listItems = listItems
        self.callouts = callouts
        self.citations = citations
    }

    /// Default weights. Sum = 1.0 so a doc that saturates every
    /// sub-metric scores exactly 1.0.
    public static let `default` = ComplexityWeights()

    /// Total of every weight — useful for a sanity assertion in
    /// tests + custom weight constructors.
    public var total: Double {
        words + headings + codeBlocks + links + math + mermaid + embeds + tables + listItems + callouts + citations
    }
}

/// Per-metric breakdown that powers the calculator's final score.
/// Surfaced separately so the doc inspector can show a debug
/// "what makes this complex" panel.
nonisolated public struct DocComplexityBreakdown: Sendable, Hashable {
    public let wordCount: Int
    public let headingCount: Int
    public let maxHeadingDepth: Int
    public let codeBlockCount: Int
    public let linkCount: Int
    public let mathCount: Int
    public let mermaidCount: Int
    public let embedCount: Int
    public let tableCount: Int
    public let listItemCount: Int
    public let calloutCount: Int
    public let citationCount: Int

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
        public let tables: Double
        public let listItems: Double
        public let callouts: Double
        public let citations: Double
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
            headings: headingSaturation(count: counts.headings, maxDepth: counts.maxHeadingDepth),
            codeBlocks: saturateLog(Double(counts.codeBlocks), ceiling: 10),
            links: saturateLog(Double(counts.links), ceiling: 20),
            math: saturateLog(Double(counts.math), ceiling: 10),
            mermaid: saturateLog(Double(counts.mermaid), ceiling: 5),
            embeds: saturateLog(Double(counts.embeds), ceiling: 10),
            tables: saturateLog(Double(counts.tables), ceiling: 5),
            listItems: saturateLog(Double(counts.listItems), ceiling: 40),
            callouts: saturateLog(Double(counts.callouts), ceiling: 10),
            citations: saturateLog(Double(counts.citations), ceiling: 20)
        )
        let raw =
            saturated.words      * weights.words +
            saturated.headings   * weights.headings +
            saturated.codeBlocks * weights.codeBlocks +
            saturated.links      * weights.links +
            saturated.math       * weights.math +
            saturated.mermaid    * weights.mermaid +
            saturated.embeds     * weights.embeds +
            saturated.tables     * weights.tables +
            saturated.listItems  * weights.listItems +
            saturated.callouts   * weights.callouts +
            saturated.citations  * weights.citations
        // Clamp defensively in case a custom ComplexityWeights sums >1.
        let complexity = clampUnit(raw)
        return DocComplexityBreakdown(
            wordCount: counts.words,
            headingCount: counts.headings,
            maxHeadingDepth: counts.maxHeadingDepth,
            codeBlockCount: counts.codeBlocks,
            linkCount: counts.links,
            mathCount: counts.math,
            mermaidCount: counts.mermaid,
            embedCount: counts.embeds,
            tableCount: counts.tables,
            listItemCount: counts.listItems,
            calloutCount: counts.callouts,
            citationCount: counts.citations,
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
        var headings: Int = 0
        var maxHeadingDepth: Int = 0
        var codeBlocks: Int = 0
        var links: Int = 0
        var math: Int = 0
        var mermaid: Int = 0
        var embeds: Int = 0
        var tables: Int = 0
        var listItems: Int = 0
        var callouts: Int = 0
        var citations: Int = 0
    }

    private static func countNodes(in node: ProseMirrorNode, into counts: inout Counts) {
        switch node.type {
        case "text":
            if let text = node.text {
                counts.words += wordCount(in: text)
            }
            for mark in node.marks ?? [] {
                if mark.type == "link" { counts.links += 1 }
            }
            counts.links += EpdocGraphProjector.wikilinkLabels(in: node).count

        case "heading":
            counts.headings += 1
            if let level = node.attrs?.level {
                counts.maxHeadingDepth = max(counts.maxHeadingDepth, max(0, min(6, level)))
            }
            for child in node.content ?? [] { countNodes(in: child, into: &counts) }

        case "code_block", "codeBlock":
            counts.codeBlocks += 1
            for child in node.content ?? [] { countNodes(in: child, into: &counts) }

        case "math_inline", "math_display", "inlineMath", "blockMath":
            counts.math += 1
            for child in node.content ?? [] { countNodes(in: child, into: &counts) }

        case "mermaid", "epdocChart":
            counts.mermaid += 1
            for child in node.content ?? [] { countNodes(in: child, into: &counts) }

        case "embed", "transclusion", "iframe", "epdocImage", "image":
            counts.embeds += 1
            for child in node.content ?? [] { countNodes(in: child, into: &counts) }

        case "table":
            counts.tables += 1
            for child in node.content ?? [] { countNodes(in: child, into: &counts) }

        case "list_item", "listItem", "taskItem", "task_item":
            counts.listItems += 1
            for child in node.content ?? [] { countNodes(in: child, into: &counts) }

        case "callout", "epdocCallout":
            counts.callouts += 1
            for child in node.content ?? [] { countNodes(in: child, into: &counts) }

        case "footnote_reference", "footnoteReference", "footnote", "citation":
            counts.citations += 1
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

    private static func headingSaturation(count: Int, maxDepth: Int) -> Double {
        let countScore = saturateLog(Double(count), ceiling: 20)
        let depthScore = clampUnit(Double(maxDepth) / 6.0)
        return clampUnit(countScore * 0.65 + depthScore * 0.35)
    }

    private static func wordCount(in text: String) -> Int {
        var count = 0
        var insideWord = false
        for scalar in text.unicodeScalars {
            let isWordScalar = CharacterSet.alphanumerics.contains(scalar)
            if isWordScalar {
                if !insideWord {
                    count += 1
                    insideWord = true
                }
            } else {
                insideWord = false
            }
        }
        return count
    }

    private static func clampUnit(_ value: Double) -> Double {
        max(0.0, min(1.0, value))
    }
}
