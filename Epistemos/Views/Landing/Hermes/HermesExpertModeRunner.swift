import Foundation
import OSLog
import SwiftUI

/// Sovereign Gate category for Hermes Expert Mode approval-gated
/// commands. Single-owner discipline — this category is only used by
/// the runner; never duplicate it elsewhere.
extension SovereignGateCategory {
    static let hermesExpertCommand = SovereignGateCategory(rawValue: "hermes_expert_command")
}

// GENUI-DEFER: hackathon-2026-05-03
// Every `render*Inline` method below produces inline transcript rows
// instead of routing through GenUIDispatcher. This is doctrinally
// incorrect per `docs/fusion/COGNITIVE_GENUI_DOCTRINE_2026_05_03.md`
// (T0 sub-track 4); the dispatcher does not yet exist (G.2 not shipped).
// On the migration list at `COGNITIVE_GENUI_DOCTRINE` §9 as **G.3
// priority 1** — first to migrate when G.2 lands. DO NOT add new
// per-command renderers here without either (a) including the
// dispatcher migration or (b) appending another row to the §9 list.

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
    let vaultSync: VaultSyncService
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
            // Surface confirmation, then clear with the spring animation
            // bound on `transcript.count` in the view (List rows fade out
            // on removal). We append BEFORE clearing so the user sees
            // the line then watches it sweep away with the rest.
            renderInfo("Clearing transcript…")
            withAnimation(.easeOut(duration: 0.32)) {
                state.transcript = []
            }

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
            renderPersonaInline(cmd)

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
            renderConfigShowInline()

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
            renderSearchInline(cmd)

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
        // Routes through the existing Artifact + ArtifactBlockView
        // pipeline (chat-block schema-first GenUI, partial). Migrates
        // to GenUIDispatcher when G.2 lands per
        // `COGNITIVE_GENUI_DOCTRINE_2026_05_03.md` §9 deferral list.
        let registry = HermesCapabilityRegistry.all
        let coreCount = registry.filter { $0.tier == .core }.count
        let proCount = registry.filter { $0.tier == .pro }.count
        let researchCount = registry.filter { $0.tier == .research }.count

        var lines: [String] = []
        lines.append("# Hermes parity")
        lines.append("")
        lines.append("**\(registry.count) commands** · CORE \(coreCount) · PRO \(proCount) · RESEARCH \(researchCount)")
        lines.append("")

        let groups: [(HermesCapabilitySurface, String)] = [
            (.agentTask,        "Agent"),
            (.session,          "Session"),
            (.configuration,    "Configuration"),
            (.fileData,         "Files"),
            (.persona,          "Persona"),
            (.uiDisplay,        "UI / Display"),
            (.toolsIntegration, "Tools"),
            (.advanced,         "Advanced"),
            (.toolset,          "Toolset"),
            (.messaging,        "Messaging"),
        ]

        for (surface, label) in groups {
            let bySurface = registry.filter { $0.surface == surface && $0.tier == .core }
            guard !bySurface.isEmpty else { continue }
            lines.append("## \(label)")
            for cap in bySurface {
                lines.append("- `\(cap.commandPattern)` — \(cap.nativeEquivalent)")
            }
            lines.append("")
        }

        if proCount > 0 {
            lines.append("## Pro (MAS gates these)")
            lines.append("`/execute` `/run` `/shell` `/kill`")
            lines.append("")
        }

        lines.append("---")
        lines.append("_Tab autofills · ↑↓ palette / history · ⏎ submit · ⎋ exit_")

        state.append(.artifact(Artifact(
            kind: .markdown,
            title: "Hermes Parity",
            content: lines.joined(separator: "\n"),
            schemaName: "hermes.help"
        )))
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

        let yaml = """
        model:       \(yamlEscape(model))
        mode:        \(yamlEscape(opMode))
        panel:       \(yamlEscape(panel))
        incognito:   \(chat.isIncognito ? "true" : "false")
        session:     hermes-expert/\(runID)
        transcript:  \(transcriptCount)
        """
        state.append(.artifact(Artifact(
            kind: .yaml,
            title: "Status",
            language: "yaml",
            content: yaml,
            schemaName: "hermes.status"
        )))
    }

    private func renderTokensInline() {
        let model = inference.preferredChatModelSelection.displayName
        let estimatedContext: String
        switch inference.preferredChatModelSelection {
        case .localMLX:          estimatedContext = "~32K (local MLX, 4-bit class)"
        case .cloud:             estimatedContext = "~200K (cloud frontier class)"
        case .appleIntelligence: estimatedContext = "~12K (Apple Intelligence)"
        }
        let yaml = """
        model:        \(yamlEscape(model))
        context_cap:  \(yamlEscape(estimatedContext))
        live_panel:   opening (Session Intelligence)
        """
        state.append(.artifact(Artifact(
            kind: .yaml,
            title: "Tokens",
            language: "yaml",
            content: yaml,
            schemaName: "hermes.tokens"
        )))
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
        let yaml = """
        model:      \(yamlEscape(model))
        surface:    \(yamlEscape(surface))
        live_panel: opening (Session Intelligence)
        """
        state.append(.artifact(Artifact(
            kind: .yaml,
            title: "Cost",
            language: "yaml",
            content: yaml,
            schemaName: "hermes.cost"
        )))
        NotificationCenter.default.post(name: .toggleSessionIntelligence, object: nil)
    }

    private func renderSearchInline(_ cmd: HermesSearchCommand) {
        let results = vaultSync.searchFull(query: cmd.query, limit: 5)
        guard !results.isEmpty else {
            state.append(.init(
                kind: .info,
                text: "search '\(cmd.query)': no matches"
            ))
            return
        }
        var lines: [String] = []
        lines.append("# Search — '\(cmd.query)'")
        lines.append("")
        for (idx, hit) in results.enumerated() {
            let title = hit.title.isEmpty ? "(untitled)" : hit.title
            let snippet = hit.snippet
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let snippetTruncated = snippet.count > 240
                ? String(snippet.prefix(240)) + "…"
                : snippet
            lines.append("**\(idx + 1). \(title)**")
            if !snippetTruncated.isEmpty {
                lines.append("")
                lines.append(snippetTruncated)
            }
            lines.append("")
        }
        if results.count == 5 {
            lines.append("---")
            lines.append("_Showing first 5 hits. Open the vault search panel for the full set._")
        }
        state.append(.artifact(Artifact(
            kind: .markdown,
            title: "Search '\(cmd.query)'",
            content: lines.joined(separator: "\n"),
            schemaName: "hermes.search"
        )))
    }

    private func renderConfigShowInline() {
        let isAppStoreBuild: Bool = {
            #if EPISTEMOS_MAS
            return true
            #else
            return false
            #endif
        }()
        let profile = isAppStoreBuild ? "AppStore (Core only)" : "Pro / Developer ID"
        let runID = state.sessionRunID.isEmpty ? "—" : String(state.sessionRunID.suffix(8))
        let yaml = """
        profile:           \(yamlEscape(profile))
        model:             \(yamlEscape(inference.preferredChatModelSelection.displayName))
        operating_mode:    \(yamlEscape(operatingMode().displayName))
        incognito:         \(chat.isIncognito ? "true" : "false")
        rrf_fusion:        \(RRFFusionFlags.isEnabled ? "on" : "off")
        expert_session:    hermes-expert/\(runID)
        history_depth:     \(state.history.count)
        transcript_length: \(state.transcript.count)
        """
        state.append(.artifact(Artifact(
            kind: .yaml,
            title: "Config",
            language: "yaml",
            content: yaml,
            schemaName: "hermes.config"
        )))
    }

    /// YAML escape: wrap in double-quotes if the value contains anything
    /// YAML-significant (`: { } [ ] , & * # ? | - < > = ! % @ \``)
    /// or starts with whitespace, or is exactly a YAML reserved keyword
    /// (`true`/`false`/`null`/`~`/etc.). Otherwise return as-is.
    private func yamlEscape(_ value: String) -> String {
        if value.isEmpty { return "\"\"" }
        let reserved: Set<String> = ["true", "false", "null", "~", "yes", "no", "on", "off"]
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != value || reserved.contains(trimmed.lowercased()) {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
        }
        let unsafe: Set<Character> = [":", "{", "}", "[", "]", ",", "&", "*",
                                      "#", "?", "|", "<", ">", "=", "!", "%", "@", "`", "\""]
        if value.contains(where: { unsafe.contains($0) }) {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
        }
        return value
    }

    /// Persona subsystem isn't a runtime mutable state on the main
    /// branch yet (PersonaState is canonical-target work). Surface a
    /// useful read of what we know rather than a generic echo.
    private func renderPersonaInline(_ cmd: HermesPersonaCommand) {
        switch cmd.action {
        case .showCurrent:
            state.append(.init(kind: .systemResponse,
                text: "current persona: default (Hermes runtime)"))
            state.append(.init(kind: .info,
                text: "active model carries persona via prompt; explicit PersonaState is canonical-target"))
        case .list:
            state.append(.init(kind: .systemResponse, text: "── personas (built-in) ──"))
            state.append(.init(kind: .info, text: "default      Hermes runtime baseline"))
            state.append(.init(kind: .info, text: "researcher   investigative tone, deep citations"))
            state.append(.init(kind: .info, text: "engineer     direct, code-first answers"))
            state.append(.init(kind: .info, text: "(roadmap: user-defined personas via /persona create)"))
        case .switchTo(let name):
            state.append(.init(kind: .info,
                text: "persona switch '\(name)': queued (PersonaState canonical-target)"))
        case .create(let name):
            state.append(.init(kind: .info,
                text: "persona create '\(name)': PersonaState not yet runtime-mutable"))
        case .edit(let name):
            state.append(.init(kind: .info,
                text: "persona edit '\(name)': PersonaState not yet runtime-mutable"))
        case .delete(let name):
            state.append(.init(kind: .info,
                text: "persona delete '\(name)': PersonaState not yet runtime-mutable"))
        case .export(let name):
            state.append(.init(kind: .info,
                text: "persona export '\(name)': PersonaState not yet runtime-mutable"))
        case .importFrom(let path):
            state.append(.init(kind: .info,
                text: "persona import '\(path)': PersonaState not yet runtime-mutable"))
        case .info(let name):
            state.append(.init(kind: .info,
                text: "persona info '\(name)': built-in personas listed via /persona list"))
        }
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
            // Markdown table — auto-rendered with copy + collapse via
            // ArtifactBlockView. Beats six inline echo rows.
            var lines: [String] = []
            lines.append("# Available Models")
            lines.append("")
            lines.append("**Local MLX** (in-process)")
            lines.append("- preferred: `\(inference.preferredLocalTextModelID)`")
            lines.append("")
            lines.append("**Cloud** (first 8 of \(CloudTextModelID.allCases.count))")
            for id in CloudTextModelID.allCases.prefix(8) {
                lines.append("- `\(id.rawValue)`")
            }
            if CloudTextModelID.allCases.count > 8 {
                lines.append("")
                lines.append("_\(CloudTextModelID.allCases.count - 8) more available — see Settings → Models_")
            }
            state.append(.artifact(Artifact(
                kind: .markdown,
                title: "Available Models",
                content: lines.joined(separator: "\n"),
                schemaName: "hermes.model.list"
            )))

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
