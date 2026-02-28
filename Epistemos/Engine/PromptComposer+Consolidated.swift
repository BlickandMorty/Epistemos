import Foundation
import os

// MARK: - Consolidated Enrichment (Passes 3-6 in one call)
// Replaces 4 sequential LLM calls with a single structured JSON call.
// Raw analysis (Pass 2) still runs separately as it's the heaviest pass.

extension EnrichmentController {

    /// Result of the consolidated Passes 3-6 call.
    struct ConsolidatedEnrichment {
        let laymanSummary: LaymanSummary
        let reflection: ReflectionResult
        let arbitration: ArbitrationResult
        let truthAssessment: TruthAssessment
    }

    /// Single LLM call that produces layman summary + reflection + arbitration + truth assessment.
    /// Reduces latency by ~60% vs 4 separate calls (each repeating the raw analysis context).
    static func generateConsolidatedEnrichment(
        query: String,
        rawAnalysis: String,
        queryAnalysis: QueryAnalysis,
        signals: GeneratedSignals,
        llm: LLMSnapshot
    ) async -> ConsolidatedEnrichment? {
        // Adaptive section labels based on question type (same as individual Pass 3)
        let (label1, label2, label3, label4, label5): (String, String, String, String, String)
        switch queryAnalysis.questionType {
        case .causal:
            (label1, label2, label3, label4, label5) = (
                "Causal analysis", "Probable relationship", "Causal certainty",
                "Alternative explanations", "Decision relevance"
            )
        case .empirical:
            (label1, label2, label3, label4, label5) = (
                "Methodology", "Key findings", "Evidence strength", "Limitations & gaps",
                "Applicability"
            )
        case .conceptual:
            (label1, label2, label3, label4, label5) = (
                "Conceptual landscape", "Most defensible position", "Epistemic status",
                "Key objections", "Who this matters to"
            )
        case .comparative:
            (label1, label2, label3, label4, label5) = (
                "Comparison framework", "Key differences", "Confidence in comparison",
                "What changes the verdict", "Context dependency"
            )
        default:
            (label1, label2, label3, label4, label5) = (
                "Approach taken", "Most likely true", "Confidence level", "What could change this",
                "Who should use this"
            )
        }

        let tagCounts = countEpistemicTags(in: rawAnalysis)

        let systemPrompt = """
            \(systemPreamble)

            You are performing CONSOLIDATED ENRICHMENT — producing four analyses in a single structured response. Each section has specific requirements. Work through them in order, as later sections build on earlier reasoning.

            QUERY: \(query)
            DOMAIN: \(queryAnalysis.domain.rawValue) | COMPLEXITY: \(String(format: "%.2f", queryAnalysis.complexity))
            SIGNALS: confidence=\(String(format: "%.2f", signals.confidence)), entropy=\(String(format: "%.2f", signals.entropy)), dissonance=\(String(format: "%.2f", signals.dissonance)), health=\(String(format: "%.2f", signals.healthScore))

            RAW ANALYSIS:
            \(rawAnalysis.prefix(8000))

            EPISTEMIC TAG COUNTS: [DATA]=\(tagCounts.data) [MODEL]=\(tagCounts.model) [UNCERTAIN]=\(tagCounts.uncertain) [CONFLICT]=\(tagCounts.conflict)

            ═══════════════════════════════════════
            SECTION 1: LAYMAN SUMMARY (5 subsections)
            ═══════════════════════════════════════
            Translate the raw analysis into an accessible 5-section summary.
            - "\(label1)" (whatWasTried): 4-6 sentences on methodology and approach
            - "\(label2)" (whatIsLikelyTrue): 8-15 sentences, the MAIN ANSWER with markdown, quantified where possible
            - "\(label3)" (confidenceExplanation): 4-6 sentences mapping confidence to decisions
            - "\(label4)" (whatCouldChange): 4-6 sentences naming specific evidence that would shift conclusions
            - "\(label5)" (whoShouldTrust): 4-6 sentences on who can safely act on this

            ═══════════════════════════════════════
            SECTION 2: ADVERSARIAL SELF-CRITIQUE
            ═══════════════════════════════════════
            Switch to hostile peer reviewer mode. Find weaknesses using: steel-man test, reductio ad absurdum, edge cases, missing evidence audit, survivorship bias check, anchoring detection.

            ═══════════════════════════════════════
            SECTION 3: MULTI-ENGINE ARBITRATION
            ═══════════════════════════════════════
            Simulate 5 independent engines (statistical, causal, Bayesian, meta-analysis, adversarial). Each votes supports/opposes/neutral with reasoning from its own framework. Consensus = true only if ≥4 agree.

            ═══════════════════════════════════════
            SECTION 4: TRUTH CALIBRATION
            ═══════════════════════════════════════
            REASON FIRST, THEN COMMIT (CoT-then-Confidence):
            Walk through evidence streams, weigh competing forces, THEN commit to overallTruthLikelihood.

            CALIBRATION ANCHORS:
            0.90-0.95: Near-certain (Tier 1-2 evidence, replicated ≥3x, expert consensus)
            0.70-0.89: Probable (Tier 2-3, partially replicated, majority agreement)
            0.50-0.69: Uncertain-leaning (mixed evidence, active debate)
            0.30-0.49: Genuinely uncertain (thin/conflicting evidence)
            0.05-0.29: Unlikely as stated (evidence contradicts claim)

            HARD RULES: No consensus → cap 0.70 | [CONFLICT]≥[DATA] → cap 0.60 | ≥2 engines oppose → cap 0.55 | Don't round to 0.50/0.70/0.80.

            ═══════════════════════════════════════
            OUTPUT: SINGLE JSON OBJECT
            ═══════════════════════════════════════

            ⚠️ Your response MUST begin with `{`. No prose, no markdown fences.

            {
              "laymanSummary": {
                "whatWasTried": "...",
                "whatIsLikelyTrue": "...",
                "confidenceExplanation": "...",
                "whatCouldChange": "...",
                "whoShouldTrust": "..."
              },
              "reflection": {
                "selfCriticalQuestions": ["5-7 pointed questions exposing genuine weaknesses"],
                "adjustments": ["3-5 confidence adjustments: CLAIM → ADJUSTMENT → REASON"],
                "leastDefensibleClaim": "single weakest claim with explanation",
                "precisionVsEvidenceCheck": "assessment of claimed precision vs evidence"
              },
              "arbitration": {
                "consensus": true/false,
                "votes": [
                  {"engine": "statistical", "position": "supports|opposes|neutral", "reasoning": "2-4 sentences", "confidence": 0.0-1.0},
                  {"engine": "causal", "position": "...", "reasoning": "...", "confidence": 0.0-1.0},
                  {"engine": "bayesian", "position": "...", "reasoning": "...", "confidence": 0.0-1.0},
                  {"engine": "meta_analysis", "position": "...", "reasoning": "...", "confidence": 0.0-1.0},
                  {"engine": "adversarial", "position": "...", "reasoning": "...", "confidence": 0.0-1.0}
                ],
                "disagreements": ["2-4 specific disagreements between engines"],
                "resolution": "2-4 sentence synthesis of the panel's position"
              },
              "truthAssessment": {
                "signalInterpretation": "4-6 sentences reasoning through evidence streams BEFORE committing to the number",
                "overallTruthLikelihood": 0.05-0.95,
                "weaknesses": ["3-5 specific, actionable weaknesses"],
                "improvements": ["3-5 specific improvements — name exact studies needed"],
                "blindSpots": ["2-4 areas the analysis may have missed"],
                "confidenceCalibration": "2-3 sentences cross-checking against calibration anchors",
                "dataVsModelBalance": "X% data-driven, Y% model-based, Z% heuristic (sum to 100%)",
                "recommendedActions": ["3-5 next steps prefixed with [ACT NOW], [WAIT], or [INVESTIGATE]"]
              }
            }
            """

        do {
            let raw = try await LLMService.generate(
                snapshot: llm,
                prompt: "Perform consolidated enrichment: layman summary, adversarial critique, multi-engine arbitration, and truth calibration for: \"\(queryAnalysis.coreQuestion)\"",
                systemPrompt: systemPrompt,
                maxTokens: 8000,
                timeout: 300
            )

            guard let obj = extractJSON(from: raw) else {
                Log.pipeline.info("🔬 Consolidated enrichment JSON PARSE FAILED — raw length=\(raw.count)")
                return nil
            }

            // Parse layman summary
            let laymanObj = obj["laymanSummary"] as? [String: Any]
            let fallbackLayman = fallbackLaymanSummary(queryAnalysis: queryAnalysis, signals: signals)
            let laymanSummary = LaymanSummary(
                whatWasTried: laymanObj?["whatWasTried"] as? String ?? fallbackLayman.whatWasTried,
                whatIsLikelyTrue: laymanObj?["whatIsLikelyTrue"] as? String ?? fallbackLayman.whatIsLikelyTrue,
                confidenceExplanation: laymanObj?["confidenceExplanation"] as? String ?? fallbackLayman.confidenceExplanation,
                whatCouldChange: laymanObj?["whatCouldChange"] as? String ?? fallbackLayman.whatCouldChange,
                whoShouldTrust: laymanObj?["whoShouldTrust"] as? String ?? fallbackLayman.whoShouldTrust,
                sectionLabels: SectionLabels(
                    whatWasTried: label1, whatIsLikelyTrue: label2,
                    confidenceExplanation: label3, whatCouldChange: label4, whoShouldTrust: label5
                )
            )

            // Parse reflection
            let reflObj = obj["reflection"] as? [String: Any]
            let fallbackRefl = fallbackReflection(signals: signals)
            let reflection = ReflectionResult(
                selfCriticalQuestions: reflObj?["selfCriticalQuestions"] as? [String] ?? fallbackRefl.selfCriticalQuestions,
                adjustments: reflObj?["adjustments"] as? [String] ?? [],
                leastDefensibleClaim: reflObj?["leastDefensibleClaim"] as? String ?? fallbackRefl.leastDefensibleClaim,
                precisionVsEvidenceCheck: reflObj?["precisionVsEvidenceCheck"] as? String ?? fallbackRefl.precisionVsEvidenceCheck
            )

            // Parse arbitration
            let arbObj = obj["arbitration"] as? [String: Any]
            let fallbackArb = fallbackArbitration(signals: signals)
            let votesRaw = arbObj?["votes"] as? [[String: Any]] ?? []
            let votes: [EngineVote] = votesRaw.compactMap { v in
                guard let engineStr = v["engine"] as? String,
                      let posStr = v["position"] as? String,
                      let reasoning = v["reasoning"] as? String,
                      let confidence = v["confidence"] as? Double
                else { return nil }
                let stage = PipelineStage(rawValue: engineStr.uppercased()) ?? .statistical
                let position: VotePosition =
                    posStr == "supports" ? .supports : posStr == "opposes" ? .opposes : .neutral
                return EngineVote(engine: stage, position: position, reasoning: reasoning, confidence: confidence)
            }
            let arbitration = ArbitrationResult(
                consensus: arbObj?["consensus"] as? Bool ?? (signals.confidence > 0.65),
                votes: votes.isEmpty ? fallbackArb.votes : votes,
                disagreements: arbObj?["disagreements"] as? [String] ?? [],
                resolution: arbObj?["resolution"] as? String ?? fallbackArb.resolution
            )

            // Parse truth assessment
            let truthObj = obj["truthAssessment"] as? [String: Any]
            let fallbackTruth = fallbackTruthAssessment(signals: signals)
            let likelihood = min(0.95, max(0.05, truthObj?["overallTruthLikelihood"] as? Double ?? signals.confidence))
            let truthAssessment = TruthAssessment(
                overallTruthLikelihood: likelihood,
                signalInterpretation: truthObj?["signalInterpretation"] as? String ?? fallbackTruth.signalInterpretation,
                weaknesses: truthObj?["weaknesses"] as? [String] ?? fallbackTruth.weaknesses,
                improvements: truthObj?["improvements"] as? [String] ?? fallbackTruth.improvements,
                blindSpots: truthObj?["blindSpots"] as? [String] ?? fallbackTruth.blindSpots,
                confidenceCalibration: truthObj?["confidenceCalibration"] as? String ?? fallbackTruth.confidenceCalibration,
                dataVsModelBalance: truthObj?["dataVsModelBalance"] as? String ?? fallbackTruth.dataVsModelBalance,
                recommendedActions: truthObj?["recommendedActions"] as? [String] ?? fallbackTruth.recommendedActions
            )

            return ConsolidatedEnrichment(
                laymanSummary: laymanSummary,
                reflection: reflection,
                arbitration: arbitration,
                truthAssessment: truthAssessment
            )
        } catch {
            Log.pipeline.info("🔬 Consolidated enrichment HTTP ERROR — \(error.localizedDescription)")
            return nil
        }
    }
}
