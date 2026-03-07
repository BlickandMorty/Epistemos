import Foundation
import os

// MARK: - LearningPoolService
// Handles search requests from agents via the message bus.
// Phase 6 scaffold — full Perplexica port (Brave Search, RAG pipeline)
// comes when the Rust learning-pool crate is built.

@MainActor
final class LearningPoolService {
    private let state: LearningPoolState
    private let messageBus: MessageBus
    private var listenerTask: Task<Void, Never>?

    init(state: LearningPoolState, messageBus: MessageBus) {
        self.state = state
        self.messageBus = messageBus
    }

    // MARK: - Start/Stop

    func start() {
        listenerTask?.cancel()
        listenerTask = Task { [weak self] in
            guard let self else { return }
            let stream = await self.messageBus.subscribeAll()
            for await message in stream {
                guard !Task.isCancelled else { break }
                if case .searchRequest(let from, let query) = message {
                    await self.handleSearchRequest(from: from, query: query)
                }
            }
        }
        Log.engine.info("LearningPoolService: started listening for search requests")
    }

    func stop() {
        listenerTask?.cancel()
        listenerTask = nil
    }

    // MARK: - Search

    func search(query: String, from: AgentID) async {
        let searchQuery = SearchQuery(text: query, maxResults: 5, from: from)
        await handleSearchRequest(from: from, query: searchQuery)
    }

    private func handleSearchRequest(from: AgentID, query: SearchQuery) async {
        state.isSearching = true
        state.currentQuery = query.text

        await messageBus.publish(.activityLog(
            from: from,
            action: "search",
            detail: "Learning Pool: \(query.text.prefix(60))"
        ))

        // Placeholder — returns empty results until Brave Search + RAG pipeline is built.
        // The infrastructure is wired: agents can publish searchRequest, this service
        // receives them, and results flow back through searchResult messages.
        let result = LearningPoolState.PoolSearchResult(
            id: UUID().uuidString,
            query: query.text,
            answer: "Learning Pool search for: \(query.text) (full pipeline pending)",
            sources: [],
            timestamp: Date()
        )

        state.addResult(result)
        state.isSearching = false

        // Send results back to the requesting agent
        await messageBus.publish(.searchResult(to: from, results: []))

        Log.engine.debug("LearningPool: processed search from \(from.rawValue): \(query.text.prefix(40))")
    }
}
