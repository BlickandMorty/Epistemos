import Testing
@testable import Epistemos

/// P6.4 (item 3) — locks the Appearance pane's declutter: look-and-feel sections
/// are grouped ahead of the graph trio, the graph sections stay contiguous, and
/// nothing is dropped. Guards against a future reorder silently re-fragmenting
/// the pane (e.g. Editor drifting back below the graph block).
@Suite("Appearance section order")
struct AppearanceSectionOrderTests {

    @Test("canonical order lists every section exactly once")
    func canonicalCoversAllOnce() {
        let canonical = AppearanceSection.canonical
        #expect(Set(canonical).count == canonical.count)              // no duplicates
        #expect(Set(canonical) == Set(AppearanceSection.allCases))     // none missing
    }

    @Test("all look-and-feel sections come before any graph section")
    func lookAndFeelPrecedesGraph() {
        let groups = AppearanceSection.canonical.map(\.group)
        // Once we hit the graph group, we must never return to look-and-feel.
        var sawGraph = false
        for group in groups {
            if group == .graph { sawGraph = true }
            if sawGraph { #expect(group == .graph) }
        }
    }

    @Test("the graph sections are one contiguous block")
    func graphSectionsContiguous() {
        let canonical = AppearanceSection.canonical
        let graphIndices = canonical.enumerated()
            .filter { $0.element.group == .graph }
            .map(\.offset)
        // Indices must be consecutive (max - min + 1 == count).
        let span = (graphIndices.max() ?? 0) - (graphIndices.min() ?? 0) + 1
        #expect(span == graphIndices.count)
        #expect(graphIndices.count == 3)  // node types, performance, shaped graph
    }

    @Test("Editor is grouped with look-and-feel, not the graph block")
    func editorIsLookAndFeel() {
        #expect(AppearanceSection.editor.group == .lookAndFeel)
        // And it sits before the first graph section in canonical order.
        let editorIdx = AppearanceSection.canonical.firstIndex(of: .editor)
        let firstGraphIdx = AppearanceSection.canonical.firstIndex { $0.group == .graph }
        #expect(editorIdx != nil && firstGraphIdx != nil)
        #expect(editorIdx! < firstGraphIdx!)
    }
}
