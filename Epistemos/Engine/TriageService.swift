import Foundation
import Observation
import os

// MARK: - Notes Operation

/// Classifies each notes AI operation with a base complexity score.
/// Simple transforms (grammar, summarize) route to Apple Intelligence;
/// deeper work routes to the local Qwen path.
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
    case localQwen
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
    let requestedReasoningMode: LocalReasoningMode
    let explicitThinkingRequested: Bool
    let explicitFastRequested: Bool
    let visibleThinkingRequested: Bool
}

nonisolated struct InferencePolicyContext: Sendable, Equatable {
    let routingMode: LocalRoutingMode
    let appleIntelligenceAvailable: Bool
    let preferredChatModelSelection: ChatModelSelection
    let preferredLocalTextModelID: String
    let installedLocalTextModelIDs: Set<String>
    let hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot
    let runtimeConditions: LocalRuntimeConditions
}

nonisolated struct InferenceRouteDecision: Sendable, Equatable {
    let selectedRoute: InferenceRouteKind
    let selectedReasoningMode: LocalReasoningMode
    let localSelection: LocalModelSelection?
    let reuseWarmModel: Bool
    let complexityTier: InferenceComplexityTier
    let contextTier: InferenceContextTier
    let reasonCodes: Set<InferenceDecisionReasonCode>

    var selectedLocalModelID: String? {
        localSelection?.modelID
    }
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

        let localSelection = localSelection(
            for: profile,
            context: context,
            complexityTier: complexityTier,
            contextTier: contextTier,
            reasonCodes: &reasonCodes
        )

        if let explicitRoute = explicitRoute(for: profile, context: context, localSelection: localSelection.selection) {
            return InferenceRouteDecision(
                selectedRoute: explicitRoute,
                selectedReasoningMode: localSelection.selection?.reasoningMode ?? reasoningMode(
                    for: profile,
                    complexityTier: complexityTier,
                    contextTier: contextTier
                ),
                localSelection: localSelection.selection,
                reuseWarmModel: localSelection.reuseWarmModel,
                complexityTier: complexityTier,
                contextTier: contextTier,
                reasonCodes: reasonCodes
            )
        }

        if prefersDedicatedLocalChatRouting(
            for: profile,
            localSelection: localSelection.selection
        ) {
            return InferenceRouteDecision(
                selectedRoute: localRouteKind(
                    for: localSelection.selection,
                    context: context
                ),
                selectedReasoningMode: localSelection.selection?.reasoningMode ?? reasoningMode(
                    for: profile,
                    complexityTier: complexityTier,
                    contextTier: contextTier
                ),
                localSelection: localSelection.selection,
                reuseWarmModel: localSelection.reuseWarmModel,
                complexityTier: complexityTier,
                contextTier: contextTier,
                reasonCodes: reasonCodes
            )
        }

        if context.routingMode == .localOnly {
            reasonCodes.insert(.localModeForced)
            return InferenceRouteDecision(
                selectedRoute: localRouteKind(
                    for: localSelection.selection,
                    context: context
                ),
                selectedReasoningMode: localSelection.selection?.reasoningMode ?? reasoningMode(
                    for: profile,
                    complexityTier: complexityTier,
                    contextTier: contextTier
                ),
                localSelection: localSelection.selection,
                reuseWarmModel: localSelection.reuseWarmModel,
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
                localSelection: localSelection.selection,
                reuseWarmModel: localSelection.reuseWarmModel,
                complexityTier: complexityTier,
                contextTier: contextTier,
                reasonCodes: reasonCodes
            )
        }

        return InferenceRouteDecision(
            selectedRoute: localRouteKind(
                for: localSelection.selection,
                context: context
            ),
            selectedReasoningMode: localSelection.selection?.reasoningMode ?? reasoningMode(
                for: profile,
                complexityTier: complexityTier,
                contextTier: contextTier
            ),
            localSelection: localSelection.selection,
            reuseWarmModel: localSelection.reuseWarmModel,
            complexityTier: complexityTier,
            contextTier: contextTier,
            reasonCodes: reasonCodes
        )
    }

    func resolvedPreferredLocalSelection(
        in context: InferencePolicyContext,
        reasoningMode: LocalReasoningMode? = nil
    ) -> LocalModelSelection? {
        let installedModels = supportedInstalledModels(in: context)
        guard !installedModels.isEmpty else { return nil }

        guard let preferredModel = LocalTextModelID(rawValue: context.preferredLocalTextModelID),
              installedModels.contains(preferredModel) else {
            return nil
        }

        let selectedReasoningMode = reasoningMode ?? .fast
        return LocalModelSelection(
            modelID: preferredModel.rawValue,
            reasoningMode: selectedReasoningMode,
            contentBudget: context.hardwareCapabilitySnapshot.recommendedLocalContentLength(
                for: context.runtimeConditions,
                reasoningMode: selectedReasoningMode
            )
        )
    }

    func localSelection(
        for profile: InferenceRequestProfile,
        context: InferencePolicyContext
    ) -> LocalModelSelection? {
        var reasonCodes: Set<InferenceDecisionReasonCode> = []
        return localSelection(
            for: profile,
            context: context,
            complexityTier: complexityTier(for: profile),
            contextTier: contextTier(for: profile),
            reasonCodes: &reasonCodes
        ).selection
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

    private func localSelection(
        for profile: InferenceRequestProfile,
        context: InferencePolicyContext,
        complexityTier: InferenceComplexityTier,
        contextTier: InferenceContextTier,
        reasonCodes: inout Set<InferenceDecisionReasonCode>
    ) -> (selection: LocalModelSelection?, reuseWarmModel: Bool) {
        let preferred = resolvedPreferredLocalSelection(
            in: context,
            reasoningMode: .fast
        )
        if preferred != nil {
            reasonCodes.insert(.preferredLocalModelUsed)
        } else if supportedInstalledModels(in: context).isEmpty {
            reasonCodes.insert(.noInstalledLocalModel)
        } else {
            reasonCodes.insert(.preferredLocalModelUnavailable)
        }
        return (preferred, false)
    }

    private func reasoningMode(
        for profile: InferenceRequestProfile,
        complexityTier: InferenceComplexityTier,
        contextTier: InferenceContextTier
    ) -> LocalReasoningMode {
        if profile.explicitFastRequested {
            return .fast
        }
        guard profile.requestedReasoningMode == .thinking,
              profile.explicitThinkingRequested,
              contextTier != .tiny else {
            return .fast
        }
        switch complexityTier {
        case .heavy, .extreme:
            return .thinking
        case .trivial, .light, .moderate:
            return .fast
        }
    }

    private func localRouteKind(
        for selection: LocalModelSelection?,
        context: InferencePolicyContext
    ) -> InferenceRouteKind {
        _ = selection
        _ = context
        return .localQwen
    }

    private func explicitRoute(
        for profile: InferenceRequestProfile,
        context: InferencePolicyContext,
        localSelection: LocalModelSelection?
    ) -> InferenceRouteKind? {
        switch context.preferredChatModelSelection {
        case .appleIntelligence:
            return context.appleIntelligenceAvailable ? .appleIntelligence : nil
        case .localQwen:
            return localSelection != nil ? .localQwen : nil
        }
    }

    private func prefersDedicatedLocalChatRouting(
        for profile: InferenceRequestProfile,
        localSelection: LocalModelSelection?
    ) -> Bool {
        guard localSelection != nil else { return false }
        switch profile.surface {
        case .mainChat, .miniChat:
            return true
        case .noteChat, .graph:
            return false
        }
    }

    private func supportedInstalledModels(in context: InferencePolicyContext) -> [LocalTextModelID] {
        context.installedLocalTextModelIDs
            .compactMap(LocalTextModelID.init(rawValue:))
            .filter { context.hardwareCapabilitySnapshot.supports(textModelID: $0.rawValue) }
            .sorted { lhs, rhs in
                lhs.minimumRecommendedMemoryGB < rhs.minimumRecommendedMemoryGB
            }
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
        case .miniChat:
            score += 0.01
        case .noteChat:
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
    case localMLX

    var isOnDevice: Bool {
        true
    }

    var label: String {
        switch self {
        case .appleIntelligence: "On-device"
        case .localMLX:          "Local Model"
        }
    }

    var icon: String {
        switch self {
        case .appleIntelligence: "cpu"
        case .localMLX:          "memorychip"
        }
    }
}

nonisolated enum LocalInferenceRoutingError: LocalizedError, Equatable {
    case modelRequired
    case runtimeUnavailable

    var errorDescription: String? {
        switch self {
        case .modelRequired:
            "No usable local Qwen model is available. Open Settings and install or select a supported Qwen model."
        case .runtimeUnavailable:
            "The local Qwen runtime is unavailable right now. Reopen the app or re-enable the local model in Settings."
        }
    }
}

// MARK: - Triage Service

/// Routes AI operations between Apple Intelligence and the local model runtime
/// based on automatic complexity scoring and prepared role availability.
@MainActor @Observable
final class TriageService {
    private static let localQwenBaselineSystemPrompt = """
    You are Epistemos' local Qwen assistant.
    Answer directly and concisely.
    Do not claim to have browsing, external tool use, research mode, or hidden capabilities you do not actually have.
    Do not claim to be a different model.
    If asked about your identity, say you are the local Epistemos assistant powered by Qwen.
    If the answer is uncertain, say so plainly instead of fabricating confidence.
    """

    private let inference: InferenceState
    private let localLLMService: (any LLMClientProtocol)?
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
            "as an ai",
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
            "as an apple",
        ]
        return patterns.contains { prefix.contains($0) }
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
        prepareForRouting: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        self.inference = inference
        self.localLLMService = localLLMService
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
        prepareForRouting()
        let decision = routeDecisionForNotes(
            operation: operation,
            contentLength: contentLength,
            query: query,
            localReasoningMode: localReasoningMode
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
        localReasoningMode: LocalReasoningMode? = nil
    ) -> AsyncThrowingStream<String, Error> {
        prepareForRouting()
        let decision = routeDecisionForNotes(
            operation: operation,
            contentLength: contentLength,
            query: query,
            localReasoningMode: localReasoningMode
        )
        let triageDecision = triageDecision(for: decision.selectedRoute)
        lastDecision = triageDecision
        Log.engine.info("Triage: \(operation.displayName) → \(triageDecision.label) (content: \(contentLength) chars)")

        switch triageDecision {
        case .appleIntelligence:
            return userFacingStream(
                appleIntelligenceStreamWithFallback(
                prompt: prompt,
                systemPrompt: systemPrompt,
                localSelection: decision.localSelection
                )
            )
        case .localMLX:
            return userFacingStream(
                localStreamOrFallback(
                prompt: prompt,
                systemPrompt: systemPrompt,
                selection: decision.localSelection
                )
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
        prepareForRouting()
        let decision = routeDecisionForNotes(
            operation: operation,
            contentLength: contentLength,
            query: query,
            localReasoningMode: localReasoningMode
        )
        let triageDecision = triageDecision(for: decision.selectedRoute)
        lastDecision = triageDecision
        Log.engine.info("Triage: \(operation.displayName) → \(triageDecision.label) (content: \(contentLength) chars)")

        switch triageDecision {
        case .appleIntelligence:
            let (aiPrompt, aiSystem) = Self.trimForAppleIntelligence(prompt: prompt, systemPrompt: systemPrompt)
            do {
                let result = try await AppleIntelligenceService.shared.generate(prompt: aiPrompt, systemPrompt: aiSystem)
                if Self.shouldRetryWithLocalModel(result) {
                    Log.engine.info("Apple Intelligence response inadequate, falling back to the local model path")
                    lastDecision = .localMLX
                    return UserFacingModelOutput.finalVisibleText(from: try await localGenerateOrFallback(
                        prompt: prompt,
                        systemPrompt: systemPrompt,
                        selection: decision.localSelection
                    ))
                }
                return UserFacingModelOutput.finalVisibleText(from: result)
            } catch {
                Log.engine.warning("Apple Intelligence failed, falling back to the local model path: \(error.localizedDescription, privacy: .public)")
                lastDecision = .localMLX
                return UserFacingModelOutput.finalVisibleText(from: try await localGenerateOrFallback(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    selection: decision.localSelection
                ))
            }
        case .localMLX:
            return UserFacingModelOutput.finalVisibleText(from: try await localGenerateOrFallback(
                prompt: prompt,
                systemPrompt: systemPrompt,
                selection: decision.localSelection
            ))
        }
    }

    // MARK: - General Triage Logic

    /// Routes a general operation to Apple Intelligence or the local model path.
    func triageGeneral(
        operation: GeneralOperation,
        contentLength: Int,
        localReasoningMode: LocalReasoningMode? = nil,
        localSurface: LocalModelSelectionSurface = .mainChat
    ) -> TriageDecision {
        prepareForRouting()
        let decision = routeDecisionForGeneral(
            operation: operation,
            contentLength: contentLength,
            localReasoningMode: localReasoningMode,
            localSurface: localSurface
        )
        return triageDecision(for: decision.selectedRoute)
    }

    func streamGeneral(
        prompt: String,
        systemPrompt: String? = nil,
        operation: GeneralOperation,
        contentLength: Int,
        localReasoningMode: LocalReasoningMode? = nil,
        localSurface: LocalModelSelectionSurface = .mainChat
    ) -> AsyncThrowingStream<String, Error> {
        prepareForRouting()
        let decision = routeDecisionForGeneral(
            operation: operation,
            contentLength: contentLength,
            localReasoningMode: localReasoningMode,
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
                systemPrompt: systemPrompt,
                localSelection: decision.localSelection
                )
            )
        case .localMLX:
            return userFacingStream(
                localStreamOrFallback(
                prompt: prompt,
                systemPrompt: systemPrompt,
                selection: decision.localSelection
                )
            )
        }
    }

    func generateGeneral(
        prompt: String,
        systemPrompt: String? = nil,
        operation: GeneralOperation,
        contentLength: Int,
        localReasoningMode: LocalReasoningMode? = nil,
        localSurface: LocalModelSelectionSurface = .mainChat
    ) async throws -> String {
        prepareForRouting()
        let decision = routeDecisionForGeneral(
            operation: operation,
            contentLength: contentLength,
            localReasoningMode: localReasoningMode,
            localSurface: localSurface
        )
        let triageDecision = triageDecision(for: decision.selectedRoute)
        lastDecision = triageDecision
        Log.engine.info("Triage: \(operation.displayName) → \(triageDecision.label) (content: \(contentLength) chars)")

        switch triageDecision {
        case .appleIntelligence:
            let (aiPrompt, aiSystem) = Self.trimForAppleIntelligence(prompt: prompt, systemPrompt: systemPrompt)
            do {
                let result = try await AppleIntelligenceService.shared.generate(prompt: aiPrompt, systemPrompt: aiSystem)
                if Self.shouldRetryWithLocalModel(result) {
                    Log.engine.info("Apple Intelligence response inadequate (general), falling back to the local model path")
                    lastDecision = .localMLX
                    return UserFacingModelOutput.finalVisibleText(from: try await localGenerateOrFallback(
                        prompt: prompt,
                        systemPrompt: systemPrompt,
                        selection: decision.localSelection
                    ))
                }
                return UserFacingModelOutput.finalVisibleText(from: result)
            } catch {
                Log.engine.warning("Apple Intelligence failed (general), falling back to the local model path: \(error.localizedDescription, privacy: .public)")
                lastDecision = .localMLX
                return UserFacingModelOutput.finalVisibleText(from: try await localGenerateOrFallback(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    selection: decision.localSelection
                ))
            }
        case .localMLX:
            return UserFacingModelOutput.finalVisibleText(from: try await localGenerateOrFallback(
                prompt: prompt,
                systemPrompt: systemPrompt,
                selection: decision.localSelection
            ))
        }
    }

    // MARK: - Apple Intelligence Stream with Fallback

    /// Streams from Apple Intelligence, falling back to the local model path seamlessly if:
    /// - Apple Intelligence throws an error (timeout, unavailable)
    /// - The response is a polite refusal ("I can't help with that")
    /// - The response appears truncated (stops mid-sentence)
    /// The user never sees the failed response — fallback replaces it entirely.
    private func appleIntelligenceStreamWithFallback(
        prompt: String,
        systemPrompt: String?,
        localSelection: LocalModelSelection?
    ) -> AsyncThrowingStream<String, Error> {
        let (aiPrompt, aiSystem) = Self.trimForAppleIntelligence(prompt: prompt, systemPrompt: systemPrompt)

        return AsyncThrowingStream { continuation in
            let task = Task { [weak self] in
                do {
                    let result = try await AppleIntelligenceService.shared.generate(
                        prompt: aiPrompt,
                        systemPrompt: aiSystem
                    )

                    // Check for refusal, truncation, or suspiciously short response
                    if Self.shouldRetryWithLocalModel(result) {
                        Log.engine.info("Apple Intelligence response inadequate (stream), falling back to the local model path")
                        await MainActor.run { self?.lastDecision = .localMLX }
                        do {
                            guard let self else {
                                continuation.finish(throwing: LocalInferenceRoutingError.runtimeUnavailable)
                                return
                            }
                            let fallbackStream = self.localStreamOrFallback(
                                prompt: prompt,
                                systemPrompt: systemPrompt,
                                selection: localSelection
                            )
                            for try await chunk in fallbackStream {
                                continuation.yield(chunk)
                            }
                            continuation.finish()
                        } catch {
                            Log.engine.info("Local model fallback also failed — using Apple Intelligence response")
                            continuation.yield(result)
                            continuation.finish()
                        }
                        return
                    }

                    continuation.yield(result)
                    continuation.finish()
                } catch {
                    Log.engine.warning("Apple Intelligence failed (stream), falling back to the local model path: \(error.localizedDescription, privacy: .public)")
                    await MainActor.run { self?.lastDecision = .localMLX }
                    do {
                        guard let self else {
                            continuation.finish(throwing: LocalInferenceRoutingError.runtimeUnavailable)
                            return
                        }
                        let fallbackStream = self.localStreamOrFallback(
                            prompt: prompt,
                            systemPrompt: systemPrompt,
                            selection: localSelection
                        )
                        for try await chunk in fallbackStream {
                            continuation.yield(chunk)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
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
        inference.routeDecision(
            for: requestProfileForNotes(
                operation: operation,
                contentLength: contentLength,
                query: query,
                localReasoningMode: localReasoningMode
            )
        )
    }

    private func routeDecisionForGeneral(
        operation: GeneralOperation,
        contentLength: Int,
        localReasoningMode: LocalReasoningMode?,
        localSurface: LocalModelSelectionSurface
    ) -> InferenceRouteDecision {
        inference.routeDecision(
            for: requestProfileForGeneral(
                operation: operation,
                contentLength: contentLength,
                localReasoningMode: localReasoningMode,
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
        let queryText: String
        if case .ask(let prompt) = operation, !prompt.isEmpty {
            queryText = prompt
        } else {
            queryText = query ?? ""
        }
        let analysis = queryText.isEmpty ? nil : QueryAnalyzer.analyze(query: queryText)
        let promptLength = max(contentLength, queryText.count)
        return InferenceRequestProfile(
            surface: .noteChat,
            intent: taskIntent(for: operation, queryText: queryText),
            contentLength: contentLength,
            promptLength: promptLength,
            contextBlockCount: contextBlockCount(
                contentLength: contentLength,
                promptLength: promptLength,
                surface: .noteChat
            ),
            estimatedTokenLoad: estimatedTokenLoad(
                contentLength: contentLength,
                promptLength: promptLength
            ),
            baseComplexity: operation.baseComplexity,
            queryComplexity: analysis?.complexity ?? 0,
            requestedReasoningMode: localReasoningMode ?? .fast,
            explicitThinkingRequested: localReasoningMode == .thinking,
            explicitFastRequested: localReasoningMode == .fast,
            visibleThinkingRequested: false
        )
    }

    private func requestProfileForGeneral(
        operation: GeneralOperation,
        contentLength: Int,
        localReasoningMode: LocalReasoningMode?,
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
            requestedReasoningMode: localReasoningMode ?? .fast,
            explicitThinkingRequested: localReasoningMode == .thinking,
            explicitFastRequested: localReasoningMode == .fast,
            visibleThinkingRequested: false
        )
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
        case .localQwen:
            .localMLX
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
        case .mainChat, .miniChat:
            divisor = 2_400
        case .noteChat:
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
            return inferredTaskIntent(from: queryText, surface: .noteChat)
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

    // MARK: - Local MLX Fallback

    private func localGenerateOrFallback(
        prompt: String,
        systemPrompt: String?,
        selection: LocalModelSelection?
    ) async throws -> String {
        guard let selection else {
            throw LocalInferenceRoutingError.modelRequired
        }
        guard let localLLMService else {
            throw LocalInferenceRoutingError.runtimeUnavailable
        }

        let effectiveSystemPrompt = Self.effectiveLocalSystemPrompt(systemPrompt)

        do {
            if let configurable = localLLMService as? any LocalConfigurableLLMClient {
                return try await configurable.generate(
                    prompt: prompt,
                    systemPrompt: effectiveSystemPrompt,
                    maxTokens: 0,
                    reasoningMode: selection.reasoningMode,
                    modelID: selection.modelID
                )
            }
            return try await localLLMService.generate(prompt: prompt, systemPrompt: effectiveSystemPrompt)
        } catch {
            throw error
        }
    }

    private func localStreamOrFallback(
        prompt: String,
        systemPrompt: String?,
        selection: LocalModelSelection?
    ) -> AsyncThrowingStream<String, Error> {
        guard let selection else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: LocalInferenceRoutingError.modelRequired)
            }
        }
        guard let localLLMService else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: LocalInferenceRoutingError.runtimeUnavailable)
            }
        }
        let effectiveSystemPrompt = Self.effectiveLocalSystemPrompt(systemPrompt)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let stream: AsyncThrowingStream<String, Error>
                    if let configurable = localLLMService as? any LocalConfigurableLLMClient {
                        stream = configurable.stream(
                            prompt: prompt,
                            systemPrompt: effectiveSystemPrompt,
                            maxTokens: 0,
                            reasoningMode: selection.reasoningMode,
                            modelID: selection.modelID
                        )
                    } else {
                        stream = localLLMService.stream(prompt: prompt, systemPrompt: effectiveSystemPrompt)
                    }
                    for try await chunk in stream {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func effectiveLocalSystemPrompt(_ systemPrompt: String?) -> String {
        guard let systemPrompt,
              !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return localQwenBaselineSystemPrompt
        }
        return "\(localQwenBaselineSystemPrompt)\n\n\(systemPrompt)"
    }

    private func userFacingStream(
        _ upstream: AsyncThrowingStream<String, Error>
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var rawText = ""
                var emittedVisibleText = ""

                do {
                    for try await chunk in upstream {
                        rawText += chunk
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
                        }
                    }

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

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
