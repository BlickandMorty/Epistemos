import Foundation

// MARK: - Timeout Utility
//
// Race-two-tasks pattern for wrapping any async operation with a deadline.
// Every operation that can take >50ms should be wrapped with this to prevent
// UI hangs and SIGKILL from the watchdog.

struct TimeoutError: Error, LocalizedError {
    let seconds: Double
    var errorDescription: String? {
        "Operation timed out after \(String(format: "%.1f", seconds))s"
    }
}

/// Wraps an async operation with a timeout. If the operation doesn't complete
/// within `seconds`, throws `TimeoutError` and cancels the operation.
func withTimeout<T: Sendable>(
    seconds: Double,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw TimeoutError(seconds: seconds)
        }
        defer { group.cancelAll() }
        // The first task to complete wins — either the result or the timeout.
        guard let result = try await group.next() else {
            throw TimeoutError(seconds: seconds)
        }
        return result
    }
}

// MARK: - Circuit Breaker Error

/// Thrown when a circuit breaker is open and rejects a call.
struct CircuitBreakerOpenError: Error, LocalizedError {
    let domain: String
    let retryAfter: Date

    var errorDescription: String? {
        let remaining = max(0, retryAfter.timeIntervalSinceNow)
        return "Circuit breaker '\(domain)' is open — retry after \(String(format: "%.1f", remaining))s"
    }
}

// MARK: - Circuit Breaker (Resilience4j-style)
//
// Ring bit buffer for rolling failure rate, multi-probe half-open,
// typed retry metadata, and thermal pause exemption.
//
// Three states:
//   Closed   → calls proceed, failures tracked in ring buffer
//   Open     → calls rejected with retryAfter, auto-transitions to halfOpen
//   HalfOpen → limited probe calls; N consecutive successes → Closed

actor AgentCircuitBreaker {
    enum State: Sendable {
        case closed
        case open(until: Date)
        case halfOpen
    }

    /// Ring bit buffer: true = success, false = failure.
    /// Fixed size — oldest entries are overwritten as the head advances.
    private var ringBuffer: [Bool]
    private var ringHead: Int = 0
    private var ringCount: Int = 0

    private var state: State = .closed

    /// Consecutive successes in half-open state.
    private var halfOpenSuccesses: Int = 0

    let domain: String
    let bufferSize: Int
    let failureRateThreshold: Double
    let resetTimeout: TimeInterval
    /// Number of consecutive successes required in half-open before closing.
    let requiredHalfOpenSuccesses: Int

    init(
        domain: String = "default",
        bufferSize: Int = 10,
        failureRateThreshold: Double = 0.5,
        resetTimeout: TimeInterval = 30.0,
        requiredHalfOpenSuccesses: Int = 3
    ) {
        self.domain = domain
        self.bufferSize = bufferSize
        self.failureRateThreshold = failureRateThreshold
        self.resetTimeout = resetTimeout
        self.requiredHalfOpenSuccesses = requiredHalfOpenSuccesses
        self.ringBuffer = Array(repeating: true, count: bufferSize)
    }

    /// Legacy-compatible initializer (used by AppSupervisor).
    init(failureThreshold: Int, resetTimeout: TimeInterval) {
        self.domain = "legacy"
        self.bufferSize = max(failureThreshold * 2, 6)
        self.failureRateThreshold = Double(failureThreshold) / Double(self.bufferSize)
        self.resetTimeout = resetTimeout
        self.requiredHalfOpenSuccesses = 2
        self.ringBuffer = Array(repeating: true, count: self.bufferSize)
    }

    // MARK: - State Queries

    var isOpen: Bool {
        switch state {
        case .closed:
            return false
        case .open(let until):
            if Date() > until {
                state = .halfOpen
                halfOpenSuccesses = 0
                return false
            }
            return true
        case .halfOpen:
            return false
        }
    }

    var currentState: State { state }

    /// Current failure rate across the ring buffer (0.0–1.0).
    var failureRate: Double {
        guard ringCount > 0 else { return 0.0 }
        let windowSize = min(ringCount, bufferSize)
        var failures = 0
        for i in 0..<windowSize {
            let idx = (ringHead - windowSize + i + bufferSize) % bufferSize
            if !ringBuffer[idx] { failures += 1 }
        }
        return Double(failures) / Double(windowSize)
    }

    // MARK: - Recording

    func recordSuccess() {
        pushResult(true)

        switch state {
        case .halfOpen:
            halfOpenSuccesses += 1
            if halfOpenSuccesses >= requiredHalfOpenSuccesses {
                state = .closed
                halfOpenSuccesses = 0
            }
        case .open:
            break
        case .closed:
            break
        }
    }

    func recordFailure() {
        pushResult(false)

        switch state {
        case .closed:
            // Check if failure rate exceeds threshold (only when buffer has enough data)
            if ringCount >= bufferSize / 2 && failureRate >= failureRateThreshold {
                state = .open(until: Date().addingTimeInterval(resetTimeout))
            }
        case .halfOpen:
            // Any failure in half-open → back to open
            state = .open(until: Date().addingTimeInterval(resetTimeout))
            halfOpenSuccesses = 0
        case .open:
            break
        }
    }

    /// Record a thermal pause — does NOT count as a failure.
    /// Prevents thermal throttling from tripping the circuit breaker.
    func recordThermalPause() {
        // Intentionally no-op: thermal pauses are not the dependency's fault.
        // The ring buffer is not modified.
    }

    func reset() {
        state = .closed
        halfOpenSuccesses = 0
        ringHead = 0
        ringCount = 0
        ringBuffer = Array(repeating: true, count: bufferSize)
    }

    // MARK: - Ring Buffer

    private func pushResult(_ success: Bool) {
        ringBuffer[ringHead % bufferSize] = success
        ringHead = (ringHead + 1) % bufferSize
        ringCount += 1
    }
}

// MARK: - Health Checkable Protocol

protocol HealthCheckable: Actor {
    func healthCheck() async -> Bool
    func restart(reason: String) async throws
}
