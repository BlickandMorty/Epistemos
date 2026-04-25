import Foundation
import OSLog

// MARK: - ContextualShadowsState
// Patch 7 / AMBIENT_RECALL_WIRING_PLAN.md §5 — V0 ambient-recall surface state.
// Gated behind `EPISTEMOS_AMBIENT_RECALL_V0`. Owns the latest top-K recall hit
// list, panel visibility, and the in-flight `Task` so a fresh keystroke can
// cancel the previous query before launching a new one.
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

        init(id: String, title: String, snippet: String, kind: RecallContextKind, similarity: Float) {
            self.id = id
            self.title = title
            self.snippet = snippet
            self.kind = kind
            self.similarity = similarity
        }
    }

    // MARK: - Constants

    /// Minimum query length per AMBIENT_RECALL_WIRING_PLAN R3 — avoids
    /// recall noise on quick acks ("ok", "hi") in the chat composer.
    static let minimumQueryLength: Int = 6

    /// Default top-K shown in each tab. Plan §2.5 — top-5 related notes.
    static let defaultTopK: Int = 5

    // MARK: - Published state

    /// Top-K results from the most recently completed recall query.
    var currentResults: [RecallHit] = []

    /// Whether the lightweight slide-in panel is currently visible.
    var isPanelVisible: Bool = false

    /// In-flight recall task — held so a fresh keystroke can cancel and
    /// supersede the previous query before launching a new one.
    var pendingTask: Task<Void, Never>?

    /// True only when the V0 flag is set on the running process. UI surfaces
    /// must hide themselves entirely when false.
    var isEnabled: Bool {
        ProcessInfo.processInfo.environment["EPISTEMOS_AMBIENT_RECALL_V0"] == "1"
    }

    // MARK: - Internals

    nonisolated private static let log = Logger(
        subsystem: "com.epistemos",
        category: "ContextualShadowsState"
    )

    init() {}

    // MARK: - Recall request

    /// Schedule an off-MainActor recall query for the supplied snapshot.
    /// Cancels any in-flight task before launching a new one (backpressure
    /// per plan §7 — never queue, always supersede).
    ///
    /// The encoder + HNSW search executes on `Task.detached(priority: .utility)`
    /// via `InstantRecallService.searchAsync`. Only the final assignment to
    /// `currentResults` runs on @MainActor.
    func requestRecall(
        snapshot: RecallContextSnapshot,
        instantRecall: InstantRecallService
    ) {
        // Flag-gated: when V0 is OFF, do nothing — no work scheduled, no
        // results mutated. UI guards on `isEnabled` separately so this is a
        // belt-and-braces guarantee.
        guard isEnabled else { return }

        // Minimum query length keeps the chat composer quiet during quick
        // acks; the note composer also benefits from skipping very short
        // partial words.
        guard snapshot.text.count >= Self.minimumQueryLength else { return }

        // Cancel the previous in-flight task before launching a new one.
        // The detached task checks `Task.isCancelled` inside the MainActor
        // hop so a superseded query never publishes stale results.
        pendingTask?.cancel()

        let originId = snapshot.originId
        let kind = snapshot.kind
        let queryText = snapshot.text

        pendingTask = Task { [weak self, weak instantRecall] in
            guard let instantRecall else { return }

            // searchAsync internally hops to a detached utility task for the
            // FFI call. We await its result here; the await suspension is
            // cancellation-aware so a cancelled task short-circuits below.
            let raw = await instantRecall.searchAsync(
                query: queryText,
                topK: Self.defaultTopK
            )

            // Re-enter MainActor for the published mutation. Drop the result
            // entirely if the task was cancelled or the originating snapshot
            // belongs to a stale composer.
            await MainActor.run {
                guard let self else { return }
                guard !Task.isCancelled else { return }
                let hits = Self.convert(
                    raw: raw,
                    kind: kind,
                    originId: originId
                )
                self.currentResults = hits
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
    }

    // MARK: - Conversion

    /// Convert raw `InstantRecallResult` values to `RecallHit`. Kept as a
    /// `nonisolated static` so it can be invoked from either actor side
    /// without a hop. Filters out the originating note/chat to avoid
    /// suggesting the very note the user is composing into.
    nonisolated static func convert(
        raw: [InstantRecallResult],
        kind: RecallContextKind,
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
                kind: kind,
                similarity: Float(result.score)
            )
        }
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
}
