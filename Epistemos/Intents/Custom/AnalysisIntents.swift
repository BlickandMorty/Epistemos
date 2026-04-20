import AppIntents
import SwiftData

// MARK: - Notes Intents

struct AskAboutNotesIntent: AppIntent {
    static var title: LocalizedStringResource { "Ask About Notes" }
    static var description: IntentDescription {
        IntentDescription("Asks the AI a question grounded in your Epistemos notes.")
    }
    static var openAppWhenRun: Bool { false }  // Siri can answer without opening the app

    @Parameter(title: "Question")
    var question: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let bootstrap = AppBootstrap.shared else { throw IntentError.appNotReady }

        // Use ambient manifest for vault-wide awareness, with keyword-matched pages for depth
        let manifestContext = bootstrap.ambientManifest?.asManifestOnly() ?? ""

        let matches = await AppIntentSearchSupport.rankedPages(
            query: question,
            bootstrap: bootstrap,
            limit: 5
        ) { page in
            !page.isArchived && page.templateId == nil
        }
        let relevantBodies = await bootstrap.vaultSync.fetchNoteBodies(ids: matches.map(\.page.id))

        let deepContext: String
        if relevantBodies.isEmpty {
            let context = ModelContext(bootstrap.modelContainer)
            let recent: [SDPage]
            do {
                recent = try context.fetch(SDPage.recentDescriptor(limit: 5))
            } catch {
                Log.app.error(
                    "AskAboutNotesIntent: failed to fetch recent notes: \(error.localizedDescription, privacy: .public)"
                )
                recent = []
            }
            deepContext = recent.map { page in
                let body = NoteWindowManager.shared.currentBody(for: page.id, mapped: true)
                return "## \(page.title)\n\(String(body.prefix(500)))"
            }.joined(separator: "\n\n")
        } else {
            deepContext = relevantBodies.map { note in
                "## \(note.title)\n\(String(note.body.prefix(500)))"
            }.joined(separator: "\n\n")
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
