import Foundation
import Testing
@testable import Epistemos

/// P5.H A1 (EML-2) — the ConfidenceRouter EML route fusion. Each hard gate in
/// `route()` checks one axis (confidence, complexity, …) in isolation; the EML
/// key fuses confidence × complexity-headroom into one energy so a request that
/// scrapes past every individual gate but is jointly weak defers to cloud.
/// Default OFF (EPISTEMOS_EML_ROUTE_V1) → `route()` is byte-identical to before.
/// These pin the fusion math + the flag-gating + that the default build is
/// unchanged + that the energy is byte-identical to the Rust vault re-rank key.
@Suite("EML route fusion (EML-2)")
struct EmlRouteFusionTests {

    private let router = ConfidenceRouter()  // defaults: thr 0.60, maxCplx 0.40, ceiling 1.50

    // Borderline on BOTH axes: confidence just over the 0.60 threshold AND
    // complexity just under the 0.40 ceiling (headroom ≈ 0.01).
    private let borderlineBoth = ConfidenceRouter.Classification(
        complexity: 0.39, toolCountEstimate: 1, requiresCurrentInfo: false,
        requiresCodeExecution: false, privacySensitive: false, confidence: 0.61
    )
    // Strong on confidence, tight on complexity.
    private let strongConfidence = ConfidenceRouter.Classification(
        complexity: 0.39, toolCountEstimate: 1, requiresCurrentInfo: false,
        requiresCodeExecution: false, privacySensitive: false, confidence: 0.99
    )
    // Weak-ish confidence, ample complexity headroom.
    private let ampleHeadroom = ConfidenceRouter.Classification(
        complexity: 0.00, toolCountEstimate: 1, requiresCurrentInfo: false,
        requiresCodeExecution: false, privacySensitive: false, confidence: 0.61
    )

    @Test("flag truth table mirrors the Rust gates")
    func flagTruthTable() {
        for on in ["1", "true", "TRUE", "Yes", "on", " on "] {
            #expect(ConfidenceRouter.emlRouteFusionEnabled(environment: ["EPISTEMOS_EML_ROUTE_V1": on]))
        }
        for off in ["0", "false", "no", "off", "", "2"] {
            #expect(!ConfidenceRouter.emlRouteFusionEnabled(environment: ["EPISTEMOS_EML_ROUTE_V1": off]))
        }
        #expect(!ConfidenceRouter.emlRouteFusionEnabled(environment: [:]))
    }

    @Test("local-fitness energy is byte-identical to the EML key formula")
    func energyMatchesFormula() {
        // 1/(confidence+ε) − ln(headroom+1), the Rust eml_rerank::rerank_key.
        let eps = 1e-6
        let headroom = 0.40 - 0.39
        let expected = 1.0 / (0.61 + eps) - log(headroom + 1.0)
        #expect(abs(router.localFitnessEnergy(borderlineBoth) - expected) < 1e-9)
        // Also exactly EmlRerank.rerankKey (the shared primitive).
        #expect(router.localFitnessEnergy(borderlineBoth)
                == EmlRerank.rerankKey(primary: 0.61, secondary: headroom))
    }

    @Test("fusion OFF never defers (default build unchanged)")
    func fusionOffNeverDefers() {
        #expect(!router.shouldDeferForLocalFitness(borderlineBoth, fusionEnabled: false, ceiling: 1.50))
        #expect(!router.shouldDeferForLocalFitness(strongConfidence, fusionEnabled: false, ceiling: 1.50))
    }

    @Test("fusion ON defers only when BOTH axes are weak")
    func fusionOnFusesSignals() {
        // Borderline on both → energy ≈ 1.629 > 1.50 → defer.
        #expect(router.shouldDeferForLocalFitness(borderlineBoth, fusionEnabled: true, ceiling: 1.50))
        // Strong on EITHER axis rescues it (energy < 1.50 → stay local).
        #expect(!router.shouldDeferForLocalFitness(strongConfidence, fusionEnabled: true, ceiling: 1.50))
        #expect(!router.shouldDeferForLocalFitness(ampleHeadroom, fusionEnabled: true, ceiling: 1.50))
    }

    @Test("route() default (flag OFF) keeps the borderline case local")
    func routeDefaultKeepsBorderlineLocal() {
        let request = ConfidenceRouter.Request(
            objective: "Summarize my notes.",
            selectedLocalModelID: LocalTextModelID.qwen35_4B4Bit.rawValue,
            requiresStructuredOutput: false,
            schemaJson: nil
        )
        // Real process env has EPISTEMOS_EML_ROUTE_V1 unset → OFF → the gate is
        // skipped, so the borderline-on-both request still approves locally.
        let decision = router.route(request: request, classification: borderlineBoth)
        #expect(decision.route == .local)
        #expect(decision.reason == .localAgentApproved)
    }
}
