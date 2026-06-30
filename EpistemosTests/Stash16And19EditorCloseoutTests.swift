import Foundation
import Testing

@Suite("Stash 16 and 19 Editor Closeout")
struct Stash16And19EditorCloseoutTests {
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

    @Test("closeout records editor stashes as preserved not raw applied")
    func closeoutRecordsEditorStashesAsPreservedNotRawApplied() throws {
        let closeout = try loadMirroredSourceTextFile(
            "docs/audits/STASH16_19_EDITOR_DONOR_CLOSEOUT_2026_05_26.md"
        )
        let ledger = try loadMirroredSourceTextFile(
            "docs/audits/STASH_RECOVERY_LEDGER_2026_05_26.md"
        )
        let recoveryStatus = try loadMirroredSourceTextFile(
            "docs/audits/MAIN_ARCHITECTURE_RECOVERY_STATUS_2026_05_26.md"
        )
        let livingIndex = try loadMirroredSourceTextFile(
            "docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md"
        )

        #expect(closeout.contains("stash@{16}"))
        #expect(closeout.contains("stash@{19}"))
        #expect(closeout.contains("No stash was popped, dropped, checked out, or bulk-applied."))
        #expect(closeout.contains("closed for current product editor recovery"))
        #expect(closeout.contains("must not be restored as live editor code"))
        #expect(ledger.contains("`stash@{16}` - April 27 editor/vendor donor"))
        #expect(ledger.contains("`stash@{19}` - old code-editor invisible-text fix"))
        #expect(!ledger.contains("1. `stash@{16}` - remaining editor asset WIP only."))
        #expect(!ledger.contains("2. `stash@{19}` - old code-editor invisible-text stash."))
        #expect(recoveryStatus.contains("Code editor/vendor donor material from `stash@{16}` and `stash@{19}`"))
        #expect(recoveryStatus.contains("STASH16_19_EDITOR_DONOR_CLOSEOUT_2026_05_26.md"))
        #expect(livingIndex.contains("`stash@{16}` / `stash@{19}` editor donor recovery is closed"))
    }

    @Test("editor resources keep compressed KaTeX bundle and no active Mermaid vendor")
    func editorResourcesKeepCompressedKaTeXBundleAndNoActiveMermaidVendor() {
        #expect(repoFileExists("Epistemos/Resources/Editor/editor.html"))
        #expect(repoFileExists("Epistemos/Resources/Editor/editor.css.br"))
        #expect(repoFileExists("Epistemos/Resources/Editor/editor.js.br"))
        #expect(repoFileExists("Epistemos/Resources/Editor/vendor/katex/katex.min.css.br"))
        #expect(repoFileExists("Epistemos/Resources/Editor/vendor/katex/fonts/KaTeX_Main-Regular.woff2"))

        #expect(!repoFileExists("Epistemos/Resources/Editor/vendor/mermaid/mermaid.min.js"))
        #expect(!repoFileExists("Epistemos/Resources/Editor/editor.js"))
        #expect(!repoFileExists("Epistemos/Resources/Editor/editor.css"))
    }

    @Test("current code editor keeps MarkEdit CoreEditor path instead of minimal test shell")
    func currentCodeEditorKeepsMarkEditCoreEditorPathInsteadOfMinimalTestShell() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/CodeEditorView.swift")
        let adapter = try loadMirroredSourceTextFile("Epistemos/Views/Notes/MarkEditCoreEditorView.swift")
            + "\n"
            + loadMirroredSourceTextFile("Epistemos/Views/Notes/MarkEditCoreEditorState.swift")

        #expect(!source.contains("@preconcurrency import CodeEditSourceEditor"))
        #expect(!source.contains("SourceEditor("))
        #expect(!source.contains("SourceEditorConfiguration("))
        #expect(source.contains("MarkEditCodeEditorRepresentable("))
        #expect(source.contains("showLineNumbers: showLineGutter"))
        #expect(source.contains("showInvisibles: showInvisibles"))
        #expect(adapter.contains("MarkEditCoreEditorConfig("))
        #expect(adapter.contains("tabKeyBehavior: tabKeyBehavior"))
        #expect(adapter.contains("indentUnit: indentUnit"))
        #expect(source.contains("private func ensureContentDebouncer() -> CodeEditorContentDebouncer"))
        #expect(source.contains("if let contentDebouncer {"))
        #expect(source.contains("let debouncer = CodeEditorContentDebouncer { newText in"))

        #expect(!source.contains("MINIMAL TEST"))
        #expect(!source.contains("LineNumberGutter(textView: textView)"))
        #expect(!source.contains("MinimapView(textView: textView"))
    }

    @Test("invisible text donor is represented by Xcode colors without old rewrite")
    func invisibleTextDonorIsRepresentedByXcodeColorsWithoutOldRewrite() throws {
        let theme = try loadMirroredSourceTextFile("Epistemos/Theme/EpistemosTheme.swift")
        let codeEditor = try loadMirroredSourceTextFile("Epistemos/Views/Notes/CodeEditorView.swift")

        #expect(theme.contains("struct XcodeCodeColors: @unchecked Sendable"))
        #expect(theme.contains("static let defaultDark = XcodeCodeColors("))
        #expect(theme.contains("static let defaultLight = XcodeCodeColors("))
        #expect(theme.contains("@MainActor var xcodeColors: XcodeCodeColors"))
        #expect(theme.contains("func nsColorForTokenType(_ tokenType: UInt8) -> NSColor"))
        #expect(codeEditor.contains("func rgbSafeForCodeEditorTheme() -> NSColor"))
        #expect(codeEditor.contains("livePreviewThemeGuardCSS"))
        #expect(codeEditor.contains("rgbSafeForCodeEditorTheme()"))
        #expect(!codeEditor.contains("textView.isRichText = true  // required for per-token syntax highlighting colors"))
        #expect(!codeEditor.contains("struct CodeTextView: NSViewRepresentable"))
        #expect(!codeEditor.contains("final class Coordinator: NSObject, NSTextViewDelegate"))
    }
}
