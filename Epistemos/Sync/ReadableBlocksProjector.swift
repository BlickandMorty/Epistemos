import Foundation

// MARK: - ReadableBlocksProjector
//
// T+4 audit gap F7 close-out (per
// `docs/audits/T+4_T+5_DEEP_AUDIT_2026-04-27.md`).
//
// Pure-function projection of a ProseMirror JSON document into a
// flat `[ReadableBlock]` list ready for the universal block-level
// FTS5 index (`Epistemos/Sync/ReadableBlocksIndex.swift`).
//
// Walks the ProseMirror node tree and emits one row per leaf
// content block. Nested wrappers (`blockquote`, `callout`,
// `bulletList`, `orderedList`, `taskList`, `listItem`) flatten —
// their inner paragraphs/headings/etc. are emitted with the
// wrapper's `block_kind` carrying the parent context. This
// matches what a typical FTS query expects: search hits land on
// the smallest meaningful unit, not on the wrapping container.
//
// Title-path breadcrumb is recomputed as the walker descends:
// the nearest preceding heading at each level becomes part of
// `title_path`. So a paragraph inside `H1 "Kant" → H2
// "Critique"` reports `"Kant > Critique"`. The breadcrumb is
// recorded to disk so search results can show context without
// reading the full document body.
//
// Performance: O(N) over ProseMirror nodes. For 100 KB documents
// (~10K nodes) this finishes in single-digit ms on M-series.
// Caller responsible for debouncing how often projection runs
// (see `EpdocEditorSavePipeline` 300 ms quiet window for the
// canonical save path).
//
// What this projector does NOT do (deliberate scope cuts):
// - Embedding generation (handled separately by epistemos-shadow)
// - Block-ID stability across edits (Tiptap's UniqueID extension
//   handles that on the JS side; we just read whatever ID the
//   document carries)
// - Markdown round-trip (use `ProseMirrorMarkdownProjector` for
//   `shadow.md` regeneration on save; that's audit gap F6)

/// Pure-function projector. The Swift namespace mirrors the
/// (currently-test-only) helper in `EpdocEndToEndSmokeTests`;
/// production callers use this class.
nonisolated public enum ReadableBlocksProjector {

    /// Project a Tiptap/ProseMirror JSON document into the flat
    /// list of `ReadableBlock` rows for FTS5 indexing. Returns an
    /// empty list when the input cannot be parsed (defensive —
    /// the autosave pipeline must not crash on malformed input).
    public static func project(
        contentJSON: Data,
        artifactID: String,
        artifactKind: ArtifactKind,
        documentTitle: String,
        updatedAt: Date = Date()
    ) -> [ReadableBlock] {
        guard
            let root = try? JSONSerialization.jsonObject(with: contentJSON)
                as? [String: Any],
            let topLevel = root["content"] as? [[String: Any]]
        else {
            return []
        }
        let timestamp = ReadableBlock.iso8601(updatedAt)
        var output: [ReadableBlock] = []
        var headingStack: [HeadingFrame] = []
        for node in topLevel {
            walk(
                node: node,
                artifactID: artifactID,
                artifactKind: artifactKind,
                documentTitle: documentTitle,
                updatedAt: timestamp,
                headingStack: &headingStack,
                output: &output
            )
        }
        return output
    }

    /// Encode projected blocks as the package-level
    /// `projections/search_blocks.jsonl` file. This is a derived
    /// projection, not a source of truth; callers regenerate it from
    /// canonical ProseMirror JSON on every save.
    public static func encodeSearchBlocksJSONL(_ blocks: [ReadableBlock]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        var data = Data()
        for block in blocks {
            let line = SearchBlockJSONLine(block: block)
            data.append(try encoder.encode(line))
            data.append(0x0A)
        }
        return data
    }

    /// Build the package-level `projections/plain.txt` body from the
    /// same projection rows. This gives agents and fallback search a
    /// cheap readable surface without parsing the canonical JSON.
    public static func plainText(from blocks: [ReadableBlock]) -> Data {
        let text = blocks.map(\.body).joined(separator: "\n\n")
        return Data(text.utf8)
    }

    // MARK: Internal walker

    private struct SearchBlockJSONLine: Encodable {
        let artifactID: String
        let artifactKind: String
        let blockID: String
        let blockKind: String
        let titlePath: String?
        let body: String
        let updatedAt: String
        let vaultID: String?

        init(block: ReadableBlock) {
            self.artifactID = block.artifactID
            self.artifactKind = block.artifactKind.snakeCaseString
            self.blockID = block.blockID
            self.blockKind = block.blockKind.rawValue
            self.titlePath = block.titlePath
            self.body = block.body
            self.updatedAt = block.updatedAt
            self.vaultID = block.vaultID
        }

        enum CodingKeys: String, CodingKey {
            case artifactID = "artifact_id"
            case artifactKind = "artifact_kind"
            case blockID = "block_id"
            case blockKind = "block_kind"
            case titlePath = "title_path"
            case body
            case updatedAt = "updated_at"
            case vaultID = "vault_id"
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(artifactID, forKey: .artifactID)
            try container.encode(artifactKind, forKey: .artifactKind)
            try container.encode(blockID, forKey: .blockID)
            try container.encode(blockKind, forKey: .blockKind)
            try container.encodeIfPresent(titlePath, forKey: .titlePath)
            try container.encode(body, forKey: .body)
            try container.encode(updatedAt, forKey: .updatedAt)
            try container.encodeIfPresent(vaultID, forKey: .vaultID)
        }
    }

    /// One entry on the heading stack — tracks the most recent
    /// heading seen at each level so the breadcrumb path stays
    /// accurate as the walker descends.
    private struct HeadingFrame {
        let level: Int
        let text: String
    }

    private static func walk(
        node: [String: Any],
        artifactID: String,
        artifactKind: ArtifactKind,
        documentTitle: String,
        updatedAt: String,
        headingStack: inout [HeadingFrame],
        output: inout [ReadableBlock]
    ) {
        guard let type = node["type"] as? String else { return }

        // Update the breadcrumb stack BEFORE emitting the row so
        // a heading sees itself at the end of its own crumb.
        if type == "heading" {
            let level = (node["attrs"] as? [String: Any])?["level"] as? Int ?? 1
            // Drop sibling/deeper frames so the heading stack is
            // monotonically increasing in level.
            while let top = headingStack.last, top.level >= level {
                headingStack.removeLast()
            }
            let body = collectText(from: node)
            headingStack.append(HeadingFrame(level: level, text: body))
        }

        switch type {
        case "doc":
            // The root carrier — recurse into its content.
            guard let inner = node["content"] as? [[String: Any]] else { return }
            for child in inner {
                walk(
                    node: child,
                    artifactID: artifactID,
                    artifactKind: artifactKind,
                    documentTitle: documentTitle,
                    updatedAt: updatedAt,
                    headingStack: &headingStack,
                    output: &output
                )
            }

        case "paragraph", "heading", "codeBlock", "code_block":
            // Leaf-content blocks — emit one row.
            emit(
                node: node,
                explicitKind: kindFor(type: type, node: node),
                artifactID: artifactID,
                artifactKind: artifactKind,
                documentTitle: documentTitle,
                updatedAt: updatedAt,
                headingStack: headingStack,
                output: &output
            )

        case "blockquote", "callout":
            // Wrappers — emit any direct text content as a single
            // block carrying the wrapper's kind, then recurse for
            // nested blocks (which usually means inner paragraphs
            // get emitted as their own paragraph rows AND we get
            // a wrapper-text row above them).
            emit(
                node: node,
                explicitKind: type == "callout" ? .callout : .quote,
                artifactID: artifactID,
                artifactKind: artifactKind,
                documentTitle: documentTitle,
                updatedAt: updatedAt,
                headingStack: headingStack,
                output: &output
            )
            if let inner = node["content"] as? [[String: Any]] {
                for child in inner {
                    walk(
                        node: child,
                        artifactID: artifactID,
                        artifactKind: artifactKind,
                        documentTitle: documentTitle,
                        updatedAt: updatedAt,
                        headingStack: &headingStack,
                        output: &output
                    )
                }
            }

        case "bulletList", "orderedList", "taskList",
             "bullet_list", "ordered_list", "task_list":
            // List wrappers — recurse only; the `listItem`
            // children carry the searchable text.
            if let inner = node["content"] as? [[String: Any]] {
                for child in inner {
                    walk(
                        node: child,
                        artifactID: artifactID,
                        artifactKind: artifactKind,
                        documentTitle: documentTitle,
                        updatedAt: updatedAt,
                        headingStack: &headingStack,
                        output: &output
                    )
                }
            }

        case "listItem", "list_item", "taskItem", "task_item":
            // List items wrap one or more block children (usually
            // a paragraph). Recurse so the inner content is
            // indexed under its own block_kind. We don't emit a
            // separate row for the listItem itself because the
            // inner paragraph already carries the text; doing so
            // would double-index every list line.
            if let inner = node["content"] as? [[String: Any]] {
                for child in inner {
                    walk(
                        node: child,
                        artifactID: artifactID,
                        artifactKind: artifactKind,
                        documentTitle: documentTitle,
                        updatedAt: updatedAt,
                        headingStack: &headingStack,
                        output: &output
                    )
                }
            }

        case "table":
            // Tables flatten to a single .table row carrying all
            // cell text concatenated. Per-cell granularity is a
            // future T+8/T+13 enhancement; today the FTS hit on
            // a table just opens the document.
            emit(
                node: node,
                explicitKind: .table,
                artifactID: artifactID,
                artifactKind: artifactKind,
                documentTitle: documentTitle,
                updatedAt: updatedAt,
                headingStack: headingStack,
                output: &output
            )

        default:
            // Unknown block type — emit as a paragraph if it
            // carries text content, otherwise skip. Forward-
            // compat with new ProseMirror node kinds.
            let text = collectText(from: node)
            if !text.isEmpty {
                emit(
                    node: node,
                    explicitKind: .paragraph,
                    artifactID: artifactID,
                    artifactKind: artifactKind,
                    documentTitle: documentTitle,
                    updatedAt: updatedAt,
                    headingStack: headingStack,
                    output: &output
                )
            }
        }
    }

    /// Map a ProseMirror node type string to the canonical
    /// `ReadableBlockKind`. Unknown / leaf types fall back to
    /// `.paragraph`.
    private static func kindFor(
        type: String,
        node: [String: Any]
    ) -> ReadableBlockKind {
        switch type {
        case "paragraph":             return .paragraph
        case "heading":               return .heading
        case "codeBlock", "code_block": return .code
        case "table":                 return .table
        case "callout":               return .callout
        case "blockquote":            return .quote
        default:                      return .paragraph
        }
    }

    private static func emit(
        node: [String: Any],
        explicitKind: ReadableBlockKind,
        artifactID: String,
        artifactKind: ArtifactKind,
        documentTitle: String,
        updatedAt: String,
        headingStack: [HeadingFrame],
        output: inout [ReadableBlock]
    ) {
        let attrs = node["attrs"] as? [String: Any] ?? [:]
        // Block ID is whatever the Tiptap UniqueID extension wrote
        // onto the node attrs. Fall back to a synthetic id so the
        // FTS row at least has a key — when the host wires Tiptap
        // UniqueID this fallback never fires.
        let blockId =
            (attrs["blockId"] as? String)
            ?? (attrs["id"] as? String)
            ?? "synthetic-\(output.count)"

        let body = collectText(from: node).trimmingCharacters(in: .whitespacesAndNewlines)
        // Empty leaf-content blocks (paragraphs the user hasn't
        // typed into yet) are not worth indexing.
        if body.isEmpty { return }

        output.append(
            ReadableBlock(
                artifactID: artifactID,
                artifactKind: artifactKind,
                blockID: blockId,
                blockKind: explicitKind,
                titlePath: titlePath(
                    documentTitle: documentTitle,
                    headingStack: headingStack
                ),
                body: body,
                updatedAt: updatedAt
            )
        )
    }

    /// Build the breadcrumb path: `"DocTitle > Heading 1 > Heading 2"`
    /// up to (but not including) the deepest heading already on
    /// the stack — that's the heading the row IS, not above it.
    private static func titlePath(
        documentTitle: String,
        headingStack: [HeadingFrame]
    ) -> String? {
        let crumbs = headingStack.map(\.text)
        let title = documentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts: [String] = {
            if title.isEmpty { return crumbs }
            return [title] + crumbs
        }()
        if parts.isEmpty { return nil }
        return parts.joined(separator: " > ")
    }

    /// Walk a ProseMirror node, concatenating every `text` leaf
    /// into a single string. Marks (bold/italic/code/etc.) are
    /// stripped — the FTS index sees plain prose. Soft breaks
    /// (`hardBreak` nodes) become spaces; deeper structure (e.g.
    /// nested bold inside a paragraph) is flattened.
    private static func collectText(from node: [String: Any]) -> String {
        var buffer = ""
        collect(node: node, into: &buffer)
        return buffer
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private static func collect(
        node: [String: Any],
        into buffer: inout String
    ) {
        if let text = node["text"] as? String {
            buffer.append(text)
            return
        }
        if let type = node["type"] as? String {
            switch type {
            case "hardBreak", "hard_break":
                buffer.append(" ")
                return
            default:
                break
            }
        }
        guard let inner = node["content"] as? [[String: Any]] else { return }
        for child in inner {
            collect(node: child, into: &buffer)
            // Inter-node separator — keeps adjacent paragraphs
            // from running together at concat time.
            if !buffer.isEmpty && !buffer.hasSuffix(" ") {
                buffer.append(" ")
            }
        }
    }
}
