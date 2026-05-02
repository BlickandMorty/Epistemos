import Foundation
import IOKit.ps
import OSLog

// MARK: - PowerGate
//
// W10.10-FIX cross-cutting (compass artifact 2026-04-26)
//
// Shared pre-flight predicate used by all background subsystems so a
// single thermal / battery pressure event throttles the whole stack
// uniformly. Used by:
//   - NightBrain LaunchAgent (3 AM cron — defer if battery < 50 %
//     or thermal ≥ serious)
//   - FSRS-6 daily decay pass (W10.2)
//   - SpeechAnalyzer always-on transcription (W10.11)
//   - MLX subconscious dispatch (W10.5 — `canRunMLX()` already
//     wraps similar checks; PowerGate is the canonical extraction)
//
// The predicate is intentionally conservative — false negatives (skip
// when we could have run) are cheap; false positives (run when we
// shouldn't) cost battery and trigger Apple Silicon thermal throttle
// that affects the foreground UI for ~minutes after the spike.

public enum PowerGate {

    private static let log = Logger(subsystem: "com.epistemos", category: "PowerGate")
    private static let memoryPressureLock = NSLock()
    nonisolated(unsafe) private static var memoryPressureActive = false

    public enum DeferReason: String, Sendable, Equatable {
        case lowPower = "low power mode"
        case thermal = "thermal pressure"
        case battery = "on battery"
        case memoryPressure = "memory pressure"
    }

    public struct DeferSnapshot: Sendable, Equatable {
        public let shouldDefer: Bool
        public let reason: DeferReason?
    }

    /// Returns `true` if the caller should defer expensive background
    /// work right now. Combines battery, thermal, low-power mode, and
    /// the process-wide memory-pressure signal.
    ///
    /// Thresholds match the compass artifact's recommended Phase-5
    /// concurrency policy:
    ///   - On battery + < 50 % capacity → defer
    ///   - Thermal ≥ serious            → defer
    ///   - Low-power-mode enabled       → defer
    ///   - Memory pressure warning/crit. → defer
    public static func shouldDefer() -> Bool {
        let snapshot = deferSnapshot()
        if let reason = snapshot.reason {
            log.debug("defer: \(reason.rawValue, privacy: .public)")
        }
        return snapshot.shouldDefer
    }

    /// Convenience: returns `true` if the caller can proceed.
    public static func canRunNow() -> Bool { !shouldDefer() }

    public static var isMemoryPressureActive: Bool {
        memoryPressureLock.lock()
        defer { memoryPressureLock.unlock() }
        return memoryPressureActive
    }

    public static func recordMemoryPressureActive(_ active: Bool) {
        memoryPressureLock.lock()
        memoryPressureActive = active
        memoryPressureLock.unlock()
    }

    public static func deferSnapshot() -> DeferSnapshot {
        let processInfo = ProcessInfo.processInfo
        return deferSnapshot(
            lowPowerModeEnabled: processInfo.isLowPowerModeEnabled,
            thermalState: processInfo.thermalState,
            battery: batteryState(),
            memoryPressureActive: isMemoryPressureActive
        )
    }

    public static func deferSnapshot(
        lowPowerModeEnabled: Bool,
        thermalState: ProcessInfo.ThermalState,
        battery: BatterySnapshot,
        memoryPressureActive: Bool
    ) -> DeferSnapshot {
        if lowPowerModeEnabled {
            return DeferSnapshot(shouldDefer: true, reason: .lowPower)
        }
        if thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue {
            return DeferSnapshot(shouldDefer: true, reason: .thermal)
        }
        if battery.onBattery, battery.percent < 50 {
            return DeferSnapshot(shouldDefer: true, reason: .battery)
        }
        if memoryPressureActive {
            return DeferSnapshot(shouldDefer: true, reason: .memoryPressure)
        }
        return DeferSnapshot(shouldDefer: false, reason: nil)
    }

    // MARK: - Battery snapshot

    public struct BatterySnapshot: Sendable, Equatable {
        public let onBattery: Bool
        public let percent: Int
        public let isCharging: Bool
    }

    public static func batteryState() -> BatterySnapshot {
        let snap = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snap).takeRetainedValue() as Array
        guard let src = sources.first else {
            return BatterySnapshot(onBattery: false, percent: 100, isCharging: false)
        }
        let info = IOPSGetPowerSourceDescription(snap, src).takeUnretainedValue() as NSDictionary
        let stateRaw = info[kIOPSPowerSourceStateKey] as? String ?? ""
        let onBattery = stateRaw == kIOPSBatteryPowerValue
        let pct = info[kIOPSCurrentCapacityKey] as? Int ?? 100
        let charging = info[kIOPSIsChargingKey] as? Bool ?? false
        return BatterySnapshot(onBattery: onBattery, percent: pct, isCharging: charging)
    }
}
