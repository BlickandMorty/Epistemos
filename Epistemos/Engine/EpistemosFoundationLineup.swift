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

extension EpistemosOperatingMode {
    /// The local model tier a chat mode binds to, or nil for modes that are not
    /// a model tier (Tools/agent = the cloud/managed runtime path). Drives the
    /// "buttons become Fast/Think/Code/Tools" behavior: on a local selection the
    /// mode picks its tier's foundation model.
    var epistemosModelTier: EpistemosModelTier? {
        switch self {
        case .fast: .fast
        case .thinking: .think
        case .pro: .code
        case .agent: nil
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
        case .firstRuntimeHarness, .nextScaleLane, .proFlagshipCandidate, .moeFlagshipCandidate:
            // The MoE flagship (26B-A4B) joins the Fast Gemma family as the
            // largest, explicit-only pick — effort sizing never auto-routes to
            // it (it clamps to the 12B band), so it's selected only deliberately.
            .fast
        case .reasoningSpecialist, .liquidGeneralMoe, .gemmaTwelveBLowMemory:
            // VibeThinker (reasoning) + LFM2.5 (general MoE) + the 2-bit 12B Gemma
            // (big-model-low-memory) all back the Think tier's "general capable"
            // surface; Think has no Fast effort-sizing, so they stay explicit-only
            // picks (the 2-bit 12B in Fast would break the memory∝capability ladder).
            .think
        case .specialistCoderFineTune:
            .code
        }
    }
}

/// The curated "Epistemos AI foundation" model lineup — the five GGUF models a
/// user installs and chooses from, derived from the proven runtime ladder.
nonisolated enum EpistemosFoundationLineup {
    /// Whether the simplified Fast/Think/Code lineup is active (default ON).
    /// When active, the legacy non-foundation MLX chat models are hidden from
    /// the user-facing picker — but ONLY once at least one foundation GGUF model
    /// is installed, so a user is never left with an empty local picker. Set
    /// `EPISTEMOS_SIMPLIFIED_LINEUP=0` to restore the full legacy lineup
    /// (reversible — the "hide, keep code" decision, 2026-06-16). Internal
    /// helper models (router/draft/embeddings) are unaffected: they are not
    /// chat-picker entries.
    static var simplifiedLineupActive: Bool {
        ProcessInfo.processInfo.environment["EPISTEMOS_SIMPLIFIED_LINEUP"] != "0"
    }

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

    /// The canonical default chat model id for a fresh install / unset / stale
    /// selection — the smallest Fast Gemma (the Fast tier representative). Owner
    /// 2026-06-18: the default is a Fast GEMMA, never Qwen (both Qwens are
    /// explicit-only picks). Falls back to the literal E2B GGUF id when the
    /// ladder is somehow empty so this is always non-nil for property defaults.
    static let defaultChatModelID: String =
        representativeModelID(for: .fast) ?? "google/gemma-4-E2B-it-qat-q4_0-gguf"
}

/// P1.5 — Fast "three efforts" per-query sizing policy. Maps a query-complexity
/// score in `[0, 1]` to an index into an ascending-by-size candidate list
/// (E2B → E4B → 12B): trivial → smallest, medium → middle, hard → largest.
///
/// Pure + deterministic, with no `InferenceState` / hardware / flag dependency,
/// so the sizing policy is unit-testable on its own. The index is clamped to the
/// available candidate count, so when only two sizes fit (e.g. a 16 GB Mac where
/// the 12B is excluded for headroom) a "hard" query collapses onto the largest
/// that fits rather than running off the end.
nonisolated enum EpistemosFastEffortSizing {
    /// Below this complexity → smallest model (E2B). Short factual asks land
    /// well under here in `QueryAnalyzer.analyze(...).complexity`.
    static let mediumThreshold = 0.30
    /// Below this → middle model (E4B); at or above → largest (12B). Multi-entity
    /// / multi-sentence / follow-up asks climb past here.
    static let hardThreshold = 0.60

    /// Human-facing Fast effort band (P1.9). The user-visible explanation of why
    /// a query ran a given Gemma size — low → E2B, medium → E4B, high → 12B
    /// (subject to memory headroom). Derived purely from the same complexity
    /// thresholds as `candidateIndex`, so the label and the actual size never
    /// disagree on which band a query is in.
    enum FastEffort: String, Sendable, CaseIterable {
        case low
        case medium
        case high

        var displayName: String {
            switch self {
            case .low: "Low"
            case .medium: "Medium"
            case .high: "High"
            }
        }
    }

    /// The effort band for a `[0, 1]` complexity score. Shares the
    /// `candidateIndex` thresholds so "Medium effort" always lines up with the
    /// middle candidate band.
    static func effort(forComplexity complexity: Double) -> FastEffort {
        let clamped = min(max(complexity, 0), 1)
        if clamped < mediumThreshold {
            return .low
        }
        if clamped < hardThreshold {
            return .medium
        }
        return .high
    }

    /// Index into an ascending-by-size candidate list for a given complexity.
    /// `candidateCount <= 1` always returns `0` (nothing to size between).
    static func candidateIndex(forComplexity complexity: Double, candidateCount: Int) -> Int {
        guard candidateCount > 1 else { return 0 }
        let clamped = min(max(complexity, 0), 1)
        let band: Int
        if clamped < mediumThreshold {
            band = 0
        } else if clamped < hardThreshold {
            band = 1
        } else {
            band = 2
        }
        return min(band, candidateCount - 1)
    }

    /// Index into an ascending-by-size candidate list for a user-pinned effort
    /// band (low→smallest, medium→middle, high→largest), bypassing the per-query
    /// complexity derivation. Mirrors `candidateIndex(forComplexity:)`'s band→
    /// index contract so a pinned "High" lands on the same candidate a high-
    /// complexity query auto-sizes to. The owner's "i dont see the low medium
    /// high on fast mode" override (L1128) routes through this.
    static func candidateIndex(forEffort effort: FastEffort, candidateCount: Int) -> Int {
        guard candidateCount > 1 else { return 0 }
        let band: Int
        switch effort {
        case .low: band = 0
        case .medium: band = 1
        case .high: band = 2
        }
        return min(band, candidateCount - 1)
    }

    /// Flag-gate (default OFF) for the user-facing Fast effort override picker
    /// (L1128). OFF → Fast sizing stays purely per-query auto (byte-identical to
    /// before); ON → a pinned low/med/high overrides the complexity band and the
    /// selector appears in the runtime picker. Set
    /// `EPISTEMOS_FAST_EFFORT_PICKER_V0=1` to enable.
    static var pickerOverrideEnabled: Bool {
        ProcessInfo.processInfo.environment["EPISTEMOS_FAST_EFFORT_PICKER_V0"] == "1"
    }
}

/// P1.4 — honest local-runtime memory gate. Pure policy for deciding whether a
/// local chat model can actually load into the current free-memory budget, and
/// for the one-line reason shown to the user when it can't. Kept here (pure +
/// nonisolated, no `InferenceState` dependency) so the decision is unit-testable
/// on its own; `InferenceState.localChatModelMemoryBlocker` supplies the live
/// numbers. The headroom matches the agent-tier budget check
/// (`localAgentModelFitsCurrentMemoryBudget`) so chat and agent gate alike.
nonisolated enum LocalChatModelMemoryGate {
    /// GB assumed reclaimable on top of free memory before a model is judged
    /// un-runnable — matches the agent-tier fit check so the two never disagree.
    static let headroomGB = 6

    /// Whether a model needing `requiredGB` can run with `availableGB` free.
    /// A non-positive requirement or unknown (`<= 0`) availability is treated as
    /// runnable: we surface a blocker only on positive evidence it can't load,
    /// never on missing data.
    static func fits(requiredGB: Int, availableGB: Int) -> Bool {
        guard requiredGB > 0 else { return true }
        guard availableGB > 0 else { return true }
        return availableGB + headroomGB >= requiredGB
    }

    /// One-line, honest blocker reason. Names the model, the rough need, the
    /// free memory, and the three honest ways out (free memory / smaller tier /
    /// cloud). Used verbatim in the composer banner + Send tooltip.
    static func blockerReason(modelDisplayName: String, requiredGB: Int, availableGB: Int) -> String {
        "Not enough free memory for \(modelDisplayName) (~\(requiredGB) GB needed, \(availableGB) GB free). Free up memory, pick a smaller tier, or route to cloud."
    }
}
