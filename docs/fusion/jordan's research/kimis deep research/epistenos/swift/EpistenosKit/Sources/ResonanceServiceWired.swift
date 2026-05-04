import Foundation

/// Swift mirror of Rust ResonanceSignature — Codable for JSON round-trip via FFI.
public struct ResonanceSignature: Codable, Sendable {
    public var loadPressure: Float
    public var entropyCurvature: Float
    public var semanticTorsion: Float       // τ ∈ [-1,1]
    public var predictiveResidual: Float
    public var plasticityState: String     // "freeze", "fast_weight", "lora", "sketch"
    public var claimType: String           // "prime", "composite", "gap"
    public var direction: String          // "upward", "downward", "sideways", "inward", "on_itself", "none"
    public var kamStability: Float         // ∈ [0,1]; φ = 0.382 critical
    
    public init(
        loadPressure: Float = 0,
        entropyCurvature: Float = 0,
        semanticTorsion: Float = 0,
        predictiveResidual: Float = 0,
        plasticityState: String = "freeze",
        claimType: String = "composite",
        direction: String = "none",
        kamStability: Float = 1.0
    ) {
        self.loadPressure = loadPressure
        self.entropyCurvature = entropyCurvature
        self.semanticTorsion = semanticTorsion
        self.predictiveResidual = predictiveResidual
        self.plasticityState = plasticityState
        self.claimType = claimType
        self.direction = direction
        self.kamStability = kamStability
    }
}

public enum GateAction: String, Codable, Sendable {
    case pass = "Pass"
    case hold = "Hold"
    case quarantine = "Quarantine"
    case triggerEvidenceSupremacy = "TriggerEvidenceSupremacy"
    case engramAnchor = "EngramAnchor"
    case migrateResidency = "MigrateResidency"
}

@MainActor
public final class ResonanceService {
    public static let shared = ResonanceService()
    
    /// Compute signature via FFI to Rust core.
    public func computeSignature(
        loadPressure: Float,
        entropyCurvature: Float,
        semanticTorsion: Float,
        predictiveResidual: Float,
        plasticityState: String,
        claimType: String,
        direction: String,
        kamStability: Float
    ) -> ResonanceSignature {
        // Call UniFFI exported function
        let ffi = computeResonanceSignatureCore(
            loadPressure: loadPressure,
            entropyCurvature: entropyCurvature,
            semanticTorsion: semanticTorsion,
            predictiveResidual: predictiveResidual,
            plasticityState: plasticityState,
            claimType: claimType,
            direction: direction,
            kamStability: kamStability
        )
        return ResonanceSignature(
            loadPressure: ffi.loadPressure,
            entropyCurvature: ffi.entropyCurvature,
            semanticTorsion: ffi.semanticTorsion,
            predictiveResidual: ffi.predictiveResidual,
            plasticityState: ffi.plasticityState,
            claimType: ffi.claimType,
            direction: ffi.direction,
            kamStability: ffi.kamStability
        )
    }
    
    /// Run the gate decision via FFI.
    public func decide(_ signature: ResonanceSignature) -> GateAction {
        let ffiSig = ResonanceSignatureFFI(
            loadPressure: signature.loadPressure,
            entropyCurvature: signature.entropyCurvature,
            semanticTorsion: signature.semanticTorsion,
            predictiveResidual: signature.predictiveResidual,
            plasticityState: signature.plasticityState,
            claimType: signature.claimType,
            direction: signature.direction,
            kamStability: signature.kamStability
        )
        let action = resonanceGateDecide(sig: ffiSig)
        switch action {
        case .pass: return .pass
        case .hold: return .hold
        case .quarantine: return .quarantine
        case .triggerEvidenceSupremacy: return .triggerEvidenceSupremacy
        case .engramAnchor: return .engramAnchor
        case .migrateResidency(_): return .migrateResidency
        }
    }
}
