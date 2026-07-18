import Foundation
import OSLog

// MARK: - ContextualShadowsState
// Patch 7 / AMBIENT_RECALL_WIRING_PLAN.md §5 — V0 ambient-recall surface state.
// Gated by the `EPISTEMOS_AMBIENT_RECALL_V0` product flag. Owns the latest
// top-K recall hit list, panel visibility, and the in-flight `Task` so a fresh
// keystroke can cancel the previous query before launching a new one.
//
// Off-MainActor discipline: the actual encoder + HNSW search runs inside
// `Task.detached(priority: .utility)`. Only the final `currentResults`
// assignment hops back to the @MainActor in the `await MainActor.run` block.
// Typing latency must stay 60fps — see plan §7.

@MainActor
@Observable
final class ContextualShadowsState {

    // MARK: - Types

    /// Single ambient-recall hit shown in the panel. Captured as `Sendable`
    /// so the off-MainActor query path can hand the converted result back to
    /// MainActor via `await MainActor.run`.
    nonisolated struct RecallHit: Identifiable, Hashable, Sendable {
        let id: String  // durable document id
        let title: String
        let snippet: String
        let kind: RecallContextKind
        let similarity: Float
        let source: String

        init(
            id: String,
            title: String,
            snippet: String,
            kind: RecallContextKind,
            similarity: Float,
            source: String = "instant-recall"
        ) {
            self.id = id
            self.title = title
            self.snippet = snippet
            self.kind = kind
            self.similarity = similarity
            self.source = source
        }
    }

    nonisolated struct RecallPayload: Equatable, Sendable {
        let results: [RecallHit]
        let queryText: String
        let errorMessage: String?
        let isSearching: Bool

        static let empty = RecallPayload(
            results: [],
            queryText: "",
            errorMessage: nil,
            isSearching: false
        )

        var hasPanelPayload: Bool {
            !results.isEmpty || errorMessage != nil || isSearching
        }
    }

    // MARK: - Constants

    /// Minimum query length per AMBIENT_RECALL_WIRING_PLAN R3 — avoids
    /// recall noise on quick acks ("ok", "hi") in input surfaces.
    nonisolated static let minimumQueryLength: Int = 6

    /// Default recall payload shown across typing surfaces. This intentionally
    /// exceeds the old top-5 so the panel can behave like a real related
    /// thoughts surface instead of repeating the same short list.
    nonisolated static let defaultTopK: Int = 12

    /// Backend request limit before cross-channel dedupe/ranking.
    nonisolated private static let backendSearchLimit: Int = 16

    /// Explicit title lookups need a wider first pass than ambient semantic
    /// recall. Otherwise a generated "look-for-a-note..." artifact can appear
    /// in the first few FTS rows while the real title sits farther down.
    nonisolated private static let explicitTitleSearchLimit: Int = 80

    /// UserDefaults-backed product gate. The environment variable can
    /// still pin the surface on for CI/schemes; the persisted setting keeps
    /// the user-facing app from silently disabling Halo/Contextual Shadows
    /// when no launch environment is present.
    nonisolated static let userDefaultsKey = "EPISTEMOS_AMBIENT_RECALL_V0"
    nonisolated static let defaultEnabled = true

    // MARK: - Published state

    /// Top-K results from the most recently completed recall query.
    var currentResults: [RecallHit] = []

    /// Query window used for the latest live recall request. Exposed so the
    /// panel can show that it is tracking the current sentence/topic, not a
    /// stale note-wide snapshot.
    private(set) var lastQueryText: String = ""

    /// Recoverable backend error from the mounted Shadow route. Kept separate
    /// from `currentResults` so a broken Shadow index does not masquerade as
    /// a valid zero-hit recall query.
    private(set) var lastErrorMessage: String?

    /// Whether the lightweight slide-in panel is currently visible.
    var isPanelVisible: Bool = false

    /// In-flight recall task — held so a fresh keystroke can cancel and
    /// supersede the previous query before launching a new one.
    var pendingTask: Task<Void, Never>?

    /// True only when the V0 flag is set on the running process. UI surfaces
    /// must hide themselves entirely when false.
    var isEnabled: Bool {
        if let isEnabledOverride {
            return isEnabledOverride
        }
        if ProcessInfo.processInfo.environment[Self.userDefaultsKey] == "1" {
            return true
        }
        if let persisted = FoundationSafety.runtimeUserDefaults.object(forKey: Self.userDefaultsKey) as? Bool {
            return persisted
        }
        return Self.defaultEnabled
    }

    // MARK: - Internals

    private let isEnabledOverride: Bool?
    private var shadowSearch: (any ShadowSearchServicing)?
    private var scopedPayloads: [String: RecallPayload] = [:]
    private var scopedPanelVisibility: [String: Bool] = [:]
    private var scopedPendingTasks: [String: Task<Void, Never>] = [:]
    private(set) var latestScopeKey: String?
    private(set) var recallCancellationCount: UInt = 0
    private(set) var haloSearchRevision: Int = 0

    var haloSearchService: (any ShadowSearchServicing)? {
        guard isEnabled else { return nil }
        return shadowSearch
    }

    var hasPanelPayload: Bool {
        !currentResults.isEmpty || lastErrorMessage != nil
    }

    func hasPanelPayload(kind: RecallContextKind? = nil, originDocId: String? = nil) -> Bool {
        payload(kind: kind, originDocId: originDocId).hasPanelPayload
    }

    func payload(kind: RecallContextKind? = nil, originDocId: String? = nil) -> RecallPayload {
        guard let scopeKey = Self.scopeKey(kind: kind, originDocId: originDocId) else {
            return RecallPayload(
                results: currentResults,
                queryText: lastQueryText,
                errorMessage: lastErrorMessage,
                isSearching: pendingTask != nil
            )
        }
        return scopedPayloads[scopeKey] ?? .empty
    }

    func isPanelVisible(kind: RecallContextKind? = nil, originDocId: String? = nil) -> Bool {
        guard let scopeKey = Self.scopeKey(kind: kind, originDocId: originDocId) else {
            return isPanelVisible
        }
        return scopedPanelVisibility[scopeKey] == true
    }

    nonisolated private static let log = Logger(
        subsystem: "com.epistemos",
        category: "ContextualShadowsState"
    )

    init(isEnabledOverride: Bool? = nil) {
        self.isEnabledOverride = isEnabledOverride
    }

    /// Configure the newer Shadow backend as the preferred V0 recall route.
    /// Existing callers still pass `InstantRecallService`; this optional
    /// service lets AppBootstrap switch the backend once the per-vault Shadow
    /// handle is ready, without touching editor hot paths.
    func configureShadowSearch(_ search: (any ShadowSearchServicing)?) {
        shadowSearch = search
        haloSearchRevision &+= 1
    }

    /// Drop all visible and in-flight recall/Halo state for a vault lifecycle boundary.
    func resetForVaultLifecycle() {
        pendingTask?.cancel()
        pendingTask = nil
        shadowSearch = nil
        clearResults()
        haloSearchRevision &+= 1
    }

    // MARK: - Recall request

    /// Schedule an off-MainActor recall query for the supplied snapshot.
    /// Cancels any in-flight task for the same surface before launching a new
    /// one (backpressure per plan §7 — never queue, always supersede). Other
    /// open note surfaces keep their own recall payload instead of inheriting or
    /// cancelling the caller's current query.
    ///
    /// Prefers the configured Shadow backend when available; otherwise falls
    /// back to `InstantRecallService.searchAsync`. Only the final assignment to
    /// `currentResults` runs on @MainActor.
    func requestRecall(
        snapshot: RecallContextSnapshot,
        instantRecall: InstantRecallService,
        searchIndexService: SearchIndexService? = nil
    ) {
        // Flag-gated: when V0 is OFF, clear any visible stale snapshot and
        // schedule no work. UI guards on `isEnabled` separately so this is a
        // belt-and-braces guarantee.
        guard isEnabled else {
            clearResults()
            return
        }

        let originDocId = snapshot.originDocId
        let scopeKey = Self.scopeKey(kind: snapshot.kind, originDocId: originDocId)
        latestScopeKey = scopeKey
        cancelPendingTask(scopeKey: scopeKey)

        guard ProductCapabilityPolicy.allowsContextualShadowPresentation(of: snapshot.kind) else {
            clearResults(scopeKey: scopeKey)
            return
        }

        // Minimum query length keeps input surfaces quiet during quick
        // acks; note editing also benefits from skipping very short
        // partial words.
        let queryText = Self.recallQuery(from: snapshot.text)
        guard queryText.count >= Self.minimumQueryLength else {
            clearResults(scopeKey: scopeKey)
            return
        }

        lastQueryText = queryText
        publishPendingPayload(scopeKey: scopeKey, queryText: queryText)

        if let shadowSearch {
            let task = Task { [weak self, shadowSearch, searchIndexService, instantRecall] in
                let outcome = await shadowSearch.searchReportingErrors(
                    text: queryText,
                    limit: Self.backendSearchLimit
                )
                let shadowHits = Self.convert(raw: outcome.hits, originDocId: originDocId)

                let fallbackHits: [RecallHit]
                if shadowHits.count < Self.defaultTopK {
                    fallbackHits = await Self.appSearchFallbackHits(
                        queryText: queryText,
                        originDocId: originDocId,
                        instantRecall: instantRecall,
                        searchIndexService: searchIndexService
                    )
                } else {
                    fallbackHits = []
                }

                let mergedHits = Self.rankedUniqueHits(
                    shadowHits + fallbackHits,
                    limit: Self.defaultTopK,
                    queryText: queryText
                )

                if mergedHits.isEmpty {
                    await MainActor.run {
                        guard let self else { return }
                        guard !Task.isCancelled else { return }
                        if let errorMessage = outcome.errorMessage {
                            self.publishPayload(
                                scopeKey: scopeKey,
                                queryText: queryText,
                                results: [],
                                errorMessage: errorMessage,
                                isVisible: true
                            )
                            return
                        }
                        self.publishPayload(
                            scopeKey: scopeKey,
                            queryText: queryText,
                            results: [],
                            errorMessage: nil,
                            isVisible: false
                        )
                    }
                    return
                }

                await MainActor.run {
                    guard let self else { return }
                    guard !Task.isCancelled else { return }
                    self.publishPayload(
                        scopeKey: scopeKey,
                        queryText: queryText,
                        results: mergedHits,
                        errorMessage: nil,
                        isVisible: true
                    )
                }
            }
            storePendingTask(task, scopeKey: scopeKey)
            return
        }

        let task = Task { [weak self, instantRecall, searchIndexService] in
            let hits = await Self.appSearchFallbackHits(
                queryText: queryText,
                originDocId: originDocId,
                instantRecall: instantRecall,
                searchIndexService: searchIndexService
            )

            // Re-enter MainActor for the published mutation. Drop the result
            // entirely if the task was cancelled or the originating snapshot
            // belongs to a stale composer.
            await MainActor.run {
                guard let self else { return }
                guard !Task.isCancelled else { return }
                self.publishPayload(
                    scopeKey: scopeKey,
                    queryText: queryText,
                    results: hits,
                    errorMessage: nil,
                    isVisible: !hits.isEmpty
                )
            }
        }
        storePendingTask(task, scopeKey: scopeKey)
    }

    // MARK: - Panel visibility

    /// Open the contextual-shadows panel. No-op when V0 flag is OFF so a
    /// stray binding can never surface the panel in production.
    func openPanel() {
        guard isEnabled else { return }
        isPanelVisible = true
    }

    func openPanel(kind: RecallContextKind?, originDocId: String?) {
        guard isEnabled else { return }
        guard let scopeKey = Self.scopeKey(kind: kind, originDocId: originDocId) else {
            openPanel()
            return
        }
        scopedPanelVisibility[scopeKey] = true
        latestScopeKey = scopeKey
    }

    /// Close the panel and clear `currentResults` (memory hygiene per plan
    /// §8.7 — closing the panel must release its result snapshot).
    func closePanel() {
        isPanelVisible = false
        currentResults = []
        lastErrorMessage = nil
        lastQueryText = ""
        latestScopeKey = nil
        scopedPayloads.removeAll(keepingCapacity: true)
        scopedPanelVisibility.removeAll(keepingCapacity: true)
        cancelAllScopedPendingTasks()
    }

    private func clearResults() {
        isPanelVisible = false
        currentResults = []
        lastErrorMessage = nil
        lastQueryText = ""
        latestScopeKey = nil
        scopedPayloads.removeAll(keepingCapacity: true)
        scopedPanelVisibility.removeAll(keepingCapacity: true)
        cancelAllScopedPendingTasks()
    }

    func closePanel(kind: RecallContextKind?, originDocId: String?) {
        guard let scopeKey = Self.scopeKey(kind: kind, originDocId: originDocId) else {
            closePanel()
            return
        }
        scopedPendingTasks[scopeKey]?.cancel()
        scopedPendingTasks[scopeKey] = nil
        pendingTask = scopedPendingTasks.values.first
        scopedPanelVisibility[scopeKey] = false
        scopedPayloads[scopeKey] = .empty
        if latestScopeKey == scopeKey {
            currentResults = []
            lastErrorMessage = nil
            lastQueryText = ""
            isPanelVisible = false
        }
    }

    private func cancelPendingTask(scopeKey: String?) {
        guard let scopeKey else {
            if pendingTask != nil {
                recallCancellationCount &+= 1
            }
            pendingTask?.cancel()
            pendingTask = nil
            return
        }
        if scopedPendingTasks[scopeKey] != nil {
            recallCancellationCount &+= 1
        }
        scopedPendingTasks[scopeKey]?.cancel()
        scopedPendingTasks[scopeKey] = nil
    }

    private func storePendingTask(_ task: Task<Void, Never>, scopeKey: String?) {
        guard let scopeKey else {
            pendingTask = task
            return
        }
        scopedPendingTasks[scopeKey] = task
        pendingTask = task
    }

    private func cancelAllScopedPendingTasks() {
        pendingTask?.cancel()
        pendingTask = nil
        for task in scopedPendingTasks.values {
            task.cancel()
        }
        scopedPendingTasks.removeAll(keepingCapacity: true)
    }

    private func clearResults(scopeKey: String?) {
        guard let scopeKey else {
            clearResults()
            return
        }
        scopedPayloads[scopeKey] = .empty
        scopedPanelVisibility[scopeKey] = false
        if latestScopeKey == scopeKey {
            currentResults = []
            lastErrorMessage = nil
            lastQueryText = ""
            isPanelVisible = false
        }
    }

    private func publishPayload(
        scopeKey: String?,
        queryText: String,
        results: [RecallHit],
        errorMessage: String?,
        isVisible: Bool
    ) {
        let visibleResults = Self.freeV1VisibleRecallHits(results)
        currentResults = visibleResults
        lastQueryText = queryText
        lastErrorMessage = errorMessage
        // SS-IR (owner 2026-06-20): never AUTO-OPEN the panel from a query result — that was the
        // "weird pixel box that overlays things" popping up mid-typing. A query still publishes its
        // payload (which LIGHTS the button via hasPanelPayload), but only KEEPS the panel visible
        // if the user had ALREADY opened it; `isVisible:false` (empty/error) still closes. The
        // explicit openPanel() (button click) is now the sole path that opens the panel.
        let hasVisiblePayload = !visibleResults.isEmpty || errorMessage != nil
        isPanelVisible = isVisible && hasVisiblePayload && isPanelVisible
        latestScopeKey = scopeKey

        guard let scopeKey else {
            pendingTask = nil
            return
        }
        let scopeWasOpen = scopedPanelVisibility[scopeKey] == true
        scopedPayloads[scopeKey] = RecallPayload(
            results: visibleResults,
            queryText: queryText,
            errorMessage: errorMessage,
            isSearching: false
        )
        scopedPanelVisibility[scopeKey] = isVisible && hasVisiblePayload && scopeWasOpen
        scopedPendingTasks[scopeKey] = nil
        pendingTask = scopedPendingTasks.values.first
    }

    private func publishPendingPayload(scopeKey: String?, queryText: String) {
        currentResults = []
        lastQueryText = queryText
        lastErrorMessage = nil
        latestScopeKey = scopeKey

        guard let scopeKey else {
            return
        }

        let wasVisible = scopedPanelVisibility[scopeKey] == true
        scopedPayloads[scopeKey] = RecallPayload(
            results: [],
            queryText: queryText,
            errorMessage: nil,
            isSearching: true
        )
        scopedPanelVisibility[scopeKey] = wasVisible
    }

    // MARK: - Conversion

    /// Convert raw `InstantRecallResult` values to `RecallHit`. Kept as a
    /// `nonisolated static` so it can be invoked from either actor side
    /// without a hop. Filters out the originating document to avoid suggesting
    /// the very note the user is composing into.
    nonisolated static func convert(
        raw: [InstantRecallResult],
        resultKind: RecallContextKind,
        originId: UUID
    ) -> [RecallHit] {
        convert(raw: raw, resultKind: resultKind, originDocId: originId.uuidString)
    }

    nonisolated static func freeV1VisibleRecallHits(_ hits: [RecallHit]) -> [RecallHit] {
        hits.filter { ProductCapabilityPolicy.allowsContextualShadowPresentation(of: $0.kind) }
    }

    nonisolated static func convert(
        raw: [InstantRecallResult],
        resultKind: RecallContextKind,
        originDocId: String
    ) -> [RecallHit] {
        return raw.compactMap { result -> RecallHit? in
            guard result.id != originDocId else { return nil }
            let snippet = makeSnippet(from: result.text)
            let title = makeTitle(from: result.text)
            return RecallHit(
                id: result.id,
                title: title,
                snippet: snippet,
                kind: resultKind,
                similarity: Float(result.score),
                source: "instant-recall"
            )
        }
    }

    nonisolated static func convert(
        raw: [ShadowHit],
        originId: UUID
    ) -> [RecallHit] {
        convert(raw: raw, originDocId: originId.uuidString)
    }

    nonisolated static func convert(
        raw: [ShadowHit],
        originDocId: String
    ) -> [RecallHit] {
        return raw.compactMap { hit -> RecallHit? in
            guard hit.id != originDocId, hit.domain == .notes else { return nil }
            return RecallHit(
                id: hit.id,
                title: hit.title,
                snippet: hit.snippet,
                kind: .note,
                similarity: hit.score,
                source: hit.source.isEmpty ? "shadow" : hit.source
            )
        }
    }

    nonisolated static func convert(
        raw: [InstantRecallResult],
        kind: RecallContextKind,
        originId: UUID
    ) -> [RecallHit] {
        convert(raw: raw, resultKind: kind, originId: originId)
    }

    nonisolated static func convert(
        raw: [SearchResult],
        originId: UUID
    ) -> [RecallHit] {
        convert(raw: raw, originDocId: originId.uuidString)
    }

    nonisolated static func convert(
        raw: [SearchResult],
        originDocId: String
    ) -> [RecallHit] {
        return raw.enumerated().compactMap { index, result -> RecallHit? in
            guard result.pageId != originDocId else { return nil }
            let title = result.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let snippet = cleanSearchSnippet(result.snippet)
            let score = searchIndexSimilarity(rank: result.rank, index: index)
            return RecallHit(
                id: result.pageId,
                title: title.isEmpty ? "Untitled" : String(title.prefix(80)),
                snippet: snippet,
                kind: .note,
                similarity: score,
                source: "vault-search"
            )
        }
    }

    nonisolated private static func appSearchFallbackHits(
        queryText: String,
        originDocId: String,
        instantRecall: InstantRecallService,
        searchIndexService: SearchIndexService?
    ) async -> [RecallHit] {
        if let searchIndexService {
            do {
                let titleIntent = explicitTitleIntent(from: queryText)
                let searchQueries = explicitTitleSearchQueries(
                    titleIntent: titleIntent,
                    queryText: queryText
                )
                let searchLimit = titleIntent == nil
                    ? Self.backendSearchLimit
                    : max(Self.backendSearchLimit, Self.explicitTitleSearchLimit)
                var results: [SearchResult] = []
                for query in searchQueries {
                    let queryResults = try await searchIndexService.searchAsync(
                        query: query,
                        limit: searchLimit
                    )
                    results.append(contentsOf: queryResults)
                }
                let hits = Self.convert(raw: results, originDocId: originDocId)
                if !hits.isEmpty {
                    return Self.rankedUniqueHits(
                        hits,
                        limit: Self.defaultTopK,
                        queryText: queryText
                    )
                }
            } catch {
                log.warning(
                    "Contextual Shadows vault-search fallback failed."
                )
            }
        }

        // searchAsync internally hops to a detached utility task for the
        // FFI call. We await its result here; the await suspension is
        // cancellation-aware so a cancelled task short-circuits in the caller.
        let titleIntent = explicitTitleIntent(from: queryText)
        let searchQueries = explicitTitleSearchQueries(
            titleIntent: titleIntent,
            queryText: queryText
        )
        let searchLimit = titleIntent == nil
            ? Self.backendSearchLimit
            : max(Self.backendSearchLimit, Self.explicitTitleSearchLimit)
        var raw: [InstantRecallResult] = []
        for query in searchQueries {
            let queryResults = await instantRecall.searchAsync(
                query: query,
                topK: searchLimit
            )
            raw.append(contentsOf: queryResults)
        }
        let hits = Self.convert(
            raw: raw,
            resultKind: .note,
            originDocId: originDocId
        )
        return Self.rankedUniqueHits(
            hits,
            limit: Self.defaultTopK,
            queryText: queryText
        )
    }

    /// Build a compact semantic query from the live typed text. Full-note
    /// queries make older paragraphs dominate; this keeps recall attached to
    /// the sentence/topic the user is actively writing.
    nonisolated static func recallQuery(from text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let compactNormalized = normalized
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !compactNormalized.isEmpty else { return "" }

        let tail = String(normalized.suffix(1_200))
        let paragraphWindow = currentRecallParagraph(from: tail)
        let activeLineWindow = currentRecallLine(from: paragraphWindow)
        let focusWindow = normalizedRecallField(activeLineWindow).count >= Self.minimumQueryLength
            ? activeLineWindow
            : paragraphWindow
        let sentencePieces = focusWindow
            .split(whereSeparator: { ".?!;".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let sentenceWindow = sentencePieces
            .suffix(2)
            .joined(separator: ". ")
        let baseWindow = sentenceWindow.isEmpty ? String(focusWindow.suffix(520)) : sentenceWindow
        // Keep explicit note-title lookup local to the active writing window.
        // Pulling a "look for note titled ..." command from the whole note
        // makes later unrelated sentences keep recalling the old target.
        let titleIntent = explicitTitleIntent(from: focusWindow)
            ?? (normalizedRecallField(focusWindow) == normalizedRecallField(compactNormalized)
                ? explicitTitleIntent(from: compactNormalized)
                : nil)
        let baseTerms = Set(
            normalizedRecallField([titleIntent, baseWindow].compactMap { $0 }.joined(separator: " "))
                .split(separator: " ")
                .map(String.init)
        )
        let keywordValues = rankedKeywords(from: baseWindow, limit: 10)
            .filter { !baseTerms.contains($0) }
        let keywords = keywordValues.isEmpty ? nil : keywordValues.joined(separator: " ")
        let combined = [titleIntent, baseWindow, keywords]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(combined.prefix(1_000))
    }

    nonisolated private static func currentRecallParagraph(from text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let paragraphSeparated = normalized
            .replacingOccurrences(
                of: "\\n\\s*\\n",
                with: "\u{0}",
                options: .regularExpression
            )
        let paragraphs = paragraphSeparated
            .components(separatedBy: "\u{0}")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return paragraphs.last ?? normalized
    }

    nonisolated private static func currentRecallLine(from text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.last ?? normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func explicitTitleIntent(from text: String) -> String? {
        let patterns = [
            #/(?i)\b(?:go\s+to|open|find|use|read|show|look\s+for|check)\s+(?:the\s+|my\s+)?notes?\s+(?:titled|called)\s+["“]?(.+?)["”]?(?=\s+(?:in\s+(?:my\s+)?(?:notes|vault)|and|then|please|summarize|rewrite|analyze|compare|review|explain|tell|show|use)\b|[?.!,]|$)/#,
            #/(?i)\b(?:titled|called)\s+["“]?(.+?)["”]?(?=\s+(?:in\s+(?:my\s+)?(?:notes|vault)|and|then|please|summarize|rewrite|analyze|compare|review|explain|tell|show|use)\b|[?.!,]|$)/#,
            #/(?i)\b(?:go\s+to|open|find|use|read|show|look\s+for|check)\s+(?:the\s+|my\s+)?notes?\s+(.+?)(?=\s+(?:in\s+(?:my\s+)?(?:notes|vault)|and|then|please|summarize|rewrite|analyze|compare|review|explain|tell|show|use)\b|[?.!,]|$)/#,
        ]

        for pattern in patterns {
            if let match = text.firstMatch(of: pattern) {
                let title = String(match.output.1)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’"))
                if !title.isEmpty {
                    return title
                }
            }
        }
        return nil
    }

    nonisolated private static func explicitTitleSearchQueries(
        titleIntent: String?,
        queryText: String
    ) -> [String] {
        uniquePreservingOrder([titleIntent, queryText].compactMap { candidate in
            let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        })
    }

    nonisolated private static func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var ordered: [String] = []
        ordered.reserveCapacity(values.count)
        for value in values {
            let normalized = normalizedRecallField(value)
            guard !normalized.isEmpty, !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            ordered.append(value)
        }
        return ordered
    }

    nonisolated private static func rankedKeywords(from text: String, limit: Int) -> [String] {
        var counts: [String: Int] = [:]
        var firstSeen: [String: Int] = [:]
        let tokens = text
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
        for (index, token) in tokens.enumerated() {
            guard token.count >= 3, !recallStopWords.contains(token) else { continue }
            counts[token, default: 0] += 1
            if firstSeen[token] == nil {
                firstSeen[token] = index
            }
        }
        let rankedTokens: [String] = counts.keys.sorted { lhs, rhs in
            let leftCount = counts[lhs, default: 0]
            let rightCount = counts[rhs, default: 0]
            if leftCount != rightCount { return leftCount > rightCount }
            return firstSeen[lhs, default: Int.max] < firstSeen[rhs, default: Int.max]
        }
        return Array(rankedTokens.prefix(limit))
    }

    nonisolated private static let recallStopWords: Set<String> = [
        "the", "and", "for", "that", "this", "with", "from", "have", "has",
        "had", "was", "were", "are", "you", "your", "but", "not", "can",
        "could", "would", "should", "about", "into", "when", "then", "than",
        "they", "them", "there", "their", "what", "why", "how", "just",
        "like", "really", "because", "while", "also", "more", "most"
    ]

    nonisolated private static func rankedUniqueHits(
        _ hits: [RecallHit],
        limit: Int,
        queryText: String? = nil
    ) -> [RecallHit] {
        var bestByID: [String: RecallHit] = [:]
        for hit in hits {
            let key = "\(hit.kind.rawValue):\(hit.id)"
            guard let existing = bestByID[key] else {
                bestByID[key] = hit
                continue
            }
            if hit.similarity > existing.similarity {
                bestByID[key] = hit
            }
        }
        let normalizedTitleIntent = queryText
            .flatMap { explicitTitleIntent(from: $0) }
            .map(normalizedRecallField)
            .flatMap { $0.isEmpty ? nil : $0 }
        return bestByID.values
            .sorted {
                let lhsScore = recallRankingScore($0, normalizedTitleIntent: normalizedTitleIntent)
                let rhsScore = recallRankingScore($1, normalizedTitleIntent: normalizedTitleIntent)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }

    nonisolated private static func recallRankingScore(
        _ hit: RecallHit,
        normalizedTitleIntent: String?
    ) -> Float {
        guard let normalizedTitleIntent, !normalizedTitleIntent.isEmpty else {
            return hit.similarity
        }
        let normalizedTitle = normalizedRecallField(hit.title)
        guard !normalizedTitle.isEmpty else { return hit.similarity }
        let titleLooksLikeLookupCommand = recallTitleLooksLikeLookupCommand(normalizedTitle)

        if normalizedTitle == normalizedTitleIntent {
            return hit.similarity + 4.0
        }
        if normalizedTitle.contains(normalizedTitleIntent) {
            return hit.similarity + (titleLooksLikeLookupCommand ? 0.35 : 3.0)
        }
        let titleTokens = Set(normalizedTitle.split(separator: " ").map(String.init))
        let intentTokens = normalizedTitleIntent
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
        guard !intentTokens.isEmpty else { return hit.similarity }
        let overlap = intentTokens.reduce(0) { partial, token in
            partial + (titleTokens.contains(token) ? 1 : 0)
        }
        if overlap == intentTokens.count {
            return hit.similarity + (titleLooksLikeLookupCommand ? 0.20 : 2.0)
        }
        let commandPenalty: Float = titleLooksLikeLookupCommand ? 0.35 : 0
        return hit.similarity + Float(overlap) * 0.25 - commandPenalty
    }

    nonisolated private static func normalizedRecallField(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    nonisolated private static func recallTitleLooksLikeLookupCommand(_ normalizedTitle: String) -> Bool {
        normalizedTitle.hasPrefix("look for ")
            || normalizedTitle.hasPrefix("find ")
            || normalizedTitle.hasPrefix("open ")
            || normalizedTitle.hasPrefix("read ")
            || normalizedTitle.contains(" note titled ")
            || normalizedTitle.contains(" note called ")
            || normalizedTitle.contains("notes titled")
            || normalizedTitle.contains("notes called")
    }

    /// Best-effort title extraction — prefer the first markdown heading,
    /// otherwise fall back to the first non-empty line trimmed.
    nonisolated private static func makeTitle(from text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        for raw in lines {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if trimmed.hasPrefix("#") {
                let stripped = trimmed.drop(while: { $0 == "#" })
                    .trimmingCharacters(in: .whitespaces)
                if !stripped.isEmpty { return String(stripped.prefix(80)) }
            }
            return String(trimmed.prefix(80))
        }
        return "Untitled"
    }

    nonisolated private static func makeSnippet(from text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(collapsed.prefix(160))
    }

    nonisolated private static func cleanSearchSnippet(_ snippet: String) -> String {
        let cleaned = snippet
            .replacingOccurrences(of: "<b>", with: "")
            .replacingOccurrences(of: "</b>", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(cleaned.prefix(160))
    }

    nonisolated private static func searchIndexSimilarity(rank: Double, index: Int) -> Float {
        let rankScore: Double
        if rank.isFinite {
            rankScore = 1.0 / (1.0 + max(0.0, abs(rank)))
        } else {
            rankScore = 1.0 / Double(index + 2)
        }
        let positionScore = 1.0 / Double(index + 1)
        return Float(min(1.0, max(0.05, max(rankScore, positionScore))))
    }

    nonisolated static func scopeKey(kind: RecallContextKind?, originDocId: String?) -> String? {
        guard let kind,
              let originDocId = originDocId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !originDocId.isEmpty
        else { return nil }
        return "\(kind.rawValue):\(originDocId)"
    }
}
