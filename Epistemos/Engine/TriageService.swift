import Foundation
import Observation
import os

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
    case localMLX
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
    let routingMode: LocalRoutingMode
    let appleIntelligenceAvailable: Bool
    let cloudAutoRouteEnabled: Bool
    let hasConfiguredCloudModels: Bool
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

        if shouldAutoRouteToCloud(
            profile: profile,
            context: context,
            localSelection: localSelection.selection,
            complexityTier: complexityTier,
            reasonCodes: &reasonCodes
        ) {
            return InferenceRouteDecision(
                selectedRoute: .cloud,
                selectedReasoningMode: localSelection.selection?.reasoningMode ?? reasoningMode(
                    for: profile,
                    complexityTier: complexityTier,
                    contextTier: contextTier
                ),
                localSelection: localSelection.selection,
                reuseWarmModel: false,
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
        if selectedReasoningMode == .fast, preferredModel.cannotDisableThinkingInFast {
            return nil
        }
        return LocalModelSelection(
            modelID: preferredModel.rawValue,
            reasoningMode: selectedReasoningMode,
            contentBudget: context.hardwareCapabilitySnapshot.recommendedLocalContentLength(
                for: preferredModel,
                conditions: context.runtimeConditions,
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
        let selectedReasoningMode = reasoningMode(
            for: profile,
            complexityTier: complexityTier,
            contextTier: contextTier
        )
        let installedModels = supportedInstalledModels(in: context)
        guard !installedModels.isEmpty else {
            reasonCodes.insert(.noInstalledLocalModel)
            return (nil, false)
        }

        if shouldUseAutomaticLocalRouting(for: context) {
            return (
                automaticLocalSelection(
                    for: profile,
                    context: context,
                    installedModels: installedModels,
                    reasoningMode: selectedReasoningMode,
                    complexityTier: complexityTier,
                    contextTier: contextTier
                ),
                false
            )
        }

        let preferred = resolvedPreferredLocalSelection(
            in: context,
            reasoningMode: selectedReasoningMode
        )
        if preferred != nil {
            reasonCodes.insert(.preferredLocalModelUsed)
            return (preferred, false)
        }

        reasonCodes.insert(.preferredLocalModelUnavailable)
        return (
            automaticLocalSelection(
                for: profile,
                context: context,
                installedModels: installedModels,
                reasoningMode: selectedReasoningMode,
                complexityTier: complexityTier,
                contextTier: contextTier
            ),
            false
        )
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

    private func localRouteKind(
        for selection: LocalModelSelection?,
        context: InferencePolicyContext
    ) -> InferenceRouteKind {
        _ = selection
        _ = context
        return .localMLX
    }

    private func explicitRoute(
        for profile: InferenceRequestProfile,
        context: InferencePolicyContext,
        localSelection: LocalModelSelection?
    ) -> InferenceRouteKind? {
        _ = profile
        switch context.preferredChatModelSelection {
        case .appleIntelligence:
            return context.appleIntelligenceAvailable ? .appleIntelligence : nil
        case .localMLX(_):
            return localSelection != nil ? .localMLX : nil
        case .cloud(_):
            return .cloud
        }
    }

    private func shouldAutoRouteToCloud(
        profile: InferenceRequestProfile,
        context: InferencePolicyContext,
        localSelection: LocalModelSelection?,
        complexityTier: InferenceComplexityTier,
        reasonCodes: inout Set<InferenceDecisionReasonCode>
    ) -> Bool {
        guard context.cloudAutoRouteEnabled,
              context.hasConfiguredCloudModels else {
            return false
        }

        switch profile.operatingMode {
        case .pro, .agent:
            reasonCodes.insert(.cloudAutoRoute)
            return true
        case .thinking:
            if localSelection == nil || complexityTier == .extreme {
                reasonCodes.insert(.cloudAutoRoute)
                return true
            }
            return false
        case .fast:
            if localSelection == nil && !context.appleIntelligenceAvailable {
                reasonCodes.insert(.cloudAutoRoute)
                return true
            }
            return false
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
        let installedModels = context.installedLocalTextModelIDs
            .compactMap(LocalTextModelID.init(rawValue:))
            .filter {
                context.hardwareCapabilitySnapshot.supportsInteractiveChatModel(textModelID: $0.rawValue)
                    && !$0.isExperimentalForEpistemos
            }
            .sorted { lhs, rhs in
                lhs.minimumRecommendedMemoryGB < rhs.minimumRecommendedMemoryGB
            }
        let shippedModels = installedModels.filter(\.isEpistemosShippedLocalModel)
        return shippedModels.isEmpty ? installedModels : shippedModels
    }

    private func shouldUseAutomaticLocalRouting(for context: InferencePolicyContext) -> Bool {
        switch context.preferredChatModelSelection {
        case .localMLX:
            return false
        case .appleIntelligence, .cloud:
            return true
        }
    }

    private func automaticLocalSelection(
        for profile: InferenceRequestProfile,
        context: InferencePolicyContext,
        installedModels: [LocalTextModelID],
        reasoningMode: LocalReasoningMode,
        complexityTier: InferenceComplexityTier,
        contextTier: InferenceContextTier
    ) -> LocalModelSelection? {
        guard let model = preferredAutomaticLocalModel(
            for: profile,
            installedModels: installedModels,
            reasoningMode: reasoningMode,
            complexityTier: complexityTier,
            contextTier: contextTier
        ) else {
            return nil
        }

        let effectiveReasoningMode: LocalReasoningMode = {
            guard reasoningMode == .thinking else { return .fast }
            return model.supportsThinkingMode ? .thinking : .fast
        }()

        return LocalModelSelection(
            modelID: model.rawValue,
            reasoningMode: effectiveReasoningMode,
            contentBudget: context.hardwareCapabilitySnapshot.recommendedLocalContentLength(
                for: model,
                conditions: context.runtimeConditions,
                reasoningMode: effectiveReasoningMode
            )
        )
    }

    private func preferredAutomaticLocalModel(
        for profile: InferenceRequestProfile,
        installedModels: [LocalTextModelID],
        reasoningMode: LocalReasoningMode,
        complexityTier: InferenceComplexityTier,
        contextTier: InferenceContextTier
    ) -> LocalTextModelID? {
        let oversizedContext = contextTier == .oversized || profile.contextBlockCount >= 6
        let heavyWork = complexityTier == .heavy || complexityTier == .extreme
        let candidateModels: [LocalTextModelID]
        switch profile.operatingMode {
        case .agent:
            candidateModels = installedModels.filter(\.canRunLocalAgentLoop)
        default:
            if reasoningMode == .thinking {
                candidateModels = installedModels.filter(\.supportsThinkingMode)
            } else {
                candidateModels = installedModels
            }
        }
        let fastEligibleCandidateModels =
            reasoningMode == .fast
            ? candidateModels.filter { !$0.cannotDisableThinkingInFast }
            : candidateModels
        if reasoningMode == .fast && fastEligibleCandidateModels.isEmpty {
            return nil
        }
        let effectiveCandidateModels =
            reasoningMode == .fast ? fastEligibleCandidateModels : candidateModels
        guard !effectiveCandidateModels.isEmpty else {
            return nil
        }

        // Stack refresh 2026-04-18 (see docs/MASTER_MODEL_STACK_PLAN.md).
        // Preferred orders now prefer, in priority order:
        //   - Qwen 3 Coder Next / 30B A3B for coding (Qwen 3 generation
        //     with native tool-calling).
        //   - DeepSeek R1 7B for reasoning (until OpenThinker3-7B is
        //     converted to MLX 4-bit and lands next session).
        //   - Hermes 4.3 36B for on-device agent/function-calling work.
        //   - Qwen 3.6 35B A3B (Unsloth UD preferred, DWQ secondary) for
        //     flagship generalist.
        //   - Qwen 3 4B + Bonsai for fast/light work.
        // Gemma 4 family remains excluded from every automatic order
        // until the MLX-Swift Gemma 4 loader is ported from
        // SharpAI/SwiftLM (tracked in MASTER_MODEL_STACK_PLAN §3a).
        // Legacy mlx-community Qwen 3.6 4-bit stays as the last-resort
        // installed fallback so existing installs don't break. Qwen 2.5
        // Coder 7B is held out while the freeze mitigation is active.
        let preferredOrder: [LocalTextModelID]
        switch profile.operatingMode {
        case .agent:
            switch profile.intent {
            case .coding, .debugging:
                preferredOrder = [
                    .qwen3Coder30BA3B4Bit, .qwen3CoderNext4Bit,
                    .hermes43_36B4Bit, .hermes43_36B3Bit,
                    .deepseekR1Distill7B,
                ]
            default:
                preferredOrder = [
                    .hermes43_36B4Bit, .hermes43_36B3Bit,
                    .qwen36_35BA3B_Unsloth4Bit, .qwen36_35BA3B_DWQ4Bit,
                    .qwen3Coder30BA3B4Bit, .deepseekR1Distill7B,
                ]
            }
        case .pro:
            switch profile.intent {
            case .coding, .debugging:
                preferredOrder = [
                    .qwen3Coder30BA3B4Bit, .qwen3CoderNext4Bit,
                    .qwen36_35BA3B_Unsloth4Bit, .qwen36_35BA3B_DWQ4Bit,
                    .deepseekR1Distill7B,
                ]
            default:
                preferredOrder = [
                    .qwen36_35BA3B_Unsloth4Bit, .qwen36_35BA3B_DWQ4Bit,
                    .deepseekR1Distill7B, .hermes43_36B4Bit,
                    .qwen3_4B4Bit,
                ]
            }
        case .thinking:
            switch profile.intent {
            case .coding, .debugging:
                preferredOrder = [
                    .qwqFlagship32B4Bit, .deepseekR1Distill7B,
                    .qwen3Coder30BA3B4Bit,
                    .qwen36_35BA3B_Unsloth4Bit, .qwen36_35BA3B_DWQ4Bit,
                ]
            default:
                preferredOrder = [
                    // QwQ 32B leads thinking mode — comparable reasoning
                    // quality to DeepSeek R1 at 32B on harder prompts.
                    .qwqFlagship32B4Bit, .deepseekR1Distill7B,
                    .qwen36_35BA3B_Unsloth4Bit, .qwen36_35BA3B_DWQ4Bit,
                    .qwen3_4B4Bit,
                ]
            }
        case .fast:
            switch profile.intent {
            case .coding, .debugging:
                preferredOrder = [
                    .qwen3CoderNext4Bit, .qwen3Coder30BA3B4Bit,
                    .deepseekR1Distill7B,
                    .qwen3_4B4Bit, .bonsai8B2Bit, .bonsai4B2Bit,
                ]
            case .comparison, .synthesis, .noteAnalysis, .graphAnalysis:
                preferredOrder = [
                    .deepseekR1Distill7B,
                    .qwen36_35BA3B_Unsloth4Bit, .qwen36_35BA3B_DWQ4Bit,
                    .qwen3_4B4Bit, .qwen3CoderNext4Bit,
                    .bonsai8B2Bit, .bonsai4B2Bit,
                ]
            case .rewrite, .summarize, .simpleAsk, .brainstorm:
                if oversizedContext || heavyWork {
                    preferredOrder = [
                        .qwen36_35BA3B_Unsloth4Bit, .qwen36_35BA3B_DWQ4Bit,
                        .deepseekR1Distill7B, .qwen3_4B4Bit,
                        .bonsai8B2Bit, .bonsai4B2Bit,
                    ]
                } else {
                    preferredOrder = [
                        .qwen3_4B4Bit, .bonsai4B2Bit, .bonsai8B2Bit,
                        .deepseekR1Distill7B,
                        .qwen36_35BA3B_Unsloth4Bit, .qwen36_35BA3B_DWQ4Bit,
                    ]
                }
            }
        }

        for candidate in preferredOrder where effectiveCandidateModels.contains(candidate) {
            if reasoningMode != .thinking || candidate.supportsThinkingMode {
                return candidate
            }
        }

        // Triage-ready candidates: same as the input list minus families we
        // know cannot load today. Right now this is the Gemma 4 family —
        // mlx-swift-lm has no Gemma 4 config decoder, so letting the
        // shipped-fallback pick a Gemma 4 tier would reproduce the user-
        // visible "Unsupported model type: gemma4" error even when the
        // preferredOrder above successfully demotes it. Qwen 3.6 / Qwen
        // Coder / DeepSeek R1 / Bonsai all load cleanly so they're safe
        // fallback picks. When the Gemma 4 decoder ships, drop this
        // filter and restore Gemma 4 to preferredOrder at the top of
        // this function.
        let triageReadyCandidates = effectiveCandidateModels.filter { candidate in
            switch candidate {
            case .gemma4_2B4Bit, .gemma4_4B4Bit, .gemma4_27BA4B4Bit, .gemma4_31BJANG:
                return false
            default:
                return true
            }
        }

        if let shippedInstalled = triageReadyCandidates.first(where: \.isEpistemosShippedLocalModel) {
            return shippedInstalled
        }
        return triageReadyCandidates.first ?? effectiveCandidateModels.first
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
    case cloud

    var isOnDevice: Bool {
        switch self {
        case .appleIntelligence, .localMLX:
            true
        case .cloud:
            false
        }
    }

    var label: String {
        switch self {
        case .appleIntelligence: "On-device"
        case .localMLX:          "Local Model"
        case .cloud:             "Cloud Model"
        }
    }

    var icon: String {
        switch self {
        case .appleIntelligence: "cpu"
        case .localMLX:          "memorychip"
        case .cloud:             "cloud"
        }
    }
}

nonisolated enum LocalInferenceRoutingError: LocalizedError, Equatable {
    case modelRequired
    case runtimeUnavailable
    case fastModeUnsupported(modelID: String)
    /// Thrown when code tries to load a model whose Swift MLX decoder
    /// isn't ported yet (see `LocalTextModelID.isAwaitingSwiftRuntimeLoader`
    /// — currently the Gemma 4 family). Distinct from
    /// `runtimeUnavailable` so the UI can surface a clearer message than
    /// the opaque "Unsupported model type: gemma4" that mlx-swift-lm
    /// would otherwise emit.
    case modelLoaderUnavailable(modelID: String)
    /// Thrown when a local model never finishes loading into memory. This is
    /// distinct from a generic request timeout so the chat can tell the user
    /// the model load stalled and suggest a smaller model.
    case modelLoadStalled(modelID: String)
    /// Thrown BEFORE we ask MLX to load a model when the OS says we don't have
    /// enough available unified memory to hold it. Refusing up-front beats the
    /// alternative (SSD swap thrash, hard freeze, or a jetsam kill) by a mile.
    case insufficientMemory(modelID: String, requiredGB: Int, availableGB: Int)

    var errorDescription: String? {
        switch self {
        case .modelRequired:
            return "No usable local model is available. Open Settings and install or select a supported local model."
        case .runtimeUnavailable:
            return "The local model runtime is unavailable right now. Reopen the app or re-enable the local model in Settings."
        case .fastModeUnsupported(let modelID):
            let displayName = LocalTextModelID(rawValue: modelID)?.displayName ?? modelID
            return "Fast mode is unavailable for \(displayName) because this local model always emits thinking traces. Switch to Thinking or pick a different local model."
        case .modelLoaderUnavailable(let modelID):
            return "The \(modelID) loader hasn't shipped yet. Pick a different local model in Settings → Inference — Qwen 3 4B and DeepSeek R1 7B are solid defaults."
        case .modelLoadStalled(let modelID):
            let displayName = LocalTextModelID(rawValue: modelID)?.displayName ?? modelID
            return "The \(displayName) model couldn't finish loading. Try restarting the app or switch to a smaller local model like Qwen 3 4B."
        case .insufficientMemory(let modelID, let requiredGB, let availableGB):
            let displayName = LocalTextModelID(rawValue: modelID)?.displayName ?? modelID
            return "\(displayName) needs about \(requiredGB) GB of free memory but only \(availableGB) GB is available right now. Close some apps, reduce open notes, or pick a smaller local model like Qwen 3 4B."
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
    private static let localMLXBaselineSystemPrompt = """
    You are Epistemos' local on-device assistant.
    Answer directly and concisely.
    Do not narrate tool plans, function calls, or internal reasoning in the visible answer.
    Do not claim to have browsing, external tool use, research mode, or hidden capabilities you do not actually have.
    Do not claim to be a different model.
    If asked about your identity, say you are the local Epistemos assistant running on-device.
    If the answer is uncertain, say so plainly instead of fabricating confidence.
    """

    /// Shorter system prompt for abliterated models (JANG, etc.).
    /// No refusal-coaching lines that conflict with the model's fine-tuning.
    private static let localAbliteratedBaselineSystemPrompt = """
    You are Epistemos' local on-device assistant.
    Answer directly and concisely.
    """

    private static let cloudBaselineSystemPrompt = """
    You are a helpful assistant inside Epistemos, a personal knowledge management app.
    Answer directly and concisely.
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
                systemPrompt: systemPrompt,
                localSelection: decision.localSelection
                ),
                reasoningSink: reasoningSink
            )
        case .localMLX:
            return userFacingStream(
                localStreamOrFallback(
                prompt: prompt,
                systemPrompt: systemPrompt,
                selection: decision.localSelection
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
                reasoningSink: reasoningSink
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

    // MARK: - Raw Local Generation (for Knowledge Fusion pipeline)

    /// Generates text using the local model directly, returning raw output without
    /// `finalVisibleText` stripping. Used by the Knowledge Fusion synthetic data
    /// pipeline where we need the full model response including structured content.
    func generateRawLocal(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int = 0,
        modelID: String? = nil
    ) async throws -> String {
        guard let localLLMService else {
            throw LocalInferenceRoutingError.runtimeUnavailable
        }
        let effectiveSystemPrompt = Self.effectiveLocalSystemPrompt(
            systemPrompt,
            modelID: modelID,
            reasoningMode: .fast
        )
        if let configurable = localLLMService as? any LocalConfigurableLLMClient {
            return try await configurable.generate(
                prompt: prompt,
                systemPrompt: effectiveSystemPrompt,
                maxTokens: maxTokens,
                reasoningMode: .fast,
                modelID: modelID
            )
        }
        return try await localLLMService.generate(prompt: prompt, systemPrompt: effectiveSystemPrompt)
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
                systemPrompt: systemPrompt,
                localSelection: decision.localSelection,
                steeringHintsJSON: steeringHintsJSON
                ),
                reasoningSink: reasoningSink
            )
        case .localMLX:
            return userFacingStream(
                localStreamOrFallback(
                prompt: prompt,
                systemPrompt: systemPrompt,
                selection: decision.localSelection,
                steeringHintsJSON: steeringHintsJSON
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
                reasoningSink: reasoningSink
            )
        }
    }

    func streamGeneralLocally(
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
        lastDecision = .localMLX
        Log.engine.info("Triage: \(operation.displayName) → Local Model (forced local execution) (content: \(contentLength) chars)")
        return userFacingStream(
            localStreamOrFallback(
                prompt: prompt,
                systemPrompt: systemPrompt,
                selection: decision.localSelection,
                steeringHintsJSON: steeringHintsJSON
            ),
            reasoningSink: reasoningSink
        )
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
            do {
                let result = try await AppleIntelligenceService.shared.generate(prompt: aiPrompt, systemPrompt: aiSystem)
                if Self.shouldRetryWithLocalModel(result) {
                    Log.engine.info("Apple Intelligence response inadequate (general), falling back to the local model path")
                    lastDecision = .localMLX
                    return UserFacingModelOutput.finalVisibleText(from: try await localGenerateOrFallback(
                        prompt: prompt,
                        systemPrompt: systemPrompt,
                        selection: decision.localSelection,
                        steeringHintsJSON: steeringHintsJSON
                    ))
                }
                return UserFacingModelOutput.finalVisibleText(from: result)
            } catch {
                Log.engine.warning("Apple Intelligence failed (general), falling back to the local model path: \(error.localizedDescription, privacy: .public)")
                lastDecision = .localMLX
                return UserFacingModelOutput.finalVisibleText(from: try await localGenerateOrFallback(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    selection: decision.localSelection,
                    steeringHintsJSON: steeringHintsJSON
                ))
            }
        case .localMLX:
            return UserFacingModelOutput.finalVisibleText(from: try await localGenerateOrFallback(
                prompt: prompt,
                systemPrompt: systemPrompt,
                selection: decision.localSelection,
                steeringHintsJSON: steeringHintsJSON
            ))
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

    /// Streams from Apple Intelligence, falling back to the local model path seamlessly if:
    /// - Apple Intelligence throws an error (timeout, unavailable)
    /// - The response is a polite refusal ("I can't help with that")
    /// - The response appears truncated (stops mid-sentence)
    /// The user never sees the failed response — fallback replaces it entirely.
    private func appleIntelligenceStreamWithFallback(
        prompt: String,
        systemPrompt: String?,
        localSelection: LocalModelSelection?,
        steeringHintsJSON: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        let (aiPrompt, aiSystem) = Self.trimForAppleIntelligence(prompt: prompt, systemPrompt: systemPrompt)

        return StreamingBufferPolicy.throwingStream { continuation in
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
                                selection: localSelection,
                                steeringHintsJSON: steeringHintsJSON
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
                            selection: localSelection,
                            steeringHintsJSON: steeringHintsJSON
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
        case .localMLX:
            .localMLX
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

    private func generateWithCloudFallbackChain(
        prompt: String,
        systemPrompt: String?,
        operatingMode: EpistemosOperatingMode,
        localSelection: LocalModelSelection?,
        steeringHintsJSON: String? = nil
    ) async throws -> String {
        let fallbackChain = inference.cloudFallbackChain(for: operatingMode)
        let useAutoFallback = inference.cloudAutoFallback
        let modelsToTry = useAutoFallback ? fallbackChain : Array(fallbackChain.prefix(1))
        var lastCloudError: Error?

        for model in modelsToTry {
            do {
                lastDecision = .cloud
                return try await cloudGenerate(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    model: model,
                    operatingMode: operatingMode
                )
            } catch {
                lastCloudError = error
                Log.engine.warning(
                    "Cloud route \(model.vendorModelID, privacy: .public) failed, trying the next fallback: \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        guard useAutoFallback else {
            if let cloudError = lastCloudError as? CloudLLMError {
                throw cloudError
            }
            if let llmError = lastCloudError as? LLMError {
                throw llmError
            }

            let modelName = modelsToTry.first?.vendorModelID ?? "unknown"
            let reason = lastCloudError?.localizedDescription ?? "Unknown error"
            throw CloudRoutingError.modelFailed("\(modelName) failed: \(reason)")
        }

        var lastLocalError: Error?

        if localSelection != nil {
            do {
                lastDecision = .localMLX
                return try await localGenerateOrFallback(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    selection: localSelection,
                    steeringHintsJSON: steeringHintsJSON
                )
            } catch {
                lastLocalError = error
                Log.engine.warning(
                    "Local fallback failed after cloud retries, trying Apple Intelligence next: \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        if inference.appleIntelligenceAvailable {
            let (aiPrompt, aiSystem) = Self.trimForAppleIntelligence(prompt: prompt, systemPrompt: systemPrompt)
            do {
                let result = try await AppleIntelligenceService.shared.generate(prompt: aiPrompt, systemPrompt: aiSystem)
                if !Self.shouldRetryWithLocalModel(result) {
                    lastDecision = .appleIntelligence
                    return result
                }
                Log.engine.info("Apple Intelligence fallback response was inadequate after cloud/local retries")
            } catch {
                Log.engine.warning(
                    "Apple Intelligence fallback failed after cloud/local retries: \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        if let lastLocalError {
            throw lastLocalError
        }
        if let lastCloudError {
            throw lastCloudError
        }
        throw LocalInferenceRoutingError.modelRequired
    }

    private func streamWithCloudFallbackChain(
        prompt: String,
        systemPrompt: String?,
        operatingMode: EpistemosOperatingMode,
        localSelection: LocalModelSelection?,
        steeringHintsJSON: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        StreamingBufferPolicy.throwingStream { continuation in
            let task = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }

                let fallbackChain = self.inference.cloudFallbackChain(for: operatingMode)
                let useAutoFallback = self.inference.cloudAutoFallback

                // In manual mode, only try the first model (the user's selection).
                // In auto mode, try all models in the fallback chain.
                let modelsToTry = useAutoFallback ? fallbackChain : Array(fallbackChain.prefix(1))
                var lastCloudError: Error?

                for model in modelsToTry {
                    var emittedAnyTokens = false
                    do {
                        self.lastDecision = .cloud
                        Log.engine.info("Cloud request → \(model.vendorModelID, privacy: .public) (\(model.provider.displayName, privacy: .public))")
                        let stream = self.cloudStream(
                            prompt: prompt,
                            systemPrompt: systemPrompt,
                            model: model,
                            operatingMode: operatingMode
                        )
                        for try await chunk in stream {
                            emittedAnyTokens = true
                            continuation.yield(chunk)
                        }
                        continuation.finish()
                        return
                    } catch {
                        lastCloudError = error
                        if emittedAnyTokens {
                            continuation.finish(throwing: error)
                            return
                        }
                        Log.engine.warning(
                            "Cloud stream route \(model.vendorModelID, privacy: .public) failed before yielding output: \(error.localizedDescription, privacy: .public)"
                        )
                    }
                }

                // Manual mode: fail with descriptive error, no silent fallback
                guard useAutoFallback else {
                    if let cloudError = lastCloudError as? CloudLLMError {
                        continuation.finish(throwing: cloudError)
                        return
                    }
                    if let llmError = lastCloudError as? LLMError {
                        continuation.finish(throwing: llmError)
                        return
                    }

                    let modelName = modelsToTry.first?.vendorModelID ?? "unknown"
                    let reason = lastCloudError?.localizedDescription ?? "Unknown error"
                    let message = """
                    \(modelName) failed: \(reason)

                    Suggestions:
                    • Check your API key in Settings → AI
                    • Verify your account has access to this model
                    • Enable "Auto-route" in Settings to try other models automatically
                    """
                    continuation.finish(throwing: CloudRoutingError.modelFailed(message))
                    return
                }

                var lastLocalError: Error?
                if localSelection != nil {
                    self.lastDecision = .localMLX
                    let localFallback = self.localStreamOrFallback(
                        prompt: prompt,
                        systemPrompt: systemPrompt,
                        selection: localSelection,
                        steeringHintsJSON: steeringHintsJSON
                    )
                    var emittedLocalTokens = false
                    do {
                        for try await chunk in localFallback {
                            emittedLocalTokens = true
                            continuation.yield(chunk)
                        }
                        continuation.finish()
                        return
                    } catch {
                        lastLocalError = error
                        if emittedLocalTokens {
                            continuation.finish(throwing: error)
                            return
                        }
                        Log.engine.warning(
                            "Local stream fallback failed after cloud retries, trying Apple Intelligence next: \(error.localizedDescription, privacy: .public)"
                        )
                    }
                }

                if self.inference.appleIntelligenceAvailable {
                    self.lastDecision = .appleIntelligence
                    let appleFallback = self.appleIntelligenceStreamWithFallback(
                        prompt: prompt,
                        systemPrompt: systemPrompt,
                        localSelection: lastLocalError == nil ? localSelection : nil,
                        steeringHintsJSON: steeringHintsJSON
                    )
                    do {
                        for try await chunk in appleFallback {
                            continuation.yield(chunk)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                    return
                }

                continuation.finish(throwing: lastLocalError ?? lastCloudError ?? LocalInferenceRoutingError.modelRequired)
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Local MLX Fallback

    private func localGenerateOrFallback(
        prompt: String,
        systemPrompt: String?,
        selection: LocalModelSelection?,
        steeringHintsJSON: String? = nil
    ) async throws -> String {
        guard let selection else {
            throw LocalInferenceRoutingError.modelRequired
        }
        guard let localLLMService else {
            throw LocalInferenceRoutingError.runtimeUnavailable
        }

        let effectiveSystemPrompt = Self.effectiveLocalSystemPrompt(
            systemPrompt,
            modelID: selection.modelID,
            reasoningMode: selection.reasoningMode
        )

        do {
            if let configurable = localLLMService as? any LocalConfigurableLLMClient {
                return try await configurable.generate(
                    prompt: prompt,
                    systemPrompt: effectiveSystemPrompt,
                    maxTokens: resolvedLocalOutputTokens(for: selection.reasoningMode),
                    reasoningMode: selection.reasoningMode,
                    modelID: selection.modelID,
                    steeringHintsJSON: steeringHintsJSON
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
        selection: LocalModelSelection?,
        steeringHintsJSON: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        // If local isn't available, fall back to Apple Intelligence (on-device
        // and always present on macOS 26+ after the system model is downloaded).
        // This means a user with no configured local model and no cloud key
        // still gets a real answer instead of an opaque "modelRequired" error.
        guard let selection else {
            if inference.appleIntelligenceAvailable {
                return appleIntelligenceOnlyStream(prompt: prompt, systemPrompt: systemPrompt)
            }
            return StreamingBufferPolicy.throwingStream { continuation in
                continuation.finish(throwing: LocalInferenceRoutingError.modelRequired)
            }
        }
        guard let localLLMService else {
            if inference.appleIntelligenceAvailable {
                return appleIntelligenceOnlyStream(prompt: prompt, systemPrompt: systemPrompt)
            }
            return StreamingBufferPolicy.throwingStream { continuation in
                continuation.finish(throwing: LocalInferenceRoutingError.runtimeUnavailable)
            }
        }
        let resolvedLocalLLMService = localLLMService
        let effectiveSystemPrompt = Self.effectiveLocalSystemPrompt(
            systemPrompt,
            modelID: selection.modelID,
            reasoningMode: selection.reasoningMode
        )
        return StreamingBufferPolicy.throwingStream { continuation in
            let task = Task {
                do {
                    let stream: AsyncThrowingStream<String, Error>
                    if let configurable = resolvedLocalLLMService as? any LocalConfigurableLLMClient {
                        stream = configurable.stream(
                            prompt: prompt,
                            systemPrompt: effectiveSystemPrompt,
                            maxTokens: self.resolvedLocalOutputTokens(for: selection.reasoningMode),
                            reasoningMode: selection.reasoningMode,
                            modelID: selection.modelID,
                            steeringHintsJSON: steeringHintsJSON
                        )
                    } else {
                        stream = resolvedLocalLLMService.stream(prompt: prompt, systemPrompt: effectiveSystemPrompt)
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

    private static func effectiveLocalSystemPrompt(
        _ systemPrompt: String?,
        modelID: String? = nil,
        reasoningMode: LocalReasoningMode = .fast
    ) -> String {
        // Use shorter prompt for abliterated models (no refusal-coaching needed)
        let baseline: String
        if let modelID,
           LocalTextModelID(rawValue: modelID)?.isAbliterated == true {
            baseline = localAbliteratedBaselineSystemPrompt
        } else {
            baseline = localMLXBaselineSystemPrompt
        }
        var parts = [baseline]
        if reasoningMode == .fast {
            parts.append("If your template supports it, treat this turn as /no_think and return only the final answer.")
        }
        guard let systemPrompt,
              !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return parts.joined(separator: "\n\n")
        }
        parts.append(systemPrompt)
        return parts.joined(separator: "\n\n")
    }

    private func userFacingStream(
        _ upstream: AsyncThrowingStream<String, Error>,
        reasoningSink: (@MainActor @Sendable (String) -> Void)? = nil
    ) -> AsyncThrowingStream<String, Error> {
        StreamingBufferPolicy.throwingStream(limit: StreamingBufferPolicy.textLimit) { continuation in
            let task = Task {
                var rawText = ""
                var emittedVisibleText = ""
                var emittedInferredReasoningText = ""
                var reasoningRouter = ThinkTagStreamRouter()
                var sawExplicitThinkingTags = false

                do {
                    for try await chunk in upstream {
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

    private func resolvedLocalOutputTokens(for reasoningMode: LocalReasoningMode) -> Int {
        if inference.chatOutputTokens > 0 {
            return inference.chatOutputTokens
        }
        switch reasoningMode {
        case .fast:
            return 4_096
        case .thinking:
            return 8_192
        }
    }
}
