import AppKit
import CryptoKit
import Foundation

// MARK: - LiveCodeEditorController
//
// **SCAFFOLD ONLY (RCA13 P3-003).** This controller + the
// LiveHighlighter protocol + the two highlighter implementations
// (SwiftTreeSitterLiveHighlighter canonical, SyntaxCoreLiveHighlighter
// superseded) form a complete W9.6-base substrate, but no production
// SwiftUI view binds to LiveCodeEditorController today. The visible
// code editor (`Epistemos/Views/Notes/CodeEditorView.swift`) uses
// `CodeEditSourceEditor` with its built-in highlight path. This
// substrate is exercised only by tests + previews.
//
// When the live-editor wiring slice lands, this is the canonical
// `@MainActor @Observable` target for the SwiftUI binding. The
// W9.6 canonical highlighter (`SwiftTreeSitterLiveHighlighter`) is
// already labeled as the path to pick — see RCA13 P1-014 commit.
//
// Wave 9.6 base of the Extended Program Plan
// (cross-ref `epistemos_code_verdict.md` §1: live syntax highlighting
//  STAYS IN SWIFT via SwiftTreeSitter direct C bindings).
//
// Per the canonical architectural verdict: the live editing surface
// lives in Swift / TextKit 2 because the UTF-16 ↔ UTF-8 cross-FFI
// mapping required for Rust-driven syntax kills typing throughput on
// any non-ASCII content. SwiftTreeSitter calls Tree-sitter's C API
// directly without a UniFFI hop, so range mapping happens once,
// natively, on the same actor as the NSTextView.
//
// This controller is the @MainActor @Observable substrate the SwiftUI
// editor view binds to. It owns:
//   - The current `text` (NSAttributedString-friendly String)
//   - The `language` (CodeArtifactKind)
//   - The current `highlightTokens` (rendered by the editor view)
//   - Dirty / clean tracking against the source-of-truth file
//
// Highlight tokens come from a pluggable `LiveHighlighter` protocol so
// tests use a deterministic stub and the W9.6 follow-up swaps in the
// real SwiftTreeSitter highlighter without touching the controller.

// MARK: - Token + Range

/// One highlight token covering a UTF-16 range in the editor's text.
/// UTF-16 because that's NSString's native unit; the editor view
/// applies attributes to NSRange directly without conversion.
nonisolated public struct LiveHighlightToken: Sendable, Hashable {
    /// UTF-16 offset from the start of the document.
    public let utf16Start: Int
    /// UTF-16 length (NOT byte length).
    public let utf16Length: Int
    /// Coarse semantic kind matching `CodeSymbolKind` for cross-
    /// component consistency. Editor renderers map kind → color via
    /// the active theme.
    public let kind: LiveHighlightKind

    public init(utf16Start: Int, utf16Length: Int, kind: LiveHighlightKind) {
        self.utf16Start = utf16Start
        self.utf16Length = utf16Length
        self.kind = kind
    }

    public var nsRange: NSRange {
        NSRange(location: utf16Start, length: utf16Length)
    }
}

/// Highlight categories. Wider than `CodeSymbolKind` because the live
/// editor needs to colour comments / strings / numbers etc. in
/// addition to the symbol-graph kinds the indexer produces.
nonisolated public enum LiveHighlightKind: String, Sendable, Hashable, CaseIterable {
    case keyword
    case identifier
    case type
    case property
    case function
    case method
    case macro
    case comment
    case string
    case number
    case constant
    case `operator`
    case `import`
    case attribute
    case error
}

// MARK: - LiveHighlighter protocol

/// Pluggable highlighter the controller delegates to. Real impl
/// (W9.6 follow-up) wraps SwiftTreeSitter; tests use the stub below.
nonisolated public protocol LiveHighlighter: Sendable {
    /// Compute highlight tokens for the given text + language.
    /// Synchronous to keep the contract simple; the controller wraps
    /// the call in a Task off the main actor when the text is large.
    func highlight(text: String, language: CodeArtifactKind) -> [LiveHighlightToken]
}

/// Trivial substring-based highlighter used by tests + as the
/// default fallback before SwiftTreeSitter is wired. Marks every
/// occurrence of the language's primary keyword (e.g. "func" in
/// Swift, "fn" in Rust) as `.keyword`.
nonisolated public final class StubLiveHighlighter: LiveHighlighter, @unchecked Sendable {
    public init() {}

    public func highlight(text: String, language: CodeArtifactKind) -> [LiveHighlightToken] {
        let needles = Self.keywordNeedles(for: language)
        var tokens: [LiveHighlightToken] = []
        let nsString = text as NSString
        for needle in needles {
            var searchRange = NSRange(location: 0, length: nsString.length)
            while true {
                let found = nsString.range(of: needle, options: [], range: searchRange)
                if found.location == NSNotFound { break }
                tokens.append(LiveHighlightToken(
                    utf16Start: found.location,
                    utf16Length: found.length,
                    kind: .keyword
                ))
                let next = found.location + found.length
                searchRange = NSRange(location: next, length: nsString.length - next)
                if searchRange.length <= 0 { break }
            }
        }
        return tokens.sorted { $0.utf16Start < $1.utf16Start }
    }

    /// Tiny per-language keyword set used by the stub. Exhaustive
    /// keyword tables ship with the SwiftTreeSitter highlighter.
    private static func keywordNeedles(for language: CodeArtifactKind) -> [String] {
        switch language {
        case .swift:      return ["func", "let", "var", "import"]
        case .rust:       return ["fn", "let", "use", "impl"]
        case .typescript, .javascript: return ["function", "const", "let", "import"]
        case .python:     return ["def", "import", "class"]
        case .go:         return ["func", "import", "type"]
        case .ruby:       return ["def", "class", "require"]
        case .html:       return ["html", "body", "head"]
        case .css:        return ["color", "font", "margin"]
        case .json, .yaml, .toml, .markdown, .shell, .sql, .plain:
            return []
        }
    }
}

// MARK: - Controller

/// @MainActor @Observable controller that drives the live code editor
/// view. Pure-data + protocol-bound so unit tests cover every state
/// transition without spinning up an NSTextView.
@MainActor
@Observable
public final class LiveCodeEditorController {

    // MARK: - Public state

    /// The full editor body text. SwiftUI bindings read this directly.
    public private(set) var text: String

    /// CodeArtifactKind for the file being edited. Drives the
    /// highlighter's grammar selection.
    public private(set) var language: CodeArtifactKind

    /// Most recent highlight tokens, applied by the editor view's
    /// attribute pass. Empty until `recomputeHighlights()` runs.
    public private(set) var highlightTokens: [LiveHighlightToken] = []

    /// Whether the in-memory text has diverged from the on-disk file.
    /// SwiftUI binds to this for the unsaved-changes indicator.
    public private(set) var isDirty: Bool = false

    /// SHA-256 of the on-disk file content the controller last loaded
    /// or saved against. Used to detect external edits + decide
    /// whether `save(via:)` actually needs to write.
    public private(set) var diskContentHash: String

    // MARK: - Dependencies

    private let highlighter: any LiveHighlighter

    // MARK: - Init

    public init(
        text: String = "",
        language: CodeArtifactKind = .plain,
        highlighter: any LiveHighlighter = StubLiveHighlighter()
    ) {
        self.text = text
        self.language = language
        self.highlighter = highlighter
        self.diskContentHash = Self.sha256(of: text)
        recomputeHighlights()
    }

    // MARK: - Mutations

    /// Replace the editor body. Marks dirty + recomputes highlights
    /// when the bytes actually changed (no-op on identical text).
    public func setText(_ newText: String) {
        if newText == text { return }
        text = newText
        isDirty = (Self.sha256(of: newText) != diskContentHash)
        recomputeHighlights()
    }

    /// Switch the file's language. Recomputes highlights immediately.
    public func setLanguage(_ newLanguage: CodeArtifactKind) {
        if newLanguage == language { return }
        language = newLanguage
        recomputeHighlights()
    }

    /// Recompute highlight tokens via the bound highlighter. Called
    /// automatically on text + language changes; exposed publicly so
    /// tests + theme switches can request a refresh.
    public func recomputeHighlights() {
        highlightTokens = highlighter.highlight(text: text, language: language)
    }

    // MARK: - File integration (Wave 9.5 CodeFileService)

    /// Load the file at `fileURL` into the controller. Synchronises
    /// language + diskContentHash so subsequent setText calls
    /// correctly toggle isDirty.
    public func load(fileURL: URL, via files: CodeFileService) throws {
        let pair = try files.readCodeFile(at: fileURL)
        self.text = pair.body
        self.language = pair.sidecar?.kind ?? CodeArtifactKind.from(fileURL: fileURL)
        self.diskContentHash = Self.sha256(of: pair.body)
        self.isDirty = false
        recomputeHighlights()
    }

    /// Save the controller's text to `fileURL`. No-op when not dirty;
    /// updates diskContentHash + clears the dirty flag on success.
    public func save(
        fileURL: URL,
        via files: CodeFileService,
        provenanceOverride: CodeProvenance? = nil
    ) throws {
        if !isDirty { return }
        try files.updateCodeFile(at: fileURL, body: text, provenanceOverride: provenanceOverride)
        diskContentHash = Self.sha256(of: text)
        isDirty = false
    }

    // MARK: - Helpers

    private static func sha256(of text: String) -> String {
        // Defer to CryptoKit only when we actually have content; an
        // empty file's hash is the well-known empty digest.
        if text.isEmpty { return "" }
        return CodeArtifactSidecarHashHelper.sha256Hex(of: Data(text.utf8))
    }
}

/// Tiny shim around the same SHA-256 the CodeFileService uses for
/// content_hash, exposed here so the controller can compute the same
/// digest without depending on CodeFileService internals.
nonisolated enum CodeArtifactSidecarHashHelper {
    static func sha256Hex(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
