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
        let id: String  // note/chat id (doc_id)
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

    // MARK: - Constants

    /// Minimum query length per AMBIENT_RECALL_WIRING_PLAN R3 — avoids
    /// recall noise on quick acks ("ok", "hi") in the chat composer.
    nonisolated static let minimumQueryLength: Int = 6

    /// Default top-K shown in each tab. Plan §2.5 — top-5 related notes.
    nonisolated static let defaultTopK: Int = 5

    /// UserDefaults-backed product gate. The environment variable can
    /// still pin the surface on for CI/schemes; the persisted setting keeps
    /// the user-facing app from silently disabling Halo/Contextual Shadows
    /// when no launch environment is present.
    nonisolated static let userDefaultsKey = "EPISTEMOS_AMBIENT_RECALL_V0"
    nonisolated static let defaultEnabled = true

    // MARK: - Published state

    /// Top-K results from the most recently completed recall query.
    var currentResults: [RecallHit] = []

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
        if let persisted = UserDefaults.standard.object(forKey: Self.userDefaultsKey) as? Bool {
            return persisted
        }
        return Self.defaultEnabled
    }

    // MARK: - Internals

    private let isEnabledOverride: Bool?
    private var shadowSearch: (any ShadowSearchServicing)?
    private(set) var haloSearchRevision: Int = 0

    var haloSearchService: (any ShadowSearchServicing)? {
        guard isEnabled else { return nil }
        return shadowSearch
    }

    var hasPanelPayload: Bool {
        !currentResults.isEmpty || lastErrorMessage != nil
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
    /// Cancels any in-flight task before launching a new one (backpressure
    /// per plan §7 — never queue, always supersede).
    ///
    /// Prefers the configured Shadow backend when available; otherwise falls
    /// back to `InstantRecallService.searchAsync`. Only the final assignment to
    /// `currentResults` runs on @MainActor.
    func requestRecall(
        snapshot: RecallContextSnapshot,
        instantRecall: InstantRecallService,
        searchIndexService: SearchIndexService? = nil
    ) {
        pendingTask?.cancel()
        pendingTask = nil

        // Flag-gated: when V0 is OFF, clear any visible stale snapshot and
        // schedule no work. UI guards on `isEnabled` separately so this is a
        // belt-and-braces guarantee.
        guard isEnabled else {
            clearResults()
            return
        }

        // Minimum query length keeps the chat composer quiet during quick
        // acks; the note composer also benefits from skipping very short
        // partial words.
        let queryText = snapshot.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard queryText.count >= Self.minimumQueryLength else {
            clearResults()
            return
        }

        let originId = snapshot.originId

        if let shadowSearch {
            let domains = Self.shadowDomains(for: snapshot.kind)
            pendingTask = Task { [weak self, shadowSearch, searchIndexService, instantRecall] in
                async let first = shadowSearch.searchReportingErrors(
                    text: queryText,
                    domain: domains.first,
                    limit: Self.defaultTopK
                )
                async let second = shadowSearch.searchReportingErrors(
                    text: queryText,
                    domain: domains.second,
                    limit: Self.defaultTopK
                )
                let firstOutcome = await first
                let secondOutcome = await second
                let raw = firstOutcome.hits + secondOutcome.hits
                let errorMessage = firstOutcome.errorMessage ?? secondOutcome.errorMessage
                let shadowHits = Self.convert(raw: raw, originId: originId)

                if shadowHits.isEmpty {
                    let fallbackHits = await Self.appSearchFallbackHits(
                        queryText: queryText,
                        originId: originId,
                        instantRecall: instantRecall,
                        searchIndexService: searchIndexService
                    )

                    await MainActor.run {
                        guard let self else { return }
                        guard !Task.isCancelled else { return }
                        if fallbackHits.isEmpty, let errorMessage {
                            self.currentResults = []
                            self.lastErrorMessage = errorMessage
                            self.isPanelVisible = true
                            return
                        }
                        self.lastErrorMessage = nil
                        self.currentResults = fallbackHits
                        self.isPanelVisible = !fallbackHits.isEmpty
                    }
                    return
                }

                await MainActor.run {
                    guard let self else { return }
                    guard !Task.isCancelled else { return }
                    if shadowHits.isEmpty, let errorMessage {
                        self.currentResults = []
                        self.lastErrorMessage = errorMessage
                        self.isPanelVisible = true
                        return
                    }
                    self.lastErrorMessage = nil
                    self.currentResults = shadowHits
                    self.isPanelVisible = !shadowHits.isEmpty
                }
            }
            return
        }

        pendingTask = Task { [weak self, instantRecall, searchIndexService] in
            let hits = await Self.appSearchFallbackHits(
                queryText: queryText,
                originId: originId,
                instantRecall: instantRecall,
                searchIndexService: searchIndexService
            )

            // Re-enter MainActor for the published mutation. Drop the result
            // entirely if the task was cancelled or the originating snapshot
            // belongs to a stale composer.
            await MainActor.run {
                guard let self else { return }
                guard !Task.isCancelled else { return }
                self.lastErrorMessage = nil
                self.currentResults = hits
                self.isPanelVisible = !hits.isEmpty
            }
        }
    }

    // MARK: - Panel visibility

    /// Open the contextual-shadows panel. No-op when V0 flag is OFF so a
    /// stray binding can never surface the panel in production.
    func openPanel() {
        guard isEnabled else { return }
        isPanelVisible = true
    }

    /// Close the panel and clear `currentResults` (memory hygiene per plan
    /// §8.7 — closing the panel must release its result snapshot).
    func closePanel() {
        isPanelVisible = false
        currentResults = []
        lastErrorMessage = nil
    }

    private func clearResults() {
        isPanelVisible = false
        currentResults = []
        lastErrorMessage = nil
    }

    // MARK: - Conversion

    /// Convert raw `InstantRecallResult` values to `RecallHit`. Kept as a
    /// `nonisolated static` so it can be invoked from either actor side
    /// without a hop. Filters out the originating note/chat to avoid
    /// suggesting the very note the user is composing into.
    nonisolated static func convert(
        raw: [InstantRecallResult],
        resultKind: RecallContextKind,
        originId: UUID
    ) -> [RecallHit] {
        let originString = originId.uuidString
        return raw.compactMap { result -> RecallHit? in
            guard result.id != originString else { return nil }
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
        let originString = originId.uuidString
        return raw.compactMap { hit -> RecallHit? in
            guard hit.id != originString else { return nil }
            return RecallHit(
                id: hit.id,
                title: hit.title,
                snippet: hit.snippet,
                kind: recallKind(for: hit.domain),
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
        let originString = originId.uuidString
        return raw.enumerated().compactMap { index, result -> RecallHit? in
            guard result.pageId != originString else { return nil }
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
        originId: UUID,
        instantRecall: InstantRecallService,
        searchIndexService: SearchIndexService?
    ) async -> [RecallHit] {
        if let searchIndexService {
            let started = Date()
            do {
                let results = try await searchIndexService.searchAsync(
                    query: queryText,
                    limit: Self.defaultTopK
                )
                let latencyMs = Date().timeIntervalSince(started) * 1000
                let trace = SearchIndexService.vaultRecallTrace(
                    query: queryText,
                    limit: Self.defaultTopK,
                    results: results
                )
                VaultRecallBridge.recordProductionTrace(trace, latencyMs: latencyMs)

                let hits = Self.convert(raw: results, originId: originId)
                if !hits.isEmpty {
                    return hits
                }
            } catch {
                log.warning(
                    "Contextual Shadows vault-search fallback failed: \(String(describing: error), privacy: .public)"
                )
            }
        }

        // searchAsync internally hops to a detached utility task for the
        // FFI call. We await its result here; the await suspension is
        // cancellation-aware so a cancelled task short-circuits in the caller.
        let raw = await instantRecall.searchAsync(
            query: queryText,
            topK: Self.defaultTopK
        )
        return Self.convert(
            raw: raw,
            resultKind: .note,
            originId: originId
        )
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

    nonisolated private static func shadowDomains(for kind: RecallContextKind) -> (first: ShadowDomain, second: ShadowDomain) {
        switch kind {
        case .note:
            return (.notes, .chats)
        case .chat:
            return (.chats, .notes)
        }
    }

    nonisolated private static func recallKind(for domain: ShadowDomain) -> RecallContextKind {
        switch domain {
        case .notes:
            return .note
        case .chats:
            return .chat
        }
    }
}
