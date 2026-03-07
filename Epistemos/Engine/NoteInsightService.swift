import Foundation
import NaturalLanguage
import OSLog
import SwiftData

nonisolated(unsafe) private let log = Logger(subsystem: "Epistemos", category: "NoteInsightService")

// MARK: - NoteInsightService

@MainActor @Observable
final class NoteInsightService {

    private(set) var isIndexing = false
    private(set) var indexedCount = 0
    private(set) var totalCount = 0

    nonisolated(unsafe) private var reindexTask: Task<Void, Never>?
    private var reindexGeneration: Int = 0
    nonisolated(unsafe) private var reanalyzeTasks: [String: Task<Void, Never>] = [:]
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
        reindexTask = Task.detached(priority: .utility) {
            let result = NoteInsightService.runReindex(container: container)
            await MainActor.run { [result] in
                // Only update UI if this is still the latest reindex generation
                guard AppBootstrap.shared?.noteInsightService.reindexGeneration == gen else { return }
                AppBootstrap.shared?.noteInsightService.indexedCount = result.analyzed
                AppBootstrap.shared?.noteInsightService.totalCount = result.total
                AppBootstrap.shared?.noteInsightService.isIndexing = false
            }
        }
    }

    private nonisolated static func runReindex(container: ModelContainer) -> (analyzed: Int, total: Int) {
        let start = CFAbsoluteTimeGetCurrent()
        let context = ModelContext(container)
        context.autosaveEnabled = false

        do {
            let pages = try context.fetch(FetchDescriptor<SDPage>())
            let total = pages.count

            var analyzed = 0
            var skipped = 0
            for page in pages {
                guard !Task.isCancelled else { break }
                let body = NoteFileStorage.readBody(pageId: page.id)
                let hash = SDNoteInsight.hash(of: body)

                let targetPageId = page.id
                let existing = try? context.fetch(
                    FetchDescriptor<SDNoteInsight>(predicate: #Predicate { $0.pageId == targetPageId })
                ).first

                if let existing, existing.contentHash == hash {
                    skipped += 1
                    analyzed += 1
                    continue
                }

                let signals = ContentPersonalitySignals.analyze(body)
                let insight = existing ?? SDNoteInsight(pageId: page.id)
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
                    try? context.save()
                }
            }
            try? context.save()

            let phase1Time = CFAbsoluteTimeGetCurrent() - start
            log.info("Phase 1 complete: \(analyzed) notes (\(skipped) skipped) in \(String(format: "%.1f", phase1Time))s")

            // Phase 2: Cross-note relatedness
            guard !Task.isCancelled else { return (analyzed, total) }

            let phase2Start = CFAbsoluteTimeGetCurrent()
            try computeRelatedness(context: context)
            try? context.save()

            let totalTime = CFAbsoluteTimeGetCurrent() - start
            let phase2Time = CFAbsoluteTimeGetCurrent() - phase2Start
            log.info("Phase 2 (relatedness) in \(String(format: "%.1f", phase2Time))s — total: \(String(format: "%.1f", totalTime))s")

            return (analyzed, total)
        } catch {
            log.error("Reindex failed: \(error.localizedDescription, privacy: .public)")
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
        reanalyzeTasks[pageId] = Task.detached(priority: .utility) {
            // Debounce: wait 500ms so rapid autosaves coalesce
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }

            let context = ModelContext(container)
            context.autosaveEnabled = false

            let body = NoteFileStorage.readBody(pageId: targetId)
            let hash = SDNoteInsight.hash(of: body)

            let existing = try? context.fetch(
                FetchDescriptor<SDNoteInsight>(predicate: #Predicate { $0.pageId == targetId })
            ).first

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
            try? context.save()
            guard !Task.isCancelled else { return }

            log.info("Re-analyzed note \(targetId.prefix(8))")

            // Schedule coalesced Phase 2 — multiple page saves within 300ms share one recompute
            await MainActor.run {
                AppBootstrap.shared?.noteInsightService.scheduleRelatedness()
            }
        }
    }

    /// Coalesces Phase 2 relatedness recomputes. Multiple per-page Phase 1 completions
    /// within 300ms share a single O(n²) recompute instead of running redundant ones.
    private func scheduleRelatedness() {
        relatednessTask?.cancel()
        let container = modelContainer
        relatednessTask = Task.detached(priority: .utility) {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            let context = ModelContext(container)
            context.autosaveEnabled = false
            try? NoteInsightService.computeRelatedness(context: context)
            try? context.save()
            log.info("Coalesced relatedness recompute complete")
        }
    }

    /// Fetch cached insight for a note. Returns nil if not yet analyzed.
    nonisolated func fetchInsight(pageId: String, context: ModelContext) -> SDNoteInsight? {
        let targetId = pageId
        return try? context.fetch(
            FetchDescriptor<SDNoteInsight>(predicate: #Predicate { $0.pageId == targetId })
        ).first
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

                // Signal 4: Embedding similarity will be added when EmbeddingService
                // exposes per-note vectors. For now, entity + topic signals carry the weight.
                // TODO: Wire EmbeddingService.embeddings[pageId] cosine similarity (0.30 weight)

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
