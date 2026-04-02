import SwiftUI

// Hermes session panel kept separate from the legacy Omega runtime surface.
struct AgentSessionPanel: View {
    @Bindable var viewModel: AgentViewModel
    @State private var prompt = ""
    @State private var searchText = ""
    @FocusState private var promptFocused: Bool

    var body: some View {
        ZStack {
            panelBackdrop

            VStack(spacing: 12) {
                header
                content
                promptComposer
            }
            .padding(18)
        }
        .frame(minWidth: 420, minHeight: 320)
        .task {
            await viewModel.prepareRuntimeIfNeeded()
        }
    }

    private var panelBackdrop: some View {
        Color(nsColor: .windowBackgroundColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Agent Runtime")
                        .font(.headline.weight(.semibold))
                    Text("Hermes cloud runtime with persistent sessions and tool approvals")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(Color.blue.opacity(0.14))
                    )
            }

            Spacer(minLength: 12)

            if let session = viewModel.activeSessionSummary {
                RuntimeStatusBadge(
                    title: session.shortID,
                    systemImage: "clock.arrow.circlepath",
                    tint: .secondary
                )
            }

            commandsMenu
            sessionMenu

            if case .failed = viewModel.phase {
                Button("Retry") {
                    Task { await viewModel.prepareRuntimeIfNeeded() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if viewModel.isRunning {
                Button("Stop") {
                    viewModel.stop()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.small)
            }
        }
    }

    private var sessionMenu: some View {
        Menu {
            Button("New Session") {
                viewModel.startNewSession()
            }

            Button("Fork Current Session") {
                viewModel.forkCurrentSession()
            }
            .disabled(viewModel.activeSessionID == nil)

            Button("Refresh Sessions") {
                viewModel.refreshSessions()
            }

            if !viewModel.sessions.isEmpty {
                Divider()
                ForEach(viewModel.sessions.prefix(12)) { session in
                    Button(
                        session.id == viewModel.activeSessionID
                            ? "Resume \(session.title) • Current"
                            : "Resume \(session.title) • \(session.shortID)"
                    ) {
                        viewModel.resume(sessionID: session.id)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.stack")
                Text(viewModel.activeSessionSummary?.shortID ?? "Sessions")
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .controlSize(.small)
    }

    private var commandsMenu: some View {
        Menu {
            Section("Inspect") {
                ForEach([HermesQuickAction.help, .model, .tools, .context, .version]) { action in
                    commandMenuButton(action)
                }
            }

            Section("Session") {
                ForEach([HermesQuickAction.compact, .reset]) { action in
                    commandMenuButton(action)
                }
            }

            Section("Admin") {
                Button {
                    UtilityWindowManager.shared.show(.settings)
                } label: {
                    Label("Cron Jobs", systemImage: "clock.arrow.circlepath")
                }
                Button {
                    UtilityWindowManager.shared.show(.settings)
                } label: {
                    Label("MCP Servers", systemImage: "server.rack")
                }
                Button {
                    UtilityWindowManager.shared.show(.settings)
                } label: {
                    Label("Tools Config", systemImage: "wrench.and.screwdriver")
                }
            }

            Divider()

            Button {
                UtilityWindowManager.shared.show(.settings)
            } label: {
                Label("Cloud AI Settings", systemImage: "gearshape")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "command.circle")
                Text("Hermes Commands")
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .controlSize(.small)
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 16) {
            sessionRail
            transcriptSurface
        }
    }

    private var sessionRail: some View {
        RuntimeGlassCard(cornerRadius: 26, padding: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sessions")
                            .font(.subheadline.weight(.semibold))
                        Text("\(viewModel.sessions.count) available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    railButton(systemImage: "plus", helpText: "Start a fresh Hermes session") {
                        viewModel.startNewSession()
                    }

                    railButton(
                        systemImage: "arrow.triangle.branch",
                        helpText: "Fork the current Hermes session",
                        disabled: viewModel.activeSessionID == nil
                    ) {
                        viewModel.forkCurrentSession()
                    }

                    railButton(systemImage: "arrow.clockwise", helpText: "Refresh Hermes sessions") {
                        viewModel.refreshSessions()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 12)

                TextField("Search sessions...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
                    .onSubmit {
                        viewModel.searchSessions(query: searchText)
                    }
                    .onChange(of: searchText) { _, newValue in
                        viewModel.searchSessions(query: newValue)
                    }

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if !searchText.isEmpty {
                            if viewModel.sessionSearchResults.isEmpty {
                                Text("No results for \"\(searchText)\"")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 4)
                            } else {
                                Text("Search Results")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(viewModel.sessionSearchResults) { session in
                                    sessionRow(session)
                                }
                                Divider()
                            }
                        }

                        ForEach(viewModel.sessions) { session in
                            sessionRow(session)
                        }

                        if viewModel.sessions.isEmpty && searchText.isEmpty {
                            emptySessionsView
                                .padding(.top, 6)
                        }
                    }
                    .padding(14)
                }
            }
        }
        .frame(width: 280)
    }

    private var transcriptSurface: some View {
        RuntimeGlassCard(cornerRadius: 28, padding: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Live Transcript")
                            .font(.subheadline.weight(.semibold))
                        Text(runtimeStatusTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if viewModel.tokenUsage.input > 0 || viewModel.tokenUsage.output > 0 {
                        RuntimeStatusBadge(
                            title: "\(viewModel.tokenUsage.input) in • \(viewModel.tokenUsage.output) out",
                            systemImage: "chart.bar.xaxis",
                            tint: .secondary
                        )
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                transcriptView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func railButton(
        systemImage: String,
        helpText: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.primary.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(helpText)
    }

    private func commandMenuButton(_ action: HermesQuickAction) -> some View {
        Button(role: action.isDestructive ? .destructive : nil) {
            viewModel.performQuickAction(action)
        } label: {
            Label(action.title, systemImage: action.systemImage)
        }
        .help(action.detail)
    }

    private var emptySessionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("No sessions yet", systemImage: "sparkles.rectangle.stack")
                .font(.subheadline.weight(.medium))

            Text("Start a fresh Hermes session or send a prompt. New runs appear here immediately, even before the turn finishes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Start New Session") {
                viewModel.startNewSession()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private func sessionRow(_ session: AgentSessionSummary) -> some View {
        Button {
            if !session.isActive {
                viewModel.resume(sessionID: session.id)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(session.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if session.isActive {
                        RuntimeStatusBadge(title: "Live", systemImage: "dot.radiowaves.left.and.right", tint: .blue)
                    } else {
                        Text(session.shortID)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }

                Text(session.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !session.preview.isEmpty {
                    Text(session.preview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(session.isActive ? Color.blue.opacity(0.14) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        session.isActive ? Color.blue.opacity(0.24) : Color.white.opacity(0.08),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var transcriptView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(viewModel.contentBlocks) { block in
                        renderedBlock(block)
                    }

                    livePhaseView

                    Color.clear
                        .frame(height: 1)
                        .id("agent-panel-bottom")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .onChange(of: viewModel.contentBlocks.count) { _, _ in
                // Fix: [Agent Hang] — debounce scroll to avoid layout thrashing
                // during rapid token streaming.
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("agent-panel-bottom", anchor: .bottom)
                }
            }
            .onChange(of: viewModel.turnCount) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("agent-panel-bottom", anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private var livePhaseView: some View {
        switch viewModel.phase {
        case .idle, .complete:
            if viewModel.contentBlocks.isEmpty {
                idleState
            }

        case .thinking(let tokenCount):
            if !viewModel.chainOfThoughtText.isEmpty {
                ChainOfThoughtBubble(
                    text: viewModel.chainOfThoughtText,
                    tokenCount: tokenCount,
                    completed: false
                )
            }
            if !viewModel.thinkingText.isEmpty {
                ThinkingBubble(
                    title: "Thinking",
                    text: viewModel.thinkingText,
                    tokenCount: tokenCount
                )
            }

        case .searching(let query):
            StatusRow(
                title: "Searching",
                detail: query,
                icon: "magnifyingglass",
                tint: .blue
            )

        case .executing(let toolName):
            ToolExecutionRow(
                toolName: toolName,
                input: nil,
                result: nil,
                isRunning: true,
                isError: false
            )

        case .reasoning(let tokenCount):
            ThinkingBubble(
                title: "Reasoning",
                text: viewModel.thinkingText,
                tokenCount: tokenCount,
                secondary: true
            )

        case .responding:
            if !viewModel.chainOfThoughtText.isEmpty {
                ChainOfThoughtBubble(
                    text: viewModel.chainOfThoughtText,
                    tokenCount: max(1, viewModel.chainOfThoughtText.count / 4),
                    completed: true
                )
            }
            ResponseBubble(
                text: viewModel.responseText,
                isStreaming: true
            )

        case .awaitingApproval(let request):
            AgentApprovalGateView(
                request: request,
                onApprove: { viewModel.resolvePermission(id: request.id, approved: true) },
                onDeny: { viewModel.resolvePermission(id: request.id, approved: false) }
            )

        case .failed(let message):
            ErrorBanner(message: message)
        }
    }

    @ViewBuilder
    private func renderedBlock(_ block: RenderedBlock) -> some View {
        switch block.kind {
        case .userPrompt(let text):
            UserPromptBubble(text: text)

        case .thinking(let text, let tokenCount):
            ThinkingBubble(
                title: "Thinking",
                text: text,
                tokenCount: tokenCount,
                completed: true
            )

        case .chainOfThought(let text, let tokenCount):
            ChainOfThoughtBubble(
                text: text,
                tokenCount: tokenCount,
                completed: true
            )

        case .text(let text):
            ResponseBubble(text: text, isStreaming: false)

        case .toolExecution(let name, let input, let result, let isError):
            ToolExecutionRow(
                toolName: name,
                input: input,
                result: result,
                isRunning: false,
                isError: isError
            )

        case .status(let text):
            StatusRow(
                title: "Runtime",
                detail: text,
                icon: "arrow.triangle.2.circlepath",
                tint: .orange
            )
        }
    }

    private var promptComposer: some View {
        RuntimeGlassCard(cornerRadius: 28, padding: 0) {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Ask the runtime…", text: $prompt, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...6)
                        .focused($promptFocused)
                        .font(.body)
                        .onSubmit(sendPrompt)

                    HStack(spacing: 8) {
                        RuntimeStatusBadge(
                            title: viewModel.activeSessionSummary?.title ?? "Hermes",
                            systemImage: "brain",
                            tint: .secondary
                        )
                        RuntimeStatusBadge(
                            title: runtimeStatusTitle,
                            systemImage: runtimeStatusIcon,
                            tint: runtimeTint
                        )
                    }
                }

                Spacer(minLength: 10)

                Button {
                    sendPrompt()
                } label: {
                    Image(systemName: viewModel.isRunning ? "stop.fill" : "arrow.up")
                        .font(.headline.weight(.semibold))
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(
                                    viewModel.isRunning
                                        ? Color.red.opacity(0.16)
                                        : (prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                            ? Color.secondary.opacity(0.12)
                                            : Color.blue.opacity(0.18))
                                )
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(
                    viewModel.isRunning
                        ? Color.red
                        : (prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.blue)
                )
                .disabled(!viewModel.isRunning && prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private var idleState: some View {
        VStack(spacing: 14) {
            Image(systemName: "brain.filled.head.profile")
                .font(.system(size: 38))
                .foregroundStyle(.blue.opacity(0.75))

            Text("Hermes is ready")
                .font(.headline.weight(.semibold))

            Text("This is your native macOS front end on top of the Hermes cloud agent loop. Start a session, fork one, or ask for a multi-step task and it will stream here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
    }

    private var runtimeStatusTitle: String {
        switch viewModel.phase {
        case .idle:
            return viewModel.sessions.isEmpty ? "Ready" : "Standing By"
        case .thinking:
            return "Thinking"
        case .searching:
            return "Searching"
        case .executing:
            return "Tool Run"
        case .reasoning:
            return "Reasoning"
        case .responding:
            return "Responding"
        case .awaitingApproval:
            return "Approval Needed"
        case .complete:
            return "Complete"
        case .failed:
            return "Needs Attention"
        }
    }

    private var runtimeTint: Color {
        switch viewModel.phase {
        case .failed:
            .orange
        case .awaitingApproval:
            .orange
        case .complete:
            .green
        case .idle:
            .blue
        default:
            .blue
        }
    }

    private var runtimeStatusIcon: String {
        switch viewModel.phase {
        case .failed:
            "exclamationmark.triangle.fill"
        case .awaitingApproval:
            "hand.raised.fill"
        case .complete:
            "checkmark.circle.fill"
        case .idle:
            "sparkles"
        case .searching:
            "magnifyingglass"
        case .executing:
            "wrench.and.screwdriver.fill"
        default:
            "brain"
        }
    }

    private func sendPrompt() {
        if viewModel.isRunning {
            viewModel.stop()
            return
        }

        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        prompt = ""
        viewModel.send(prompt: trimmed)
    }
}

private struct RuntimeGlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let padding: CGFloat
    let content: Content

    init(
        cornerRadius: CGFloat = 22,
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            }
    }
}

private struct RuntimeStatusBadge: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
            .foregroundStyle(tint)
    }
}

private struct ThinkingBubble: View {
    let title: String
    let text: String
    let tokenCount: Int
    var completed = false
    var secondary = false

    @State private var expanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            Text(text.isEmpty ? "…" : text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(secondary ? Color.orange.opacity(0.08) : Color.blue.opacity(0.08))
                )
        } label: {
            HStack(spacing: 8) {
                if !completed {
                    PulsingDot(tint: secondary ? .orange : .blue)
                }
                Text(title)
                    .font(.caption.bold())
                Text("~\(tokenCount) tokens")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(secondary ? .orange : .blue)
    }
}

/// Chain-of-thought bubble for distilled reasoning models (<think> blocks).
/// Renders with a blurred/frosted glass effect and starts collapsed to keep
/// the agent's internal monologue unobtrusive while still accessible.
private struct ChainOfThoughtBubble: View {
    let text: String
    let tokenCount: Int
    var completed = false

    @State private var expanded = false
    @State private var revealText = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            ZStack {
                Text(text.isEmpty ? "..." : text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.purple.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Color.purple.opacity(0.15), lineWidth: 1)
                            )
                    )
                    .blur(radius: revealText ? 0 : 4)
                    .animation(.easeInOut(duration: 0.3), value: revealText)

                if !revealText {
                    Button {
                        revealText = true
                    } label: {
                        Label("Reveal reasoning", systemImage: "eye")
                            .font(.caption.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        } label: {
            HStack(spacing: 8) {
                if !completed {
                    PulsingDot(tint: .purple)
                }
                Image(systemName: "brain.head.profile")
                    .font(.caption)
                    .foregroundStyle(.purple)
                Text("Chain of Thought")
                    .font(.caption.bold())
                Text("~\(tokenCount) tokens")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(.purple)
    }
}

private struct UserPromptBubble: View {
    let text: String

    var body: some View {
        HStack {
            Spacer(minLength: 48)
            Text(text)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: 420, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.blue.opacity(0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.blue.opacity(0.24), lineWidth: 1)
                )
        }
    }
}

private struct ResponseBubble: View {
    let text: String
    let isStreaming: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text + (isStreaming ? " ▊" : ""))
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                }
        }
    }
}

private struct ToolExecutionRow: View {
    let toolName: String
    let input: String?
    let result: String?
    let isRunning: Bool
    let isError: Bool

    @State private var expanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 10) {
                if let input, !input.isEmpty {
                    Text(input)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                if let result {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(isError ? .red : .secondary)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill((isError ? Color.red : Color.green).opacity(0.08))
            )
        } label: {
            HStack(spacing: 8) {
                if isRunning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(isError ? .red : .green)
                }
                Image(systemName: iconName)
                    .foregroundStyle(.secondary)
                Text(toolName)
                    .font(.caption.monospaced())
            }
        }
        .tint(.secondary)
    }

    private var iconName: String {
        switch toolName {
        case let name where name.contains("search"):
            return "magnifyingglass"
        case let name where name.contains("read"):
            return "doc.text"
        case let name where name.contains("write"):
            return "square.and.pencil"
        case let name where name.contains("bash"):
            return "terminal"
        default:
            return "wrench.and.screwdriver"
        }
    }
}

private struct AgentApprovalGateView: View {
    let request: AgentPermissionRequest
    let onApprove: () -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Approval Required")
                        .font(.subheadline.bold())
                    Text(request.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(request.toolName)
                .font(.caption.monospaced().bold())

            Text(request.inputJson)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                Button("Deny", action: onDeny)
                    .buttonStyle(.bordered)
                    .tint(.red)
                Button("Approve", action: onApprove)
                    .buttonStyle(.borderedProminent)
                    .tint(color)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(color.opacity(0.18), lineWidth: 1)
        )
    }

    private var color: Color {
        switch request.riskLevel {
        case .readOnly:
            return .green
        case .modification:
            return .orange
        case .destructive:
            return .red
        }
    }

    private var iconName: String {
        switch request.riskLevel {
        case .readOnly:
            return "eye"
        case .modification:
            return "square.and.pencil"
        case .destructive:
            return "exclamationmark.triangle.fill"
        }
    }
}

private struct StatusRow: View {
    let title: String
    let detail: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint.opacity(0.08))
        )
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
    }
}

private struct PulsingDot: View {
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(tint)
            .frame(width: 7, height: 7)
            .opacity(reduceMotion ? 1.0 : 0.96)
            .breathe(amplitude: 0.08, period: 1.6)
    }
}
