import Foundation
import OSLog
import ServiceManagement

// MARK: - NightBrainScheduler
//
// W10.10-FIX (compass artifact 2026-04-26)
//
// Wraps `SMAppService.agent(plistName:)` registration of the
// NightBrain LaunchAgent so the 3 AM consolidation pass survives the
// main app being quit. Bridges the existing `NightBrainService` actor
// (which only runs while the app is alive) with launchd, so:
//
//   - When the app is foreground at 03:00, `NightBrainService` runs
//     in-process via `tokio-cron-scheduler` (no helper handoff).
//   - When the app has been quit, launchd wakes the
//     `NightBrainHelper` executable target at 03:00; helper does the
//     same consolidation work via the same Rust core, writes a
//     `last_run` UserDefaults entry, and exits.
//   - On next foreground launch, `fallbackIfStale()` checks
//     `last_consolidation_at` and fires the helper inline if the gap
//     exceeds 36 h (handles M-series laptop on-battery / lid-closed
//     deferrals that launchd may have skipped).
//
// xcodegen target wiring (the `NightBrainHelper` separate executable
// target inside the .app bundle's Contents/MacOS/) is a follow-up
// commit; without that target, `register()` returns
// `Operation not permitted` because the embedded plist references a
// missing program path. The Swift surface here is correct + ready
// even before the target lands.

@MainActor
public enum NightBrainScheduler {

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "NightBrainScheduler"
    )

    /// Bundled plist filename, relative to the app's
    /// `Contents/Library/LaunchAgents/` folder. Must match the
    /// `Label` inside the plist or `SMAppService.register()` fails.
    public static let plistName = "com.epistemos.nightbrain.plist"

    /// UserDefaults key carrying the timestamp of the most recent
    /// successful consolidation pass — used by `fallbackIfStale()`
    /// to detect launchd misses on M-series laptops.
    public static let lastRunKey = "com.epistemos.nightbrain.lastRun"

    /// Maximum acceptable gap between consolidation passes. If the
    /// last recorded pass is older than this, the next foreground
    /// launch fires the consolidation inline.
    public static let staleThreshold: TimeInterval = 36 * 3600

    private static var agent: SMAppService {
        SMAppService.agent(plistName: plistName)
    }

    // MARK: - Registration

    /// Register the LaunchAgent if it isn't already enabled.
    /// Idempotent — calling twice is a no-op when status is enabled.
    public static func register() throws {
        let current = agent.status
        if current == .enabled { return }
        if current == .requiresApproval {
            // User must approve in System Settings → Login Items
            log.info("NightBrain LaunchAgent requires approval — System Settings opens via SMAppService")
            return
        }
        do {
            try agent.register()
            log.info("NightBrain LaunchAgent registered")
        } catch {
            // Common failure: helper executable path doesn't exist
            // (xcodegen target not yet wired). Log + swallow so the
            // app keeps booting.
            log.error("NightBrain LaunchAgent register failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    /// Tear down the LaunchAgent (e.g. user disables NightBrain in
    /// Settings).
    public static func unregister() throws {
        guard agent.status == .enabled else { return }
        try agent.unregister()
        log.info("NightBrain LaunchAgent unregistered")
    }

    // MARK: - Status surfacing

    public enum Status: Sendable, Equatable {
        case notRegistered
        case requiresApproval
        case enabled
        case foundButNotRegistered

        var displayLabel: String {
            switch self {
            case .notRegistered:       return "Not registered"
            case .requiresApproval:    return "Requires approval in System Settings"
            case .enabled:             return "Enabled"
            case .foundButNotRegistered: return "Found in bundle, not registered"
            }
        }
    }

    public static func status() -> Status {
        switch agent.status {
        case .notRegistered:       return .notRegistered
        case .requiresApproval:    return .requiresApproval
        case .enabled:             return .enabled
        case .notFound:            return .foundButNotRegistered
        @unknown default:          return .notRegistered
        }
    }

    // MARK: - Last-run telemetry

    public static var lastRunDate: Date? {
        UserDefaults.standard.object(forKey: lastRunKey) as? Date
    }

    /// Helper executable + in-process scheduler both call this when
    /// they finish a consolidation pass. SwiftUI surfaces in Settings
    /// (`Last NightBrain: 03:14 AM yesterday`) bind to this value via
    /// `lastRunDate`.
    public static func recordSuccessfulRun(at date: Date = Date()) {
        UserDefaults.standard.set(date, forKey: lastRunKey)
    }

    // MARK: - Fallback for missed runs

    /// Called from `AppBootstrap` after launch finishes. If the
    /// last consolidation is older than 36 h (launchd may have
    /// deferred on a sleeping laptop) and `PowerGate` lets us run
    /// right now, fire the in-process consolidation inline.
    ///
    /// The actual consolidation work is owned by `NightBrainService`;
    /// this method is the trigger condition only.
    public static func shouldRunFallbackInline() -> Bool {
        guard !PowerGate.shouldDefer() else { return false }
        guard let last = lastRunDate else { return true }
        return Date().timeIntervalSince(last) > staleThreshold
    }
}
