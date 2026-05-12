import Testing
@testable import Epistemos

@MainActor
private func makeReasoningService() -> ReasoningLoopService {
    let triage = AppBootstrap.shared?.triageService ?? TriageService(
        inference: InferenceState(),
        localLLMService: nil,
        cloudLLMService: nil
    )
    return ReasoningLoopService(triageService: triage)
}

// MARK: - Quality Score Parsing Tests

@Suite("ReasoningLoop — Quality Score Parsing")
@MainActor
struct ReasoningLoopScoreTests {

    @Test("Parses explicit 'Score: 0.85' format")
    func parseExplicitScore() {
        let service = makeReasoningService()
        let score = service.parseQualityScore(from: "The reasoning is solid. Score: 0.85")
        #expect(score == 0.85)
    }

    @Test("Parses 'quality: 0.7' format (case insensitive)")
    func parseQualityLabel() {
        let service = makeReasoningService()
        let score = service.parseQualityScore(from: "Quality: 0.7 — needs more detail")
        #expect(score == 0.7)
    }

    @Test("Parses 'confidence: 0.92' format")
    func parseConfidenceLabel() {
        let service = makeReasoningService()
        let score = service.parseQualityScore(from: "Confidence: 0.92")
        #expect(score == 0.92)
    }

    @Test("Parses standalone decimal in 0-1 range")
    func parseStandaloneDecimal() {
        let service = makeReasoningService()
        let score = service.parseQualityScore(from: "The answer is adequate. 0.65")
        #expect(score == 0.65)
    }

    @Test("Parses integer score as fraction of 10")
    func parseIntegerScore() {
        let service = makeReasoningService()
        let score = service.parseQualityScore(from: "Score: 8")
        #expect(score == 0.8)
    }

    @Test("Returns 0.5 for unparseable text")
    func defaultForGarbage() {
        let service = makeReasoningService()
        let score = service.parseQualityScore(from: "This is great reasoning with no numbers!")
        #expect(score == 0.5)
    }

    @Test("Returns 0.5 for empty string")
    func defaultForEmpty() {
        let service = makeReasoningService()
        let score = service.parseQualityScore(from: "")
        #expect(score == 0.5)
    }

    @Test("Parses 1.0 as perfect score")
    func parsePerfectScore() {
        let service = makeReasoningService()
        let score = service.parseQualityScore(from: "Score: 1.0")
        #expect(score == 1.0)
    }

    @Test("Parses 0.0 as minimum score")
    func parseMinimumScore() {
        let service = makeReasoningService()
        let score = service.parseQualityScore(from: "Score: 0.0 — completely wrong")
        #expect(score == 0.0)
    }
}

// MARK: - Configuration Tests

@Suite("ReasoningLoop — Configuration")
@MainActor
struct ReasoningLoopConfigTests {

    @Test("Default config has reasoning disabled")
    func defaultDisabled() {
        let config = ReasoningLoopConfig()
        #expect(!config.enabled)
        #expect(config.qualityThreshold == 0.7)
        #expect(config.maxRounds == 5)
        #expect(config.enableToolUse)
        #expect(config.minComplexity == 0.40)
    }

    @Test("Low complexity operations should bypass reasoning")
    func lowComplexityBypass() {
        // .rewrite = 0.25, below 0.40 threshold
        #expect(NotesOperation.rewrite.baseComplexity < 0.40)
        #expect(NotesOperation.summarize.baseComplexity < 0.40)
        #expect(NotesOperation.continueWriting.baseComplexity < 0.40)
    }

    @Test("High complexity operations should engage reasoning")
    func highComplexityEngages() {
        #expect(NotesOperation.outline.baseComplexity >= 0.40)
        #expect(NotesOperation.expand.baseComplexity >= 0.40)
        #expect(NotesOperation.analyze.baseComplexity >= 0.40)
    }

    @Test("Complex ask queries cross the reasoning threshold once enabled")
    func complexAskEngagesWhenEnabled() {
        let service = makeReasoningService()
        service.config.enabled = true

        let query = "Compare Bayesian and evidential decision theory across uncertainty, Dutch book arguments, dynamic inconsistency, and practical planning tradeoffs."
        let complexity = service.effectiveComplexity(
            operation: .ask(query: query),
            contentLength: query.count,
            query: query
        )

        #expect(complexity >= service.config.minComplexity)
        #expect(service.shouldEngageReasoning(
            operation: .ask(query: query),
            contentLength: query.count,
            query: query,
            operatingMode: .thinking
        ))
    }

    @Test("Fast mode bypasses recursive reasoning even for complex asks")
    func fastModeBypassesReasoning() {
        let service = makeReasoningService()
        service.config.enabled = true

        let query = "Compare Bayesian and evidential decision theory across uncertainty, Dutch book arguments, dynamic inconsistency, and practical planning tradeoffs."
        #expect(!service.shouldEngageReasoning(
            operation: .ask(query: query),
            contentLength: query.count,
            query: query,
            operatingMode: .fast
        ))
        #expect(service.shouldEngageReasoning(
            operation: .ask(query: query),
            contentLength: query.count,
            query: query,
            operatingMode: .pro
        ))
    }

    @Test("Simple ask queries stay on the direct path even when reasoning is enabled")
    func simpleAskBypassesWhenEnabled() {
        let service = makeReasoningService()
        service.config.enabled = true

        let query = "Summarize this."
        let complexity = service.effectiveComplexity(
            operation: .ask(query: query),
            contentLength: query.count,
            query: query
        )

        #expect(complexity < service.config.minComplexity)
        #expect(!service.shouldEngageReasoning(
            operation: .ask(query: query),
            contentLength: query.count,
            query: query,
            operatingMode: .thinking
        ))
    }

    @Test("App bootstrap keeps the reasoning loop opt-in by default")
    func bootstrapDefaultsReasoningLoopToDisabled() {
        let bootstrap = AppBootstrap()
        #expect(!bootstrap.reasoningLoopService.config.enabled)
    }
}

// MARK: - Trace Logger Tests

@Suite("ReasoningLoop — Trace Logger")
@MainActor
struct ReasoningTraceLoggerTests {

    @Test("Single round produces one trace line")
    func singleRoundTrace() {
        let logger = ReasoningTraceLogger()
        let round = ReasoningRound(
            roundIndex: 0,
            thinkOutput: "The answer is 42.",
            critiqueOutput: "Score: 0.9 — solid reasoning.",
            qualityScore: 0.9,
            toolCalls: [],
            refinedOutput: "",
            durationMs: 1500
        )

        let lines = logger.logReasoningChain(
            query: "What is the meaning of life?",
            rounds: [round],
            finalAnswer: "The answer is 42.",
            totalDurationMs: 1500
        )

        // Single round → 1 per-round trace (no chain trace for single round)
        #expect(lines.count == 1)

        // Verify JSONL validity
        for line in lines {
            let data = Data(line.utf8)
            let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            #expect(parsed != nil)
            let messages = parsed?["messages"] as? [[String: Any]]
            #expect(messages?.count == 3) // system, user, assistant
        }
    }

    @Test("Multiple rounds produce per-round + chain traces")
    func multiRoundTrace() {
        let logger = ReasoningTraceLogger()
        let rounds = [
            ReasoningRound(
                roundIndex: 0,
                thinkOutput: "Initial thought",
                critiqueOutput: "Score: 0.4 — needs more info",
                qualityScore: 0.4,
                toolCalls: [ToolCallRecord(toolName: "vault.search", query: "life meaning", result: "found stuff", durationMs: 50)],
                refinedOutput: "Refined with search results",
                durationMs: 2000
            ),
            ReasoningRound(
                roundIndex: 1,
                thinkOutput: "Better thought",
                critiqueOutput: "Score: 0.8 — good",
                qualityScore: 0.8,
                toolCalls: [],
                refinedOutput: "",
                durationMs: 1000
            ),
        ]

        let lines = logger.logReasoningChain(
            query: "Deep question",
            rounds: rounds,
            finalAnswer: "Better thought",
            totalDurationMs: 3000
        )

        // 2 per-round traces + 1 chain trace = 3
        #expect(lines.count == 3)
    }

    @Test("Empty rounds produce no traces")
    func emptyRounds() {
        let logger = ReasoningTraceLogger()
        let lines = logger.logReasoningChain(
            query: "test",
            rounds: [],
            finalAnswer: "",
            totalDurationMs: 0
        )
        #expect(lines.isEmpty)
    }

    @Test("Traces are valid JSONL with messages array")
    func validJsonl() {
        let logger = ReasoningTraceLogger()
        let round = ReasoningRound(
            roundIndex: 0,
            thinkOutput: "Think output with \"quotes\" and\nnewlines",
            critiqueOutput: "Score: 0.75",
            qualityScore: 0.75,
            toolCalls: [],
            refinedOutput: "",
            durationMs: 500
        )

        let lines = logger.logReasoningChain(
            query: "Test with special chars: <>&\"'",
            rounds: [round],
            finalAnswer: "Answer",
            totalDurationMs: 500
        )

        #expect(lines.count == 1)

        let data = Data(lines[0].utf8)
        let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(parsed != nil)

        let messages = parsed?["messages"] as? [[String: String]]
        #expect(messages?[0]["role"] == "system")
        #expect(messages?[1]["role"] == "user")
        #expect(messages?[2]["role"] == "assistant")
    }
}

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
