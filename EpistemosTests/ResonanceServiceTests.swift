import Testing
@testable import Epistemos

/// Swift-side mirror of the Rust `agent_core::resonance` τ + π + λ
/// daemon seed. Validates that the Swift mirror in
/// `Epistemos/Engine/ResonanceService.swift` matches the Rust seed's
/// behavior exactly. When the FFI lands, these tests will continue to
/// validate the offline mirror used by SwiftUI Previews.
///
/// Doctrine §7 lane: Core killer-feature seed work — Resonance Gate
/// τ + π + λ daemon (Swift consumer + UI shell).
@MainActor
@Suite("Resonance Service")
struct ResonanceServiceTests {

    // MARK: - Mirror types — fixed enum cardinality per doctrine §4.1

    @Test("ResonanceTruth has exactly three Kleene K3 values")
    func truthHasThreeKleeneValues() {
        #expect(ResonanceTruth.allCases.count == 3)
        #expect(ResonanceTruth.true_.rawValue == 1)
        #expect(ResonanceTruth.unknown.rawValue == 0)
        #expect(ResonanceTruth.false_.rawValue == -1)
    }

    @Test("ResonanceClaimType enumerates the 9 doctrine §4.1 types")
    func claimTypeEnumeratesNineTypes() {
        #expect(ResonanceClaimType.allCases.count == 9)
        // Spot-check each variant present
        for kind in [
            ResonanceClaimType.equation, .inequality, .causal,
            .definition, .empirical, .codeInvariant,
            .prime, .composite, .gap
        ] {
            #expect(ResonanceClaimType.allCases.contains(kind))
        }
    }

    @Test("ResonanceClass has exactly three structural classes")
    func classHasThreeStructuralClasses() {
        #expect(ResonanceClass.allCases.count == 3)
    }

    @Test("ResonanceResidency has 8 levels and Core gates 3 of them")
    func residencyEightLevelsCoreGatesThree() {
        #expect(ResonanceResidency.allCases.count == 8)
        let coreAllowed = ResonanceResidency.allCases.filter(\.isCoreAllowed)
        #expect(coreAllowed.count == 5,
                "Core-allowed = L0..L3 + L7 = 5 levels")
        let proResearchOnly = ResonanceResidency.allCases.filter { !$0.isCoreAllowed }
        #expect(proResearchOnly.count == 3,
                "L4..L6 must be Pro/Research only")
        for lvl in [ResonanceResidency.l4Engram, .l5Adapter, .l6Forbidden] {
            #expect(!lvl.isCoreAllowed, "\(lvl) must not be Core-allowed")
        }
    }

    // MARK: - τ — Kleene K3 truth invariant 1

    @Test("Doctrine §4.1 invariant 1: τ = -1 must not pass")
    func truthInvariantOneRejectsFalse() {
        #expect(ResonanceTruth.true_.passesInvariantOne)
        #expect(ResonanceTruth.unknown.passesInvariantOne)
        #expect(!ResonanceTruth.false_.passesInvariantOne)
    }

    // MARK: - Service: definition tautologically True + Prime + L2 Warm

    @Test("Definition computes (True, Prime, L2 Warm)")
    func definitionComputesExpectedSignature() {
        let svc = ResonanceService()
        let claim = ResonanceClaim(
            kind: .definition,
            statement: "A graph is a set of nodes and edges."
        )
        let sig = svc.computeSignatureCore(for: claim)
        #expect(sig.truth == .true_)
        #expect(sig.class_ == .prime)
        #expect(sig.residency == .l2Warm)
        #expect(sig.passesTruthInvariant)
        #expect(sig.isCoreCompatible)
    }

    // MARK: - Service: empirical claim promotes with evidence

    @Test("Empirical truth promotes at evidence threshold of 3")
    func empiricalPromotesWithEvidence() {
        let svc = ResonanceService()
        for evidence: Int in [0, 1, 2] {
            let sig = svc.computeSignatureCore(for: ResonanceClaim(
                kind: .empirical,
                statement: "x",
                evidenceCount: evidence
            ))
            #expect(sig.truth == .unknown,
                    "evidence=\(evidence) should be Unknown")
        }
        for evidence: Int in [3, 5, 100] {
            let sig = svc.computeSignatureCore(for: ResonanceClaim(
                kind: .empirical,
                statement: "x",
                evidenceCount: evidence
            ))
            #expect(sig.truth == .true_,
                    "evidence=\(evidence) should be True")
        }
    }

    // MARK: - Service: composite without dependencies → quarantine + False

    @Test("Composite without dependencies quarantines and is False")
    func structurallyInvalidCompositeQuarantines() {
        let svc = ResonanceService()
        let bad = ResonanceClaim(
            kind: .composite,
            statement: "structurally invalid",
            dependencyCount: 0
        )
        let sig = svc.computeSignatureCore(for: bad)
        #expect(sig.truth == .false_)
        #expect(sig.residency == .l7Quarantine)
        #expect(!sig.passesTruthInvariant,
                "False claim must NOT pass display invariant")
        #expect(sig.isCoreCompatible,
                "L7 Quarantine is Core-allowed (the safe sink)")
    }

    // MARK: - Service: π classification

    @Test("π classifies lone evidenced claim as Prime")
    func loneEvidencedClaimIsPrime() {
        let svc = ResonanceService()
        let sig = svc.computeSignatureCore(for: ResonanceClaim(
            kind: .empirical,
            statement: "isolated finding",
            dependencyCount: 0,
            evidenceCount: 5
        ))
        #expect(sig.class_ == .prime)
    }

    @Test("π classifies 2+ deps as Composite")
    func twoOrMoreDepsClassifyAsComposite() {
        let svc = ResonanceService()
        for deps in [2, 3, 10] {
            let sig = svc.computeSignatureCore(for: ResonanceClaim(
                kind: .empirical,
                statement: "x",
                dependencyCount: deps,
                evidenceCount: 1
            ))
            #expect(sig.class_ == .composite,
                    "deps=\(deps) should classify as Composite")
        }
    }

    @Test("π classifies no-evidence-no-deps as Gap")
    func noEvidenceNoDepsIsGap() {
        let svc = ResonanceService()
        let sig = svc.computeSignatureCore(for: ResonanceClaim(
            kind: .empirical,
            statement: "x",
            dependencyCount: 0,
            evidenceCount: 0
        ))
        #expect(sig.class_ == .gap)
    }

    @Test("π ontological inputs short-circuit to their class")
    func ontologicalInputsShortCircuit() {
        let svc = ResonanceService()
        for (kind, expected) in [
            (ResonanceClaimType.prime, ResonanceClass.prime),
            (.composite, .composite),
            (.gap, .gap)
        ] as [(ResonanceClaimType, ResonanceClass)] {
            let sig = svc.computeSignatureCore(for: ResonanceClaim(
                kind: kind,
                statement: "ontological input",
                dependencyCount: kind == .composite ? 2 : 0,
                evidenceCount: 100
            ))
            #expect(sig.class_ == expected,
                    "kind \(kind) should classify as \(expected)")
        }
    }

    // MARK: - Core compatibility sweep — invariant per doctrine §3 + §6

    @Test("Service never emits a non-Core-compatible signature")
    func serviceNeverEmitsProResearchResidency() {
        let svc = ResonanceService()
        for kind in ResonanceClaimType.allCases {
            for evidence in [0, 1, 3, 10] {
                for deps in [0, 1, 2, 3] {
                    let sig = svc.computeSignatureCore(for: ResonanceClaim(
                        kind: kind,
                        statement: "sweep",
                        dependencyCount: deps,
                        evidenceCount: evidence
                    ))
                    #expect(sig.isCoreCompatible,
                            "Core seed emitted non-Core signature \(sig) for kind=\(kind) evidence=\(evidence) deps=\(deps)")
                }
            }
        }
    }

    // MARK: - Service: signature is a pure function

    @Test("Same input yields identical signature")
    func signatureIsPureFunction() {
        let svc = ResonanceService()
        let claim = ResonanceClaim(
            kind: .definition,
            statement: "Pure"
        )
        let sig1 = svc.computeSignatureCore(for: claim)
        let sig2 = svc.computeSignatureCore(for: claim)
        #expect(sig1 == sig2)
    }

    @Test("Service tracks lastSignature + signaturesComputed counter")
    func serviceTracksLastSignatureAndCounter() {
        let svc = ResonanceService()
        #expect(svc.lastSignature == nil)
        #expect(svc.signaturesComputed == 0)

        let sig1 = svc.computeSignatureCore(for: ResonanceClaim(
            kind: .definition,
            statement: "first"
        ))
        #expect(svc.lastSignature == sig1)
        #expect(svc.signaturesComputed == 1)

        let sig2 = svc.computeSignatureCore(for: ResonanceClaim(
            kind: .empirical,
            statement: "second",
            evidenceCount: 5
        ))
        #expect(svc.lastSignature == sig2)
        #expect(svc.signaturesComputed == 2)
    }

    @Test("Swift service labels Rust FFI as wired and fallback as mirror, not stub")
    func serviceFFIStatusIsWiredAndFallbackIsMirror() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Engine/ResonanceService.swift")
        #expect(source.contains("FFI status: wired"))
        #expect(source.contains("compute_resonance_signature_core"))
        #expect(source.contains("computeSwiftMirror(for:)"))
        #expect(source.contains("swiftMirrorFallbackCount"))
        #expect(!source.contains("FFI status: stub"))
        #expect(!source.contains("computeStub(for:)"))
        #expect(!source.contains("Swift stub"))
        #expect(!source.contains("stubFallbackCount"))
    }

    @Test("lastSignatureIsCoreCompatible mirrors lastSignature.isCoreCompatible")
    func lastSignatureCompatibilityMirrors() {
        let svc = ResonanceService()
        #expect(!svc.lastSignatureIsCoreCompatible,
                "Empty service should report not-compatible")

        _ = svc.computeSignatureCore(for: ResonanceClaim(
            kind: .definition,
            statement: "x"
        ))
        #expect(svc.lastSignatureIsCoreCompatible,
                "Definition-derived signature is Core-compatible")
    }
}
