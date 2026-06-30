import Foundation

nonisolated enum FoundationSafety {
    static func userApplicationSupportDirectory() -> URL {
        FileManager.default.temporaryDirectory
    }
}

nonisolated enum MutationOpLogProjectionWorker {
    static func databaseURL(applicationSupportDirectory: URL) -> URL {
        applicationSupportDirectory
            .appendingPathComponent("epistemos-oplog-smoke")
            .appendingPathExtension("sqlite")
    }
}

nonisolated enum MutationOpLogProjector {
    static let projectionKey = "mutation_projection"
}

nonisolated public enum RuntimePlane: String, Codable, Hashable, Sendable {
    case data
    case control
    case verification
}

nonisolated public enum ResidencyTier: String, Codable, Hashable, Sendable {
    case hot
    case warm
    case cold
}

enum ActivityEventKind: Codable {
    case noteEdited(pageId: String, title: String, changed: Int, total: Int)
    case noteOpened(pageId: String, title: String)
    case noteClosed(pageId: String, title: String)
    case chatMessageSent(chatId: String, snippet: String)
}

nonisolated struct VaultRecallTrace: Codable, Hashable, Sendable {}

struct ReasoningTrajectoryMetricsFFI: Sendable {
    let classification: String
    let displacement: Double
    let pathLength: Double
    let curvatureRatio: Double
    let loopCount: Int
    let errorCount: Int
    let totalCalls: Int
    let efficiency: Double
}

struct CapturedArtifact: Codable, Sendable {
    let sourceBundleId: String
    let appName: String
    let windowTitle: String?
    let url: String?
    let textContent: String
    let capturedAt: TimeInterval
    let dedupeHash: String
    let ocrUsed: Bool
}

struct FrictionWindow: Codable, Sendable, Equatable {
    let id: Int64
    let noteId: String
    let sessionId: String
    let windowStart: TimeInterval
    let windowEnd: TimeInterval
    let pauseRate: Double
    let meanPauseDurationMs: Double
    let meanBurstLengthChars: Double
    let burstLengthCV: Double
    let deletionDensity: Double
    let regressionFrequency: Double
    let frictionScore: Double
}

nonisolated enum AppDataRetentionPolicy {
    struct Snapshot: Sendable, Equatable {
        var eventStorePolicy: EventStore.RetentionPolicy {
            EventStore.RetentionPolicy(
                timeMachineRetentionDays: 30,
                timeMachineMaxSnapshots: 60,
                eventLogRetentionDays: 30,
                captureArtifactRetentionDays: 7,
                auditLogRetentionDays: 30
            )
        }
    }

    static func current(defaults: UserDefaults = .standard) -> Snapshot {
        Snapshot()
    }
}
