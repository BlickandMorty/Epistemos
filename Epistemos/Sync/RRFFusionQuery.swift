import Foundation
import GRDB

// MARK: - RRFFusionQuery — load-bearing single-SQL Reciprocal Rank Fusion
//
// RRF Phase 2 per `docs/RRF_FUSION_DESIGN.md` + `docs/RRF_FUSION_PROMPT.md`.
//
// Fuses three FTS5 sources sharing the `SearchIndexService.dbPool`
// (audit gap F8 close-out):
//
//   1. `page_search`      — page-level prose, BM25-weighted (5.0 / 1.0 / 2.0)
//   2. `block_search`     — block-level prose, BM25 default
//   3. `readable_blocks_fts` — universal artifact projection (Documents,
//                              Raw Thoughts, Code, Source, Output)
//
// Per the user mission brief settled architectural decisions:
//   - SINGLE SQL query, no Swift-side merging
//   - k=60 source-of-truth: `epistemos-shadow/src/backend/rrf.rs:22`
//     (`RRF_K_DEFAULT`); Swift mirror is the one constant below
//   - per-source LIMIT 200 BEFORE the union to bound work
//   - GROUP BY entity_id rollup with weighted reciprocal-rank sum
//   - tie-breakers: fused_score DESC, updated_at DESC, entity_id ASC
//   - recency boost: `fused_score * exp(-ln(2) * age_days / halfLifeDays)`
//     (`exp()` is built-in to SQLite ≥3.35; we ship 3.45+ via GRDB 7.10)
//   - additive behind `EPISTEMOS_RRF_FUSION_V1` flag
//
// bm25 sign reminder: FTS5's `bm25()` returns negative scores in
// `[-inf, 0]` — LOWER is better. Hence `ROW_NUMBER() OVER
// (ORDER BY bm25(table) ASC)` assigns rank 1 to the best hit.
// Asserted by `RRFFusionQueryTests.bm25SignAssumptionHolds`.

// MARK: - Phase 6 metrics (observability)

/// In-memory observability for `SearchIndexService.fusedSearch` /
/// `fusedSearchAsync`. Records per-call latency + per-source hit
/// counts in a fixed-size ring buffer. Thread-safe via NSLock —
/// callable from any actor context (the RRF search methods are
/// `nonisolated`, so this can't be `@MainActor`-bound).
///
/// The Settings → "Search Fusion Health" row reads `snapshot()` on
/// view appearance and refreshes when metrics change. p95 is computed
/// lazily from the sample buffer at snapshot time.
nonisolated public final class SearchFusionMetrics: @unchecked Sendable {
    public static let shared = SearchFusionMetrics()
    public static let didChangeNotification = Notification.Name(
        "epistemos.searchFusionMetrics.didChange"
    )

    /// Sample buffer cap. 200 samples × 200 bytes ≈ 40 KB peak.
    /// Bounded so that long-running sessions do not balloon memory.
    public static let bufferCap = 200

    private let lock = NSLock()
    private var samples: [Double] = []
    private var lastLatencyMs: Double = 0
    private var lastQueryAt: Date?
    private var totalQueries: UInt64 = 0
    private var hitsBySource: [String: Int] = [:]
    private var lastContractSufficientCount: Int = 0
    private var lastHighConfidenceCount: Int = 0
    private var lastMediumConfidenceCount: Int = 0
    private var lastLowConfidenceCount: Int = 0
    private var lastTopScoreMargin: Double?
    private var lastExactEscalationRequired = false
    private var lastExactEscalationReasons: [String] = []
    private var lastErrorDescription: String?
    private var lastErrorAt: Date?

    private init() {}

    /// Record a successful fused search. Called from
    /// `SearchIndexService.fusedSearch` and `fusedSearchAsync`.
    public func record(latencyMs: Double, query: String = "", results: [FusedResult]) {
        lock.lock()
        samples.append(latencyMs)
        if samples.count > Self.bufferCap {
            samples.removeFirst(samples.count - Self.bufferCap)
        }
        lastLatencyMs = latencyMs
        lastQueryAt = Date()
        totalQueries &+= 1
        var hits: [String: Int] = [:]
        var contractSufficientCount = 0
        var highConfidenceCount = 0
        var mediumConfidenceCount = 0
        var lowConfidenceCount = 0
        for r in results {
            hits[r.entityKind, default: 0] += 1
            if r.isContractSufficient {
                contractSufficientCount += 1
            }
            switch r.confidenceBand {
            case .high:
                highConfidenceCount += 1
            case .medium:
                mediumConfidenceCount += 1
            case .low:
                lowConfidenceCount += 1
            }
        }
        hitsBySource = hits
        lastContractSufficientCount = contractSufficientCount
        lastHighConfidenceCount = highConfidenceCount
        lastMediumConfidenceCount = mediumConfidenceCount
        lastLowConfidenceCount = lowConfidenceCount
        lastTopScoreMargin = RRFFusionQuery.topScoreMargin(results)
        lastExactEscalationReasons = RRFFusionQuery.exactEscalationReasons(
            query: query,
            results: results
        )
        lastExactEscalationRequired = !lastExactEscalationReasons.isEmpty
        lastErrorDescription = nil
        lock.unlock()
        notifyDidChange()
    }

    /// Record an error from the fused path so the health row can
    /// surface it. Latency is unknown; sample buffer is not appended.
    public func recordError(_ error: Error) {
        lock.lock()
        lastErrorDescription = String(describing: error)
        lastErrorAt = Date()
        lock.unlock()
        notifyDidChange()
    }

    /// Atomic read of every metric for view rendering.
    public func snapshot() -> Snapshot {
        lock.lock(); defer { lock.unlock() }
        return Snapshot(
            isFlagEnabled:        RRFFusionFlags.isEnabled,
            lastQueryAt:          lastQueryAt,
            lastLatencyMs:        lastLatencyMs,
            p95LatencyMs:         Self.percentile(samples, 0.95),
            sampleCount:          samples.count,
            totalQueries:         totalQueries,
            hitsBySource:         hitsBySource,
            contractSufficientCount: lastContractSufficientCount,
            highConfidenceCount:     lastHighConfidenceCount,
            mediumConfidenceCount:   lastMediumConfidenceCount,
            lowConfidenceCount:      lastLowConfidenceCount,
            topScoreMargin:          lastTopScoreMargin,
            exactEscalationRequired: lastExactEscalationRequired,
            exactEscalationReasons:  lastExactEscalationReasons,
            vaultContextContractSchema: "vault_context_contract_2026_05_17",
            exactEscalationTargetLimit: 5,
            exactEscalationSnippetCharLimit: 240,
            exactEscalationQueryCharLimit: 160,
            lastErrorDescription: lastErrorDescription,
            lastErrorAt:          lastErrorAt
        )
    }

    /// Reset the metrics. Test-only convenience.
    public func reset() {
        lock.lock()
        samples.removeAll(keepingCapacity: true)
        lastLatencyMs = 0
        lastQueryAt = nil
        totalQueries = 0
        hitsBySource.removeAll(keepingCapacity: true)
        lastContractSufficientCount = 0
        lastHighConfidenceCount = 0
        lastMediumConfidenceCount = 0
        lastLowConfidenceCount = 0
        lastTopScoreMargin = nil
        lastExactEscalationRequired = false
        lastExactEscalationReasons = []
        lastErrorDescription = nil
        lastErrorAt = nil
        lock.unlock()
        notifyDidChange()
    }

    private func notifyDidChange() {
        NotificationCenter.default.post(
            name: Self.didChangeNotification,
            object: self
        )
    }

    public struct Snapshot: Sendable {
        public let isFlagEnabled: Bool
        public let lastQueryAt: Date?
        public let lastLatencyMs: Double
        public let p95LatencyMs: Double
        public let sampleCount: Int
        public let totalQueries: UInt64
        public let hitsBySource: [String: Int]
        public let contractSufficientCount: Int
        public let highConfidenceCount: Int
        public let mediumConfidenceCount: Int
        public let lowConfidenceCount: Int
        public let topScoreMargin: Double?
        public let exactEscalationRequired: Bool
        public let exactEscalationReasons: [String]
        public let vaultContextContractSchema: String
        public let exactEscalationTargetLimit: Int
        public let exactEscalationSnippetCharLimit: Int
        public let exactEscalationQueryCharLimit: Int
        public let lastErrorDescription: String?
        public let lastErrorAt: Date?
    }

    /// Sort-and-pick percentile. Returns 0 on empty input.
    nonisolated private static func percentile(_ values: [Double], _ p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let idx = max(0, min(sorted.count - 1, Int((p * Double(sorted.count)).rounded(.up)) - 1))
        return sorted[idx]
    }
}

// MARK: - Feature flag

/// `EPISTEMOS_RRF_FUSION_V1` env-flag gate. Mirrors the existing
/// pattern (`EPISTEMOS_RAW_THOUGHTS_V0`, `EPISTEMOS_AMBIENT_RECALL_V0`).
/// Phase 4 wiring sites read this once at the call site to decide
/// between the fused path and the legacy per-index search path.
nonisolated public enum RRFFusionFlags {
    /// `true` when the env-var `EPISTEMOS_RRF_FUSION_V1` is set to `1`.
    /// Default OFF in MAS / signed builds; default ON in dev (set by
    /// the developer's `.envrc` / xcscheme env block).
    public static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["EPISTEMOS_RRF_FUSION_V1"] == "1"
    }
}

// MARK: - K_RRF source-of-truth (single Swift constant)

/// RRF Phase-3 fusion constants. The `K_RRF` constant is the only
/// place `60.0` appears in Swift source — a parity test in
/// `RRFFusionQueryTests` asserts it equals
/// `epistemos-shadow::backend::rrf::RRF_K_DEFAULT`.
///
/// SOURCE OF TRUTH: `epistemos-shadow/src/backend/rrf.rs:22`
/// `pub const RRF_K_DEFAULT: usize = 60;`
nonisolated public enum Phase3FusionConsts {
    /// Reciprocal Rank Fusion smoothing constant. The empirically
    /// validated default from Cormack/Clarke/Büttcher SIGIR 2009.
    /// Higher values smooth the contribution of top-ranked items;
    /// lower values reward consensus more aggressively. DO NOT
    /// change without validating against the test corpus.
    public static let K_RRF: Double = 60.0

    /// Natural log of 2.0 for true half-life decay in SQLite SQL.
    /// Bound as a parameter instead of calling `ln()` so the query
    /// only depends on the `exp()` math function already required by
    /// the fusion path.
    public static let RECENCY_LN_2: Double = 0.6931471805599453
}

// MARK: - FusionWeights

/// Tunable knobs for the fusion query. Defaults match the user
/// mission brief; production callers usually pass `.default`. Custom
/// weights let surface-specific callers (e.g. Halo's "Vault" tab vs
/// the Document editor) tilt toward their preferred source.
nonisolated public struct FusionWeights: Sendable, Hashable {
    /// Multiplier on the page-level prose source contribution.
    /// `1.0` = parity with the other sources.
    public var pageWeight: Double
    /// Multiplier on the block-level prose source contribution.
    public var blockWeight: Double
    /// Multiplier on the universal `readable_blocks` projection.
    /// Bumping this slightly is reasonable when the call site
    /// expects Documents / RawThoughts / Code to dominate (e.g.
    /// the Epdoc Slash menu).
    public var universalWeight: Double
    /// Recency exponential-decay half-life in days. Score is multiplied
    /// by `exp(-ln(2) * age_days / halfLifeDays)`. Default 30 keeps a
    /// 30-day-old doc at half score, 90-day-old at 12.5%, 365-day-old
    /// at ~0.02%.
    public var halfLifeDays: Double
    /// Final result LIMIT applied AFTER fusion + tie-break sort.
    public var maxResults: Int
    /// Per-source LIMIT applied BEFORE the union. Bounds the work
    /// the rollup has to chew through — without this a query with
    /// 50k matching pages would force a 50k-row aggregation.
    public var perSourceLimit: Int

    public init(
        pageWeight: Double = 1.0,
        blockWeight: Double = 1.0,
        universalWeight: Double = 1.0,
        halfLifeDays: Double = 30.0,
        maxResults: Int = 50,
        perSourceLimit: Int = 200
    ) {
        self.pageWeight = pageWeight
        self.blockWeight = blockWeight
        self.universalWeight = universalWeight
        self.halfLifeDays = halfLifeDays
        self.maxResults = maxResults
        self.perSourceLimit = perSourceLimit
    }

    /// Settled defaults from the design doc.
    public static let `default` = FusionWeights()
}

// MARK: - FusedResult

nonisolated public enum FusedResultConfidenceBand: String, Sendable, Hashable {
    case low
    case medium
    case high
}

/// One row of the fused result set. Fields chosen to support both
/// "open the doc" UI flows (`parentDocID`, `entityKind`) AND
/// "scroll to the matching block" affordances (`snippetBlockID`).
nonisolated public struct FusedResult: Sendable, Hashable {
    /// Stable entity id — for page/readable hits this equals
    /// `parentDocID`; for block hits this is the parent doc the
    /// block rolls up to.
    public let entityID: String
    /// Coarse kind discriminator from the source CTE
    /// (`"page"`, `"block"`, or one of the `ArtifactKind`
    /// snake_case strings for readable hits).
    public let entityKind: String
    /// Best human-readable title or title path surfaced by the
    /// contributing source. Used for provenance and exact-escalation
    /// target hints; nil only when the backing source has no title.
    public let displayTitle: String?
    /// Parent doc id — the artifact the user clicks into. Equals
    /// `entityID` when the entity itself IS a doc; equals the
    /// owning page id for legacy block hits.
    public let parentDocID: String
    /// Final fused score AFTER the recency boost. Higher is
    /// better. Tie-broken by `updatedAtUnix` then `entityID`.
    public let fusedScore: Double
    /// The lowest (best) per-source rank that contributed to this
    /// entity. Surfaces the "consensus winner" semantic — an
    /// entity at rank 1 in any source has `bestSourceRank == 1`.
    public let bestSourceRank: Int64
    /// Block id of the best-rank block within the entity (when the
    /// best source was a block-level hit). UI uses this to scroll
    /// to the relevant block on click. nil for page-level hits.
    public let snippetBlockID: String?
    /// FTS5-projected snippet from the best-rank source for this
    /// entity, with `<b>...</b>` highlight markup and `…` ellipsis
    /// markers around the matched terms. Phase 4 wiring sites use
    /// this for UI display without re-querying. nil only when the
    /// FTS5 module returned an empty snippet (e.g. matched on a
    /// column the snippet helper isn't projecting).
    public let snippet: String?
    /// Last-modified Unix timestamp of the entity. Drives the
    /// recency boost. nil only when no source supplied a timestamp
    /// (legacy block_search rows whose parent page is missing).
    public let updatedAtUnix: Double?
    /// Human-readable provenance labels explaining why this result
    /// was selected. These are intentionally short so note UIs can
    /// render them as provenance chips without re-running search.
    public let matchReasons: [String]
    /// Number of independent FTS projections that contributed to this
    /// fused row: page, block, readable-block. This is evidence breadth,
    /// not a replacement for answer-time citation.
    public let sourceHitCount: Int
    /// Coarse confidence for callers enforcing the Vault Context
    /// Contract. Low-confidence fused rows should not be used as
    /// asserted vault grounding without broadening or asking.
    public let confidenceBand: FusedResultConfidenceBand

    public var provenanceSummary: String {
        matchReasons.joined(separator: ", ")
    }

    public var isContractSufficient: Bool {
        confidenceBand != .low && hasVisibleEvidenceReason && hasVisibleEvidenceSurface
    }

    public var hasVisibleEvidenceReason: Bool {
        matchReasons.contains { reason in
            !reason
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveContains("source rank")
        }
    }

    public var hasVisibleEvidenceSurface: Bool {
        if let displayTitle,
           !displayTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        if let snippet,
           !snippet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        return false
    }

    public init(
        entityID: String,
        entityKind: String,
        displayTitle: String? = nil,
        parentDocID: String,
        fusedScore: Double,
        bestSourceRank: Int64,
        snippetBlockID: String?,
        snippet: String?,
        updatedAtUnix: Double?,
        matchReasons: [String] = [],
        sourceHitCount: Int = 1,
        confidenceBand: FusedResultConfidenceBand = .medium
    ) {
        self.entityID = entityID
        self.entityKind = entityKind
        self.displayTitle = displayTitle
        self.parentDocID = parentDocID
        self.fusedScore = fusedScore
        self.bestSourceRank = bestSourceRank
        self.snippetBlockID = snippetBlockID
        self.snippet = snippet
        self.updatedAtUnix = updatedAtUnix
        self.matchReasons = matchReasons
        self.sourceHitCount = sourceHitCount
        self.confidenceBand = confidenceBand
    }
}

// MARK: - RRFFusionQuery (SQL builder + arg binder)

/// Pure SQL builder + argument binder. Stateless — every call
/// produces an identical (idempotent) query string parameterised
/// by `:query` / `:k` / `:w_page` / `:w_block` / `:w_universal` /
/// `:per_source_limit` / `:half_life_days` / `:recency_ln_2` /
/// `:now_unix` / `:max_results`.
///
/// `SearchIndexService.fusedSearch` (Phase 3) wraps this; tests
/// (Phase 5) bind the parameters directly against a `:memory:`
/// pool with a fixture corpus.
nonisolated public enum RRFFusionQuery {
    public static let defaultExactEscalationMarginFloor = 0.02

    public static func topScoreMargin(_ results: [FusedResult]) -> Double? {
        guard results.count >= 2 else { return nil }
        let ranked = results.enumerated().sorted { lhs, rhs in
            let lhsScore = finiteScore(lhs.element.fusedScore)
            let rhsScore = finiteScore(rhs.element.fusedScore)
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            if lhs.element.bestSourceRank != rhs.element.bestSourceRank {
                return lhs.element.bestSourceRank < rhs.element.bestSourceRank
            }
            return lhs.offset < rhs.offset
        }
        let top = finiteScore(ranked[0].element.fusedScore)
        let runnerUp = finiteScore(ranked[1].element.fusedScore)
        return max(0, top - runnerUp)
    }

    public static func exactEscalationReasons(
        query: String,
        results: [FusedResult],
        minimumTopScoreMargin: Double = 0.02
    ) -> [String] {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ["empty_query"]
        }
        guard !results.isEmpty else {
            return ["no_results"]
        }

        var reasons: [String] = []
        let top = rankedForContract(results).first
        if results.allSatisfy({ !$0.isContractSufficient }) {
            reasons.append("no_contract_sufficient_results")
        }
        if top?.confidenceBand == .low {
            reasons.append("top_hit_low_confidence")
        }
        if let top,
           (!top.hasVisibleEvidenceReason || !top.hasVisibleEvidenceSurface) {
            reasons.append("top_hit_evidence_hidden")
        }
        if let margin = topScoreMargin(results),
           margin < max(0, minimumTopScoreMargin) {
            reasons.append("low_top_score_margin")
        }
        return reasons
    }

    private static func finiteScore(_ score: Double) -> Double {
        guard score.isFinite else { return 0 }
        return max(0, score)
    }

    private static func rankedForContract(_ results: [FusedResult]) -> [FusedResult] {
        results.enumerated()
            .sorted { lhs, rhs in
                let lhsScore = finiteScore(lhs.element.fusedScore)
                let rhsScore = finiteScore(rhs.element.fusedScore)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }
                if lhs.element.bestSourceRank != rhs.element.bestSourceRank {
                    return lhs.element.bestSourceRank < rhs.element.bestSourceRank
                }
                return lhs.offset < rhs.offset
            }
            .map { $0.element }
    }

    /// The single-statement SQL query. Built once + cached at
    /// call-site if the caller wants. Composes 3 per-source CTEs +
    /// UNION ALL + GROUP BY rollup with weighted reciprocal-rank
    /// sum + recency exponential decay + deterministic tie-break.
    ///
    /// EXPLAIN QUERY PLAN over this MUST show `VIRTUAL TABLE INDEX
    /// N:M<col>` for each of the three FTS sources — proving FTS5
    /// MATCH was accelerated. The bare `SCAN` token in SQLite's plan
    /// output is NOT the regression we care about: SQLite always
    /// prints `SCAN tablename VIRTUAL TABLE` for virtual-table row
    /// visits, even when the FTS5 module accepted the constraint.
    /// The discriminator is the suffix — `INDEX 0:M2` (good, MATCH on
    /// column 2) versus `INDEX 0:` (bad, full virtual-table scan).
    /// Asserted by `RRFFusionQueryTests.queryPlanUsesFTS5IndexNotScan`.
    public static let sql: String = """
        WITH
          page_hits AS (
            SELECT
              indexed_pages.id        AS entity_id,
              indexed_pages.id        AS parent_doc_id,
              'page'                  AS entity_kind,
              indexed_pages.title     AS display_title,
              'page'                  AS source,
              NULL                    AS snippet_block_id,
              snippet(page_search, 1, '<b>', '</b>', '…', 32) AS snippet_text,
              indexed_pages.updatedAt AS updated_at_unix,
              ROW_NUMBER() OVER (ORDER BY bm25(page_search) ASC) AS rnk
            FROM page_search
            JOIN indexed_pages ON indexed_pages.rowid = page_search.rowid
            WHERE page_search MATCH :query
            LIMIT :per_source_limit
          ),
          block_hits AS (
            SELECT
              indexed_blocks.page_id  AS entity_id,
              indexed_blocks.page_id  AS parent_doc_id,
              'block'                 AS entity_kind,
              (SELECT title FROM indexed_pages
               WHERE id = indexed_blocks.page_id)
                                      AS display_title,
              'block'                 AS source,
              indexed_blocks.block_id AS snippet_block_id,
              snippet(block_search, 0, '<b>', '</b>', '…', 32) AS snippet_text,
              (SELECT updatedAt FROM indexed_pages
               WHERE id = indexed_blocks.page_id)
                                      AS updated_at_unix,
              ROW_NUMBER() OVER (ORDER BY bm25(block_search) ASC) AS rnk
            FROM block_search
            JOIN indexed_blocks ON indexed_blocks.rowid = block_search.rowid
            WHERE block_search MATCH :query
            LIMIT :per_source_limit
          ),
          readable_hits AS (
            SELECT
              readable_blocks.artifact_id    AS entity_id,
              readable_blocks.artifact_id    AS parent_doc_id,
              readable_blocks.artifact_kind  AS entity_kind,
              readable_blocks.title_path     AS display_title,
              'readable_block'               AS source,
              readable_blocks.block_id       AS snippet_block_id,
              snippet(readable_blocks_fts, 0, '<b>', '</b>', '…', 32) AS snippet_text,
              CAST(strftime('%s', readable_blocks.updated_at) AS REAL)
                                             AS updated_at_unix,
              ROW_NUMBER() OVER (ORDER BY bm25(readable_blocks_fts) ASC) AS rnk
            FROM readable_blocks_fts
            JOIN readable_blocks ON readable_blocks.id = readable_blocks_fts.rowid
            WHERE readable_blocks_fts MATCH :query
            LIMIT :per_source_limit
          ),
          unioned AS (
            SELECT entity_id, parent_doc_id, entity_kind, display_title, source,
                   snippet_block_id, snippet_text, updated_at_unix, rnk
            FROM page_hits
            UNION ALL
            SELECT entity_id, parent_doc_id, entity_kind, display_title, source,
                   snippet_block_id, snippet_text, updated_at_unix, rnk
            FROM block_hits
            UNION ALL
            SELECT entity_id, parent_doc_id, entity_kind, display_title, source,
                   snippet_block_id, snippet_text, updated_at_unix, rnk
            FROM readable_hits
          ),
          rolled_up AS (
            -- SQLite "bare columns in aggregate queries" extension —
            -- when MIN(rnk) selects one row per group, display_title,
            -- snippet_block_id, snippet_text, and entity_kind come from THAT same row.
            -- Documented at https://sqlite.org/lang_select.html#bareagg
            SELECT
              entity_id,
              MAX(parent_doc_id)              AS parent_doc_id,
              entity_kind,
              display_title,
              MAX(updated_at_unix)            AS updated_at_unix,
              snippet_block_id,
              snippet_text,
              MIN(rnk)                        AS best_source_rank,
              MAX(CASE WHEN source = 'page' THEN 1 ELSE 0 END)
                                                AS page_source_hit,
              MAX(CASE WHEN source = 'block' THEN 1 ELSE 0 END)
                                                AS block_source_hit,
              MAX(CASE WHEN source = 'readable_block' THEN 1 ELSE 0 END)
                                                AS readable_block_source_hit,
              SUM(
                CASE source
                  WHEN 'page'           THEN :w_page      / (:k + rnk)
                  WHEN 'block'          THEN :w_block     / (:k + rnk)
                  WHEN 'readable_block' THEN :w_universal / (:k + rnk)
                END
              )                               AS raw_fused_score
            FROM unioned
            GROUP BY entity_id
          )
        SELECT
          entity_id,
          parent_doc_id,
          entity_kind,
          display_title,
          (raw_fused_score *
            CASE WHEN updated_at_unix IS NULL THEN 1.0
                 ELSE exp(
                   -:recency_ln_2
                   * (MAX(:now_unix - updated_at_unix, 0.0) / 86400.0)
                   / MAX(:half_life_days, 0.000001)
                 )
            END
          )                                   AS fused_score,
          best_source_rank,
          snippet_block_id,
          snippet_text,
          updated_at_unix,
          page_source_hit,
          block_source_hit,
          readable_block_source_hit
        FROM rolled_up
        ORDER BY fused_score DESC, updated_at_unix DESC, entity_id ASC
        LIMIT :max_results
        """

    /// Bind the 10 parameters the SQL expects against a query
    /// string + weights + clock. `now` is injectable so tests can
    /// pin a deterministic recency boost.
    public static func bindArguments(
        query: String,
        weights: FusionWeights = .default,
        now: Date = Date()
    ) -> StatementArguments {
        let nowUnix = now.timeIntervalSince1970
        return [
            "query":             query,
            "k":                 Phase3FusionConsts.K_RRF,
            "w_page":            weights.pageWeight,
            "w_block":           weights.blockWeight,
            "w_universal":       weights.universalWeight,
            "per_source_limit":  weights.perSourceLimit,
            "half_life_days":    weights.halfLifeDays,
            "recency_ln_2":      Phase3FusionConsts.RECENCY_LN_2,
            "now_unix":          nowUnix,
            "max_results":       weights.maxResults,
        ]
    }

    /// Execute the fusion query and decode rows into `[FusedResult]`.
    /// The actual `SearchIndexService.fusedSearch` (Phase 3) wraps
    /// this in actor + os_signpost ceremony; tests call this
    /// helper directly.
    public static func execute(
        query: String,
        weights: FusionWeights = .default,
        now: Date = Date(),
        in db: Database
    ) throws -> [FusedResult] {
        let rows = try Row.fetchAll(
            db,
            sql: sql,
            arguments: bindArguments(query: query, weights: weights, now: now)
        )
        return rows.map { row in
            let fusedScore: Double = row["fused_score"]
            let bestSourceRank: Int64 = row["best_source_rank"]
            let pageSourceHit: Int64 = row["page_source_hit"]
            let blockSourceHit: Int64 = row["block_source_hit"]
            let readableBlockSourceHit: Int64 = row["readable_block_source_hit"]
            let sourceHitCount = Self.sourceHitCount(
                pageSourceHit: pageSourceHit,
                blockSourceHit: blockSourceHit,
                readableBlockSourceHit: readableBlockSourceHit
            )
            return FusedResult(
                entityID:        row["entity_id"],
                entityKind:      row["entity_kind"],
                displayTitle:    row["display_title"],
                parentDocID:     row["parent_doc_id"],
                fusedScore:      fusedScore,
                bestSourceRank:  bestSourceRank,
                snippetBlockID:  row["snippet_block_id"],
                snippet:         row["snippet_text"],
                updatedAtUnix:   row["updated_at_unix"],
                matchReasons:    matchReasons(
                    pageSourceHit: pageSourceHit,
                    blockSourceHit: blockSourceHit,
                    readableBlockSourceHit: readableBlockSourceHit,
                    bestSourceRank: bestSourceRank,
                    updatedAtUnix: row["updated_at_unix"],
                    weights: weights,
                    now: now
                ),
                sourceHitCount: sourceHitCount,
                confidenceBand: Self.confidenceBand(
                    sourceHitCount: sourceHitCount,
                    bestSourceRank: bestSourceRank,
                    fusedScore: fusedScore
                )
            )
        }
    }

    private static func matchReasons(
        pageSourceHit: Int64,
        blockSourceHit: Int64,
        readableBlockSourceHit: Int64,
        bestSourceRank: Int64,
        updatedAtUnix: Double?,
        weights: FusionWeights,
        now: Date
    ) -> [String] {
        var reasons: [String] = []
        if pageSourceHit > 0 {
            reasons.append("Page match")
        }
        if blockSourceHit > 0 {
            reasons.append("Block match")
        }
        if readableBlockSourceHit > 0 {
            reasons.append("Readable block match")
        }
        if bestSourceRank > 0 {
            reasons.append("Best source rank #\(bestSourceRank)")
        }
        if let updatedAtUnix {
            let ageDays = max(0, now.timeIntervalSince1970 - updatedAtUnix) / 86_400
            if ageDays <= 1 {
                reasons.append("Updated today")
            } else if ageDays <= weights.halfLifeDays {
                reasons.append("Recency boost")
            }
        }
        return reasons
    }

    private static func sourceHitCount(
        pageSourceHit: Int64,
        blockSourceHit: Int64,
        readableBlockSourceHit: Int64
    ) -> Int {
        [pageSourceHit, blockSourceHit, readableBlockSourceHit]
            .filter { $0 > 0 }
            .count
    }

    private static func confidenceBand(
        sourceHitCount: Int,
        bestSourceRank: Int64,
        fusedScore: Double
    ) -> FusedResultConfidenceBand {
        guard sourceHitCount > 0, bestSourceRank > 0, fusedScore.isFinite else {
            return .low
        }
        if sourceHitCount >= 2 || bestSourceRank <= 3 {
            return .high
        }
        if bestSourceRank <= 20 {
            return .medium
        }
        return .low
    }
}
