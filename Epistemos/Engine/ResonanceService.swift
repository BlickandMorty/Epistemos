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
// FFI status: wired when `agent_coreFFI` is linked. The service calls the
// Rust `compute_resonance_signature_core` entrypoint for authoritative
// signatures and keeps the Swift mirror only for previews, tests, and
// non-FFI builds.

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

    /// Rust-side serde variant name for `agent_core::resonance::ClaimType`.
    /// Default serde naming is PascalCase; Swift uses camelCase raw values
    /// for display. Keep these in sync with `agent_core/src/resonance/pi.rs`.
    nonisolated var rustName: String {
        switch self {
        case .equation: "Equation"
        case .inequality: "Inequality"
        case .causal: "Causal"
        case .definition: "Definition"
        case .empirical: "Empirical"
        case .codeInvariant: "CodeInvariant"
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
/// **FFI status.** When `agent_coreFFI` is linked the service calls the
/// Rust `compute_resonance_signature_core` for authoritative signatures.
/// The Swift `computeSwiftMirror(for:)` path remains as the offline fallback
/// (tests, previews, and any build that doesn't link agent_coreFFI). On
/// FFI failure the service logs and falls back to the mirror so the UI
/// surface never breaks.
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

    /// Counts FFI calls vs. Swift mirror fallbacks. Diagnostics only.
    private(set) var ffiCallCount: UInt64 = 0
    private(set) var swiftMirrorFallbackCount: UInt64 = 0

    init() {}

    /// Compute the Core-tier Σ signature for a claim. Pure given the
    /// input; safe to call from any caller. Hot-path target per doctrine
    /// §4.1 is < 100 µs/token; the Swift mirror is well within that.
    @discardableResult
    func computeSignatureCore(for claim: ResonanceClaim) -> ResonanceSignatureCore {
        #if canImport(agent_coreFFI)
        let signature: ResonanceSignatureCore
        do {
            signature = try Self.computeViaFFI(claim: claim)
            ffiCallCount &+= 1
        } catch {
            Self.log.error("Resonance FFI call failed (\(String(describing: error), privacy: .public)); falling back to Swift mirror")
            signature = computeSwiftMirror(for: claim)
            swiftMirrorFallbackCount &+= 1
        }
        #else
        let signature = computeSwiftMirror(for: claim)
        swiftMirrorFallbackCount &+= 1
        #endif
        lastSignature = signature
        signaturesComputed &+= 1
        return signature
    }

    #if canImport(agent_coreFFI)
    /// Bridge to the Rust `compute_resonance_signature_core` FFI. The
    /// Rust side accepts/returns JSON for the `Claim` and
    /// `ResonanceSignatureCore` types; we serialize via the wire structs
    /// below so the Swift public API doesn't have to expose Rust serde
    /// shape details.
    nonisolated private static func computeViaFFI(
        claim: ResonanceClaim
    ) throws -> ResonanceSignatureCore {
        let wire = ClaimWire(
            kind: claim.kind.rustName,
            statement: claim.statement,
            // Rust only reads `dependencies.len()` and `.is_empty()`, so we
            // pad with zero ClaimRefs to match the count. See
            // agent_core/src/resonance/{pi,tau,lambda}.rs — none of them
            // dereference the inner ClaimRef IDs.
            dependencies: Array(repeating: 0, count: claim.dependencyCount),
            evidence_count: UInt32(claim.evidenceCount)
        )
        let claimJson = try String(
            decoding: JSONEncoder().encode(wire),
            as: UTF8.self
        )
        let responseJson = try computeResonanceSignatureCore(claimJson: claimJson)
        let decoded = try JSONDecoder().decode(
            SignatureWire.self,
            from: Data(responseJson.utf8)
        )
        return ResonanceSignatureCore(
            truth: decoded.truth.swift,
            class_: decoded.class_.swift,
            residency: decoded.residency.swift
        )
    }

    nonisolated private struct ClaimWire: Encodable {
        let kind: String
        let statement: String
        let dependencies: [UInt64]
        let evidence_count: UInt32
    }

    nonisolated private struct SignatureWire: Decodable {
        let truth: TruthWire
        let class_: ClassWire
        let residency: ResidencyWire

        enum CodingKeys: String, CodingKey {
            case truth
            case class_ = "class"
            case residency
        }
    }

    nonisolated private enum TruthWire: String, Decodable {
        case True, Unknown, False
        var swift: ResonanceTruth {
            switch self {
            case .True: .true_
            case .Unknown: .unknown
            case .False: .false_
            }
        }
    }

    nonisolated private enum ClassWire: String, Decodable {
        case Prime, Composite, Gap
        var swift: ResonanceClass {
            switch self {
            case .Prime: .prime
            case .Composite: .composite
            case .Gap: .gap
            }
        }
    }

    nonisolated private enum ResidencyWire: String, Decodable {
        case L0Working, L1Recent, L2Warm, L3Cold, L4Engram, L5Adapter, L6Forbidden, L7Quarantine
        var swift: ResonanceResidency {
            switch self {
            case .L0Working: .l0Working
            case .L1Recent: .l1Recent
            case .L2Warm: .l2Warm
            case .L3Cold: .l3Cold
            case .L4Engram: .l4Engram
            case .L5Adapter: .l5Adapter
            case .L6Forbidden: .l6Forbidden
            case .L7Quarantine: .l7Quarantine
            }
        }
    }
    #endif

    /// Whether the most recent signature is allowed in a Core build.
    /// Returns `false` if no signature has been computed yet.
    var lastSignatureIsCoreCompatible: Bool {
        lastSignature?.isCoreCompatible ?? false
    }

    // MARK: - Private — Swift mirror of the Rust seed

    private func computeSwiftMirror(for claim: ResonanceClaim) -> ResonanceSignatureCore {
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
