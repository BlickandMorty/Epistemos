import PDFKit
import SwiftUI

struct SourcePDFViewerPresentation: Identifiable, Equatable {
    let url: URL

    var id: String {
        url.standardizedFileURL.path
    }
}

struct SourcePDFViewerSheet: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss
    @State private var document: PDFDocument?
    @State private var loadError: String?
    @State private var outlineItems: [SourcePDFOutlineItem] = []
    @State private var searchText = ""
    @State private var searchResults: [PDFSelection] = []
    @State private var selectedSearchIndex = 0
    @State private var selectedDestination: PDFDestination?

    private var selectedSearch: PDFSelection? {
        guard searchResults.indices.contains(selectedSearchIndex) else { return nil }
        return searchResults[selectedSearchIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

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
        .task(id: url) {
            loadDocument()
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Label(url.lastPathComponent, systemImage: "doc.richtext")
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 12)

            HStack(spacing: 6) {
                TextField("Find", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                    .onSubmit(runSearch)

                Button {
                    moveSearchSelection(by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(searchResults.isEmpty)
                .help("Previous match")

                Button {
                    moveSearchSelection(by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(searchResults.isEmpty)
                .help("Next match")

                Text(searchStatus)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .trailing)
            }

            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var outlineList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Outline")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

            Divider()

            if outlineItems.isEmpty {
                Text("No outline")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
                Spacer(minLength: 0)
            } else {
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
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var searchStatus: String {
        guard !searchResults.isEmpty else { return "0" }
        return "\(selectedSearchIndex + 1)/\(searchResults.count)"
    }

    private func loadDocument() {
        guard document == nil else { return }
        guard let loaded = PDFDocument(url: url) else {
            loadError = "Could not open \(url.lastPathComponent)"
            return
        }
        document = loaded
        outlineItems = SourcePDFOutlineItem.flatten(document: loaded)
    }

    private func runSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let document, !query.isEmpty else {
            searchResults = []
            selectedSearchIndex = 0
            return
        }
        searchResults = document.findString(query, withOptions: .caseInsensitive)
        selectedSearchIndex = 0
    }

    private func moveSearchSelection(by delta: Int) {
        guard !searchResults.isEmpty else { return }
        selectedSearchIndex = (selectedSearchIndex + delta + searchResults.count) % searchResults.count
    }
}

private struct SourcePDFOutlineItem: Identifiable {
    let id: String
    let title: String
    let level: Int
    let destination: PDFDestination?

    static func flatten(document: PDFDocument) -> [SourcePDFOutlineItem] {
        guard let root = document.outlineRoot else { return [] }
        var items: [SourcePDFOutlineItem] = []
        appendChildren(of: root, level: 0, path: "root", into: &items)
        return items
    }

    private static func appendChildren(
        of outline: PDFOutline,
        level: Int,
        path: String,
        into items: inout [SourcePDFOutlineItem]
    ) {
        for index in 0..<outline.numberOfChildren {
            guard let child = outline.child(at: index) else { continue }
            let title = child.label?.trimmingCharacters(in: .whitespacesAndNewlines)
            let itemPath = "\(path).\(index)"
            if let title, !title.isEmpty {
                items.append(
                    SourcePDFOutlineItem(
                        id: itemPath,
                        title: title,
                        level: level,
                        destination: child.destination
                    )
                )
            }
            appendChildren(of: child, level: level + 1, path: itemPath, into: &items)
        }
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
            if let page = selectedSearch.pages.first {
                coordinator.pdfView?.go(to: page)
            }
        }
        _ = splitView
    }

    final class Coordinator {
        weak var pdfView: PDFView?
        weak var thumbnailView: PDFThumbnailView?
    }
}
