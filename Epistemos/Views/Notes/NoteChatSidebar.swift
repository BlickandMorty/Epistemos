import SwiftUI

// MARK: - Note Chat Sidebar
// Trailing sidebar showing per-note chat history from NoteChatState.messages.
// Mirrors the ChatSidebarView glass aesthetic but reads from in-memory AssistantMessage array.

struct NoteChatSidebar: View {
    @Environment(NoteChatState.self) private var noteChat
    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            if noteChat.messages.isEmpty {
                emptyState
            } else {
                messageList
            }

            Spacer(minLength: 0)
        }
        .frame(width: 260)
        .background(theme.background.opacity(0.5))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.accent)
            Text("Chat History")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.foreground)
            Spacer()
            Text("\(noteChat.messages.count)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(theme.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(theme.foreground.opacity(0.06), in: Capsule())
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(noteChat.messages) { msg in
                        messageRow(msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .onChange(of: noteChat.messages.count) { _, _ in
                if let last = noteChat.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func messageRow(_ msg: AssistantMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: msg.role == .user ? "person.fill" : "sparkles")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(msg.role == .user ? theme.textTertiary : theme.accent)
                .frame(width: 16, alignment: .center)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(msg.content)
                    .font(.system(size: 12))
                    .foregroundStyle(msg.role == .user ? theme.textSecondary : theme.foreground)
                    .lineLimit(msg.role == .user ? 2 : 4)
                    .textSelection(.enabled)

                Text(msg.createdAt.formatted(.relative(presentation: .named)))
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary.opacity(0.6))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(
            .regular.tint(msg.role == .user ? theme.glassBg.opacity(0.15) : theme.glassBg.opacity(0.25)),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(theme.textTertiary.opacity(0.5))

            Text("No messages yet")
                .font(.epBody)
                .fontWeight(.medium)
                .foregroundStyle(theme.textSecondary)

            Text("Use the chat field above\nto ask about this note")
                .font(.epSmall)
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 40)
    }
}
