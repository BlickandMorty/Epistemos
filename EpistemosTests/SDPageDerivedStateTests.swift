import Testing
@testable import Epistemos

@Suite("SDPage Derived State")
struct SDPageDerivedStateTests {
    @Test("interactive derived state clears inline storage and stale block refs when note has no block links")
    func interactiveDerivedStateClearsInlineStorageAndStaleRefs() {
        let page = SDPage(title: "Derived State")
        page.body = "legacy inline body"
        page.blockReferences = ["stale-ref"]

        page.applyInteractiveDerivedState(from: "# Heading\n\nPlain body text with no links")

        #expect(page.body.isEmpty)
        #expect(page.blockReferences.isEmpty)
    }

    @Test("interactive block reference extraction trims whitespace and ignores broken closers")
    func interactiveBlockReferenceExtractionTrimsWhitespaceAndIgnoresBrokenClosers() {
        let refs = SDPage.extractBlockReferences(
            from: """
            Intro (( alpha-ref )).
            Broken ((missing-close) text should be ignored.
            Unicode (( cafe-\u{301} )) and ((beta-ref)).
            """
        )

        #expect(refs == ["alpha-ref", "cafe-\u{301}", "beta-ref"])
    }
}
