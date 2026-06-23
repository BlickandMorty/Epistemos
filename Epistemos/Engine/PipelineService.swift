import Foundation
import Synchronization
import os

private final class FinishOnce: Sendable {
    private let done = Mutex(false)

    nonisolated func tryFinish() -> Bool {
        done.withLock { done in
            guard !done else { return false }
            done = true
            return true
        }
    }
}

nonisolated enum PipelineError: LocalizedError {
    case noLLMService
    case analysisFailure(String)

    var errorDescription: String? {
        switch self {
        case .noLLMService: "No usable local model is available. Open Settings to install or select one."
        case .analysisFailure(let msg): msg
        }
    }
}

/// Structured classification of chat-surface errors. The UI reads the
/// kind to decide what affordance to show — generic-message, retry-with-
/// countdown, deep-link to Settings, etc. — instead of pattern-matching
/// on a free-form String. Raw catch paths still accept `Error` and get
/// mapped through `UserFacingChatError.classify(_:)`.
nonisolated enum UserFacingChatErrorKind: String, Codable, Equatable, Sendable, CaseIterable {
    /// 401 / bad API key / OAuth token invalid. UI should deep-link to
    /// Settings → AI so the user can re-authenticate without hunting.
    case authFailure
    /// 429 / rate limited. UI should suggest waiting and offer an
    /// escape hatch to switch models.
    case rateLimited
    /// Connectivity / DNS / VPN. UI can suggest checking network.
    case providerUnreachable
    /// Timeout. UI can suggest retry or switching to a faster model.
    case timedOut
    /// Context-window overflow. UI can suggest starting a new chat.
    case contextOverflow
    /// The model / runtime isn't installed or ready (local path only).
    /// UI deep-links to Settings → Models.
    case modelNotReady
    /// User hit Stop. UI treats as a silent "stopped" message, not red.
    case cancelled
    /// Anything else — treated as a generic "something went wrong".
    case generic
}

/// Converts infrastructure errors into copy suitable for the chat error
/// bubble. Users should never see an opaque stack-level message — the chat
/// surface is a user experience, not a log viewer.
nonisolated enum UserFacingChatError {
    static func classify(_ error: Error) -> UserFacingChatErrorKind {
        switch error {
        case PipelineError.noLLMService,
             LocalInferenceRoutingError.modelRequired,
             LocalInferenceRoutingError.runtimeUnavailable:
            return .modelNotReady
        case is CancellationError:
            return .cancelled
        default:
            break
        }

        let lower = (error as NSError).localizedDescription.lowercased()
        if lower.contains("unauthorized") || lower.contains("api key") || lower.contains("401") {
            return .authFailure
        }
        if lower.contains("rate limit") || lower.contains("429") || lower.contains("too many requests") {
            return .rateLimited
        }
        if lower.contains("network") || lower.contains("offline") || lower.contains("internet") || lower.contains("connection") {
            return .providerUnreachable
        }
        if lower.contains("timed out") || lower.contains("timeout") {
            return .timedOut
        }
        if lower.contains("context length") || lower.contains("too long") || (lower.contains("token") && lower.contains("limit")) {
            return .contextOverflow
        }
        // Osaurus act-engine "no usable model" failures → the actionable model-not-ready
        // message (owner 2026-06-22 P0-A "it's not working": these MUST be diagnosable,
        // not a raw technical string). Matched by error CONTENT so PipelineService stays
        // decoupled from OsaurusCore's error types and the App Store target needs no
        // OsaurusCore import. Strings are the canonical errorDescriptions of:
        //   EpistemosOsaurusModelProvider.ProviderError.modelNotPrepared,
        //   EpistemosModelBridgeError.noProvider, CoreModelError.modelUnavailable.
        if lower.contains("not prepared")
            || lower.contains("model provider is registered")
            || lower.contains("no model id")
            || (lower.contains("core model") && lower.contains("not available")) {
            return .modelNotReady
        }
        return .generic
    }

    /// Default copy for each error kind — used by the String-returning
    /// `message(from:)` below and by views that want a fallback label.
    static func message(for kind: UserFacingChatErrorKind, fallback: String = "") -> String {
        switch kind {
        case .modelNotReady:
            return "No model is ready to answer yet. Open Settings → Models to install a local model, sign in to a cloud provider, or enable Apple Intelligence on macOS 26+."
        case .authFailure:
            return "The provider rejected your credentials. Open Settings → AI to re-authenticate."
        case .rateLimited:
            return "The provider is rate-limiting requests. Wait a moment and try again, or switch to a different model in the picker."
        case .providerUnreachable:
            return "Couldn't reach the provider. Check your internet connection and try again."
        case .timedOut:
            return "The request timed out. Try again, or pick a faster model."
        case .contextOverflow:
            return "This conversation is longer than the model can hold. Start a new chat or switch to a model with a larger context window."
        case .cancelled:
            return "Stopped."
        case .generic:
            return fallback.isEmpty ? "Something went wrong. Please try again." : fallback
        }
    }

    static func message(from error: Error) -> String {
        // PipelineError.analysisFailure carries its own message — preserve
        // it verbatim instead of replacing with a generic classification.
        if case let PipelineError.analysisFailure(msg) = error {
            return msg
        }
        let underlying = (error as NSError).localizedDescription
        let normalizedUnderlying = underlying.lowercased()
        if normalizedUnderlying == BackendRuntimeContractError.policyDenied.rawValue
            || normalizedUnderlying.contains("policy_denied")
            || normalizedUnderlying.contains("policy denied") {
            return "This turn was blocked because tools or restricted actions were not available here. Try Tools/Agent mode for tool use, or ask again in plain chat."
        }
        let kind = classify(error)
        if kind == .generic {
            return message(for: .generic, fallback: underlying)
        }
        return message(for: kind)
    }
}

@MainActor
final class PipelineService {
    private let pipelineState: PipelineState
    private let llmService: any LLMClientProtocol
    private let triageService: TriageService
    private let inference: InferenceState
    private let eventBus: EventBus
    private let localModelClient: (any LocalConfigurableLLMClient)?
    private let constrainedDecoding: ConstrainedDecodingService?
    private let vaultPathProvider: @MainActor () -> String?
    private let activeCompanionInstructionProvider: @MainActor () -> String?
    private let skillNamesProvider: @MainActor () -> [String]
    /// L1187 — deterministic vault-ranking answer provider. Given the user's query it returns a
    /// ranked title/path/reason answer, or nil when the query isn't a vault-ranking query / has no
    /// results. nil provider = feature off (no intercept). Gated additionally by
    /// `VaultBestEssayResponder.isEnabled` so the path is doubly default-OFF.
    private let vaultRankingSearchProvider: (@MainActor (String) -> String?)?
    private var pipelineTask: Task<Void, Never>?
    private var activeRunID: UUID?

    init(
        pipelineState: PipelineState,
        llmService: any LLMClientProtocol,
        triageService: TriageService,
        inference: InferenceState,
        eventBus: EventBus,
        localModelClient: (any LocalConfigurableLLMClient)? = nil,
        constrainedDecoding: ConstrainedDecodingService? = nil,
        vaultPathProvider: @escaping @MainActor () -> String? = { nil },
        activeCompanionInstructionProvider: @escaping @MainActor () -> String? = { nil },
        skillNamesProvider: @escaping @MainActor () -> [String] = { [] },
        vaultRankingSearchProvider: (@MainActor (String) -> String?)? = nil
    ) {
        self.pipelineState = pipelineState
        self.llmService = llmService
        self.triageService = triageService
        self.inference = inference
        self.eventBus = eventBus
        self.localModelClient = localModelClient
        self.constrainedDecoding = constrainedDecoding
        self.vaultPathProvider = vaultPathProvider
        self.activeCompanionInstructionProvider = activeCompanionInstructionProvider
        self.skillNamesProvider = skillNamesProvider
        self.vaultRankingSearchProvider = vaultRankingSearchProvider
    }

    func run(
        query: String,
        mode: InferenceMode,
        notesContext: String? = nil,
        conversationHistory: String? = nil,
        operatingMode: EpistemosOperatingMode = .fast,
        executionPlan: OverseerComplexityRouter.ExecutionPlan? = nil,
        toolEventHandler: (@MainActor @Sendable (PipelineToolEvent) -> Void)? = nil,
        toolApprovalHandler: (@MainActor @Sendable (AgentPermissionRequest) async -> Bool)? = nil,
        modelInputCaptureHandler: (@MainActor @Sendable (CapturedModelInput) -> Void)? = nil
    ) -> AsyncThrowingStream<PipelineEvent, Error> {
        let _ = (mode, llmService, inference, eventBus)
        let runID = UUID()
        supersedeActiveRun(with: runID)

        let finisher = FinishOnce()

        return AsyncThrowingStream(
            bufferingPolicy: .bufferingNewest(StreamingBufferPolicy.textLimit)
        ) { (continuation: AsyncThrowingStream<PipelineEvent, Error>.Continuation) in
            let mainTask = Task { @MainActor [weak self] in
                guard let self else {
                    if finisher.tryFinish() { continuation.finish() }
                    return
                }
                guard activeRunID == runID, !Task.isCancelled else {
                    if finisher.tryFinish() { continuation.finish() }
                    return
                }

                do {
                    pipelineState.startProcessing()

                    // L1187 — deterministic vault-ranking fast-path (flag-gated, default OFF). For a
                    // recognised NL vault query ("the best essay in my vault"), answer directly from
                    // vault search with a ranked title/path/reason list instead of a generic model
                    // reply. OFF / non-matching / no-results → byte-identical fall-through below.
                    if VaultBestEssayResponder.isEnabled,
                       VaultBestEssayResponder.isVaultRankingQuery(query),
                       let vaultRankingSearchProvider,
                       let rankedAnswer = vaultRankingSearchProvider(query),
                       !rankedAnswer.isEmpty {
                        continuation.yield(.textDelta(rankedAnswer))
                        continuation.yield(
                            .completed(
                                DualMessage(
                                    rawAnalysis: rankedAnswer,
                                    uncertaintyTags: [],
                                    modelVsDataFlags: []
                                ),
                                nil
                            )
                        )
                        completeActiveRunIfNeeded(runID)
                        if finisher.tryFinish() { continuation.finish() }
                        return
                    }

                    let effectiveChatSelection = inference.effectiveChatSurfaceSelection(
                        for: operatingMode
                    )

                    let useToolLoop = shouldUseToolLoop(
                        query: query,
                        operatingMode: operatingMode,
                        executionPlan: executionPlan,
                        effectiveChatSelection: effectiveChatSelection
                    )
                    let isLocalModelSelected: Bool = {
                        if case .localMLX = effectiveChatSelection { return true }
                        return false
                    }()
                    var emittedVisibleText = ""

                    if useToolLoop,
                       isLocalModelSelected,
                       let localClient = localModelClient {
                        let vaultPath = resolvedManagedToolRuntimeVaultPath()
                        var streamedToolLoopText = ""
                        // Tool-enabled local path: LocalAgentLoop handles
                        // multi-turn tool execution via the Rust FFI.
                        let toolLoopOutput = try await runToolLoop(
                            runID: runID,
                            query: query,
                            notesContext: notesContext,
                            conversationHistory: conversationHistory,
                            operatingMode: operatingMode,
                            executionPlan: executionPlan,
                            vaultPath: vaultPath,
                            localClient: localClient,
                            toolEventHandler: toolEventHandler,
                            toolApprovalHandler: toolApprovalHandler,
                            modelInputCaptureHandler: modelInputCaptureHandler,
                            onToken: { token in
                                streamedToolLoopText += token
                                continuation.yield(.textDelta(token))
                            }
                        )
                        let reconciledToolLoopOutput = Self.reconcileToolLoopVisibleText(
                            streamedText: streamedToolLoopText,
                            finalOutput: toolLoopOutput
                        )
                        emittedVisibleText = reconciledToolLoopOutput.completedText
                        if let missingDelta = reconciledToolLoopOutput.missingDelta {
                            continuation.yield(.textDelta(missingDelta))
                        }
                    } else {
                        // Legacy direct-stream path (cloud models in non-agent
                        // mode, or when localClient / vault aren't available).
                        let directStream = generateDirectStream(
                            query: query,
                            notesContext: notesContext,
                            conversationHistory: conversationHistory,
                            operatingMode: operatingMode,
                            executionPlan: executionPlan,
                            modelInputCaptureHandler: modelInputCaptureHandler,
                            reasoningEventHandler: { delta in
                                continuation.yield(.thinkingDelta(delta))
                            },
                            toolEventHandler: toolEventHandler
                        )
                        for try await token in directStream {
                            emittedVisibleText += token
                            continuation.yield(.textDelta(token))
                        }
                    }

                    guard !Task.isCancelled else {
                        completeActiveRunIfNeeded(runID)
                        if finisher.tryFinish() { continuation.finish() }
                        return
                    }

                    continuation.yield(
                        .completed(
                            DualMessage(
                                rawAnalysis: emittedVisibleText,
                                uncertaintyTags: [],
                                modelVsDataFlags: []
                            ),
                            nil
                        )
                    )
                    completeActiveRunIfNeeded(runID)
                    if finisher.tryFinish() { continuation.finish() }
                } catch is CancellationError {
                    completeActiveRunIfNeeded(runID)
                    if finisher.tryFinish() { continuation.finish() }
                } catch {
                    failActiveRunIfNeeded(runID, error: error.localizedDescription)
                    continuation.yield(.error(UserFacingChatError.message(from: error)))
                    if finisher.tryFinish() { continuation.finish() }
                }
            }

            pipelineTask = mainTask
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.cancelActiveRunIfNeeded(runID)
                }
            }
        }
    }

    /// Decide whether the current turn should route through `LocalAgentLoop`
    /// with tier-filtered tools. Fast / Thinking / Pro all qualify when a
    /// local model client is wired. Agent mode goes through the Rust
    /// agent loop instead (handled by ChatCoordinator, not here).
    private func shouldUseToolLoop(
        query: String,
        operatingMode: EpistemosOperatingMode,
        executionPlan: OverseerComplexityRouter.ExecutionPlan?,
        effectiveChatSelection: ChatModelSelection
    ) -> Bool {
        guard case let .localMLX(modelID) = effectiveChatSelection else {
            return false
        }

        if let executionPlan {
            switch executionPlan.route {
            case .managedAgentSession:
                return false
            case .localOnly:
                return false
            case .overseerLocalExecution:
                guard executionPlan.allowsToolExecution else { return false }
                // The chat model drives the loop directly only when it is
                // itself agent-capable. A non-agent selection (e.g. a GGUF
                // Gemma) must be backed by the hidden agent tier — but ONLY if
                // an agent-capable model actually fits the current memory
                // budget. If nothing fits, NEVER swap to a model that will OOM
                // (the user-reported "routed to Qwen again" bug). Returning
                // false here degrades the caller to a direct stream on the
                // selected model, which answers from the inlined context.
                if let model = LocalTextModelID(rawValue: modelID),
                   model.canRunLocalAgentLoop {
                    return true
                }
                return inference.fittingLocalAgentTextModelID != nil
            }
        }

        // Per user 2026-05-11: basic chat needs read/search/write tools
        // for notes — the previous "keep standard local chat simple"
        // policy meant users typing "find my note about X" or
        // "@MyNote what changed?" got toolless chat that hallucinated
        // instead of calling vault.search / vault.read. Now local Fast
        // / Thinking opts in to the ChatLite tool loop when the model
        // is large enough to drive it (canRunLocalAgentLoop). The
        // ChatLite tier is read-only by default; `vault.write` still
        // gates through AgentAuthority approval + R5 capability so MAS
        // safety is preserved.
        //
        // Cloud Fast/Thinking + AFM are handled at the ChatCoordinator
        // layer via runCommandCenterRustAgentPath — they don't flow
        // through this Pipeline branch.
        if let model = LocalTextModelID(rawValue: modelID),
           model.canRunLocalAgentLoop {
            // AUTO-ROUTE v0 (EPISTEMOS_AUTO_TOOL_ROUTE_V0, OFF=unchanged): for a
            // plain query (no execution plan) the deterministic Rust tool-need
            // detector decides loop-vs-direct, so "find my note about X" keeps the
            // tool loop (vault.search) while pure chat ("write a haiku") direct-
            // streams. The detector + the candidate-tool load run ONLY when the flag
            // is armed; a nil verdict (flag off / FFI down / parse fail) preserves
            // today's "a loop-capable model always loops" behaviour.
            if Self.autoToolRouteArmed {
                let tier = Self.localToolTier(for: operatingMode, executionPlan: nil)
                let candidateTools = ToolTierBridge(
                    vaultPath: resolvedManagedToolRuntimeVaultPath(),
                    tier: tier
                ).loadTools()
                if let needsTools = Self.autoRouteNeedsTools(
                    query: query,
                    tools: candidateTools
                ) {
                    return needsTools
                }
            }
            return true
        }
        // SS-H PART 2: a non-agent local model (e.g. a GGUF Gemma) with no execution
        // plan used to ALWAYS degrade to a tool-less stream here. Now, when the query
        // actually needs tools AND an agent-capable model fits memory, route to the
        // tool loop (backed by the fitting agent tier) instead — symmetric with the
        // overseerLocalExecution branch above. NEVER swaps to a model that OOMs:
        // `fittingLocalAgentTextModelID` only returns a model that fits the budget.
        // When it stays a direct stream, PART 1 still injects the skills CATALOG, so
        // nothing is hidden from the model.
        if Self.autoToolRouteArmed, inference.fittingLocalAgentTextModelID != nil {
            let tier = Self.localToolTier(for: operatingMode, executionPlan: nil)
            let candidateTools = ToolTierBridge(
                vaultPath: resolvedManagedToolRuntimeVaultPath(),
                tier: tier
            ).loadTools()
            if Self.autoRouteNeedsTools(query: query, tools: candidateTools) == true {
                return true
            }
        }
        return false
    }

    /// SS-H keystone: a read-only CATALOG of the ChatLite skills/tools the model
    /// could use, for injection into the DIRECT (tool-loop-less) system prompt so a
    /// small local model that can't drive the tool loop still SEES what's available
    /// (skills as CONTEXT). Names + one-line descriptions only — not the tool-call
    /// schemas — so the model is aware without being prompted to emit calls it can't
    /// run. nil when no tools resolve (e.g. FFI down) → the prompt is unchanged.
    private func chatLiteSkillsCatalogBlock(operatingMode: EpistemosOperatingMode) -> String? {
        let tier = Self.localToolTier(for: operatingMode, executionPlan: nil)
        let tools = ToolTierBridge(
            vaultPath: resolvedManagedToolRuntimeVaultPath(),
            tier: tier
        ).loadTools()
        guard !tools.isEmpty else { return nil }
        let lines = tools.prefix(24).map { "• \($0.name) — \($0.description)" }
        return "Skills available to Epistemos (a larger local model or a cloud model "
            + "can run these for you on request):\n" + lines.joined(separator: "\n")
    }

    /// AUTO-ROUTE v0 flag (`EPISTEMOS_AUTO_TOOL_ROUTE_V0`). FLIPPED ON by default
    /// 2026-06-19 (owner: plain queries should route to tools) — env `0` disables.
    /// A plain local query consults the deterministic Rust tool-need detector so
    /// tool-needing queries route to the loop and pure chat does not. The Rust FFI
    /// is now also ON by default, so the two sides agree.
    nonisolated static var autoToolRouteArmed: Bool {
        ProcessInfo.processInfo.environment["EPISTEMOS_AUTO_TOOL_ROUTE_V0"] != "0"
    }

    /// Build the detector's candidate catalog JSON (`[{"name","description",
    /// "keywords"}]`, matching Rust `PreflightToolInput`) from the tier's tools.
    /// Returns nil for an empty catalog (the caller keeps its existing decision).
    /// Pure — unit-testable without the FFI / env flag.
    nonisolated static func autoRouteCandidatesJSON(
        tools: [OmegaToolDefinition]
    ) -> String? {
        guard !tools.isEmpty else { return nil }
        let candidates: [[String: Any]] = tools.map {
            ["name": $0.name, "description": $0.description, "keywords": [String]()]
        }
        guard JSONSerialization.isValidJSONObject(candidates),
              let data = try? JSONSerialization.data(withJSONObject: candidates),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return json
    }

    /// Parse the detector envelope `{"needs_tools":<bool>,"tools":[…]}` → the bool,
    /// or nil when the payload is malformed (the caller keeps its existing decision).
    /// Pure — unit-testable without the FFI / env flag.
    nonisolated static func parseAutoRouteVerdict(_ raw: String) -> Bool? {
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let needsTools = obj["needs_tools"] as? Bool else {
            return nil
        }
        return needsTools
    }

    /// Consult the deterministic Rust tool-need detector for `query` against `tools`.
    /// Returns the verdict, or nil when the catalog is empty / the FFI is unavailable
    /// / the payload is malformed (the caller keeps its existing decision).
    nonisolated static func autoRouteNeedsTools(
        query: String,
        tools: [OmegaToolDefinition]
    ) -> Bool? {
        guard let candidatesJSON = autoRouteCandidatesJSON(tools: tools) else { return nil }
        #if canImport(agent_coreFFI)
        let raw = schemaAutoToolRouteJson(
            query: query,
            candidatesJson: candidatesJSON,
            max: 5
        )
        return parseAutoRouteVerdict(raw)
        #else
        return nil
        #endif
    }

    /// GGUF-Gemma grammar tool-call flag (`EPISTEMOS_GGUF_TOOL_GRAMMAR_V0`). OFF by
    /// default: the GGUF generation is unconstrained (today's behaviour). ON: a GGUF
    /// tool turn constrains llama-cli via `--json-schema` so Gemma emits a
    /// structurally valid tool call. (The Rust FFI is itself flag-gated — double
    /// gate, matching the auto-route pattern.)
    nonisolated static var ggufToolGrammarArmed: Bool {
        ProcessInfo.processInfo.environment["EPISTEMOS_GGUF_TOOL_GRAMMAR_V0"] == "1"
    }

    /// Build the GGUF dispatch candidate catalog JSON (`[{"name","description",
    /// "keywords","schema"}]`, matching Rust `PreflightToolWithSchemaInput`) from the
    /// tier's tools — like `autoRouteCandidatesJSON` but CARRYING each tool's
    /// parameter schema (parsed from `schemaJson`, falling back to an empty object
    /// schema) so `schema_gguf_tool_dispatch_json` can build the constrained
    /// `oneOf` dispatch grammar. Returns nil for an empty catalog. Pure —
    /// unit-testable without the FFI / env flag.
    nonisolated static func ggufDispatchCandidatesJSON(
        tools: [OmegaToolDefinition]
    ) -> String? {
        guard !tools.isEmpty else { return nil }
        let candidates: [[String: Any]] = tools.map { tool in
            let schemaObject: Any = {
                if let data = tool.schemaJson.data(using: .utf8),
                   let parsed = try? JSONSerialization.jsonObject(with: data),
                   parsed is [String: Any] {
                    return parsed
                }
                return ["type": "object", "properties": [String: Any](), "additionalProperties": false]
            }()
            return [
                "name": tool.name,
                "description": tool.description,
                "keywords": [String](),
                "schema": schemaObject,
            ]
        }
        guard JSONSerialization.isValidJSONObject(candidates),
              let data = try? JSONSerialization.data(withJSONObject: candidates),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return json
    }

    /// Compute the GGUF tool-dispatch JSON schema for `query` against `tools` (the
    /// `--json-schema` constraint string), or nil when the flag is off / the catalog
    /// is empty / no tool matched / the FFI is unavailable — in which case the
    /// caller runs an UNCONSTRAINED GGUF generation (today's behaviour). This is the
    /// Swift entry the GGUF tool turn calls before driving `LocalGgufRuntimeBridge`
    /// (the live-wiring of that call is the follow-on).
    nonisolated static func ggufToolDispatchSchema(
        query: String,
        tools: [OmegaToolDefinition]
    ) -> String? {
        guard ggufToolGrammarArmed else { return nil }
        guard let candidatesJSON = ggufDispatchCandidatesJSON(tools: tools) else { return nil }
        #if canImport(agent_coreFFI)
        let raw = schemaGgufToolDispatchJson(
            query: query,
            candidatesJson: candidatesJSON,
            max: 5
        )
        return raw.isEmpty ? nil : raw
        #else
        return nil
        #endif
    }

    /// Parse a GGUF Gemma's grammar-CONSTRAINED tool-call output into a dispatchable
    /// `(name, argumentsJSON)`. When the generation is constrained by the dispatch
    /// schema (`ggufToolDispatchSchema`), the model emits exactly
    /// `{"name": <tool>, "input": {…}}` (the shape of Rust
    /// `grammar::dispatch_schema_for_tools`). This turns that into the tool name +
    /// the arguments JSON the tool-execution path consumes. Returns nil for any
    /// non-conforming output (a plain text answer, no `name`, a non-object `input`)
    /// so the caller treats it as a normal text response rather than a tool call.
    /// Pure — unit-testable without the FFI / a live model.
    nonisolated static func parseGgufToolCall(
        _ raw: String
    ) -> (name: String, argumentsJSON: String)? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = obj["name"] as? String,
              !name.isEmpty else {
            return nil
        }
        // `input` is the tool's arguments object. Missing/absent → empty args (a
        // tool with no params still dispatches); a non-object input is malformed.
        let argumentsJSON: String
        if let input = obj["input"] {
            guard let inputObject = input as? [String: Any],
                  JSONSerialization.isValidJSONObject(inputObject),
                  let argData = try? JSONSerialization.data(withJSONObject: inputObject),
                  let argString = String(data: argData, encoding: .utf8) else {
                return nil
            }
            argumentsJSON = argString
        } else {
            argumentsJSON = "{}"
        }
        return (name: name, argumentsJSON: argumentsJSON)
    }

    private func resolvedManagedToolRuntimeVaultPath() -> String {
        FoundationSafety.managedToolRuntimeVaultDirectory(
            preferredVaultPath: vaultPathProvider()
        ).path
    }

    nonisolated static func reconcileToolLoopVisibleText(
        streamedText: String,
        finalOutput: String
    ) -> (completedText: String, missingDelta: String?) {
        let trimmedStreamedText = streamedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFinalOutput = finalOutput.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedStreamedText.isEmpty {
            return (
                completedText: finalOutput,
                missingDelta: trimmedFinalOutput.isEmpty ? nil : finalOutput
            )
        }

        if trimmedFinalOutput.isEmpty {
            return (completedText: streamedText, missingDelta: nil)
        }

        return (completedText: finalOutput, missingDelta: nil)
    }

    /// Tool-enabled local-model path. Builds a tier-filtered tool registry
    /// via the Rust FFI, then drives a LocalAgentLoop with the incoming
    /// query. Tokens are forwarded to the caller via `onToken`.
    private func runToolLoop(
        runID: UUID,
        query: String,
        notesContext: String?,
        conversationHistory: String?,
        operatingMode: EpistemosOperatingMode,
        executionPlan: OverseerComplexityRouter.ExecutionPlan?,
        vaultPath: String,
        localClient: any LocalConfigurableLLMClient,
        toolEventHandler: (@MainActor @Sendable (PipelineToolEvent) -> Void)?,
        toolApprovalHandler: (@MainActor @Sendable (AgentPermissionRequest) async -> Bool)?,
        modelInputCaptureHandler: (@MainActor @Sendable (CapturedModelInput) -> Void)?,
        onToken: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        let tier = Self.localToolTier(
            for: operatingMode,
            executionPlan: executionPlan
        )
        let bridge = ToolTierBridge(vaultPath: vaultPath, tier: tier)
        let tools = filteredTools(
            bridge.loadTools(),
            using: executionPlan
        )

        // If no tools loaded (bindings missing, empty registry), fall back
        // to the legacy stream so we don't break builds that haven't linked
        // the Rust FFI yet.
        if tools.isEmpty {
            Log.pipeline.warning("No tools available for tier \(tier.rawValue) — falling back to direct stream")
            var accumulated = ""
            let stream = generateDirectStream(
                query: query,
                notesContext: notesContext,
                conversationHistory: conversationHistory,
                operatingMode: operatingMode,
                executionPlan: executionPlan,
                modelInputCaptureHandler: modelInputCaptureHandler,
                toolEventHandler: toolEventHandler
            )
            for try await token in stream {
                accumulated += token
                onToken(token)
            }
            return accumulated
        }

        // Build the objective: include notes context and history inline so
        // the loop sees a single self-contained prompt. LocalAgentLoop
        // manages its own turn history internally once the loop starts.
        let hookPromptContext = await HookRegistry.shared.fireBeforePromptBuild(
            context: PromptContext(),
            runID: runID.uuidString
        )
        let objective = Self.buildPromptEnvelope(
            query: query,
            notesContext: notesContext,
            conversationHistory: conversationHistory
        )
        let additionalSystemPrompt = Self.joinSystemPromptSections(
            Self.combinedAdditionalSystemPrompt(
                base: executionPlan?.additionalSystemPrompt(),
                hookContext: hookPromptContext
            ),
            activeCompanionSystemInstruction()
        )

        let reasoningMode: LocalReasoningMode = switch operatingMode {
        case .thinking: .thinking
        case .pro:      .thinking
        default:        .fast
        }

        let effectiveChatSelection = inference.effectiveChatSurfaceSelection(for: operatingMode)
        let modelID: String? = {
            if executionPlan?.forcesLocalExecution == true {
                return inference.fittingLocalAgentTextModelID
                    ?? inference.effectiveLocalAgentTextModelID
            }
            if case .localMLX(let id) = effectiveChatSelection,
               let model = LocalTextModelID(rawValue: id),
               model.canRunLocalAgentLoop {
                return id
            }
            // Non-agent chat selection (e.g. GGUF Gemma): back it with a model
            // that ACTUALLY fits memory. `shouldUseToolLoop` already guaranteed
            // a fitting model exists before we reach here, so prefer it and
            // never fall through to a non-fitting OOM candidate.
            return inference.fittingLocalAgentTextModelID
                ?? inference.effectiveLocalAgentTextModelID
        }()
        let executorBridge = ToolTierBridge(
            vaultPath: vaultPath,
            tier: tier,
            allowedToolNames: Set(tools.map(\.name))
        )
        let toolMetadataByName = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })
        let loop = LocalAgentLoop.liveLoop(
            using: localClient,
            constrainedDecoding: constrainedDecoding,
            toolExecutor: observedToolExecutor(
                executorBridge.toolExecutor(),
                toolMetadataByName: toolMetadataByName,
                toolEventHandler: toolEventHandler,
                toolApprovalHandler: toolApprovalHandler,
                runID: runID.uuidString,
                actor: .agent(id: "pipeline-service", modelID: modelID)
            ),
            modelID: modelID,
            steeringHintsJSON: executionPlan?.steeringHintsJSON,
            defaultReasoningMode: reasoningMode
        )

        Log.pipeline.info(
            "🔧 Tool loop starting — tier=\(tier.rawValue) tools=\(tools.count) mode=\(String(describing: operatingMode))"
        )

        emitCapturedModelInput(
            systemPrompt: additionalSystemPrompt,
            userPrompt: objective,
            conversationHistory: conversationHistory,
            operatingMode: operatingMode,
            toolDefinitionsJSON: Self.encodedToolDefinitionsJSON(tools),
            handler: modelInputCaptureHandler
        )

        let result = try await loop.run(
            objective: objective,
            tools: tools,
            maxTurns: 6,
            reasoningMode: reasoningMode,
            additionalSystemPrompt: additionalSystemPrompt,
            reflexMode: true,
            onToken: { token in
                Task { @MainActor in
                    onToken(token)
                }
            }
        )
        return result
    }

    func observedToolExecutor(
        _ baseExecutor: @escaping LocalAgentToolExecutor,
        toolMetadataByName: [String: OmegaToolDefinition] = [:],
        toolEventHandler: (@MainActor @Sendable (PipelineToolEvent) -> Void)?,
        toolApprovalHandler: (@MainActor @Sendable (AgentPermissionRequest) async -> Bool)? = nil,
        runID: String? = nil,
        traceID: String? = nil,
        actor: AgentProvenanceActor = .system,
        agentProvenanceRecorder: AgentToolProvenanceRecorder? = nil
    ) -> LocalAgentToolExecutor {
        let toolProvenanceRecorder = agentProvenanceRecorder ?? AgentToolProvenanceRecorder()
        let normalizedRunID = runID?.trimmingCharacters(in: .whitespacesAndNewlines)

        return { name, argumentsJson in
            let callID = UUID().uuidString
            let startedAt = Date()
            let requestedCall = HookToolCall(id: callID, name: name, argsJson: argumentsJson)
            guard let preparedCall = await HookRegistry.shared.fireBeforeToolCall(
                call: requestedCall,
                runID: normalizedRunID
            ) else {
                let cancelledResult = LocalToolResult(
                    toolName: name,
                    resultJson: Self.toolErrorJSON("Tool '\(name)' was hook_cancelled by HookRegistry."),
                    isError: true
                )
                let elapsedSeconds = max(0, Date().timeIntervalSince(startedAt))
                let durationMs = UInt64(elapsedSeconds * 1000)
                await MainActor.run {
                    toolEventHandler?(
                        .completed(
                            id: callID,
                            name: name,
                            inputJson: argumentsJson,
                            resultJson: cancelledResult.resultJson,
                            isError: true,
                            durationMs: durationMs
                        )
                    )
                }
                return cancelledResult
            }

            let effectiveName = preparedCall.name
            let effectiveArgumentsJson = preparedCall.argsJson
            let metadata = toolMetadataByName[effectiveName]
            let permissionRequest = AgentPermissionRequest(
                id: callID,
                toolName: effectiveName,
                inputJson: effectiveArgumentsJson,
                riskLevel: Self.pipelineToolRiskLevel(for: metadata),
                description: "Local tool execution requested \(effectiveName)."
            )

            func recordAgentToolEvent(
                kind: AgentProvenanceEventKind,
                status: AgentToolEventStatus,
                resultJson: String? = nil,
                durationMs: UInt64? = nil,
                approvalID: String? = nil,
                errorMessage: String? = nil,
                metadata: [String: String] = [:]
            ) async {
                guard let normalizedRunID, !normalizedRunID.isEmpty else { return }
                await MainActor.run {
                    _ = toolProvenanceRecorder.recordToolEvent(
                        runID: normalizedRunID,
                        traceID: traceID,
                        kind: kind,
                        actor: actor,
                        toolCallID: callID,
                        toolName: effectiveName,
                        argumentsJSON: effectiveArgumentsJson,
                        resultJSON: resultJson,
                        durationMs: durationMs,
                        approvalID: approvalID,
                        status: status,
                        errorMessage: errorMessage,
                        metadata: metadata
                    )
                }
            }

            await recordAgentToolEvent(
                kind: .toolCallRequested,
                status: .requested,
                approvalID: permissionRequest.id
            )

            await MainActor.run {
                toolEventHandler?(.started(id: callID, name: effectiveName, inputJson: effectiveArgumentsJson))
            }

            let approved =
                if let toolApprovalHandler {
                    await toolApprovalHandler(permissionRequest)
                } else {
                    !permissionRequest.requiresHumanApproval
                }
            if !approved {
                let deniedResult = LocalToolResult(
                    toolName: effectiveName,
                    resultJson: Self.toolErrorJSON("Tool '\(effectiveName)' was denied by policy."),
                    isError: true
                )
                let elapsedSeconds = max(0, Date().timeIntervalSince(startedAt))
                let durationMs = UInt64(elapsedSeconds * 1000)
                await recordAgentToolEvent(
                    kind: .toolCallDenied,
                    status: .denied,
                    resultJson: deniedResult.resultJson,
                    durationMs: durationMs,
                    approvalID: permissionRequest.id,
                    errorMessage: "Tool '\(effectiveName)' was denied by policy."
                )

                await MainActor.run {
                    toolEventHandler?(
                        .completed(
                            id: callID,
                            name: effectiveName,
                            inputJson: effectiveArgumentsJson,
                            resultJson: deniedResult.resultJson,
                            isError: true,
                            durationMs: durationMs
                        )
                    )
                }

                return deniedResult
            }

            await recordAgentToolEvent(
                kind: .toolCallApproved,
                status: .approved,
                approvalID: permissionRequest.id,
                metadata: [
                    "approval_required": permissionRequest.requiresHumanApproval ? "true" : "false",
                    "authority_checked": toolApprovalHandler == nil ? "false" : "true",
                ]
            )
            await recordAgentToolEvent(
                kind: .toolCallStarted,
                status: .started
            )

            let rawResult = await baseExecutor(effectiveName, effectiveArgumentsJson)
            let hookedResult = await HookRegistry.shared.fireAfterToolCall(
                call: preparedCall,
                result: HookToolResult(
                    toolCallId: callID,
                    content: rawResult.resultJson,
                    isError: rawResult.isError
                ),
                runID: normalizedRunID
            )
            let result = LocalToolResult(
                toolName: effectiveName,
                resultJson: hookedResult.content,
                isError: hookedResult.isError
            )
            let elapsedSeconds = max(0, Date().timeIntervalSince(startedAt))
            let durationMs = UInt64(elapsedSeconds * 1000)
            await recordAgentToolEvent(
                kind: result.isError ? .toolCallFailed : .toolCallCompleted,
                status: result.isError ? .failed : .completed,
                resultJson: result.resultJson,
                durationMs: durationMs,
                errorMessage: result.isError ? String(result.resultJson.prefix(500)) : nil
            )

            await MainActor.run {
                toolEventHandler?(
                    .completed(
                        id: callID,
                        name: effectiveName,
                        inputJson: effectiveArgumentsJson,
                        resultJson: result.resultJson,
                        isError: result.isError,
                        durationMs: durationMs
                    )
                )
            }

            return result
        }
    }

    nonisolated private static func pipelineToolRiskLevel(
        for tool: OmegaToolDefinition?
    ) -> AgentRuntimeRiskLevel {
        guard let tool else { return .readOnly }
        if tool.destructive {
            return .destructive
        }
        if tool.requiresConfirmation {
            return .modification
        }
        return .readOnly
    }

    nonisolated private static func toolErrorJSON(_ message: String) -> String {
        let payload: [String: Any] = [
            "error": message,
            "success": false,
        ]
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ),
        let json = String(data: data, encoding: .utf8) else {
            return "{\"error\":\"\(message)\",\"success\":false}"
        }
        return json
    }

    nonisolated private static func elapsedMilliseconds(since start: Date?) -> UInt64 {
        guard let start else { return 0 }
        let elapsedSeconds = max(0, Date().timeIntervalSince(start))
        return UInt64(elapsedSeconds * 1000)
    }

    nonisolated private static func combinedAdditionalSystemPrompt(
        base: String?,
        hookContext: PromptContext
    ) -> String? {
        var sections: [String] = []
        if let base = base?.trimmingCharacters(in: .whitespacesAndNewlines), !base.isEmpty {
            sections.append(base)
        }

        let facts = hookContext.injectedFacts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !facts.isEmpty {
            sections.append("Hook injected facts:\n" + facts.map { "- \($0)" }.joined(separator: "\n"))
        }

        let toolDescriptions = hookContext.additionalToolDescriptions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !toolDescriptions.isEmpty {
            sections.append("Hook tool notes:\n" + toolDescriptions.joined(separator: "\n"))
        }

        let suffix = hookContext.systemPromptSuffix.trimmingCharacters(in: .whitespacesAndNewlines)
        if !suffix.isEmpty {
            sections.append(suffix)
        }

        return sections.isEmpty ? nil : sections.joined(separator: "\n\n")
    }

    private func activeCompanionSystemInstruction() -> String? {
        guard let instruction = activeCompanionInstructionProvider()?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !instruction.isEmpty else {
            return nil
        }
        return instruction
    }

    nonisolated private static func joinSystemPromptSections(_ sections: String?...) -> String? {
        let normalized = sections.compactMap { section -> String? in
            guard let value = section?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else {
                return nil
            }
            return value
        }
        return normalized.isEmpty ? nil : normalized.joined(separator: "\n\n")
    }

    func cancelActiveRun() {
        guard activeRunID != nil else { return }
        pipelineTask?.cancel()
        pipelineTask = nil
        activeRunID = nil
        pipelineState.completeProcessing()
    }

    private func supersedeActiveRun(with runID: UUID) {
        pipelineTask?.cancel()
        pipelineTask = nil
        activeRunID = runID
    }

    private func cancelActiveRunIfNeeded(_ runID: UUID) {
        guard activeRunID == runID else { return }
        pipelineTask?.cancel()
        pipelineTask = nil
        activeRunID = nil
    }

    private func completeActiveRunIfNeeded(_ runID: UUID) {
        guard activeRunID == runID else { return }
        pipelineState.completeProcessing()
        pipelineTask = nil
        activeRunID = nil
    }

    private func failActiveRunIfNeeded(_ runID: UUID, error: String) {
        guard activeRunID == runID else { return }
        pipelineState.setError(error)
        pipelineState.completeProcessing()
        pipelineTask = nil
        activeRunID = nil
    }

    nonisolated static func buildPromptEnvelope(
        query: String,
        notesContext: String? = nil,
        conversationHistory: String? = nil
    ) -> String {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notesContext?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHistory = conversationHistory?.trimmingCharacters(in: .whitespacesAndNewlines)

        let hasNotes = trimmedNotes?.isEmpty == false
        let hasHistory = trimmedHistory?.isEmpty == false
        guard hasNotes || hasHistory else {
            return trimmedQuery
        }

        var sections: [String] = []
        if let trimmedNotes, !trimmedNotes.isEmpty {
            sections.append(trimmedNotes)
        }
        if let trimmedHistory, !trimmedHistory.isEmpty {
            sections.append("Conversation history:\n\(trimmedHistory)")
        }
        sections.append("Current request:\n\(trimmedQuery)")
        return sections.joined(separator: "\n\n")
    }

    private func generateDirectStream(
        query: String,
        notesContext: String? = nil,
        conversationHistory: String? = nil,
        operatingMode: EpistemosOperatingMode = .fast,
        executionPlan: OverseerComplexityRouter.ExecutionPlan? = nil,
        modelInputCaptureHandler: (@MainActor @Sendable (CapturedModelInput) -> Void)? = nil,
        reasoningEventHandler: (@MainActor @Sendable (String) -> Void)? = nil,
        toolEventHandler: (@MainActor @Sendable (PipelineToolEvent) -> Void)? = nil
    ) -> AsyncThrowingStream<String, Error> {
        Log.pipeline.info("🔬 generateDirectStream — chatMode=PLAIN queryLen=\(query.count)")

        let finalPrompt = Self.buildPromptEnvelope(
            query: query,
            notesContext: notesContext,
            conversationHistory: conversationHistory
        )

        Log.pipeline.info(
            "🔬 systemPrompt length=0 chars | prompt length=\(finalPrompt.count) chars | hasHistory=\(conversationHistory != nil)"
        )

        // Prepend the capability manifest so non-agent turns (Fast /
        // Thinking mode, local and cloud) have the same identity +
        // app-routes + how-to-act brief the Rust-agent path builds.
        //
        // Tool-contract: this direct-stream path cannot execute app
        // tools (vault.read, file.read, etc.) — only the Rust agent
        // path and LocalAgentLoop can. We filter app tools out of
        // the manifest (toolExecutionAvailable: false) and skip the
        // overseer-plan tool prompt so the model isn't lied to about
        // tool availability. Provider-native tools (web_search,
        // web_fetch, code_execution, google_search) still work
        // because LLMService wires them directly into the provider
        // request body.
        var systemParts: [String] = []
        if let manifest = buildCapabilityManifest(
            operatingMode: operatingMode,
            executionPlan: executionPlan,
            toolExecutionAvailable: false
        ), !manifest.isEmpty {
            systemParts.append(manifest)
        }
        if let activeAgent = activeCompanionSystemInstruction() {
            systemParts.append(activeAgent)
        }
        // Procedural memory: the user's generated skills shape direct (non-agent)
        // chats too, matching the local-agent loop. Absent skills → no change.
        if let skills = LocalAgentPromptBuilder.proceduralMemoryBlock() {
            systemParts.append(skills)
        }
        // SS-H keystone: even on the direct (tool-loop-less) stream, show the model
        // the ChatLite skills catalog so a small local model that can't drive the
        // loop is still AWARE of what's available (skills as context, not requiring
        // the loop). Pairs with shouldUseToolLoop PART 2 (tool-needing queries route
        // to a fitting agent model when one fits).
        if let catalog = chatLiteSkillsCatalogBlock(operatingMode: operatingMode) {
            systemParts.append(catalog)
        }
        let systemPrompt: String? = systemParts.isEmpty
            ? nil
            : systemParts.joined(separator: "\n\n")

        emitCapturedModelInput(
            systemPrompt: systemPrompt,
            userPrompt: finalPrompt,
            conversationHistory: conversationHistory,
            operatingMode: operatingMode,
            toolDefinitionsJSON: Self.encodedToolNameJSON(
                inference.capabilityToolNames(
                    for: operatingMode,
                    executionPlan: executionPlan
                )
            ),
            handler: modelInputCaptureHandler
        )

        let effectiveChatSelection = inference.effectiveChatSurfaceSelection(
            for: operatingMode
        )
        let requestedActModelID: String? = {
            if case .localMLX(let modelID) = effectiveChatSelection {
                return modelID
            }
            return nil
        }()
        let shouldUseActEventStream = LocalAgentLoop.shouldRouteActThroughOsaurus()
            && (operatingMode == .agent || requestedActModelID != nil)
        if shouldUseActEventStream,
           let actEventStream = SharedActInference.actEventStreamIfArmed(
            prompt: finalPrompt,
            systemPrompt: systemPrompt,
            maxTokens: 2_048,
            reasoningMode: operatingMode == .fast ? .fast : .thinking,
            modelID: requestedActModelID
           ) {
            return StreamingBufferPolicy.throwingStream { continuation in
                let task = Task { @MainActor in
                    var toolStarts: [String: (name: String, inputJson: String, startedAt: Date)] = [:]
                    do {
                        for try await event in actEventStream {
                            switch event {
                            case .textDelta(let text):
                                continuation.yield(text)
                            case .thinkingDelta(let text):
                                reasoningEventHandler?(text)
                            case .toolStarted(let id, let name, let inputJson):
                                toolStarts[id] = (name: name, inputJson: inputJson, startedAt: Date())
                                toolEventHandler?(.started(id: id, name: name, inputJson: inputJson))
                            case .toolCompleted(let id, let result, let isError):
                                let started = toolStarts.removeValue(forKey: id)
                                let durationMs = Self.elapsedMilliseconds(since: started?.startedAt)
                                toolEventHandler?(
                                    .completed(
                                        id: id,
                                        name: started?.name ?? "osaurus.tool",
                                        inputJson: started?.inputJson ?? "{}",
                                        resultJson: result,
                                        isError: isError,
                                        durationMs: durationMs
                                    )
                                )
                            case .generationStats:
                                // 0.33a: telemetry recorded to ActTurnStatsStore upstream; no text effect here.
                                break
                            }
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
        let shouldForceDirectLocalStream = executionPlan?.forcesLocalExecution == true
            && {
                if case .localMLX = effectiveChatSelection {
                    return true
                }
                return false
            }()

        if shouldForceDirectLocalStream {
            return triageService.streamGeneralLocally(
                prompt: finalPrompt,
                systemPrompt: systemPrompt,
                operation: .chatResponse(query: query),
                contentLength: finalPrompt.count,
                operatingMode: operatingMode,
                localSurface: .miniChat,
                steeringHintsJSON: executionPlan?.steeringHintsJSON,
                reasoningSink: reasoningEventHandler
            )
        }

        return triageService.streamGeneral(
            prompt: finalPrompt,
            systemPrompt: systemPrompt,
            operation: .chatResponse(query: query),
            contentLength: finalPrompt.count,
            operatingMode: operatingMode,
            localSurface: .miniChat,
            steeringHintsJSON: executionPlan?.steeringHintsJSON,
            reasoningSink: reasoningEventHandler
        )
    }

    /// Compose a CapabilityManifestBuilder context from the current
    /// pipeline state + render it to markdown. Local paths get the
    /// compact variant (small-model-friendly); cloud gets the full
    /// manifest. Returns nil if we don't have enough info.
    ///
    /// `toolExecutionAvailable` is false for direct-stream callers
    /// (Fast / Thinking cloud, local non-agent) that can't execute
    /// app tools. When false, app-level tools are filtered out so
    /// the manifest only advertises provider-native tools the request
    /// actually supports (web_search, web_fetch, code_execution,
    /// google_search). This prevents the model from hallucinating
    /// tool calls for vault.read / file.read / file.patch etc. that the
    /// runtime can't honor.
    private func buildCapabilityManifest(
        operatingMode: EpistemosOperatingMode,
        executionPlan: OverseerComplexityRouter.ExecutionPlan?,
        toolExecutionAvailable: Bool = true
    ) -> String? {
        let effectiveSelection = inference.effectiveChatSurfaceSelection(for: operatingMode)
        let providerLabel: String
        let modelLabel: String
        let isLocal: Bool
        switch effectiveSelection {
        case .cloud(let model):
            providerLabel = model.provider.rawValue
            modelLabel = model.vendorModelID
            isLocal = false
        case .localMLX(let modelID):
            providerLabel = "local"
            modelLabel = modelID
            isLocal = true
        case .appleIntelligence:
            providerLabel = "apple"
            modelLabel = "Apple Intelligence"
            isLocal = true
        }

        let allowedNames: [String] = {
            if toolExecutionAvailable {
                return inference.capabilityToolNames(
                    for: operatingMode,
                    executionPlan: executionPlan
                )
            }
            // Direct-stream path: only keep provider-native tools
            // the cloud request actually attaches. App tools would
            // just lie to the model.
            return inference.providerNativeCapabilityToolNameList(
                for: operatingMode
            )
        }()
        let disabledNames: [String] = {
            guard !toolExecutionAvailable,
                  let requestedNames = executionPlan?.allowedToolNames,
                  !requestedNames.isEmpty else {
                return []
            }
            return CapabilityManifestBuilder.disabledToolNames(
                availableToolNames: Array(requestedNames).sorted(),
                enabledToolNames: allowedNames
            )
        }()

        let vaultName = vaultPathProvider().flatMap {
            URL(fileURLWithPath: $0).lastPathComponent
        }

        let context = CapabilityManifestBuilder.Context(
            providerLabel: providerLabel,
            modelLabel: modelLabel,
            operatingMode: operatingMode,
            reasoningTier: inference.chatReasoningTier,
            enabledToolNames: allowedNames,
            disabledToolNames: disabledNames,
            vaultName: vaultName,
            vaultNoteCount: nil,
            skillNames: skillNamesProvider(),
            maxContextTokens: 128_000
        )
        let manifest = isLocal
            ? CapabilityManifestBuilder.renderCompact(context)
            : CapabilityManifestBuilder.render(context)
        CapabilityManifestBuilder.persist(manifest)
        return manifest
    }

    private func emitCapturedModelInput(
        systemPrompt: String?,
        userPrompt: String,
        conversationHistory: String?,
        operatingMode: EpistemosOperatingMode,
        toolDefinitionsJSON: String?,
        handler: (@MainActor @Sendable (CapturedModelInput) -> Void)?
    ) {
        guard let handler else { return }
        handler(
            CapturedModelInput(
                runtimeLabel: inference.effectiveModelLabel(for: operatingMode),
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                messageHistory: conversationHistory,
                toolDefinitionsJSON: toolDefinitionsJSON
            )
        )
    }

    static func localToolTier(
        for operatingMode: EpistemosOperatingMode,
        executionPlan: OverseerComplexityRouter.ExecutionPlan?
    ) -> ChatToolTier {
        let effectiveMode = executionPlan?.allowsToolExecution == true
            ? executionPlan?.localOperatingMode ?? operatingMode
            : operatingMode
        return ChatToolTier.from(operatingMode: effectiveMode)
    }

    private func filteredTools(
        _ tools: [OmegaToolDefinition],
        using executionPlan: OverseerComplexityRouter.ExecutionPlan?
    ) -> [OmegaToolDefinition] {
        guard let executionPlan else { return tools }
        let allowed = executionPlan.allowedToolNames
        guard !allowed.isEmpty else { return [] }
        return tools.filter {
            AgentToolNameAliases.containsEquivalent(allowed, $0.name)
        }
    }

    nonisolated private static func encodedToolDefinitionsJSON(
        _ tools: [OmegaToolDefinition]
    ) -> String? {
        let schemas = tools.map(\.planningSchema)
        guard !schemas.isEmpty else { return nil }
        return encodedJSON(schemas)
    }

    nonisolated private static func encodedToolNameJSON(
        _ toolNames: [String]
    ) -> String? {
        let payload = toolNames.map { ["name": $0] }
        guard !payload.isEmpty else { return nil }
        return encodedJSON(payload)
    }

    nonisolated private static func encodedJSON(
        _ payload: Any
    ) -> String? {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(
                withJSONObject: payload,
                options: [.prettyPrinted, .sortedKeys]
              ) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
