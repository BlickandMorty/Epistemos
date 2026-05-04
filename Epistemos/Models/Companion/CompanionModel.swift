import Foundation
import SwiftData

/// Persisted Companion record. SwiftData @Model so the Farm view can
/// query and react to companion lifecycle changes natively.
///
/// Per the Simulation Mode v1.6 doctrine (T6 hackathon Block B):
/// - Each Companion is a lightweight identity attached to one shared
///   base substrate (the active model selection).
/// - Cosmetic config (body grammar: Block / Sage / Orb / Hermes Snake)
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
    /// Body grammar — see CompanionBodyKind for the four variants.
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

/// The four canonical body grammars from the Simulation v1.6 doctrine.
/// Each one is a distinct visual archetype with its own animation
/// vocabulary in CompanionView.
nonisolated enum CompanionBodyKind: String, Codable, Sendable, CaseIterable {
    case block         // Heavy presence — square outline, slow breathing
    case sage          // Tall robed silhouette — vertical orientation
    case orb           // Default — soft sphere with halo
    case hermesSnake   // Sinuous winged — Hermes' caduceus, used for orchestrator/runtime

    var displayName: String {
        switch self {
        case .block:        return "Block"
        case .sage:         return "Sage"
        case .orb:          return "Orb"
        case .hermesSnake:  return "Hermes Snake"
        }
    }

    var systemImageName: String {
        switch self {
        case .block:        return "square.fill"
        case .sage:         return "figure.stand.dress"
        case .orb:          return "circle.fill"
        case .hermesSnake:  return "wand.and.stars"
        }
    }

    /// Tagline hint shown in the creation wizard.
    var hint: String {
        switch self {
        case .block:        return "Heavy, deliberate. Good for code, build, and analysis work."
        case .sage:         return "Reflective, careful. Good for research, writing, deliberation."
        case .orb:          return "Balanced default. Good for general chat and exploration."
        case .hermesSnake:  return "Sinuous, orchestrated. The runtime's own face — used for system events."
        }
    }
}
