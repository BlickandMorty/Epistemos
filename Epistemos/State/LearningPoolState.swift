import Foundation

// MARK: - LearningPoolState

@MainActor @Observable
final class LearningPoolState {

    // MARK: - Search Mode

    enum SearchMode: String, CaseIterable, Sendable {
        case speed
        case balanced
        case quality

        nonisolated var displayName: String {
            switch self {
            case .speed: "Speed"
            case .balanced: "Balanced"
            case .quality: "Quality"
            }
        }

        nonisolated var maxIterations: Int {
            switch self {
            case .speed: 2
            case .balanced: 6
            case .quality: 25
            }
        }
    }

    // MARK: - Source Toggle

    struct SourceConfig: Sendable {
        var web = true
        var academic = true
        var notes = true
    }

    // MARK: - Search Result

    struct PoolSearchResult: Identifiable, Sendable {
        let id: String
        let query: String
        let answer: String
        let sources: [PoolSource]
        let timestamp: Date
    }

    struct PoolSource: Identifiable, Sendable {
        let id: String
        let title: String
        let url: String?
        let snippet: String
        let sourceType: SourceType

        enum SourceType: String, Sendable {
            case web
            case academic
            case note
        }
    }

    // MARK: - State

    var searchMode: SearchMode = .balanced
    var sourceConfig = SourceConfig()
    var isSearching = false
    var currentQuery = ""
    private(set) var recentSearches: [PoolSearchResult] = []
    private(set) var error: String?

    // MARK: - Actions

    func addResult(_ result: PoolSearchResult) {
        recentSearches.insert(result, at: 0)
        if recentSearches.count > 50 {
            recentSearches = Array(recentSearches.prefix(50))
        }
    }

    func clearHistory() {
        recentSearches.removeAll()
    }

    func setError(_ message: String?) {
        error = message
    }
}
