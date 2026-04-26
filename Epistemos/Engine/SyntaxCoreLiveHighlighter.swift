import Foundation
import os

// MARK: - SyntaxCoreLiveHighlighter
//
// Wave 9.6 follow-up of the Extended Program Plan
// (cross-ref `epistemos_code_verdict.md` §1: live syntax highlighting
//  STAYS IN SWIFT via direct C bindings to tree-sitter).
//
// Real `LiveHighlighter` implementation that bridges `SyntaxCoreService`
// (the existing tree-sitter wrapper Wave 4.5 already ships) into the
// `LiveHighlighter` protocol the W9.6 base controller binds to.
//
// Per the canonical architectural verdict the Rust syntax-core crate
// owns the parser + ropey buffer + capture mapping, but the highlight
// query runs on the same actor as the editor view (the FFI is a one-
// shot call per recompute, NOT one call per character — so the
// UTF-16 ↔ UTF-8 cross-FFI mapping cost only hits on text changes,
// not on every keystroke for unchanged text).
//
// W9.6 base ships the `LiveHighlighter` protocol + `StubLiveHighlighter`
// (substring-based tests). This follow-up wires the real one. Drop-in:
//   let editor = LiveCodeEditorController(highlighter: SyntaxCoreLiveHighlighter())
//
// The `kind_id → LiveHighlightKind` mapping uses the new
// `syntax_document_kind_name` FFI added in this commit, so it is
// robust against the per-document `TokenRegistry`'s intern order
// (the V1.5 hardcoded knownOrder workaround in
// `SyntaxCoreCaptureNameRegistry` was fragile against sources that
// didn't trigger every capture in declaration order).
//
// V1.5 LIMITATION — the underlying `GENERIC_HIGHLIGHTS_QUERY` in
// syntax-core/src/highlight.rs uses Rust-grammar node names
// (`(line_comment)`, `(string_literal)`, `(type_identifier)` …).
// `tree_sitter::Query::new` returns Err when those nodes don't exist
// in the target grammar, and `tokens_for_byte_range` then silently
// returns 0. So today **only Rust source produces semantic tokens**;
// every other supported language (.swift, .python, .typescript, .go,
// etc.) parses successfully (the parser handle stays valid) but
// yields an empty token array. The W9.6 V2 follow-up is per-language
// .scm query files; until then this highlighter is a Rust-first
// preview surface and the editor falls back to plain rendering for
// non-Rust files.

nonisolated public final class SyntaxCoreLiveHighlighter: LiveHighlighter, @unchecked Sendable {

    private static let log = Logger(
        subsystem: "com.epistemos.syntax",
        category: "SyntaxCoreLiveHighlighter"
    )

    private static let docIdCounter = OSAllocatedUnfairLock<UInt64>(initialState: 1_000_000)

    public init() {}

    // MARK: - LiveHighlighter

    public func highlight(text: String, language: CodeArtifactKind) -> [LiveHighlightToken] {
        guard let langName = Self.syntaxCoreLanguageName(for: language) else {
            // syntax-core doesn't ship a grammar for this language —
            // return no tokens; the editor renders plain text.
            return []
        }
        let docId = Self.docIdCounter.withLock { current in
            let value = current
            current = current &+ 1
            return value
        }
        let service = SyntaxCoreService(docId: docId, language: langName, source: text)
        guard service.isValid else {
            Self.log.warning("SyntaxCoreService init failed for language=\(langName, privacy: .public)")
            return []
        }
        let utf8Len = UInt64(text.utf8.count)
        let spans = service.tokensForViewport(byteStart: 0, byteEnd: utf8Len)

        var tokens: [LiveHighlightToken] = []
        tokens.reserveCapacity(spans.count)
        for span in spans {
            let length = Int(span.utf16_len)
            guard length > 0 else { continue }
            // Resolve the per-document kind_id back to the canonical
            // tree-sitter capture name + map → LiveHighlightKind.
            let kind: LiveHighlightKind?
            if let name = service.kindName(for: span.kind_id) {
                kind = Self.liveHighlightKind(for: name)
            } else {
                kind = nil
            }
            guard let kind else { continue }
            tokens.append(LiveHighlightToken(
                utf16Start: Int(span.utf16_start),
                utf16Length: length,
                kind: kind
            ))
        }
        return tokens
    }

    // MARK: - Mappings

    /// Map `CodeArtifactKind` → the language string `language_for_name`
    /// in syntax-core/src/languages.rs accepts. Returns nil for kinds
    /// syntax-core doesn't ship a grammar for (markdown, sql, yaml,
    /// toml, ruby, plain).
    private static func syntaxCoreLanguageName(for kind: CodeArtifactKind) -> String? {
        switch kind {
        case .swift:      return "swift"
        case .rust:       return "rust"
        case .python:     return "python"
        case .javascript: return "javascript"
        case .typescript: return "typescript"
        case .json:       return "json"
        case .html:       return "html"
        case .css:        return "css"
        case .shell:      return "bash"
        case .go:         return "go"
        // syntax-core does not ship grammars for these — V2 will add
        // tree-sitter-ruby / tree-sitter-yaml / tree-sitter-toml etc.
        case .ruby, .yaml, .toml, .markdown, .sql, .plain:
            return nil
        }
    }

    /// Map a tree-sitter capture name (from syntax-core's
    /// `GENERIC_HIGHLIGHTS_QUERY`) → `LiveHighlightKind`. Returns nil
    /// for `"unknown"` (the sentinel) so unrecognised tokens render
    /// plain instead of as a highlight category.
    static func liveHighlightKind(for captureName: String) -> LiveHighlightKind? {
        switch captureName {
        case "comment":          return .comment
        case "string":           return .string
        case "escape":           return .string  // escape sequences render as part of the string
        case "number":           return .number
        case "constant":         return .constant
        case "type":             return .type
        case "variable":         return .identifier
        case "property":         return .property
        case "function.def",
             "function.call",
             "function":         return .function
        case "method":           return .method
        case "macro":            return .macro
        case "attribute":        return .attribute
        case "keyword":          return .keyword
        case "operator":         return .operator
        case "import":           return .import
        case "error":            return .error
        case "unknown":          return nil
        default:                 return nil
        }
    }
}
