import Testing
import Foundation

@testable import Epistemos

// SS-2S A.2 (owner 2026-06-21): the flag-gated TextKit2 render that DRAWS md images in the Prose
// editor (owner wants to SEE the image). The draw + geometry live in ProseInlineImageLayoutFragment
// and can't run headless, but the fragment provider's DECISION — when to return an image fragment
// vs the default — is isolated in `ProseInlineImageRender.imageURL(forParagraphText:noteDirectory:
// enabled:)`. These pin that decision: flag-off is a pure no-op (the byte-identical guarantee);
// flag-on resolves only well-formed image paragraphs; the render never mutates the md.
@Suite("SS-2S — inline image render decision")
struct SS2SInlineImageRenderTests {

    private let noteDir = URL(fileURLWithPath: "/vault/notes")

    @Test("flag OFF is a pure no-op — never returns an image URL, even for a valid image paragraph")
    func flagOffNoOp() {
        #expect(ProseInlineImageRender.imageURL(
            forParagraphText: "![cat](assets/cat.png)", noteDirectory: noteDir, enabled: false) == nil)
        #expect(ProseInlineImageRender.imageURL(
            forParagraphText: "![a](https://h/y.png)", noteDirectory: nil, enabled: false) == nil)
    }

    @Test("flag ON resolves a note-relative image paragraph to its asset URL")
    func flagOnNoteRelative() {
        #expect(ProseInlineImageRender.imageURL(
            forParagraphText: "![cat](assets/cat.png)", noteDirectory: noteDir, enabled: true)
            == noteDir.appendingPathComponent("assets/cat.png"))
    }

    @Test("flag ON resolves a remote image paragraph with no note directory")
    func flagOnRemote() {
        #expect(ProseInlineImageRender.imageURL(
            forParagraphText: "![a](https://h/y.png)", noteDirectory: nil, enabled: true)
            == URL(string: "https://h/y.png"))
    }

    @Test("flag ON returns nil for a non-image paragraph (→ the default fragment, no image)")
    func flagOnNonImage() {
        #expect(ProseInlineImageRender.imageURL(
            forParagraphText: "just some prose text", noteDirectory: noteDir, enabled: true) == nil)
        // Note-relative src with no base → nil (honest, no guessed directory).
        #expect(ProseInlineImageRender.imageURL(
            forParagraphText: "![x](assets/x.png)", noteDirectory: nil, enabled: true) == nil)
    }

    @Test("the env flag defaults OFF (owner opts in via EPISTEMOS_PROSE_INLINE_IMAGE_V0=1)")
    func envFlagDefaultsOff() {
        // The test process doesn't set the flag, so the live default must be off — this is the
        // byte-identical-editor guarantee at the env-read layer.
        if ProcessInfo.processInfo.environment["EPISTEMOS_PROSE_INLINE_IMAGE_V0"] == nil {
            #expect(ProseInlineImageRender.enabled == false)
        }
    }
}
