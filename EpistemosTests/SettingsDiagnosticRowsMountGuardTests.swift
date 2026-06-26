import Testing
import Foundation

@testable import Epistemos

// Regression guard for the diagnostics rows that remain after the model/run
// diagnostics were removed from Settings.
@Suite("Settings Diagnostics — the honest-capability rows stay mounted")
struct SettingsDiagnosticRowsMountGuardTests {

    private func settingsSource() throws -> String {
        try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
    }

    @Test("SettingsView has a Diagnostics section that hosts the capability rows")
    func diagnosticsSectionExists() throws {
        #expect(try settingsSource().contains("Section(\"Diagnostics\")"))
    }

    @Test("the remaining honest-status diagnostic rows are each mounted exactly once")
    func remainingRowsMounted() throws {
        let src = try settingsSource()
        for row in ["HTMLWorkspaceHealthRow()", "BrowserCapabilityHealthRow()"] {
            let mounts = src.components(separatedBy: row).count - 1
            #expect(mounts == 1, "\(row) must be mounted exactly once in Settings; found \(mounts)")
        }
        #expect(!src.contains("RawThoughtsHealthRow()"))
    }
}
