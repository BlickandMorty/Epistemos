import Foundation
import os

// MARK: - Unified Logging
// Wraps os.Logger for structured, privacy-aware logging.
// Zero-cost when not observed — messages are compiled out at runtime
// unlike print() which always evaluates and writes to stdout.
//
// The enum is nonisolated so loggers can be accessed from @Sendable closures,
// nonisolated methods, and actors. Logger is Sendable so this is safe.
// The subsystem uses a fixed string to avoid MainActor-isolated Bundle access.

nonisolated enum Log {
    private static let subsystem = "com.epistemos"

    /// General app lifecycle events
    static let app = Logger(subsystem: subsystem, category: "app")

    /// Signpost log for app lifecycle / launch instrumentation
    static let appPerf = OSSignposter(subsystem: subsystem, category: "app-perf")

    /// Database / SwiftData operations
    static let db = Logger(subsystem: subsystem, category: "database")

    /// Chat & LLM pipeline
    static let pipeline = Logger(subsystem: subsystem, category: "pipeline")

    /// Notes & vault file operations
    static let notes = Logger(subsystem: subsystem, category: "notes")

    /// Signpost log for note editor instrumentation
    static let notesPerf = OSSignposter(subsystem: subsystem, category: "notes-perf")

    /// Vault file system access
    static let vault = Logger(subsystem: subsystem, category: "vault")

    /// Signpost log for vault attach/import/export instrumentation
    static let vaultPerf = OSSignposter(subsystem: subsystem, category: "vault-perf")

    /// Learning protocol & scheduler
    static let learning = Logger(subsystem: subsystem, category: "learning")

    /// Research service (Semantic Scholar, etc.)
    static let research = Logger(subsystem: subsystem, category: "research")

    /// Security & keychain operations
    static let security = Logger(subsystem: subsystem, category: "security")

    /// Engine services
    static let engine = Logger(subsystem: subsystem, category: "engine")

    /// Graph rendering, physics, and performance instrumentation
    static let graph = Logger(subsystem: subsystem, category: "graph")

    /// Signpost log for Instruments integration (graph performance)
    static let graphPerf = OSSignposter(subsystem: subsystem, category: "graph-perf")

    /// Graph build/fetch/persist failures
    static let graphBuilder = Logger(subsystem: subsystem, category: "GraphBuilder")

    /// Persistence bootstrap, migration, and SwiftData recovery
    static let persistence = Logger(subsystem: subsystem, category: "Persistence")

    /// Swift ↔ Rust / FFI boundary diagnostics
    static let ffiBoundary = Logger(subsystem: subsystem, category: "FFIBoundary")

    /// Durable runtime issue reporting
    static let diagnostics = Logger(subsystem: subsystem, category: "Diagnostics")
}

nonisolated enum RuntimeDiagnosticSeverity: String, Codable, Sendable, Equatable {
    case debug
    case info
    case warning
    case error
    case fault

    var rank: Int {
        switch self {
        case .debug: 0
        case .info: 1
        case .warning: 2
        case .error: 3
        case .fault: 4
        }
    }

    var isIssueSeverity: Bool {
        self == .warning || self == .error || self == .fault
    }

    static func mergedSeverity(
        _ lhs: RuntimeDiagnosticSeverity,
        _ rhs: RuntimeDiagnosticSeverity
    ) -> RuntimeDiagnosticSeverity {
        lhs.rank >= rhs.rank ? lhs : rhs
    }
}

nonisolated struct RuntimeDiagnosticRecord: Codable, Sendable {
    let timestamp: String
    let severity: RuntimeDiagnosticSeverity
    let category: String
    let message: String
    let metadata: [String: String]
    let sourceFile: String
    let sourceFunction: String
    let sourceLine: UInt
}

nonisolated struct RuntimeLifecycleEvent: Codable, Sendable {
    let timestamp: String
    let name: String
    let metadata: [String: String]
}

nonisolated struct RuntimeDiagnosticIssueSummary: Codable, Sendable {
    let fingerprint: String
    let category: String
    let message: String
    let highestSeverity: RuntimeDiagnosticSeverity
    let count: Int
    let firstSeenTimestamp: String
    let lastSeenTimestamp: String
    let latestMetadata: [String: String]
    let sourceFile: String
    let sourceFunction: String
    let sourceLine: UInt
}

nonisolated struct RuntimeDiagnosticIssueIndex: Codable, Sendable {
    let generatedAt: String
    let sessionId: String?
    let issues: [RuntimeDiagnosticIssueSummary]
}

nonisolated struct RuntimeDiagnosticSessionSnapshot: Codable, Sendable {
    let sessionId: String
    let startedAt: String
    let launchMetadata: [String: String]
    let lastUpdatedAt: String
    let endedAt: String?
    let severityCounts: [String: Int]
    let lifecycleEvents: [RuntimeLifecycleEvent]
    let latestIssueFingerprint: String?
    let latestIssueCategory: String?
    let latestIssueMessage: String?
}

nonisolated enum RuntimeDiagnostics {
    private static let directoryLock = NSLock()
    private static let defaultMaxRetainedFiles = 30
    private static let maxLifecycleEvents = 40
    nonisolated(unsafe) private static var currentSessionID: String?
    nonisolated(unsafe) private static var currentSessionLaunchMetadata: [String: String] = [:]

    static func directoryURL(
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        let root = baseDirectory ?? FoundationSafety.userApplicationSupportDirectory(fileManager: fileManager)
        let directory = root
            .appendingPathComponent("Epistemos", isDirectory: true)
            .appendingPathComponent("runtime_diagnostics", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func crashReportsDirectoryURL(
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        let root = baseDirectory ?? FoundationSafety.userApplicationSupportDirectory(fileManager: fileManager)
        let directory = root
            .appendingPathComponent("Epistemos", isDirectory: true)
            .appendingPathComponent("crash_reports", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func issueIndexURL(
        baseDirectory: URL? = nil,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) throws -> URL {
        let directory = try directoryURL(baseDirectory: baseDirectory, fileManager: fileManager)
        return directory.appendingPathComponent(
            "\(dayStamp(for: now))-summary.json",
            isDirectory: false
        )
    }

    static func currentSessionURL(
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        let directory = try directoryURL(baseDirectory: baseDirectory, fileManager: fileManager)
        return directory.appendingPathComponent("current_session.json", isDirectory: false)
    }

    static func logStorageLocations(fileManager: FileManager = .default) {
        do {
            let diagnosticsDirectory = try directoryURL(fileManager: fileManager)
            let crashReportsDirectory = try crashReportsDirectoryURL(fileManager: fileManager)
            let issueSummaryURL = try issueIndexURL(fileManager: fileManager)
            let currentSessionSnapshotURL = try currentSessionURL(fileManager: fileManager)
            Log.diagnostics.info(
                "Runtime diagnostics directory: \(diagnosticsDirectory.path, privacy: .public)"
            )
            Log.diagnostics.info(
                "Crash diagnostics directory: \(crashReportsDirectory.path, privacy: .public)"
            )
            Log.diagnostics.info(
                "Runtime issue summary: \(issueSummaryURL.path, privacy: .public)"
            )
            Log.diagnostics.info(
                "Current runtime session: \(currentSessionSnapshotURL.path, privacy: .public)"
            )
        } catch {
            Log.diagnostics.error(
                "Failed to resolve diagnostics storage locations: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    @discardableResult
    static func recordSessionStart(
        metadata: [String: String],
        baseDirectory: URL? = nil,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) -> URL? {
        directoryLock.lock()
        defer { directoryLock.unlock() }

        let sessionID = metadata["sessionID"] ?? UUID().uuidString
        currentSessionID = sessionID

        var mergedMetadata = metadata
        mergedMetadata["sessionID"] = sessionID
        currentSessionLaunchMetadata = mergedMetadata.filter { $0.key != "sessionID" }

        return recordLocked(
            .info,
            category: "Diagnostics",
            message: "session_started",
            metadata: mergedMetadata,
            baseDirectory: baseDirectory,
            now: now,
            maxRetainedFiles: defaultMaxRetainedFiles,
            fileManager: fileManager,
            file: #fileID,
            function: #function,
            line: #line
        )
    }

    @discardableResult
    static func recordSessionEnd(
        reason: String,
        metadata: [String: String] = [:],
        baseDirectory: URL? = nil,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) -> URL? {
        var mergedMetadata = metadata
        mergedMetadata["reason"] = reason
        return record(
            .info,
            category: "Diagnostics",
            message: "session_ended",
            metadata: mergedMetadata,
            baseDirectory: baseDirectory,
            now: now,
            fileManager: fileManager
        )
    }

    @discardableResult
    static func recordLifecycleEvent(
        _ name: String,
        metadata: [String: String] = [:],
        baseDirectory: URL? = nil,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) -> URL? {
        var mergedMetadata = metadata
        mergedMetadata["name"] = name
        return record(
            .info,
            category: "Diagnostics",
            message: "lifecycle_event",
            metadata: mergedMetadata,
            baseDirectory: baseDirectory,
            now: now,
            fileManager: fileManager
        )
    }

    @discardableResult
    static func record(
        _ severity: RuntimeDiagnosticSeverity,
        category: String,
        message: String,
        metadata: [String: String] = [:],
        baseDirectory: URL? = nil,
        now: Date = Date(),
        maxRetainedFiles: Int = defaultMaxRetainedFiles,
        fileManager: FileManager = .default,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> URL? {
        directoryLock.lock()
        defer { directoryLock.unlock() }

        return recordLocked(
            severity,
            category: category,
            message: message,
            metadata: metadata,
            baseDirectory: baseDirectory,
            now: now,
            maxRetainedFiles: maxRetainedFiles,
            fileManager: fileManager,
            file: file,
            function: function,
            line: line
        )
    }

    @discardableResult
    private static func recordLocked(
        _ severity: RuntimeDiagnosticSeverity,
        category: String,
        message: String,
        metadata: [String: String],
        baseDirectory: URL?,
        now: Date,
        maxRetainedFiles: Int,
        fileManager: FileManager,
        file: String,
        function: String,
        line: UInt
    ) -> URL? {
        do {
            let directory = try directoryURL(baseDirectory: baseDirectory, fileManager: fileManager)
            let logURL = directory.appendingPathComponent("\(dayStamp(for: now)).ndjson", isDirectory: false)
            try ensureFileExists(at: logURL, fileManager: fileManager)
            let sessionID = ensureSessionIdentifierLocked()
            var combinedMetadata = metadata
            combinedMetadata["sessionID"] = combinedMetadata["sessionID"] ?? sessionID

            let record = RuntimeDiagnosticRecord(
                timestamp: iso8601String(from: now),
                severity: severity,
                category: category,
                message: message,
                metadata: combinedMetadata,
                sourceFile: file,
                sourceFunction: function,
                sourceLine: line
            )
            emitUnifiedLog(for: record)
            try append(encodedLine(for: record), to: logURL)
            try updateSessionSnapshotLocked(
                with: record,
                baseDirectory: baseDirectory,
                fileManager: fileManager
            )
            try ensureIssueIndexExistsLocked(
                baseDirectory: baseDirectory,
                now: now,
                fileManager: fileManager
            )
            if severity.isIssueSeverity {
                try updateIssueIndexLocked(
                    with: record,
                    baseDirectory: baseDirectory,
                    now: now,
                    fileManager: fileManager
                )
            }
            try pruneOldFilesIfNeeded(
                in: directory,
                maxRetainedFiles: maxRetainedFiles,
                fileManager: fileManager
            )
            return logURL
        } catch {
            Log.diagnostics.error(
                "Failed to persist runtime diagnostic for \(category, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private static func updateSessionSnapshotLocked(
        with record: RuntimeDiagnosticRecord,
        baseDirectory: URL?,
        fileManager: FileManager
    ) throws {
        let sessionID = ensureSessionIdentifierLocked()
        let sessionURL = try currentSessionURL(baseDirectory: baseDirectory, fileManager: fileManager)
        let existing = try loadSessionSnapshotLocked(
            at: sessionURL,
            fileManager: fileManager
        )

        let launchMetadata: [String: String]
        let startedAt: String
        if record.message == "session_started" {
            launchMetadata = record.metadata.filter { $0.key != "sessionID" }
            startedAt = record.timestamp
            currentSessionLaunchMetadata = launchMetadata
            currentSessionID = record.metadata["sessionID"] ?? sessionID
        } else {
            launchMetadata = existing?.launchMetadata ?? currentSessionLaunchMetadata
            startedAt = existing?.startedAt ?? record.timestamp
        }

        var severityCounts = existing?.severityCounts ?? [:]
        severityCounts[record.severity.rawValue, default: 0] += 1

        var lifecycleEvents = existing?.lifecycleEvents ?? []
        if record.category == "Diagnostics",
           record.message == "lifecycle_event" {
            let name = record.metadata["name"] ?? "unknown"
            let metadata = record.metadata.filter { $0.key != "name" && $0.key != "sessionID" }
            lifecycleEvents.append(
                RuntimeLifecycleEvent(
                    timestamp: record.timestamp,
                    name: name,
                    metadata: metadata
                )
            )
            if lifecycleEvents.count > maxLifecycleEvents {
                lifecycleEvents.removeFirst(lifecycleEvents.count - maxLifecycleEvents)
            }
        }

        let latestIssueFingerprint: String?
        let latestIssueCategory: String?
        let latestIssueMessage: String?
        if record.severity.isIssueSeverity {
            latestIssueFingerprint = fingerprint(for: record)
            latestIssueCategory = record.category
            latestIssueMessage = record.message
        } else {
            latestIssueFingerprint = existing?.latestIssueFingerprint
            latestIssueCategory = existing?.latestIssueCategory
            latestIssueMessage = existing?.latestIssueMessage
        }

        let endedAt: String?
        if record.category == "Diagnostics", record.message == "session_ended" {
            endedAt = record.timestamp
        } else {
            endedAt = existing?.endedAt
        }

        let snapshot = RuntimeDiagnosticSessionSnapshot(
            sessionId: currentSessionID ?? sessionID,
            startedAt: startedAt,
            launchMetadata: launchMetadata,
            lastUpdatedAt: record.timestamp,
            endedAt: endedAt,
            severityCounts: severityCounts,
            lifecycleEvents: lifecycleEvents,
            latestIssueFingerprint: latestIssueFingerprint,
            latestIssueCategory: latestIssueCategory,
            latestIssueMessage: latestIssueMessage
        )
        try writeJSON(snapshot, to: sessionURL)
    }

    private static func updateIssueIndexLocked(
        with record: RuntimeDiagnosticRecord,
        baseDirectory: URL?,
        now: Date,
        fileManager: FileManager
    ) throws {
        let url = try issueIndexURL(baseDirectory: baseDirectory, now: now, fileManager: fileManager)
        var issues = (try loadIssueIndexLocked(at: url, fileManager: fileManager)?.issues ?? [])
        let issueFingerprint = fingerprint(for: record)

        if let existingIndex = issues.firstIndex(where: { $0.fingerprint == issueFingerprint }) {
            let existing = issues[existingIndex]
            issues[existingIndex] = RuntimeDiagnosticIssueSummary(
                fingerprint: existing.fingerprint,
                category: existing.category,
                message: record.message,
                highestSeverity: RuntimeDiagnosticSeverity.mergedSeverity(
                    existing.highestSeverity,
                    record.severity
                ),
                count: existing.count + 1,
                firstSeenTimestamp: existing.firstSeenTimestamp,
                lastSeenTimestamp: record.timestamp,
                latestMetadata: record.metadata,
                sourceFile: existing.sourceFile,
                sourceFunction: existing.sourceFunction,
                sourceLine: existing.sourceLine
            )
        } else {
            issues.append(
                RuntimeDiagnosticIssueSummary(
                    fingerprint: issueFingerprint,
                    category: record.category,
                    message: record.message,
                    highestSeverity: record.severity,
                    count: 1,
                    firstSeenTimestamp: record.timestamp,
                    lastSeenTimestamp: record.timestamp,
                    latestMetadata: record.metadata,
                    sourceFile: record.sourceFile,
                    sourceFunction: record.sourceFunction,
                    sourceLine: record.sourceLine
                )
            )
        }

        issues.sort {
            if $0.highestSeverity != $1.highestSeverity {
                return $0.highestSeverity.rank > $1.highestSeverity.rank
            }
            if $0.count != $1.count {
                return $0.count > $1.count
            }
            return $0.lastSeenTimestamp > $1.lastSeenTimestamp
        }

        let index = RuntimeDiagnosticIssueIndex(
            generatedAt: iso8601String(from: now),
            sessionId: currentSessionID,
            issues: issues
        )
        try writeJSON(index, to: url)
    }

    private static func ensureIssueIndexExistsLocked(
        baseDirectory: URL?,
        now: Date,
        fileManager: FileManager
    ) throws {
        let url = try issueIndexURL(baseDirectory: baseDirectory, now: now, fileManager: fileManager)
        guard !fileManager.fileExists(atPath: url.path) else { return }

        let index = RuntimeDiagnosticIssueIndex(
            generatedAt: iso8601String(from: now),
            sessionId: currentSessionID,
            issues: []
        )
        try writeJSON(index, to: url)
    }

    private static func ensureSessionIdentifierLocked() -> String {
        if let currentSessionID {
            return currentSessionID
        }
        let fallback = "session-\(UUID().uuidString)"
        currentSessionID = fallback
        return fallback
    }

    private static func ensureFileExists(
        at url: URL,
        fileManager: FileManager
    ) throws {
        guard !fileManager.fileExists(atPath: url.path) else { return }
        guard fileManager.createFile(atPath: url.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    private static func append(_ data: Data, to url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer {
            try? handle.close()
        }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }

    private static func pruneOldFilesIfNeeded(
        in directory: URL,
        maxRetainedFiles: Int,
        fileManager: FileManager
    ) throws {
        guard maxRetainedFiles > 0 else { return }

        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        let dailyLogs = try sortedByModificationDateDescending(
            contents.filter { $0.pathExtension == "ndjson" },
            fileManager: fileManager
        )
        let dailySummaries = try sortedByModificationDateDescending(
            contents.filter { $0.lastPathComponent.hasSuffix("-summary.json") },
            fileManager: fileManager
        )

        for collection in [dailyLogs, dailySummaries] where collection.count > maxRetainedFiles {
            for url in collection.dropFirst(maxRetainedFiles) {
                try fileManager.removeItem(at: url)
            }
        }
    }

    private static func sortedByModificationDateDescending(
        _ urls: [URL],
        fileManager _: FileManager
    ) throws -> [URL] {
        try urls.sorted { lhs, rhs in
            let lhsDate = try lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            let rhsDate = try rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            return lhsDate > rhsDate
        }
    }

    private static func loadIssueIndexLocked(
        at url: URL,
        fileManager: FileManager
    ) throws -> RuntimeDiagnosticIssueIndex? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(RuntimeDiagnosticIssueIndex.self, from: data)
    }

    private static func loadSessionSnapshotLocked(
        at url: URL,
        fileManager: FileManager
    ) throws -> RuntimeDiagnosticSessionSnapshot? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(RuntimeDiagnosticSessionSnapshot.self, from: data)
    }

    private static func writeJSON<Value: Encodable>(
        _ value: Value,
        to url: URL
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    private static func encodedLine(for record: RuntimeDiagnosticRecord) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var data = try encoder.encode(record)
        data.append(0x0A)
        return data
    }

    private static func fingerprint(for record: RuntimeDiagnosticRecord) -> String {
        [
            record.category,
            record.message,
            record.sourceFile,
            record.sourceFunction,
            "\(record.sourceLine)",
        ].joined(separator: "|")
    }

    private static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func dayStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func emitUnifiedLog(for record: RuntimeDiagnosticRecord) {
        let metadataSuffix = metadataSummary(record.metadata)

        switch record.severity {
        case .debug:
            Log.diagnostics.debug(
                "[\(record.category, privacy: .public)] \(record.message, privacy: .public)\(metadataSuffix, privacy: .public)"
            )
        case .info:
            Log.diagnostics.info(
                "[\(record.category, privacy: .public)] \(record.message, privacy: .public)\(metadataSuffix, privacy: .public)"
            )
        case .warning:
            Log.diagnostics.warning(
                "[\(record.category, privacy: .public)] \(record.message, privacy: .public)\(metadataSuffix, privacy: .public)"
            )
        case .error:
            Log.diagnostics.error(
                "[\(record.category, privacy: .public)] \(record.message, privacy: .public)\(metadataSuffix, privacy: .public)"
            )
        case .fault:
            Log.diagnostics.fault(
                "[\(record.category, privacy: .public)] \(record.message, privacy: .public)\(metadataSuffix, privacy: .public)"
            )
        }
    }

    private static func metadataSummary(_ metadata: [String: String]) -> String {
        guard !metadata.isEmpty else { return "" }
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys])
        } catch {
            return " metadata=\(String(describing: metadata))"
        }

        guard var json = String(data: data, encoding: .utf8) else {
            return " metadata=\(String(describing: metadata))"
        }
        if json.count > 1200 {
            json = String(json.prefix(1200)) + "…"
        }
        return " metadata=\(json)"
    }
}
