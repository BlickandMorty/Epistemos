import Foundation
import os

// MARK: - Power Mode

/// Two-tier power management:
///   - `.full`: everything on, no restrictions
///   - `.lowPower`: system Low Power Mode or critical thermal state — pauses
///     nonessential maintenance and throttles rendering as an emergency fallback
enum PowerMode: Int, Sendable, CaseIterable {
    case full = 0
    case lowPower = 1

    var label: String {
        switch self {
        case .full: "Full"
        case .lowPower: "Low Power"
        }
    }

    /// Whether background subsystems (heartbeat, watchdog, screen capture,
    /// vault timers, health checks) should be disabled.
    var disablesBackground: Bool {
        self == .lowPower
    }

    /// Whether rendering should be throttled (60fps cap, physics paused,
    /// ring buffer polling slowed).
    var throttlesRendering: Bool {
        self == .lowPower
    }
}

// MARK: - Power Guard

/// Centralized power authority. All subsystems query this before doing
/// background or compute-intensive work.
///
/// Derives `currentMode` from two automatic inputs:
///   1. System low power mode (`ProcessInfo.isLowPowerModeEnabled`)
///   2. Thermal state (`.critical` escalates to `.lowPower`)
///
/// Same architectural pattern as ThermalGuard — singleton, notification-driven,
/// observable for SwiftUI.
@MainActor @Observable
final class PowerGuard {
    static let shared = PowerGuard()

    private static let log = Logger(subsystem: "com.epistemos", category: "PowerGuard")
    nonisolated static let modeDidChangeNotification = Notification.Name("com.epistemos.powerModeDidChange")
    nonisolated static let modeUserInfoKey = "modeRawValue"

    // MARK: - Observable State

    /// Current derived power mode — the canonical source of truth.
    private(set) var currentMode: PowerMode = .full

    /// Whether the system is in low power mode.
    private(set) var systemLowPowerActive = false

    /// Whether thermal state is critical.
    private(set) var thermalCritical = false

    // MARK: - Convenience Queries

    /// True when background subsystems should be disabled.
    var shouldDisableBackground: Bool { currentMode.disablesBackground }

    /// True when rendering should be throttled (60fps cap, physics pause).
    var shouldThrottleRendering: Bool { currentMode.throttlesRendering }

    /// Max display link FPS. Unlimited (0) in full, 60 in lowPower.
    var maxDisplayLinkFPS: Int { currentMode.throttlesRendering ? 60 : 0 }

    /// Ring buffer polling interval.
    var ringPollInterval: Duration {
        currentMode.throttlesRendering ? .milliseconds(100) : .milliseconds(16)
    }

    /// Health check interval for AppSupervisor.
    var healthCheckInterval: TimeInterval {
        switch currentMode {
        case .full: 30.0
        case .lowPower: .infinity // stopped
        }
    }

    // MARK: - Lifecycle

    private var powerNotificationTask: Task<Void, Never>?
    private var thermalNotificationTask: Task<Void, Never>?

    private init() {
        // Retire the old manual Eco setting instead of allowing a saved value to
        // suppress a fresh session's normal-performance policy.
        FoundationSafety.runtimeUserDefaults.removeObject(forKey: "epistemos.ecoMode")
        systemLowPowerActive = ProcessInfo.processInfo.isLowPowerModeEnabled
        thermalCritical = ProcessInfo.processInfo.thermalState == .critical

        recalculate(reason: "init")
    }

    func start() {
        guard powerNotificationTask == nil else { return }

        powerNotificationTask = Task.detached(priority: .high) { [weak self] in
            let stream = NotificationCenter.default.notifications(
                named: .NSProcessInfoPowerStateDidChange
            )
            for await _ in stream {
                guard !Task.isCancelled else { break }
                let isLPM = ProcessInfo.processInfo.isLowPowerModeEnabled
                await MainActor.run {
                    self?.systemLowPowerActive = isLPM
                    self?.recalculate(reason: isLPM ? "system LPM on" : "system LPM off")
                }
            }
        }

        thermalNotificationTask = Task.detached(priority: .high) { [weak self] in
            let stream = NotificationCenter.default.notifications(
                named: ProcessInfo.thermalStateDidChangeNotification
            )
            for await _ in stream {
                guard !Task.isCancelled else { break }
                let isCritical = ProcessInfo.processInfo.thermalState == .critical
                await MainActor.run {
                    self?.thermalCritical = isCritical
                    self?.recalculate(reason: isCritical ? "thermal critical" : "thermal recovered")
                }
            }
        }

        Self.log.info("PowerGuard started — mode: \(self.currentMode.label)")
    }

    func stop() {
        powerNotificationTask?.cancel()
        powerNotificationTask = nil
        thermalNotificationTask?.cancel()
        thermalNotificationTask = nil
    }

    // MARK: - Mode Derivation

    private func recalculate(reason: String) {
        let previous = currentMode

        let derived: PowerMode = systemLowPowerActive || thermalCritical ? .lowPower : .full

        guard derived != previous else { return }
        currentMode = derived
        Self.log.notice("Power mode: \(previous.label) → \(derived.label) [\(reason)]")
        NotificationCenter.default.post(
            name: Self.modeDidChangeNotification,
            object: self,
            userInfo: [Self.modeUserInfoKey: derived.rawValue]
        )
    }
}
