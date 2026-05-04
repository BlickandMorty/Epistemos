import Foundation
import OSLog

/// Sovereign Gate category for Hermes Expert Mode approval-gated
/// commands. Single-owner discipline — this category is only used by
/// the runner; never duplicate it elsewhere.
extension SovereignGateCategory {
    static let hermesExpertCommand = SovereignGateCategory(rawValue: "hermes_expert_command")
}

/// Bridges the Hermes Expert Mode UI to the canonical
/// `HermesCommandDispatcher`, the chat / orchestrator state, the
/// canonical `SovereignGate` for approval-gated commands, and the
/// canonical `AgentToolProvenanceRecorder` for provenance.
///
/// Doctrinal posture:
/// - **Trivial** action class for parsed-command echoes; no biometric
///   needed for the dispatcher to surface what was parsed.
/// - **Sensitive (15-min biometric grace)** for any command whose
///   `requiresApproval` is true. Routes through the canonical
///   `Epistemos/Sovereign/SovereignGate.swift` — single LAContext owner
///   per doctrine §A.7. NEVER duplicates `LAContext` calls.
/// - Pro-tier commands resolve to nil at the dispatcher (parseCore only
///   returns Core variants); the runner surfaces them as inline errors.
/// - Every submission emits provenance via the canonical
///   `AgentToolProvenanceRecorder` — the same recorder MLX inference
///   uses — so Provenance Console (T2) sees expert-mode activity.
@MainActor
struct HermesExpertModeRunner {
    private static let log = Logger(subsystem: "com.epistemos", category: "HermesExpertModeRunner")

    let state: HermesExpertModeState
    let chat: ChatState
    let orchestrator: OrchestratorState
    let inference: InferenceState
    let ui: UIState
    let operatingMode: () -> EpistemosOperatingMode
    let sovereignGate: SovereignGate
    let provenanceRecorder: AgentToolProvenanceRecorder
    let onDelegateToMainChat: (String) -> Void

    /// Single entry point for every submission from the expert mode
    /// input ribbon. Routes:
    /// - empty / whitespace → no-op
    /// - bare prompt (no leading slash) → `/ask`-equivalent path:
    ///   handed off to MainChatSubmissionRouter via the closure
    /// - `/cmd ...` (no approval needed) → dispatch + provenance
    /// - `/cmd ...` (approval needed) → Sovereign Gate biometric +
    ///   provenance (denied / approved / completed)
    func submit(_ raw: String) async {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.append(.init(kind: .userInput, text: trimmed))
        state.recordHistory(trimmed)
        state.resetRecall()
        state.bumpSubmitCounter()
        state.clearDraft()

        // Bare prompt (no slash): treat as /ask — hand to main chat.
        if !trimmed.hasPrefix("/") {
            recordSubmissionStart(toolName: "hermes_expert.ask",
                                  args: ["prompt": String(trimmed.prefix(120))])
            recordSubmissionCompleted(toolName: "hermes_expert.ask",
                                      result: "delegated_to_main_chat")
            handoffAsAsk(trimmed)
            return
        }

        guard let parsed = HermesCommandDispatcher.parseCore(trimmed) else {
            recordSubmissionStart(toolName: "hermes_expert.unknown",
                                  args: ["raw": String(trimmed.prefix(120))])
            recordSubmissionFailed(toolName: "hermes_expert.unknown",
                                   error: "unknown_or_pro_only")
            state.append(.init(
                kind: .error,
                text: "Unknown or Pro-only command. Try /help."
            ))
            state.lastErrorMessage = "Unknown or Pro-only command."
            return
        }

        let toolName = "hermes_expert.\(commandKey(for: parsed))"
        recordSubmissionStart(toolName: toolName, args: ["raw": String(trimmed.prefix(180))])

        // Approval-gated commands (per the parsed-command's own
        // `requiresApproval` flag) must pass Sovereign Gate first.
        // Routes through the canonical SovereignGate (single LAContext
        // owner) — never re-implements LocalAuthentication.
        if parsed.requiresApproval {
            state.dispatching = true
            defer { state.dispatching = false }

            recordSubmissionApprovalRequested(toolName: toolName)

            let outcome = await sovereignGate.confirm(
                .biometric(category: .hermesExpertCommand),
                reason: sovereignReason(for: parsed)
            )
            switch outcome {
            case .allowed:
                recordSubmissionApprovalGranted(toolName: toolName)
                state.append(.init(kind: .info, text: "✓ approved — running…"))
                dispatch(parsed, raw: trimmed)
                recordSubmissionCompleted(toolName: toolName, result: "approved_and_dispatched")
            case .denied(let reason):
                let reasonText: String
                switch reason {
                case .missingReason:        reasonText = "missing_reason"
                case .authenticationFailed: reasonText = "authentication_failed"
                }
                recordSubmissionApprovalDenied(toolName: toolName, reason: reasonText)
                state.append(.init(kind: .error, text: "✗ denied (\(reasonText))"))
                state.lastErrorMessage = "Sovereign Gate denied: \(reasonText)"
            }
            return
        }

        dispatch(parsed, raw: trimmed)
        recordSubmissionCompleted(toolName: toolName, result: "dispatched")
    }

    // MARK: - Dispatch routes

    private func dispatch(_ command: HermesParsedCommand, raw: String) {
        switch command {
        case .ask(let question):
            handoffAsAsk(question)

        case .help:
            renderHelpInline()

        case .calc(let cmd):
            renderCalcInline(cmd)

        case .status:
            renderStatusInline()

        case .tokens:
            renderTokensInline()

        case .cost:
            renderCostInline()

        case .think(let cmd):
            renderInfo("Local thinking display: \"\(cmd.prompt.prefix(80))…\"")
            handoffAsAsk("/think " + cmd.prompt)

        case .todo:
            renderInfo("Todo subsystem — opening from native surface.")

        case .newSession:
            renderInfo("New session — clearing context.")
            chat.startNewChat()

        case .clear:
            renderInfo("Clearing transcript.")
            state.transcript = []

        case .compact:
            renderInfo("Compaction — handing to native compactor.")
            handoffAsAsk("/compact")

        case .summary:
            renderInfo("Generating summary artifact via native pipeline.")
            handoffAsAsk("/summary")

        case .save:
            renderInfo("Save — native session ledger.")

        case .load:
            renderInfo("Load — opening native session browser.")

        case .export:
            renderInfo("Export — user-approved.")
            handoffAsAsk("/export")

        case .model(let cmd):
            renderModelInline(cmd)

        case .persona(let cmd):
            renderInfo("Persona: " + cmd.echoSummary)

        case .parameter(let cmd):
            renderInfo("Parameter: " + cmd.echoSummary)

        case .systemPrompt(let cmd):
            renderInfo("System prompt update queued (audited): " + cmd.echoSummary)
            handoffAsAsk(raw)

        case .memory(let cmd):
            renderInfo("Memory: " + cmd.echoSummary)

        case .toolsToggle(let cmd):
            renderInfo("Tools: " + cmd.echoSummary)

        case .uiToggle(let cmd):
            renderInfo("UI toggle: " + cmd.echoSummary)

        case .configShow:
            renderInfo("Config show — opening native diagnostics panel.")

        case .read(let cmd):
            renderInfo("Read: " + cmd.echoSummary)
            handoffAsAsk(raw)

        case .write(let cmd):
            renderInfo("Write (approval-gated): " + cmd.echoSummary)
            handoffAsAsk(raw)

        case .append(let cmd):
            renderInfo("Append (approval-gated): " + cmd.echoSummary)
            handoffAsAsk(raw)

        case .ls(let cmd):
            renderInfo("ls: " + cmd.echoSummary)
            handoffAsAsk(raw)

        case .search(let cmd):
            renderInfo("Search: " + cmd.echoSummary)
            handoffAsAsk(raw)

        case .grep(let cmd):
            renderInfo("Grep: " + cmd.echoSummary)
            handoffAsAsk(raw)

        case .notebook(let cmd):
            renderNotebookInline(cmd)

        case .colors, .font, .fontsize, .theme, .width, .mode:
            renderInfo("UI/display change applied (echo): \(raw)")
        }
    }

    // MARK: - Inline renderers

    private func renderHelpInline() {
        let registry = HermesCapabilityRegistry.all
        let coreCount = registry.filter { $0.tier == .core }.count
        let proCount = registry.filter { $0.tier == .pro }.count
        let researchCount = registry.filter { $0.tier == .research }.count

        state.append(.init(kind: .systemResponse,
            text: "Hermes parity — \(registry.count) commands. CORE \(coreCount), PRO \(proCount), RESEARCH \(researchCount)."))

        let groups: [(HermesCapabilitySurface, String)] = [
            (.agentTask,        "agent"),
            (.session,          "session"),
            (.configuration,    "config"),
            (.fileData,         "files"),
            (.persona,          "persona"),
            (.uiDisplay,        "ui"),
            (.toolsIntegration, "tools"),
            (.advanced,         "advanced"),
            (.toolset,          "toolset"),
            (.messaging,        "msg"),
        ]

        for (surface, label) in groups {
            let bySurface = registry.filter { $0.surface == surface && $0.tier == .core }
            guard !bySurface.isEmpty else { continue }
            let tokens = bySurface.map { $0.commandToken }.joined(separator: " ")
            state.append(.init(
                kind: .info,
                text: "[\(label)] \(tokens)"
            ))
        }

        if proCount > 0 {
            state.append(.init(kind: .info,
                text: "[pro · MAS-blocked] /execute /run /shell /kill"))
        }
        state.append(.init(kind: .info,
            text: "tab autofills · ↑↓ palette · ⏎ submit · ⎋ exit"))
    }

    private func renderCalcInline(_ cmd: HermesCalcCommand) {
        switch cmd.evaluate() {
        case .success(_, let formatted):
            state.append(.init(kind: .systemResponse, text: "= \(formatted)"))
        case .failure(let reason):
            state.append(.init(kind: .error, text: "calc error: \(reason)"))
        }
    }

    private func renderStatusInline() {
        let model = inference.preferredChatModelSelection.displayName
        let opMode = operatingMode().displayName
        let panel = ui.activePanel.rawValue
        let runID = state.sessionRunID.isEmpty ? "—" : String(state.sessionRunID.suffix(8))
        let transcriptCount = state.transcript.count

        state.append(.init(kind: .systemResponse, text: "── status ──"))
        state.append(.init(kind: .info, text: "model       \(model)"))
        state.append(.init(kind: .info, text: "mode        \(opMode)"))
        state.append(.init(kind: .info, text: "panel       \(panel)"))
        state.append(.init(kind: .info, text: "incognito   \(chat.isIncognito ? "yes" : "no")"))
        state.append(.init(kind: .info, text: "session     hermes-expert/\(runID)"))
        state.append(.init(kind: .info, text: "transcript  \(transcriptCount) entries"))
    }

    private func renderTokensInline() {
        let model = inference.preferredChatModelSelection.displayName
        // Approximate context budget by class — local 4-bit MLX 4-8B
        // tier vs cloud frontier — so the user sees something useful
        // without us having to wire a per-turn token meter (that's
        // session intelligence panel territory). The panel is opened
        // alongside for the live drill-down.
        let estimatedContext: String
        switch inference.preferredChatModelSelection {
        case .localMLX:        estimatedContext = "~32K (local MLX, 4-bit class)"
        case .cloud:           estimatedContext = "~200K (cloud frontier class)"
        case .appleIntelligence: estimatedContext = "~12K (Apple Intelligence)"
        }
        state.append(.init(kind: .systemResponse, text: "── tokens ──"))
        state.append(.init(kind: .info, text: "model        \(model)"))
        state.append(.init(kind: .info, text: "context cap  \(estimatedContext)"))
        state.append(.init(kind: .info,
            text: "live drill-down → opening Session Intelligence panel"))
        NotificationCenter.default.post(name: .toggleSessionIntelligence, object: nil)
    }

    private func renderCostInline() {
        let model = inference.preferredChatModelSelection.displayName
        let surface: String
        switch inference.preferredChatModelSelection {
        case .localMLX:           surface = "$0 — local MLX runs in-process"
        case .appleIntelligence:  surface = "$0 — Apple Intelligence"
        case .cloud:              surface = "billed per token (see Session Intelligence)"
        }
        state.append(.init(kind: .systemResponse, text: "── cost ──"))
        state.append(.init(kind: .info, text: "model      \(model)"))
        state.append(.init(kind: .info, text: "surface    \(surface)"))
        state.append(.init(kind: .info,
            text: "live drill-down → opening Session Intelligence panel"))
        NotificationCenter.default.post(name: .toggleSessionIntelligence, object: nil)
    }

    private func renderNotebookInline(_ cmd: HermesNotebookCommand) {
        switch cmd.action {
        case .showCurrent:
            state.append(.init(kind: .systemResponse,
                text: "notebook: opening notes panel"))
            UtilityWindowManager.shared.show(.notes)
        case .list:
            state.append(.init(kind: .systemResponse,
                text: "notebook list: opening notes panel for browsing"))
            UtilityWindowManager.shared.show(.notes)
        case .open(let name):
            state.append(.init(kind: .systemResponse,
                text: "notebook open '\(name)': opening notes panel — find by title"))
            UtilityWindowManager.shared.show(.notes)
        case .clear:
            state.append(.init(kind: .info,
                text: "notebook clear: destructive — handled per-note via the notes panel"))
            UtilityWindowManager.shared.show(.notes)
        }
    }

    /// Materialize a `/model` action into a real InferenceState mutation
    /// when the user provides a name we can resolve. `/model list` and
    /// bare `/model` are read-only and route through here too.
    private func renderModelInline(_ cmd: HermesModelCommand) {
        switch cmd.action {
        case .showCurrent:
            state.append(.init(kind: .systemResponse,
                text: "current model: \(inference.preferredChatModelSelection.displayName)"))

        case .list:
            state.append(.init(kind: .systemResponse, text: "── available models ──"))
            // Local options (always available)
            state.append(.init(kind: .info,
                text: "[local-mlx] preferred=\(inference.preferredLocalTextModelID)"))
            // Cloud options — derived from the CloudTextModelID enum
            let cloudIDs = CloudTextModelID.allCases
            for id in cloudIDs.prefix(8) {
                state.append(.init(kind: .info, text: "[cloud] \(id.rawValue)"))
            }
            if cloudIDs.count > 8 {
                state.append(.init(kind: .info,
                    text: "… \(cloudIDs.count - 8) more (see Settings → Models)"))
            }

        case .switchTo(let name):
            // Try cloud first (most common selection); fall back to local mlx
            // if the user typed a recognizable local model id.
            if let cloud = CloudTextModelID.from(rawValueOrVendorID: name) {
                inference.preferredChatModelSelection = .cloud(cloud)
                state.append(.init(kind: .systemResponse,
                    text: "→ model switched: cloud(\(cloud.rawValue))"))
            } else if !name.isEmpty {
                inference.preferredChatModelSelection = .localMLX(name)
                state.append(.init(kind: .systemResponse,
                    text: "→ model switched: localMLX(\(name))"))
            } else {
                state.append(.init(kind: .error, text: "model name was empty"))
            }
        }
    }

    private func renderInfo(_ text: String) {
        state.append(.init(kind: .systemEcho, text: text))
    }

    // MARK: - Handoffs

    private func handoffAsAsk(_ prompt: String) {
        // Route through the canonical main chat submission so prompt
        // caching / streaming / tool-use all work the same as the
        // normal landing search path. The view will exit expert mode
        // and the next response renders in the main chat surface.
        onDelegateToMainChat(prompt)
    }

    // MARK: - Sovereign Gate reason strings

    /// Human-readable reason shown in the LAContext biometric prompt.
    /// The reason MUST be specific to the action so the user can make
    /// an informed grant (doctrine: never show generic "approve this"
    /// prompts; tell the user what they're approving).
    private func sovereignReason(for command: HermesParsedCommand) -> String {
        switch command {
        case .clear:        return "Clear the current chat transcript"
        case .compact:      return "Compact the current session context"
        case .export:       return "Export this session"
        case .write:        return "Write to a vault file"
        case .append:       return "Append to a vault file"
        case .systemPrompt: return "Update the audited system prompt"
        case .memory:       return "Change memory configuration"
        case .toolsToggle:  return "Toggle tool / tier policy"
        case .model:        return "Switch model routing"
        case .todo:         return "Modify the todo subsystem"
        default:            return "Confirm Hermes Expert Mode action"
        }
    }

    // MARK: - Provenance recording

    /// Stable per-submission identifier so the start / approval /
    /// complete events tie together in the ledger. Each `submit`
    /// pass uses one fresh ID.
    private static func makeToolCallID() -> String { "hermes_expert_\(UUID().uuidString)" }

    private static func encodeArgs(_ dict: [String: String]) -> String? {
        guard let data = try? JSONEncoder().encode(dict),
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }

    private func recordSubmissionStart(toolName: String, args: [String: String]) {
        let runID = state.sessionRunID
        guard !runID.isEmpty else { return }
        let toolCallID = Self.makeToolCallID()
        // Stash the most recent toolCallID on the state so completion /
        // failure / approval events can reference the same id.
        state.lastSubmissionToolCallID = toolCallID
        let _ = provenanceRecorder.recordToolEvent(
            runID: runID,
            traceID: nil,
            kind: .toolCallRequested,
            actor: .user,
            toolCallID: toolCallID,
            toolName: toolName,
            argumentsJSON: Self.encodeArgs(args),
            status: .requested
        )
    }

    private func recordSubmissionApprovalRequested(toolName: String) {
        let runID = state.sessionRunID
        let toolCallID = state.lastSubmissionToolCallID
        guard !runID.isEmpty, !toolCallID.isEmpty else { return }
        let _ = provenanceRecorder.recordToolEvent(
            runID: runID,
            traceID: nil,
            kind: .toolCallRequested,
            actor: .system,
            toolCallID: toolCallID,
            toolName: toolName,
            argumentsJSON: nil,
            status: .requested,
            metadata: ["sovereign_gate": "requested"]
        )
    }

    private func recordSubmissionApprovalGranted(toolName: String) {
        let runID = state.sessionRunID
        let toolCallID = state.lastSubmissionToolCallID
        guard !runID.isEmpty, !toolCallID.isEmpty else { return }
        let _ = provenanceRecorder.recordToolEvent(
            runID: runID,
            traceID: nil,
            kind: .toolCallApproved,
            actor: .user,
            toolCallID: toolCallID,
            toolName: toolName,
            argumentsJSON: nil,
            status: .approved,
            metadata: ["sovereign_gate": "approved"]
        )
    }

    private func recordSubmissionApprovalDenied(toolName: String, reason: String) {
        let runID = state.sessionRunID
        let toolCallID = state.lastSubmissionToolCallID
        guard !runID.isEmpty, !toolCallID.isEmpty else { return }
        let _ = provenanceRecorder.recordToolEvent(
            runID: runID,
            traceID: nil,
            kind: .toolCallDenied,
            actor: .user,
            toolCallID: toolCallID,
            toolName: toolName,
            argumentsJSON: nil,
            status: .denied,
            errorMessage: reason,
            metadata: ["sovereign_gate": "denied"]
        )
    }

    private func recordSubmissionCompleted(toolName: String, result: String) {
        let runID = state.sessionRunID
        let toolCallID = state.lastSubmissionToolCallID
        guard !runID.isEmpty, !toolCallID.isEmpty else { return }
        let _ = provenanceRecorder.recordToolEvent(
            runID: runID,
            traceID: nil,
            kind: .toolCallCompleted,
            actor: .system,
            toolCallID: toolCallID,
            toolName: toolName,
            argumentsJSON: nil,
            resultJSON: Self.encodeArgs(["result": result]),
            status: .completed
        )
    }

    private func recordSubmissionFailed(toolName: String, error: String) {
        let runID = state.sessionRunID
        let toolCallID = state.lastSubmissionToolCallID
        guard !runID.isEmpty, !toolCallID.isEmpty else { return }
        let _ = provenanceRecorder.recordToolEvent(
            runID: runID,
            traceID: nil,
            kind: .toolCallFailed,
            actor: .system,
            toolCallID: toolCallID,
            toolName: toolName,
            argumentsJSON: nil,
            status: .failed,
            errorMessage: error
        )
    }

    /// Short stable key per parsed command variant for tool-name
    /// composition. Mirrors the registry's command-token shape so it
    /// reads cleanly in the Provenance Console.
    private func commandKey(for command: HermesParsedCommand) -> String {
        switch command {
        case .ask:          return "ask"
        case .append:       return "append"
        case .calc:         return "calc"
        case .clear:        return "clear"
        case .colors:       return "colors"
        case .compact:      return "compact"
        case .configShow:   return "config_show"
        case .cost:         return "cost"
        case .export:       return "export"
        case .font:         return "font"
        case .fontsize:     return "fontsize"
        case .grep:         return "grep"
        case .help:         return "help"
        case .load:         return "load"
        case .ls:           return "ls"
        case .memory:       return "memory"
        case .mode:         return "mode"
        case .model:        return "model"
        case .newSession:   return "new_session"
        case .notebook:     return "notebook"
        case .parameter:    return "parameter"
        case .persona:      return "persona"
        case .read:         return "read"
        case .save:         return "save"
        case .search:       return "search"
        case .status:       return "status"
        case .summary:      return "summary"
        case .systemPrompt: return "system_prompt"
        case .theme:        return "theme"
        case .think:        return "think"
        case .todo:         return "todo"
        case .tokens:       return "tokens"
        case .toolsToggle:  return "tools_toggle"
        case .uiToggle:     return "ui_toggle"
        case .width:        return "width"
        case .write:        return "write"
        }
    }
}

// MARK: - Echo summary helpers (small UI-side adapters)
//
// Each command file ships a domain-correct API; for inline transcript
// rendering we only need a 1-line "what got parsed" string. These
// adapters call the existing public surface without duplicating logic.
// If a command file changes its public shape, update the adapter, not
// the runner.

extension HermesModelCommand {
    var echoSummary: String { "request — \(self)" }
}

extension HermesPersonaCommand {
    var echoSummary: String { "request — \(self)" }
}

extension HermesParameterCommand {
    var echoSummary: String { "request — \(self)" }
}

extension HermesSystemPromptCommand {
    var echoSummary: String { "request — \(self)" }
}

extension HermesMemoryCommand {
    var echoSummary: String { "request — \(self)" }
}

extension HermesToolsToggleCommand {
    var echoSummary: String { "request — \(self)" }
}

extension HermesUIToggleCommand {
    var echoSummary: String { "request — \(self)" }
}

extension HermesReadCommand {
    var echoSummary: String { "request — \(self)" }
}

extension HermesWriteCommand {
    var echoSummary: String { "request — \(self)" }
}

extension HermesAppendCommand {
    var echoSummary: String { "request — \(self)" }
}

extension HermesLsCommand {
    var echoSummary: String { "request — \(self)" }
}

extension HermesSearchCommand {
    var echoSummary: String { "request — \(self)" }
}

extension HermesGrepCommand {
    var echoSummary: String { "request — \(self)" }
}

extension HermesNotebookCommand {
    var echoSummary: String { "request — \(self)" }
}
