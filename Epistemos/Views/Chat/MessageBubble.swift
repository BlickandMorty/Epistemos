import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Message Rating

private enum MessageRating { case up, down }

/// Strips non-epistemic bracket tags (e.g. [CAUSAL INFERENCE]) from response text.
/// Preserves [DATA], [MODEL], [UNCERTAIN], [CONFLICT] for TaggedMarkdownTextView.
private func stripBracketTags(_ text: String) -> String {
    text.replacingOccurrences(of: "\\[[A-Z][A-Z ]+\\]", with: "", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Full Export Builder

private func buildFullExport(message: ChatMessage) -> String {
    UserFacingModelOutput.finalVisibleText(from: stripBracketTags(message.content))
}

// MARK: - Assistant Transcript Chrome

struct AssistantTranscriptChrome<Content: View>: View {
    @Environment(UIState.self) private var ui

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        if theme.assistantBubbleBackgroundHex != nil {
            content
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    theme.assistantBubbleBackground,
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(theme.border.opacity(0.85), lineWidth: 0.8)
                )
        } else {
            content
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    let originalQuery: String?
    let displayContent: String
    let heading: String?
    let sourceReferences: [AssistantSourceReference]
    let allowsResubmit: Bool
    let onResubmit: (String) -> Void

    @Environment(UIState.self) private var ui
    @State private var copied = false
    @State private var isHovered = false
    @State private var rating: MessageRating? = nil

    private var theme: EpistemosTheme { ui.theme }
    private var isUser: Bool { message.role == .user }

    private var contextAttachments: [ContextAttachment] {
        message.contextAttachments ?? []
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if isUser { Spacer(minLength: 200) }

            if isUser {
                userBubble
            } else if message.isError {
                errorBubble
            } else {
                assistantBubble
            }

            // No right spacer for assistant messages — content fills the 760px column
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    // MARK: - User Bubble

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: Spacing.xs) {
            TaggedMarkdownTextView(
                content: displayContent,
                theme: theme,
                rippleStyle: .none,
                foregroundOverride: theme.userBubbleText
            )
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(theme.userBubbleBg, in: UserBubbleShape())

            if !contextAttachments.isEmpty {
                ContextAttachmentBadgeRow(attachments: contextAttachments, alignment: .trailing)
            }

            if !message.attachments.isEmpty {
                HStack(spacing: 6) {
                    ForEach(message.attachments) { att in
                        AttachmentBadge(attachment: att)
                    }
                }
            }
        }
    }

    // MARK: - Error Bubble

    private var errorBubble: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.epTitle)
                .foregroundStyle(theme.error)
                .frame(width: 28, height: 28)

            Text(message.content)
                .font(.epBody)
                .foregroundStyle(theme.error)
                .textSelection(.enabled)
                .padding(Spacing.md)
                .background(theme.error.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(theme.error.opacity(0.2), lineWidth: 1)
                )
        }
    }

    private var assistantBubble: some View {
        AssistantTranscriptChrome {
            VStack(alignment: .leading, spacing: Spacing.md) {
            // Vault briefing header — Notes Mode auto-briefing indicator
                if message.isVaultBriefing {
                    HStack(spacing: 6) {
                        Image(systemName: "book.pages.fill")
                            .font(.epCaption)
                            .foregroundStyle(theme.resolved.accent.color)
                        Text("Vault Briefing")
                            .font(.epCaption)
                            .foregroundStyle(theme.resolved.accent.color)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(theme.resolved.accent.color.opacity(0.1), in: Capsule())
                }

                // Response heading — auto-extracted topic
                if let heading {
                    Text(heading)
                        .font(AppHeadingRole.h2.font)
                        .foregroundStyle(theme.fontAccent)
                }

                TaggedMarkdownTextView(content: displayContent, theme: theme)

                if !contextAttachments.isEmpty {
                    ContextAttachmentBadgeRow(attachments: contextAttachments)
                }

                AssistantSourcesFooter(sources: sourceReferences, theme: theme, style: .popoverPanel)

                // Toolbar — always rendered at fixed height, opacity-only transition
                MessageToolbar(
                    message: message,
                    originalQuery: originalQuery,
                    allowsResubmit: allowsResubmit,
                    onResubmit: onResubmit,
                    copied: $copied,
                    rating: $rating
                )
                .opacity(isHovered ? 1 : 0)
                .animation(Motion.quick, value: isHovered)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

// MARK: - User Bubble Shape

private struct UserBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 20
        let smallR: CGFloat = 6
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r,
            startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.addArc(
            center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r,
            startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        path.addArc(
            center: CGPoint(x: rect.maxX - smallR, y: rect.maxY - smallR), radius: smallR,
            startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addArc(
            center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r,
            startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.closeSubpath()
        return path
    }
}

// MARK: - Message Toolbar

private struct MessageToolbar: View {
    let message: ChatMessage
    let originalQuery: String?
    let allowsResubmit: Bool
    let onResubmit: (String) -> Void
    @Binding var copied: Bool
    @Binding var rating: MessageRating?

    @Environment(UIState.self) private var ui
    @Environment(VaultSyncService.self) private var vaultSync
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(spacing: 8) {
            // Copy the visible answer only.
            Button {
                let fullContent = buildFullExport(message: message)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(fullContent, forType: .string)
                copied = true
                Task {
                    try? await Task.sleep(for: .milliseconds(1500))
                    copied = false
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(copied ? theme.success : .secondary)
            }
            .buttonStyle(NativeToolbarButtonStyle())
            .help(copied ? "Copied" : "Copy to clipboard")
            .accessibilityLabel(copied ? "Copied" : "Copy to clipboard")

            // Send to Notes — full export via VaultSyncService, opens the new page
            Button {
                let fullContent = buildFullExport(message: message)
                let title = extractTitle(from: message.content)
                Task {
                    if let pageId = await vaultSync.createPage(title: title, body: fullContent) {
                        NoteWindowManager.shared.open(pageId: pageId)
                    }
                }
            } label: {
                Image(systemName: "note.text.badge.plus")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(NativeToolbarButtonStyle())
            .help("Send to Notes")
            .accessibilityLabel("Send to Notes")

            // Export as .md file
            Button {
                let fullContent = buildFullExport(message: message)
                let panel = NSSavePanel()
                panel.nameFieldStringValue =
                    "message-\(ISO8601DateFormatter().string(from: message.createdAt).prefix(10)).md"
                panel.allowedContentTypes = [.plainText]
                panel.canCreateDirectories = true
                if panel.runModal() == .OK, let url = panel.url {
                    try? fullContent.write(to: url, atomically: true, encoding: .utf8)
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(NativeToolbarButtonStyle())
            .help("Export as Markdown")
            .accessibilityLabel("Export as Markdown")

            // Re-ask — resubmit the same query for a fresh analysis (hidden during streaming)
            if allowsResubmit {
                Button {
                    onResubmit(originalQuery ?? String(message.content.prefix(200)))
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(NativeToolbarButtonStyle())
                .help("Resubmit this query")
                .accessibilityLabel("Resubmit this query")
            }
        }
    }

    private func extractTitle(from text: String) -> String {
        let firstLine =
            text.components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? "Chat Export"
        let cleaned =
            firstLine
            .replacingOccurrences(of: "\\*\\*|\\*|`|^#+\\s*", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(cleaned.prefix(50))
    }
}

// MARK: - Attachment Badge

private struct AttachmentBadge: View {
    let attachment: FileAttachment

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    private var icon: String {
        switch attachment.type {
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .csv: return "tablecells"
        case .text, .other: return "paperclip"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.epSmall)
            Text(attachment.name)
                .font(.epSmall)
                .lineLimit(1)
        }
        .foregroundStyle(theme.mutedForeground.opacity(0.7))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(theme.card, in: Capsule())
    }
}

private struct ContextAttachmentBadgeRow: View {
    let attachments: [ContextAttachment]
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 0) {
            HStack(spacing: 6) {
                ForEach(attachments) { attachment in
                    ContextAttachmentBadge(attachment: attachment)
                }
            }
        }
    }
}

private struct ContextAttachmentBadge: View {
    let attachment: ContextAttachment

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    private var tint: Color {
        attachment.kind == .allNotes ? theme.resolved.accent.color : theme.mutedForeground.opacity(0.78)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: attachment.systemImageName)
                .font(.epSmall)
            Text(attachment.title)
                .font(.epSmall)
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(attachment.kind == .allNotes ? theme.resolved.accent.color.opacity(0.10) : theme.card)
        )
        .overlay {
            Capsule()
                .strokeBorder(
                    attachment.kind == .allNotes
                        ? theme.resolved.accent.color.opacity(0.18)
                        : theme.border.opacity(0.55),
                    lineWidth: 0.7
                )
        }
        .help(attachment.subtitle ?? attachment.title)
    }
}
