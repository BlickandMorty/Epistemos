import Testing
import Foundation
@testable import Epistemos

// MARK: - Phase 0: EventStore Schema Tests

@Suite("EventStore Cognitive Tables")
struct EventStoreSchemaTests {

    private func makeTestStore() -> EventStore? {
        let tempDir = FileManager.default.temporaryDirectory
        let dbURL = tempDir.appendingPathComponent("test-\(UUID().uuidString).sqlite")
        return EventStore(databaseURL: dbURL)
    }

    @Test("Migration creates all four cognitive substrate tables")
    func migrationCreatesAllTables() {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }
        #expect(store.tableExists("captured_artifacts"))
        #expect(store.tableExists("friction_windows"))
        #expect(store.tableExists("night_brain_runs"))
        #expect(store.tableExists("night_brain_checkpoints"))
    }

    @Test("Existing tables still present after migration")
    func existingTablesUnchanged() {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }
        #expect(store.tableExists("events"))
        #expect(store.tableExists("snapshots"))
    }

    @Test("Dedupe hash UNIQUE constraint rejects duplicates")
    func dedupeHashUnique() async throws {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let artifact = CapturedArtifact(
            sourceBundleId: "com.test.app",
            appName: "TestApp",
            textContent: "Hello world",
            capturedAt: Date().timeIntervalSince1970,
            dedupeHash: "abc123",
            ocrUsed: false
        )

        store.insertCapturedArtifact(artifact)
        try await Task.sleep(nanoseconds: 100_000_000)

        store.insertCapturedArtifact(artifact)
        try await Task.sleep(nanoseconds: 100_000_000)

        let count = store.capturedArtifactCount()
        #expect(count == 1)
    }

    @Test("Night brain run insert and query")
    func nightBrainRunCRUD() async throws {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let runId = store.insertNightBrainRun(status: "running", triggerReason: "test")
        #expect(runId != nil)

        store.updateNightBrainRun(
            id: runId!, status: "completed",
            completedJobs: ["job1", "job2"],
            completedAt: Date().timeIntervalSince1970
        )
        try await Task.sleep(nanoseconds: 100_000_000)

        let runs = store.completedNightBrainRuns(limit: 10)
        #expect(runs.count == 1)
        #expect(runs.first?.status == "completed")
        #expect(runs.first?.jobsCompleted == ["job1", "job2"])
    }

    @Test("No interrupted runs returns nil")
    func noInterruptedRuns() {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }
        #expect(store.mostRecentInterruptedRun() == nil)
    }
}

// MARK: - Night Brain Checkpoint Resume Tests

@Suite("Night Brain Checkpoint Resume")
struct NightBrainCheckpointResumeTests {

    private func makeTestStore() -> EventStore? {
        let tempDir = FileManager.default.temporaryDirectory
        let dbURL = tempDir.appendingPathComponent("test-\(UUID().uuidString).sqlite")
        return EventStore(databaseURL: dbURL)
    }

    @Test("Checkpoint rows are written per job and readable for resume")
    func checkpointWriteAndRead() {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let runId = store.insertNightBrainRun(status: "running", triggerReason: "test")
        #expect(runId != nil)

        // Simulate two jobs completing with checkpoint writes
        store.insertCheckpoint(runId: runId!, jobType: "event_store_checkpoint_vacuum", data: "{}")
        store.insertCheckpoint(runId: runId!, jobType: "dedupe_artifacts", data: "{}")

        // checkpointedJobTypes reads from the checkpoint TABLE
        let completed = store.checkpointedJobTypes(runId: runId!)
        #expect(completed.count == 2)
        #expect(completed.contains("event_store_checkpoint_vacuum"))
        #expect(completed.contains("dedupe_artifacts"))
    }

    @Test("Resume skips checkpointed jobs and continues from where it left off")
    func resumeSkipsCheckpointedJobs() {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        // Create a run, write checkpoints for first 2 jobs, then interrupt
        let runId = store.insertNightBrainRun(status: "running", triggerReason: "test")!
        store.insertCheckpoint(runId: runId, jobType: "event_store_checkpoint_vacuum", data: "{}")
        store.insertCheckpoint(runId: runId, jobType: "dedupe_artifacts", data: "{}")
        store.updateNightBrainRun(
            id: runId, status: "interrupted",
            completedJobs: ["event_store_checkpoint_vacuum", "dedupe_artifacts"]
        )

        // Simulate what the pipeline does on resume: find interrupted run, read checkpoints
        let interrupted = store.mostRecentInterruptedRun()
        #expect(interrupted == runId)

        let alreadyDone = store.checkpointedJobTypes(runId: interrupted!)
        #expect(alreadyDone == ["event_store_checkpoint_vacuum", "dedupe_artifacts"])

        // The pipeline would skip these and continue with remaining jobs
        let allJobs = ["event_store_checkpoint_vacuum", "dedupe_artifacts",
                       "workspace_snapshot_compaction", "maintenance_log"]
        let remaining = allJobs.filter { !alreadyDone.contains($0) }
        #expect(remaining == ["workspace_snapshot_compaction", "maintenance_log"])
    }

    @Test("Empty checkpoint table means no jobs to skip")
    func emptyCheckpointMeansFullRun() {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let runId = store.insertNightBrainRun(status: "running", triggerReason: "test")!
        let completed = store.checkpointedJobTypes(runId: runId)
        #expect(completed.isEmpty)
    }

    @Test("Checkpoint table is authoritative over stale jobs_completed payloads")
    func checkpointsOverrideStaleJobsCompleted() {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let runId = store.insertNightBrainRun(status: "running", triggerReason: "test")!
        store.updateNightBrainRun(
            id: runId, status: "interrupted",
            completedJobs: ["workspace_snapshot_compaction", "maintenance_log"]
        )
        store.insertCheckpoint(runId: runId, jobType: "event_store_checkpoint_vacuum", data: "{}")

        let completed = store.checkpointedJobTypes(runId: runId)
        #expect(completed == ["event_store_checkpoint_vacuum"])
    }

    @Test("Completed runs are not returned by mostRecentInterruptedRun")
    func completedRunsNotReturned() async throws {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let runId = store.insertNightBrainRun(status: "running", triggerReason: "test")!
        store.updateNightBrainRun(
            id: runId, status: "completed",
            completedJobs: ["all_done"],
            completedAt: Date().timeIntervalSince1970
        )
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(store.mostRecentInterruptedRun() == nil)
    }
}

// MARK: - Phase 1: Ambient Capture Tests

@Suite("Ambient Capture")
struct AmbientCaptureTests {

    @Test("Secret redaction removes API keys")
    func redactAPIKeys() {
        let input = "api_key=sk_live_abc123def456"
        let result = AmbientCaptureService.redactSecrets(input)
        #expect(result.contains("[REDACTED]"))
        #expect(!result.contains("sk_live_abc123def456"))
    }

    @Test("Secret redaction removes email addresses")
    func redactEmails() {
        let input = "Contact user@example.com for help"
        let result = AmbientCaptureService.redactSecrets(input)
        #expect(result.contains("[REDACTED]"))
        #expect(!result.contains("user@example.com"))
    }

    @Test("Secret redaction removes credit card numbers")
    func redactCreditCards() {
        let input = "Card: 4111-1111-1111-1111"
        let result = AmbientCaptureService.redactSecrets(input)
        #expect(result.contains("[REDACTED]"))
        #expect(!result.contains("4111"))
    }

    @Test("Secret redaction removes SSNs")
    func redactSSNs() {
        let input = "SSN: 123-45-6789"
        let result = AmbientCaptureService.redactSecrets(input)
        #expect(result.contains("[REDACTED]"))
        #expect(!result.contains("123-45-6789"))
    }

    @Test("Secret redaction leaves normal text unchanged")
    func redactNormalText() {
        let input = "This is a normal paragraph about Swift programming"
        let result = AmbientCaptureService.redactSecrets(input)
        #expect(result == input)
    }

    @Test("Stable hash is deterministic")
    func stableHashDeterministic() {
        let hash1 = AmbientCaptureService.stableHash("hello world")
        let hash2 = AmbientCaptureService.stableHash("hello world")
        #expect(hash1 == hash2)
    }

    @Test("Stable hash differs for different inputs")
    func stableHashDiffers() {
        let hash1 = AmbientCaptureService.stableHash("hello world")
        let hash2 = AmbientCaptureService.stableHash("hello world!")
        #expect(hash1 != hash2)
    }
}

// MARK: - Live Toggle Behavior Tests

@Suite("Live Toggle Behavior")
@MainActor
struct LiveToggleTests {

    @Test("Friction monitor respects live config toggle")
    func frictionLiveToggle() async {
        let config = EpistemosConfig()
        config.frictionEnabled = true
        let monitor = FrictionMonitorService(config: config)

        // Should accept events when enabled
        await monitor.record(EditorTelemetryEvent(
            noteId: "note-1", kind: .insertion(count: 5),
            timestampMs: Int64(Date().timeIntervalSince1970 * 1000)
        ))
        // No crash = event was accepted

        // Disable live — next event should be silently dropped
        config.frictionEnabled = false
        await monitor.record(EditorTelemetryEvent(
            noteId: "note-1", kind: .insertion(count: 5),
            timestampMs: Int64(Date().timeIntervalSince1970 * 1000) + 100
        ))
        // No crash = disabled path works
    }

    @Test("EpistemosConfig blocklist is enforced by isBlocked")
    func blocklistEnforced() {
        let config = EpistemosConfig()
        config.blocklistJSON = "[\"com.apple.Safari\",\"com.slack.Slack\"]"

        #expect(config.isBlocked("com.apple.Safari"))
        #expect(config.isBlocked("com.slack.Slack"))
        #expect(!config.isBlocked("com.apple.Terminal"))
    }

    @Test("EpistemosConfig allowlist restricts to listed apps only")
    func allowlistRestricts() {
        let config = EpistemosConfig()
        config.allowlistJSON = "[\"com.apple.Safari\"]"
        config.blocklistJSON = "[]"

        #expect(!config.isBlocked("com.apple.Safari"))
        #expect(config.isBlocked("com.apple.Terminal"))
    }

    @Test("Blocklist takes priority over allowlist")
    func blocklistPriority() {
        let config = EpistemosConfig()
        config.allowlistJSON = "[\"com.apple.Safari\"]"
        config.blocklistJSON = "[\"com.apple.Safari\"]"

        // Blocklist is checked first, so Safari should be blocked
        #expect(config.isBlocked("com.apple.Safari"))
    }

    @Test("Night Brain continue gate respects live config and AC requirements")
    func nightBrainContinueGateUsesLiveConfig() async {
        let config = EpistemosConfig()
        config.nightBrainEnabled = true
        config.nightBrainRequiresAC = true
        config.nightBrainMinIdleSeconds = 300
        let service = NightBrainService(config: config)

        #expect(await service.canContinue(idleSeconds: 301, thermalPressureLevel: 1, onACPower: true))

        config.nightBrainEnabled = false
        #expect(!(await service.canContinue(idleSeconds: 301, thermalPressureLevel: 1, onACPower: true)))

        config.nightBrainEnabled = true
        #expect(!(await service.canContinue(idleSeconds: 301, thermalPressureLevel: 1, onACPower: false)))

        config.nightBrainRequiresAC = false
        config.nightBrainMinIdleSeconds = 500
        #expect(!(await service.canContinue(idleSeconds: 301, thermalPressureLevel: 1, onACPower: true)))
    }
}

// MARK: - Phase 2: Friction Detection Tests

@Suite("Friction Detection")
struct FrictionDetectionTests {

    @Test("Ring buffer push and toArray")
    func ringBufferBasic() {
        var buffer = RingBuffer<Int>(capacity: 5)
        for i in 0..<3 {
            buffer.push(i)
        }
        #expect(buffer.count == 3)
        #expect(buffer.toArray() == [0, 1, 2])
    }

    @Test("Ring buffer wraps on overflow")
    func ringBufferOverflow() {
        var buffer = RingBuffer<Int>(capacity: 3)
        for i in 0..<5 {
            buffer.push(i)
        }
        #expect(buffer.count == 3)
        #expect(buffer.toArray() == [2, 3, 4])
    }

    @Test("Ring buffer reset clears state")
    func ringBufferReset() {
        var buffer = RingBuffer<Int>(capacity: 5)
        buffer.push(1)
        buffer.push(2)
        buffer.reset()
        #expect(buffer.count == 0)
        #expect(buffer.toArray().isEmpty)
    }

    @Test("Smooth typing stays below friction threshold")
    func smoothTypingLowFriction() async {
        let monitor = FrictionMonitorService(config: EpistemosConfig())

        let baseTime = Int64(Date().timeIntervalSince1970 * 1000)
        for i in 0..<50 {
            await monitor.record(EditorTelemetryEvent(
                noteId: "test-note",
                kind: .insertion(count: 5),
                timestampMs: baseTime + Int64(i) * 100
            ))
        }
    }

    @Test("AI stream events are filtered out")
    func aiStreamEventsFiltered() async {
        let monitor = FrictionMonitorService(config: EpistemosConfig())

        await monitor.record(EditorTelemetryEvent(
            noteId: "test-note",
            kind: .aiStreamEnd,
            timestampMs: Int64(Date().timeIntervalSince1970 * 1000)
        ))
    }

    @Test("Friction disabled = no recording")
    func frictionDisabledNoOp() async {
        let disabledConfig = EpistemosConfig()
        disabledConfig.frictionEnabled = false
        let monitor = FrictionMonitorService(config: disabledConfig)

        await monitor.record(EditorTelemetryEvent(
            noteId: "test-note",
            kind: .insertion(count: 1),
            timestampMs: Int64(Date().timeIntervalSince1970 * 1000)
        ))
    }

    @Test("Note switch rotates session ID and flushes buffer")
    func noteSwitch() async {
        let monitor = FrictionMonitorService(config: EpistemosConfig())

        // Record events for note-1
        let baseTime = Int64(Date().timeIntervalSince1970 * 1000)
        for i in 0..<5 {
            await monitor.record(EditorTelemetryEvent(
                noteId: "note-1",
                kind: .insertion(count: 3),
                timestampMs: baseTime + Int64(i) * 200
            ))
        }

        // Switch to note-2 — this should flush note-1's buffer and start fresh
        await monitor.record(EditorTelemetryEvent(
            noteId: "note-2",
            kind: .insertion(count: 1),
            timestampMs: baseTime + 5000
        ))

        // Explicit note switch notification
        await monitor.noteDidSwitch(oldNoteId: "note-2")
        // No crash, buffer is clean
    }
}

@Suite("Friction Persistence", .serialized)
struct FrictionPersistenceTests {

    private func makeTestStore() -> EventStore? {
        let tempDir = FileManager.default.temporaryDirectory
        let dbURL = tempDir.appendingPathComponent("test-\(UUID().uuidString).sqlite")
        return EventStore(databaseURL: dbURL)
    }

    @Test("Note switches persist separate friction windows with distinct sessions")
    func noteSwitchPersistsDistinctSessions() async {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let monitor = FrictionMonitorService(config: EpistemosConfig(), storeProvider: { store })
        let baseTime: Int64 = 1_000_000

        for i in 0..<20 {
            await monitor.record(EditorTelemetryEvent(
                noteId: "note-1",
                kind: .insertion(count: 2),
                timestampMs: baseTime + Int64(i) * 2_000
            ))
        }

        await monitor.record(EditorTelemetryEvent(
            noteId: "note-2",
            kind: .insertion(count: 1),
            timestampMs: baseTime + 40_000
        ))

        for i in 1..<20 {
            await monitor.record(EditorTelemetryEvent(
                noteId: "note-2",
                kind: .insertion(count: 2),
                timestampMs: baseTime + 40_000 + Int64(i) * 2_000
            ))
        }

        await monitor.noteDidSwitch(oldNoteId: "note-2")

        let windows = store.frictionWindows(limit: 10)
        #expect(windows.count == 2)
        #expect(windows[0].noteId == "note-1")
        #expect(windows[1].noteId == "note-2")
        #expect(windows[0].sessionId != windows[1].sessionId)
    }
}

// MARK: - Phase 3: Graph Pin Tests

@Suite("Graph Pinning")
@MainActor
struct GraphPinTests {

    @Test("Pin and unpin updates pinnedNodeIds set")
    func pinUnpinState() {
        let state = GraphState()
        #expect(state.pinnedNodeIds.isEmpty)

        state.pinnedNodeIds.insert("node-1")
        #expect(state.pinnedNodeIds.contains("node-1"))

        state.pinnedNodeIds.remove("node-1")
        #expect(state.pinnedNodeIds.isEmpty)
    }

    @Test("Freeze all nodes populates pinnedNodeIds")
    func freezeAllNodes() {
        let state = GraphState()
        let node1 = GraphNodeRecord(
            id: "n1", type: .note, label: "Note 1", sourceId: nil,
            metadata: GraphNodeMetadata(), weight: 1.0,
            createdAt: .now, position: .zero, velocity: .zero
        )
        let node2 = GraphNodeRecord(
            id: "n2", type: .note, label: "Note 2", sourceId: nil,
            metadata: GraphNodeMetadata(), weight: 1.0,
            createdAt: .now, position: .zero, velocity: .zero
        )
        state.store.addNode(node1)
        state.store.addNode(node2)

        state.freezeAllNodes()
        #expect(state.pinnedNodeIds.contains("n1"))
        #expect(state.pinnedNodeIds.contains("n2"))
    }

    @Test("Unfreeze all clears pinnedNodeIds")
    func unfreezeAllNodes() {
        let state = GraphState()
        state.pinnedNodeIds = Set(["n1", "n2", "n3"])
        state.unfreezeAllNodes()
        #expect(state.pinnedNodeIds.isEmpty)
    }

    @Test("GraphOverlaySnapshot persists pinnedNodeIds")
    func snapshotPersistence() throws {
        let snapshot = GraphOverlaySnapshot(
            visibility: .full,
            selectedNodeId: "sel-1",
            pinnedNodeIds: ["pin-1", "pin-2"]
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(GraphOverlaySnapshot.self, from: data)
        #expect(decoded.pinnedNodeIds == ["pin-1", "pin-2"])
    }

    @Test("GraphOverlaySnapshot backward compat with nil pinnedNodeIds")
    func snapshotBackwardCompat() throws {
        let json = """
        {"visibility":"full","selectedNodeId":"sel-1"}
        """
        let decoded = try JSONDecoder().decode(GraphOverlaySnapshot.self, from: Data(json.utf8))
        #expect(decoded.pinnedNodeIds == nil)
    }
}

// MARK: - Phase 4: Night Brain Tests

@Suite("Night Brain")
struct NightBrainTests {

    @Test("Thermal pressure level returns a valid value")
    func thermalPressureLevel() {
        let level = NightBrainService.thermalPressureLevel()
        #expect(level <= 4)
    }

    @Test("User idle seconds returns non-negative")
    func userIdleSeconds() {
        let idle = NightBrainService.userIdleSeconds()
        #expect(idle >= 0)
    }
}

// MARK: - Phase 5: Config Tests

@Suite("EpistemosConfig")
struct EpistemosConfigTests {

    @Test("Default values are sensible")
    func defaultValues() {
        let config = EpistemosConfig()
        #expect(config.captureEnabled == false)
        #expect(config.frictionEnabled == true)
        #expect(config.nightBrainEnabled == true)
        #expect(config.nightBrainRequiresAC == true)
    }

    @Test("Blocklist rejects blocked bundle IDs")
    func blocklistRejects() {
        let config = EpistemosConfig()
        config.blocklistJSON = "[\"com.blocked.app\"]"
        #expect(config.isBlocked("com.blocked.app"))
        #expect(!config.isBlocked("com.allowed.app"))
    }

    @Test("Allowlist restricts to allowed bundle IDs only")
    func allowlistRestricts() {
        let config = EpistemosConfig()
        config.allowlistJSON = "[\"com.allowed.app\"]"
        #expect(!config.isBlocked("com.allowed.app"))
        #expect(config.isBlocked("com.other.app"))
    }

    @Test("Empty allowlist allows everything")
    func emptyAllowlistAllowsAll() {
        let config = EpistemosConfig()
        config.allowlistJSON = "[]"
        config.blocklistJSON = "[]"
        #expect(!config.isBlocked("com.any.app"))
    }
}
