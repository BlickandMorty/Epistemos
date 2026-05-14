#if !EPISTEMOS_APP_STORE
import Foundation
import os
import GRDB

private enum HarnessLabTime {
    nonisolated static func timestampString(_ date: Date = Date()) -> String {
        date.ISO8601Format()
    }

    nonisolated static func filenameTimestamp(_ date: Date = Date()) -> String {
        String(timestampString(date).prefix(19)).replacingOccurrences(of: ":", with: "-")
    }
}

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
    let allowNetwork: Bool
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

        let allowNetwork = dict["allowNetwork"] as? Bool ?? false

        let metadata = EvalTaskMetadata.parse(dict["metadata"] as? [String: Any])

        return EvalTask(
            id: id,
            objective: objective,
            taskType: taskType,
            verification: verification,
            initialStatePath: initialStatePath,
            allowNetwork: allowNetwork,
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
        if task.allowNetwork {
            dict["allowNetwork"] = true
        }

        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        let filePath = dir.appendingPathComponent("\(task.id).json")
        try data.write(to: filePath, options: .atomic)
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
///
/// Responsibilities:
///   - Execute verification for each task with per-task timeout and failure isolation
///   - Persist results as scores.json in the candidate directory via HarnessRegistry
///   - Record evaluation traces for observability
///   - Report safe failures without crashing the evaluation loop
actor EvaluationRunner {
    private static let log = Logger(subsystem: "com.epistemos", category: "EvalRunner")

    private let registry: HarnessRegistry
    private let taskSuite: TaskSuite

    /// Per-task timeout in seconds. Tasks exceeding this are marked as failed.
    let perTaskTimeout: TimeInterval = 120

    init(registry: HarnessRegistry, taskSuite: TaskSuite) {
        self.registry = registry
        self.taskSuite = taskSuite
    }

    /// Evaluate a candidate harness against the search set.
    /// Results are persisted to the candidate directory as scores.json.
    func evaluateCandidate(
        candidateId: String,
        maxConcurrent: Int = 1
    ) async -> EvalSuiteResult {
        let tasks = await taskSuite.searchSet
        Self.log.info("Evaluating \(candidateId) against \(tasks.count) search tasks")

        let results = await evaluateTasks(tasks, candidateId: candidateId)
        let suiteResult = EvalSuiteResult(harnessVersion: candidateId, results: results)

        // Persist scores to candidate directory
        await persistScores(suiteResult, candidateId: candidateId, setName: "search")

        return suiteResult
    }

    /// Evaluate against the held-out test set (post-promotion gate).
    /// Results are persisted alongside search set scores.
    func evaluateHeldOut(
        candidateId: String
    ) async -> EvalSuiteResult {
        let tasks = await taskSuite.testSet
        Self.log.info("Evaluating \(candidateId) against \(tasks.count) held-out tasks")

        let results = await evaluateTasks(tasks, candidateId: candidateId)
        let suiteResult = EvalSuiteResult(harnessVersion: candidateId, results: results)

        await persistScores(suiteResult, candidateId: candidateId, setName: "held_out")

        return suiteResult
    }

    // MARK: - Batch Evaluation

    private func evaluateTasks(_ tasks: [EvalTask], candidateId: String) async -> [EvalResult] {
        var results: [EvalResult] = []
        for task in tasks {
            // Check cancellation — allows foreground work to preempt evaluation
            guard !Task.isCancelled else {
                Self.log.info("Evaluation cancelled after \(results.count)/\(tasks.count) tasks")
                break
            }

            // Thermal backpressure — pause if the machine is overheating
            do {
                try await ThermalGuard.shared.acquireClearance()
            } catch {
                Self.log.warning("Thermal clearance denied, stopping evaluation: \(error.localizedDescription)")
                break
            }

            let result = await evaluateSingleTaskSafely(task: task, candidateId: candidateId)
            results.append(result)

            // Yield to let foreground work proceed between tasks
            await Task.yield()
        }
        return results
    }

    /// Wraps single-task evaluation with error isolation.
    /// Any unexpected error is caught and reported as a failed result rather than
    /// aborting the entire evaluation run.
    private func evaluateSingleTaskSafely(
        task: EvalTask,
        candidateId: String
    ) async -> EvalResult {
        do {
            return try await withThrowingTaskGroup(of: EvalResult.self) { group in
                group.addTask {
                    await self.evaluateSingleTask(task: task, candidateId: candidateId)
                }

                // Timeout watchdog
                group.addTask {
                    try await Task.sleep(for: .seconds(self.perTaskTimeout + 5))
                    return EvalResult(
                        taskId: task.id,
                        harnessVersion: candidateId,
                        passed: false,
                        score: 0.0,
                        tokenCost: 0,
                        turns: 0,
                        tracePath: nil,
                        evidence: "Evaluation timed out after \(Int(self.perTaskTimeout))s",
                        timestamp: HarnessLabTime.timestampString()
                    )
                }

                // Return whichever finishes first; if both tasks cancel out, treat it as cancellation.
                guard let result = try await group.next() else {
                    throw CancellationError()
                }
                group.cancelAll()
                return result
            }
        } catch {
            Self.log.error("Task \(task.id) evaluation failed with error: \(error.localizedDescription)")
            return EvalResult(
                taskId: task.id,
                harnessVersion: candidateId,
                passed: false,
                score: 0.0,
                tokenCost: 0,
                turns: 0,
                tracePath: nil,
                evidence: "Evaluation error: \(error.localizedDescription)",
                timestamp: HarnessLabTime.timestampString()
            )
        }
    }

    /// Evaluate a single task with sandboxed verification.
    /// Phase 8: Uses volatile project root, sanitized environment, and sandbox-exec isolation.
    private func evaluateSingleTask(
        task: EvalTask,
        candidateId: String
    ) async -> EvalResult {
        Self.log.info("Evaluating task \(task.id) with candidate \(candidateId)")

        let startTime = ContinuousClock.now

        // Create volatile project root for isolation
        let volatileRoot: VolatileProjectRoot
        do {
            volatileRoot = try VolatileProjectRoot.create(initialStatePath: task.initialStatePath)
        } catch {
            return EvalResult(
                taskId: task.id, harnessVersion: candidateId, passed: false, score: 0.0,
                tokenCost: 0, turns: 0, tracePath: nil,
                evidence: "Failed to create volatile root: \(error.localizedDescription)",
                timestamp: HarnessLabTime.timestampString()
            )
        }
        defer { volatileRoot.cleanup() }

        let verificationResult: (passed: Bool, evidence: String, exitCode: Int?)

        switch task.verification {
        case .commandExitZero(let command):
            let result = await sandboxedRunCommand(
                command,
                volatileRoot: volatileRoot.rootURL,
                allowNetwork: task.allowNetwork,
                timeout: perTaskTimeout
            )
            verificationResult = (
                result.exitCode == 0,
                result.exitCode == 0 ? "Command succeeded (sandboxed)" : "Exit code \(result.exitCode): \(String(result.stderr.suffix(500)))",
                Int(result.exitCode)
            )

        case .filesExist(let paths):
            // File existence checks run against the volatile root
            let fm = FileManager.default
            let missing = paths.filter { path in
                let absolutePath = path.hasPrefix("/") ? path : volatileRoot.rootURL.appendingPathComponent(path).path
                return !fm.fileExists(atPath: absolutePath)
            }
            if missing.isEmpty {
                verificationResult = (true, "All \(paths.count) files exist", nil)
            } else {
                verificationResult = (false, "Missing files: \(missing.joined(separator: ", "))", nil)
            }

        case .outputPattern(let command, let pattern):
            let result = await sandboxedRunCommand(
                command,
                volatileRoot: volatileRoot.rootURL,
                allowNetwork: task.allowNetwork,
                timeout: perTaskTimeout
            )
            let combined = result.stdout + result.stderr
            if combined.range(of: pattern, options: .regularExpression) != nil {
                verificationResult = (true, "Pattern matched in output (sandboxed)", Int(result.exitCode))
            } else {
                verificationResult = (false, "Pattern not found in output (exit \(result.exitCode))", Int(result.exitCode))
            }

        case .llmJudge, .humanReview:
            verificationResult = (false, "Requires manual evaluation", nil)
        }

        let elapsed = ContinuousClock.now - startTime
        let durationMs = Int(elapsed.components.seconds * 1000 + elapsed.components.attoseconds / 1_000_000_000_000_000)

        Self.log.info("Task \(task.id): \(verificationResult.passed ? "PASS" : "FAIL") (\(durationMs)ms, sandboxed)")

        return EvalResult(
            taskId: task.id,
            harnessVersion: candidateId,
            passed: verificationResult.passed,
            score: verificationResult.passed ? 1.0 : 0.0,
            tokenCost: 0,
            turns: 0,
            tracePath: nil,
            evidence: verificationResult.evidence,
            timestamp: HarnessLabTime.timestampString()
        )
    }

    // MARK: - Result Persistence

    /// Persist evaluation scores to the candidate directory as JSON.
    private func persistScores(_ suiteResult: EvalSuiteResult, candidateId: String, setName: String) async {
        do {
            try await registry.saveCandidateScores(
                candidateId: candidateId,
                setName: setName,
                suiteResult: suiteResult
            )
            Self.log.info("Persisted \(setName) scores for \(candidateId): \(suiteResult.results.count) results, pass rate \(String(format: "%.0f", suiteResult.passRate * 100))%")
        } catch {
            Self.log.error("Failed to persist scores for \(candidateId): \(error.localizedDescription)")
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Promotion Pipeline (Phase 7F scaffold)
// ═══════════════════════════════════════════════════════════════════

/// Manages the human-reviewed promotion of candidate harnesses to production.
/// No auto-promote — every promotion requires explicit developer approval.
///
/// The promotion flow:
///   1. `generateProposal()` — evaluates candidate, generates diff + scorecard + regression report
///   2. `saveProposalArtifact()` — persists the proposal to disk for human review
///   3. `executePromotion()` — applies the promotion after explicit developer approval
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

        // Generate unified diff between production and candidate harness
        let diffs: [HarnessDiff]
        do {
            diffs = try await registry.diffCandidate(candidateId)
        } catch {
            Self.log.error("Failed to generate diff for \(candidateId): \(error.localizedDescription)")
            diffs = []
        }

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
            diffs: diffs,
            improvement: improvement,
            verdict: verdict,
            timestamp: HarnessLabTime.timestampString()
        )
    }

    /// Persist the promotion proposal as a human-readable Markdown review artifact.
    /// Returns the file URL where the proposal was saved.
    func saveProposalArtifact(_ proposal: PromotionProposal) async throws -> URL {
        let markdown = formatProposalMarkdown(proposal)

        let proposalDir = await registry.proposalArtifactsDir
        let fm = FileManager.default
        try fm.createDirectory(at: proposalDir, withIntermediateDirectories: true)

        let filename = "proposal_\(proposal.candidateId)_\(proposal.timestamp.prefix(10)).md"
        let filePath = proposalDir.appendingPathComponent(filename)
        try markdown.write(to: filePath, atomically: true, encoding: .utf8)

        Self.log.info("Saved promotion proposal: \(filePath.path)")
        return filePath
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

    // MARK: - Scorecard Formatting

    /// Format the proposal as a Markdown document for human review.
    private nonisolated func formatProposalMarkdown(_ proposal: PromotionProposal) -> String {
        var md = """
        # Promotion Proposal: \(proposal.candidateId)

        **Generated:** \(proposal.timestamp)
        **Verdict:** \(verdictString(proposal.verdict))

        ## Scorecard

        | Metric | Baseline | Candidate | Delta |
        |--------|----------|-----------|-------|
        | Pass Rate | \(pct(proposal.baselineResults.passRate)) | \(pct(proposal.candidateResults.passRate)) | \(delta(proposal.candidateResults.passRate - proposal.baselineResults.passRate)) |
        | Avg Score | \(String(format: "%.2f", proposal.baselineResults.averageScore)) | \(String(format: "%.2f", proposal.candidateResults.averageScore)) | \(delta(proposal.improvement)) |
        | Avg Token Cost | \(proposal.baselineResults.averageTokenCost) | \(proposal.candidateResults.averageTokenCost) | \(proposal.candidateResults.averageTokenCost - proposal.baselineResults.averageTokenCost) |

        """

        // Per-task results
        md += "\n## Per-Task Results\n\n"
        md += "| Task | Baseline | Candidate | Status |\n"
        md += "|------|----------|-----------|--------|\n"

        let baselineByTask = Dictionary(grouping: proposal.baselineResults.results, by: \.taskId)
        for result in proposal.candidateResults.results {
            let baseScore = baselineByTask[result.taskId]?.first?.score
            let baseStr = baseScore.map { String(format: "%.2f", $0) } ?? "n/a"
            let status = result.passed ? "PASS" : "FAIL"
            md += "| \(result.taskId) | \(baseStr) | \(String(format: "%.2f", result.score)) | \(status) |\n"
        }

        // Regressions
        if !proposal.regressions.isEmpty {
            md += "\n## Regressions\n\n"
            for reg in proposal.regressions {
                md += "- **\(reg.taskId)**: \(String(format: "%.2f", reg.baselineScore)) → \(String(format: "%.2f", reg.candidateScore)) (\(delta(reg.delta)))\n"
            }
        }

        // File diffs
        if !proposal.diffs.isEmpty {
            md += "\n## Harness File Changes\n\n"
            for diff in proposal.diffs {
                md += "### \(diff.summary)\n\n"
                if let prod = diff.productionContent, let cand = diff.candidateContent {
                    md += "```diff\n--- production/\(diff.relativePath)\n+++ candidate/\(diff.relativePath)\n"
                    md += Self.simpleLineDiff(old: prod, new: cand)
                    md += "```\n\n"
                } else if let cand = diff.candidateContent {
                    md += "```\n\(cand)\n```\n\n"
                } else {
                    md += "(file removed)\n\n"
                }
            }
        }

        md += "\n---\n*Review this proposal carefully. Promotion requires explicit `executePromotion()` call.*\n"
        return md
    }

    /// Simple line-by-line diff (not a real unified diff algorithm, but sufficient for small harness files).
    private nonisolated static func simpleLineDiff(old: String, new: String) -> String {
        let oldLines = old.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let newLines = new.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var result = ""
        let maxLen = max(oldLines.count, newLines.count)
        for i in 0..<maxLen {
            let oldLine = i < oldLines.count ? oldLines[i] : nil
            let newLine = i < newLines.count ? newLines[i] : nil

            if oldLine == newLine {
                result += " \(oldLine ?? "")\n"
            } else {
                if let ol = oldLine { result += "-\(ol)\n" }
                if let nl = newLine { result += "+\(nl)\n" }
            }
        }
        return result
    }

    private nonisolated func verdictString(_ verdict: PromotionVerdict) -> String {
        switch verdict {
        case .readyForReview: return "READY FOR REVIEW"
        case .rejected(let reason): return "REJECTED — \(reason)"
        }
    }

    private nonisolated func pct(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }

    private nonisolated func delta(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", value * 100))%"
    }

    // MARK: - Regression Detection

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
    let diffs: [HarnessDiff]
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
// MARK: - Proposer Orchestrator (Phase 7E)
// ═══════════════════════════════════════════════════════════════════

/// Invokes a coding agent as a subprocess to propose harness improvements
/// based on trace analysis. Developer-only, never runs autonomously.
///
/// Flow:
///   1. Materialize traces to filesystem (via TraceMaterializer)
///   2. Write a skill prompt describing what to inspect and propose
///   3. Spawn the agent subprocess with filesystem access to traces + registry
///   4. Capture proposer output (proposed diffs, diagnostics)
///   5. Create a candidate harness from the proposal
///   6. Clean up materialized traces
///
/// Rules (enforced by the skill prompt):
///   - Never modify held-out tasks
///   - Never hardcode answers or task-specific hacks
///   - Proposals must be general improvements to the harness
actor ProposerOrchestrator {
    private static let log = Logger(subsystem: "com.epistemos", category: "Proposer")

    private let registry: HarnessRegistry
    private let traceStore: TraceStoreIndex
    private let materializer: TraceMaterializer

    /// The agent command to invoke (e.g., "claude" for Claude Code CLI).
    let agentCommand: String

    /// Maximum time the proposer subprocess is allowed to run.
    let timeout: TimeInterval

    init(
        registry: HarnessRegistry,
        traceStore: TraceStoreIndex,
        agentCommand: String = "claude",
        timeout: TimeInterval = 600
    ) {
        self.registry = registry
        self.traceStore = traceStore
        self.materializer = TraceMaterializer(traceStore: traceStore)
        self.agentCommand = agentCommand
        self.timeout = timeout
    }

    /// Run the proposer agent to generate a harness improvement proposal.
    /// Returns the proposer's raw output and the candidate ID if one was created.
    func runProposer(
        targetVersion: String,
        description: String = "Automated harness improvement proposal"
    ) async throws -> ProposerResult {
        Self.log.info("Starting proposer run for harness \(targetVersion)")

        // Step 1: Materialize traces
        let tracesRoot = try await materializer.materialize(harnessVersion: targetVersion)
        defer { Task { await materializer.cleanup() } }

        // Step 2: Build the skill prompt
        let prompt = buildSkillPrompt(
            targetVersion: targetVersion,
            tracesRoot: tracesRoot
        )

        // Step 3: Write the prompt to a temp file for the agent
        let promptFile = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("epistemos_proposer_prompt_\(UUID().uuidString).md")
        try prompt.write(to: promptFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: promptFile) }

        // Step 4: Invoke the agent subprocess
        let output = await runAgentSubprocess(promptFile: promptFile)

        // Step 5: Log the output
        let logFile = try await saveProposerLog(output: output, targetVersion: targetVersion)

        Self.log.info("Proposer run complete: \(output.stdout.count) bytes stdout, exit \(output.exitCode)")

        return ProposerResult(
            exitCode: output.exitCode,
            stdout: output.stdout,
            stderr: output.stderr,
            logFile: logFile,
            tracesRoot: tracesRoot
        )
    }

    // MARK: - Skill Prompt

    private func buildSkillPrompt(
        targetVersion: String,
        tracesRoot: URL
    ) -> String {
        """
        # Epistemos Harness Improvement Proposal

        You are analyzing agent session traces to propose improvements to the Epistemos \
        agent harness (system prompts, tool policies, completion checkers).

        ## Your Task

        1. Read the trace summary at: \(tracesRoot.path)/summary.json
        2. Examine session traces in the session subdirectories (events.jsonl files)
        3. Identify patterns: failures, wasted tokens, unnecessary tool calls, \
           completion check mismatches
        4. Propose specific, actionable changes to the harness

        ## Current Harness Version: \(targetVersion)

        ## Rules (NON-NEGOTIABLE)

        - Do NOT modify held-out evaluation tasks
        - Do NOT hardcode answers to specific tasks
        - Do NOT propose task-specific hacks — changes must generalize
        - Focus on system prompt improvements, tool policy adjustments, and \
          completion checker tuning
        - Every proposal must be a general improvement, not a narrow fix

        ## Output Format

        Write your proposals as a structured Markdown document with:
        - **Diagnosis**: What patterns did you find in the traces?
        - **Proposals**: Numbered list of changes with rationale
        - **Expected Impact**: What should improve and by how much?

        Keep the output under 2000 words. Be specific and actionable.
        """
    }

    // MARK: - Subprocess Execution

    private nonisolated func runAgentSubprocess(promptFile: URL) async -> ProcessResult {
        let state = ProcessContinuationState<ProcessResult>()
        let cancellationResult = ProcessResult(
            exitCode: -1,
            stdout: "",
            stderr: "Cancelled proposer agent"
        )

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .utility).async { [agentCommand, timeout] in
                    let process = Process.init()

                    // Try to find the agent command
                    let resolvedCommand = Self.resolveAgentCommand(agentCommand)
                    process.executableURL = URL(fileURLWithPath: resolvedCommand)
                    process.arguments = ["--print", "--input-file", promptFile.path]
                    process.environment = SanitizedEnvironment.build()

                    let stdoutPipe = Pipe()
                    let stderrPipe = Pipe()
                    process.standardOutput = stdoutPipe
                    process.standardError = stderrPipe

                    guard state.store(process: process, continuation: continuation) else {
                        continuation.resume(returning: cancellationResult)
                        return
                    }

                    let timer = DispatchSource.makeTimerSource(queue: .global())
                    timer.schedule(deadline: .now() + timeout)
                    timer.setEventHandler { process.terminate() }
                    timer.resume()

                    process.terminationHandler = { proc in
                        timer.cancel()

                        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                        state.resume(returning: ProcessResult(
                            exitCode: proc.terminationStatus,
                            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                            stderr: String(data: stderrData, encoding: .utf8) ?? ""
                        ))
                    }

                    do {
                        try process.run()
                    } catch {
                        timer.cancel()
                        state.resume(returning: ProcessResult(
                            exitCode: -1,
                            stdout: "",
                            stderr: "Failed to launch proposer agent: \(error.localizedDescription)"
                        ))
                    }
                }
            }
        } onCancel: {
            state.terminate()
            state.resume(returning: cancellationResult)
        }
    }

    /// Resolve the agent command to a full path.
    private nonisolated static func resolveAgentCommand(_ command: String) -> String {
        let candidates = [
            "/usr/local/bin/\(command)",
            "/opt/homebrew/bin/\(command)",
            "\(NSHomeDirectory())/.local/bin/\(command)",
            "\(NSHomeDirectory())/.npm-global/bin/\(command)",
        ]
        let fm = FileManager.default
        for candidate in candidates where fm.isExecutableFile(atPath: candidate) {
            return candidate
        }
        return command // Fall back to PATH resolution
    }

    // MARK: - Logging

    private func saveProposerLog(output: ProcessResult, targetVersion: String) async throws -> URL {
        let logsDir = await registry.proposalArtifactsDir.appendingPathComponent("proposer_logs")
        let fm = FileManager.default
        try fm.createDirectory(at: logsDir, withIntermediateDirectories: true)

        let timestamp = HarnessLabTime.filenameTimestamp()
        let filename = "proposer_\(targetVersion)_\(timestamp).md"
        let logFile = logsDir.appendingPathComponent(filename)

        var content = """
        # Proposer Run Log

        **Target Version:** \(targetVersion)
        **Timestamp:** \(HarnessLabTime.timestampString())
        **Exit Code:** \(output.exitCode)
        **Agent Command:** \(agentCommand)

        ## Stdout

        ```
        \(output.stdout)
        ```

        """

        if !output.stderr.isEmpty {
            content += """

            ## Stderr

            ```
            \(output.stderr)
            ```
            """
        }

        try content.write(to: logFile, atomically: true, encoding: .utf8)
        return logFile
    }
}

/// Result from a proposer agent run.
struct ProposerResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let logFile: URL
    let tracesRoot: URL

    var succeeded: Bool { exitCode == 0 }
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

    /// Get all distinct harness versions in the index.
    func distinctHarnessVersions() throws -> [String] {
        guard let pool = dbPool else { throw TraceStoreError.notOpen }
        return try pool.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT DISTINCT harnessVersion FROM trace_index ORDER BY harnessVersion")
            return rows.compactMap { $0["harnessVersion"] as String? }
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

// ═══════════════════════════════════════════════════════════════════
// MARK: - Trace Materialization Engine (Phase 7G)
// ═══════════════════════════════════════════════════════════════════

/// Extracts indexed trace data from JSONL files into a temporary filesystem
/// hierarchy suitable for grep/cat-style access by the ProposerOrchestrator.
///
/// Output layout:
/// ```
/// /tmp/epistemos_lab_traces/
///   harness_v1.0.0/
///     session_abc123/
///       events.jsonl           ← all events for that session
///     session_def456/
///       events.jsonl
///     summary.json             ← per-version summary stats
///   harness_v1.1.0-candidate_001/
///     ...
/// ```
///
/// The materialized traces are temporary — call `cleanup()` after the
/// proposer has finished reading them. Never persist these beyond a
/// single proposer run.
actor TraceMaterializer {
    private static let log = Logger(subsystem: "com.epistemos", category: "TraceMaterializer")

    private let traceStore: TraceStoreIndex
    private let baseDir: URL

    /// The root directory where materialized traces are written.
    var materializedRoot: URL { baseDir }

    init(traceStore: TraceStoreIndex, baseDir: URL? = nil) {
        self.traceStore = traceStore
        self.baseDir = baseDir ?? URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("epistemos_lab_traces")
    }

    /// Materialize all traces for a specific harness version.
    /// Returns the directory containing the materialized files.
    func materialize(harnessVersion: String) async throws -> URL {
        let versionDir = baseDir.appendingPathComponent(sanitizeDirName(harnessVersion))
        let fm = FileManager.default
        try fm.createDirectory(at: versionDir, withIntermediateDirectories: true)

        // Query all trace index rows for this version
        let rows = try await traceStore.traces(forVersion: harnessVersion)
        Self.log.info("Materializing \(rows.count) trace events for \(harnessVersion)")

        // Group by session
        let bySession = Dictionary(grouping: rows, by: \.sessionId)

        var sessionSummaries: [[String: Any]] = []

        for (sessionId, sessionRows) in bySession {
            let sessionDir = versionDir.appendingPathComponent("session_\(sanitizeDirName(sessionId))")
            try fm.createDirectory(at: sessionDir, withIntermediateDirectories: true)

            // Extract original JSONL lines from source files
            var lines: [String] = []
            let rowsByFile = Dictionary(grouping: sessionRows, by: \.filePath)

            for (filePath, fileRows) in rowsByFile {
                guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
                    Self.log.warning("Source file missing: \(filePath)")
                    continue
                }
                let allLines = content.components(separatedBy: "\n")
                for row in fileRows.sorted(by: { $0.lineOffset < $1.lineOffset }) {
                    guard row.lineOffset < allLines.count else { continue }
                    let line = allLines[row.lineOffset]
                    if !line.isEmpty { lines.append(line) }
                }
            }

            // Write the session's events.jsonl
            let eventsFile = sessionDir.appendingPathComponent("events.jsonl")
            let content = lines.joined(separator: "\n")
            try content.write(to: eventsFile, atomically: true, encoding: .utf8)

            // Build session summary
            let eventTypes = Dictionary(grouping: sessionRows, by: \.eventType)
                .mapValues(\.count)
            let totalTokens = sessionRows.compactMap(\.tokenCost).reduce(0, +)
            let outcomes = sessionRows.compactMap(\.outcome)
            let passed = outcomes.filter { $0 == "passed" }.count
            let failed = outcomes.filter { $0 == "failed" }.count

            var summary: [String: Any] = [
                "sessionId": sessionId,
                "eventCount": sessionRows.count,
                "linesMaterialized": lines.count,
                "totalTokenCost": totalTokens,
                "eventTypes": eventTypes,
            ]
            if !outcomes.isEmpty {
                summary["passed"] = passed
                summary["failed"] = failed
            }
            sessionSummaries.append(summary)
        }

        // Write version-level summary.json
        let versionSummary: [String: Any] = [
            "harnessVersion": harnessVersion,
            "sessionCount": bySession.count,
            "totalEvents": rows.count,
            "materializedAt": HarnessLabTime.timestampString(),
            "sessions": sessionSummaries
        ]
        let summaryData = try JSONSerialization.data(withJSONObject: versionSummary, options: [.prettyPrinted, .sortedKeys])
        try summaryData.write(
            to: versionDir.appendingPathComponent("summary.json"),
            options: .atomic
        )

        Self.log.info("Materialized \(rows.count) events across \(bySession.count) sessions → \(versionDir.path)")
        return versionDir
    }

    /// Materialize traces for all harness versions that have indexed data.
    /// Returns the root directory containing all version subdirectories.
    func materializeAll() async throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: baseDir, withIntermediateDirectories: true)

        // Get distinct harness versions from the index
        let versions = try await traceStore.distinctHarnessVersions()

        for version in versions {
            _ = try await materialize(harnessVersion: version)
        }

        let root = self.baseDir
        Self.log.info("Materialized traces for \(versions.count) harness versions → \(root.path)")
        return baseDir
    }

    /// Remove all materialized trace files.
    func cleanup() {
        let root = self.baseDir
        do {
            let fm = FileManager.default
            if fm.fileExists(atPath: root.path) {
                try fm.removeItem(at: root)
                Self.log.info("Cleaned up materialized traces at \(root.path)")
            }
        } catch {
            Self.log.warning("Failed to clean up materialized traces: \(error.localizedDescription)")
        }
    }

    /// Check if materialized traces exist.
    func hasMaterializedTraces() -> Bool {
        FileManager.default.fileExists(atPath: baseDir.path)
    }

    /// Disk usage of materialized traces in bytes.
    func materializedDiskUsage() -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: baseDir, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        while let url = enumerator.nextObject() as? URL {
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    // MARK: - Private

    /// Sanitize a string for use as a directory name.
    private nonisolated func sanitizeDirName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        return String(name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
    }
}
#endif // !EPISTEMOS_APP_STORE -- Harness eval lab (subprocess spawning, Pro-only)
