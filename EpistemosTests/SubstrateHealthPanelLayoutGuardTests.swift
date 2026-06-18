import Testing
import Foundation

/// Owner 2026-06-18 — the Substrate Health panel's 18 stacked rows blew out the
/// window height. Guard that the three sections are collapsible and the 10-row
/// "Substrate Floor" defaults collapsed, so the panel opens compact. Nothing is
/// removed — every row stays one click away (per-feature hardening for the fix).
@Suite("Substrate health panel layout")
struct SubstrateHealthPanelLayoutGuardTests {

    @Test("all three sections are collapsible; Substrate Floor defaults collapsed")
    func sectionsAreCollapsible() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SubstrateHealthPanel.swift")

        // Collapsible Section(isExpanded:) for each section.
        #expect(src.contains("Section(\"Retrieval and Indexing\", isExpanded: $showRetrieval)"))
        #expect(src.contains("Section(\"Agent Runtime\", isExpanded: $showAgentRuntime)"))
        #expect(src.contains("Section(\"Substrate Floor\", isExpanded: $showSubstrateFloor)"))

        // The heavy 10-row section opens COLLAPSED; the two small ones expanded.
        #expect(src.contains("@State private var showSubstrateFloor = false"))
        #expect(src.contains("@State private var showRetrieval = true"))
        #expect(src.contains("@State private var showAgentRuntime = true"))
    }
}
