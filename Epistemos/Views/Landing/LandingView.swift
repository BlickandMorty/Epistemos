import SwiftData
import SwiftUI

enum LandingShortcutDisplay {
    static let fontSize: CGFloat = 12
    static let keyHorizontalPadding: CGFloat = 7
    static let keyVerticalPadding: CGFloat = 4
    static let keyCornerRadius: CGFloat = 7
    static let multiCharacterKeyMinWidth: CGFloat = 48
    static let shortcutRowSpacing: CGFloat = 12

    static func label(_ text: String) -> String {
        text
    }

    static func font(weight: Font.Weight = .medium) -> Font {
        .system(size: fontSize, weight: weight, design: .rounded)
    }

    static func nsFont(weight: NSFont.Weight = .medium) -> NSFont {
        AppDisplayTypography.regularUIFont(size: fontSize, weight: weight)
    }

    static func keyMinWidth(for text: String?) -> CGFloat? {
        guard let text, text.count > 1 else { return nil }
        return multiCharacterKeyMinWidth
    }
}

enum LandingSearchLayout {
    static let maxWidth: CGFloat = 820
    static let topRowSpacing: CGFloat = 14
    static let controlRowSpacing: CGFloat = 8
    static let controlRowTopPadding: CGFloat = 10
    static let horizontalPadding: CGFloat = 24
    static let topPadding: CGFloat = 20
    static let bottomPadding: CGFloat = 18
    static let cornerRadius: CGFloat = 24
    static let inputFontSize: CGFloat = 22
    static let inputMinHeight: CGFloat = ChatComposerInputMetrics.minHeight(for: inputFontSize)
}

enum LandingCoordinateSpace {
    static let root = "LandingRoot"
}

@MainActor @Observable
final class LandingPointerState {
    var location: CGPoint?
    private(set) var tapToken: UInt = 0
    private(set) var tapLocation: CGPoint?

    func registerTap(at location: CGPoint) {
        tapLocation = location
        tapToken &+= 1
    }
}

// MARK: - Landing View
// Clean landing: liquid glass greeting with shortcut hints.
// Search/command palette is now a global overlay (CommandPaletteOverlay)
// shown from any panel via Option+Space — no longer embedded here.

struct LandingView: View {
    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    @Environment(NotesUIState.self) private var notesUI
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(DailyBriefState.self) private var dailyBrief
    @Environment(\.modelContext) private var modelContext

    // Recent data for Daily Brief context
    @Query(SDPage.recentDescriptor(limit: 50))
    private var allPages: [SDPage]

    // Inline search state
    @State private var showingSearch = false
    @State private var landingSearchText = ""
    @State private var landingComposerHeight: CGFloat = LandingSearchLayout.inputMinHeight
    @State private var isLandingSearchFocused = false
    @State private var showLandingMentionDropdown = false
    @State private var landingMentionFilter = ""
    @State private var landingReferenceSearch = ComposerReferenceSearchState()
    @State private var landingContextAttachments: [ContextAttachment] = []
    @State private var pointerState = LandingPointerState()

    // Cached vocabulary — rebuilt only when allPages changes, not every body evaluation.
    @State private var landingWakeVocabulary: [String] = []

    private var theme: EpistemosTheme { ui.theme }
    private var showingBrief: Bool { dailyBrief.showDailyBrief }
    private var currentCursorSurface: LandingCursorSurface? {
        if showingBrief {
            nil
        } else if showingSearch {
            .search
        } else {
            .landing
        }
    }
    private var trimmedLandingSearchText: String {
        landingSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var landingMentionSearchResults: ChatCoordinator.ReferenceSearchResults {
        ChatCoordinator.searchReferenceResults(
            filter: landingMentionFilter,
            manifest: AppBootstrap.shared?.ambientManifest,
            chats: recentChats(limit: 20),
            threads: AppBootstrap.shared?.threadState.chatThreads ?? [],
            indexedNoteIDs: landingReferenceSearch.indexedNoteIDs,
            indexedNoteSnippets: landingReferenceSearch.indexedNoteSnippetsByPageID
        )
    }

    private func rebuildVocabulary() {
        landingWakeVocabulary = LandingASCIIWakeFieldEngine.normalizedVocabulary(
            from: [
                "Epistemos",
                "Research",
                "Knowledge Graph",
                "Command Palette",
                "New Note",
                "Daily Brief",
                "Apple Intelligence",
                "Sources",
                "Claims",
                "Concepts",
                "Questions",
            ] + allPages.prefix(36).map(\.title)
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            if let surface = currentCursorSurface,
                ui.landingCursorVisibilityMode.shows(on: surface) {
                LandingASCIIWakeField(
                    vocabulary: landingWakeVocabulary,
                    theme: theme,
                    pointerState: pointerState,
                    surface: surface
                )
                .allowsHitTesting(false)
                .transition(.opacity)
                .zIndex(0)
            }

            // ── Greeting Mode ──
            // Blurs and fades when Daily Brief or inline search is active.
            greetingContent
                .blur(radius: (showingBrief || showingSearch) ? 20 : 0)
                .opacity((showingBrief || showingSearch) ? 0 : 1)
                .allowsHitTesting(!showingBrief && !showingSearch)
                .zIndex(1)

            // ── Inline Search Mode ──
            // Click anywhere on landing → greeting blur-replaces into search bar.
            if showingSearch {
                landingSearchContent
                    .transition(.opacity.combined(with: .blurReplace))
                    .zIndex(2)
            }

            // ── Daily Brief Mode ──
            // Fades in on top of the blurred greeting.
            if showingBrief {
                dailyBriefContent
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .zIndex(3)
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                pointerState.location = location
            case .ended:
                pointerState.location = nil
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .coordinateSpace(name: LandingCoordinateSpace.root)
        .animation(Motion.smooth, value: showingBrief)
        .animation(Motion.smooth, value: showingSearch)
        .animation(Motion.smooth, value: ui.landingCursorVisibilityMode)
        .simultaneousGesture(
            SpatialTapGesture()
                .onEnded { value in
                    guard currentCursorSurface == .landing,
                        ui.landingCursorVisibilityMode.shows(on: .landing) else { return }
                    pointerState.registerTap(at: value.location)
                }
        )
        .background {
            // Hidden ⌘N shortcut — creates new note and teleports there
            Button(action: { createAndOpenNote() }) {}
                .keyboardShortcut("n", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)

            // Hidden ⌘I shortcut — quick idea capture
            Button(action: { captureQuickIdea() }) {}
                .keyboardShortcut("i", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)

        }
        .onKeyPress(.escape) {
            if showingSearch {
                dismissLandingSearch()
                return .handled
            }
            if showingBrief {
                dailyBrief.dismissDailyBrief()
                return .handled
            }
            if ui.showChatSidebar {
                ui.dismissChatSidebar()
                return .handled
            }
            return .ignored
        }
        .onAppear { rebuildVocabulary() }
        .onChange(of: allPages.map(\.id)) { _, _ in rebuildVocabulary() }
    }

    // MARK: - Greeting Content (normal landing state)

    private var greetingContent: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 36) {
                LiquidGreeting(retractNow: .constant(false))
            }
            .padding(.horizontal, Spacing.xxl)

            Spacer()

                // Shortcut hints
                HStack(spacing: LandingShortcutDisplay.shortcutRowSpacing) {
                    CommandHint(icon: "magnifyingglass", label: "Click to search", theme: theme) {
                        activateLandingSearch()
                    }
                    .springEntrance(index: 0, stagger: 0.08)

                    Circle()
                        .fill(theme.textTertiary.opacity(0.3))
                        .frame(width: 3, height: 3)

                    CommandHint(modIcon: "option", key: "Space", label: "Palette", theme: theme) {
                        Task { @MainActor in
                            CommandPaletteWindowController.shared.show()
                        }
                    }
                    .springEntrance(index: 1, stagger: 0.08)

                    Circle()
                        .fill(theme.textTertiary.opacity(0.3))
                        .frame(width: 3, height: 3)

                    HoverRevealCommandHint(
                        primary: .init(modIcon: "command", key: "2", label: "Notes"),
                        secondary: .init(modIcon: "command", key: "N", label: "New Note"),
                        theme: theme,
                        primaryAction: {
                            UtilityWindowManager.shared.show(.notes)
                        },
                        secondaryAction: {
                            createAndOpenNote()
                        }
                    )
                    .springEntrance(index: 2, stagger: 0.08)

                    Circle()
                        .fill(theme.textTertiary.opacity(0.3))
                        .frame(width: 3, height: 3)

                    CommandHint(modIcon: "command", key: "S", label: "Settings", theme: theme) {
                        UtilityWindowManager.shared.show(.settings)
                    }
                    .springEntrance(index: 3, stagger: 0.08)

                    Circle()
                        .fill(theme.textTertiary.opacity(0.3))
                        .frame(width: 3, height: 3)

                    CommandHint(modIcon: "command", key: "G", label: "Graph", theme: theme) {
                        HologramController.shared.toggle()
                    }
                    .help("Graph overlay (\u{2318}G).")
                    .springEntrance(index: 4, stagger: 0.08)
                }
                .padding(.bottom, 28)
            }
        .contentShape(Rectangle())
        .onTapGesture { activateLandingSearch() }
    }

    // MARK: - Landing Search Content (replaces greeting in-place)

    private var landingSearchContent: some View {
        VStack(spacing: 0) {
             Spacer()
                 .allowsHitTesting(false)

            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    ComposerContextShortcutBar(
                        noteLabel: "Chat with Note",
                        vaultLabel: "Chat with Vault",
                        onChatWithNote: openLandingNotePicker,
                        onChatWithVault: attachLandingVaultContext
                    )

                    if !landingContextAttachments.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(landingContextAttachments) { attachment in
                                    HStack(spacing: 4) {
                                        Image(systemName: attachment.systemImageName)
                                            .font(.system(size: 10, weight: .medium))
                                        Text(attachment.title)
                                            .font(.system(size: 11, weight: .medium))
                                            .lineLimit(1)
                                        Button {
                                            removeLandingContextAttachment(attachment.id)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 10))
                                                .foregroundStyle(theme.textTertiary.opacity(0.5))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .glassEffect(.regular.interactive(), in: Capsule())
                                    .foregroundStyle(theme.textSecondary)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }

                    VStack(alignment: .leading, spacing: LandingSearchLayout.controlRowTopPadding) {
                        HStack(alignment: .top, spacing: LandingSearchLayout.topRowSpacing) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(hue: 0.75, saturation: 0.5, brightness: 0.9),
                                            Color(hue: 0.55, saturation: 0.5, brightness: 0.95),
                                            Color(hue: 0.05, saturation: 0.5, brightness: 0.95),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                   )
                                )
                                .padding(.top, 8)

                            ZStack(alignment: .topLeading) {
                                ChatComposerTextEditor(
                                    text: $landingSearchText,
                                    height: $landingComposerHeight,
                                    isFocused: $isLandingSearchFocused,
                                    theme: theme,
                                    fontSize: LandingSearchLayout.inputFontSize,
                                    isProcessing: false
                                ) {
                                    submitLandingSearch()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: landingComposerHeight)
                                .frame(minHeight: LandingSearchLayout.inputMinHeight, alignment: .topLeading)
                                .onChange(of: landingSearchText) { _, newValue in
                                    if let filter = ComposerReferenceHelpers.mentionFilter(in: newValue) {
                                        landingMentionFilter = filter
                                        if !showLandingMentionDropdown {
                                            showLandingMentionDropdown = true
                                        }
                                        landingReferenceSearch.update(
                                            filter: filter,
                                            manifest: AppBootstrap.shared?.ambientManifest,
                                            vaultSync: vaultSync
                                        )
                                    } else if showLandingMentionDropdown {
                                        showLandingMentionDropdown = false
                                        landingReferenceSearch.reset()
                                    }
                                }

                                if landingSearchText.isEmpty {
                                    Text("Ask Epistemos\u{2026}")
                                        .font(.system(size: LandingSearchLayout.inputFontSize, weight: .regular))
                                        .foregroundStyle(theme.mutedForeground.opacity(0.55))
                                        .padding(.top, ChatComposerInputMetrics.verticalInset)
                                        .allowsHitTesting(false)
                                }
                            }
                        }

                        HStack(spacing: LandingSearchLayout.controlRowSpacing) {
                            landingRoutingMenu

                            Spacer(minLength: 0)

                            if !landingSearchText.isEmpty {
                                Button {
                                    landingSearchText = ""
                                    landingComposerHeight = LandingSearchLayout.inputMinHeight
                                    showLandingMentionDropdown = false
                                    landingMentionFilter = ""
                                    landingReferenceSearch.reset()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(theme.textTertiary)
                                        .frame(width: 28, height: 28)
                                }
                                .buttonStyle(NativeToolbarButtonStyle())
                                .transition(.scale(scale: 0.5).combined(with: .opacity))
                            }

                            AssistantSendButton(
                                theme: theme,
                                isEnabled: !trimmedLandingSearchText.isEmpty,
                                isProcessing: false,
                                metrics: .compactChat
                            ) {
                                submitLandingSearch()
                            }
                            .help("Send")
                            .accessibilityLabel("Send prompt")
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if showLandingMentionDropdown {
                            ComposerReferencePopover(
                                results: landingMentionSearchResults,
                                idealWidth: 468,
                                maxHeight: 360,
                                onSelect: attachLandingMentionReference
                            )
                            }
                        }
                    }
                .padding(.horizontal, LandingSearchLayout.horizontalPadding)
                .padding(.top, LandingSearchLayout.topPadding)
                .padding(.bottom, LandingSearchLayout.bottomPadding)
                .assistantGlassInputChrome(
                    theme: theme,
                    cornerRadius: LandingSearchLayout.cornerRadius,
                    isActive: isLandingSearchFocused || !trimmedLandingSearchText.isEmpty || !landingContextAttachments.isEmpty
                )
                .frame(maxWidth: LandingSearchLayout.maxWidth)
            }
            .padding(.horizontal, Spacing.xxl)

            Spacer()
                .allowsHitTesting(false)

            VStack(spacing: 16) {
                // Hint to dismiss
                Text("Press Esc to go back")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.textTertiary.opacity(0.4))
                
                // Quick action chips moved to the bottom
                HStack(spacing: 12) {
                    landingChip(label: "New Note", icon: "doc.badge.plus") {
                        dismissLandingSearch()
                        createAndOpenNote()
                    }
                    landingChip(label: "Quick Idea", icon: "lightbulb") {
                        dismissLandingSearch()
                        captureQuickIdea()
                    }
                    landingChip(label: "Vault Briefing", icon: "book.pages") {
                        dismissLandingSearch()
                        chat.startNewChat()
                        ui.setActivePanel(.home)
                        AppBootstrap.shared?.requestVaultBriefing(chatState: chat)
                    }
                    landingChip(label: "Daily Brief", icon: "newspaper.fill") {
                        dismissLandingSearch()
                        dailyBrief.requestDailyBrief(prompt: buildDailyBriefPrompt())
                    }
                }
            }
            .padding(.bottom, 28)
        }
    }

    private func landingChip(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .hoverGlass(flatBackground: theme.foreground.opacity(0.06), cornerRadius: 100)
        }
        .buttonStyle(.plain)
    }

    private var landingRoutingMenu: some View {
        InferenceControlPopoverButton(
            titleStyle: .routing,
            variant: .toolbar,
            stableWidth: NativeControlSystem.reservedWidth(
                for: LocalRoutingMode.allCases.map(\.displayName),
                variant: .toolbar,
                includesDisclosureGlyph: true
            ),
            idealPopoverWidth: 336
        )
        .accessibilityLabel("Routing Mode")
    }

    private func activateLandingSearch() {
        guard !showingBrief else { return }
        showingSearch = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            isLandingSearchFocused = true
        }
    }

    private func dismissLandingSearch() {
        showingSearch = false
        landingSearchText = ""
        landingComposerHeight = LandingSearchLayout.inputMinHeight
        isLandingSearchFocused = false
        showLandingMentionDropdown = false
        landingMentionFilter = ""
        landingReferenceSearch.reset()
        landingContextAttachments = []
    }

    private func submitLandingSearch() {
        let trimmed = landingSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let attachments = landingContextAttachments
        dismissLandingSearch()
        chat.startNewChat()
        for attachment in attachments {
            chat.addContextAttachment(attachment)
        }
        chat.submitQuery(trimmed)
        ui.setActivePanel(.home)
    }

    private func openLandingNotePicker() {
        landingMentionFilter = ""
        showLandingMentionDropdown = true
        isLandingSearchFocused = true
        landingReferenceSearch.reset()
    }

    private func attachLandingVaultContext() {
        let attachment = ComposerReferenceHelpers.allNotesAttachment
        guard !landingContextAttachments.contains(attachment) else { return }
        landingContextAttachments.append(attachment)
    }

    private func attachLandingMentionReference(_ choice: ComposerReferenceChoice) {
        let attachment = ComposerReferenceHelpers.contextAttachment(for: choice)
        if !landingContextAttachments.contains(attachment) {
            landingContextAttachments.append(attachment)
        }
        landingSearchText = ComposerReferenceHelpers.removingTrailingMention(from: landingSearchText)
        showLandingMentionDropdown = false
        landingMentionFilter = ""
        landingReferenceSearch.reset()
    }

    private func removeLandingContextAttachment(_ id: String) {
        landingContextAttachments.removeAll { $0.id == id }
    }

    // MARK: - Daily Brief Content (replaces greeting in-place)

    private var dailyBriefContent: some View {
        VStack(spacing: 0) {
            // Title — RetroGaming font, centered under nav bar
            Text("daily brief")
                .font(AppDisplayTypography.font(size: 24))
                .foregroundStyle(theme.fontAccent)
                .shadow(color: theme.isDark ? theme.fontAccent.opacity(0.12) : .clear, radius: 8)
                .padding(.top, 28)
                .padding(.bottom, 4)

            // Subtitle date
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.mutedForeground.opacity(0.5))
                .padding(.bottom, 16)

            // Scrollable brief content
            if dailyBrief.isDailyBriefLoading {
                Spacer()
                VStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(theme.fontAccent.opacity(0.6))
                    Text(
                        dailyBrief.isDeepBrief
                            ? "Deep analysis in progress…" : "Scanning your notes & conversations…"
                    )
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.mutedForeground.opacity(0.4))
                }
                Spacer()
            } else {
                ScrollView {
                    TypewriterPlainText(content: dailyBrief.dailyBriefContent)
                        .font(.system(size: 14.5, weight: .regular))
                        .foregroundStyle(theme.fontAccent.opacity(0.85))
                        .lineSpacing(5)
                        .textSelection(.enabled)
                        .frame(maxWidth: 580, alignment: .leading)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                }
                .mask {
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [.clear, .black], startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 16)
                        Rectangle()
                        LinearGradient(
                            colors: [.black, .clear], startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 24)
                    }
                }
            }

            // Action buttons row
            HStack(spacing: 12) {
                // Back button
                Button {
                    dailyBrief.dismissDailyBrief()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 11, weight: .medium))
                        Text("Back")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(theme.mutedForeground.opacity(0.5))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(theme.foreground.opacity(0.06)))
                }
                .buttonStyle(.plain)

                // "Go Deeper" button — visible only after initial brief loads, before deep mode
                if !dailyBrief.isDailyBriefLoading && !dailyBrief.isDeepBrief
                    && !dailyBrief.dailyBriefContent.isEmpty
                {
                    Button {
                        dailyBrief.requestGoDeep(prompt: buildGoDeepPrompt())
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.system(size: 11, weight: .medium))
                            Text("Go Deeper")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(theme.accent.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func createAndOpenNote() {
        Task {
            if let pageId = await vaultSync.createPage(title: "New Note") {
                NoteWindowManager.shared.open(pageId: pageId)
            }
        }
    }

    private func captureQuickIdea() {
        Task {
            if let pageId = await vaultSync.createPage(title: "New Idea", emoji: "💡") {
                NoteWindowManager.shared.open(pageId: pageId)
            }
        }
    }

    // MARK: - Daily Brief Prompt

    private func buildDailyBriefPrompt() -> String {
        DailyBriefState.buildBriefPrompt(pages: Array(allPages), chats: recentChats(limit: 12))
    }

    // MARK: - Go Deeper Prompt (metadata-rich)

    /// Builds an enriched prompt with full note/chat metadata for deep multi-perspective analysis.
    private func buildGoDeepPrompt() -> String {
        let recentChats = recentChats(limit: 10)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        var sections: [String] = []

        // ── Note metadata with rich stats ──
        let activeNotes =
            allPages
            .filter { $0.templateId == nil && !$0.isArchived }
            .prefix(15)

        if !activeNotes.isEmpty {
            var notesSection = "## Notes Inventory (sorted by most recently edited)\n\n"
            for note in activeNotes {
                let daysSinceEdit =
                    Calendar.current.dateComponents([.day], from: note.updatedAt, to: .now).day ?? 0
                let daysSinceCreated =
                    Calendar.current.dateComponents([.day], from: note.createdAt, to: .now).day ?? 0
                let tags = note.tags.isEmpty ? "none" : note.tags.joined(separator: ", ")
                let emoji = note.emoji.isEmpty ? "" : "\(note.emoji) "

                notesSection += """
                    - **\(emoji)\(note.title.isEmpty ? "Untitled" : note.title)**
                      Words: \(note.wordCount) | Tags: \(tags) | Created: \(dateFormatter.string(from: note.createdAt)) (\(daysSinceCreated)d ago) | Last edited: \(dateFormatter.string(from: note.updatedAt)) (\(daysSinceEdit)d ago)\n
                    """
            }

            // Aggregate stats
            let totalWords = activeNotes.reduce(0) { $0 + $1.wordCount }
            let allTags = activeNotes.flatMap(\.tags)
            let tagFreq = Dictionary(allTags.map { ($0, 1) }, uniquingKeysWith: +)
                .sorted { $0.value > $1.value }
                .prefix(10)
                .map { "\($0.key) (\($0.value))" }
            let longestNote = activeNotes.max(by: { $0.wordCount < $1.wordCount })

            notesSection += "\n### Aggregate Note Stats\n"
            notesSection += "- Total notes: \(activeNotes.count) | Total words: \(totalWords)\n"
            if let longest = longestNote {
                notesSection +=
                    "- Longest note: \"\(longest.title)\" (\(longest.wordCount) words)\n"
            }
            if !tagFreq.isEmpty {
                notesSection += "- Top tags by frequency: \(tagFreq.joined(separator: ", "))\n"
            }

            sections.append(notesSection)
        }

        // ── Chat metadata ──
        if !recentChats.isEmpty {
            var chatsSection = "## Conversation History (sorted by most recent)\n\n"
            for chatItem in recentChats {
                let msgs = chatItem.sortedMessages
                let msgCount = msgs.count
                let daysSinceChat =
                    Calendar.current.dateComponents([.day], from: chatItem.updatedAt, to: .now).day
                    ?? 0

                // Last user query snippet
                let lastUserQuery = msgs.last { $0.role == "user" }?.content.prefix(120) ?? ""
                let snippet = String(lastUserQuery).replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                chatsSection += """
                    - **\(chatItem.title)**
                      Messages: \(msgCount) | \(dateFormatter.string(from: chatItem.updatedAt)) (\(daysSinceChat)d ago)
                      Last query: \(snippet.isEmpty ? "(none)" : "\(snippet)…")\n
                    """
            }

            // Chat aggregate
            let totalMsgs = recentChats.reduce(0) {
                $0 + ($1.messages?.count ?? 0)
            }
            chatsSection += "\n### Aggregate Chat Stats\n"
            chatsSection +=
                "- Total conversations: \(recentChats.count) | Total messages: \(totalMsgs)\n"

            sections.append(chatsSection)
        }

        // ── Cross-reference ──
        let noteTagSet = Set(allPages.prefix(15).flatMap(\.tags))
        let chatTitles = recentChats.map { $0.title.lowercased() }
        let overlaps = noteTagSet.filter { tag in
            chatTitles.contains { $0.contains(tag) }
        }
        if !overlaps.isEmpty {
            sections.append(
                "## Cross-References\nTags that also appear in chat titles: **\(overlaps.sorted().joined(separator: ", "))**"
            )
        }

        let contextBlock =
            sections.isEmpty
            ? ""
            : """

            Here is the full metadata from my knowledge base for deep analysis:

            \(sections.joined(separator: "\n\n"))
            """

        return """
            Perform a deep multi-perspective analysis of my knowledge base. \
            You have full metadata below — word counts, dates, tags, and conversation history. \
            Use ALL of this data to produce a rigorous synthesis:

            1. **Statistical Patterns** — What do the numbers (word counts, edit frequency, message counts) reveal about my activity?
            2. **Thematic Clusters** — Group my notes and chats into emergent themes. What clusters form naturally?
            3. **Temporal Evolution** — How has my focus shifted? What appeared recently vs. weeks ago? What was abandoned?
            4. **Knowledge Gaps** — Based on what I'm researching, what adjacent topics am I missing?
            5. **Unexpected Connections** — Find non-obvious links between seemingly unrelated notes and conversations.

            End with 3-5 provocative questions I should consider based on the patterns you see.

            Format: Use ### headers for each perspective. Use **bold** for emphasis. Be specific — cite actual \
            note titles, chat topics, dates, word counts, and scores. This should feel like a research briefing, \
            not a summary.
            \(contextBlock)
            """
    }

    private func recentChats(limit: Int) -> [SDChat] {
        var descriptor = SDChat.recentChatsDescriptor
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}

// MARK: - Landing Command Item

struct LandingCommandItem: Identifiable {
    let id: String
    let label: String
    let icon: String
    let category: String
    var subtitle: String? = nil
    var snippet: String? = nil
    var badge: String? = nil
    var contextActions: [ContextAction] = []
    let action: () -> Void

    struct ContextAction {
        let label: String
        let icon: String
        let action: () -> Void
    }
}

// MARK: - Landing Command Row

struct LandingCommandRow: View {
    let command: LandingCommandItem
    let isSelected: Bool
    let action: () -> Void

    @Environment(UIState.self) private var ui
    @State private var isHovered = false

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: command.icon)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(isSelected ? theme.accent : theme.textSecondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(command.label)
                        .font(.epBody)
                        .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
                        .lineLimit(1)

                    if let subtitle = command.subtitle {
                        Text(subtitle)
                            .font(.epSmall)
                            .foregroundStyle(theme.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if let badge = command.badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(theme.glassTint)
                        )
                } else {
                    Text(command.category)
                        .font(.epSmall)
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.accent.opacity(0.13))
            } else if isHovered {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.foreground.opacity(0.06))
            }
        }
        .animation(Motion.micro, value: isSelected)
        .onHover { hovering in
            withAnimation(Motion.micro) { isHovered = hovering }
        }
        .contextMenu {
            if !command.contextActions.isEmpty {
                ForEach(Array(command.contextActions.enumerated()), id: \.offset) { _, ctx in
                    Button {
                        ctx.action()
                    } label: {
                        Label(ctx.label, systemImage: ctx.icon)
                    }
                }
            }
        }
    }
}

// MARK: - Command Hint (Landing Shortcuts)

private struct CommandHintSpec {
    var modIcon: String? = nil
    var icon: String? = nil
    var key: String? = nil
    let label: String
}

private struct CommandHintLabel: View {
    let spec: CommandHintSpec
    let theme: EpistemosTheme
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 2) {
            if spec.modIcon != nil || spec.key != nil {
                HStack(spacing: 3) {
                    if let modIcon = spec.modIcon {
                         Image(systemName: modIcon)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                    }
                    if let key = spec.key {
                        Text(key)
                            .font(LandingShortcutDisplay.font())
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .padding(.horizontal, LandingShortcutDisplay.keyHorizontalPadding)
                .padding(.vertical, LandingShortcutDisplay.keyVerticalPadding)
                .frame(minWidth: LandingShortcutDisplay.keyMinWidth(for: spec.key))
                .fixedSize(horizontal: true, vertical: false)
                .background(
                    RoundedRectangle(
                        cornerRadius: LandingShortcutDisplay.keyCornerRadius,
                        style: .continuous
                    )
                    .fill(theme.foreground.opacity(theme.isDark ? 0.08 : 0.06))
                )
            } else if let icon = spec.icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
            }
            Text(LandingShortcutDisplay.label(spec.label))
                .font(LandingShortcutDisplay.font())
                .padding(.leading, (spec.key != nil || spec.modIcon != nil || spec.icon != nil) ? 4 : 0)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .contentShape(Rectangle())
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct CommandHint: View {
    var modIcon: String? = nil
    var icon: String? = nil
    var key: String? = nil
    let label: String
    let theme: EpistemosTheme
    let action: () -> Void

    @State private var isHovered = false

    private var spec: CommandHintSpec {
        CommandHintSpec(modIcon: modIcon, icon: icon, key: key, label: label)
    }

    var body: some View {
        Button(action: action) {
            CommandHintLabel(spec: spec, theme: theme, isHovered: isHovered)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .hoverGlass(flatBackground: .clear, cornerRadius: LandingShortcutDisplay.keyCornerRadius + 4)
    }
}

private struct HoverRevealCommandHint: View {
    let primary: CommandHintSpec
    let secondary: CommandHintSpec
    let theme: EpistemosTheme
    let primaryAction: () -> Void
    let secondaryAction: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            commandButton(spec: primary, action: primaryAction)

            if isHovered {
                commandButton(spec: secondary, action: secondaryAction)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
    }

    private func commandButton(
        spec: CommandHintSpec,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            CommandHintLabel(spec: spec, theme: theme, isHovered: isHovered)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .hoverGlass(flatBackground: .clear, cornerRadius: LandingShortcutDisplay.keyCornerRadius + 4)
    }
}

struct LandingASCIIWakeTrail: Equatable, Sendable {
    let x: CGFloat
    let y: CGFloat
    let startTime: TimeInterval
    let radiusScale: CGFloat

    init(x: CGFloat, y: CGFloat, startTime: TimeInterval, radiusScale: CGFloat = 1) {
        self.x = x
        self.y = y
        self.startTime = startTime
        self.radiusScale = radiusScale
    }

    init(column: Int, row: Int, startTime: TimeInterval, radiusScale: CGFloat = 1) {
        self.init(x: CGFloat(column), y: CGFloat(row), startTime: startTime, radiusScale: radiusScale)
    }
}

struct LandingASCIIWakeFieldConfiguration: Equatable, Sendable {
    var frameInterval: TimeInterval = 1.0 / 60.0
    var interpolationStep: CGFloat = 0.4
    var duration: TimeInterval = 1.14
    var initialRadius: CGFloat = 0.62
    var maxRadius: CGFloat = 7.6
    var growthExponent: CGFloat = 1.18
    var peakProgress: CGFloat = 0.68
    var endRadius: CGFloat = 0.4
    var contractionExponent: CGFloat = 0.72
    var boundaryThickness: CGFloat = 1.15
    var scrambleCharacters = ASCIIRippleConfiguration().characters
    var surfaceCharacters: [Character] = Array(repeating: "·", count: 32)
    var restingSurfaceOpacity: Double = 0
    var maxTrailCount = 176
    var streamTailLength: CGFloat = 3.4
    var streamLongDragDistance: CGFloat = 4.8
    var streamVelocityReference: CGFloat = 26
    var streamCoreRadiusBoost: CGFloat = 0.72
    var streamAdaptiveStepBoost: CGFloat = 0.45
    var streamBubbleStride = 3
    var streamBubbleOffset: CGFloat = 1.15
    var streamBubbleBacktrack: CGFloat = 0.72
    var streamBubbleRadiusScale: CGFloat = 0.56
    var streamBubbleFastScaleBoost: CGFloat = 0.32
    var streamSwingMaxOffset: CGFloat = 0.72
    var streamSwingCycles: CGFloat = 1.18
    var streamHeadAgeBoost: TimeInterval = 0.1
    var overlayOpacity: Double = 1.0
    var scrambleShellOpacity: Double = 0.34
    var scrambleShellBlur: CGFloat = 0.5

    static func tuned(
        response: Double,
        spread: Double,
        trail: Double,
        viscosity: Double = 0.8,
        turbulence: Double = 0.5,
        opacity: Double = 1.0,
        blur: Double = 0.5
    ) -> LandingASCIIWakeFieldConfiguration {
        let clampedResponse = max(0, min(1, response))
        let clampedSpread = max(0, min(1, spread))
        let clampedTrail = max(0, min(1, trail))
        let clampedViscosity = max(0, min(1, viscosity))
        let clampedTurbulence = max(0, min(1, turbulence))
        let clampedOpacity = max(0.2, min(1.4, opacity))
        let clampedBlur = max(0, min(1, blur))

        let durBase = 1.32 - (0.36 * clampedResponse)
        let dur = durBase + (clampedViscosity * 0.7)
        
        let cExpBase = 0.64 + (0.16 * clampedTrail)
        let cExp = cExpBase - (clampedViscosity * 0.4)
        
        let maxRadBase = 5.8 + (3.6 * clampedSpread)
        let maxRad = maxRadBase + (clampedTurbulence * 2.0)

        return LandingASCIIWakeFieldConfiguration(
            frameInterval: 1.0 / 60.0,
            interpolationStep: 0.5 - (0.18 * clampedResponse),
            duration: dur,
            initialRadius: 0.42 + (0.32 * clampedSpread),
            maxRadius: maxRad,
            growthExponent: 1.06 + (0.2 * clampedResponse),
            peakProgress: 0.6 + (0.12 * clampedSpread),
            endRadius: 0.28 + (0.24 * clampedTrail),
            contractionExponent: cExp,
            boundaryThickness: 0.88 + (0.48 * clampedSpread),
            scrambleCharacters: ASCIIRippleConfiguration().characters,
            surfaceCharacters: Array(repeating: "·", count: 32),
            restingSurfaceOpacity: 0.0,
            maxTrailCount: Int(round(104 + (96 * clampedTrail))),
            streamTailLength: 2.1 + (2.9 * clampedTrail),
            streamLongDragDistance: 3.6 + (2.6 * clampedTrail),
            streamVelocityReference: 34 - (12 * clampedResponse),
            streamCoreRadiusBoost: 0.56 + (0.34 * clampedSpread),
            streamAdaptiveStepBoost: 0.32 + (0.28 * clampedResponse),
            streamBubbleStride: max(2, 5 - Int(round(2 * clampedTrail))),
            streamBubbleOffset: 0.82 + (0.56 * clampedTrail),
            streamBubbleBacktrack: 0.54 + (0.34 * clampedTrail),
            streamBubbleRadiusScale: 0.38 + (0.24 * clampedTrail),
            streamBubbleFastScaleBoost: 0.2 + (0.2 * clampedResponse),
            streamSwingMaxOffset: (0.44 + (0.5 * clampedSpread)) + (clampedTurbulence * 0.7),
            streamSwingCycles: (0.92 + (0.52 * clampedTrail)) + (clampedTurbulence * 0.65),
            streamHeadAgeBoost: 0.04 + (0.14 * clampedTrail),
            overlayOpacity: clampedOpacity,
            scrambleShellOpacity: clampedOpacity * (0.16 + (0.42 * clampedBlur)),
            scrambleShellBlur: clampedBlur
        )
    }
}

struct LandingASCIIWakeFieldLayout: Equatable, Sendable {
    struct CellPosition: Equatable, Sendable {
        let column: Int
        let row: Int
    }

    let columns: Int
    let rows: Int
    let hiddenCharacters: [Character]
    let surfaceCharacters: [Character]
    let blankCharacters: [Character]
    let cellPositions: [CellPosition?]

    var hiddenText: String { String(hiddenCharacters) }
    var surfaceText: String { String(surfaceCharacters) }
    var blankText: String { String(blankCharacters) }
}

enum LandingASCIIWakeFieldEngine {
    struct OverlayLayers: Equatable {
        let revealText: String
        let shellText: String
    }

    struct ResolvedTrail: Equatable {
        let x: CGFloat
        let y: CGFloat
        let radius: CGFloat
        let radiusSquared: CGFloat
        let revealRadius: CGFloat
        let minColumn: Int
        let maxColumn: Int
        let minRow: Int
        let maxRow: Int
        let scramblePhase: Int
    }

    struct TrailPoint: Equatable {
        let x: CGFloat
        let y: CGFloat
    }

    struct TrailSample: Equatable {
        let point: TrailPoint
        let radiusScale: CGFloat
        let ageOffset: TimeInterval

        init(point: TrailPoint, radiusScale: CGFloat, ageOffset: TimeInterval = 0) {
            self.point = point
            self.radiusScale = radiusScale
            self.ageOffset = ageOffset
        }
    }

    static func localHoverLocation(from location: CGPoint, in frame: CGRect) -> CGPoint {
        CGPoint(
            x: location.x - frame.minX,
            y: location.y - frame.minY
        )
    }

    static func trailPoint(
        for location: CGPoint,
        columns: Int,
        rows: Int,
        charWidth: CGFloat,
        lineHeight: CGFloat,
        horizontalInset: CGFloat = 26,
        verticalInset: CGFloat = 22
    ) -> TrailPoint {
        TrailPoint(
            x: max(0, min(CGFloat(columns - 1), (location.x - horizontalInset) / charWidth)),
            y: max(0, min(CGFloat(rows - 1), (location.y - verticalInset) / lineHeight))
        )
    }

    static func normalizedVocabulary(from values: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []

        for value in values {
            let trimmed = value
                .uppercased()
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let capped = String(trimmed.prefix(40))
            guard seen.insert(capped).inserted else { continue }
            output.append(capped)
        }

        if output.isEmpty {
            return ["EPISTEMOS", "RESEARCH", "KNOWLEDGE GRAPH", "NEW NOTE", "COMMAND PALETTE"]
        }

        return output
    }

    static func layout(
        vocabulary: [String],
        columns: Int,
        rows: Int,
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> LandingASCIIWakeFieldLayout {
        let safeColumns = max(columns, 1)
        let safeRows = max(rows, 1)
        let requiredCells = safeColumns * safeRows
        let stream = Array((normalizedVocabulary(from: vocabulary).joined(separator: " · ") + " · "))
        let hiddenStream = stream.isEmpty ? Array("EPISTEMOS · ") : stream

        var hidden: [Character] = []
        hidden.reserveCapacity(requiredCells + safeRows - 1)

        var surface: [Character] = []
        surface.reserveCapacity(requiredCells + safeRows - 1)

        var blanks: [Character] = []
        blanks.reserveCapacity(requiredCells + safeRows - 1)

        var positions: [LandingASCIIWakeFieldLayout.CellPosition?] = []
        positions.reserveCapacity(requiredCells + safeRows - 1)

        var hiddenIndex = 0
        for row in 0..<safeRows {
            for column in 0..<safeColumns {
                hidden.append(hiddenStream[hiddenIndex % hiddenStream.count])
                surface.append(configuration.surfaceCharacters[(row * safeColumns + column) % configuration.surfaceCharacters.count])
                blanks.append(" ")
                positions.append(.init(column: column, row: row))
                hiddenIndex += 1
            }
            if row < safeRows - 1 {
                hidden.append("\n")
                surface.append("\n")
                blanks.append("\n")
                positions.append(nil)
            }
        }

        return LandingASCIIWakeFieldLayout(
            columns: safeColumns,
            rows: safeRows,
            hiddenCharacters: hidden,
            surfaceCharacters: surface,
            blankCharacters: blanks,
            cellPositions: positions
        )
    }

    static func hasActiveTrails(
        _ trails: [LandingASCIIWakeTrail],
        now: TimeInterval,
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> Bool {
        for trail in trails where now - trail.startTime < configuration.duration {
            return true
        }
        return false
    }

    static func prunedTrails(
        _ trails: [LandingASCIIWakeTrail],
        now: TimeInterval,
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> [LandingASCIIWakeTrail] {
        guard !trails.isEmpty else { return [] }

        var output: [LandingASCIIWakeTrail] = []
        output.reserveCapacity(trails.count)
        for trail in trails where now - trail.startTime < configuration.duration {
            output.append(trail)
        }
        return output
    }

    static func nextTrailCleanupDelay(
        _ trails: [LandingASCIIWakeTrail],
        now: TimeInterval,
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> TimeInterval? {
        var nextDelay: TimeInterval?

        for trail in trails {
            let delay = trail.startTime + configuration.duration - now
            guard delay > 0 else { continue }
            if let currentDelay = nextDelay {
                if delay < currentDelay {
                    nextDelay = delay
                }
            } else {
                nextDelay = delay
            }
        }

        return nextDelay
    }

    static func interpolatedPath(
        from start: TrailPoint,
        to end: TrailPoint,
        maxStep: CGFloat = 0.4
    ) -> [TrailPoint] {
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        guard distance > 0 else { return [] }

        let steps = max(Int(ceil(distance / max(maxStep, 0.05))), 1)
        var output: [TrailPoint] = []
        output.reserveCapacity(steps)

        for step in 1...steps {
            let progress = CGFloat(step) / CGFloat(steps)
            let point = TrailPoint(
                x: start.x + deltaX * progress,
                y: start.y + deltaY * progress
            )
            if output.last != point {
                output.append(point)
            }
        }

        return output
    }

    static func streamInterpolationStep(
        distance: CGFloat,
        eventDelta: TimeInterval?,
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> CGFloat {
        let intensity = streamIntensity(
            distance: distance,
            eventDelta: eventDelta,
            configuration: configuration
        )
        let baseStep = max(configuration.interpolationStep, 0.05)
        return baseStep * (1 + intensity * configuration.streamAdaptiveStepBoost)
    }

    static func streamPath(
        from start: TrailPoint,
        to end: TrailPoint,
        maxStep: CGFloat = 0.4,
        tailLength: CGFloat
    ) -> [TrailPoint] {
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        guard distance > 0 else { return [end] }

        let step = max(maxStep, 0.05)
        let normalizedX = deltaX / distance
        let normalizedY = deltaY / distance
        let tailSteps = max(Int(ceil(max(tailLength, 0) / step)), 0)
        let movementPoints = interpolatedPath(from: start, to: end, maxStep: step)
        var output: [TrailPoint] = []
        output.reserveCapacity(tailSteps + movementPoints.count + 1)

        if tailSteps > 0 {
            for stepIndex in stride(from: tailSteps, through: 1, by: -1) {
                let tailDistance = CGFloat(stepIndex) * step
                let point = TrailPoint(
                    x: end.x - normalizedX * tailDistance,
                    y: end.y - normalizedY * tailDistance
                )
                if output.last != point {
                    output.append(point)
                }
            }
        }

        for point in movementPoints {
            if output.last != point {
                output.append(point)
            }
        }
        if output.last != end {
            output.append(end)
        }

        return output
    }

    static func streamTrailSamples(
        from start: TrailPoint,
        to end: TrailPoint,
        eventDelta: TimeInterval? = nil,
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> [TrailSample] {
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        guard distance > 0 else {
            return [.init(point: end, radiusScale: 1)]
        }

        let normalizedX = deltaX / distance
        let normalizedY = deltaY / distance
        let normalX = -normalizedY
        let normalY = normalizedX
        let intensity = streamIntensity(
            distance: distance,
            eventDelta: eventDelta,
            configuration: configuration
        )
        let interpolationStep = streamInterpolationStep(
            distance: distance,
            eventDelta: eventDelta,
            configuration: configuration
        )
        // Extend tail during intense drags to maintain water continuity
        let dynamicTailLength = configuration.streamTailLength * (1 + intensity * 0.5)
        let swingAmplitude = configuration.streamSwingMaxOffset * intensity
        let headAgeOffset = configuration.streamHeadAgeBoost * Double(intensity)
        let path = streamPath(
            from: start,
            to: end,
            maxStep: interpolationStep,
            tailLength: dynamicTailLength
        )
        var output: [TrailSample] = []
        output.reserveCapacity(path.count + path.count / max(configuration.streamBubbleStride, 1))

        let bubbleStride = max(configuration.streamBubbleStride, 2)
        var bubbleOrdinal = 0
        let progressDivisor = CGFloat(max(path.count - 1, 1))
        for (index, point) in path.enumerated() {
            let progress = CGFloat(index) / progressDivisor
            let swingTaper = sqrt(progress)
            let swing = sin(progress * .pi * configuration.streamSwingCycles) * swingAmplitude * swingTaper
            let streamPoint = TrailPoint(
                x: point.x + normalX * swing,
                y: point.y + normalY * swing
            )
            let streamRadiusScale = 1 + configuration.streamCoreRadiusBoost * intensity * progress
            let streamAgeOffset = headAgeOffset * Double(progress)

            if output.last?.point != streamPoint
                || output.last?.radiusScale != streamRadiusScale
                || output.last?.ageOffset != streamAgeOffset {
                output.append(
                    .init(
                        point: streamPoint,
                        radiusScale: streamRadiusScale,
                        ageOffset: streamAgeOffset
                    )
                )
            }

            guard index >= 2, index < path.count - 1, index.isMultiple(of: bubbleStride) else { continue }
            let side: CGFloat = bubbleOrdinal.isMultiple(of: 2) ? 1 : -1
            bubbleOrdinal += 1

            // Add swing to bubbles during intense movement for "water splash" effect
            let bubbleSwing = sin(progress * .pi * configuration.streamSwingCycles * 1.5) * swingAmplitude * 0.5 * intensity
            let bubblePoint = TrailPoint(
                x: streamPoint.x - normalizedX * configuration.streamBubbleBacktrack + normalX * side * configuration.streamBubbleOffset + normalX * bubbleSwing,
                y: streamPoint.y - normalizedY * configuration.streamBubbleBacktrack + normalY * side * configuration.streamBubbleOffset + normalY * bubbleSwing
            )
            // Ensure minimum bubble size during intense movement (prevents "tiny bubble" issue)
            let minBubbleScale: CGFloat = 0.4 + (intensity * 0.3)
            let bubbleRadiusScale = max(minBubbleScale, configuration.streamBubbleRadiusScale
                * (1 + configuration.streamBubbleFastScaleBoost * intensity))
            let bubbleAgeOffset = headAgeOffset * Double(max(progress - 0.1, 0))
            output.append(
                .init(
                    point: bubblePoint,
                    radiusScale: bubbleRadiusScale,
                    ageOffset: bubbleAgeOffset
                )
            )
        }

        return output
    }

    static func blastTrailSamples(
        at point: TrailPoint,
        blastPower: Double
    ) -> [TrailSample] {
        let clampedBlastPower = max(0, min(100, blastPower))
        guard clampedBlastPower > 0 else { return [] }

        let particleCount = max(Int(round(clampedBlastPower * 0.8)), 1)
        let radiusScale = 5.0 + (clampedBlastPower * 0.05)
        var output: [TrailSample] = []
        output.reserveCapacity(particleCount)

        for index in 0..<particleCount {
            output.append(
                TrailSample(
                    point: point,
                    radiusScale: radiusScale,
                    ageOffset: Double(index) * 0.015
                )
            )
        }

        return output
    }

    private static func streamIntensity(
        distance: CGFloat,
        eventDelta: TimeInterval?,
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> CGFloat {
        let distanceFactor = min(max(distance / max(configuration.streamLongDragDistance, 0.1), 0), 1)
        guard let eventDelta else { return distanceFactor }

        let safeDelta = max(CGFloat(eventDelta), 1.0 / 240.0)
        let velocity = distance / safeDelta
        let velocityFactor = min(max(velocity / max(configuration.streamVelocityReference, 0.1), 0), 1)
        return max(distanceFactor, velocityFactor)
    }

    static func clampedTrailSamples(
        _ rawSamples: [TrailSample],
        columns: Int,
        rows: Int
    ) -> [TrailSample] {
        guard !rawSamples.isEmpty else { return [] }

        let maxColumn = CGFloat(max(columns - 1, 0))
        let maxRow = CGFloat(max(rows - 1, 0))
        var output: [TrailSample] = []
        output.reserveCapacity(rawSamples.count)

        for rawSample in rawSamples {
            let sample = TrailSample(
                point: TrailPoint(
                    x: max(0, min(maxColumn, rawSample.point.x)),
                    y: max(0, min(maxRow, rawSample.point.y))
                ),
                radiusScale: rawSample.radiusScale,
                ageOffset: rawSample.ageOffset
            )
            if output.last != sample {
                output.append(sample)
            }
        }

        return output
    }

    static func radius(
        progress: TimeInterval,
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> CGFloat {
        let clamped = min(max(progress, 0), 1)
        let peak = min(max(configuration.peakProgress, 0.05), 0.95)

        if clamped <= peak {
            let normalized = CGFloat(clamped / peak)
            let shaped = pow(normalized, configuration.growthExponent)
            return configuration.initialRadius + shaped * (configuration.maxRadius - configuration.initialRadius)
        }

        let tailProgress = CGFloat((clamped - peak) / (1 - peak))
        let shaped = pow(tailProgress, configuration.contractionExponent)
        return configuration.maxRadius - shaped * (configuration.maxRadius - configuration.endRadius)
    }

    static func resolvedTrails(
        _ trails: [LandingASCIIWakeTrail],
        now: TimeInterval,
        configuration: LandingASCIIWakeFieldConfiguration,
        columns: Int,
        rows: Int
    ) -> [ResolvedTrail] {
        guard !trails.isEmpty, columns > 0, rows > 0 else { return [] }

        var output: [ResolvedTrail] = []
        output.reserveCapacity(trails.count)

        for trail in trails {
            let age = now - trail.startTime
            guard age >= 0, age < configuration.duration else { continue }

            let progress = age / configuration.duration
            let radius = radius(progress: progress, configuration: configuration) * trail.radiusScale
            guard radius > 0 else { continue }

            let boundaryThickness = max(0.35, configuration.boundaryThickness * max(trail.radiusScale, 0.7))
            let blur = max(0, min(configuration.scrambleShellBlur, 1))
            let scrambleShellThickness = max(
                boundaryThickness * (0.78 + (blur * 1.1)),
                radius * (0.08 + (blur * 0.2))
            )
            let revealRadius = max(0, radius - scrambleShellThickness)
            let minColumn = max(0, Int(floor(trail.x - radius)))
            let maxColumn = min(columns - 1, Int(ceil(trail.x + radius)))
            let minRow = max(0, Int(floor(trail.y - radius)))
            let maxRow = min(rows - 1, Int(ceil(trail.y + radius)))
            guard minColumn <= maxColumn, minRow <= maxRow else { continue }

            output.append(
                ResolvedTrail(
                    x: trail.x,
                    y: trail.y,
                    radius: radius,
                    radiusSquared: radius * radius,
                    revealRadius: revealRadius,
                    minColumn: minColumn,
                    maxColumn: maxColumn,
                    minRow: minRow,
                    maxRow: maxRow,
                    scramblePhase: Int(age / 0.035)
                )
            )
        }

        return output
    }

    static func overlayLayers(
        layout: LandingASCIIWakeFieldLayout,
        now: TimeInterval,
        trails: [LandingASCIIWakeTrail],
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> OverlayLayers {
        let activeTrails = resolvedTrails(
            trails,
            now: now,
            configuration: configuration,
            columns: layout.columns,
            rows: layout.rows
        )
        guard !activeTrails.isEmpty else {
            return OverlayLayers(
                revealText: layout.blankText,
                shellText: layout.blankText
            )
        }

        var revealOutput = layout.blankCharacters
        var shellOutput = layout.blankCharacters
        var revealStrengths = Array(
            repeating: -CGFloat.greatestFiniteMagnitude,
            count: revealOutput.count
        )
        var shellStrengths = Array(
            repeating: -CGFloat.greatestFiniteMagnitude,
            count: shellOutput.count
        )
        let shellStride = 7 + Int(round(configuration.scrambleShellBlur * 12))

        for trail in activeTrails {
            for row in trail.minRow...trail.maxRow {
                let dy = CGFloat(row) - trail.y
                let dySquared = dy * dy
                let rowBase = row * (layout.columns + 1)

                for column in trail.minColumn...trail.maxColumn {
                    let dx = CGFloat(column) - trail.x
                    let distanceSquared = dx * dx + dySquared
                    guard distanceSquared < trail.radiusSquared else { continue }

                    let distance = sqrt(distanceSquared)
                    let characterIndex = rowBase + column

                    if distance >= trail.revealRadius {
                        let strength = trail.radius - distance
                        guard strength > shellStrengths[characterIndex] else { continue }
                        shellStrengths[characterIndex] = strength
                        let scrambleIndex = Int((distance - trail.revealRadius) * CGFloat(shellStride)) + trail.scramblePhase
                        shellOutput[characterIndex] = configuration.scrambleCharacters[scrambleIndex % configuration.scrambleCharacters.count]
                    } else {
                        let strength = trail.revealRadius - distance
                        guard strength > revealStrengths[characterIndex] else { continue }
                        revealStrengths[characterIndex] = strength
                        revealOutput[characterIndex] = layout.hiddenCharacters[characterIndex]
                    }
                }
            }
        }

        return OverlayLayers(
            revealText: String(revealOutput),
            shellText: String(shellOutput)
        )
    }

    static func overlayText(
        layout: LandingASCIIWakeFieldLayout,
        now: TimeInterval,
        trails: [LandingASCIIWakeTrail],
        configuration: LandingASCIIWakeFieldConfiguration
    ) -> String {
        let layers = overlayLayers(
            layout: layout,
            now: now,
            trails: trails,
            configuration: configuration
        )
        let revealCharacters = Array(layers.revealText)
        let shellCharacters = Array(layers.shellText)
        guard revealCharacters.count == shellCharacters.count else {
            return layers.revealText
        }
        var output = revealCharacters
        for index in output.indices where output[index] == " " && shellCharacters[index] != " " {
            output[index] = shellCharacters[index]
        }
        return String(output)
    }
}


private struct LandingASCIIWakeField: View {
    let vocabulary: [String]
    let theme: EpistemosTheme
    let pointerState: LandingPointerState
    let surface: LandingCursorSurface

    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var layout = LandingASCIIWakeFieldLayout(
        columns: 1,
        rows: 1,
        hiddenCharacters: [" "],
        surfaceCharacters: ["·"],
        blankCharacters: [" "],
        cellPositions: [.init(column: 0, row: 0)]
    )
    @State private var trails: [LandingASCIIWakeTrail] = []
    @State private var lastHoverPoint: LandingASCIIWakeFieldEngine.TrailPoint?
    @State private var lastHoverTime: TimeInterval?
    @State private var trailCleanupTask: Task<Void, Never>?

    // Cached configuration — rebuilt only when slider values change.
    @State private var cachedConfiguration = LandingASCIIWakeFieldConfiguration()

    private let fontSize: CGFloat = 11
    private let lineSpacing: CGFloat = 3

    private var charWidth: CGFloat { fontSize * 0.64 }
    private var lineHeight: CGFloat { fontSize + lineSpacing + 2 }
    private var shouldAnimate: Bool {
        !reduceMotion && !ui.windowOccluded && ui.landingCursorAnimationEnabled
    }
    private var hasExternalHover: Bool {
        pointerState.location != nil
    }

    /// Key built from the slider values — when this changes, recache configuration.
    private var configurationKey: String {
        "\(ui.landingCursorResponse)_\(ui.landingCursorSpread)_\(ui.landingCursorTrail)_\(ui.landingCursorViscosity)_\(ui.landingCursorTurbulence)_\(ui.landingCursorOpacity)_\(ui.landingCursorBlur)"
    }

    var body: some View {
        GeometryReader { proxy in
            let columns = max(Int(proxy.size.width / charWidth), 12)
            let rows = max(Int(proxy.size.height / lineHeight), 10)

            ZStack(alignment: .topLeading) {
                if cachedConfiguration.restingSurfaceOpacity > 0 {
                    Text(layout.surfaceText)
                        .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                        .lineSpacing(lineSpacing)
                        .foregroundStyle(theme.textTertiary.opacity(cachedConfiguration.restingSurfaceOpacity))
                }

                if shouldAnimate, !trails.isEmpty {
                    TimelineView(
                        .animation(
                            minimumInterval: hasExternalHover
                                ? cachedConfiguration.frameInterval
                                : (1.0 / 36.0)
                        )
                    ) { context in
                        let overlayLayers = LandingASCIIWakeFieldEngine.overlayLayers(
                            layout: layout,
                            now: context.date.timeIntervalSinceReferenceDate,
                            trails: trails,
                            configuration: cachedConfiguration
                        )
                        ZStack(alignment: .topLeading) {
                            Text(overlayLayers.shellText)
                                .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                                .lineSpacing(lineSpacing)
                                .foregroundStyle(
                                    theme.fontAccent.opacity(
                                        min(
                                            1,
                                            (theme.isDark ? 0.72 : 0.64)
                                                * cachedConfiguration.scrambleShellOpacity
                                        )
                                    )
                                )

                            Text(overlayLayers.revealText)
                                .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
                                .lineSpacing(lineSpacing)
                                .foregroundStyle(
                                    theme.fontAccent.opacity(
                                        min(
                                            1,
                                            (theme.isDark ? 0.72 : 0.64)
                                                * cachedConfiguration.overlayOpacity
                                        )
                                    )
                                )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 26)
            .padding(.vertical, 22)
            .mask(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.9),
                        .white,
                        .white.opacity(0.9),
                        .clear,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .contentShape(Rectangle())
            .onAppear {
                recacheConfiguration()
                rebuildLayout(columns: columns, rows: rows)
            }
            .onChange(of: columns) { _, newValue in
                rebuildLayout(columns: newValue, rows: rows)
            }
            .onChange(of: rows) { _, newValue in
                rebuildLayout(columns: columns, rows: newValue)
            }
            .onChange(of: vocabulary) { _, _ in
                rebuildLayout(columns: columns, rows: rows)
            }
            .onChange(of: configurationKey) { _, _ in
                recacheConfiguration()
                rebuildLayout(columns: columns, rows: rows)
                if !trails.isEmpty {
                    scheduleTrailCleanup()
                }
            }
            .onContinuousHover { phase in
                guard shouldAnimate, !hasExternalHover else { return }
                switch phase {
                case .active(let location):
                    handleHover(location: location, columns: columns, rows: rows)
                case .ended:
                    lastHoverPoint = nil
                    lastHoverTime = nil
                }
            }
            .onChange(of: pointerState.location) { _, newValue in
                guard shouldAnimate, let location = newValue else {
                    if newValue == nil {
                        lastHoverPoint = nil
                        lastHoverTime = nil
                    }
                    return
                }
                let localLocation = LandingASCIIWakeFieldEngine.localHoverLocation(
                    from: location,
                    in: proxy.frame(in: .named(LandingCoordinateSpace.root))
                )
                handleHover(location: localLocation, columns: columns, rows: rows)
            }
            .onChange(of: pointerState.tapToken) { _, _ in
                guard shouldAnimate, let location = pointerState.tapLocation else { return }
                let localLocation = LandingASCIIWakeFieldEngine.localHoverLocation(
                    from: location,
                    in: proxy.frame(in: .named(LandingCoordinateSpace.root))
                )
                emitBlast(at: localLocation, columns: columns, rows: rows)
            }
            .onChange(of: shouldAnimate) { _, newValue in
                guard !newValue else { return }
                trails.removeAll(keepingCapacity: false)
                lastHoverPoint = nil
                lastHoverTime = nil
                trailCleanupTask?.cancel()
                trailCleanupTask = nil
            }
        }
        .onDisappear {
            trailCleanupTask?.cancel()
            trailCleanupTask = nil
        }
        .allowsHitTesting(true)
    }

    private func handleHover(location: CGPoint, columns: Int, rows: Int) {
        let point = LandingASCIIWakeFieldEngine.trailPoint(
            for: location,
            columns: columns,
            rows: rows,
            charWidth: charWidth,
            lineHeight: lineHeight
        )
        let now = Date.timeIntervalSinceReferenceDate
        if let lastHoverPoint, lastHoverPoint != point {
            let eventDelta = lastHoverTime.map { now - $0 }
            let rawSamples = LandingASCIIWakeFieldEngine.streamTrailSamples(
                from: lastHoverPoint,
                to: point,
                eventDelta: eventDelta,
                configuration: cachedConfiguration
            )
            appendTrailSamples(rawSamples, now: now, columns: columns, rows: rows)
        } else if lastHoverPoint == nil {
            appendTrailSamples(
                [LandingASCIIWakeFieldEngine.TrailSample(point: point, radiusScale: 1)],
                now: now,
                columns: columns,
                rows: rows
            )
        }
        lastHoverPoint = point
        lastHoverTime = now
    }

    private func emitBlast(at location: CGPoint, columns: Int, rows: Int) {
        let point = LandingASCIIWakeFieldEngine.trailPoint(
            for: location,
            columns: columns,
            rows: rows,
            charWidth: charWidth,
            lineHeight: lineHeight
        )
        let samples = LandingASCIIWakeFieldEngine.blastTrailSamples(
            at: point,
            blastPower: ui.landingCursorBlastPower
        )
        appendTrailSamples(
            samples,
            now: Date.timeIntervalSinceReferenceDate,
            columns: columns,
            rows: rows
        )
    }

    private func appendTrailSamples(
        _ rawSamples: [LandingASCIIWakeFieldEngine.TrailSample],
        now: TimeInterval,
        columns: Int,
        rows: Int
    ) {
        let samples = LandingASCIIWakeFieldEngine.clampedTrailSamples(
            rawSamples,
            columns: columns,
            rows: rows
        )
        guard !samples.isEmpty else { return }

        trails = LandingASCIIWakeFieldEngine.prunedTrails(
            trails,
            now: now,
            configuration: cachedConfiguration
        )

        let timeStride = min(0.01, cachedConfiguration.duration / Double(max(samples.count * 5, 1)))
        trails.reserveCapacity(max(trails.count + samples.count, cachedConfiguration.maxTrailCount))
        for (index, sample) in samples.enumerated() {
            trails.append(
                LandingASCIIWakeTrail(
                    x: sample.point.x,
                    y: sample.point.y,
                    startTime: now - timeStride * Double(samples.count - index - 1) - sample.ageOffset,
                    radiusScale: sample.radiusScale
                )
            )
        }
        if trails.count > cachedConfiguration.maxTrailCount {
            trails.removeFirst(trails.count - cachedConfiguration.maxTrailCount)
        }
        scheduleTrailCleanup()
    }

    private func rebuildLayout(columns: Int, rows: Int) {
        layout = LandingASCIIWakeFieldEngine.layout(
            vocabulary: vocabulary,
            columns: columns,
            rows: rows,
            configuration: cachedConfiguration
        )
    }

    private func recacheConfiguration() {
        cachedConfiguration = LandingASCIIWakeFieldConfiguration.tuned(
            response: ui.landingCursorResponse,
            spread: ui.landingCursorSpread,
            trail: ui.landingCursorTrail,
            viscosity: ui.landingCursorViscosity,
            turbulence: ui.landingCursorTurbulence,
            opacity: ui.landingCursorOpacity,
            blur: ui.landingCursorBlur
        )
    }

    private func scheduleTrailCleanup() {
        trailCleanupTask?.cancel()

        let now = Date.timeIntervalSinceReferenceDate
        guard let delay = LandingASCIIWakeFieldEngine.nextTrailCleanupDelay(
            trails,
            now: now,
            configuration: cachedConfiguration
        ) else {
            trailCleanupTask = nil
            return
        }

        trailCleanupTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(max(Int(ceil(delay * 1000)), 1)))
            guard !Task.isCancelled else { return }

            trails = LandingASCIIWakeFieldEngine.prunedTrails(
                trails,
                now: Date.timeIntervalSinceReferenceDate,
                configuration: cachedConfiguration
            )

            if trails.isEmpty {
                trailCleanupTask = nil
            } else {
                scheduleTrailCleanup()
            }
        }
    }
}
