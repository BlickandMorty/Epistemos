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

    @Test("skills settings source exposes a create skill form with an instruction sheet")
    func skillsSettingsSourceExposesCreateSkillFormWithInstructionSheet() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Settings/SkillsSettingsView.swift")

        #expect(source.contains("Text(\"Create Skill\")"))
        #expect(source.contains("Instruction Sheet"))
        #expect(source.contains("createSkill(vaultPath: vaultPath)"))
    }

    @Test("agent control source exposes a JSON custom tool editor")
    func agentControlSourceExposesCustomToolEditor() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Settings/AgentControlSettingsView.swift")

        #expect(source.contains("Text(\"Custom Tools\")"))
        #expect(source.contains("Tool Spec JSON"))
        #expect(source.contains("saveCustomTool(vaultPath: vaultPath)"))
    }

    @Test("authority settings source exposes a quick setup for fewer permission interruptions")
    func authoritySettingsSourceExposesQuickSetupPresets() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Settings/AuthoritySettingsView.swift")

        #expect(source.contains("Text(\"Quick Setup\")"))
        #expect(source.contains("Less Interruptions"))
        #expect(source.contains("applyPreset("))
    }

    private func loadRepoTextFile(_ relativePath: String) throws -> String {
        try loadMirroredSourceTextFile(relativePath)
    }
}
