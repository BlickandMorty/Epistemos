import AppIntents
import SwiftData

// MARK: - Research Intents (Custom)
// Research and knowledge management via Siri Shortcuts.

// MARK: Deep Analyze

struct DeepAnalyzeIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Deep Analyze"
    nonisolated(unsafe) static var description: IntentDescription = "Runs the full multi-pass analysis pipeline with evidence grading on a query or note."
    nonisolated(unsafe) static var openAppWhenRun = true

    @Parameter(title: "Query")
    var query: String

    @Parameter(title: "Save Result", default: false)
    var saveResult: Bool

    @MainActor
    func perform() async throws -> some ReturnsValue<AnalysisResultEntity> & ProvidesDialog {
        guard let bootstrap = AppBootstrap.shared else { throw IntentError.appNotReady }
        let pipeline = PipelineService(
            pipelineState: bootstrap.pipelineState,
            llmService: bootstrap.llmService,
            triageService: bootstrap.triageService,
            inference: bootstrap.inferenceState,
            eventBus: bootstrap.eventBus
        )

        // Consume the pipeline stream to get the completed/enriched result
        var rawAnswer = ""
        var truthAssessment: TruthAssessment?

        let stream = pipeline.run(query: query, mode: .api)
        for try await event in stream {
            switch event {
            case .textDelta(let token):
                rawAnswer += token
            case .enriched(_, let truth):
                truthAssessment = truth
            default:
                break
            }
        }

        let grade: String
        let confidence: Double
        if let truth = truthAssessment {
            confidence = truth.overallTruthLikelihood
            grade = confidence > 0.75 ? "A" : confidence > 0.55 ? "B" : confidence > 0.35 ? "C" : "D"
        } else {
            grade = "C"
            confidence = 0.5
        }

        let summary = String(rawAnswer.prefix(500))
        let weaknesses = truthAssessment?.weaknesses.joined(separator: "; ") ?? ""

        if saveResult {
            let formatted = """
            # Epistemic Lens: \(query)

            **Grade:** \(grade) | **Confidence:** \(Int(confidence * 100))%

            ## Summary
            \(summary)

            ## Weaknesses
            \(weaknesses)
            """
            let _ = await bootstrap.vaultSync.createPage(title: "Analysis: \(String(query.prefix(40)))", body: formatted)
        }

        let result = AnalysisResultEntity(grade: grade, confidence: confidence, summary: summary, weaknesses: weaknesses)
        return .result(value: result, dialog: "Analysis complete — Grade \(grade) (\(Int(confidence * 100))% confidence).")
    }
}

// MARK: Find Connections

struct FindConnectionsIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Find Connections"
    nonisolated(unsafe) static var description: IntentDescription = "Discovers hidden connections between your notes using cross-reference analysis."
    nonisolated(unsafe) static var openAppWhenRun = true

    @Parameter(title: "Topic")
    var topic: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let bootstrap = AppBootstrap.shared else { throw IntentError.appNotReady }
        let context = ModelContext(bootstrap.modelContainer)
        let descriptor = FetchDescriptor<SDPage>(
            sortBy: [SortDescriptor(\SDPage.updatedAt, order: .reverse)]
        )
        let pages = (try? context.fetch(descriptor)) ?? []
        let pageContexts = pages.map { page in
            (page: page, body: page.loadBody(mapped: true))
        }

        let relevantPages: [(page: SDPage, body: String)]
        if let topic = topic?.lowercased() {
            relevantPages = Array(pageContexts.filter {
                $0.page.title.lowercased().contains(topic) || $0.body.lowercased().contains(topic)
            }.prefix(10))
        } else {
            relevantPages = Array(pageContexts.prefix(10))
        }

        let notesSummary = relevantPages.map { "- \($0.page.title): \(String($0.body.prefix(300)))" }.joined(separator: "\n")

        // Inject vault manifest for full vault awareness
        let manifestHint = bootstrap.ambientManifest.map { "\n\n" + $0.asManifestOnly() } ?? ""
        let fullPrompt = "Analyze these notes for hidden connections and cross-references:\n\(notesSummary)\(manifestHint)"

        let response = try await bootstrap.triageService.generateGeneral(
            prompt: fullPrompt,
            systemPrompt: "You are a knowledge graph analyst with access to the user's full vault index. Identify 3-5 non-obvious connections — shared concepts, contradictions, complementary ideas, and synthesis opportunities. Reference notes by title. Look beyond the detailed notes to spot patterns in the vault index too.",
            operation: .epistemicLens,
            contentLength: fullPrompt.count
        )

        let area = topic ?? "all notes"
        return .result(dialog: "Connections in \(area):\n\(String(response.prefix(400)))")
    }
}

// MARK: Generate Questions

struct GenerateQuestionsIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Generate Questions"
    nonisolated(unsafe) static var description: IntentDescription = "Generates thought-provoking questions your notes don't yet answer."

    @Parameter(title: "Topic")
    var topic: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let bootstrap = AppBootstrap.shared else { throw IntentError.appNotReady }
        let context = ModelContext(bootstrap.modelContainer)
        let descriptor = FetchDescriptor<SDPage>(
            sortBy: [SortDescriptor(\SDPage.updatedAt, order: .reverse)]
        )
        let pages = (try? context.fetch(descriptor)) ?? []
        let pageContexts = pages.map { page in
            (page: page, body: page.loadBody(mapped: true))
        }

        let relevantPages: [(page: SDPage, body: String)]
        if let topic = topic?.lowercased() {
            relevantPages = Array(pageContexts.filter {
                $0.page.title.lowercased().contains(topic) || $0.body.lowercased().contains(topic)
            }.prefix(10))
        } else {
            relevantPages = Array(pageContexts.prefix(10))
        }

        let notesSummary = relevantPages.map { "- \($0.page.title): \(String($0.body.prefix(300)))" }.joined(separator: "\n")

        // Inject vault manifest for full vault awareness
        let manifestHint = bootstrap.ambientManifest.map { "\n\n" + $0.asManifestOnly() } ?? ""
        let fullPrompt = "Based on these notes, generate thought-provoking questions:\n\(notesSummary)\(manifestHint)"

        let response = try await bootstrap.triageService.generateGeneral(
            prompt: fullPrompt,
            systemPrompt: "You are a Socratic research advisor with access to the user's full vault. Generate 5 incisive questions that their notes don't yet answer. Challenge assumptions, probe gaps, suggest new angles. Consider the broader vault index for patterns they might be missing. Format: numbered list with a one-line 'Why it matters' for each.",
            operation: .epistemicLens,
            contentLength: fullPrompt.count
        )

        let area = topic ?? "your research"
        return .result(dialog: "Questions about \(area):\n\(String(response.prefix(400)))")
    }
}
