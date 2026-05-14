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

    @Test("notes sidebar shares mini chat frost glass and pixel accents")
    func notesSidebarSharesMiniChatFrostGlassAndPixelAccents() throws {
        let notesSidebarSource = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NotesSidebar.swift")

        #expect(notesSidebarSource.contains("NotesSidebarGlassBackdrop(theme: theme)"))
        #expect(notesSidebarSource.contains(".fill(.ultraThinMaterial)"))
        #expect(notesSidebarSource.contains("Color.white.opacity(0.55)"))
        #expect(notesSidebarSource.contains("Color.black.opacity(0.32)"))
        #expect(notesSidebarSource.contains("Color.clear"))
        #expect(!notesSidebarSource.contains("LinearGradient("))
        #expect(notesSidebarSource.contains("NotesSidebarPixelDither"))
        #expect(notesSidebarSource.contains("NotesSidebarRowChrome"))
    }

    @Test("graph note editor inherits graph workspace blur without changing normal note tabs")
    func graphNoteEditorInheritsGraphWorkspaceBlurWithoutChangingNormalNoteTabs() throws {
        let graphNotePageSource = try loadMirroredSourceTextFile("Epistemos/Views/Graph/GraphNotePage.swift")
        let graphWorkspaceSource = try loadMirroredSourceTextFile(
            "Epistemos/Views/Graph/GraphWorkspaceContainer.swift"
        )
        let proseEditorSource = try loadMirroredSourceTextFile("Epistemos/Views/Notes/ProseEditorView.swift")
        let representableSource = try loadMirroredSourceTextFile(
            "Epistemos/Views/Notes/ProseEditorRepresentable2.swift"
        )
        let noteWorkspaceSource = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(graphWorkspaceSource.contains("private var graphNoteBackdrop: some View"))
        #expect(graphWorkspaceSource.contains("Color.clear"))
        #expect(graphWorkspaceSource.contains("case .note(let id):\n                graphNoteBackdrop"))
        #expect(graphWorkspaceSource.contains("private var graphPageBackdrop: some View"))
        #expect(graphNotePageSource.contains("Color.clear"))
        #expect(!graphNotePageSource.contains("GraphNotePageGlassBackdrop"))
        #expect(!graphNotePageSource.contains("LinearGradient("))
        #expect(proseEditorSource.contains("usesTransparentEditorBackground: navigationContext == .graph"))
        #expect(representableSource.contains("usesTransparentEditorBackground: Bool = false"))
        #expect(representableSource.contains("scrollView?.drawsBackground = false"))
        #expect(representableSource.contains("scrollView?.contentView.drawsBackground = false"))
        #expect(representableSource.contains("parent.applyEditorBackgroundMode(to: tv, in: scrollView)"))
        #expect(representableSource.contains("tv.drawsBackground = false"))
        #expect(!noteWorkspaceSource.contains("usesTransparentEditorBackground: true"))
    }
}
