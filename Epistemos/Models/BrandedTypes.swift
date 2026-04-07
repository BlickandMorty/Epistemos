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

struct ChatId: BrandedId, Sendable {
    nonisolated let rawValue: String
    nonisolated init?(rawValue: String) { self.rawValue = rawValue }
    nonisolated init(_ raw: String) { self.rawValue = raw }
}

struct MessageId: BrandedId, Sendable {
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
        case .omega: "Agent Runtime"
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
    case zai
    case kimi
    case minimax
    case deepseek

    /// Display name shown in badges and UI.
    nonisolated var displayName: String {
        switch self {
        case .appleIntelligence: "Apple Intelligence"
        case .localMLX: "Local Model"
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .google: "Google"
        case .zai: "Z.AI / GLM"
        case .kimi: "Kimi / Moonshot"
        case .minimax: "MiniMax"
        case .deepseek: "DeepSeek"
        }
    }

    /// SF Symbol for provider badge.
    nonisolated var iconName: String {
        switch self {
        case .appleIntelligence: "apple.intelligence"
        case .localMLX: "memorychip"
        case .openAI: "sparkles.rectangle.stack"
        case .anthropic: "brain.head.profile"
        case .google: "diamond"
        case .zai: "bolt.horizontal.circle"
        case .kimi: "moon.stars"
        case .minimax: "paperplane.circle"
        case .deepseek: "water.waves"
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
        case .zai: Color(red: 0.16, green: 0.62, blue: 0.92)
        case .kimi: Color(red: 0.41, green: 0.48, blue: 0.94)
        case .minimax: Color(red: 0.98, green: 0.42, blue: 0.24)
        case .deepseek: Color(red: 0.10, green: 0.68, blue: 0.74)
        }
    }
}
