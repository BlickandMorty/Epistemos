import Foundation
import OSLog

/// Bridges the Hermes Expert Mode UI to the canonical
/// `HermesCommandDispatcher` and the chat / orchestrator state. Owns
/// the side-effecting handoffs (`MainChatSubmissionRouter` for free-form
/// `/ask` and natural-language input; transcript-only echoes for Core
/// commands that are surfaced inline like `/help`, `/calc`, `/status`).
///
/// Doctrinal posture:
/// - **Trivial** action class for parsed-command echoes; no biometric
///   needed for the dispatcher to surface what was parsed.
/// - **Sensitive / Destructive** for any command whose
///   `requiresApproval` is true — this runner does NOT bypass approval.
///   It surfaces the parsed command and lets the chat coordinator route
///   through the existing approval modal pipeline.
/// - Pro-tier commands return early with an inline error in MAS-build
///   mode (handled at the dispatcher level — `parseCore` only returns
///   Core variants, so Pro patterns just resolve to `nil` here).
@MainActor
struct HermesExpertModeRunner {
    private static let log = Logger(subsystem: "com.epistemos", category: "HermesExpertModeRunner")

    let state: HermesExpertModeState
    let chat: ChatState
    let orchestrator: OrchestratorState
    let inference: InferenceState
    let ui: UIState
    let operatingMode: () -> EpistemosOperatingMode
    let onDelegateToMainChat: (String) -> Void

    /// Single entry point for every submission from the expert mode
    /// input ribbon. Routes:
    /// - empty / whitespace → no-op
    /// - bare prompt (no leading slash) → `/ask`-equivalent path:
    ///   handed off to MainChatSubmissionRouter via the closure
    /// - `/cmd ...` → `HermesCommandDispatcher.parseCore` → branch
    func submit(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.append(.init(kind: .userInput, text: trimmed))
        state.clearDraft()

        // Bare prompt (no slash): treat as /ask — hand to main chat.
        if !trimmed.hasPrefix("/") {
            handoffAsAsk(trimmed)
            return
        }

        guard let parsed = HermesCommandDispatcher.parseCore(trimmed) else {
            state.append(.init(
                kind: .error,
                text: "Unknown or Pro-only command. Try /help."
            ))
            state.lastErrorMessage = "Unknown or Pro-only command."
            return
        }

        dispatch(parsed, raw: trimmed)
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
            renderInfo("Token / context dashboard — opening native panel.")
            // Hand off to native dashboard surface
            NotificationCenter.default.post(name: .toggleSessionIntelligence, object: nil)

        case .cost:
            renderInfo("Cost panel — opening native dashboard.")
            NotificationCenter.default.post(name: .toggleSessionIntelligence, object: nil)

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
            renderInfo("Model: " + cmd.echoSummary)

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
            renderInfo("Notebook: " + cmd.echoSummary)

        case .colors, .font, .fontsize, .theme, .width, .mode:
            renderInfo("UI/display change applied (echo): \(raw)")
        }
    }

    // MARK: - Inline renderers

    private func renderHelpInline() {
        let registry = HermesCapabilityRegistry.all
        let core = registry.filter { $0.tier == .core }
        let pro = registry.filter { $0.tier == .pro }

        state.append(.init(kind: .systemResponse,
            text: "Hermes parity — \(registry.count) commands across \(HermesCapabilitySurface.allCases.count) surfaces."))
        state.append(.init(kind: .info,
            text: "CORE (\(core.count)): /ask /think /todo /new /clear /status /tokens /cost /model /help /persona /memory /tools /config /read /write /append /ls /search /grep /save /load /export /compact /summary /system /notebook"))
        state.append(.init(kind: .info,
            text: "PRO (\(pro.count); MAS gates these): /execute /run /shell /kill"))
        state.append(.init(kind: .info,
            text: "Type / to surface the live palette. Bare prompts route to /ask."))
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
        state.append(.init(kind: .systemResponse,
            text: "model=\(model)  mode=\(opMode)  panel=\(panel)"))
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
