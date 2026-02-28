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

        // Add vault context if available for grounded analysis
        let vaultHint = bootstrap.ambientManifest.map { "\n\nUser's vault index:\n" + $0.asManifestOnly() } ?? ""

        let response = try await bootstrap.triageService.generateGeneral(
            prompt: query + vaultHint,
            systemPrompt: """
            You are Epistemos, a research-grade analytical engine. Give a concise, well-structured answer. \
            Use markdown for clarity. Be direct — answer first, then evidence. 2-4 paragraphs max. \
            If the user has notes on this topic, reference them naturally. Don't force vault references when irrelevant.
            """,
            operation: .chatResponse(query: query),
            contentLength: query.count + vaultHint.count
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

        // Use ambient manifest for vault-wide awareness, with keyword-matched pages for depth
        let manifestContext = bootstrap.ambientManifest?.asManifestOnly() ?? ""

        let context = ModelContext(bootstrap.modelContainer)
        let descriptor = FetchDescriptor<SDPage>(
            sortBy: [SortDescriptor(\SDPage.updatedAt, order: .reverse)]
        )
        let pages = (try? context.fetch(descriptor)) ?? []

        let queryLower = question.lowercased()
        let keywords = queryLower.split(separator: " ").filter { $0.count > 3 }.map(String.init)

        let relevantPages = pages.filter { page in
            let titleLower = page.title.lowercased()
            let bodyLower = page.loadBody().lowercased()
            return keywords.contains(where: { titleLower.contains($0) || bodyLower.contains($0) })
        }.prefix(5)

        let deepContext: String
        if relevantPages.isEmpty {
            let recent = pages.prefix(5)
            deepContext = recent.map { "## \($0.title)\n\(String($0.loadBody().prefix(500)))" }.joined(separator: "\n\n")
        } else {
            deepContext = relevantPages.map { "## \($0.title)\n\(String($0.loadBody().prefix(500)))" }.joined(separator: "\n\n")
        }

        let fullContext = manifestContext.isEmpty ? deepContext : "\(manifestContext)\n\n## Relevant Note Bodies\n\(deepContext)"

        let response = try await bootstrap.triageService.generateGeneral(
            prompt: "Question about my notes: \(question)",
            systemPrompt: """
            You are Epistemos, the user's research assistant with access to their full vault index and relevant note bodies. \
            Answer their question by referencing specific notes. Quote content when relevant. \
            If the vault doesn't cover something, say so and offer what you know from general knowledge.

            \(fullContext)
            """,
            operation: .chatResponse(query: question),
            contentLength: fullContext.count
        )

        return .result(dialog: "\(String(response.prefix(500)))")
    }
}
