import Testing

@testable import Epistemos

@Suite("Epdoc source-of-truth mode")
nonisolated struct EpdocSourceOfTruthModeTests {
    @Test("default mode stays JSON-only")
    func defaultMode() {
        #expect(EpdocSourceOfTruthMode.parse(nil) == .jsonOnly)
        #expect(EpdocSourceOfTruthMode.parse("") == .jsonOnly)
        #expect(EpdocSourceOfTruthMode.parse("jsonOnly") == .jsonOnly)
    }

    @Test("dual-write spellings parse from environment value")
    func dualWriteAliases() {
        for value in ["1", "true", "yes", "dualWrite", "dual-write", "dual_write"] {
            #expect(EpdocSourceOfTruthMode.parse(value) == .dualWrite)
        }
    }

    @Test("markdown-canonical spellings parse from environment value")
    func markdownCanonicalAliases() {
        for value in ["2", "canonical", "markdownCanonical", "markdown-canonical", "markdown_canonical"] {
            #expect(EpdocSourceOfTruthMode.parse(value) == .markdownCanonical)
        }
    }

    @Test("environment initializer reads the canonical key")
    func environmentInitializer() {
        #expect(EpdocSourceOfTruthMode(environment: [
            EpdocSourceOfTruthMode.environmentKey: "dualWrite",
        ]) == .dualWrite)
    }
}
