import Foundation

enum KnowledgeFusionAdapterDeletionSovereignGate: Equatable {
    case adapter(name: String)

    static func requirement(for target: KnowledgeFusionAdapterDeletionSovereignGate) -> SovereignGateRequirement {
        .deviceOwnerAuthentication
    }

    static func reason(for target: KnowledgeFusionAdapterDeletionSovereignGate) -> String {
        switch target {
        case let .adapter(name):
            return "Permanently delete adapter \"\(safeName(name))\"."
        }
    }

    private static func safeName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }
}
