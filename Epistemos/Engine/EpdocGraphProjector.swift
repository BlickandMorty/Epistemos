import Foundation

// MARK: - EpdocGraphProjector
//
// Wave 7.14 of the Extended Program Plan
// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 7.14).
//
// Projects an `.epdoc` package (manifest + ProseMirror content tree)
// into the data needed to materialise it as a node + edges in the
// knowledge graph (`SDGraphNode` + `SDGraphEdge`). Pure value-typed
// — no SwiftData / ModelContext coupling. Caller inserts the
// projection into the active context.
//
// Why pure: the projector is shared between (a) the W7.14 first-pass
// indexer (runs against a SwiftData context), (b) the live save path
// (also a SwiftData context but on the editor actor), (c) the
// W7.16 Metal renderer's pre-pass that wants weights without
// touching SwiftData. Decoupling the data shape from the persistence
// path keeps every caller cheap.
//
// One projection per `.epdoc`:
//   nodeID     == manifest.id              (stable across saves)
//   nodeLabel  == manifest.title           (refreshed on every save)
//   nodeWeight == complexity scalar 0..1   (W7.12)
//
// Edges (every edge is directed; the source is always nodeID):
//   For each EpdocProvenance.derivedFrom     → .derivedFrom edge
//   For each EpdocProvenance.sourceArtifacts → .derivedFrom edge
//   For each EpdocProvenance.outputArtifacts → .reference edge (this
//                                              doc → output it produced)
//   For each `[[wikilink]]` in the body      → .reference edge
//   For document headings/list items/salient  → .contains edge
//       paragraph/image alt text
//
// Wikilink extraction (V1):
//   - Scan every text node's body for the `[[…]]` pattern (the
//     classic Obsidian / Logseq syntax).
//   - The captured target string is treated as a node label, NOT
//     a node id. The persistence step (W7.14 follow-up) resolves
//     label → existing node id via SDGraphNode lookup; if no match,
//     it creates a lightweight `.idea` node so the graph remains
//     visibly explorable immediately after save.
//   - Future: also recognise links with `epistemos-doc://` href
//     marks (Tiptap-native cross-doc links).
//
// Semantic content extraction (V1):
//   - Uses authored document text only: headings, list items,
//     blockquotes, image alt/title text, and long paragraph lead
//     sentences.
//   - Emits bounded `.contains` label edges so a long document without
//     explicit wikilinks still projects meaningful graph targets.
//   - Does not infer theory/proof claims or fabricate canonical types.

// MARK: - Projection value type

nonisolated struct EpdocGraphProjection: Sendable, Hashable {
    /// Equal to `manifest.id` — stable across saves so the graph
    /// node is upserted, not duplicated.
    let nodeID: String
    /// Doc title at write time.
    let nodeLabel: String
    /// 0..1 complexity scalar from `EpdocComplexityCalculator`.
    let nodeWeight: Double
    /// Graph node type derived from the package's ArtifactKind.
    let nodeType: GraphNodeType
    /// Outgoing edges from this doc.
    let edges: [Edge]

    init(
        nodeID: String,
        nodeLabel: String,
        nodeWeight: Double,
        nodeType: GraphNodeType,
        edges: [Edge]
    ) {
        self.nodeID = nodeID
        self.nodeLabel = nodeLabel
        self.nodeWeight = nodeWeight
        self.nodeType = nodeType
        self.edges = edges
    }

    nonisolated struct Edge: Sendable, Hashable {
        /// Target identifier. For `.derivedFrom` / `.reference` the
        /// id is the upstream doc's `manifest.id`. For wikilinks the
        /// id is the captured `[[label]]` string — the persistence
        /// step looks it up by node label.
        let targetID: String
        /// `GraphEdgeType` raw discriminant.
        let kind: GraphEdgeType
        /// 1.0 by default; `.derivedFrom` and `.reference` weights
        /// can be tuned by the caller (e.g. multiplying by the
        /// upstream doc's complexity).
        let weight: Double
        /// True when the target is a label / wikilink string (not an
        /// id) — the persistence step needs to resolve it.
        let targetIsLabel: Bool

        init(targetID: String, kind: GraphEdgeType, weight: Double = 1.0, targetIsLabel: Bool = false) {
            self.targetID = targetID
            self.kind = kind
            self.weight = weight
            self.targetIsLabel = targetIsLabel
        }
    }
}

// MARK: - Projector

nonisolated enum EpdocGraphProjector {
    private static let maxSemanticLabelCount = 24
    private static let maxSemanticLabelLength = 140
    private static let genericSemanticLabels: Set<String> = [
        "idea", "ideas", "evidence", "claim", "claims", "question",
        "questions", "method", "methods", "notes", "summary",
        "findings", "risks", "todo", "todos",
    ]

    /// Project an `.epdoc` package into the graph data.
    ///
    /// `contentJSON` is the canonical ProseMirror tree (the
    /// `content.pm.json` file inside the package). When supplied,
    /// the projector also extracts `[[wikilink]]` edges from text
    /// nodes. When nil, only provenance edges are emitted (used by
    /// W7.14's first-pass indexer that hasn't read the body yet).
    ///
    /// `complexityWeights` defaults to the canonical W7.12 weights;
    /// callers tuning the graph render can supply a custom weight
    /// vector.
    static func project(
        manifest: EpdocManifest,
        contentJSON: Data? = nil,
        complexityWeights: ComplexityWeights = .default
    ) -> EpdocGraphProjection {
        // Compute the W7.12 complexity scalar. Empty body → score 0.0
        // (the projector stays valid even when the body isn't loaded).
        let complexity: Double
        if let data = contentJSON,
           let scored = EpdocComplexityCalculator.complexity(jsonData: data, weights: complexityWeights) {
            complexity = scored
        } else {
            complexity = 0.0
        }

        var edges: [EpdocGraphProjection.Edge] = []

        // Provenance edges. Each ref id becomes a stable target id.
        for ref in manifest.provenance.derivedFrom {
            edges.append(.init(targetID: ref.id, kind: .derivedFrom))
        }
        for ref in manifest.provenance.sourceArtifacts {
            edges.append(.init(targetID: ref.id, kind: .derivedFrom))
        }
        for ref in manifest.provenance.outputArtifacts {
            edges.append(.init(targetID: ref.id, kind: .reference))
        }

        // Wikilink edges from the body, if loaded.
        if let data = contentJSON,
           let doc = try? JSONDecoder().decode(ProseMirrorNode.self, from: data) {
            let labels = wikilinkLabels(in: doc)
            for label in labels {
                edges.append(.init(
                    targetID: label,
                    kind: .reference,
                    weight: 1.0,
                    targetIsLabel: true
                ))
            }
            for label in semanticGraphLabels(in: doc, documentTitle: manifest.title) {
                edges.append(.init(
                    targetID: label,
                    kind: .contains,
                    weight: 0.65,
                    targetIsLabel: true
                ))
            }
        }

        return EpdocGraphProjection(
            nodeID: manifest.id,
            nodeLabel: manifest.title,
            nodeWeight: complexity,
            nodeType: GraphNodeType(from: manifest.kind),
            edges: edges
        )
    }

    // MARK: - Wikilink scanner

    /// Walk a ProseMirror tree pulling every `[[label]]` substring
    /// out of every text node. Returns labels in declaration order;
    /// duplicates are preserved (the persistence step dedupes by
    /// `(source, target, kind)` triple).
    static func wikilinkLabels(in node: ProseMirrorNode) -> [String] {
        var hits: [String] = []
        scanText(in: node, into: &hits)
        return hits
    }

    static func semanticGraphLabels(
        in node: ProseMirrorNode,
        documentTitle: String
    ) -> [String] {
        var labels: [String] = []
        var seen = Set<String>()
        collectSemanticLabels(
            in: node,
            documentTitle: normalizedInlineLabel(documentTitle) ?? "",
            insideListItem: false,
            insideBlockquote: false,
            labels: &labels,
            seen: &seen
        )
        return labels
    }

    private static func scanText(in node: ProseMirrorNode, into hits: inout [String]) {
        if node.type == "text", let body = node.text {
            extractWikilinks(from: body, into: &hits)
        }
        for child in node.content ?? [] {
            scanText(in: child, into: &hits)
        }
    }

    /// Pull every `[[…]]` out of `body`. Lazy linear scan — wikilinks
    /// are uncommon enough that a regex would lose to the simple state
    /// machine + `.contains` exits early on bodies that have none.
    private static func extractWikilinks(from body: String, into hits: inout [String]) {
        guard body.contains("[[") else { return }
        var idx = body.startIndex
        while idx < body.endIndex {
            guard let openRange = body.range(of: "[[", range: idx..<body.endIndex) else { return }
            let afterOpen = openRange.upperBound
            guard let closeRange = body.range(of: "]]", range: afterOpen..<body.endIndex) else { return }
            let label = String(body[afterOpen..<closeRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            // Refuse empty or oversized labels (sanity guard against
            // pathological input — shouldn't appear in real docs).
            if !label.isEmpty && label.count <= 256 && !label.contains("\n") {
                hits.append(label)
            }
            idx = closeRange.upperBound
        }
    }

    private static func collectSemanticLabels(
        in node: ProseMirrorNode,
        documentTitle: String,
        insideListItem: Bool,
        insideBlockquote: Bool,
        labels: inout [String],
        seen: inout Set<String>
    ) {
        guard labels.count < maxSemanticLabelCount else { return }

        switch node.type {
        case "heading":
            appendSemanticLabel(
                inlineText(in: node),
                documentTitle: documentTitle,
                labels: &labels,
                seen: &seen
            )
            return

        case "list_item":
            appendSemanticLabel(
                firstSemanticSentence(inlineText(in: node), minimumLength: 12),
                documentTitle: documentTitle,
                labels: &labels,
                seen: &seen
            )
            for child in node.content ?? [] {
                collectSemanticLabels(
                    in: child,
                    documentTitle: documentTitle,
                    insideListItem: true,
                    insideBlockquote: insideBlockquote,
                    labels: &labels,
                    seen: &seen
                )
            }
            return

        case "blockquote":
            appendSemanticLabel(
                firstSemanticSentence(inlineText(in: node), minimumLength: 12),
                documentTitle: documentTitle,
                labels: &labels,
                seen: &seen
            )
            for child in node.content ?? [] {
                collectSemanticLabels(
                    in: child,
                    documentTitle: documentTitle,
                    insideListItem: insideListItem,
                    insideBlockquote: true,
                    labels: &labels,
                    seen: &seen
                )
            }
            return

        case "paragraph" where !insideListItem && !insideBlockquote:
            appendSemanticLabel(
                firstSemanticSentence(inlineText(in: node), minimumLength: 48),
                documentTitle: documentTitle,
                labels: &labels,
                seen: &seen
            )

        case "image":
            appendSemanticLabel(
                node.attrs?.alt ?? node.attrs?.title,
                documentTitle: documentTitle,
                labels: &labels,
                seen: &seen
            )

        default:
            break
        }

        for child in node.content ?? [] {
            collectSemanticLabels(
                in: child,
                documentTitle: documentTitle,
                insideListItem: insideListItem,
                insideBlockquote: insideBlockquote,
                labels: &labels,
                seen: &seen
            )
        }
    }

    private static func appendSemanticLabel(
        _ raw: String?,
        documentTitle: String,
        labels: inout [String],
        seen: inout Set<String>
    ) {
        guard labels.count < maxSemanticLabelCount,
              let normalized = normalizedInlineLabel(raw),
              let label = documentQualifiedLabel(normalized, documentTitle: documentTitle) else {
            return
        }
        let key = label.lowercased()
        guard seen.insert(key).inserted else { return }
        labels.append(label)
    }

    private static func inlineText(in node: ProseMirrorNode) -> String? {
        if node.type == "text" { return node.text }
        let pieces = (node.content ?? []).compactMap { inlineText(in: $0) }
        guard !pieces.isEmpty else { return nil }
        return pieces.joined(separator: " ")
    }

    private static func firstSemanticSentence(_ raw: String?, minimumLength: Int) -> String? {
        guard let normalized = normalizedInlineLabel(raw),
              normalized.count >= minimumLength else {
            return nil
        }
        if let sentenceEnd = normalized.firstIndex(where: { ".?!".contains($0) }) {
            let sentence = String(normalized[...sentenceEnd])
            if sentence.count >= minimumLength {
                return sentence
            }
        }
        return normalized
    }

    private static func normalizedInlineLabel(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let normalized = raw
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#*-_`[](){}:;,."))
        guard normalized.count >= 4 else { return nil }
        guard !normalized.contains("[[") && !normalized.contains("]]") else { return nil }
        if normalized.count <= maxSemanticLabelLength {
            return normalized
        }
        let end = normalized.index(
            normalized.startIndex,
            offsetBy: maxSemanticLabelLength,
            limitedBy: normalized.endIndex
        ) ?? normalized.endIndex
        let prefix = normalized[..<end]
        let cut = prefix.rangeOfCharacter(from: .whitespacesAndNewlines, options: .backwards)?.lowerBound ?? end
        let truncated = String(normalized[..<cut]).trimmingCharacters(in: .whitespacesAndNewlines)
        return truncated.count >= 4 ? truncated : String(prefix).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func documentQualifiedLabel(
        _ label: String,
        documentTitle: String
    ) -> String? {
        let lower = label.lowercased()
        guard genericSemanticLabels.contains(lower),
              !documentTitle.isEmpty,
              documentTitle.lowercased() != lower else {
            return label
        }
        return normalizedInlineLabel("\(documentTitle): \(label)")
    }
}
