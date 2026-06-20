import Testing
import Foundation

@testable import Epistemos

// SS-SH regression guard (owner-diagnosed 2026-06-20): the Substrate Health panel went
// BLANK because its Form hosts collapsible Section(_:isExpanded:) rows (added in 13d2b5307)
// but had no .formStyle(.grouped) — collapsible sections require the grouped style to
// render, else the whole Form collapses to nothing. NOT the SS-SH clock. This guards the
// fix so the panel can't silently re-blank. (The visual "panel renders" pass is owner-runtime.)
@Suite("SS-SH panel form style regression guard")
struct SSSHPanelFormStyleTests {

    @Test("the Substrate Health panel Form uses .formStyle(.grouped)")
    func panelHasGroupedFormStyle() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SubstrateHealthPanel.swift")
        // The panel uses collapsible Section(isExpanded:) — which only render under .grouped.
        #expect(src.contains("isExpanded: $showRetrieval"))
        #expect(src.contains(".formStyle(.grouped)"))
    }
}
