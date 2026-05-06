import Foundation

/// Native session-status surface for `/status` per
/// `HERMES_CAPABILITY_PARITY_TARGET_2026_05_03.md` — Session row.
///
/// Returns a `LocalAgentSessionStatus` snapshot the UI can format into the
/// status panel. **Core-safe**: pure value composition over already-known
/// session state. The caller injects current values; this file does not
/// reach into globals.
nonisolated struct LocalAgentStatusCommand: Equatable, Sendable {
    var requiresApproval: Bool { false }

    static func parse(_ rawCommand: String) -> LocalAgentStatusCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "/status" else {
            return nil
        }
        return LocalAgentStatusCommand()
    }

    /// Build a status snapshot from a snapshot input. The UI fills the
    /// fields it knows; missing fields render as "—" so the panel is
    /// always meaningful even before all sources are wired.
    func snapshot(from input: LocalAgentSessionStatusInput) -> LocalAgentSessionStatus {
        LocalAgentSessionStatus(
            providerLabel: input.providerLabel ?? "—",
            modelLabel: input.modelLabel ?? "—",
            sessionID: input.sessionID ?? "—",
            turnsThisSession: input.turnsThisSession ?? 0,
            messagesInContext: input.messagesInContext ?? 0,
            inputTokensUsed: input.inputTokensUsed ?? 0,
            outputTokensUsed: input.outputTokensUsed ?? 0,
            cumulativeCostUSD: input.cumulativeCostUSD ?? 0,
            isAgentMode: input.isAgentMode ?? false,
            sovereignGraceCategoriesActive: input.sovereignGraceCategoriesActive ?? 0,
            generatedAt: input.generatedAt ?? Date()
        )
    }
}

/// Caller-provided snapshot input. Optionals so callers wire what they have.
nonisolated struct LocalAgentSessionStatusInput: Equatable, Sendable {
    var providerLabel: String?
    var modelLabel: String?
    var sessionID: String?
    var turnsThisSession: Int?
    var messagesInContext: Int?
    var inputTokensUsed: Int?
    var outputTokensUsed: Int?
    var cumulativeCostUSD: Double?
    var isAgentMode: Bool?
    var sovereignGraceCategoriesActive: Int?
    var generatedAt: Date?

    init(
        providerLabel: String? = nil,
        modelLabel: String? = nil,
        sessionID: String? = nil,
        turnsThisSession: Int? = nil,
        messagesInContext: Int? = nil,
        inputTokensUsed: Int? = nil,
        outputTokensUsed: Int? = nil,
        cumulativeCostUSD: Double? = nil,
        isAgentMode: Bool? = nil,
        sovereignGraceCategoriesActive: Int? = nil,
        generatedAt: Date? = nil
    ) {
        self.providerLabel = providerLabel
        self.modelLabel = modelLabel
        self.sessionID = sessionID
        self.turnsThisSession = turnsThisSession
        self.messagesInContext = messagesInContext
        self.inputTokensUsed = inputTokensUsed
        self.outputTokensUsed = outputTokensUsed
        self.cumulativeCostUSD = cumulativeCostUSD
        self.isAgentMode = isAgentMode
        self.sovereignGraceCategoriesActive = sovereignGraceCategoriesActive
        self.generatedAt = generatedAt
    }
}

/// Resolved session status. UI renders the rows in declared order.
nonisolated struct LocalAgentSessionStatus: Equatable, Sendable {
    let providerLabel: String
    let modelLabel: String
    let sessionID: String
    let turnsThisSession: Int
    let messagesInContext: Int
    let inputTokensUsed: Int
    let outputTokensUsed: Int
    let cumulativeCostUSD: Double
    let isAgentMode: Bool
    let sovereignGraceCategoriesActive: Int
    let generatedAt: Date

    var totalTokensUsed: Int { inputTokensUsed + outputTokensUsed }

    /// One-shot text rendering for the chat surface. Stable order.
    func renderText() -> String {
        var lines: [String] = []
        lines.append("Session status:")
        lines.append("  Provider:           \(providerLabel)")
        lines.append("  Model:              \(modelLabel)")
        lines.append("  Session ID:         \(sessionID)")
        lines.append("  Turns:              \(turnsThisSession)")
        lines.append("  Messages in ctx:    \(messagesInContext)")
        lines.append("  Tokens (in/out):    \(inputTokensUsed) / \(outputTokensUsed) (total \(totalTokensUsed))")
        lines.append("  Cost (USD):         \(String(format: "%.4f", cumulativeCostUSD))")
        lines.append("  Agent mode:         \(isAgentMode ? "yes" : "no")")
        lines.append("  Sovereign grace:    \(sovereignGraceCategoriesActive) active categor\(sovereignGraceCategoriesActive == 1 ? "y" : "ies")")
        return lines.joined(separator: "\n")
    }
}
