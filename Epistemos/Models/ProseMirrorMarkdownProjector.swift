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
//                ordered_list, list_item, blockquote, code_block/codeBlock,
//                mermaid, epdocChart, horizontal_rule, hard_break, text
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
/// href for links, language for code blocks). Optional fields keep the
/// `Codable` derivation tolerant of older / newer documents that omit
/// or add keys we don't yet model.
nonisolated public struct ProseMirrorAttrs: Codable, Sendable, Hashable {
    public let level: Int?
    public let href: String?
    public let language: String?
    public let title: String?
    /// W7.7 — Math node (KaTeX). The LaTeX source string for both
    /// `math_inline` (`$x=1$`) and `math_display` (`$$…$$`).
    public let formula: String?
    /// Tiptap's current `@tiptap/extension-mathematics` stores the
    /// source under `latex` on `inlineMath` / `blockMath` nodes.
    public let latex: String?
    /// Image / embed source URL.
    public let src: String?
    /// Image alternate text.
    public let alt: String?
    /// W7.8 — Footnote / callout / heading anchor identifier. For
    /// `footnote_reference` this is the marker (e.g. `1` → `[^1]`);
    /// for `callout` it's a slug used by the heading-anchor extension.
    public let id: String?
    /// W7.8 — Task item state. true → `- [x]`, false → `- [ ]`.
    public let checked: Bool?
    /// W7.8 — Callout type discriminant (`tip` / `info` / `warning` /
    /// `danger` / `details`). Drives the `:::<kind>` fence.
    public let kind: String?

    public init(
        level: Int? = nil,
        href: String? = nil,
        language: String? = nil,
        title: String? = nil,
        formula: String? = nil,
        latex: String? = nil,
        src: String? = nil,
        alt: String? = nil,
        id: String? = nil,
        checked: Bool? = nil,
        kind: String? = nil
    ) {
        self.level = level
        self.href = href
        self.language = language
        self.title = title
        self.formula = formula
        self.latex = latex
        self.src = src
        self.alt = alt
        self.id = id
        self.checked = checked
        self.kind = kind
    }
}

/// Project a ProseMirror JSON document into GFM Markdown text.
///
/// Per the plan §4: this is intentionally LOSSY. The intent is a
/// human-readable + grep-able `shadow.md` for FTS5 indexing + plain-
/// text export. Round-trip back to ProseMirror is NOT guaranteed.
nonisolated public enum ProseMirrorMarkdownProjector {

    /// Mutable accumulator passed through every `visit` call. Carries
    /// the running output buffer + side-collected footnote definitions
    /// (which must appear after the main flow regardless of where they
    /// were declared in the ProseMirror tree).
    fileprivate struct State {
        var out: String = ""
        /// Per-doc footnote definitions, indexed in declaration order.
        /// Each tuple is `(id, body)` — `id` is the user-visible
        /// marker (`"1"`, `"long-marker"`); `body` is the rendered
        /// content of the `footnote` node.
        var footnoteDefs: [(id: String, body: String)] = []
    }

    /// Project a parsed ProseMirror tree to GFM Markdown.
    public static func project(_ doc: ProseMirrorNode) -> String {
        var state = State()
        visit(doc, state: &state, listDepth: 0)
        // Append collected footnote definitions at the end of the doc
        // per GFM convention (`[^id]: body`). One blank line between
        // the body and the first definition; one blank line between
        // each definition.
        if !state.footnoteDefs.isEmpty {
            if !state.out.hasSuffix("\n") { state.out.append("\n") }
            state.out.append("\n")
            for (idx, def) in state.footnoteDefs.enumerated() {
                let body = def.body.trimmingCharacters(in: .whitespacesAndNewlines)
                state.out.append("[^\(def.id)]: \(body)")
                if idx < state.footnoteDefs.count - 1 {
                    state.out.append("\n\n")
                } else {
                    state.out.append("\n")
                }
            }
        }
        // Trim a trailing extra newline that block visitors emit
        // for paragraph separation.
        while state.out.hasSuffix("\n\n") {
            state.out.removeLast()
        }
        if !state.out.hasSuffix("\n") && !state.out.isEmpty {
            state.out.append("\n")
        }
        return state.out
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

    private static func visit(_ node: ProseMirrorNode, state: inout State, listDepth: Int) {
        switch node.type {
        case "doc":
            visitChildren(node, state: &state, listDepth: listDepth)

        case "paragraph":
            visitChildren(node, state: &state, listDepth: listDepth)
            state.out.append("\n\n")

        case "heading":
            let level = max(1, min(6, node.attrs?.level ?? 1))
            state.out.append(String(repeating: "#", count: level))
            state.out.append(" ")
            visitChildren(node, state: &state, listDepth: listDepth)
            state.out.append("\n\n")

        case "bullet_list":
            visitListChildren(node, state: &state, listDepth: listDepth, ordered: false)
            if listDepth == 0 {
                state.out.append("\n")
            }

        case "ordered_list":
            visitListChildren(node, state: &state, listDepth: listDepth, ordered: true)
            if listDepth == 0 {
                state.out.append("\n")
            }

        case "list_item":
            // Caller (visitListChildren) already prefixed bullet/number.
            visitChildren(node, state: &state, listDepth: listDepth)

        case "blockquote":
            // Project children into a sub-state, then prefix every line.
            var inner = State()
            visitChildren(node, state: &inner, listDepth: listDepth)
            for line in inner.out.split(separator: "\n", omittingEmptySubsequences: false) {
                state.out.append("> ")
                state.out.append(String(line))
                state.out.append("\n")
            }
            // Footnotes inside a blockquote bubble up to the doc level
            // — their definitions render at the end of the doc, not
            // mid-quote.
            state.footnoteDefs.append(contentsOf: inner.footnoteDefs)
            state.out.append("\n")

        case "code_block", "codeBlock":
            let lang = node.attrs?.language ?? ""
            state.out.append("```\(lang)\n")
            for child in node.content ?? [] {
                if let t = child.text { state.out.append(t) }
            }
            state.out.append("\n```\n\n")

        case "horizontal_rule":
            state.out.append("---\n\n")

        case "hard_break":
            state.out.append("  \n")

        case "text":
            let body = node.text ?? ""
            state.out.append(applyMarks(to: body, marks: node.marks ?? []))

        // MARK: - W7.7 — Math (KaTeX) inline + display

        case "math_inline", "inlineMath":
            // Per Alexandrie's `katex.ts` the inline syntax is `$…$`.
            // Pandoc reads this natively too so the .docx export gets
            // proper math without a writer change.
            let formula = node.attrs?.formula ?? node.attrs?.latex ?? extractTextContent(node)
            state.out.append("$\(formula)$")

        case "math_display", "blockMath":
            // Display math sits as its own block: blank-line / `$$…$$`
            // / blank-line so paragraphs around it don't fuse.
            let formula = node.attrs?.formula ?? node.attrs?.latex ?? extractTextContent(node)
            state.out.append("$$\n\(formula)\n$$\n\n")

        // MARK: - W7.8 — Markdown plugin nodes (footnote / task / callout)

        case "callout":
            // markdown-it-container syntax: `:::<kind>\n…\n:::`. Default
            // to "info" if the kind attr is missing so we never emit a
            // bare `:::` (which markdown-it-container rejects).
            let kind = node.attrs?.kind?.lowercased() ?? "info"
            var inner = State()
            visitChildren(node, state: &inner, listDepth: listDepth)
            // Trim trailing blank lines from the inner block so the
            // closing fence sits flush.
            var body = inner.out
            while body.hasSuffix("\n\n") { body.removeLast() }
            state.out.append(":::\(kind)\n")
            state.out.append(body)
            if !body.hasSuffix("\n") { state.out.append("\n") }
            state.out.append(":::\n\n")
            state.footnoteDefs.append(contentsOf: inner.footnoteDefs)

        case "task_list":
            // GFM task lists are bullet lists where each item starts
            // with `[ ]` or `[x]`. Render via the bullet pipeline but
            // tag the marker with the task state.
            visitTaskListChildren(node, state: &state, listDepth: listDepth)
            if listDepth == 0 {
                state.out.append("\n")
            }

        case "task_item":
            // Caller (visitTaskListChildren) renders the marker.
            visitChildren(node, state: &state, listDepth: listDepth)

        case "footnote_reference":
            // Inline `[^id]` reference. The matching `footnote`
            // definition node (sibling somewhere else in the doc)
            // contributes the body via the footnoteDefs collector.
            let id = node.attrs?.id ?? "1"
            state.out.append("[^\(id)]")

        case "footnote":
            // Collect the definition into the doc-level footnotes
            // list — DON'T emit at the call site. The body renders
            // at the end of the doc per GFM convention.
            let id = node.attrs?.id ?? String(state.footnoteDefs.count + 1)
            var inner = State()
            visitChildren(node, state: &inner, listDepth: 0)
            state.footnoteDefs.append((id: id, body: inner.out))

        // MARK: - W7.9 — Mermaid diagram fenced block

        case "mermaid":
            // Mermaid fences are language-tagged code blocks: any
            // markdown reader that doesn't speak Mermaid still shows
            // the source verbatim. Tiptap stores the diagram body as
            // a single text child (same shape as code_block).
            state.out.append("```mermaid\n")
            for child in node.content ?? [] {
                if let t = child.text { state.out.append(t) }
            }
            state.out.append("\n```\n\n")

        case "epdocChart":
            // Charts store a small JSON spec as text content. The
            // projection keeps it grep-able and export-safe without
            // pretending every markdown reader can render the chart.
            state.out.append("```epdoc-chart\n")
            for child in node.content ?? [] {
                if let t = child.text { state.out.append(t) }
            }
            state.out.append("\n```\n\n")

        case "epdocImage", "image":
            if let src = node.attrs?.src, !src.isEmpty {
                let alt = node.attrs?.alt ?? ""
                state.out.append("![\(alt)](\(src))\n\n")
            }

        default:
            // Unknown node — emit raw text content if any, then recurse.
            if let t = node.text {
                state.out.append(t)
            }
            visitChildren(node, state: &state, listDepth: listDepth)
        }
    }

    /// Drain the immediate text descendants of a node into a single
    /// string. Used by math_inline / math_display when the formula
    /// arrived as a child text node instead of a `formula` attr.
    private static func extractTextContent(_ node: ProseMirrorNode) -> String {
        if let direct = node.text { return direct }
        var buf = ""
        for child in node.content ?? [] {
            if let t = child.text { buf.append(t) }
            else { buf.append(extractTextContent(child)) }
        }
        return buf
    }

    private static func visitChildren(_ node: ProseMirrorNode, state: inout State, listDepth: Int) {
        for child in node.content ?? [] {
            visit(child, state: &state, listDepth: listDepth)
        }
    }

    private static func visitListChildren(_ node: ProseMirrorNode, state: inout State, listDepth: Int, ordered: Bool) {
        let children = node.content ?? []
        let indent = String(repeating: "  ", count: listDepth)
        for (idx, item) in children.enumerated() {
            let marker = ordered ? "\(idx + 1). " : "- "

            var itemState = State()
            visit(item, state: &itemState, listDepth: listDepth + 1)

            while itemState.out.hasSuffix("\n\n") {
                itemState.out.removeLast()
            }

            let lines = itemState.out.split(separator: "\n", omittingEmptySubsequences: false)
            for (lineIdx, line) in lines.enumerated() {
                if lineIdx == 0 {
                    state.out.append(indent)
                    state.out.append(marker)
                    state.out.append(String(line))
                    state.out.append("\n")
                } else if !line.isEmpty {
                    let nestedIndent = String(repeating: " ", count: marker.count)
                    state.out.append(indent)
                    state.out.append(nestedIndent)
                    state.out.append(String(line))
                    state.out.append("\n")
                }
            }
            // Footnotes from inside the list item bubble up.
            state.footnoteDefs.append(contentsOf: itemState.footnoteDefs)
        }
    }

    /// Specialised list walker for `task_list`. Each child is a
    /// `task_item` whose `attrs.checked` decides whether to emit
    /// `- [x]` or `- [ ]`.
    private static func visitTaskListChildren(_ node: ProseMirrorNode, state: inout State, listDepth: Int) {
        let indent = String(repeating: "  ", count: listDepth)
        for item in node.content ?? [] {
            let checked = item.attrs?.checked ?? false
            let marker = checked ? "- [x] " : "- [ ] "
            var itemState = State()
            visit(item, state: &itemState, listDepth: listDepth + 1)
            while itemState.out.hasSuffix("\n\n") { itemState.out.removeLast() }
            let lines = itemState.out.split(separator: "\n", omittingEmptySubsequences: false)
            for (lineIdx, line) in lines.enumerated() {
                if lineIdx == 0 {
                    state.out.append(indent)
                    state.out.append(marker)
                    state.out.append(String(line))
                    state.out.append("\n")
                } else if !line.isEmpty {
                    let nestedIndent = String(repeating: " ", count: marker.count)
                    state.out.append(indent)
                    state.out.append(nestedIndent)
                    state.out.append(String(line))
                    state.out.append("\n")
                }
            }
            state.footnoteDefs.append(contentsOf: itemState.footnoteDefs)
        }
    }

    // MARK: - Inline marks

    private static func applyMarks(to text: String, marks: [ProseMirrorMark]) -> String {
        var output = text
        // Apply marks in a deterministic order so the wrapping is
        // canonical: link wraps innermost, then code, then em, then
        // strong, then highlight (W7.8). Markdown wrapping order does
        // matter for some renderers.
        let priority: [String] = ["link", "code", "em", "strong", "highlight"]
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
            // W7.8 — markdown-it-mark `==text==` highlight syntax,
            // mirrors Alexandrie's `markdown-it-mark` plugin.
            case "highlight":
                output = "==\(output)=="
            default:
                break  // unknown marks pass through unchanged
            }
        }
        return output
    }
}
