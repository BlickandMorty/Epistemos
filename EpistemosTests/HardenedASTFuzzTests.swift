import Foundation
import Testing
@testable import Epistemos

@Suite("Hardened AST Fuzz")
struct HardenedASTFuzzTests {
    private let payloads = StringFuzz.sqlInjectionPatterns() + StringFuzz.controlChars() + [
        "<script>alert(1)</script>",
        "[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]",
        String(repeating: "#", count: 10000) + " Header",
        "![exploit](javascript:alert(1))",
    ]

    @Test("markdown AST sanitization fuzz does not hard-fail", arguments: [
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
    ])
    func markdownASTSanitization(_ index: Int) throws {
        let payload = try #require(payloads[safe: index])
        let page = SDPage(title: payload, isJournal: false)

        let attempt = try? AttributedString(markdown: page.title)
        let rendered = attempt.map { String($0.characters) } ?? "failed cleanly"

        #expect(page.title == payload)
        #expect(!rendered.isEmpty)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
