import Foundation
import Testing

@testable import Epistemos

/// Wave 9.6 follow-up source-guard for `SyntaxCoreLiveHighlighter` —
/// the real `LiveHighlighter` impl that drives `SyntaxCoreService`
/// (tree-sitter via syntax-core's Rust FFI) under the W9.6 base
/// editor controller.
@Suite("SyntaxCoreLiveHighlighter (Wave 9.6 follow-up)")
nonisolated struct SyntaxCoreLiveHighlighterTests {

    // MARK: - Capture name → LiveHighlightKind mapping

    @Test("captureName mapping covers every emitted GENERIC_HIGHLIGHTS_QUERY name")
    func captureNameMappingExhaustive() {
        // Every name syntax-core's GENERIC_HIGHLIGHTS_QUERY can emit
        // (cross-ref syntax-core/src/highlight.rs).
        let cases: [(String, LiveHighlightKind?)] = [
            ("comment",        .comment),
            ("string",         .string),
            ("escape",         .string),
            ("number",         .number),
            ("constant",       .constant),
            ("type",           .type),
            ("variable",       .identifier),
            ("property",       .property),
            ("function.def",   .function),
            ("function.call",  .function),
            ("macro",          .macro),
            ("attribute",      .attribute),
            ("unknown",        nil),
            ("totally-bogus",  nil),
        ]
        for (name, expected) in cases {
            let actual = SyntaxCoreLiveHighlighter.liveHighlightKind(for: name)
            #expect(actual == expected,
                    "capture '\(name)' → expected \(String(describing: expected)) got \(String(describing: actual))")
        }
    }

    // MARK: - Unsupported language returns no tokens

    @Test("Languages syntax-core has no grammar for return zero tokens (markdown / yaml / toml / sql / ruby / plain)")
    func unsupportedLanguagesReturnEmpty() {
        let h = SyntaxCoreLiveHighlighter()
        for kind in [CodeArtifactKind.markdown, .yaml, .toml, .sql, .ruby, .plain] {
            let tokens = h.highlight(text: "anything at all", language: kind)
            #expect(tokens.isEmpty,
                    "\(kind) is not in syntax-core's language table; highlighter must produce no tokens")
        }
    }

    // MARK: - Real Rust source produces a recognisable token mix

    @Test("Rust source produces at least one comment + one string token (round-trip via syntax-core FFI)")
    func rustSourceProducesRecognisableTokens() {
        let h = SyntaxCoreLiveHighlighter()
        let src = """
        // top-level comment
        fn add(a: i32, b: i32) -> i32 {
            let _name = "epistemos";
            a + b
        }
        """
        let tokens = h.highlight(text: src, language: .rust)
        #expect(!tokens.isEmpty, "non-empty Rust source must produce at least one token")
        let kinds = Set(tokens.map(\.kind))
        #expect(kinds.contains(.comment), "tokens must include the leading line comment; got kinds=\(kinds)")
        #expect(kinds.contains(.string), "tokens must include the \"epistemos\" string literal; got kinds=\(kinds)")
        #expect(kinds.contains(.type), "tokens must include the i32 type identifiers; got kinds=\(kinds)")
    }

    @Test("Non-Rust languages currently return zero tokens (GENERIC_HIGHLIGHTS_QUERY is Rust-specific in syntax-core today)")
    func nonRustLanguagesReturnZeroTokensV15() {
        // Truthful source-guard: syntax-core's GENERIC_HIGHLIGHTS_QUERY
        // (cross-ref syntax-core/src/highlight.rs) uses Rust-grammar node
        // names like `(line_comment)`, `(string_literal)`,
        // `(type_identifier)`. Tree-sitter's `Query::new` returns Err
        // when those nodes don't exist in the target grammar, and
        // `tokens_for_byte_range` returns 0 silently in that case
        // (cross-ref highlight.rs L21–24).
        //
        // V2 follow-up: split into per-language query files so swift /
        // python / typescript / etc. produce semantically correct tokens.
        // This test pins the V1.5 reality so a regression that produces
        // garbage tokens for non-Rust languages is caught.
        let h = SyntaxCoreLiveHighlighter()
        let swiftSrc = "struct Greeter { let name: String = \"world\" }"
        let pySrc = "def greet():\n    return \"world\""
        let tsSrc = "const greet = (): string => \"world\";"
        for (lang, src) in [(CodeArtifactKind.swift, swiftSrc),
                            (.python, pySrc),
                            (.typescript, tsSrc)] {
            let tokens = h.highlight(text: src, language: lang)
            #expect(tokens.isEmpty,
                    "GENERIC_HIGHLIGHTS_QUERY is Rust-only today; \(lang) MUST yield zero tokens (got \(tokens.count)). If this test starts failing, syntax-core gained per-language queries — update both this test and the doc-comment on SyntaxCoreLiveHighlighter.")
        }
    }

    // MARK: - Token offsets are document-global UTF-16

    @Test("Token offsets are valid NSRange-style indices into the source UTF-16 view")
    func tokenOffsetsAreInRange() {
        let h = SyntaxCoreLiveHighlighter()
        let src = "fn main() { let s = \"abc\"; }"
        let tokens = h.highlight(text: src, language: .rust)
        #expect(!tokens.isEmpty)
        let nsLen = (src as NSString).length
        for tok in tokens {
            #expect(tok.utf16Start >= 0)
            #expect(tok.utf16Length > 0)
            #expect(tok.utf16Start + tok.utf16Length <= nsLen,
                    "token \(tok) extends past the source's UTF-16 length \(nsLen)")
        }
    }

    // MARK: - Empty source

    @Test("Empty source returns zero tokens for a supported language")
    func emptySourceReturnsEmpty() {
        let h = SyntaxCoreLiveHighlighter()
        let tokens = h.highlight(text: "", language: .rust)
        #expect(tokens.isEmpty)
    }

    // MARK: - Drop-in compatibility with LiveCodeEditorController

    @Test("LiveCodeEditorController accepts SyntaxCoreLiveHighlighter as the highlighter dependency")
    @MainActor
    func compatibleWithController() {
        let controller = LiveCodeEditorController(
            text: "fn main() {}",
            language: .rust,
            highlighter: SyntaxCoreLiveHighlighter()
        )
        // recomputeHighlights ran in init — tokens must be set (or
        // empty if the build didn't link syntax-core, which would
        // fail earlier at link time anyway).
        #expect(controller.text == "fn main() {}")
        #expect(controller.language == .rust)
    }
}
