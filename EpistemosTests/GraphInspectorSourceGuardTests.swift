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
}
