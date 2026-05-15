import Foundation
import Testing
@testable import Epistemos

/// B.6 W1 — Cognitive Weight Swift mirror + W1 silent-downgrade tests.
///
/// Acceptance source: `docs/fusion/COGNITIVE_WEIGHT_CLASS_DOCTRINE_2026_05_04.md`
/// §2 (4-tier classification table) + §6 (W1 silent-downgrade contract).
///
/// Wire-format parity with `agent_core::cognitive_weight::CognitiveWeight`
/// is verified by the JSON round-trip tests below — a payload encoded
/// in Rust deserializes correctly through this Swift mirror.
@Suite("Cognitive Weight (B.6 W1)")
struct CognitiveWeightTests {
    @Test("Classification table boundaries match doctrine §2 exactly")
    func classificationBoundariesMatchDoctrine() throws {
        // Boundary anchors per doctrine §2 — boundary scores fall to
        // the LOWER class (the table reads "0.00–0.30" inclusive).
        #expect(CognitiveWeight.classify(0.00) == .soft)
        #expect(CognitiveWeight.classify(0.30) == .soft)
        #expect(CognitiveWeight.classify(0.31) == .preferred)
        #expect(CognitiveWeight.classify(0.60) == .preferred)
        #expect(CognitiveWeight.classify(0.61) == .strongAnchor)
        #expect(CognitiveWeight.classify(0.85) == .strongAnchor)
        #expect(CognitiveWeight.classify(0.86) == .policyGrade)
        #expect(CognitiveWeight.classify(1.00) == .policyGrade)
    }

    @Test("Raw score is clamped to [0, 1]")
    func rawScoreClamped() throws {
        let negative = CognitiveWeight(rawScore: -0.5)
        #expect(negative.rawScore == 0.0)
        #expect(negative.class == .soft)

        let over = CognitiveWeight(rawScore: 1.5)
        #expect(over.rawScore == 1.0)
        #expect(over.class == .policyGrade)
    }

    @Test("policyAuthority is ALWAYS false (W1 §6 silent-downgrade)")
    func policyAuthorityAlwaysFalseW1() throws {
        // Test the silent-downgrade contract against every class.
        // Even constructing a 0.99-score weight (clearly policy_grade)
        // MUST report policyAuthority=false on the Swift side under W1.
        for raw: Float in [0.0, 0.30, 0.50, 0.70, 0.86, 0.95, 1.00] {
            let weight = CognitiveWeight(rawScore: raw)
            #expect(
                weight.policyAuthority == false,
                "raw=\(raw) (class=\(weight.class)) MUST have policyAuthority=false under W1"
            )
        }
    }

    @Test("Decoder silently downgrades policy_authority:true from FFI wire")
    func decoderSilentlyDowngradesPolicyAuthority() throws {
        // Simulate a Rust-side payload that incorrectly sets
        // policy_authority=true. The Swift decoder MUST rewrite to
        // false so the misconfigured upstream doesn't accidentally
        // signal policy authority into the UI.
        let rustJSON = """
        {
            "raw_score": 0.95,
            "class": "policy_grade",
            "policy_authority": true,
            "retrieval_priority_boost": 0.80,
            "context_placement": "immutable_system"
        }
        """
        let data = Data(rustJSON.utf8)
        let decoded = try JSONDecoder().decode(CognitiveWeight.self, from: data)
        #expect(decoded.class == .policyGrade)
        #expect(
            decoded.policyAuthority == false,
            "W1 §6: Swift decoder MUST silently downgrade policy_authority=true to false"
        )
        #expect(decoded.rawScore == 0.95)
    }

    @Test("Bias for class matches doctrine §2 retrieval-priority range")
    func biasForClassMatchesDoctrine() throws {
        // §2 ranges: Soft 0–10% → 0.05, Preferred 10–30% → 0.20,
        // StrongAnchor 30–60% → 0.45, PolicyGrade 60–100% → 0.80.
        let pairs: [(CognitiveWeightClass, ClosedRange<Float>)] = [
            (.soft, 0.00...0.10),
            (.preferred, 0.10...0.30),
            (.strongAnchor, 0.30...0.60),
            (.policyGrade, 0.60...1.00),
        ]
        for (cls, range) in pairs {
            let (boost, _) = CognitiveWeight.biasForClass(cls)
            #expect(
                range.contains(boost),
                "boost \(boost) for class \(cls) outside doctrine range \(range)"
            )
        }
    }

    @Test("Context placement per class matches doctrine §2")
    func contextPlacementPerClass() throws {
        #expect(CognitiveWeight.biasForClass(.soft).1 == .trailing)
        #expect(CognitiveWeight.biasForClass(.preferred).1 == .inline)
        #expect(CognitiveWeight.biasForClass(.strongAnchor).1 == .aboveFold)
        #expect(CognitiveWeight.biasForClass(.policyGrade).1 == .immutableSystem)
    }

    @Test("Wire format uses snake_case (Rust-side parity)")
    func wireFormatUsesSnakeCase() throws {
        let weight = CognitiveWeight(rawScore: 0.95)
        let json = try JSONEncoder().encode(weight)
        let str = String(data: json, encoding: .utf8) ?? ""
        // Key names match the Rust serde field names so the FFI
        // boundary doesn't need a remap layer.
        #expect(str.contains("\"raw_score\""))
        #expect(str.contains("\"policy_authority\""))
        #expect(str.contains("\"retrieval_priority_boost\""))
        #expect(str.contains("\"context_placement\""))
        #expect(str.contains("\"policy_grade\""), "class value must serialize as snake_case")
        #expect(str.contains("\"immutable_system\""), "placement value must serialize as snake_case")
    }

    @Test("4 short labels are distinct + non-empty (badge display)")
    func shortLabelsDistinct() throws {
        let labels = Set(CognitiveWeightClass.allCases.map(\.shortLabel))
        #expect(labels.count == 4)
        #expect(!labels.contains(""))
        // Specific labels pinned for badge consistency:
        #expect(CognitiveWeightClass.soft.shortLabel == "Soft")
        #expect(CognitiveWeightClass.preferred.shortLabel == "Preferred")
        #expect(CognitiveWeightClass.strongAnchor.shortLabel == "Strong")
        #expect(CognitiveWeightClass.policyGrade.shortLabel == "Policy")
    }

    @Test("PolicyGrade accessibility description explicitly mentions W1 advisory state")
    func policyGradeAccessibilityMentionsW1() throws {
        // §6 acceptance: the PolicyGrade variant MUST tell the user it's
        // advisory until W2 — so a user inspecting the badge with VoiceOver
        // doesn't think policy authority is enforced.
        let desc = CognitiveWeightClass.policyGrade.accessibilityDescription
        #expect(desc.contains("advisory"))
        #expect(desc.contains("W1") || desc.contains("W2"),
                "PolicyGrade tooltip must reference the W1/W2 boundary")
    }

    @Test("ShadowRow renders CognitiveWeightBadge derived from hit.score (B.6 W1 wiring)")
    func shadowRowRendersCognitiveWeightBadge() throws {
        // Drift gate: pin that ShadowPanelContent.ShadowRow uses
        // CognitiveWeightBadge(weight: CognitiveWeight(rawScore: hit.score))
        // in its result-row header. If a refactor drops the badge or
        // breaks the rawScore-from-hit-score wiring, this trips
        // before the W1 visual contract regresses.
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Views/Halo/ShadowPanelContent.swift"
        )
        #expect(
            source.contains("CognitiveWeightBadge("),
            "ShadowRow MUST render CognitiveWeightBadge in its result-row header"
        )
        #expect(
            source.contains("CognitiveWeight(rawScore: hit.score)"),
            "ShadowRow MUST derive the badge weight from hit.score until sidecar metadata flows through"
        )
        // Accessibility label must surface the weight class so VoiceOver
        // users hear the 4-tier classification, not just the raw score.
        #expect(
            source.contains(".class.shortLabel"),
            "ShadowRow accessibility label MUST include the weight class short label"
        )
    }

    @Test("Encoded weight round-trips back through the decoder")
    func roundTripsThroughJSON() throws {
        let original = CognitiveWeight(rawScore: 0.70)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CognitiveWeight.self, from: data)
        #expect(decoded.rawScore == original.rawScore)
        #expect(decoded.class == original.class)
        #expect(decoded.policyAuthority == false) // W1 silent downgrade
        #expect(decoded.retrievalPriorityBoost == original.retrievalPriorityBoost)
        #expect(decoded.contextPlacement == original.contextPlacement)
    }
}
