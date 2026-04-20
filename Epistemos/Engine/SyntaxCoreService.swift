import Foundation
import os

/// Swift bridge to the syntax-core Rust crate for incremental tree-sitter parsing.
///
/// Owns an opaque `SyntaxDocument` pointer and provides viewport-scoped
/// token generation via the C FFI. Behind `EPISTEMOS_USE_SYNTAX_CORE` flag.
final class SyntaxCoreService: @unchecked Sendable {

    static let useSyntaxCore: Bool = {
        ProcessInfo.processInfo.environment["EPISTEMOS_USE_SYNTAX_CORE"] == "1"
    }()

    private static let log = Logger(subsystem: "com.epistemos.syntax", category: "SyntaxCoreService")

    nonisolated(unsafe) private var document: OpaquePointer?
    private let language: String
    private let docId: UInt64

    init(docId: UInt64, language: String, source: String) {
        self.docId = docId
        self.language = language

        document = language.withCString { langPtr in
            source.withCString { srcPtr in
                syntax_document_create(docId, langPtr, srcPtr, UInt32(source.utf8.count))
            }
        }

        if document == nil {
            Self.log.warning("Failed to create SyntaxDocument for language: \(language, privacy: .public)")
        }
    }

    deinit {
        if let doc = document {
            syntax_document_free(doc)
        }
    }

    var isValid: Bool { document != nil }

    var generation: UInt64 {
        guard let doc = document else { return 0 }
        return syntax_document_generation(doc)
    }

    var handle: SyntaxDocumentHandle {
        guard let doc = document else {
            return SyntaxDocumentHandle(doc_id: 0, generation: 0)
        }
        return syntax_document_handle(doc)
    }

    var stats: SyntaxSnapshotStats {
        guard let doc = document else {
            return SyntaxSnapshotStats(doc_id: 0, generation: 0, node_count: 0, error_count: 0, parse_time_us: 0)
        }
        return syntax_document_stats(doc)
    }

    /// Apply an edit delta and trigger incremental reparse.
    @discardableResult
    func edit(byteStart: UInt64, oldLen: UInt64, newText: String) -> SyntaxEditDelta {
        guard let doc = document else {
            return SyntaxEditDelta(doc_id: 0, from_generation: 0, to_generation: 0, byte_offset: 0, old_len: 0, new_len: 0)
        }
        let delta = newText.withCString { ptr in
            syntax_document_edit(doc, byteStart, oldLen, ptr, UInt32(newText.utf8.count))
        }
        return delta
    }

    /// Generate syntax tokens for the given byte range (typically the visible viewport).
    /// Returns an array of `SyntaxTokenSpan` with document-global UTF-16 offsets.
    func tokensForViewport(byteStart: UInt64, byteEnd: UInt64, maxTokens: Int = 8192) -> [SyntaxTokenSpan] {
        guard let doc = document else { return [] }

        let buffer = UnsafeMutablePointer<SyntaxTokenSpan>.allocate(capacity: maxTokens)
        defer { buffer.deallocate() }

        let count = language.withCString { langPtr in
            syntax_document_tokens_for_viewport(
                doc,
                langPtr,
                byteStart,
                byteEnd,
                buffer,
                UInt32(maxTokens)
            )
        }

        guard count > 0 else { return [] }

        var tokens: [SyntaxTokenSpan] = []
        tokens.reserveCapacity(Int(count))
        for i in 0..<Int(count) {
            tokens.append(buffer[i])
        }
        return tokens
    }
}
