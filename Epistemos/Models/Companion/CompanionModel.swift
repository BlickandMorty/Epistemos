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

    init(
        id: String = UUID().uuidString,
        name: String,
        tagline: String = "",
        bodyKind: CompanionBodyKind = .orb,
        accentHex: String = "#7BA8E0",
        loraAdapterPath: String? = nil,
        personaPrompt: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.tagline = tagline
        self.bodyKindRaw = bodyKind.rawValue
        self.accentHex = accentHex
        self.loraAdapterPath = loraAdapterPath
        self.personaPrompt = personaPrompt
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
    private static func computeIdentityHash(id: String, bodyKindRaw: String, name: String) -> String {
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
/// Block is parameterized; Hermes Snake is a graph faculty glyph, not a Farm body.
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

nonisolated struct CompanionBodyKind: RawRepresentable, Codable, Sendable, Hashable {
    let family: CompanionBodyFamily
    let blockAspect: CompanionBlockAspect?
    let legStyle: CompanionLegStyle?
    let antennaStyle: CompanionAntennaStyle?
    let eyeTreatment: CompanionEyeTreatment?

    private init(
        family: CompanionBodyFamily,
        blockAspect: CompanionBlockAspect? = nil,
        legStyle: CompanionLegStyle? = nil,
        antennaStyle: CompanionAntennaStyle? = nil,
        eyeTreatment: CompanionEyeTreatment? = nil
    ) {
        self.family = family
        self.blockAspect = blockAspect
        self.legStyle = legStyle
        self.antennaStyle = antennaStyle
        self.eyeTreatment = eyeTreatment
    }

    static func block(
        aspect: CompanionBlockAspect,
        legs: CompanionLegStyle,
        antennae: CompanionAntennaStyle,
        eyeTreatment: CompanionEyeTreatment
    ) -> CompanionBodyKind {
        CompanionBodyKind(
            family: .block,
            blockAspect: aspect,
            legStyle: legs,
            antennaStyle: antennae,
            eyeTreatment: eyeTreatment
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

    static let orb = CompanionBodyKind(family: .orb)
    static let sage = CompanionBodyKind(family: .sage)

    static let creationPresets: [CompanionBodyKind] = [
        .blockCompact,
        .blockWide,
        .orb,
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
        case "sage":
            self = .sage
        case "orb":
            self = .orb
        default:
            let parts = rawValue.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 5,
                  parts[0] == CompanionBodyFamily.block.rawValue,
                  let aspect = CompanionBlockAspect(rawValue: parts[1]),
                  let legs = CompanionLegStyle(rawValue: parts[2]),
                  let antennae = CompanionAntennaStyle(rawValue: parts[3]),
                  let eyes = CompanionEyeTreatment(rawValue: parts[4]) else {
                return nil
            }
            self = .block(
                aspect: aspect,
                legs: legs,
                antennae: antennae,
                eyeTreatment: eyes
            )
        }
    }

    var rawValue: String {
        switch family {
        case .block:
            let aspect = blockAspect ?? .compact
            let legs = legStyle ?? .stubs
            let antennae = antennaStyle ?? .none
            let eyes = eyeTreatment ?? .filled
            return "block.\(aspect.rawValue).\(legs.rawValue).\(antennae.rawValue).\(eyes.rawValue)"
        case .sage:
            return CompanionBodyFamily.sage.rawValue
        case .orb:
            return CompanionBodyFamily.orb.rawValue
        }
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
