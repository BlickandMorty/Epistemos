import Foundation
import SwiftUI

// MARK: - Branded Types
// Type-safe wrappers for entity IDs. v3 SwiftData models use plain String IDs,
// but ChatId and MessageId are still used by EventBus and ChatState.

nonisolated protocol BrandedId: RawRepresentable, Hashable, Codable, Sendable,
    CustomStringConvertible
where RawValue == String {
    init(_ raw: String)
}

extension BrandedId {
    nonisolated var description: String { rawValue }
    nonisolated static func new() -> Self { Self(UUID().uuidString) }
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
    case omega
    case settings

    /// Human-readable display name for UI and intents.
    nonisolated var displayName: String {
        switch self {
        case .home: "Home"
        case .notes: "Notes"
        case .omega: "Omega"
        case .settings: "Settings"
        }
    }
}

/// LLM providers
enum LLMProviderType: String, Codable, Sendable, CaseIterable {
    case appleIntelligence
    case localMLX
    case openAI
    case anthropic
    case google

    /// Display name shown in badges and UI.
    nonisolated var displayName: String {
        switch self {
        case .appleIntelligence: "Apple Intelligence"
        case .localMLX: "Local Model"
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .google: "Google"
        }
    }

    /// SF Symbol for provider badge.
    nonisolated var iconName: String {
        switch self {
        case .appleIntelligence: "apple.intelligence"
        case .localMLX: "memorychip"
        case .openAI: "sparkles.rectangle.stack"
        case .anthropic: "brain.head.profile"
        case .google: "cloud"
        }
    }

    /// Brand color for each provider.
    var badgeColor: Color {
        switch self {
        case .appleIntelligence: Color.purple
        case .localMLX: Color(red: 0.22, green: 0.64, blue: 0.78)
        case .openAI: Color(red: 0.07, green: 0.67, blue: 0.54)
        case .anthropic: Color(red: 0.77, green: 0.48, blue: 0.18)
        case .google: Color(red: 0.24, green: 0.52, blue: 0.96)
        }
    }
}
