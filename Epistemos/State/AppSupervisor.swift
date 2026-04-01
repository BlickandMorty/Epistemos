import Foundation
import os

// MARK: - Restart Policy (OTP semantics)

/// Erlang/OTP restart policies for supervised children.
///   - permanent: always restart, regardless of exit reason
///   - transient: restart only on abnormal termination (not cancellation)
///   - temporary: never restart — if it dies, it stays dead
enum RestartPolicy: Sendable {
    case permanent
    case transient
    case temporary
}

// MARK: - Child Specification

/// Describes a supervised child: its identity, restart rules, and factory.
struct ChildSpec: Sendable {
    let id: String
    let policy: RestartPolicy
    /// Sliding window for restart intensity (seconds).
    let restartWindow: TimeInterval
    /// Max restarts allowed within `restartWindow` before escalation.
    let maxRestarts: Int
    /// Factory that produces a long-running async task.
    /// Returning normally = clean exit. Throwing = abnormal termination.
    let factory: @Sendable () async throws -> Void
}

// MARK: - Degradation Mode

/// The app's operating mode based on subsystem health.
/// UI observes this to show/hide features gracefully.
enum EpistemosHealthMode: String, Sendable, CaseIterable {
    case full           // All subsystems operational
    case degradedAI     // Foundation Models / local inference unavailable
    case degradedCloud  // Network unavailable, local-only
    case localOnly      // Both model backends unavailable — pure note-taking
    case readOnly       // Knowledge store degraded — display only, no writes
}

// MARK: - Degradation Reason (causal chain preservation)

/// Why the system degraded — prevents "state amnesia" where recovery happens
/// without understanding the original cause.
enum DegradationReason: Sendable, CustomStringConvertible {
    case inferenceUnavailable
    case networkDown
    case knowledgeStoreCorrupted
    case thermalThrottling
    case crashLoopEscalation(childId: String)
    case supervisorForceDegrade(message: String)

    var description: String {
        switch self {
        case .inferenceUnavailable: "inference unavailable"
        case .networkDown: "network down"
        case .knowledgeStoreCorrupted: "knowledge store corrupted"
        case .thermalThrottling: "thermal throttling"
        case .crashLoopEscalation(let id): "crash loop escalation (\(id))"
        case .supervisorForceDegrade(let msg): "force degrade: \(msg)"
        }
    }
}

// MARK: - Mode Transition Record

/// An immutable record of a mode transition, for event-sourced observability.
struct ModeTransition: Sendable {
    let from: EpistemosHealthMode
    let to: EpistemosHealthMode
    let reason: DegradationReason?
    let timestamp: Date
}

// MARK: - Mode Machine

/// Typed state machine that enforces transition validation, preserves causal
/// chains via DegradationReason, and exposes an AsyncStream for reactive UI.
///
/// Recovery hysteresis: returning to .full requires the source to hold stable
/// for `recoveryHysteresis` seconds — prevents oscillation when a subsystem
/// is flapping between healthy and unhealthy.
@MainActor @Observable
final class ModeMachine {
    private static let log = Logger(subsystem: "com.epistemos", category: "ModeMachine")

    private(set) var currentMode: EpistemosHealthMode = .full
    private(set) var currentReason: DegradationReason?
    private(set) var lastTransition: Date = .distantPast

    /// How long a recovery must hold before we actually transition back up.
    private let recoveryHysteresis: TimeInterval

    /// AsyncStream for reactive UI consumption.
    private var continuation: AsyncStream<ModeTransition>.Continuation?
    private(set) var transitionStream: AsyncStream<ModeTransition>!

    init(recoveryHysteresis: TimeInterval = 10.0) {
        self.recoveryHysteresis = recoveryHysteresis

        // Create stream + continuation pair
        var capturedContinuation: AsyncStream<ModeTransition>.Continuation?
        self.transitionStream = AsyncStream<ModeTransition> { continuation in
            capturedContinuation = continuation
        }
        self.continuation = capturedContinuation
    }

    // MARK: - Transition Validation

    /// Allowed transitions. Degradation can skip levels (full → readOnly),
    /// but recovery must go step-by-step (readOnly → localOnly → degraded → full).
    private static let recoveryPath: [EpistemosHealthMode] = [
        .readOnly, .localOnly, .degradedAI, .degradedCloud, .full
    ]

    /// Attempt a transition. Returns true if the transition was applied.
    @discardableResult
    func transition(to target: EpistemosHealthMode, reason: DegradationReason?) -> Bool {
        guard target != currentMode else { return false }

        let isDegrading = Self.severity(target) > Self.severity(currentMode)

        if !isDegrading {
            // Recovery: enforce hysteresis — must wait before recovering
            let elapsed = Date().timeIntervalSince(lastTransition)
            if elapsed < recoveryHysteresis {
                Self.log.info(
                    "Recovery to \(target.rawValue) blocked — hysteresis (\(String(format: "%.1f", elapsed))s < \(self.recoveryHysteresis)s)"
                )
                return false
            }

            // Recovery: only allow one step at a time
            let currentSeverity = Self.severity(currentMode)
            let targetSeverity = Self.severity(target)
            if currentSeverity - targetSeverity > 1 {
                Self.log.info(
                    "Recovery must be step-by-step: \(self.currentMode.rawValue) → \(target.rawValue) skips levels"
                )
                return false
            }
        }

        applyTransition(to: target, reason: reason)
        return true
    }

    /// Emergency override — bypasses hysteresis and step-at-a-time recovery.
    /// Used by supervisor escalation when the system is in crisis.
    func forceDegrade(to target: EpistemosHealthMode, reason: DegradationReason) {
        guard Self.severity(target) > Self.severity(currentMode) else {
            Self.log.warning("forceDegrade called but \(target.rawValue) is not worse than \(self.currentMode.rawValue)")
            return
        }
        applyTransition(to: target, reason: reason)
    }

    // MARK: - Internals

    private func applyTransition(to target: EpistemosHealthMode, reason: DegradationReason?) {
        let record = ModeTransition(
            from: currentMode,
            to: target,
            reason: reason,
            timestamp: Date()
        )

        Self.log.notice(
            "Mode: \(self.currentMode.rawValue) → \(target.rawValue) [\(reason?.description ?? "recovery")]"
        )

        currentMode = target
        currentReason = reason
        lastTransition = record.timestamp
        continuation?.yield(record)
    }

    /// Severity rank: higher = worse.
    private static func severity(_ mode: EpistemosHealthMode) -> Int {
        switch mode {
        case .full: 0
        case .degradedCloud: 1
        case .degradedAI: 2
        case .localOnly: 3
        case .readOnly: 4
        }
    }
}

// MARK: - App Supervisor

/// Event-driven OTP-style supervisor with real child lifecycles,
/// sliding-window restart intensity, exponential backoff with jitter,
/// and escalation.
///
/// NOT a polling loop. Each child is a structured Task whose lifecycle
/// is monitored via TaskGroup. Failures trigger restart logic with
/// backoff, and crash loops escalate to app-level degradation.
@MainActor @Observable
final class AppSupervisor {
    private static let log = Logger(subsystem: "com.epistemos", category: "AppSupervisor")

    // MARK: - Observable State

    /// Typed mode machine with causal tracking and transition validation.
    let modeMachine = ModeMachine()

    /// Convenience: current health mode (delegates to mode machine).
    var healthMode: EpistemosHealthMode { modeMachine.currentMode }

    private(set) var lastHealthCheck: Date = .distantPast
    private(set) var subsystemStatus: [String: Bool] = [:]

    // UI convenience (unchanged public API)
    var isAIAvailable: Bool {
        healthMode == .full || healthMode == .degradedCloud
    }
    var isWriteAvailable: Bool {
        healthMode != .readOnly
    }
    var isCloudAvailable: Bool {
        healthMode == .full || healthMode == .degradedAI
    }

    /// Circuit breaker for inference calls (consumed by AppleIntelligenceService).
    let inferenceCircuitBreaker = AgentCircuitBreaker(failureThreshold: 3, resetTimeout: 30.0)

    // MARK: - Child Management

    /// Registered child specs, in start order (important for rest_for_one).
    private var childSpecs: [ChildSpec] = []

    /// Ring buffer of restart timestamps per child, for sliding-window intensity.
    private var restartHistory: [String: [Date]] = [:]

    /// Active child tasks, keyed by child ID.
    private var childTasks: [String: Task<Void, Never>] = [:]

    /// Supervisor lifecycle task.
    private var supervisorTask: Task<Void, Never>?

    /// Health check task (lightweight, separate from supervision).
    private var healthCheckTask: Task<Void, Never>?

    /// Thermal observation task — drives mode machine on thermal state changes.
    private var thermalObserverTask: Task<Void, Never>?

    private let healthCheckInterval: TimeInterval

    init(healthCheckInterval: TimeInterval = 30.0) {
        self.healthCheckInterval = healthCheckInterval
    }

    // MARK: - Registration

    /// Register a child spec. Must be called before `start()`.
    func register(_ spec: ChildSpec) {
        childSpecs.append(spec)
        restartHistory[spec.id] = []
    }

    // MARK: - Lifecycle

    func start() {
        guard supervisorTask == nil else { return }
        Self.log.info("AppSupervisor starting with \(self.childSpecs.count) children")

        // Start all children
        for spec in childSpecs {
            spawnChild(spec)
        }

        // Separate health check loop for subsystem status (network, store, etc.)
        healthCheckTask = Task.detached(priority: .utility) { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.healthCheckInterval ?? 30.0))
                guard !Task.isCancelled else { break }
                await self?.performHealthCheck()
            }
        }

        // Observe thermal state changes and drive mode machine accordingly
        thermalObserverTask = Task.detached(priority: .high) { [weak self] in
            let stream = NotificationCenter.default.notifications(
                named: ProcessInfo.thermalStateDidChangeNotification
            )
            for await _ in stream {
                guard !Task.isCancelled else { break }
                await self?.handleThermalStateChange()
            }
        }
    }

    private func handleThermalStateChange() {
        let thermalState = ProcessInfo.processInfo.thermalState
        switch thermalState {
        case .serious:
            modeMachine.transition(to: .degradedAI, reason: .thermalThrottling)
        case .critical:
            modeMachine.forceDegrade(to: .degradedAI, reason: .thermalThrottling)
        case .nominal, .fair:
            // Attempt recovery — hysteresis will gate this
            modeMachine.transition(to: .full, reason: nil)
        @unknown default:
            break
        }
    }

    func stop() {
        // Cancel all children
        for (id, task) in childTasks {
            task.cancel()
            Self.log.info("Cancelled child: \(id)")
        }
        childTasks.removeAll()

        healthCheckTask?.cancel()
        healthCheckTask = nil

        thermalObserverTask?.cancel()
        thermalObserverTask = nil

        supervisorTask?.cancel()
        supervisorTask = nil

        Self.log.info("AppSupervisor stopped")
    }

    // MARK: - Child Spawning & Supervision

    /// Spawn a child task and monitor it for failure.
    private func spawnChild(_ spec: ChildSpec) {
        let childId = spec.id
        subsystemStatus[childId] = true

        let task = Task.detached(priority: .medium) { [weak self] in
            do {
                try await spec.factory()
                // Clean exit
                await self?.handleChildExit(spec: spec, abnormal: false, error: nil)
            } catch is CancellationError {
                // Cooperative cancellation — not a failure
                await self?.handleChildExit(spec: spec, abnormal: false, error: nil)
            } catch {
                // Abnormal termination
                await self?.handleChildExit(spec: spec, abnormal: true, error: error)
            }
        }

        childTasks[childId] = task
    }

    /// Handle a child exiting, applying OTP restart semantics.
    private func handleChildExit(spec: ChildSpec, abnormal: Bool, error: Error?) {
        let childId = spec.id

        if let error {
            Self.log.error("Child '\(childId)' failed: \(error.localizedDescription)")
        } else {
            Self.log.info("Child '\(childId)' exited (abnormal=\(abnormal))")
        }

        childTasks.removeValue(forKey: childId)

        let shouldRestart: Bool
        switch spec.policy {
        case .permanent:
            shouldRestart = true
        case .transient:
            shouldRestart = abnormal
        case .temporary:
            shouldRestart = false
        }

        guard shouldRestart else {
            subsystemStatus[childId] = !abnormal
            return
        }

        // Check sliding-window restart intensity
        if checkAndRecordRestart(spec: spec) {
            scheduleRestart(spec: spec)
        } else {
            // Crash loop detected — escalate
            escalate(spec: spec)
        }
    }

    // MARK: - Restart Intensity (Sliding Window)

    /// Returns true if restart is allowed, false if intensity exceeded (crash loop).
    /// Records the restart timestamp in the ring buffer.
    private func checkAndRecordRestart(spec: ChildSpec) -> Bool {
        let now = Date()
        let windowStart = now.addingTimeInterval(-spec.restartWindow)

        // Evict timestamps outside the window
        var history = restartHistory[spec.id] ?? []
        history.removeAll { $0 < windowStart }

        // Check intensity
        if history.count >= spec.maxRestarts {
            Self.log.error(
                "Child '\(spec.id)' exceeded restart intensity: \(history.count) restarts in \(spec.restartWindow)s window"
            )
            restartHistory[spec.id] = history
            return false
        }

        // Record this restart
        history.append(now)
        restartHistory[spec.id] = history
        return true
    }

    // MARK: - Exponential Backoff with Jitter

    /// Schedule a restart with exponential backoff + jitter.
    /// Delay = min(base * 2^attempt, 60) + random(0..1)
    private func scheduleRestart(spec: ChildSpec) {
        let attempt = restartHistory[spec.id]?.count ?? 1
        let baseDelay: Double = 0.5
        let maxDelay: Double = 60.0
        let exponential = min(baseDelay * pow(2.0, Double(attempt - 1)), maxDelay)
        let jitter = Double.random(in: 0.0...1.0)
        let delay = exponential + jitter

        Self.log.notice(
            "Scheduling restart of '\(spec.id)' in \(String(format: "%.2f", delay))s (attempt \(attempt))"
        )

        subsystemStatus[spec.id] = false

        Task.detached(priority: .medium) { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await self?.spawnChild(spec)
        }
    }

    // MARK: - Escalation

    /// Crash loop detected — escalate by degrading the app mode and
    /// cancelling downstream dependents (rest_for_one semantic).
    private func escalate(spec: ChildSpec) {
        Self.log.critical(
            "ESCALATION: Child '\(spec.id)' in crash loop. Triggering rest_for_one shutdown."
        )

        subsystemStatus[spec.id] = false

        // rest_for_one: cancel all children registered AFTER the failed child
        if let failedIndex = childSpecs.firstIndex(where: { $0.id == spec.id }) {
            let dependents = childSpecs.suffix(from: childSpecs.index(after: failedIndex))
            for dependent in dependents {
                if let task = childTasks.removeValue(forKey: dependent.id) {
                    task.cancel()
                    subsystemStatus[dependent.id] = false
                    Self.log.warning("rest_for_one: cancelled dependent '\(dependent.id)'")
                }
            }
        }

        // Force degrade through mode machine — bypasses hysteresis
        let (newMode, _) = deriveMode()
        if newMode != healthMode {
            modeMachine.forceDegrade(
                to: newMode,
                reason: .crashLoopEscalation(childId: spec.id)
            )
        }
    }

    // MARK: - Public Restart API

    /// Manually restart a specific subsystem (one_for_one).
    func restartSubsystem(_ name: String, reason: String) async {
        Self.log.notice("Manual restart of '\(name)': \(reason)")

        // Cancel existing task if running
        if let task = childTasks.removeValue(forKey: name) {
            task.cancel()
        }

        // Special cases for subsystems not managed as children
        switch name {
        case "inference":
            await inferenceCircuitBreaker.reset()
            subsystemStatus["inference"] = true

        case "hermesSubprocess":
            if let hermes = AppBootstrap.shared?.hermesManager {
                try? await hermes.restart()
            }

        default:
            // If it's a registered child, respawn it
            if let spec = childSpecs.first(where: { $0.id == name }) {
                spawnChild(spec)
            } else {
                Self.log.warning("Unknown subsystem for restart: \(name)")
            }
        }

        await performHealthCheck()
    }

    // MARK: - Health Checks

    func performHealthCheck() async {
        lastHealthCheck = Date()

        let inferenceOK = await checkInference()
        subsystemStatus["inference"] = inferenceOK

        let networkOK = await checkNetwork()
        subsystemStatus["network"] = networkOK

        let storeOK = checkKnowledgeStore()
        subsystemStatus["knowledgeStore"] = storeOK

        let (newMode, reason) = deriveMode(
            inferenceOK: inferenceOK,
            networkOK: networkOK,
            storeOK: storeOK
        )

        modeMachine.transition(to: newMode, reason: reason)
    }

    // MARK: - Private Checks

    private func checkInference() async -> Bool {
        let isOpen = await inferenceCircuitBreaker.isOpen
        if isOpen { return false }

        let (available, _) = AppleIntelligenceService.shared.checkAvailability()
        if available { return true }

        if let bootstrap = AppBootstrap.shared {
            return !bootstrap.localModelManager.installRecords.isEmpty
        }

        return false
    }

    private nonisolated func checkNetwork() async -> Bool {
        do {
            let url = URL(string: "https://api.anthropic.com")!
            var request = URLRequest(url: url, timeoutInterval: 5.0)
            request.httpMethod = "HEAD"
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode < 500
            }
            return true
        } catch {
            return false
        }
    }

    private func checkKnowledgeStore() -> Bool {
        guard AppBootstrap.shared != nil else { return false }
        // EventStore is the session persistence layer — if it failed to init, it's nil.
        // This is a real health signal, unlike `AppBootstrap.shared != nil` which is
        // always true after boot.
        return EventStore.shared != nil
    }

    // MARK: - Mode Derivation

    /// Derive mode and reason from explicit subsystem states.
    private func deriveMode(
        inferenceOK: Bool, networkOK: Bool, storeOK: Bool
    ) -> (EpistemosHealthMode, DegradationReason?) {
        if !storeOK { return (.readOnly, .knowledgeStoreCorrupted) }
        if !inferenceOK && !networkOK { return (.localOnly, .inferenceUnavailable) }
        if !inferenceOK { return (.degradedAI, .inferenceUnavailable) }
        if !networkOK { return (.degradedCloud, .networkDown) }
        return (.full, nil)
    }

    /// Derive mode from current subsystemStatus dict (for escalation paths).
    private func deriveMode() -> (EpistemosHealthMode, DegradationReason?) {
        let inferenceOK = subsystemStatus["inference"] ?? true
        let networkOK = subsystemStatus["network"] ?? true
        let storeOK = subsystemStatus["knowledgeStore"] ?? true
        return deriveMode(inferenceOK: inferenceOK, networkOK: networkOK, storeOK: storeOK)
    }
}
