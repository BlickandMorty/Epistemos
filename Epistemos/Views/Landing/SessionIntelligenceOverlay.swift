import SwiftData
import SwiftUI

// MARK: - Session Intelligence Overlay
// Full-screen overlay triggered by Cmd+Ctrl+R. Shows a visual map of all open windows
// with per-window AI summaries typed progressively, followed by a global synthesis.
// Uses the Map-Reduce pipeline from WorkspaceSummaryService.

struct SessionIntelligenceOverlay: View {
    @Environment(UIState.self) private var ui
    @Binding var isPresented: Bool

    @State private var windowCards: [WindowCard] = []
    @State private var globalSynthesis = ""
    @State private var isGenerating = true
    @State private var appeared = false

    private var theme: EpistemosTheme { ui.theme }

    struct WindowCard: Identifiable {
        let id: String
        let title: String
        let icon: String
        let kind: String // "note", "chat", "graph"
        var summary: String = ""
        var wordCount: Int = 0
    }

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.4 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Session Intelligence")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Spacer()
                    if isGenerating {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.7)
                    }
                    Text("esc to close")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 14)

                Divider().opacity(0.3)

                // Window map
                ScrollView {
                    VStack(spacing: 12) {
                        // Window cards grid
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 12)], spacing: 12) {
                            ForEach(Array(windowCards.enumerated()), id: \.element.id) { index, card in
                                windowCardView(card)
                                    .springEntrance(index: index, stagger: 0.06)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                        // Global synthesis
                        if !globalSynthesis.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Divider().opacity(0.2)

                                Text("Session Focus")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(theme.textTertiary)
                                    .padding(.horizontal, 24)

                                TypewriterPlainText(content: globalSynthesis)
                                    .font(.system(size: 14.5, weight: .regular))
                                    .foregroundStyle(theme.fontAccent.opacity(0.85))
                                    .italic()
                                    .lineSpacing(5)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 24)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.bottom, 20)
                }
                .frame(maxHeight: 500)
            }
            .frame(width: 600)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.25), radius: 24, y: 10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.08))
            }
            .scaleEffect(appeared ? 1 : 0.95)
            .opacity(appeared ? 1 : 0)
            .foregroundStyle(theme.foreground)
        }
        .background {
            Button(action: { dismiss() }) {}
                .keyboardShortcut(.escape, modifiers: [])
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) { appeared = true }
            buildWindowCards()
            Task { await generateIntelligence() }
        }
    }

    // MARK: - Window Card View

    private func windowCardView(_ card: WindowCard) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: card.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle().fill(theme.accent.opacity(0.12))
                    )

                Text(card.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                Spacer()

                Text(card.kind)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.foreground.opacity(0.05), in: Capsule())
            }

            if card.wordCount > 0 {
                Text("\(card.wordCount) words")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
            }

            if !card.summary.isEmpty {
                Text(card.summary)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(3)
                    .italic()
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.foreground.opacity(0.03))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(theme.foreground.opacity(0.06))
        }
    }

    // MARK: - Data Collection

    private func buildWindowCards() {
        var cards: [WindowCard] = []

        // Note windows
        for pageId in NoteWindowManager.shared.orderedPageIds() {
            let title = NoteWindowManager.shared.navState(forTab: pageId)?.currentPageTitle ?? "Untitled"
            let body = NoteFileStorage.readBody(pageId: pageId, mapped: true)
            let wordCount = body.split(separator: " ").count
            cards.append(WindowCard(
                id: "note-\(pageId)", title: title, icon: "doc.text.fill",
                kind: "note", wordCount: wordCount
            ))
        }

        // Mini chats
        for chatId in MiniChatWindowController.shared.openChatIds {
            cards.append(WindowCard(
                id: "chat-\(chatId)", title: "Mini Chat", icon: "bubble.left.and.bubble.right.fill",
                kind: "chat"
            ))
        }

        // Graph
        if HologramController.shared.isVisible {
            let nodeCount = AppBootstrap.shared?.graphState.store.nodes.count ?? 0
            cards.append(WindowCard(
                id: "graph", title: "Knowledge Graph",
                icon: "point.3.connected.trianglepath.dotted",
                kind: HologramController.shared.isMinimized ? "mini graph" : "graph",
                wordCount: nodeCount
            ))
        }

        windowCards = cards
    }

    // MARK: - AI Generation (Map-Reduce)

    private func generateIntelligence() async {
        guard let summaryService = AppBootstrap.shared?.workspaceSummaryService else {
            isGenerating = false
            return
        }

        // Map phase: per-window summaries
        let perWindow = await summaryService.generatePerWindowSummaries()

        // Apply per-window summaries to cards
        for (title, summary) in perWindow {
            if let idx = windowCards.firstIndex(where: { $0.title == title }) {
                windowCards[idx].summary = summary
            }
        }

        // Reduce phase: global synthesis
        await summaryService.generateSummaryNow()
        if let workspace = try? AppBootstrap.shared?.modelContainer.mainContext.fetch(
            FetchDescriptor<SDWorkspace>(predicate: #Predicate<SDWorkspace> { $0.isAutoSave == true })
        ).first {
            globalSynthesis = workspace.summary
        }

        isGenerating = false
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.15)) { appeared = false }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            isPresented = false
        }
    }
}
