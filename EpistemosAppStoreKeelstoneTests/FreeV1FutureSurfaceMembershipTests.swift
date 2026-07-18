import Foundation
import Testing

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("Free V1 future-surface membership tests must compile in the App Store Free V1 target.")
#endif

@Suite("Free V1 future-surface membership")
struct FreeV1FutureSurfaceMembershipTests {
    @Test("Free V1 physically removes the model-backed Daily Brief")
    func freeV1RemovesDailyBriefSurface() throws {
        let project = try sourceText("project.yml")
        let appTarget = try #require(appStoreTarget(in: project))
        let generatedProject = try sourceText("Epistemos.xcodeproj/project.pbxproj")
        let bootstrap = try sourceText("Epistemos/App/AppBootstrap.swift")
        let environment = try sourceText("Epistemos/App/AppEnvironment.swift")
        let landing = try sourceText("Epistemos/Views/Landing/LandingView.swift")

        #expect(!sourcePathExists("Epistemos/State/DailyBriefState.swift"))
        #expect(!appTarget.contains("State/DailyBriefState.swift"))
        #expect(!generatedProject.contains("State/DailyBriefState.swift"))
        #expect(!bootstrap.contains("DailyBrief"))
        #expect(!environment.contains("DailyBrief"))
        #expect(!landing.contains("DailyBrief"))
        #expect(landing.contains("Welcome Back"))
    }

    @Test("Free V1 excludes the model-backed HTML regeneration surface")
    func freeV1ExcludesHTMLWorkspaceRegeneration() throws {
        let project = try sourceText("project.yml")
        let appTarget = try #require(appStoreTarget(in: project))
        let editor = try sourceText("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")
        let packageActions = try sourceText("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorPackageActions.swift")

        for excludedSource in [
            "Views/HTMLWorkspace/HTMLWorkspaceEditorRegeneration.swift",
            "Views/HTMLWorkspace/HTMLWorkspaceRegenerateContextPresentation.swift",
            "Views/HTMLWorkspace/HTMLWorkspaceRegeneratePreview.swift",
            "Views/HTMLWorkspace/HTMLWorkspaceRegenerateSupport.swift",
            "Views/HTMLWorkspace/HTMLWorkspaceRegenerateSurface.swift",
        ] {
            #expect(
                appTarget.components(separatedBy: "\\n").filter {
                    $0 == "          - \(excludedSource)"
                }.count == 1
            )
        }

        #expect(editor.contains("#if !EPISTEMOS_FREE_V1\n    @State var regenerateSheetPresented = false"))
        #expect(editor.contains("#if !EPISTEMOS_FREE_V1\n        .sheet(isPresented: regenerateSheetBinding)"))
        #expect(editor.contains("#if !EPISTEMOS_FREE_V1\n                    Button(\"Restore Previous Surface\""))
        #expect(packageActions.contains("#if !EPISTEMOS_FREE_V1\n    func restorePreviousSurface()"))

        // The retained element inspector and deterministic vault-search feed must
        // not call helpers compiled only by the excluded regeneration surface.
        #expect(editor.contains("func boundedInspectorSelectorStatus(_ value: String) -> String"))
        #expect(
            editor.components(separatedBy: "#if !EPISTEMOS_FREE_V1\n        clearPendingRegeneratePreview()\n        #endif").count == 3
        )
    }

    @Test("Free V1 physically removes the model tool-call parser")
    func freeV1RemovesToolCallParser() throws {
        let project = try sourceText("project.yml")
        let appTarget = try #require(appStoreTarget(in: project))
        let generatedProject = try sourceText("Epistemos.xcodeproj/project.pbxproj")
        let extensions = try sourceText("Epistemos/Engine/Extensions.swift")

        #expect(!sourcePathExists("Epistemos/Omega/Inference/ToolCallParser.swift"))
        #expect(!appTarget.contains("Omega/Inference/ToolCallParser.swift"))
        #expect(!generatedProject.contains("Omega/Inference/ToolCallParser.swift"))
        #expect(!extensions.contains("ToolCallParser.parse"))
        #expect(extensions.contains("let looksLikeToolPayload = isStructuredToolPayload(body)"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        let repositoryRoot = repositoryRootURL()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    private func sourcePathExists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(
            atPath: repositoryRootURL().appendingPathComponent(relativePath).path
        )
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func appStoreTarget(in project: String) -> String? {
        guard let targetRange = project.range(of: "  Epistemos-AppStore:\\n") else { return nil }
        let suffix = project[targetRange.upperBound...]
        guard let nextTargetRange = suffix.range(of: "  EpistemosWidgets:\\n") else {
            return String(suffix)
        }
        return String(suffix[..<nextTargetRange.lowerBound])
    }
}
