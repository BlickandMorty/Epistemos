import Foundation
import os
import GRDB

// MARK: - Harness Lab
//
// Developer-only, offline subsystem for harness evolution.
// This file contains:
//   - TaskSuite: curated task definitions with expected outcomes (Phase 7B)
//   - EvaluationRunner: isolated candidate harness execution (Phase 7D scaffold)
//   - PromotionPipeline: review-gated promotion from candidate to production (Phase 7F scaffold)
//   - TraceStoreIndex: GRDB SQLite index over JSONL trace corpus (Phase 7C)
//
// NONE of this runs on the production hot path. It is invoked only
// through explicit developer action (e.g., a developer-mode UI toggle
// or a CLI tool).

// ═══════════════════════════════════════════════════════════════════
// MARK: - Task Suite (Phase 7B)
// ═══════════════════════════════════════════════════════════════════

/// A single task definition for harness evaluation.
/// Loaded from JSON files in the task suite directory.
///
/// JSON format:
/// ```json
/// {
///   "id": "coding-001",
///   "objective": "Add error handling to the FFI bridge",
///   "taskType": "coding",
///   "verification": {
///     "type": "commandExitZero",
///     "command": "cargo test --manifest-path agent_core/Cargo.toml"
///   },
///   "initialStatePath": null,
///   "metadata": {
///     "difficulty": "medium",
///     "domain": "rust",
///     "expectedTurns": 5,
///     "expectedTokenBudget": 15000
///   }
/// }
/// ```
struct EvalTask: Sendable {
    let id: String
    let objective: String
    let taskType: HarnessTaskType
    let verification: EvalVerification
    let initialStatePath: URL?
    let metadata: EvalTaskMetadata

    /// Load an EvalTask from a JSON dictionary (manual deserialization to avoid
    /// Swift 6.2 MainActor Codable inference issues).
    nonisolated static func load(from url: URL) -> EvalTask? {
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = dict["id"] as? String,
              let objective = dict["objective"] as? String else {
            return nil
        }

        let taskTypeStr = dict["taskType"] as? String ?? "coding"
        let taskType = HarnessTaskType(rawValue: taskTypeStr) ?? .coding

        let verification = EvalVerification.parse(dict["verification"] as? [String: Any])

        let initialStatePath: URL?
        if let pathStr = dict["initialStatePath"] as? String {
            initialStatePath = URL(fileURLWithPath: pathStr)
        } else {
            initialStatePath = nil
        }

        let metadata = EvalTaskMetadata.parse(dict["metadata"] as? [String: Any])

        return EvalTask(
            id: id,
            objective: objective,
            taskType: taskType,
            verification: verification,
            initialStatePath: initialStatePath,
            metadata: metadata
        )
    }
}

struct EvalTaskMetadata: Sendable {
    let difficulty: String?
    let domain: String?
    let expectedTurns: Int?
    let expectedTokenBudget: Int?

    nonisolated static func parse(_ dict: [String: Any]?) -> EvalTaskMetadata {
        guard let dict else {
            return EvalTaskMetadata(difficulty: nil, domain: nil, expectedTurns: nil, expectedTokenBudget: nil)
        }
        return EvalTaskMetadata(
            difficulty: dict["difficulty"] as? String,
            domain: dict["domain"] as? String,
            expectedTurns: dict["expectedTurns"] as? Int,
            expectedTokenBudget: dict["expectedTokenBudget"] as? Int
        )
    }

    /// Serialize to JSON-compatible dictionary.
    nonisolated func toDict() -> [String: Any] {
        var d: [String: Any] = [:]
        if let v = difficulty { d["difficulty"] = v }
        if let v = domain { d["domain"] = v }
        if let v = expectedTurns { d["expectedTurns"] = v }
        if let v = expectedTokenBudget { d["expectedTokenBudget"] = v }
        return d
    }
}

enum EvalVerification: Sendable {
    case commandExitZero(command: String)
    case filesExist(paths: [String])
    case outputPattern(command: String, pattern: String)
    case llmJudge(rubric: String, minimumScore: Double)
    case humanReview

    /// Parse from a JSON dictionary.
    nonisolated static func parse(_ dict: [String: Any]?) -> EvalVerification {
        guard let dict, let type = dict["type"] as? String else {
            return .humanReview
        }
        switch type {
        case "commandExitZero":
            return .commandExitZero(command: dict["command"] as? String ?? "echo 'no command'")
        case "filesExist":
            return .filesExist(paths: dict["paths"] as? [String] ?? [])
        case "outputPattern":
            return .outputPattern(
                command: dict["command"] as? String ?? "",
                pattern: dict["pattern"] as? String ?? ""
            )
        case "llmJudge":
            return .llmJudge(
                rubric: dict["rubric"] as? String ?? "",
                minimumScore: dict["minimumScore"] as? Double ?? 0.7
            )
        default:
            return .humanReview
        }
    }

    /// Serialize to JSON-compatible dictionary.
    nonisolated func toDict() -> [String: Any] {
        switch self {
        case .commandExitZero(let command):
            return ["type": "commandExitZero", "command": command]
        case .filesExist(let paths):
            return ["type": "filesExist", "paths": paths]
        case .outputPattern(let command, let pattern):
            return ["type": "outputPattern", "command": command, "pattern": pattern]
        case .llmJudge(let rubric, let minimumScore):
            return ["type": "llmJudge", "rubric": rubric, "minimumScore": minimumScore]
        case .humanReview:
            return ["type": "humanReview"]
        }
    }
}

/// A collection of tasks split into search set and held-out test set.
/// Layout:
///   baseDir/
///     search/      ← 10-20 tasks the proposer can analyze
///     held_out/    ← 5-10 tasks the proposer never sees
actor TaskSuite {
    private static let log = Logger(subsystem: "com.epistemos", category: "TaskSuite")

    private let baseDir: URL
    private var searchTasks: [EvalTask] = []
    private var heldOutTasks: [EvalTask] = []

    init(baseDir: URL) {
        self.baseDir = baseDir
    }

    var searchSet: [EvalTask] { searchTasks }
    var testSet: [EvalTask] { heldOutTasks }
    var totalCount: Int { searchTasks.count + heldOutTasks.count }

    /// Load task definitions from the task suite directory.
    func load() throws {
        let fm = FileManager.default
        let searchDir = baseDir.appendingPathComponent("search")
        let heldOutDir = baseDir.appendingPathComponent("held_out")

        try fm.createDirectory(at: searchDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: heldOutDir, withIntermediateDirectories: true)

        searchTasks = loadTasks(from: searchDir)
        heldOutTasks = loadTasks(from: heldOutDir)

        Self.log.info("Loaded task suite: \(self.searchTasks.count) search, \(self.heldOutTasks.count) held-out")
    }

    /// Add a task to the search set and persist it to disk.
    func addSearchTask(_ task: EvalTask) throws {
        searchTasks.append(task)
        try persistTask(task, to: baseDir.appendingPathComponent("search"))
    }

    /// Add a task to the held-out set and persist it to disk.
    func addHeldOutTask(_ task: EvalTask) throws {
        heldOutTasks.append(task)
        try persistTask(task, to: baseDir.appendingPathComponent("held_out"))
    }

    /// Look up a task by ID across both sets.
    func task(withId id: String) -> EvalTask? {
        searchTasks.first(where: { $0.id == id }) ?? heldOutTasks.first(where: { $0.id == id })
    }

    private func loadTasks(from dir: URL) -> [EvalTask] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        return files
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { EvalTask.load(from: $0) }
    }

    private func persistTask(_ task: EvalTask, to dir: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        var dict: [String: Any] = [
            "id": task.id,
            "objective": task.objective,
            "taskType": task.taskType.rawValue,
            "verification": task.verification.toDict(),
            "metadata": task.metadata.toDict()
        ]
        if let path = task.initialStatePath {
            dict["initialStatePath"] = path.path
        }

        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        let filePath = dir.appendingPathComponent("\(task.id).json")
        try data.write(to: filePath)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Evaluation Result
// ═══════════════════════════════════════════════════════════════════

struct EvalResult: Sendable {
    let taskId: String
    let harnessVersion: String
    let passed: Bool
    let score: Double
    let tokenCost: Int
    let turns: Int
    let tracePath: URL?
    let evidence: String
    let timestamp: String
}

/// Aggregated results across a task suite.
struct EvalSuiteResult: Sendable {
    let harnessVersion: String
    let results: [EvalResult]

    nonisolated var passRate: Double {
        guard !results.isEmpty else { return 0.0 }
        return Double(results.filter(\.passed).count) / Double(results.count)
    }

    nonisolated var averageTokenCost: Int {
        guard !results.isEmpty else { return 0 }
        return results.map(\.tokenCost).reduce(0, +) / results.count
    }

    nonisolated var averageScore: Double {
        guard !results.isEmpty else { return 0.0 }
        return results.map(\.score).reduce(0.0, +) / Double(results.count)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Evaluation Runner (Phase 7D scaffold)
// ═══════════════════════════════════════════════════════════════════

/// Runs candidate harnesses against the task suite in isolation.
/// Developer-only — never invoked on the production hot path.
actor EvaluationRunner {
    private static let log = Logger(subsystem: "com.epistemos", category: "EvalRunner")

    private let registry: HarnessRegistry
    private let taskSuite: TaskSuite

    init(registry: HarnessRegistry, taskSuite: TaskSuite) {
        self.registry = registry
        self.taskSuite = taskSuite
    }

    /// Evaluate a candidate harness against the search set.
    func evaluateCandidate(
        candidateId: String,
        maxConcurrent: Int = 1
    ) async -> EvalSuiteResult {
        let tasks = await taskSuite.searchSet
        Self.log.info("Evaluating \(candidateId) against \(tasks.count) search tasks")

        var results: [EvalResult] = []

        for task in tasks {
            let result = await evaluateSingleTask(
                task: task,
                candidateId: candidateId
            )
            results.append(result)
        }

        return EvalSuiteResult(
            harnessVersion: candidateId,
            results: results
        )
    }

    /// Evaluate against the held-out test set (post-promotion gate).
    func evaluateHeldOut(
        candidateId: String
    ) async -> EvalSuiteResult {
        let tasks = await taskSuite.testSet
        Self.log.info("Evaluating \(candidateId) against \(tasks.count) held-out tasks")

        var results: [EvalResult] = []
        for task in tasks {
            let result = await evaluateSingleTask(task: task, candidateId: candidateId)
            results.append(result)
        }
        return EvalSuiteResult(harnessVersion: candidateId, results: results)
    }

    /// Evaluate a single task with verification.
    private func evaluateSingleTask(
        task: EvalTask,
        candidateId: String
    ) async -> EvalResult {
        Self.log.info("Evaluating task \(task.id) with candidate \(candidateId)")

        // Phase 8 will add real isolated subprocess execution.
        // For now, run verification directly if the task has a command-based check.
        let startTime = ContinuousClock.now
        let verificationResult: (passed: Bool, evidence: String, exitCode: Int?)

        switch task.verification {
        case .commandExitZero(let command):
            let result = await runCommand(
                "/bin/sh", arguments: ["-c", command],
                at: URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
                timeout: 120
            )
            verificationResult = (
                result.exitCode == 0,
                result.exitCode == 0 ? "Command succeeded" : "Exit code \(result.exitCode): \(String(result.stderr.suffix(200)))",
                Int(result.exitCode)
            )

        case .filesExist(let paths):
            let fm = FileManager.default
            let missing = paths.filter { !fm.fileExists(atPath: $0) }
            if missing.isEmpty {
                verificationResult = (true, "All \(paths.count) files exist", nil)
            } else {
                verificationResult = (false, "Missing files: \(missing.joined(separator: ", "))", nil)
            }

        case .outputPattern(let command, let pattern):
            let result = await runCommand(
                "/bin/sh", arguments: ["-c", command],
                at: URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
                timeout: 120
            )
            let combined = result.stdout + result.stderr
            if combined.range(of: pattern, options: .regularExpression) != nil {
                verificationResult = (true, "Pattern matched in output", Int(result.exitCode))
            } else {
                verificationResult = (false, "Pattern not found in output", Int(result.exitCode))
            }

        case .llmJudge, .humanReview:
            verificationResult = (false, "Requires manual evaluation", nil)
        }

        let elapsed = ContinuousClock.now - startTime

        return EvalResult(
            taskId: task.id,
            harnessVersion: candidateId,
            passed: verificationResult.passed,
            score: verificationResult.passed ? 1.0 : 0.0,
            tokenCost: 0,
            turns: 0,
            tracePath: nil,
            evidence: verificationResult.evidence,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Promotion Pipeline (Phase 7F scaffold)
// ═══════════════════════════════════════════════════════════════════

/// Manages the human-reviewed promotion of candidate harnesses to production.
/// No auto-promote — every promotion requires explicit developer approval.
actor PromotionPipeline {
    private static let log = Logger(subsystem: "com.epistemos", category: "Promotion")

    private let registry: HarnessRegistry
    private let evaluationRunner: EvaluationRunner

    /// Regression threshold: candidate must not degrade any task by >10%.
    let maxRegressionRate: Double = 0.10
    /// Improvement threshold: average score must improve by >=5%.
    let minImprovementRate: Double = 0.05

    init(registry: HarnessRegistry, evaluationRunner: EvaluationRunner) {
        self.registry = registry
        self.evaluationRunner = evaluationRunner
    }

    /// Generate a promotion proposal for a candidate.
    /// This does NOT promote — it generates the review artifact.
    func generateProposal(
        candidateId: String,
        baselineResults: EvalSuiteResult
    ) async -> PromotionProposal {
        let candidateResults = await evaluationRunner.evaluateCandidate(candidateId: candidateId)

        let regressions = findRegressions(
            baseline: baselineResults,
            candidate: candidateResults
        )

        let improvement = candidateResults.averageScore - baselineResults.averageScore

        let verdict: PromotionVerdict
        if !regressions.isEmpty {
            verdict = .rejected(reason: "Regressions detected: \(regressions.map(\.taskId).joined(separator: ", "))")
        } else if improvement < minImprovementRate {
            verdict = .rejected(reason: "Insufficient improvement: \(String(format: "%.1f", improvement * 100))% < \(String(format: "%.1f", minImprovementRate * 100))% threshold")
        } else {
            verdict = .readyForReview
        }

        return PromotionProposal(
            candidateId: candidateId,
            candidateResults: candidateResults,
            baselineResults: baselineResults,
            regressions: regressions,
            improvement: improvement,
            verdict: verdict,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
    }

    /// Execute promotion after human approval.
    /// Requires explicit developer call — never automated.
    func executePromotion(
        candidateId: String,
        newVersion: String,
        approvedBy: String
    ) async throws {
        try await registry.promote(
            candidateId: candidateId,
            newVersion: newVersion,
            promotedBy: approvedBy
        )
        Self.log.notice("Promoted \(candidateId) → \(newVersion) by \(approvedBy)")
    }

    private nonisolated func findRegressions(
        baseline: EvalSuiteResult,
        candidate: EvalSuiteResult
    ) -> [RegressionReport] {
        var regressions: [RegressionReport] = []
        let baselineByTask = Dictionary(grouping: baseline.results, by: \.taskId)
        let candidateByTask = Dictionary(grouping: candidate.results, by: \.taskId)

        for (taskId, baseResults) in baselineByTask {
            guard let baseResult = baseResults.first,
                  let candResult = candidateByTask[taskId]?.first else { continue }

            let delta = candResult.score - baseResult.score
            if delta < -maxRegressionRate {
                regressions.append(RegressionReport(
                    taskId: taskId,
                    baselineScore: baseResult.score,
                    candidateScore: candResult.score,
                    delta: delta
                ))
            }
        }
        return regressions
    }
}

// MARK: - Promotion Types

struct PromotionProposal: Sendable {
    let candidateId: String
    let candidateResults: EvalSuiteResult
    let baselineResults: EvalSuiteResult
    let regressions: [RegressionReport]
    let improvement: Double
    let verdict: PromotionVerdict
    let timestamp: String
}

enum PromotionVerdict: Sendable {
    case readyForReview
    case rejected(reason: String)
}

struct RegressionReport: Sendable {
    let taskId: String
    let baselineScore: Double
    let candidateScore: Double
    let delta: Double
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Trace Store Index (Phase 7C)
// ═══════════════════════════════════════════════════════════════════

/// GRDB-backed SQLite index over the JSONL trace corpus for fast queries.
/// Indexes: sessionId, taskId, harnessVersion, eventType, outcome, timestamp.
/// The JSONL files remain the source of truth — this is a read-acceleration layer.
///
/// Schema:
/// ```sql
/// CREATE TABLE trace_index (
///   id INTEGER PRIMARY KEY AUTOINCREMENT,
///   sessionId TEXT NOT NULL,
///   taskId TEXT,
///   harnessVersion TEXT NOT NULL,
///   eventType TEXT NOT NULL,
///   timestamp TEXT NOT NULL,
///   filePath TEXT NOT NULL,
///   lineOffset INTEGER NOT NULL,
///   outcome TEXT,           -- "passed" | "failed" | NULL
///   score REAL,
///   tokenCost INTEGER,
///   domain TEXT
/// );
/// ```
actor TraceStoreIndex {
    private static let log = Logger(subsystem: "com.epistemos", category: "TraceStore")

    private let tracesDir: URL
    private let dbPath: URL
    private var dbPool: DatabasePool?

    init(tracesDir: URL) {
        self.tracesDir = tracesDir
        self.dbPath = tracesDir.appendingPathComponent("trace_index.sqlite")
    }

    /// Open (or create) the SQLite index.
    func open() throws {
        try FileManager.default.createDirectory(at: tracesDir, withIntermediateDirectories: true)
        let pool = try DatabasePool(path: dbPath.path)
        try pool.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS trace_index (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    sessionId TEXT NOT NULL,
                    taskId TEXT,
                    harnessVersion TEXT NOT NULL,
                    eventType TEXT NOT NULL,
                    timestamp TEXT NOT NULL,
                    filePath TEXT NOT NULL,
                    lineOffset INTEGER NOT NULL,
                    outcome TEXT,
                    score REAL,
                    tokenCost INTEGER,
                    domain TEXT
                )
                """)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_trace_session ON trace_index(sessionId)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_trace_task ON trace_index(taskId)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_trace_version ON trace_index(harnessVersion)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_trace_type ON trace_index(eventType)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_trace_ts ON trace_index(timestamp)")
        }
        dbPool = pool
        Self.log.info("TraceStoreIndex opened at \(self.dbPath.path)")
    }

    /// Index all unindexed JSONL files in the traces directory.
    /// Scans date-organized directories and inserts events not yet in the index.
    func reindex() throws {
        guard let pool = dbPool else { throw TraceStoreError.notOpen }

        let fm = FileManager.default
        guard let dateDirs = try? fm.contentsOfDirectory(at: tracesDir, includingPropertiesForKeys: nil) else { return }

        for dateDir in dateDirs where dateDir.hasDirectoryPath && dateDir.lastPathComponent != "trace_index.sqlite" {
            guard let jsonlFiles = try? fm.contentsOfDirectory(at: dateDir, includingPropertiesForKeys: nil) else { continue }
            for file in jsonlFiles where file.pathExtension == "jsonl" {
                try indexFile(file, pool: pool)
            }
        }
    }

    /// Query traces by session ID.
    func traces(forSession sessionId: String) throws -> [TraceIndexRow] {
        guard let pool = dbPool else { throw TraceStoreError.notOpen }
        return try pool.read { db in
            try TraceIndexRow.fetchAll(db, sql: "SELECT * FROM trace_index WHERE sessionId = ? ORDER BY timestamp", arguments: [sessionId])
        }
    }

    /// Query traces by task ID and outcome.
    func traces(forTask taskId: String, outcome: String? = nil) throws -> [TraceIndexRow] {
        guard let pool = dbPool else { throw TraceStoreError.notOpen }
        return try pool.read { db in
            if let outcome {
                return try TraceIndexRow.fetchAll(db, sql: "SELECT * FROM trace_index WHERE taskId = ? AND outcome = ? ORDER BY timestamp", arguments: [taskId, outcome])
            } else {
                return try TraceIndexRow.fetchAll(db, sql: "SELECT * FROM trace_index WHERE taskId = ? ORDER BY timestamp", arguments: [taskId])
            }
        }
    }

    /// Query traces by harness version.
    func traces(forVersion version: String) throws -> [TraceIndexRow] {
        guard let pool = dbPool else { throw TraceStoreError.notOpen }
        return try pool.read { db in
            try TraceIndexRow.fetchAll(db, sql: "SELECT * FROM trace_index WHERE harnessVersion = ? ORDER BY timestamp", arguments: [version])
        }
    }

    /// Count indexed events.
    func totalIndexedCount() throws -> Int {
        guard let pool = dbPool else { throw TraceStoreError.notOpen }
        return try pool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM trace_index") ?? 0
        }
    }

    /// Disk usage of the traces directory in bytes.
    func diskUsageBytes() -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: tracesDir, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        while let url = enumerator.nextObject() as? URL {
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    /// Soft limit: 5GB. Returns true if over limit.
    func isOverSoftLimit() -> Bool {
        diskUsageBytes() > 5 * 1024 * 1024 * 1024
    }

    /// Rotate traces older than 90 days by deleting their date directories.
    func rotateOldTraces(olderThanDays: Int = 90) throws {
        let fm = FileManager.default
        let cutoff = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date()) ?? Date()
        let cutoffStr = Self.dateString(cutoff)

        guard let dateDirs = try? fm.contentsOfDirectory(at: tracesDir, includingPropertiesForKeys: nil) else { return }

        for dateDir in dateDirs where dateDir.hasDirectoryPath {
            let dirName = dateDir.lastPathComponent
            guard dirName.count == 10, dirName < cutoffStr else { continue }

            try fm.removeItem(at: dateDir)

            // Remove index entries for rotated files
            try dbPool?.write { db in
                try db.execute(sql: "DELETE FROM trace_index WHERE filePath LIKE ?", arguments: ["%/\(dirName)/%"])
            }

            Self.log.info("Rotated trace directory: \(dirName)")
        }
    }

    /// List all trace files for a session (filesystem scan).
    func traceFiles(for sessionId: String) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: tracesDir, includingPropertiesForKeys: nil) else {
            return []
        }
        var results: [URL] = []
        while let url = enumerator.nextObject() as? URL {
            if url.pathExtension == "jsonl" && url.lastPathComponent.contains(sessionId) {
                results.append(url)
            }
        }
        return results
    }

    /// List all trace files from a date range (filesystem scan).
    func traceFiles(from startDate: String, to endDate: String) -> [URL] {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(at: tracesDir, includingPropertiesForKeys: nil) else {
            return []
        }
        return dirs.filter { dir in
            let name = dir.lastPathComponent
            return name >= startDate && name <= endDate
        }.flatMap { dir -> [URL] in
            (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "jsonl" }) ?? []
        }
    }

    /// Count total trace files in the corpus (filesystem scan).
    func totalTraceCount() -> Int {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: tracesDir, includingPropertiesForKeys: nil) else {
            return 0
        }
        var count = 0
        while let url = enumerator.nextObject() as? URL {
            if url.pathExtension == "jsonl" { count += 1 }
        }
        return count
    }

    // MARK: - Private

    private func indexFile(_ file: URL, pool: DatabasePool) throws {
        let filePath = file.path

        // Check if already indexed (by checking first entry for this file)
        let alreadyIndexed = try pool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM trace_index WHERE filePath = ?", arguments: [filePath]) ?? 0
        }
        if alreadyIndexed > 0 { return }

        guard let content = try? String(contentsOf: file, encoding: .utf8) else { return }
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)

        try pool.write { db in
            for (offset, line) in lines.enumerated() {
                guard let data = line.data(using: .utf8),
                      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

                let sessionId = dict["sessionId"] as? String ?? ""
                let taskId = dict["taskId"] as? String
                let harnessVersion = dict["harnessVersion"] as? String ?? ""
                let eventType = dict["type"] as? String ?? ""
                let timestamp = dict["ts"] as? String ?? ""
                let domain = dict["domain"] as? String

                // Derive outcome from completion_check events
                let outcome: String?
                if eventType == "completion_check" {
                    if let passed = dict["passed"] as? Bool {
                        outcome = passed ? "passed" : "failed"
                    } else {
                        outcome = nil
                    }
                } else {
                    outcome = nil
                }

                let score = dict["score"] as? Double
                let tokenCost = dict["tokensUsed"] as? Int

                try db.execute(
                    sql: """
                        INSERT INTO trace_index (sessionId, taskId, harnessVersion, eventType, timestamp, filePath, lineOffset, outcome, score, tokenCost, domain)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                    arguments: [sessionId, taskId, harnessVersion, eventType, timestamp, filePath, offset, outcome, score, tokenCost, domain]
                )
            }
        }
    }

    private nonisolated static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}

// MARK: - Trace Index Row

/// Manual row extraction to avoid Swift 6.2 MainActor inference on FetchableRecord.
struct TraceIndexRow: Sendable {
    let id: Int64
    let sessionId: String
    let taskId: String?
    let harnessVersion: String
    let eventType: String
    let timestamp: String
    let filePath: String
    let lineOffset: Int
    let outcome: String?
    let score: Double?
    let tokenCost: Int?
    let domain: String?

    nonisolated static func fetchAll(_ db: Database, sql: String, arguments: StatementArguments = StatementArguments()) throws -> [TraceIndexRow] {
        let rows = try Row.fetchAll(db, sql: sql, arguments: arguments)
        return rows.map { row in
            TraceIndexRow(
                id: row["id"],
                sessionId: row["sessionId"],
                taskId: row["taskId"],
                harnessVersion: row["harnessVersion"],
                eventType: row["eventType"],
                timestamp: row["timestamp"],
                filePath: row["filePath"],
                lineOffset: row["lineOffset"],
                outcome: row["outcome"],
                score: row["score"],
                tokenCost: row["tokenCost"],
                domain: row["domain"]
            )
        }
    }
}

enum TraceStoreError: Error {
    case notOpen
}
