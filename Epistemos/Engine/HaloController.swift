import Foundation
import OSLog

// MARK: - HaloController
//
// Wave 8 of the Extended Program Plan
// (cross-ref `ambient/EPISTEMOS_V1_DECISION.md` §"The state machine"
//  + §"The technical stack — locked").
//
// Per the V1 decision §"Concurrency":
//   - HaloController @MainActor @Observable. Owns nothing heavy.
//     Holds matches + state + pendingSearch. All it does is debounce
//     and reflect.
//   - Search service: actor with default cooperative executor. Calls
//     nonisolated UniFFI bindings. Returns plain [ShadowHit].
//
// The performance budget per the V1 decision §"performance budget":
//   - MainActor work per recall update: < 1 ms (hard ceiling 2 ms)
//   - Debounce window: 400 ms (SS-IR accuracy-first; was 200 ms V1 budget)
//   - Query context extraction: < 0.5 ms
//   - End-to-end recall pass: < 25 ms (hard ceiling 40 ms)

/// Abstract search service the controller talks to. Real implementation
/// is `RustShadowSearchService` (W8.3) which wraps the FFI; tests use
/// `MockShadowSearchService` so the state machine is fully covered
/// without spinning up the Rust crate.
public protocol ShadowSearchServicing: Sendable {
    func search(text: String, limit: Int) async -> [ShadowHit]

    /// Same as `search` but surfaces backend failures so the UI can
    /// show "Search backend unavailable" instead of silently treating
    /// a crash as "no results." Default impl wraps `search` and
    /// reports nil error; the production `ShadowSearchService`
    /// overrides to actually catch FFI errors. Per RCA13 P5.
    func searchReportingErrors(
        text: String,
        limit: Int
    ) async -> (hits: [ShadowHit], errorMessage: String?)
}

extension ShadowSearchServicing {
    public func searchReportingErrors(
        text: String,
        limit: Int
    ) async -> (hits: [ShadowHit], errorMessage: String?) {
        let hits = await search(text: text, limit: limit)
        return (hits: hits, errorMessage: nil)
    }
}

/// Telemetry sink so tests can verify the OSSignposter intervals fire
/// without depending on `os.signpost`. Production uses a no-op sink
/// since the real signposts emit through `Sig.storage`.
public protocol HaloTelemetry: Sendable {
    func recordIntervalBegin(_ name: String)
    func recordIntervalEnd(_ name: String)
}

/// No-op telemetry for shipped builds — `Sig.storage` already emits
/// real OSSignposter intervals at the call sites.
public struct NullHaloTelemetry: HaloTelemetry, Sendable {
    public init() {}
    public func recordIntervalBegin(_ name: String) {}
    public func recordIntervalEnd(_ name: String) {}
}

/// The Halo state machine controller. @MainActor + @Observable so
/// SwiftUI bindings can read `state` and `matches` without
/// an actor hop, while the heavy search work happens on the background
/// `ShadowSearchServicing` actor.
@MainActor
@Observable
public final class HaloController {
    typealias GraphProjectionReportProvider = @MainActor (Int) -> GraphEventAuditProjectionReport

    // MARK: - Public state (SwiftUI-bound)

    public private(set) var state: HaloState = .dormant
    public private(set) var matches: [ShadowHit] = []
    private(set) var graphProjectionReport: GraphEventAuditProjectionReport = .empty

    // MARK: - Tunables (V1 decision §"performance budget")

    /// Debounce before issuing a search. SS-IR (owner 2026-06-20): raised 200 → 400 ms for
    /// ACCURACY-FIRST recall — the owner wants "slower OK, must be accurate." A longer window
    /// fires the query on more-complete input (fewer wasted partial-word searches) → better hits.
    public let debounceWindowMs: Int
    /// Minimum query length before we even enter `.sensing`.
    public let minQueryChars: Int
    /// Score threshold below which a hit is not surfaced.
    public let scoreThreshold: Float
    /// Stop words that don't count toward `minQueryChars`.
    public let stopWords: Set<String>

    // MARK: - Dependencies

    private let search: any ShadowSearchServicing
    private let telemetry: any HaloTelemetry
    private let graphProjectionReportProvider: GraphProjectionReportProvider
    private static let log = Logger(subsystem: "com.epistemos", category: "Halo")
    private static let graphProjectionReportLimit = 100

    // MARK: - In-flight task

    private var pendingSearch: Task<Void, Never>?
    private var lastQueryContext: String = ""

    public convenience init(
        search: any ShadowSearchServicing,
        telemetry: any HaloTelemetry = NullHaloTelemetry(),
        debounceWindowMs: Int = 400,
        minQueryChars: Int = 3,
        scoreThreshold: Float = 0.2,
        stopWords: Set<String> = ["the", "a", "an", "and", "or", "but", "is", "are"]
    ) {
        self.init(
            search: search,
            telemetry: telemetry,
            debounceWindowMs: debounceWindowMs,
            minQueryChars: minQueryChars,
            scoreThreshold: scoreThreshold,
            stopWords: stopWords,
            graphProjectionReportProvider: { limit in
                GraphEventAuditProjectionService().auditReport(limit: limit)
            }
        )
    }

    init(
        search: any ShadowSearchServicing,
        telemetry: any HaloTelemetry = NullHaloTelemetry(),
        debounceWindowMs: Int = 400,
        minQueryChars: Int = 3,
        scoreThreshold: Float = 0.2,
        stopWords: Set<String> = ["the", "a", "an", "and", "or", "but", "is", "are"],
        graphProjectionReportProvider: @escaping GraphProjectionReportProvider
    ) {
        self.search = search
        self.telemetry = telemetry
        self.debounceWindowMs = debounceWindowMs
        self.minQueryChars = minQueryChars
        self.scoreThreshold = scoreThreshold
        self.stopWords = stopWords
        self.graphProjectionReportProvider = graphProjectionReportProvider
    }

    // MARK: - Editor input

    /// Called from the NSTextView delegate on every text change. Cheap.
    /// Always returns instantly — the heavy work runs in a detached Task.
    public func editorTextDidChange(_ text: String) {
        let queryContext = Self.extractQueryContext(from: text)
        lastQueryContext = queryContext

        guard isMeaningful(queryContext) else {
            clearSearch()
            return
        }

        scheduleSearch(
            queryContext: queryContext,
            keepPanelOpen: state.isPanelOpen
        )
    }

    private func clearSearch() {
        pendingSearch?.cancel()
        pendingSearch = nil
        matches = []
        transition(to: .dormant)
    }

    private func scheduleSearch(
        queryContext: String,
        keepPanelOpen: Bool
    ) {
        // Cancel any in-flight search (cooperative cancellation).
        pendingSearch?.cancel()
        if state == .dormant, !keepPanelOpen {
            transition(to: .sensing)
        }

        let captured = queryContext
        let capturedDebounce = UInt64(debounceWindowMs) * 1_000_000
        let capturedThreshold = scoreThreshold
        pendingSearch = Task { [weak self] in
            guard let self else { return }
            self.telemetry.recordIntervalBegin("halo.search")
            defer { self.telemetry.recordIntervalEnd("halo.search") }

            try? await Task.sleep(nanoseconds: capturedDebounce)
            if Task.isCancelled { return }

            // RCA13 P5: use the error-reporting variant so a backend
            // crash (vault unmounted, FFI handle invalid, bundle
            // missing) surfaces as .errorRecoverable instead of an
            // empty matches list that looks identical to "no hits."
            let outcome = await self.search.searchReportingErrors(
                text: captured,
                // SS-IR accuracy-first: 10 → 16 so the panel surfaces a wider, more complete recall
                // set (the warm RRF/HNSW backend already ranks; more candidates = fewer misses).
                limit: 16
            )
            if Task.isCancelled { return }

            if let message = outcome.errorMessage {
                self.matches = []
                self.transition(to: .errorRecoverable(message))
                return
            }

            let above = outcome.hits.filter {
                $0.domain == .notes && $0.score >= capturedThreshold
            }
            self.matches = above
            if above.isEmpty {
                self.transition(to: keepPanelOpen ? .open(domain: .notes) : .dormant)
            } else if keepPanelOpen {
                self.transition(to: .open(domain: .notes))
            } else {
                self.transition(to: .available(count: above.count))
            }
        }
    }

    /// Editor lost focus or app went inactive. Cancel any pending
    /// search and return to dormant.
    public func editorDidLoseFocus() {
        pendingSearch?.cancel()
        pendingSearch = nil
        lastQueryContext = ""
        matches = []
        transition(to: .dormant)
    }

    // MARK: - User actions

    /// User clicked the Halo glyph. Opens the notes-only recall panel.
    public func openPanel() {
        switch state {
        case .available:
            refreshGraphProjectionReport()
            transition(to: .open(domain: .notes))
        case .errorRecoverable:
            refreshGraphProjectionReport()
        case .dormant, .sensing:
            // SS-IR (owner 2026-06-20): the resting bubble is a LIVE entry point — open a panel
            // even with zero hits (it shows the "no matches yet" empty state) so recall is
            // discoverable instead of a dead affordance.
            refreshGraphProjectionReport()
            transition(to: .open(domain: .notes))
        default:
            return
        }
    }

    /// User pressed Esc / clicked outside / focus returned to editor.
    /// Closes the panel; falls back to `.available` if results are
    /// still present, else `.dormant`.
    public func closePanel() {
        guard state.isPanelOpen else { return }
        if matches.isEmpty {
            transition(to: .dormant)
        } else {
            transition(to: .available(count: matches.count))
        }
    }

    /// User clicked the inline-edit affordance on a note result.
    public func beginEditingNote(id: String) {
        guard case .open = state else { return }
        transition(to: .editingNote(id: id))
    }

    /// Inline edit finished or cancelled. Returns to the notes-only panel.
    public func endNestedAction() {
        switch state {
        case .editingNote:
            transition(to: .open(domain: .notes))
        default:
            break
        }
    }

    /// Backend reported a recoverable error. Surfaces in the Halo so
    /// the user can retry without looking at the console.
    public func reportRecoverableError(_ message: String) {
        transition(to: .errorRecoverable(message))
    }

    func refreshGraphProjectionReport(limit: Int = HaloController.graphProjectionReportLimit) {
        graphProjectionReport = graphProjectionReportProvider(limit)
    }

    // MARK: - State transition

    private func transition(to next: HaloState) {
        if state == next { return }
        Self.log.debug("halo state: \(String(describing: self.state), privacy: .public) → \(String(describing: next), privacy: .public)")
        state = next
    }

    // MARK: - Query context extraction

    /// Pulls the most recent paragraph (or last 256 chars, whichever
    /// is shorter) from the full editor text. The Shadow engine works
    /// best on a paragraph-sized chunk, not the full document.
    public static func extractQueryContext(from text: String) -> String {
        if text.isEmpty { return "" }
        // HC-2/HC-3: bound ALL work to the trailing ~2048 chars instead of scanning the WHOLE
        // document on every keystroke. This runs per-keystroke (before the debounce), and the old
        // `text.range(of: "\n\n", .backwards)` scanned the entire doc when no double-newline was
        // near the end, while `text.count` is itself O(n) — both meant typing lag in a large note.
        // 2048 captures any realistic trailing paragraph (and caps a pathological one, which also
        // bounds the search query); walk back with `limitedBy` so we never do an O(n) count.
        let tailStart = text.index(text.endIndex, offsetBy: -2048, limitedBy: text.startIndex)
            ?? text.startIndex
        let tail = text[tailStart...]
        // Trailing paragraph: split on the last double-newline WITHIN the bounded tail.
        if let lastDouble = tail.range(of: "\n\n", options: .backwards) {
            return String(tail[lastDouble.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // No paragraph break in the tail — use the trailing 256 chars (same fallback as before).
        let contextStart = tail.index(tail.endIndex, offsetBy: -256, limitedBy: tail.startIndex)
            ?? tail.startIndex
        return String(tail[contextStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether the (extracted) query context has enough non-stop-word
    /// content to bother searching. Cheaply gates the debounce.
    private func isMeaningful(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < minQueryChars { return false }
        let tokens = trimmed
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
        let meaningful = tokens.filter { !stopWords.contains($0) && $0.count >= 2 }
        return !meaningful.isEmpty
    }
}
