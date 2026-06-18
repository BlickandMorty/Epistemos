import Foundation

/// P1.11 — the data model for the rebuilt runtime picker. The old popover buried
/// the choice under Routing/Fallback/per-model/Advanced sections and never showed
/// the owner explicit picks. This is the clean replacement: per tier
/// (Fast/Think/Code) it produces the explicit, selectable options with HONEST
/// gating (installed + fits memory, or an Apple-Intelligence availability check),
/// each carrying a one-line blocked reason when it can't be selected — never a
/// silent omission. Fast offers four picks (the three Gemma sizes + Apple
/// Intelligence); Think and Code each offer their single foundation model.
///
/// Pure + `nonisolated` so the selection/gating truth is unit-testable without
/// the SwiftUI panel or `InferenceState`. The panel maps live state
/// (installed ids, free memory, Apple-Intelligence availability) into
/// `Environment` and renders the returned options.
nonisolated enum EpistemosRuntimePicker {
    /// Sentinel option id for the Apple Intelligence (Fast) pick.
    static let appleIntelligenceID = "apple-intelligence"

    /// One selectable (or honestly-blocked) pick in the picker.
    struct Option: Equatable, Sendable, Identifiable {
        let id: String
        let title: String
        let tier: EpistemosModelTier
        let isAppleIntelligence: Bool
        /// Installed on disk (for Apple Intelligence: available on this Mac).
        let isInstalled: Bool
        /// Can be selected right now (installed AND fits memory, or AI available).
        let isSelectable: Bool
        /// One-line honest reason when not selectable (P1.4 style); nil when fine.
        let blockedReason: String?
    }

    /// The live inputs the picker gates on.
    struct Environment: Equatable, Sendable {
        let installedModelIDs: Set<String>
        let freeMemoryGB: Double
        /// Safety headroom kept free on top of a model's recommended memory.
        let headroomGB: Double
        let appleIntelligenceAvailable: Bool
    }

    /// An explicit non-foundation pick the owner wants visible in a tier — a
    /// VISIBLE user choice, never a silent fallback (P1.10 still holds). Memory-
    /// gated like any other pick (P1.4 blocker when it can't fit).
    struct ExtraPick: Equatable, Sendable {
        let id: String
        let title: String
        let tier: EpistemosModelTier
        let minimumMemoryGB: Int
    }

    /// Owner 2026-06-18: Qwen 3 8B back as an explicit Think pick. It's a general
    /// native-tool-call + thinking model (`LocalTextModelID.qwen3_8B4Bit`, the
    /// `fallbackPrimaryAgentModel`; displayName "Qwen 3 8B"; min 12 GB). Source of
    /// truth for these constants is `LocalTextModelID.qwen3_8B4Bit`.
    static let extraPicks: [ExtraPick] = [
        ExtraPick(id: "Qwen/Qwen3-8B-MLX-4bit", title: "Qwen 3 8B", tier: .think, minimumMemoryGB: 12),
    ]

    /// The picks for a tier, in display order: foundation models, then any
    /// explicit extra picks for the tier, then (Fast only) Apple Intelligence.
    /// Local picks are gated on installed + memory; nothing is hidden — a blocked
    /// pick still appears, with its reason.
    static func options(for tier: EpistemosModelTier, environment: Environment) -> [Option] {
        var result = EpistemosFoundationLineup.candidates(for: tier).map {
            gatedOption(
                id: $0.id,
                title: cleanTitle(for: $0.displayName),
                tier: tier,
                minimumMemoryGB: $0.minimumRecommendedMemoryGB,
                isAppleIntelligence: false,
                environment: environment
            )
        }
        result += extraPicks.filter { $0.tier == tier }.map {
            gatedOption(
                id: $0.id,
                title: $0.title,
                tier: tier,
                minimumMemoryGB: $0.minimumMemoryGB,
                isAppleIntelligence: false,
                environment: environment
            )
        }
        if tier == .fast {
            result.append(appleIntelligenceOption(environment: environment))
        }
        return result
    }

    /// A short, owner-facing title from a candidate's verbose displayName
    /// ("Gemma 4 E2B QAT GGUF" → "Gemma 2B", "Gemma 4 12B Coder QAT GGUF" →
    /// "Gemma 12B Coder").
    static func cleanTitle(for displayName: String) -> String {
        var title = displayName
        for token in [" QAT GGUF", " GGUF", " QAT"] {
            title = title.replacingOccurrences(of: token, with: "")
        }
        // "Gemma 4 E2B" → "Gemma 2B" (effective-size lanes); then the plain
        // "Gemma 4 12B" → "Gemma 12B".
        title = title.replacingOccurrences(of: "Gemma 4 E", with: "Gemma ")
        title = title.replacingOccurrences(of: "Gemma 4 ", with: "Gemma ")
        return title.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Private

    private static func gatedOption(
        id: String,
        title: String,
        tier: EpistemosModelTier,
        minimumMemoryGB: Int,
        isAppleIntelligence: Bool,
        environment: Environment
    ) -> Option {
        let installed = environment.installedModelIDs.contains(id)
        let neededGB = Double(minimumMemoryGB) + environment.headroomGB
        let fits = environment.freeMemoryGB >= neededGB
        let selectable = installed && fits
        let reason: String?
        if !installed {
            reason = "Not installed — tap to install"
        } else if !fits {
            reason = "Needs \(Int(neededGB.rounded())) GB free (\(Int(environment.freeMemoryGB.rounded())) GB available)"
        } else {
            reason = nil
        }
        return Option(
            id: id,
            title: title,
            tier: tier,
            isAppleIntelligence: isAppleIntelligence,
            isInstalled: installed,
            isSelectable: selectable,
            blockedReason: reason
        )
    }

    private static func appleIntelligenceOption(environment: Environment) -> Option {
        let available = environment.appleIntelligenceAvailable
        return Option(
            id: appleIntelligenceID,
            title: "Apple Intelligence",
            tier: .fast,
            isAppleIntelligence: true,
            isInstalled: available,
            isSelectable: available,
            blockedReason: available ? nil : "Not available on this Mac"
        )
    }
}
