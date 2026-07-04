import Foundation

// Surface A — wave quick chat (Plan 1-MAS §2). Shared model types for the
// local-only engines: Apple Foundation Models (zero-download, gated) and the
// embedded llama.cpp GGUF lane (opt-in download). No cloud, no account, no
// agent furniture on this surface (§3.4 anti-mixing).

nonisolated enum QuickChatEngineID: Sendable, Equatable, Hashable {
    case appleFM
    case localGGUF(modelID: String)

    var displayName: String {
        switch self {
        case .appleFM:
            return "Apple Intelligence"
        case .localGGUF(let modelID):
            return GGUFModelCatalog.entry(id: modelID)?.displayName ?? modelID
        }
    }
}

nonisolated enum QuickChatFinishReason: String, Sendable, Equatable {
    case complete
    case maxTokens
    case contextFull
    case cancelled
}

nonisolated struct QuickChatCompletion: Sendable, Equatable {
    let engine: QuickChatEngineID
    let finishReason: QuickChatFinishReason
    let fullText: String
}

nonisolated enum QuickChatEvent: Sendable, Equatable {
    case delta(String)
    /// The FM lane refused (guardrails) or died mid-flight and the router
    /// switched engines. Surfaces as honest inline copy, never silence (§0.6).
    case engineFellBack(from: QuickChatEngineID, to: QuickChatEngineID, reason: String)
    case finished(QuickChatCompletion)
}

nonisolated enum QuickChatEngineUnavailable: Error, Sendable, Equatable {
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case noLocalModelInstalled
    case insufficientMemory(requiredGB: Double, availableGB: Double)

    /// Honest user copy (strings match AppleIntelligenceService's wording so
    /// the two surfaces never disagree about why FM is off).
    var userCopy: String {
        switch self {
        case .deviceNotEligible:
            return "This device is not eligible for Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is not enabled. Turn it on in System Settings → Apple Intelligence & Siri."
        case .modelNotReady:
            return "The on-device model is still downloading. Please try again later."
        case .noLocalModelInstalled:
            return "No local model is installed yet. Download one to chat privately on this Mac."
        case .insufficientMemory(let required, let available):
            return String(
                format: "This model needs about %.1f GB free memory; only %.1f GB is safely available.",
                required, available
            )
        }
    }
}

nonisolated enum QuickChatError: Error, Sendable, Equatable {
    /// Apple FM guardrails threw on legitimate content — the documented
    /// fallback trigger (§2.1): the router retries on the GGUF lane.
    case guardrailBlocked
    case exceededContextWindow
    case engineUnavailable(QuickChatEngineUnavailable)
    case generationFailed(String)
}
