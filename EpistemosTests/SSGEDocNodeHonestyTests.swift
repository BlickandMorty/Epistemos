import Testing
import Foundation

@testable import Epistemos

// SS-GE doc-node (owner: "surfaces that are NOT editable in the graph open a UTILITY instead"). An
// Epdoc document node still opens in a SEPARATE window today, not inline in the graph. Until inline
// doc-editing lands, the honest move is to (a) label it truthfully ("Open Document in a Window") so the
// user knows it's not in-place, and (b) route that decision through GraphSurfaceInlineEditability
// (foundation 9573a79fa) so the helper is the single authority for inline-vs-utility — now consumed in
// production, not an orphan. These pin both.
@Suite("SS-GE doc-node — honest 'opens in a window' + inline-editability helper consumed")
struct SSGEDocNodeHonestyTests {

    @Test("the graph document-open affordance consumes GraphSurfaceInlineEditability (no orphan)")
    func graphConsumesInlineEditabilityHelper() throws {
        let graph = try loadMirroredSourceTextFile("Epistemos/Views/Graph/HologramSearchSidebar.swift")
        #expect(graph.contains("GraphSurfaceInlineEditability.fallsThroughToUtility"))
    }

    @Test("the document-open label is honest about opening a separate window (not inline)")
    func documentLabelIsHonest() throws {
        let graph = try loadMirroredSourceTextFile("Epistemos/Views/Graph/HologramSearchSidebar.swift")
        #expect(graph.contains("Open Document in a Window"))
    }
}
