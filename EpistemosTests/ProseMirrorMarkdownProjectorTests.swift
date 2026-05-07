import Foundation
import Testing

@testable import Epistemos

/// Wave 7.3 source-guard for the ProseMirror → GFM Markdown projector
/// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 7.3,
///  cross-ref `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §4).
///
/// The projector is intentionally lossy — covers the GFM-shaped subset
/// of ProseMirror nodes (paragraph, heading, lists, blockquote,
/// code_block, hr, hard_break) + the four canonical inline marks
/// (strong, em, code, link). Unknown nodes/marks pass through as
/// best-effort plain text.
@Suite("ProseMirror Markdown projector (Wave 7.3)")
nonisolated struct ProseMirrorMarkdownProjectorTests {

    private static func text(_ s: String, marks: [ProseMirrorMark] = []) -> ProseMirrorNode {
        ProseMirrorNode(type: "text", marks: marks, text: s)
    }

    private static func para(_ children: [ProseMirrorNode]) -> ProseMirrorNode {
        ProseMirrorNode(type: "paragraph", content: children)
    }

    private static func doc(_ children: [ProseMirrorNode]) -> ProseMirrorNode {
        ProseMirrorNode(type: "doc", content: children)
    }

    // MARK: - basic blocks

    @Test("paragraph emits text + trailing blank line")
    func paragraphBasic() {
        let d = Self.doc([Self.para([Self.text("hello")])])
        #expect(ProseMirrorMarkdownProjector.project(d) == "hello\n")
    }

    @Test("heading emits hash prefix per level")
    func headingLevels() {
        for level in 1...6 {
            let d = Self.doc([
                ProseMirrorNode(
                    type: "heading",
                    attrs: ProseMirrorAttrs(level: level),
                    content: [Self.text("title")]
                )
            ])
            let prefix = String(repeating: "#", count: level)
            #expect(ProseMirrorMarkdownProjector.project(d) == "\(prefix) title\n",
                    "heading level \(level) must emit `\(prefix) title`")
        }
    }

    @Test("heading clamps level to 1...6")
    func headingClampsLevel() {
        let high = Self.doc([
            ProseMirrorNode(
                type: "heading",
                attrs: ProseMirrorAttrs(level: 99),
                content: [Self.text("title")]
            )
        ])
        let low = Self.doc([
            ProseMirrorNode(
                type: "heading",
                attrs: ProseMirrorAttrs(level: 0),
                content: [Self.text("title")]
            )
        ])
        #expect(ProseMirrorMarkdownProjector.project(high).hasPrefix("######"))
        #expect(ProseMirrorMarkdownProjector.project(low).hasPrefix("#"))
    }

    @Test("hard_break emits two-space line wrap")
    func hardBreakEmitsTwoSpaces() {
        let d = Self.doc([
            Self.para([
                Self.text("a"),
                ProseMirrorNode(type: "hard_break"),
                Self.text("b"),
            ])
        ])
        #expect(ProseMirrorMarkdownProjector.project(d) == "a  \nb\n")
    }

    @Test("horizontal_rule emits ---")
    func horizontalRule() {
        let d = Self.doc([
            ProseMirrorNode(type: "horizontal_rule")
        ])
        #expect(ProseMirrorMarkdownProjector.project(d).contains("---"))
    }

    // MARK: - inline marks

    @Test("strong mark wraps text in **")
    func strongMark() {
        let d = Self.doc([
            Self.para([
                Self.text("hello", marks: [ProseMirrorMark(type: "strong")])
            ])
        ])
        #expect(ProseMirrorMarkdownProjector.project(d) == "**hello**\n")
    }

    @Test("em mark wraps text in *")
    func emMark() {
        let d = Self.doc([
            Self.para([
                Self.text("hello", marks: [ProseMirrorMark(type: "em")])
            ])
        ])
        #expect(ProseMirrorMarkdownProjector.project(d) == "*hello*\n")
    }

    @Test("code mark wraps text in backticks")
    func codeMark() {
        let d = Self.doc([
            Self.para([
                Self.text("foo()", marks: [ProseMirrorMark(type: "code")])
            ])
        ])
        #expect(ProseMirrorMarkdownProjector.project(d) == "`foo()`\n")
    }

    @Test("link mark emits [text](href)")
    func linkMark() {
        let d = Self.doc([
            Self.para([
                Self.text("kant", marks: [
                    ProseMirrorMark(type: "link", attrs: ProseMirrorAttrs(href: "https://example.com/k"))
                ])
            ])
        ])
        #expect(ProseMirrorMarkdownProjector.project(d) == "[kant](https://example.com/k)\n")
    }

    @Test("link without href passes through as plain text")
    func linkWithoutHref() {
        let d = Self.doc([
            Self.para([
                Self.text("plain", marks: [ProseMirrorMark(type: "link")])
            ])
        ])
        #expect(ProseMirrorMarkdownProjector.project(d) == "plain\n",
                "link mark with no href is malformed; projector emits plain text and moves on (lossy by design)")
    }

    @Test("strong + em wrap in canonical priority order")
    func combinedMarksOrder() {
        let d = Self.doc([
            Self.para([
                Self.text("x", marks: [
                    ProseMirrorMark(type: "strong"),
                    ProseMirrorMark(type: "em"),
                ])
            ])
        ])
        // em wraps innermost, then strong → ***x*** in the GFM dialect.
        // Our priority puts em first (priority list: link > code > em > strong),
        // so em wraps innermost and strong wraps outermost.
        let out = ProseMirrorMarkdownProjector.project(d)
        #expect(out.contains("***x***") || out.contains("***x***"),
                "combined em + strong must produce nested wrapping; got: \(out)")
    }

    // MARK: - lists

    @Test("bullet list emits - prefix per item")
    func bulletList() {
        let d = Self.doc([
            ProseMirrorNode(type: "bullet_list", content: [
                ProseMirrorNode(type: "list_item", content: [
                    Self.para([Self.text("a")])
                ]),
                ProseMirrorNode(type: "list_item", content: [
                    Self.para([Self.text("b")])
                ]),
            ])
        ])
        let out = ProseMirrorMarkdownProjector.project(d)
        #expect(out.contains("- a"), "bullet list must emit `- a`; got: \(out)")
        #expect(out.contains("- b"), "bullet list must emit `- b`; got: \(out)")
    }

    @Test("ordered list emits 1. 2. ...")
    func orderedList() {
        let d = Self.doc([
            ProseMirrorNode(type: "ordered_list", content: [
                ProseMirrorNode(type: "list_item", content: [
                    Self.para([Self.text("first")])
                ]),
                ProseMirrorNode(type: "list_item", content: [
                    Self.para([Self.text("second")])
                ]),
            ])
        ])
        let out = ProseMirrorMarkdownProjector.project(d)
        #expect(out.contains("1. first"), "got: \(out)")
        #expect(out.contains("2. second"), "got: \(out)")
    }

    // MARK: - blockquote

    @Test("blockquote prefixes every line with '> '")
    func blockquote() {
        let d = Self.doc([
            ProseMirrorNode(type: "blockquote", content: [
                Self.para([Self.text("first line")]),
                Self.para([Self.text("second line")]),
            ])
        ])
        let out = ProseMirrorMarkdownProjector.project(d)
        #expect(out.contains("> first line"), "got: \(out)")
        #expect(out.contains("> second line"), "got: \(out)")
    }

    // MARK: - code block

    @Test("code_block emits triple-backtick fence with language hint")
    func codeBlockWithLanguage() {
        let d = Self.doc([
            ProseMirrorNode(
                type: "code_block",
                attrs: ProseMirrorAttrs(language: "swift"),
                content: [Self.text("let x = 1")]
            )
        ])
        let out = ProseMirrorMarkdownProjector.project(d)
        #expect(out.contains("```swift"), "got: \(out)")
        #expect(out.contains("let x = 1"), "got: \(out)")
        #expect(out.hasSuffix("```\n"), "fenced code block must end with ```; got: \(out)")
    }

    @Test("Tiptap codeBlock emits triple-backtick fence with language hint")
    func tiptapCodeBlockWithLanguage() {
        let d = Self.doc([
            ProseMirrorNode(
                type: "codeBlock",
                attrs: ProseMirrorAttrs(language: "swift"),
                content: [Self.text("let x = 1\nprint(x)")]
            )
        ])
        let out = ProseMirrorMarkdownProjector.project(d)
        #expect(out.contains("```swift"), "got: \(out)")
        #expect(out.contains("let x = 1\nprint(x)"), "got: \(out)")
        #expect(out.hasSuffix("```\n"), "fenced code block must end with ```; got: \(out)")
    }

    @Test("code_block without language emits empty-language fence")
    func codeBlockNoLanguage() {
        let d = Self.doc([
            ProseMirrorNode(type: "code_block", content: [Self.text("plain")])
        ])
        let out = ProseMirrorMarkdownProjector.project(d)
        #expect(out.hasPrefix("```\nplain"), "got: \(out)")
    }

    // MARK: - JSON entry point

    @Test("project(jsonData:) decodes + projects in one call")
    func jsonDataEntryPoint() {
        let json = #"""
        {"type":"doc","content":[
          {"type":"paragraph","content":[{"type":"text","text":"hi"}]}
        ]}
        """#
        let data = json.data(using: .utf8)!
        let result = ProseMirrorMarkdownProjector.project(jsonData: data)
        #expect(result == "hi\n", "project(jsonData:) must decode + project; got: \(String(describing: result))")
    }

    @Test("project(jsonData:) returns nil on malformed JSON")
    func jsonDataReturnsNilOnMalformed() {
        let data = "not json at all".data(using: .utf8)!
        let result = ProseMirrorMarkdownProjector.project(jsonData: data)
        #expect(result == nil, "malformed JSON must return nil so callers can fall back")
    }

    // MARK: - unknown node fallback

    @Test("unknown node types fall back to inline text without panic")
    func unknownNodeFallback() {
        let d = Self.doc([
            ProseMirrorNode(type: "experimental_widget", content: [Self.text("data")])
        ])
        let out = ProseMirrorMarkdownProjector.project(d)
        #expect(out.contains("data"),
                "unknown node types must emit their text content (lossy by design)")
    }

    // MARK: - W7.7 — Math (KaTeX)

    @Test("math_inline emits $formula$ from attrs.formula")
    func mathInlineFromAttrs() {
        let d = Self.doc([Self.para([
            Self.text("Pythagoras: "),
            ProseMirrorNode(type: "math_inline", attrs: ProseMirrorAttrs(formula: "a^2 + b^2 = c^2")),
            Self.text("."),
        ])])
        let out = ProseMirrorMarkdownProjector.project(d)
        #expect(out.contains("$a^2 + b^2 = c^2$"),
                "math_inline MUST wrap the formula in single dollar signs; got: \(out)")
    }

    @Test("math_inline falls back to child text when attrs.formula is missing")
    func mathInlineFromTextFallback() {
        let d = Self.doc([Self.para([
            ProseMirrorNode(type: "math_inline", content: [Self.text("x = 1")]),
        ])])
        let out = ProseMirrorMarkdownProjector.project(d)
        #expect(out.contains("$x = 1$"))
    }

    @Test("math_display emits $$ … $$ as a standalone block")
    func mathDisplayBlock() {
        let d = Self.doc([
            ProseMirrorNode(
                type: "math_display",
                attrs: ProseMirrorAttrs(formula: "\\int_0^1 x^2\\,dx = \\tfrac{1}{3}")
            )
        ])
        let out = ProseMirrorMarkdownProjector.project(d)
        #expect(out.contains("$$\n\\int_0^1 x^2\\,dx = \\tfrac{1}{3}\n$$"),
                "math_display MUST be wrapped in $$ on its own lines; got: \(out)")
    }

    @Test("Tiptap Mathematics aliases project to markdown math")
    func tiptapMathematicsAliases() {
        let d = Self.doc([
            Self.para([
                Self.text("Energy: "),
                ProseMirrorNode(type: "inlineMath", attrs: ProseMirrorAttrs(latex: "E = mc^2")),
            ]),
            ProseMirrorNode(type: "blockMath", attrs: ProseMirrorAttrs(latex: "\\sum x_i")),
        ])
        let out = ProseMirrorMarkdownProjector.project(d)
        #expect(out.contains("$E = mc^2$"), "inlineMath MUST project like math_inline; got: \(out)")
        #expect(out.contains("$$\n\\sum x_i\n$$"), "blockMath MUST project like math_display; got: \(out)")
    }

    // MARK: - W7.8 — markdown plugin nodes

    @Test("highlight mark wraps text in ==…==")
    func highlightMark() {
        let d = Self.doc([Self.para([
            Self.text("ordinary "),
            Self.text("important", marks: [ProseMirrorMark(type: "highlight")]),
            Self.text(" rest"),
        ])])
        let out = ProseMirrorMarkdownProjector.project(d)
        #expect(out.contains("==important=="),
                "highlight mark MUST wrap in == per markdown-it-mark; got: \(out)")
    }

    @Test("task_list emits - [ ] / - [x] markers per task_item.attrs.checked")
    func taskListMarkers() {
        let d = Self.doc([
            ProseMirrorNode(type: "task_list", content: [
                ProseMirrorNode(
                    type: "task_item",
                    attrs: ProseMirrorAttrs(checked: false),
                    content: [Self.para([Self.text("write spec")])]
                ),
                ProseMirrorNode(
                    type: "task_item",
                    attrs: ProseMirrorAttrs(checked: true),
                    content: [Self.para([Self.text("ship spec")])]
                ),
            ])
        ])
        let out = ProseMirrorMarkdownProjector.project(d)
        #expect(out.contains("- [ ] write spec"), "got: \(out)")
        #expect(out.contains("- [x] ship spec"), "got: \(out)")
    }

    @Test("callout emits :::kind / body / ::: fence (markdown-it-container syntax)")
    func calloutFence() {
        let d = Self.doc([
            ProseMirrorNode(
                type: "callout",
                attrs: ProseMirrorAttrs(kind: "warning"),
                content: [Self.para([Self.text("be careful here")])]
            )
        ])
        let out = ProseMirrorMarkdownProjector.project(d)
        #expect(out.contains(":::warning"), "callout MUST open with :::<kind>; got: \(out)")
        #expect(out.contains("be careful here"), "callout body must be present; got: \(out)")
        #expect(out.hasSuffix(":::\n") || out.contains(":::\n\n"), "callout MUST close with `:::`; got: \(out)")
    }

    @Test("callout defaults missing kind to 'info' so the fence is never bare `:::`")
    func calloutDefaultKind() {
        let d = Self.doc([
            ProseMirrorNode(
                type: "callout",
                content: [Self.para([Self.text("note")])]
            )
        ])
        let out = ProseMirrorMarkdownProjector.project(d)
        #expect(out.contains(":::info"), "missing kind MUST fall back to :::info; got: \(out)")
    }

    @Test("footnote_reference emits [^id] inline + footnote node renders def at end of doc")
    func footnoteReferenceAndDef() {
        let d = Self.doc([
            Self.para([
                Self.text("First "),
                ProseMirrorNode(type: "footnote_reference", attrs: ProseMirrorAttrs(id: "1")),
                Self.text("."),
            ]),
            // The footnote definition node lives somewhere in the doc;
            // the projector collects + emits it at the end.
            ProseMirrorNode(
                type: "footnote",
                attrs: ProseMirrorAttrs(id: "1"),
                content: [Self.para([Self.text("the definition body")])]
            ),
            Self.para([Self.text("after")]),
        ])
        let out = ProseMirrorMarkdownProjector.project(d)
        #expect(out.contains("First [^1]."), "inline footnote ref MUST be [^id]; got: \(out)")
        #expect(out.contains("[^1]: the definition body"),
                "footnote definition MUST render as `[^id]: body` at end of doc; got: \(out)")

        // The definition must NOT appear inline at its declaration position
        // — verify by confirming the def follows the body paragraphs.
        if let defRange = out.range(of: "[^1]:"),
           let bodyRange = out.range(of: "after") {
            #expect(defRange.lowerBound > bodyRange.lowerBound,
                    "footnote definition MUST appear AFTER the body; got: \(out)")
        } else {
            #expect(Bool(false), "expected both `[^1]:` and `after` in output; got: \(out)")
        }
    }

    @Test("multiple footnote definitions render in declaration order")
    func multipleFootnotes() {
        let d = Self.doc([
            Self.para([Self.text("ref a"), ProseMirrorNode(type: "footnote_reference", attrs: ProseMirrorAttrs(id: "a"))]),
            ProseMirrorNode(type: "footnote", attrs: ProseMirrorAttrs(id: "a"), content: [Self.para([Self.text("first")])]),
            Self.para([Self.text("ref b"), ProseMirrorNode(type: "footnote_reference", attrs: ProseMirrorAttrs(id: "b"))]),
            ProseMirrorNode(type: "footnote", attrs: ProseMirrorAttrs(id: "b"), content: [Self.para([Self.text("second")])]),
        ])
        let out = ProseMirrorMarkdownProjector.project(d)
        guard let firstIdx = out.range(of: "[^a]: first")?.lowerBound,
              let secondIdx = out.range(of: "[^b]: second")?.lowerBound else {
            #expect(Bool(false), "both definitions must render; got: \(out)")
            return
        }
        #expect(firstIdx < secondIdx, "footnote definitions MUST render in declaration order; got: \(out)")
    }

    // MARK: - W7.9 — Mermaid

    @Test("mermaid node emits ```mermaid fence so any markdown reader shows source")
    func mermaidFence() {
        let d = Self.doc([
            ProseMirrorNode(
                type: "mermaid",
                content: [Self.text("graph TD\nA --> B")]
            )
        ])
        let out = ProseMirrorMarkdownProjector.project(d)
        #expect(out.contains("```mermaid"), "mermaid MUST open with ```mermaid; got: \(out)")
        #expect(out.contains("graph TD"), "mermaid body must be present; got: \(out)")
        #expect(out.hasSuffix("```\n"), "mermaid MUST close with ```; got: \(out)")
    }

    @Test("Epdoc chart node emits ```epdoc-chart fence with JSON source")
    func epdocChartFence() {
        let chartJSON = #"{"type":"scatter","points":[{"x":0.7,"y":0.9}]}"#
        let d = Self.doc([
            ProseMirrorNode(
                type: "epdocChart",
                content: [Self.text(chartJSON)]
            )
        ])
        let out = ProseMirrorMarkdownProjector.project(d)
        #expect(out.contains("```epdoc-chart"), "chart MUST open with ```epdoc-chart; got: \(out)")
        #expect(out.contains(#""type":"scatter""#), "chart JSON body must be present; got: \(out)")
        #expect(out.hasSuffix("```\n"), "chart MUST close with ```; got: \(out)")
    }

    @Test("Epdoc image nodes project to markdown images")
    func epdocImageProjection() {
        let d = Self.doc([
            ProseMirrorNode(
                type: "epdocImage",
                attrs: ProseMirrorAttrs(src: "epistemos.png", alt: "Epistemos")
            )
        ])
        let out = ProseMirrorMarkdownProjector.project(d)
        #expect(out.contains("![Epistemos](epistemos.png)"), "epdocImage MUST project as markdown image; got: \(out)")
    }
}
