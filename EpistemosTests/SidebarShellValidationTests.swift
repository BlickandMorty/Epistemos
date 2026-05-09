import Testing
@testable import Epistemos

@Suite("Sidebar Shell Validation")
struct SidebarShellValidationTests {
    @Test("sidebar shell owns top-level notes model and system modes")
    func sidebarShellOwnsTopLevelModes() throws {
        let browserSource = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NotesBrowserView.swift")
        let shellSource = try loadMirroredSourceTextFile("Epistemos/Views/Sidebar/SidebarShell.swift")
        let notesSidebarSource = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NotesSidebar.swift")
        let modelVaultsSource = try loadMirroredSourceTextFile(
            "Epistemos/Views/Notes/ModelVaultsSidebarSection.swift"
        )

        #expect(browserSource.contains("SidebarShell(allPages: allPages, allFolders: allFolders)"))
        #expect(shellSource.contains("ModeSwitcherControl(modeStore: modeStore)"))
        #expect(shellSource.contains("PinnedStripView()"))
        #expect(shellSource.contains("case .myVault:"))
        #expect(shellSource.contains("case .modelVaults:"))
        #expect(shellSource.contains("case .system:"))
        #expect(shellSource.contains("showsModelVaultsSection: false"))
        #expect(notesSidebarSource.contains("var showsModelVaultsSection = true"))
        #expect(modelVaultsSource.contains("case standalone"))
        #expect(modelVaultsSource.contains("presentation: Presentation = .sidebarSection"))
    }
}
