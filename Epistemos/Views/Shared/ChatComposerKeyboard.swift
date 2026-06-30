import AppKit
import SwiftUI

@MainActor
final class ChatRecallDebounceBox {
    var task: Task<Void, Never>?
}

enum ChatComposerReturnBehavior: Equatable {
    case submit
    case insertNewline
    case systemDefault
    case ignore
}

enum ChatComposerOverlayCommand: Equatable {
    case moveDown
    case moveUp
    case confirm
    case cancel
}

enum MainChatComposerLayout {
    static let horizontalPadding: CGFloat = 11
    static let topPadding: CGFloat = 9
    static let bottomPadding: CGFloat = 7
    static let controlRowSpacing: CGFloat = 4
    static let controlRowTopPadding: CGFloat = 6
}

enum ChatComposerKeyHandling {
    static func isReturnCommand(_ commandSelector: Selector) -> Bool {
        commandSelector == #selector(NSResponder.insertNewline(_:))
            || commandSelector == #selector(NSResponder.insertLineBreak(_:))
    }

    static func overlayCommand(
        for commandSelector: Selector,
        modifierFlags: NSEvent.ModifierFlags
    ) -> ChatComposerOverlayCommand? {
        let flags = semanticModifierFlags(modifierFlags)
        guard flags.isEmpty else { return nil }

        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            return .moveDown
        }
        if commandSelector == #selector(NSResponder.moveUp(_:)) {
            return .moveUp
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            return .cancel
        }
        if isReturnCommand(commandSelector) {
            return .confirm
        }
        return nil
    }

    static func returnBehavior(
        modifierFlags: NSEvent.ModifierFlags,
        trimmedText: String,
        isProcessing: Bool
    ) -> ChatComposerReturnBehavior {
        let flags = semanticModifierFlags(modifierFlags)
        let normalizedText = trimmedText.trimmingCharacters(in: .whitespacesAndNewlines)

        if flags == [.shift] {
            return .insertNewline
        }
        if flags.isEmpty {
            return (!normalizedText.isEmpty && !isProcessing) ? .submit : .ignore
        }
        return .systemDefault
    }

    static func semanticModifierFlags(_ modifierFlags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        var flags = modifierFlags.intersection(.deviceIndependentFlagsMask)
        flags.remove(.numericPad)
        flags.remove(.function)
        return flags
    }
}

enum ChatComposerInputMetrics {
    static let fontSize: CGFloat = 14
    static let maxVisibleLines = 8
    static let horizontalInset: CGFloat = 10
    static let verticalInset: CGFloat = 4
    static let placeholderTopPadding: CGFloat = 4
    static let minimumHeightPadding: CGFloat = 4
    static let lineHeight = lineHeight(for: fontSize)
    static let minHeight = minHeight(for: fontSize)
    static let maxHeight = maxHeight(for: fontSize)

    static func lineHeight(for fontSize: CGFloat) -> CGFloat {
        let font = NSFont.systemFont(ofSize: fontSize)
        return ceil(font.ascender - font.descender + font.leading)
    }

    static func minHeight(for fontSize: CGFloat) -> CGFloat {
        lineHeight(for: fontSize) + (verticalInset * 2) + minimumHeightPadding
    }

    static func maxHeight(for fontSize: CGFloat) -> CGFloat {
        (lineHeight(for: fontSize) * CGFloat(maxVisibleLines)) + (verticalInset * 2)
    }

    static func clampedHeight(for contentHeight: CGFloat) -> CGFloat {
        clampedHeight(for: contentHeight, fontSize: fontSize)
    }

    static func clampedHeight(for contentHeight: CGFloat, fontSize: CGFloat) -> CGFloat {
        min(max(contentHeight, minHeight(for: fontSize)), maxHeight(for: fontSize))
    }
}

nonisolated enum FileAttachmentDiagnostics {
    static let maxLogMessageCharacters = 240

    static func logMessage(for error: Error, fallback: String) -> String {
        let nsError = error as NSError
        return logMessage(
            "\(fallback) (domain=\(safeDomain(nsError.domain)) code=\(nsError.code))",
            fallback: fallback
        )
    }

    static func logMessage(_ message: String, fallback: String = "File attachment operation failed") -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        guard trimmed.count > maxLogMessageCharacters else { return trimmed }

        let suffix = "..."
        let end = trimmed.index(
            trimmed.startIndex,
            offsetBy: max(0, maxLogMessageCharacters - suffix.count)
        )
        return String(trimmed[..<end]) + suffix
    }

    private static func safeDomain(_ domain: String) -> String {
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Error" }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return "Error"
        }
        guard trimmed.count <= 80 else {
            let end = trimmed.index(trimmed.startIndex, offsetBy: 80)
            return String(trimmed[..<end])
        }
        return trimmed
    }
}

struct ChatComposerTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    @Binding var isFocused: Bool

    let theme: EpistemosTheme
    let fontSize: CGFloat
    let isProcessing: Bool
    let onCommand: ((Selector, NSEvent.ModifierFlags) -> Bool)?
    let onSubmit: () -> Void

    init(
        text: Binding<String>,
        height: Binding<CGFloat>,
        isFocused: Binding<Bool>,
        theme: EpistemosTheme,
        fontSize: CGFloat = ChatComposerInputMetrics.fontSize,
        isProcessing: Bool,
        onCommand: ((Selector, NSEvent.ModifierFlags) -> Bool)? = nil,
        onSubmit: @escaping () -> Void
    ) {
        _text = text
        _height = height
        _isFocused = isFocused
        self.theme = theme
        self.fontSize = fontSize
        self.isProcessing = isProcessing
        self.onCommand = onCommand
        self.onSubmit = onSubmit
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView(frame: .zero)
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        scrollView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let textView = ChatComposerNativeTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.string = text
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.minSize = NSSize(width: 0, height: ChatComposerInputMetrics.minHeight(for: fontSize))
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(
            width: ChatComposerInputMetrics.horizontalInset,
            height: ChatComposerInputMetrics.verticalInset
        )
        textView.allowsUndo = true
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.onWidthChange = { [weak textView] in
            guard let textView else { return }
            context.coordinator.updateHeight(for: textView)
        }

        context.coordinator.applyTheme(theme, to: textView)
        scrollView.documentView = textView
        context.coordinator.updateHeight(for: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? ChatComposerNativeTextView else { return }

        if textView.string != text {
            textView.string = text
        }

        context.coordinator.applyTheme(theme, to: textView)
        context.coordinator.updateHeight(for: textView)

        guard let window = textView.window else { return }
        if isFocused, window.firstResponder !== textView {
            window.makeFirstResponder(textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ChatComposerTextEditor
        private var pendingHeight: CGFloat?

        init(parent: ChatComposerTextEditor) {
            self.parent = parent
        }

        func textDidBeginEditing(_ notification: Notification) {
            DispatchQueue.main.async { [weak self] in
                self?.parent.isFocused = true
            }
        }

        func textDidEndEditing(_ notification: Notification) {
            DispatchQueue.main.async { [weak self] in
                self?.parent.isFocused = false
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? ChatComposerNativeTextView else { return }
            let newText = textView.string
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.parent.text != newText {
                    self.parent.text = newText
                }
            }
            updateHeight(for: textView)
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            let modifierFlags = NSApp.currentEvent?.modifierFlags ?? []
            if parent.onCommand?(commandSelector, modifierFlags) == true {
                return true
            }

            guard ChatComposerKeyHandling.isReturnCommand(commandSelector) else { return false }

            let behavior = ChatComposerKeyHandling.returnBehavior(
                modifierFlags: modifierFlags,
                trimmedText: parent.text.trimmingCharacters(in: .whitespacesAndNewlines),
                isProcessing: parent.isProcessing
            )

            switch behavior {
            case .submit:
                parent.onSubmit()
                return true
            case .ignore:
                return true
            case .insertNewline, .systemDefault:
                return false
            }
        }

        func applyTheme(_ theme: EpistemosTheme, to textView: ChatComposerNativeTextView) {
            textView.font = NSFont.systemFont(ofSize: parent.fontSize)
            textView.textColor = NSColor(theme.resolved.foreground.color)
            textView.insertionPointColor = NSColor(theme.resolved.foreground.color)
        }

        func updateHeight(for textView: ChatComposerNativeTextView) {
            guard
                let textContainer = textView.textContainer,
                let layoutManager = textView.layoutManager
            else { return }

            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let contentHeight = ceil(usedRect.height + (textView.textContainerInset.height * 2))
            let clampedHeight = ChatComposerInputMetrics.clampedHeight(
                for: contentHeight,
                fontSize: parent.fontSize
            )

            if abs(parent.height - clampedHeight) > 0.5, pendingHeight != clampedHeight {
                pendingHeight = clampedHeight
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    if abs(self.parent.height - clampedHeight) > 0.5 {
                        self.parent.height = clampedHeight
                    }
                    self.pendingHeight = nil
                }
            }

            textView.enclosingScrollView?.hasVerticalScroller =
                contentHeight > (ChatComposerInputMetrics.maxHeight(for: parent.fontSize) + 0.5)
        }
    }
}

final class ChatComposerNativeTextView: NSTextView {
    var onWidthChange: (() -> Void)?

    override func setFrameSize(_ newSize: NSSize) {
        let widthChanged = abs(frame.size.width - newSize.width) > 0.5
        super.setFrameSize(newSize)
        if widthChanged {
            onWidthChange?()
        }
    }
}

enum FileAttachmentBuilder {
    nonisolated static let maxPreviewBytes = 262_144
    nonisolated static let maxPreviewCharacters = 2_000

    nonisolated static func buildAll(from urls: [URL]) async -> [FileAttachment] {
        await withTaskGroup(of: (Int, FileAttachment).self, returning: [FileAttachment].self) { group in
            for (index, url) in urls.enumerated() {
                group.addTask {
                    (index, await build(from: url))
                }
            }

            var ordered: [(Int, FileAttachment)] = []
            ordered.reserveCapacity(urls.count)
            for await result in group {
                ordered.append(result)
            }
            ordered.sort { $0.0 < $1.0 }
            return ordered.map(\.1)
        }
    }

    nonisolated static func build(from url: URL) async -> FileAttachment {
        await Task.detached(priority: .utility) {
            buildSync(from: url)
        }.value
    }

    private nonisolated static func buildSync(from url: URL) -> FileAttachment {
        let gainedSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if gainedSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let size = fileSize(for: url)
        let (type, mimeType) = classify(pathExtension: ext)
        let preview = previewText(for: url, type: type, size: size)

        return FileAttachment(
            id: UUID().uuidString,
            name: name,
            type: type,
            uri: url.absoluteString,
            size: size,
            mimeType: mimeType,
            preview: preview
        )
    }

    private nonisolated static func fileSize(for url: URL) -> Int {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let size = attributes[.size] as? Int else {
                Log.pipeline.error(
                    "FileAttachmentBuilder: missing file size attribute for \(url.lastPathComponent, privacy: .public)"
                )
                return 0
            }
            return size
        } catch {
            let message = FileAttachmentDiagnostics.logMessage(
                for: error,
                fallback: "FileAttachmentBuilder: failed to read file size"
            )
            Log.pipeline.error(
                "\(message, privacy: .public)"
            )
            return 0
        }
    }

    private nonisolated static func classify(pathExtension ext: String) -> (AttachmentType, String) {
        switch ext {
        case "png", "jpg", "jpeg", "gif", "webp", "heic":
            return (.image, "image/\(ext == "jpg" ? "jpeg" : ext)")
        case "pdf":
            return (.pdf, "application/pdf")
        case "csv":
            return (.csv, "text/csv")
        case "txt", "md", "swift", "ts", "js", "py", "json":
            return (.text, "text/plain")
        default:
            return (.other, "application/octet-stream")
        }
    }

    private nonisolated static func previewText(for url: URL, type: AttachmentType, size: Int) -> String? {
        guard type == .text || type == .csv else { return nil }
        guard size > 0, size <= maxPreviewBytes else { return nil }
        let data: Data
        do {
            data = try previewData(for: url)
        } catch {
            let message = FileAttachmentDiagnostics.logMessage(
                for: error,
                fallback: "FileAttachmentBuilder: failed to read preview"
            )
            Log.pipeline.error(
                "\(message, privacy: .public)"
            )
            return nil
        }
        guard !data.isEmpty else { return nil }

        guard let preview = FoundationSafety.decodedText(from: data) else { return nil }
        guard preview.count > maxPreviewCharacters else { return preview }
        return String(preview.prefix(maxPreviewCharacters)) + "\n...(truncated)"
    }

    private nonisolated static func previewData(for url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            do {
                try handle.close()
            } catch {
                let message = FileAttachmentDiagnostics.logMessage(
                    for: error,
                    fallback: "FileAttachmentBuilder: failed to close preview handle"
                )
                Log.pipeline.error(
                    "\(message, privacy: .public)"
                )
            }
        }
        return try handle.read(upToCount: maxPreviewBytes) ?? Data()
    }
}
