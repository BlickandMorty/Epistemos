import Testing
import Foundation

@testable import Epistemos

// SS-2S A.2 (owner 2026-06-21): the inline-image render's foundation — resolve `![alt](src)` to the
// asset URL the TextKit2 layout draw will load (without ever mutating the persisted md). Pure +
// exhaustive so the render builds on a verified base; composes with NoteImageProcessor.loadDisplayImage.
@Suite("SS-2S — inline image source resolver")
struct SS2SInlineImageResolverTests {

    @Test("parses src from a well-formed ![alt](src), nil otherwise")
    func parseSource() {
        #expect(ProseInlineImage.source(fromMarkdownSpan: "![cat](assets/cat.png)") == "assets/cat.png")
        #expect(ProseInlineImage.source(fromMarkdownSpan: "![](x.png)") == "x.png")
        #expect(ProseInlineImage.source(fromMarkdownSpan: "![a](https://h/y.png)") == "https://h/y.png")
        #expect(ProseInlineImage.source(fromMarkdownSpan: "not an image") == nil)
        #expect(ProseInlineImage.source(fromMarkdownSpan: "![alt]()") == nil)   // empty src
        #expect(ProseInlineImage.source(fromMarkdownSpan: "![alt](") == nil)    // unterminated
    }

    @Test("resolves remote, absolute, and note-relative srcs")
    func resolveSources() {
        #expect(ProseInlineImage.resolveURL(source: "https://h/y.png", noteDirectory: nil)
                == URL(string: "https://h/y.png"))
        #expect(ProseInlineImage.resolveURL(source: "/abs/x.png", noteDirectory: nil)
                == URL(fileURLWithPath: "/abs/x.png"))
        let noteDir = URL(fileURLWithPath: "/vault/notes")
        #expect(ProseInlineImage.resolveURL(source: "assets/x.png", noteDirectory: noteDir)
                == noteDir.appendingPathComponent("assets/x.png"))
        // Note-relative with NO note directory → nil (honest, no guessed base).
        #expect(ProseInlineImage.resolveURL(source: "assets/x.png", noteDirectory: nil) == nil)
        // Empty → nil.
        #expect(ProseInlineImage.resolveURL(source: "  ", noteDirectory: noteDir) == nil)
    }

    @Test("home-relative ~/ expands to an absolute home path")
    func resolveHome() {
        let url = ProseInlineImage.resolveURL(source: "~/Pictures/x.png", noteDirectory: nil)
        #expect(url != nil)
        #expect(url?.path.hasSuffix("/Pictures/x.png") == true)
        #expect(url?.path.hasPrefix("/") == true)
    }

    @Test("one-step parse+resolve composes correctly")
    func parseAndResolve() {
        let noteDir = URL(fileURLWithPath: "/vault/notes")
        #expect(ProseInlineImage.resolveURL(fromMarkdownSpan: "![cat](assets/cat.png)", noteDirectory: noteDir)
                == noteDir.appendingPathComponent("assets/cat.png"))
        #expect(ProseInlineImage.resolveURL(fromMarkdownSpan: "no image here", noteDirectory: noteDir) == nil)
    }
}
