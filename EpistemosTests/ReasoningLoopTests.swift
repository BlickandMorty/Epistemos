import Testing
@testable import Epistemos

// MARK: - Runtime Diagnostics Tests

@Suite("Runtime Diagnostics")
struct RuntimeDiagnosticsTests {

    private func makeTempRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("runtime-diagnostics-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test("record persists a structured jsonl diagnostic")
    func recordPersistsStructuredJSONL() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let fixedDate = Date(timeIntervalSince1970: 1_711_631_296)
        let url = try #require(
            RuntimeDiagnostics.record(
                .error,
                category: "GraphBuilder",
                message: "Failed to fetch pages",
                metadata: [
                    "error": "simulated fetch failure",
                    "pageCount": "42",
                ],
                baseDirectory: root,
                now: fixedDate
            )
        )

        let contents = try String(contentsOf: url, encoding: .utf8)
        let line = try #require(contents.split(separator: "\n").first.map(String.init))
        let object = try #require(
            try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
        )

        #expect(object["severity"] as? String == "error")
        #expect(object["category"] as? String == "GraphBuilder")
        #expect(object["message"] as? String == "Failed to fetch pages")
        let metadata = object["metadata"] as? [String: String]
        #expect(metadata?["error"] == "simulated fetch failure")
        #expect(metadata?["pageCount"] == "42")
    }

    @Test("record session start creates a daily diagnostics file")
    func recordSessionStartCreatesDailyFile() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let fixedDate = Date(timeIntervalSince1970: 1_711_631_296)
        let url = try #require(
            RuntimeDiagnostics.recordSessionStart(
                metadata: [
                    "pid": "1234",
                    "version": "1.0",
                    "build": "42",
                ],
                baseDirectory: root,
                now: fixedDate
            )
        )

        let contents = try String(contentsOf: url, encoding: .utf8)
        let line = try #require(contents.split(separator: "\n").first.map(String.init))
        let object = try #require(
            try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
        )

        #expect(object["severity"] as? String == "info")
        #expect(object["category"] as? String == "Diagnostics")
        #expect(object["message"] as? String == "session_started")
        let metadata = object["metadata"] as? [String: String]
        #expect(metadata?["pid"] == "1234")
        #expect(metadata?["version"] == "1.0")
        #expect(metadata?["build"] == "42")

        let summaryURL = try RuntimeDiagnostics.issueIndexURL(
            baseDirectory: root,
            now: fixedDate
        )
        let summary = try loadJSONObject(at: summaryURL)
        let issues = try #require(summary["issues"] as? [[String: Any]])
        #expect(issues.isEmpty)
    }

    @Test("record prunes oldest daily logs beyond retention limit")
    func recordPrunesOldDailyLogs() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let calendar = Calendar(identifier: .gregorian)
        let baseDate = try #require(
            calendar.date(from: DateComponents(
                timeZone: TimeZone(secondsFromGMT: 0),
                year: 2026,
                month: 3,
                day: 28,
                hour: 12
            ))
        )

        for offset in 0..<5 {
            let date = calendar.date(byAdding: .day, value: offset, to: baseDate)!
            _ = RuntimeDiagnostics.record(
                .warning,
                category: "Persistence",
                message: "migration warning \(offset)",
                baseDirectory: root,
                now: date,
                maxRetainedFiles: 3
            )
        }

        let directory = try RuntimeDiagnostics.directoryURL(baseDirectory: root)
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .map(\.lastPathComponent)
        .sorted()
        let dailyLogs = files.filter { $0.hasSuffix(".ndjson") }
        let dailySummaries = files.filter { $0.hasSuffix("-summary.json") }

        #expect(dailyLogs == [
            "2026-03-30.ndjson",
            "2026-03-31.ndjson",
            "2026-04-01.ndjson",
        ])
        #expect(dailySummaries == [
            "2026-03-30-summary.json",
            "2026-03-31-summary.json",
            "2026-04-01-summary.json",
        ])
        #expect(files.contains("current_session.json"))
    }

    @Test("record builds a daily issue summary with deduplicated counts and escalated severity")
    func recordBuildsDailyIssueSummary() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let fixedDate = Date(timeIntervalSince1970: 1_711_631_296)
        RuntimeDiagnostics.recordSessionStart(
            metadata: ["pid": "4321"],
            baseDirectory: root,
            now: fixedDate
        )

        recordRepeatedVaultIssues(baseDirectory: root, now: fixedDate)

        let summaryURL = try RuntimeDiagnostics.issueIndexURL(
            baseDirectory: root,
            now: fixedDate
        )
        let summary = try loadJSONObject(at: summaryURL)
        let issues = try #require(summary["issues"] as? [[String: Any]])
        #expect(issues.count == 1)

        let issue = try #require(issues.first)
        #expect(issue["category"] as? String == "VaultSync")
        #expect(issue["count"] as? Int == 2)
        #expect(issue["highestSeverity"] as? String == "fault")
        #expect(issue["message"] as? String == "bookmark restore degraded")
    }

    @Test("session snapshot tracks lifecycle events and latest issue details")
    func sessionSnapshotTracksLifecycleAndLatestIssue() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let fixedDate = Date(timeIntervalSince1970: 1_711_631_296)
        let startedAt = try #require(
            RuntimeDiagnostics.recordSessionStart(
                metadata: ["pid": "777", "version": "1.2.3"],
                baseDirectory: root,
                now: fixedDate
            )
        )
        #expect(FileManager.default.fileExists(atPath: startedAt.path))

        RuntimeDiagnostics.recordLifecycleEvent(
            "app_became_active",
            metadata: ["windowCount": "2"],
            baseDirectory: root,
            now: fixedDate.addingTimeInterval(1)
        )
        recordRepeatedVaultIssues(
            baseDirectory: root,
            now: fixedDate.addingTimeInterval(2)
        )

        let sessionURL = try RuntimeDiagnostics.currentSessionURL(baseDirectory: root)
        let session = try loadJSONObject(at: sessionURL)
        #expect(session["latestIssueMessage"] as? String == "bookmark restore degraded")
        let severityCounts = session["severityCounts"] as? [String: Int]
        #expect(severityCounts?["info"] == 2)
        #expect(severityCounts?["warning"] == 1)
        #expect(severityCounts?["fault"] == 1)

        let lifecycleEvents = try #require(session["lifecycleEvents"] as? [[String: Any]])
        let lifecycleNames = lifecycleEvents.compactMap { $0["name"] as? String }
        #expect(lifecycleNames.contains("app_became_active"))
    }

    @Test("session snapshot resets endedAt and issue state when a new session starts")
    func sessionSnapshotResetsWhenNewSessionStarts() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let firstStart = Date(timeIntervalSince1970: 1_711_631_296)
        RuntimeDiagnostics.recordSessionStart(
            metadata: ["pid": "111"],
            baseDirectory: root,
            now: firstStart
        )
        RuntimeDiagnostics.recordLifecycleEvent(
            "app_became_active",
            metadata: ["windowCount": "2"],
            baseDirectory: root,
            now: firstStart.addingTimeInterval(1)
        )
        recordRepeatedVaultIssues(
            baseDirectory: root,
            now: firstStart.addingTimeInterval(2)
        )
        RuntimeDiagnostics.recordSessionEnd(
            reason: "test_shutdown",
            baseDirectory: root,
            now: firstStart.addingTimeInterval(3)
        )

        let secondStart = firstStart.addingTimeInterval(10)
        RuntimeDiagnostics.recordSessionStart(
            metadata: ["pid": "222", "version": "2.0.0"],
            baseDirectory: root,
            now: secondStart
        )

        let sessionURL = try RuntimeDiagnostics.currentSessionURL(baseDirectory: root)
        let session = try loadJSONObject(at: sessionURL)
        let startedAt = try #require(session["startedAt"] as? String)
        #expect(startedAt.hasPrefix("2024-03-28T13:08:26"))
        #expect(session["endedAt"] as? String == nil)
        #expect(session["latestIssueMessage"] as? String == nil)

        let severityCounts = try #require(session["severityCounts"] as? [String: Int])
        #expect(severityCounts["info"] == 1)
        #expect(severityCounts["warning"] == nil)
        #expect(severityCounts["fault"] == nil)

        let lifecycleEvents = try #require(session["lifecycleEvents"] as? [[String: Any]])
        #expect(lifecycleEvents.isEmpty)
    }

    private func recordRepeatedVaultIssues(baseDirectory: URL, now: Date) {
        for severity in [RuntimeDiagnosticSeverity.warning, .fault] {
            RuntimeDiagnostics.record(
                severity,
                category: "VaultSync",
                message: "bookmark restore degraded",
                metadata: ["bookmark": "primary"],
                baseDirectory: baseDirectory,
                now: now
            )
        }
    }

    private func loadJSONObject(at url: URL) throws -> [String: Any] {
        try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
    }
}

// Note: ODIATraceType.reasoning is tested in OmegaODIATraceTests.swift.
// The two ODIATrace definitions (Omega/Knowledge vs KnowledgeFusion/SyntheticData)
// create ambiguity in the test target, so we test the enum case there instead.
