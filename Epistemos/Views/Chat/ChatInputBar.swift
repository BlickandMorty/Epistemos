import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum MainChatComposerLayout {
    static let horizontalPadding: CGFloat = 11
    static let topPadding: CGFloat = 9
    static let bottomPadding: CGFloat = 7
    static let controlRowSpacing: CGFloat = 4
    static let controlRowTopPadding: CGFloat = 6
}

// MARK: - Chat Input Bar
// Bottom input bar for the conversation view.
// Uses a stacked native-style composer: multiline text area on the first row,
// controls on the second row, all inside a rounded-rect material surface.

struct ChatInputBar: View {
    let onSubmit: (String) -> Void
    let onStop: () -> Void
    let isProcessing: Bool

    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(\.modelContext) private var modelContext

    @State private var text = ""
    @State private var isFocused = false
    @State private var composerHeight = ChatComposerInputMetrics.minHeight

    // Notes Mode @-mention dropdown
    @State private var showMentionDropdown = false
    @State private var mentionFilter = ""
    @State private var referenceSearch = ComposerReferenceSearchState()

    private var theme: EpistemosTheme { ui.theme }
    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private let composerMetrics = AssistantComposerMetrics.mainChat
    private let placeholderText = "Ask anything…"
    private var mentionSearchResults: ChatCoordinator.ReferenceSearchResults {
        ChatCoordinator.searchReferenceResults(
            filter: mentionFilter,
            manifest: AppBootstrap.shared?.ambientManifest,
            chats: recentChats(),
            threads: AppBootstrap.shared?.threadState.chatThreads ?? [],
            indexedNoteIDs: referenceSearch.indexedNoteIDs,
            indexedNoteSnippets: referenceSearch.indexedNoteSnippetsByPageID
        )
    }
    private var composerIsActive: Bool {
        isFocused || !trimmedText.isEmpty || isProcessing || !chat.pendingAttachments.isEmpty || !chat.pendingContextAttachments.isEmpty
    }
    var body: some View {
        VStack(spacing: 0) {
            // Pending attachments preview — collapsed to 0 height when empty
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(chat.pendingContextAttachments) { attachment in
                        HStack(spacing: 4) {
                            Image(systemName: attachment.systemImageName)
                                .font(.epSmall)
                            Text(attachment.title)
                                .font(.epSmall)
                                .lineLimit(1)
                            Button {
                                chat.removeContextAttachment(attachment.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.epSmall)
                                    .foregroundStyle(theme.mutedForeground.opacity(0.5))
                            }
                            .buttonStyle(NativeToolbarButtonStyle())
                            .accessibilityLabel("Remove context attachment")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .glassEffect(.regular.interactive(), in: Capsule())
                        .foregroundStyle(theme.mutedForeground.opacity(0.7))
                    }

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
            .frame(height: (chat.pendingAttachments.isEmpty && chat.pendingContextAttachments.isEmpty) ? 0 : nil)
            .clipped()
            .animation(Motion.quick, value: chat.pendingAttachments.count + chat.pendingContextAttachments.count)

            VStack(alignment: .leading, spacing: 0) {
                ComposerContextShortcutBar(
                    noteLabel: "Chat with Note",
                    vaultLabel: "Chat with Vault",
                    onChatWithNote: openNotePicker,
                    onChatWithVault: attachVaultContext
                )
                .padding(.bottom, 8)

                composerTextArea

                HStack(alignment: .center, spacing: MainChatComposerLayout.controlRowSpacing) {
                    HStack(spacing: MainChatComposerLayout.controlRowSpacing) {
                        attachButton

                        incognitoButton
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
            if showMentionDropdown {
                ComposerReferencePopover(
                    results: mentionSearchResults,
                    idealWidth: 432,
                    maxHeight: 360,
                    onSelect: attachMentionReference
                )
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
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(theme.mutedForeground.opacity(0.55))
                    .padding(.top, ChatComposerInputMetrics.placeholderTopPadding)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: ChatComposerInputMetrics.minHeight, alignment: .topLeading)
        .layoutPriority(1)
        .onChange(of: text) { _, newVal in
            if let filter = ComposerReferenceHelpers.mentionFilter(in: newVal) {
                mentionFilter = filter
                if !showMentionDropdown { showMentionDropdown = true }
                referenceSearch.update(
                    filter: filter,
                    manifest: AppBootstrap.shared?.ambientManifest,
                    vaultSync: vaultSync
                )
            } else if showMentionDropdown {
                showMentionDropdown = false
                referenceSearch.reset()
            }
        }
    }

    private var attachButton: some View {
        ToolbarCapsuleButton(
            title: nil,
            systemImage: "plus",
            variant: .toolbar,
            helpText: "Attach File",
            accessibilityLabel: "Attach file"
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
            stableWidth: NativeControlSystem.reservedWidth(for: "Incognito", variant: .toolbar)
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
        referenceSearch.reset()
    }

    private func openNotePicker() {
        mentionFilter = ""
        showMentionDropdown = true
        isFocused = true
        referenceSearch.reset()
    }

    private func attachVaultContext() {
        chat.addContextAttachment(ComposerReferenceHelpers.allNotesAttachment)
    }

    private func attachMentionReference(_ choice: ComposerReferenceChoice) {
        chat.addContextAttachment(ComposerReferenceHelpers.contextAttachment(for: choice))
        text = ComposerReferenceHelpers.removingTrailingMention(from: text)
        showMentionDropdown = false
        mentionFilter = ""
        referenceSearch.reset()
    }

    private func recentChats() -> [SDChat] {
        var descriptor = SDChat.recentChatsDescriptor
        descriptor.fetchLimit = 20
        return (try? modelContext.fetch(descriptor)) ?? []
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
    static let fontSize: CGFloat = 14
    static let maxVisibleLines = 8
    static let verticalInset: CGFloat = 4
    static let placeholderTopPadding: CGFloat = 4
    static let minimumHeightPadding: CGFloat = 4
    static let lineHeight = lineHeight(for: fontSize)
    static let minHeight = minHeight(for: fontSize)
    static let maxHeight = maxHeight(for: fontSize)

    static func lineHeight(for fontSize: CGFloat) -> CGFloat {
        ceil(NSLayoutManager().defaultLineHeight(for: NSFont.systemFont(ofSize: fontSize)))
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

struct ChatComposerTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    @Binding var isFocused: Bool

    let theme: EpistemosTheme
    let fontSize: CGFloat
    let isProcessing: Bool
    let onSubmit: () -> Void

    init(
        text: Binding<String>,
        height: Binding<CGFloat>,
        isFocused: Binding<Bool>,
        theme: EpistemosTheme,
        fontSize: CGFloat = ChatComposerInputMetrics.fontSize,
        isProcessing: Bool,
        onSubmit: @escaping () -> Void
    ) {
        _text = text
        _height = height
        _isFocused = isFocused
        self.theme = theme
        self.fontSize = fontSize
        self.isProcessing = isProcessing
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
            textView.font = NSFont.systemFont(ofSize: parent.fontSize)
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
            let clampedHeight = ChatComposerInputMetrics.clampedHeight(
                for: contentHeight,
                fontSize: parent.fontSize
            )

            if parent.height != clampedHeight {
                parent.height = clampedHeight
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
