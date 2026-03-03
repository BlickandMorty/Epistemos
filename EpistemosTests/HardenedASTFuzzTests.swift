import XCTest
@testable import Epistemos

final class HardenedASTFuzzTests: XCTestCase {
    // Paper Translation: XSS, Markdown Parser Injection, and Fuzzing
    // Validating that the Native SwiftUI/SwiftData Markdown representations do not crash or execute code under extreme AST stress.
    let payloads = StringFuzz.sqlInjectionPatterns() + StringFuzz.controlChars() + [
        "<script>alert(1)</script>",
        "[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]",
        String(repeating: "#", count: 10000) + " Header",
        "![exploit](javascript:alert(1))"
    ]

    func test_Markdown_AST_Sanitization() {
        for (idx, payload) in payloads.enumerated() {
            let page = SDPage(title: payload, isJournal: false)
            // Simulate Text(page.title) AST rendering crash test
            var attemptStr: String?
            do {
                let attr = try AttributedString(markdown: page.title)
                attemptStr = String(attr.characters)
            } catch {
                // Expected to fail on garbage, but must NEVER hard crash the app
                attemptStr = "failed cleanly"
            }
            XCTAssertNotNil(page)
            XCTAssertNotNil(attemptStr)
        }
    }
}
