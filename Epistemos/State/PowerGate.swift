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

    /// Returns `true` if the caller should defer expensive background
    /// work right now. Combines battery state + thermal state.
    ///
    /// Thresholds match the compass artifact's recommended Phase-5
    /// concurrency policy:
    ///   - On battery + < 50 % capacity → defer
    ///   - Thermal ≥ serious            → defer
    ///   - Low-power-mode enabled       → defer
    public static func shouldDefer() -> Bool {
        let pi = ProcessInfo.processInfo
        if pi.isLowPowerModeEnabled {
            log.debug("defer: low-power mode enabled")
            return true
        }
        if pi.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue {
            log.debug("defer: thermal state \(pi.thermalState.rawValue)")
            return true
        }
        let snap = batteryState()
        if snap.onBattery, snap.percent < 50 {
            log.debug("defer: on battery at \(snap.percent)%")
            return true
        }
        return false
    }

    /// Convenience: returns `true` if the caller can proceed.
    public static func canRunNow() -> Bool { !shouldDefer() }

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
