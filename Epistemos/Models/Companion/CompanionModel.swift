import Foundation
import SwiftData

/// Persisted Companion record. SwiftData @Model so the Farm view can
/// query and react to companion lifecycle changes natively.
///
/// Per the Simulation Mode v1.6 doctrine (T6 hackathon Block B):
/// - Each Companion is a lightweight visual identity. It does not own
///   model, prompt, tool, MCP, approval, or autonomous runtime authority.
/// - Cosmetic config (body grammar: parameterized Block / Sage / Orb)
///   maps to the mascot renderer only.
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
    var name: String = ""
    /// One-liner tagline shown beneath the orb in the Farm.
    var tagline: String = ""
    /// Body grammar — see CompanionBodyKind for the parameterized Farm variants.
    /// Stored as raw string for SwiftData friendliness.
    var bodyKindRaw: String = "orb"
    /// Hex-coded accent color (e.g. "#7BA8E0"). Drives the mascot halo.
    var accentHex: String = "#7BA8E0"
    /// Stable seed for DeterministicPRNG. Computed at creation from
    /// (id + bodyKindRaw + name) so cosmetic randomness is replayable.
    var identityHash: String = ""
    /// When the companion was created.
    var createdAt: Date = Date.now
    /// When the companion was last brought to the foreground (for
    /// "recent" sorting in the Farm).
    var lastInteractedAt: Date = Date.now
    /// When the companion was archived (soft-deleted). Non-nil = in
    /// trash; restorable. Nil = active.
    var archivedAt: Date?

    init(
        id: String = UUID().uuidString,
        name: String,
        tagline: String = "",
        bodyKind: CompanionBodyKind = .orb,
        accentHex: String = "#7BA8E0",
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.tagline = tagline
        self.bodyKindRaw = bodyKind.rawValue
        self.accentHex = accentHex
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

    var isArchived: Bool { archivedAt != nil }

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
