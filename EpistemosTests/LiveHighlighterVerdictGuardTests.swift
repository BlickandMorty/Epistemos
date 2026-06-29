import Foundation
import Testing

@Suite("Plan 2 live highlighter scaffold legacy guard")
struct LiveHighlighterVerdictGuardTests {
    private var repoRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func repoFileExists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(
            atPath: repoRootURL.appendingPathComponent(relativePath).path
        )
    }

    @Test("unused live editor controller and highlighter scaffold files stay legacy-only")
    func unusedLiveEditorControllerAndHighlighterScaffoldFilesStayLegacyOnly() {
        #expect(repoFileExists("Epistemos/Engine/LiveCodeEditorController.swift"))
        #expect(repoFileExists("Epistemos/Engine/SwiftTreeSitterLiveHighlighter.swift"))
        #expect(repoFileExists("Epistemos/Engine/SyntaxCoreLiveHighlighter.swift"))
        #expect(!repoFileExists("EpistemosTests/LiveCodeEditorControllerTests.swift"))
        #expect(!repoFileExists("EpistemosTests/SwiftTreeSitterLiveHighlighterTests.swift"))
        #expect(!repoFileExists("EpistemosTests/SyntaxCoreLiveHighlighterTests.swift"))
    }

    @Test("production code editor stays on MarkEdit CoreEditor")
    func productionCodeEditorStaysOnMarkEditCoreEditor() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/CodeEditorView.swift")
        let adapter = try loadMirroredSourceTextFile("Epistemos/Views/Notes/MarkEditCoreEditorView.swift")

        #expect(source.contains("MarkEditCodeEditorRepresentable("))
        #expect(source.contains("MarkEditMarkdownEditorRepresentable("))
        #expect(source.contains("HTMLWorkspacePreviewView("))
        #expect(!source.contains("LiveCodeEditorController("))
        #expect(!source.contains("SwiftTreeSitterLiveHighlighter"))
        #expect(!source.contains("SyntaxCoreLiveHighlighter"))
        #expect(source.contains(#"@AppStorage("codeEditor.useLegacyV1Editor")"#))
        #expect(source.contains("WebKitCodeEditorView("))
        #expect(adapter.contains("MarkEditCoreEditorBridge"))
    }
}
