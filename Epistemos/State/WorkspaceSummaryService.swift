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
            let raw = UserDefaults.standard.string(forKey: Self.intervalDefaultsKey) ?? "5m"
            return SummaryInterval(rawValue: raw) ?? .fiveMinutes
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
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    break
                }
                guard !Task.isCancelled else { break }
                guard let self else { break }
                // Skip if minimized or no windows open
                guard let ui = AppBootstrap.shared?.uiState, !ui.windowOccluded else { continue }
                let hasMainChat = AppBootstrap.shared.map { bootstrap in
                    WorkspaceService.hasLiveMainChatWork(bootstrap.chatState)
                } ?? false
                let hasWork = !NoteWindowManager.shared.orderedPageIds().isEmpty
                    || !MiniChatWindowController.shared.openChatIds.isEmpty
                    || hasMainChat
                    || AppBootstrap.shared?.graphState.currentRoute != .canvas
                guard hasWork else { continue }
                await self.generateAndStoreSummary()
            }
        }
    }

    // MARK: - Summary Generation (Map-Reduce Pipeline)

    func generateSummaryNow() async {
        await generateAndStoreSummary()
    }

    /// Generates summary and returns it directly (avoids stale DB read race).
    func generateSummaryNowReturning() async -> String? {
        guard !isGenerating else { return nil }
        isGenerating = true
        defer { isGenerating = false }

        let lastSummaryAt = fetchAutoSaveLastSummaryAt() ?? activityTracker.trackingStartedAt ?? Date().addingTimeInterval(-3600)
        let windowSummaries = await generatePerWindowSummaries()
        let reducePrompt = buildReducePrompt(since: lastSummaryAt, windowSummaries: windowSummaries)
        guard !reducePrompt.isEmpty else { return nil }

        do {
            let summary = try await triageService.generate(
                prompt: reducePrompt,
                systemPrompt: "You are a workspace intelligence engine. Synthesize the user's current project state as a welcome-back handoff: what they were doing, what changed, what evidence is open, and the likely next move. Be specific and grounded in the live state.",
                operation: .summarize,
                contentLength: reducePrompt.count,
                query: "workspace synthesis"
            )
            guard let cleaned = Self.sanitizedSummaryText(from: summary) else { return nil }
            guard !cleaned.isEmpty else { return nil }
            storeSummary(cleaned)
            return cleaned
        } catch {
            Self.log.error("Summary generation failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Per-window summary uses deterministic extraction. Passive workspace
    /// refreshes run during launch/window restore, so they must not warm
    /// FoundationModels or any selected model before explicit user intent.
    func generatePerWindowSummaries() async -> [(title: String, summary: String)] {
        let liveDocuments = AppBootstrap.shared?.workspaceService.captureSnapshot().liveDocuments ?? []
        guard !liveDocuments.isEmpty else { return [] }

        var results: [(title: String, summary: String)] = []
        for document in liveDocuments.prefix(8) {
            let pageId = document.pageId
            let body = NoteWindowManager.shared.currentBody(for: pageId, mapped: true)
            let sourceText = body.isEmpty
                ? "\(document.preview)\n\n\(document.tailPreview)"
                : body
            guard !sourceText.isEmpty else {
                results.append((title: document.title, summary: "Empty note"))
                continue
            }
            results.append((
                title: document.title,
                summary: Self.extractiveWindowSummary(from: sourceText, source: document.source)
            ))
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
                systemPrompt: "You are a workspace intelligence engine. Synthesize the user's current project state as a welcome-back handoff: what they were doing, what changed, what evidence is open, and the likely next move. Be specific and grounded in the live state.",
                operation: .summarize,
                contentLength: reducePrompt.count,
                query: "workspace synthesis"
            )
            guard let cleaned = Self.sanitizedSummaryText(from: summary) else { return }
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
        let snapshot = AppBootstrap.shared?.workspaceService.captureSnapshot()
        let openPageIds = snapshot?.liveDocuments?.map(\.pageId) ?? NoteWindowManager.shared.orderedPageIds()

        guard !windowSummaries.isEmpty || !digest.editedNotes.isEmpty || digest.chatMessageCount > 0 || snapshot?.liveDocuments?.isEmpty == false || snapshot?.mainChat != nil || snapshot?.miniChats?.isEmpty == false else {
            return ""
        }

        var parts: [String] = []
        if let snapshot {
            let liveState = WorkspaceSynthesisBuilder.summary(for: snapshot)
            if !liveState.isEmpty {
                parts.append("Current live workspace state:\n\(liveState)")
            }
        }

        // Per-window summaries (from Map phase)
        if !windowSummaries.isEmpty {
            let lines = windowSummaries.map { "- \($0.title): \($0.summary)" }
            parts.append("Per-document summaries:\n\(lines.joined(separator: "\n"))")
        }

        // Semantic diffs (what changed, not raw content)
        var diffLines: [String] = []
        for note in digest.editedNotes.prefix(5) {
            let pageId = note.pageId
            let body = NoteWindowManager.shared.currentBody(for: pageId, mapped: true)
            let paragraphs = body.components(separatedBy: "\n\n")
            // Show the LAST few paragraphs (most likely recently edited) rather than
            // the first 3 (which are often just the title/header and never change).
            let recentSnippets = paragraphs.suffix(min(3, paragraphs.count))
                .map { "  \(String($0.prefix(100)))" }
            diffLines.append("- \"\(note.title)\": \(note.changedParagraphCount)/\(note.totalParagraphs) paragraphs modified\n\(recentSnippets.joined(separator: "\n"))")
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

    private nonisolated static func sanitizedSummaryText(from raw: String) -> String? {
        let visible = UserFacingModelOutput.finalVisibleText(from: raw)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !visible.isEmpty else { return nil }
        return visible
    }

    private nonisolated static func extractiveWindowSummary(from raw: String, source: String) -> String {
        let collapsed = raw
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return "Empty \(source)" }

        let sentenceEnd = collapsed.firstIndex { ".!?".contains($0) }
        let firstSentence: String
        if let sentenceEnd {
            firstSentence = String(collapsed[...sentenceEnd])
        } else {
            firstSentence = String(collapsed.prefix(180))
        }
        let clipped = String(firstSentence.prefix(220)).trimmingCharacters(in: .whitespacesAndNewlines)
        return clipped.isEmpty ? "Active \(source)" : clipped
    }

    private func storeSummary(_ text: String) {
        let context = modelContainer.mainContext
        let workspaces: [SDWorkspace]
        do {
            workspaces = try context.fetch(FetchDescriptor<SDWorkspace>())
        } catch {
            Self.log.error("Summary storage fetch failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard let workspace = workspaces.first(where: { $0.isAutoSave }) else { return }
        let originalSummary = workspace.summary
        let originalLastSummaryAt = workspace.lastSummaryAt
        workspace.summary = text
        workspace.lastSummaryAt = Date()
        do {
            try context.save()
        } catch {
            workspace.summary = originalSummary
            workspace.lastSummaryAt = originalLastSummaryAt
            Self.log.error("Summary storage save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func fetchAutoSaveLastSummaryAt() -> Date? {
        let context = modelContainer.mainContext
        do {
            return try context.fetch(FetchDescriptor<SDWorkspace>())
                .first(where: { $0.isAutoSave })?.lastSummaryAt
        } catch {
            Self.log.error("Summary timestamp fetch failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func fetchPageTitle(pageId: String) -> String? {
        let targetId = pageId
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.id == targetId }
        )
        do {
            return try modelContainer.mainContext.fetch(descriptor).first?.title
        } catch {
            Self.log.error("Summary page-title fetch failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
