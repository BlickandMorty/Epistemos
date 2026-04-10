import Foundation
import Testing

@Suite("Status Bar Audit")
struct StatusBarAuditTests {
    @Test("status bar hides the retired omega utility panel")
    func statusBarHidesRetiredOmegaUtilityPanel() throws {
        let statusBar = try loadRepoTextFile("Epistemos/App/StatusBar.swift")
        let utilityPanels = try loadRepoTextFile("Epistemos/App/UtilityWindowManager.swift")

        #expect(statusBar.contains("UtilityPanel.statusBarPanels"))
        #expect(!statusBar.contains("UtilityPanel.allCases"))
        #expect(utilityPanels.contains("static var statusBarPanels: [UtilityPanel]"))
        #expect(utilityPanels.contains("[.notes, .settings]"))
    }

    private func loadRepoTextFile(_ relativePath: String) throws -> String {
        try loadMirroredSourceTextFile(relativePath)
    }
}
