import SwiftUI
import AppKit
import WebKit

public struct ContentView: View {
    /// Public entry point so Epistemos can mount the embedded agent UI as its Chat surface.
    public init() {}

    @State private var viewModel = AgentViewModel()
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var dependencyStatus: DependencyStatus?
    @State private var showDependencyOverlay = true
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var caseSensitive = false
    @FocusState private var isSearchFieldFocused: Bool
    @FocusState private var isTaskFieldFocused: Bool
    @State private var currentMatchIndex = 0
    @State private var totalMatches = 0
    @State private var showMCPServers = false
    @State private var showTools = false
    @State private var showOptions = false
    @ObservedObject private var aiMediator = AppleIntelligenceMediator.shared
    @State private var showAIPopover = false
    @State private var showMessages = false
    @State private var showAccessibility = false
    @State private var showQuitConfirm = false
    @State private var showClearConfirm = false
    @State private var showNewTabSheet = false
    @State private var showServices = false
    @State private var showAppleAIBanner = false
    @State private var showUserQuestion = false
    @State private var userQuestionText = ""
    @State private var userAnswerText = ""
    @State private var showControlPanel = false

    public var body: some View {
        GeometryReader { geometry in
            let metrics = Self.layoutMetrics(for: geometry.size, controlPanelVisible: showControlPanel)
            self.mainChatShell(metrics: metrics)
        }
        .frame(minWidth: 640, minHeight: 500)
        .background(AgentSkin.bg)
        .onTapGesture {
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
        .toolbarBackground(AgentSkin.bg, for: .windowToolbar)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button { showControlPanel.toggle() } label: {
                    Image(systemName: "sidebar.left")
                }
                .help("Controls")
                .buttonStyle(.plain)
            }
            ToolbarItem(placement: .automatic) {
                Spacer()
            }
            ToolbarItemGroup(placement: .automatic) {
                Button { showControlPanel.toggle() } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .help("Advanced controls")
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            applyCurrentHostContext()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTaskFieldFocused = true
            }
        }
        .overlay {
            DependencyOverlay(status: dependencyStatus, isVisible: $showDependencyOverlay)
        }
        .overlay(alignment: .leading) {
            if showControlPanel {
                AgentControlSidePanel(
                    viewModel: viewModel,
                    selectedTab: selectedTab,
                    showServices: $showServices,
                    showMessages: $showMessages,
                    showAccessibility: $showAccessibility,
                    showMCPServers: $showMCPServers,
                    showTools: $showTools,
                    showSettings: $showSettings,
                    showAIPopover: $showAIPopover,
                    showOptions: $showOptions,
                    showHistory: $showHistory,
                    showClearConfirm: $showClearConfirm,
                    close: { showControlPanel = false }
                )
                .frame(width: Self.sidePanelWidth)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .alert("Quit Epistemos?", isPresented: $showQuitConfirm) {
            Button("Quit", role: .destructive) { NSApplication.shared.terminate(nil) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to close the window and quit?")
        }
        .sheet(isPresented: $showNewTabSheet) {
            NewMainTabSheet(viewModel: viewModel)
        }
        .alert("Epistemos Task Failed", isPresented: $viewModel.showFailedAgentAlert) {
            Button("Remove", role: .destructive) { if let id = viewModel.failedAgentId { RecentAgentsService.shared.removeById(id) } }
            Button("Keep", role: .cancel) { }
        } message: {
            Text("'\(viewModel.failedAgentName)' failed. Remove it from the recent agents menu?")
        }
        // Auto-expand of HUD on run-start happens in AgentViewModel.executeTask now,
        // so we don't fire it from a generic onChange (which would also trigger on tab swaps).
        .onChange(of: viewModel.selectedTabId) { _, _ in
            // Reset search state when switching tabs
            if showSearch {
                showSearch = false
                searchText = ""
                currentMatchIndex = 0
                totalMatches = 0
            }
            // Focus task input when switching/creating tabs
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTaskFieldFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appWillQuit)) { _ in
            viewModel.stopAll()
            viewModel.stopMessagesMonitor()
            Task { await MCPService.shared.disconnectAll() }
        }
        .onReceive(NotificationCenter.default.publisher(for: AgentCloneBridge.submitPromptNotification)) { notification in
            submitBridgePrompt(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: AgentCloneBridge.hostContextNotification)) { notification in
            applyBridgeHostContext(notification)
        }
        .onChange(of: viewModel.pendingQuestion) { _, question in
            if !question.isEmpty {
                showAskUserDialog(question: question)
            }
        }
        .onAppear {
            setupMenuObservers()
            AgentsMenuDelegate.shared.viewModel = viewModel
            applyCurrentHostContext()
            drainPendingBridgePrompts()
            DispatchQueue.global(qos: .userInitiated).async {
                let status = DependencyChecker.check()
                DispatchQueue.main.async {
                    dependencyStatus = status
                    // Don't dismiss here — the overlay animates its own
                    // 2.5-second auto-dismiss when allGood is true.
                }
            }
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                handleKeyDown(event)
            }
        }
    }

    private var selectedTab: ScriptTab? {
        viewModel.selectedTabId.flatMap { id in viewModel.tab(for: id) }
    }

    @ViewBuilder
    private func mainChatShell(metrics: ChatLayoutMetrics) -> some View {
        let activeTab = selectedTab
        let activeActivityText = activityText(for: activeTab)
        VStack(spacing: 0) {
            EpistemosChatChromeBar(
                viewModel: viewModel,
                selectedTab: activeTab,
                controlPanelVisible: showControlPanel,
                showControlPanel: $showControlPanel,
                showSearch: $showSearch,
                showSettings: $showSettings,
                showHistory: $showHistory,
                showNewTabSheet: $showNewTabSheet
            )
            .frame(width: metrics.chatWidth)
            .padding(.top, metrics.chromeTopPadding)
            .padding(.bottom, metrics.chromeBottomPadding)
            .frame(maxWidth: .infinity, alignment: .center)

            headerStack()

            if shouldShowStartSurface(tab: activeTab, activityText: activeActivityText) {
                ChatStartSurface(
                    viewModel: viewModel,
                    isTaskFieldFocused: $isTaskFieldFocused,
                    selectedTab: activeTab,
                    chatWidth: metrics.chatWidth
                )
            } else {
                transcriptStack(
                    tab: activeTab,
                    logText: activeActivityText,
                    metrics: metrics
                )

                Divider()

                attachmentStrip(tab: activeTab, chatWidth: metrics.chatWidth)

                InputSectionView(
                    viewModel: viewModel,
                    isTaskFieldFocused: $isTaskFieldFocused,
                    selectedTab: activeTab
                )
                .frame(width: metrics.chatWidth)
                .padding(.bottom, metrics.composerBottomPadding)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(width: metrics.contentWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
    }

    @ViewBuilder
    private func headerStack() -> some View {
        if showSearch {
            SearchBarView(
                searchText: $searchText,
                caseSensitive: $caseSensitive,
                totalMatches: totalMatches,
                currentMatchIndex: currentMatchIndex,
                previousMatch: previousMatch,
                nextMatch: nextMatch,
                onClose: { showSearch = false; searchText = "" }
            )
            .focused($isSearchFieldFocused)
        }

        if !viewModel.scriptTabs.isEmpty {
            TabBarView(viewModel: viewModel)
            Divider()
        }

        if let prompt = activeTaskPrompt, !prompt.isEmpty {
            TaskBannerView(
                prompt: prompt,
                appleAIPrompt: activeAppleAIPrompt,
                showAppleAIBanner: $showAppleAIBanner,
                onCancel: cancelActiveTaskFromBanner
            )
        }
    }

    @ViewBuilder
    private func transcriptStack(
        tab: ScriptTab?,
        logText: String,
        metrics: ChatLayoutMetrics
    ) -> some View {
        let activeIsBusy = isBusy(for: tab)
        ZStack(alignment: .top) {
            ActivityLogView(
                text: logText,
                tabID: viewModel.selectedTabId,
                isActive: activeIsBusy,
                textProvider: { activityText(for: tab) },
                searchText: searchText,
                caseSensitive: caseSensitive,
                currentMatchIndex: currentMatchIndex,
                onMatchCount: updateSearchMatchCount
            )
            .frame(width: metrics.chatWidth)
            .frame(maxHeight: .infinity)
            .padding(.top, metrics.transcriptTopPadding)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            thinkingIndicator
                .frame(width: metrics.chatWidth)
                .padding(.top, 10)
        }
    }

    @ViewBuilder
    private func attachmentStrip(tab: ScriptTab?, chatWidth: CGFloat) -> some View {
        if let tab, !tab.attachedImages.isEmpty {
            ScreenshotPreviewView(
                images: tab.attachedImages,
                onRemove: { index in
                    guard tab.attachedImages.indices.contains(index) else { return }
                    tab.attachedImages.remove(at: index)
                    tab.attachedImagesBase64.remove(at: index)
                },
                onRemoveAll: {
                    tab.attachedImages.removeAll()
                    tab.attachedImagesBase64.removeAll()
                }
            )
            .frame(width: chatWidth)
            .frame(maxWidth: .infinity, alignment: .center)
        } else if tab == nil, !viewModel.attachedImages.isEmpty {
            ScreenshotPreviewView(
                images: viewModel.attachedImages,
                onRemove: { index in viewModel.removeAttachment(at: index) },
                onRemoveAll: { viewModel.removeAllAttachments() }
            )
            .frame(width: chatWidth)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func cancelActiveTaskFromBanner() {
        if let selId = viewModel.selectedTabId,
           let tab = viewModel.tab(for: selId)
        {
            if tab.isLLMRunning {
                viewModel.stopTabTask(tab: tab)
            } else if tab.isRunning {
                viewModel.cancelScriptTab(id: tab.id)
            }
        } else {
            viewModel.stop()
        }
    }

    private func activityText(for tab: ScriptTab?) -> String {
        tab?.activityLog ?? viewModel.activityLog
    }

    private func isBusy(for tab: ScriptTab?) -> Bool {
        tab?.isBusy ?? viewModel.isRunning
    }

    private func shouldShowStartSurface(tab: ScriptTab?, activityText: String) -> Bool {
        !Self.hasConversationContent(activityText)
            && !((tab?.isBusy ?? false) || viewModel.isRunning || viewModel.isThinking)
            && activeTaskPrompt?.isEmpty != false
            && viewModel.attachedImages.isEmpty
            && (tab?.attachedImages.isEmpty ?? true)
            && !showSearch
    }

    private static func hasConversationContent(_ activityText: String) -> Bool {
        activityText
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .contains { line in
                let visibleLine = strippingActivityTimestamp(from: line)
                return !visibleLine.isEmpty && !isBootstrapStatusLine(visibleLine)
            }
    }

    private static func strippingActivityTimestamp(from line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "[", let timestampEnd = trimmed.firstIndex(of: "]") else {
            return trimmed
        }

        let afterTimestamp = trimmed.index(after: timestampEnd)
        return String(trimmed[afterTimestamp...]).trimmingCharacters(in: .whitespaces)
    }

    private static func isBootstrapStatusLine(_ line: String) -> Bool {
        line == "Privileged helper plist not found in app bundle. Rebuild and reinstall Epistemos."
            || line == "User helper plist not found in app bundle. Rebuild and reinstall Epistemos."
            || line == "🔥 Warming up..."
            || line.hasPrefix("⚙️ User helper:")
            || line.hasPrefix("⚙️ Privileged helper:")
            || line.hasPrefix("🔄 User helper:")
            || line.hasPrefix("🔄 Privileged helper:")
            || line == "⚠️ Click Register to restart helpers"
            || line == "⚙️ Advanced helpers unavailable — Epistemos runs in-process."
            || (line.hasPrefix("⚙️ Ollama:") && line.hasSuffix("pre-warmed"))
    }

    // MARK: - Menu Command Observers

    private static let menuNotifications: [Notification.Name] = [
        .menuToggleChevrons, .menuToggleOverlay, .menuRunTask, .menuCancelTask,
        .menuFind, .menuNewTab, .menuCloseTab, .menuNextTab, .menuPrevTab,
        .menuClearAll, .menuClearLog, .menuClearLLM, .menuClearHistory,
        .menuClearTasks, .menuClearTokens
    ]

    func setupMenuObservers() {
        for name in Self.menuNotifications {
            let menuName = name
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { [self] in handleMenuCommand(menuName) }
            }
        }
    }

    func updateSearchMatchCount(_ count: Int) {
        DispatchQueue.main.async {
            totalMatches = count
            if currentMatchIndex >= count {
                currentMatchIndex = max(0, count - 1)
            }
        }
    }

    func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        let hasCommand = event.modifierFlags.contains(.command)
        let hasShift = event.modifierFlags.contains(.shift)
        let key = event.charactersIgnoringModifiers

        if hasCommand, key == "w" {
            if let selId = viewModel.selectedTabId {
                viewModel.closeScriptTab(id: selId)
            } else if viewModel.scriptTabs.isEmpty {
                showQuitConfirm = true
            }
            return nil
        }

        if hasCommand, key == "t" {
            showNewTabSheet = true
            return nil
        }

        if hasCommand, key == "f" {
            showSearch.toggle()
            if showSearch {
                isSearchFieldFocused = true
            } else {
                searchText = ""
            }
            return nil
        }

        if event.keyCode == 53, showSearch {
            showSearch = false
            searchText = ""
            return nil
        }

        if hasCommand, key == "v" {
            if viewModel.pasteImageFromClipboard() { return nil }
            if viewModel.pasteLongTextAsAttachment() { return nil }
        }

        if hasCommand, key == "n" {
            return nil
        }

        if hasCommand, !hasShift, key == "b" {
            toggleThinkingDismissed()
            return nil
        }

        if hasCommand, event.keyCode == 36 {
            runActiveTaskFromShortcut()
            return nil
        }

        if hasCommand, key == "." {
            stopActiveTaskFromShortcut()
            return nil
        }

        if hasCommand, hasShift, key == "p" {
            showSettings = true
            return nil
        }

        if hasCommand, hasShift, key == "m" {
            viewModel.messagesMonitorEnabled.toggle()
            return nil
        }

        if hasCommand, !hasShift, key == "d" {
            toggleThinkingExpansion()
            return nil
        }

        if hasCommand, !hasShift, key == "l" {
            viewModel.clearSelectedLog()
            return nil
        }

        if hasCommand, hasShift, key == "k" {
            viewModel.clearAll()
            return nil
        }

        if hasCommand, hasShift, key == "l" {
            viewModel.rawLLMOutput = ""
            if let selId = viewModel.selectedTabId, let tab = viewModel.tab(for: selId) {
                tab.rawLLMOutput = ""
            }
            return nil
        }

        if hasCommand, hasShift, key == "h" {
            viewModel.promptHistory.removeAll()
            UserDefaults.standard.removeObject(forKey: "agentPromptHistory")
            if let selId = viewModel.selectedTabId, let tab = viewModel.tab(for: selId) {
                tab.promptHistory.removeAll()
            }
            return nil
        }

        if hasCommand, hasShift, key == "j" {
            viewModel.history.clearAll()
            return nil
        }

        if hasCommand, hasShift, key == "u" {
            viewModel.taskInputTokens = 0
            viewModel.taskOutputTokens = 0
            viewModel.sessionInputTokens = 0
            viewModel.sessionOutputTokens = 0
            return nil
        }

        if hasCommand, let key, let number = Int(key), number >= 1, number <= 9 {
            selectTab(viewModel: viewModel, number: number)
            return nil
        }

        if hasCommand, event.keyCode == 124 {
            nextTab(viewModel: viewModel)
            return nil
        }

        if hasCommand, event.keyCode == 123 {
            previousTab(viewModel: viewModel)
            return nil
        }

        if event.keyCode == 53 {
            if stopActiveTaskFromShortcut() {
                return nil
            }
        }

        if event.keyCode == 126 || event.keyCode == 125 {
            return navigatePromptHistoryFromShortcut(event)
        }

        return event
    }

    private func toggleThinkingDismissed() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if let selId = viewModel.selectedTabId, let tab = viewModel.tab(for: selId) {
                tab.thinkingDismissed.toggle()
            } else {
                viewModel.thinkingDismissed.toggle()
            }
        }
    }

    private func toggleThinkingExpansion() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if let selId = viewModel.selectedTabId, let tab = viewModel.tab(for: selId) {
                let expand = !tab.thinkingExpanded
                tab.thinkingExpanded = expand
                tab.thinkingOutputExpanded = expand
            } else {
                let expand = !viewModel.thinkingExpanded
                viewModel.thinkingExpanded = expand
                viewModel.thinkingOutputExpanded = expand
            }
        }
    }

    private func runActiveTaskFromShortcut() {
        if let selId = viewModel.selectedTabId, let tab = viewModel.tab(for: selId) {
            if !tab.taskInput.isEmpty && !tab.isLLMRunning {
                viewModel.runTabTask(tab: tab)
            }
        } else if !viewModel.taskInput.isEmpty && !viewModel.isRunning {
            viewModel.run()
        }
    }

    private func submitBridgePrompt(_ notification: Notification) {
        if let promptID = notification.userInfo?[AgentCloneBridge.promptIDUserInfoKey] as? UUID {
            AgentCloneBridge.markPromptConsumed(id: promptID)
        }
        guard let prompt = notification.userInfo?[AgentCloneBridge.promptUserInfoKey] as? String else { return }
        submitBridgePromptText(prompt)
    }

    private func drainPendingBridgePrompts() {
        for pendingPrompt in AgentCloneBridge.drainPendingPrompts() {
            submitBridgePromptText(pendingPrompt.text)
        }
    }

    private func submitBridgePromptText(_ prompt: String) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        applyCurrentHostContext()

        if let selId = viewModel.selectedTabId, let tab = viewModel.tab(for: selId) {
            tab.taskInput = trimmed
            viewModel.runTabTask(tab: tab)
            return
        }

        viewModel.taskInput = trimmed
        viewModel.run()
    }

    private func applyBridgeHostContext(_ notification: Notification) {
        guard let context = notification.userInfo?[AgentCloneBridge.hostContextUserInfoKey] as? AgentCloneHostContext else { return }
        viewModel.applyEpistemosHostContext(context)
    }

    private func applyCurrentHostContext() {
        guard let context = AgentCloneBridge.currentHostContext else { return }
        viewModel.applyEpistemosHostContext(context)
    }

    @discardableResult
    private func stopActiveTaskFromShortcut() -> Bool {
        if let selId = viewModel.selectedTabId,
           let tab = viewModel.tab(for: selId),
           tab.isBusy
        {
            if tab.isLLMRunning {
                viewModel.stopTabTask(tab: tab)
            } else if tab.isRunning {
                viewModel.cancelScriptTab(id: tab.id)
            }
            return true
        }
        if viewModel.isRunning || viewModel.isThinking {
            viewModel.stop()
            return true
        }
        return false
    }

    private func navigatePromptHistoryFromShortcut(_ event: NSEvent) -> NSEvent? {
        let text: String
        let browsingHistory: Bool
        if let tabId = viewModel.selectedTabId,
           let tab = viewModel.tab(for: tabId)
        {
            text = tab.taskInput
            browsingHistory = tab.historyIndex != -1
        } else {
            text = viewModel.taskInput
            browsingHistory = viewModel.historyIndex != -1
        }
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
        let isSingleLine = !text.contains("\n") && textWidth <= viewModel.inputFieldWidth
        if isSingleLine || browsingHistory {
            let direction = event.keyCode == 126 ? -1 : 1
            if let tabId = viewModel.selectedTabId,
               let tab = viewModel.tab(for: tabId)
            {
                tab.navigateHistory(direction: direction)
            } else {
                viewModel.navigatePromptHistory(direction: direction)
            }
            return nil
        }
        return event
    }

    /// Show the ask_user NSAlert and pass the result back through the view model's
    /// continuation. Driven by `.onChange(of: viewModel.pendingQuestion)` — no
    /// NotificationCenter, no polling.
    func showAskUserDialog(question: String) {
        guard !question.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = "Epistemos Question"
        alert.informativeText = question
        alert.alertStyle = .informational
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = "Your answer"
        alert.accessoryView = input
        alert.addButton(withTitle: "Send")
        alert.addButton(withTitle: "Skip")
        let response = alert.runModal()
        let answer: String = response == .alertFirstButtonReturn
            ? (input.stringValue.isEmpty ? "(no answer)" : input.stringValue)
            : "(skipped)"
        viewModel.provideAnswer(answer)
    }

    func handleMenuCommand(_ name: Notification.Name) {
        switch name {
        case .menuToggleChevrons:
            withAnimation(.easeInOut(duration: 0.25)) {
                if let selId = viewModel.selectedTabId, let tab = viewModel.tab(for: selId) {
                    let expand = !tab.thinkingExpanded
                    tab.thinkingExpanded = expand; tab.thinkingOutputExpanded = expand
                } else {
                    let expand = !viewModel.thinkingExpanded
                    viewModel.thinkingExpanded = expand; viewModel.thinkingOutputExpanded = expand
                }
            }
        case .menuToggleOverlay:
            withAnimation(.easeInOut(duration: 0.2)) {
                if let selId = viewModel.selectedTabId, let tab = viewModel.tab(for: selId) {
                    tab.thinkingDismissed.toggle()
                } else { viewModel.thinkingDismissed.toggle() }
            }
        case .menuRunTask:
            if let selId = viewModel.selectedTabId, let tab = viewModel.tab(for: selId) {
                if !tab.taskInput.isEmpty && !tab.isLLMRunning { viewModel.runTabTask(tab: tab) }
            } else if !viewModel.taskInput.isEmpty && !viewModel.isRunning { viewModel.run() }
        case .menuCancelTask:
            if let selId = viewModel.selectedTabId, let tab = viewModel.tab(for: selId), tab.isBusy {
                if tab.isLLMRunning { viewModel.stopTabTask(tab: tab) }
                else if tab.isRunning { viewModel.cancelScriptTab(id: tab.id) }
            } else if viewModel.isRunning { viewModel.stop() }
        case .menuFind:
            showSearch.toggle()
            if showSearch { isSearchFieldFocused = true } else { searchText = "" }
        case .menuNewTab: showNewTabSheet = true
        case .menuCloseTab:
            if let selId = viewModel.selectedTabId { viewModel.closeScriptTab(id: selId) }
        case .menuNextTab: nextTab(viewModel: viewModel)
        case .menuPrevTab: previousTab(viewModel: viewModel)
        case .menuClearAll: viewModel.clearAll()
        case .menuClearLog: viewModel.clearSelectedLog()
        case .menuClearLLM:
            viewModel.rawLLMOutput = ""
            if let selId = viewModel.selectedTabId, let tab = viewModel.tab(for: selId) { tab.rawLLMOutput = "" }
        case .menuClearHistory:
            viewModel.promptHistory.removeAll()
            UserDefaults.standard.removeObject(forKey: "agentPromptHistory")
            if let selId = viewModel.selectedTabId, let tab = viewModel.tab(for: selId) { tab.promptHistory.removeAll() }
        case .menuClearTasks: viewModel.history.clearAll()
        case .menuClearTokens:
            viewModel.taskInputTokens = 0; viewModel.taskOutputTokens = 0
            viewModel.sessionInputTokens = 0; viewModel.sessionOutputTokens = 0
        default: break
        }
    }

    private func nextMatch() {
        guard totalMatches > 0 else { return }
        currentMatchIndex = (currentMatchIndex + 1) % totalMatches
    }

    private func previousMatch() {
        guard totalMatches > 0 else { return }
        currentMatchIndex = (currentMatchIndex - 1 + totalMatches) % totalMatches
    }

    private static let tabColors: [Color] = [
        .orange, .purple, .pink, .cyan, .mint, .indigo, .teal, .yellow
    ]

    private static let sidePanelWidth: CGFloat = 340
    private static let maxChatColumnWidth: CGFloat = 880
    private static let minChatColumnWidth: CGFloat = 320

    private struct ChatLayoutMetrics {
        let contentWidth: CGFloat
        let chatWidth: CGFloat
        let chromeTopPadding: CGFloat
        let chromeBottomPadding: CGFloat
        let transcriptTopPadding: CGFloat
        let composerBottomPadding: CGFloat
    }

    private static func layoutMetrics(for size: CGSize, controlPanelVisible: Bool) -> ChatLayoutMetrics {
        let reservedPanelWidth = controlPanelVisible ? sidePanelWidth : 0
        let contentWidth = max(minChatColumnWidth, size.width - reservedPanelWidth)
        let sidePadding: CGFloat
        if contentWidth < 560 {
            sidePadding = 10
        } else if contentWidth < 760 {
            sidePadding = 18
        } else if contentWidth < 1040 {
            sidePadding = 28
        } else {
            sidePadding = 44
        }
        let chatWidth = min(maxChatColumnWidth, max(minChatColumnWidth, contentWidth - (sidePadding * 2)))
        let chromeTopPadding: CGFloat = contentWidth < 760 ? 10 : 14
        let chromeBottomPadding: CGFloat = contentWidth < 760 ? 8 : 10
        let topPadding: CGFloat = contentWidth < 760 ? 10 : 16
        let bottomPadding: CGFloat = contentWidth < 760 ? 8 : 12
        return ChatLayoutMetrics(
            contentWidth: contentWidth,
            chatWidth: chatWidth,
            chromeTopPadding: chromeTopPadding,
            chromeBottomPadding: chromeBottomPadding,
            transcriptTopPadding: topPadding,
            composerBottomPadding: bottomPadding
        )
    }

    /// Assign a consistent color per tab based on its index. Main tab uses .red.
    static func tabColor(for tabId: UUID, in tabs: [ScriptTab]) -> Color {
        guard let idx = tabs.firstIndex(where: { $0.id == tabId }) else { return .orange }
        return tabColors[idx % tabColors.count]
    }

    @ViewBuilder
    private var thinkingIndicator: some View {
        if let selId = viewModel.selectedTabId,
           let tab = viewModel.tab(for: selId)
        {
            if !tab.thinkingDismissed {
                ThinkingIndicatorView(viewModel: viewModel, tab: tab)
            }
        } else if viewModel.showThinkingIndicator && !isActiveDismissed {
            ThinkingIndicatorView(viewModel: viewModel)
        }
    }

    /// Whether the active context's thinking indicator has been dismissed.
    private var isActiveDismissed: Bool {
        if let selId = viewModel.selectedTabId,
           let tab = viewModel.tab(for: selId)
        {
            return tab.thinkingDismissed
        }
        return viewModel.thinkingDismissed
    }

    /// Whether the active context (selected tab or main) is in thinking state.
    private var isActiveThinking: Bool {
        if let selId = viewModel.selectedTabId,
           let tab = viewModel.tab(for: selId)
        {
            return tab.isLLMThinking
        }
        return viewModel.isThinking
    }

    /// Whether the active context is doing anything — thinking, running, or executing.
    private var isActiveRunning: Bool {
        if let selId = viewModel.selectedTabId,
           let tab = viewModel.tab(for: selId)
        {
            return tab.isLLMRunning || tab.isLLMThinking || tab.isRunning
        }
        return viewModel.isRunning || viewModel.isThinking
    }

    /// The prompt of the currently running task (main or selected tab).
    private var activeTaskPrompt: String? {
        // Check selected tab first
        if let selId = viewModel.selectedTabId,
           let tab = viewModel.tab(for: selId)
        {
            if tab.isLLMRunning { return tab.currentTaskPrompt }
            if tab.isRunning { return "Running: \(tab.scriptName)" }
        }
        // Always show main tab's prompt if it's running
        if viewModel.isRunning { return viewModel.currentTaskPrompt }
        return nil
    }

    /// The Apple AI annotation for the currently running task.
    private var activeAppleAIPrompt: String? {
        // Check selected tab first
        if let selId = viewModel.selectedTabId,
           let tab = viewModel.tab(for: selId)
        {
            let p = tab.currentAppleAIPrompt
            if !p.isEmpty { return p }
        }
        // Fall back to main tab
        let p = viewModel.currentAppleAIPrompt
        return p.isEmpty ? nil : p
    }

    /// Color for the currently selected tab.
    private var currentTabColor: Color {
        guard let selectedId = viewModel.selectedTabId else { return .red }
        if let tab = viewModel.tab(for: selectedId) {
            return tab.isMainTab ? .blue : Self.tabColor(for: selectedId, in: viewModel.scriptTabs)
        }
        return .red
    }
}

private struct EpistemosChatChromeBar: View {
    @Bindable var viewModel: AgentViewModel
    var selectedTab: ScriptTab?
    var controlPanelVisible: Bool
    @Binding var showControlPanel: Bool
    @Binding var showSearch: Bool
    @Binding var showSettings: Bool
    @Binding var showHistory: Bool
    @Binding var showNewTabSheet: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                titleBlock
                    .frame(minWidth: 160, alignment: .leading)

                Divider()
                    .frame(height: 18)

                modelButton

                Spacer(minLength: 8)

                chromeControls
            }

            HStack(spacing: 8) {
                compactTitleBlock

                Spacer(minLength: 6)

                chromeButton(
                    systemName: "sidebar.left",
                    accessibilityLabel: "Context panel",
                    isActive: controlPanelVisible
                ) {
                    showControlPanel.toggle()
                }

                chromeButton(systemName: "gearshape", accessibilityLabel: "Settings") {
                    showSettings = true
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(AgentSkin.surface.opacity(0.68))
        .overlay(
            RoundedRectangle(cornerRadius: AgentSkin.radius)
                .stroke(AgentSkin.border.opacity(0.72), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AgentSkin.radius))
    }

    private var titleBlock: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isRunning ? Color.green.opacity(0.9) : AgentSkin.accent.opacity(0.78))
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 1) {
                Text("Epistemos")
                    .font(AgentSkin.pixel(13))
                    .foregroundStyle(AgentSkin.text)
                    .lineLimit(1)

                Text(activeContextTitle)
                    .font(AgentSkin.mono(10))
                    .foregroundStyle(AgentSkin.textDim)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private var compactTitleBlock: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(isRunning ? Color.green.opacity(0.9) : AgentSkin.accent.opacity(0.78))
                .frame(width: 7, height: 7)
            Text("Epistemos")
                .font(AgentSkin.pixel(13))
                .foregroundStyle(AgentSkin.text)
                .lineLimit(1)
        }
    }

    private var modelButton: some View {
        let pair = providerModelPair
        return Button {
            showSettings = true
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "cpu")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AgentSkin.accent)

                Text(pair.provider)
                    .font(AgentSkin.pixel(11))
                    .foregroundStyle(AgentSkin.text)
                    .lineLimit(1)

                Text(pair.model)
                    .font(AgentSkin.mono(11))
                    .foregroundStyle(AgentSkin.textDim)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 9)
            .frame(height: 28)
            .frame(maxWidth: 280, alignment: .leading)
            .background(AgentSkin.bg.opacity(0.34))
            .overlay(
                RoundedRectangle(cornerRadius: AgentSkin.radius)
                    .stroke(AgentSkin.border.opacity(0.56), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AgentSkin.radius))
        }
        .buttonStyle(.plain)
        .help("Model settings")
        .accessibilityLabel("\(pair.provider), \(pair.model)")
    }

    private var chromeControls: some View {
        HStack(spacing: 4) {
            chromeButton(
                systemName: "sidebar.left",
                accessibilityLabel: "Context panel",
                isActive: controlPanelVisible
            ) {
                showControlPanel.toggle()
            }

            chromeButton(systemName: "plus.message", accessibilityLabel: "New chat") {
                showNewTabSheet = true
            }

            chromeButton(systemName: "magnifyingglass", accessibilityLabel: "Search") {
                showSearch.toggle()
            }

            chromeButton(systemName: "clock.arrow.circlepath", accessibilityLabel: "History") {
                showHistory = true
            }

            chromeButton(systemName: "gearshape", accessibilityLabel: "Settings") {
                showSettings = true
            }
        }
    }

    private func chromeButton(
        systemName: String,
        accessibilityLabel: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isActive ? AgentSkin.accent : AgentSkin.textDim)
                .frame(width: 28, height: 28)
                .background(isActive ? AgentSkin.accent.opacity(0.13) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: AgentSkin.radius)
                        .stroke(isActive ? AgentSkin.accent.opacity(0.44) : Color.clear, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AgentSkin.radius))
        }
        .buttonStyle(.plain)
        .help(accessibilityLabel)
        .accessibilityLabel(accessibilityLabel)
    }

    private var providerModelPair: (provider: String, model: String) {
        if let selectedTab {
            let resolved = viewModel.resolvedLLMConfig(for: selectedTab)
            return (resolved.provider.displayName, resolved.model)
        }
        let provider = viewModel.selectedProvider
        return (provider.displayName, viewModel.globalModelForProvider(provider))
    }

    private var activeContextTitle: String {
        if let selectedTab {
            return selectedTab.displayTitle
        }
        let model = viewModel.globalModelForProvider(viewModel.selectedProvider)
        return model.isEmpty ? "main session" : model
    }

    private var isRunning: Bool {
        if let selectedTab {
            return selectedTab.isBusy
        }
        return viewModel.isRunning || viewModel.isThinking
    }
}

private struct ChatStartSurface: View {
    @Bindable var viewModel: AgentViewModel
    @FocusState.Binding var isTaskFieldFocused: Bool
    var selectedTab: ScriptTab?
    let chatWidth: CGFloat

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 54)

            Text("epistemos")
                .font(.system(size: 50, weight: .black, design: .monospaced))
                .foregroundStyle(AgentSkin.text.opacity(0.72))

            InputSectionView(
                viewModel: viewModel,
                isTaskFieldFocused: $isTaskFieldFocused,
                selectedTab: selectedTab
            )
            .frame(width: chatWidth)

            Spacer(minLength: 96)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AgentSkin.bg)
    }
}

private struct AgentControlSidePanel: View {
    @Bindable var viewModel: AgentViewModel
    var selectedTab: ScriptTab?
    @Binding var showServices: Bool
    @Binding var showMessages: Bool
    @Binding var showAccessibility: Bool
    @Binding var showMCPServers: Bool
    @Binding var showTools: Bool
    @Binding var showSettings: Bool
    @Binding var showAIPopover: Bool
    @Binding var showOptions: Bool
    @Binding var showHistory: Bool
    @Binding var showClearConfirm: Bool
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Context")
                    .font(AgentSkin.pixel(14))
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("Close controls")
            }

            Divider()

            HeaderStatusView(viewModel: viewModel)
                .padding(.leading, -15)

            ProjectFolderSectionView(viewModel: viewModel, selectedTab: selectedTab)
                .padding(.horizontal, -12)
                .padding(.vertical, -6)

            EpistemosHostContextRow(summary: viewModel.epistemosHostContextSummary)

            Divider()

            Text("Capabilities")
                .font(AgentSkin.pixel(12))
                .foregroundStyle(AgentSkin.textDim)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HeaderToolbarButtons(
                        viewModel: viewModel,
                        showServices: $showServices,
                        showMessages: $showMessages,
                        showAccessibility: $showAccessibility,
                        showMCPServers: $showMCPServers,
                        showTools: $showTools,
                        showSettings: $showSettings,
                        showAIPopover: $showAIPopover,
                        showOptions: $showOptions,
                        showHistory: $showHistory,
                        showClearConfirm: $showClearConfirm
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(18)
        .frame(width: 340)
        .frame(maxHeight: .infinity)
        .background(AgentSkin.bg.opacity(0.97))
        .overlay(Rectangle().stroke(AgentSkin.border.opacity(0.75), lineWidth: 1))
    }
}

private struct EpistemosHostContextRow: View {
    let summary: String

    var body: some View {
        if !summary.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Text("Epistemos context")
                    .font(AgentSkin.pixel(11))
                    .foregroundStyle(AgentSkin.textDim)

                Text(summary)
                    .font(AgentSkin.mono(11))
                    .foregroundStyle(AgentSkin.text)
                    .lineLimit(3)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AgentSkin.surface.opacity(0.52))
            .overlay(Rectangle().stroke(AgentSkin.border.opacity(0.55), lineWidth: 1))
        }
    }
}
