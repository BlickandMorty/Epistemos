import Foundation
import OSLog

// MARK: - Adaptation Executor

/// Executes bounded LoRA adaptation on MLX helper models under Rust session governance.
///
/// Responsibilities:
/// - Begin/end adaptation sessions via the Rust AdaptationSubsystem FFI
/// - Accumulate training signals from conversation turns
/// - Execute gradient steps (delegated to the MLX LoRA training infrastructure)
/// - Run canary validation after each update
/// - Manage adapter checkpoints for rollback
///
/// Non-negotiable constraints:
/// - Helper-model only (never the primary GGUF chat backbone)
/// - MLX-only execution
/// - Session-scoped (no persistent silent learning)
/// - Delta-only (base weights are immutable)
/// - Fail closed on any safety check failure
@MainActor
final class AdaptationExecutor: @unchecked Sendable {

    private static let log = Logger(subsystem: "com.epistemos", category: "Adaptation")

    private let subsystem: AdaptationSubsystem
    private let stabilizer: AdaptationStabilizer
    private var activeSessionID: String?
    private var checkpoints: [AdapterCheckpoint] = []
    private var anchorWeightNorms: [Double] = []
    private var baselineCanaryLoss: Double = 0

    init(
        subsystem: AdaptationSubsystem = AdaptationSubsystem(),
        stabilizer: AdaptationStabilizer = AdaptationStabilizer()
    ) {
        self.subsystem = subsystem
        self.stabilizer = stabilizer
    }

    // MARK: - Session Lifecycle

    var hasActiveSession: Bool {
        activeSessionID != nil && subsystem.hasActiveSession()
    }

    var adaptationState: String {
        subsystem.activeSessionAdaptationState()
    }

    func beginSession(
        adapterID: String,
        modelID: String,
        runtimeKind: BackendRuntimeKind = .mlx,
        isHelperModel: Bool = true,
        maxUpdates: UInt32 = 50,
        minChunkTokens: UInt32 = 256
    ) throws -> String {
        guard activeSessionID == nil else {
            Self.log.warning("Attempted to begin adaptation session while one is already active")
            throw AdaptationExecutorError.sessionAlreadyActive
        }

        guard isHelperModel else {
            Self.log.warning("Rejected adaptation session for non-helper model \(modelID, privacy: .public)")
            throw AdaptationExecutorError.helperModelRequired
        }

        guard runtimeKind == .mlx else {
            Self.log.warning("Rejected adaptation session for non-MLX runtime \(runtimeKind.rawValue, privacy: .public)")
            throw AdaptationExecutorError.mainRuntimeAdaptationDenied
        }

        let config = AdaptSessionConfig(
            adaptTarget: "helper_model",
            adapterId: adapterID,
            modelId: modelID,
            minChunkTokens: minChunkTokens,
            maxUpdateCount: maxUpdates,
            maxAdaptSteps: maxUpdates * 4,
            gradientNormCap: stabilizer.gradientNormCap,
            canaryLossThresholdMultiplier: stabilizer.canaryLossThresholdMultiplier
        )

        let sessionID = try subsystem.beginAdaptSession(config: config)
        activeSessionID = sessionID
        checkpoints = []
        anchorWeightNorms = []
        baselineCanaryLoss = 0

        Self.log.info("Adaptation session started: \(sessionID, privacy: .public) adapter=\(adapterID, privacy: .public) model=\(modelID, privacy: .public)")
        return sessionID
    }

    func setBaselineCanaryLoss(_ loss: Double) throws {
        guard let sessionID = activeSessionID else {
            throw AdaptationExecutorError.noActiveSession
        }
        baselineCanaryLoss = loss
        try subsystem.setBaselineCanaryLoss(sessionId: sessionID, baselineLoss: loss)
        Self.log.info("Baseline canary loss set: \(loss, format: .fixed(precision: 4))")
    }

    func submitTrainingSignal(tokenCount: UInt32) throws {
        guard let sessionID = activeSessionID else {
            throw AdaptationExecutorError.noActiveSession
        }
        try subsystem.submitTrainingSignal(sessionId: sessionID, tokenCount: tokenCount)
    }

    /// Trigger a gradient update. The caller is responsible for performing the actual
    /// MLX gradient computation and calling `reportUpdateResult` with the outcome.
    func fireUpdate() throws {
        guard let sessionID = activeSessionID else {
            throw AdaptationExecutorError.noActiveSession
        }
        try subsystem.fireUpdate(sessionId: sessionID)
        Self.log.info("Adaptation update fired for session \(sessionID, privacy: .public)")
    }

    func reportUpdateResult(
        canaryLoss: Double,
        anchorDivergence: Double,
        gradientNorm: Double,
        checkpointURL: URL?,
        durationMS: Double
    ) throws {
        guard let sessionID = activeSessionID else {
            throw AdaptationExecutorError.noActiveSession
        }

        let normAcceptable = stabilizer.isGradientNormAcceptable(gradientNorm)
        let canaryPassed = stabilizer.evaluateCanary(
            baselineLoss: baselineCanaryLoss,
            currentLoss: canaryLoss
        )

        let result = AdaptUpdateResult(
            accepted: normAcceptable && canaryPassed,
            canaryLoss: canaryLoss,
            anchorDivergence: anchorDivergence,
            gradientNorm: gradientNorm,
            rollbackTriggered: !canaryPassed && normAcceptable,
            durationMs: durationMS
        )

        do {
            try subsystem.reportUpdateResult(sessionId: sessionID, result: result)

            if let url = checkpointURL {
                let snap = try subsystem.adaptSessionSnapshot(sessionId: sessionID)
                let checkpoint = AdapterCheckpoint(
                    checkpointURL: url,
                    updateIndex: Int(snap.updateCount),
                    canaryLoss: canaryLoss,
                    anchorDivergence: anchorDivergence,
                    timestamp: Date()
                )
                checkpoints.append(checkpoint)
                checkpoints = stabilizer.trimmedCheckpoints(checkpoints)
            }

            Self.log.info(
                "Adaptation update committed: canary=\(canaryLoss, format: .fixed(precision: 4)) divergence=\(anchorDivergence, format: .fixed(precision: 4)) norm=\(gradientNorm, format: .fixed(precision: 4))"
            )
        } catch {
            Self.log.warning(
                "Adaptation update rejected: \(error.localizedDescription, privacy: .public) canary=\(canaryLoss, format: .fixed(precision: 4)) norm=\(gradientNorm, format: .fixed(precision: 4))"
            )
            throw error
        }
    }

    func endSession() -> AdaptSessionSnapshot? {
        guard let sessionID = activeSessionID else { return nil }
        activeSessionID = nil

        do {
            let snapshot = try subsystem.endAdaptSession(sessionId: sessionID)
            Self.log.info(
                "Adaptation session ended: \(sessionID, privacy: .public) updates=\(snapshot.updateCount) rollbacks=\(snapshot.rollbackCount)"
            )
            checkpoints = []
            anchorWeightNorms = []
            baselineCanaryLoss = 0
            return snapshot
        } catch {
            Self.log.error("Failed to end adaptation session: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Anchor Management

    func updateAnchor(currentWeightNorms: [Double]) {
        if anchorWeightNorms.isEmpty {
            anchorWeightNorms = currentWeightNorms
        } else {
            anchorWeightNorms = stabilizer.updatedAnchorNorms(
                currentAnchor: anchorWeightNorms,
                newWeightNorms: currentWeightNorms
            )
        }
    }

    func currentAnchorDivergence(currentWeightNorms: [Double]) -> Double {
        stabilizer.computeAnchorDivergence(
            currentWeightNorms: currentWeightNorms,
            anchorWeightNorms: anchorWeightNorms
        )
    }

    // MARK: - Rollback

    var bestRollbackTarget: AdapterCheckpoint? {
        stabilizer.bestRollbackTarget(checkpoints)
    }

    var currentSnapshot: AdaptSessionSnapshot? {
        guard let sessionID = activeSessionID else { return nil }
        return try? subsystem.adaptSessionSnapshot(sessionId: sessionID)
    }
}

// MARK: - Errors

enum AdaptationExecutorError: LocalizedError, Equatable {
    case sessionAlreadyActive
    case noActiveSession
    case helperModelRequired
    case mainRuntimeAdaptationDenied

    var errorDescription: String? {
        switch self {
        case .sessionAlreadyActive:
            return "An adaptation session is already active."
        case .noActiveSession:
            return "No adaptation session is currently active."
        case .helperModelRequired:
            return "Adaptation requires a helper model, not the primary runtime."
        case .mainRuntimeAdaptationDenied:
            return "Adaptation on the main GGUF runtime is denied."
        }
    }
}
