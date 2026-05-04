import Testing
@testable import Epistemos

@Suite("SSM Memory Sidecar")
struct SSMMemorySidecarTests {

    @Test("sidecar disabled by default")
    @MainActor
    func sidecarDisabledByDefault() {
        let subsystem = AdaptationSubsystem()
        let sidecar = SSMMemorySidecar(
            subsystem: subsystem,
            stateService: nil,
            enabled: false
        )
        #expect(!sidecar.isEnabled)
        #expect(sidecar.compressedContextPrefix == nil)
    }

    @Test("sidecar can be enabled and disabled")
    @MainActor
    func sidecarEnableDisable() {
        let subsystem = AdaptationSubsystem()
        let sidecar = SSMMemorySidecar(
            subsystem: subsystem,
            stateService: nil,
            enabled: false
        )
        sidecar.setEnabled(true)
        #expect(sidecar.isEnabled)
        sidecar.setEnabled(false)
        #expect(!sidecar.isEnabled)
    }

    @Test("begin compression returns nil when disabled")
    @MainActor
    func beginCompressionDisabled() {
        let subsystem = AdaptationSubsystem()
        let sidecar = SSMMemorySidecar(
            subsystem: subsystem,
            stateService: nil,
            enabled: false
        )
        let sessionID = sidecar.beginCompression(
            sessionHistory: "Hello world",
            modelID: "test-model",
            sessionID: "test-session"
        )
        #expect(sessionID == nil)
    }

    @Test("begin compression returns session ID when enabled")
    @MainActor
    func beginCompressionEnabled() {
        let subsystem = AdaptationSubsystem()
        let sidecar = SSMMemorySidecar(
            subsystem: subsystem,
            stateService: nil,
            enabled: true
        )
        let sessionID = sidecar.beginCompression(
            sessionHistory: "Hello world, this is a test session with enough content.",
            modelID: "test-model",
            sessionID: "test-session"
        )
        #expect(sessionID != nil)
        #expect(sidecar.activeSidecarSessionID != nil)
    }

    @Test("successful compression updates context prefix")
    @MainActor
    func successfulCompression() {
        let subsystem = AdaptationSubsystem()
        let sidecar = SSMMemorySidecar(
            subsystem: subsystem,
            stateService: nil,
            enabled: true
        )
        let _ = sidecar.beginCompression(
            sessionHistory: "Hello world, this is a long test session.",
            modelID: "test-model",
            sessionID: "test-session"
        )
        sidecar.reportCompressionSuccess(
            compressedContext: "Compressed: hello world test session",
            compressedTokenCount: 6,
            durationMS: 50.0
        )
        #expect(sidecar.lastCompressedContext != nil)
        #expect(sidecar.compressedContextPrefix?.contains("Compressed") == true)
        #expect(sidecar.lastCompressionRatio > 0)
    }

    @Test("compression failure clears context")
    @MainActor
    func compressionFailure() {
        let subsystem = AdaptationSubsystem()
        let sidecar = SSMMemorySidecar(
            subsystem: subsystem,
            stateService: nil,
            enabled: true
        )
        let _ = sidecar.beginCompression(
            sessionHistory: "Hello world",
            modelID: "test-model",
            sessionID: "test-session"
        )
        sidecar.reportCompressionFailure()
        #expect(sidecar.lastCompressedContext == nil)
    }

    @Test("compression failure clears previously successful context")
    @MainActor
    func compressionFailureClearsStaleContext() {
        let subsystem = AdaptationSubsystem()
        let sidecar = SSMMemorySidecar(
            subsystem: subsystem,
            stateService: nil,
            enabled: true
        )
        let _ = sidecar.beginCompression(
            sessionHistory: "A longer session history that first compresses successfully.",
            modelID: "test-model",
            sessionID: "test-session"
        )
        sidecar.reportCompressionSuccess(
            compressedContext: "Compressed context",
            compressedTokenCount: 4,
            durationMS: 25.0
        )
        #expect(sidecar.compressedContextPrefix == "Compressed context")

        sidecar.reportCompressionFailure()

        #expect(sidecar.lastCompressedContext == nil)
        #expect(sidecar.compressedContextPrefix == nil)
        #expect(sidecar.lastCompressionRatio == 0)
    }

    @Test("end session returns snapshot")
    @MainActor
    func endSession() {
        let subsystem = AdaptationSubsystem()
        let sidecar = SSMMemorySidecar(
            subsystem: subsystem,
            stateService: nil,
            enabled: true
        )
        let _ = sidecar.beginCompression(
            sessionHistory: "Test content for compression pass",
            modelID: "test-model",
            sessionID: "test-session"
        )
        sidecar.reportCompressionSuccess(
            compressedContext: "compressed",
            compressedTokenCount: 1,
            durationMS: 10.0
        )
        let snapshot = sidecar.endSession()
        #expect(snapshot != nil)
        #expect(snapshot?.state == "ready")
        #expect(sidecar.activeSidecarSessionID == nil)
    }

    @Test("diagnostic summary reflects state")
    @MainActor
    func diagnosticSummary() {
        let subsystem = AdaptationSubsystem()
        let sidecar = SSMMemorySidecar(
            subsystem: subsystem,
            stateService: nil,
            enabled: true
        )
        let summary = sidecar.diagnosticSummary
        #expect(summary.contains("enabled=true"))
        #expect(summary.contains("state=idle"))
    }

    @Test("persistState writes and reloads compressed context through SSMStateService")
    @MainActor
    func persistStateWritesCompressedContext() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ssm-sidecar-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let stateService = SSMStateService(stateRoot: root)
        stateService.activate(enabled: true)
        let sidecar = SSMMemorySidecar(
            subsystem: AdaptationSubsystem(),
            stateService: stateService,
            enabled: true
        )
        let modelID = "mlx-community/mamba2-2.7b-4bit"
        let sessionID = "session/with spaces"

        _ = sidecar.beginCompression(
            sessionHistory: "A long context that should be compressed and persisted.",
            modelID: modelID,
            sessionID: sessionID
        )
        sidecar.reportCompressionSuccess(
            compressedContext: "compressed warm resume context",
            compressedTokenCount: 5,
            durationMS: 12
        )

        let savedURL = try #require(sidecar.persistState(modelID: modelID, sessionID: sessionID))
        let latestURL = try #require(stateService.findLatestCompressedContext(modelId: modelID, sessionId: sessionID))
        let snapshot = try #require(stateService.loadCompressedContext(from: latestURL))

        #expect(savedURL.resolvingSymlinksInPath() == latestURL.resolvingSymlinksInPath())
        #expect(savedURL.path.contains("compressed_context"))
        #expect(savedURL.lastPathComponent.contains("session_with_spaces"))
        #expect(snapshot.modelId == modelID)
        #expect(snapshot.sessionId == sessionID)
        #expect(snapshot.context == "compressed warm resume context")
        #expect(snapshot.formatVersion == 1)
        #expect(stateService.currentSessionStateId == sessionID)
    }

    @Test("persistState is inactive without service activation or compressed context")
    @MainActor
    func persistStateRequiresActiveServiceAndContext() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ssm-sidecar-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let stateService = SSMStateService(stateRoot: root)
        let sidecar = SSMMemorySidecar(
            subsystem: AdaptationSubsystem(),
            stateService: stateService,
            enabled: true
        )

        #expect(sidecar.persistState(modelID: "model", sessionID: "session") == nil)
        stateService.activate(enabled: true)
        #expect(sidecar.persistState(modelID: "model", sessionID: "session") == nil)
    }

    @Test("compressed context discovery does not prefix-match neighboring sessions")
    @MainActor
    func compressedContextDiscoveryRequiresExactSessionPrefix() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ssm-sidecar-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let stateService = SSMStateService(stateRoot: root)
        stateService.activate(enabled: true)

        let neighboringURL = try #require(stateService.saveCompressedContext(
            modelId: "model",
            sessionId: "session-extra",
            context: "neighboring context"
        ))
        #expect(neighboringURL.lastPathComponent.hasPrefix("session-extra_"))

        #expect(stateService.findLatestCompressedContext(modelId: "model", sessionId: "session") == nil)

        let exactURL = try #require(stateService.saveCompressedContext(
            modelId: "model",
            sessionId: "session",
            context: "exact context"
        ))
        let latestURL = try #require(stateService.findLatestCompressedContext(modelId: "model", sessionId: "session"))
        let snapshot = try #require(stateService.loadCompressedContext(from: latestURL))

        #expect(latestURL.resolvingSymlinksInPath() == exactURL.resolvingSymlinksInPath())
        #expect(snapshot.sessionId == "session")
        #expect(snapshot.context == "exact context")
    }
}
