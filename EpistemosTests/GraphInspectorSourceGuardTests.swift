import Testing

@Suite("Graph inspector source guards", .serialized)
// UAS-EXEMPT: source-guard test fixture, not persisted substrate data.
nonisolated struct GraphInspectorSourceGuardTests {
    @Test("node inspector is preview-only and scrolls to the bottom")
    func nodeInspectorIsPreviewOnlyAndScrollsToBottom() throws {
        let inspector = try loadMirroredSourceTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")

        let modeStart = try #require(inspector.range(of: "private var modePicker"))
        let modeEnd = try #require(
            inspector.range(of: "private func noteEditorBody", range: modeStart.lowerBound..<inspector.endIndex)
        )
        let modePicker = String(inspector[modeStart.lowerBound..<modeEnd.lowerBound])

        let bodyEnd = try #require(
            inspector.range(of: "private func currentBody", range: modeEnd.lowerBound..<inspector.endIndex)
        )
        let noteBody = String(inspector[modeEnd.lowerBound..<bodyEnd.lowerBound])

        #expect(modePicker.contains("Text(\"Preview\").tag(NodeInspectorState.InspectorMode.editor)"))
        #expect(!modePicker.contains("Text(\"Editor\").tag(NodeInspectorState.InspectorMode.editor)"))
        #expect(!inspector.contains("enum EditorDisplay: String, CaseIterable"))
        #expect(!noteBody.contains("TextEditor(text: $editorText)"))
        #expect(!noteBody.contains("ForEach(EditorDisplay.allCases"))
        #expect(noteBody.contains("formattedMarkdownView(editorText)"))
        #expect(noteBody.contains(".scrollIndicators(.visible)"))
        #expect(noteBody.contains(".padding(.bottom, graphInspectorPreviewBottomPadding)"))
        #expect(noteBody.contains(".frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)"))
        #expect(!noteBody.contains(".frame(minHeight: inspectorState.inspectorMode == .editor ? 500 : 300)"))
    }

    @Test("node inspector preview content uses one Anthropic Sans body font without rendering markdown headings")
    func nodeInspectorPreviewUsesRawMarkdownBodyTextOnly() throws {
        let inspector = try loadMirroredSourceTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")

        let headerStart = try #require(inspector.range(of: "private func compactHeader"))
        let headerEnd = try #require(
            inspector.range(of: "private func compactVitals", range: headerStart.lowerBound..<inspector.endIndex)
        )
        let header = String(inspector[headerStart.lowerBound..<headerEnd.lowerBound])

        let previewStart = try #require(inspector.range(of: "private func noteEditorBody"))
        let previewEnd = try #require(
            inspector.range(of: "private func currentBody", range: previewStart.lowerBound..<inspector.endIndex)
        )
        let previewBody = String(inspector[previewStart.lowerBound..<previewEnd.lowerBound])

        let markdownStart = try #require(inspector.range(of: "private func formattedMarkdownView"))
        let accordionStart = try #require(
            inspector.range(of: "private func accordionBody", range: markdownStart.lowerBound..<inspector.endIndex)
        )
        let markdownPreview = String(inspector[markdownStart.lowerBound..<accordionStart.lowerBound])

        #expect(header.contains("theme.nodeTitleFontName"),
                "The selected-node inspector title should keep its theme/pixel display font.")
        #expect(previewBody.contains("formattedMarkdownView(editorText)"))
        #expect(inspector.contains("private func graphInspectorPreviewFont"))
        #expect(inspector.contains("ClaudeAppTypography.assistantFont(size: size, weight: weight)"))
        #expect(inspector.contains("private let graphInspectorPreviewBodyFontSize: CGFloat = 13"))
        #expect(markdownPreview.contains("rawMarkdownLineText(line)"))
        #expect(markdownPreview.contains("Text(verbatim: line)"))
        #expect(markdownPreview.contains("graphInspectorPreviewFont(size: graphInspectorPreviewBodyFontSize)"))
        #expect(!markdownPreview.contains("previewHeadingText("),
                "Graph inspector preview should show raw markdown heading markers instead of rendering large headings.")
        #expect(!markdownPreview.contains("graphPreviewHeadingFont("),
                "Graph inspector preview should have one body size, not heading-specific font sizes.")
        #expect(!markdownPreview.contains("headingLevel(for:"))
        #expect(!markdownPreview.contains("inlineMarkdown(markdown)"),
                "Graph inspector preview should keep markdown characters visible instead of interpreting inline markdown.")
        #expect(!markdownPreview.contains("Text(\"•\")"),
                "Graph inspector preview should keep list markdown markers visible.")
        #expect(!markdownPreview.contains("Image(systemName: \"square\")"),
                "Graph inspector preview should keep checklist markdown markers visible.")
        #expect(!markdownPreview.contains("String(trimmed.dropFirst("),
                "Graph inspector preview should not strip markdown syntax characters.")
        #expect(!markdownPreview.contains("theme.boxedLabelText("),
                "Preview-tab markdown headings should not use Ember boxed/display transforms.")
        #expect(!markdownPreview.contains("AppDisplayTypography.panelFont"),
                "Preview-tab markdown body text should not reuse graph panel display fonts.")
        #expect(!markdownPreview.contains("AppDisplayTypography.headingFont"),
                "Preview-tab markdown headings should not reuse note/display heading fonts.")
    }
}
