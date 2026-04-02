import Foundation
import os

// MARK: - Power Mode

/// Three-tier power management:
///   - `.full`: everything on, no restrictions
///   - `.eco`: manual toggle — disables background subsystems, full FPS
///   - `.lowPower`: system LPM or critical thermal — eco + 60fps cap + render throttle
enum PowerMode: Int, Comparable, Sendable, CaseIterable {
    case full = 0
    case eco = 1
    case lowPower = 2

    static func < (lhs: PowerMode, rhs: PowerMode) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .full: "Full"
        case .eco: "Eco"
        case .lowPower: "Low Power"
        }
    }

    /// Whether background subsystems (NightBrain, Heartbeat, watchdog,
    /// screen capture, vault timers, health checks) should be disabled.
    var disablesBackground: Bool {
        self >= .eco
    }

    /// Whether rendering should be throttled (60fps cap, physics paused,
    /// ring buffer polling slowed).
    var throttlesRendering: Bool {
        self >= .lowPower
    }
}

// MARK: - Power Guard

/// Centralized power authority. All subsystems query this before doing
/// background or compute-intensive work.
///
/// Derives `currentMode` from three inputs:
///   1. System low power mode (`ProcessInfo.isLowPowerModeEnabled`)
///   2. Thermal state (`.critical` escalates to `.lowPower`)
///   3. User eco toggle (persisted in UserDefaults)
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

    /// User-controlled eco toggle. Persisted across launches.
    var ecoModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(ecoModeEnabled, forKey: "epistemos.ecoMode")
            recalculate(reason: ecoModeEnabled ? "eco enabled" : "eco disabled")
        }
    }

    /// Whether eco mode has ever been explicitly set by the user.
    /// On first launch, eco is on by default.
    private static var hasExplicitEcoPreference: Bool {
        UserDefaults.standard.object(forKey: "epistemos.ecoMode") != nil
    }

    /// Whether the system is in low power mode.
    private(set) var systemLowPowerActive = false

    /// Whether thermal state is critical.
    private(set) var thermalCritical = false

    // MARK: - Convenience Queries

    /// True when background subsystems should be disabled.
    var shouldDisableBackground: Bool { currentMode.disablesBackground }

    /// True when rendering should be throttled (60fps cap, physics pause).
    var shouldThrottleRendering: Bool { currentMode.throttlesRendering }

    /// Max display link FPS. Unlimited (0) in full/eco, 60 in lowPower.
    var maxDisplayLinkFPS: Int { currentMode.throttlesRendering ? 60 : 0 }

    /// Ring buffer polling interval.
    var ringPollInterval: Duration {
        currentMode.throttlesRendering ? .milliseconds(100) : .milliseconds(16)
    }

    /// Health check interval for AppSupervisor.
    var healthCheckInterval: TimeInterval {
        switch currentMode {
        case .full: 30.0
        case .eco: 120.0
        case .lowPower: .infinity // stopped
        }
    }

    // MARK: - Lifecycle

    private var powerNotificationTask: Task<Void, Never>?
    private var thermalNotificationTask: Task<Void, Never>?

    private init() {
        // Default to eco mode on first launch (no key in UserDefaults yet).
        ecoModeEnabled = Self.hasExplicitEcoPreference
            ? UserDefaults.standard.bool(forKey: "epistemos.ecoMode")
            : true
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

        let derived: PowerMode
        if systemLowPowerActive || thermalCritical {
            derived = .lowPower
        } else if ecoModeEnabled {
            derived = .eco
        } else {
            derived = .full
        }

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
