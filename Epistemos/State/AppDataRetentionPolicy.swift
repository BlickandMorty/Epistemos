import Foundation

// 2026-05-23: explicit `nonisolated` because the Epistemos target has
// `.defaultIsolation(MainActor.self)` and this is a pure-value computation
// over UserDefaults — needs to be callable from background queues (SQLite
// retention sweeps inside EventStore.saveSnapshot, etc.).
nonisolated enum AppDataRetentionPolicy {
    static let timeMachineRetentionDaysKey = "epistemos.retention.timeMachineDays"
    static let timeMachineMaxSnapshotsKey = "epistemos.retention.timeMachineMaxSnapshots"
    static let eventLogRetentionDaysKey = "epistemos.retention.eventLogDays"
    static let captureArtifactRetentionDaysKey = "epistemos.retention.captureArtifactDays"
    static let auditLogRetentionDaysKey = "epistemos.retention.auditLogDays"
    static let savedWorkspaceLimitKey = "epistemos.retention.savedWorkspaceLimit"

    static let defaultTimeMachineRetentionDays = 30
    static let defaultTimeMachineMaxSnapshots = 60
    static let defaultEventLogRetentionDays = 30
    static let defaultCaptureArtifactRetentionDays = 7
    static let defaultAuditLogRetentionDays = 30
    static let defaultSavedWorkspaceLimit = 25

    static let dayOptions = [7, 30, 90, 365, 0]

    struct Snapshot: Sendable, Equatable {
        var timeMachineRetentionDays: Int
        var timeMachineMaxSnapshots: Int
        var eventLogRetentionDays: Int
        var captureArtifactRetentionDays: Int
        var auditLogRetentionDays: Int
        var savedWorkspaceLimit: Int

        var eventStorePolicy: EventStore.RetentionPolicy {
            EventStore.RetentionPolicy(
                timeMachineRetentionDays: timeMachineRetentionDays,
                timeMachineMaxSnapshots: timeMachineMaxSnapshots,
                eventLogRetentionDays: eventLogRetentionDays,
                captureArtifactRetentionDays: captureArtifactRetentionDays,
                auditLogRetentionDays: auditLogRetentionDays
            )
        }
    }

    static func current(defaults: UserDefaults = FoundationSafety.runtimeUserDefaults) -> Snapshot {
        Snapshot(
            timeMachineRetentionDays: boundedDays(
                defaults.integerOrDefault(forKey: timeMachineRetentionDaysKey, defaultValue: defaultTimeMachineRetentionDays)
            ),
            timeMachineMaxSnapshots: boundedLimit(
                defaults.integerOrDefault(forKey: timeMachineMaxSnapshotsKey, defaultValue: defaultTimeMachineMaxSnapshots),
                minimum: 1,
                maximum: 500
            ),
            eventLogRetentionDays: boundedDays(
                defaults.integerOrDefault(forKey: eventLogRetentionDaysKey, defaultValue: defaultEventLogRetentionDays)
            ),
            captureArtifactRetentionDays: boundedDays(
                defaults.integerOrDefault(forKey: captureArtifactRetentionDaysKey, defaultValue: defaultCaptureArtifactRetentionDays)
            ),
            auditLogRetentionDays: boundedDays(
                defaults.integerOrDefault(forKey: auditLogRetentionDaysKey, defaultValue: defaultAuditLogRetentionDays)
            ),
            savedWorkspaceLimit: boundedLimit(
                defaults.integerOrDefault(forKey: savedWorkspaceLimitKey, defaultValue: defaultSavedWorkspaceLimit),
                minimum: 0,
                maximum: 200
            )
        )
    }

    static func label(forDays days: Int) -> String {
        switch days {
        case 0:
            return "Forever"
        case 1:
            return "1 day"
        default:
            return "\(days) days"
        }
    }

    static func savedWorkspaceLimitLabel(_ limit: Int) -> String {
        limit <= 0 ? "Unlimited" : "\(limit)"
    }

    static func summaryLabel(eventSummary: EventStore.RetentionPruneSummary, workspaceDeletes: Int) -> String {
        let total = eventSummary.totalDeleted + workspaceDeletes
        guard total > 0 else {
            return "Retention is already within the selected limits."
        }
        return "Removed \(total) old item\(total == 1 ? "" : "s") from local history."
    }

    private static func boundedDays(_ value: Int) -> Int {
        if value == 0 {
            return 0
        }
        return min(max(value, 1), 3650)
    }

    private static func boundedLimit(_ value: Int, minimum: Int, maximum: Int) -> Int {
        min(max(value, minimum), maximum)
    }
}

private extension UserDefaults {
    // Must be nonisolated because AppDataRetentionPolicy is nonisolated
    // and calls this from background queues. Without the marker, the
    // Epistemos target's `.defaultIsolation(MainActor.self)` makes this
    // implicitly @MainActor and the enum's call sites fail to compile.
    nonisolated func integerOrDefault(forKey key: String, defaultValue: Int) -> Int {
        object(forKey: key) == nil ? defaultValue : integer(forKey: key)
    }
}
