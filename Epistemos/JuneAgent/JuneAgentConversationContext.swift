#if EPISTEMOS_BASE_JUNE
import Foundation

@MainActor
enum JuneAgentConversationContext {
    private static let maxHistoryMessages = 20
    private static let maxTranscriptCharacters = 64 * 1024
    private static let maxMessageCharacters = 8_000
    private static let baseInstructions =
        "You are June, a helpful cloud assistant inside Epistemos. " +
        "You run through the in-process Goose agent_core bridge. Use only the approved June tools, " +
        "ask for approval before reading or writing vault data, and cite vault-derived facts."

    static func boundedHistory(
        _ messages: [JuneSessionStore.Message],
        for _: String
    ) -> [JuneSessionStore.Message] {
        messages.count <= maxHistoryMessages ? messages : Array(messages.suffix(maxHistoryMessages))
    }

    static func agentCloudInstructions(withHistory history: [JuneSessionStore.Message]) -> String {
        let behavior = JuneSystemPromptForge.runtimeLayer(isLocal: false)
        let base = behavior.isEmpty ? baseInstructions : "\(baseInstructions)\n\n\(behavior)"
        let prior = history.dropLast()
        guard !prior.isEmpty else { return base }

        var rows: [String] = []
        var usedCharacters = 0
        for message in prior.reversed() {
            let speaker: String
            switch message.role {
            case "assistant": speaker = "June"
            case "system": speaker = "System"
            case "tool": speaker = "Tool"
            default: speaker = "User"
            }
            let collapsed = message.content
                .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
                .joined(separator: " ")
            let bounded = String(collapsed.prefix(maxMessageCharacters))
            let row = "\(speaker): \(bounded)"
            guard usedCharacters + row.count + (rows.isEmpty ? 0 : 1) <= maxTranscriptCharacters else { break }
            rows.append(row)
            usedCharacters += row.count + (rows.count == 1 ? 0 : 1)
        }
        guard !rows.isEmpty else { return base }
        return "\(base)\n\nConversation so far:\n\(rows.reversed().joined(separator: "\n"))"
    }
}
#endif
