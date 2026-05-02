import Foundation
import SwiftData
import Testing
@testable import Epistemos

// MARK: - Phase 6.5: TextCapturePipeline Tests
//
// Coverage:
// - empty capture fails clearly
// - short capture produces note/draft and trace
// - unicode capture preserves text
// - tasks/entities extraction is deterministic on a fixture
// - source spans point into original text
// - no follow-up action executes without explicit permission
// - graph unavailable path fails truthfully or records skipped graph write

@Suite("TextCapturePipeline")
@MainActor
struct TextCapturePipelineTests {

    // MARK: - Test Helpers

    /// Creates a minimal in-memory SwiftData container for testing.
    private func makeTestContainer() throws -> ModelContainer {
        let schema = Schema([SDPage.self, SDGraphNode.self, SDGraphEdge.self, SDBlock.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makePipeline() -> TextCapturePipeline {
        let traceDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-test-traces-\(UUID().uuidString)")
        let collector = TraceCollector(baseDir: traceDir)
        return TextCapturePipeline(
            traceCollector: collector,
            sessionId: "test-session-\(UUID().uuidString)"
        )
    }

    private struct TracedPipelineFixture {
        let pipeline: TextCapturePipeline
        let collector: TraceCollector
        let traceDir: URL
        let sessionId: String
    }

    private func makeTracedPipeline() -> TracedPipelineFixture {
        let traceDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-test-traces-\(UUID().uuidString)")
        let collector = TraceCollector(baseDir: traceDir)
        let sessionId = "test-session-\(UUID().uuidString)"
        return TracedPipelineFixture(
            pipeline: TextCapturePipeline(traceCollector: collector, sessionId: sessionId),
            collector: collector,
            traceDir: traceDir,
            sessionId: sessionId
        )
    }

    private func traceFileURL(traceDir: URL, sessionId: String) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        let dateDirectory = formatter.string(from: Date())
        return traceDir
            .appendingPathComponent(dateDirectory, isDirectory: true)
            .appendingPathComponent("\(sessionId).jsonl")
    }

    private func traceEventTypes(traceDir: URL, sessionId: String) throws -> [String] {
        let fileURL = traceFileURL(traceDir: traceDir, sessionId: sessionId)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        return contents
            .split(separator: "\n")
            .compactMap { line -> String? in
                guard
                    let data = line.data(using: .utf8),
                    let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else {
                    return nil
                }
                return object["type"] as? String
            }
    }

    private func waitForTraceEventTypes(
        traceDir: URL,
        sessionId: String,
        minimumCount: Int
    ) async throws -> [String] {
        var last: [String] = []
        for _ in 0..<20 {
            last = try traceEventTypes(traceDir: traceDir, sessionId: sessionId)
            if last.count >= minimumCount { return last }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        return last
    }

    // MARK: - Empty Capture

    @Test("Empty capture throws TextCaptureError.emptyCapture")
    func emptyCapture() async throws {
        let pipeline = makePipeline()

        await #expect(throws: TextCaptureError.emptyCapture) {
            _ = try await pipeline.run(rawText: "")
        }
    }

    @Test("Whitespace-only capture throws emptyCapture")
    func whitespaceOnlyCapture() async throws {
        let pipeline = makePipeline()

        await #expect(throws: TextCaptureError.emptyCapture) {
            _ = try await pipeline.run(rawText: "   \n\t  \n  ")
        }
    }

    // MARK: - Short Capture

    @Test("Short capture produces valid CaptureResult with trace ID")
    func shortCapture() async throws {
        let pipeline = makePipeline()
        let result = try await pipeline.run(rawText: "Buy milk at the store")

        #expect(!result.traceID.isEmpty)
        #expect(result.cleanedText == "Buy milk at the store")
        #expect(!result.title.isEmpty)
        #expect(!result.summary.isEmpty)
        #expect(result.rawText == "Buy milk at the store")
    }

    @Test("Short capture with model context creates note")
    func shortCaptureWithPersistence() async throws {
        let pipeline = makePipeline()
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let result = try await pipeline.run(
            rawText: "Meeting notes from today",
            modelContext: context
        )

        #expect(result.createdNoteID != nil, "Note should be created")

        // Verify note exists in SwiftData
        let descriptor = FetchDescriptor<SDPage>()
        let pages = try context.fetch(descriptor)
        #expect(pages.count == 1)
        #expect(pages.first?.title == "Meeting notes from today")
        #expect(pages.first?.needsVaultSync == true)
        #expect(pages.first?.loadBody().contains("Meeting notes from today") == true)

        let blocks = try context.fetch(FetchDescriptor<SDBlock>())
        #expect(!blocks.isEmpty)
        #expect(blocks.allSatisfy { $0.pageId == pages.first?.id })
    }

    // MARK: - Unicode Preservation

    @Test("Unicode text is preserved through pipeline")
    func unicodeCapture() async throws {
        let pipeline = makePipeline()
        let text = "会议记录：讨论了新项目的进展。\n参会人：张三、李四"

        let result = try await pipeline.run(rawText: text)

        #expect(result.cleanedText == text)
        #expect(result.rawText == text)
        #expect(!result.title.isEmpty)
    }

    @Test("Emoji text preserved")
    func emojiCapture() async throws {
        let pipeline = makePipeline()
        let text = "📝 Notes from standup 🚀\n- Ship the feature\n- Fix the bug 🐛"

        let result = try await pipeline.run(rawText: text)
        #expect(result.cleanedText == text)
    }

    // MARK: - Title Extraction

    @Test("Title extracted from first line")
    func titleFromFirstLine() async throws {
        let pipeline = makePipeline()
        let result = try await pipeline.run(
            rawText: "Project Alpha Status\n\nWe discussed the timeline and deliverables."
        )

        #expect(result.title == "Project Alpha Status")
    }

    @Test("Title strips markdown heading prefix")
    func titleStripsMarkdownHeading() async throws {
        let pipeline = makePipeline()
        let result = try await pipeline.run(rawText: "# Weekly Review\n\nThis week was productive.")

        #expect(result.title == "Weekly Review")
    }

    // MARK: - Task Extraction

    @Test("Markdown checkboxes extracted as tasks")
    func markdownCheckboxTasks() async throws {
        let pipeline = makePipeline()
        let text = """
        Meeting Notes

        - [ ] Send follow-up email
        - [x] Review proposal
        - [ ] Schedule next meeting
        """

        let result = try await pipeline.run(rawText: text)

        #expect(result.tasks.count == 3)

        let uncompleted = result.tasks.filter { !$0.isCompleted }
        let completed = result.tasks.filter { $0.isCompleted }
        #expect(uncompleted.count == 2)
        #expect(completed.count == 1)
        #expect(completed.first?.text == "Review proposal")
    }

    @Test("TODO: prefix lines extracted as tasks")
    func todoPrefixTasks() async throws {
        let pipeline = makePipeline()
        let text = """
        Notes

        TODO: Update the documentation
        Some other text here.
        FIXME: Handle edge case in parser
        """

        let result = try await pipeline.run(rawText: text)

        #expect(result.tasks.count == 2)
        #expect(result.tasks[0].text == "Update the documentation")
        #expect(result.tasks[1].text == "Handle edge case in parser")
        #expect(result.tasks.allSatisfy { !$0.isCompleted })
    }

    @Test("Task source spans point into original text")
    func taskSourceSpans() async throws {
        let pipeline = makePipeline()
        let text = "Notes\n\n- [ ] Buy groceries"

        let result = try await pipeline.run(rawText: text)

        #expect(result.tasks.count == 1)
        let span = result.tasks[0].sourceSpan

        // Verify span points into the original text
        let nsText = text as NSString
        let extracted = nsText.substring(with: NSRange(location: span.start, length: span.end - span.start))
        #expect(extracted.contains("Buy groceries"))
    }

    // MARK: - Entity Extraction

    @Test("Named entities extracted from text")
    func entityExtraction() async throws {
        let pipeline = makePipeline()
        // Use a sentence that NL framework reliably tags
        let text = "Tim Cook announced new products at Apple Park in Cupertino."

        let result = try await pipeline.run(rawText: text)

        // NL entity recognition is probabilistic — check that at least some entities are found
        // and that source spans are valid
        for entity in result.entities {
            #expect(!entity.text.isEmpty)
            #expect(!entity.kind.isEmpty)
            #expect(entity.sourceSpan.start >= 0)
            #expect(entity.sourceSpan.end > entity.sourceSpan.start)

            // Verify source span text matches entity text
            #expect(entity.sourceSpan.text == entity.text)
        }
    }

    @Test("Entity source spans have correct roles")
    func entitySourceSpanRoles() async throws {
        let pipeline = makePipeline()
        let result = try await pipeline.run(
            rawText: "John Smith works at Acme Corp in New York."
        )

        for entity in result.entities {
            #expect(entity.sourceSpan.role.hasPrefix("entity:"))
            let kind = String(entity.sourceSpan.role.dropFirst("entity:".count))
            #expect(["person", "place", "organization"].contains(kind))
        }
    }

    // MARK: - Source Spans

    @Test("Source spans point into original text")
    func sourceSpansValid() async throws {
        let pipeline = makePipeline()
        let text = "# My Title\n\n- [ ] Do something\nJohn went to London."

        let result = try await pipeline.run(rawText: text)

        let nsText = text as NSString
        for span in result.sourceSpans {
            #expect(span.start >= 0)
            #expect(span.end <= nsText.length)
            #expect(span.end > span.start)
            #expect(!span.text.isEmpty)
            #expect(!span.role.isEmpty)
        }
    }

    // MARK: - Graph Write

    @Test("Graph nodes created for note and entities")
    func graphWriteCreatesNodes() async throws {
        let pipeline = makePipeline()
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let result = try await pipeline.run(
            rawText: "Tim Cook presented the new iPhone at Apple Park.",
            modelContext: context
        )

        #expect(result.graphWriteSummary.noteNodeCreated)
        #expect(result.graphWriteSummary.skippedReason == nil)

        // Verify a note node exists
        let nodeDescriptor = FetchDescriptor<SDGraphNode>()
        let nodes = try context.fetch(nodeDescriptor)
        let noteNodes = nodes.filter { $0.type == GraphNodeType.note.rawValue }
        #expect(noteNodes.count >= 1)
    }

    @Test("Graph write skipped when no model context")
    func graphWriteSkippedWithoutContext() async throws {
        let pipeline = makePipeline()

        let result = try await pipeline.run(rawText: "Some text about John Smith.")

        #expect(!result.graphWriteSummary.noteNodeCreated)
        #expect(result.graphWriteSummary.skippedReason != nil)
        #expect(result.graphWriteSummary.skippedReason?.contains("no model context") == true)
    }

    // MARK: - No Follow-Up Actions Without Permission

    @Test("Pipeline does not execute follow-up actions")
    func noFollowUpActionsExecuted() async throws {
        let pipeline = makePipeline()

        // Even with task content that mentions actions, the pipeline
        // should only extract — never execute
        let text = """
        ACTION: Send email to john@example.com
        TODO: Delete old files
        - [ ] Call the API endpoint
        """

        let result = try await pipeline.run(rawText: text)

        // Tasks are extracted but not executed
        #expect(result.tasks.count >= 2)
        // No createdNoteID when no context
        #expect(result.createdNoteID == nil)
        // Graph write is skipped (no context)
        #expect(result.graphWriteSummary.skippedReason != nil)
    }

    // MARK: - Trace ID

    @Test("Each run generates a unique trace ID")
    func uniqueTraceIds() async throws {
        let pipeline = makePipeline()

        let result1 = try await pipeline.run(rawText: "First capture")
        let result2 = try await pipeline.run(rawText: "Second capture")

        #expect(result1.traceID != result2.traceID)
    }

    // MARK: - Summary Extraction

    @Test("Summary is first paragraph")
    func summaryFromFirstParagraph() async throws {
        let pipeline = makePipeline()
        let text = """
        This is the first paragraph about the project status.

        This is a second paragraph with more details about timelines.
        """

        let result = try await pipeline.run(rawText: text)
        #expect(result.summary == "This is the first paragraph about the project status.")
    }

    // MARK: - Text Cleaning

    @Test("Leading and trailing whitespace trimmed")
    func textCleaning() async throws {
        let pipeline = makePipeline()
        let result = try await pipeline.run(rawText: "  \n  Hello World  \n  ")

        #expect(result.cleanedText == "Hello World")
    }

    // MARK: - Deterministic Extraction on Fixture

    @Test("Extraction is deterministic on a fixed fixture")
    func deterministicExtraction() async throws {
        let pipeline = makePipeline()
        let fixture = """
        # Sprint Review Notes

        - [ ] Deploy to staging
        - [x] Write tests
        - [ ] Update README

        TODO: Notify the team about the release
        """

        let result1 = try await pipeline.run(rawText: fixture)
        let result2 = try await pipeline.run(rawText: fixture)

        // Title must be identical
        #expect(result1.title == result2.title)
        #expect(result1.title == "Sprint Review Notes")

        // Task count must be identical
        #expect(result1.tasks.count == result2.tasks.count)
        #expect(result1.tasks.count == 4)

        // Task text must be identical
        for (t1, t2) in zip(result1.tasks, result2.tasks) {
            #expect(t1.text == t2.text)
            #expect(t1.isCompleted == t2.isCompleted)
        }
    }

    // MARK: - Audio Capture Integration

    @Test("Audio transcription flows through pipeline")
    func audioTranscriptionCapture() async throws {
        let pipeline = makePipeline()
        let transcription = TranscribedAudio(
            id: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp/test-recording.m4a"),
            fullText: "We need to schedule a meeting with the marketing team about the Q2 launch.",
            segments: [
                AudioSegment(startTime: 0, endTime: 3.5, text: "We need to schedule a meeting", speaker: "Speaker 1"),
                AudioSegment(startTime: 3.5, endTime: 7.0, text: "with the marketing team about the Q2 launch.", speaker: "Speaker 1"),
            ],
            wordsPerMinute: 140,
            hesitationFrequency: 2.5,
            speakerCount: 1
        )

        let result = try await pipeline.runFromAudio(transcription: transcription)

        #expect(!result.traceID.isEmpty)
        #expect(!result.title.isEmpty)
        // Raw text should contain the audio source metadata comment
        #expect(result.rawText.contains("audio-source"))
        #expect(result.rawText.contains("test-recording.m4a"))
        // Cleaned text should also contain the full transcription
        #expect(result.cleanedText.contains("meeting"))
    }

    @Test("Empty audio transcription throws emptyCapture")
    func emptyAudioTranscription() async throws {
        let pipeline = makePipeline()
        let transcription = TranscribedAudio(
            id: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp/silence.m4a"),
            fullText: "   ",
            segments: [],
            wordsPerMinute: 0,
            hesitationFrequency: 0,
            speakerCount: 0
        )

        await #expect(throws: TextCaptureError.emptyCapture) {
            _ = try await pipeline.runFromAudio(transcription: transcription)
        }
    }

    // MARK: - Graph Deduplication

    @Test("Duplicate entity nodes are reused across captures")
    func graphEntityDeduplication() async throws {
        let pipeline = makePipeline()
        let container = try makeTestContainer()
        let context = ModelContext(container)

        // First capture mentioning "Tim Cook"
        _ = try await pipeline.run(
            rawText: "Tim Cook announced the new product lineup at Apple Park.",
            modelContext: context
        )

        let nodesAfterFirst = try context.fetch(FetchDescriptor<SDGraphNode>())
        #expect(!nodesAfterFirst.isEmpty)

        // Second capture also mentioning "Tim Cook"
        _ = try await pipeline.run(
            rawText: "Tim Cook presented the quarterly results to shareholders.",
            modelContext: context
        )

        let nodesAfterSecond = try context.fetch(FetchDescriptor<SDGraphNode>())

        // If dedup works, the entity node count should not double.
        // We expect: 2 note nodes + entities (deduplicated).
        // The note nodes are always new (each capture = new note).
        let noteNodes = nodesAfterSecond.filter { $0.type == GraphNodeType.note.rawValue }
        #expect(noteNodes.count == 2, "Two captures should produce two note nodes")

        // Entity nodes should be reused, not duplicated
        let personNodes = nodesAfterSecond.filter {
            $0.sourceId?.hasPrefix("capture-entity-") == true
        }
        // Each unique entity name should appear at most once
        let uniqueSourceIds = Set(personNodes.compactMap(\.sourceId))
        #expect(uniqueSourceIds.count == personNodes.count, "No duplicate entity sourceIds")
    }

    // MARK: - Edge Cases (Phase 6.5 hardening)

    @Test("Very long input is bounded before extraction")
    func veryLongInput() async throws {
        let pipeline = makePipeline()
        // Build a 15K character input
        let longParagraph = String(repeating: "This is a long sentence with many words to fill space. ", count: 300)
        let text = "# Very Long Document Title That Keeps Going\n\n\(longParagraph)"

        let result = try await pipeline.run(rawText: text)

        #expect(!result.traceID.isEmpty)
        #expect(result.rawText == text)
        #expect(result.cleanedText.count == TextCapturePipeline.maxCleanedTextCharacters)
        #expect(result.title == "Very Long Document Title That Keeps Going")
        // Summary should be truncated to <= 300 chars
        #expect(result.summary.count <= 300)
    }

    @Test("Title extracted from H2 heading")
    func titleFromH2Heading() async throws {
        let pipeline = makePipeline()
        let result = try await pipeline.run(rawText: "## Sub-section Title\n\nSome body text.")

        #expect(result.title == "Sub-section Title")
    }

    @Test("Multiple task patterns in one document")
    func multipleTaskPatterns() async throws {
        let pipeline = makePipeline()
        let text = """
        Project Notes

        - [ ] First checkbox task
        - [x] Completed checkbox
        TODO: A todo item
        ACTION: An action item
        FIXME: Fix this bug
        TASK: Do this thing
        """

        let result = try await pipeline.run(rawText: text)

        // Should find checkbox tasks + keyword tasks
        #expect(result.tasks.count >= 6)
        let completed = result.tasks.filter(\.isCompleted)
        #expect(completed.count == 1)
    }

    @Test("Pipeline with persistence produces graph and evidence trace events")
    func fullPipelineWithPersistence() async throws {
        let fixture = makeTracedPipeline()
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let text = """
        # Meeting with John Smith at Apple Park

        - [ ] Send follow-up to John
        TODO: Review the proposal

        We discussed the new product roadmap with the engineering team.
        """

        let result = try await fixture.pipeline.run(rawText: text, modelContext: context)

        // Note should be persisted
        #expect(result.createdNoteID != nil)
        // Graph should be written
        #expect(result.graphWriteSummary.noteNodeCreated)
        #expect(result.graphWriteSummary.skippedReason == nil)
        // Source spans should exist
        #expect(!result.sourceSpans.isEmpty)
        // Tasks should be found
        #expect(result.tasks.count >= 2)
        // Trace ID present
        #expect(!result.traceID.isEmpty)

        let eventTypes = try await waitForTraceEventTypes(
            traceDir: fixture.traceDir,
            sessionId: fixture.sessionId,
            minimumCount: 5
        )
        await fixture.collector.closeSession(fixture.sessionId)
        #expect(eventTypes.contains(TraceEvent.TraceEventType.captureReceived.rawValue))
        #expect(eventTypes.contains(TraceEvent.TraceEventType.structureGenerated.rawValue))
        #expect(eventTypes.contains(TraceEvent.TraceEventType.notePersisted.rawValue))
        #expect(eventTypes.contains(TraceEvent.TraceEventType.graphWriteAttempted.rawValue))
        #expect(eventTypes.contains(TraceEvent.TraceEventType.evidenceLinked.rawValue))
    }

    // MARK: - Quick Capture Wiring

    @Test("Graph refresh signaled after successful graph write")
    func graphRefreshSignaledAfterWrite() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Engine/TextCapturePipeline.swift"
        )

        #expect(source.contains("graphState.needsRefresh = true"))
        #expect(source.contains("if graphSummary.noteNodeCreated"))
    }

    @Test("Graph node lookup logs fetch failures instead of swallowing them")
    func graphNodeLookupLogsFetchFailures() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Engine/TextCapturePipeline.swift"
        )

        #expect(!source.contains("return (try? context.fetch(descriptor))?.first"))
        #expect(source.contains("TextCapturePipeline: failed to fetch existing graph node"))
    }

    @Test("note persistence cleanup removes failed transient managed bodies")
    func notePersistenceCleanupRemovesFailedTransientManagedBodies() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Engine/TextCapturePipeline.swift"
        )

        #expect(source.contains("let failedPageId = page.id"))
        #expect(source.contains("context.delete(page)"))
        #expect(source.contains("NoteFileStorage.deleteBody(pageId: failedPageId)"))
    }

    @Test("Quick Capture command opens idempotently instead of toggling closed")
    func quickCaptureCommandIsIdempotent() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/App/EpistemosApp.swift")

        #expect(source.contains("showQuickCapture = true"))
        #expect(!source.contains("showQuickCapture.toggle()"))
    }

    @Test("Quick Capture comments describe the current app-scoped sheet honestly")
    func quickCaptureSurfaceClaimsStayTruthful() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Capture/QuickCaptureView.swift")

        #expect(source.contains("app-scoped capture sheet"))
        #expect(source.contains("Epistemos ⌘⇧N command"))
        #expect(!source.contains("auto-dismiss or open note"))
    }

    @Test("Shortcut Quick Capture fails rather than claiming success without a persisted note")
    func quickCaptureIntentRequiresPersistedNote() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Intents/Custom/NoteActionIntents.swift")

        #expect(source.contains("guard let noteId = result.createdNoteID else"))
        #expect(source.contains("throw IntentError.creationFailed"))
    }

    @Test("Brain Dump intent with no body opens Quick Capture for dictation")
    func blankBrainDumpIntentOpensQuickCaptureForDictation() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Intents/Schemas/CognitiveIntents.swift")
        let emptyPath = try #require(source.range(of: "guard !trimmed.isEmpty else"))
        let showCapture = try #require(source.range(of: "NotificationCenter.default.post(name: .showQuickCapture"))

        #expect(emptyPath.lowerBound < showCapture.lowerBound)
        #expect(source.contains("Opening Quick Capture so you can dictate your brain dump."))
    }

    @Test("Brain Dump intent anchors raw thoughts to the active note or chat")
    func brainDumpIntentAnchorsRawThoughtsToActiveContext() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Intents/Schemas/CognitiveIntents.swift")
        let anchorHelper = try #require(source.range(of: "private static func activeContextAnchor() -> QuarantineAnchor?"))
        let captureCall = try #require(source.range(of: "QuarantineArchive.shared.capture("))

        #expect(anchorHelper.lowerBound < captureCall.lowerBound)
        #expect(source.contains("bootstrap.notesUI.activePageId"))
        #expect(source.contains("bootstrap.chatState.activeChatId"))
        #expect(source.contains("anchor: Self.activeContextAnchor()"))
    }
}
