import Foundation
import os

// MARK: - Paperclip Heartbeat Clock

/// Lightweight liveness pulse for the Paperclip WAL store.
///
/// The clock records one immediate heartbeat and then repeats at the configured
/// cadence. It deliberately does not touch model, Metal, or retrieval paths.
actor PaperclipHeartbeatClock {
    static let defaultAgentId = "epistemos.paperclip.heartbeat"
    static let defaultInterval: Duration = .seconds(120)

    private static let logger = Logger(
        subsystem: "com.epistemos.state",
        category: "PaperclipHeartbeat"
    )

    private let store: PaperclipStateStore
    private let agentId: String
    private let interval: Duration
    private var task: Task<Void, Never>?

    var isRunning: Bool {
        task != nil
    }

    init(
        store: PaperclipStateStore,
        agentId: String = PaperclipHeartbeatClock.defaultAgentId,
        interval: Duration = PaperclipHeartbeatClock.defaultInterval
    ) {
        self.store = store
        self.agentId = agentId
        self.interval = interval
    }

    func start() {
        guard task == nil else { return }

        let store = self.store
        let agentId = self.agentId
        let interval = self.interval

        task = Task(priority: .utility) {
            var scheduledAt = Date()
            while !Task.isCancelled {
                await Self.recordHeartbeat(
                    store: store,
                    agentId: agentId,
                    scheduledAt: scheduledAt
                )

                do {
                    try await Task.sleep(for: interval)
                } catch {
                    break
                }
                scheduledAt = Date()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func tickOnce(scheduledAt: Date = Date()) async {
        await Self.recordHeartbeat(
            store: store,
            agentId: agentId,
            scheduledAt: scheduledAt
        )
    }

    private nonisolated static func recordHeartbeat(
        store: PaperclipStateStore,
        agentId: String,
        scheduledAt: Date
    ) async {
        let executedAt = Date()
        let durationStartedAt = Date()
        let durationMs = max(
            0,
            Int(Date().timeIntervalSince(durationStartedAt) * 1000.0)
        )
        let heartbeat = CronHeartbeat(
            agentId: agentId,
            scheduledAt: scheduledAt,
            executedAt: executedAt,
            durationMs: durationMs,
            success: true,
            errorMessage: nil
        )

        do {
            try await store.recordHeartbeat(heartbeat)
        } catch {
            logger.error(
                "Paperclip heartbeat record failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
