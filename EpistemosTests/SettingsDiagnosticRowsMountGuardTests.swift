import Testing
import Foundation

@testable import Epistemos

// Regression guard (2026-06-21) for the honest-capability diagnostic rows shipped this session.
// RawThoughtsHealthRow / HTMLWorkspaceHealthRow / BrowserCapabilityHealthRow each expose a truthful
// status for a partial/opt-in subsystem (raw-thoughts emit flag, HTML workspace, browser scraper).
// Their per-row helper tests (SSGERawThoughtsDiagnosticTests / SSHWCapabilityStatusTests /
// SSMBrowserCapabilityStatusTests) cover the status LOGIC — but nothing covers the MOUNTING.
// A refactor of SettingsView's Diagnostics section could silently drop a row: the helper tests stay
// green while the honest status vanishes from the UI. This pins that all three remain mounted, in the
// Diagnostics section, so the surfaces can't regress invisibly.
@Suite("Settings Diagnostics — the honest-capability rows stay mounted")
struct SettingsDiagnosticRowsMountGuardTests {

    private func settingsSource() throws -> String {
        try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
    }

    @Test("SettingsView has a Diagnostics section that hosts the capability rows")
    func diagnosticsSectionExists() throws {
        #expect(try settingsSource().contains("Section(\"Diagnostics\")"))
    }

    @Test("the three honest-status diagnostic rows are each mounted exactly once")
    func allThreeRowsMounted() throws {
        let src = try settingsSource()
        for row in ["RawThoughtsHealthRow()", "HTMLWorkspaceHealthRow()", "BrowserCapabilityHealthRow()"] {
            let mounts = src.components(separatedBy: row).count - 1
            #expect(mounts == 1, "\(row) must be mounted exactly once in Settings; found \(mounts)")
        }
    }
}
