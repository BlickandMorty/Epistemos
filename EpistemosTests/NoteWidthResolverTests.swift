import Foundation
import Testing

@testable import Epistemos

@Suite("Note width resolver (Plan 2 L2)")
@MainActor
struct NoteWidthResolverTests {
    @Test("Width modes map to canonical CSS and frontmatter values")
    func widthModeValues() {
        #expect(NoteWidthMode.normal.cssMaxWidthValue == "720px")
        #expect(NoteWidthMode.wide.cssMaxWidthValue == "none")
        #expect(NoteWidthMode.custom(px: 960).cssMaxWidthValue == "960px")
        #expect(NoteWidthMode.custom(px: 40).cssMaxWidthValue == "560px")
        #expect(NoteWidthMode.custom(px: 4_000).frontmatterValue == "1600px")
    }

    @Test("Resolve precedence is session, then frontmatter, then settings default")
    func resolvePrecedence() {
        let defaults = isolatedDefaults()
        let resolver = NoteWidthResolver(defaults: defaults)
        resolver.setSettingsDefault(.wide)

        #expect(resolver.resolve(noteID: "note-a", frontmatterValue: nil) == .wide)
        #expect(resolver.resolve(noteID: "note-a", frontmatterValue: "normal") == .normal)
        #expect(resolver.resolve(noteID: "note-a", frontmatterValue: "940px") == .custom(px: 940))

        resolver.setSessionWidth(.custom(px: 1_120), noteID: "note-a")
        #expect(resolver.resolve(noteID: "note-a", frontmatterValue: "normal") == .custom(px: 1_120))
    }

    @Test("setWidth records session state but does not create frontmatter")
    func setWidthDoesNotCreateFrontmatter() {
        let resolver = NoteWidthResolver(defaults: isolatedDefaults())
        let markdown = "# Title\n\nBody\n"

        #expect(resolver.setWidth(.wide, noteID: "note-a", markdown: markdown) == nil)
        #expect(resolver.resolve(noteID: "note-a", frontmatterValue: nil) == .wide)
    }

    @Test("setWidth upserts _width in existing BOM frontmatter without changing line endings")
    func setWidthUpsertsWidthWithBOMAndCRLF() throws {
        let resolver = NoteWidthResolver(defaults: isolatedDefaults())
        let markdown = "\u{feff}---\r\ntitle: Alpha\r\n---\r\nBody\r\n"

        let updated = try #require(resolver.setWidth(.custom(px: 1_040), noteID: "note-a", markdown: markdown))

        #expect(updated == "\u{feff}---\r\ntitle: Alpha\r\n_width: 1040px\r\n---\r\nBody\r\n")
    }

    @Test("setWidth replaces an existing _width line instead of duplicating it")
    func setWidthReplacesExistingWidth() throws {
        let resolver = NoteWidthResolver(defaults: isolatedDefaults())
        let markdown = """
        ---
        title: Alpha
        _width: wide
        ---
        Body
        """

        let updated = try #require(resolver.setWidth(.normal, noteID: "note-a", markdown: markdown))

        #expect(updated.contains("_width: normal\n"))
        #expect(updated.components(separatedBy: "_width:").count - 1 == 1)
    }

    @Test("Frontmatter parser accepts normal, wide, px, and custom px spellings")
    func parsesFrontmatterValues() {
        #expect(NoteWidthMode(frontmatterValue: "normal") == .normal)
        #expect(NoteWidthMode(frontmatterValue: "'wide'") == .wide)
        #expect(NoteWidthMode(frontmatterValue: "960px") == .custom(px: 960))
        #expect(NoteWidthMode(frontmatterValue: "custom: 1040px") == .custom(px: 1_040))
        #expect(NoteWidthMode(frontmatterValue: "40px") == .custom(px: 560))
        #expect(NoteWidthMode(frontmatterValue: "not-a-width") == nil)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "NoteWidthResolverTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
