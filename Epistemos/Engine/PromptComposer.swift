import Foundation

// MARK: - Prompt Composer
// Translates settings to directives matching lib/engine/steering/prompt-composer.ts

enum PromptComposer {

    // MARK: - Compose Steering Directives

    nonisolated static func compose(
        controls: PipelineControls? = nil,
        steeringBias: SteeringBias? = nil,
        soarConfig: SOARConfig? = nil,
        signalOverrides: SignalOverrides? = nil,
        reroute: RerouteInstruction? = nil,
        analyticsEngineEnabled: Bool = true,
        chatMode: AnalyticalMode = .research
    ) -> String {
        guard analyticsEngineEnabled else { return "" }

        let deadband: Double = 0.15
        func far(_ value: Double, _ base: Double) -> Bool {
            abs(value - base) > deadband
        }

        var lines: [String] = []
        let c = controls
        let sb = steeringBias
        let soar = soarConfig
        let ov = signalOverrides

        // 0. Analytical Mode
        switch chatMode {
        case .research:
            lines.append("""
            Use a rigorous, evidence-based approach. Support significant claims with evidence — \
            citing study types, effect sizes, or consensus where relevant. Distinguish clearly \
            between empirical findings [DATA], theoretical models [MODEL], genuinely uncertain \
            questions [UNCERTAIN], and areas of active expert disagreement [CONFLICT]. \
            Surface contradictions in the evidence rather than smoothing them over. \
            Aim for the depth and intellectual honesty that would satisfy a careful specialist reader.
            """)
        case .plain:
            lines.append("""
            Lead with the direct answer, then support it concisely with the most compelling \
            evidence or reasoning. Include one non-obvious insight worth knowing. Express \
            uncertainty plainly. Skip filler — every sentence should add information.
            """)
        }

        // 1. Complexity Bias
        if let complexity = c?.complexityBias, far(complexity, 0) {
            if complexity > 0 {
                lines.append("""
                This question has more layers than it might initially appear. Where relevant, \
                try to address: what the question literally asks; what assumptions it takes for \
                granted (and whether they hold); how it connects to adjacent domains the reader \
                may not have considered; what second-order consequences follow from the obvious \
                answer; and whether the framing itself contains a hidden assumption or false \
                dichotomy. (complexity bias: +\(String(format: "%.2f", complexity)))
                """)
            } else {
                lines.append("""
                Prioritize clarity and directness over exhaustiveness. Identify the single strongest \
                conclusion the evidence supports, back it with the most compelling reasoning, and \
                mention only the caveats that would actually change the conclusion. \
                (complexity bias: \(String(format: "%.2f", complexity)))
                """)
            }
        }

        // 2. Adversarial Intensity
        if let adversarial = c?.adversarialIntensity, far(adversarial, 1.0) {
            if adversarial > 1.0 {
                lines.append("""
                Apply critical scrutiny to the main claims. For the central conclusions, consider: \
                what's the strongest opposing argument a thoughtful critic would make? What single \
                assumption does the conclusion most depend on — and if that assumption is wrong, \
                does the conclusion hold? \
                (adversarial intensity: \(String(format: "%.2f", adversarial))×)
                """)
            } else {
                lines.append("""
                Build toward synthesis rather than debate. Lead with the most compelling evidence \
                for the main conclusion, note alternatives where they're genuinely significant. \
                (adversarial intensity: \(String(format: "%.2f", adversarial))×)
                """)
            }
        }

        // 3. Bayesian Prior Strength
        if let bayesian = c?.bayesianPriorStrength, far(bayesian, 1.0) {
            if bayesian > 1.0 {
                lines.append("""
                Apply conservative epistemic standards. Anchor on base rates before adjusting for \
                specific evidence. Treat replicated findings as substantially more credible than \
                single studies. (prior strength: \(String(format: "%.2f", bayesian))×)
                """)
            } else {
                lines.append("""
                Bring epistemic openness to this topic. Give well-designed novel findings the benefit \
                of the doubt. (prior strength: \(String(format: "%.2f", bayesian))×)
                """)
            }
        }

        // 4. Focus Depth
        if let depth = c?.focusDepthOverride {
            if depth >= 8 {
                lines.append("""
                Go deep on this topic — the reader wants specialist-level treatment. \
                (depth: \(String(format: "%.1f", depth)))
                """)
            } else if depth >= 5 {
                lines.append("""
                Provide thorough coverage without exhausting every thread. \
                (depth: \(String(format: "%.1f", depth)))
                """)
            } else {
                lines.append("""
                Keep this focused and efficient — the reader wants the essential landscape. \
                (depth: \(String(format: "%.1f", depth)))
                """)
            }
        }

        // 5. Temperature
        if let temp = c?.temperatureOverride {
            if temp >= 1.2 {
                lines.append("""
                Bring creative, wide-ranging thinking to this response. Draw at least one analogy \
                from an unexpected domain. (temperature: \(String(format: "%.2f", temp)))
                """)
            } else if temp >= 0.85 {
                lines.append("""
                Balance rigor with imagination. Feel free to draw connections across domains. \
                (temperature: \(String(format: "%.2f", temp)))
                """)
            } else if temp <= 0.4 {
                lines.append("""
                Prioritize precision over creativity. Report what the evidence directly supports. \
                (temperature: \(String(format: "%.2f", temp)))
                """)
            }
        }

        // 6. Adaptive Steering
        if let sb = sb, sb.steeringStrength > 0.1 {
            var biasLines: [String] = []
            let str = sb.steeringStrength

            if abs(sb.confidence) * str > 0.05 {
                if sb.confidence > 0 {
                    biasLines.append("Confidence calibration: where evidence is strong, commit to clear conclusions. (+\(String(format: "%.2f", sb.confidence * str)))")
                } else {
                    biasLines.append("Confidence calibration: express uncertainty more explicitly. (\(String(format: "%.2f", sb.confidence * str)))")
                }
            }

            if abs(sb.entropy) * str > 0.05 {
                if sb.entropy > 0 {
                    biasLines.append("Complexity: surface disagreements between evidence streams. (+\(String(format: "%.2f", sb.entropy * str)))")
                } else {
                    biasLines.append("Clarity: converge toward the most defensible interpretation. (\(String(format: "%.2f", sb.entropy * str)))")
                }
            }

            if abs(sb.dissonance) * str > 0.05 {
                if sb.dissonance > 0 {
                    biasLines.append("Contradiction: surface disagreements and analyze why. (+\(String(format: "%.2f", sb.dissonance * str)))")
                } else {
                    biasLines.append("Synthesis: look for reconciliation through moderator variables. (+\(String(format: "%.2f", sb.dissonance * str)))")
                }
            }

            if abs(sb.healthScore) * str > 0.05 {
                if sb.healthScore > 0 {
                    biasLines.append("Rigor: trace each inference back to its evidence base. (+\(String(format: "%.2f", sb.healthScore * str)))")
                } else {
                    biasLines.append("Practicality: first-order approximations are acceptable. (\(String(format: "%.2f", sb.healthScore * str)))")
                }
            }

            if abs(sb.riskScore) * str > 0.05 {
                if sb.riskScore > 0 {
                    biasLines.append("Risk sensitivity: flag potential downsides clearly. (+\(String(format: "%.2f", sb.riskScore * str)))")
                } else {
                    biasLines.append("Opportunity orientation: emphasize what's possible. (\(String(format: "%.2f", sb.riskScore * str)))")
                }
            }

            if !biasLines.isEmpty {
                lines.append("""
                Adaptive steering (calibrated from \(sb.steeringSource), strength \(Int(str * 100))%): \
                \(biasLines.joined(separator: " "))
                """)
            }
        }

        // 7. Signal Overrides
        if let ov = ov {
            var overrides: [String] = []
            if let conf = ov.confidence { overrides.append("confidence=\(String(format: "%.2f", conf))") }
            if let ent = ov.entropy { overrides.append("entropy=\(String(format: "%.2f", ent))") }
            if let diss = ov.dissonance { overrides.append("dissonance=\(String(format: "%.2f", diss))") }

            if !overrides.isEmpty {
                lines.append("""
                The user has set the following signal priors for this query: \(overrides.joined(separator: ", ")). \
                Calibrate your certainty language to reflect these.
                """)
            }
        }

        // 8. SOAR Mode
        if let soar = soar, soar.enabled {
            lines.append("""
            After your main analysis, briefly reflect on: what evidence would most change your \
            conclusion, and what decisive data is missing?
            """)

            if soar.contradictionDetection {
                lines.append("""
                Check whether any major claims are in tension with each other. Where two claims \
                can't both be fully true, note the conflict explicitly.
                """)
            }
        }

        // 9. Concept Emphasis
        if let weights = c?.conceptWeights {
            let boosted = weights
                .filter { abs($0.value - 1.0) > 0.3 }
                .sorted { $0.value > $1.value }

            if !boosted.isEmpty {
                let items = boosted.map { concept, weight in
                    if weight > 1.0 {
                        "\"\(concept)\" (prioritize — \(String(format: "%.1f", weight))× weight)"
                    } else {
                        "\"\(concept)\" (de-emphasize — \(String(format: "%.1f", weight))× weight)"
                    }
                }
                lines.append("""
                Adjust analytical attention proportionally to these concepts: \(items.joined(separator: "; ")).
                """)
            }
        }

        // 10. Mid-stream Reroute Directive
        if let reroute = reroute {
            var rerouteLine = "REDIRECT: \(reroute.type.prompt)"
            if let detail = reroute.detail {
                rerouteLine += " Additional guidance: \(detail)"
            }
            lines.append(rerouteLine)
        }

        guard !lines.isEmpty else { return "" }

        return """

        [\(lines.joined(separator: " "))]

        """
    }

    // MARK: - Stage Detail Generation

    static func generateStageDetail(stage: PipelineStage, queryAnalysis: QueryAnalysis) -> String {
        let c = queryAnalysis.complexity
        let ef = min(1, Double(queryAnalysis.entities.count) / 8)
        let topic = queryAnalysis.entities.prefix(3).joined(separator: ", ").ifEmpty(
            "the query topic")

        switch stage {
        case .triage:
            return queryAnalysis.isPhilosophical
                ? "complexity score: \(String(format: "%.2f", 0.7 + c * 0.3)) — philosophical-conceptual routing"
                : "complexity score: \(String(format: "%.2f", 0.3 + c * 0.6)) — \(c > 0.5 ? "executive" : "moderate-depth") analysis"

        case .memory:
            return "\(Int(2 + c * 8)) context fragments retrieved for \"\(topic)\""

        case .routing:
            if queryAnalysis.isPhilosophical {
                return "philosophical-analytical mode — dialectical + ethical + epistemic engines"
            } else if queryAnalysis.isMetaAnalytical {
                return "meta-analytical mode — multi-study synthesis with heterogeneity assessment"
            } else if queryAnalysis.questionType == .causal {
                return "causal-inference mode — DAG construction + Bradford Hill scoring"
            }
            return "executive mode — full reasoning pipeline"

        case .statistical:
            let d = String(format: "%.2f", 0.2 + c * 0.8 + ef * 0.2)
            return
                "Cohen's d = \(d) (\(Double(d) ?? 0 > 0.8 ? "large" : Double(d) ?? 0 > 0.5 ? "medium" : "small"))"

        case .causal:
            let hill = String(format: "%.2f", 0.4 + c * 0.35 + ef * 0.15)
            return
                "Bradford Hill score: \(hill) — \(Double(hill) ?? 0 > 0.7 ? "strong" : Double(hill) ?? 0 > 0.5 ? "moderate" : "weak") causal evidence"

        case .metaAnalysis:
            if queryAnalysis.isPhilosophical {
                return
                    "\(Int(3 + Double(queryAnalysis.entities.count) * 0.6)) traditions synthesized"
            }
            let iSq = Int(20 + c * 40 + ef * 20)
            return
                "\(Int(4 + c * 8 + ef * 4)) studies pooled, I\u{00B2} = \(iSq)% (\(iSq < 30 ? "low" : iSq < 60 ? "moderate" : "high") heterogeneity)"

        case .bayesian:
            let bf = String(format: "%.1f", 1.5 + c * 12 + ef * 6)
            return
                "BF\u{2081}\u{2080} = \(bf) (\(Double(bf) ?? 0 > 10 ? "strong" : Double(bf) ?? 0 > 3 ? "moderate" : "weak") evidence)"

        case .synthesis:
            return queryAnalysis.isPhilosophical
                ? "synthesizing dialectical analysis across \(queryAnalysis.entities.count) concepts"
                : "integrating evidence streams for structured response"

        case .adversarial:
            let challenges = max(1, Int(1 + c * 2 + ef))
            return "\(challenges) weakness\(challenges > 1 ? "es" : "") identified"

        case .calibration:
            let conf = String(format: "%.2f", 0.3 + c * 0.35 + ef * 0.2)
            let grade = Double(conf) ?? 0 > 0.75 ? "A" : Double(conf) ?? 0 > 0.55 ? "B" : "C"
            return "final confidence: \(conf) (grade \(grade))"
        }
    }
}

// MARK: - Signal Overrides

struct SignalOverrides: Sendable {
    var confidence: Double?
    var entropy: Double?
    var dissonance: Double?
}
