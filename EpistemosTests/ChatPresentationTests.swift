import Testing
@testable import Epistemos

@Suite("Chat Presentation")
struct ChatPresentationTests {
    @Test("transcript rows precompute assistant presentation metadata")
    func transcriptRowsPrecomputeAssistantPresentationMetadata() {
        let messages = [
            ChatMessage(chatId: "chat", role: .user, content: "How does this work?"),
            ChatMessage(
                chatId: "chat",
                role: .assistant,
                content: """
                Sure, here's the answer in brief.

                See [Paper](https://example.com/paper) for details.
                """,
                loadedNoteTitles: ["Field Notes"]
            ),
        ]

        let rows = makeChatTranscriptRows(from: messages)

        #expect(rows.count == 2)
        #expect(rows[0].displayContent == "How does this work?")
        #expect(rows[0].heading == nil)
        #expect(rows[0].sourceReferences.isEmpty)
        #expect(rows[1].originalQuery == "How does this work?")
        #expect(rows[1].heading == "here's the answer in brief.")
        #expect(rows[1].sourceReferences.count == 2)
        #expect(rows[1].sourceReferences[0].kind == .note)
        #expect(rows[1].sourceReferences[0].title == "Field Notes")
        #expect(rows[1].sourceReferences[1].url?.absoluteString == "https://example.com/paper")
    }

    @Test("markdown block cache reuses repeated content")
    func markdownBlockCacheReusesRepeatedContent() {
        TaggedMarkdownTextView.resetBlockCacheForTesting()

        let content = """
        ## Title

        Paragraph

        - one
        - two
        """

        let firstCount = TaggedMarkdownTextView.cachedBlockCount(for: content)
        let firstStats = TaggedMarkdownTextView.blockCacheStatsForTesting()
        let secondCount = TaggedMarkdownTextView.cachedBlockCount(for: content)
        let secondStats = TaggedMarkdownTextView.blockCacheStatsForTesting()

        #expect(firstCount == 4)
        #expect(secondCount == firstCount)
        #expect(firstStats.hits == 0)
        #expect(firstStats.misses == 1)
        #expect(secondStats.hits == 1)
        #expect(secondStats.misses == 1)
    }
}
