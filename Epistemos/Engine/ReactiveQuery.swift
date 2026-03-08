import Foundation
import Combine

// MARK: - ReactiveQuery
// Reactive query results with automatic re-evaluation on data changes.
// Uses 100ms debounce via Task.sleep to avoid thrashing during rapid edits.

@MainActor
final class ReactiveQuery {

    private let runtime: QueryRuntime
    private let plan: QueryPlan
    private var debounceTask: Task<Void, Never>?
    private var lastResult: QueryResult?
    private var cancellables = Set<AnyCancellable>()
    private var continuation: AsyncStream<QueryResult>.Continuation?

    // Backpressure: coalesce rapid invalidations
    private let debounceInterval: Duration = .milliseconds(100)

    init(runtime: QueryRuntime, plan: QueryPlan) {
        self.runtime = runtime
        self.plan = plan
    }

    /// Create a reactive stream that re-evaluates on data changes.
    func stream() -> AsyncStream<QueryResult> {
        // Clean up any existing stream
        continuation?.finish()
        cancellables.removeAll()

        return AsyncStream { [weak self] continuation in
            guard let self else { continuation.finish(); return }
            self.continuation = continuation

            // Initial evaluation
            let initial = self.runtime.execute(self.plan)
            self.lastResult = initial
            continuation.yield(initial)

            // Subscribe to notifications to trigger re-evaluation.
            // receive(on: RunLoop.main) ensures sink fires on @MainActor
            // regardless of which thread posted the notification.
            NotificationCenter.default.publisher(for: .graphStoreDidChange)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.reevaluate()
                }
                .store(in: &self.cancellables)

            NotificationCenter.default.publisher(for: .searchIndexDidUpdate)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.reevaluate()
                }
                .store(in: &self.cancellables)

            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.cancellables.removeAll()
                    self?.continuation = nil
                }
            }
        }
    }

    /// Execute the plan and yield result (with deduplication + debounce).
    private func reevaluate() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.debounceInterval)
            guard !Task.isCancelled else { return }
            let result = self.runtime.execute(self.plan)
            if !result.isEquivalent(to: self.lastResult) {
                self.lastResult = result
                self.continuation?.yield(result)
            }
        }
    }
}

// MARK: - QueryResult Equivalence

extension QueryResult {
    /// Compare two results for meaningful equality (ignoring execution time).
    func isEquivalent(to other: QueryResult?) -> Bool {
        guard let other else { return false }
        let selfIds = Set(nodes.map(\.id))
        let otherIds = Set(other.nodes.map(\.id))
        return selfIds == otherIds && edges.count == other.edges.count
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let graphStoreDidChange = Notification.Name("graphStoreDidChange")
    static let searchIndexDidUpdate = Notification.Name("searchIndexDidUpdate")
}

// MARK: - Convenience: ReactiveQuery from AST

extension ReactiveQuery {
    /// Create a reactive query from a QueryAST (auto-compiles to plan).
    convenience init(runtime: QueryRuntime, ast: QueryAST) {
        self.init(runtime: runtime, plan: QueryCompiler.compile(ast))
    }

    /// Create a reactive query from a string query (auto-parses and compiles).
    /// Routes ?-prefix to StructuredQueryParser, natural language to QueryParser.
    convenience init?(runtime: QueryRuntime, query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let ast: QueryAST?
        if trimmed.hasPrefix("?") {
            ast = StructuredQueryParser.parse(trimmed)
        } else {
            ast = QueryParser.parseToAST(trimmed)
        }
        guard let ast else { return nil }

        self.init(runtime: runtime, ast: ast)
    }
}
