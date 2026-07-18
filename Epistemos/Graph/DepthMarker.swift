import Foundation

/// A durable graph depth classification used by visual graph surfaces.
public enum DepthMarker: String, Sendable, Codable, Hashable, CaseIterable {
    case surface
    case synthesized
    case coreBelief

    public var label: String {
        switch self {
        case .surface: return "Surface"
        case .synthesized: return "Synthesized"
        case .coreBelief: return "Core Belief"
        }
    }
}
