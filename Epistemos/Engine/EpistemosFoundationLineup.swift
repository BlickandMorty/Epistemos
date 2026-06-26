import Foundation

nonisolated enum EpistemosModelTier: String, Codable, Sendable, CaseIterable {
    case fast
    case think
    case code

    var displayName: String {
        switch self {
        case .fast: "Fast"
        case .think: "Think"
        case .code: "Code"
        }
    }

    var shortName: String { displayName }
    var tagline: String { "App-owned local generation models are removed." }
    var systemImage: String { "xmark.circle" }
}

extension EpistemosOperatingMode {
    var epistemosModelTier: EpistemosModelTier? { nil }
}

nonisolated enum EpistemosFoundationLineup {
    static var simplifiedLineupActive: Bool { false }
    static var models: [GemmaQATRuntimeCandidate] { [] }
    static var foundationModelIDs: Set<String> { [] }
    static let defaultChatModelID = ""

    static func candidates(for tier: EpistemosModelTier) -> [GemmaQATRuntimeCandidate] { [] }
    static func tier(forModelID id: String) -> EpistemosModelTier? { nil }
    static func representativeModelID(for tier: EpistemosModelTier) -> String? { nil }
}

nonisolated enum EpistemosFastEffortSizing {
    enum FastEffort: String, Sendable, CaseIterable {
        case low
        case medium
        case high

        var displayName: String {
            switch self {
            case .low: "Low"
            case .medium: "Medium"
            case .high: "High"
            }
        }
    }

    static var pickerOverrideEnabled: Bool { false }
    static func effort(forComplexity complexity: Double) -> FastEffort { .low }
    static func candidateIndex(forComplexity complexity: Double, candidateCount: Int) -> Int { 0 }
    static func candidateIndex(forEffort effort: FastEffort, candidateCount: Int) -> Int { 0 }
}

nonisolated enum LocalChatModelMemoryGate {
    static let headroomGB = 0
    static func fits(requiredGB: Int, availableGB: Int) -> Bool { false }
    static func blockerReason(modelDisplayName: String, requiredGB: Int, availableGB: Int) -> String {
        "\(modelDisplayName) is unavailable because app-owned local generation models are removed."
    }
}
