import Foundation

// MARK: - ProseMirrorMarkdownProjector
//
// Wave 7.3 of the Extended Program Plan
// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 7.3,
//  cross-ref `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §4).
//
// Lossy GFM Markdown projector for ProseMirror JSON documents. The
// `.epdoc` package format keeps `content.pm.json` as the canonical
// source of truth and stores `projections/shadow.md` as a derived
// view. This module computes that derived view.
//
// Design rules from the plan §4:
//   - Markdown is DERIVED, never canonical. The projector regenerates
//     `shadow.md` on every save from the live ProseMirror JSON.
//   - External `shadow.md` edits do NOT silently overwrite canonical.
//     They are imported as a reviewable conversion / new version
//     (out of scope for this projector — handled by the editor).
//   - Lossy by design. Block IDs, custom marks, embedded extensions
//     don't survive the round-trip. Only the visual GFM shape is
//     preserved.
//
// Coverage in this base wave:
//   Node types:  doc, paragraph, heading (h1-h6), bullet_list,
//                ordered_list, list_item, blockquote, code_block,
//                horizontal_rule, hard_break, text
//   Mark types:  strong (**), em (*), code (`), link ([]())
//
// Anything else passes through as the node's `text` (or empty) — the
// shadow.md is intentionally lossy. Round-trip Markdown→ProseMirror is
// NOT in scope here (handled by Tiptap's importer in Wave 7.2).

/// One node in the ProseMirror JSON tree.
nonisolated public struct ProseMirrorNode: Codable, Sendable, Hashable {
    public let type: String
    public let attrs: ProseMirrorAttrs?
    public let content: [ProseMirrorNode]?
    public let marks: [ProseMirrorMark]?
    public let text: String?

    public init(
        type: String,
        attrs: ProseMirrorAttrs? = nil,
        content: [ProseMirrorNode]? = nil,
        marks: [ProseMirrorMark]? = nil,
        text: String? = nil
    ) {
        self.type = type
        self.attrs = attrs
        self.content = content
        self.marks = marks
        self.text = text
    }
}

/// One mark applied to a text node in ProseMirror JSON. Marks are how
/// ProseMirror represents inline formatting (bold / italic / link / etc.).
nonisolated public struct ProseMirrorMark: Codable, Sendable, Hashable {
    public let type: String
    public let attrs: ProseMirrorAttrs?

    public init(type: String, attrs: ProseMirrorAttrs? = nil) {
        self.type = type
        self.attrs = attrs
    }
}

/// Heterogeneous attribute bag — ProseMirror uses arbitrary JSON values.
/// We capture only the keys we actually project (level for headings,
/// href for links, language for code blocks).
nonisolated public struct ProseMirrorAttrs: Codable, Sendable, Hashable {
    public let level: Int?
    public let href: String?
    public let language: String?
    public let title: String?

    public init(
        level: Int? = nil,
        href: String? = nil,
        language: String? = nil,
        title: String? = nil
    ) {
        self.level = level
        self.href = href
        self.language = language
        self.title = title
    }
}

/// Project a ProseMirror JSON document into GFM Markdown text.
///
/// Per the plan §4: this is intentionally LOSSY. The intent is a
/// human-readable + grep-able `shadow.md` for FTS5 indexing + plain-
/// text export. Round-trip back to ProseMirror is NOT guaranteed.
nonisolated public enum ProseMirrorMarkdownProjector {

    /// Project a parsed ProseMirror tree to GFM Markdown.
    public static func project(_ doc: ProseMirrorNode) -> String {
        var out = ""
        visit(doc, into: &out, listDepth: 0)
        // Trim a trailing extra newline that block visitors emit
        // for paragraph separation.
        while out.hasSuffix("\n\n") {
            out.removeLast()
        }
        if !out.hasSuffix("\n") && !out.isEmpty {
            out.append("\n")
        }
        return out
    }

    /// Convenience: parse JSON bytes and project in one call. Returns
    /// `nil` on JSON decode failure (callers should fall back to the
    /// previous shadow.md or skip the save with a warning).
    public static func project(jsonData: Data) -> String? {
        let decoder = JSONDecoder()
        guard let doc = try? decoder.decode(ProseMirrorNode.self, from: jsonData) else {
            return nil
        }
        return project(doc)
    }

    // MARK: - Visitor

    private static func visit(_ node: ProseMirrorNode, into out: inout String, listDepth: Int) {
        switch node.type {
        case "doc":
            visitChildren(node, into: &out, listDepth: listDepth)

        case "paragraph":
            visitChildren(node, into: &out, listDepth: listDepth)
            out.append("\n\n")

        case "heading":
            let level = max(1, min(6, node.attrs?.level ?? 1))
            out.append(String(repeating: "#", count: level))
            out.append(" ")
            visitChildren(node, into: &out, listDepth: listDepth)
            out.append("\n\n")

        case "bullet_list":
            visitListChildren(node, into: &out, listDepth: listDepth, ordered: false)
            if listDepth == 0 {
                out.append("\n")
            }

        case "ordered_list":
            visitListChildren(node, into: &out, listDepth: listDepth, ordered: true)
            if listDepth == 0 {
                out.append("\n")
            }

        case "list_item":
            // Caller (visitListChildren) already prefixed bullet/number.
            visitChildren(node, into: &out, listDepth: listDepth)

        case "blockquote":
            // Project children into a buffer, then prefix every line.
            var inner = ""
            visitChildren(node, into: &inner, listDepth: listDepth)
            for line in inner.split(separator: "\n", omittingEmptySubsequences: false) {
                out.append("> ")
                out.append(String(line))
                out.append("\n")
            }
            out.append("\n")

        case "code_block":
            let lang = node.attrs?.language ?? ""
            out.append("```\(lang)\n")
            for child in node.content ?? [] {
                if let t = child.text { out.append(t) }
            }
            out.append("\n```\n\n")

        case "horizontal_rule":
            out.append("---\n\n")

        case "hard_break":
            out.append("  \n")

        case "text":
            let body = node.text ?? ""
            out.append(applyMarks(to: body, marks: node.marks ?? []))

        default:
            // Unknown node — emit raw text content if any, then recurse.
            if let t = node.text {
                out.append(t)
            }
            visitChildren(node, into: &out, listDepth: listDepth)
        }
    }

    private static func visitChildren(_ node: ProseMirrorNode, into out: inout String, listDepth: Int) {
        for child in node.content ?? [] {
            visit(child, into: &out, listDepth: listDepth)
        }
    }

    private static func visitListChildren(_ node: ProseMirrorNode, into out: inout String, listDepth: Int, ordered: Bool) {
        let children = node.content ?? []
        let indent = String(repeating: "  ", count: listDepth)
        for (idx, item) in children.enumerated() {
            // For each list_item, render its inline content + nested lists.
            // Compute its marker and render the item body.
            let marker = ordered ? "\(idx + 1). " : "- "

            // Visit the item's children separately so we can prefix the
            // first paragraph with the marker and indent the rest.
            var itemBuf = ""
            visit(item, into: &itemBuf, listDepth: listDepth + 1)

            // Strip a trailing single newline that paragraph appends.
            while itemBuf.hasSuffix("\n\n") {
                itemBuf.removeLast()
            }

            let lines = itemBuf.split(separator: "\n", omittingEmptySubsequences: false)
            for (lineIdx, line) in lines.enumerated() {
                if lineIdx == 0 {
                    out.append(indent)
                    out.append(marker)
                    out.append(String(line))
                    out.append("\n")
                } else if !line.isEmpty {
                    let nestedIndent = String(repeating: " ", count: marker.count)
                    out.append(indent)
                    out.append(nestedIndent)
                    out.append(String(line))
                    out.append("\n")
                }
            }
        }
    }

    // MARK: - Inline marks

    private static func applyMarks(to text: String, marks: [ProseMirrorMark]) -> String {
        var output = text
        // Apply marks in a deterministic order so the wrapping is
        // canonical: link wraps innermost, then code, then em, then strong.
        // (Markdown wrapping order does matter for some renderers.)
        let priority: [String] = ["link", "code", "em", "strong"]
        let sorted = marks.sorted { lhs, rhs in
            (priority.firstIndex(of: lhs.type) ?? Int.max) <
                (priority.firstIndex(of: rhs.type) ?? Int.max)
        }
        for mark in sorted {
            switch mark.type {
            case "strong":
                output = "**\(output)**"
            case "em":
                output = "*\(output)*"
            case "code":
                output = "`\(output)`"
            case "link":
                if let href = mark.attrs?.href {
                    output = "[\(output)](\(href))"
                }
            default:
                break  // unknown marks pass through unchanged
            }
        }
        return output
    }
}
