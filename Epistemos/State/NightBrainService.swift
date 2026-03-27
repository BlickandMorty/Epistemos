import AppKit
import Foundation
import IOKit.ps
import os

// MARK: - Night Brain Service
// Background maintenance runtime that runs deterministic jobs when idle.
// Semantic intelligence (summarization, clustering, embedding drift) is
// explicitly deferred until model-stack unification.
//
// Config is read LIVE via @MainActor hop at each scheduler invocation,
// so toggling Night Brain off in Settings takes effect immediately.
//
// Resume: on each invocation, we look for the most recent interrupted run
// and resume from its checkpoint rather than creating a fresh run.
//
// DEFERRED(model-stack): Night Brain autonomous summarization
// DEFERRED(model-stack): Leiden community detection + orphan scoring
// DEFERRED(model-stack): Embedding-based digest assembly

actor NightBrainService {
    nonisolated static let log = Logger(subsystem: "com.epistemos", category: "NightBrain")

    enum Job: String, CaseIterable, Sendable {
        case eventStoreCheckpointVacuum = "event_store_checkpoint_vacuum"
        case dedupeArtifacts = "dedupe_artifacts"
        case workspaceSnapshotCompaction = "workspace_snapshot_compaction"
        case maintenanceLog = "maintenance_log"
    }

    private let config: EpistemosConfig
    private let storeProvider: @Sendable () -> EventStore?
    private nonisolated(unsafe) var scheduler: NSBackgroundActivityScheduler?
    private var activityToken: NSObjectProtocol?
    private var currentRunId: Int64?

    init(
        config: EpistemosConfig,
        storeProvider: @escaping @Sendable () -> EventStore? = { EventStore.shared }
    ) {
        self.config = config
        self.storeProvider = storeProvider
    }

    // MARK: - Config Reads

    private func readConfig() async -> (enabled: Bool, requiresAC: Bool, minIdleSeconds: Double) {
        await MainActor.run {
            (config.nightBrainEnabled, config.nightBrainRequiresAC, config.nightBrainMinIdleSeconds)
        }
    }

    // MARK: - Lifecycle

    /// Always registers the scheduler. Config is checked live at each invocation.
    func start() {
        let bgScheduler = NSBackgroundActivityScheduler(identifier: "com.epistemos.nightbrain")
        bgScheduler.repeats = true
        bgScheduler.interval = 86400
        bgScheduler.tolerance = 3600
        bgScheduler.qualityOfService = .background

        bgScheduler.schedule { [weak self] completion in
            guard let self else { completion(.deferred); return }
            Task {
                let canStart = await self.canStart()
                if canStart {
                    await self.executePipeline(completion: completion)
                } else {
                    completion(.deferred)
                }
            }
        }
        scheduler = bgScheduler
        Self.log.info("NightBrain: scheduler registered")
    }

    func stop() {
        scheduler?.invalidate()
        scheduler = nil
    }

    // MARK: - Guard Checks

    private func canStart() async -> Bool {
        let cfg = await readConfig()
        guard cfg.enabled else { return false }
        if cfg.requiresAC && !Self.isOnACPower() { return false }
        guard Self.userIdleSeconds() > cfg.minIdleSeconds else { return false }
        guard Self.thermalPressureLevel() <= 1 else { return false }
        return true
    }

    func canContinue(idleSeconds: Double, thermalPressureLevel: UInt64, onACPower: Bool) async -> Bool {
        let cfg = await readConfig()
        guard cfg.enabled else { return false }
        if cfg.requiresAC && !onACPower { return false }
        guard idleSeconds > cfg.minIdleSeconds else { return false }
        guard thermalPressureLevel <= 2 else { return false }
        return true
    }

    private func canContinue() async -> Bool {
        await canContinue(
            idleSeconds: Self.userIdleSeconds(),
            thermalPressureLevel: Self.thermalPressureLevel(),
            onACPower: Self.isOnACPower()
        )
    }

    // MARK: - Pipeline Execution

    private func executePipeline(completion: @escaping @Sendable (NSBackgroundActivityScheduler.Result) -> Void) async {
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.background, .idleSystemSleepDisabled, .automaticTerminationDisabled],
            reason: "Epistemos Night Brain maintenance"
        )
        defer {
            if let t = activityToken { ProcessInfo.processInfo.endActivity(t) }
            activityToken = nil
        }

        // Try to resume the most recent interrupted run, or create a new one.
        // Resume state is read from the checkpoint TABLE (not the runs table),
        // so it's durable even if the process crashed between writing a checkpoint
        // and updating the run record.
        let (runId, alreadyCompleted) = { () -> (Int64?, [String]) in
            guard let store = storeProvider() else { return (nil, []) }
            if let interrupted = store.mostRecentInterruptedRun() {
                let completed = store.checkpointedJobTypes(runId: interrupted)
                store.updateNightBrainRun(id: interrupted, status: "running", completedJobs: completed)
                return (interrupted, completed)
            }
            return (store.insertNightBrainRun(status: "running", triggerReason: "scheduler"), [])
        }()

        guard let runId else {
            completion(.deferred)
            return
        }
        currentRunId = runId

        var completedJobs = alreadyCompleted

        for job in Job.allCases {
            if completedJobs.contains(job.rawValue) {
                continue
            }

            guard await canContinue() else {
                storeProvider()?.updateNightBrainRun(
                    id: runId, status: "interrupted", completedJobs: completedJobs
                )
                completion(.deferred)
                return
            }

            await executeJob(job)
            completedJobs.append(job.rawValue)

            // Write a checkpoint row for EVERY completed job — this is the
            // durable resume record. The runs table is updated too for query convenience.
            guard let store = storeProvider() else { continue }
            store.insertCheckpoint(
                runId: runId, jobType: job.rawValue,
                data: "{\"completed_at\": \(Date().timeIntervalSince1970)}"
            )
            store.updateNightBrainRun(
                id: runId, status: "running", completedJobs: completedJobs
            )
        }

        storeProvider()?.updateNightBrainRun(
            id: runId, status: "completed", completedJobs: completedJobs,
            completedAt: Date().timeIntervalSince1970
        )
        Self.log.info("NightBrain: pipeline completed (\(completedJobs.count) jobs)")
        completion(.finished)
    }

    // MARK: - Job Execution

    private func executeJob(_ job: Job) async {
        Self.log.info("NightBrain: executing \(job.rawValue, privacy: .public)")

        switch job {
        case .eventStoreCheckpointVacuum:
            storeProvider()?.walCheckpointVacuum()
            try? await Task.sleep(nanoseconds: 100_000_000)

        case .dedupeArtifacts:
            storeProvider()?.deduplicateArtifacts()

        case .workspaceSnapshotCompaction:
            storeProvider()?.compactSnapshots(olderThanDays: 30)

        case .maintenanceLog:
            // No-op: the checkpoint is written by the pipeline loop after every job.
            // This job exists as a terminal marker confirming the full pipeline completed.
            break
        }
    }

    // MARK: - System State Queries

    nonisolated static func userIdleSeconds() -> Double {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
    }

    nonisolated static func isOnACPower() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [Any],
              !sources.isEmpty else { return true }
        for source in sources {
            if let desc = IOPSGetPowerSourceDescription(info, source as CFTypeRef)?.takeUnretainedValue() as? [String: Any],
               let powerSource = desc[kIOPSPowerSourceStateKey] as? String {
                return powerSource == kIOPSACPowerValue
            }
        }
        return true
    }

    nonisolated static func thermalPressureLevel() -> UInt64 {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return 0
        case .fair: return 1
        case .serious: return 2
        case .critical: return 3
        @unknown default: return 0
        }
    }
}
