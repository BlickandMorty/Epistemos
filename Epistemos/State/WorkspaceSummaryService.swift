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

    // MARK: - Summary Generation (Map-Reduce Pipeline)

    func generateSummaryNow() async {
        await generateAndStoreSummary()
    }

    /// Per-window summary using Apple Intelligence (fast, short context, ideal for one-sentence summaries).
    /// Falls back to TriageService if Apple Intelligence is unavailable.
    func generatePerWindowSummaries() async -> [(title: String, summary: String)] {
        let openPageIds = NoteWindowManager.shared.orderedPageIds()
        guard !openPageIds.isEmpty else { return [] }

        var results: [(title: String, summary: String)] = []
        for pageId in openPageIds.prefix(8) {
            guard let title = fetchPageTitle(pageId: pageId) else { continue }
            let body = NoteFileStorage.readBody(pageId: pageId, mapped: true)
            guard !body.isEmpty else {
                results.append((title: title, summary: "Empty note"))
                continue
            }
            let snippet = String(body.prefix(600))
            let prompt = "Summarize the intent and key content of this document in one sentence:\n\n\(snippet)"

            do {
                // Prefer Apple Intelligence for per-window summaries (fast, low-latency)
                let summary = try await AppleIntelligenceService.shared.generate(
                    prompt: prompt,
                    systemPrompt: "You are a concise document summarizer. One sentence only."
                )
                results.append((title: title, summary: summary.trimmingCharacters(in: .whitespacesAndNewlines)))
            } catch {
                // Fallback to triage (Qwen) if Apple Intelligence unavailable
                do {
                    let summary = try await triageService.generate(
                        prompt: prompt,
                        systemPrompt: "You are a concise document summarizer. One sentence only.",
                        operation: .summarize,
                        contentLength: snippet.count,
                        query: "per-window summary"
                    )
                    results.append((title: title, summary: summary.trimmingCharacters(in: .whitespacesAndNewlines)))
                } catch {
                    results.append((title: title, summary: "Could not summarize"))
                }
            }
        }
        return results
    }

    private func generateAndStoreSummary() async {
        guard !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }

        let lastSummaryAt = fetchAutoSaveLastSummaryAt() ?? activityTracker.trackingStartedAt ?? Date().addingTimeInterval(-3600)

        // Map phase: per-window summaries
        let windowSummaries = await generatePerWindowSummaries()

        // Build reduce prompt with semantic diffs + graph topology + per-window summaries
        let reducePrompt = buildReducePrompt(since: lastSummaryAt, windowSummaries: windowSummaries)
        guard !reducePrompt.isEmpty else {
            Self.log.info("Summary: no activity to summarize")
            return
        }

        // Reduce phase: global synthesis
        do {
            let summary = try await triageService.generate(
                prompt: reducePrompt,
                systemPrompt: "You are a workspace intelligence engine. Synthesize the user's intent and focus in 2-3 sentences. Describe WHAT they are trying to accomplish, not just what files are open.",
                operation: .summarize,
                contentLength: reducePrompt.count,
                query: "workspace synthesis"
            )
            let cleaned = summary.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return }
            storeSummary(cleaned)
            Self.log.info("Summary generated (Map-Reduce): \(cleaned.prefix(80), privacy: .public)")
        } catch {
            Self.log.error("Summary generation failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Reduce Prompt (Semantic Diffs + Graph Topology + Per-Window Summaries)

    private func buildReducePrompt(since date: Date, windowSummaries: [(title: String, summary: String)]) -> String {
        let digest = activityTracker.buildDigest(since: date)
        let openPageIds = NoteWindowManager.shared.orderedPageIds()

        guard !windowSummaries.isEmpty || !digest.editedNotes.isEmpty || digest.chatMessageCount > 0 else {
            return ""
        }

        var parts: [String] = []

        // Per-window summaries (from Map phase)
        if !windowSummaries.isEmpty {
            let lines = windowSummaries.map { "- \($0.title): \($0.summary)" }
            parts.append("Per-document summaries:\n\(lines.joined(separator: "\n"))")
        }

        // Semantic diffs (what changed, not raw content)
        var diffLines: [String] = []
        for note in digest.editedNotes.prefix(5) {
            let body = NoteFileStorage.readBody(pageId: note.pageId, mapped: true)
            let paragraphs = body.components(separatedBy: "\n\n")
            let changedSnippets = paragraphs.prefix(note.totalParagraphs)
                .enumerated()
                .prefix(3)  // limit to first 3 changed paragraphs for token budget
                .map { "  Paragraph \($0.offset + 1): \(String($0.element.prefix(100)))" }
            diffLines.append("- \"\(note.title)\": \(note.changedParagraphCount)/\(note.totalParagraphs) paragraphs modified\n\(changedSnippets.joined(separator: "\n"))")
        }
        if digest.chatMessageCount > 0 {
            diffLines.append("- \(digest.chatMessageCount) AI chat message\(digest.chatMessageCount == 1 ? "" : "s") exchanged")
        }
        if !diffLines.isEmpty {
            parts.append("Recent changes:\n\(diffLines.joined(separator: "\n"))")
        }

        // Graph topology (condensed edge-list for open notes)
        let graphEdges = buildGraphEdgeList(for: openPageIds)
        if !graphEdges.isEmpty {
            parts.append("Knowledge graph connections:\n\(graphEdges)")
        }

        return parts.joined(separator: "\n\n")
    }

    /// Build a condensed edge-list showing how open notes connect in the knowledge graph.
    private func buildGraphEdgeList(for pageIds: [String]) -> String {
        guard let store = AppBootstrap.shared?.graphState.store else { return "" }
        var edges: [String] = []
        for pageId in pageIds.prefix(6) {
            guard let node = store.node(bySourceId: pageId, type: .note) else { continue }
            guard let neighborIds = store.adjacency[node.id] else { continue }
            for neighborId in neighborIds.prefix(3) {
                guard let neighbor = store.nodes[neighborId] else { continue }
                edges.append("[\(node.label)] -> [\(neighbor.label)]")
            }
        }
        return edges.isEmpty ? "" : edges.joined(separator: "\n")
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
