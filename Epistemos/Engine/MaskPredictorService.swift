import Foundation
import OSLog

// MARK: - Phase 4: Mask Predictor Service
//
// **SCAFFOLD ONLY (RCA13 P2-009).** This file ships the
// `MaskPredictorService` protocol + payload types + the
// `PlaceholderMaskPredictor` concrete implementation. The placeholder
// always returns `.failure(.predictorUnavailable)` from `predict(...)`
// and exposes `isAvailable = false` so consumers can short-circuit.
//
// There is NO trained mask-predictor model loaded today. Settings /
// onboarding / chat tier UI must not advertise sparsity-aware mask
// prediction as a working feature. The placeholder lets the planner
// + overseer code paths compile + test, but every runtime call
// fails closed.
//
// When the V3.2 mask-predictor training slice lands, replace
// `PlaceholderMaskPredictor` with the trained implementation; the
// `isAvailable` flag flips and consumers light up automatically.

nonisolated struct PredictedLayerMask: Sendable, Equatable, Codable {
    let layerIndex: Int
    let activeBlocks: [Int]
    let totalBlocks: Int
    let sparsity: Double

    enum CodingKeys: String, CodingKey {
        case layerIndex = "layer_index"
        case activeBlocks = "active_blocks"
        case totalBlocks = "total_blocks"
        case sparsity
    }
}

nonisolated struct PredictedMaskResult: Sendable, Equatable, Codable {
    let layerMasks: [PredictedLayerMask]
    let confidence: Double
    let predictorModelID: String
    let calibrationVersion: String
    let overallSparsity: Double

    enum CodingKeys: String, CodingKey {
        case layerMasks = "layer_masks"
        case confidence
        case predictorModelID = "predictor_model_id"
        case calibrationVersion = "calibration_version"
        case overallSparsity = "overall_sparsity"
    }
}

nonisolated enum MaskPredictionError: LocalizedError, Sendable {
    case predictorUnavailable
    case instructionTooShort
    case predictionFailed(String)
    case sparsityExceedsCap
    case lowConfidence

    var errorDescription: String? {
        switch self {
        case .predictorUnavailable:
            "Mask predictor model is not available."
        case .instructionTooShort:
            "Instruction too short for mask prediction."
        case .predictionFailed(let reason):
            "Mask prediction failed: \(reason)"
        case .sparsityExceedsCap:
            "Predicted sparsity exceeds the Phase 4 cap (60%)."
        case .lowConfidence:
            "Prediction confidence below threshold."
        }
    }
}

protocol MaskPredictorService: Sendable {
    var isAvailable: Bool { get }
    var minimumConfidence: Double { get }
    var maximumSparsity: Double { get }
    func predict(instruction: String) async -> Result<PredictedMaskResult, MaskPredictionError>
}

final class PlaceholderMaskPredictor: MaskPredictorService, @unchecked Sendable {
    private static let log = Logger(subsystem: "com.epistemos", category: "MaskPredictor")

    let isAvailable: Bool = false
    let minimumConfidence: Double = 0.6
    let maximumSparsity: Double = 0.6

    func predict(instruction: String) async -> Result<PredictedMaskResult, MaskPredictionError> {
        Self.log.info("Mask predictor called but no trained model is loaded — returning unavailable")
        return .failure(.predictorUnavailable)
    }
}
