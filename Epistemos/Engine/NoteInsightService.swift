import Foundation
import NaturalLanguage
import OSLog
import SwiftData

// MARK: - NoteInsightService

@MainActor @Observable
final class NoteInsightService {
    nonisolated private static let log = Logger(subsystem: "Epistemos", category: "NoteInsightService")

    private struct PageBodyStage: Sendable {
        let pageId: String
        let filePath: String?
        let inlineBody: String
    }

    private(set) var isIndexing = false
    private(set) var indexedCount = 0
    private(set) var totalCount = 0

    @ObservationIgnored
    nonisolated(unsafe) private var reindexTask: Task<Void, Never>?
    private var reindexGeneration: Int = 0
    @ObservationIgnored
    nonisolated(unsafe) private var reanalyzeTasks: [String: Task<Void, Never>] = [:]
    private var reanalyzeTaskTokens: [String: UUID] = [:]
    @ObservationIgnored
    nonisolated(unsafe) private var relatednessTask: Task<Void, Never>?

    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    deinit {
        reindexTask?.cancel()
        relatednessTask?.cancel()
        for task in reanalyzeTasks.values { task.cancel() }
    }

    // MARK: - Public API

    func reindex() {
        reindexTask?.cancel()
        reindexGeneration += 1
        let gen = reindexGeneration
        isIndexing = true
        indexedCount = 0

        let container = modelContainer
        reindexTask = Task.detached(priority: .utility) { [weak self] in
            let result = await NoteInsightService.runReindex(container: container)
            await self?.applyReindexResult(result, generation: gen)
        }
    }

    private func applyReindexResult(_ result: (analyzed: Int, total: Int), generation: Int) {
        guard reindexGeneration == generation else { return }
        indexedCount = result.analyzed
        totalCount = result.total
        isIndexing = false
    }

    private nonisolated static func fetchInsightRecord(
        pageId: String,
        context: ModelContext,
        operation: String
    ) throws -> SDNoteInsight? {
        let targetPageId = pageId
        do {
            return try context.fetch(
                FetchDescriptor<SDNoteInsight>(predicate: #Predicate { $0.pageId == targetPageId })
            ).first
        } catch {
            Self.log.error(
                "\(operation, privacy: .public) fetch failed for \(String(pageId.prefix(8)), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    private nonisolated static func persistContext(
        _ context: ModelContext,
        operation: String
    ) throws {
        do {
            try context.save()
        } catch {
            Self.log.error(
                "\(operation, privacy: .public) save failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    private nonisolated static func runReindex(container: ModelContainer) async -> (analyzed: Int, total: Int) {
        let start = CFAbsoluteTimeGetCurrent()
        let context = ModelContext(container)
        context.autosaveEnabled = false

        do {
            let pages = try context.fetch(FetchDescriptor<SDPage>())
            let total = pages.count
            let stages = pages.map(Self.pageBodyStage(for:))

            var analyzed = 0
            var skipped = 0
            for stage in stages {
                guard !Task.isCancelled else { break }
                let body = await Self.readBody(from: stage)
                let hash = SDNoteInsight.hash(of: body)

                let existing = try Self.fetchInsightRecord(
                    pageId: stage.pageId,
                    context: context,
                    operation: "Note insight reindex"
                )

                if let existing, existing.contentHash == hash {
                    skipped += 1
                    analyzed += 1
                    continue
                }

                let signals = ContentPersonalitySignals.analyze(body)
                let insight = existing ?? SDNoteInsight(pageId: stage.pageId)
                insight.contentHash = hash
                insight.lastAnalyzedAt = .now
                insight.sentiment = signals.sentiment
                insight.formality = signals.formalityScore
                insight.vocabDiversity = signals.vocabDiversity
                insight.questionDensity = signals.questionDensity
                insight.entityKeywords = signals.entityKeywords
                insight.topicNouns = signals.dominantTopics

                if existing == nil { context.insert(insight) }

                analyzed += 1
                if analyzed % 50 == 0 {
                    try Self.persistContext(context, operation: "Note insight reindex checkpoint")
                }
            }
            try Self.persistContext(context, operation: "Note insight reindex final")

            let phase1Time = CFAbsoluteTimeGetCurrent() - start
            Self.log.info("Phase 1 complete: \(analyzed) notes (\(skipped) skipped) in \(String(format: "%.1f", phase1Time))s")

            // Phase 2: Cross-note relatedness
            guard !Task.isCancelled else { return (analyzed, total) }

            let phase2Start = CFAbsoluteTimeGetCurrent()
            try computeRelatedness(context: context)
            try Self.persistContext(context, operation: "Note insight relatedness recompute")

            let totalTime = CFAbsoluteTimeGetCurrent() - start
            let phase2Time = CFAbsoluteTimeGetCurrent() - phase2Start
            Self.log.info("Phase 2 (relatedness) in \(String(format: "%.1f", phase2Time))s — total: \(String(format: "%.1f", totalTime))s")

            return (analyzed, total)
        } catch {
            Self.log.error("Reindex failed: \(error.localizedDescription, privacy: .public)")
            return (0, 0)
        }
    }

    /// Re-analyze a single note (called on vault sync for changed notes).
    /// Per-page debounce: rapid saves of the SAME page cancel previous work,
    /// but different pages run independently.
    func reanalyze(pageId: String) {
        reanalyzeTasks[pageId]?.cancel()
        let container = modelContainer
        let targetId = pageId
        let taskToken = UUID()
        reanalyzeTaskTokens[pageId] = taskToken
        reanalyzeTasks[pageId] = Task.detached(priority: .utility) { [weak self] in
            defer { Task { @MainActor [weak self] in self?.finishReanalyzeTask(pageId: targetId, token: taskToken) } }

            // Debounce: wait 500ms so rapid autosaves coalesce
            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch is CancellationError {
                return
            } catch {
                Self.log.error(
                    "Re-analyze debounce failed for \(String(targetId.prefix(8)), privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                return
            }
            guard !Task.isCancelled else { return }

            let context = ModelContext(container)
            context.autosaveEnabled = false

            let stage = Self.pageBodyStage(pageId: targetId, context: context)
            let body = await Self.readBody(from: stage)
            let hash = SDNoteInsight.hash(of: body)

            let existing: SDNoteInsight?
            do {
                existing = try Self.fetchInsightRecord(
                    pageId: targetId,
                    context: context,
                    operation: "Note insight re-analyze"
                )
            } catch {
                return
            }

            if let existing, existing.contentHash == hash { return }

            let signals = ContentPersonalitySignals.analyze(body)
            let insight = existing ?? SDNoteInsight(pageId: targetId)
            insight.contentHash = hash
            insight.lastAnalyzedAt = .now
            insight.sentiment = signals.sentiment
            insight.formality = signals.formalityScore
            insight.vocabDiversity = signals.vocabDiversity
            insight.questionDensity = signals.questionDensity
            insight.entityKeywords = signals.entityKeywords
            insight.topicNouns = signals.dominantTopics

            if existing == nil { context.insert(insight) }
            do {
                try context.save()
            } catch {
                Self.log.error("Re-analyze save failed for \(targetId.prefix(8), privacy: .public): \(error.localizedDescription, privacy: .public)")
                return
            }
            guard !Task.isCancelled else { return }

            Self.log.info("Re-analyzed note \(targetId.prefix(8))")

            // Schedule coalesced Phase 2 — multiple page saves within 300ms share one recompute
            await self?.scheduleRelatedness()
        }
    }

    private nonisolated static func pageBodyStage(for page: SDPage) -> PageBodyStage {
        PageBodyStage(
            pageId: page.id,
            filePath: page.filePath,
            inlineBody: page.body
        )
    }

    private nonisolated static func pageBodyStage(pageId: String, context: ModelContext) -> PageBodyStage {
        let targetId = pageId
        do {
            var descriptor = FetchDescriptor<SDPage>(
                predicate: #Predicate<SDPage> { $0.id == targetId }
            )
            descriptor.fetchLimit = 1
            if let page = try context.fetch(descriptor).first {
                return pageBodyStage(for: page)
            }
        } catch {
            Self.log.error(
                "Note insight body stage fetch failed for \(String(pageId.prefix(8)), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
        return PageBodyStage(pageId: pageId, filePath: nil, inlineBody: "")
    }

    private nonisolated static func readBody(from stage: PageBodyStage) async -> String {
        await SDPage.loadBodyAsyncFromPrimitives(
            pageId: stage.pageId,
            filePath: stage.filePath,
            inlineBody: stage.inlineBody,
            mapped: true,
            fast: true
        )
    }

    private func finishReanalyzeTask(pageId: String, token: UUID) {
        guard reanalyzeTaskTokens[pageId] == token else { return }
        reanalyzeTaskTokens.removeValue(forKey: pageId)
        reanalyzeTasks.removeValue(forKey: pageId)
    }

    /// Coalesces Phase 2 relatedness recomputes. Multiple per-page Phase 1 completions
    /// within 300ms share a single O(n²) recompute instead of running redundant ones.
    private func scheduleRelatedness() {
        relatednessTask?.cancel()
        let container = modelContainer
        relatednessTask = Task.detached(priority: .utility) {
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch is CancellationError {
                return
            } catch {
                Self.log.error(
                    "Relatedness debounce failed: \(error.localizedDescription, privacy: .public)"
                )
                return
            }
            guard !Task.isCancelled else { return }

            let context = ModelContext(container)
            context.autosaveEnabled = false
            do {
                try NoteInsightService.computeRelatedness(context: context)
                try context.save()
                Self.log.info("Coalesced relatedness recompute complete")
            } catch {
                Self.log.error("Coalesced relatedness recompute failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Fetch cached insight for a note. Returns nil if not yet analyzed.
    nonisolated func fetchInsight(pageId: String, context: ModelContext) -> SDNoteInsight? {
        do {
            return try Self.fetchInsightRecord(
                pageId: pageId,
                context: context,
                operation: "Note insight fetch"
            )
        } catch {
            return nil
        }
    }

    func debugPendingReanalyzeTaskCount() -> Int {
        reanalyzeTasks.count
    }

    // MARK: - Phase 2: Relatedness

    private nonisolated static let relatednessThreshold = 0.35
    private nonisolated static let gapThreshold = 0.15
    private nonisolated static let maxRelated = 5

    nonisolated static func computeRelatedness(context: ModelContext, onlyForPageId: String? = nil) throws {
        let allInsights = try context.fetch(FetchDescriptor<SDNoteInsight>())
        guard allInsights.count >= 2 else { return }

        // Build lookup tables
        let entitySets: [String: Set<String>] = Dictionary(
            uniqueKeysWithValues: allInsights.map { ($0.pageId, Set($0.entityKeywords.map { $0.lowercased() })) }
        )
        let topicSets: [String: Set<String>] = Dictionary(
            uniqueKeysWithValues: allInsights.map { ($0.pageId, Set($0.topicNouns.map { $0.lowercased() })) }
        )

        // IDF weights for entities — common entities get lower weight
        var entityDocFreq: [String: Int] = [:]
        for (_, entities) in entitySets {
            for entity in entities {
                entityDocFreq[entity, default: 0] += 1
            }
        }
        let totalDocs = Double(allInsights.count)
        let entityIDF: [String: Double] = Dictionary(
            uniqueKeysWithValues: entityDocFreq.map { ($0.key, log2(totalDocs / max(1, Double($0.value)))) }
        )
        let maxIDF = entityIDF.values.max() ?? 1.0

        let targets = onlyForPageId != nil
            ? allInsights.filter { $0.pageId == onlyForPageId }
            : allInsights

        for insight in targets {
            let aId = insight.pageId
            let aEntities = entitySets[aId] ?? []
            let aTopics = topicSets[aId] ?? []

            var candidates: [(id: String, score: Double, reasons: [String])] = []

            for other in allInsights where other.pageId != aId {
                let bId = other.pageId
                let bEntities = entitySets[bId] ?? []
                let bTopics = topicSets[bId] ?? []

                var score = 0.0
                var reasons: [String] = []

                // Signal 1: Entity overlap with IDF weighting (0.30 weight)
                let sharedEntities = aEntities.intersection(bEntities)
                if !sharedEntities.isEmpty {
                    let union = aEntities.union(bEntities)
                    // IDF-weighted Jaccard: sum of IDF for shared / sum of IDF for union
                    let sharedIDF = sharedEntities.reduce(0.0) { $0 + (entityIDF[$1] ?? 0) / maxIDF }
                    let unionIDF = union.reduce(0.0) { $0 + (entityIDF[$1] ?? 0) / maxIDF }
                    let idfJaccard = unionIDF > 0 ? sharedIDF / unionIDF : 0
                    if idfJaccard > 0.10 {
                        score += idfJaccard * 0.30
                        reasons.append(RelatednessReason.sharedEntities.rawValue)
                    }
                }

                // Signal 2: Topic noun overlap (0.25 weight)
                let sharedTopics = aTopics.intersection(bTopics)
                if !sharedTopics.isEmpty {
                    let union = aTopics.union(bTopics)
                    let jaccard = Double(sharedTopics.count) / Double(max(1, union.count))
                    if jaccard > 0.15 {
                        score += jaccard * 0.25
                        reasons.append(RelatednessReason.sharedKeywords.rawValue)
                    }
                }

                // Signal 3: Sentiment + formality similarity (0.15 weight)
                // Notes with very similar tone are more likely related
                let sentimentDiff = abs(insight.sentiment - other.sentiment)
                let formalityDiff = abs(insight.formality - other.formality)
                let toneSimilarity = 1.0 - (sentimentDiff + formalityDiff) / 2.0
                if toneSimilarity > 0.75 && !reasons.isEmpty {
                    score += toneSimilarity * 0.15
                }

                // Signal 4 intentionally remains absent here. Relatedness currently relies on
                // entity and topic overlap until note-level embeddings become a real runtime path.

                if score >= relatednessThreshold && !reasons.isEmpty {
                    candidates.append((id: bId, score: score, reasons: reasons))
                }
            }

            // Sort by score descending
            candidates.sort { $0.score > $1.score }

            // Gap detection: cut at first gap > gapThreshold
            var cutoff = candidates.count
            if candidates.count >= 2 {
                for i in 1..<candidates.count {
                    if candidates[i - 1].score - candidates[i].score > gapThreshold {
                        cutoff = i
                        break
                    }
                }
            }
            candidates = Array(candidates.prefix(min(maxRelated, cutoff)))

            insight.relatedNoteIds = candidates.map(\.id)
            insight.relatednessScores = candidates.map(\.score)
            insight.relatednessReasons = candidates.map(\.reasons)
        }
    }
}
