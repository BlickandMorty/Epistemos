import Foundation
import Observation
import os

nonisolated enum ChatResponseStyleGuide {
    static let mainChatSystemInstruction = """
    Prefer flowing prose over outlines and bullet lists unless the user asks for structure or the material truly needs it.
    Aim for a conversational, reflective voice that feels like thinking with the user, not lecturing at them.
    When the topic is philosophical or introspective, go deeper instead of defaulting to a list.
    Keep provenance explicit: attached notes/files/chats are not the same thing as vault material you had to go find.
    If the user asks you to find, open, summarize, copy, or edit a vault note, only say you found or read it after the vault lookup actually succeeded.
    If a required tool lookup is blocked, denied, or unreadable, say that plainly and stop instead of pretending the lookup succeeded.
    """
}

// MARK: - Notes Operation

/// Classifies each notes AI operation with a base complexity score.
/// The local runtime remains primary when available; the lighter operations
/// simply remain eligible for an Apple fallback when no usable local runtime is ready.
nonisolated enum NotesOperation: Sendable {
    case grammarFix        // 0.15 — simple transform, ideal for on-device
    case summarize         // 0.20 — focused extraction
    case rewrite           // 0.25 — focused transformation
    case continueWriting   // 0.30 — needs tone matching
    case ask(query: String)// 0.20 + query complexity — short note questions fit on-device
    case outline           // 0.40 — structural analysis
    case expand            // 0.50 — needs creative depth
    case analyze           // 0.60 — deep reasoning

    var baseComplexity: Double {
        switch self {
        case .grammarFix:      0.15
        case .summarize:       0.20
        case .rewrite:         0.25
        case .continueWriting: 0.30
        case .ask:             0.20
        case .outline:         0.40
        case .expand:          0.50
        case .analyze:         0.60
        }
    }

    var displayName: String {
        switch self {
        case .grammarFix:      "Grammar Fix"
        case .summarize:       "Summarize"
        case .rewrite:         "Rewrite"
        case .continueWriting: "Continue Writing"
        case .ask:             "Ask"
        case .outline:         "Outline"
        case .expand:          "Expand"
        case .analyze:         "Analyze"
        }
    }
}

// MARK: - General Operation

/// Classifies non-notes AI operations for triage routing.
nonisolated enum GeneralOperation: Sendable {
    case chatResponse(query: String)  // 0.35 — user-facing streaming answer
    case brainstorm                   // 0.25 — creative, short output

    var baseComplexity: Double {
        switch self {
        case .chatResponse: 0.35
        case .brainstorm:   0.25
        }
    }

    var displayName: String {
        switch self {
        case .chatResponse: "Chat Response"
        case .brainstorm:   "Brainstorm"
        }
    }
}

nonisolated enum InferenceTaskIntent: Sendable, Equatable {
    case simpleAsk
    case rewrite
    case summarize
    case brainstorm
    case coding
    case debugging
    case comparison
    case synthesis
    case noteAnalysis
    case graphAnalysis
}

nonisolated enum InferenceRouteKind: String, Sendable, Equatable {
    case appleIntelligence
    case cloud
}

nonisolated enum InferenceComplexityTier: String, Sendable, Equatable {
    case trivial
    case light
    case moderate
    case heavy
    case extreme
}

nonisolated enum InferenceContextTier: String, Sendable, Equatable {
    case tiny
    case small
    case medium
    case large
    case oversized
}

nonisolated enum InferenceDecisionReasonCode: String, Sendable, Equatable, Hashable {
    case simpleTaskAppleEligible
    case appleUnavailable
    case appleBypassedForComplexity
    case localModeForced
    case cloudAutoRoute
    case explicitThinkingRequested
    case explicitFastRequested
    case preferredLocalModelUsed
    case preferredLocalModelUnavailable
    case noInstalledLocalModel
}

nonisolated struct InferenceRequestProfile: Sendable, Equatable {
    let surface: LocalModelSelectionSurface
    let intent: InferenceTaskIntent
    let contentLength: Int
    let promptLength: Int
    let contextBlockCount: Int
    let estimatedTokenLoad: Int
    let baseComplexity: Double
    let queryComplexity: Double
    let operatingMode: EpistemosOperatingMode
    let requestedReasoningMode: LocalReasoningMode
    let explicitThinkingRequested: Bool
    let explicitFastRequested: Bool
    let visibleThinkingRequested: Bool
}

nonisolated struct InferencePolicyContext: Sendable, Equatable {
    let appleIntelligenceAvailable: Bool
    let cloudAutoRouteEnabled: Bool
    let hasConfiguredCloudModels: Bool
    let preferredChatModelSelection: ChatModelSelection
}

nonisolated struct InferenceRouteDecision: Sendable, Equatable {
    let selectedRoute: InferenceRouteKind
    let selectedReasoningMode: LocalReasoningMode
    let complexityTier: InferenceComplexityTier
    let contextTier: InferenceContextTier
    let reasonCodes: Set<InferenceDecisionReasonCode>
}

nonisolated struct InferencePolicyEngine {
    private let maxAppleIntelligenceContentLength = 6_000

    func decide(
        profile: InferenceRequestProfile,
        context: InferencePolicyContext
    ) -> InferenceRouteDecision {
        let complexityTier = self.complexityTier(for: profile)
        let contextTier = self.contextTier(for: profile)
        var reasonCodes: Set<InferenceDecisionReasonCode> = []

        if let explicitRoute = explicitRoute(for: profile, context: context) {
            return InferenceRouteDecision(
                selectedRoute: explicitRoute,
                selectedReasoningMode: reasoningMode(
                    for: profile,
                    complexityTier: complexityTier,
                    contextTier: contextTier
                ),
                complexityTier: complexityTier,
                contextTier: contextTier,
                reasonCodes: reasonCodes
            )
        }

        if shouldAutoRouteToCloud(
            profile: profile,
            context: context,
            complexityTier: complexityTier,
            contextTier: contextTier,
            reasonCodes: &reasonCodes
        ) {
            return InferenceRouteDecision(
                selectedRoute: .cloud,
                selectedReasoningMode: reasoningMode(
                    for: profile,
                    complexityTier: complexityTier,
                    contextTier: contextTier
                ),
                complexityTier: complexityTier,
                contextTier: contextTier,
                reasonCodes: reasonCodes
            )
        }

        if appleEligible(
            profile: profile,
            context: context,
            complexityTier: complexityTier,
            contextTier: contextTier,
            reasonCodes: &reasonCodes
        ) {
            return InferenceRouteDecision(
                selectedRoute: .appleIntelligence,
                selectedReasoningMode: .fast,
                complexityTier: complexityTier,
                contextTier: contextTier,
                reasonCodes: reasonCodes
            )
        }

        // Cloud-only terminal fallback: no local runtime exists, so an
        // unrouted request goes to the configured cloud provider (never a
        // local route). Credential absence surfaces downstream as a cloud
        // configuration error, not a silent "no model".
        return InferenceRouteDecision(
            selectedRoute: .cloud,
            selectedReasoningMode: reasoningMode(
                for: profile,
                complexityTier: complexityTier,
                contextTier: contextTier
            ),
            complexityTier: complexityTier,
            contextTier: contextTier,
            reasonCodes: reasonCodes
        )
    }

    private func appleEligible(
        profile: InferenceRequestProfile,
        context: InferencePolicyContext,
        complexityTier: InferenceComplexityTier,
        contextTier: InferenceContextTier,
        reasonCodes: inout Set<InferenceDecisionReasonCode>
    ) -> Bool {
        guard context.appleIntelligenceAvailable else {
            reasonCodes.insert(.appleUnavailable)
            return false
        }
        guard contextTier != .oversized,
              profile.contentLength <= (maxAppleIntelligenceContentLength * 2) else {
            reasonCodes.insert(.appleBypassedForComplexity)
            return false
        }

        let appleFriendlyIntent: Bool
        switch profile.intent {
        case .rewrite, .summarize, .simpleAsk, .brainstorm:
            appleFriendlyIntent = true
        case .coding, .debugging, .comparison, .synthesis, .noteAnalysis, .graphAnalysis:
            appleFriendlyIntent = false
        }
        guard appleFriendlyIntent else {
            reasonCodes.insert(.appleBypassedForComplexity)
            return false
        }

        switch (complexityTier, contextTier) {
        case (.trivial, _),
             (.light, .tiny),
             (.light, .small),
             (.light, .medium),
             (.light, .large),
             (.moderate, .tiny),
             (.moderate, .small):
            reasonCodes.insert(.simpleTaskAppleEligible)
            return true
        default:
            reasonCodes.insert(.appleBypassedForComplexity)
            return false
        }
    }

    private func reasoningMode(
        for profile: InferenceRequestProfile,
        complexityTier: InferenceComplexityTier,
        contextTier: InferenceContextTier
    ) -> LocalReasoningMode {
        if profile.explicitFastRequested {
            return .fast
        }
        if profile.requestedReasoningMode == .thinking,
           profile.explicitThinkingRequested {
            return .thinking
        }
        _ = complexityTier
        _ = contextTier
        return .fast
    }

    private func explicitRoute(
        for profile: InferenceRequestProfile,
        context: InferencePolicyContext
    ) -> InferenceRouteKind? {
        _ = profile
        switch context.preferredChatModelSelection {
        case .appleIntelligence:
            return context.appleIntelligenceAvailable ? .appleIntelligence : nil
        case .localMLX:
            // Cloud-only: a stale local pin never routes locally — fall through.
            return nil
        case .cloud:
            return .cloud
        }
    }

    private func shouldAutoRouteToCloud(
        profile: InferenceRequestProfile,
        context: InferencePolicyContext,
        complexityTier: InferenceComplexityTier,
        contextTier: InferenceContextTier,
        reasonCodes: inout Set<InferenceDecisionReasonCode>
    ) -> Bool {
        guard context.cloudAutoRouteEnabled,
              context.hasConfiguredCloudModels else {
            return false
        }

        if contextTier == .large || contextTier == .oversized {
            reasonCodes.insert(.cloudAutoRoute)
            return true
        }

        // LOCAL FOR ALL MODES (owner #1 mandate 2026-06-18): every mode stays
        // local when a local model can serve; cloud is the honest escalation ONLY
        // when none can (no local selection + no Apple Intelligence). Previously
        // .pro/.agent/.thinking returned cloud UNCONDITIONALLY — a silent-GPT
        // route even with a working local model (the second seam alongside the
        // chat seam effectiveChatSurfaceSelection). The large/oversized-context
        // escalation above still applies — that is a genuine "local can't fit
        // this" case, not a silent preference for cloud.
        if !context.appleIntelligenceAvailable {
            reasonCodes.insert(.cloudAutoRoute)
            return true
        }
        _ = complexityTier
        _ = profile.operatingMode
        return false
    }

    private func complexityTier(for profile: InferenceRequestProfile) -> InferenceComplexityTier {
        let contextTier = contextTier(for: profile)
        var score = profile.baseComplexity
        score += min(0.28, profile.queryComplexity * 0.50)
        score += contextComplexityWeight(for: contextTier)
        score += intentComplexityWeight(for: profile.intent)

        switch profile.surface {
        case .mainChat:
            break
        case .noteAgentPortal:
            score += 0.03
        case .graph:
            score += 0.06
        }

        let clamped = max(0, min(1, score))
        switch clamped {
        case ..<0.18:
            return .trivial
        case ..<0.34:
            return .light
        case ..<0.58:
            return .moderate
        case ..<0.78:
            return .heavy
        default:
            return .extreme
        }
    }

    private func contextTier(for profile: InferenceRequestProfile) -> InferenceContextTier {
        switch (profile.contentLength, profile.estimatedTokenLoad, profile.contextBlockCount) {
        case (...400, ...160, ...1):
            return .tiny
        case (...1_800, ...600, ...2):
            return .small
        case (...6_000, ...1_800, ...4):
            return .medium
        case (...12_000, ...3_500, ...8):
            return .large
        default:
            return .oversized
        }
    }

    private func contextComplexityWeight(for tier: InferenceContextTier) -> Double {
        switch tier {
        case .tiny:
            0
        case .small:
            0.03
        case .medium:
            0.10
        case .large:
            0.18
        case .oversized:
            0.28
        }
    }

    private func intentComplexityWeight(for intent: InferenceTaskIntent) -> Double {
        switch intent {
        case .simpleAsk:
            0
        case .rewrite:
            -0.04
        case .summarize:
            -0.02
        case .brainstorm:
            0.03
        case .coding:
            0.12
        case .debugging:
            0.18
        case .comparison:
            0.10
        case .synthesis:
            0.14
        case .noteAnalysis:
            0.16
        case .graphAnalysis:
            0.20
        }
    }
}

// MARK: - Triage Decision

nonisolated enum TriageDecision: Sendable, Equatable {
    case appleIntelligence
    case cloud

    var isOnDevice: Bool {
        switch self {
        case .appleIntelligence:
            true
        case .cloud:
            false
        }
    }

    var label: String {
        switch self {
        case .appleIntelligence: "On-device"
        case .cloud:             "Cloud Model"
        }
    }

    var icon: String {
        switch self {
        case .appleIntelligence: "cpu"
        case .cloud:             "cloud"
        }
    }
}

nonisolated enum CloudRoutingError: LocalizedError {
    case modelFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelFailed(let detail): return detail
        }
    }
}

// MARK: - Triage Service

/// Routes AI operations across the local runtime, explicit Apple selection,
/// and cloud paths while keeping the local runtime first in the automatic flow.
@MainActor @Observable
final class TriageService {
    private static let cloudBaselineSystemPrompt = """
    You are a helpful assistant inside Epistemos, a personal knowledge management app.
    Answer directly and clearly.
    \(ChatResponseStyleGuide.mainChatSystemInstruction)
    Use polished spelling and grammar.
    You have access to the user's knowledge graph context when provided.
    If the answer is uncertain, say so plainly instead of fabricating confidence.
    """

    private let inference: InferenceState
    private let localLLMService: (any LLMClientProtocol)?
    private let cloudLLMService: (any LLMClientProtocol)?
    private let prepareForRouting: @MainActor @Sendable () -> Void

    var lastDecision: TriageDecision?

    /// Returns true if the response looks like a polite refusal.
    /// Checks only the first 500 chars — long Apple refusals start with the refusal
    /// then pad with resources/disclaimers. Checking the opening is sufficient and fast.
    nonisolated static func isRefusalResponse(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true } // Empty = refusal

        // Check the opening of the response (refusals always lead with the refusal)
        let prefix = String(trimmed.prefix(500)).lowercased()

        let patterns = [
            // Generic AI refusals
            "i can't help", "i cannot help",
            "i'm not able to", "i am not able to",
            "i don't have the ability",
            "i'm unable to", "i am unable to",
            "i can't assist", "i cannot assist",
            "i'm sorry, but i can't", "i'm sorry, but i cannot",
            "beyond my capabilities", "outside my capabilities",
            "not something i can do",
            "i don't have enough context",
            "i can't provide", "i cannot provide",
            "i can't access", "i cannot access",
            "could not help", "couldn't help",
            // Apple Intelligence specific
            "as a language model created by apple",
            "beyond my remit",
            "adhere to ethical guidelines",
            "i'm not able to assist",
            "i am not able to assist",
            "i'm sorry, but as a language model",
            "i am sorry, but as a language model",
            "ensure the safety and well-being",
            "is beyond my",
            "outside my remit",
            "not within my capabilities",
            "i'm designed to",
        ]
        if patterns.contains(where: { prefix.contains($0) }) { return true }

        // "As an AI…" / "As an Apple…" are refusals ONLY when paired with a refusal verb in the same opening —
        // a bare "As an AI assistant, I'd be happy to help…" is a HELPFUL response and must NOT be flagged
        // (the old bare "as an ai"/"as an apple" patterns false-positived on it → wrong fallback/escalation).
        if prefix.contains("as an ai") || prefix.contains("as an apple") {
            let refusalVerbs = [
                "can't", "cannot", "can not", "unable", "not able", "won't", "will not",
                "i'm sorry", "i am sorry", "not going to", "shouldn't", "should not", "not permitted",
            ]
            if refusalVerbs.contains(where: { prefix.contains($0) }) { return true }
        }
        return false
    }

    /// Returns true if the response appears truncated or too short to be useful.
    /// Catches: empty responses, mid-sentence cutoffs, suspiciously brief answers.
    nonisolated static func isTruncatedResponse(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Empty or near-empty
        if trimmed.count < 20 { return true }

        // Ends mid-sentence: no terminal punctuation and response is substantial
        if trimmed.count > 40 {
            let lastChar = trimmed.last ?? " "
            let terminalChars: Set<Character> = [".", "!", "?", ":", ")", "]", "\"", "'", "`", "-", "*"]
            if !terminalChars.contains(lastChar) {
                // Check it's not a list item or code block (which may end without punctuation)
                let lastLine = trimmed.components(separatedBy: "\n").last ?? ""
                let isListOrCode = lastLine.hasPrefix("-") || lastLine.hasPrefix("*") ||
                    lastLine.hasPrefix("```") || lastLine.hasPrefix("  ")
                if !isListOrCode { return true }
            }
        }

        return false
    }

    /// Combined check: is the Apple response a failure that should trigger a local retry?
    nonisolated static func shouldRetryWithLocalModel(_ text: String) -> Bool {
        isRefusalResponse(text) || isTruncatedResponse(text)
    }

    /// Apple Intelligence on-device model has ~4096 tokens of context.
    /// Trim the prompt to fit without silently replacing the caller's instructions.
    private static func trimForAppleIntelligence(prompt: String, systemPrompt: String?) -> (String, String?) {
        // Budget: ~4096 tokens ≈ 12,000 chars. Reserve room for the response.
        let promptBudget = 8_000

        let trimmedPrompt: String
        if prompt.count > promptBudget {
            // Preserve the end (the actual user query) over conversation history prefix
            let suffix = String(prompt.suffix(2_000))
            let prefix = String(prompt.prefix(promptBudget - 2_000))
            trimmedPrompt = prefix + "\n\n[...]\n\n" + suffix
        } else {
            trimmedPrompt = prompt
        }

        return (trimmedPrompt, systemPrompt)
    }

    init(
        inference: InferenceState,
        localLLMService: (any LLMClientProtocol)? = nil,
        cloudLLMService: (any LLMClientProtocol)? = nil,
        prepareForRouting: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        self.inference = inference
        self.localLLMService = localLLMService
        self.cloudLLMService = cloudLLMService
        self.prepareForRouting = prepareForRouting
    }

    // MARK: - Triage Logic

    /// Routes a notes operation to Apple Intelligence or the local model path.
    func triage(
        operation: NotesOperation,
        contentLength: Int,
        query: String? = nil,
        localReasoningMode: LocalReasoningMode? = nil
    ) -> TriageDecision {
        triage(
            operation: operation,
            contentLength: contentLength,
            query: query,
            operatingMode: cloudOperatingMode(for: localReasoningMode)
        )
    }

    func triage(
        operation: NotesOperation,
        contentLength: Int,
        query: String? = nil,
        operatingMode: EpistemosOperatingMode
    ) -> TriageDecision {
        prepareForRouting()
        let decision = routeDecisionForNotes(
            operation: operation,
            contentLength: contentLength,
            query: query,
            operatingMode: operatingMode
        )
        return triageDecision(for: decision.selectedRoute)
    }

    // MARK: - Stream with Triage

    func stream(
        prompt: String,
        systemPrompt: String? = nil,
        operation: NotesOperation,
        contentLength: Int,
        query: String? = nil,
        localReasoningMode: LocalReasoningMode? = nil,
        reasoningSink: (@MainActor @Sendable (String) -> Void)? = nil
    ) -> AsyncThrowingStream<String, Error> {
        stream(
            prompt: prompt,
            systemPrompt: systemPrompt,
            operation: operation,
            contentLength: contentLength,
            query: query,
            operatingMode: cloudOperatingMode(for: localReasoningMode),
            reasoningSink: reasoningSink
        )
    }

    func stream(
        prompt: String,
        systemPrompt: String? = nil,
        operation: NotesOperation,
        contentLength: Int,
        query: String? = nil,
        operatingMode: EpistemosOperatingMode,
        reasoningSink: (@MainActor @Sendable (String) -> Void)? = nil
    ) -> AsyncThrowingStream<String, Error> {
        prepareForRouting()
        let decision = routeDecisionForNotes(
            operation: operation,
            contentLength: contentLength,
            query: query,
            operatingMode: operatingMode
        )
        let triageDecision = triageDecision(for: decision.selectedRoute)
        lastDecision = triageDecision
        Log.engine.info("Triage: \(operation.displayName) → \(triageDecision.label) (content: \(contentLength) chars)")

        switch triageDecision {
        case .appleIntelligence:
            return userFacingStream(
                appleIntelligenceStreamWithFallback(
                    prompt: prompt,
                    systemPrompt: systemPrompt
                ),
                reasoningSink: reasoningSink
            )
        case .cloud:
            guard let model = selectedCloudModel(for: operatingMode) else {
                return userFacingStream(
                    StreamingBufferPolicy.throwingStream { continuation in
                        continuation.finish(throwing: CloudLLMError.modelRequired)
                    },
                    reasoningSink: reasoningSink
                )
            }
            return userFacingStream(
                cloudStream(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    model: model,
                    operatingMode: operatingMode
                ),
                reasoningSink: reasoningSink,
                skipInferredReasoning: true
            )
        }
    }

    // MARK: - Generate with Triage

    func generate(
        prompt: String,
        systemPrompt: String? = nil,
        operation: NotesOperation,
        contentLength: Int,
        query: String? = nil,
        localReasoningMode: LocalReasoningMode? = nil
    ) async throws -> String {
        try await generate(
            prompt: prompt,
            systemPrompt: systemPrompt,
            operation: operation,
            contentLength: contentLength,
            query: query,
            operatingMode: cloudOperatingMode(for: localReasoningMode)
        )
    }

    func generate(
        prompt: String,
        systemPrompt: String? = nil,
        operation: NotesOperation,
        contentLength: Int,
        query: String? = nil,
        operatingMode: EpistemosOperatingMode
    ) async throws -> String {
        prepareForRouting()
        let decision = routeDecisionForNotes(
            operation: operation,
            contentLength: contentLength,
            query: query,
            operatingMode: operatingMode
        )
        let triageDecision = triageDecision(for: decision.selectedRoute)
        lastDecision = triageDecision
        Log.engine.info("Triage: \(operation.displayName) → \(triageDecision.label) (content: \(contentLength) chars)")

        switch triageDecision {
        case .appleIntelligence:
            let (aiPrompt, aiSystem) = Self.trimForAppleIntelligence(prompt: prompt, systemPrompt: systemPrompt)
            // Cloud-only: no local model to retry with — return the on-device
            // Apple Intelligence response (or propagate its error).
            let result = try await AppleIntelligenceService.shared.generate(prompt: aiPrompt, systemPrompt: aiSystem)
            return UserFacingModelOutput.finalVisibleText(from: result)
        case .cloud:
            guard let model = selectedCloudModel(for: operatingMode) else {
                throw CloudLLMError.modelRequired
            }
            return UserFacingModelOutput.finalVisibleText(from: try await cloudGenerate(
                prompt: prompt,
                systemPrompt: systemPrompt,
                model: model,
                operatingMode: operatingMode
            ))
        }
    }

    // MARK: - General Triage Logic

    /// Routes a general operation to Apple Intelligence or the local model path.
    func triageGeneral(
        operation: GeneralOperation,
        contentLength: Int,
        operatingMode: EpistemosOperatingMode = .fast,
        localSurface: LocalModelSelectionSurface = .mainChat
    ) -> TriageDecision {
        prepareForRouting()
        let decision = routeDecisionForGeneral(
            operation: operation,
            contentLength: contentLength,
            operatingMode: operatingMode,
            localSurface: localSurface
        )
        return triageDecision(for: decision.selectedRoute)
    }

    func streamGeneral(
        prompt: String,
        systemPrompt: String? = nil,
        operation: GeneralOperation,
        contentLength: Int,
        operatingMode: EpistemosOperatingMode = .fast,
        localSurface: LocalModelSelectionSurface = .mainChat,
        steeringHintsJSON: String? = nil,
        reasoningSink: (@MainActor @Sendable (String) -> Void)? = nil
    ) -> AsyncThrowingStream<String, Error> {
        prepareForRouting()
        let decision = routeDecisionForGeneral(
            operation: operation,
            contentLength: contentLength,
            operatingMode: operatingMode,
            localSurface: localSurface
        )
        let triageDecision = triageDecision(for: decision.selectedRoute)
        lastDecision = triageDecision
        Log.engine.info("Triage: \(operation.displayName) → \(triageDecision.label) (content: \(contentLength) chars)")

        switch triageDecision {
        case .appleIntelligence:
            return userFacingStream(
                appleIntelligenceStreamWithFallback(
                    prompt: prompt,
                    systemPrompt: systemPrompt
                ),
                reasoningSink: reasoningSink
            )
        case .cloud:
            guard let model = selectedCloudModel(for: operatingMode) else {
                return userFacingStream(
                    StreamingBufferPolicy.throwingStream { continuation in
                        continuation.finish(throwing: CloudLLMError.modelRequired)
                    },
                    reasoningSink: reasoningSink
                )
            }
            // Prominent per-turn log so "is it actually hitting
            // ChatGPT?" has a definitive answer without code-diving.
            // Prints the wire-level identity: provider brand + vendor
            // model id + operating mode + reasoning tier.
            Log.engine.notice(
                "Cloud route: provider=\(model.provider.rawValue, privacy: .public) model=\(model.vendorModelID, privacy: .public) mode=\(operatingMode.rawValue, privacy: .public) reasoning=\(self.inference.chatReasoningTier.rawValue, privacy: .public)"
            )
            return userFacingStream(
                cloudStream(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    model: model,
                    operatingMode: operatingMode
                ),
                reasoningSink: reasoningSink,
                skipInferredReasoning: true
            )
        }
    }

    func generateGeneral(
        prompt: String,
        systemPrompt: String? = nil,
        operation: GeneralOperation,
        contentLength: Int,
        operatingMode: EpistemosOperatingMode = .fast,
        localSurface: LocalModelSelectionSurface = .mainChat,
        steeringHintsJSON: String? = nil
    ) async throws -> String {
        prepareForRouting()
        let decision = routeDecisionForGeneral(
            operation: operation,
            contentLength: contentLength,
            operatingMode: operatingMode,
            localSurface: localSurface
        )
        let triageDecision = triageDecision(for: decision.selectedRoute)
        lastDecision = triageDecision
        Log.engine.info("Triage: \(operation.displayName) → \(triageDecision.label) (content: \(contentLength) chars)")

        switch triageDecision {
        case .appleIntelligence:
            let (aiPrompt, aiSystem) = Self.trimForAppleIntelligence(prompt: prompt, systemPrompt: systemPrompt)
            // Cloud-only: no local model to retry with — return the on-device
            // Apple Intelligence response (or propagate its error).
            let result = try await AppleIntelligenceService.shared.generate(prompt: aiPrompt, systemPrompt: aiSystem)
            return UserFacingModelOutput.finalVisibleText(from: result)
        case .cloud:
            guard let model = selectedCloudModel(for: operatingMode) else {
                throw CloudLLMError.modelRequired
            }
            return UserFacingModelOutput.finalVisibleText(from: try await cloudGenerate(
                prompt: prompt,
                systemPrompt: systemPrompt,
                model: model,
                operatingMode: operatingMode
            ))
        }
    }

    // MARK: - Apple Intelligence Stream with Fallback

    /// Streams from Apple Intelligence (the on-device path). Cloud-only build:
    /// there is no local model to fall back to, so the Apple response is surfaced
    /// as-is, and a thrown Apple error finishes the stream with that error.
    private func appleIntelligenceStreamWithFallback(
        prompt: String,
        systemPrompt: String?
    ) -> AsyncThrowingStream<String, Error> {
        let (aiPrompt, aiSystem) = Self.trimForAppleIntelligence(prompt: prompt, systemPrompt: systemPrompt)

        return StreamingBufferPolicy.throwingStream { continuation in
            let task = Task {
                do {
                    let result = try await AppleIntelligenceService.shared.generate(
                        prompt: aiPrompt,
                        systemPrompt: aiSystem
                    )
                    continuation.yield(result)
                    continuation.finish()
                } catch {
                    Log.engine.warning("Apple Intelligence failed (stream): \(error.localizedDescription, privacy: .public)")
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Shared Triage Heuristics

    private func routeDecisionForNotes(
        operation: NotesOperation,
        contentLength: Int,
        query: String?,
        localReasoningMode: LocalReasoningMode?
    ) -> InferenceRouteDecision {
        routeDecisionForNotes(
            operation: operation,
            contentLength: contentLength,
            query: query,
            operatingMode: cloudOperatingMode(for: localReasoningMode)
        )
    }

    private func routeDecisionForNotes(
        operation: NotesOperation,
        contentLength: Int,
        query: String?,
        operatingMode: EpistemosOperatingMode
    ) -> InferenceRouteDecision {
        inference.routeDecision(
            for: requestProfileForNotes(
                operation: operation,
                contentLength: contentLength,
                query: query,
                operatingMode: operatingMode
            )
        )
    }

    private func routeDecisionForGeneral(
        operation: GeneralOperation,
        contentLength: Int,
        operatingMode: EpistemosOperatingMode,
        localSurface: LocalModelSelectionSurface
    ) -> InferenceRouteDecision {
        inference.routeDecision(
            for: requestProfileForGeneral(
                operation: operation,
                contentLength: contentLength,
                operatingMode: operatingMode,
                localSurface: localSurface
            )
        )
    }

    private func requestProfileForNotes(
        operation: NotesOperation,
        contentLength: Int,
        query: String?,
        localReasoningMode: LocalReasoningMode?
    ) -> InferenceRequestProfile {
        requestProfileForNotes(
            operation: operation,
            contentLength: contentLength,
            query: query,
            operatingMode: cloudOperatingMode(for: localReasoningMode)
        )
    }

    private func requestProfileForNotes(
        operation: NotesOperation,
        contentLength: Int,
        query: String?,
        operatingMode: EpistemosOperatingMode
    ) -> InferenceRequestProfile {
        let queryText: String
        if case .ask(let prompt) = operation, !prompt.isEmpty {
            queryText = prompt
        } else {
            queryText = query ?? ""
        }
        let analysis = queryText.isEmpty ? nil : QueryAnalyzer.analyze(query: queryText)
        let promptLength = max(contentLength, queryText.count)
        return InferenceRequestProfile(
            surface: .noteAgentPortal,
            intent: taskIntent(for: operation, queryText: queryText),
            contentLength: contentLength,
            promptLength: promptLength,
            contextBlockCount: contextBlockCount(
                contentLength: contentLength,
                promptLength: promptLength,
                surface: .noteAgentPortal
            ),
            estimatedTokenLoad: estimatedTokenLoad(
                contentLength: contentLength,
                promptLength: promptLength
            ),
            baseComplexity: operation.baseComplexity,
            queryComplexity: analysis?.complexity ?? 0,
            operatingMode: operatingMode,
            requestedReasoningMode: operatingMode.localReasoningMode ?? .fast,
            explicitThinkingRequested: operatingMode == .thinking || operatingMode == .pro || operatingMode == .agent,
            explicitFastRequested: operatingMode == .fast,
            visibleThinkingRequested: false
        )
    }

    private func requestProfileForGeneral(
        operation: GeneralOperation,
        contentLength: Int,
        operatingMode: EpistemosOperatingMode,
        localSurface: LocalModelSelectionSurface
    ) -> InferenceRequestProfile {
        let queryText: String
        if case .chatResponse(let prompt) = operation {
            queryText = prompt
        } else {
            queryText = ""
        }
        let analysis = queryText.isEmpty ? nil : QueryAnalyzer.analyze(query: queryText)
        let promptLength = max(contentLength, queryText.count)
        return InferenceRequestProfile(
            surface: localSurface,
            intent: taskIntent(for: operation, queryText: queryText, surface: localSurface),
            contentLength: contentLength,
            promptLength: promptLength,
            contextBlockCount: contextBlockCount(
                contentLength: contentLength,
                promptLength: promptLength,
                surface: localSurface
            ),
            estimatedTokenLoad: estimatedTokenLoad(
                contentLength: contentLength,
                promptLength: promptLength
            ),
            baseComplexity: operation.baseComplexity,
            queryComplexity: analysis?.complexity ?? 0,
            operatingMode: operatingMode,
            requestedReasoningMode: operatingMode.localReasoningMode ?? .fast,
            explicitThinkingRequested: operatingMode == .thinking || operatingMode == .pro,
            explicitFastRequested: operatingMode == .fast,
            visibleThinkingRequested: false
        )
    }

    private func cloudOperatingMode(for localReasoningMode: LocalReasoningMode?) -> EpistemosOperatingMode {
        switch localReasoningMode {
        case .thinking:
            .thinking
        case .fast, .none:
            .fast
        }
    }

    private static func explicitThinkingRequested(in text: String) -> Bool {
        _ = text
        return false
    }

    private static func explicitFastRequested(in text: String) -> Bool {
        _ = text
        return false
    }

    private func triageDecision(for route: InferenceRouteKind) -> TriageDecision {
        switch route {
        case .appleIntelligence:
            .appleIntelligence
        case .cloud:
            .cloud
        }
    }

    private func estimatedTokenLoad(contentLength: Int, promptLength: Int) -> Int {
        max(1, max(contentLength, promptLength) / 4)
    }

    private func contextBlockCount(
        contentLength: Int,
        promptLength: Int,
        surface: LocalModelSelectionSurface
    ) -> Int {
        let divisor: Double
        switch surface {
        case .mainChat:
            divisor = 2_400
        case .noteAgentPortal:
            divisor = 1_800
        case .graph:
            divisor = 1_500
        }
        let combined = max(contentLength, promptLength)
        return max(1, Int(ceil(Double(combined) / divisor)))
    }

    private func taskIntent(
        for operation: NotesOperation,
        queryText: String
    ) -> InferenceTaskIntent {
        switch operation {
        case .grammarFix, .rewrite:
            return .rewrite
        case .summarize:
            return .summarize
        case .continueWriting:
            return .synthesis
        case .ask:
            return inferredTaskIntent(from: queryText, surface: .noteAgentPortal)
        case .outline, .expand:
            return .synthesis
        case .analyze:
            return .noteAnalysis
        }
    }

    private func taskIntent(
        for operation: GeneralOperation,
        queryText: String,
        surface: LocalModelSelectionSurface
    ) -> InferenceTaskIntent {
        switch operation {
        case .chatResponse:
            return inferredTaskIntent(from: queryText, surface: surface)
        case .brainstorm:
            return .brainstorm
        }
    }

    private func inferredTaskIntent(
        from queryText: String,
        surface: LocalModelSelectionSurface
    ) -> InferenceTaskIntent {
        if surface == .graph {
            return .graphAnalysis
        }

        let normalized = queryText.lowercased()
        if normalized.contains("```")
            || normalized.contains(" stack trace")
            || normalized.contains(" compiler ")
            || normalized.contains(" compile ")
            || normalized.contains(" bug ")
            || normalized.contains(" debug") {
            return .debugging
        }
        if normalized.contains("swift")
            || normalized.contains("rust")
            || normalized.contains("python")
            || normalized.contains("javascript")
            || normalized.contains("typescript")
            || normalized.contains(" code") {
            return .coding
        }
        if normalized.contains("compare")
            || normalized.contains("versus")
            || normalized.contains(" vs ")
            || normalized.contains("tradeoff")
            || normalized.contains("difference between") {
            return .comparison
        }
        if normalized.contains("synthesize")
            || normalized.contains("combine")
            || normalized.contains("across notes")
            || normalized.contains("across sources") {
            return .synthesis
        }
        if normalized.contains("analyze")
            || normalized.contains("reason through")
            || normalized.contains("failure mode")
            || normalized.contains("why") {
            return .noteAnalysis
        }
        return .simpleAsk
    }

    private func selectedCloudModel(for operatingMode: EpistemosOperatingMode? = nil) -> CloudTextModelID? {
        if case .cloud(let model) = inference.preferredChatModelSelection {
            return model
        }
        guard let operatingMode else { return nil }
        return inference.preferredAutoRouteCloudModel(for: operatingMode)
    }

    private func cloudConfigurationError(for model: CloudTextModelID) -> CloudLLMError? {
        guard inference.hasConfiguredCloudAccess(for: model.provider) else {
            return .missingAccess(model.provider.displayName)
        }
        return nil
    }

    private func cloudGenerate(
        prompt: String,
        systemPrompt: String?,
        model: CloudTextModelID,
        operatingMode: EpistemosOperatingMode
    ) async throws -> String {
        if let error = cloudConfigurationError(for: model) {
            throw error
        }
        guard let cloudLLMService else {
            throw CloudLLMError.runtimeUnavailable
        }
        if let configurable = cloudLLMService as? any CloudConfigurableLLMClient {
            return try await configurable.generate(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: inference.chatOutputTokens,
                model: model,
                operatingMode: operatingMode
            )
        }
        return try await cloudLLMService.generate(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: inference.chatOutputTokens
        )
    }

    private func cloudStream(
        prompt: String,
        systemPrompt: String?,
        model: CloudTextModelID,
        operatingMode: EpistemosOperatingMode
    ) -> AsyncThrowingStream<String, Error> {
        // Ensure cloud models always have a baseline identity prompt
        let effectiveSystemPrompt: String = {
            if let sp = systemPrompt, !sp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "\(Self.cloudBaselineSystemPrompt)\n\n\(sp)"
            }
            return Self.cloudBaselineSystemPrompt
        }()

        if let error = cloudConfigurationError(for: model) {
            return StreamingBufferPolicy.throwingStream { continuation in
                continuation.finish(throwing: error)
            }
        }
        guard let cloudLLMService else {
            return StreamingBufferPolicy.throwingStream { continuation in
                continuation.finish(throwing: CloudLLMError.runtimeUnavailable)
            }
        }
        if let configurable = cloudLLMService as? any CloudConfigurableLLMClient {
            return configurable.stream(
                prompt: prompt,
                systemPrompt: effectiveSystemPrompt,
                maxTokens: inference.chatOutputTokens,
                model: model,
                operatingMode: operatingMode
            )
        }
        return cloudLLMService.stream(
            prompt: prompt,
            systemPrompt: effectiveSystemPrompt,
            maxTokens: inference.chatOutputTokens
        )
    }

    /// Stream wrapper around Apple Intelligence's non-streaming `generate(...)`.
    /// Used when the user has no configured local or cloud model but Apple
    /// Intelligence is available — the on-device model still answers the turn
    /// instead of surfacing `modelRequired` to the chat.
    private func appleIntelligenceOnlyStream(
        prompt: String,
        systemPrompt: String?
    ) -> AsyncThrowingStream<String, Error> {
        StreamingBufferPolicy.throwingStream { continuation in
            let task = Task {
                let (trimmedPrompt, trimmedSystem) = Self.trimForAppleIntelligence(
                    prompt: prompt,
                    systemPrompt: systemPrompt
                )
                do {
                    let result = try await AppleIntelligenceService.shared.generate(
                        prompt: trimmedPrompt,
                        systemPrompt: trimmedSystem
                    )
                    self.lastDecision = .appleIntelligence
                    if !result.isEmpty {
                        continuation.yield(result)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func userFacingStream(
        _ upstream: AsyncThrowingStream<String, Error>,
        reasoningSink: (@MainActor @Sendable (String) -> Void)? = nil,
        skipInferredReasoning: Bool = false
    ) -> AsyncThrowingStream<String, Error> {
        StreamingBufferPolicy.throwingStream(limit: StreamingBufferPolicy.textLimit) { continuation in
            let task = Task {
                var rawText = ""
                var emittedVisibleText = ""
                var emittedInferredReasoningText = ""
                let reasoningRouter = ThinkTagStreamRouter()
                var sawExplicitThinkingTags = false

                do {
                    for try await chunk in upstream {
                        // Fast path for cloud models with native reasoning
                        // channels: the text stream IS the visible answer
                        // (reasoning is already extracted at the transport
                        // layer). Skip all heuristic reasoning/visible
                        // splitting to prevent answer text from being
                        // misclassified as reasoning and duplicated into the
                        // thinking lane.
                        if skipInferredReasoning {
                            // Still parse <think> tags in case a cloud model
                            // includes them (e.g. DeepSeek-R1), but skip
                            // heuristic inference entirely.
                            let reasoningEmit = reasoningRouter.ingest(chunk)
                            if !reasoningEmit.thinking.isEmpty {
                                reasoningSink?(reasoningEmit.thinking)
                            }
                            if !reasoningEmit.visible.isEmpty {
                                emittedVisibleText += reasoningEmit.visible
                                continuation.yield(reasoningEmit.visible)
                            }
                            continue
                        }

                        let priorRawText = rawText
                        let reasoningEmit = reasoningRouter.ingest(chunk)
                        if !reasoningEmit.thinking.isEmpty
                            || reasoningRouter.isCurrentlyThinking
                            || ThinkingTagSyntax.openingMatch(in: chunk) != nil
                            || ThinkingTagSyntax.closingMatch(in: chunk) != nil {
                            sawExplicitThinkingTags = true
                        }
                        if !reasoningEmit.thinking.isEmpty {
                            reasoningSink?(reasoningEmit.thinking)
                        }
                        rawText += chunk
                        if sawExplicitThinkingTags, !reasoningEmit.visible.isEmpty {
                            emittedVisibleText += reasoningEmit.visible
                            continuation.yield(reasoningEmit.visible)
                            continue
                        }
                        let inferredReasoningText = UserFacingModelOutput.streamingReasoningText(from: rawText)
                        if !inferredReasoningText.isEmpty,
                           inferredReasoningText.hasPrefix(emittedInferredReasoningText) {
                            let deltaStart = inferredReasoningText.index(
                                inferredReasoningText.startIndex,
                                offsetBy: emittedInferredReasoningText.count
                            )
                            let delta = String(inferredReasoningText[deltaStart...])
                            if !delta.isEmpty {
                                emittedInferredReasoningText = inferredReasoningText
                                reasoningSink?(delta)
                            }
                        }
                        let visibleText = UserFacingModelOutput.streamingVisibleText(from: rawText)
                        guard visibleText.hasPrefix(emittedVisibleText) else { continue }

                        let deltaStart = visibleText.index(
                            visibleText.startIndex,
                            offsetBy: emittedVisibleText.count
                        )
                        let delta = String(visibleText[deltaStart...])
                        if !delta.isEmpty {
                            emittedVisibleText = visibleText
                            continuation.yield(delta)
                            continue
                        }

                        guard emittedVisibleText.isEmpty,
                              let standaloneAnswer = UserFacingModelOutput
                                  .streamingStandaloneAnswerChunk(chunk, afterReasoningRaw: priorRawText),
                              !standaloneAnswer.isEmpty else {
                            continue
                        }

                        emittedVisibleText = standaloneAnswer
                        continuation.yield(standaloneAnswer)
                    }

                    let trailingReasoning = reasoningRouter.flush()
                    if !trailingReasoning.thinking.isEmpty {
                        reasoningSink?(trailingReasoning.thinking)
                    }

                    if !skipInferredReasoning {
                        let finalVisibleText = UserFacingModelOutput.finalVisibleText(from: rawText)
                        if finalVisibleText.hasPrefix(emittedVisibleText) {
                            let deltaStart = finalVisibleText.index(
                                finalVisibleText.startIndex,
                                offsetBy: emittedVisibleText.count
                            )
                            let delta = String(finalVisibleText[deltaStart...])
                            if !delta.isEmpty {
                                continuation.yield(delta)
                            }
                        } else if emittedVisibleText.isEmpty, !finalVisibleText.isEmpty {
                            continuation.yield(finalVisibleText)
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

    nonisolated static func maxOutputTokens(fromSteeringHintsJSON steeringHintsJSON: String?) -> Int? {
        guard let steeringHintsJSON,
              let data = steeringHintsJSON.data(using: .utf8),
              let hints = try? JSONDecoder().decode(BackendSteeringHints.self, from: data),
              let maxOutputTokens = hints.depthBudget?.maxOutputTokens,
              maxOutputTokens > 0 else {
            return nil
        }
        return Int(maxOutputTokens)
    }
}
