import SwiftUI

// MARK: - Note Chat Sidebar
// Popover showing per-note chat history from NoteChatState.messages.

struct NoteChatSidebar: View {
    @Environment(NoteChatState.self) private var noteChat
    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(spacing: 0) {
            if noteChat.messages.isEmpty {
                emptyState
            } else {
                messageList
            }
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(noteChat.messages) { msg in
                        messageRow(msg)
                            .id(msg.id)
                    }
                }
                .padding(14)
            }
            .onChange(of: noteChat.messages.count) { _, _ in
                if let last = noteChat.messages.last {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func messageRow(_ msg: AssistantMessage) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(msg.role == .user ? "You" : "Assistant")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                Spacer()
                Text(msg.createdAt.formatted(.relative(presentation: .named)))
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary.opacity(0.5))
            }
            Text(msg.content)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            msg.role == .user
                ? theme.foreground.opacity(0.04)
                : theme.accent.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(theme.textTertiary.opacity(0.4))

            Text("No messages yet")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            Text("Use the Ask field to chat")
                .font(.system(size: 11))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
