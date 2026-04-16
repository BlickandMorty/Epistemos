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

        let rows = makeChatTranscriptRows(from: messages, chatTitle: nil)

        #expect(rows.count == 2)
        #expect(rows[0].displayContent == "How does this work?")
        #expect(rows[0].heading == nil)
        #expect(rows[0].sourceReferences.isEmpty)
        #expect(rows[1].originalQuery == "How does this work?")
        #expect(rows[1].heading == nil)
        #expect(rows[1].sourceReferences.count == 2)
        #expect(rows[1].sourceReferences[0].kind == AssistantSourceKind.note)
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

    @Test("chat markdown parser preserves nested and task list metadata")
    func chatMarkdownParserPreservesNestedAndTaskListMetadata() {
        let content = """
        - Top level
          - Nested bullet
        - [x] Completed task
        1. First step
          2. Nested step
        """

        let blocks = TaggedMarkdownTextView.debugBlockSummaries(for: content)

        #expect(blocks == [
            "bullet@0:Top level",
            "bullet@1:Nested bullet",
            "check@0:true:Completed task",
            "numbered@0:1.:First step",
            "numbered@1:2.:Nested step",
        ])
    }

    @Test("chat markdown groups consecutive list items into one tight render run")
    func chatMarkdownGroupsConsecutiveListItemsIntoOneRenderRun() {
        let content = """
        Intro paragraph

        - One
        - Two
        - [ ] Three
        1. Four
        """

        let renderUnits = TaggedMarkdownTextView.debugRenderUnitSummaries(for: content)

        #expect(renderUnits == [
            "paragraph",
            "list:4",
        ])
    }

    @Test("chat H1 and H2 markdown keep the retro display font path")
    func chatH1AndH2MarkdownKeepTheRetroDisplayFontPath() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/TaggedMarkdownTextView.swift")

        #expect(source.contains("if level == 1 || level == 2"))
        #expect(source.contains("return .custom(AppDisplayTypography.displayFontName, size: fontSize)"))
    }

    @Test("chat typography references Claude's Anthropic font families")
    func chatTypographyReferencesClaudesAnthropicFontFamilies() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Theme/EpistemosTheme.swift")

        #expect(source.contains("\"Anthropic Serif\""))
        #expect(source.contains("\"Anthropic Sans\""))
    }

    @Test("artifact cards expose a rendered versus markdown presentation toggle")
    func artifactCardsExposeARenderedVersusMarkdownPresentationToggle() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ArtifactBlockView.swift")

        #expect(source.contains("MarkdownDocumentModeToggle(mode: documentPresentationModeBinding)"))
        #expect(source.contains("case .csv, .table, .markdown:"))
        #expect(source.contains("rawSourceContent"))
    }
}
