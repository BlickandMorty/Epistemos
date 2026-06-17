import Foundation

/// The three user-facing Epistemos tiers. Each maps to a curated GGUF model
/// group on the proven llama-cli lane:
///   - Fast  → Gemma 4 (E2B / E4B / 12B, picked by task complexity)
///   - Think → VibeThinker 3B (compact reasoning)
///   - Code  → Gemma 4 12B Coder
///
/// This is the single source of truth the simplified lineup is built on: the
/// honest Settings display, the foundation-package install, and the mode→model
/// binding all read tiers from here rather than hardcoding model ids.
nonisolated enum EpistemosModelTier: String, Codable, Sendable, CaseIterable {
    case fast
    case think
    case code

    /// Branded label shown in the mode picker and Settings.
    var displayName: String {
        switch self {
        case .fast: "Epistemos Fast"
        case .think: "Epistemos Think"
        case .code: "Epistemos Code"
        }
    }

    /// Short label for compact chips.
    var shortName: String {
        switch self {
        case .fast: "Fast"
        case .think: "Think"
        case .code: "Code"
        }
    }

    /// One-line honest description of what the tier is for and which model backs it.
    var tagline: String {
        switch self {
        case .fast: "Quick answers — Gemma 4, sized to the task (2B / 4B / 12B)."
        case .think: "Deeper reasoning — VibeThinker 3B."
        case .code: "Coding — Gemma 4 12B Coder."
        }
    }

    var systemImage: String {
        switch self {
        case .fast: "bolt.fill"
        case .think: "brain"
        case .code: "chevron.left.forwardslash.chevron.right"
        }
    }
}

extension GemmaQATRuntimeStage {
    /// The Epistemos tier a GGUF runtime stage belongs to. Tier is *derived*
    /// from stage so the lineup auto-stays-in-sync with
    /// `GemmaQATRuntimeLadder.candidates` — there is no duplicate id list to
    /// drift. The three Gemma size lanes collapse into the single Fast tier
    /// (complexity routing picks the size); the coder and reasoner each own a
    /// tier.
    ///
    /// `nonisolated` so the `nonisolated` lineup helpers below can read it under
    /// the module's default-MainActor isolation (it's a pure stage→tier map).
    nonisolated var epistemosTier: EpistemosModelTier {
        switch self {
        case .firstRuntimeHarness, .nextScaleLane, .proFlagshipCandidate:
            .fast
        case .reasoningSpecialist:
            .think
        case .specialistCoderFineTune:
            .code
        }
    }
}

/// The curated "Epistemos AI foundation" model lineup — the five GGUF models a
/// user installs and chooses from, derived from the proven runtime ladder.
nonisolated enum EpistemosFoundationLineup {
    /// Every foundation model, in ladder order (Fast E2B→E4B→12B, then coder,
    /// then reasoner — matching `GemmaQATRuntimeLadder.candidates`).
    static var models: [GemmaQATRuntimeCandidate] {
        GemmaQATRuntimeLadder.candidates
    }

    /// Foundation models for a tier. Fast is returned smallest→largest
    /// (by recommended memory) so complexity routing can walk E2B→E4B→12B.
    static func candidates(for tier: EpistemosModelTier) -> [GemmaQATRuntimeCandidate] {
        models
            .filter { $0.stage.epistemosTier == tier }
            .sorted { $0.minimumRecommendedMemoryGB < $1.minimumRecommendedMemoryGB }
    }

    /// The id set used to curate the user-facing selectable/installable lineup
    /// and to drive the one-click foundation-package install.
    static var foundationModelIDs: Set<String> {
        Set(models.map(\.id))
    }

    /// The tier a given GGUF model id belongs to, or nil if it is not a
    /// foundation model.
    static func tier(forModelID id: String) -> EpistemosModelTier? {
        GemmaQATRuntimeLadder.candidate(forID: id)?.stage.epistemosTier
    }

    /// The default (largest-that-fits is chosen elsewhere) representative model
    /// id for a tier — used where a single id is needed (e.g. Think→VibeThinker,
    /// Code→coder). For Fast this returns the smallest Gemma; complexity routing
    /// upgrades from there.
    static func representativeModelID(for tier: EpistemosModelTier) -> String? {
        candidates(for: tier).first?.id
    }
}
