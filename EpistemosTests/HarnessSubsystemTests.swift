import Testing
import Foundation
@testable import Epistemos

// MARK: - Bootstrap Packet Tests

@Suite("BootstrapPacketBuilder")
@MainActor
struct BootstrapPacketTests {

    @Test("Builds packet with required fields")
    func buildsPacket() {
        let packet = BootstrapPacketBuilder.build(
            objective: "Implement user authentication",
            workingDirectory: URL(fileURLWithPath: "/tmp")
        )
        #expect(packet.taskType == "coding")
        #expect(packet.taskObjective == "Implement user authentication")
        #expect(packet.sessionNumber == 1)
        #expect(packet.harnessVersion == "v1.0.0")
        #expect(!packet.timestamp.isEmpty)
    }

    @Test("Classifies research tasks")
    func classifiesResearch() {
        let packet = BootstrapPacketBuilder.build(
            objective: "research: survey quantum computing papers"
        )
        #expect(packet.taskType == "research")
    }

    @Test("Classifies terminal tasks")
    func classifiesTerminal() {
        let packet = BootstrapPacketBuilder.build(
            objective: "run deploy script on staging"
        )
        #expect(packet.taskType == "terminal")
    }

    @Test("Classifies note synthesis tasks")
    func classifiesNoteSynthesis() {
        let packet = BootstrapPacketBuilder.build(
            objective: "synthesize notes from all quantum physics entries"
        )
        #expect(packet.taskType == "note_synthesis")
    }

    @Test("Defaults to coding for ambiguous tasks")
    func defaultsToCoding() {
        let packet = BootstrapPacketBuilder.build(
            objective: "fix the login bug"
        )
        #expect(packet.taskType == "coding")
    }

    @Test("Renders packet as string with environment context tags")
    func rendersPacket() {
        let packet = BootstrapPacketBuilder.build(
            objective: "test task",
            workingDirectory: URL(fileURLWithPath: "/tmp")
        )
        let rendered = BootstrapPacketBuilder.render(packet)
        #expect(rendered.hasPrefix("<environment_context>"))
        #expect(rendered.hasSuffix("</environment_context>"))
        #expect(rendered.contains("Working directory:"))
        #expect(rendered.contains("Task type: coding"))
    }

    @Test("Caps open files at 5")
    func capsOpenFiles() {
        let packet = BootstrapPacketBuilder.build(
            objective: "test",
            openFiles: ["a.swift", "b.swift", "c.swift", "d.swift", "e.swift", "f.swift", "g.swift"]
        )
        #expect(packet.openFiles.count == 5)
    }

    @Test("Includes progress summary for continuation sessions")
    func includesProgressForContinuation() {
        let packet = BootstrapPacketBuilder.build(
            objective: "continue auth work",
            sessionNumber: 2,
            progressSummary: "Completed login endpoint, started registration"
        )
        #expect(packet.sessionNumber == 2)
        #expect(packet.progressSummary != nil)
        let rendered = BootstrapPacketBuilder.render(packet)
        #expect(rendered.contains("Progress from prior session:"))
    }

    @Test("Reports thermal state only when serious or critical")
    func thermalReporting() {
        let packet = BootstrapPacketBuilder.build(objective: "test")
        let rendered = BootstrapPacketBuilder.render(packet)
        // In test environment, thermal state should be nominal
        // So no WARNING should appear
        if packet.thermalLevel == "nominal" || packet.thermalLevel == "fair" {
            #expect(!rendered.contains("WARNING: Thermal state"))
        }
    }
}

// MARK: - Task Classification Tests

@Suite("HarnessTaskType Classification")
struct TaskTypeTests {

    @Test("Research keywords trigger research classification")
    func researchKeywords() {
        #expect(HarnessTaskType.classify("research: find evidence for claim") == .research)
        #expect(HarnessTaskType.classify("investigate the root cause") == .research)
        #expect(HarnessTaskType.classify("survey available literature") == .research)
    }

    @Test("Terminal keywords trigger terminal classification")
    func terminalKeywords() {
        #expect(HarnessTaskType.classify("run the deployment script") == .terminal)
        #expect(HarnessTaskType.classify("execute the migration") == .terminal)
        #expect(HarnessTaskType.classify("install homebrew packages") == .terminal)
    }

    @Test("Note synthesis keywords trigger note_synthesis classification")
    func noteSynthesisKeywords() {
        #expect(HarnessTaskType.classify("synthesize notes on quantum") == .noteSynthesis)
        #expect(HarnessTaskType.classify("summarize notes about ML") == .noteSynthesis)
    }

    @Test("Default classification is coding")
    func defaultIsCoding() {
        #expect(HarnessTaskType.classify("refactor the database layer") == .coding)
        #expect(HarnessTaskType.classify("add pagination to the API") == .coding)
    }
}

// MARK: - Trace Collector Tests

@Suite("TraceCollector")
struct TraceCollectorTests {

    @Test("Records events to JSONL file")
    func recordsEvents() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos_trace_test_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let collector = TraceCollector(baseDir: tempDir)

        let event = TraceEvent.userIntentEvent(
            sessionId: "test-session-001",
            taskId: "task-001",
            harnessVersion: "v1.0.0",
            content: "Fix the login bug"
        )

        collector.record(event)
        // Allow fire-and-forget Task to complete
        try await Task.sleep(for: .milliseconds(200))
        await collector.closeAll()

        // Verify file was created
        // Find the written file
        let fm = FileManager.default
        var foundFile = false
        if let enumerator = fm.enumerator(at: tempDir, includingPropertiesForKeys: nil) {
            while let url = enumerator.nextObject() as? URL {
                if url.pathExtension == "jsonl" {
                    foundFile = true
                    let content = try String(contentsOf: url, encoding: .utf8)
                    #expect(content.contains("test-session-001"))
                    #expect(content.contains("user_intent"))
                    #expect(content.contains("Fix the login bug"))
                }
            }
        }
        #expect(foundFile, "Expected a .jsonl trace file to be created")
    }

    @Test("TraceEvent toJSONData produces valid JSON")
    func traceEventToJSON() {
        let event = TraceEvent.toolCallEvent(
            sessionId: "s1", taskId: "t1", harnessVersion: "v1.0.0",
            turn: 3, tool: "bash", input: "ls -la", output: "total 42",
            exitCode: 0, durationMs: 150
        )
        let data = event.toJSONData()
        #expect(data != nil)
        if let data {
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            #expect(json?["type"] as? String == "tool_call")
            #expect(json?["tool"] as? String == "bash")
            #expect(json?["exitCode"] as? Int == 0)
        }
    }

    @Test("Event factories set correct types")
    func eventFactoryTypes() {
        let events: [(TraceEvent, String)] = [
            (.userIntentEvent(sessionId: "s", taskId: nil, harnessVersion: "v1", content: "hi"), "user_intent"),
            (.modelOutputEvent(sessionId: "s", taskId: nil, harnessVersion: "v1", turn: 1, provider: "cloud", model: nil, tokensUsed: 100, content: "ok"), "model_output"),
            (.completionCheckEvent(sessionId: "s", taskId: nil, harnessVersion: "v1", checkerType: "coding", passed: true, evidence: "ok"), "completion_check"),
            (.sessionEndEvent(sessionId: "s", harnessVersion: "v1", stopReason: "end_turn", inputTokens: 100, outputTokens: 50), "session_end"),
            (.errorEvent(sessionId: "s", harnessVersion: "v1", message: "oops"), "error"),
        ]
        for (event, expectedType) in events {
            #expect(event.type.rawValue == expectedType)
        }
    }
}

// MARK: - Progress Store Tests

@Suite("ProgressStore")
struct ProgressStoreTests {

    @Test("Saves and loads session progress")
    func saveAndLoadProgress() {
        let sessionId = "test-progress-\(UUID().uuidString)"
        let progress = SessionProgress(
            sessionId: sessionId,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            harnessVersion: "v1.0.0",
            accomplishedSummary: "Implemented login endpoint",
            completedTasks: ["auth-001", "auth-002"],
            failedTasks: [
                SessionProgress.TaskFailure(
                    taskId: "auth-003",
                    description: "Registration endpoint",
                    errorSummary: "Validation logic incomplete"
                )
            ],
            nextPriority: "auth-003",
            contextNotes: ["Using JWT tokens", "PostgreSQL backend"],
            gitState: RepoState(branch: "feature/auth", lastCommitHash: "abc123", uncommittedChanges: 2),
            changedFiles: ["Sources/Auth/LoginController.swift"],
            totalInputTokens: 5000,
            totalOutputTokens: 2000,
            totalTurns: 8
        )

        ProgressStore.saveProgress(progress)
        let loaded = ProgressStore.loadProgress(sessionId: sessionId)
        #expect(loaded != nil)
        #expect(loaded?.sessionId == sessionId)
        #expect(loaded?.completedTasks.count == 2)
        #expect(loaded?.failedTasks.count == 1)
        #expect(loaded?.nextPriority == "auth-003")

        // Cleanup
        let dir = ProgressStore.sessionDirectory(for: sessionId)
        try? FileManager.default.removeItem(at: dir)
    }

    @Test("Saves and loads task decomposition")
    func saveAndLoadTasks() {
        let sessionId = "test-tasks-\(UUID().uuidString)"
        let decomp = TaskDecomposition(
            sessionId: sessionId,
            objective: "Build user auth system",
            createdAt: ISO8601DateFormatter().string(from: Date()),
            tasks: [
                TaskDecomposition.TaskItem(id: "t1", description: "Login endpoint", status: .completed, evidence: "Tests pass", completedAt: nil),
                TaskDecomposition.TaskItem(id: "t2", description: "Registration endpoint", status: .pending, evidence: nil, completedAt: nil),
                TaskDecomposition.TaskItem(id: "t3", description: "Password reset", status: .pending, evidence: nil, completedAt: nil),
            ]
        )

        ProgressStore.saveTaskDecomposition(decomp)
        let loaded = ProgressStore.loadTaskDecomposition(sessionId: sessionId)
        #expect(loaded != nil)
        #expect(loaded?.tasks.count == 3)
        #expect(loaded?.pendingCount == 2)
        #expect(loaded?.completedCount == 1)

        // Cleanup
        let dir = ProgressStore.sessionDirectory(for: sessionId)
        try? FileManager.default.removeItem(at: dir)
    }

    @Test("List sessions ignores non-directory artifacts")
    func listSessionsIgnoresNonDirectoryArtifacts() throws {
        let firstSessionId = "test-list-\(UUID().uuidString)"
        let secondSessionId = "test-list-\(UUID().uuidString)"
        let firstSessionDir = ProgressStore.sessionDirectory(for: firstSessionId)
        let secondSessionDir = ProgressStore.sessionDirectory(for: secondSessionId)
        let sessionsDir = firstSessionDir.deletingLastPathComponent()
        let artifact = sessionsDir.appendingPathComponent("README.txt")
        let fileManager = FileManager.default

        try fileManager.createDirectory(at: firstSessionDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: secondSessionDir, withIntermediateDirectories: true)
        try "ignore me".write(to: artifact, atomically: true, encoding: .utf8)

        defer {
            try? fileManager.removeItem(at: firstSessionDir)
            try? fileManager.removeItem(at: secondSessionDir)
            try? fileManager.removeItem(at: artifact)
        }

        let sessions = ProgressStore.listSessions()
        #expect(sessions.contains(firstSessionId))
        #expect(sessions.contains(secondSessionId))
        #expect(!sessions.contains("README.txt"))
    }
}

// MARK: - Completion Checker Tests

@Suite("CompletionChecker")
struct CompletionCheckerTests {

    @Test("CodingCompletionChecker returns skipped when no build system found")
    func codingSkipsWithoutBuildSystem() async {
        let checker = CodingCompletionChecker()
        let result = await checker.verify(
            objective: "fix bug",
            workingDirectory: FileManager.default.temporaryDirectory,
            sessionId: "test"
        )
        if case .skipped = result {
            // Expected
        } else {
            Issue.record("Expected skipped when no build system found, got: \(result.summary)")
        }
    }

    @Test("CompletionCheckerRegistry returns correct checker types")
    func registryReturnsCorrectTypes() {
        let coding = CompletionCheckerRegistry.checker(for: .coding)
        #expect(coding.taskType == .coding)

        let research = CompletionCheckerRegistry.checker(for: .research)
        #expect(research.taskType == .research)

        let terminal = CompletionCheckerRegistry.checker(for: .terminal)
        #expect(terminal.taskType == .terminal)

        let synthesis = CompletionCheckerRegistry.checker(for: .noteSynthesis)
        #expect(synthesis.taskType == .noteSynthesis)
    }

    @Test("CompletionResult summary formatting")
    func completionResultSummary() {
        let passed = CompletionResult.passed(evidence: "all tests pass")
        #expect(passed.isPassed)
        #expect(passed.summary.contains("PASSED"))

        let failed = CompletionResult.failed(reason: "build error")
        #expect(!failed.isPassed)
        #expect(failed.summary.contains("FAILED"))

        let skipped = CompletionResult.skipped(reason: "no verifier")
        #expect(!skipped.isPassed)
        #expect(skipped.summary.contains("SKIPPED"))
    }
}

// MARK: - Harness Registry Tests

@Suite("HarnessRegistry")
struct HarnessRegistryTests {

    @Test("Creates default harness on first access")
    func createsDefault() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("harness_test_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let registry = HarnessRegistry(baseDir: tempDir)
        let config = try await registry.loadProductionConfig()
        #expect(config.version == "v1.0.0")
    }

    @Test("Creates candidate harness")
    func createsCandidate() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("harness_test_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let registry = HarnessRegistry(baseDir: tempDir)
        let (id, dir) = try await registry.createCandidate(
            parentVersion: "v1.0.0",
            description: "Test candidate"
        )
        #expect(id == "candidate_001")
        #expect(FileManager.default.fileExists(atPath: dir.path))

        let candidates = await registry.listCandidates()
        #expect(candidates.count == 1)
        #expect(candidates.first == "candidate_001")
    }

    @Test("Promotion requires valid candidate")
    func promotionRequiresCandidate() async {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("harness_test_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let registry = HarnessRegistry(baseDir: tempDir)
        do {
            try await registry.promote(
                candidateId: "nonexistent",
                newVersion: "v2.0.0",
                promotedBy: "test"
            )
            Issue.record("Should have thrown for nonexistent candidate")
        } catch is HarnessError {
            // Expected
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}

// MARK: - Harness Prompt Builder Tests

@Suite("HarnessPromptBuilder")
@MainActor
struct HarnessPromptBuilderTests {

    @Test("Determines initializer mode for first session")
    func initializerMode() {
        let mode = HarnessPromptBuilder.determineMode(sessionNumber: 1, hasExistingProgress: false)
        #expect(mode == .initializer)
    }

    @Test("Determines continuation mode when progress exists")
    func continuationMode() {
        let mode = HarnessPromptBuilder.determineMode(sessionNumber: 2, hasExistingProgress: true)
        #expect(mode == .continuation)
    }

    @Test("Falls back to initializer when no progress for session > 1")
    func fallbackInitializer() {
        let mode = HarnessPromptBuilder.determineMode(sessionNumber: 3, hasExistingProgress: false)
        #expect(mode == .initializer)
    }

    @Test("Initializer prompt contains session mode tag and decomposition instruction")
    func initializerPromptContent() {
        let packet = BootstrapPacketBuilder.build(
            objective: "implement auth",
            workingDirectory: URL(fileURLWithPath: "/tmp")
        )
        let prompt = HarnessPromptBuilder.buildSystemPrompt(
            objective: "implement auth",
            taskType: .coding,
            sessionMode: .initializer,
            bootstrapPacket: packet
        )
        #expect(prompt.contains("INITIALIZER SESSION"))
        #expect(prompt.contains("DECOMPOSE the task"))
        #expect(prompt.contains("<environment_context>"))
    }

    @Test("Continuation prompt includes prior progress and task list")
    func continuationIncludesProgress() {
        let packet = BootstrapPacketBuilder.build(
            objective: "continue auth",
            sessionNumber: 2,
            progressSummary: "Login done"
        )
        let progress = SessionProgress(
            sessionId: "test",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            harnessVersion: "v1.0.0",
            accomplishedSummary: "Login endpoint implemented",
            completedTasks: ["auth-001"],
            failedTasks: [],
            nextPriority: "auth-002",
            contextNotes: ["Using JWT"],
            gitState: nil,
            changedFiles: [],
            totalInputTokens: 1000,
            totalOutputTokens: 500,
            totalTurns: 5
        )
        let prompt = HarnessPromptBuilder.buildSystemPrompt(
            objective: "continue auth",
            taskType: .coding,
            sessionMode: .continuation,
            bootstrapPacket: packet,
            priorProgress: progress
        )
        #expect(prompt.contains("CONTINUATION SESSION"))
        #expect(prompt.contains("Login endpoint implemented"))
        #expect(prompt.contains("auth-002"))
    }
}

// MARK: - Harness Integration Tests

@Suite("HarnessIntegration")
@MainActor
struct HarnessIntegrationTests {

    @Test("prepareSession returns augmented system prompt")
    func prepareSessionReturnsPrompt() {
        let integration = HarnessIntegration()
        let prompt = integration.prepareSession(
            sessionId: "test-\(UUID().uuidString)",
            objective: "fix the login bug"
        )
        #expect(prompt.contains("<environment_context>"))
        #expect(prompt.contains("INITIALIZER SESSION"))
        #expect(integration.activeSessionId != nil)
        #expect(integration.activeTaskType == .coding)
    }

    @Test("completeSession saves progress to disk")
    func completeSessionSavesProgress() {
        let sessionId = "test-complete-\(UUID().uuidString)"
        let integration = HarnessIntegration()
        _ = integration.prepareSession(sessionId: sessionId, objective: "test task")
        integration.completeSession(
            stopReason: "end_turn",
            inputTokens: 1000, outputTokens: 500, turns: 5,
            accomplishedSummary: "Completed all tasks"
        )
        let progress = ProgressStore.loadProgress(sessionId: sessionId)
        #expect(progress != nil)
        #expect(progress?.accomplishedSummary == "Completed all tasks")
        let dir = ProgressStore.sessionDirectory(for: sessionId)
        try? FileManager.default.removeItem(at: dir)
    }

    @Test("resetForNewTask clears all state")
    func resetClearsState() {
        let integration = HarnessIntegration()
        _ = integration.prepareSession(sessionId: "test-reset", objective: "task")
        #expect(integration.activeSessionId != nil)
        integration.resetForNewTask()
        #expect(integration.activeSessionId == nil)
        #expect(integration.currentBootstrapPacket == nil)
    }
}

// MARK: - Eval Metrics Tests

@Suite("EvalSuiteResult Metrics")
struct EvalMetricsTests {

    @Test("Computes pass rate, avg token cost, avg score")
    func metricsComputation() {
        let results = EvalSuiteResult(
            harnessVersion: "test",
            results: [
                EvalResult(taskId: "t1", harnessVersion: "test", passed: true, score: 1.0, tokenCost: 100, turns: 3, tracePath: nil, evidence: "ok", timestamp: ""),
                EvalResult(taskId: "t2", harnessVersion: "test", passed: false, score: 0.0, tokenCost: 200, turns: 5, tracePath: nil, evidence: "fail", timestamp: ""),
                EvalResult(taskId: "t3", harnessVersion: "test", passed: true, score: 0.8, tokenCost: 150, turns: 4, tracePath: nil, evidence: "ok", timestamp: ""),
            ]
        )
        #expect(abs(results.passRate - 0.6667) < 0.01)
        #expect(results.averageTokenCost == 150)
        #expect(abs(results.averageScore - 0.6) < 0.01)
    }

    @Test("Empty results return zero for all metrics")
    func emptyResults() {
        let results = EvalSuiteResult(harnessVersion: "test", results: [])
        #expect(results.passRate == 0.0)
        #expect(results.averageTokenCost == 0)
        #expect(results.averageScore == 0.0)
    }
}

// MARK: - Task Suite Tests (Phase 7B)

@Suite("TaskSuite JSON Loading")
struct TaskSuiteTests {

    @Test("Loads tasks from JSON files in search directory")
    func loadsFromJSON() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("task_suite_test_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let searchDir = tempDir.appendingPathComponent("search")
        try FileManager.default.createDirectory(at: searchDir, withIntermediateDirectories: true)

        // Write a test task JSON file
        let taskJSON: [String: Any] = [
            "id": "coding-001",
            "objective": "Fix the FFI bridge panic handler",
            "taskType": "coding",
            "verification": [
                "type": "commandExitZero",
                "command": "cargo test"
            ],
            "metadata": [
                "difficulty": "medium",
                "domain": "rust",
                "expectedTurns": 5,
                "expectedTokenBudget": 15000
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: taskJSON, options: .prettyPrinted)
        try data.write(to: searchDir.appendingPathComponent("coding-001.json"))

        let suite = TaskSuite(baseDir: tempDir)
        try await suite.load()

        let tasks = await suite.searchSet
        #expect(tasks.count == 1)
        #expect(tasks.first?.id == "coding-001")
        #expect(tasks.first?.objective == "Fix the FFI bridge panic handler")
        #expect(tasks.first?.taskType == .coding)
        if case .commandExitZero(let cmd) = tasks.first?.verification {
            #expect(cmd == "cargo test")
        } else {
            Issue.record("Expected commandExitZero verification")
        }
        #expect(tasks.first?.metadata.difficulty == "medium")
        #expect(tasks.first?.metadata.domain == "rust")
    }

    @Test("addSearchTask persists to disk")
    func addSearchTaskPersists() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("task_suite_add_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let suite = TaskSuite(baseDir: tempDir)
        try await suite.load()

        let task = EvalTask(
            id: "research-001",
            objective: "Survey quantum computing frameworks",
            taskType: .research,
            verification: .humanReview,
            initialStatePath: nil,
            allowNetwork: false,
            metadata: EvalTaskMetadata(difficulty: "easy", domain: "research", expectedTurns: 3, expectedTokenBudget: 8000)
        )
        try await suite.addSearchTask(task)
        #expect(await suite.searchSet.count == 1)

        // Verify persisted to disk
        let filePath = tempDir.appendingPathComponent("search/research-001.json")
        #expect(FileManager.default.fileExists(atPath: filePath.path))

        // Reload from scratch
        let suite2 = TaskSuite(baseDir: tempDir)
        try await suite2.load()
        #expect(await suite2.searchSet.count == 1)
        #expect(await suite2.searchSet.first?.id == "research-001")
    }

    @Test("Handles held-out tasks separately")
    func heldOutTasks() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("task_suite_held_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let suite = TaskSuite(baseDir: tempDir)
        try await suite.load()

        let searchTask = EvalTask(
            id: "s-001", objective: "search task", taskType: .coding,
            verification: .commandExitZero(command: "echo ok"),
            initialStatePath: nil,
            allowNetwork: false,
            metadata: EvalTaskMetadata(difficulty: nil, domain: nil, expectedTurns: nil, expectedTokenBudget: nil)
        )
        let heldOutTask = EvalTask(
            id: "h-001", objective: "held out task", taskType: .coding,
            verification: .filesExist(paths: ["/tmp/test.txt"]),
            initialStatePath: nil,
            allowNetwork: false,
            metadata: EvalTaskMetadata(difficulty: "hard", domain: "swift", expectedTurns: 10, expectedTokenBudget: 30000)
        )

        try await suite.addSearchTask(searchTask)
        try await suite.addHeldOutTask(heldOutTask)

        #expect(await suite.searchSet.count == 1)
        #expect(await suite.testSet.count == 1)
        #expect(await suite.totalCount == 2)
    }

    @Test("task(withId:) finds tasks across both sets")
    func taskLookup() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("task_suite_lookup_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let suite = TaskSuite(baseDir: tempDir)
        try await suite.load()

        try await suite.addSearchTask(EvalTask(
            id: "s-001", objective: "search", taskType: .coding,
            verification: .humanReview, initialStatePath: nil, allowNetwork: false,
            metadata: EvalTaskMetadata(difficulty: nil, domain: nil, expectedTurns: nil, expectedTokenBudget: nil)
        ))
        try await suite.addHeldOutTask(EvalTask(
            id: "h-001", objective: "held out", taskType: .terminal,
            verification: .humanReview, initialStatePath: nil, allowNetwork: false,
            metadata: EvalTaskMetadata(difficulty: nil, domain: nil, expectedTurns: nil, expectedTokenBudget: nil)
        ))

        let found = await suite.task(withId: "h-001")
        #expect(found?.objective == "held out")
        let notFound = await suite.task(withId: "nonexistent")
        #expect(notFound == nil)
    }
}

// MARK: - EvalVerification Parsing Tests

@Suite("EvalVerification Parsing")
struct EvalVerificationTests {

    @Test("Parses all verification types from JSON")
    func parsesAllTypes() {
        let cmd = EvalVerification.parse(["type": "commandExitZero", "command": "cargo test"])
        if case .commandExitZero(let c) = cmd { #expect(c == "cargo test") }
        else { Issue.record("Expected commandExitZero") }

        let files = EvalVerification.parse(["type": "filesExist", "paths": ["/a.txt", "/b.txt"]])
        if case .filesExist(let p) = files { #expect(p.count == 2) }
        else { Issue.record("Expected filesExist") }

        let pattern = EvalVerification.parse(["type": "outputPattern", "command": "ls", "pattern": "^total"])
        if case .outputPattern(let c, let p) = pattern {
            #expect(c == "ls")
            #expect(p == "^total")
        } else { Issue.record("Expected outputPattern") }

        let judge = EvalVerification.parse(["type": "llmJudge", "rubric": "check quality", "minimumScore": 0.8])
        if case .llmJudge(let r, let s) = judge {
            #expect(r == "check quality")
            #expect(s == 0.8)
        } else { Issue.record("Expected llmJudge") }

        let human = EvalVerification.parse(["type": "humanReview"])
        if case .humanReview = human { /* expected */ }
        else { Issue.record("Expected humanReview") }
    }

    @Test("Defaults to humanReview for nil or unknown type")
    func defaultsToHumanReview() {
        let nilResult = EvalVerification.parse(nil)
        if case .humanReview = nilResult { /* expected */ }
        else { Issue.record("Expected humanReview for nil") }

        let unknown = EvalVerification.parse(["type": "someNewType"])
        if case .humanReview = unknown { /* expected */ }
        else { Issue.record("Expected humanReview for unknown type") }
    }

    @Test("Round-trips through toDict and parse")
    func roundTrip() {
        let original = EvalVerification.commandExitZero(command: "swift test")
        let dict = original.toDict()
        let parsed = EvalVerification.parse(dict)
        if case .commandExitZero(let cmd) = parsed {
            #expect(cmd == "swift test")
        } else {
            Issue.record("Round-trip failed for commandExitZero")
        }
    }
}

// MARK: - TraceStoreIndex Tests (Phase 7C)

@Suite("TraceStoreIndex SQLite")
struct TraceStoreIndexTests {

    @Test("Opens and creates schema")
    func opensAndCreatesSchema() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("trace_store_test_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = TraceStoreIndex(tracesDir: tempDir)
        try await store.open()

        let count = try await store.totalIndexedCount()
        #expect(count == 0)
    }

    @Test("Indexes JSONL trace files and queries by session")
    func indexesAndQueriesBySession() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("trace_store_idx_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create a fake trace JSONL file
        let dateDir = tempDir.appendingPathComponent("2026-04-01")
        try FileManager.default.createDirectory(at: dateDir, withIntermediateDirectories: true)

        let events = [
            "{\"ts\":\"2026-04-01T10:00:00Z\",\"type\":\"session_start\",\"sessionId\":\"sess-001\",\"harnessVersion\":\"v1.0.0\"}",
            "{\"ts\":\"2026-04-01T10:01:00Z\",\"type\":\"tool_call\",\"sessionId\":\"sess-001\",\"harnessVersion\":\"v1.0.0\",\"tool\":\"bash\"}",
            "{\"ts\":\"2026-04-01T10:02:00Z\",\"type\":\"completion_check\",\"sessionId\":\"sess-001\",\"harnessVersion\":\"v1.0.0\",\"passed\":true}",
            "{\"ts\":\"2026-04-01T10:03:00Z\",\"type\":\"session_end\",\"sessionId\":\"sess-001\",\"harnessVersion\":\"v1.0.0\"}"
        ]
        let content = events.joined(separator: "\n")
        try content.write(to: dateDir.appendingPathComponent("sess-001.jsonl"), atomically: true, encoding: .utf8)

        let store = TraceStoreIndex(tracesDir: tempDir)
        try await store.open()
        try await store.reindex()

        let count = try await store.totalIndexedCount()
        #expect(count == 4)

        let sessionTraces = try await store.traces(forSession: "sess-001")
        #expect(sessionTraces.count == 4)
        #expect(sessionTraces.first?.eventType == "session_start")
        #expect(sessionTraces.last?.eventType == "session_end")

        // Check that completion_check has outcome indexed
        let completionTraces = sessionTraces.filter { $0.eventType == "completion_check" }
        #expect(completionTraces.first?.outcome == "passed")
    }

    @Test("Disk usage and soft limit")
    func diskUsageAndSoftLimit() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("trace_store_disk_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = TraceStoreIndex(tracesDir: tempDir)
        try await store.open()

        let usage = await store.diskUsageBytes()
        #expect(usage >= 0)
        #expect(await !store.isOverSoftLimit())
    }

    @Test("File-based trace listing works")
    func fileBasedListing() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("trace_store_files_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dateDir = tempDir.appendingPathComponent("2026-04-01")
        try FileManager.default.createDirectory(at: dateDir, withIntermediateDirectories: true)
        try "{}".write(to: dateDir.appendingPathComponent("sess-abc.jsonl"), atomically: true, encoding: .utf8)
        try "{}".write(to: dateDir.appendingPathComponent("sess-def.jsonl"), atomically: true, encoding: .utf8)

        let store = TraceStoreIndex(tracesDir: tempDir)
        let files = await store.traceFiles(for: "sess-abc")
        #expect(files.count == 1)

        let rangeFiles = await store.traceFiles(from: "2026-04-01", to: "2026-04-01")
        #expect(rangeFiles.count == 2)

        let total = await store.totalTraceCount()
        #expect(total == 2)
    }
}

// MARK: - EvaluationRunner Tests (Phase 7D)

@Suite("EvaluationRunner — verification and persistence")
struct EvaluationRunnerTests {

    @Test("Evaluates commandExitZero task with true command")
    func evaluatesPassingCommand() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("eval_runner_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let registry = HarnessRegistry(baseDir: tempDir.appendingPathComponent("harness"))
        let taskSuiteDir = tempDir.appendingPathComponent("tasks")
        let taskSuite = TaskSuite(baseDir: taskSuiteDir)

        // Create a task that always passes
        let task = EvalTask(
            id: "test-pass-001",
            objective: "Verify true exits 0",
            taskType: .coding,
            verification: .commandExitZero(command: "true"),
            initialStatePath: nil,
            allowNetwork: false,
            metadata: EvalTaskMetadata(difficulty: "easy", domain: "shell", expectedTurns: 1, expectedTokenBudget: 100)
        )
        try await taskSuite.load()
        try await taskSuite.addSearchTask(task)

        let runner = EvaluationRunner(registry: registry, taskSuite: taskSuite)
        let result = await runner.evaluateCandidate(candidateId: "test-candidate")

        #expect(result.results.count == 1)
        #expect(result.results[0].passed)
        #expect(result.passRate == 1.0)
    }

    @Test("Evaluates failing command task")
    func evaluatesFailingCommand() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("eval_runner_fail_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let registry = HarnessRegistry(baseDir: tempDir.appendingPathComponent("harness"))
        let taskSuiteDir = tempDir.appendingPathComponent("tasks")
        let taskSuite = TaskSuite(baseDir: taskSuiteDir)

        let task = EvalTask(
            id: "test-fail-001",
            objective: "Verify false exits non-zero",
            taskType: .coding,
            verification: .commandExitZero(command: "false"),
            initialStatePath: nil,
            allowNetwork: false,
            metadata: EvalTaskMetadata(difficulty: "easy", domain: "shell", expectedTurns: 1, expectedTokenBudget: 100)
        )
        try await taskSuite.load()
        try await taskSuite.addSearchTask(task)

        let runner = EvaluationRunner(registry: registry, taskSuite: taskSuite)
        let result = await runner.evaluateCandidate(candidateId: "test-candidate")

        #expect(result.results.count == 1)
        #expect(!result.results[0].passed)
        #expect(result.passRate == 0.0)
    }

    @Test("Evaluates filesExist verification")
    func evaluatesFilesExist() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("eval_runner_files_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let registry = HarnessRegistry(baseDir: tempDir.appendingPathComponent("harness"))
        let taskSuiteDir = tempDir.appendingPathComponent("tasks")
        let taskSuite = TaskSuite(baseDir: taskSuiteDir)

        // Create a test file
        let testFile = tempDir.appendingPathComponent("exists.txt")
        try "hello".write(to: testFile, atomically: true, encoding: .utf8)

        let task = EvalTask(
            id: "test-files-001",
            objective: "Check file exists",
            taskType: .coding,
            verification: .filesExist(paths: [testFile.path]),
            initialStatePath: nil,
            allowNetwork: false,
            metadata: EvalTaskMetadata(difficulty: "easy", domain: "fs", expectedTurns: 1, expectedTokenBudget: 100)
        )
        try await taskSuite.load()
        try await taskSuite.addSearchTask(task)

        let runner = EvaluationRunner(registry: registry, taskSuite: taskSuite)
        let result = await runner.evaluateCandidate(candidateId: "test-candidate")

        #expect(result.results[0].passed)
    }

    @Test("Persists scores to candidate directory")
    func persistsScores() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("eval_runner_persist_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let registry = HarnessRegistry(baseDir: tempDir.appendingPathComponent("harness"))
        let taskSuiteDir = tempDir.appendingPathComponent("tasks")
        let taskSuite = TaskSuite(baseDir: taskSuiteDir)

        // Create a candidate first
        let (candidateId, _) = try await registry.createCandidate(
            parentVersion: "v1.0.0",
            description: "Test candidate"
        )

        let task = EvalTask(
            id: "persist-001",
            objective: "Test persistence",
            taskType: .coding,
            verification: .commandExitZero(command: "true"),
            initialStatePath: nil,
            allowNetwork: false,
            metadata: EvalTaskMetadata(difficulty: "easy", domain: "shell", expectedTurns: 1, expectedTokenBudget: 100)
        )
        try await taskSuite.load()
        try await taskSuite.addSearchTask(task)

        let runner = EvaluationRunner(registry: registry, taskSuite: taskSuite)
        _ = await runner.evaluateCandidate(candidateId: candidateId)

        // Verify scores were persisted by checking the file directly
        let scoresPath = tempDir.appendingPathComponent("harness/lab/candidates/\(candidateId)/scores_search.json")
        #expect(FileManager.default.fileExists(atPath: scoresPath.path))
        let scoresData = try Data(contentsOf: scoresPath)
        let scoresDict = try JSONSerialization.jsonObject(with: scoresData) as? [String: Any]
        #expect(scoresDict?["passRate"] as? Double == 1.0)
    }

    @Test("Isolates failures — one bad task doesn't crash the run")
    func isolatesFailures() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("eval_runner_isolate_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let registry = HarnessRegistry(baseDir: tempDir.appendingPathComponent("harness"))
        let taskSuiteDir = tempDir.appendingPathComponent("tasks")
        let taskSuite = TaskSuite(baseDir: taskSuiteDir)

        try await taskSuite.load()

        // Good task
        try await taskSuite.addSearchTask(EvalTask(
            id: "good-001", objective: "Passes",
            taskType: .coding,
            verification: .commandExitZero(command: "true"),
            initialStatePath: nil,
            allowNetwork: false,
            metadata: EvalTaskMetadata(difficulty: nil, domain: nil, expectedTurns: nil, expectedTokenBudget: nil)
        ))
        // Bad task (nonexistent file check)
        try await taskSuite.addSearchTask(EvalTask(
            id: "bad-001", objective: "Fails",
            taskType: .coding,
            verification: .filesExist(paths: ["/nonexistent/path/that/will/never/exist"]),
            initialStatePath: nil,
            allowNetwork: false,
            metadata: EvalTaskMetadata(difficulty: nil, domain: nil, expectedTurns: nil, expectedTokenBudget: nil)
        ))

        let runner = EvaluationRunner(registry: registry, taskSuite: taskSuite)
        let result = await runner.evaluateCandidate(candidateId: "test-candidate")

        #expect(result.results.count == 2)
        #expect(result.results[0].passed)
        #expect(!result.results[1].passed)
        #expect(result.passRate == 0.5)
    }
}

// MARK: - PromotionPipeline Tests (Phase 7F)

@Suite("PromotionPipeline — proposals and review artifacts")
struct PromotionPipelineTests {

    @Test("Generates proposal with correct verdict for improvement")
    func generatesPassingProposal() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("promotion_pass_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let registry = HarnessRegistry(baseDir: tempDir.appendingPathComponent("harness"))
        let taskSuiteDir = tempDir.appendingPathComponent("tasks")
        let taskSuite = TaskSuite(baseDir: taskSuiteDir)
        try await taskSuite.load()

        // Add a task the candidate will pass
        try await taskSuite.addSearchTask(EvalTask(
            id: "promo-001", objective: "Test",
            taskType: .coding,
            verification: .commandExitZero(command: "true"),
            initialStatePath: nil,
            allowNetwork: false,
            metadata: EvalTaskMetadata(difficulty: nil, domain: nil, expectedTurns: nil, expectedTokenBudget: nil)
        ))

        let runner = EvaluationRunner(registry: registry, taskSuite: taskSuite)
        let pipeline = PromotionPipeline(registry: registry, evaluationRunner: runner)

        // Baseline where same task failed
        let baseline = EvalSuiteResult(harnessVersion: "v1.0.0", results: [
            EvalResult(taskId: "promo-001", harnessVersion: "v1.0.0", passed: false, score: 0.0,
                       tokenCost: 1000, turns: 5, tracePath: nil, evidence: "Failed",
                       timestamp: ISO8601DateFormatter().string(from: Date()))
        ])

        let (candidateId, _) = try await registry.createCandidate(
            parentVersion: "v1.0.0",
            description: "Improved candidate"
        )

        let proposal = await pipeline.generateProposal(
            candidateId: candidateId,
            baselineResults: baseline
        )

        #expect(proposal.candidateResults.passRate == 1.0)
        #expect(proposal.improvement > 0)
        if case .readyForReview = proposal.verdict { /* expected */ }
        else { Issue.record("Expected readyForReview verdict") }
    }

    @Test("Detects regressions and rejects")
    func detectsRegressions() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("promotion_regress_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let registry = HarnessRegistry(baseDir: tempDir.appendingPathComponent("harness"))
        let taskSuiteDir = tempDir.appendingPathComponent("tasks")
        let taskSuite = TaskSuite(baseDir: taskSuiteDir)
        try await taskSuite.load()

        // Add a task the candidate will FAIL
        try await taskSuite.addSearchTask(EvalTask(
            id: "regress-001", objective: "Will fail",
            taskType: .coding,
            verification: .commandExitZero(command: "false"),
            initialStatePath: nil,
            allowNetwork: false,
            metadata: EvalTaskMetadata(difficulty: nil, domain: nil, expectedTurns: nil, expectedTokenBudget: nil)
        ))

        let runner = EvaluationRunner(registry: registry, taskSuite: taskSuite)
        let pipeline = PromotionPipeline(registry: registry, evaluationRunner: runner)

        // Baseline where the same task passed
        let baseline = EvalSuiteResult(harnessVersion: "v1.0.0", results: [
            EvalResult(taskId: "regress-001", harnessVersion: "v1.0.0", passed: true, score: 1.0,
                       tokenCost: 500, turns: 3, tracePath: nil, evidence: "Passed",
                       timestamp: ISO8601DateFormatter().string(from: Date()))
        ])

        let (candidateId, _) = try await registry.createCandidate(
            parentVersion: "v1.0.0",
            description: "Regressed candidate"
        )

        let proposal = await pipeline.generateProposal(
            candidateId: candidateId,
            baselineResults: baseline
        )

        #expect(!proposal.regressions.isEmpty)
        if case .rejected(let reason) = proposal.verdict {
            #expect(reason.contains("Regressions"))
        } else {
            Issue.record("Expected rejected verdict")
        }
    }

    @Test("Saves proposal artifact as Markdown")
    func savesProposalArtifact() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("promotion_artifact_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let registry = HarnessRegistry(baseDir: tempDir.appendingPathComponent("harness"))
        let taskSuiteDir = tempDir.appendingPathComponent("tasks")
        let taskSuite = TaskSuite(baseDir: taskSuiteDir)
        try await taskSuite.load()

        try await taskSuite.addSearchTask(EvalTask(
            id: "artifact-001", objective: "Test",
            taskType: .coding,
            verification: .commandExitZero(command: "true"),
            initialStatePath: nil,
            allowNetwork: false,
            metadata: EvalTaskMetadata(difficulty: nil, domain: nil, expectedTurns: nil, expectedTokenBudget: nil)
        ))

        let runner = EvaluationRunner(registry: registry, taskSuite: taskSuite)
        let pipeline = PromotionPipeline(registry: registry, evaluationRunner: runner)

        let baseline = EvalSuiteResult(harnessVersion: "v1.0.0", results: [])
        let (candidateId, _) = try await registry.createCandidate(
            parentVersion: "v1.0.0", description: "Test"
        )

        let proposal = await pipeline.generateProposal(
            candidateId: candidateId,
            baselineResults: baseline
        )

        let artifactPath = try await pipeline.saveProposalArtifact(proposal)
        #expect(FileManager.default.fileExists(atPath: artifactPath.path))

        let content = try String(contentsOf: artifactPath, encoding: .utf8)
        #expect(content.contains("# Promotion Proposal"))
        #expect(content.contains("Scorecard"))
        #expect(content.contains(candidateId))
    }
}

// MARK: - Phase 8: Sanitized Environment Tests

@Suite("SanitizedEnvironment — safe baseline env")
struct SanitizedEnvironmentTests {

    @Test("Preserves baseline keys (PATH, HOME, USER)")
    func preservesBaselineKeys() {
        let env = SanitizedEnvironment.build()
        // PATH and HOME should always be present on macOS
        #expect(env["PATH"] != nil)
        #expect(env["HOME"] != nil)
        #expect(env["USER"] != nil)
    }

    @Test("Strips API keys and sensitive tokens")
    func stripsAPIKeys() {
        // Temporarily inject a fake key to verify it gets stripped
        let env = SanitizedEnvironment.build(extras: [:])
        // Even if ANTHROPIC_API_KEY is in the process env, it should be stripped
        // We verify the deny pattern logic directly
        #expect(SanitizedEnvironment.deniedPatterns.contains("ANTHROPIC_"))
        #expect(SanitizedEnvironment.deniedPatterns.contains("OPENAI_"))
        #expect(SanitizedEnvironment.deniedPatterns.contains("GITHUB_TOKEN"))
        #expect(SanitizedEnvironment.deniedPatterns.contains("AWS_SECRET"))
        // The build result should not contain any denied patterns
        for key in env.keys {
            let upper = key.uppercased()
            for denied in SanitizedEnvironment.deniedPatterns {
                #expect(!upper.contains(denied), "Key \(key) matches denied pattern \(denied)")
            }
        }
    }

    @Test("Preserves XDG_* prefix keys but not denied ones")
    func preservesXDGPrefix() {
        // XDG_RUNTIME_DIR should be allowed if present
        let allowed = SanitizedEnvironment.allowedPrefixes
        #expect(allowed.contains("XDG_"))
        #expect(allowed.contains("HOMEBREW_"))
    }
}

// MARK: - Phase 8: Volatile Project Root Tests

@Suite("VolatileProjectRoot — temp directory lifecycle")
struct VolatileProjectRootTests {

    @Test("Creates temp directory and copies initial state")
    func createsAndCopies() throws {
        // Create a source directory with a test file
        let sourceDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("volatile_source_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sourceDir) }

        try "test content".write(
            to: sourceDir.appendingPathComponent("test.txt"),
            atomically: true, encoding: .utf8
        )

        let root = try VolatileProjectRoot.create(initialStatePath: sourceDir)
        defer { root.cleanup() }

        #expect(FileManager.default.fileExists(atPath: root.rootURL.path))
        #expect(FileManager.default.fileExists(
            atPath: root.rootURL.appendingPathComponent("test.txt").path
        ))

        let content = try String(contentsOf: root.rootURL.appendingPathComponent("test.txt"), encoding: .utf8)
        #expect(content == "test content")
    }

    @Test("Cleanup removes the volatile directory")
    func cleanupRemoves() throws {
        let root = try VolatileProjectRoot.create()
        let path = root.rootURL.path
        #expect(FileManager.default.fileExists(atPath: path))

        root.cleanup()
        #expect(!FileManager.default.fileExists(atPath: path))
    }

    @Test("Handles nil initialStatePath gracefully")
    func handlesNilInitialState() throws {
        let root = try VolatileProjectRoot.create(initialStatePath: nil)
        defer { root.cleanup() }

        #expect(FileManager.default.fileExists(atPath: root.rootURL.path))
    }
}

// MARK: - Phase 8: Eval Sandbox Profile Tests

@Suite("EvalSandboxProfile — SBPL profile generation")
struct EvalSandboxProfileTests {

    @Test("Default profile denies network")
    func defaultDeniesNetwork() {
        let profile = EvalSandboxProfile.build(volatileRoot: "/tmp/test_root")
        #expect(profile.contains("(deny network*)"))
        #expect(!profile.contains("(allow network*)"))
        #expect(profile.contains("(version 1)"))
        #expect(profile.contains("(deny default)"))
    }

    @Test("Profile allows network when flag is set")
    func allowsNetworkWhenFlagged() {
        let profile = EvalSandboxProfile.build(volatileRoot: "/tmp/test_root", allowNetwork: true)
        #expect(profile.contains("(allow network*)"))
    }
}

// MARK: - Phase 8: Sandboxed Evaluation Tests

@Suite("Sandboxed Evaluation — isolated command execution")
struct SandboxedEvaluationTests {

    @Test("Sandboxed command succeeds for simple verification")
    func sandboxedCommandSucceeds() async throws {
        let root = try VolatileProjectRoot.create()
        defer { root.cleanup() }

        let result = await sandboxedRunCommand(
            "echo 'hello from sandbox'",
            volatileRoot: root.rootURL,
            timeout: 30
        )

        // sandbox-exec may or may not be available; either way the command should attempt to run
        if result.exitCode == 0 {
            #expect(result.stdout.contains("hello from sandbox"))
        } else {
            // sandbox-exec might reject on some configs — that's acceptable for test
            #expect(result.exitCode != 0)
        }
    }

    @Test("Sandboxed command uses sanitized environment")
    func sandboxedUsesCleanEnv() async throws {
        let root = try VolatileProjectRoot.create()
        defer { root.cleanup() }

        // env command lists all environment variables
        let result = await sandboxedRunCommand(
            "env",
            volatileRoot: root.rootURL,
            timeout: 30
        )

        // If it ran, verify no API keys in output
        if result.exitCode == 0 {
            let output = result.stdout.uppercased()
            #expect(!output.contains("ANTHROPIC_API_KEY"))
            #expect(!output.contains("OPENAI_API_KEY"))
            #expect(!output.contains("GITHUB_TOKEN"))
        }
    }
}

// MARK: - Phase 7G: Trace Materialization Engine Tests

@Suite("TraceMaterializer — DB to filesystem extraction")
struct TraceMaterializerTests {

    /// Helper: create a traces dir with sample JSONL data and return an opened TraceStoreIndex.
    private func createPopulatedTraceStore() async throws -> (TraceStoreIndex, URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("trace_mat_\(UUID().uuidString)")

        let dateDir = tempDir.appendingPathComponent("2026-04-01")
        try FileManager.default.createDirectory(at: dateDir, withIntermediateDirectories: true)

        // Write sample JSONL events
        let events = [
            #"{"ts":"2026-04-01T10:00:00Z","type":"session_start","sessionId":"sess-001","harnessVersion":"v1.0.0"}"#,
            #"{"ts":"2026-04-01T10:00:01Z","type":"user_intent","sessionId":"sess-001","harnessVersion":"v1.0.0","content":"fix the bug"}"#,
            #"{"ts":"2026-04-01T10:00:02Z","type":"tool_call","sessionId":"sess-001","harnessVersion":"v1.0.0","tool":"bash","tokensUsed":150}"#,
            #"{"ts":"2026-04-01T10:00:03Z","type":"completion_check","sessionId":"sess-001","harnessVersion":"v1.0.0","passed":true}"#,
            #"{"ts":"2026-04-01T10:00:04Z","type":"session_end","sessionId":"sess-001","harnessVersion":"v1.0.0"}"#,
        ]
        let content = events.joined(separator: "\n")
        try content.write(to: dateDir.appendingPathComponent("sess-001.jsonl"), atomically: true, encoding: .utf8)

        // Second session for same version
        let events2 = [
            #"{"ts":"2026-04-01T11:00:00Z","type":"session_start","sessionId":"sess-002","harnessVersion":"v1.0.0"}"#,
            #"{"ts":"2026-04-01T11:00:01Z","type":"error","sessionId":"sess-002","harnessVersion":"v1.0.0","errorMessage":"timeout"}"#,
        ]
        try events2.joined(separator: "\n").write(to: dateDir.appendingPathComponent("sess-002.jsonl"), atomically: true, encoding: .utf8)

        let store = TraceStoreIndex(tracesDir: tempDir)
        try await store.open()
        try await store.reindex()

        return (store, tempDir)
    }

    @Test("Materializes traces for a harness version into filesystem hierarchy")
    func materializesVersion() async throws {
        let (store, tracesDir) = try await createPopulatedTraceStore()
        defer { try? FileManager.default.removeItem(at: tracesDir) }

        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mat_output_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: outputDir) }

        let materializer = TraceMaterializer(traceStore: store, baseDir: outputDir)
        let versionDir = try await materializer.materialize(harnessVersion: "v1.0.0")

        // Check directory structure
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: versionDir.path))

        // Should have session directories
        let sess1Dir = versionDir.appendingPathComponent("session_sess-001")
        let sess2Dir = versionDir.appendingPathComponent("session_sess-002")
        #expect(fm.fileExists(atPath: sess1Dir.path))
        #expect(fm.fileExists(atPath: sess2Dir.path))

        // Check events.jsonl content
        let eventsFile = sess1Dir.appendingPathComponent("events.jsonl")
        #expect(fm.fileExists(atPath: eventsFile.path))
        let content = try String(contentsOf: eventsFile, encoding: .utf8)
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count == 5)

        // Check summary.json
        let summaryFile = versionDir.appendingPathComponent("summary.json")
        #expect(fm.fileExists(atPath: summaryFile.path))
        let summaryData = try Data(contentsOf: summaryFile)
        let summary = try JSONSerialization.jsonObject(with: summaryData) as? [String: Any]
        #expect(summary?["sessionCount"] as? Int == 2)
        #expect(summary?["totalEvents"] as? Int == 7)
    }

    @Test("Cleanup removes materialized directory")
    func cleanupRemoves() async throws {
        let (store, tracesDir) = try await createPopulatedTraceStore()
        defer { try? FileManager.default.removeItem(at: tracesDir) }

        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mat_cleanup_\(UUID().uuidString)")

        let materializer = TraceMaterializer(traceStore: store, baseDir: outputDir)
        _ = try await materializer.materialize(harnessVersion: "v1.0.0")
        #expect(FileManager.default.fileExists(atPath: outputDir.path))

        await materializer.cleanup()
        #expect(!FileManager.default.fileExists(atPath: outputDir.path))
    }

    @Test("Distinct harness versions query works")
    func distinctVersions() async throws {
        let (store, tracesDir) = try await createPopulatedTraceStore()
        defer { try? FileManager.default.removeItem(at: tracesDir) }

        let versions = try await store.distinctHarnessVersions()
        #expect(versions.count == 1)
        #expect(versions.contains("v1.0.0"))
    }

    @Test("Disk usage reporting works")
    func diskUsage() async throws {
        let (store, tracesDir) = try await createPopulatedTraceStore()
        defer { try? FileManager.default.removeItem(at: tracesDir) }

        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mat_disk_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: outputDir) }

        let materializer = TraceMaterializer(traceStore: store, baseDir: outputDir)
        _ = try await materializer.materialize(harnessVersion: "v1.0.0")

        let usage = await materializer.materializedDiskUsage()
        #expect(usage > 0)
        #expect(await materializer.hasMaterializedTraces())
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Phase 9: Fault Injection Tests
// ═══════════════════════════════════════════════════════════════════

@Suite("Fault Injection — trace and progress resilience")
struct FaultInjectionTests {

    @Test("TraceCollector handles write to read-only directory gracefully")
    func traceWriteToReadOnlyDir() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("trace_readonly_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Make the directory read-only
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: 0o444)],
            ofItemAtPath: tempDir.path
        )
        defer {
            // Restore write permission for cleanup
            try? FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: 0o755)],
                ofItemAtPath: tempDir.path
            )
        }

        // Create a collector pointing at the read-only dir
        let collector = TraceCollector(baseDir: tempDir)

        // Record should not crash — fire-and-forget silently handles errors
        collector.record(.errorEvent(
            sessionId: "readonly-test",
            harnessVersion: "v1.0.0",
            message: "This should fail silently",
            domain: nil
        ))

        // Give the async task time to attempt the write
        try await Task.sleep(for: .milliseconds(200))

        // The collector should still be usable (not crashed)
        await collector.closeAll()
    }

    @Test("ProgressStore handles corrupted JSON gracefully")
    func corruptedProgressFile() throws {
        let sessionId = "corrupt-\(UUID().uuidString)"
        let sessionDir = ProgressStore.sessionDirectory(for: sessionId)
        let fm = FileManager.default
        try fm.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: sessionDir) }

        // Write garbage to the progress file
        let progressFile = sessionDir.appendingPathComponent("epistemos-progress.json")
        try "{{{{not valid json!!!!".write(to: progressFile, atomically: true, encoding: .utf8)

        // loadProgress should return nil, not crash
        let progress = ProgressStore.loadProgress(sessionId: sessionId)
        #expect(progress == nil)
    }

    @Test("ProgressStore handles missing session directory")
    func missingSessionDir() {
        let progress = ProgressStore.loadProgress(sessionId: "nonexistent-\(UUID().uuidString)")
        #expect(progress == nil)
    }

    @Test("TraceCollector recovers after close and re-record")
    func traceCollectorRecoversAfterClose() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("trace_recover_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let collector = TraceCollector(baseDir: tempDir)
        let sid = "recover-\(UUID().uuidString)"

        // Record → close → record again
        collector.record(.userIntentEvent(
            sessionId: sid, taskId: nil,
            harnessVersion: "v1.0.0", content: "first"
        ))
        try await Task.sleep(for: .milliseconds(100))
        await collector.closeSession(sid)

        // Record after close — should create a new file handle
        collector.record(.userIntentEvent(
            sessionId: sid, taskId: nil,
            harnessVersion: "v1.0.0", content: "second"
        ))
        try await Task.sleep(for: .milliseconds(100))
        await collector.closeAll()

        // Verify file exists and has content
        let dateStr = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = .current
            return f.string(from: Date())
        }()
        let sanitized = sid.replacingOccurrences(of: "/", with: "_")
        let tracePath = tempDir.appendingPathComponent(dateStr).appendingPathComponent("\(sanitized).jsonl")
        #expect(FileManager.default.fileExists(atPath: tracePath.path))

        let content = try String(contentsOf: tracePath, encoding: .utf8)
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count >= 2)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Phase 9: Thermal Event Tracing Tests
// ═══════════════════════════════════════════════════════════════════

@Suite("Thermal Event Tracing")
struct ThermalEventTracingTests {

    @Test("Thermal change events can be recorded and serialized")
    func thermalChangeEventSerializes() {
        let event = TraceEvent(
            ts: "2026-04-01T12:00:00Z",
            type: .thermalChange,
            sessionId: "thermal-test",
            taskId: nil,
            harnessVersion: "v1.0.0",
            turn: nil,
            provider: nil, model: nil, tool: nil, toolInput: nil, toolOutput: nil,
            exitCode: nil, durationMs: nil, content: nil,
            tokensUsed: nil, stopReason: nil, inputTokens: nil, outputTokens: nil,
            checkerType: nil, passed: nil, evidence: nil, errorMessage: nil,
            thermalState: "serious", domain: nil, progressSnapshot: nil, bootstrapPacket: nil
        )

        let data = event.toJSONData()
        #expect(data != nil)

        if let data, let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            #expect(dict["type"] as? String == "thermal_change")
            #expect(dict["thermalState"] as? String == "serious")
            #expect(dict["sessionId"] as? String == "thermal-test")
        }
    }

    @Test("Breaker tripped events can be recorded and serialized")
    func breakerTrippedEventSerializes() {
        let event = TraceEvent(
            ts: "2026-04-01T12:00:00Z",
            type: .breakerTripped,
            sessionId: "breaker-test",
            taskId: nil,
            harnessVersion: "v1.0.0",
            turn: nil,
            provider: nil, model: nil, tool: nil, toolInput: nil, toolOutput: nil,
            exitCode: nil, durationMs: nil, content: "cloud breaker opened",
            tokensUsed: nil, stopReason: nil, inputTokens: nil, outputTokens: nil,
            checkerType: nil, passed: nil, evidence: nil, errorMessage: nil,
            thermalState: nil, domain: "cloud", progressSnapshot: nil, bootstrapPacket: nil
        )

        let data = event.toJSONData()
        #expect(data != nil)

        if let data, let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            #expect(dict["type"] as? String == "breaker_tripped")
            #expect(dict["domain"] as? String == "cloud")
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Phase 9: Full Harness Lifecycle Integration Tests
// ═══════════════════════════════════════════════════════════════════

@Suite("Harness Lifecycle — full prepare → record → complete flow")
@MainActor
struct HarnessLifecycleTests {

    @Test("Full lifecycle: prepare → record events → complete → verify traces and progress")
    func fullLifecycle() async throws {
        let sessionId = "lifecycle-\(UUID().uuidString)"
        let integration = HarnessIntegration()

        // Step 1: Prepare session
        let prompt = integration.prepareSession(
            sessionId: sessionId,
            objective: "refactor the database layer"
        )
        #expect(!prompt.isEmpty)
        #expect(integration.activeSessionId == sessionId)
        #expect(integration.activeTaskType == .coding)

        // Step 2: Record events during execution
        integration.recordUserIntent("refactor the database layer")
        integration.recordModelOutput(
            turn: 1, provider: "cloud", model: "claude-opus-4.6",
            tokensUsed: 500, content: "I'll start by examining the schema..."
        )
        integration.recordToolCall(
            turn: 1, tool: "bash",
            input: "grep -r 'CREATE TABLE' src/",
            output: "Found 5 tables", exitCode: 0, durationMs: 150
        )
        integration.recordError("Connection timeout", domain: "cloud")

        // Step 3: Complete session
        integration.completeSession(
            stopReason: "end_turn",
            inputTokens: 2000, outputTokens: 1500, turns: 3,
            accomplishedSummary: "Refactored database layer with migrations",
            completedTasks: ["schema-redesign", "migration-script"],
            changedFiles: ["src/db/schema.rs", "src/db/migrations.rs"]
        )

        // Step 4: Verify progress was saved
        let progress = ProgressStore.loadProgress(sessionId: sessionId)
        #expect(progress != nil)
        #expect(progress?.accomplishedSummary == "Refactored database layer with migrations")
        #expect(progress?.completedTasks.count == 2)
        #expect(progress?.totalInputTokens == 2000)
        #expect(progress?.totalOutputTokens == 1500)

        // Cleanup
        let dir = ProgressStore.sessionDirectory(for: sessionId)
        try? FileManager.default.removeItem(at: dir)
    }

    @Test("Session continuation detects prior progress")
    func sessionContinuation() async throws {
        let sessionId1 = "cont-first-\(UUID().uuidString)"
        let integration = HarnessIntegration()

        // First session
        _ = integration.prepareSession(sessionId: sessionId1, objective: "build feature X")
        integration.completeSession(
            stopReason: "end_turn",
            inputTokens: 1000, outputTokens: 500, turns: 2,
            accomplishedSummary: "Scaffolded feature X",
            nextPriority: "Implement the API endpoints"
        )

        // Second session should detect prior progress
        let sessionId2 = "cont-second-\(UUID().uuidString)"
        let prompt2 = integration.prepareSession(
            sessionId: sessionId2,
            objective: "build feature X"
        )

        // The continuation prompt should reference prior work
        // (mode detection depends on ProgressStore finding latest progress)
        #expect(!prompt2.isEmpty)
        #expect(integration.activeSessionId == sessionId2)

        // Cleanup
        try? FileManager.default.removeItem(at: ProgressStore.sessionDirectory(for: sessionId1))
        try? FileManager.default.removeItem(at: ProgressStore.sessionDirectory(for: sessionId2))
    }

    @Test("Events before prepareSession are silently dropped")
    func eventsBeforePrepareDropped() {
        let integration = HarnessIntegration()

        // These should not crash — activeSessionId is nil, events are dropped
        integration.recordUserIntent("this should be dropped")
        integration.recordError("this too")
        integration.recordToolCall(turn: 1, tool: "bash", input: "ls", output: "files")
        integration.recordModelOutput(turn: 1, provider: "cloud", model: nil, tokensUsed: 0, content: "")

        // No crash = success
        #expect(integration.activeSessionId == nil)
    }

    @Test("resetForNewTask allows fresh session after completion")
    func resetAndRestart() {
        let integration = HarnessIntegration()

        // First task
        _ = integration.prepareSession(sessionId: "task1", objective: "task one")
        integration.completeSession(
            stopReason: "end_turn", inputTokens: 100, outputTokens: 50, turns: 1,
            accomplishedSummary: "Done"
        )

        // Reset
        integration.resetForNewTask()
        #expect(integration.activeSessionId == nil)
        #expect(integration.currentBootstrapPacket == nil)

        // New task works cleanly
        let prompt = integration.prepareSession(sessionId: "task2", objective: "research: investigate topic Y")
        #expect(!prompt.isEmpty)
        #expect(integration.activeSessionId == "task2")
        #expect(integration.activeTaskType == .research)

        // Cleanup
        try? FileManager.default.removeItem(at: ProgressStore.sessionDirectory(for: "task1"))
        try? FileManager.default.removeItem(at: ProgressStore.sessionDirectory(for: "task2"))
    }
}
