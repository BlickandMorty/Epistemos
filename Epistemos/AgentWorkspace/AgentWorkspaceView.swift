import SwiftUI

// Surface B — the June-style agent workspace (Plan 1-MAS §3.3). Deliberately
// DIFFERENT from Surface A (§3.4 anti-mixing): multi-pane, dense, stateful,
// agent furniture always visible. Verbs: do · research · revise · approve.
//
// Panes: session/step rail · center activity feed (cards mapped 1:1 to
// AgentEventDelegate events) · right document pane (last file the agent
// touched). The header reserves the mascot slot (Plan 5 ships the mascot;
// Plan 1 ships the slot).
struct AgentWorkspaceView: View {
    @Environment(UIState.self) private var ui

    @State private var session = AgentWorkspaceSession()
    @State private var consent = AgentCloudConsentStore()
    @State private var objectiveDraft = ""
    @State private var showConsentSheet = false
    @State private var showBoundedToolsExplainer = false
    @State private var documentText = ""
    @State private var documentPath: String?

    private var theme: EpistemosTheme { ui.theme }
    private var provider: AgentCloudProviderDescriptor {
        .descriptor(for: AgentWorkspaceSession.defaultProviderSlug)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                sessionRail
                    .frame(minWidth: 200, idealWidth: 230, maxWidth: 300)
                activityFeed
                    .frame(minWidth: 380, idealWidth: 520)
                documentPane
                    .frame(minWidth: 260, idealWidth: 340)
            }
        }
        .background(theme.resolved.background.color)
        .sheet(item: approvalBinding) { request in
            AgentApprovalSheet(request: request, theme: theme) { approved in
                session.resolveApproval(id: request.id, approved: approved)
            }
        }
        .sheet(isPresented: $showConsentSheet) {
            AgentCloudConsentSheet(provider: provider, theme: theme) { granted in
                showConsentSheet = false
                if granted {
                    consent.grant(provider)
                    launchPendingObjective()
                }
            }
        }
        .popover(isPresented: $showBoundedToolsExplainer, arrowEdge: .bottom) {
            boundedToolsExplainer
        }
        .onChange(of: session.lastTouchedFilePath) {
            loadTouchedDocument()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            // Mascot slot (Plan 5 ships the mascot; keep the geometry stable).
            AgentMascotSlot()
                .frame(width: 26, height: 26)

            Text("Agent Workspace")
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            Button {
                showBoundedToolsExplainer = true
            } label: {
                Label("Bounded on the App Store", systemImage: "checkmark.shield")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(theme.resolved.foreground.color.opacity(0.55))
            }
            .buttonStyle(.plain)
            .help("What this agent can and can't do in the App Store build")

            Spacer()

            if consent.hasConsent(for: provider.id) {
                Label(provider.displayName, systemImage: "cloud")
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.resolved.foreground.color.opacity(0.5))
                    .help("Runs use \(provider.displayName). Revocable in the consent settings.")
            }

            if session.isRunning {
                Button {
                    session.cancel()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private var boundedToolsExplainer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bounded on the App Store")
                .font(.system(size: 12, weight: .semibold))
            Text(
                """
                In this build the agent can read and write your vault, search \
                your knowledge, use the reasoning scratchpad, and fetch from a \
                fixed set of HTTPS services. It cannot run shell commands, \
                execute code, control other apps, or install extensions — \
                those capabilities exist only in the Developer edition.
                """
            )
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 330)
    }

    // MARK: - Session rail

    private var sessionRail: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sessions")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(theme.resolved.foreground.color.opacity(0.45))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            if session.runs.isEmpty {
                Text("Every run appears here with its steps.")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.resolved.foreground.color.opacity(0.4))
                    .padding(.horizontal, 12)
            }
            List(session.runs.reversed()) { run in
                VStack(alignment: .leading, spacing: 3) {
                    Text(run.objective)
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        if run.isActive {
                            ProgressView().controlSize(.mini)
                        }
                        Text("\(run.items.count) steps · \(run.startedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 3)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .background(theme.glassBg.opacity(theme.isDark ? 0.18 : 0.10))
    }

    // MARK: - Activity feed

    private var activityFeed: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if session.runs.isEmpty {
                            feedEmptyState
                        }
                        if let run = session.activeRun {
                            ForEach(run.items) { item in
                                AgentTimelineCard(item: item, theme: theme)
                                    .id(item.id)
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: session.activeRun?.items.count ?? 0) {
                    if let last = session.activeRun?.items.last?.id {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }
            Divider()
            objectiveBar
        }
    }

    private var feedEmptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Give the agent something to do.")
                .font(.system(size: 13, weight: .medium))
            Text("It works in deliberate steps — thinking, tools, and edits stream here, and anything risky waits for your approval.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var objectiveBar: some View {
        HStack(spacing: 10) {
            TextField("Do, research, or revise something…", text: $objectiveDraft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .lineLimit(1...3)
                .onSubmit(startRun)
                .disabled(session.isRunning)
            Button(action: startRun) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(
                        objectiveDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.isRunning
                            ? theme.resolved.foreground.color.opacity(0.25)
                            : theme.resolved.accent.color
                    )
            }
            .buttonStyle(.plain)
            .disabled(objectiveDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.isRunning)
            .help("Start the run")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Document pane

    private var documentPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(documentPath.map { ($0 as NSString).lastPathComponent } ?? "Document")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(theme.resolved.foreground.color.opacity(0.45))
                Spacer()
                if documentPath != nil {
                    Button("Save") { saveTouchedDocument() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(theme.resolved.accent.color)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider().opacity(0.3)
            if documentPath == nil {
                Text("When the agent reads or writes a document, it opens here for you to review and edit.")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.resolved.foreground.color.opacity(0.4))
                    .padding(12)
                Spacer()
            } else {
                TextEditor(text: $documentText)
                    .font(.system(size: 11.5, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
            }
        }
        .background(theme.glassBg.opacity(theme.isDark ? 0.12 : 0.06))
    }

    // MARK: - Actions

    private var approvalBinding: Binding<AgentApprovalRequest?> {
        Binding(
            get: { session.pendingApproval },
            set: { newValue in
                if newValue == nil, let pending = session.pendingApproval {
                    // Sheet dismissed without a choice = deny, honestly.
                    session.resolveApproval(id: pending.id, approved: false)
                }
            }
        )
    }

    private func startRun() {
        let objective = objectiveDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !objective.isEmpty, !session.isRunning else { return }
        // 5.1.2(i): consent BEFORE the first byte reaches the provider.
        guard consent.hasConsent(for: provider.id) else {
            showConsentSheet = true
            return
        }
        launchPendingObjective()
    }

    private func launchPendingObjective() {
        let objective = objectiveDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !objective.isEmpty else { return }
        objectiveDraft = ""
        session.start(objective: objective, vaultPath: currentVaultPath())
    }

    private func currentVaultPath() -> String {
        // The agent's file territory: the app-container documents scratch for
        // v1 runs; Surface B's vault picker integration follows with the
        // session-store work.
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("AgentWorkspace", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.path
    }

    private func loadTouchedDocument() {
        guard let path = session.lastTouchedFilePath else { return }
        let resolved: String
        if path.hasPrefix("/") {
            resolved = path
        } else {
            resolved = (currentVaultPath() as NSString).appendingPathComponent(path)
        }
        guard let contents = try? String(contentsOfFile: resolved, encoding: .utf8) else { return }
        documentPath = resolved
        documentText = contents
    }

    private func saveTouchedDocument() {
        guard let documentPath else { return }
        try? documentText.write(toFile: documentPath, atomically: true, encoding: .utf8)
    }
}

// MARK: - Mascot slot (Plan 5 fills this)

struct AgentMascotSlot: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(.quaternary.opacity(0.5))
            .overlay {
                Image(systemName: "sparkle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Timeline cards (1:1 with delegate events)

private struct AgentTimelineCard: View {
    let item: AgentTimelineItem
    let theme: EpistemosTheme

    @State private var thinkingExpanded = false

    var body: some View {
        switch item {
        case .turnStarted(_, let number):
            Text("Turn \(number)")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(theme.resolved.foreground.color.opacity(0.35))
                .padding(.top, 2)
        case .thinking(_, let text):
            DisclosureGroup(isExpanded: $thinkingExpanded) {
                Text(text)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            } label: {
                Label("Thinking", systemImage: "brain")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(theme.resolved.foreground.color.opacity(0.5))
            }
            .padding(10)
            .background(cardBackground)
        case .assistantText(_, let text):
            Text(text)
                .font(.system(size: 12.5))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(cardBackground)
        case .tool(_, let call):
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if call.isRunning {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: call.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(call.isError ? .red : .green)
                    }
                    Text(call.name)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    Spacer()
                }
                if !call.inputJson.isEmpty {
                    Text(call.inputJson)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                if let result = call.result, !result.isEmpty {
                    Text(result)
                        .font(.system(size: 10.5))
                        .foregroundStyle(theme.resolved.foreground.color.opacity(0.7))
                        .lineLimit(6)
                        .textSelection(.enabled)
                }
            }
            .padding(10)
            .background(cardBackground)
        case .notice(_, let text):
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .completed(_, let stopReason, let inputTokens, let outputTokens):
            Text("Done · \(stopReason) · \(inputTokens)→\(outputTokens) tokens")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.resolved.foreground.color.opacity(0.4))
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(theme.glassBg.opacity(theme.isDark ? 0.25 : 0.15))
    }
}

// MARK: - Approval sheet (§3.3 — blocks on on_permission_required)

private struct AgentApprovalSheet: View {
    let request: AgentApprovalRequest
    let theme: EpistemosTheme
    let decide: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("The agent wants to use \(request.toolName)", systemImage: "hand.raised")
                .font(.system(size: 13, weight: .semibold))
            if !request.inputJson.isEmpty {
                ScrollView {
                    Text(request.inputJson)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 140)
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.4))
                }
            }
            Text("Risk: \(request.riskLevel)")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Deny") { decide(false) }
                    .keyboardShortcut(.cancelAction)
                Button("Approve") { decide(true) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(width: 440)
    }
}

// MARK: - 5.1.2(i) consent interstitial

private struct AgentCloudConsentSheet: View {
    let provider: AgentCloudProviderDescriptor
    let theme: EpistemosTheme
    let decide: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Send your content to \(provider.displayName)?", systemImage: "cloud")
                .font(.system(size: 13, weight: .semibold))
            Text(
                """
                The agent workspace uses \(provider.displayName) to reason and \
                act. Your objective — and any vault content the agent reads for \
                it — is sent to \(provider.dataDestination). Nothing is sent \
                until you agree, and you can revoke this at any time, which \
                stops all cloud runs.
                """
            )
            .font(.system(size: 11.5))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Not now") { decide(false) }
                    .keyboardShortcut(.cancelAction)
                Button("Allow \(provider.displayName)") { decide(true) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(width: 460)
    }
}
