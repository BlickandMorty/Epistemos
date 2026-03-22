import AppIntents
import SwiftData

// MARK: - Notes Intents

struct AskAboutNotesIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Ask About Notes"
    nonisolated(unsafe) static var description: IntentDescription = "Asks the AI a question grounded in your Epistemos notes."
    nonisolated(unsafe) static var openAppWhenRun = false  // Siri can answer without opening the app

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
        let pageContexts = pages.map { page in
            (page: page, body: page.loadBody(mapped: true))
        }

        let queryLower = question.lowercased()
        let keywords = queryLower.split(separator: " ").filter { $0.count > 3 }.map(String.init)

        let relevantPages = pageContexts.filter { entry in
            let titleLower = entry.page.title.lowercased()
            let bodyLower = entry.body.lowercased()
            return keywords.contains(where: { titleLower.contains($0) || bodyLower.contains($0) })
        }.prefix(5)

        let deepContext: String
        if relevantPages.isEmpty {
            let recent = pageContexts.prefix(5)
            deepContext = recent.map { "## \($0.page.title)\n\(String($0.body.prefix(500)))" }.joined(separator: "\n\n")
        } else {
            deepContext = relevantPages.map { "## \($0.page.title)\n\(String($0.body.prefix(500)))" }.joined(separator: "\n\n")
        }

        let fullContext = manifestContext.isEmpty ? deepContext : "\(manifestContext)\n\n## Relevant Note Bodies\n\(deepContext)"

        let response = try await bootstrap.triageService.generateGeneral(
            prompt: """
            Use this vault context to answer the question. Reference specific notes when useful. If the vault does not cover something, say so plainly.

            \(fullContext)

            Question: \(question)
            """,
            systemPrompt: nil,
            operation: .chatResponse(query: question),
            contentLength: fullContext.count
        )

        return .result(dialog: "\(String(response.prefix(500)))")
    }
}
