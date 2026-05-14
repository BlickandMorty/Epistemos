import Foundation
import os

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

/// Thread-safe continuation state for subprocess-backed async wrappers.
/// Ensures the continuation resumes exactly once and exposes best-effort
/// termination for timeout/cancellation handlers.
#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
final class ThrowingProcessContinuationState<Result: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var process: Process?
    nonisolated(unsafe) private var continuation: CheckedContinuation<Result, Error>?
    nonisolated(unsafe) private var resumed = false

    nonisolated func store(process: Process, continuation: CheckedContinuation<Result, Error>) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return false }
        self.process = process
        self.continuation = continuation
        return true
    }

    nonisolated func terminate() {
        lock.lock()
        let process = self.process
        lock.unlock()
        process?.terminate()
    }

    nonisolated func resume(returning value: Result) {
        let continuation = takeContinuation()
        continuation?.resume(returning: value)
    }

    nonisolated func resume(throwing error: Error) {
        let continuation = takeContinuation()
        continuation?.resume(throwing: error)
    }

    private nonisolated func takeContinuation() -> CheckedContinuation<Result, Error>? {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return nil }
        resumed = true
        let continuation = self.continuation
        self.continuation = nil
        self.process = nil
        return continuation
    }
}

/// Thread-safe continuation state for subprocess-backed async wrappers that
/// always return a value, even on cancellation.
final class ProcessContinuationState<Result: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var process: Process?
    nonisolated(unsafe) private var continuation: CheckedContinuation<Result, Never>?
    nonisolated(unsafe) private var resumed = false

    nonisolated func store(process: Process, continuation: CheckedContinuation<Result, Never>) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return false }
        self.process = process
        self.continuation = continuation
        return true
    }

    nonisolated func terminate() {
        lock.lock()
        let process = self.process
        lock.unlock()
        process?.terminate()
    }

    nonisolated func resume(returning value: Result) {
        let continuation = takeContinuation()
        continuation?.resume(returning: value)
    }

    private nonisolated func takeContinuation() -> CheckedContinuation<Result, Never>? {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return nil }
        resumed = true
        let continuation = self.continuation
        self.continuation = nil
        self.process = nil
        return continuation
    }
}
#endif

/// Thread-safe continuation state for general async bridge helpers.
/// Allows timeout/cancellation handlers to win races against late completions.
final class ThrowingContinuationState<Result: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var continuation: CheckedContinuation<Result, Error>?
    nonisolated(unsafe) private var resumed = false

    nonisolated func store(continuation: CheckedContinuation<Result, Error>) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return false }
        self.continuation = continuation
        return true
    }

    nonisolated func resume(returning value: Result) {
        let continuation = takeContinuation()
        continuation?.resume(returning: value)
    }

    nonisolated func resume(throwing error: Error) {
        let continuation = takeContinuation()
        continuation?.resume(throwing: error)
    }

    private nonisolated func takeContinuation() -> CheckedContinuation<Result, Error>? {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return nil }
        resumed = true
        let continuation = self.continuation
        self.continuation = nil
        return continuation
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

/// Bridge a MainActor-isolated async operation into a nonisolated context with
/// the same timeout/cancellation guarantees as subprocess-backed helpers.
func withTimedMainActorBridge<T: Sendable>(
    seconds: Double = 30.0,
    operation: @escaping @MainActor @Sendable () async throws -> T
) async throws -> T {
    let state = ThrowingContinuationState<T>()

    return try await withTaskCancellationHandler {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    guard !Task.isCancelled else {
                        continuation.resume(throwing: CancellationError())
                        return
                    }
                    guard state.store(continuation: continuation) else {
                        continuation.resume(throwing: CancellationError())
                        return
                    }

                    Task { @MainActor in
                        do {
                            state.resume(returning: try await operation())
                        } catch {
                            state.resume(throwing: error)
                        }
                    }
                }
            }

            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                let timeout = TimeoutError(seconds: seconds)
                state.resume(throwing: timeout)
                throw timeout
            }

            defer { group.cancelAll() }
            guard let result = try await group.next() else {
                let timeout = TimeoutError(seconds: seconds)
                state.resume(throwing: timeout)
                throw timeout
            }
            return result
        }
    } onCancel: {
        state.resume(throwing: CancellationError())
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

// MARK: - Error Classification

/// Classifies whether an error should be ignored by the circuit breaker.
/// Thermal errors, cancellation, and context exhaustion are not provider failures.
protocol CircuitBreakerIgnorable {
    /// If true, this error does not count as a failure in the ring buffer.
    nonisolated var isCircuitBreakerNeutral: Bool { get }
}

extension ThermalError: CircuitBreakerIgnorable {
    nonisolated var isCircuitBreakerNeutral: Bool { true }
}

extension CancellationError: CircuitBreakerIgnorable {
    nonisolated var isCircuitBreakerNeutral: Bool { true }
}

extension TimeoutError: CircuitBreakerIgnorable {
    /// Timeouts during thermal throttling are neutral; others are real failures.
    /// Callers should route through ThermalGuard first, so if a timeout reaches
    /// the breaker, it's a genuine provider timeout.
    nonisolated var isCircuitBreakerNeutral: Bool { false }
}

// MARK: - Breaker Domain

/// Identifies a resilience domain with its specific configuration.
enum BreakerDomain: String, Sendable, CaseIterable {
    case cloud
    case foundationModels
    case mlx
    case vault
}

// MARK: - Breaker Configuration

/// Per-domain configuration for circuit breaker behavior.
struct BreakerConfig: Sendable {
    /// Ring buffer capacity (number of tracked call outcomes).
    let capacity: Int
    /// Failure rate (0.0–1.0) that triggers the breaker to open.
    let failureRateThreshold: Double
    /// How long the breaker stays open before transitioning to half-open.
    let resetTimeout: TimeInterval
    /// Consecutive successes needed in half-open to close the breaker.
    let requiredHalfOpenSuccesses: Int
    /// Health mode to degrade to when this breaker opens.
    let degradedMode: EpistemosHealthMode
    /// Additional error types treated as neutral (beyond thermal/cancellation).
    let additionalNeutralErrors: [@Sendable (any Error) -> Bool]
}

/// Factory for per-domain breaker configs. Constructed inline to avoid
/// static property isolation inference under Swift 6.2 approachable concurrency.
nonisolated func breakerConfig(for domain: BreakerDomain) -> BreakerConfig {
    switch domain {
    case .cloud:
        BreakerConfig(
            capacity: 32,
            failureRateThreshold: 0.50,
            resetTimeout: 60.0,
            requiredHalfOpenSuccesses: 2,
            degradedMode: .degradedCloud,
            additionalNeutralErrors: []
        )
    case .foundationModels:
        BreakerConfig(
            capacity: 16,
            failureRateThreshold: 0.75,
            resetTimeout: 30.0,
            requiredHalfOpenSuccesses: 3,
            degradedMode: .degradedAI,
            additionalNeutralErrors: [{ error in
                String(describing: error).contains("contextWindowExceeded")
                    || String(describing: error).contains("exceededContextWindowSize")
            }]
        )
    case .mlx:
        BreakerConfig(
            capacity: 16,
            failureRateThreshold: 0.80,
            resetTimeout: 15.0,
            requiredHalfOpenSuccesses: 2,
            degradedMode: .degradedAI,
            additionalNeutralErrors: []
        )
    case .vault:
        BreakerConfig(
            capacity: 8,
            failureRateThreshold: 0.75,
            resetTimeout: 30.0,
            requiredHalfOpenSuccesses: 2,
            degradedMode: .readOnly,
            additionalNeutralErrors: []
        )
    }
}

// MARK: - UInt64 Bit Ring Buffer

/// Fixed-size ring buffer backed by UInt64 words. Zero allocation after init.
/// Each bit represents one call outcome: 1 = failure, 0 = success.
/// Failure rate is computed via incremental cardinality tracking.
///
/// This is the Resilience4j RingBitBuffer pattern:
/// cardinality is updated on every record: new = old - evicted_bit + incoming_bit.
/// Query is O(1). Recording is O(1). Memory is fixed at initialization.
private struct BitRingBuffer: Sendable {
    /// Storage words — each UInt64 holds 64 slots.
    private var words: [UInt64]
    /// Total capacity in bits.
    let capacity: Int
    /// Number of words.
    private let wordCount: Int
    /// Current write position (0..<capacity).
    private var writeIndex: Int = 0
    /// Number of recorded results (saturates at capacity).
    private var recorded: Int = 0
    /// Pre-computed failure count (number of 1-bits in the active window).
    private var cardinality: Int = 0

    nonisolated init(capacity: Int) {
        precondition(capacity > 0 && capacity <= 1024, "Capacity must be 1–1024")
        self.capacity = capacity
        self.wordCount = (capacity + 63) / 64
        self.words = Array(repeating: 0, count: self.wordCount)
    }

    /// Whether the buffer has been fully filled at least once.
    nonisolated var isFilled: Bool { recorded >= capacity }

    /// Current failure rate (0.0–1.0). Returns 0.0 if buffer is not yet filled.
    nonisolated var failureRate: Double {
        guard isFilled else { return 0.0 }
        return Double(cardinality) / Double(capacity)
    }

    /// Record a call outcome. `isFailure = true` sets the bit to 1.
    nonisolated mutating func record(isFailure: Bool) {
        let wordIdx = writeIndex / 64
        let bitIdx = writeIndex % 64
        let mask: UInt64 = 1 << bitIdx

        // Read the bit being evicted
        let evictedBit = (words[wordIdx] & mask) != 0 ? 1 : 0
        let incomingBit = isFailure ? 1 : 0

        // Update cardinality: subtract evicted, add incoming
        cardinality = cardinality - evictedBit + incomingBit

        // Write the new bit
        if isFailure {
            words[wordIdx] |= mask
        } else {
            words[wordIdx] &= ~mask
        }

        // Advance write position
        writeIndex = (writeIndex + 1) % capacity
        recorded += 1
    }

    /// Reset all state.
    nonisolated mutating func reset() {
        words = Array(repeating: 0, count: wordCount)
        writeIndex = 0
        recorded = 0
        cardinality = 0
    }
}

// MARK: - Circuit Breaker (Resilience4j-style, per-domain)
//
// UInt64 bit ring buffer for rolling failure rate, multi-probe half-open,
// typed retry metadata, thermal pause exemption, and error classification.
//
// Three states:
//   Closed   → calls proceed, failures tracked in ring buffer
//   Open     → calls rejected with retryAfter, auto-transitions to halfOpen
//   HalfOpen → limited probe calls; N consecutive successes → Closed
//
// Canonical API: execute<T>() — callers never touch record* directly.

actor AgentCircuitBreaker {
    private static let log = Logger(subsystem: "com.epistemos", category: "CircuitBreaker")

    enum State: Sendable, CustomStringConvertible {
        case closed
        case open(until: Date)
        case halfOpen

        var description: String {
            switch self {
            case .closed: "closed"
            case .open(let until): "open(until: \(until))"
            case .halfOpen: "halfOpen"
            }
        }
    }

    /// UInt64-backed ring buffer — zero allocation after init.
    private var ringBuffer: BitRingBuffer

    private var state: State = .closed

    /// Consecutive successes in half-open state.
    private var halfOpenSuccesses: Int = 0

    let domain: BreakerDomain
    let config: BreakerConfig

    /// Weak reference to mode machine for state change notifications.
    /// Set after initialization via `setModeMachine(_:)`.
    private weak var modeMachine: ModeMachine?

    init(domain: BreakerDomain) {
        self.domain = domain
        self.config = breakerConfig(for: domain)
        self.ringBuffer = BitRingBuffer(capacity: config.capacity)
    }

    /// Legacy-compatible initializer (used by AppSupervisor during migration).
    init(failureThreshold: Int, resetTimeout: TimeInterval) {
        self.domain = .cloud
        self.config = BreakerConfig(
            capacity: max(failureThreshold * 2, 6),
            failureRateThreshold: Double(failureThreshold) / Double(max(failureThreshold * 2, 6)),
            resetTimeout: resetTimeout,
            requiredHalfOpenSuccesses: 2,
            degradedMode: .degradedCloud,
            additionalNeutralErrors: []
        )
        self.ringBuffer = BitRingBuffer(capacity: config.capacity)
    }

    /// Connect this breaker to the mode machine for degradation notifications.
    func setModeMachine(_ machine: ModeMachine) {
        self.modeMachine = machine
    }

    // MARK: - Canonical API: execute<T>()

    /// Execute work through the circuit breaker. This is the ONLY way callers
    /// should interact with the breaker — never call record* directly.
    ///
    /// - If the breaker is open, throws `CircuitBreakerOpenError` immediately.
    /// - If the work succeeds, records success and may close from half-open.
    /// - If the work fails with a neutral error (thermal, cancellation), the
    ///   ring buffer is NOT modified.
    /// - If the work fails with a real error, records failure and may trip open.
    func execute<T: Sendable>(
        _ work: @Sendable () async throws -> T
    ) async throws -> T {
        // Check state — may auto-transition open → halfOpen
        switch effectiveState {
        case .open(let until):
            throw CircuitBreakerOpenError(domain: domain.rawValue, retryAfter: until)
        case .closed, .halfOpen:
            break
        }

        do {
            let result = try await work()
            recordSuccess()
            return result
        } catch {
            // Classify the error
            if isNeutral(error) {
                Self.log.debug("Neutral error in \(self.domain.rawValue): \(error.localizedDescription)")
                throw error
            }

            recordFailure()
            throw error
        }
    }

    // MARK: - State Queries

    var isOpen: Bool {
        switch effectiveState {
        case .open: true
        case .closed, .halfOpen: false
        }
    }

    var currentState: State { state }

    /// Current failure rate across the ring buffer (0.0–1.0).
    var failureRate: Double { ringBuffer.failureRate }

    // MARK: - Error Classification

    /// Determine if an error is neutral (should not affect the ring buffer).
    private func isNeutral(_ error: any Error) -> Bool {
        // Built-in neutral errors
        if error is ThermalError { return true }
        if error is CancellationError { return true }

        // Check CircuitBreakerIgnorable conformance
        if let ignorable = error as? CircuitBreakerIgnorable, ignorable.isCircuitBreakerNeutral {
            return true
        }

        // Domain-specific additional neutral errors
        for checker in config.additionalNeutralErrors {
            if checker(error) { return true }
        }

        return false
    }

    // MARK: - Internal State Management

    /// Returns the effective state, auto-transitioning open → halfOpen when timeout expires.
    private var effectiveState: State {
        if case .open(let until) = state, Date() > until {
            state = .halfOpen
            halfOpenSuccesses = 0
            Self.log.notice("\(self.domain.rawValue): open → halfOpen (timeout expired)")
        }
        return state
    }

    /// Record a success. Prefer `execute<T>()` which calls this automatically.
    func recordSuccess() {
        ringBuffer.record(isFailure: false)

        switch state {
        case .halfOpen:
            halfOpenSuccesses += 1
            if halfOpenSuccesses >= config.requiredHalfOpenSuccesses {
                state = .closed
                halfOpenSuccesses = 0
                Self.log.notice("\(self.domain.rawValue): halfOpen → closed (\(self.config.requiredHalfOpenSuccesses) successes)")
                notifyModeMachine(opened: false)
            }
        case .open, .closed:
            break
        }
    }

    /// Record a failure. Prefer `execute<T>()` which calls this automatically.
    func recordFailure() {
        ringBuffer.record(isFailure: true)

        switch state {
        case .closed:
            // Only trip if buffer is filled enough and failure rate exceeds threshold
            if ringBuffer.isFilled && ringBuffer.failureRate >= config.failureRateThreshold {
                let until = Date().addingTimeInterval(config.resetTimeout)
                state = .open(until: until)
                Self.log.warning(
                    "\(self.domain.rawValue): closed → open (rate=\(String(format: "%.2f", self.ringBuffer.failureRate)), threshold=\(self.config.failureRateThreshold))"
                )
                notifyModeMachine(opened: true)
            }
        case .halfOpen:
            // Any real failure in half-open → back to open
            let until = Date().addingTimeInterval(config.resetTimeout)
            state = .open(until: until)
            halfOpenSuccesses = 0
            Self.log.warning("\(self.domain.rawValue): halfOpen → open (probe failed)")
            notifyModeMachine(opened: true)
        case .open:
            break
        }
    }

    /// Notify mode machine about breaker state changes.
    private func notifyModeMachine(opened: Bool) {
        guard let machine = modeMachine else { return }
        let domain = self.domain
        let degradedMode = config.degradedMode

        // DispatchQueue.main.async for MainActor-isolated ModeMachine
        DispatchQueue.main.async {
            if opened {
                machine.transition(
                    to: degradedMode,
                    reason: .circuitBreakerOpen(domain: domain.rawValue)
                )
            } else {
                machine.transition(
                    to: .full,
                    reason: .circuitBreakerRecovered(domain: domain.rawValue)
                )
            }
        }
    }

    /// Record a thermal pause — does NOT count as a failure.
    /// Preserves backward compatibility for callers that use this directly.
    func recordThermalPause() {
        // Intentionally no-op: thermal pauses are not the dependency's fault.
    }

    func reset() {
        state = .closed
        halfOpenSuccesses = 0
        ringBuffer.reset()
    }
}

// MARK: - Breaker Registry

/// Centralized registry providing per-domain circuit breaker instances.
/// Ensures each domain has exactly one breaker with the correct configuration.
@MainActor
final class BreakerRegistry {
    static let shared = BreakerRegistry()

    let cloud = AgentCircuitBreaker(domain: .cloud)
    let foundationModels = AgentCircuitBreaker(domain: .foundationModels)
    let mlx = AgentCircuitBreaker(domain: .mlx)
    let vault = AgentCircuitBreaker(domain: .vault)

    /// Get breaker by domain enum.
    func breaker(for domain: BreakerDomain) -> AgentCircuitBreaker {
        switch domain {
        case .cloud: cloud
        case .foundationModels: foundationModels
        case .mlx: mlx
        case .vault: vault
        }
    }

    /// Wire all breakers to the mode machine for degradation notifications.
    func wireModeMachine(_ machine: ModeMachine) {
        let allBreakers = [cloud, foundationModels, mlx, vault]
        for breaker in allBreakers {
            Task { await breaker.setModeMachine(machine) }
        }
    }

    /// All domain breakers for iteration.
    var allBreakers: [AgentCircuitBreaker] {
        [cloud, foundationModels, mlx, vault]
    }
}

// MARK: - Health Checkable Protocol

protocol HealthCheckable: Actor {
    func healthCheck() async -> Bool
    func restart(reason: String) async throws
}
