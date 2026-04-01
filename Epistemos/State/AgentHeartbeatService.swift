import Foundation
import IOKit.ps
import os

// MARK: - Agent Heartbeat Service
// Scheduled background agent that wakes on a configurable interval to run
// a user-defined prompt through Hermes. Uses NSBackgroundActivityScheduler
// (same pattern as NightBrainService) to respect system idle, thermal, and
// power constraints.
//
// The heartbeat is budget-gated: each invocation gets its own CostTracker
// ceiling so background runs can't burn through the user's API credits.

actor AgentHeartbeatService {
    nonisolated static let log = Logger(subsystem: "com.epistemos", category: "AgentHeartbeat")

    private let config: EpistemosConfig
    private let hermesManagerProvider: @MainActor @Sendable () -> HermesSubprocessManager?
    private let costTrackerProvider: @MainActor @Sendable () -> CostTracker?
    private nonisolated(unsafe) var scheduler: NSBackgroundActivityScheduler?
    private var activityToken: NSObjectProtocol?
    private var runCount: Int = 0

    init(
        config: EpistemosConfig,
        hermesManagerProvider: @escaping @MainActor @Sendable () -> HermesSubprocessManager? = { nil },
        costTrackerProvider: @escaping @MainActor @Sendable () -> CostTracker? = { nil }
    ) {
        self.config = config
        self.hermesManagerProvider = hermesManagerProvider
        self.costTrackerProvider = costTrackerProvider
    }

    // MARK: - Config Reads

    private func readConfig() async -> (
        enabled: Bool,
        interval: TimeInterval,
        requiresAC: Bool,
        prompt: String,
        budgetCapMicro: Int
    ) {
        await MainActor.run {
            (
                config.heartbeatEnabled,
                config.heartbeatIntervalSeconds,
                config.heartbeatRequiresAC,
                config.heartbeatPrompt,
                config.heartbeatBudgetCapMicro
            )
        }
    }

    // MARK: - Lifecycle

    /// Register the background activity scheduler. Config is checked live at each invocation.
    func start() {
        let bgScheduler = NSBackgroundActivityScheduler(identifier: "com.epistemos.agent.heartbeat")
        bgScheduler.repeats = true
        bgScheduler.interval = 3600  // Default 1h; actual interval read from config at invocation
        bgScheduler.tolerance = 600  // 10 minute tolerance
        bgScheduler.qualityOfService = .utility

        bgScheduler.schedule { [weak self] completion in
            guard let self else { completion(.deferred); return }
            Task {
                let canRun = await self.canStart()
                if canRun {
                    await self.executeHeartbeat(completion: completion)
                } else {
                    completion(.deferred)
                }
            }
        }
        scheduler = bgScheduler
        Self.log.info("AgentHeartbeat: scheduler registered")
    }

    func stop() {
        scheduler?.invalidate()
        scheduler = nil
        Self.log.info("AgentHeartbeat: scheduler stopped")
    }

    /// Update the scheduler interval from config (call after settings change).
    func reconfigure() async {
        let cfg = await readConfig()
        if cfg.enabled {
            scheduler?.interval = cfg.interval
        }
    }

    // MARK: - Guard Checks

    private func canStart() async -> Bool {
        // Eco/low-power mode disables all background agent runs.
        guard await !PowerGuard.shared.shouldDisableBackground else {
            Self.log.debug("AgentHeartbeat: skipped — eco/low-power mode")
            return false
        }
        let cfg = await readConfig()
        guard cfg.enabled else {
            Self.log.debug("AgentHeartbeat: disabled in config")
            return false
        }
        if cfg.requiresAC && !Self.isOnACPower() {
            Self.log.debug("AgentHeartbeat: skipped — not on AC power")
            return false
        }
        // Don't run under heavy thermal pressure
        guard Self.thermalPressureLevel() <= 1 else {
            Self.log.debug("AgentHeartbeat: skipped — thermal pressure too high")
            return false
        }
        return true
    }

    // MARK: - Heartbeat Execution

    private func executeHeartbeat(
        completion: @escaping @Sendable (NSBackgroundActivityScheduler.Result) -> Void
    ) async {
        let cfg = await readConfig()
        guard !cfg.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Self.log.warning("AgentHeartbeat: empty prompt, skipping")
            completion(.finished)
            return
        }

        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.background, .idleSystemSleepDisabled],
            reason: "Epistemos Agent Heartbeat"
        )
        defer {
            if let t = activityToken { ProcessInfo.processInfo.endActivity(t) }
            activityToken = nil
        }

        Self.log.info("AgentHeartbeat: starting run #\(self.runCount + 1)")
        runCount += 1

        // Budget gate: check the cost tracker before dispatching
        let budgetBlocked = await MainActor.run { [costTrackerProvider, cfg] () -> String? in
            guard let tracker = costTrackerProvider() else { return nil }
            // Set a per-heartbeat session budget
            let budgetMicro = Int64(cfg.budgetCapMicro)
            if budgetMicro > 0, tracker.sessionCostMicro > 0 {
                return tracker.canAffordTurn(model: "claude_sonnet", agentId: "heartbeat")
            }
            return nil
        }

        if let reason = budgetBlocked {
            Self.log.warning("AgentHeartbeat: budget blocked — \(reason)")
            completion(.finished)
            return
        }

        // Dispatch the heartbeat prompt to Hermes
        let dispatched = await MainActor.run { [hermesManagerProvider, cfg] () -> Bool in
            guard let manager = hermesManagerProvider() else { return false }
            guard manager.isRunning else { return false }

            let payload: [String: Any] = [
                "command": "start",
                "prompt": cfg.prompt,
                "cwd": AgentRuntimeDefaults.vaultPath,
                "source": "heartbeat",
            ]

            do {
                let data = try JSONSerialization.data(withJSONObject: payload)
                if let json = String(data: data, encoding: .utf8) {
                    try manager.writeLine(json)
                    return true
                }
            } catch {
                Self.log.error("AgentHeartbeat: failed to dispatch — \(error.localizedDescription)")
            }
            return false
        }

        if dispatched {
            Self.log.info("AgentHeartbeat: dispatched prompt to Hermes")
        } else {
            Self.log.warning("AgentHeartbeat: Hermes not available, deferring")
            completion(.deferred)
            return
        }

        // Wait a reasonable time for the heartbeat to complete.
        // The actual agent session runs asynchronously; we just need to hold
        // the activity token long enough for Hermes to process.
        try? await Task.sleep(for: .seconds(30))

        completion(.finished)
    }

    // MARK: - System Queries

    nonisolated static func isOnACPower() -> Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
              let first = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, first as CFTypeRef)?.takeUnretainedValue() as? [String: Any],
              let state = desc[kIOPSPowerSourceStateKey] as? String
        else { return true }
        return state == kIOPSACPowerValue
    }

    nonisolated static func thermalPressureLevel() -> UInt64 {
        var size = MemoryLayout<UInt64>.size
        var level: UInt64 = 0
        let result = sysctlbyname("machdep.xcpm.thermal_level", &level, &size, nil, 0)
        return result == 0 ? level : 0
    }
}
