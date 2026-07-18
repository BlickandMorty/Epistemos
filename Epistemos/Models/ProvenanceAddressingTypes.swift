import Foundation

/// Durable five-plane address for provenance records.
///
/// This is deliberately model-only metadata. It preserves the stable on-disk
/// address of existing `AcsAnchor` records after the paid runtime router is
/// removed from Free V1; it does not select, start, or describe an inference
/// runtime.
nonisolated public enum RuntimePlane: String, Hashable, Sendable, Codable, CaseIterable {
    case state
    case episodic
    case assembly
    case controller
    case verification

    public var displayName: String { rawValue.capitalized }
}

/// Durable residency classification for provenance records.
///
/// Like `RuntimePlane`, this remains only so persisted provenance can round
/// trip honestly. It is not a capability policy or a provider-routing surface.
nonisolated public enum ResidencyTier: String, Hashable, Sendable, Codable, CaseIterable {
    case currentApp = "current_app"
    case verifiedFloor = "verified_floor"
    case capabilityCeiling = "capability_ceiling"

    public var displayName: String {
        switch self {
        case .currentApp: return "Current App"
        case .verifiedFloor: return "Verified Floor"
        case .capabilityCeiling: return "Capability Ceiling"
        }
    }
}
