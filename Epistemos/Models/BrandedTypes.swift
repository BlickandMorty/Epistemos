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
    case anthropic
    case openai
    case google
    case kimi
    case ollama
    case appleIntelligence

    /// Display name shown in badges and UI.
    nonisolated var displayName: String {
        switch self {
        case .anthropic: "Claude"
        case .openai: "GPT"
        case .google: "Gemini"
        case .kimi: "Kimi"
        case .ollama: "Ollama"
        case .appleIntelligence: "Apple AI"
        }
    }

    /// SF Symbol for provider badge.
    nonisolated var iconName: String {
        switch self {
        case .anthropic: "sparkle"
        case .openai: "circle.hexagongrid"
        case .google: "diamond"
        case .kimi: "moon.stars"
        case .ollama: "server.rack"
        case .appleIntelligence: "apple.intelligence"
        }
    }

    /// Brand color for each provider.
    var badgeColor: Color {
        switch self {
        case .anthropic: Color(red: 0.85, green: 0.55, blue: 0.20)  // Warm amber
        case .openai: Color(red: 0.06, green: 0.64, blue: 0.50)  // Emerald green
        case .google: Color(red: 0.26, green: 0.52, blue: 0.96)  // Google blue
        case .kimi: Color(red: 0.45, green: 0.35, blue: 0.85)  // Moonlight purple
        case .ollama: Color(red: 0.30, green: 0.75, blue: 0.55)  // Teal green
        case .appleIntelligence: Color.purple
        }
    }
}
