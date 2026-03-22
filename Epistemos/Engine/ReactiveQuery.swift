import Foundation
import Combine

// MARK: - ReactiveQuery
// Reactive query results with automatic re-evaluation on data changes.
// Uses a single short debounce window to coalesce rapid edits without making
// the UI feel stale.

@MainActor
final class ReactiveQuery {

    private let runtime: QueryRuntime
    private let plan: QueryPlan
    private let dependencies: Set<QueryDependencyKey>
    private var debounceTask: Task<Void, Never>?
    private var lastResult: QueryResult?
    private var cancellables = Set<AnyCancellable>()
    private var continuation: AsyncStream<QueryResult>.Continuation?

    // Backpressure: coalesce rapid invalidations without stacking visible lag
    // on top of upstream mutations.
    private let debounceInterval: Duration = .milliseconds(35)

    init(runtime: QueryRuntime, plan: QueryPlan) {
        self.runtime = runtime
        self.plan = plan
        self.dependencies = plan.dependencies
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
            // Both graph and search-index invalidations are already marshaled
            // onto the main actor at the source, so an extra RunLoop hop only
            // adds avoidable latency on top of the debounce window.
            NotificationCenter.default.publisher(for: .graphStoreDidChange)
                .sink { [weak self] notification in
                    self?.handleInvalidation(notification)
                }
                .store(in: &self.cancellables)

            NotificationCenter.default.publisher(for: .searchIndexDidUpdate)
                .sink { [weak self] notification in
                    self?.handleInvalidation(notification)
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

    func shouldInvalidate(for notification: Notification) -> Bool {
        guard let changedKeys = QueryDependencyKey.from(notification) else {
            return true
        }
        return !dependencies.isDisjoint(with: changedKeys)
    }

    private func handleInvalidation(_ notification: Notification) {
        guard shouldInvalidate(for: notification) else { return }
        reevaluate()
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
