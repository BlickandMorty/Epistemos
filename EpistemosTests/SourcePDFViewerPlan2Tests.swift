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
        #expect(viewer.contains("private static let maxSearchQueryLength = 128"))
        #expect(viewer.contains("@FocusState private var isSearchFieldFocused: Bool"))
        #expect(viewer.contains("private var searchFieldBackground: Color"))
        #expect(viewer.contains(".textFieldStyle(.plain)"))
        #expect(!viewer.contains(".textFieldStyle(.roundedBorder)"))
        #expect(viewer.contains(".frame(width: 180)\n                    .frame(minHeight: 30)"))
        #expect(!viewer.contains(".frame(width: 180, minHeight: 30)"))
        #expect(viewer.contains(".focused($isSearchFieldFocused)"))
        #expect(viewer.contains("isSearchFieldFocused = true"))
        #expect(viewer.contains("String(searchText.prefix(Self.maxSearchQueryLength + 32))"))
        #expect(viewer.contains("let boundedQuery = String(query.prefix(Self.maxSearchQueryLength))"))
        #expect(viewer.contains("document\n                .findString(boundedQuery, withOptions: .caseInsensitive)"))
        #expect(viewer.contains(#"systemImage: "magnifyingglass""#))
        #expect(viewer.contains(#"helpText: "Find in PDF""#))
        #expect(viewer.contains(#".keyboardShortcut("g", modifiers: [.command, .shift])"#))
        #expect(viewer.contains(#".keyboardShortcut("g", modifiers: .command)"#))
        #expect(viewer.contains("private func clearSearch(resetText: Bool = true)"))
        #expect(viewer.contains(#"systemImage: "xmark.circle.fill""#))
        #expect(viewer.contains(#"helpText: "Clear search""#))
        #expect(viewer.contains("document.outlineRoot"))
        #expect(viewer.contains("maxOutlineTitleLength"))
        #expect(viewer.contains("max(0, outline.numberOfChildren)"))
        #expect(viewer.contains("title: displayTitle"))
        #expect(viewer.contains("maxAnnotationPages"))
        #expect(viewer.contains("coordinator.pdfView?.go(to: selectedSearch)"))
        #expect(viewer.contains("selectedDestination = nil"))
        #expect(viewer.contains("SourcePDFAnnotationItem"))
        #expect(viewer.contains("page.annotations"))
        #expect(viewer.contains("PDFDestination(page: page, at: point)"))
        #expect(viewer.contains(#"sidebarHeader("Annotations")"#))
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
