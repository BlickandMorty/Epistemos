enum AgentSessionDeletionSovereignGate {
    enum Target: Equatable {
        case session(title: String)
    }

    static func requirement(for _: Target) -> SovereignGateRequirement {
        .deviceOwnerAuthentication
    }

    static func reason(for target: Target) -> String {
        switch target {
        case let .session(title):
            return "Permanently delete agent session \"\(safeName(title))\"."
        }
    }

    private static func safeName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }
}
