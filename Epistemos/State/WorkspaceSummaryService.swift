import Foundation
import SwiftData
import os

// MARK: - Workspace Summary Service
// Generates AI summaries of workspace activity using TriageService.
// Runs on a configurable interval (5m, 15m, 30m, 1hr, or manual only).
// Summary is stored on the auto-save SDWorkspace record.

@MainActor @Observable
final class WorkspaceSummaryService {
    private static let log = Logger(subsystem: "com.epistemos", category: "WorkspaceSummary")
    private static let intervalDefaultsKey = "epistemos.summaryInterval"

    private let triageService: TriageService
    private let activityTracker: ActivityTracker
    private let modelContainer: ModelContainer

    private var autoSummaryTask: Task<Void, Never>?
    private(set) var isGenerating = false

    var summaryInterval: SummaryInterval {
        get {
            let raw = UserDefaults.standard.string(forKey: Self.intervalDefaultsKey) ?? "15m"
            return SummaryInterval(rawValue: raw) ?? .fifteenMinutes
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Self.intervalDefaultsKey)
            restartAutoSummaryLoop()
        }
    }

    enum SummaryInterval: String, CaseIterable, Codable {
        case fiveMinutes = "5m"
        case fifteenMinutes = "15m"
        case thirtyMinutes = "30m"
        case oneHour = "1hr"
        case manualOnly = "manual"

        var displayName: String {
            switch self {
            case .fiveMinutes: "Every 5 minutes"
            case .fifteenMinutes: "Every 15 minutes"
            case .thirtyMinutes: "Every 30 minutes"
            case .oneHour: "Every hour"
            case .manualOnly: "Manual only"
            }
        }

        var duration: Duration? {
            switch self {
            case .fiveMinutes: .seconds(300)
            case .fifteenMinutes: .seconds(900)
            case .thirtyMinutes: .seconds(1800)
            case .oneHour: .seconds(3600)
            case .manualOnly: nil
            }
        }
    }

    init(triageService: TriageService, activityTracker: ActivityTracker, modelContainer: ModelContainer) {
        self.triageService = triageService
        self.activityTracker = activityTracker
        self.modelContainer = modelContainer
    }

    // MARK: - Lifecycle

    func startAutoSummaryLoop() {
        restartAutoSummaryLoop()
    }

    func stopAutoSummaryLoop() {
        autoSummaryTask?.cancel()
        autoSummaryTask = nil
    }

    private func restartAutoSummaryLoop() {
        autoSummaryTask?.cancel()
        guard let interval = summaryInterval.duration else {
            autoSummaryTask = nil
            return
        }
        autoSummaryTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { break }
                guard let self else { break }
                // Skip if minimized or no windows open
                guard let ui = AppBootstrap.shared?.uiState, !ui.windowOccluded else { continue }
                let hasWork = !NoteWindowManager.shared.orderedPageIds().isEmpty
                    || !MiniChatWindowController.shared.openChatIds.isEmpty
                guard hasWork else { continue }
                await self.generateAndStoreSummary()
            }
        }
    }

    // MARK: - Summary Generation

    func generateSummaryNow() async {
        await generateAndStoreSummary()
    }

    private func generateAndStoreSummary() async {
        guard !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }

        let lastSummaryAt = fetchAutoSaveLastSummaryAt() ?? activityTracker.trackingStartedAt ?? Date().addingTimeInterval(-3600)
        let prompt = buildPrompt(since: lastSummaryAt)
        guard !prompt.isEmpty else {
            Self.log.info("Summary: no activity to summarize")
            return
        }

        do {
            let summary = try await triageService.generate(
                prompt: prompt,
                systemPrompt: "You are a concise workspace summarizer. Write 2-3 sentences about what the user is working on based on their activity.",
                operation: .summarize,
                contentLength: prompt.count,
                query: "workspace summary"
            )
            let cleaned = summary.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return }
            storeSummary(cleaned)
            Self.log.info("Summary generated: \(cleaned.prefix(80), privacy: .public)")
        } catch {
            Self.log.error("Summary generation failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Prompt Construction

    private func buildPrompt(since date: Date) -> String {
        let digest = activityTracker.buildDigest(since: date)
        let openPageIds = NoteWindowManager.shared.orderedPageIds()

        // Skip if no activity
        guard !digest.editedNotes.isEmpty || digest.chatMessageCount > 0 || !openPageIds.isEmpty else {
            return ""
        }

        var parts: [String] = []

        // Open notes
        if !openPageIds.isEmpty {
            let titles = openPageIds.prefix(10).compactMap { fetchPageTitle(pageId: $0) }
            if !titles.isEmpty {
                parts.append("Open notes: \(titles.joined(separator: ", "))")
            }
        }

        // Activity
        var activityLines: [String] = []
        for note in digest.editedNotes {
            activityLines.append("- Edited \"\(note.title)\": \(note.changedParagraphCount) of \(note.totalParagraphs) paragraphs changed")
        }
        if digest.chatMessageCount > 0 {
            activityLines.append("- Sent \(digest.chatMessageCount) chat message\(digest.chatMessageCount == 1 ? "" : "s")")
        }
        if !activityLines.isEmpty {
            parts.append("Recent activity:\n\(activityLines.joined(separator: "\n"))")
        }

        // Note previews (first 200 chars of edited notes)
        var previews: [String] = []
        var totalPreviewChars = 0
        for note in digest.editedNotes.prefix(5) {
            let body = NoteFileStorage.readBody(pageId: note.pageId, mapped: true)
            guard !body.isEmpty else { continue }
            let preview = String(body.prefix(200))
            previews.append("\"\(note.title)\": \(preview)")
            totalPreviewChars += preview.count
            if totalPreviewChars > 1000 { break }
        }
        if !previews.isEmpty {
            parts.append("Note previews:\n\(previews.joined(separator: "\n"))")
        }

        return parts.joined(separator: "\n\n")
    }

    // MARK: - Storage

    private func storeSummary(_ text: String) {
        let context = modelContainer.mainContext
        let predicate = #Predicate<SDWorkspace> { $0.isAutoSave == true }
        guard let workspace = try? context.fetch(FetchDescriptor(predicate: predicate)).first else { return }
        workspace.summary = text
        workspace.lastSummaryAt = Date()
        try? context.save()
    }

    private func fetchAutoSaveLastSummaryAt() -> Date? {
        let context = modelContainer.mainContext
        let predicate = #Predicate<SDWorkspace> { $0.isAutoSave == true }
        return try? context.fetch(FetchDescriptor(predicate: predicate)).first?.lastSummaryAt
    }

    private func fetchPageTitle(pageId: String) -> String? {
        let targetId = pageId
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.id == targetId }
        )
        return try? modelContainer.mainContext.fetch(descriptor).first?.title
    }
}
