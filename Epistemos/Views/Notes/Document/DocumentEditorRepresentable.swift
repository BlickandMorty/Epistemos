import SwiftUI
import SwiftData

// MARK: - DocumentEditorRepresentable
// NSViewRepresentable wrapping DocumentTextView (TextKit 2).
// Handles rich text loading/saving, page swap, appearance sync.
// Save pipeline mirrors ProseEditorView: file write -> dirty flag -> modelContext.save().

struct DocumentEditorRepresentable: NSViewRepresentable {

    let pageId: String
    let pageFormat: String
    let theme: EpistemosTheme
    let isEditable: Bool
    let modelContext: ModelContext
    var noteChatState: NoteChatState?
    var onWikilinkClick: ((String) -> Void)?
    var onTocChanged: (([TOCItem]) -> Void)?
    var onTextViewCreated: ((DocumentTextView) -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let (scrollView, textView) = DocumentTextView.makeTextKit2()
        textView.delegate = context.coordinator
        textView.isEditable = isEditable
        context.coordinator.textView = textView
        context.coordinator.onWikilinkClick = onWikilinkClick
        context.coordinator.onTocChanged = onTocChanged
        context.coordinator.loadContent(pageId: pageId, format: pageFormat, theme: theme)
        updateAppearance(textView, theme: theme)
        wireNoteChatState(context.coordinator)
        onTextViewCreated?(textView)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        // Page swap — flush old, load new
        if context.coordinator.currentPageId != pageId {
            context.coordinator.flushIfNeeded()
            context.coordinator.loadContent(pageId: pageId, format: pageFormat, theme: theme)
        }

        textView.isEditable = isEditable
        updateAppearance(textView, theme: theme)
        context.coordinator.refreshTheme(theme)
        context.coordinator.onWikilinkClick = onWikilinkClick
        context.coordinator.onTocChanged = onTocChanged
        wireNoteChatState(context.coordinator)
    }

    private func wireNoteChatState(_ coordinator: Coordinator) {
        guard let noteChat = noteChatState, coordinator.noteChatState !== noteChat else { return }
        coordinator.noteChatState = noteChat
        noteChat.onStreamStart = { [weak coordinator] query in
            coordinator?.startNoteChatStream(query)
        }
        noteChat.onTokenFlush = { [weak coordinator] delta in
            coordinator?.appendNoteChatTokens(delta)
        }
        noteChat.onAccept = { [weak coordinator] in
            coordinator?.acceptNoteChatResponse()
        }
        noteChat.onDiscard = { [weak coordinator] in
            coordinator?.discardNoteChatResponse()
        }
        noteChat.noteBodyProvider = { [weak coordinator] in
            coordinator?.textView?.string ?? ""
        }
    }

    private func updateAppearance(_ textView: DocumentTextView, theme: EpistemosTheme) {
        textView.applyTheme(theme)
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        coordinator.flushIfNeeded()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(modelContext: modelContext)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: DocumentTextView?
        var currentPageId = ""
        var currentFormat = "markdown"
        var currentTheme: EpistemosTheme?
        var lastPersistedHash: Int = 0
        var saveTask: Task<Void, Never>?
        var noteChatState: NoteChatState?
        var isFlushingTokens = false
        var onWikilinkClick: ((String) -> Void)?
        var onTocChanged: (([TOCItem]) -> Void)?
        private var wikilinkTask: Task<Void, Never>?
        private var dataDetectionTask: Task<Void, Never>?
        private static let aiDivider = "\n\n<!-- ai-response -->\n\n"
        let modelContext: ModelContext

        init(modelContext: ModelContext) {
            self.modelContext = modelContext
            super.init()
            NotificationCenter.default.addObserver(
                self, selector: #selector(handleWillTerminate),
                name: NSApplication.willTerminateNotification, object: nil
            )
        }

        @objc private func handleWillTerminate() {
            flushIfNeeded()
        }

        /// Load content from disk. If format is markdown, convert to attributed string.
        func loadContent(pageId: String, format: String, theme: EpistemosTheme) {
            currentPageId = pageId
            currentFormat = format
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
                let attrStr = Self.markdownToAttributedString(markdown, theme: theme)
                ts.setAttributedString(attrStr)
            }
            textView?.rethemeContent(to: theme)
            currentTheme = theme
            lastPersistedHash = Self.contentHash(ts)
            Self.applyWikilinkAttributes(to: ts)
            scheduleDataDetection()
            emitTocItems()
        }

        func refreshTheme(_ theme: EpistemosTheme) {
            guard currentTheme != theme else { return }
            textView?.rethemeContent(to: theme)
            currentTheme = theme
        }

        /// Simple markdown -> attributed string conversion for opening notes in doc mode.
        private static func markdownToAttributedString(
            _ markdown: String,
            theme: EpistemosTheme
        ) -> NSAttributedString {
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
                    .foregroundColor: NSColor(theme.foreground),
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
            guard !isFlushingTokens else { return }
            debouncedSave()
            scheduleWikilinkDetection()
            scheduleDataDetection()
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
            let currentHash = Self.contentHash(ts)
            guard currentHash != lastPersistedHash else { return }
            persistContent(pageId: currentPageId)
        }

        /// Hash that captures both text AND attributes so formatting-only edits are detected.
        private static func contentHash(_ storage: NSTextStorage) -> Int {
            var hasher = Hasher()
            hasher.combine(storage.string)
            let fullRange = NSRange(location: 0, length: storage.length)
            guard fullRange.length > 0 else { return hasher.finalize() }
            storage.enumerateAttributes(in: fullRange) { attrs, range, _ in
                hasher.combine(range.location)
                hasher.combine(range.length)
                for (key, value) in attrs {
                    hasher.combine(key.rawValue)
                    hasher.combine("\(value)")
                }
            }
            return hasher.finalize()
        }

        private func persistContent(pageId: String) {
            guard let ts = textView?.textStorage else { return }
            let content = NSAttributedString(attributedString: ts)
            currentFormat = "richtext"
            lastPersistedHash = Self.contentHash(ts)

            // File-write-first ordering: RTFD must exist before model promotion + notification.
            NoteFileStorage.writeRichText(pageId: pageId, content: content)

            Task { @MainActor [weak self] in
                self?.markPageDirty(pageId: pageId)
                NoteFileStorage.notifyBodyChanged(pageId: pageId)
            }

            emitTocItems()
        }

        // MARK: - Wikilink Detection

        private func scheduleWikilinkDetection() {
            wikilinkTask?.cancel()
            wikilinkTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(300))
                guard let self, !Task.isCancelled else { return }
                guard let ts = self.textView?.textStorage else { return }
                Self.applyWikilinkAttributes(to: ts)
            }
        }

        static func applyWikilinkAttributes(to storage: NSTextStorage) {
            let text = storage.string as NSString
            let fullRange = NSRange(location: 0, length: text.length)
            guard fullRange.length > 0 else { return }

            // Clear old wikilink links AND restore bracket foreground color
            storage.enumerateAttribute(.link, in: fullRange) { value, range, _ in
                if let str = value as? String, str.hasPrefix("wikilink://") {
                    storage.removeAttribute(.link, range: range)
                }
            }
            // Reset any tertiaryLabelColor ranges left from previous bracket dimming
            storage.enumerateAttribute(.foregroundColor, in: fullRange) { value, range, _ in
                if let color = value as? NSColor, color == NSColor.tertiaryLabelColor {
                    storage.removeAttribute(.foregroundColor, range: range)
                }
            }

            let pattern = "\\[\\[([^\\]]+)\\]\\]"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let matches = regex.matches(in: text as String, range: fullRange)
            guard !matches.isEmpty else { return }

            storage.beginEditing()
            for match in matches {
                guard match.numberOfRanges >= 2 else { continue }
                let innerRange = match.range(at: 1)
                let title = text.substring(with: innerRange)
                storage.addAttribute(.link, value: "wikilink://\(title)", range: innerRange)

                let openRange = NSRange(location: match.range.location, length: 2)
                let closeRange = NSRange(location: NSMaxRange(innerRange), length: 2)
                storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: openRange)
                storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: closeRange)
            }
            storage.endEditing()
        }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            guard let urlString = link as? String else { return false }
            if urlString.hasPrefix("wikilink://") {
                let title = String(urlString.dropFirst("wikilink://".count))
                onWikilinkClick?(title)
                return true
            }
            return false
        }

        // MARK: - AI Chat Streaming

        func startNoteChatStream(_ query: String) {
            guard let ts = textView?.textStorage else { return }
            isFlushingTokens = true
            ts.replaceCharacters(
                in: NSRange(location: ts.length, length: 0),
                with: Self.aiDivider
            )
            isFlushingTokens = false
            textView?.scrollRangeToVisible(NSRange(location: ts.length, length: 0))
        }

        func appendNoteChatTokens(_ delta: String) {
            guard let ts = textView?.textStorage else { return }
            isFlushingTokens = true
            ts.replaceCharacters(
                in: NSRange(location: ts.length, length: 0),
                with: delta
            )
            isFlushingTokens = false
            textView?.scrollRangeToVisible(NSRange(location: ts.length, length: 0))
        }

        func acceptNoteChatResponse() {
            guard let ts = textView?.textStorage else { return }
            let str = ts.string
            guard let swiftRange = str.range(of: Self.aiDivider, options: .backwards) else { return }
            let nsRange = NSRange(swiftRange, in: str)
            ts.replaceCharacters(in: nsRange, with: "\n\n")
            debouncedSave()
        }

        func discardNoteChatResponse() {
            guard let ts = textView?.textStorage else { return }
            let str = ts.string
            guard let swiftRange = str.range(of: Self.aiDivider, options: .backwards) else { return }
            let nsRange = NSRange(swiftRange, in: str)
            let deleteRange = NSRange(location: nsRange.location, length: ts.length - nsRange.location)
            ts.replaceCharacters(in: deleteRange, with: "")
        }

        // MARK: - Data Detection

        private func scheduleDataDetection() {
            dataDetectionTask?.cancel()
            dataDetectionTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                guard let ts = self.textView?.textStorage else { return }
                let text = ts.string
                let isDark = self.currentTheme?.isDark ?? false
                let fullRange = NSRange(location: 0, length: ts.length)

                // Clear old detection attributes
                ts.beginEditing()
                ts.enumerateAttribute(DataDetectionService.detectedDataKey, in: fullRange) { val, range, _ in
                    guard val != nil else { return }
                    ts.removeAttribute(DataDetectionService.detectedDataKey, range: range)
                    ts.removeAttribute(.underlineStyle, range: range)
                    ts.removeAttribute(.underlineColor, range: range)
                }
                ts.endEditing()

                let items = DataDetectionService.detect(in: text)
                guard !items.isEmpty else { return }
                ts.beginEditing()
                DataDetectionService.styleDetectedRanges(in: ts, items: items, isDark: isDark)
                ts.endEditing()
            }
        }

        // MARK: - TOC

        private func emitTocItems() {
            guard let ts = textView?.textStorage else { return }
            let items = TOCParser.parseRichText(ts)
            Task { @MainActor [weak self] in
                self?.onTocChanged?(items)
            }
        }

        @MainActor private func markPageDirty(pageId: String) {
            let desc = FetchDescriptor<SDPage>(
                predicate: #Predicate<SDPage> { $0.id == pageId }
            )
            if let page = try? modelContext.fetch(desc).first {
                // Promote markdown → richtext on first document-mode save
                if page.format != "richtext" {
                    page.format = "richtext"
                }
                page.needsVaultSync = true
                page.updatedAt = .now
                // Write plain-text mirror so loadBody(), search index, and vault sync stay current
                if let ts = textView?.textStorage {
                    let plainText = ts.string
                    page.wordCount = plainText.split(separator: " ").count
                    NoteFileStorage.writeBody(pageId: pageId, content: plainText)
                    BlockMirror.sync(pageId: pageId, body: plainText, modelContext: modelContext)
                }
                try? modelContext.save()
            }
        }
    }
}
