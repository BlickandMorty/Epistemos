import Foundation
import Testing

@testable import Epistemos

/// Wave 7.14 source-guard for the .epdoc → graph projection.
@Suite("EpdocGraphProjector (Wave 7.14)")
nonisolated struct EpdocGraphProjectorTests {

    private static func manifest(
        id: String,
        title: String,
        derivedFrom: [String] = [],
        sourceArtifacts: [String] = [],
        outputArtifacts: [String] = []
    ) -> EpdocManifest {
        EpdocManifest(
            id: id,
            createdAt: 0,
            updatedAt: 0,
            title: title,
            contentHash: "",
            provenance: EpdocProvenance(
                producer: .human,
                derivedFrom: derivedFrom.map { EpdocArtifactRef(id: $0, kind: .source) },
                sourceArtifacts: sourceArtifacts.map { EpdocArtifactRef(id: $0, kind: .document) },
                outputArtifacts: outputArtifacts.map { EpdocArtifactRef(id: $0, kind: .document) }
            )
        )
    }

    private static func contentJSON(_ doc: ProseMirrorNode) throws -> Data {
        try JSONEncoder().encode(doc)
    }

    private static func text(_ s: String) -> ProseMirrorNode {
        ProseMirrorNode(type: "text", text: s)
    }

    private static func para(_ children: [ProseMirrorNode]) -> ProseMirrorNode {
        ProseMirrorNode(type: "paragraph", content: children)
    }

    private static func doc(_ children: [ProseMirrorNode]) -> ProseMirrorNode {
        ProseMirrorNode(type: "doc", content: children)
    }

    // MARK: - Node identity + label

    @Test("Projection node carries manifest.id + manifest.title verbatim")
    func nodeIdentity() {
        let m = Self.manifest(id: "01HMV5K2K9DOC1", title: "Quarterly report")
        let p = EpdocGraphProjector.project(manifest: m)
        #expect(p.nodeID == "01HMV5K2K9DOC1")
        #expect(p.nodeLabel == "Quarterly report")
        #expect(p.nodeType == .note,
                "every .epdoc projects as .note today; future per-kind mapping in W7.14 follow-up")
    }

    // MARK: - Complexity weight

    @Test("Node weight equals the W7.12 complexity scalar when contentJSON is supplied; 0 otherwise")
    func complexityWeight() throws {
        let m = Self.manifest(id: "x", title: "x")
        // Without content
        let pNoContent = EpdocGraphProjector.project(manifest: m)
        #expect(pNoContent.nodeWeight == 0.0,
                "projection without contentJSON MUST set weight to 0 (the indexer fills it on the next pass)")

        // With content
        let body = Self.doc([
            ProseMirrorNode(type: "heading",
                            attrs: ProseMirrorAttrs(level: 2),
                            content: [Self.text("title")]),
            Self.para([Self.text("a sentence with words to push the score above zero")]),
        ])
        let pWithContent = EpdocGraphProjector.project(manifest: m, contentJSON: try Self.contentJSON(body))
        #expect(pWithContent.nodeWeight > 0.0)
        #expect(pWithContent.nodeWeight <= 1.0)
    }

    // MARK: - Provenance edges

    @Test("derivedFrom + sourceArtifacts emit .derivedFrom edges; outputArtifacts emit .reference")
    func provenanceEdges() {
        let m = Self.manifest(
            id: "doc",
            title: "x",
            derivedFrom: ["src-a", "src-b"],
            sourceArtifacts: ["raw-1"],
            outputArtifacts: ["out-pdf"]
        )
        let p = EpdocGraphProjector.project(manifest: m)
        let edgesByKind = Dictionary(grouping: p.edges, by: \.kind)
        let derivedTargets = Set((edgesByKind[.derivedFrom] ?? []).map(\.targetID))
        #expect(derivedTargets == ["src-a", "src-b", "raw-1"],
                "derivedFrom + sourceArtifacts MUST flatten into .derivedFrom edges; got \(derivedTargets)")
        let referenceTargets = Set((edgesByKind[.reference] ?? []).map(\.targetID))
        #expect(referenceTargets == ["out-pdf"],
                "outputArtifacts MUST emit .reference edges; got \(referenceTargets)")
    }

    // MARK: - Wikilinks

    @Test("[[wikilink]] in a text node emits a .reference edge with targetIsLabel=true")
    func wikilinks() throws {
        let body = Self.doc([
            Self.para([Self.text("See [[Quarterly Plan]] and [[Risks]] for context.")]),
            Self.para([Self.text("No links here.")]),
        ])
        let m = Self.manifest(id: "doc", title: "Notes")
        let p = EpdocGraphProjector.project(
            manifest: m,
            contentJSON: try Self.contentJSON(body)
        )
        let wiki = p.edges.filter { $0.targetIsLabel }
        let labels = Set(wiki.map(\.targetID))
        #expect(labels == ["Quarterly Plan", "Risks"],
                "wikilink scanner MUST extract every [[label]] in declaration order; got \(labels)")
        #expect(wiki.allSatisfy { $0.kind == .reference },
                "wikilinks MUST emit .reference edges; got \(wiki)")
    }

    @Test("Wikilink scanner handles nested nodes (paragraphs inside blockquotes inside lists)")
    func wikilinksNested() throws {
        let body = Self.doc([
            ProseMirrorNode(type: "bullet_list", content: [
                ProseMirrorNode(type: "list_item", content: [
                    ProseMirrorNode(type: "blockquote", content: [
                        Self.para([Self.text("Mentions [[Deep Note]] from inside a list.")])
                    ])
                ])
            ])
        ])
        let m = Self.manifest(id: "doc", title: "Notes")
        let p = EpdocGraphProjector.project(
            manifest: m,
            contentJSON: try Self.contentJSON(body)
        )
        let labels = p.edges.filter(\.targetIsLabel).map(\.targetID)
        #expect(labels == ["Deep Note"], "nested wikilinks MUST be discovered; got \(labels)")
    }

    @Test("Wikilink scanner refuses empty / oversized / multiline labels (sanity guard)")
    func wikilinksSanity() throws {
        let body = Self.doc([
            Self.para([Self.text("[[]] [[ ]] [[short]] [[\(String(repeating: "x", count: 300))]] [[multi\nline]]")]),
        ])
        let m = Self.manifest(id: "doc", title: "Notes")
        let p = EpdocGraphProjector.project(
            manifest: m,
            contentJSON: try Self.contentJSON(body)
        )
        let labels = p.edges.filter(\.targetIsLabel).map(\.targetID)
        #expect(labels == ["short"],
                "scanner MUST drop empty / >256 char / multiline labels; got \(labels)")
    }

    @Test("No wikilinks in body → only provenance edges in the projection")
    func wikilinksAbsent() throws {
        let body = Self.doc([Self.para([Self.text("Plain text, no special syntax.")])])
        let m = Self.manifest(id: "doc", title: "Notes",
                              derivedFrom: ["src-only"])
        let p = EpdocGraphProjector.project(
            manifest: m,
            contentJSON: try Self.contentJSON(body)
        )
        #expect(p.edges.count == 1)
        #expect(p.edges.first?.targetID == "src-only")
        #expect(p.edges.first?.kind == .derivedFrom)
        #expect(p.edges.first?.targetIsLabel == false,
                "provenance edges target stable manifest ids, not labels")
    }

    // MARK: - Stability across saves

    @Test("Projecting the same manifest twice yields equal nodeID + nodeLabel + edges (stable upserts)")
    func projectionIsStable() {
        let m = Self.manifest(id: "stable", title: "Same",
                              derivedFrom: ["upstream"])
        let p1 = EpdocGraphProjector.project(manifest: m)
        let p2 = EpdocGraphProjector.project(manifest: m)
        #expect(p1 == p2,
                "identical manifests MUST project identically so the persistence step performs an upsert, not a duplicate insert")
    }
}
