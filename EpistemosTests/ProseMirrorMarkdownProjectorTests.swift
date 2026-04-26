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
}
