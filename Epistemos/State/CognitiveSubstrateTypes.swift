import Foundation

// MARK: - Cognitive Substrate Domain Types
// Plain Sendable structs for the four cognitive substrates.
// No class overhead, no reference counting in hot paths.

struct CapturedArtifact: Codable, Sendable {
    var id: Int64?
    var sourceBundleId: String
    var appName: String
    var windowTitle: String?
    var url: String?
    var textContent: String
    var capturedAt: Double   // Unix timestamp (seconds)
    var dedupeHash: String
    var ocrUsed: Bool
}

struct FrictionWindow: Codable, Sendable {
    var id: Int64?
    var noteId: String
    var sessionId: String
    var windowStart: Double   // Unix timestamp (seconds)
    var windowEnd: Double
    var pauseRate: Double
    var meanPauseDurationMs: Double
    var meanBurstLengthChars: Double
    var burstLengthCV: Double
    var deletionDensity: Double
    var regressionFrequency: Double
    var frictionScore: Double
}

struct NightBrainRun: Codable, Sendable {
    var id: Int64?
    var startedAt: Double     // Unix timestamp (seconds)
    var completedAt: Double?
    var status: String        // "running", "completed", "interrupted", "deferred"
    var jobsCompleted: String // JSON array of job type strings
    var triggerReason: String?
}

struct NightBrainCheckpoint: Codable, Sendable {
    var id: Int64?
    var runId: Int64
    var jobType: String
    var checkpointData: String // JSON payload per job type
    var recordedAt: Double     // Unix timestamp (seconds)
}

// MARK: - Editor Telemetry

struct EditorTelemetryEvent: Sendable {
    enum Kind: Sendable {
        case insertion(count: Int)
        case deletion(count: Int)
        case cursorMove(delta: Int)
        case pauseEnd
        case aiStreamEnd
    }

    let noteId: String
    let kind: Kind
    let timestampMs: Int64
}

// MARK: - Ring Buffer

struct RingBuffer<T: Sendable>: @unchecked Sendable {
    private var storage: [T?]
    private var writeIndex: Int = 0
    private(set) var count: Int = 0
    let capacity: Int

    nonisolated init(capacity: Int) {
        self.capacity = capacity
        self.storage = Array(repeating: nil, count: capacity)
    }

    nonisolated mutating func push(_ value: T) {
        storage[writeIndex] = value
        writeIndex = (writeIndex + 1) % capacity
        count = min(count + 1, capacity)
    }

    nonisolated var first: T? {
        guard count > 0 else { return nil }
        let start = count < capacity ? 0 : writeIndex
        return storage[start]
    }

    nonisolated var last: T? {
        guard count > 0 else { return nil }
        let index = (writeIndex - 1 + capacity) % capacity
        return storage[index]
    }

    nonisolated func toArray() -> [T] {
        guard count > 0 else { return [] }
        let start = count < capacity ? 0 : writeIndex
        return (0..<count).compactMap { storage[(start + $0) % capacity] }
    }

    nonisolated mutating func reset() {
        for index in storage.indices {
            storage[index] = nil
        }
        writeIndex = 0
        count = 0
    }
}
