import Foundation
import Testing
@testable import Epistemos

@Suite("Settings Window Presentation")
struct SettingsWindowPresentationTests {
    @Test("settings window source keeps flexible sizing and unified chrome")
    func settingsWindowSourceKeepsFlexibleSizingAndUnifiedChrome() throws {
        let source = try loadRepoTextFile("Epistemos/App/UtilityWindowManager.swift")

        #expect(!source.contains("case .settings: NSSize(width: 680, height: 10000)"))
        #expect(source.contains("panel.toolbarStyle = .unified"))
        #expect(source.contains("cornerRadius: CGFloat? = kind == .settings ? 22 : nil"))
    }

    @Test("settings split view source hides toolbar background and extends sidebar backdrop")
    func settingsSplitViewSourceHidesToolbarBackgroundAndExtendsSidebarBackdrop() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")

        #expect(source.contains(".scrollContentBackground(.hidden)"))
        #expect(source.contains("SettingsSidebarBackdrop(theme: ui.theme)"))
        #expect(source.contains(".toolbarBackgroundVisibility(.hidden, for: .windowToolbar)"))
    }

    private func loadRepoTextFile(_ relativePath: String) throws -> String {
        try loadMirroredSourceTextFile(relativePath)
    }
}
