import Foundation
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

    @Test("chat export surfaces use the shared text export helper instead of silent raw writes")
    func chatExportSurfacesUseSharedTextExportHelper() throws {
        let messageSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/MessageBubble.swift")
        let artifactSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ArtifactBlockView.swift")
        let chatViewSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatView.swift")

        #expect(messageSource.contains("ChatTextExportSupport.save("))
        #expect(artifactSource.contains("ChatTextExportSupport.save("))
        #expect(chatViewSource.contains("ChatTextExportSupport.save("))
        #expect(!messageSource.contains("try? fullContent.write(to: url"))
        #expect(!artifactSource.contains("try? content.write(to: url"))
        #expect(!chatViewSource.contains("try md.write(to: url"))
    }

    @Test("tool preview cards start collapsed so read-only tool chatter stays out of the way")
    func toolPreviewCardsStartCollapsed() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/MessageBubble.swift")

        #expect(source.contains("@State private var isExpanded = false"))
    }

    @Test("chat brain picker mirrors the release-selectable local model set")
    func chatBrainPickerMirrorsReleaseSelectableLocalModels() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatBrainPickerMenu.swift")

        #expect(source.contains("inference.releaseSelectableInstalledLocalTextModelIDs"))
        #expect(!source.contains("Array(inference.installedLocalTextModelIDs)"))
        #expect(source.contains("inference.activeChatModelDisplayName"))
    }

    @Test("chat brain picker exposes operating mode choices when chat surfaces pass a binding")
    func chatBrainPickerExposesOperatingModes() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatBrainPickerMenu.swift")

        #expect(source.contains("Section(\"Mode\")"))
        #expect(source.contains("operatingMode: Binding<EpistemosOperatingMode>?"))
        #expect(source.contains("availableOperatingModes: [EpistemosOperatingMode]?"))
    }

    @Test("chat brain picker simplifies cloud switching to one shared cloud row")
    func chatBrainPickerSimplifiesCloudSwitching() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatBrainPickerMenu.swift")

        #expect(source.contains("private var pickerCloudModel: CloudTextModelID?"))
        #expect(source.contains("Section(\"Cloud\")"))
        #expect(source.contains("inference.preferredCloudModel(for: provider)"))
        #expect(!source.contains("Section(\"Routing\")"))
        #expect(!source.contains("inference.setChatAutoRouteToCloud("))
    }

    @Test("chat capability surfaces avoid repeatForever pulse loops")
    func chatCapabilitySurfacesAvoidRepeatForeverPulseLoops() throws {
        let pillSource = try loadMirroredSourceTextFile("Epistemos/Views/Shared/ChatCapabilityPill.swift")
        let thinkingSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ThinkingPopoverView.swift")

        #expect(!pillSource.contains("repeatForever("))
        #expect(!thinkingSource.contains("repeatForever("))
        #expect(pillSource.contains(".breathe("))
        #expect(thinkingSource.contains(".breathe("))
    }

    @Test("chat text export support writes content and throws for unwritable destinations")
    func chatTextExportSupportWritesContentAndThrowsForUnwritableDestinations() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "chat-export-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("message.md")
        try ChatTextExportSupport.write("export body", to: fileURL)

        let written = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(written == "export body")

        #expect(throws: CocoaError.self) {
            try ChatTextExportSupport.write("should fail", to: directory)
        }
    }

    @Test("chat sidebar delete only clears the active session after a saved delete and surfaces failures")
    func chatSidebarDeleteDefersClearingUntilSaveSucceeds() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatSidebarView.swift")

        let saveRange = try #require(source.range(of: "try modelContext.save()"))
        let clearRange = try #require(source.range(of: "chat.clearMessages()"))

        #expect(!source.contains("modelContext.rollback()"))
        #expect(source.contains("modelContext.insert(sdChat)"))
        #expect(source.contains("sdChat.messages = originalMessages"))
        #expect(source.contains("deleteErrorMessage = error.localizedDescription"))
        #expect(source.contains(".alert(\"Couldn't Delete Chat\""))
        #expect(saveRange.lowerBound < clearRange.lowerBound)
    }
}
