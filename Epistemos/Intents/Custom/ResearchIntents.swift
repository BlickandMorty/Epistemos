import AppIntents
import SwiftData

// MARK: - Research Intents (Custom)
// Voice-activated academic research. Lucid is the first note app where
// Siri is a research partner: paper search, novelty checks, peer review,
// and citation finding — all via Semantic Scholar integration.

// MARK: Research Topic

struct ResearchTopicIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Research Topic"
    nonisolated(unsafe) static var description: IntentDescription = "Searches academic literature for papers on a topic via Semantic Scholar."
    nonisolated(unsafe) static var openAppWhenRun = true

    @Parameter(title: "Topic")
    var topic: String

    @Parameter(title: "Max Results", default: 5)
    var maxResults: Int

    @Parameter(title: "Save to Note", default: false)
    var saveToNote: Bool

    @MainActor
    func perform() async throws -> some ReturnsValue<[PaperEntity]> & ProvidesDialog {
        guard let bootstrap = AppBootstrap.shared else { throw IntentError.appNotReady }
        let service = bootstrap.researchService
        let papers = try await service.searchPapers(query: topic)
        let limited = Array(papers.prefix(maxResults))

        if saveToNote {
            let formatted = limited.map { "- **\($0.title)** (\($0.year ?? 0)) — \($0.authors.prefix(3).joined(separator: ", "))" }.joined(separator: "\n")
            let _ = await bootstrap.vaultSync.createPage(title: "Research: \(topic)", body: formatted)
        }

        let entities = limited.map { $0.toPaperEntity() }
        let count = entities.count
        return .result(value: entities, dialog: "Found \(count) papers on \"\(topic)\".")
    }
}

// MARK: Fact Check

struct FactCheckIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Fact Check"
    nonisolated(unsafe) static var description: IntentDescription = "Grades a claim's evidence using the analysis pipeline and academic literature."
    nonisolated(unsafe) static var openAppWhenRun = true

    @Parameter(title: "Claim")
    var claim: String

    @MainActor
    func perform() async throws -> some ReturnsValue<AnalysisResultEntity> & ProvidesDialog {
        guard let bootstrap = AppBootstrap.shared else { throw IntentError.appNotReady }
        let triage = bootstrap.triageService
        let systemPrompt = """
        You are an evidence evaluator. Assess the following claim for factual accuracy.
        Grade on a scale: A (well-supported), B (partially supported), C (weak evidence),
        D (contradicted), F (false/no evidence). Include confidence 0.0-1.0.
        Format: Grade: [X]\nConfidence: [0.X]\nSummary: [...]\nWeaknesses: [...]
        """
        let response = try await triage.generateGeneral(
            prompt: "Claim to evaluate: \(claim)",
            systemPrompt: systemPrompt,
            operation: .epistemicLens,
            contentLength: claim.count
        )

        let grade = extractField(from: response, field: "Grade") ?? "C"
        let confidence = Double(extractField(from: response, field: "Confidence") ?? "0.5") ?? 0.5
        let summary = extractField(from: response, field: "Summary") ?? response
        let weaknesses = extractField(from: response, field: "Weaknesses") ?? ""

        let result = AnalysisResultEntity(grade: grade, confidence: confidence, summary: summary, weaknesses: weaknesses)
        return .result(value: result, dialog: "Fact check: \(grade) (confidence: \(Int(confidence * 100))%)")
    }

    private func extractField(from text: String, field: String) -> String? {
        let pattern = "\(field):\\s*(.+)"
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        let match = text[range]
        guard let colonIndex = match.firstIndex(of: ":") else { return nil }
        return String(match[match.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
    }
}

// MARK: Find Gaps

struct FindGapsIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Find Knowledge Gaps"
    nonisolated(unsafe) static var description: IntentDescription = "Identifies blind spots in your research by analyzing your notes against academic literature."
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
        let relevantPages: [SDPage]
        if let topic = topic?.lowercased() {
            relevantPages = Array(pages.filter { $0.title.lowercased().contains(topic) || $0.loadBody().lowercased().contains(topic) }.prefix(10))
        } else {
            relevantPages = Array(pages.prefix(10))
        }

        let notesSummary = relevantPages.map { "- \($0.title): \(String($0.loadBody().prefix(300)))" }.joined(separator: "\n")

        // Inject vault manifest for full vault awareness
        let manifestHint = bootstrap.ambientManifest.map { "\n\n" + $0.asManifestOnly() } ?? ""
        let fullPrompt = "Analyze these notes for knowledge gaps:\n\(notesSummary)\(manifestHint)"

        let triage = bootstrap.triageService
        let response = try await triage.generateGeneral(
            prompt: fullPrompt,
            systemPrompt: "You are a research advisor with access to the user's full vault index. Identify 3-5 specific knowledge gaps or blind spots. Consider what the vault covers broadly versus what these specific notes address. Focus on missing evidence, unexplored angles, and methodological gaps. Be specific and actionable.",
            operation: .epistemicLens,
            contentLength: fullPrompt.count
        )

        let area = topic ?? "all research"
        return .result(dialog: "Gaps in \(area):\n\(String(response.prefix(400)))")
    }
}

// MARK: Review Paper

struct ReviewPaperIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Review Paper"
    nonisolated(unsafe) static var description: IntentDescription = "Runs an AI peer review on a paper using NeurIPS/ICML evaluation criteria."

    @Parameter(title: "Title")
    var paperTitle: String

    @Parameter(title: "Abstract")
    var abstract: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let bootstrap = AppBootstrap.shared else { throw IntentError.appNotReady }
        let service = bootstrap.researchService
        let result = try await service.reviewPaper(title: paperTitle, abstract: abstract, fullText: nil)
        let summary = "Decision: \(result.decision.rawValue)\nOriginality: \(result.scores.originality)/10\nClarity: \(result.scores.clarity)/10\nSoundness: \(result.scores.soundness)/10"
        return .result(dialog: "Review of \"\(paperTitle)\":\n\(summary)")
    }
}

// MARK: Find Citations

struct FindCitationsIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Find Citations"
    nonisolated(unsafe) static var description: IntentDescription = "Identifies claims that need citations and matches them to academic papers."

    @Parameter(title: "Text")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let bootstrap = AppBootstrap.shared else { throw IntentError.appNotReady }
        let service = bootstrap.researchService
        let result = try await service.searchCitations(text: text, context: nil)
        let count = result.claimsFound
        let summary = result.matches.prefix(3).map { "- \($0.claim): \($0.paperTitle)" }.joined(separator: "\n")
        return .result(dialog: "Found \(count) claims needing citations:\n\(summary)")
    }
}
