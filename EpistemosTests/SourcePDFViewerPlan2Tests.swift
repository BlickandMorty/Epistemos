import Testing

@Suite("Plan 2 source PDF viewer")
struct SourcePDFViewerPlan2Tests {
    @Test("source PDF viewer mounts native PDFKit with search thumbnails and outline")
    func sourcePDFViewerMountsNativePDFKit() throws {
        let viewer = try loadMirroredSourceTextFile("Epistemos/LiteParse/SourcePDFViewer.swift")

        #expect(viewer.contains("import PDFKit"))
        #expect(viewer.contains("struct SourcePDFViewerSheet"))
        #expect(viewer.contains("PDFView()"))
        #expect(viewer.contains("PDFThumbnailView()"))
        #expect(viewer.contains("document.findString(query, withOptions: .caseInsensitive)"))
        #expect(viewer.contains("document.outlineRoot"))
        #expect(viewer.contains("selectedSearch.pages.first"))
    }

    @Test("View original PDF affordance opens the native Plan 2 viewer from the note workspace")
    func viewOriginalPDFAffordanceOpensNativeViewer() throws {
        let affordance = try loadMirroredSourceTextFile("Epistemos/LiteParse/ViewOriginalPDFAffordance.swift")
        let workspace = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let canonical = try loadMirroredSourceTextFile("docs/research/EDITOR_CANONICAL_PLAN_2026_06_27.md")

        #expect(canonical.contains("PDF *viewer* (PDFKit `PDFView`) — Plan 2 owns it"))
        #expect(affordance.contains("let openOriginalPDF: (URL) -> Void"))
        #expect(!affordance.contains("var openOriginalPDF: (URL) -> Void = { _ in }"))
        #expect(workspace.contains("@State private var sourcePDFViewerPresentation: SourcePDFViewerPresentation?"))
        #expect(workspace.contains("ViewOriginalPDFAffordance("))
        #expect(workspace.contains("SourcePDFViewerSheet(url: presentation.url)"))
        #expect(workspace.contains("sourcePDFViewerPresentation = SourcePDFViewerPresentation(url: url)"))
    }
}
