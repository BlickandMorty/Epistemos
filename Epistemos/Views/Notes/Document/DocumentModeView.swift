import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - DocumentModeView
// SwiftUI container for Document mode. Assembles DocumentFormatBar and
// DocumentEditorView. Manages DOCX import/export and format state.
//
// Persistence: attributed string is serialized as RTFD data in the
// note's body field with a "rtfd:" prefix to distinguish from markdown.

struct DocumentModeView: View {
    let page: SDPage
    let isDark: Bool
    var theme: EpistemosTheme = .light
    var isLocked: Bool = false

    @State private var formatState = DocumentFormatState()
    @State private var attributedText = NSAttributedString()
    @State private var saveTask: Task<Void, Never>?
    @State private var hasLoaded = false

    @Environment(\.modelContext) private var modelContext

    /// Notification posted when format bar changes should apply to the editor selection.
    private let applyFormatNotification = Notification.Name("DocumentModeApplyFormat")

    var body: some View {
        DocumentEditorView(
            attributedText: $attributedText,
            isDark: isDark,
            theme: theme,
            isEditable: !isLocked,
            formatState: formatState
        )
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                DocumentFormatBar(
                    formatState: formatState,
                    isDark: isDark,
                    onApplyFormat: applyFormat,
                    onImportDOCX: importDOCX,
                    onExportDOCX: exportDOCX
                )
                .disabled(isLocked)

                LinearGradient(
                    colors: [
                        (isDark ? Color.black : theme.background).opacity(0.5),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 16)
                .allowsHitTesting(false)
            }
        }
        .animation(.spring(duration: 0.3), value: isDark)
        .onAppear {
            loadContent()
            hasLoaded = true
        }
        .onChange(of: attributedText) { _, _ in
            guard hasLoaded else { return }
            debouncedSave()
        }
        .onDisappear {
            flushIfNeeded()
        }
    }

    // MARK: - Content Loading

    private func loadContent() {
        let body = page.loadBody()
        if body.hasPrefix("rtfd:"),
           let data = Data(base64Encoded: String(body.dropFirst(5))),
           let attrStr = try? NSAttributedString(
               data: data,
               options: [.documentType: NSAttributedString.DocumentType.rtfd],
               documentAttributes: nil
           ) {
            attributedText = attrStr
        } else if !body.isEmpty {
            // Plain text / markdown — convert to attributed string
            let font = NSFont(name: "New York", size: 14)
                ?? NSFont.systemFont(ofSize: 14)
            attributedText = NSAttributedString(string: body, attributes: [
                .font: font,
                .foregroundColor: isDark ? NSColor.white : NSColor.black,
            ])
        }
    }

    // MARK: - Persistence

    private func debouncedSave() {
        saveTask?.cancel()
        page.needsVaultSync = true
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            saveContent()
        }
    }

    private func flushIfNeeded() {
        saveTask?.cancel()
        saveContent()
    }

    private func saveContent() {
        guard attributedText.length > 0 else { return }
        guard let data = try? attributedText.data(
            from: NSRange(location: 0, length: attributedText.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
        ) else { return }
        let encoded = "rtfd:" + data.base64EncodedString()
        if encoded != page.loadBody() {
            page.saveBody(encoded)
            page.updatedAt = .now
        }
    }

    // MARK: - Format Application

    private func applyFormat() {
        NotificationCenter.default.post(name: applyFormatNotification, object: formatState)
    }

    // MARK: - DOCX Import

    private func importDOCX() {
        let panel = NSOpenPanel()
        let docxType = UTType(filenameExtension: "docx") ?? .data
        panel.allowedContentTypes = [docxType]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            if let imported = DocumentEditorView.importDOCX(from: url) {
                attributedText = imported
            }
        }
    }

    // MARK: - DOCX Export

    private func exportDOCX() {
        let docxType = UTType(filenameExtension: "docx") ?? .data
        let panel = NSSavePanel()
        panel.allowedContentTypes = [docxType]
        panel.nameFieldStringValue = "\(page.title).docx"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? DocumentEditorView.exportDOCX(attributedText, to: url)
        }
    }
}
