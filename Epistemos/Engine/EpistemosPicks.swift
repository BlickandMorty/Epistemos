import Foundation

/// "Epistemos Picks" — the curated section that surfaces the owner's custom hardened
/// models (the Gemma QAT GGUF ladder via `EpistemosFoundationLineup`/`GemmaQATRuntimeLadder`
/// + the explicit Qwen Think picks) at the TOP of the Act model stack, kept
/// distinct from generic installed/advertised models. Owner 2026-06-21: *"add my models
/// to the Act stack as a section that says epistemos picks … so i don't lose my custom
/// hardened models."*
///
/// PURE curation over the proven `EpistemosRuntimePicker` substrate — NOT a new model layer
/// and NOT a re-import (favor-reuse; the catalog stays the single source of truth). Honest
/// selection is inherited VERBATIM from the picker's `Option` (`isSelectable` +
/// `blockedReason`, computed by `LocalChatModelMemoryGate`): a too-large pick stays VISIBLE
/// with its honest reason — never a silent Qwen substitute (owner P0 "too-large → honest
/// message"). This is where that requirement lands in the act stack, NOT a chat patch.
///
/// `nonisolated` + side-effect-free so the section/ordering/honesty truth is unit-testable
/// without SwiftUI or `InferenceState`. The act model-stack view maps live state into
/// `EpistemosRuntimePicker.Environment` and renders these groups; the front-end stays the
/// minimal Epistemos pixel-art skin (owner 2026-06-21).
nonisolated enum EpistemosPicks {
    /// Which curated section an option belongs to.
    enum Section: String, Sendable, CaseIterable, Identifiable {
        /// The owner's curated/hardened models + curated system picks — top-billed.
        case epistemosPicks
        /// Other models the user installed or advertised beyond the curated lineup.
        case installed

        var id: String { rawValue }

        /// Section header shown in the act model stack.
        var title: String {
            switch self {
            case .epistemosPicks: "Epistemos Picks"
            case .installed: "Installed Models"
            }
        }

        /// One-line section subtitle.
        var subtitle: String {
            switch self {
            case .epistemosPicks: "Your custom hardened models — curated, sized to your Mac."
            case .installed: "Other models you've installed or advertised."
            }
        }
    }

    /// A curated group: a section + its (already gated/honest) picks, in display order.
    struct Group: Equatable, Sendable, Identifiable {
        let section: Section
        let options: [EpistemosRuntimePicker.Option]
        var id: String { section.id }
        var isEmpty: Bool { options.isEmpty }
    }

    /// Is this option one of the owner's curated picks — the foundation lineup, the static
    /// extra picks (the explicit Qwens), or the curated Apple-Intelligence pick — as opposed
    /// to a generic installed/advertised model the user added beyond the curated set?
    static func isCurated(_ option: EpistemosRuntimePicker.Option) -> Bool {
        option.isAppleIntelligence || EpistemosRuntimePicker.fixedLineupIDs.contains(option.id)
    }

    /// Curated sections for a SINGLE tier — "Epistemos Picks" first, "Installed" second;
    /// empty sections dropped. Order within each section is preserved from the picker (the
    /// proven default ordering).
    static func sections(
        for tier: EpistemosModelTier,
        environment: EpistemosRuntimePicker.Environment
    ) -> [Group] {
        groups(from: EpistemosRuntimePicker.options(for: tier, environment: environment))
    }

    /// Curated sections ACROSS all tiers (Fast/Think/Code), deduped by option id, in tier
    /// order then picker order — the full "model stack" the act picker renders.
    static func allSections(environment: EpistemosRuntimePicker.Environment) -> [Group] {
        var seen = Set<String>()
        var all: [EpistemosRuntimePicker.Option] = []
        for tier in EpistemosModelTier.allCases {
            for option in EpistemosRuntimePicker.options(for: tier, environment: environment)
            where seen.insert(option.id).inserted {
                all.append(option)
            }
        }
        return groups(from: all)
    }

    /// Partition options into the curated groups, preserving input order and dropping empty
    /// sections. Honest by construction: every input option (including blocked ones) lands in
    /// exactly one group — nothing is silently dropped or substituted.
    private static func groups(from options: [EpistemosRuntimePicker.Option]) -> [Group] {
        let curated = options.filter(isCurated)
        let installed = options.filter { !isCurated($0) }
        var result: [Group] = []
        if !curated.isEmpty { result.append(Group(section: .epistemosPicks, options: curated)) }
        if !installed.isEmpty { result.append(Group(section: .installed, options: installed)) }
        return result
    }
}
