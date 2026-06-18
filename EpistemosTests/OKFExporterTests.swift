import Testing
@testable import Epistemos

/// R-OKF — locks the Open Knowledge Format projection: `type` is always present
/// (the one OKF-required field), optional fields are omitted when empty, YAML
/// scalars round-trip safely, and the filename is a clean slug.
@Suite("OKF exporter")
struct OKFExporterTests {

    @Test("type is always emitted, even on a minimal note")
    func typeAlwaysPresent() {
        let md = OKFExporter.markdown(for: OKFExporter.Note(body: "hello"))
        #expect(md.hasPrefix("---\ntype: note\n---\n"))
        #expect(md.hasSuffix("\n"))
        #expect(md.contains("\nhello\n"))
    }

    @Test("empty/whitespace type falls back to 'note'")
    func emptyTypeFallsBack() {
        let md = OKFExporter.markdown(for: OKFExporter.Note(type: "   ", body: "x"))
        #expect(md.contains("type: note"))
    }

    @Test("set fields emit in order; empty optionals are omitted")
    func fieldsEmittedAndOmitted() {
        let note = OKFExporter.Note(
            type: "concept",
            title: "My Title",
            tags: ["alpha", "  ", "beta"],   // blanks dropped
            body: "Body text.",
            created: "2026-06-18T12:00:00Z",
            updated: nil                      // omitted
        )
        let md = OKFExporter.markdown(for: note)
        #expect(md.contains("type: concept"))
        #expect(md.contains("title: My Title"))
        #expect(md.contains("tags: [alpha, beta]"))
        #expect(md.contains("created: \"2026-06-18T12:00:00Z\""))  // colons → quoted
        #expect(!md.contains("updated:"))  // nil omitted
        #expect(md.contains("Body text."))
    }

    @Test("YAML-significant punctuation is double-quoted and escaped")
    func unsafeScalarsQuoted() {
        let note = OKFExporter.Note(title: "Plan: \"phase 2\", now", body: "")
        let md = OKFExporter.markdown(for: note)
        // Quoted, with the inner quotes escaped.
        #expect(md.contains("title: \"Plan: \\\"phase 2\\\", now\""))
    }

    @Test("plain-safe titles stay unquoted")
    func plainScalarsUnquoted() {
        let md = OKFExporter.markdown(for: OKFExporter.Note(title: "well-formed_title v2", body: ""))
        #expect(md.contains("title: well-formed_title v2"))
    }

    @Test("a leading YAML indicator forces quoting")
    func leadingIndicatorQuoted() {
        let md = OKFExporter.markdown(for: OKFExporter.Note(title: "- dashes lead", body: ""))
        #expect(md.contains("title: \"- dashes lead\""))
    }

    @Test("filename is a kebab slug of the title; fallback when empty")
    func fileNameSlug() {
        #expect(OKFExporter.fileName(for: OKFExporter.Note(title: "My Great Note!")) == "my-great-note.md")
        #expect(OKFExporter.fileName(for: OKFExporter.Note(title: "   ")) == "untitled.md")
        #expect(OKFExporter.fileName(for: OKFExporter.Note(title: "©™ ✦")) == "untitled.md")
    }
}
