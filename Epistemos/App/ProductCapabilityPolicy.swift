import Foundation

nonisolated enum ProductEdition: String, Sendable {
    case freeV1
    case futurePaid
}

nonisolated enum ProductCapability: String, CaseIterable, Sendable {
    case agentAutomation
    case browser
    case epdocAssist
    case epdocPlanner
    case generativeActions
    case june
    case knowledgeGraph
    case kokoroVoice
    case meeting
    case models
    case pdfImport
    case quickCapture
    case reckoner
    case researchHub
    case search
    case sync
    case workspaceExport

    var edition: ProductEdition {
        switch self {
        case .agentAutomation,
             .browser,
             .epdocAssist,
             .generativeActions,
             .june,
             .models,
             .researchHub:
            .futurePaid
        case .epdocPlanner,
             .knowledgeGraph,
             .kokoroVoice,
             .meeting,
             .pdfImport,
             .quickCapture,
             .reckoner,
             .search,
             .sync,
             .workspaceExport:
            .freeV1
        }
    }
}

nonisolated enum ProductCapabilityPolicy {
    /// StoreKit and purchase state are deliberately not part of the first free
    /// release. A later paid build can replace this single edition selector.
    static let currentEdition: ProductEdition = .freeV1

    static let freeCapabilities = ProductCapability.allCases.filter { $0.edition == .freeV1 }
    static let paidCapabilities = ProductCapability.allCases.filter { $0.edition == .futurePaid }

    static func isAvailable(_ capability: ProductCapability) -> Bool {
        switch currentEdition {
        case .freeV1:
            capability.edition == .freeV1
        case .futurePaid:
            true
        }
    }
}

nonisolated struct ProductCapabilityUnavailableError: LocalizedError, Sendable {
    let capability: ProductCapability

    var errorDescription: String? {
        "This capability is reserved for a future paid Epistemos edition."
    }
}
