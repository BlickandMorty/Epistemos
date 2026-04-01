import Foundation
import os

// MARK: - Thermal Guard
//
// Centralized thermal authority. ALL thermal state queries go through this actor.
// No subsystem should read ProcessInfo.processInfo.thermalState directly.
//
// Capabilities:
//   - Single source of truth for thermal state
//   - CheckedContinuation parking: callers await clearance, suspended during thermal pressure
//   - Resume on cooling, cancel with ThermalError on critical
//   - Mode machine integration for thermal degradation

/// Error thrown when a thermal-parked operation is cancelled due to critical thermal state.
struct ThermalError: Error, LocalizedError {
    let thermalState: ProcessInfo.ThermalState
    var errorDescription: String? {
        "Operation cancelled due to critical thermal pressure (\(thermalState.label))"
    }
}

extension ProcessInfo.ThermalState {
    nonisolated var label: String {
        switch self {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
    }

    /// Whether this state should block new inference work.
    nonisolated var shouldThrottle: Bool {
        self == .serious || self == .critical
    }
}

/// Centralized thermal authority actor.
/// All inference callers must call `acquireClearance()` before starting compute work.
/// If thermal pressure is high, the caller is parked (suspended) until conditions improve.
/// If thermal pressure goes critical, parked callers receive a `ThermalError`.
actor ThermalGuard {
    static let shared = ThermalGuard()

    private static let log = Logger(subsystem: "com.epistemos", category: "ThermalGuard")

    /// Current thermal state — updated from notification observer.
    private(set) var currentState: ProcessInfo.ThermalState = .nominal

    /// Parked continuations waiting for thermal clearance.
    private var parkedCallers: [UUID: CheckedContinuation<Void, Error>] = [:]

    /// Observation task for thermal notifications.
    private var observerTask: Task<Void, Never>?

    // MARK: - Lifecycle

    func start() {
        guard observerTask == nil else { return }

        // Read initial state
        currentState = ProcessInfo.processInfo.thermalState
        Self.log.info("ThermalGuard started, initial state: \(self.currentState.label)")

        // Observe changes via NotificationCenter
        observerTask = Task.detached(priority: .high) { [weak self] in
            let center = NotificationCenter.default
            let stream = center.notifications(
                named: ProcessInfo.thermalStateDidChangeNotification
            )
            for await _ in stream {
                guard !Task.isCancelled else { break }
                let newState = ProcessInfo.processInfo.thermalState
                await self?.handleThermalChange(newState)
            }
        }
    }

    func stop() {
        observerTask?.cancel()
        observerTask = nil
        // Cancel all parked callers
        for (_, continuation) in parkedCallers {
            continuation.resume(throwing: CancellationError())
        }
        parkedCallers.removeAll()
    }

    // MARK: - Clearance API

    /// Acquire thermal clearance before starting compute-intensive work.
    /// If thermal pressure is high, this suspends the caller until conditions improve.
    /// Throws `ThermalError` if the system enters critical thermal state while parked.
    func acquireClearance() async throws {
        // Fast path: no throttling needed
        guard currentState.shouldThrottle else { return }

        // Critical: reject immediately
        if currentState == .critical {
            throw ThermalError(thermalState: currentState)
        }

        // Serious: park the caller until thermal state improves
        Self.log.notice("Parking caller — thermal state: \(self.currentState.label)")
        let id = UUID()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            parkedCallers[id] = continuation
        }
    }

    /// Check if inference work is currently allowed (non-blocking query).
    var isInferenceAllowed: Bool {
        !currentState.shouldThrottle
    }

    // MARK: - Thermal State Changes

    private func handleThermalChange(_ newState: ProcessInfo.ThermalState) {
        let oldState = currentState
        currentState = newState

        guard oldState != newState else { return }
        Self.log.notice("Thermal: \(oldState.label) → \(newState.label)")

        switch newState {
        case .nominal, .fair:
            // Conditions improved — resume all parked callers
            resumeAllParked()

        case .serious:
            // Keep callers parked, don't cancel them yet
            break

        case .critical:
            // Cancel all parked callers with error
            cancelAllParked(reason: ThermalError(thermalState: newState))

        @unknown default:
            break
        }
    }

    private func resumeAllParked() {
        guard !parkedCallers.isEmpty else { return }
        Self.log.notice("Resuming \(self.parkedCallers.count) parked callers")
        for (_, continuation) in parkedCallers {
            continuation.resume()
        }
        parkedCallers.removeAll()
    }

    private func cancelAllParked(reason: Error) {
        guard !parkedCallers.isEmpty else { return }
        Self.log.warning("Cancelling \(self.parkedCallers.count) parked callers — critical thermal")
        for (_, continuation) in parkedCallers {
            continuation.resume(throwing: reason)
        }
        parkedCallers.removeAll()
    }
}
