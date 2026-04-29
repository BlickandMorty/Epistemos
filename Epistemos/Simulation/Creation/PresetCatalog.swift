//
//  PresetCatalog.swift
//  Simulation Mode S8 — provider-preset catalog backing the §6.1
//  step-1 "Begin from preset" picker.
//
//  Each preset materialises into a partial CompanionSpec the
//  wizard pre-fills the downstream steps with. Users can override
//  any axis at any step. Palette refs come from the curated
//  catalog (the `_v1` slugs) so they bypass the §6.2 hex/contrast
//  gate; the Custom preset uses an empty palette ref so the
//  wizard's palette step forces an explicit hex pick.
//
//  Hermes is intentionally absent here — it's S9 territory
//  (separate snake atlas + landing-ritual entrance). When S9
//  ships, append a `.hermesFaculty` case here.
//

import Foundation

/// Identifier for one factory preset. Hashable so wizard state
/// can pin which preset the user started from (used by "skip to
/// default" + audit trail).
public enum CompanionPresetId: String, Hashable, Sendable, CaseIterable {
    case claudeCodeWorker
    case kimiWorker
    case codexWorker
    case gptOrchestrator
    case hermesFaculty
    case localHelper
    case custom
}

/// Snapshot of a preset's defaults across the §5 customization
/// axes. The wizard reads these into its draft spec and then
/// lets the user override.
public struct CompanionPreset: Identifiable, Sendable, Hashable {
    public let id: CompanionPresetId
    /// Human-facing label rendered on the picker tile.
    public let displayName: String
    /// One-line subtitle ("careful code worker", "fast explorer
    /// / long-context", …) lifted from §5.4.
    public let blurb: String
    /// `"Block" | "Sage" | "Orb"`. (HermesSnake is reserved for
    /// the future S9 preset.)
    public let headShape: String
    /// Curated palette slug (`claude_warm_v1`, …) or empty for
    /// the Custom preset where the wizard forces a hex pick.
    public let paletteRef: String
    public let eyes: String
    public let arms: String
    public let prop: String?
    public let role: String
    /// Recommended base model — pre-fills the spec; users can
    /// swap. Must be a string the registry's `base_model`
    /// column accepts.
    public let baseModel: String
    /// System-prompt preset slug; canonical defaults per §5.4.
    public let systemPromptPreset: String
    /// Brand hex (for the picker tile chrome). Mirrors the
    /// values in `bridge.rs::company_brand_hex`.
    public let brandHex: String
}

/// The S8 V1 catalog. Public so previews + tests can iterate.
public enum PresetCatalog {
    public static let claudeCodeWorker = CompanionPreset(
        id: .claudeCodeWorker,
        displayName: "Claude Code worker",
        blurb: "Careful code reviewer / patcher",
        headShape: "Block",
        paletteRef: "claude_warm_v1",
        eyes: "NegativeSpace",
        arms: "None",
        prop: "Wrench",
        role: "CodeWorker",
        baseModel: "claude-sonnet-4-6",
        systemPromptPreset: "careful_reviewer_v1",
        brandHex: "#D97757"
    )
    public static let kimiWorker = CompanionPreset(
        id: .kimiWorker,
        displayName: "Kimi worker",
        blurb: "Fast explorer / long-context",
        headShape: "Block",
        paletteRef: "kimi_indigo_v1",
        eyes: "Round",
        arms: "Short",
        prop: "Magnifier",
        role: "Researcher",
        baseModel: "kimi-k2",
        systemPromptPreset: "kimi_explorer_v1",
        brandHex: "#5B8DEF"
    )
    public static let codexWorker = CompanionPreset(
        id: .codexWorker,
        displayName: "Codex worker",
        blurb: "Code patcher / auditor",
        headShape: "Block",
        paletteRef: "gpt_neutral_v1",
        eyes: "Round",
        arms: "Short",
        prop: "Wrench",
        role: "CodeWorker",
        baseModel: "codex-cli",
        systemPromptPreset: "codex_patcher_v1",
        brandHex: "#9C9C9C"
    )
    public static let gptOrchestrator = CompanionPreset(
        id: .gptOrchestrator,
        displayName: "GPT Orchestrator",
        blurb: "Calm planner / router",
        headShape: "Orb",
        paletteRef: "gpt_neutral_v1",
        eyes: "Closed",
        arms: "None",
        prop: "Baton",
        role: "Orchestrator",
        baseModel: "gpt-5",
        systemPromptPreset: "gpt_orchestrator_v1",
        brandHex: "#9C9C9C"
    )
    /// DOCTRINE §5.4 + §8.1 — Hermes is privileged. The picker
    /// tile triggers the §8.2.2 7-phase landing ritual rather
    /// than the regular wizard. The preset's axes are the ones
    /// `epistemos_companions_create_hermes` enforces; we surface
    /// them here for the live preview only — the wizard's
    /// downstream steps are skipped when this preset is chosen.
    public static let hermesFaculty = CompanionPreset(
        id: .hermesFaculty,
        displayName: "Hermes Faculty",
        blurb: "Graph-native faculty (privileged)",
        headShape: "HermesSnake",
        paletteRef: "hermes_gold_v1",
        eyes: "Slit",
        arms: "None",
        prop: "Scroll",
        role: "Faculty",
        baseModel: "hermes-3-405b",
        systemPromptPreset: "hermes_faculty_v1",
        brandHex: "#D4AF37"
    )
    public static let localHelper = CompanionPreset(
        id: .localHelper,
        displayName: "Local Helper",
        blurb: "Classifier / memory clerk",
        headShape: "Block",
        paletteRef: "local_teal_v1",
        eyes: "Round",
        arms: "Short",
        prop: "Folder",
        role: "Helper",
        baseModel: "qwen3-4b-mlx",
        systemPromptPreset: "local_helper_v1",
        brandHex: "#2BA59B"
    )
    public static let custom = CompanionPreset(
        id: .custom,
        displayName: "Custom",
        blurb: "Build your own",
        headShape: "Sage",
        paletteRef: "",
        eyes: "Round",
        arms: "None",
        prop: nil,
        role: "Custom",
        baseModel: "claude-sonnet-4-6",
        systemPromptPreset: "custom_v1",
        brandHex: "#6F6F6F"
    )

    /// All presets in canonical wizard order. Order mirrors
    /// DOCTRINE §5.4 table.
    public static let all: [CompanionPreset] = [
        claudeCodeWorker,
        kimiWorker,
        codexWorker,
        gptOrchestrator,
        hermesFaculty,
        localHelper,
        custom,
    ]

    /// Find by id; returns Custom on miss so a stale persisted
    /// id never crashes the wizard.
    public static func preset(_ id: CompanionPresetId) -> CompanionPreset {
        all.first { $0.id == id } ?? custom
    }
}
