import Foundation

struct InstantRecallResult: Identifiable, Sendable {
    let id: String
    let text: String
    let score: Double

    var docId: String { id }
}

enum RecallContextKind: String, Sendable {
    case note
    case chat
}

struct RecallContextSnapshot: Sendable, Hashable {
    let text: String
    let kind: RecallContextKind
    let originDocId: String
    let originId: UUID

    init(text: String, kind: RecallContextKind, originId: UUID, originDocId: String? = nil) {
        self.text = text
        self.kind = kind
        self.originId = originId
        self.originDocId = originDocId ?? originId.uuidString
    }
}

@MainActor
@Observable
final class InstantRecallService {
    private(set) var isReady = true
    private(set) var documentCount = 0
    private(set) var lastResults: [InstantRecallResult] = []
    private(set) var lastSearchLatencyMs: Double = 0
    private(set) var searchCount = 0
    private(set) var averageSearchLatencyMs: Double = 0
    private(set) var maxSearchLatencyMs: Double = 0

    private var documents: [String: String] = [:]
    private var initialSnapshotProvider: (() -> [(id: String, text: String)])?
    private var hasHydratedInitialSnapshot = false

    func configureInitialSnapshotProvider(_ provider: @escaping () -> [(id: String, text: String)]) {
        initialSnapshotProvider = provider
        hasHydratedInitialSnapshot = false
    }

    func prewarmForAmbientRecall() {
        hydrateInitialSnapshotIfNeeded()
    }

    func indexNote(noteId: String, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            removeNote(noteId: noteId)
            return
        }
        documents[noteId] = text
        documentCount = documents.count
    }

    func removeNote(noteId: String) {
        documents.removeValue(forKey: noteId)
        documentCount = documents.count
        lastResults.removeAll { $0.docId == noteId }
    }

    func rebuildIndexAsync(notes: [(id: String, text: String)]) async {
        let preparedDocuments = await Task.detached(priority: .utility) {
            Self.makeDocumentMap(notes: notes)
        }.value
        replaceIndex(with: preparedDocuments)
    }

    func replaceIndex(with preparedDocuments: [String: String]) {
        documents = preparedDocuments
        hasHydratedInitialSnapshot = true
        documentCount = documents.count
        lastResults = []
        resetMetrics()
    }

    private nonisolated static func makeDocumentMap(
        notes: [(id: String, text: String)]
    ) -> [String: String] {
        var documents: [String: String] = [:]
        documents.reserveCapacity(notes.count)
        for note in notes {
            let trimmed = note.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                documents[note.id] = note.text
            }
        }
        return documents
    }

    func search(queryText: String, topK: Int = 5) -> [InstantRecallResult] {
        let start = Date()
        let results = searchDocuments(queryText: queryText, topK: topK)
        let elapsed = Date().timeIntervalSince(start) * 1_000
        lastResults = results
        lastSearchLatencyMs = elapsed
        searchCount += 1
        averageSearchLatencyMs += (elapsed - averageSearchLatencyMs) / Double(searchCount)
        maxSearchLatencyMs = max(maxSearchLatencyMs, elapsed)
        return results
    }

    func searchAsync(query: String, topK: Int = 5) async -> [InstantRecallResult] {
        search(queryText: query, topK: topK)
    }

    func clearIndex() {
        documents.removeAll(keepingCapacity: true)
        documentCount = 0
        lastResults = []
        resetMetrics()
    }

    private func hydrateInitialSnapshotIfNeeded() {
        guard !hasHydratedInitialSnapshot else { return }
        hasHydratedInitialSnapshot = true
        guard let snapshot = initialSnapshotProvider?() else { return }
        documents = Dictionary(
            uniqueKeysWithValues: snapshot.compactMap { item in
                let trimmed = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : (item.id, item.text)
            }
        )
        documentCount = documents.count
    }

    private func searchDocuments(queryText: String, topK: Int) -> [InstantRecallResult] {
        hydrateInitialSnapshotIfNeeded()
        let terms = Set(
            queryText
                .lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
                .filter { $0.count > 1 }
        )
        guard !terms.isEmpty, topK > 0 else { return [] }

        return documents.compactMap { id, text -> InstantRecallResult? in
            let lower = text.lowercased()
            let matches = terms.reduce(0) { count, term in
                lower.contains(term) ? count + 1 : count
            }
            guard matches > 0 else { return nil }
            return InstantRecallResult(
                id: id,
                text: text,
                score: Double(matches) / Double(max(terms.count, 1))
            )
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score { return lhs.id < rhs.id }
            return lhs.score > rhs.score
        }
        .prefix(topK)
        .map { $0 }
    }

    private func resetMetrics() {
        lastSearchLatencyMs = 0
        searchCount = 0
        averageSearchLatencyMs = 0
        maxSearchLatencyMs = 0
    }
}
