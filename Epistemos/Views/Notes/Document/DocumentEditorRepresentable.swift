import SwiftUI
import SwiftData

// MARK: - DocumentEditorRepresentable
// NSViewRepresentable wrapping DocumentTextView (TextKit 2).
// Handles rich text loading/saving, page swap, appearance sync.
// Save pipeline mirrors ProseEditorView: file write -> dirty flag -> modelContext.save().

struct DocumentEditorRepresentable: NSViewRepresentable {

    let pageId: String
    let pageFormat: String
    let isDark: Bool
    let isEditable: Bool
    let modelContext: ModelContext

    func makeNSView(context: Context) -> NSScrollView {
        let (scrollView, textView) = DocumentTextView.makeTextKit2()
        textView.delegate = context.coordinator
        textView.isEditable = isEditable
        context.coordinator.textView = textView
        context.coordinator.loadContent(pageId: pageId, format: pageFormat)
        updateAppearance(textView, isDark: isDark)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        // Page swap — flush old, load new
        if context.coordinator.currentPageId != pageId {
            context.coordinator.flushIfNeeded()
            context.coordinator.loadContent(pageId: pageId, format: pageFormat)
        }

        textView.isEditable = isEditable
        updateAppearance(textView, isDark: isDark)
    }

    private func updateAppearance(_ textView: DocumentTextView, isDark: Bool) {
        textView.backgroundColor = isDark
            ? NSColor(white: 0.12, alpha: 1)
            : .textBackgroundColor
        textView.insertionPointColor = isDark ? .white : .textColor
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(modelContext: modelContext)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: DocumentTextView?
        var currentPageId = ""
        var lastPersistedHash = 0
        var saveTask: Task<Void, Never>?
        let modelContext: ModelContext

        init(modelContext: ModelContext) {
            self.modelContext = modelContext
        }

        /// Load content from disk. If format is markdown, convert to attributed string.
        func loadContent(pageId: String, format: String) {
            currentPageId = pageId
            guard let ts = textView?.textStorage else { return }

            if format == "richtext" {
                if let content = NoteFileStorage.readRichText(pageId: pageId) {
                    ts.setAttributedString(content)
                } else {
                    ts.setAttributedString(NSAttributedString(string: ""))
                }
            } else {
                // Markdown note opened in doc mode — convert to attributed string
                let markdown = NoteFileStorage.readBody(pageId: pageId)
                let attrStr = Self.markdownToAttributedString(markdown)
                ts.setAttributedString(attrStr)
            }
            lastPersistedHash = ts.string.hashValue
        }

        /// Simple markdown -> attributed string conversion for opening notes in doc mode.
        private static func markdownToAttributedString(_ markdown: String) -> NSAttributedString {
            let result = NSMutableAttributedString()
            let bodyFont = NSFont(name: "New York", size: 16) ?? .systemFont(ofSize: 16)
            let bodyStyle = NSMutableParagraphStyle()
            bodyStyle.lineSpacing = 6
            bodyStyle.paragraphSpacing = 8

            let lines = markdown.components(separatedBy: "\n")
            for (i, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                var attrs: [NSAttributedString.Key: Any] = [
                    .font: bodyFont,
                    .foregroundColor: NSColor.textColor,
                    .paragraphStyle: bodyStyle
                ]

                if trimmed.hasPrefix("### ") {
                    attrs[.font] = NSFont.systemFont(ofSize: 18, weight: .medium)
                    let text = String(trimmed.dropFirst(4))
                    result.append(NSAttributedString(string: text, attributes: attrs))
                } else if trimmed.hasPrefix("## ") {
                    attrs[.font] = NSFont.systemFont(ofSize: 22, weight: .semibold)
                    let text = String(trimmed.dropFirst(3))
                    result.append(NSAttributedString(string: text, attributes: attrs))
                } else if trimmed.hasPrefix("# ") {
                    attrs[.font] = NSFont.systemFont(ofSize: 28, weight: .bold)
                    let text = String(trimmed.dropFirst(2))
                    result.append(NSAttributedString(string: text, attributes: attrs))
                } else {
                    // Strip basic markdown bold/italic markers for clean display
                    let cleaned = trimmed
                        .replacingOccurrences(of: "**", with: "")
                        .replacingOccurrences(of: "__", with: "")
                    result.append(NSAttributedString(string: cleaned, attributes: attrs))
                }

                if i < lines.count - 1 {
                    result.append(NSAttributedString(string: "\n", attributes: attrs))
                }
            }
            return result
        }

        func textDidChange(_ notification: Notification) {
            debouncedSave()
        }

        private func debouncedSave() {
            saveTask?.cancel()
            let pid = currentPageId
            saveTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, let self else { return }
                self.persistContent(pageId: pid)
            }
        }

        func flushIfNeeded() {
            saveTask?.cancel()
            saveTask = nil
            guard let ts = textView?.textStorage else { return }
            let currentHash = ts.string.hashValue
            guard currentHash != lastPersistedHash else { return }
            persistContent(pageId: currentPageId)
        }

        private func persistContent(pageId: String) {
            guard let ts = textView?.textStorage else { return }
            let content = NSAttributedString(attributedString: ts)
            lastPersistedHash = ts.string.hashValue

            Task.detached(priority: .utility) {
                NoteFileStorage.writeRichText(pageId: pageId, content: content)
            }

            Task { @MainActor [weak self] in
                self?.markPageDirty(pageId: pageId)
                NoteFileStorage.notifyBodyChanged(pageId: pageId)
            }
        }

        @MainActor private func markPageDirty(pageId: String) {
            let desc = FetchDescriptor<SDPage>(
                predicate: #Predicate<SDPage> { $0.id == pageId }
            )
            if let page = try? modelContext.fetch(desc).first {
                page.needsVaultSync = true
                try? modelContext.save()
            }
        }
    }
}
