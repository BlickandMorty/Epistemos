import Foundation
import SwiftData
import SwiftUI

// ---------------------------------------------------------------------------
// MARK: - CosmeticConfig
// ---------------------------------------------------------------------------

/// Visual and behavioural configuration for a companion.
///
/// `CosmeticConfig` is entirely cosmetic — it does not affect model inference.
/// In the Pro tier `voiceHint` maps to an ElevenLabs voice ID.
public struct CosmeticConfig: Codable, Equatable, Sendable {
    public var colorTheme: String       // e.g. "amber", "teal", "violet"
    public var avatarShape: String        // e.g. "orb", "shard", "pulse"
    public var idleBreathingRate: Double  // 0.5 = slow, 2.0 = fast
    public var voiceHint: String?         // nil in Core, voice ID in Pro

    public init(
        colorTheme: String = "amber",
        avatarShape: String = "orb",
        idleBreathingRate: Double = 1.0,
        voiceHint: String? = nil
    ) {
        self.colorTheme = colorTheme
        self.avatarShape = avatarShape
        self.idleBreathingRate = idleBreathingRate
        self.voiceHint = voiceHint
    }
}

// ---------------------------------------------------------------------------
// MARK: - CompanionModel
// ---------------------------------------------------------------------------

/// A SwiftData model representing a persistent companion entity.
///
/// `CompanionModel` stores identity, profile selection, cosmetics, and
/// archival state. It is the backing store for `CompanionState`.
@Model
public final class CompanionModel {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var baseProfile: String        // e.g. "default", "research", "coding"
    public var cosmeticConfig: CosmeticConfig
    public var createdAt: Date
    public var lastActiveAt: Date
    public var isArchived: Bool
    public var personalityVector: [Float]? // Resonance Gate δ vector (Pro tier, nil in Core)

    public init(
        id: UUID = UUID(),
        name: String,
        baseProfile: String,
        cosmeticConfig: CosmeticConfig,
        createdAt: Date = Date(),
        lastActiveAt: Date = Date(),
        isArchived: Bool = false,
        personalityVector: [Float]? = nil
    ) {
        self.id = id
        self.name = name
        self.baseProfile = baseProfile
        self.cosmeticConfig = cosmeticConfig
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
        self.isArchived = isArchived
        self.personalityVector = personalityVector
    }
}

// ---------------------------------------------------------------------------
// MARK: - Helpers
// ---------------------------------------------------------------------------

extension CompanionModel {
    /// Human-readable relative timestamp (e.g. "2h ago").
    public var relativeLastActive: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastActiveAt, relativeTo: Date())
    }

    /// Color derived from the cosmetic theme.
    public var themeColor: Color {
        switch cosmeticConfig.colorTheme {
        case "amber":  return Color(red: 1.0, green: 0.6, blue: 0.0)
        case "teal":   return Color(red: 0.0, green: 0.6, blue: 0.6)
        case "violet": return Color(red: 0.5, green: 0.2, blue: 0.8)
        case "rose":   return Color(red: 0.9, green: 0.3, blue: 0.4)
        case "slate":  return Color(red: 0.4, green: 0.4, blue: 0.5)
        default:       return Color.accentColor
        }
    }
}
