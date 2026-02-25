import SwiftData
import SwiftUI

// MARK: - WriterModeView
// SwiftUI container that assembles the WriterFormatBar and PagedDocumentView,
// managing the WriterFormatState lifecycle (load from front-matter, debounced save,
// flush on disappear).
//
// Data flow mirrors ProseEditorView:
//   1. SDPage.body (SwiftData) -> @State bodyText (markdown-stripped) -> PagedDocumentView
//   2. User types -> bodyText binding updates -> onChange debounces -> SDPage.body
//   3. Format state persists to SDPage.frontMatter on disappear

struct WriterModeView: View {
    let page: SDPage
    let isDark: Bool
    var isLocked: Bool = false

    @State private var formatState = WriterFormatState()
    @State private var bodyText: String = ""
    @State private var saveTask: Task<Void, Never>?
    @State private var hasLoaded = false

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 0) {
            WriterFormatBar(
                formatState: formatState,
                isDark: isDark,
                onExport: handleExport
            )
            .disabled(isLocked)
            .transition(.move(edge: .top).combined(with: .opacity))

            PagedDocumentView(
                text: $bodyText,
                formatState: formatState,
                isDark: isDark,
                isEditable: !isLocked
            )
        }
        .animation(.spring(duration: 0.3), value: isDark)
        .onAppear {
            bodyText = stripMarkdownForWriter(page.body)
            formatState.load(from: page.frontMatter)
            if formatState.titlePageTitle.isEmpty {
                formatState.titlePageTitle = page.title
            }
            hasLoaded = true
        }
        .onChange(of: bodyText) { _, newValue in
            guard hasLoaded else { return }
            debouncedSave(newValue)
        }
        .onDisappear {
            flushIfNeeded()
            saveFormatState()
        }
    }

    // MARK: - Debounced Save
    // Matches ProseEditorView pattern: 5s debounce, cancel previous, flush on disappear.
    // Sets needsVaultSync immediately so the dirty flag is visible before the body flush.

    private func debouncedSave(_ newValue: String) {
        saveTask?.cancel()
        page.needsVaultSync = true
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            guard newValue != page.body else { return }
            page.body = newValue
            page.updatedAt = .now
        }
    }

    // MARK: - Flush

    private func flushIfNeeded() {
        saveTask?.cancel()
        if page.body != bodyText {
            page.body = bodyText
            page.needsVaultSync = true
            page.updatedAt = .now
        }
    }

    // MARK: - Format State Persistence

    private func saveFormatState() {
        var fm = page.frontMatter
        formatState.save(into: &fm)
        page.frontMatter = fm
        formatState.saveTitlePageDefaults()
    }

    // MARK: - Export

    private func handleExport(_ format: ExportFormat) {
        saveFormatState()
        WriterExportService.export(
            format: format,
            title: page.title,
            body: bodyText,
            storage: nil,
            pageTiles: [],
            formatState: formatState
        )
    }

    // MARK: - Markdown Stripping

    /// Strips markdown syntax for the writer's plain-text editing surface.
    /// Uses the same regex set as WriterExportService's `markdownStripped`.
    private func stripMarkdownForWriter(_ text: String) -> String {
        var s = text

        // Bold: **text** or __text__
        s = s.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: #"__(.+?)__"#, with: "$1", options: .regularExpression)

        // Italic: *text* or _text_
        s = s.replacingOccurrences(of: #"\*(.+?)\*"#, with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\b_(.+?)_\b"#, with: "$1", options: .regularExpression)

        // Strikethrough: ~~text~~
        s = s.replacingOccurrences(of: #"~~(.+?)~~"#, with: "$1", options: .regularExpression)

        // Inline code: `code`
        s = s.replacingOccurrences(of: #"`(.+?)`"#, with: "$1", options: .regularExpression)

        // Links: [text](url)
        s = s.replacingOccurrences(of: #"\[(.+?)\]\(.+?\)"#, with: "$1", options: .regularExpression)

        // Headings: lines starting with #
        s = s.replacingOccurrences(of: #"(?m)^#{1,6}\s+"#, with: "", options: .regularExpression)

        return s
    }
}
