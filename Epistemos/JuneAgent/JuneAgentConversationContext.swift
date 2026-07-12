#if EPISTEMOS_APP_STORE
import Foundation

@MainActor
enum JuneAgentConversationContext {
    private struct LocalHistoryBudget {
        let maxMessages: Int
        let maxTranscriptCharacters: Int
        let maxMessageCharacters: Int
        let replyBudgetTokens: Int
    }

    private static let maxHistoryMessages = 20
    private static let maxCloudTranscriptCharacters = 64 * 1024
    private static let maxCloudHistoryMessageCharacters = 8_000
    private static let localBaseInstructions =
        "You are June, a helpful on-device assistant inside Epistemos. " +
        "Answer concisely. You cannot browse the web or use tools in this local mode."
    private static let agentCloudBaseInstructions =
        "You are June, a helpful assistant inside Epistemos. " +
        "Use MAS-approved tools only when they help, ask for approval before reading or writing vault data, " +
        "and cite vault-derived facts in the final answer."

    static func boundedHistory(_ messages: [JuneSessionStore.Message]) -> [JuneSessionStore.Message] {
        messages.count <= maxHistoryMessages ? messages : Array(messages.suffix(maxHistoryMessages))
    }

    static func boundedHistory(_ messages: [JuneSessionStore.Message], for modelID: String) -> [JuneSessionStore.Message] {
        let limit = isLocalModelID(modelID) ? localHistoryBudget(for: modelID).maxMessages : maxHistoryMessages
        return messages.count <= limit ? messages : Array(messages.suffix(limit))
    }

    static func localInstructions(withHistory history: [JuneSessionStore.Message], modelID: String) -> String {
        let budget = localHistoryBudget(for: modelID)
        return instructions(
            withHistory: history,
            base: behaviorBase(localBaseInstructions, isLocal: true),
            maxTranscriptCharacters: budget.maxTranscriptCharacters,
            maxMessageCharacters: budget.maxMessageCharacters
        )
    }

    static func agentCloudInstructions(withHistory history: [JuneSessionStore.Message]) -> String {
        instructions(
            withHistory: history,
            base: behaviorBase(agentCloudBaseInstructions, isLocal: false),
            maxTranscriptCharacters: maxCloudTranscriptCharacters,
            maxMessageCharacters: maxCloudHistoryMessageCharacters
        )
    }

    static func localReplyBudgetTokens(for modelID: String) -> Int {
        localHistoryBudget(for: modelID).replyBudgetTokens
    }

    private static func behaviorBase(_ base: String, isLocal: Bool) -> String {
        let layer = JuneSystemPromptForge.runtimeLayer(isLocal: isLocal)
        guard !layer.isEmpty else { return base }
        return "\(base)\n\n\(layer)"
    }

    private static func instructions(
        withHistory history: [JuneSessionStore.Message],
        base: String,
        maxTranscriptCharacters: Int,
        maxMessageCharacters: Int
    ) -> String {
        let prior = history.dropLast()
        guard !prior.isEmpty else { return base }
        var rows: [String] = []
        var usedCharacters = 0
        for msg in prior.reversed() {
            let who: String
            switch msg.role {
            case "assistant":
                who = "June"
            case "system":
                who = "System"
            case "tool":
                who = "Tool"
            default:
                who = "User"
            }
            let content = boundedHistoryContent(msg.content, maxCharacters: maxMessageCharacters)
            let row = "\(who): \(content)"
            let separatorCharacters = rows.isEmpty ? 0 : 1
            let nextUsed = usedCharacters + row.count + separatorCharacters
            guard nextUsed <= maxTranscriptCharacters else {
                if rows.isEmpty {
                    rows.append(String(row.prefix(maxTranscriptCharacters)))
                }
                break
            }
            rows.append(row)
            usedCharacters = nextUsed
        }
        guard !rows.isEmpty else { return base }
        let transcript = rows.reversed().joined(separator: "\n")
        return "\(base)\n\nConversation so far:\n\(transcript)"
    }

    private static func boundedHistoryContent(_ content: String, maxCharacters: Int) -> String {
        let collapsed = content
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .joined(separator: " ")
        guard collapsed.count > maxCharacters else { return collapsed }
        return "\(collapsed.prefix(maxCharacters))..."
    }

    private static func localHistoryBudget(for modelID: String) -> LocalHistoryBudget {
        switch localContextTokens(for: modelID) {
        case ...2_048:
            return LocalHistoryBudget(
                maxMessages: 3,
                maxTranscriptCharacters: 2_400,
                maxMessageCharacters: 700,
                replyBudgetTokens: 384
            )
        case ...4_096:
            return LocalHistoryBudget(
                maxMessages: 4,
                maxTranscriptCharacters: 3_800,
                maxMessageCharacters: 900,
                replyBudgetTokens: 640
            )
        case ...8_192:
            return LocalHistoryBudget(
                maxMessages: 6,
                maxTranscriptCharacters: 6_000,
                maxMessageCharacters: 1_100,
                replyBudgetTokens: 768
            )
        case ...16_384:
            return LocalHistoryBudget(
                maxMessages: 8,
                maxTranscriptCharacters: 10_000,
                maxMessageCharacters: 1_500,
                replyBudgetTokens: 1_024
            )
        default:
            return LocalHistoryBudget(
                maxMessages: 10,
                maxTranscriptCharacters: 14_000,
                maxMessageCharacters: 1_800,
                replyBudgetTokens: 1_024
            )
        }
    }

    private static func localContextTokens(for modelID: String) -> Int {
        if modelID == JuneModelID.appleFM {
            return 4_096
        }
        if modelID == JuneModelID.localGGUF {
            return GGUFModelCatalog.defaultEntry.defaultContextTokens
        }
        if let entry = GGUFModelCatalog.entry(id: modelID) {
            return entry.defaultContextTokens
        }
        return 4_096
    }

    private static func isLocalModelID(_ modelID: String) -> Bool {
        modelID == JuneModelID.appleFM || modelID == JuneModelID.localGGUF || GGUFModelCatalog.entry(id: modelID) != nil
    }
}

#endif
