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
//   - Debounce window: 200 ms (hard ceiling 250 ms)
//   - Query context extraction: < 0.5 ms
//   - End-to-end recall pass: < 25 ms (hard ceiling 40 ms)

/// Abstract search service the controller talks to. Real implementation
/// is `RustShadowSearchService` (W8.3) which wraps the FFI; tests use
/// `MockShadowSearchService` so the state machine is fully covered
/// without spinning up the Rust crate.
public protocol ShadowSearchServicing: Sendable {
    func search(text: String, domain: ShadowDomain, limit: Int) async -> [ShadowHit]
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
/// SwiftUI bindings can read `state`, `matches`, and `domain` without
/// an actor hop, while the heavy search work happens on the background
/// `ShadowSearchServicing` actor.
@MainActor
@Observable
public final class HaloController {
    typealias GraphProjectionReportProvider = @MainActor (Int) -> GraphEventAuditProjectionReport

    // MARK: - Public state (SwiftUI-bound)

    public private(set) var state: HaloState = .dormant
    public private(set) var matches: [ShadowHit] = []
    public private(set) var domain: ShadowDomain = .notes
    private(set) var graphProjectionReport: GraphEventAuditProjectionReport = .empty

    // MARK: - Tunables (V1 decision §"performance budget")

    /// Debounce before issuing a search. 200 ms per the V1 budget.
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
        debounceWindowMs: Int = 200,
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
        debounceWindowMs: Int = 200,
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
    public func editorTextDidChange(_ text: String, domain: ShadowDomain = .notes) {
        let queryContext = Self.extractQueryContext(from: text)
        lastQueryContext = queryContext
        self.domain = domain

        guard isMeaningful(queryContext) else {
            clearSearch()
            return
        }

        scheduleSearch(
            queryContext: queryContext,
            domain: domain,
            keepPanelOpen: state.isPanelOpen
        )
    }

    /// Called from the Halo panel's segmented domain picker. Reuses the latest
    /// meaningful editor query so switching Notes/Chats is a real search, not
    /// a visual-only control.
    public func selectDomain(_ domain: ShadowDomain) {
        guard self.domain != domain else { return }
        self.domain = domain
        guard isMeaningful(lastQueryContext) else {
            clearSearch()
            return
        }
        scheduleSearch(
            queryContext: lastQueryContext,
            domain: domain,
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
        domain: ShadowDomain,
        keepPanelOpen: Bool
    ) {
        // Cancel any in-flight search (cooperative cancellation).
        pendingSearch?.cancel()
        if state == .dormant, !keepPanelOpen {
            transition(to: .sensing)
        }

        let captured = queryContext
        let capturedDomain = domain
        let capturedDebounce = UInt64(debounceWindowMs) * 1_000_000
        let capturedThreshold = scoreThreshold
        pendingSearch = Task { [weak self] in
            guard let self else { return }
            self.telemetry.recordIntervalBegin("halo.search")
            defer { self.telemetry.recordIntervalEnd("halo.search") }

            try? await Task.sleep(nanoseconds: capturedDebounce)
            if Task.isCancelled { return }

            let hits = await self.search.search(text: captured, domain: capturedDomain, limit: 10)
            if Task.isCancelled { return }

            let above = hits.filter { $0.score >= capturedThreshold }
            self.matches = above
            if above.isEmpty {
                self.transition(to: keepPanelOpen ? .open(domain: capturedDomain) : .dormant)
            } else if keepPanelOpen {
                self.transition(to: .open(domain: capturedDomain))
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

    /// User clicked the Halo glyph. Opens the panel for the current domain.
    public func openPanel() {
        guard case .available = state else { return }
        refreshGraphProjectionReport()
        transition(to: .open(domain: domain))
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

    /// User right-clicked a chat result → "Summarise this".
    public func beginSummarizingChat(id: String) {
        guard case .open = state else { return }
        transition(to: .summarizingChat(id: id))
    }

    /// Inline edit / summarisation finished or cancelled. Returns to
    /// `.open` for the current domain.
    public func endNestedAction() {
        switch state {
        case .editingNote, .summarizingChat:
            transition(to: .open(domain: domain))
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
        // Take the trailing paragraph by splitting on the last
        // double-newline. If none, use the trailing 256 chars.
        if let lastDouble = text.range(of: "\n\n", options: .backwards) {
            let tail = text[lastDouble.upperBound...]
            return String(tail).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if text.count <= 256 {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let start = text.index(text.endIndex, offsetBy: -256)
        return String(text[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
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
