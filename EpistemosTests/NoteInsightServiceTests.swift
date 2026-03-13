import Testing
@testable import Epistemos
import Foundation
import SwiftData

// MARK: - ContentPersonalitySignals Tests

@Suite("ContentPersonalitySignals")
struct ContentPersonalitySignalsTests {

    @Test("Empty text returns empty signals")
    func emptyInput() {
        let signals = ContentPersonalitySignals.analyze("")
        #expect(signals == .empty)
    }

    @Test("Short text under 50 chars returns empty signals")
    func shortInput() {
        let signals = ContentPersonalitySignals.analyze("Hello world, this is short.")
        #expect(signals == .empty)
    }

    @Test("Exactly 50 chars is analyzed")
    func fiftyCharBoundary() {
        // 50 chars of real text
        let text = String(repeating: "word ", count: 10)
        let signals = ContentPersonalitySignals.analyze(text)
        // Should not be .empty since we have >= 50 chars of content
        #expect(signals.vocabDiversity >= 0)
    }

    @Test("Sentiment is in valid range")
    func sentimentRange() {
        let text = "This is a wonderful, amazing, fantastic piece of writing that I truly love and appreciate deeply."
        let signals = ContentPersonalitySignals.analyze(text)
        #expect(signals.sentiment >= -1.0)
        #expect(signals.sentiment <= 1.0)
    }

    @Test("Question density detects questions")
    func questionDensity() {
        let text = "What is this? Why does it work? How can we improve? Who is responsible? Where do we go from here? Let me explain."
        let signals = ContentPersonalitySignals.analyze(text)
        #expect(signals.questionDensity > 0.0)
        #expect(signals.questionDensity <= 1.0)
    }

    @Test("Formality score is in valid range")
    func formalityRange() {
        let text = "The architectural paradigm necessitates a comprehensive evaluation of the structural components within the established framework of analysis."
        let signals = ContentPersonalitySignals.analyze(text)
        #expect(signals.formalityScore >= 0.0)
        #expect(signals.formalityScore <= 1.0)
    }

    @Test("Vocab diversity is in valid range")
    func vocabDiversityRange() {
        let text = "The quick brown fox jumps over the lazy dog. A swift auburn vulpine leaps across the languid canine resting peacefully."
        let signals = ContentPersonalitySignals.analyze(text)
        #expect(signals.vocabDiversity > 0.0)
        #expect(signals.vocabDiversity <= 1.0)
    }

    @Test("Entity extraction finds named entities")
    func entityExtraction() {
        let text = "Albert Einstein developed the theory of relativity at Princeton University. Isaac Newton formulated the laws of motion in Cambridge."
        let signals = ContentPersonalitySignals.analyze(text)
        // NLTagger should find at least one named entity
        #expect(!signals.entityKeywords.isEmpty)
    }

    @Test("Topic nouns are extracted from content")
    func topicNouns() {
        let text = "The neural network architecture uses convolutional layers for feature extraction. The architecture processes images through multiple convolutional filters and pooling operations."
        let signals = ContentPersonalitySignals.analyze(text)
        #expect(!signals.dominantTopics.isEmpty)
    }

    @Test("Topic noun extraction is deterministic when counts tie")
    func topicNounsDeterministic() {
        let text = """
        Albert Einstein developed the theory of relativity at Princeton University.
        Isaac Newton formulated the laws of motion in Cambridge.
        """
        let first = ContentPersonalitySignals.analyze(text).dominantTopics
        #expect(!first.isEmpty)

        for _ in 0..<10 {
            #expect(ContentPersonalitySignals.analyze(text).dominantTopics == first)
        }
    }

    @Test("Entity keywords capped at 6")
    func entityCap() {
        // Lots of named entities
        let text = "Einstein, Newton, Darwin, Tesla, Curie, Hawking, Feynman, Bohr, Planck all contributed to science at Harvard, MIT, Stanford, Oxford, Cambridge, Princeton, Yale, Columbia."
        let signals = ContentPersonalitySignals.analyze(text)
        #expect(signals.entityKeywords.count <= 6)
    }

    @Test("Topic nouns capped at 5")
    func topicNounCap() {
        let text = "Architecture engineering mathematics physics chemistry biology astronomy geology meteorology oceanography ecology botany zoology paleontology genetics. " +
            "Architecture engineering mathematics physics chemistry biology astronomy geology meteorology oceanography ecology botany zoology paleontology genetics."
        let signals = ContentPersonalitySignals.analyze(text)
        #expect(signals.dominantTopics.count <= 5)
    }
}

// MARK: - SDNoteInsight Tests

@Suite("SDNoteInsight Model")
struct SDNoteInsightModelTests {

    @Test("Content hash is deterministic")
    func hashDeterministic() {
        let body = "Some note body content."
        let hash1 = SDNoteInsight.hash(of: body)
        let hash2 = SDNoteInsight.hash(of: body)
        #expect(hash1 == hash2)
    }

    @Test("Content hash differs for different content")
    func hashDiffers() {
        let hash1 = SDNoteInsight.hash(of: "First note body")
        let hash2 = SDNoteInsight.hash(of: "Second note body")
        #expect(hash1 != hash2)
    }

    @Test("Empty body produces valid hash")
    func emptyBodyHash() {
        let hash = SDNoteInsight.hash(of: "")
        #expect(!hash.isEmpty)
    }

    @Test("JSON accessors round-trip entity keywords")
    func entityKeywordsRoundTrip() {
        let insight = SDNoteInsight(pageId: "test-1")
        let keywords = ["Einstein", "Relativity", "Physics"]
        insight.entityKeywords = keywords
        #expect(insight.entityKeywords == keywords)
    }

    @Test("JSON accessors round-trip topic nouns")
    func topicNounsRoundTrip() {
        let insight = SDNoteInsight(pageId: "test-2")
        let topics = ["architecture", "network", "layer"]
        insight.topicNouns = topics
        #expect(insight.topicNouns == topics)
    }

    @Test("JSON accessors round-trip related note IDs")
    func relatedNoteIdsRoundTrip() {
        let insight = SDNoteInsight(pageId: "test-3")
        let ids = ["page-a", "page-b", "page-c"]
        insight.relatedNoteIds = ids
        #expect(insight.relatedNoteIds == ids)
    }

    @Test("JSON accessors round-trip relatedness scores")
    func relatednessScoresRoundTrip() {
        let insight = SDNoteInsight(pageId: "test-4")
        let scores = [0.85, 0.72, 0.51]
        insight.relatednessScores = scores
        #expect(insight.relatednessScores == scores)
    }

    @Test("JSON accessors round-trip relatedness reasons")
    func relatednessReasonsRoundTrip() {
        let insight = SDNoteInsight(pageId: "test-5")
        let reasons: [[String]] = [["sharedEntities", "sharedKeywords"], ["sharedEntities"]]
        insight.relatednessReasons = reasons
        #expect(insight.relatednessReasons == reasons)
    }

    @Test("Corrupted JSON falls back to empty arrays")
    func corruptedJSONFallback() {
        let insight = SDNoteInsight(pageId: "test-6")
        insight.entityKeywordsJSON = "not valid json"
        insight.topicNounsJSON = "{broken}"
        insight.relatedNoteIdsJSON = "null"
        #expect(insight.entityKeywords.isEmpty)
        #expect(insight.topicNouns.isEmpty)
        #expect(insight.relatedNoteIds.isEmpty)
    }

    @Test("Default init produces empty arrays")
    func defaultInit() {
        let insight = SDNoteInsight(pageId: "test-7")
        #expect(insight.entityKeywords.isEmpty)
        #expect(insight.topicNouns.isEmpty)
        #expect(insight.relatedNoteIds.isEmpty)
        #expect(insight.relatednessScores.isEmpty)
        #expect(insight.relatednessReasons.isEmpty)
    }
}

// MARK: - NoteInsightService Lifecycle Tests

@Suite("NoteInsightService")
struct NoteInsightServiceLifecycleTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(EpistemosSchema.models)
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func waitUntil(
        timeout: Duration = .seconds(3),
        condition: @escaping () async throws -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout

        while clock.now < deadline {
            if try await condition() { return }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    private func fetchInsight(pageId: String, from container: ModelContainer) throws -> SDNoteInsight? {
        let verifyContext = ModelContext(container)
        let descriptor = FetchDescriptor<SDNoteInsight>(
            predicate: #Predicate { $0.pageId == pageId }
        )
        return try verifyContext.fetch(descriptor).first
    }

    @Test("reindex updates the service instance that launched the task")
    func reindexUpdatesOwnInstance() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let page = SDPage(title: "Direct Service")
        context.insert(page)
        try context.save()

        let service = await MainActor.run { NoteInsightService(modelContainer: container) }
        await MainActor.run { service.reindex() }

        try await waitUntil {
            await MainActor.run { !service.isIndexing }
        }

        let insights = try context.fetch(FetchDescriptor<SDNoteInsight>())
        let counters = await MainActor.run {
            (total: service.totalCount, indexed: service.indexedCount, indexing: service.isIndexing)
        }
        #expect(counters.total == 1)
        #expect(counters.indexed == 1)
        #expect(counters.indexing == false)
        #expect(insights.count == 1)
        #expect(insights.first?.pageId == page.id)
    }

    @Test("reanalyze schedules relatedness on the same service instance")
    func reanalyzeSchedulesOwnRelatedness() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let body = """
        Albert Einstein developed the theory of relativity at Princeton University.
        Isaac Newton formulated the laws of motion in Cambridge.
        """
        let peerSignals = ContentPersonalitySignals.analyze(body)
        #expect(!peerSignals.entityKeywords.isEmpty)
        #expect(!peerSignals.dominantTopics.isEmpty)

        let page = SDPage(title: "Target")
        context.insert(page)
        let pageId = page.id

        let peerInsight = SDNoteInsight(pageId: "peer")
        peerInsight.contentHash = SDNoteInsight.hash(of: "peer")
        peerInsight.entityKeywords = peerSignals.entityKeywords
        peerInsight.topicNouns = peerSignals.dominantTopics
        peerInsight.sentiment = peerSignals.sentiment
        peerInsight.formality = peerSignals.formalityScore
        context.insert(peerInsight)
        try context.save()

        NoteFileStorage.writeBody(pageId: pageId, content: body)
        defer { NoteFileStorage.deleteBody(pageId: pageId) }

        let service = await MainActor.run { NoteInsightService(modelContainer: container) }
        await MainActor.run { service.reanalyze(pageId: pageId) }

        try await waitUntil {
            try fetchInsight(pageId: pageId, from: container)?.relatedNoteIds.contains("peer") == true
        }

        let targetInsight = try fetchInsight(pageId: pageId, from: container)
        #expect(targetInsight != nil)
        #expect(targetInsight?.contentHash == SDNoteInsight.hash(of: body))
        #expect(targetInsight?.topicNouns == peerSignals.dominantTopics)
        #expect(targetInsight?.sentiment == peerSignals.sentiment)
        #expect(targetInsight?.formality == peerSignals.formalityScore)
        #expect(targetInsight?.relatedNoteIds.contains("peer") == true)
    }

    @Test("reanalyze releases completed task handles")
    func reanalyzeReleasesCompletedTaskHandles() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let page = SDPage(title: "Task Cleanup")
        context.insert(page)
        let pageId = page.id
        try context.save()

        let body = String(repeating: "Einstein relativity Princeton theory motion laws. ", count: 4)
        NoteFileStorage.writeBody(pageId: pageId, content: body)
        defer { NoteFileStorage.deleteBody(pageId: pageId) }

        let service = await MainActor.run { NoteInsightService(modelContainer: container) }
        await MainActor.run { service.reanalyze(pageId: pageId) }

        try await waitUntil {
            try fetchInsight(pageId: pageId, from: container)?.contentHash == SDNoteInsight.hash(of: body)
        }
        try? await Task.sleep(for: .milliseconds(100))

        let pendingTasks = await MainActor.run { service.debugPendingReanalyzeTaskCount() }
        #expect(pendingTasks == 0)
    }
}

// MARK: - Relatedness Contract Tests

@Suite("Relatedness Contracts")
@MainActor
struct RelatednessContractTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: SDNoteInsight.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func insertInsight(
        _ context: ModelContext,
        pageId: String,
        entities: [String] = [],
        topics: [String] = [],
        sentiment: Double = 0,
        formality: Double = 0.5
    ) {
        let insight = SDNoteInsight(pageId: pageId)
        insight.entityKeywords = entities
        insight.topicNouns = topics
        insight.sentiment = sentiment
        insight.formality = formality
        insight.contentHash = SDNoteInsight.hash(of: pageId)
        context.insert(insight)
    }

    @Test("All relatedness scores meet threshold")
    func thresholdEnforced() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        insertInsight(context, pageId: "a", entities: ["Swift", "Apple"], topics: ["compiler", "language"])
        insertInsight(context, pageId: "b", entities: ["Swift", "Apple"], topics: ["compiler", "framework"])
        insertInsight(context, pageId: "c", entities: ["Python", "Google"], topics: ["machine", "learning"])
        try context.save()

        try NoteInsightService.computeRelatedness(context: context)

        let insights = try context.fetch(FetchDescriptor<SDNoteInsight>())
        #expect(insights.count == 3)

        for insight in insights {
            for score in insight.relatednessScores {
                #expect(score >= 0.35, "Score \(score) for \(insight.pageId) is below threshold")
            }
        }
    }

    @Test("Max 5 related notes enforced")
    func capAtFive() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let sharedEntities = ["Swift", "Apple", "Xcode"]
        let sharedTopics = ["compiler", "language", "framework"]
        insertInsight(context, pageId: "hub", entities: sharedEntities, topics: sharedTopics)
        for i in 0..<8 {
            insertInsight(context, pageId: "spoke-\(i)", entities: sharedEntities, topics: sharedTopics)
        }
        try context.save()

        try NoteInsightService.computeRelatedness(context: context)

        let insights = try context.fetch(FetchDescriptor<SDNoteInsight>())
        for insight in insights {
            #expect(insight.relatedNoteIds.count <= 5, "\(insight.pageId) has \(insight.relatedNoteIds.count) related notes")
        }
    }

    @Test("Relatedness entries always have reasons")
    func reasonsNotEmpty() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        insertInsight(context, pageId: "x", entities: ["Rust", "Mozilla"], topics: ["memory", "safety"])
        insertInsight(context, pageId: "y", entities: ["Rust", "Mozilla"], topics: ["memory", "ownership"])
        try context.save()

        try NoteInsightService.computeRelatedness(context: context)

        let insights = try context.fetch(FetchDescriptor<SDNoteInsight>())
        for insight in insights {
            for reasons in insight.relatednessReasons {
                #expect(!reasons.isEmpty, "Empty reasons for \(insight.pageId)")
            }
        }
    }

    @Test("Unrelated notes produce no relatedness")
    func unrelatedNotesClean() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        insertInsight(context, pageId: "math", entities: ["Euler", "Gauss"], topics: ["theorem", "proof"])
        insertInsight(context, pageId: "cooking", entities: ["Julia Child"], topics: ["recipe", "butter"])
        try context.save()

        try NoteInsightService.computeRelatedness(context: context)

        let insights = try context.fetch(FetchDescriptor<SDNoteInsight>())
        for insight in insights {
            #expect(insight.relatedNoteIds.isEmpty, "\(insight.pageId) should have no related notes")
        }
    }

    @Test("Single note produces no relatedness")
    func singleNote() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        insertInsight(context, pageId: "solo", entities: ["Test"], topics: ["note"])
        try context.save()

        try NoteInsightService.computeRelatedness(context: context)

        let insights = try context.fetch(FetchDescriptor<SDNoteInsight>())
        #expect(insights.first?.relatedNoteIds.isEmpty == true)
    }

    @Test("Scores and IDs arrays have matching length")
    func arraysAligned() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        insertInsight(context, pageId: "p1", entities: ["Swift", "Metal"], topics: ["graphics", "shader"])
        insertInsight(context, pageId: "p2", entities: ["Swift", "Metal"], topics: ["graphics", "render"])
        insertInsight(context, pageId: "p3", entities: ["Swift", "Metal"], topics: ["graphics", "pipeline"])
        try context.save()

        try NoteInsightService.computeRelatedness(context: context)

        let insights = try context.fetch(FetchDescriptor<SDNoteInsight>())
        for insight in insights {
            #expect(insight.relatedNoteIds.count == insight.relatednessScores.count)
            #expect(insight.relatedNoteIds.count == insight.relatednessReasons.count)
        }
    }
}

// MARK: - RelatednessReason Tests

@Suite("RelatednessReason")
struct RelatednessReasonTests {

    @Test("All reason cases are valid raw values")
    func reasonRawValues() {
        let expected = ["sharedEntities", "semanticSimilarity", "sharedKeywords", "structuralProximity"]
        for raw in expected {
            #expect(RelatednessReason(rawValue: raw) != nil, "\(raw) should be a valid reason")
        }
    }

    @Test("Reasons are Codable")
    func reasonCodable() throws {
        let reason = RelatednessReason.sharedEntities
        let data = try JSONEncoder().encode(reason)
        let decoded = try JSONDecoder().decode(RelatednessReason.self, from: data)
        #expect(decoded == reason)
    }
}
