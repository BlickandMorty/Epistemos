import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Command Palette Overlay
// Global Gemini-style command palette — shown from any panel via Cmd+S.
// Fullscreen blur backdrop with centered glass search panel.
// Executes commands, searches vault, submits chat queries.

struct CommandPaletteOverlay: View {
    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    @Environment(NotesUIState.self) private var notesUI
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(InferenceState.self) private var inference

    // Vault search — in-memory title filter from SwiftData @Query
    @Query(SDPage.activePagesDescriptor) private var allPages: [SDPage]

    // Search state
    @State private var searchText = ""
    @State private var inlineSelectedIndex = 0
    @FocusState private var isSearchFocused: Bool

    private var theme: EpistemosTheme { ui.theme }

    // MARK: - Body

    var body: some View {
        searchPanel
            .onAppear {
                // Focus after the transition settles
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.15))
                    isSearchFocused = true
                }
            }
    }

    // MARK: - Search Panel

    private var searchPanel: some View {
        VStack(spacing: 0) {
            promptArea
            toolsRow

            Rectangle()
                .fill(theme.glassBorder)
                .frame(height: 0.5)

            inlineCommandList
        }
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: theme.accent.opacity(0.06), radius: 24, y: 0)
        .shadow(color: .black.opacity(theme.isDark ? 0.25 : 0.06), radius: 8, y: 4)
    }

    // MARK: - Prompt Area

    private var promptArea: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            TextField("Ask anything or type a command...", text: $searchText, axis: .vertical)
                .font(.epBody)
                .foregroundStyle(theme.foreground)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($isSearchFocused)
                .onSubmit { executeSelected() }

            if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                Button {
                    executeSelected()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
                .help("Send")
                .accessibilityLabel("Send")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    // MARK: - Tools Row

    private var toolsRow: some View {
        HStack(spacing: 8) {
            Button {
                handleUpload()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Attach a file")
            .accessibilityLabel("Attach a file")

            // Research mode toggle — oval pill button (can combine with Notes)
            Button {
                withAnimation(Motion.quick) {
                    if chat.isResearchMode {
                        chat.disableResearchMode()
                    } else {
                        chat.enableResearchMode()
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: chat.isResearchMode ? "flask.fill" : "flask")
                        .font(.system(size: 10, weight: .medium))
                    Text("Research")
                        .font(.system(size: 11, weight: chat.isResearchMode ? .semibold : .regular))
                }
                .foregroundStyle(chat.isResearchMode ? theme.accent : theme.textTertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(
                            chat.isResearchMode
                                ? theme.accent.opacity(0.12) : theme.glassTint.opacity(0.5))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            chat.isResearchMode ? theme.accent.opacity(0.3) : theme.glassBorder,
                            lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .help(chat.isResearchMode ? "Research Mode On — full pipeline" : "Enable Research Mode")

            // Incognito toggle
            Button {
                withAnimation(Motion.quick) { chat.isIncognito.toggle() }
            } label: {
                Image(systemName: chat.isIncognito ? "eye.slash.fill" : "eye.slash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(chat.isIncognito ? theme.accent : theme.textTertiary)
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(chat.isIncognito ? "Incognito On" : "Enable Incognito")
            .accessibilityLabel(chat.isIncognito ? "Incognito on" : "Incognito off")

            ProviderDropdown()

            Spacer()

            Text("esc")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4).fill(theme.glassTint))
                .onTapGesture { dismiss() }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 8)
    }

    // MARK: - Inline Command List

    private var inlineFilteredCommands: [LandingCommandItem] {
        let chatCandidate = searchText.split(separator: " ").count > 2 || searchText.hasSuffix("?")
        var base: [LandingCommandItem] = []
        if !searchText.isEmpty && chatCandidate {
            let q = searchText
            base.append(
                LandingCommandItem(
                    id: "ask", label: "Ask: \"\(q)\"", icon: "arrow.up.circle", category: "Chat"
                ) {
                    submitChat(q)
                })
        }

        // Real-time vault search
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            let matchingNotes =
                allPages
                .filter { $0.title.lowercased().contains(q) }
                .prefix(8)
            for page in matchingNotes {
                let pageId = page.id
                let label = page.emoji.isEmpty ? page.title : "\(page.emoji) \(page.title)"
                base.append(
                    LandingCommandItem(
                        id: "note-\(pageId)", label: label, icon: "doc.text", category: "Notes"
                    ) { [self] in
                        dismiss()
                        NoteWindowManager.shared.open(pageId: pageId)
                    })
            }
        }

        let q = searchText.lowercased()
        let commands = makeCommands()
        let filtered =
            searchText.isEmpty
            ? commands
            : commands.filter {
                $0.label.lowercased().contains(q) || $0.category.lowercased().contains(q)
            }
        return base + filtered
    }

    private var inlineCommandList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(inlineFilteredCommands.enumerated()), id: \.element.id) {
                        index, cmd in
                        LandingCommandRow(command: cmd, isSelected: index == inlineSelectedIndex) {
                            cmd.action()
                        }
                        .id(index)
                        .onTapGesture {
                            inlineSelectedIndex = index
                            cmd.action()
                        }
                    }
                }
            }
            .frame(maxHeight: 260)
            .onChange(of: inlineSelectedIndex) { _, newValue in
                withAnimation(Motion.micro) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
        .onKeyPress(.upArrow) {
            inlineMoveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            inlineMoveSelection(by: 1)
            return .handled
        }
        .onChange(of: searchText) { _, _ in inlineSelectedIndex = 0 }
    }

    private func inlineMoveSelection(by delta: Int) {
        let count = inlineFilteredCommands.count
        guard count > 0 else { return }
        inlineSelectedIndex = (inlineSelectedIndex + delta + count) % count
    }

    // MARK: - Actions

    private func dismiss() {
        isSearchFocused = false
        searchText = ""
        inlineSelectedIndex = 0
        ui.dismissCommandPalette()
    }

    private func submitChat(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Start a fresh chat — don't append to any existing conversation
        chat.startNewChat()
        chat.submitQuery(trimmed)
        dismiss()
        ui.setActivePanel(.home)
    }

    private func executeSelected() {
        guard !inlineFilteredCommands.isEmpty, inlineSelectedIndex < inlineFilteredCommands.count
        else {
            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                submitChat(searchText)
            }
            return
        }
        inlineFilteredCommands[inlineSelectedIndex].action()
    }

    private func handleUpload() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.pdf, .plainText, .png, .jpeg, .json, .commaSeparatedText]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                searchText = "Analyze this file: \(url.lastPathComponent)"
            }
        }
    }

    // MARK: - Commands

    private func makeCommands() -> [LandingCommandItem] {
        var commands: [LandingCommandItem] = [
            LandingCommandItem(
                id: "chat-with-notes", label: "Chat with Notes", icon: "book.pages",
                category: "Chat"
            ) { [self] in
                dismiss()
                chat.startNewChat()
                chat.enableNotesMode()
                ui.setActivePanel(.home)
                AppBootstrap.shared?.startNotesMode(chatState: chat)
            },
            LandingCommandItem(
                id: "new-note", label: "New Note", icon: "doc.badge.plus", category: "Notes"
            ) {
                dismiss()
                Task {
                    if let pageId = await vaultSync.createPage(title: "New Note") {
                        NoteWindowManager.shared.open(pageId: pageId)
                    }
                }
            },
            LandingCommandItem(
                id: "nav-home", label: "Go Home", icon: "house", category: "Navigate"
            ) {
                ui.setActivePanel(.home)
                dismiss()
            },
            LandingCommandItem(
                id: "nav-notes", label: "Go to Notes", icon: "note.text", category: "Navigate"
            ) {
                UtilityWindowManager.shared.show(.notes)
                dismiss()
            },
            LandingCommandItem(
                id: "nav-library", label: "Go to Library & Research", icon: "books.vertical",
                category: "Navigate"
            ) {
                UtilityWindowManager.shared.show(.library)
                dismiss()
            },
            LandingCommandItem(
                id: "nav-settings", label: "Open Settings", icon: "gearshape", category: "Navigate"
            ) {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                dismiss()
            },
            LandingCommandItem(
                id: "toggle-theme", label: "Toggle Theme", icon: "paintpalette",
                category: "Appearance"
            ) {
                ui.cycleTheme()
                dismiss()
            },
            LandingCommandItem(
                id: "breathe", label: "Breathe Now", icon: "wind", category: "Wellness"
            ) {
                ui.startBreathe()
                dismiss()
            },
        ]

        return commands
    }
}
