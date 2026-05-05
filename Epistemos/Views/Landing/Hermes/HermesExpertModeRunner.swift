import Foundation
import OSLog
import SwiftUI

/// Sovereign Gate category for Hermes Expert Mode approval-gated
/// commands. Single-owner discipline — this category is only used by
/// the runner; never duplicate it elsewhere.
extension SovereignGateCategory {
    static let hermesExpertCommand = SovereignGateCategory(rawValue: "hermes_expert_command")
}

// CANON-COMPLIANT 2026-05-04 (Stage A.4 / GenUI G.3 priority 1):
// Structured Hermes Expert Mode command output routes through
// `GenUIPayload` + `GenUIDispatcher`. Terse command echoes may remain
// inline transcript rows; new rich command output must use typed payloads.

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
///   `Epistemos/Sovereign/SovereignGate.swift` — single biometric context
///   owner per doctrine §A.7. NEVER duplicates local auth calls.
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
    ///   direct Rust Hermes runtime
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

        // Bare prompt (no slash): treat as /ask on the Rust Hermes runtime.
        if !trimmed.hasPrefix("/") {
            recordSubmissionStart(toolName: "hermes_expert.ask",
                                  args: ["prompt": String(trimmed.prefix(120))])
            await runAskThroughRustRuntime(trimmed)
            recordSubmissionCompleted(toolName: "hermes_expert.ask",
                                      result: "rust_runtime_dispatched")
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
        // Routes through the canonical SovereignGate (single biometric context
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
                await dispatch(parsed, raw: trimmed)
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

        await dispatch(parsed, raw: trimmed)
        recordSubmissionCompleted(toolName: toolName, result: "dispatched")
    }

    // MARK: - Dispatch routes

    private func dispatch(_ command: HermesParsedCommand, raw: String) async {
        switch command {
        case .ask(let question):
            await runAskThroughRustRuntime(question)

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
        // Stage A.4 / GenUI G.3: rich help output is a typed payload
        // rendered by the canonical dispatcher.
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

        state.append(.payload(.markdownCard(
            title: "Hermes Parity",
            lines.joined(separator: "\n")
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
        // GenUI G.3 priority 1 (FIRST MIGRATION) — routes through the
        // canonical GenUIDispatcher (Stage A.3 deliverable). The
        // payload is a typed `GenUIPayload` with `schema: .keyValueTable`;
        // the dispatcher renders it via KeyValueTableGenUIView. This
        // is the doctrinally-correct path per
        // `COGNITIVE_GENUI_DOCTRINE_2026_05_03.md`.
        //
        // The other six originally Artifact-routed commands now follow
        // this same typed-payload pattern.
        let model = inference.preferredChatModelSelection.displayName
        let opMode = operatingMode().displayName
        let panel = ui.activePanel.rawValue
        let runID = state.sessionRunID.isEmpty ? "—" : String(state.sessionRunID.suffix(8))
        let transcriptCount = state.transcript.count

        state.append(.payload(.keyValueTable(
            title: "Status",
            [
                ("model",      model),
                ("mode",       opMode),
                ("panel",      panel),
                ("incognito",  chat.isIncognito ? "yes" : "no"),
                ("session",    "hermes-expert/\(runID)"),
                ("transcript", "\(transcriptCount) entries"),
            ]
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
        state.append(.payload(.keyValueTable(
            title: "Tokens",
            [
                ("model", model),
                ("context_cap", estimatedContext),
                ("live_panel", "opening (Session Intelligence)"),
            ]
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
        state.append(.payload(.keyValueTable(
            title: "Cost",
            [
                ("model", model),
                ("surface", surface),
                ("live_panel", "opening (Session Intelligence)"),
            ]
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
        let rows: [[String]] = results.enumerated().map { idx, hit in
            let title = hit.title.isEmpty ? "(untitled)" : hit.title
            let snippet = hit.snippet
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let snippetTruncated = snippet.count > 240
                ? String(snippet.prefix(240)) + "…"
                : snippet
            return ["\(idx + 1)", title, snippetTruncated]
        }
        state.append(.payload(.searchResults(query: cmd.query, rows: rows)))
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
        state.append(.payload(.keyValueTable(
            title: "Config",
            [
                ("profile", profile),
                ("model", inference.preferredChatModelSelection.displayName),
                ("operating_mode", operatingMode().displayName),
                ("incognito", chat.isIncognito ? "true" : "false"),
                ("rrf_fusion", RRFFusionFlags.isEnabled ? "on" : "off"),
                ("expert_session", "hermes-expert/\(runID)"),
                ("history_depth", "\(state.history.count)"),
                ("transcript_length", "\(state.transcript.count)"),
            ]
        )))
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
            var rows: [[String]] = [
                ["Local MLX", inference.preferredLocalTextModelID, "in-process"],
            ]
            for id in CloudTextModelID.allCases.prefix(8) {
                rows.append(["Cloud", id.rawValue, "Hermes Gateway"])
            }
            if CloudTextModelID.allCases.count > 8 {
                rows.append(["Cloud", "\(CloudTextModelID.allCases.count - 8) more", "Settings → Models"])
            }
            state.append(.payload(.capabilityList(
                title: "Available Models",
                headers: ["Class", "Model", "Route"],
                rows: rows
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

    // MARK: - Rust runtime

    private static let rustAskSystemPrompt = """
    You are Hermes inside Epistemos Expert Mode. Answer the user's prompt directly, \
    keep local provenance and MAS/Core boundaries intact, and do not request write, \
    shell, subprocess, cloud-orchestration, or destructive tools on this read-only ask path.
    """

    private func runAskThroughRustRuntime(_ prompt: String) async {
        state.dispatching = true
        defer { state.dispatching = false }

        let sessionId = state.sessionRunID.isEmpty
            ? "hermes-expert-\(UUID().uuidString)"
            : state.sessionRunID
        let vaultPath = vaultSync.vaultURL?.path ?? FileManager.default.temporaryDirectory.path
        let mode = operatingMode()
        let providerName = Self.rustProviderName(
            for: inference.preferredChatModelSelection,
            fallback: inference.activeAIProvider
        )
        let toolConfig = ToolConfig(
            vaultPath: vaultPath,
            enableBash: false,
            enableWebSearch: false,
            toolTier: "chat_lite",
            allowedToolNames: []
        )
        let agentConfig = AgentConfigFFI(
            maxTurns: 4,
            maxOutputTokens: 4096,
            contextThreshold: 32_000,
            enableThinking: mode.capturesReasoningTrace,
            effort: Self.rustEffort(
                for: mode,
                tier: inference.sanitizedReasoningTier(inference.chatReasoningTier, for: mode)
            ),
            systemPrompt: Self.rustAskSystemPrompt,
            autoApproveReads: false,
            autoApproveWrites: false,
            promptMode: "general",
            maxCostUsd: nil
        )

        var delegateBox: StreamingDelegate?
        var answer = ""
        state.append(.init(kind: .info, text: "→ running Hermes Rust runtime…"))

        let stream = AsyncStream<AgentStreamEvent>(bufferingPolicy: .bufferingNewest(256)) { continuation in
            let delegate = StreamingDelegate(continuation: continuation)
            delegateBox = delegate
            continuation.onTermination = { @Sendable _ in
                cancelAgentSession(sessionId: sessionId)
            }
            Task.detached {
                do {
                    _ = try await runAgentSession(
                        sessionId: sessionId,
                        objective: prompt,
                        providerName: providerName,
                        toolConfig: toolConfig,
                        agentConfig: agentConfig,
                        delegate: delegate
                    )
                    continuation.finish()
                } catch {
                    continuation.yield(.error(AgentRuntimeError(message: error.localizedDescription)))
                    continuation.finish()
                }
            }
        }

        for await event in stream {
            switch event {
            case .thinkingDelta:
                break
            case .textDelta(let delta):
                answer += delta
            case .toolInputStreaming:
                break
            case .toolStarted(_, let name, _):
                state.append(.init(kind: .info, text: "tool started: \(name)"))
            case .toolCompleted(_, _, let isError):
                if isError {
                    state.append(.init(kind: .error, text: "tool failed on Rust runtime"))
                }
            case .subagentSpawned(_, let role):
                state.append(.init(kind: .info, text: "subagent spawned: \(role)"))
            case .permissionRequired(let request):
                let approved = !request.requiresHumanApproval
                delegateBox?.resolvePermission(permissionId: request.id, approved: approved)
                let message = approved
                    ? "read-only tool approved: \(request.toolName)"
                    : "tool permission denied by Expert Mode ask policy: \(request.toolName)"
                state.append(.init(kind: approved ? .info : .error, text: message))
            case .contextCompacting(let tokens):
                state.append(.init(kind: .info, text: "context compacting at \(tokens) tokens"))
            case .contextCompacted(let messageCount):
                state.append(.init(kind: .info, text: "context compacted to \(messageCount) messages"))
            case .turnStarted:
                break
            case .complete(let stopReason, let inputTokens, let outputTokens, _):
                state.append(.init(
                    kind: .info,
                    text: "runtime complete (\(stopReason), in \(inputTokens), out \(outputTokens))"
                ))
            case .error(let error):
                state.append(.init(kind: .error, text: error.message))
                state.lastErrorMessage = error.message
            }
        }

        let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAnswer.isEmpty {
            state.append(.init(kind: .systemResponse, text: trimmedAnswer))
        }
    }

    private static func rustEffort(
        for mode: EpistemosOperatingMode,
        tier: ChatReasoningTier
    ) -> String {
        switch tier {
        case .off, .low:
            return "low"
        case .medium:
            return mode == .fast ? "low" : "medium"
        case .high:
            return "high"
        case .heavy:
            return "max"
        }
    }

    private static func rustProviderName(
        for selection: ChatModelSelection,
        fallback provider: AIProviderSelection
    ) -> String {
        switch selection {
        case .appleIntelligence:
            return rustProviderName(for: provider)
        case .localMLX:
            return "ollama"
        case .cloud(let model):
            switch model {
            case .anthropicClaudeOpus47, .anthropicClaudeOpus41, .anthropicClaudeOpus4:
                return "claude_opus"
            case .anthropicClaudeHaiku35:
                return "claude_haiku"
            case .anthropicClaudeSonnet46, .anthropicClaudeSonnet4, .anthropicClaudeSonnet37:
                return "claude_sonnet"
            case .googleGemini25Pro, .googleGemini3ProPreview, .googleGemini31ProPreview:
                return "gemini_pro"
            case .googleGemini25Flash, .googleGemini3FlashPreview:
                return "gemini_flash"
            case .openAIGPT54Mini, .openAIGPT54Nano:
                return "openai_gpt4o_mini"
            case .openAIO3Mini, .openAIO3:
                return "openai_o3_mini"
            case .openAIGPT54, .openAIGPT52, .openAIGPT41, .openAIGPT41Mini:
                return "openai_gpt4o"
            case .zaiGLM5, .zaiGLM45Flash:
                return "zai"
            case .kimiK25, .kimiK2Thinking, .kimiK2TurboPreview:
                return "kimi_coding"
            case .minimaxM25, .minimaxM25HighSpeed, .minimaxM21:
                return "minimax"
            case .deepseekChat, .deepseekReasoner:
                return "deepseek"
            }
        }
    }

    private static func rustProviderName(for provider: AIProviderSelection) -> String {
        switch provider {
        case .anthropic:
            return "claude_sonnet"
        case .openAI:
            return "openai_gpt4o"
        case .google:
            return "gemini_flash"
        case .zai:
            return "zai"
        case .kimi:
            return "kimi_coding"
        case .minimax:
            return "minimax"
        case .deepseek:
            return "deepseek"
        case .localOnly:
            return "ollama"
        }
    }

    // MARK: - Handoffs

    private func handoffAsAsk(_ prompt: String) {
        // Legacy non-ask commands still hand off until their typed Rust
        // command routes land. `/ask` and bare prompts use the direct
        // Rust runtime path above.
        onDelegateToMainChat(prompt)
    }

    // MARK: - Sovereign Gate reason strings

    /// Human-readable reason shown in the biometric prompt.
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
