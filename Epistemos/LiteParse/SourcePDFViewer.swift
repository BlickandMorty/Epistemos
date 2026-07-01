import PDFKit
import SwiftUI

struct SourcePDFViewerPresentation: Identifiable, Equatable {
    let url: URL

    var id: String {
        url.standardizedFileURL.path
    }
}

struct SourcePDFViewerSheet: View {
    private static let maxSearchQueryLength = 128
    private static let maxSearchResults = 250
    private static let maxFileNameDisplayCharacters = 180

    let url: URL

    @Environment(UIState.self) private var ui
    @Environment(\.dismiss) private var dismiss
    @State private var document: PDFDocument?
    @State private var loadError: String?
    @State private var outlineItems: [SourcePDFOutlineItem] = []
    @State private var annotationItems: [SourcePDFAnnotationItem] = []
    @State private var searchText = ""
    @State private var searchResults: [PDFSelection] = []
    @State private var selectedSearchIndex = 0
    @State private var selectedDestination: PDFDestination?
    @FocusState private var isSearchFieldFocused: Bool

    private var selectedSearch: PDFSelection? {
        guard searchResults.indices.contains(selectedSearchIndex) else { return nil }
        return searchResults[selectedSearchIndex]
    }

    private var mutedTint: Color {
        ui.theme.resolved.mutedForeground.color
    }

    private var secondaryTint: Color {
        mutedTint.opacity(ui.theme.isDark ? 0.78 : 0.72)
    }

    private var searchFieldBackground: Color {
        ui.theme.surfaceVariant(.other).resolved.card.color.opacity(ui.theme.isDark ? 0.34 : 0.58)
    }

    private var sourcePDFSeparator: some View {
        Rectangle()
            .fill(ui.theme.border.opacity(ui.theme.isDark ? 0.54 : 0.46))
            .frame(height: 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            sourcePDFSeparator

            if let document {
                HSplitView {
                    outlineList
                        .frame(minWidth: 190, idealWidth: 220, maxWidth: 300)

                    SourcePDFKitView(
                        document: document,
                        selectedSearch: selectedSearch,
                        selectedDestination: selectedDestination
                    )
                    .frame(minWidth: 520, minHeight: 520)
                }
            } else {
                ContentUnavailableView(
                    loadError ?? "PDF unavailable",
                    systemImage: "doc.richtext"
                )
                .frame(minWidth: 680, minHeight: 520)
            }
        }
        .frame(minWidth: 760, minHeight: 560)
        .onAppear {
            isSearchFieldFocused = true
        }
        .task(id: url) {
            loadDocument()
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Label(Self.displayFileName(url.lastPathComponent), systemImage: "doc.richtext")
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(ui.theme.resolved.foreground.color)

            Spacer(minLength: 12)

            HStack(spacing: 6) {
                TextField("Find", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(ui.theme.resolved.foreground.color)
                    .padding(.horizontal, 9)
                    .frame(width: 180)
                    .frame(minHeight: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(searchFieldBackground)
                    )
                    .focused($isSearchFieldFocused)
                    .onSubmit(runSearch)

                ToolbarCapsuleButton(
                    title: nil,
                    systemImage: "magnifyingglass",
                    role: .primaryAction,
                    chromePolicy: .alwaysSurface,
                    helpText: "Find in PDF",
                    accessibilityLabel: "Find in PDF",
                    action: runSearch
                )
                .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                ToolbarCapsuleButton(
                    title: nil,
                    systemImage: "chevron.up",
                    role: .toolbarUtility,
                    helpText: "Previous match",
                    accessibilityLabel: "Previous match"
                ) {
                    moveSearchSelection(by: -1)
                }
                .disabled(searchResults.isEmpty)
                .keyboardShortcut("g", modifiers: [.command, .shift])

                ToolbarCapsuleButton(
                    title: nil,
                    systemImage: "chevron.down",
                    role: .toolbarUtility,
                    helpText: "Next match",
                    accessibilityLabel: "Next match"
                ) {
                    moveSearchSelection(by: 1)
                }
                .disabled(searchResults.isEmpty)
                .keyboardShortcut("g", modifiers: .command)

                Text(searchStatus)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(mutedTint)
                    .frame(width: 56, alignment: .trailing)

                ToolbarCapsuleButton(
                    title: nil,
                    systemImage: "xmark.circle.fill",
                    role: .secondaryGhost,
                    helpText: "Clear search",
                    accessibilityLabel: "Clear search"
                ) {
                    clearSearch()
                }
                .disabled(searchText.isEmpty && searchResults.isEmpty)
            }

            ToolbarCapsuleButton(
                title: nil,
                systemImage: "xmark",
                role: .secondaryGhost,
                chromePolicy: .alwaysSurface,
                helpText: "Close",
                accessibilityLabel: "Close PDF viewer"
            ) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var outlineList: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarHeader("Outline")
            if outlineItems.isEmpty { emptySidebarText("No outline") } else { outlineSection }
            sourcePDFSeparator
            sidebarHeader("Annotations")
            if annotationItems.isEmpty { emptySidebarText("No annotations") } else { annotationSection }
            Spacer(minLength: 0)
        }
    }

    private func sidebarHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(secondaryTint)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
    }

    private func emptySidebarText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(mutedTint)
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
    }

    private var outlineSection: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(outlineItems) { item in
                    Button {
                        selectedDestination = item.destination
                    } label: {
                        Text(item.title)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, CGFloat(item.level) * 12)
                            .foregroundStyle(ui.theme.resolved.foreground.color)
                    }
                    .buttonStyle(NativeCardButtonStyle(cornerRadius: 6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(minHeight: 120)
    }

    private var annotationSection: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(annotationItems) { item in
                    Button {
                        selectedDestination = item.destination
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Text(item.subtitle)
                                .font(.caption2)
                                .foregroundStyle(mutedTint)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(ui.theme.resolved.foreground.color)
                    }
                    .buttonStyle(NativeCardButtonStyle(cornerRadius: 6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(minHeight: 120)
    }

    private var searchStatus: String {
        guard !searchResults.isEmpty else { return "0" }
        return "\(selectedSearchIndex + 1)/\(searchResults.count)"
    }

    private func loadDocument() {
        guard document == nil else { return }
        guard let loaded = PDFDocument(url: url) else {
            loadError = "Could not open \(Self.displayFileName(url.lastPathComponent))"
            return
        }
        document = loaded
        outlineItems = SourcePDFOutlineItem.flatten(document: loaded)
        annotationItems = SourcePDFAnnotationItem.flatten(document: loaded)
    }

    private func runSearch() {
        let boundedSearchText = String(searchText.prefix(Self.maxSearchQueryLength + 32))
        let query = boundedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let document, !query.isEmpty else {
            clearSearch(resetText: false)
            return
        }
        selectedDestination = nil
        let boundedQuery = String(query.prefix(Self.maxSearchQueryLength))
        searchResults = Array(
            document
                .findString(boundedQuery, withOptions: .caseInsensitive)
                .prefix(Self.maxSearchResults)
        )
        selectedSearchIndex = 0
    }

    private static func displayFileName(_ fileName: String) -> String {
        let bounded = String(fileName.prefix(maxFileNameDisplayCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "PDF" }
        guard trimmed.count > maxFileNameDisplayCharacters else { return trimmed }
        return String(trimmed.prefix(maxFileNameDisplayCharacters - 3)) + "..."
    }

    private func moveSearchSelection(by delta: Int) {
        guard !searchResults.isEmpty else { return }
        selectedDestination = nil
        selectedSearchIndex = (selectedSearchIndex + delta + searchResults.count) % searchResults.count
    }

    private func clearSearch(resetText: Bool = true) {
        if resetText {
            searchText = ""
        }
        searchResults = []
        selectedSearchIndex = 0
        selectedDestination = nil
    }
}

private struct SourcePDFOutlineItem: Identifiable {
    private static let maxOutlineDepth = 12
    private static let maxOutlineItems = 500
    private static let maxOutlineNodes = 1_000
    private static let maxOutlineTitleLength = 160

    let id: String
    let title: String
    let level: Int
    let destination: PDFDestination?

    static func flatten(document: PDFDocument) -> [SourcePDFOutlineItem] {
        guard let root = document.outlineRoot else { return [] }
        var items: [SourcePDFOutlineItem] = []
        var visitedNodeCount = 0
        appendChildren(of: root, level: 0, path: "root", into: &items, visitedNodeCount: &visitedNodeCount)
        return items
    }

    private static func appendChildren(
        of outline: PDFOutline,
        level: Int,
        path: String,
        into items: inout [SourcePDFOutlineItem],
        visitedNodeCount: inout Int
    ) {
        guard level <= maxOutlineDepth,
              visitedNodeCount < maxOutlineNodes,
              items.count < maxOutlineItems else {
            return
        }

        let childCount = max(0, outline.numberOfChildren)
        for index in 0..<childCount {
            guard visitedNodeCount < maxOutlineNodes,
                  items.count < maxOutlineItems else {
                break
            }
            guard let child = outline.child(at: index) else { continue }
            visitedNodeCount += 1
            let itemPath = "\(path).\(index)"
            if let title = child.label {
                let displayTitle = boundedTitle(title)
                items.append(
                    SourcePDFOutlineItem(
                        id: itemPath,
                        title: displayTitle,
                        level: level,
                        destination: child.destination
                    )
                )
            }
            appendChildren(
                of: child,
                level: level + 1,
                path: itemPath,
                into: &items,
                visitedNodeCount: &visitedNodeCount
            )
        }
    }

    private static func boundedTitle(_ title: String) -> String {
        let bounded = String(title.prefix(maxOutlineTitleLength + 32))
        let resolved = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !resolved.isEmpty else { return "Untitled" }
        guard resolved.count > maxOutlineTitleLength else { return resolved }
        return String(resolved.prefix(maxOutlineTitleLength))
    }
}

private struct SourcePDFAnnotationItem: Identifiable {
    private static let maxAnnotationPages = 500
    private static let maxAnnotationItems = 500
    private static let maxAnnotationTitleLength = 120

    let id: String
    let title: String
    let subtitle: String
    let destination: PDFDestination?

    static func flatten(document: PDFDocument) -> [SourcePDFAnnotationItem] {
        var items: [SourcePDFAnnotationItem] = []
        let pageLimit = min(document.pageCount, maxAnnotationPages)
        for pageIndex in 0..<pageLimit {
            guard items.count < maxAnnotationItems,
                  let page = document.page(at: pageIndex) else { break }
            for (annotationIndex, annotation) in page.annotations.enumerated() {
                guard items.count < maxAnnotationItems else { break }
                let rawTitle = annotation.contents
                let fallbackTitle = annotation.type.map { "\($0) annotation" } ?? "Annotation"
                let title = boundedTitle(rawTitle?.isEmpty == false ? rawTitle : fallbackTitle)
                let point = NSPoint(x: annotation.bounds.midX, y: annotation.bounds.midY)
                items.append(
                    SourcePDFAnnotationItem(
                        id: "\(pageIndex).\(annotationIndex)",
                        title: title,
                        subtitle: "Page \(pageIndex + 1)",
                        destination: PDFDestination(page: page, at: point)
                    )
                )
            }
        }
        return items
    }

    private static func boundedTitle(_ title: String?) -> String {
        let bounded = title.map { String($0.prefix(maxAnnotationTitleLength + 32)) }
        let resolved = bounded?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let resolved, !resolved.isEmpty else { return "Annotation" }
        guard resolved.count > maxAnnotationTitleLength else { return resolved }
        return String(resolved.prefix(maxAnnotationTitleLength))
    }
}

private struct SourcePDFKitView: NSViewRepresentable {
    let document: PDFDocument
    let selectedSearch: PDFSelection?
    let selectedDestination: PDFDestination?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSSplitView {
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin

        let thumbnailScrollView = NSScrollView()
        thumbnailScrollView.hasVerticalScroller = true
        thumbnailScrollView.hasHorizontalScroller = false
        thumbnailScrollView.translatesAutoresizingMaskIntoConstraints = false

        let thumbnailView = PDFThumbnailView()
        thumbnailView.thumbnailSize = NSSize(width: 72, height: 92)
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailScrollView.documentView = thumbnailView

        let pdfView = PDFView()
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true
        pdfView.displaysPageBreaks = true
        pdfView.backgroundColor = .textBackgroundColor

        thumbnailView.pdfView = pdfView
        context.coordinator.pdfView = pdfView
        context.coordinator.thumbnailView = thumbnailView

        splitView.addArrangedSubview(thumbnailScrollView)
        splitView.addArrangedSubview(pdfView)
        thumbnailScrollView.widthAnchor.constraint(equalToConstant: 112).isActive = true

        return splitView
    }

    func updateNSView(_ splitView: NSSplitView, context: Context) {
        let coordinator = context.coordinator
        if coordinator.pdfView?.document !== document {
            coordinator.pdfView?.document = document
            coordinator.thumbnailView?.pdfView = coordinator.pdfView
        }
        if let selectedDestination {
            coordinator.pdfView?.go(to: selectedDestination)
        }
        if let selectedSearch {
            coordinator.pdfView?.setCurrentSelection(selectedSearch, animate: true)
            coordinator.pdfView?.go(to: selectedSearch)
        }
        _ = splitView
    }

    final class Coordinator {
        weak var pdfView: PDFView?
        weak var thumbnailView: PDFThumbnailView?
    }
}
