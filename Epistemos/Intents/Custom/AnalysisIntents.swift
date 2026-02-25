import AppIntents
import SwiftData

// MARK: - Analysis Intents (Custom)
// Quick AI operations that route through TriageService for
// automatic Apple Intelligence / cloud API selection.

// MARK: Run Analysis (Quick — Pass 1 only)

struct RunAnalysisIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Quick Analysis"
    nonisolated(unsafe) static var description: IntentDescription = "Runs a quick analytical pass on a query and returns a concise answer."
    nonisolated(unsafe) static var openAppWhenRun = true

    @Parameter(title: "Query")
    var query: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let bootstrap = AppBootstrap.shared else { throw IntentError.appNotReady }

        // Quick analysis: single LLM call through triage (auto-routes Apple Intelligence vs API)
        let response = try await bootstrap.triageService.generateGeneral(
            prompt: query,
            systemPrompt: "You are Epistemos, a research-grade analytical engine. Give a concise, well-structured answer. Use markdown for clarity. Be direct — answer first, then evidence. 2-4 paragraphs max.",
            operation: .chatResponse(query: query),
            contentLength: query.count
        )

        return .result(dialog: "\(String(response.prefix(500)))")
    }
}

// MARK: Ask About Notes

struct AskAboutNotesIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Ask About Notes"
    nonisolated(unsafe) static var description: IntentDescription = "Asks the AI a question grounded in your Epistemos notes."
    nonisolated(unsafe) static var openAppWhenRun = true

    @Parameter(title: "Question")
    var question: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let bootstrap = AppBootstrap.shared else { throw IntentError.appNotReady }
        let context = ModelContext(bootstrap.modelContainer)

        // Gather relevant notes as context
        let descriptor = FetchDescriptor<SDPage>(
            sortBy: [SortDescriptor(\SDPage.updatedAt, order: .reverse)]
        )
        let pages = (try? context.fetch(descriptor)) ?? []

        // Search notes for relevance to the question
        let queryLower = question.lowercased()
        let keywords = queryLower.split(separator: " ").filter { $0.count > 3 }.map(String.init)

        let relevantPages = pages.filter { page in
            let titleLower = page.title.lowercased()
            let bodyLower = page.body.lowercased()
            return keywords.contains(where: { titleLower.contains($0) || bodyLower.contains($0) })
        }.prefix(5)

        let notesContext: String
        if relevantPages.isEmpty {
            // Fall back to most recent notes
            let recent = pages.prefix(5)
            notesContext = recent.map { "## \($0.title)\n\(String($0.body.prefix(300)))" }.joined(separator: "\n\n")
        } else {
            notesContext = relevantPages.map { "## \($0.title)\n\(String($0.body.prefix(300)))" }.joined(separator: "\n\n")
        }

        let response = try await bootstrap.triageService.generateGeneral(
            prompt: "Question about my notes: \(question)",
            systemPrompt: """
            You are Epistemos, the user's research assistant. Answer their question using ONLY the context from their notes below. Quote specific note content when relevant. If the notes don't contain enough information, say so clearly.

            ## User's Notes
            \(notesContext)
            """,
            operation: .chatResponse(query: question),
            contentLength: notesContext.count
        )

        return .result(dialog: "\(String(response.prefix(500)))")
    }
}
