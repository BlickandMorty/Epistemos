import Foundation
import Observation
import os

// MARK: - Resonance Gate Swift Consumer
//
// The Swift-side surface for the Rust `agent_core::resonance` τ + π + λ
// daemon (committed in `06230e8d Seed Resonance Gate τ + π + λ daemon`).
// This service mirrors the Rust types as Swift value types so the UI can
// render Σ-core signatures without depending on the FFI being live.
//
// Doctrine §4.1 anchor: the Resonance Gate is the user-facing surface of
// SCOPE-Rex. The Core tier ships τ (Kleene K3 truth) + π (prime/composite/
// gap classification over 9 typed claims) + λ (residency target L0–L3
// + L7). δ + ρ are Pro; κ + η are Research.
//
// FFI status: stub. When `agent_core::resonance::compute_signature_core`
// is exposed via UniFFI, swap `computeStub(for:)` for the real call. Until
// then, the Swift mirror computes the same logic and the UI surfaces are
// fully testable in isolation.

// MARK: - Mirror types (Swift mirror of agent_core::resonance public API)

/// Kleene K3 ternary truth value. Mirrors `agent_core::resonance::Truth`.
/// Integer encoding (-1, 0, +1) matches the Rust `as_int()` for future
/// FFI serialization.
nonisolated enum ResonanceTruth: Int8, Codable, Sendable, Hashable, CaseIterable {
    case false_ = -1
    case unknown = 0
    case true_ = 1

    /// Display label for UI consumers — short, glanceable.
    nonisolated var label: String {
        switch self {
        case .true_: "T"
        case .unknown: "?"
        case .false_: "F"
        }
    }

    /// Doctrine §4.1 invariant 1: "no token with τ = -1 ever reaches the user."
    nonisolated var passesInvariantOne: Bool {
        self != .false_
    }
}

/// 9 claim types per doctrine §4.1. Mirrors `agent_core::resonance::ClaimType`.
nonisolated enum ResonanceClaimType: String, Codable, Sendable, Hashable, CaseIterable {
    // Concrete (six)
    case equation, inequality, causal, definition, empirical, codeInvariant
    // Ontological (three)
    case prime, composite, gap

    nonisolated var displayName: String {
        switch self {
        case .equation: "Equation"
        case .inequality: "Inequality"
        case .causal: "Causal"
        case .definition: "Definition"
        case .empirical: "Empirical"
        case .codeInvariant: "Code Invariant"
        case .prime: "Prime"
        case .composite: "Composite"
        case .gap: "Gap"
        }
    }
}

/// π output. Mirrors `agent_core::resonance::ClaimClass`.
nonisolated enum ResonanceClass: String, Codable, Sendable, Hashable, CaseIterable {
    case prime, composite, gap

    nonisolated var label: String {
        switch self {
        case .prime: "P"
        case .composite: "C"
        case .gap: "G"
        }
    }
}

/// 8-level residency hierarchy. Mirrors `agent_core::resonance::ResidencyLevel`.
nonisolated enum ResonanceResidency: String, Codable, Sendable, Hashable, CaseIterable {
    case l0Working, l1Recent, l2Warm, l3Cold
    case l4Engram, l5Adapter, l6Forbidden
    case l7Quarantine

    /// Mirrors the Rust `is_core_allowed()` enforcement. Core builds
    /// must reject signatures emitting L4–L6.
    nonisolated var isCoreAllowed: Bool {
        switch self {
        case .l0Working, .l1Recent, .l2Warm, .l3Cold, .l7Quarantine: true
        case .l4Engram, .l5Adapter, .l6Forbidden: false
        }
    }

    nonisolated var label: String {
        switch self {
        case .l0Working: "L0"
        case .l1Recent: "L1"
        case .l2Warm: "L2"
        case .l3Cold: "L3"
        case .l4Engram: "L4"
        case .l5Adapter: "L5"
        case .l6Forbidden: "L6"
        case .l7Quarantine: "L7"
        }
    }
}

/// Core-tier Σ signature. Mirrors `agent_core::resonance::ResonanceSignatureCore`.
/// Pro tier extends with `direction` + `resonance`; Research with `kam` + `evidence`.
nonisolated struct ResonanceSignatureCore: Codable, Sendable, Hashable {
    let truth: ResonanceTruth
    let class_: ResonanceClass
    let residency: ResonanceResidency

    nonisolated var passesTruthInvariant: Bool { truth.passesInvariantOne }
    nonisolated var isCoreCompatible: Bool { residency.isCoreAllowed }
}

/// Input claim. Mirrors `agent_core::resonance::Claim`.
nonisolated struct ResonanceClaim: Sendable, Hashable {
    let kind: ResonanceClaimType
    let statement: String
    let dependencyCount: Int
    let evidenceCount: Int

    nonisolated init(
        kind: ResonanceClaimType,
        statement: String,
        dependencyCount: Int = 0,
        evidenceCount: Int = 0
    ) {
        self.kind = kind
        self.statement = statement
        self.dependencyCount = max(0, dependencyCount)
        self.evidenceCount = max(0, evidenceCount)
    }
}

// MARK: - Service

/// Swift consumer for the Resonance Gate τ + π + λ daemon.
///
/// **FFI status.** Today the service computes signatures locally in Swift
/// using the same logic as the Rust seed. When the Rust FFI exposes
/// `compute_resonance_signature_core(...)`, swap `computeStub(for:)` for
/// the FFI call. The mirror Swift logic stays for offline tests + previews.
@MainActor
@Observable
final class ResonanceService {

    static let shared = ResonanceService()

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "ResonanceService"
    )

    /// Most recent signature computed; `nil` until the first call.
    private(set) var lastSignature: ResonanceSignatureCore?

    /// Rolling counter — useful for diagnostics + test assertions.
    private(set) var signaturesComputed: UInt64 = 0

    init() {}

    /// Compute the Core-tier Σ signature for a claim. Pure given the
    /// input; safe to call from any caller. Hot-path target per doctrine
    /// §4.1 is < 100 µs/token; the Swift mirror is well within that.
    @discardableResult
    func computeSignatureCore(for claim: ResonanceClaim) -> ResonanceSignatureCore {
        #if canImport(agent_coreFFI)
        // FUTURE: replace with the real FFI call, e.g.
        //   let sig = computeResonanceSignatureCore(claimJson: encode(claim))
        let signature = computeStub(for: claim)
        #else
        let signature = computeStub(for: claim)
        #endif
        lastSignature = signature
        signaturesComputed &+= 1
        return signature
    }

    /// Whether the most recent signature is allowed in a Core build.
    /// Returns `false` if no signature has been computed yet.
    var lastSignatureIsCoreCompatible: Bool {
        lastSignature?.isCoreCompatible ?? false
    }

    // MARK: - Private — Swift mirror of the Rust seed

    private func computeStub(for claim: ResonanceClaim) -> ResonanceSignatureCore {
        ResonanceSignatureCore(
            truth: evaluateTruth(claim),
            class_: classify(claim),
            residency: targetResidency(claim)
        )
    }

    private func evaluateTruth(_ claim: ResonanceClaim) -> ResonanceTruth {
        switch claim.kind {
        case .definition: return .true_
        case .empirical: return claim.evidenceCount >= 3 ? .true_ : .unknown
        case .composite where claim.dependencyCount == 0: return .false_
        default: return .unknown
        }
    }

    private func classify(_ claim: ResonanceClaim) -> ResonanceClass {
        switch claim.kind {
        case .definition, .prime: return .prime
        case .composite: return .composite
        case .gap: return .gap
        default: break
        }
        let hasEvidence = claim.evidenceCount > 0
        switch (claim.dependencyCount, hasEvidence) {
        case (0, true): return .prime
        case let (n, _) where n >= 2: return .composite
        default: return .gap
        }
    }

    private func targetResidency(_ claim: ResonanceClaim) -> ResonanceResidency {
        if claim.kind == .composite, claim.dependencyCount == 0 {
            return .l7Quarantine
        }
        switch claim.kind {
        case .definition: return .l2Warm
        case .empirical: return claim.evidenceCount >= 3 ? .l1Recent : .l3Cold
        case .equation, .inequality, .codeInvariant: return .l1Recent
        case .causal: return .l2Warm
        case .prime: return .l1Recent
        case .composite: return .l0Working
        case .gap: return .l3Cold
        }
    }
}
