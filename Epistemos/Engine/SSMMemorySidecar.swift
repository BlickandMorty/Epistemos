import Foundation
import OSLog

// MARK: - SSM Memory Sidecar

/// Compresses session history through a Mamba2-based SSM at turn boundaries.
///
/// Architecture:
/// - Operates at turn boundaries, never during active generation
/// - Takes conversation history text as input
/// - Runs through the Mamba2 forward pass for state compression
/// - Leaves persistence to future MLX prompt-cache handoff work
/// - Exposes compressed context as an injectable prefix for main generation
///
/// Constraints:
/// - Helper/sidecar role only (not the main overseer, not the main backbone)
/// - Background-only (dispatched off the main generation thread)
/// - Optional and disableable
/// - Fail closed: if Mamba2 fails, generation proceeds without compression
@MainActor
final class SSMMemorySidecar: @unchecked Sendable {

    private static let log = Logger(subsystem: "com.epistemos", category: "SSMSidecar")

    private let subsystem: AdaptationSubsystem
    private let stateService: SSMStateService?
    private(set) var isEnabled: Bool
    private(set) var lastCompressedContext: String?
    private(set) var lastCompressionRatio: Double = 0
    private(set) var activeSidecarSessionID: String?

    init(
        subsystem: AdaptationSubsystem,
        stateService: SSMStateService?,
        enabled: Bool = false
    ) {
        self.subsystem = subsystem
        self.stateService = stateService
        self.isEnabled = enabled
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            lastCompressedContext = nil
            lastCompressionRatio = 0
        }
        Self.log.info("SSM sidecar \(enabled ? "enabled" : "disabled", privacy: .public)")
    }

    // MARK: - Compression Lifecycle

    /// Begin a compression pass for the given session history.
    /// Returns the sidecar session ID, or nil if the sidecar is disabled/unavailable.
    func beginCompression(
        sessionHistory: String,
        modelID: String,
        sessionID: String
    ) -> String? {
        guard isEnabled else { return nil }

        let tokenEstimate = UInt32(clamping: sessionHistory.count / 4)
        guard tokenEstimate > 0 else { return nil }

        do {
            let sidecarSessionID = try subsystem.beginSidecarCompression(inputTokenCount: tokenEstimate)
            activeSidecarSessionID = sidecarSessionID
            Self.log.info(
                "Sidecar compression started: \(sidecarSessionID, privacy: .public) tokens~\(tokenEstimate) model=\(modelID, privacy: .public)"
            )
            return sidecarSessionID
        } catch {
            Self.log.error("Failed to begin sidecar compression: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Report a successful compression result.
    /// The compressed context text is stored for injection into the next generation.
    func reportCompressionSuccess(
        compressedContext: String,
        compressedTokenCount: UInt32,
        durationMS: Double
    ) {
        guard let sidecarSessionID = activeSidecarSessionID else { return }

        do {
            try subsystem.reportSidecarResult(
                sessionId: sidecarSessionID,
                compressedTokenCount: compressedTokenCount,
                durationMs: durationMS
            )
            lastCompressedContext = compressedContext
            let snap = try subsystem.sidecarSessionSnapshot(sessionId: sidecarSessionID)
            lastCompressionRatio = snap.compressionRatio

            Self.log.info(
                "Sidecar compression succeeded: \(compressedTokenCount) tokens, ratio=\(snap.compressionRatio, format: .fixed(precision: 2)), \(durationMS, format: .fixed(precision: 1))ms"
            )
        } catch {
            Self.log.error("Failed to report sidecar result: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Report a compression failure. Generation will proceed without compressed context.
    func reportCompressionFailure() {
        guard let sidecarSessionID = activeSidecarSessionID else { return }

        do {
            try subsystem.reportSidecarFailure(sessionId: sidecarSessionID)
            lastCompressedContext = nil
            lastCompressionRatio = 0
            Self.log.warning("Sidecar compression failed — proceeding without compressed context")
        } catch {
            Self.log.error("Failed to report sidecar failure: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// End the active sidecar session and return the snapshot.
    func endSession() -> SidecarSessionSnapshot? {
        guard let sidecarSessionID = activeSidecarSessionID else { return nil }
        activeSidecarSessionID = nil

        do {
            let snapshot = try subsystem.endSidecarSession(sessionId: sidecarSessionID)
            Self.log.info(
                "Sidecar session ended: state=\(snapshot.state, privacy: .public) ratio=\(snapshot.compressionRatio, format: .fixed(precision: 2))"
            )
            return snapshot
        } catch {
            Self.log.error("Failed to end sidecar session: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Context Injection

    /// Returns the compressed context prefix for injection into the main generation prompt,
    /// or nil if no compressed context is available.
    var compressedContextPrefix: String? {
        guard isEnabled, let context = lastCompressedContext, !context.isEmpty else {
            return nil
        }
        return context
    }

    // MARK: - State Persistence

    /// Persist the last compressed text context for warm prompt resume.
    @discardableResult
    func persistState(modelID: String, sessionID: String) -> URL? {
        guard let stateService, stateService.isActive else { return nil }
        guard let context = lastCompressedContext, !context.isEmpty else { return nil }

        return stateService.saveCompressedContext(
            modelId: modelID,
            sessionId: sessionID,
            context: context
        )
    }

    // MARK: - Diagnostics

    var diagnosticSummary: String {
        let state = activeSidecarSessionID != nil ? "active" : "idle"
        let ratio = lastCompressionRatio > 0 ? String(format: "%.2f", lastCompressionRatio) : "n/a"
        let hasContext = lastCompressedContext != nil ? "yes" : "no"
        return "SSMSidecar(enabled=\(isEnabled), state=\(state), ratio=\(ratio), hasContext=\(hasContext))"
    }
}
