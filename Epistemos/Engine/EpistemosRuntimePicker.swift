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

    /// The live inputs the picker gates on. Memory selectability mirrors the
    /// real runtime gate (`LocalChatModelMemoryGate`) so the picker never shows a
    /// model selectable that the composer would then block, or vice versa.
    struct Environment: Equatable, Sendable {
        let installedModelIDs: Set<String>
        /// Free memory in GB (rounded). `<= 0` is treated as "unknown" by the
        /// gate → not blocked (never block on missing data).
        let freeMemoryGB: Int
        let appleIntelligenceAvailable: Bool
        /// SS-CHATPICKER P0 — the user's installed + owner-advertised models BEYOND the fixed
        /// foundation lineup, so any model the owner installed/advertised becomes a clickable pick
        /// (the owner's "other models installed but won't let me click them"). The panel computes
        /// these from `installedLocalTextModelIDs` ∪ prepared, filtered by the advertised set, and
        /// `options` includes them per tier — deduped against the lineup + static `extraPicks`,
        /// gated like any other pick. Default empty preserves today's behavior.
        let additionalPicks: [ExtraPick]

        init(
            installedModelIDs: Set<String>,
            freeMemoryGB: Int,
            appleIntelligenceAvailable: Bool,
            additionalPicks: [ExtraPick] = []
        ) {
            self.installedModelIDs = installedModelIDs
            self.freeMemoryGB = freeMemoryGB
            self.appleIntelligenceAvailable = appleIntelligenceAvailable
            self.additionalPicks = additionalPicks
        }
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

    /// Owner 2026-06-18: BOTH Qwen 3 4B and Qwen 3 8B back as explicit Think picks
    /// (general native-tool-call + thinking models). NEITHER is the auto-default —
    /// the default stays a Fast Gemma; these are visible USER choices only (P1.10
    /// holds: never a silent fallback). Source of truth for the constants:
    /// `LocalTextModelID.qwen3_4B4Bit` (8 GB) and `.qwen3_8B4Bit` (12 GB, the
    /// `fallbackPrimaryAgentModel`).
    static let extraPicks: [ExtraPick] = [
        ExtraPick(id: "Qwen/Qwen3-4B-MLX-4bit", title: "Qwen 3 4B", tier: .think, minimumMemoryGB: 8),
        ExtraPick(id: "Qwen/Qwen3-8B-MLX-4bit", title: "Qwen 3 8B", tier: .think, minimumMemoryGB: 12),
    ]

    /// Every id already offered by the FIXED picker (foundation lineup across all tiers + the static
    /// extra picks). `additionalPicks` skips these so a model is never offered in two tiers (the
    /// builder's name-heuristic tier can differ from a model's canonical static/foundation tier).
    static var fixedLineupIDs: Set<String> {
        var ids = Set(extraPicks.map(\.id))
        for tier in EpistemosModelTier.allCases {
            ids.formUnion(EpistemosFoundationLineup.candidates(for: tier).map(\.id))
        }
        return ids
    }

    /// The picks for a tier, in display order: foundation models, then any
    /// explicit extra picks for the tier, then (Fast only) Apple Intelligence.
    /// Local picks are gated on installed + memory; nothing is hidden — a blocked
    /// pick still appears, with its reason.
    static func options(for tier: EpistemosModelTier, environment: Environment) -> [Option] {
        var seenIDs = Set<String>()
        var result: [Option] = []

        // 1. Foundation lineup (the default ordering).
        for candidate in EpistemosFoundationLineup.candidates(for: tier) {
            guard seenIDs.insert(candidate.id).inserted else { continue }
            result.append(gatedOption(
                id: candidate.id,
                title: cleanTitle(for: candidate.displayName),
                tier: tier,
                minimumMemoryGB: candidate.minimumRecommendedMemoryGB,
                isAppleIntelligence: false,
                environment: environment
            ))
        }
        // 2. Static extra picks (the explicit Qwen Think picks).
        for pick in extraPicks where pick.tier == tier {
            guard seenIDs.insert(pick.id).inserted else { continue }
            result.append(gatedOption(
                id: pick.id, title: pick.title, tier: tier,
                minimumMemoryGB: pick.minimumMemoryGB, isAppleIntelligence: false, environment: environment
            ))
        }
        // 3. SS-CHATPICKER P0 — the user's installed + advertised models for this tier, deduped
        //    against the lineup + static extras. This is what makes an installed model outside the
        //    fixed lineup a clickable pick instead of silently absent.
        for pick in environment.additionalPicks where pick.tier == tier {
            guard seenIDs.insert(pick.id).inserted else { continue }
            result.append(gatedOption(
                id: pick.id, title: pick.title, tier: tier,
                minimumMemoryGB: pick.minimumMemoryGB, isAppleIntelligence: false, environment: environment
            ))
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
        // Mirror the real runtime gate exactly (available + headroom >= required;
        // unknown/<=0 memory is treated as runnable) so the picker and the
        // composer never disagree on what can load.
        let fits = LocalChatModelMemoryGate.fits(
            requiredGB: minimumMemoryGB,
            availableGB: environment.freeMemoryGB
        )
        let selectable = installed && fits
        let reason: String?
        if !installed {
            reason = "Not installed — tap to install"
        } else if !fits {
            reason = "Needs ~\(minimumMemoryGB) GB (\(environment.freeMemoryGB) GB free)"
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

/// SS-CHATPICKER P0 — builds the runtime-picker `additionalPicks` (the user's installed models beyond
/// the fixed lineup) so they become clickable picks. A top-level `nonisolated` enum (NOT a static on
/// the @MainActor InferenceState) so the metadata/tier/advertised-filter truth is unit-testable. The
/// panel calls `picks(...)` with the live installed set + the owner's advertised set; `options`
/// dedups the result against the foundation lineup + static extras, so a lineup model passed here is
/// harmless.
nonisolated enum RuntimePickerExtraPicksBuilder {
    /// Resolve a model id's picker tier. Foundation GGUF candidates carry their tier; everything else
    /// is bucketed by a name heuristic (coder→Code, thinking/reasoning/R1/distill/QwQ→Think, else Fast)
    /// — placement only; the select path works regardless of tier.
    static func tier(forID id: String, displayName: String) -> EpistemosModelTier {
        if let foundationTier = EpistemosFoundationLineup.tier(forModelID: id) {
            return foundationTier
        }
        let lower = (id + " " + displayName).lowercased()
        if lower.contains("coder") || lower.contains("code") { return .code }
        if lower.contains("thinking") || lower.contains("reason") || lower.contains("qwq")
            || lower.contains("-r1") || lower.contains("distill") { return .think }
        return .fast
    }

    /// (title, memory, tier) for an installed id from the catalog. nil for an id the app doesn't
    /// recognise (a stray on-disk dir) → it is simply not offered.
    static func metadata(forID id: String) -> (title: String, memoryGB: Int, tier: EpistemosModelTier)? {
        if let candidate = GemmaQATRuntimeLadder.candidate(forID: id) {
            return (EpistemosRuntimePicker.cleanTitle(for: candidate.displayName),
                    candidate.minimumRecommendedMemoryGB, candidate.stage.epistemosTier)
        }
        if let model = LocalTextModelID(rawValue: id) {
            return (EpistemosRuntimePicker.cleanTitle(for: model.displayName),
                    model.minimumRecommendedMemoryGB, tier(forID: id, displayName: model.displayName))
        }
        return nil
    }

    /// The installed (∪ prepared) models as runtime-picker extra picks. When the owner has customized
    /// the advertised set, only advertised ids are offered (honest curation); otherwise all installed.
    static func picks(installedIDs: Set<String>, advertised: [String], isCustomized: Bool) -> [EpistemosRuntimePicker.ExtraPick] {
        let covered = EpistemosRuntimePicker.fixedLineupIDs
        let advertisedSet = Set(advertised)
        return installedIDs.sorted().compactMap { id in
            if covered.contains(id) { return nil }  // already offered by the fixed picker in its canonical tier
            if isCustomized && !advertisedSet.contains(id) { return nil }
            guard let meta = metadata(forID: id) else { return nil }
            return EpistemosRuntimePicker.ExtraPick(
                id: id, title: meta.title, tier: meta.tier, minimumMemoryGB: meta.memoryGB)
        }
    }
}
