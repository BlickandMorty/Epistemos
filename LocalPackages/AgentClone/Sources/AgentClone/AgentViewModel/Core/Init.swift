@preconcurrency import Foundation
import AgentTools
import AgentColorSyntax
import AgentTerminalNeo
import AgentLLM
import AppKit

extension AgentViewModel {
    // MARK: - Init Helpers

    /// Theme + script + system prompt bootstrap (called from init)
    func bootstrapThemeAndScripts() {
        activityLog = ChatHistoryStore.shared.buildActivityLogText(maxTasks: 3)
        // Trim main tab log on relaunch
        activityLog = ScriptTab.capActivityLog(activityLog)
        CodeBlockTheme.updateAppearance()
        TerminalNeoTheme.updateAppearance()
        // Restore ~/Documents/AgentScript/ folder and bundled resources if missing (off main thread)
        Task.detached { [scriptService = self.scriptService] in
            scriptService.ensurePackage()
            scriptService.rebuildAllMetadata()
            // Refresh upstream-bundled scripts when the embedded agent package upgraded since last sync. User-authored scripts untouched; modified bundled scripts backed up to .Trash.
            await scriptService.syncBundledScriptsFromRemote()
            let names = Set(scriptService.listScripts().map { $0.name.lowercased() })
            await MainActor.run { AppleIntelligenceMediator.knownAgentNames = names }
        }
        SystemPromptService.shared.ensureDefaults()
    }

    /// Messages monitor restoration on startup (called from init)
    func restoreMessagesMonitor() {
        guard messagesMonitorEnabled else { return }
        refreshMessageRecipients()
        Task {
            // Wait for UserService to be ready instead of a blind 3s sleep.
            _ = await Self.awaitServiceReady(ping: { [userService] in await userService.ping() }, timeout: 5)
            startMessagesMonitor()
        }
    }

    /// Startup ping / warmup task (called from init)
    func startupPingWarmup() {
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            // Epistemos: only run the SMAppService user-agent/daemon ping→mend→register flow if the helper plists are
            // actually bundled. They are NOT in the Epistemos app (the root-shell-exec LaunchDaemon is MAS-fatal/unsafe),
            // so surface ONE honest state instead of the "no response → mending → still NOT responding → Click Register"
            // spam. Capability preserved: bundle the plists + install the helper and this whole block re-engages.
            if SafeSMAppService.userAgentPlistExists() {
            appendLog("🔥 Warming up...")
            var userOK = await userService.ping()
            userPingOK = userOK
            appendLog("⚙️ User helper: \(userOK ? "ping OK" : "no response")")
            var daemonOK = false
            if rootEnabled {
                daemonOK = await helperService.ping()
                daemonPingOK = daemonOK
                appendLog("⚙️ Privileged helper: \(daemonOK ? "ping OK" : "no response")")
            } else {
                daemonPingOK = false
                appendLog("⚙️ Privileged helper: disabled")
            }
            if !userOK {
                appendLog("🔄 User helper: mending...")
                _ = userService.restartAgent()
                userOK = await Self.awaitServiceReady(ping: { [userService] in await userService.ping() }, timeout: 5)
                userPingOK = userOK
                appendLog("⚙️ User helper: \(userOK ? "mended — ping OK" : "still NOT responding")")
            }
            if rootEnabled && !daemonOK {
                appendLog("🔄 Privileged helper: mending...")
                _ = helperService.restartDaemon()
                daemonOK = await Self.awaitServiceReady(ping: { [helperService] in await helperService.ping() }, timeout: 5)
                daemonPingOK = daemonOK
                appendLog("⚙️ Privileged helper: \(daemonOK ? "mended — ping OK" : "still NOT responding")")
            }
            if !userOK || (rootEnabled && !daemonOK) {
                appendLog("⚠️ Click Register to restart helpers")
            }
            } else {
                userPingOK = false
                daemonPingOK = false
                appendLog("⚙️ Advanced helpers unavailable — Epistemos runs in-process.")
            }

            // Pre-warm Ollama model to avoid cold-start delay on first task
            await self.preWarmOllama()
        }
    }

    /// Poll an async ping function until it returns true or `timeout` elapses.
    /// Replaces the "sleep N seconds then ping once" anti-pattern: if the service
    /// comes up before the timeout we return immediately; if not, we don't miss it.
    static func awaitServiceReady(
        ping: @escaping @Sendable () async -> Bool,
        timeout: TimeInterval,
        interval: TimeInterval = 0.25
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await ping() { return true }
            try? await Task.sleep(for: .seconds(interval))
        }
        return await ping()
    }

    // MARK: - Provider selection dispatch

    func fetchModelsForSelectedProviderIfNeeded() {
        fetchModelsIfNeeded(for: selectedProvider)
    }

    /// Push global provider/model change into the active tab's LLMConfig.
    /// Skipped while a restore-from-tab is in flight so the tab's user-picked model isn't clobbered.
    func syncProviderToActiveTab() {
        if isRestoringProviderFromTab { return }
        guard let tabId = selectedTabId, let tab = tab(for: tabId), tab.isMainTab else { return }
        let model = globalModelForProvider(selectedProvider)
        tab.llmConfig = LLMConfig(provider: selectedProvider, model: model, displayName: tab.scriptName)
        persistScriptTabs()
    }

    /// Restore global provider/model from the active tab's saved LLMConfig when switching tabs.
    func restoreProviderFromActiveTab() {
        guard let tabId = selectedTabId,
              let tab = tab(for: tabId),
              let config = tab.llmConfig else { return }
        if selectedProvider != config.provider {
            isRestoringProviderFromTab = true
            selectedProvider = config.provider
            isRestoringProviderFromTab = false
        }
    }
}
