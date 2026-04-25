import SwiftData
import SwiftUI

// MARK: - Chat Sidebar
// Floating glass card with Liquid Glass interactive elements.
// Parent applies .glassEffect for the card background. Search bar, chat rows,
// and New Chat button use nested .glassEffect / .flatToGlass for depth hierarchy.

struct ChatSidebarView: View {
    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var recentChats: [SDChat] = []
    @State private var searchText = ""
    @AppStorage("chatSidebar.showNotesOnly") private var showNotesOnly = false
    @State private var deleteErrorMessage: String?
    private var theme: EpistemosTheme { ui.theme }

    private var filteredChats: [SDChat] {
        var result = recentChats
        if showNotesOnly {
            result = result.filter { $0.linkedPageId != nil }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter { $0.title.lowercased().contains(q) }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar — glass field
            searchBar
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Filters
            HStack(spacing: 6) {
                Button {
                    withAnimation(reduceMotion ? nil : Motion.quick) {
                        showNotesOnly.toggle()
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "book.pages")
                        Text("Notes")
                    }
                    .font(.epSmall)
                }
                .buttonStyle(NativePillButtonStyle(isActive: showNotesOnly, activeColor: theme.resolved.accent.color))

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)

            // Chat list or empty state
            if filteredChats.isEmpty {
                emptyState
            } else {
                chatList
            }

            Spacer(minLength: 0)
        }
        .alert("Couldn't Delete Chat", isPresented: Binding(
            get: { deleteErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    deleteErrorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage ?? "Epistemos couldn't delete that chat.")
        }
        .onAppear {
            Task { @MainActor in
                loadChats()
            }
        }
        .onHover { inside in
            if inside {
                // Force cursor visible — landing page may have hidden it via NSCursor.hide().
                // .arrow.set() alone doesn't undo hide(); unhide() is needed first.
                NSCursor.unhide()
                NSCursor.arrow.set()
            }
        }
    }

    // MARK: - Search Bar (glass)

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.epCaption)
                .fontWeight(.medium)
                .foregroundStyle(theme.textTertiary)

            TextField("Search chats…", text: $searchText)
                .font(.epBody)
                .foregroundStyle(theme.resolved.foreground.color)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button {
                    withAnimation(reduceMotion ? nil : Motion.quick) { searchText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.epCaption)
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(NativeToolbarButtonStyle())
                .help("Clear search")
                .accessibilityLabel("Clear search")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(
            .regular.tint(theme.glassBg.opacity(0.3)),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }

    // MARK: - Chat List (time-grouped)

    private var chatList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                let grouped = groupedChats
                ForEach(grouped, id: \.label) { section in
                    sectionHeader(section.label)

                    ForEach(section.chats, id: \.id) { sdChat in
                        SidebarChatRow(
                            sdChat: sdChat,
                            isActive: sdChat.id == chat.activeChatId,
                            onSelect: { loadChatIntoSession(sdChat) },
                            onDelete: { deleteChat(sdChat) }
                        )
                    }
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.epSmall)
            .fontWeight(.semibold)
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.top, 14)
            .padding(.bottom, 4)
    }

    // MARK: - Time Grouping

    private struct ChatSection {
        let label: String
        let chats: [SDChat]
    }

    private var groupedChats: [ChatSection] {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)
            ?? startOfToday
        let startOfWeek = calendar.date(byAdding: .day, value: -7, to: startOfToday)
            ?? startOfYesterday

        var today: [SDChat] = []
        var yesterday: [SDChat] = []
        var thisWeek: [SDChat] = []
        var older: [SDChat] = []

        for chat in filteredChats {
            if chat.updatedAt >= startOfToday {
                today.append(chat)
            } else if chat.updatedAt >= startOfYesterday {
                yesterday.append(chat)
            } else if chat.updatedAt >= startOfWeek {
                thisWeek.append(chat)
            } else {
                older.append(chat)
            }
        }

        var sections: [ChatSection] = []
        if !today.isEmpty { sections.append(ChatSection(label: "Today", chats: today)) }
        if !yesterday.isEmpty { sections.append(ChatSection(label: "Yesterday", chats: yesterday)) }
        if !thisWeek.isEmpty { sections.append(ChatSection(label: "Previous 7 Days", chats: thisWeek)) }
        if !older.isEmpty { sections.append(ChatSection(label: "Older", chats: older)) }
        return sections
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: searchText.isEmpty ? "bubble.left.and.bubble.right" : "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(theme.textTertiary.opacity(0.5))

            Text(searchText.isEmpty ? "No chats yet" : "No matches")
                .font(.epBody)
                .fontWeight(.medium)
                .foregroundStyle(theme.textSecondary)

            Text(searchText.isEmpty ? "Start a conversation to see it here" : "Try a different search term")
                .font(.epSmall)
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Data

    private func deleteChat(_ sdChat: SDChat) {
        let deletingActiveChat = sdChat.id == chat.activeChatId
        let originalMessages = sdChat.messages ?? []
        modelContext.delete(sdChat)
        do {
            try modelContext.save()
            if deletingActiveChat {
                chat.clearMessages()
            }
        } catch {
            modelContext.insert(sdChat)
            sdChat.messages = originalMessages
            for message in originalMessages {
                modelContext.insert(message)
                message.chat = sdChat
            }
            deleteErrorMessage = error.localizedDescription
            Log.app.error("Save failed (delete chat): \(error.localizedDescription, privacy: .private)")
        }
        loadChats()
    }

    private func loadChats() {
        var descriptor = FetchDescriptor<SDChat>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 50
        do {
            recentChats = try modelContext.fetch(descriptor)
        } catch {
            Log.app.error(
                "ChatSidebarView: failed to fetch chats: \(error.localizedDescription, privacy: .public)"
            )
            recentChats = []
        }
    }

    private func loadChatIntoSession(_ sdChat: SDChat) {
        if let bootstrap = AppBootstrap.shared {
            bootstrap.loadChat(chatId: sdChat.id)
        } else {
            chat.setCurrentChat(sdChat.id)
            chat.chatTitle = sdChat.title
            chat.loadMessages(sdChat.loadedMessages)
            ui.setActivePanel(.home)
        }
        ui.dismissChatSidebar()
    }
}

// MARK: - Sidebar Chat Row (hover glass)

private struct SidebarChatRow: View {
    let sdChat: SDChat
    let isActive: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    /// Last assistant message preview (truncated).
    private var previewText: String? {
        let msgs = sdChat.sortedMessages
        guard let last = msgs.last(where: { $0.role == "assistant" }) else { return nil }
        let content = last.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return nil }
        return content.count > 80 ? String(content.prefix(80)) + "…" : content
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    if sdChat.chatType == "notes" {
                        Image(systemName: "book.pages")
                            .font(.epSmall)
                            .fontWeight(.medium)
                            .foregroundStyle(theme.resolved.accent.color.opacity(0.7))
                    }
                    if sdChat.isWorkerSession {
                        // Worker Session sidebar marker — Pass 8.
                        // This glyph is the only UI surface today that
                        // reads `SDChat.isWorkerSession`. Removing it
                        // will orphan the schema helper.
                        Image(systemName: "terminal.fill")
                            .font(.epSmall)
                            .fontWeight(.medium)
                            .foregroundStyle(theme.resolved.accent.color.opacity(0.8))
                            .accessibilityLabel("Worker session")
                    }
                    Text(sdChat.title)
                        .font(.epBody)
                        .fontWeight(isActive ? .semibold : .medium)
                        .foregroundStyle(isActive ? theme.resolved.accent.color : theme.resolved.foreground.color)
                        .lineLimit(1)
                }

                if let preview = previewText {
                    Text(preview)
                        .font(.epSmall)
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(2)
                }

                Text(sdChat.updatedAt.formatted(.relative(presentation: .named)))
                    .font(.epSmall)
                    .foregroundStyle(theme.textTertiary.opacity(0.6))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(NativeCardButtonStyle(cornerRadius: 10))
        .physicsHover(.subtle)
        .contextMenu {
            if !sdChat.isWorkerSession {
                // Pass 8 — promote a normal chat into a worker session.
                // `markAsWorkerSession` is the imperative schema API that
                // future UI will continue to call (composer toggle,
                // command palette, etc.). Keeping at least one call site
                // here ensures a prune pass can't orphan-delete the
                // helper.
                Button {
                    sdChat.markAsWorkerSession()
                } label: {
                    Label("Make Worker Session", systemImage: "terminal.fill")
                }
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Chat", systemImage: "trash")
            }
        }
    }
}
