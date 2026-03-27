import AppIntents
import SwiftData

// MARK: - Daily Briefing Intent
// Generates a daily brief from the user's vault.

struct DailyBriefingIntent: AppIntent {
    static var title: LocalizedStringResource { "Daily Brief" }
    static var description: IntentDescription {
        IntentDescription("Generates a daily brief from your recent notes and chats.")
    }
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let bootstrap = AppBootstrap.shared else { throw IntentError.appNotReady }

        // Build a brief prompt from vault context
        let context = ModelContext(bootstrap.modelContainer)
        var desc = FetchDescriptor<SDPage>(sortBy: [SortDescriptor(\SDPage.updatedAt, order: .reverse)])
        desc.fetchLimit = 20
        let recentPages = (try? context.fetch(desc)) ?? []

        let summary = recentPages.map { "- \($0.title) (updated \($0.updatedAt.formatted(.relative(presentation: .named))))" }.joined(separator: "\n")
        let manifestHint = bootstrap.ambientManifest.map { "\n\n" + $0.asManifestOnly() } ?? ""

        let prompt = """
        Summarize my recent notes and chats into a short daily brief:
        \(summary)\(manifestHint)
        """

        // Use the same daily brief pipeline (Apple Intelligence first, then local Qwen)
        if let result = await bootstrap.dailyBriefState.onDailyBriefGenerate?(prompt) {
            return .result(dialog: "\(String(result.prefix(500)))")
        } else {
            return .result(dialog: "Couldn't generate your daily brief. Please try again.")
        }
    }
}
