import Testing
import Foundation

@testable import Epistemos

// SS-2S (owner 2026-06-20): md images `![alt](src)` were silently DROPPED from the
// Prose/TextKit2 surface (they only rendered in Epdoc — the confusing asymmetry). A1 added
// the Rust Image token (graph-engine markdown.rs, cargo-tested); this surfaces it in Prose
// as a VISIBLE, signaled image chip (ghost the syntax, accent the alt) rather than dropping
// it — the honest caveat. The full inline-attachment render is the A2 follow-on (it needs
// offset-safe attachment insertion + async asset loading); the md text is always preserved.
@Suite("SS-2S md-image caveat in Prose")
struct SS2SImageCaveatTests {

    @Test("the image StyleKind (27) is an applied inline style, not dropped")
    func imageStyleApplied() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Notes/MarkdownContentStorage.swift")
        // Registered in inlineStyleKinds (so the span isn't filtered out)…
        #expect(src.contains("27,  // Image (SS-2S)"))
        // …and given a visible caveat treatment in applySpanStyle.
        #expect(src.contains("case 27:"))
    }
}
