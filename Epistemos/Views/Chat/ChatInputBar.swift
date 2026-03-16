import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Chat Input Bar
// Bottom input bar for the conversation view.
// Uses a stacked native-style composer: multiline text area on the first row,
// controls on the second row, all inside a rounded-rect material surface.

enum MainChatComposerLayout {
    static let horizontalPadding: CGFloat = 14
    static let topPadding: CGFloat = 12
    static let bottomPadding: CGFloat = 10
    static let controlRowSpacing: CGFloat = 6
    static let controlRowTopPadding: CGFloat = 8
}

struct ChatInputBar: View {
    let onSubmit: (String) -> Void
    let onStop: () -> Void
    let isProcessing: Bool

    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat

    @State private var text = ""
    @State private var isFocused = false
    @State private var composerHeight = ChatComposerInputMetrics.minHeight

    // Notes Mode @-mention dropdown
    @State private var showMentionDropdown = false
    @State private var mentionFilter = ""

    private var theme: EpistemosTheme { ui.theme }
    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private let composerMetrics = AssistantComposerMetrics.mainChat
    private var composerIsActive: Bool {
        isFocused || !trimmedText.isEmpty || isProcessing || !chat.pendingAttachments.isEmpty
    }
    private var placeholderText: String {
        chat.isResearchMode ? "Ask a research question…" : "Ask anything…"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Pending attachments preview — collapsed to 0 height when empty
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(chat.pendingAttachments) { att in
                        HStack(spacing: 4) {
                            Image(systemName: iconForType(att.type))
                                .font(.epSmall)
                            Text(att.name)
                                .font(.epSmall)
                                .lineLimit(1)
                            Button {
                                chat.removeAttachment(att.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.epSmall)
                                    .foregroundStyle(theme.mutedForeground.opacity(0.5))
                            }
                            .buttonStyle(NativeToolbarButtonStyle())
                            .accessibilityLabel("Remove attachment")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .glassEffect(.regular.interactive(), in: Capsule())
                        .foregroundStyle(theme.mutedForeground.opacity(0.7))
                    }
                }
                .padding(.horizontal, MainChatComposerLayout.horizontalPadding)
                .padding(.top, 6)
                .padding(.bottom, 4)
            }
            .frame(height: chat.pendingAttachments.isEmpty ? 0 : nil)
            .clipped()
            .animation(Motion.quick, value: chat.pendingAttachments.count)

            VStack(alignment: .leading, spacing: 0) {
                composerTextArea

                HStack(alignment: .center, spacing: MainChatComposerLayout.controlRowSpacing) {
                    ToolbarMorphHost(style: .composerControls, baseSurface: .none) {
                        HStack(spacing: MainChatComposerLayout.controlRowSpacing) {
                            attachButton

                            ResearchModeControl(
                                variant: .toolbar,
                                toggleMorphID: MainChatToolbarMorphID.research.rawValue,
                                optionsMorphID: MainChatToolbarMorphID.researchOptions.rawValue
                            )
                            .disabled(isProcessing)

                            incognitoButton
                        }
                    }

                    Spacer(minLength: 0)

                    sendButton
                }
                .padding(.top, MainChatComposerLayout.controlRowTopPadding)
            }
            .padding(.horizontal, MainChatComposerLayout.horizontalPadding)
            .padding(.top, MainChatComposerLayout.topPadding)
            .padding(.bottom, MainChatComposerLayout.bottomPadding)
        }
        .assistantComposerChrome(
            theme: theme,
            metrics: composerMetrics,
            isActive: composerIsActive
        )
        .overlay(alignment: .topLeading) {
            // Notes Mode @-mention dropdown — floats above the input bar
            if showMentionDropdown, let manifest = AppBootstrap.shared?.ambientManifest {
                NotesMentionDropdown(
                    entries: manifest.entries,
                    filter: mentionFilter,
                    onSelect: insertMention
                )
                .frame(maxWidth: 320)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: -2)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .offset(y: -8)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, ChatLayout.mainComposerHorizontalPadding)
        .padding(.bottom, Spacing.md)
        .frame(maxWidth: ChatLayout.mainComposerMaxWidth)
        .frame(maxWidth: .infinity)
    }

    private var composerTextArea: some View {
        ZStack(alignment: .topLeading) {
            ChatComposerTextEditor(
                text: $text,
                height: $composerHeight,
                isFocused: $isFocused,
                theme: theme,
                isProcessing: isProcessing
            ) {
                submitCurrentText()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: composerHeight)
            .accessibilityLabel("Message input")
            .accessibilityHint(
                isProcessing
                    ? "You can keep typing while the current response finishes. Press stop to cancel."
                    : "Type a question or command. Press Shift-Enter for a new line."
            )

            if text.isEmpty {
                Text(placeholderText)
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .foregroundStyle(theme.mutedForeground.opacity(0.55))
                    .padding(.top, ChatComposerInputMetrics.placeholderTopPadding)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: ChatComposerInputMetrics.minHeight, alignment: .topLeading)
        .layoutPriority(1)
        .onChange(of: text) { _, newVal in
            if AppBootstrap.shared?.ambientManifest != nil {
                if let atIdx = newVal.lastIndex(of: "@") {
                    let afterAt = String(newVal[newVal.index(after: atIdx)...])
                    if !afterAt.contains("]") {
                        mentionFilter = afterAt
                        if !showMentionDropdown { showMentionDropdown = true }
                        return
                    }
                }
                if showMentionDropdown { showMentionDropdown = false }
            }
        }
    }

    private var attachButton: some View {
        ToolbarCapsuleButton(
            title: nil,
            systemImage: "plus",
            variant: .toolbar,
            helpText: "Attach File",
            accessibilityLabel: "Attach file",
            morphID: MainChatToolbarMorphID.attach.rawValue
        ) {
            openFilePicker()
        }
        .accessibilityHint("Open file picker to attach a document")
        .disabled(isProcessing)
    }

    private var incognitoButton: some View {
        ExpandingModeButton(
            title: "Incognito",
            systemImage: chat.isIncognito ? "eye.slash.fill" : "eye.slash",
            isActive: chat.isIncognito,
            variant: .toolbar,
            helpText: chat.isIncognito
                ? "Incognito On — chat won't be saved"
                : "Enable Incognito",
            stableWidth: NativeControlSystem.reservedWidth(
                for: "Incognito",
                variant: .toolbar
            ),
            morphID: MainChatToolbarMorphID.incognito.rawValue
        ) {
            withAnimation(Motion.quick) { chat.isIncognito.toggle() }
        }
        .accessibilityLabel(chat.isIncognito ? "Incognito mode on" : "Incognito mode off")
        .disabled(isProcessing)
    }

    private var sendButton: some View {
        AssistantSendButton(
            theme: theme,
            isEnabled: !trimmedText.isEmpty,
            isProcessing: isProcessing,
            metrics: composerMetrics
        ) {
            if isProcessing {
                onStop()
            } else {
                submitCurrentText()
            }
        }
        .help(isProcessing ? "Stop" : "Send")
        .accessibilityLabel(isProcessing ? "Stop generating" : "Send message")
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.pdf, .plainText, .png, .jpeg, .json, .commaSeparatedText]
        panel.begin { response in
            guard response == .OK else { return }
            let urls = panel.urls
            Task { @MainActor in
                let attachments = await FileAttachmentBuilder.buildAll(from: urls)
                for attachment in attachments {
                    chat.addAttachment(attachment)
                }
            }
        }
    }

    private func iconForType(_ type: AttachmentType) -> String {
        switch type {
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .csv: return "tablecells"
        case .text: return "doc.text"
        case .other: return "paperclip"
        }
    }

    private func submitCurrentText() {
        guard !trimmedText.isEmpty, !isProcessing else { return }
        onSubmit(trimmedText)
        text = ""
        composerHeight = ChatComposerInputMetrics.minHeight
        showMentionDropdown = false
        mentionFilter = ""
    }

    private func insertMention(_ entry: VaultManifest.ManifestEntry) {
        // Replace the @filter text with @[Title]
        if let atIdx = text.lastIndex(of: "@") {
            text = String(text[text.startIndex..<atIdx]) + "@[\(entry.title)] "
        }
        showMentionDropdown = false
        mentionFilter = ""
    }
}

enum ChatComposerReturnBehavior: Equatable {
    case submit
    case insertNewline
    case systemDefault
    case ignore
}

enum ChatComposerKeyHandling {
    static func isReturnCommand(_ commandSelector: Selector) -> Bool {
        commandSelector == #selector(NSResponder.insertNewline(_:))
            || commandSelector == #selector(NSResponder.insertLineBreak(_:))
    }

    static func returnBehavior(
        modifierFlags: NSEvent.ModifierFlags,
        trimmedText: String,
        isProcessing: Bool
    ) -> ChatComposerReturnBehavior {
        let flags = modifierFlags.intersection(.deviceIndependentFlagsMask)
        let normalizedText = trimmedText.trimmingCharacters(in: .whitespacesAndNewlines)

        if flags == [.shift] {
            return .insertNewline
        }
        if flags.isEmpty {
            return (!normalizedText.isEmpty && !isProcessing) ? .submit : .ignore
        }
        return .systemDefault
    }
}

enum ChatComposerInputMetrics {
    static let fontSize: CGFloat = 15
    static let maxVisibleLines = 8
    static let verticalInset: CGFloat = 5
    static let placeholderTopPadding: CGFloat = 6
    static let lineHeight = ceil(
        NSLayoutManager().defaultLineHeight(for: NSFont.systemFont(ofSize: fontSize))
    )
    static let minHeight = lineHeight + (verticalInset * 2)
    static let maxHeight = (lineHeight * CGFloat(maxVisibleLines)) + (verticalInset * 2)

    static func clampedHeight(for contentHeight: CGFloat) -> CGFloat {
        min(max(contentHeight, minHeight), maxHeight)
    }
}

struct ChatComposerTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    @Binding var isFocused: Bool

    let theme: EpistemosTheme
    let isProcessing: Bool
    let onSubmit: () -> Void

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
        textView.minSize = NSSize(width: 0, height: ChatComposerInputMetrics.minHeight)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 0, height: ChatComposerInputMetrics.verticalInset)
        textView.allowsUndo = true
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
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

        init(parent: ChatComposerTextEditor) {
            self.parent = parent
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.isFocused = true
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.isFocused = false
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? ChatComposerNativeTextView else { return }
            if parent.text != textView.string {
                parent.text = textView.string
            }
            updateHeight(for: textView)
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard ChatComposerKeyHandling.isReturnCommand(commandSelector) else { return false }

            let behavior = ChatComposerKeyHandling.returnBehavior(
                modifierFlags: NSApp.currentEvent?.modifierFlags ?? [],
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
            textView.font = NSFont.systemFont(ofSize: ChatComposerInputMetrics.fontSize)
            textView.textColor = NSColor(theme.foreground)
            textView.insertionPointColor = NSColor(theme.foreground)
        }

        func updateHeight(for textView: ChatComposerNativeTextView) {
            guard
                let textContainer = textView.textContainer,
                let layoutManager = textView.layoutManager
            else { return }

            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let contentHeight = ceil(usedRect.height + (textView.textContainerInset.height * 2))
            let clampedHeight = ChatComposerInputMetrics.clampedHeight(for: contentHeight)

            if parent.height != clampedHeight {
                parent.height = clampedHeight
            }

            textView.enclosingScrollView?.hasVerticalScroller =
                contentHeight > (ChatComposerInputMetrics.maxHeight + 0.5)
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
        await withTaskGroup(of: (Int, FileAttachment).self, returning: [FileAttachment].self) {
            group in
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
        guard
            let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int
        else {
            return 0
        }
        return size
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
        guard let data = try? previewData(for: url) else { return nil }
        guard !data.isEmpty else { return nil }

        let preview = String(decoding: data, as: UTF8.self)
        guard preview.count > maxPreviewCharacters else { return preview }
        return String(preview.prefix(maxPreviewCharacters)) + "\n...(truncated)"
    }

    private nonisolated static func previewData(for url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        return try handle.read(upToCount: maxPreviewBytes) ?? Data()
    }
}

// MARK: - Provider Badge

/// Compact badge showing the active LLM provider with brand icon + name + color.
private struct ProviderBadge: View {
    let provider: LLMProviderType

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: provider.iconName)
                .font(.epSmall)
                .fontWeight(.semibold)
            Text(provider.displayName)
                .font(.epSmall)
                .fontWeight(.bold)
                .textCase(.uppercase)
                .tracking(0.3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(provider.badgeColor.opacity(0.12)))
        .foregroundStyle(provider.badgeColor)
    }
}
