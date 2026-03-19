import Foundation
import SwiftUI

// MARK: - Branded Types
// Type-safe wrappers for entity IDs. v3 SwiftData models use plain String IDs,
// but ChatId and MessageId are still used by EventBus and ChatState.

nonisolated protocol BrandedId: RawRepresentable, Hashable, Codable, Sendable,
    CustomStringConvertible
where RawValue == String {}

extension BrandedId {
    nonisolated var description: String { rawValue }
    nonisolated static func new() -> Self { Self(rawValue: UUID().uuidString)! }
}

struct ChatId: BrandedId, @unchecked Sendable {
    nonisolated let rawValue: String
    nonisolated init?(rawValue: String) { self.rawValue = rawValue }
    nonisolated init(_ raw: String) { self.rawValue = raw }
}

struct MessageId: BrandedId, @unchecked Sendable {
    nonisolated let rawValue: String
    nonisolated init?(rawValue: String) { self.rawValue = rawValue }
    nonisolated init(_ raw: String) { self.rawValue = raw }
}

// MARK: - Supporting Types

/// Message role
enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

/// Nav panel identifiers
enum NavTab: String, Codable, Sendable, CaseIterable {
    case home
    case notes
    case settings

    /// Human-readable display name for UI and intents.
    nonisolated var displayName: String {
        switch self {
        case .home: "Home"
        case .notes: "Notes"
        case .settings: "Settings"
        }
    }
}

/// LLM providers
enum LLMProviderType: String, Codable, Sendable, CaseIterable {
    case appleIntelligence
    case localMLX

    /// Display name shown in badges and UI.
    nonisolated var displayName: String {
        switch self {
        case .appleIntelligence: "Apple Intelligence"
        case .localMLX: "Qwen 3.5 Local"
        }
    }

    /// SF Symbol for provider badge.
    nonisolated var iconName: String {
        switch self {
        case .appleIntelligence: "apple.intelligence"
        case .localMLX: "memorychip"
        }
    }

    /// Brand color for each provider.
    var badgeColor: Color {
        switch self {
        case .appleIntelligence: Color.purple
        case .localMLX: Color(red: 0.22, green: 0.64, blue: 0.78)
        }
    }
}
