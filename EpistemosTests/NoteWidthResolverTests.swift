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

    @Test("presentation width stays centered and deterministic across a resize round trip")
    func presentationWidthRoundTripIsDeterministic() {
        let normalAt1200 = EditorContentWidthPolicy.horizontalInset(
            availableWidth: 1_200,
            mode: .normal
        )
        let normalAt900 = EditorContentWidthPolicy.horizontalInset(
            availableWidth: 900,
            mode: .normal
        )
        let restoredAt1200 = EditorContentWidthPolicy.horizontalInset(
            availableWidth: 1_200,
            mode: .normal
        )

        #expect(normalAt1200 == restoredAt1200)
        #expect(normalAt1200 > normalAt900)
        #expect(EditorContentWidthPolicy.readableWidth(availableWidth: 1_200, mode: .normal) == 720)
        #expect(EditorContentWidthPolicy.horizontalInset(availableWidth: 1_200, mode: .wide) == 60)
    }

    @Test("presentation width depends on geometry and mode only, never document contents")
    func presentationWidthIsContentIndependent() {
        let prose = ProseEditorRepresentable2.horizontalInset(
            for: 1_100,
            mode: .custom(px: 880)
        )
        let table = ProseEditorRepresentable2.horizontalInset(
            for: 1_100,
            mode: .custom(px: 880)
        )

        #expect(prose == table)
        #expect(prose == 110)
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

    @Test("setWidth never writes existing BOM frontmatter")
    func setWidthNeverWritesBOMFrontmatter() {
        let resolver = NoteWidthResolver(defaults: isolatedDefaults())
        let markdown = "\u{feff}---\r\ntitle: Alpha\r\n---\r\nBody\r\n"

        #expect(resolver.setWidth(.custom(px: 1_040), noteID: "note-a", markdown: markdown) == nil)
        #expect(resolver.resolve(noteID: "note-a", frontmatterValue: nil) == .custom(px: 1_040))
    }

    @Test("setWidth leaves legacy _width metadata byte-equivalent")
    func setWidthLeavesLegacyWidthMetadataUntouched() {
        let resolver = NoteWidthResolver(defaults: isolatedDefaults())
        let markdown = """
        ---
        title: Alpha
        _width: wide
        ---
        Body
        """

        #expect(resolver.setWidth(.normal, noteID: "note-a", markdown: markdown) == nil)
        #expect(markdown.contains("_width: wide\n"))
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
