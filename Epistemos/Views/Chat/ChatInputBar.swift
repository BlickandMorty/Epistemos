import SwiftUI
import UniformTypeIdentifiers

// MARK: - Chat Input Bar
// Bottom input bar for the conversation view — compact single-row layout:
// paperclip + textarea (1-6 lines) + send/stop button.
// Uses Liquid Glass for the container capsule.

struct ChatInputBar: View {
    let onSubmit: (String) -> Void
    let onStop: () -> Void
    let isProcessing: Bool

    @Environment(UIState.self) private var ui
    @Environment(InferenceState.self) private var inference
    @Environment(ChatState.self) private var chat

    @State private var text = ""
    @FocusState private var isFocused: Bool

    // Notes Mode @-mention dropdown
    @State private var showMentionDropdown = false
    @State private var mentionFilter = ""

    private var theme: EpistemosTheme { ui.theme }
    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

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
                .padding(.horizontal, Spacing.lg)
                .padding(.top, 6)
                .padding(.bottom, 4)
            }
            .frame(height: chat.pendingAttachments.isEmpty ? 0 : nil)
            .clipped()
            .animation(Motion.quick, value: chat.pendingAttachments.count)

            HStack(spacing: Spacing.sm) {
                // Attach file
                Button {
                    openFilePicker()
                } label: {
                    Image(systemName: "paperclip")
                        .font(.epBody)
                        .foregroundStyle(
                            chat.pendingAttachments.isEmpty
                                ? theme.mutedForeground.opacity(0.4) : theme.accent
                        )
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(NativeToolbarButtonStyle())
                .help("Attach File")
                .accessibilityLabel("Attach file")
                .accessibilityHint("Open file picker to attach a document")
                .disabled(isProcessing)

                // Incognito toggle
                Button {
                    withAnimation(Motion.quick) { chat.isIncognito.toggle() }
                } label: {
                    Image(systemName: chat.isIncognito ? "eye.slash.fill" : "eye.slash")
                        .font(.epCaption)
                        .foregroundStyle(
                            chat.isIncognito ? theme.accent : theme.mutedForeground.opacity(0.3)
                        )
                        .frame(width: 28, height: 32)
                }
                .buttonStyle(NativeToolbarButtonStyle())
                .help(chat.isIncognito ? "Incognito On — chat won't be saved" : "Enable Incognito")
                .accessibilityLabel(chat.isIncognito ? "Incognito mode on" : "Incognito mode off")
                .disabled(isProcessing)

                // Text field — placeholder adapts to research mode
                // In research mode, hover on the empty placeholder reveals a hint + About button
                TextField(
                    isProcessing
                        ? "Generating response…"
                        : chat.isResearchMode
                            ? "Ask a research question..." : "Ask anything...",
                    text: $text,
                    axis: .vertical
                )
                .font(.epBody)
                .foregroundStyle(
                    isProcessing ? theme.mutedForeground.opacity(0.4) : theme.foreground
                )
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .focused($isFocused)
                .writingToolsBehavior(.limited)
                .accessibilityLabel("Message input")
                .accessibilityHint(
                    isProcessing
                        ? "Waiting for response. Press stop to cancel."
                        : "Type a question or command"
                )
                .disabled(isProcessing)
                .onSubmit {
                    if !trimmedText.isEmpty && !isProcessing {
                        onSubmit(trimmedText)
                        text = ""
                    }
                }
                .onChange(of: text) { _, newVal in
                    // Detect @ trigger for mention dropdown (active when vault is attached)
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
                // Send / Stop button
                if isProcessing {
                    Button(action: onStop) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(theme.error)
                    }
                    .buttonStyle(NativeToolbarButtonStyle())
                    .help("Stop")
                    .accessibilityLabel("Stop generating")
                } else if !trimmedText.isEmpty {
                    Button {
                        onSubmit(trimmedText)
                        text = ""
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(NativeToolbarButtonStyle())
                    .help("Send")
                    .accessibilityLabel("Send message")
                    .transition(.scale.combined(with: .opacity))
                    .animation(Motion.quick, value: trimmedText.isEmpty)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 10)
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.md)
        .frame(maxWidth: 860)
        .frame(maxWidth: .infinity)
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.pdf, .plainText, .png, .jpeg, .json, .commaSeparatedText]
        panel.begin { response in
            if response == .OK {
                for url in panel.urls {
                    let attachment = fileAttachment(from: url)
                    chat.addAttachment(attachment)
                }
            }
        }
    }

    private func fileAttachment(from url: URL) -> FileAttachment {
        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0

        let type: AttachmentType
        let mimeType: String
        switch ext {
        case "png", "jpg", "jpeg", "gif", "webp", "heic":
            type = .image
            mimeType = "image/\(ext == "jpg" ? "jpeg" : ext)"
        case "pdf":
            type = .pdf
            mimeType = "application/pdf"
        case "csv":
            type = .csv
            mimeType = "text/csv"
        case "txt", "md", "swift", "ts", "js", "py", "json":
            type = .text
            mimeType = "text/plain"
        default:
            type = .other
            mimeType = "application/octet-stream"
        }

        var preview: String?
        if type == .text || type == .csv {
            preview = try? String(contentsOf: url, encoding: .utf8)
            if let p = preview, p.count > 2000 {
                preview = String(p.prefix(2000)) + "\n...(truncated)"
            }
        }

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

    private func iconForType(_ type: AttachmentType) -> String {
        switch type {
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .csv: return "tablecells"
        case .text: return "doc.text"
        case .other: return "paperclip"
        }
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
