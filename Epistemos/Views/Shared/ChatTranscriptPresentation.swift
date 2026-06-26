import Foundation
import SwiftUI

enum ChatLayout {
    static let messageColumnMaxWidth: CGFloat = 760
    static let mainComposerMaxWidth: CGFloat = 860
    static let mainComposerHorizontalPadding: CGFloat = 10
    static let transcriptSpacing: CGFloat = 28
    static let brainPanelWidth: CGFloat = 388
}

enum ChatStreamingDisplayPolicy {
    static let showsLiveResponseText = true
}

struct ChatTranscriptRow: Identifiable, Sendable {
    let message: ChatMessage
    let originalQuery: String?
    let displayContent: String
    let sourceReferences: [AssistantSourceReference]

    var id: String { message.id }
}

enum ChatPresentationFormatter {
    nonisolated static let userModePrefixRegex = FoundationSafety.regularExpression(
        pattern: #"^\[[A-Z ]+MODE\]\s*"#
    )

    nonisolated static func displayContent(
        for message: ChatMessage,
        chatTitle: String? = nil,
        isFirstAssistantMessage: Bool = false
    ) -> String {
        let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard message.role == .user else {
            let final = UserFacingModelOutput.finalVisibleText(from: trimmed)
            var lines = final.components(separatedBy: .newlines)
            if let first = lines.first, first.hasPrefix("# ") {
                let headingText = first.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines)
                let title = chatTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if headingText.caseInsensitiveCompare(title) == .orderedSame || isFirstAssistantMessage {
                    lines.removeFirst()
                    return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            return final
        }

        let fullRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let userModePrefixRegex else {
            return trimmed
        }
        return userModePrefixRegex.stringByReplacingMatches(
            in: trimmed,
            range: fullRange,
            withTemplate: ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func sourceReferences(
        for message: ChatMessage,
        displayContent: String
    ) -> [AssistantSourceReference] {
        guard message.role == .assistant, !message.isError else { return [] }
        return AssistantSourceReference.extract(
            from: displayContent,
            noteTitles: message.loadedNoteTitles ?? []
        )
    }
}

nonisolated func makeChatTranscriptRows(
    from messages: [ChatMessage],
    chatTitle: String?
) -> [ChatTranscriptRow] {
    var lastUserQuery: String?
    var assistantMessageCount = 0
    var rows: [ChatTranscriptRow] = []
    rows.reserveCapacity(messages.count)

    for message in messages {
        if message.role == .user {
            lastUserQuery = message.content
            rows.append(
                ChatTranscriptRow(
                    message: message,
                    originalQuery: nil,
                    displayContent: ChatPresentationFormatter.displayContent(
                        for: message,
                        chatTitle: chatTitle
                    ),
                    sourceReferences: []
                )
            )
            continue
        }

        assistantMessageCount += 1
        let displayContent = ChatPresentationFormatter.displayContent(
            for: message,
            chatTitle: chatTitle,
            isFirstAssistantMessage: assistantMessageCount == 1
        )
        rows.append(
            ChatTranscriptRow(
                message: message,
                originalQuery: lastUserQuery,
                displayContent: displayContent,
                sourceReferences: ChatPresentationFormatter.sourceReferences(
                    for: message,
                    displayContent: displayContent
                )
            )
        )
    }

    return rows
}
