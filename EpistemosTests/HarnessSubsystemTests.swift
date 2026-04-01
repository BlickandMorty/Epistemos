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

        await collector.record(event)
        // Allow fire-and-forget Task to complete
        try await Task.sleep(for: .milliseconds(200))
        await collector.closeAll()

        // Verify file was created
        let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
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
            metadata: EvalTaskMetadata(difficulty: nil, domain: nil, expectedTurns: nil, expectedTokenBudget: nil)
        )
        let heldOutTask = EvalTask(
            id: "h-001", objective: "held out task", taskType: .coding,
            verification: .filesExist(paths: ["/tmp/test.txt"]),
            initialStatePath: nil,
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
            verification: .humanReview, initialStatePath: nil,
            metadata: EvalTaskMetadata(difficulty: nil, domain: nil, expectedTurns: nil, expectedTokenBudget: nil)
        ))
        try await suite.addHeldOutTask(EvalTask(
            id: "h-001", objective: "held out", taskType: .terminal,
            verification: .humanReview, initialStatePath: nil,
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
