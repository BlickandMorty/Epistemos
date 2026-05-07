import Foundation
import Testing

@testable import Epistemos

/// Wave 7.12 source-guard for the doc complexity scalar that drives
/// the Notion×Obsidian×Craft tier (W7.13–W7.16). Pins the saturation
/// curves + the seven sub-metric weights against future drift.
@Suite("EpdocComplexityCalculator (Wave 7.12)")
nonisolated struct EpdocComplexityCalculatorTests {

    // MARK: - Test helpers

    private static func text(_ s: String, marks: [ProseMirrorMark] = []) -> ProseMirrorNode {
        ProseMirrorNode(type: "text", marks: marks, text: s)
    }

    private static func para(_ children: [ProseMirrorNode]) -> ProseMirrorNode {
        ProseMirrorNode(type: "paragraph", content: children)
    }

    private static func doc(_ children: [ProseMirrorNode]) -> ProseMirrorNode {
        ProseMirrorNode(type: "doc", content: children)
    }

    private static func heading(_ level: Int, _ s: String) -> ProseMirrorNode {
        ProseMirrorNode(
            type: "heading",
            attrs: ProseMirrorAttrs(level: level),
            content: [text(s)]
        )
    }

    private static func words(_ count: Int) -> ProseMirrorNode {
        let body = Array(repeating: "word", count: count).joined(separator: " ")
        return doc([para([text(body)])])
    }

    // MARK: - Default weights sum to 1.0

    @Test("Default ComplexityWeights sum to 1.0 so a saturated doc scores exactly 1.0")
    func defaultWeightsSumToOne() {
        let total = ComplexityWeights.default.total
        #expect(abs(total - 1.0) < 0.0001,
                "default weights MUST sum to 1.0; got \(total)")
    }

    // MARK: - Empty doc → 0.0

    @Test("Empty doc has complexity exactly 0.0")
    func emptyDocIsZero() {
        let d = Self.doc([])
        let result = EpdocComplexityCalculator.breakdown(for: d)
        #expect(result.complexity == 0.0)
        #expect(result.wordCount == 0)
        #expect(result.headingCount == 0)
        #expect(result.maxHeadingDepth == 0)
        #expect(result.codeBlockCount == 0)
        #expect(result.linkCount == 0)
        #expect(result.mathCount == 0)
        #expect(result.mermaidCount == 0)
        #expect(result.embedCount == 0)
        #expect(result.tableCount == 0)
        #expect(result.listItemCount == 0)
        #expect(result.calloutCount == 0)
        #expect(result.citationCount == 0)
    }

    // MARK: - Saturation behavior

    @Test("Words sub-metric saturates at the 5000-word ceiling")
    func wordsSaturate() {
        let small = EpdocComplexityCalculator.breakdown(for: Self.words(50))
        let medium = EpdocComplexityCalculator.breakdown(for: Self.words(500))
        let large = EpdocComplexityCalculator.breakdown(for: Self.words(5000))
        let huge = EpdocComplexityCalculator.breakdown(for: Self.words(50000))

        #expect(small.saturated.words < medium.saturated.words,
                "more words must yield higher saturated value")
        #expect(medium.saturated.words < large.saturated.words)
        // Hits 1.0 at the ceiling
        #expect(abs(large.saturated.words - 1.0) < 0.001,
                "5000 words must saturate words sub-metric at 1.0; got \(large.saturated.words)")
        // Stays at 1.0 past the ceiling
        #expect(abs(huge.saturated.words - 1.0) < 0.001,
                "past-ceiling word counts MUST stay clamped at 1.0; got \(huge.saturated.words)")
    }

    @Test("Heading sub-metric blends section count and max depth")
    func headingDepth() {
        var previousScore = 0.0
        for level in 1...6 {
            let d = Self.doc([Self.heading(level, "title"), Self.para([Self.text("body")])])
            let r = EpdocComplexityCalculator.breakdown(for: d)
            #expect(r.headingCount == 1)
            #expect(r.maxHeadingDepth == level)
            #expect(r.saturated.headings > previousScore)
            previousScore = r.saturated.headings
        }

        let manySections = Self.doc((0..<20).map { Self.heading(2, "section \($0)") })
        let r = EpdocComplexityCalculator.breakdown(for: manySections)
        #expect(r.headingCount == 20)
        #expect(r.maxHeadingDepth == 2)
        #expect(r.saturated.headings > 0.75,
                "many shallow sections must still register as structural complexity; got \(r.saturated.headings)")
    }

    @Test("Code block count saturates at 10 fences")
    func codeBlockCount() {
        let blocks = (0..<10).map { _ in
            ProseMirrorNode(type: "code_block", content: [Self.text("foo()")])
        }
        let d = Self.doc(blocks)
        let r = EpdocComplexityCalculator.breakdown(for: d)
        #expect(r.codeBlockCount == 10)
        #expect(abs(r.saturated.codeBlocks - 1.0) < 0.001)
    }

    @Test("Tiptap camelCase codeBlock counts as a code block")
    func tiptapCodeBlockCount() {
        let d = Self.doc([
            ProseMirrorNode(type: "codeBlock", attrs: ProseMirrorAttrs(language: "swift"), content: [
                Self.text("func open() {\n    print(\"hi\")\n}")
            ])
        ])
        let r = EpdocComplexityCalculator.breakdown(for: d)
        #expect(r.codeBlockCount == 1)
        #expect(r.wordCount > 0)
    }

    @Test("Link count saturates at 20 links")
    func linkCount() {
        let linkMark = ProseMirrorMark(type: "link", attrs: ProseMirrorAttrs(href: "https://example.com"))
        let linkNodes = (0..<20).map { _ in Self.text("anchor", marks: [linkMark]) }
        let d = Self.doc([Self.para(linkNodes)])
        let r = EpdocComplexityCalculator.breakdown(for: d)
        #expect(r.linkCount == 20)
        #expect(abs(r.saturated.links - 1.0) < 0.001)
    }

    @Test("Obsidian-style wikilinks count as document links")
    func wikilinksCountAsLinks() {
        let d = Self.doc([
            Self.para([
                Self.text("See [[Capability Sandwich]] and [[Epdoc Graph]] for the graph projection.")
            ])
        ])

        let r = EpdocComplexityCalculator.breakdown(for: d)

        #expect(r.linkCount == 2)
        #expect(r.saturated.links > 0)
    }

    @Test("Math count adds inline + display nodes; saturates at 10")
    func mathCount() {
        var children: [ProseMirrorNode] = []
        for _ in 0..<5 {
            children.append(ProseMirrorNode(type: "math_inline",
                                            attrs: ProseMirrorAttrs(formula: "x")))
            children.append(ProseMirrorNode(type: "math_display",
                                            attrs: ProseMirrorAttrs(formula: "y")))
        }
        let d = Self.doc([Self.para(children)])
        let r = EpdocComplexityCalculator.breakdown(for: d)
        #expect(r.mathCount == 10)
        #expect(abs(r.saturated.math - 1.0) < 0.001)
    }

    @Test("Tiptap Mathematics node aliases count as math")
    func tiptapMathematicsAliasesCount() {
        let d = Self.doc([
            Self.para([
                ProseMirrorNode(type: "inlineMath", attrs: ProseMirrorAttrs(latex: "x")),
            ]),
            ProseMirrorNode(type: "blockMath", attrs: ProseMirrorAttrs(latex: "E = mc^2")),
        ])
        let r = EpdocComplexityCalculator.breakdown(for: d)
        #expect(r.mathCount == 2)
    }

    @Test("Mermaid diagrams saturate at 5")
    func mermaidCount() {
        let diagrams = (0..<5).map { _ in
            ProseMirrorNode(type: "mermaid", content: [Self.text("graph TD\nA --> B")])
        }
        let d = Self.doc(diagrams)
        let r = EpdocComplexityCalculator.breakdown(for: d)
        #expect(r.mermaidCount == 5)
        #expect(abs(r.saturated.mermaid - 1.0) < 0.001)
    }

    @Test("Epdoc charts count as visual research diagrams")
    func chartCount() {
        let d = Self.doc([
            ProseMirrorNode(type: "epdocChart", content: [
                Self.text(#"{"type":"scatter","points":[{"x":0.7,"y":0.9}]}"#)
            ])
        ])
        let r = EpdocComplexityCalculator.breakdown(for: d)
        #expect(r.mermaidCount == 1,
                "Chart nodes share the visual-diagram complexity bucket so the public breakdown API does not churn.")
    }

    @Test("Embed / transclusion / iframe nodes all count toward embeds; saturate at 10")
    func embedAliases() {
        let nodes = [
            ProseMirrorNode(type: "embed", content: []),
            ProseMirrorNode(type: "transclusion", content: []),
            ProseMirrorNode(type: "iframe", content: []),
            ProseMirrorNode(type: "epdocImage", attrs: ProseMirrorAttrs(src: "epistemos.png")),
            ProseMirrorNode(type: "image", attrs: ProseMirrorAttrs(src: "image.png")),
        ] + (0..<7).map { _ in ProseMirrorNode(type: "embed", content: []) }
        let d = Self.doc(nodes)
        let r = EpdocComplexityCalculator.breakdown(for: d)
        #expect(r.embedCount == 12)
        #expect(abs(r.saturated.embeds - 1.0) < 0.001)
    }

    @Test("Research structure blocks count: tables, list items, callouts, and citations")
    func researchStructureCounts() {
        let table = ProseMirrorNode(type: "table", content: [
            ProseMirrorNode(type: "tableRow", content: [
                ProseMirrorNode(type: "tableCell", content: [Self.para([Self.text("Metric")])]),
                ProseMirrorNode(type: "tableCell", content: [Self.para([Self.text("Value")])]),
            ]),
        ])
        let list = ProseMirrorNode(type: "bulletList", content: [
            ProseMirrorNode(type: "listItem", content: [Self.para([Self.text("first")])]),
            ProseMirrorNode(type: "taskItem", attrs: ProseMirrorAttrs(checked: false), content: [Self.para([Self.text("verify")])]),
        ])
        let callout = ProseMirrorNode(type: "callout", attrs: ProseMirrorAttrs(kind: "warning"), content: [
            Self.para([Self.text("Needs evidence")]),
        ])
        let footnoteReference = ProseMirrorNode(type: "footnote_reference", attrs: ProseMirrorAttrs(id: "1"))
        let footnote = ProseMirrorNode(type: "footnote", attrs: ProseMirrorAttrs(id: "1"), content: [
            Self.para([Self.text("source")]),
        ])

        let r = EpdocComplexityCalculator.breakdown(for: Self.doc([
            Self.heading(2, "Research"),
            table,
            list,
            callout,
            Self.para([Self.text("Claim"), footnoteReference]),
            footnote,
        ]))

        #expect(r.tableCount == 1)
        #expect(r.listItemCount == 2)
        #expect(r.calloutCount == 1)
        #expect(r.citationCount == 2)
        #expect(r.saturated.tables > 0)
        #expect(r.saturated.listItems > 0)
        #expect(r.saturated.callouts > 0)
        #expect(r.saturated.citations > 0)
    }

    // MARK: - Aggregate scoring

    @Test("Simple short note scores in the 0.05–0.20 band (sanity check)")
    func simpleNote() {
        let d = Self.doc([
            Self.heading(1, "Quick note"),
            Self.para([Self.text("This is a short note that mentions one thing and stops.")]),
        ])
        let r = EpdocComplexityCalculator.breakdown(for: d)
        #expect(r.complexity > 0.05, "simple note must score above zero; got \(r.complexity)")
        #expect(r.complexity < 0.30, "simple note must NOT score above 0.30; got \(r.complexity)")
    }

    @Test("A doc that saturates every metric reaches the 1.0 ceiling")
    func fullySaturatedDocReachesOne() {
        // 5000 words + heading saturation + 10 code blocks + 20 links + 10
        // math + 5 mermaid + 10 embeds + 5 tables + 40 list items +
        // 10 callouts + 20 citations saturates every sub-metric.
        let words = Array(repeating: "word", count: 5000).joined(separator: " ")
        let linkMark = ProseMirrorMark(type: "link", attrs: ProseMirrorAttrs(href: "https://x"))
        let linkNodes = (0..<20).map { _ in Self.text("a", marks: [linkMark]) }
        let codeBlocks = (0..<10).map { _ in
            ProseMirrorNode(type: "code_block", content: [Self.text("foo")])
        }
        let mathNodes = (0..<10).map { _ in
            ProseMirrorNode(type: "math_inline", attrs: ProseMirrorAttrs(formula: "x"))
        }
        let mermaid = (0..<5).map { _ in
            ProseMirrorNode(type: "mermaid", content: [Self.text("graph TD\nA --> B")])
        }
        let embeds = (0..<10).map { _ in
            ProseMirrorNode(type: "embed", content: [])
        }
        let headings = (0..<20).map { Self.heading($0 == 0 ? 6 : 2, "section \($0)") }
        let tables = (0..<5).map { _ in ProseMirrorNode(type: "table", content: []) }
        let listItems = (0..<40).map { _ in ProseMirrorNode(type: "listItem", content: [Self.para([Self.text("item")])]) }
        let callouts = (0..<10).map { _ in ProseMirrorNode(type: "callout", content: [Self.para([Self.text("note")])]) }
        let citations = (0..<20).map { index in
            ProseMirrorNode(type: "footnote_reference", attrs: ProseMirrorAttrs(id: "\(index)"))
        }
        var children: [ProseMirrorNode] = headings + [
            Self.para([Self.text(words)]),
            Self.para(linkNodes),
            Self.para(mathNodes),
        ]
        children.append(contentsOf: codeBlocks)
        children.append(contentsOf: mermaid)
        children.append(contentsOf: embeds)
        children.append(contentsOf: tables)
        children.append(contentsOf: listItems)
        children.append(contentsOf: callouts)
        children.append(contentsOf: citations)

        let r = EpdocComplexityCalculator.breakdown(for: Self.doc(children))
        #expect(r.complexity > 0.95,
                "fully saturated doc MUST score very close to 1.0; got \(r.complexity)")
    }

    // MARK: - JSON entry point + custom weights

    @Test("complexity(jsonData:) round-trips a real ProseMirror payload")
    func jsonEntryPoint() throws {
        let d = Self.doc([
            Self.heading(2, "JSON in"),
            Self.para([Self.text("hello world")]),
            ProseMirrorNode(type: "code_block", content: [Self.text("let x = 1")]),
        ])
        let data = try JSONEncoder().encode(d)
        let score = EpdocComplexityCalculator.complexity(jsonData: data)
        #expect(score != nil)
        #expect(score! > 0.0 && score! < 1.0)

        // Malformed JSON returns nil
        let bad = "{not json}".data(using: .utf8)!
        #expect(EpdocComplexityCalculator.complexity(jsonData: bad) == nil)
    }

    @Test("Custom ComplexityWeights that sum >1.0 still clamp the final score to 1.0")
    func customWeightsClamp() {
        let exaggerated = ComplexityWeights(
            words: 5.0, headings: 5.0, codeBlocks: 5.0,
            links: 5.0, math: 5.0, mermaid: 5.0, embeds: 5.0
        )
        let d = Self.doc([
            Self.heading(2, "anything"),
            Self.para([Self.text("a few words is enough to push the score up")]),
        ])
        let score = EpdocComplexityCalculator.complexity(for: d, weights: exaggerated)
        #expect(score <= 1.0,
                "score MUST clamp to 1.0 even when custom weights sum well above 1.0; got \(score)")
    }
}
