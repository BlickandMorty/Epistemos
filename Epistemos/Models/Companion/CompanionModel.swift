import Foundation
import SwiftData

/// Persisted Companion record. SwiftData @Model so the Farm view can
/// query and react to companion lifecycle changes natively.
///
/// Per the Simulation Mode v1.6 doctrine (T6 hackathon Block B):
/// - Each Companion is a lightweight identity attached to one shared
///   base substrate (the active model selection).
/// - Cosmetic config (body grammar: parameterized Block / Sage / Orb)
///   maps to a ModelProfile per Invariant I-10 — every cosmetic choice
///   is functionally significant, not pure decoration.
/// - Identity hash is a stable per-companion seed used by
///   `DeterministicPRNG` per Invariant I-13 to make per-companion
///   animations deterministic across replay.
/// - `archivedAt` non-nil = trashed (soft delete); restorable until
///   the trash is emptied. Hard delete sets archivedAt + clears
///   payload sidecar files.
@Model
final class CompanionModel {
    /// UUID string. Stable across app launches.
    @Attribute(.unique) var id: String
    /// User-facing name ("Sage", "Orb", "Quill", custom names).
    var name: String
    /// One-liner tagline shown beneath the orb in the Farm.
    var tagline: String
    /// Body grammar — see CompanionBodyKind for the parameterized Farm variants.
    /// Stored as raw string for SwiftData friendliness.
    var bodyKindRaw: String
    /// Hex-coded accent color (e.g. "#7BA8E0"). Drives the orb halo
    /// and the persona accent in chat surfaces tied to this companion.
    var accentHex: String
    /// Stable seed for DeterministicPRNG. Computed at creation from
    /// (id + bodyKindRaw + name) so cosmetic randomness is replayable.
    var identityHash: String
    /// Optional path (relative to vault) to a LoRA-light adapter that
    /// deforms the base model toward this companion's voice. Nil =
    /// pure prompt-based persona.
    var loraAdapterPath: String?
    /// When the companion was created.
    var createdAt: Date
    /// When the companion was last brought to the foreground (for
    /// "recent" sorting in the Farm).
    var lastInteractedAt: Date
    /// When the companion was archived (soft-deleted). Non-nil = in
    /// trash; restorable. Nil = active.
    var archivedAt: Date?
    /// Optional brief persona description that augments the
    /// system prompt when this companion is active.
    var personaPrompt: String?
    /// Optional AgentBlueprint model/provider route. Nil means the
    /// canonical auto constellation should pick the runtime.
    var agentModelRoutingID: String?
    /// Display label captured at creation time so old agents still show
    /// a useful route label if a model is later unavailable.
    var agentModelDisplayName: String?
    /// Newline-separated tool names selected for this landing agent.
    var agentToolNamesRaw: String?
    /// AgentBlueprint scope raw value.
    var agentScopeRaw: String?
    /// AgentBlueprint approval raw value.
    var agentApprovalModeRaw: String?

    // MARK: - Agent meta-config (osaurus-pattern, additive 2026-06-16)
    // These extend the Companion (the tamagotchi creature) into a full
    // per-agent meta-config builder. All optional so SwiftData applies a
    // lightweight (additive) migration — existing Companions decode unchanged.

    /// Full system-prompt OVERRIDE applied when non-empty. Distinct from
    /// `personaPrompt`, which only AUGMENTS the composed instruction. Nil/empty
    /// = keep the existing persona-augment behavior.
    var customSystemPromptTemplate: String?
    /// Per-agent structured-output contract, JSON-encoded, e.g.
    /// `{"format":"json"|"xml"|"text","schema":{…}}`. Surfaced to the model and,
    /// on the GGUF runtime, can drive grammar-constrained decoding
    /// (`--json-schema`). Nil = freeform text.
    var outputStructureJSON: String?
    /// Per-agent MCP server config (JSON array of `{id,endpoint,auth,env}`) so a
    /// companion can bring its own tool servers. Nil = inherit the global MCP
    /// catalog.
    var mcpServerConfigJSON: String?
    /// Per-agent memory/context auto-pin pattern (glob/regex over note
    /// titles/paths) attached to this companion's turns. Nil = no auto-pin.
    var memoryPinPattern: String?
    /// Tool-selection mode raw: "auto" (RAG-preflight picks relevant tools) or
    /// "manual" (only `agentToolNames`). Nil = "manual" (current behavior).
    var toolSelectionModeRaw: String?
    /// Pro-only autonomous-execution grant (sandboxed code exec), JSON-encoded
    /// `AutonomousExecConfig`. Nil = no autonomous exec — the MAS-safe default.
    var autonomousExecConfigJSON: String?

    init(
        id: String = UUID().uuidString,
        name: String,
        tagline: String = "",
        bodyKind: CompanionBodyKind = .orb,
        accentHex: String = "#7BA8E0",
        loraAdapterPath: String? = nil,
        personaPrompt: String? = nil,
        agentModelChoice: AgentBlueprintModelChoice = .autoConstellation,
        agentToolNames: [String] = [],
        agentScope: AgentBlueprintScope = .currentVault,
        agentApprovalMode: AgentBlueprintApprovalMode = .approveOncePerSession,
        customSystemPromptTemplate: String? = nil,
        outputStructureJSON: String? = nil,
        mcpServerConfigJSON: String? = nil,
        memoryPinPattern: String? = nil,
        toolSelectionMode: CompanionToolSelectionMode = .manual,
        autonomousExecConfigJSON: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.tagline = tagline
        self.bodyKindRaw = bodyKind.rawValue
        self.accentHex = accentHex
        self.loraAdapterPath = loraAdapterPath
        self.personaPrompt = personaPrompt
        self.agentModelRoutingID = agentModelChoice.routingID
        self.agentModelDisplayName = agentModelChoice.displayName
        self.agentToolNamesRaw = Self.encodeToolNames(agentToolNames)
        self.agentScopeRaw = agentScope.rawValue
        self.agentApprovalModeRaw = agentApprovalMode.rawValue
        self.customSystemPromptTemplate = customSystemPromptTemplate
        self.outputStructureJSON = outputStructureJSON
        self.mcpServerConfigJSON = mcpServerConfigJSON
        self.memoryPinPattern = memoryPinPattern
        self.toolSelectionModeRaw = toolSelectionMode.rawValue
        self.autonomousExecConfigJSON = autonomousExecConfigJSON
        self.createdAt = createdAt
        self.lastInteractedAt = createdAt
        self.archivedAt = nil
        self.identityHash = Self.computeIdentityHash(
            id: id, bodyKindRaw: bodyKind.rawValue, name: name
        )
    }

    var bodyKind: CompanionBodyKind {
        get { CompanionBodyKind(rawValue: bodyKindRaw) ?? .orb }
        set { bodyKindRaw = newValue.rawValue }
    }

    var agentModelChoice: AgentBlueprintModelChoice {
        get {
            Self.modelChoice(
                routingID: agentModelRoutingID,
                displayName: agentModelDisplayName
            )
        }
        set {
            agentModelRoutingID = newValue.routingID
            agentModelDisplayName = newValue.displayName
        }
    }

    var agentToolNames: [String] {
        get { Self.decodeToolNames(agentToolNamesRaw) }
        set { agentToolNamesRaw = Self.encodeToolNames(newValue) }
    }

    var agentScope: AgentBlueprintScope {
        get { AgentBlueprintScope(rawValue: agentScopeRaw ?? "") ?? .currentVault }
        set { agentScopeRaw = newValue.rawValue }
    }

    var agentApprovalMode: AgentBlueprintApprovalMode {
        get {
            AgentBlueprintApprovalMode(rawValue: agentApprovalModeRaw ?? "") ?? .approveOncePerSession
        }
        set { agentApprovalModeRaw = newValue.rawValue }
    }

    var toolSelectionMode: CompanionToolSelectionMode {
        get { CompanionToolSelectionMode(rawValue: toolSelectionModeRaw ?? "") ?? .manual }
        set { toolSelectionModeRaw = newValue.rawValue }
    }

    /// The system instruction this companion contributes to a turn: the full
    /// `customSystemPromptTemplate` OVERRIDE when set, otherwise the
    /// `personaPrompt` augment (existing behavior). Trimmed; nil when neither is
    /// meaningfully set. This is the single seam the chat pipeline reads (via
    /// `CompanionState.activeAgentSystemInstruction()`), so a per-agent custom
    /// prompt flows through without touching the rest of the pipeline.
    var effectiveAgentSystemInstruction: String? {
        if let custom = customSystemPromptTemplate?.trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty {
            return custom
        }
        if let persona = personaPrompt?.trimmingCharacters(in: .whitespacesAndNewlines),
           !persona.isEmpty {
            return persona
        }
        return nil
    }

    var isArchived: Bool { archivedAt != nil }

    private static func modelChoice(
        routingID: String?,
        displayName: String?
    ) -> AgentBlueprintModelChoice {
        guard let routingID, !routingID.isEmpty else { return .autoConstellation }
        if routingID == AgentBlueprintModelChoice.autoConstellation.routingID {
            return .autoConstellation
        }
        if routingID == AgentBlueprintModelChoice.appleIntelligence.routingID || routingID == "apple" {
            return .appleIntelligence
        }
        if routingID.hasPrefix("local:") {
            let modelID = String(routingID.dropFirst("local:".count))
            let label = displayName ?? LocalTextModelID(rawValue: modelID)?.displayName ?? modelID
            return .local(modelID: modelID, displayName: label)
        }
        if routingID.hasPrefix("cloud:") {
            let providerRaw = String(routingID.dropFirst("cloud:".count))
            let label = displayName
                ?? CloudModelProvider(rawValue: providerRaw)?.displayName
                ?? providerRaw
            return .cloud(provider: providerRaw, displayName: label)
        }
        return .autoConstellation
    }

    private static func encodeToolNames(_ names: [String]) -> String? {
        let normalized = Array(Set(
            names
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        ))
        .sorted()
        guard !normalized.isEmpty else { return nil }
        return normalized.joined(separator: "\n")
    }

    private static func decodeToolNames(_ rawValue: String?) -> [String] {
        guard let rawValue else { return [] }
        return rawValue
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// FNV-1a-ish lightweight hash for the identity seed. Fine for
    /// cosmetic determinism — not a security primitive. Replace with
    /// BLAKE3 if/when DAG node hashing lands (Phase 8).
    static func computeIdentityHash(id: String, bodyKindRaw: String, name: String) -> String {
        let combined = "\(id):\(bodyKindRaw):\(name)"
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in combined.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}

/// Canonical Farm body families from Simulation v1.6 §5.1.
/// Block is parameterized; LocalAgent Snake is a graph faculty glyph, not a Farm body.
nonisolated enum CompanionBodyFamily: String, Codable, Sendable, CaseIterable {
    case block
    case sage
    case orb
}

/// How a companion picks tools for a turn. `.manual` uses only the explicit
/// `agentToolNames`; `.auto` lets a RAG preflight surface the most relevant
/// tools for the query (osaurus pattern). Default `.manual` preserves the
/// existing honest behavior — no surprise tool exposure.
nonisolated enum CompanionToolSelectionMode: String, Codable, Sendable, CaseIterable {
    case manual
    case auto

    var displayName: String {
        switch self {
        case .manual: "Manual (pinned tools)"
        case .auto: "Auto (RAG-selected)"
        }
    }
}

nonisolated enum CompanionBlockAspect: String, Codable, Sendable, CaseIterable {
    case compact
    case wide
    case tall
}

nonisolated enum CompanionLegStyle: String, Codable, Sendable, CaseIterable {
    case none
    case stubs
    case multi
}

nonisolated enum CompanionAntennaStyle: String, Codable, Sendable, CaseIterable {
    case none
    case single
    case double
}

nonisolated enum CompanionEyeTreatment: String, Codable, Sendable, CaseIterable {
    case negativeSpace
    case filled
}

nonisolated enum CompanionHeadStyle: String, Codable, Sendable, CaseIterable {
    case plain
    case cap
    case crown
    case visor

    var displayName: String {
        switch self {
        case .plain: "Plain"
        case .cap: "Cap"
        case .crown: "Crown"
        case .visor: "Visor"
        }
    }
}

nonisolated enum CompanionArmStyle: String, Codable, Sendable, CaseIterable {
    case none
    case nubs
    case side
    case wave

    var displayName: String {
        switch self {
        case .none: "None"
        case .nubs: "Nubs"
        case .side: "Side"
        case .wave: "Wave"
        }
    }
}

nonisolated enum CompanionEyeShape: String, Codable, Sendable, CaseIterable {
    case square
    case dot
    case bar
    case visor

    var displayName: String {
        switch self {
        case .square: "Square"
        case .dot: "Dot"
        case .bar: "Bar"
        case .visor: "Visor"
        }
    }
}

nonisolated enum CompanionAccessoryStyle: String, Codable, Sendable, CaseIterable {
    case none
    case glasses
    case mustache
    case hair
    case headset

    var displayName: String {
        switch self {
        case .none: "None"
        case .glasses: "Glasses"
        case .mustache: "Mustache"
        case .hair: "Hair"
        case .headset: "Headset"
        }
    }
}

nonisolated struct CompanionBodyKind: RawRepresentable, Codable, Sendable, Hashable {
    let family: CompanionBodyFamily
    let blockAspect: CompanionBlockAspect?
    let legStyle: CompanionLegStyle?
    let antennaStyle: CompanionAntennaStyle?
    let eyeTreatment: CompanionEyeTreatment?
    let headStyle: CompanionHeadStyle?
    let armStyle: CompanionArmStyle?
    let eyeShape: CompanionEyeShape?
    let accessoryStyle: CompanionAccessoryStyle?

    private init(
        family: CompanionBodyFamily,
        blockAspect: CompanionBlockAspect? = nil,
        legStyle: CompanionLegStyle? = nil,
        antennaStyle: CompanionAntennaStyle? = nil,
        eyeTreatment: CompanionEyeTreatment? = nil,
        headStyle: CompanionHeadStyle? = nil,
        armStyle: CompanionArmStyle? = nil,
        eyeShape: CompanionEyeShape? = nil,
        accessoryStyle: CompanionAccessoryStyle? = nil
    ) {
        self.family = family
        self.blockAspect = blockAspect
        self.legStyle = legStyle
        self.antennaStyle = antennaStyle
        self.eyeTreatment = eyeTreatment
        self.headStyle = headStyle
        self.armStyle = armStyle
        self.eyeShape = eyeShape
        self.accessoryStyle = accessoryStyle
    }

    static func block(
        aspect: CompanionBlockAspect,
        legs: CompanionLegStyle,
        antennae: CompanionAntennaStyle,
        eyeTreatment: CompanionEyeTreatment,
        headStyle: CompanionHeadStyle = .plain,
        armStyle: CompanionArmStyle = .none,
        eyeShape: CompanionEyeShape = .square,
        accessoryStyle: CompanionAccessoryStyle = .none
    ) -> CompanionBodyKind {
        CompanionBodyKind(
            family: .block,
            blockAspect: aspect,
            legStyle: legs,
            antennaStyle: antennae,
            eyeTreatment: eyeTreatment,
            headStyle: headStyle,
            armStyle: armStyle,
            eyeShape: eyeShape,
            accessoryStyle: accessoryStyle
        )
    }

    static let blockCompact = CompanionBodyKind.block(
        aspect: .compact,
        legs: .stubs,
        antennae: .none,
        eyeTreatment: .filled
    )

    static let blockWide = CompanionBodyKind.block(
        aspect: .wide,
        legs: .multi,
        antennae: .single,
        eyeTreatment: .negativeSpace
    )

    static let blockTall = CompanionBodyKind.block(
        aspect: .tall,
        legs: .stubs,
        antennae: .double,
        eyeTreatment: .filled
    )

    static let blockSignal = CompanionBodyKind.block(
        aspect: .compact,
        legs: .none,
        antennae: .single,
        eyeTreatment: .filled
    )

    static let blockTwin = CompanionBodyKind.block(
        aspect: .wide,
        legs: .stubs,
        antennae: .double,
        eyeTreatment: .filled
    )

    static let orb = CompanionBodyKind(family: .orb)
    static let sage = CompanionBodyKind(family: .sage)

    /// Visible v1 agent bodies. The orb renderer/parser stays source-preserved
    /// for existing rows, but new Landing agents use the Claude-Code-like
    /// block/sage silhouettes instead of a circular body.
    static let creationPresets: [CompanionBodyKind] = [
        .blockCompact,
        .blockWide,
        .blockTall,
        .blockSignal,
        .blockTwin,
        .sage,
    ]

    init?(rawValue: String) {
        switch rawValue {
        case "block":
            self = .blockCompact
        case "block_compact", "block.compact":
            self = .blockCompact
        case "block_wide", "block.wide":
            self = .blockWide
        case "block_tall", "block.tall":
            self = .blockTall
        case "block_signal", "block.signal":
            self = .blockSignal
        case "block_twin", "block.twin":
            self = .blockTwin
        case "sage":
            self = .sage
        case "orb":
            self = .orb
        default:
            let parts = rawValue.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
            guard let family = CompanionBodyFamily(rawValue: parts.first ?? "") else {
                return nil
            }
            switch family {
            case .block:
                guard parts.count == 5 || parts.count == 9,
                      let aspect = CompanionBlockAspect(rawValue: parts[1]),
                      let legs = CompanionLegStyle(rawValue: parts[2]),
                      let antennae = CompanionAntennaStyle(rawValue: parts[3]),
                      let eyes = CompanionEyeTreatment(rawValue: parts[4]) else {
                    return nil
                }
                if parts.count == 9 {
                    guard let head = CompanionHeadStyle(rawValue: parts[5]),
                          let arms = CompanionArmStyle(rawValue: parts[6]),
                          let eyeShape = CompanionEyeShape(rawValue: parts[7]),
                          let accessory = CompanionAccessoryStyle(rawValue: parts[8]) else {
                        return nil
                    }
                    self = .block(
                        aspect: aspect,
                        legs: legs,
                        antennae: antennae,
                        eyeTreatment: eyes,
                        headStyle: head,
                        armStyle: arms,
                        eyeShape: eyeShape,
                        accessoryStyle: accessory
                    )
                } else {
                    self = .block(
                        aspect: aspect,
                        legs: legs,
                        antennae: antennae,
                        eyeTreatment: eyes
                    )
                }
            case .sage, .orb:
                guard parts.count == 5,
                      let head = CompanionHeadStyle(rawValue: parts[1]),
                      let arms = CompanionArmStyle(rawValue: parts[2]),
                      let eyeShape = CompanionEyeShape(rawValue: parts[3]),
                      let accessory = CompanionAccessoryStyle(rawValue: parts[4]) else {
                    return nil
                }
                self = CompanionBodyKind(
                    family: family,
                    headStyle: head,
                    armStyle: arms,
                    eyeShape: eyeShape,
                    accessoryStyle: accessory
                )
            }
        }
    }

    var rawValue: String {
        let head = resolvedHeadStyle
        let arms = resolvedArmStyle
        let eyeShape = resolvedEyeShape
        let accessory = resolvedAccessoryStyle
        switch family {
        case .block:
            let aspect = blockAspect ?? .compact
            let legs = legStyle ?? .stubs
            let antennae = antennaStyle ?? .none
            let eyes = eyeTreatment ?? .filled
            return "block.\(aspect.rawValue).\(legs.rawValue).\(antennae.rawValue).\(eyes.rawValue).\(head.rawValue).\(arms.rawValue).\(eyeShape.rawValue).\(accessory.rawValue)"
        case .sage:
            return rawFamilyValueWithCosmetics(family: .sage)
        case .orb:
            return rawFamilyValueWithCosmetics(family: .orb)
        }
    }

    var resolvedHeadStyle: CompanionHeadStyle { headStyle ?? .plain }
    var resolvedArmStyle: CompanionArmStyle { armStyle ?? .none }
    var resolvedEyeShape: CompanionEyeShape { eyeShape ?? .square }
    var resolvedAccessoryStyle: CompanionAccessoryStyle { accessoryStyle ?? .none }

    func customized(
        headStyle: CompanionHeadStyle? = nil,
        armStyle: CompanionArmStyle? = nil,
        eyeShape: CompanionEyeShape? = nil,
        accessoryStyle: CompanionAccessoryStyle? = nil
    ) -> CompanionBodyKind {
        CompanionBodyKind(
            family: family,
            blockAspect: blockAspect,
            legStyle: legStyle,
            antennaStyle: antennaStyle,
            eyeTreatment: eyeTreatment,
            headStyle: headStyle ?? resolvedHeadStyle,
            armStyle: armStyle ?? resolvedArmStyle,
            eyeShape: eyeShape ?? resolvedEyeShape,
            accessoryStyle: accessoryStyle ?? resolvedAccessoryStyle
        )
    }

    private func rawFamilyValueWithCosmetics(family: CompanionBodyFamily) -> String {
        let hasCustomCosmetics = resolvedHeadStyle != .plain
            || resolvedArmStyle != .none
            || resolvedEyeShape != .square
            || resolvedAccessoryStyle != .none
        guard hasCustomCosmetics else { return family.rawValue }
        return "\(family.rawValue).\(resolvedHeadStyle.rawValue).\(resolvedArmStyle.rawValue).\(resolvedEyeShape.rawValue).\(resolvedAccessoryStyle.rawValue)"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let parsed = CompanionBodyKind(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown CompanionBodyKind raw value: \(rawValue)"
            )
        }
        self = parsed
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var displayName: String {
        switch family {
        case .block:
            if self == .blockTall { return "Tall Block" }
            if self == .blockSignal { return "Signal Block" }
            if self == .blockTwin { return "Twin Block" }
            switch blockAspect ?? .compact {
            case .compact: return "Compact Block"
            case .wide: return "Wide Block"
            case .tall: return "Tall Block"
            }
        case .sage:
            return "Sage"
        case .orb:
            return "Orb"
        }
    }

    /// Tagline hint shown in the creation wizard.
    var hint: String {
        switch family {
        case .block:
            if self == .blockTall {
                return "Tall and watchful. Good for review, synthesis, and slower decisions."
            }
            if self == .blockSignal {
                return "Small and alert. Good for quick local actions and tool checks."
            }
            if self == .blockTwin {
                return "Paired and steady. Good for compare-and-verify tasks."
            }
            switch blockAspect ?? .compact {
            case .compact:
                return "Compact, deliberate. Good for local code and precise tool work."
            case .wide:
                return "Broad, grounded. Good for multi-step coding and build analysis."
            case .tall:
                return "Tall, watchful. Good for structured review and synthesis."
            }
        case .sage:
            return "Reflective, careful. Good for research, writing, deliberation."
        case .orb:
            return "Balanced default. Good for general chat and exploration."
        }
    }
}
