import SwiftUI

// The native Epistemos Work surface (pivot 2026-06-24): a flat, compact, OpenCode-TUI-minimal workbench that binds
// the three proven pieces — engine picker ← WorkOpenGUISupervisor.status.connectedHarnesses; input →
// createSession/send on the selected engine; supervisor.onEvent → WorkEngineTranscript → native rendered parts
// (answer plain-mono, thinking dim, tool = native card, error native). NO donor chrome, NO gradients, NO raw
// JSON/log/terminal debris (the transcript reducer guarantees that). Session identity is captured in the
// WorkSessionStore (recents) on create. This is the "one native Work input → list/open/create/send/stream" surface;
// runtime/visual proof is owner-OWED (⌘R). Engine order: OpenCode first; the SAME picker drives every harness.
struct WorkEngineSurfaceView: View {
    var theme: EpistemosTheme = .nativeDefault
    /// The directory (a git repo under the runtime's allowedRoots) the engines operate in. The real Work wiring
    /// supplies a valid workspace; the default is a temp path so the view compiles + previews standalone.
    var repo: String = NSTemporaryDirectory()
    /// The active Epistemos vault root. Work's cwd can stay a safe managed workspace while app-native tools
    /// (vault.write, note.create, skills, graph context) root at the user's real vault.
    var epistemosVaultRoot: URL?

    @State private var supervisor = WorkOpenGUISupervisor()
    @State private var transcript = WorkEngineTranscript()
    @State private var sessions = WorkSessionStore()
    @State private var selectedEngine: String = ""
    @State private var input: String = ""
    @State private var activeSessionID: String?
    @State private var sending = false
    @State private var resources = WorkEngineResources.empty
    @State private var selectedModelID: String?
    @State private var selectedAgent: String?
    @State private var queue = WorkPromptQueue()
    @State private var showEnginesPanel = false
    @State private var readyEngines: [String] = []   // diagnosed-ready roster (the multi-engine picker options)
    @State private var pendingPermission: WorkPermissionRequest?   // engine permission.requested → native card
    @State private var pendingQuestion: WorkQuestionRequest?       // engine question.requested → native card
    @State private var liveDiffRefreshTask: Task<Void, Never>?
    @State private var preserveSessionOnEngineChange = false
    @State private var afterPartAbortTriggeredSessionIDs: Set<String> = []
    @State private var appContext = WorkAppContextSnapshot.empty
    @State private var pendingPromptForgeReview: WorkPromptForgeReview?

    private var accent: Color { theme.resolved.accent.color }
    private var boxBackground: Color { WorkSurfaceStyle.background(for: theme) }
    private var railBackground: Color { WorkSurfaceStyle.background(for: theme, role: .rail) }
    /// The engines the runtime connected — the picker's options (empty until `init` returns).
    private var engines: [String] {
        if case .running(let harnesses) = supervisor.status { return harnesses }
        return []
    }
    /// The picker's options: the diagnosed-ready roster (multi-engine) once loaded; else the connected set.
    private var pickerEngines: [String] { readyEngines.isEmpty ? engines : readyEngines }

    var body: some View {
        HStack(spacing: 0) {
            if !sessions.mainSessions.isEmpty {
                ScrollView { WorkSessionRailView(store: sessions, theme: theme, onNewMini: createMiniSession) }
                    .frame(width: 200)
                    .background(railBackground)
                Divider().overlay(theme.border)
            }
            VStack(spacing: 0) {
                header
                Divider().overlay(theme.border)
                transcriptView
                Divider().overlay(theme.border)
                if input.hasPrefix("/") {
                    WorkSlashCommandPopover(
                        commands: resources.commands, query: String(input.dropFirst()),
                        theme: theme, onSelect: applyCommand)
                }
                WorkQueueListView(
                    queue: queue, theme: theme,
                    onSendNow: handleSendNow, onInterrupt: handleInterrupt, onAfterPart: handleAfterPart)
                if let pendingPromptForgeReview {
                    WorkPromptForgeReviewView(
                        review: pendingPromptForgeReview,
                        theme: theme,
                        onAccept: acceptPromptForgeReview,
                        onEdit: editPromptForgeReview,
                        onRetry: retryPromptForgeReview,
                        onRevert: revertPromptForgeReview,
                        onCancel: cancelPromptForgeReview)
                        .padding(.horizontal, 8)
                        .padding(.top, 4)
                }
                if let pendingPermission {
                    WorkPermissionCardView(request: pendingPermission, theme: theme, onDecision: decideOnPermission)
                        .padding(.horizontal, 8)
                }
                if let pendingQuestion {
                    WorkQuestionCardView(
                        request: pendingQuestion, theme: theme,
                        onAnswer: { answerQuestion($0) }, onReject: skipQuestion)
                        .padding(.horizontal, 8)
                }
                inputBar
            }
        }
        .background(boxBackground)
        .task { startEngine() }
        .onChange(of: engines) { _, new in
            if selectedEngine.isEmpty || !new.contains(selectedEngine) { selectedEngine = new.first ?? "" }
        }
        .onChange(of: selectedEngine) { _, engine in
            guard !engine.isEmpty else { return }
            selectedModelID = nil; selectedAgent = nil   // reset picks for the new engine
            if preserveSessionOnEngineChange {
                preserveSessionOnEngineChange = false
                Task { await connectAndLoadResources(for: engine) }
                return
            }
            cancelLiveDiffRefresh()
            afterPartAbortTriggeredSessionIDs.removeAll()
            activeSessionID = nil; transcript.reset()    // switching engine = fresh session on the new engine
            refreshAppContext()
            Task { await connectAndLoadResources(for: engine) }
        }
        .onChange(of: selectedModelID) { _, _ in refreshAppContext() }
        .onChange(of: selectedAgent) { _, _ in refreshAppContext() }
        .onChange(of: activeSessionID) { _, _ in refreshAppContext() }
        .onChange(of: queue.count) { _, _ in refreshAppContext() }
        .onChange(of: transcript.status) { _, status in drainIfIdle(status) }
        .onChange(of: supervisor.status) { _, status in
            surfaceStatusError(status)
            if case .running = status, readyEngines.isEmpty {
                Task { await loadReadyEngines() }
            }
        }
        .onChange(of: sessions.activeSessionID) { _, sid in openFromRail(sid) }
        .sheet(isPresented: $showEnginesPanel) {
            ScrollView {
                WorkEnginesPanelView(
                    connectedHarnesses: engines,
                    resources: resources,
                    context: appContext,
                    theme: theme)
            }
                .frame(width: 320, height: 420)
        }
        .onDisappear {
            cancelLiveDiffRefresh()
            supervisor.stop()
        }
    }

    // MARK: Header (engine picker + status)

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accent)
            Text("Epistemos Work").font(WorkPixelFont.pixel(12))
            enginePicker
            modelPicker
            agentPicker
            Spacer(minLength: 0)
            Text(statusLabel).font(WorkPixelFont.body(11)).foregroundStyle(theme.textTertiary)
            Button { startNewSession() } label: {
                Image(systemName: "square.and.pencil").font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.mutedForeground)
            .frame(width: 22, height: 22)
            .help("New session (the current one stays in recents)")
            Button { showEnginesPanel = true } label: {
                Image(systemName: "gearshape").font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.mutedForeground)
            .frame(width: 22, height: 22)
            .help("Engines & capabilities")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    @ViewBuilder private var enginePicker: some View {
        if pickerEngines.isEmpty {
            Text("starting…").font(WorkPixelFont.body(11)).foregroundStyle(theme.mutedForeground)
        } else {
            Picker("", selection: $selectedEngine) {
                ForEach(pickerEngines, id: \.self) { engine in
                    Text(engineDisplayName(engine)).font(WorkPixelFont.body(11)).tag(engine)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        }
    }

    /// Compact model picker (provider · model) from loadResources; hidden until resources arrive.
    @ViewBuilder private var modelPicker: some View {
        if !resources.providers.isEmpty {
            Picker("", selection: $selectedModelID) {
                Text("model").tag(String?.none)
                ForEach(resources.flatModelOptions, id: \.id) { opt in
                    Text(opt.name).font(WorkPixelFont.body(11)).tag(String?.some(opt.id))
                }
            }
            .labelsHidden().pickerStyle(.menu).fixedSize()
        }
    }

    /// Compact agent picker from loadResources; hidden until agents arrive.
    @ViewBuilder private var agentPicker: some View {
        if !resources.agents.isEmpty {
            Picker("", selection: $selectedAgent) {
                Text("agent").tag(String?.none)
                ForEach(resources.agents) { agent in
                    Text(agent.name).font(WorkPixelFont.body(11)).tag(String?.some(agent.name))
                }
            }
            .labelsHidden().pickerStyle(.menu).fixedSize()
        }
    }

    private var statusLabel: String {
        switch supervisor.status {
        case .idle: return "·"
        case .unavailable: return "unavailable"
        case .starting: return "starting…"
        case .running: return transcript.status == .running ? "running…" : "ready"
        case .failed: return "error"
        case .stopped: return "stopped"
        }
    }

    // MARK: Transcript (native, no debris)

    /// Honest empty-state copy derived from the SUPERVISOR status (was a hardcoded "connecting…" for any engines.isEmpty,
    /// which misleadingly showed "connecting" for .stopped/.failed/.unavailable too). Placeholder-only — we deliberately do
    /// NOT inject a session.error on .stopped because intentional stop() also sets .stopped (would be a false error).
    private var emptyPlaceholder: String {
        switch supervisor.status {
        case .running: return "Type to start an Epistemos Work session"
        case .idle, .starting: return "connecting to the engine…"
        case .stopped: return "The Work engine stopped — reopen Work to restart."
        case .unavailable(let r): return r.isEmpty ? "Work engine unavailable." : r
        case .failed(let r): return r.isEmpty ? "Work engine failed to start." : r
        }
    }

    private var transcriptView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if transcript.parts.isEmpty {
                        Text(emptyPlaceholder)
                            .font(WorkPixelFont.body(12))
                            .foregroundStyle(theme.mutedForeground)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 28)
                    }
                    ForEach(transcript.parts) { part in partView(part).id(part.id) }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: scrollKey) { _, _ in
                guard let last = transcript.parts.last else { return }
                withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    /// Changes when a part is added OR the last part's text grows (streaming) → drives transcript auto-scroll.
    private var scrollKey: String { "\(transcript.parts.count):\(transcript.parts.last?.text.count ?? 0)" }

    @ViewBuilder private func partView(_ part: WorkTranscriptPart) -> some View {
        switch part.kind {
        case .user:
            Text(part.text)
                .font(WorkPixelFont.body(13))
                .foregroundStyle(accent)
                .textSelection(.enabled)
        case .answer:
            WorkMarkdownText(text: part.text, theme: theme)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .thinking:
            Text(part.text)
                .font(WorkPixelFont.body(11))
                .foregroundStyle(theme.textTertiary)
                .italic()
        case .tool:
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(part.toolName ?? "tool")
                        .font(WorkPixelFont.body(11, weight: .semibold))
                        .foregroundStyle(accent)
                    Spacer(minLength: 0)
                    Text(part.toolStatus ?? "")
                        .font(WorkPixelFont.body(10))
                        .foregroundStyle(theme.mutedForeground)
                }
                if let summary = part.toolSummary, !summary.isEmpty {
                    Text(summary)
                        .font(WorkPixelFont.body(10))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !part.text.isEmpty {
                    Text(part.text)
                        .font(WorkPixelFont.body(11))
                        .foregroundStyle(theme.mutedForeground)
                        .lineLimit(6)
                }
                ForEach(Array(part.fileDiffs.enumerated()), id: \.offset) { _, diff in
                    WorkDiffText(diff: diff, theme: theme)
                }
            }
            .padding(8)
            .overlay(RoundedRectangle(cornerRadius: 0).strokeBorder(theme.border, lineWidth: 0.8))
        case .error:
            Text(part.text)
                .font(WorkPixelFont.body(12))
                .foregroundStyle(theme.coral)
        }
    }

    // MARK: Input

    private var inputBar: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .leading) {
                if input.isEmpty {
                    Text(engines.isEmpty ? "connecting…" : "Ask Epistemos Work…")
                        .font(WorkPixelFont.body(13))
                        .foregroundStyle(theme.mutedForeground)
                        .allowsHitTesting(false)
                }
                WorkBlockCaretField(
                    text: $input,
                    font: NSFont(name: "JetBrainsMono-Regular", size: 13)
                        ?? .monospacedSystemFont(ofSize: 13, weight: .regular),
                    caretColor: NSColor(accent),
                    isEnabled: !engines.isEmpty,
                    onSubmit: submit,
                    onQueue: queueInput)
                    .frame(height: 18)
            }
            if transcript.status == .running, let active = activeSessionID {
                Button { abortActiveTurn(active) } label: {
                    Image(systemName: "stop.circle").font(.system(size: 18)).foregroundStyle(theme.coral)
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)
                .help("Cancel the running turn")
            }
            Button(action: submit) {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 18)).foregroundStyle(accent)
            }
            .buttonStyle(.plain)
            .frame(width: 24, height: 24)
            .help("Send prompt")
            .disabled(engines.isEmpty || input.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: Actions

    private func startEngine() {
        // Forward every streamed event into the native transcript (no raw debris). OpenCode first.
        supervisor.onEvent = { (sessionID: String, data: Data) in
            guard activeSessionID == nil || activeSessionID == sessionID else { return }
            let eventType = Self.liveEventType(data)
            transcript.ingest(eventJSON: data)
            if eventType == "tool.finished" {
                scheduleLiveDiffRefresh(sessionID: sessionID)
            }
            if eventType == "part.started" || eventType == "message.finished" {
                triggerAfterPartIfNeeded(sessionID: sessionID)
            }
        }
        // Engine permission requests → a native permission card (auto-approve stays the default until a tool is gated to
        // "ask"; this path is ready so flipping that gate later won't hang the agent).
        supervisor.onPermissionRequest = { request in pendingPermission = request }
        supervisor.onPermissionCleared = { sessionID in
            if pendingPermission?.sessionID == sessionID { pendingPermission = nil }
        }
        supervisor.onQuestion = { request in pendingQuestion = request }
        supervisor.onQuestionCleared = { sessionID in
            if pendingQuestion?.sessionID == sessionID { pendingQuestion = nil }
        }
        Task {
            let workspaceURL = URL(fileURLWithPath: repo)
            _ = WorkSkillsProvisioner.provisionAll(
                workspace: workspaceURL,
                vaultRoot: epistemosVaultRoot)
            var context = refreshAppContext(nativeToolsAvailable: false)
            // #7: provision Epistemos's native tools (MCP) into the workspace BEFORE the runtime spawns opencode.
            let provisioned = await WorkOpenGUIProvisioner.provisionNativeMCP(
                workspace: workspaceURL,
                epistemosVaultRoot: epistemosVaultRoot,
                context: context)
            context = refreshAppContext(nativeToolsAvailable: provisioned)
            if !provisioned {
                ingestSurfaceError("Couldn't provision Epistemos native tools; Work will start with engine defaults.")
            }
            supervisor.start(repo: repo, harnesses: ["opencode"])
        }
    }

    @discardableResult
    private func refreshAppContext(nativeToolsAvailable: Bool? = nil) -> WorkAppContextSnapshot {
        let snapshot = WorkAppContextSnapshot.current(
            workspace: URL(fileURLWithPath: repo),
            vaultRoot: epistemosVaultRoot,
            nativeToolsAvailable: nativeToolsAvailable ?? appContext.nativeToolsAvailable,
            selectedEngine: selectedEngine,
            selectedModelID: selectedModelID,
            selectedAgent: selectedAgent,
            activeWorkSessionID: activeSessionID,
            queuedPromptCount: queue.count)
        appContext = snapshot
        WorkNativeMCPHost.shared.updateContext(snapshot)
        return snapshot
    }

    /// Surface a supervisor start/availability failure REASON natively (so a failed ⌘R shows WHY, not just "unavailable").
    private func surfaceStatusError(_ status: WorkOpenGUISupervisor.Status) {
        let message: String?
        switch status {
        case .unavailable(let reason): message = reason
        case .failed(let reason): message = reason
        default: message = nil
        }
        guard let message else { return }
        ingestSurfaceError(message)
    }

    private func surfaceRuntimeError(_ message: String, _ error: Error) {
        ingestSurfaceError(WorkServerDiagnostics.statusMessage(for: error, fallback: message))
    }

    private func ingestSurfaceError(_ message: String) {
        if let data = try? JSONSerialization.data(withJSONObject: ["type": "session.error", "message": message]) {
            transcript.ingest(eventJSON: data)
        }
    }

    private func loadReadyEngines() async {
        do {
            readyEngines = try await supervisor.diagnose()
        } catch {
            readyEngines = []
            surfaceRuntimeError("Couldn't inspect Work engines", error)
        }
    }

    /// Lazy multi-engine: connect the picked/reopened engine if needed, then load its model/agent/command resources.
    private func connectAndLoadResources(for engine: String) async {
        if case .running(let connected) = supervisor.status, !connected.contains(engine) {
            do {
                _ = try await supervisor.connect(engine)
            } catch {
                surfaceRuntimeError("Couldn't connect the selected engine", error)
                return
            }
        }
        await loadResources(for: engine)
    }

    /// Load the selected engine's models/agents/commands → the compact pickers; preselect the default model + agent.
    private func loadResources(for engine: String) async {
        let loaded: WorkEngineResources
        do {
            loaded = try await supervisor.loadResources(harnessId: engine)
        } catch {
            resources = .empty
            selectedModelID = nil
            selectedAgent = nil
            surfaceRuntimeError("Couldn't load engine capabilities", error)
            return
        }
        resources = loaded
        if selectedModelID == nil, let provider = loaded.providers.first {
            // Preselect the provider's default model (or its first), keyed by the composite providerID/modelID id so
            // `send` can rebuild the SelectedModel object opencode expects.
            if let modelID = loaded.defaultModelByProvider[provider.id] ?? provider.models.first?.id {
                selectedModelID = WorkEngineResources.selectionID(providerID: provider.id, modelID: modelID)
            }
        }
        if selectedAgent == nil { selectedAgent = loaded.agents.first?.name }
        // Populate the rail / recents with the engine's existing sessions (preserve identity across launches).
        do {
            let existing = try await supervisor.listSessions(harnessId: engine, workspaceID: repo)
            for session in existing { sessions.upsert(session) }
        } catch {
            surfaceRuntimeError("Couldn't load recent Work sessions", error)
        }
    }

    /// Rail focus → open the session on the engine + replay its history into the transcript (recents fidelity).
    private func openFromRail(_ sessionID: String?) {
        guard let sessionID, sessionID != activeSessionID else { return }
        cancelLiveDiffRefresh()
        afterPartAbortTriggeredSessionIDs.removeAll()
        // The OpenGUI session id is engine-namespaced (harnessId:rawId) → open against the OWNING engine, not whatever is
        // currently selected, so a reopened recent keeps its engine identity (rail entries only come from connected
        // engines). The picker follows the owning engine, but with a one-shot preserve flag so the selectedEngine
        // onChange loads that engine's resources without wiping the reopened transcript.
        let owningEngine = Self.engineID(from: sessionID) ?? selectedEngine
        guard !owningEngine.isEmpty else {
            ingestSurfaceError("Couldn't reopen session: missing engine identity.")
            return
        }
        if selectedEngine != owningEngine {
            preserveSessionOnEngineChange = true
            selectedEngine = owningEngine
        }
        Task {
            do {
                if case .running(let connected) = supervisor.status, !connected.contains(owningEngine) {
                    _ = try await supervisor.connect(owningEngine)
                }
                _ = try await supervisor.openSession(sessionID, harnessId: owningEngine)
            } catch {
                // Honest failure (was: `try?` swallowed it, leaving the previous transcript stale under the new selection).
                transcript.reset()
                if let d = try? JSONSerialization.data(withJSONObject:
                    [
                        "type": "session.error",
                        "message": WorkServerDiagnostics.statusMessage(
                            for: error,
                            fallback: "Couldn't reopen session"
                        )
                    ]) {
                    transcript.ingest(eventJSON: d)
                }
                activeSessionID = sessionID
                return
            }
            activeSessionID = sessionID
            do {
                guard let data = try await supervisor.messages(sessionId: sessionID) else {
                    transcript.reset()
                    ingestSurfaceError("Couldn't load session history: no history returned.")
                    return
                }
                transcript.replay(history: WorkSessionHistoryProjector.project(data))
            } catch {
                transcript.reset()
                surfaceRuntimeError("Couldn't load session history", error)
            }
        }
    }

    /// Slash-command selected → opencode runs it as a "/name" message (queued if busy).
    private func applyCommand(_ command: WorkEngineCommand) {
        input = ""
        let text = "/\(command.name)"
        if transcript.status == .running || sending {
            queue.enqueue(text, model: selectedModelID, agent: selectedAgent)
        } else {
            sendNow(text, model: selectedModelID, agent: selectedAgent)
        }
    }

    private func submit() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !engines.isEmpty else { return }
        input = ""
        if text.hasPrefix("/") {
            deliverPrompt(text, delivery: transcript.status == .running || sending ? .queue : .send,
                          model: selectedModelID, agent: selectedAgent)
            return
        }
        beginPromptForgeReview(
            text: text,
            delivery: transcript.status == .running || sending ? .queue : .send,
            model: selectedModelID,
            agent: selectedAgent)
    }

    private func beginPromptForgeReview(
        text: String,
        delivery: WorkPromptForgeDelivery,
        model: String?,
        agent: String?,
        retryCount: Int = 0
    ) {
        let result = PromptForgeService.upgrade(PromptForgeRequest(
            originalPrompt: text,
            surface: "work",
            taskHint: agent ?? selectedEngine,
            contextSnippets: promptForgeContextSnippets(),
            variant: retryCount
        ))
        pendingPromptForgeReview = WorkPromptForgeReview(
            result: result,
            delivery: delivery,
            model: model,
            agent: agent,
            retryCount: retryCount)
    }

    private func acceptPromptForgeReview() {
        guard let review = pendingPromptForgeReview else { return }
        pendingPromptForgeReview = nil
        deliverPrompt(
            review.result.upgradedPrompt,
            delivery: review.delivery,
            model: review.model,
            agent: review.agent,
            variant: "prompt-forge:v\(review.retryCount + 1)")
    }

    private func editPromptForgeReview() {
        guard let review = pendingPromptForgeReview else { return }
        input = review.result.upgradedPrompt
        pendingPromptForgeReview = nil
    }

    private func retryPromptForgeReview() {
        guard let review = pendingPromptForgeReview else { return }
        beginPromptForgeReview(
            text: review.result.originalPrompt,
            delivery: review.delivery,
            model: review.model,
            agent: review.agent,
            retryCount: review.retryCount + 1)
    }

    private func revertPromptForgeReview() {
        guard let review = pendingPromptForgeReview else { return }
        pendingPromptForgeReview = nil
        deliverPrompt(
            review.result.originalPrompt,
            delivery: review.delivery,
            model: review.model,
            agent: review.agent)
    }

    private func cancelPromptForgeReview() {
        if let review = pendingPromptForgeReview {
            input = review.result.originalPrompt
        }
        pendingPromptForgeReview = nil
    }

    private func deliverPrompt(
        _ text: String,
        delivery: WorkPromptForgeDelivery,
        model: String?,
        agent: String?,
        variant: String? = nil
    ) {
        // Busy → QUEUE the prompt (pending) instead of blocking; it drains when the turn goes idle.
        if delivery == .queue || transcript.status == .running || sending {
            queue.enqueue(text, model: model, agent: agent, variant: variant)
            return
        }
        sendNow(text, model: model, agent: agent)
    }

    private func promptForgeContextSnippets() -> [PromptForgeContextSnippet] {
        appContext.rows(pathLimit: 120, textLimit: 220).map { row in
            let priority: Int
            switch row.id {
            case "note", "note-path", "graph", "selection":
                priority = 80
            case "vault", "workspace":
                priority = 60
            case "engine", "model", "agent", "runtime-skills":
                priority = 40
            default:
                priority = 20
            }
            return PromptForgeContextSnippet(
                id: "work-\(row.id)",
                title: row.label,
                source: "Work context",
                excerpt: row.value,
                priority: priority)
        }
    }

    /// Tab stages a prompt without sending immediately. Enter remains the send-now action; queued rows keep their
    /// explicit send-now / interrupt controls, so this adds queue ergonomics without hiding or removing behavior.
    private func queueInput() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !engines.isEmpty else { return }
        input = ""
        if text.hasPrefix("/") {
            queue.enqueue(text, model: selectedModelID, agent: selectedAgent)
            return
        }
        beginPromptForgeReview(text: text, delivery: .queue, model: selectedModelID, agent: selectedAgent)
    }

    private func sendNow(
        _ text: String, model: String?, agent: String?, requeueOnFailure prompt: WorkQueuedPrompt? = nil
    ) {
        sending = true
        Task {
            defer { sending = false }
            do {
                let sessionID: String
                if let active = activeSessionID {
                    sessionID = active
                } else {
                    let title = WorkSession.normalizedTitle(text, limit: 48) ?? "Work"
                    sessionID = try await supervisor.createSession(title: title, harnessId: selectedEngine)
                    activeSessionID = sessionID
                    // Capture native session identity / recents the moment a session is created.
                    sessions.upsert(.main(id: sessionID, workspaceID: repo, openCodeSessionID: sessionID, title: title))
                    // Single source of truth: focus the store on the new session so the rail highlights it (upsert only
                    // sets active when it was nil → 2nd+ sessions would otherwise leave the rail on the old one). The
                    // resulting onChange(sessions.activeSessionID)→openFromRail short-circuits (view activeSessionID already == id).
                    sessions.focus(id: sessionID)
                }
                try await supervisor.send(text, sessionId: sessionID, model: model, agent: agent)
            } catch {
                if let prompt {
                    let requeued = queue.enqueue(
                        prompt.text, mode: prompt.mode, model: prompt.model, agent: prompt.agent,
                        variant: prompt.variant)
                    queue.moveToTop(id: requeued.id)
                }
                // Surface failures as a NATIVE error part (built safely — never raw-interpolated into prose).
                if let data = try? JSONSerialization.data(
                    withJSONObject: [
                        "type": "session.error",
                        "message": WorkServerDiagnostics.statusMessage(
                            for: error,
                            fallback: "Work send failed"
                        )
                    ]) {
                    transcript.ingest(eventJSON: data)
                }
            }
        }
    }

    private static func liveEventType(_ data: Data) -> String? {
        guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        return obj["type"] as? String
    }

    private static func engineID(from sessionID: String) -> String? {
        guard let separator = sessionID.firstIndex(of: ":") else { return nil }
        let engine = String(sessionID[..<separator])
        return engine.isEmpty ? nil : engine
    }

    private func engineDisplayName(_ engine: String) -> String {
        switch engine {
        case "opencode": return "OpenCode"
        case "claude-code": return "Claude Code"
        default: return engine.isEmpty ? "engine" : engine
        }
    }

    /// LiveSessionEvent omits edit diffs; after a tool settles, history usually has `state.metadata.files[].diff`.
    /// Fetch it a couple of times at short delays, merge by partId, then stop. This keeps live transcript rendering
    /// native without a background poller.
    private func scheduleLiveDiffRefresh(sessionID: String) {
        liveDiffRefreshTask?.cancel()
        liveDiffRefreshTask = Task { @MainActor in
            let delays: [Duration] = [.milliseconds(250), .milliseconds(900)]
            for delay in delays {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled, activeSessionID == sessionID else { return }
                guard let data = try? await supervisor.messages(sessionId: sessionID) else { continue }
                guard !Task.isCancelled, activeSessionID == sessionID else { return }
                transcript.mergeFileDiffs(history: WorkSessionHistoryProjector.project(data))
            }
        }
    }

    private func cancelLiveDiffRefresh() {
        liveDiffRefreshTask?.cancel()
        liveDiffRefreshTask = nil
    }

    /// Drain the next queued prompt when the session goes idle (one per idle transition).
    private func drainIfIdle(_ status: WorkRunStatus) {
        if status == .idle, let activeSessionID {
            afterPartAbortTriggeredSessionIDs.remove(activeSessionID)
        }
        guard status == .idle, !sending, let next = queue.dequeue() else { return }
        sendNow(next.text, model: next.model, agent: next.agent, requeueOnFailure: next)
    }

    /// QueueList "send now": send immediately if free, else re-queue at the front so it drains next.
    private func handleSendNow(_ prompt: WorkQueuedPrompt) {
        if transcript.status == .running || sending {
            let requeued = queue.enqueue(
                prompt.text, mode: prompt.mode, model: prompt.model, agent: prompt.agent,
                variant: prompt.variant)
            queue.moveToTop(id: requeued.id)
        } else {
            sendNow(prompt.text, model: prompt.model, agent: prompt.agent, requeueOnFailure: prompt)
        }
    }

    /// "+ New session": start a fresh session on the SAME engine. The current session is already in the recents rail
    /// (upserted on create), so it's preserved + reopenable; the next send creates a new session (activeSessionID nil).
    private func startNewSession() {
        cancelLiveDiffRefresh()
        afterPartAbortTriggeredSessionIDs.removeAll()
        activeSessionID = nil
        transcript.reset()
        input = ""
        pendingPermission = nil
        pendingQuestion = nil
        pendingPromptForgeReview = nil
    }

    /// Create a real attached child session through the active OpenGUI engine. Floating detach stays hidden until a real
    /// Mini window hook is wired; this path still gives Work a first-class child session without Chat-surface coupling.
    private func createMiniSession(parent: WorkSession) {
        guard parent.kind == .main else { return }
        let owningEngine = parent.openCodeSessionID.flatMap(Self.engineID(from:)) ?? Self.engineID(from: parent.id) ?? selectedEngine
        guard !owningEngine.isEmpty else {
            ingestSurfaceError("Couldn't create mini session: missing engine identity.")
            return
        }
        let title = "Mini \(sessions.children(of: parent.id).count + 1)"
        Task {
            do {
                if selectedEngine != owningEngine {
                    preserveSessionOnEngineChange = true
                    selectedEngine = owningEngine
                }
                if case .running(let connected) = supervisor.status, !connected.contains(owningEngine) {
                    _ = try await supervisor.connect(owningEngine)
                }
                let sessionID = try await supervisor.createSession(title: title, harnessId: owningEngine)
                let mini = WorkSession.mini(id: sessionID, parent: parent, openCodeSessionID: sessionID, title: title)
                sessions.upsert(mini)
                sessions.focus(id: sessionID)
                cancelLiveDiffRefresh()
                afterPartAbortTriggeredSessionIDs.removeAll()
                activeSessionID = sessionID
                transcript.reset()
                input = ""
                pendingPermission = nil
                pendingQuestion = nil
                pendingPromptForgeReview = nil
            } catch {
                surfaceRuntimeError("Couldn't create mini session", error)
            }
        }
    }

    /// Convert a failed user action into a native transcript error instead of silently swallowing it.
    private func surfaceActionError(_ message: String, _ error: Error) {
        surfaceRuntimeError(message, error)
    }

    private func abortActiveTurn(_ sessionID: String) {
        Task {
            do {
                try await supervisor.abort(sessionId: sessionID)
            } catch {
                afterPartAbortTriggeredSessionIDs.remove(sessionID)
                surfaceActionError("Couldn't cancel the running turn", error)
            }
        }
    }

    /// Permission card decision → reply to the engine (allow once/always or deny), then dismiss the card.
    private func decideOnPermission(_ decision: WorkPermissionDecision) {
        guard let request = pendingPermission else { return }
        pendingPermission = nil
        Task {
            do {
                try await supervisor.respondPermission(
                    harnessId: request.harnessID ?? (selectedEngine.isEmpty ? "opencode" : selectedEngine),
                    sessionId: request.sessionID, permissionId: request.id, decision: decision)
            } catch {
                surfaceActionError("Couldn't respond to the permission request", error)
            }
        }
    }

    /// Question card "Submit" → answer the engine (one [String] per prompt), then dismiss.
    private func answerQuestion(_ answers: [[String]]) {
        guard let request = pendingQuestion else { return }
        pendingQuestion = nil
        Task {
            do {
                try await supervisor.respondQuestion(
                    harnessId: request.harnessID ?? (selectedEngine.isEmpty ? "opencode" : selectedEngine),
                    requestId: request.id, answers: answers)
            } catch {
                surfaceActionError("Couldn't answer the question", error)
            }
        }
    }

    /// Question card "skip" → dismiss without answering.
    private func skipQuestion() {
        guard let request = pendingQuestion else { return }
        pendingQuestion = nil
        Task {
            do {
                try await supervisor.rejectQuestion(
                    harnessId: request.harnessID ?? (selectedEngine.isEmpty ? "opencode" : selectedEngine),
                    requestId: request.id)
            } catch {
                surfaceActionError("Couldn't skip the question", error)
            }
        }
    }

    /// QueueList "interrupt": this prompt jumps the queue AND aborts the running turn so it sends ASAP (vs "send now"
    /// which waits for the turn to finish). Reuses the proven abort + idle-drain seams: abort → run.finished(idle) →
    /// onChange(status) → drainIfIdle pops the now-front prompt. If nothing is running, drain it immediately.
    private func handleInterrupt(_ prompt: WorkQueuedPrompt) {
        queue.moveToTop(id: prompt.id)
        queue.setMode(id: prompt.id, .interrupt)
        if transcript.status == .running, let active = activeSessionID {
            abortActiveTurn(active)
        } else {
            drainIfIdle(.idle)
        }
    }

    /// QueueList "steer after current part": jump the prompt to the front, mark it after-part, then wait for the next live
    /// part boundary. At that boundary we abort once; the existing idle-drain sends the now-front prompt.
    private func handleAfterPart(_ prompt: WorkQueuedPrompt) {
        queue.moveToTop(id: prompt.id)
        queue.setMode(id: prompt.id, .afterPart)
        if transcript.status != .running {
            drainIfIdle(.idle)
        }
    }

    private func triggerAfterPartIfNeeded(sessionID: String) {
        guard activeSessionID == sessionID,
              transcript.status == .running,
              queue.pending.first?.mode == .afterPart,
              !afterPartAbortTriggeredSessionIDs.contains(sessionID)
        else { return }
        afterPartAbortTriggeredSessionIDs.insert(sessionID)
        abortActiveTurn(sessionID)
    }
}

#Preview {
    WorkEngineSurfaceView().frame(width: 680, height: 460)
}
