import Foundation
import Testing

@testable import Epistemos

/// Tests for `ReadableBlocksProjector` — the production
/// ProseMirror → `[ReadableBlock]` projector that closes audit
/// gap F7 (per `docs/audits/T+4_T+5_DEEP_AUDIT_2026-04-27.md`).
@Suite("ReadableBlocksProjector (audit gap F7)")
nonisolated struct ReadableBlocksProjectorTests {

    private static func projectFixture(
        json: String,
        title: String = "Doc",
        artifactID: String = "doc-1"
    ) -> [ReadableBlock] {
        ReadableBlocksProjector.project(
            contentJSON: Data(json.utf8),
            artifactID: artifactID,
            artifactKind: .document,
            documentTitle: title
        )
    }

    @Test("Empty doc projects to empty list")
    func emptyDocProjectsEmpty() {
        let blocks = Self.projectFixture(json: #"{"type":"doc","content":[]}"#)
        #expect(blocks.isEmpty)
    }

    @Test("Single paragraph projects to one paragraph block")
    func singleParagraph() {
        let json = """
        {"type":"doc","content":[
          {"type":"paragraph","attrs":{"blockId":"p1"},
           "content":[{"type":"text","text":"hello world"}]}
        ]}
        """
        let blocks = Self.projectFixture(json: json)
        #expect(blocks.count == 1)
        #expect(blocks[0].blockID == "p1")
        #expect(blocks[0].body == "hello world")
        #expect(blocks[0].blockKind == .paragraph)
    }

    @Test("Heading + paragraph: paragraph's title_path includes the heading")
    func paragraphTitlePathReflectsHeading() {
        let json = """
        {"type":"doc","content":[
          {"type":"heading","attrs":{"blockId":"h1","level":1},
           "content":[{"type":"text","text":"Kant"}]},
          {"type":"paragraph","attrs":{"blockId":"p1"},
           "content":[{"type":"text","text":"categorical imperative"}]}
        ]}
        """
        let blocks = Self.projectFixture(json: json, title: "Notes")
        #expect(blocks.count == 2)
        // Heading row breadcrumb should include itself per the
        // walker's "update stack BEFORE emit" rule.
        #expect(blocks[0].titlePath == "Notes > Kant",
                "heading title_path got \(blocks[0].titlePath ?? "nil")")
        #expect(blocks[1].titlePath == "Notes > Kant",
                "paragraph below heading must inherit the breadcrumb")
    }

    @Test("Nested headings build a hierarchical breadcrumb")
    func nestedHeadingsBuildBreadcrumb() {
        let json = """
        {"type":"doc","content":[
          {"type":"heading","attrs":{"blockId":"h1","level":1},
           "content":[{"type":"text","text":"A"}]},
          {"type":"heading","attrs":{"blockId":"h2","level":2},
           "content":[{"type":"text","text":"B"}]},
          {"type":"paragraph","attrs":{"blockId":"p1"},
           "content":[{"type":"text","text":"body"}]}
        ]}
        """
        let blocks = Self.projectFixture(json: json, title: "Doc")
        #expect(blocks.count == 3)
        // Final paragraph should carry both heading levels.
        #expect(blocks[2].titlePath == "Doc > A > B",
                "got \(blocks[2].titlePath ?? "nil")")
    }

    @Test("Sibling H2 replaces the prior H2 in the breadcrumb")
    func siblingHeadingPopsPriorAtSameLevel() {
        let json = """
        {"type":"doc","content":[
          {"type":"heading","attrs":{"blockId":"h1","level":2},
           "content":[{"type":"text","text":"Section A"}]},
          {"type":"paragraph","attrs":{"blockId":"p1"},
           "content":[{"type":"text","text":"first body"}]},
          {"type":"heading","attrs":{"blockId":"h2","level":2},
           "content":[{"type":"text","text":"Section B"}]},
          {"type":"paragraph","attrs":{"blockId":"p2"},
           "content":[{"type":"text","text":"second body"}]}
        ]}
        """
        let blocks = Self.projectFixture(json: json, title: "Doc")
        let firstPara = blocks.first(where: { $0.blockID == "p1" })
        let secondPara = blocks.first(where: { $0.blockID == "p2" })
        #expect(firstPara?.titlePath == "Doc > Section A")
        #expect(secondPara?.titlePath == "Doc > Section B",
                "second H2 must REPLACE the first in the breadcrumb")
    }

    @Test("Code block projects with .code kind")
    func codeBlockKind() {
        let json = """
        {"type":"doc","content":[
          {"type":"codeBlock","attrs":{"blockId":"cb1","language":"swift"},
           "content":[{"type":"text","text":"let x = 1"}]}
        ]}
        """
        let blocks = Self.projectFixture(json: json)
        #expect(blocks.count == 1)
        #expect(blocks[0].blockKind == .code)
        #expect(blocks[0].body == "let x = 1")
    }

    @Test("Blockquote wrapper emits a quote row + flattens inner paragraphs")
    func blockquoteFlattensInner() {
        let json = """
        {"type":"doc","content":[
          {"type":"blockquote","attrs":{"blockId":"bq1"},
           "content":[
             {"type":"paragraph","attrs":{"blockId":"p1"},
              "content":[{"type":"text","text":"quoted text"}]}
           ]}
        ]}
        """
        let blocks = Self.projectFixture(json: json)
        // We expect TWO rows: the wrapper carrying its full text
        // (so a search for the quoted text matches even when the
        // FTS hit lands on the wrapper) AND the inner paragraph.
        #expect(blocks.count == 2)
        #expect(blocks.contains(where: { $0.blockKind == .quote && $0.body.contains("quoted text") }))
        #expect(blocks.contains(where: { $0.blockKind == .paragraph && $0.body == "quoted text" }))
    }

    @Test("Bullet list emits one paragraph block per item")
    func bulletListEmitsPerItem() {
        let json = """
        {"type":"doc","content":[
          {"type":"bulletList","content":[
            {"type":"listItem","content":[
              {"type":"paragraph","attrs":{"blockId":"li1"},
               "content":[{"type":"text","text":"item one"}]}
            ]},
            {"type":"listItem","content":[
              {"type":"paragraph","attrs":{"blockId":"li2"},
               "content":[{"type":"text","text":"item two"}]}
            ]}
          ]}
        ]}
        """
        let blocks = Self.projectFixture(json: json)
        // Two paragraphs (one per listItem). The bulletList
        // wrapper itself does not emit a row — list-level search
        // doesn't add value.
        #expect(blocks.count == 2)
        #expect(blocks[0].body == "item one")
        #expect(blocks[1].body == "item two")
        #expect(blocks.allSatisfy { $0.blockKind == .paragraph })
    }

    @Test("Task list with task items projects per-item")
    func taskListPerItem() {
        let json = """
        {"type":"doc","content":[
          {"type":"taskList","content":[
            {"type":"taskItem","attrs":{"checked":false},"content":[
              {"type":"paragraph","attrs":{"blockId":"t1"},
               "content":[{"type":"text","text":"todo first"}]}
            ]},
            {"type":"taskItem","attrs":{"checked":true},"content":[
              {"type":"paragraph","attrs":{"blockId":"t2"},
               "content":[{"type":"text","text":"todo second"}]}
            ]}
          ]}
        ]}
        """
        let blocks = Self.projectFixture(json: json)
        #expect(blocks.count == 2)
        #expect(blocks.first?.body == "todo first")
        #expect(blocks.last?.body == "todo second")
    }

    @Test("Table flattens to single .table row carrying concatenated cell text")
    func tableFlattensToSingleRow() {
        let json = """
        {"type":"doc","content":[
          {"type":"table","attrs":{"blockId":"tbl1"},"content":[
            {"type":"tableRow","content":[
              {"type":"tableCell","content":[
                {"type":"paragraph","content":[{"type":"text","text":"A1"}]}
              ]},
              {"type":"tableCell","content":[
                {"type":"paragraph","content":[{"type":"text","text":"B1"}]}
              ]}
            ]}
          ]}
        ]}
        """
        let blocks = Self.projectFixture(json: json)
        #expect(blocks.count == 1)
        #expect(blocks[0].blockKind == .table)
        #expect(blocks[0].body.contains("A1"))
        #expect(blocks[0].body.contains("B1"))
    }

    @Test("Empty paragraph (no text) is skipped — no row emitted")
    func emptyParagraphSkipped() {
        let json = """
        {"type":"doc","content":[
          {"type":"paragraph","attrs":{"blockId":"p1"},"content":[]},
          {"type":"paragraph","attrs":{"blockId":"p2"},
           "content":[{"type":"text","text":"only this is indexed"}]}
        ]}
        """
        let blocks = Self.projectFixture(json: json)
        #expect(blocks.count == 1, "empty paragraph must not produce a row")
        #expect(blocks[0].blockID == "p2")
    }

    @Test("Missing blockId falls back to synthetic stable id")
    func missingBlockIdFallsBackToSynthetic() {
        let json = """
        {"type":"doc","content":[
          {"type":"paragraph","content":[{"type":"text","text":"hello"}]}
        ]}
        """
        let blocks = Self.projectFixture(json: json)
        #expect(blocks.count == 1)
        #expect(blocks[0].blockID.hasPrefix("synthetic-"),
                "blockId fallback must be flagged as synthetic so callers know it's not stable across edits — got \(blocks[0].blockID)")
    }

    @Test("Malformed JSON returns empty list (defensive — autosave must not crash)")
    func malformedJSONReturnsEmpty() {
        let blocks = ReadableBlocksProjector.project(
            contentJSON: Data("not json at all".utf8),
            artifactID: "doc-bad",
            artifactKind: .document,
            documentTitle: "Doc"
        )
        #expect(blocks.isEmpty)
    }

    @Test("Marks (bold, italic, code) flatten — only plain text is indexed")
    func marksFlattenToPlainText() {
        let json = """
        {"type":"doc","content":[
          {"type":"paragraph","attrs":{"blockId":"p1"},
           "content":[
             {"type":"text","text":"hello "},
             {"type":"text","text":"bold","marks":[{"type":"bold"}]},
             {"type":"text","text":" world"}
           ]}
        ]}
        """
        let blocks = Self.projectFixture(json: json)
        #expect(blocks.count == 1)
        #expect(blocks[0].body == "hello bold world",
                "marks must flatten to plain text — got \(blocks[0].body)")
    }

    @Test("Hard break renders as space in the indexed body")
    func hardBreakBecomesSpace() {
        let json = """
        {"type":"doc","content":[
          {"type":"paragraph","attrs":{"blockId":"p1"},
           "content":[
             {"type":"text","text":"line one"},
             {"type":"hardBreak"},
             {"type":"text","text":"line two"}
           ]}
        ]}
        """
        let blocks = Self.projectFixture(json: json)
        #expect(blocks.count == 1)
        #expect(blocks[0].body == "line one line two")
    }
}
